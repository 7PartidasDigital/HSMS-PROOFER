# ============================================================================
# HSMS PROOFER - REPRODUCIBLE WINDOWS x64 ELECTRON BUILD
# ============================================================================
# Purpose:
#   Build a Windows x64 installer from the HSMS Proofer R/Shiny source code.
#   The procedure includes the tested workaround for auxiliary download windows.
#
# How to use:
#   1. Install R, RStudio and shinyelectron (and its prerequisites) on Windows.
#   2. Keep this script in the HSMS-PROOFER source directory.
#   3. Ensure proofer_app.R, validator modules and www/hsms.png are present.
#   4. Open this script in RStudio on Windows and click Source.
#   5. Inspect the new installer in the printed dist/ directory.
#
# Important:
#   * The original HSMS-PROOFER source directory is never modified.
#   * Every run creates a separate, timestamped build directory.
#   * A fresh build requires access to npm/Electron dependencies.
#   * SHINYLIVE_WASM_PACKAGES=FALSE avoids a Bioconductor connectivity failure
#     observed on the build PC. This does NOT prove that a fresh installation
#     can run offline; test the installer on a clean, disconnected machine.
#   * This script does not sign the Windows installer.
#   * Do not distribute publicly until the npm audit/security findings are
#     reviewed and offline functionality is verified on a clean machine.
# ============================================================================

# ---- 1. Configuration -------------------------------------------------------

source_dir <- "C:/Users/7PartidasDigital/Desktop/HSMS-PROOFER"
builds_root <- "C:/Users/7PartidasDigital/Desktop/HSMS-PROOFER-Windows-Builds"
app_name <- "HSMS Proofer"

# ---- 2. Verify Windows environment and R package ---------------------------

if (.Platform$OS.type != "windows") {
  stop("This script must be run on Windows.", call. = FALSE)
}
if (!requireNamespace("shinyelectron", quietly = TRUE)) {
  stop("Install shinyelectron first: install.packages('shinyelectron')", call. = FALSE)
}
if (!requireNamespace("rappdirs", quietly = TRUE)) {
  stop("Install rappdirs first: install.packages('rappdirs')", call. = FALSE)
}

source_dir <- normalizePath(source_dir, winslash = "/", mustWork = TRUE)
required_files <- c(
  "proofer_app.R", "technical_fixers.R", "validator_core.R",
  "validator_structure.R", "validator_editorial.R", "validator_main.R",
  "www/hsms.png"
)
missing_files <- required_files[!file.exists(file.path(source_dir, required_files))]
if (length(missing_files)) {
  stop(
    "Required source file(s) missing: ", paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

# ---- 3. Prepare a completely new build folder ------------------------------

if (!dir.exists(builds_root)) {
  if (!dir.create(builds_root, recursive = TRUE)) {
    stop("Could not create builds root: ", builds_root, call. = FALSE)
  }
}

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
build_dir <- file.path(builds_root, paste0("HSMS-PROOFER-", stamp))
if (dir.exists(build_dir)) {
  stop("Build directory already exists: ", build_dir, call. = FALSE)
}
if (!dir.create(build_dir)) {
  stop("Could not create build directory: ", build_dir, call. = FALSE)
}

staging_dir <- file.path(build_dir, "source-for-shinylive")
dir.create(staging_dir)

# Copy the project's files and directories into an independent staging folder.
# Exclude Git metadata and any accidental build artifacts in the source tree.
source_entries <- list.files(
  source_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE
)
source_entries <- source_entries[!basename(source_entries) %in% c(
  ".git", ".Rproj.user", "node_modules", "dist",
  "HSMS-PROOFER-Electron-Windows", "HSMS-PROOFER-BUILD"
)]

copied <- file.copy(source_entries, staging_dir, recursive = TRUE,
                    overwrite = FALSE, copy.mode = TRUE)
if (!all(copied)) {
  stop("Some source files could not be copied to the staging folder.",
       call. = FALSE)
}

# Shinylive expects app.R. The original proofer_app.R is preserved unchanged.
if (!file.copy(
  from = file.path(staging_dir, "proofer_app.R"),
  to = file.path(staging_dir, "app.R"),
  overwrite = TRUE
)) {
  stop("Could not create app.R in the staging folder.", call. = FALSE)
}

cat("\nBuild directory: ", build_dir, "\n", sep = "")
cat("Source code copied; original project left unchanged.\n")

# ---- 4. Export to Shinylive and build the initial Electron project ---------

# This is the workaround that previously allowed export on Windows when the
# Bioconductor configuration server could not be reached.
old_wasm <- Sys.getenv("SHINYLIVE_WASM_PACKAGES", unset = NA_character_)
Sys.setenv(SHINYLIVE_WASM_PACKAGES = "FALSE")

# Restore the caller's environment setting, even if export fails.
restore_wasm <- function() {
  if (is.na(old_wasm)) {
    Sys.unsetenv("SHINYLIVE_WASM_PACKAGES")
  } else {
    Sys.setenv(SHINYLIVE_WASM_PACKAGES = old_wasm)
  }
}

export_dir <- file.path(build_dir, "export")
tryCatch(
  shinyelectron::export(
    appdir = staging_dir,
    destdir = export_dir,
    app_name = app_name,
    platform = "win",
    arch = "x64",
    run_after = FALSE
  ),
  finally = restore_wasm()
)

# ---- 5. Patch the automatically generated Electron main.js -----------------

# Electron/Shinylive may open an auxiliary window during a file download.
# On the tested Windows/macOS versions, this window stays open after saving.
# The workaround tracks child windows and closes them on download completion.
# Do not silently patch a different template: fail if anchors have changed.

electron_dir <- file.path(export_dir, "electron-app")
main_js <- file.path(electron_dir, "main.js")
if (!file.exists(main_js)) {
  stop("The generated main.js was not found: ", main_js, call. = FALSE)
}

js_lines <- readLines(main_js, warn = FALSE, encoding = "UTF-8")
if (any(grepl("HSMS PROOFER: DOWNLOAD WINDOW FIX", js_lines, fixed = TRUE))) {
  stop("main.js already contains the download fix; refusing double insertion.",
       call. = FALSE)
}

constructor <- grep("mainWindow\\s*=\\s*new\\s+BrowserWindow\\s*\\(",
                    js_lines, perl = TRUE)
if (length(constructor) != 1L) {
  stop("Unexpected BrowserWindow constructor: review generated main.js.",
       call. = FALSE)
}

# Find the exact close of the window options block, shortly after constructor.
search_end <- min(length(js_lines), constructor + 45L)
window_section <- seq.int(constructor, search_end)
show_false <- window_section[grepl("^\\s*show\\s*:\\s*false\\s*,?\\s*$",
                                   js_lines[window_section], perl = TRUE)]
if (length(show_false) != 1L) {
  stop("Could not locate the expected 'show: false' setting in main.js.",
       call. = FALSE)
}
if (show_false == length(js_lines) ||
    !grepl("^\\s*\\}\\);\\s*$", js_lines[show_false + 1L], perl = TRUE)) {
  stop("Unexpected closing lines after 'show: false' in main.js.",
       call. = FALSE)
}
insert_after <- show_false + 1L

fix_lines <- c(
  "",
  "  // ============================================================",
  "  // HSMS PROOFER: DOWNLOAD WINDOW FIX",
  "  // ============================================================",
  "  // Track auxiliary windows and close them after a successful",
  "  // download, preserving the main Electron window.",
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

backup_js <- file.path(electron_dir, "main.js.before-hsms-fix")
if (!file.copy(main_js, backup_js, overwrite = FALSE)) {
  stop("Could not back up the generated main.js.", call. = FALSE)
}

patched <- append(js_lines, values = fix_lines, after = insert_after)
writeLines(patched, main_js, useBytes = TRUE)
if (!any(grepl("HSMS PROOFER: DOWNLOAD WINDOW FIX",
               readLines(main_js, warn = FALSE), fixed = TRUE))) {
  stop("main.js could not be verified after patching.", call. = FALSE)
}
cat("Download-window fix added to main.js.\n")

# ---- 6. Locate npm installed locally by shinyelectron ----------------------

# Prefer npm already on PATH; otherwise search the shinyelectron cache.
npm_on_path <- Sys.which("npm.cmd")
if (!nzchar(npm_on_path)) {
  cache_dir <- rappdirs::user_cache_dir("shinyelectron")
  npm_candidates <- if (dir.exists(cache_dir)) {
    list.files(cache_dir, pattern = "^npm\\.cmd$", full.names = TRUE,
               recursive = TRUE, ignore.case = TRUE)
  } else {
    character(0)
  }
  # The local installation normally provides node.exe and npm.cmd together.
  npm_candidates <- npm_candidates[
    file.exists(file.path(dirname(npm_candidates), "node.exe"))
  ]
  if (!length(npm_candidates)) {
    stop(
      "npm.cmd could not be found. Run shinyelectron::install_nodejs() ",
      "and then rerun this build script.", call. = FALSE
    )
  }
  # Prefer the Node 26 installation already tested in this project.
  preferred <- grep("v26\\.13\\.1", npm_candidates, value = TRUE)
  npm_cmd <- if (length(preferred)) preferred[1L] else npm_candidates[1L]
  Sys.setenv(PATH = paste(dirname(npm_cmd), Sys.getenv("PATH"),
                          sep = .Platform$path.sep))
} else {
  npm_cmd <- npm_on_path
}

cat("Using npm: ", npm_cmd, "\n", sep = "")

# ---- 7. Rebuild the Windows installer with patched main.js -----------------

# The first export already built an installer; this second build is required
# because main.js was patched AFTER export generated the Electron project.
old_wd <- getwd()
setwd(electron_dir)

# Restore the user's working directory even if the command fails.
status <- tryCatch(
  system("npm run build-win-x64", intern = FALSE),
  finally = setwd(old_wd)
)

if (!identical(as.integer(status), 0L)) {
  stop("npm run build-win-x64 failed (exit code: ", status, ").",
       call. = FALSE)
}

dist_dir <- file.path(electron_dir, "dist")
installers <- list.files(dist_dir, pattern = "\\.exe$", full.names = TRUE,
                         ignore.case = TRUE)
if (!length(installers)) {
  stop("Build reported success, but no .exe was found in: ", dist_dir,
       call. = FALSE)
}

cat("\n============================================================\n")
cat("WINDOWS BUILD FINISHED SUCCESSFULLY\n")
cat("============================================================\n")
cat("Build folder: ", build_dir, "\n", sep = "")
cat("Installer(s):\n")
cat(paste0("  ", installers, collapse = "\n"), "\n", sep = "")
cat("\nNext: install on a TEST machine and check:\n")
cat("  - Correct transcription: 0 issues\n")
cat("  - TEXT.FALSA.txt: 260 issues (for the current test fixture)\n")
cat("  - TSV and TXT downloads; auxiliary window closes\n")
cat("  - Logo appears while offline\n")
cat("  - Fresh, offline Windows installation (no prior Shinylive cache)\n")
cat("Do not distribute publicly until security/signing are reviewed.\n")
