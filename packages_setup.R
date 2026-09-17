# packages_setup.R — CRAN package bootstrap for NSSK.R
#
# Installs missing CRAN packages before NSSK.R's first library() call. Sourced by NSSK.R
# right after .script_dir is resolved. Must not depend on any non-base package itself.
# Standalone-runnable: `Rscript packages_setup.R` installs/verifies without running NSSK.R.
#
# Exports:
#   required_packages          — CRAN packages NSSK.R (or a file it sources) needs
#   cran_mirrors                — CRAN mirrors used for installation, first preferred
#   install_missing_packages() — installs whatever's missing from required_packages,
#                                 stops with a clear error if any are still missing after

# Kept in sync with NSSK.R (and render.R/context.R/theme.R/io.R) by hand -- nothing
# detects a new library()/:: call automatically. Add an entry whenever one of those files
# starts using a new CRAN package, or NSSK.R fails deep inside library() instead of here.
#
# Some entries are already transitive dependencies of others (conflicted/lubridate/ragg
# via tidyverse; fs via gt) but are listed and verified independently regardless, since
# install.packages() de-dupes the resolved graph for free and each is also called
# directly by library()/:: elsewhere in this codebase.
required_packages <- c(
  "conflicted",
  "tidyverse",
  "lubridate",
  "gt",
  "ragg",
  "fs",
  "systemfonts" # not library()'d directly, but theme.R calls systemfonts::system_fonts()
)

# Canadian CRAN mirrors (https://cran.r-project.org/mirrors.html), Manitoba Unix User
# Group first. install.packages() queries every entry in `repos` and merges results --
# confirmed directly: an unreachable first entry still resolves via the second, with only
# a warning for the dead one. So this is automatic fallback, not a single fixed mirror.
# If none are reachable, install_missing_packages() below still fails fast (see its stop()).
cran_mirrors <- c(
  CRANmuug   = "https://muug.ca/mirror/cran/",              # Manitoba Unix User Group
  CRAN       = "https://mirror.csclub.uwaterloo.ca/CRAN/",  # University of Waterloo CS Club
  CRANrafal  = "https://cran.mirror.rafal.ca/"               # Rafal Rzeczkowski
)

# Installs whichever of pkgs are missing, from mirrors, with dependencies. No-op (no
# network access) if everything's already installed. Stops naming the failed package(s)
# if any are still missing after the install attempt.
install_missing_packages <- function(pkgs, mirrors) {
  is_missing <- function(pkg) !requireNamespace(pkg, quietly = TRUE)

  missing <- Filter(is_missing, pkgs)
  if (length(missing) == 0) {
    message("packages_setup.R: all required packages are already installed, proceeding.")
    return(invisible(NULL))
  }

  for (pkg in missing) {
    message("packages_setup.R: package '", pkg, "' not found, installing...")
  }
  message("packages_setup.R: using CRAN mirror(s): ", paste(mirrors, collapse = ", "))

  old_repos <- getOption("repos")
  options(repos = mirrors)
  on.exit(options(repos = old_repos), add = TRUE)

  # Compile with make -jN instead of make's serial default. parallel is a base package
  # (no install needed); detectCores() is the cross-platform equivalent of `nproc`.
  # Restored on exit rather than left set for the rest of the session.
  #
  # No-op on Windows/macOS in the normal case, since install.packages() prefers CRAN's
  # precompiled binaries there and no `make` runs at all. Real speedup on Linux, where
  # every package builds from source; also applies on Windows/macOS if a source build
  # is forced (no binary available yet, or pkgType = "source").
  ncores <- tryCatch(parallel::detectCores(), error = function(e) NA_integer_)
  if (!is.na(ncores) && ncores > 1) {
    old_makeflags <- Sys.getenv("MAKEFLAGS", unset = NA)
    Sys.setenv(MAKEFLAGS = paste0("-j", ncores))
    on.exit(
      if (is.na(old_makeflags)) Sys.unsetenv("MAKEFLAGS") else Sys.setenv(MAKEFLAGS = old_makeflags),
      add = TRUE
    )
    message("packages_setup.R: compiling with up to ", ncores, " parallel jobs (MAKEFLAGS=-j", ncores, ")")
  }

  install_error <- tryCatch(
    {
      # Ncpus parallelizes across packages; MAKEFLAGS above parallelizes within each one.
      if (!is.na(ncores) && ncores > 1) {
        install.packages(missing, dependencies = NA, Ncpus = ncores)
      } else {
        install.packages(missing, dependencies = NA)
      }
      NULL
    },
    error = function(e) conditionMessage(e)
  )

  still_missing <- Filter(is_missing, missing)

  if (length(still_missing) > 0) {
    stop(
      "packages_setup.R: failed to install required package(s): ",
      paste(still_missing, collapse = ", "), ".\n",
      if (!is.null(install_error)) paste0("install.packages() error: ", install_error, "\n") else "",
      "Mirror(s) used: ", paste(mirrors, collapse = ", "), "\n",
      "Check network connectivity and mirror availability, and that the R library path ",
      "is writable (a common cause under non-interactive Rscript runs).\n",
      "See doc/SETUP.md for platform-specific system library requirements — on Linux, compiling ",
      "these from source needs libpng/freetype/harfbuzz/cairo (ragg/systemfonts), libuv1-dev ",
      "(fs), and libv8-dev or libnode-dev (V8, a dependency of gt).",
      call. = FALSE
    )
  }

  message("packages_setup.R: all required packages are now installed, proceeding.")
  invisible(NULL)
}

# Auto-installs only when this file is the literal Rscript entry point (`Rscript
# packages_setup.R` -- manual pre-install/testing use, not the primary path). NSSK.R is the
# primary path: it sources this file, then calls install_missing_packages() itself, right
# after. --file= (unlike sys.nframe()) always names the top-level script regardless of
# source() nesting depth -- confirmed directly -- so this stays accurate no matter how deep
# whatever sourced this file is nested. Sourcing this file from anywhere else (RStudio, a
# test, a REPL) only defines required_packages/cran_mirrors/install_missing_packages(); it
# never installs anything on its own, same as every other sourced file in this project
# (render.R/context.R/theme.R/io.R).
.entry_file <- grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(.entry_file) > 0 && basename(sub("--file=", "", .entry_file)) == "packages_setup.R") {
  install_missing_packages(required_packages, cran_mirrors)
}
