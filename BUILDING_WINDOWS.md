# Building HSMS Proofer for Windows

This document explains how to build the standalone **HSMS Proofer** desktop application for **Windows x64** from its R/Shiny source code. The build uses **Shinylive**, **Electron**, and the project's automated R build script, `build_hsms_proofer_windows.R`.

The resulting Windows application runs without requiring R or RStudio on the end user's computer. The build itself requires R and RStudio (or an equivalent R environment).

> **Status:** The automated build and installer have been tested on Windows 11 x64. The resulting application has also been exercised in a Windows 11 virtual machine under UTM on Apple Silicon. These tests do not constitute a guarantee of compatibility with every Windows configuration.

## 1. Requirements

Build on a **Windows 11 x64** computer with:

- A current installation of **R** and **RStudio**. The verified Windows build used **R 4.6.2**.
- The R packages required by the application: `shiny`, `DT`, and `bslib`.
- The R packages `shinylive`, `shinyelectron`, and their dependencies. The verified build used **shinylive 0.5.0**.
- **Node.js** and **npm**, available either system-wide or through `shinyelectron::install_nodejs()`. The verified environment used **Node.js 26.13.1** and **npm 11.20.0**.
- Internet access to fetch missing R/npm/Electron dependencies during a fresh build.

Install the main R packages if necessary:

```r
install.packages(c("shiny", "DT", "bslib", "shinylive", "shinyelectron"))
```

If the diagnostic reports missing Node.js or npm, install the local runtime:

```r
shinyelectron::install_nodejs()
```

To inspect the environment:

```r
shinyelectron::sitrep_shinyelectron()
```

**Notes:** Python Shiny, Docker/Podman, and `ggplot2` are not required for the current R/Shinylive application. The absence of Visual Studio Build Tools did not prevent the tested Windows x64 build, although other setups or dependency versions may require additional tools. A diagnostic launched in the R source directory may warn that `package.json` or `main.js` is missing; this is expected because those files are generated in the Electron build directory.

## 2. Source layout

Keep the build script in the same source directory as the application. The expected layout is:

```text
HSMS-PROOFER/
├── proofer_app.R
├── technical_fixers.R
├── validator_core.R
├── validator_structure.R
├── validator_editorial.R
├── validator_main.R
├── build_hsms_proofer_windows.R
└── www/
    └── hsms.png
```

Other project files may also be present. The HSMS logo is stored locally in `www/hsms.png`, rather than being loaded from the web, so it is available offline.

**Do not rename `proofer_app.R` in the source tree.** The script copies the project to a separate staging directory and creates `app.R` there for Shinylive.

## 3. Configure the source and build directories

By default, `build_hsms_proofer_windows.R` expects the source files on the Windows desktop:

```r
source_dir <- "C:/Users/7PartidasDigital/Desktop/HSMS-PROOFER"
builds_root <- "C:/Users/7PartidasDigital/Desktop/HSMS-PROOFER-Windows-Builds"
```

**Adjust these two paths in the script if the username or folder location differs.** For the documented workflow, copy the project from OneDrive to the desktop before building. Avoid building directly inside a OneDrive-synchronized directory: Electron creates thousands of intermediate files.

The build script never edits the original source directory and creates a new timestamped build folder on each run.

## 4. Build the Windows installer

1. Open RStudio on the Windows build computer.
2. Open `build_hsms_proofer_windows.R` from the source directory.
3. Click **Source**, or execute the complete script in the R console.
4. Inspect the console output. A successful run ends with:

```text
WINDOWS BUILD FINISHED SUCCESSFULLY
```

The script automatically:

1. Validates the operating system, required packages, and source files.
2. Creates a separate, timestamped build directory and copies the source files into it.
3. Creates `app.R` from `proofer_app.R` in the staging copy.
4. Exports the application to Shinylive and generates the initial Electron project.
5. Modifies the generated `main.js` to fix the auxiliary windows created by report downloads.
6. Rebuilds Electron for **Windows x64** with `npm run build-win-x64`.
7. Checks that a Windows `.exe` installer exists and prints its location.

**Do not run `shinyelectron::export()` again on that generated project after the fix has been applied:** it may regenerate `main.js` and remove the workaround. For future releases, run the complete R build script from the original source.

## 5. Where to find the installer

The default output folder is:

```text
C:/Users/7PartidasDigital/Desktop/HSMS-PROOFER-Windows-Builds/
    HSMS-PROOFER-YYYYMMDD-HHMMSS/
        export/
            electron-app/
                dist/
                    hsms-proofer Setup 1.0.0.exe
```

The filename above reflects the tested Electron package version, **not necessarily the version declared in `proofer_app.R`**. Use the exact installer path printed at the end of each build; older directories may contain installers with the same filename.

Once the installer has been tested, archive the `.exe` separately (for example in OneDrive under `HSMS_PROOFER/INSTALADORES/WINDOWS`). The intermediate `node_modules`, Electron project, staging files, and other build outputs can be deleted when no longer needed. Preserve the source code, the build script, and at least one known-good installer.

## 6. Why the script modifies `main.js`

In the tested Shinylive/Electron configuration, clicking a TSV or TXT download button can open an additional Electron window. The native Save dialog closes after saving, but the auxiliary window may remain open.

The application UI includes a Shinylive-specific adjustment to `downloadButton()`. The build script then inserts a separate Electron workaround into the generated `main.js`:

- Track newly created auxiliary windows.
- Listen for completed downloads.
- Close those auxiliary windows after successful downloads, without closing the main application.

This behavior was tested on macOS and Windows. The build script checks the expected structure of `main.js` and stops if it cannot apply the modification safely. It also saves a backup named `main.js.before-hsms-fix` within the generated Electron project.

**The Electron fix is a project-specific workaround, not a modification of the HSMS validation rules.** If a future `shinyelectron` release changes its Electron template, review the workaround rather than applying it blindly.

## 7. Bioconductor connectivity workaround

During the tested Windows build, Shinylive's WebAssembly package-bundling step failed because the build machine could not access `bioconductor.org/config.yaml`.

The build script therefore temporarily sets:

```r
Sys.setenv(SHINYLIVE_WASM_PACKAGES = "FALSE")
```

It restores the previous environment-variable value after the initial export. This avoids the failing bundling step, **but does not, by itself, guarantee a fully offline installer**. Dependencies may be obtained at runtime or from an existing cache.

The resulting Windows application was observed to validate files and download reports while offline on the test PC. Nevertheless, a **clean first launch on a Windows machine with no prior Shinylive/WebAssembly cache, while disconnected from the network**, remains an important test before public release. Do not describe the installer as universally offline-capable solely because an already-used installation works without Wi-Fi.

## 8. Acceptance tests

Install the newly generated `.exe` on Windows and verify the following:

| Test | Expected result |
| --- | --- |
| Launch the installed application | HSMS Proofer starts without RStudio |
| Validate `TEXT.REM.txt` | No reported issues |
| Validate `TEXT.FALSA.txt` | 260 reported issues for the current reference fixture |
| Download a TSV report | The file is saved and its contents are correct |
| Download a TXT report | The file is saved and its contents are correct |
| Close the Save dialog | No auxiliary Electron window remains open |
| Launch without an Internet connection | The application loads and validates as expected |
| Display the HSMS logo offline | The local logo is visible |

Test on a second Windows installation when possible. A clean, offline first-run test is particularly valuable due to the WebAssembly bundling workaround described above.

## 9. Troubleshooting

**`Node.js is required but not found` / `npm: command not found`**  
Run `shinyelectron::sitrep_shinyelectron()` and, if needed, `shinyelectron::install_nodejs()`. The build script locates a local `npm.cmd` when npm is not already on `PATH`.

**Cannot reach `bioconductor.org/config.yaml`**  
Confirm that you are running the project's Windows build script, which sets `SHINYLIVE_WASM_PACKAGES=FALSE` for the export. Do not disable antivirus, TLS verification, or firewall protections merely to bypass the connection error.

**`main.js` could not be patched**  
The generated template may have changed. Inspect the new `main.js` and update the patch logic carefully; do not distribute an installer until downloads have been retested.

**Downloads leave an empty window open**  
Make sure you installed the `.exe` from the **latest timestamped build directory**. Older installers may have the same `Setup 1.0.0.exe` filename.

**The HSMS logo is missing offline**  
Ensure that `www/hsms.png` is present in the source directory and that `proofer_app.R` refers to `hsms.png` rather than a remote image URL. Rebuild and reinstall the application.

**npm prints security warnings**  
Do **not** run `npm audit fix --force` without reviewing its proposed dependency changes; it may introduce incompatible upgrades.

## 10. Distribution and maintenance

- Keep the R source code, build scripts, and documentation in the GitHub repository.
- Do not commit generated `node_modules`, Electron build directories, or temporary staging files.
- Save tested installers separately; use **GitHub Releases** for public binary distribution when ready.
- The current installer is **unsigned**. Review dependency security findings and Windows code-signing/SmartScreen behavior before public distribution.
- Keep the application's R version (`APP_VERSION`) and the Electron installer version consistent in a future release.
- After changing any validation rule, rerun the R tests, execute the Windows build script, and repeat the acceptance tests above.

The project can also be built for macOS using `build_hsms_proofer_macos.R`; see [BUILDING_MACOS.md](BUILDING_MACOS.md).
