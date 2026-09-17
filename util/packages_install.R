# util/packages_install.R — pre-installs NSSK.R's CRAN packages without running the analysis.
#
# This is a test/dev-support utility, not part of the NSSK.R analysis workflow. You do not
# need to run this manually to run NSSK.R -- NSSK.R installs its own missing packages
# automatically on every run (see packages_setup.R). Use this only to pre-warm a machine's
# package cache ahead of time (e.g. CI, a fresh container) without doing a full analysis run.
#
# Usage (works from any working directory):
#   Rscript util/packages_install.R

# Duplicates NSSK.R's required_packages -- NSSK.R can't be sourced standalone for just this
# list (it expects real CLI args/input data partway through). Keep in sync if NSSK.R's list
# changes.
required_packages <- c(
  "conflicted",
  "fs", # context.R calls fs::path_abs()
  "gt",
  "lubridate",
  "ragg",
  "systemfonts", # theme.R calls systemfonts::system_fonts()
  "tidyverse"
)

# Resolve the project root (this script's own parent directory) so packages_setup.R can be
# sourced by path regardless of the working directory at invocation time. Mirrors NSSK.R
# section 1.1.1. Deliberately base-R only (no fs::) -- this script's job is partly to
# install fs itself, so it can't assume fs:: is available yet.
# Rscript:   this script lives at <project_root>/util/packages_install.R, so its own
#            directory (from --file=) is one level below the project root.
# RStudio:   falls back to getwd() -- assumes the project was opened via the .Rproj file,
#            which sets the working directory to the project root directly (no extra step).
.project_root <- if (!interactive()) {
  file_arg <- grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) {
    stop("--file= not found in commandArgs — invoke the script via: Rscript util/packages_install.R")
  }
  dirname(dirname(normalizePath(sub("--file=", "", file_arg[1]), winslash = "/", mustWork = FALSE)))
} else {
  getwd()
}

source(file.path(.project_root, "packages_setup.R"))
check_installed_packages(required_packages)
