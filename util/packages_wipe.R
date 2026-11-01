# util/packages_wipe.R — removes every installed R package except "base" priority ones,
# to test package installs (packages_setup.R / util/packages_install.R / NSSK.R) against
# a genuinely clean local environment.
#
# This is a test/dev-support utility, not part of the NSSK.R analysis workflow.
#
# THIS MUTATES YOUR REAL R LIBRARY, MUCH MORE BROADLY THAN util/packages_uninstall.R.
# packages_uninstall.R only removes the 7 packages this project installs, leaving
# everything else (including their transitive dependencies) alone. This script removes
# EVERY non-base package on this R installation, regardless of what project installed it
# or depends on it -- if this R install is used for anything besides this repo, that other
# work's packages are gone too. If you want to test a clean install without touching your
# real environment at all, use tests/docker-packages-setup-test.sh instead, which does the
# same thing in a disposable container.
#
# "base" here means R's own "base" priority packages (base, utils, stats, methods, tools,
# ...) -- the ones remove.packages() itself refuses to remove and that a bare R install
# can't function without. It deliberately does NOT spare "recommended" packages (MASS,
# Matrix, boot, survival, ...) -- those also ship with a default R install, but you asked
# for "except for base" specifically, and remove.packages() gives them no special
# protection either (confirmed in packages_uninstall.R's own comments). A brand-new R
# install normally has these; this script's "clean" is stricter than that.
#
# Safety, in order:
#   1. Dry-run by default -- lists what would be removed and exits. Pass --wipe to
#      actually remove anything.
#   2. A CSV snapshot of every package about to be removed (name, version, library path,
#      priority) is written before any removal, so the prior state is recoverable --
#      *.csv is already gitignored project-wide, so this is never accidentally committed.
#   3. y/n confirmation before the actual removal (skip with -y, same convention as
#      packages_uninstall.R).
#
# Usage:
#   Rscript util/packages_wipe.R              # dry run: list what would be removed, do nothing
#   Rscript util/packages_wipe.R --wipe        # remove, with y/n confirmation and a snapshot first
#   Rscript util/packages_wipe.R --wipe -y     # remove, no confirmation prompt
#
# To restore afterwards: install.packages(read.csv("<the printed snapshot path>")$Package)
# (this reinstalls latest versions, not necessarily the exact ones removed -- CRAN mirrors
# generally don't retain old versions). For just this project's own dependencies, re-run
# NSSK.R or `Rscript util/packages_install.R` instead -- check_installed_packages() will
# reinstall its required_packages automatically.

args <- commandArgs(trailingOnly = TRUE)
do_wipe <- "--wipe" %in% args
skip_confirm <- "-y" %in% args

installed <- as.data.frame(installed.packages(), stringsAsFactors = FALSE)

# NA priority == a regular CRAN/contributed package (installed.packages()'s Priority
# column is NA for these, not "" or "contributed" -- explicit %in% below only matches the
# two real priority strings, so NA rows correctly fall through to "to remove").
to_remove <- installed[!(installed$Priority %in% c("base")), ]

if (nrow(to_remove) == 0) {
  message("packages_wipe.R: no non-base packages installed. Nothing to do.")
  quit(status = 0)
}

recommended_count <- sum(to_remove$Priority %in% "recommended", na.rm = TRUE)

cat("packages_wipe.R: ", nrow(to_remove), " non-base package(s) installed",
    if (recommended_count > 0) paste0(" (", recommended_count, " of them R-\"recommended\" -- MASS/Matrix/etc, also being removed)") else "",
    ":\n", sep = "")
cat(paste0("  ", to_remove$Package, " (", to_remove$Version, ")  [", to_remove$LibPath, "]"), sep = "\n")

if (!do_wipe) {
  cat("\nDry run -- nothing removed. Re-run with --wipe to actually remove these.\n")
  quit(status = 0)
}

snapshot_path <- file.path(
  "util",
  paste0("package-snapshot-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".csv")
)
write.csv(
  to_remove[, c("Package", "Version", "LibPath", "Priority")],
  snapshot_path,
  row.names = FALSE
)
cat("\nSnapshot of packages about to be removed written to:", snapshot_path, "\n")

if (!skip_confirm) {
  cat("\nThis will remove all", nrow(to_remove), "package(s) listed above from this R installation. Continue? [y/N] ")
  answer <- tryCatch(readLines(con = "stdin", n = 1), error = function(e) "")
  if (!tolower(trimws(answer)) %in% c("y", "yes")) {
    message("packages_wipe.R: aborted, nothing removed. Snapshot file left in place at ", snapshot_path, ".")
    quit(status = 0)
  }
}

# remove.packages(pkgs, lib) only touches one library path per call (defaults to
# .libPaths()[1] if lib is omitted) -- group by LibPath so every package is actually
# reached, not just whatever happens to be in the first library path.
for (lib_path in unique(to_remove$LibPath)) {
  pkgs_here <- to_remove$Package[to_remove$LibPath == lib_path]
  message("packages_wipe.R: removing from ", lib_path, ": ", paste(pkgs_here, collapse = ", "))
  remove.packages(pkgs_here, lib = lib_path)
}

message("packages_wipe.R: done. ", nrow(to_remove), " package(s) removed. Snapshot: ", snapshot_path)
message("packages_wipe.R: re-run NSSK.R or `Rscript util/packages_install.R` to reinstall this project's dependencies.")
