# Tests for packages_setup.R
#
# Run from the project root:
#   Rscript tests/test-packages-setup.R
#
# Sections below, in order: default mirror list (deterministic), input validation on
# `pkgs` (deterministic, negative-focused), the no-op path (deterministic),
# .resolve_nonexistent() (deterministic, pure, negative-focused), .non_transient_patterns
# classification (deterministic, pure, negative-focused), then a small set of real-network
# integration tests for the paths that can't be exercised any other way (non-writable lib,
# nonexistent package, empty repos). install.packages()'s own download/build success
# path is not exercised here (mocking it would only prove Filter()/stop() compose
# correctly, not that the script achieves its goal against a real mirror) -- see
# doc/SETUP.md / the plan that introduced this file for how that's verified instead.

if (!requireNamespace("testthat", quietly = TRUE)) {
  install.packages("testthat", repos = "https://mirror.csclub.uwaterloo.ca/CRAN/")
}
library(testthat)

source("packages_setup.R")

# check_installed_packages()'s repos default isn't a standalone exported object -- evaluate
# it directly from the function's own formals/environment to test the real default without
# calling the function (which would attempt a real install for a missing package).
default_repos <- eval(formals(check_installed_packages)$repos, envir = environment(check_installed_packages))

## Default mirror list ---------------------------------------------------------------

test_that("the default mirrors are non-empty and every entry is a well-formed https URL", {
  expect_true(length(default_repos) > 0)
  expect_true(all(grepl("^https://", default_repos)))
})

test_that("the default mirrors have no duplicate URLs", {
  expect_equal(anyDuplicated(unname(default_repos)), 0)
})

test_that("the Manitoba Unix User Group mirror is first in the default mirrors", {
  expect_equal(unname(default_repos[1]), "https://muug.ca/mirror/cran/")
})

## Input validation on pkgs (negative) ------------------------------------------------

test_that("check_installed_packages() errors on an empty package list", {
  expect_error(check_installed_packages(character(0)))
})

test_that("check_installed_packages() rejects non-character pkgs before any network access", {
  expect_error(check_installed_packages(123), "must be a character vector")
  expect_error(check_installed_packages(TRUE), "must be a character vector")
  expect_error(check_installed_packages(list("fs")), "must be a character vector")
})

test_that("check_installed_packages() rejects NA/blank pkgs before any network access", {
  expect_error(check_installed_packages(c("fs", NA)), "must not contain NA or blank/empty names")
  expect_error(check_installed_packages(c("fs", "")), "must not contain NA or blank/empty names")
  expect_error(check_installed_packages("   "), "must not contain NA or blank/empty names")
  expect_error(check_installed_packages(NA_character_), "must not contain NA or blank/empty names")
})

## No-op path -------------------------------------------------------------------------

test_that("check_installed_packages() is a no-op when everything is already installed", {
  # utils/methods are base packages -- always present, no network needed -- so this
  # exercises the no-op path deterministically regardless of what else is installed.
  old_repos <- getOption("repos")
  expect_message(
    check_installed_packages(c("utils", "methods")),
    "all required packages are already installed, proceeding"
  )
  expect_equal(getOption("repos"), old_repos)
})

## .resolve_nonexistent() -- pure, deterministic, negative-focused --------------------

# Builds a synthetic available.packages()-shaped matrix, one row per package, so these
# tests don't need real network access. pkgs_desc is a named list: name = package name,
# value = a list with optional Depends/Imports/LinkingTo character strings.
.synthetic_available <- function(pkgs_desc) {
  cols <- c("Package", "Version", "Priority", "Depends", "Imports", "LinkingTo", "Suggests",
            "Enhances", "License", "License_is_FOSS", "License_restricts_use", "OS_type",
            "Archs", "MD5sum", "NeedsCompilation", "File", "Repository")
  pkg_names <- names(pkgs_desc)
  m <- matrix(NA_character_, nrow = length(pkg_names), ncol = length(cols),
              dimnames = list(pkg_names, cols))
  m[, "Package"] <- pkg_names
  for (p in pkg_names) {
    for (field in c("Depends", "Imports", "LinkingTo")) {
      if (!is.null(pkgs_desc[[p]][[field]])) m[p, field] <- pkgs_desc[[p]][[field]]
    }
  }
  m
}

test_that(".resolve_nonexistent() finds nothing wrong for a package with no dependencies", {
  ap <- .synthetic_available(list(realpkg = list()))
  expect_equal(.resolve_nonexistent("realpkg", ap), character(0))
})

test_that(".resolve_nonexistent() catches a declared dependency that isn't in the listing", {
  ap <- .synthetic_available(list(realpkg = list(Imports = "ghostdep")))
  expect_equal(.resolve_nonexistent("realpkg", ap), "ghostdep")
})

test_that(".resolve_nonexistent() excludes base R packages from declared dependencies", {
  # The regression this guards: base packages (never CRAN-hosted, so never a row in
  # `available`) are extremely common declared dependencies -- without this exclusion,
  # almost any real package would be misreported as having a missing dependency.
  ap <- .synthetic_available(list(realpkg = list(
    Depends = "R (>= 3.5.0), methods",
    Imports = "stats, utils"
  )))
  expect_equal(.resolve_nonexistent("realpkg", ap), character(0))
})

test_that(".resolve_nonexistent() catches a genuinely missing top-level package name", {
  ap <- .synthetic_available(list(realpkg = list()))
  expect_equal(.resolve_nonexistent("totally.absent.pkg", ap), "totally.absent.pkg")
})

test_that(".resolve_nonexistent() resolves a multi-level transitive dependency chain", {
  ap <- .synthetic_available(list(
    top    = list(Imports = "middle"),
    middle = list(Imports = "ghostdep")
  ))
  expect_equal(.resolve_nonexistent("top", ap), "ghostdep")
})

test_that(".resolve_nonexistent() handles a mix of valid and invalid requested packages", {
  ap <- .synthetic_available(list(goodpkg = list()))
  expect_equal(.resolve_nonexistent(c("goodpkg", "badpkg"), ap), "badpkg")
})

## .non_transient_patterns classification -- pure, deterministic, negative-focused ----

test_that(".non_transient_patterns matches all of its own known non-transient warning shapes", {
  samples <- c(
    "'lib = \"/some/path\"' is not writable",
    "Permission denied",
    "permission denied while creating file",
    "cannot create file: No space left on device"
  )
  combined <- paste(.non_transient_patterns, collapse = "|")
  expect_true(all(grepl(combined, samples)))
})

test_that(".non_transient_patterns does NOT match transient/unrelated warning shapes", {
  # Guards against over-broad patterns misclassifying genuinely retryable failures as
  # permanent -- these are real warning texts seen elsewhere this session. Includes the
  # generic build-failure exit-status message: deliberately excluded from the denylist
  # since it's indistinguishable from an ordinary lock conflict with a concurrent install
  # (see packages_setup.R), so it's treated as retryable rather than fatal.
  samples <- c(
    "unable to access index for repository ... cannot open URL",
    "package 'X' is not available for this version of R",
    "Timeout of 60 seconds was reached",
    "installation of package 'X' had non-zero exit status"
  )
  combined <- paste(.non_transient_patterns, collapse = "|")
  expect_false(any(grepl(combined, samples)))
})

## Real-network integration tests (negative) -------------------------------------------

test_that("check_installed_packages() fails immediately on a non-writable lib, without retrying", {
  # Needs a real CRAN package name, not a fake one -- the upfront existence check would
  # catch a fake name first and never reach the lib-writability logic this test is about.
  pkg <- "cowsay" # small, real, unlikely to be a dependency of anything else installed here
  skip_if(requireNamespace(pkg, quietly = TRUE), paste(pkg, "is already installed in this environment"))

  readonly_lib <- file.path(tempdir(), "readonly_lib_test")
  dir.create(readonly_lib, showWarnings = FALSE)
  Sys.chmod(readonly_lib, mode = "0555")
  on.exit({
    Sys.chmod(readonly_lib, mode = "0755")
    unlink(readonly_lib, recursive = TRUE)
  }, add = TRUE)

  expect_error(
    check_installed_packages(pkg, install_options = list(lib = readonly_lib)),
    "non-transient error"
  )
})

test_that("check_installed_packages() fails fast on a package that doesn't exist on any mirror", {
  expect_error(
    check_installed_packages("zzz.totally.fake.package.name"),
    "not found on any of the given mirrors"
  )
})

test_that("check_installed_packages() errors rather than hangs or silently succeeds when given no mirrors", {
  pkg <- "beepr" # small, real, unlikely to already be installed
  skip_if(requireNamespace(pkg, quietly = TRUE), paste(pkg, "is already installed in this environment"))
  old <- .max_retries
  .max_retries <<- 0
  on.exit(.max_retries <<- old, add = TRUE)

  expect_error(check_installed_packages(pkg, repos = character(0)))
})

cat("All tests passed.\n")
