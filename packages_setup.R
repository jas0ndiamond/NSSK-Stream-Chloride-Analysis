# packages_setup.R — generic CRAN package checker/installer
#
# Caller supplies its own package list; only missing packages are installed.
# Used by NSSK.R, util/packages_install.R, and tests/test-context.R.
#
# Exports:
#   check_installed_packages() — installs whatever's missing from a caller-supplied
#                                 package list, stops with a clear error if any remain
#                                 missing after retrying.

# CRAN mirrors (https://cran.r-project.org/mirrors.html). Internal -- not part of this
# file's interface; only used to build check_installed_packages()'s default repos below.
.cran_mirrors_canada <- c(
  CRANmuug	= "https://muug.ca/mirror/cran/",              # Manitoba Unix User Group
  CRANwaterloo	= "https://mirror.csclub.uwaterloo.ca/CRAN/",  # University of Waterloo CS Club
  CRANrafal	= "https://cran.mirror.rafal.ca/"              # Rafal Rzeczkowski - private
)

# Fallback mirrors after Canada, from countries with a direct undersea cable link
# (UK/Iceland/Japan). Ordered by measured download speed, fastest first.
.cran_mirrors_secondary <- c(
  CRANiceland = "https://cran.hafro.is/",                    # primary   -- Iceland; run by Hafrannsóknastofnun, Iceland's government Marine and Freshwater Research Institute
  CRANbristol = "https://www.stats.bris.ac.uk/R/",           # secondary -- UK; run by the University of Bristol's School of Mathematics
  CRANjapan   = "https://ftp.yz.yamagata-u.ac.jp/pub/cran/"  # tertiary  -- Japan; run by Yamagata University's Networking and Computing Service Center, Faculty of Engineering
)

# Warning substrings meaning a failure won't be fixed by trying another mirror
# (unwritable lib, disk space). A denylist rather than an allowlist of network-error
# strings, since those vary a lot by OS/method -- an unmatched failure just costs one
# extra retry pass, not a wrong result.
#
# "had non-zero exit status" (a source build failure) is deliberately NOT here: it's the
# same generic message R gives for a lock conflict with a concurrent install (verified
# directly -- R's specific "failed to lock directory" text isn't observable via
# warnings_seen or sink(), see git history for the failed attempts), so it can't be
# classified as non-transient without also misclassifying an ordinary lock conflict.
# Letting it retry instead means a genuine non-transient build failure (e.g. a missing
# system library) takes the full mirror/cycle exhaustion time to surface instead of
# failing fast -- accepted tradeoff, since the final still_missing check below is what
# actually decides success or failure either way.
.non_transient_patterns <- c(
  "is not writable",
  "[Pp]ermission denied",
  "No space left on device"
)

# Retry tuning for check_installed_packages()/.install_from_mirrors() below. Internal
# constants, not caller-facing parameters -- not part of this file's interface, same as
# the mirror lists and .non_transient_patterns above.
.max_retries <- 3        # full-mirror-list retry cycles after the first pass, before giving up for good
.retry_delay_secs <- 300 # sleep between cycles once a full pass through the mirror list is exhausted

.is_missing <- function(pkg) !requireNamespace(pkg, quietly = TRUE)

# Given `missing` package names and an available.packages() result, returns the subset
# of `missing` plus its full dependency closure (Depends/Imports/LinkingTo) that doesn't
# exist anywhere in `available`, excluding base R packages (shipped with R, never
# CRAN-hosted, so never a row in `available`). Pure/no network, so directly unit-testable
# with a synthetic `available` matrix.
.resolve_nonexistent <- function(missing, available) {
  deps <- tools::package_dependencies(missing, db = available,
                                       which = c("Depends", "Imports", "LinkingTo"),
                                       recursive = TRUE)
  needed <- unique(c(missing, unlist(deps, use.names = FALSE)))
  base_pkgs <- rownames(installed.packages(priority = "base"))
  setdiff(needed, c(rownames(available), base_pkgs))
}

# Tries `pkgs` against `repos[1]`; on a transient failure, recurses against `repos[-1]`.
# install.packages() doesn't itself retry a different mirror when a download fails, so
# this adds that. Always recurses with the full `pkgs` list -- cheap, since
# already-installed packages are just skipped via .is_missing().
#
# Returns invisible(NULL) on success, stop()s on a non-transient failure, or (if `repos`
# is exhausted with packages still missing) a character vector of what's still missing,
# so check_installed_packages() can decide whether to sleep and retry a new cycle.
.install_from_mirrors <- function(pkgs, repos, install_options) {
  missing <- Filter(.is_missing, pkgs)
  if (length(missing) == 0) {
    return(invisible(NULL))
  }

  for (pkg in missing) {
    message("check_installed_packages: package '", pkg, "' not found, installing...")
  }
  message("check_installed_packages: using CRAN mirror(s): ", paste(repos, collapse = ", "))

  install_args <- utils::modifyList(
    list(pkgs = missing, repos = repos, dependencies = NA),
    install_options
  )

  # withCallingHandlers (not tryCatch): a handler that returns without invoking a
  # restart lets the warning keep printing/propagating normally -- this only observes
  # it for classification below.
  warnings_seen <- character()
  install_error <- withCallingHandlers(
    tryCatch(
      { do.call(install.packages, install_args); NULL },
      error = function(e) conditionMessage(e)
    ),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
    }
  )

  still_missing <- Filter(.is_missing, missing)

  if (length(still_missing) == 0) {
    return(invisible(NULL))
  }

  non_transient <- any(grepl(paste(.non_transient_patterns, collapse = "|"), warnings_seen))

  if (non_transient) {
    stop(
      "check_installed_packages: failed to install package(s): ", paste(still_missing, collapse = ", "),
      " due to a non-transient error (not retrying):\n",
      paste(warnings_seen, collapse = "\n"), "\n",
      if (!is.null(install_error)) paste0("install.packages() error: ", install_error, "\n") else "",
      "See doc/SETUP.md for platform-specific system library requirements.",
      call. = FALSE
    )
  }

  remaining_repos <- repos[-1]
  if (length(remaining_repos) == 0) {
    return(still_missing) # this pass is exhausted; let check_installed_packages() decide whether to sleep and retry
  }

  message("check_installed_packages: mirror '", repos[1], "' failed for transient reasons, retrying with next mirror...")
  .install_from_mirrors(pkgs, remaining_repos, install_options)
}

# Installs whichever of pkgs are missing, from supplied or default CRAN mirrors.
#
# install_options is merged over this function's own install.packages() defaults
# (pkgs, repos, dependencies = NA) -- e.g. install_options = list(dependencies = FALSE)
# to override.
#
# Manages the full-mirror-list retry cycle: calls .install_from_mirrors() up to
# .max_retries + 1 times, sleeping .retry_delay_secs between cycles once a full pass
# exhausts the mirror list with packages still missing for transient reasons.
check_installed_packages <- function(pkgs, repos = c(.cran_mirrors_canada, .cran_mirrors_secondary), install_options = list()) {
  if (length(pkgs) == 0) {
    stop("check_installed_packages: pkgs must not be empty.", call. = FALSE)
  }
  if (!is.character(pkgs)) {
    stop("check_installed_packages: pkgs must be a character vector.", call. = FALSE)
  }
  # NA/blank names otherwise crash with an unhelpful low-level error or get misdiagnosed
  # further down as "not found on any of the given mirrors" -- catch them here instead.
  if (anyNA(pkgs) || any(trimws(pkgs) == "")) {
    stop("check_installed_packages: pkgs must not contain NA or blank/empty names.", call. = FALSE)
  }

  missing <- Filter(.is_missing, pkgs)
  if (length(missing) == 0) {
    message("check_installed_packages: all required packages are already installed, proceeding.")
    return(invisible(NULL))
  }

  # Checked once upfront, against every mirror's combined listing, whether `missing` and
  # its full dependency closure exist anywhere at all -- a name absent from every mirror
  # fails here (retrying can't fix that); a name just missing from one stale mirror's
  # index still goes through the normal retry path below. package_dependencies() reuses
  # this same available.packages() result as its db, so expanding to the dependency
  # closure costs no extra network call. If the check itself can't complete (e.g. every
  # mirror is unreachable), skip it and let the normal retry path handle that instead.
  check_type <- if (is.null(install_options$type)) getOption("pkgType") else install_options$type
  available <- tryCatch(
    available.packages(repos = repos, type = check_type),
    error = function(e) NULL
  )
  if (!is.null(available)) {
    nonexistent <- .resolve_nonexistent(missing, available)
    if (length(nonexistent) > 0) {
      stop(
        "check_installed_packages: package(s) not found on any of the given mirrors: ",
        paste(nonexistent, collapse = ", "), ".\n",
        "Check the name(s) for typos -- this is not a connectivity or mirror-availability ",
        "problem, so retrying would not help.\n",
        "Mirror(s) checked: ", paste(repos, collapse = ", "),
        call. = FALSE
      )
    }
  }

  # Compile with make -jN instead of the serial default on Linux. Set once here for the
  # whole call (not per attempt in .install_from_mirrors()) since the value never
  # changes between mirrors or cycles. No-op on Windows/macOS, where install.packages()
  # uses precompiled binaries and no `make` runs.
  ncores <- tryCatch(parallel::detectCores(), error = function(e) NA_integer_)
  if (!is.na(ncores) && ncores > 1) {
    old_makeflags <- Sys.getenv("MAKEFLAGS", unset = NA)
    Sys.setenv(MAKEFLAGS = paste0("-j", ncores))
    on.exit(
      if (is.na(old_makeflags)) Sys.unsetenv("MAKEFLAGS") else Sys.setenv(MAKEFLAGS = old_makeflags),
      add = TRUE
    )
    message("check_installed_packages: compiling with up to ", ncores, " parallel jobs (MAKEFLAGS=-j", ncores, ")")
    # Ncpus parallelizes across packages; MAKEFLAGS above parallelizes within each one.
    # Only set if the caller didn't already specify one.
    if (is.null(install_options$Ncpus)) install_options$Ncpus <- ncores
  }

  for (attempt in seq_len(.max_retries + 1)) {
    result <- .install_from_mirrors(pkgs, repos, install_options)

    if (is.null(result)) {
      message("check_installed_packages: all required packages are now installed, proceeding.")
      return(invisible(NULL))
    }

    if (attempt <= .max_retries) {
      message("check_installed_packages: all mirrors exhausted (cycle ", attempt, "/", .max_retries + 1,
              "), sleeping ", .retry_delay_secs, "s before retrying the full mirror list...")
      Sys.sleep(.retry_delay_secs)
    } else {
      stop(
        "check_installed_packages: failed to install package(s): ", paste(result, collapse = ", "),
        " -- all mirrors exhausted across ", .max_retries + 1, " attempt(s).\n",
        "Mirror(s) used: ", paste(repos, collapse = ", "), "\n",
        "Check network connectivity and mirror availability, and that the R library path ",
        "is writable (a common cause under non-interactive Rscript runs). ",
        "See doc/SETUP.md for platform-specific system library requirements.",
        call. = FALSE
      )
    }
  }
}
