# packages_setup.R — generic CRAN package checker/installer
#
# Caller supplies its own package list, which is checked against environment, and only 
# missing packages are installed.
#
# NSSK.R (its own required_packages), tests/test-context.R (testthat/devtools/fs), and
# util/packages_install.R (a standalone driver for NSSK.R's list) for the pattern.
#
# Not completely watertight, but should work for the vast majority of cases.
#
# Exports:
#   check_installed_packages()  — installs whatever's missing from a caller-supplied package
#                                  list, stops with a clear error if any are still missing after

# CRAN mirrors (https://cran.r-project.org/mirrors.html). Internal -- not part of this
# file's interface; only used to build check_installed_packages()'s default repos below.
.cran_mirrors_canada <- c(
  CRANmuug	= "https://muug.ca/mirror/cran/",              # Manitoba Unix User Group
  CRANwaterloo	= "https://mirror.csclub.uwaterloo.ca/CRAN/",  # University of Waterloo CS Club
  CRANrafal	= "https://cran.mirror.rafal.ca/"              # Rafal Rzeczkowski - private
)

# Mirrors from countries with an active direct undersea cable link to Canada (UK: EXA
# Express; Iceland: Greenland Connect; Japan: Topaz), used as fallback after Canada.
# Ordered by measured download speed, fastest first. Not robustly tested and may vary in
# the future. Internal, same as .cran_mirrors_canada above.
.cran_mirrors_secondary <- c(
  CRANiceland = "https://cran.hafro.is/",                    # primary   -- Iceland; run by Hafrannsóknastofnun, Iceland's government Marine and Freshwater Research Institute
  CRANbristol = "https://www.stats.bris.ac.uk/R/",           # secondary -- UK; run by the University of Bristol's School of Mathematics
  CRANjapan   = "https://ftp.yz.yamagata-u.ac.jp/pub/cran/"  # tertiary  -- Japan; run by Yamagata University's Networking and Computing Service Center, Faculty of Engineering
)

# Installs whichever of pkgs are missing, from supplied or default cran mirrrors, with respective dependencies.
#
# install_options is a named list merged over this function's own install.packages() defaults
# (pkgs, repos, dependencies = NA) -- e.g. install_options = list(dependencies = FALSE) to
# override.
check_installed_packages <- function(pkgs, repos = c(.cran_mirrors_canada, .cran_mirrors_secondary), install_options = list()) {
  if (length(pkgs) == 0) {
    stop("check_installed_packages: pkgs must not be empty.", call. = FALSE)
  }

  is_missing <- function(pkg) !requireNamespace(pkg, quietly = TRUE)

  missing <- Filter(is_missing, pkgs)
  if (length(missing) == 0) {
    message("check_installed_packages: all required packages are already installed, proceeding.")
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

  # Compile with make -jN instead of make's serial default on linux systems.
  #
  # No-op on Windows/macOS in the normal case, since install.packages() uses CRAN's
  # precompiled binaries there and no `make` runs at all. 
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
    if (is.null(install_args$Ncpus)) install_args$Ncpus <- ncores
  }

  install_error <- tryCatch(
    { do.call(install.packages, install_args); NULL },
    error = function(e) conditionMessage(e)
  )

  still_missing <- Filter(is_missing, missing)

  if (length(still_missing) > 0) {
    stop(
      "check_installed_packages: failed to install package(s): ",
      paste(still_missing, collapse = ", "), ".\n",
      if (!is.null(install_error)) paste0("install.packages() error: ", install_error, "\n") else "",
      "Mirror(s) used: ", paste(repos, collapse = ", "), "\n",
      "Check network connectivity and mirror availability, and that the R library path ",
      "is writable (a common cause under non-interactive Rscript runs). ",
      "See doc/SETUP.md for platform-specific system library requirements.",
      call. = FALSE
    )
  }

  message("check_installed_packages: all required packages are now installed, proceeding.")
  invisible(NULL)
}
