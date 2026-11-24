# ============================================================
# HSMS PROOFER — BUILD macOS ARM64 INSTALLER
# ============================================================
# Usage:
#   1. Put this file in ~/Desktop/HSMS-PROOFER/.
#   2. Ensure proofer_app.R and www/hsms.png are present.
#   3. Open this file in RStudio and click Source.
#   4. Install and test the resulting DMG before distribution.
#
# The script NEVER modifies the source R files. It creates a
# separate, timestamped build folder, copies the required files,
# renames proofer_app.R to app.R in that copy only, exports the
# Shiny application, patches Electron's download window handling,
# checks main.js syntax and rebuilds the macOS ARM64 installer.
#
# IMPORTANT: This build procedure has not yet been end-to-end
# tested with this revised script. Test the resulting installer.
# ============================================================

# ---- 1. PATHS -------------------------------------------------
source_dir <- path.expand("~/Desktop/HSMS-PROOFER")
builds_dir <- path.expand("~/Desktop/HSMS-PROOFER-Builds")
build_id <- format(Sys.time(), "%Y%m%d-%H%M%S")
build_dir <- file.path(builds_dir, paste0("HSMS-PROOFER-", build_id))
work_dir <- file.path(build_dir, "work")
export_dir <- file.path(build_dir, "export")

# ---- 2. INPUT VALIDATION --------------------------------------
if (.Platform$OS.type != "unix" || Sys.info()[["sysname"]] != "Darwin") {
  stop("This script must be run on macOS.")
}
if (Sys.info()[["machine"]] != "arm64") {
  stop("This script targets Apple Silicon (arm64).")
}
if (!requireNamespace("shinyelectron", quietly = TRUE)) {
  stop("R package 'shinyelectron' is not installed.")
}

required_r <- c(
  "proofer_app.R", "technical_fixers.R", "validator_core.R",
  "validator_structure.R", "validator_editorial.R", "validator_main.R"
)
required_files <- c(file.path(source_dir, required_r),
                    file.path(source_dir, "www", "hsms.png"))
missing <- required_files[!file.exists(required_files)]
if (length(missing)) {
  stop("Missing source file(s):\n", paste(missing, collapse = "\n"))
}
if (dir.exists(build_dir)) {
  stop("Build directory already exists: ", build_dir)
}

# ---- 3. CREATE AN ISOLATED SHINY APP COPY ---------------------
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(work_dir))

# Copy only runtime files, not old builds, documentation, or installers.
for (name in required_r) {
  if (!file.copy(file.path(source_dir, name), file.path(work_dir, name))) {
    stop("Failed to copy source file: ", name)
  }
}
dir.create(file.path(work_dir, "www"))
if (!file.copy(file.path(source_dir, "www", "hsms.png"),
               file.path(work_dir, "www", "hsms.png"))) {
  stop("Failed to copy www/hsms.png")
}

# Shiny's standard entry point; the original remains untouched.
if (!file.copy(file.path(work_dir, "proofer_app.R"),
               file.path(work_dir, "app.R"), overwrite = FALSE)) {
  stop("Failed to create work/app.R")
}
message("[1/5] Isolated application copy created: ", work_dir)

# ---- 4. EXPORT SHINYLIVE + INITIAL ELECTRON BUILD ------------
# Shinylive export can require internet access for WebAssembly
# packages. Do not disable package bundling here by default.
# run_after = FALSE prevents starting a development-mode instance.
message("[2/5] Exporting app to Shinylive and Electron...")
shinyelectron::export(
  appdir = work_dir,
  destdir = export_dir,
  app_name = "HSMS Proofer",
  platform = "mac",
  arch = "arm64",
  run_after = FALSE
)

# ---- 5. PATCH THE GENERATED ELECTRON MAIN.JS -----------------
main_path <- file.path(export_dir, "electron-app", "main.js")
if (!file.exists(main_path)) stop("main.js was not generated: ", main_path)
main_lines <- readLines(main_path, warn = FALSE, encoding = "UTF-8")

# Exact anchor from the shinyelectron version used in our tested
# manual build. Stop safely if a future template changes.
anchor <- "  // Save window state on resize/move (debounced; these events fire rapidly)"
anchor_pos <- which(main_lines == anchor)
if (length(anchor_pos) != 1L) {
  stop("main.js template has changed; download patch was NOT applied. ",
       "Please inspect the generated Electron project before rebuilding.")
}
if (any(grepl("HSMS PROOFER: DOWNLOAD WINDOW FIX", main_lines, fixed = TRUE))) {
  stop("main.js already contains the download patch. Aborting to avoid duplicates.")
}

# This is the same auxiliary-window workaround tested on macOS
# and Windows: track child windows and close them after a
# successful file download, leaving the main window untouched.
patch <- c(
  "  // HSMS PROOFER: DOWNLOAD WINDOW FIX",
  "  const downloadWindows = new Set();",
  "",
  "  mainWindow.webContents.on('did-create-window', (childWindow) => {",
  "    downloadWindows.add(childWindow);",
  "    childWindow.on('closed', () => {",
  "      downloadWindows.delete(childWindow);",
  "    });",
  "  });",
  "",
  "  mainWindow.webContents.session.on('will-download', (event, item) => {",
  "    item.once('done', (event, state) => {",
  "      if (state === 'completed') {",
  "        for (const childWindow of downloadWindows) {",
  "          if (!childWindow.isDestroyed()) {",
  "            childWindow.close();",
  "          }",
  "        }",
  "      }",
  "    });",
  "  });",
  ""
)
main_lines <- append(main_lines, patch, after = anchor_pos - 1L)
writeLines(main_lines, main_path, useBytes = TRUE)
message("[3/5] Download-window patch added to main.js")

# ---- 6. FIND SHINYELECTRON'S LOCAL NODE.JS / NPM -------------
node_cache <- path.expand("~/Library/Caches/shinyelectron/assets/nodejs")
if (!dir.exists(node_cache)) stop("Node.js cache directory is missing: ", node_cache)
node_versions <- list.dirs(node_cache, full.names = TRUE, recursive = FALSE)
node_versions <- node_versions[grepl("^v[0-9]", basename(node_versions))]
if (!length(node_versions)) stop("No local Node.js versions found")
version_values <- package_version(sub("^v", "", basename(node_versions)))
node_root <- node_versions[order(version_values, decreasing = TRUE)[1L]]
node_bin <- file.path(node_root, "darwin-arm64", "bin")
node_path <- file.path(node_bin, "node")
npm_path <- file.path(node_bin, "npm")
if (!file.exists(node_path) || !file.exists(npm_path)) {
  stop("node/npm not found in: ", node_bin)
}
Sys.setenv(PATH = paste(node_bin, Sys.getenv("PATH"), sep = .Platform$path.sep))

# Check JavaScript syntax before spending time building again.
message("[4/5] Checking JavaScript syntax...")
syntax_status <- system2(node_path, c("--check", shQuote(main_path)))
if (!identical(as.integer(syntax_status), 0L)) {
  stop("main.js has a syntax error; installer will not be rebuilt")
}

# ---- 7. REBUILD ONLY ELECTRON / DMG ---------------------------
electron_dir <- file.path(export_dir, "electron-app")
if (!file.exists(file.path(electron_dir, "package.json"))) {
  stop("Electron package.json was not generated")
}
old_wd <- getwd()
build_status <- tryCatch({
  setwd(electron_dir)
  message("[5/5] Rebuilding macOS ARM64 DMG...")
  system2(npm_path, c("run", "build-mac-arm64"))
}, finally = {
  setwd(old_wd)
})
if (!identical(as.integer(build_status), 0L)) {
  stop("npm run build-mac-arm64 failed; check preceding output")
}

dist_dir <- file.path(electron_dir, "dist")
dmg_files <- list.files(dist_dir, pattern = "\\.dmg$", full.names = TRUE,
                        ignore.case = TRUE)
if (!length(dmg_files)) stop("Build finished but no DMG was found: ", dist_dir)

cat("\n============================================================\n")
cat("MACOS BUILD FINISHED SUCCESSFULLY\n")
cat("============================================================\n")
cat("Build folder: ", build_dir, "\n", sep = "")
cat("Installer(s):\n", paste0("  ", dmg_files, collapse = "\n"), "\n", sep = "")
cat("Next: install and test TEXT.REM.txt, TEXT.FALSA.txt, TSV/TXT downloads,\n")
cat("auxiliary-window closure and the local logo while offline.\n")
cat("Keep the last known-good DMG until these tests pass.\n")
cat("Review security advisories and signing before public distribution.\n")
