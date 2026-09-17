# util/packages_uninstall.R — removes the 7 CRAN packages util/packages_install.R (and
# NSSK.R) installs, so this machine's real R environment can be reset to exercise
# packages_setup.R's not-found/installing path directly, without Docker.
#
# This is a test/dev-support utility, not part of the NSSK.R analysis workflow. You do not
# need to run this manually to run NSSK.R -- it exists solely to reset a machine's package
# state so packages_setup.R's install path can be exercised and verified again.
#
# This mutates your real R library (not a disposable container — see
# tests/docker-packages-setup-test.sh for a fully isolated alternative that never touches
# it). Nothing here is destroyed beyond reinstallability: re-running NSSK.R (or
# `Rscript util/packages_install.R` directly) reinstalls everything from the same CRAN
# mirror. Only these 7 packages are removed — their already-installed transitive
# dependencies are left alone, so a local reinstall after this is much faster than a true
# from-scratch one (measured at ~25 min in a clean container; see
# tests/docker-packages-setup-test.sh).
#
# Usage:
#   Rscript util/packages_uninstall.R      # asks for y/n confirmation before removing
#   Rscript util/packages_uninstall.R -y   # skips the confirmation
#
# If you then want to verify the reinstall from an already-open RStudio session, restart R
# first (Session > Restart R). requireNamespace() checks already-loaded namespaces before
# ever touching disk, so a session that had these packages loaded before this ran will keep
# reporting them "available" from memory and skip reinstalling, even though the files here
# just got deleted by this (separate) process.

# Mirrors NSSK.R's required_packages exactly. Duplicated rather than sourced from
# util/packages_install.R — sourcing it would trigger a real check_installed_packages()
# install call, which is wrong here (most obviously when these packages are already
# absent: it would install them just so this script could immediately remove them again).
# Keep this in sync if that list changes.
required_packages <- c(
  "conflicted",
  "fs", # context.R calls fs::path_abs()
  "gt",
  "lubridate",
  "ragg",
  "systemfonts", # theme.R calls systemfonts::system_fonts()
  "tidyverse"
)

skip_confirm <- "-y" %in% commandArgs(trailingOnly = TRUE)

# remove.packages() itself refuses to remove "base" packages (base, tools, utils, stats,
# ...) -- stop() if the whole request is base packages, warning()-and-skip if it's a mix
# (see ?remove.packages / utils::remove.packages source). It gives no such protection to
# "recommended" packages (MASS, Matrix, boot, etc., also shipped with R) -- confirmed
# directly: remove.packages() deletes one with no error or warning at all. Both priorities
# ship with R and are never something this project installed, so neither should ever be a
# legitimate entry in required_packages; check for both explicitly rather than relying on
# remove.packages()'s own (partial) protection.
priority <- installed.packages()[, "Priority"]
core_pkgs <- intersect(required_packages, names(priority)[priority %in% c("base", "recommended")])
if (length(core_pkgs) > 0) {
  stop(
    "packages_uninstall.R: required_packages contains R core/recommended package(s): ",
    paste(core_pkgs, collapse = ", "), ". These ship with R itself and must never be ",
    "uninstalled -- remove them from required_packages.",
    call. = FALSE
  )
}

installed <- Filter(function(pkg) requireNamespace(pkg, quietly = TRUE), required_packages)

if (length(installed) == 0) {
  message("packages_uninstall.R: none of the required packages are currently installed. Nothing to do.")
  quit(status = 0)
}

if (!skip_confirm) {
  cat("This will remove the following packages: ", paste(installed, collapse = ", "), "\n", sep = "")
  cat("Continue? [y/N] ")
  answer <- tryCatch(readLines(con = "stdin", n = 1), error = function(e) "")
  if (!tolower(trimws(answer)) %in% c("y", "yes")) {
    message("packages_uninstall.R: aborted, nothing removed.")
    quit(status = 0)
  }
}

message("packages_uninstall.R: removing: ", paste(installed, collapse = ", "))
remove.packages(installed)
message("packages_uninstall.R: done. Re-run NSSK.R or `Rscript util/packages_install.R` to reinstall.")
