# ============================================================
# HSMS PROOFER — CONSTRUCCIÓN DEL INSTALADOR PARA macOS ARM64
# ============================================================
#
# ¿Cuándo se usa?
#   Después de modificar una regla de validación, la interfaz o cualquier
#   archivo fuente de HSMS-PROOFER y comprobar que funciona en RStudio.
#
# ¿Qué hace?
#   1. Convierte la aplicación Shiny a Shinylive y crea Electron.
#   2. Introduce en main.js la corrección de las ventanas auxiliares
#      que quedan abiertas después de descargar informes TSV/TXT.
#   3. Reconstruye SOLAMENTE Electron para incluir ese cambio en el .dmg.
#
# ¿Qué NO hace?
#   - No modifica los .R originales ni las reglas de validación.
#   - No requiere ejecutar npm audit fix --force.
#   - No borra versiones anteriores ni instala el .dmg en Aplicaciones.
#
# USO
#   1. Guardar ESTE archivo en ~/Desktop/HSMS-PROOFER/.
#   2. Abrirlo en RStudio y pulsar «Source» (o ejecutar todo el archivo).
#   3. Esperar a que finalice la segunda compilación.
#   4. Abrir el .dmg indicado al final y probar TSV y TXT.
#
# REQUISITOS
#   - macOS con Apple Silicon (ARM64).
#   - Paquete R shinyelectron instalado y Node.js local de shinyelectron.
#   - La carpeta de la aplicación contiene app.R y los validator_*.R.
#   - app.R conserva la corrección downloadButton() para Shinylive.
#
# IMPORTANTE
#   shinyelectron genera main.js en cada exportación: NO editarlo a mano.
#   Este script aplica la corrección automáticamente en cada compilación.
#   Si cambia el formato interno de main.js, DETENDRÁ el proceso para
#   evitar generar silenciosamente un instalador sin la corrección.
# ============================================================

# ---- CONFIGURACIÓN: modificar solo si se mueven las carpetas ----
app_dir <- path.expand("~/Desktop/HSMS-PROOFER")
builds_dir <- path.expand("~/Desktop/HSMS-PROOFER-Builds")

# Cada ejecución crea una carpeta nueva. Así se conservan los .dmg anteriores.
build_id <- format(Sys.time(), "%Y%m%d-%H%M%S")
dest_dir <- file.path(builds_dir, paste0("HSMS-PROOFER-", build_id))

# ---- COMPROBACIONES INICIALES ----
if (!requireNamespace("shinyelectron", quietly = TRUE)) {
  stop("Falta shinyelectron. Instálalo en R antes de compilar.")
}
if (!dir.exists(app_dir) || !file.exists(file.path(app_dir, "app.R"))) {
  stop("No encuentro app.R en: ", app_dir)
}
if (file.exists(dest_dir)) {
  stop("La carpeta de salida ya existe; no la sobrescribiré: ", dest_dir)
}
dir.create(builds_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 1. EXPORTACIÓN NORMAL DE SHINYLIVE Y ELECTRON ----
# run_after = FALSE evita abrir una aplicación de desarrollo al terminar.
# Nota: export() ya genera un primer .dmg, que reconstruiremos tras el parche.
message("[1/4] Exportando la aplicación a Electron...")
shinyelectron::export(
  appdir = app_dir,
  destdir = dest_dir,
  app_name = "HSMS Proofer",
  run_after = FALSE
)

# ---- 2. INCORPORAR LA CORRECCIÓN AL main.js GENERADO ----
main_path <- file.path(dest_dir, "electron-app", "main.js")
if (!file.exists(main_path)) {
  stop("La exportación no ha generado el archivo esperado: ", main_path)
}

main_lines <- readLines(main_path, warn = FALSE, encoding = "UTF-8")
anchor <- "  // Save window state on resize/move (debounced; these events fire rapidly)"
anchor_pos <- which(main_lines == anchor)

if (length(anchor_pos) != 1L) {
  stop(
    "No encuentro el punto exacto para insertar el control de descargas. ",
    "Es posible que shinyelectron haya cambiado su plantilla main.js. ",
    "No se reconstruirá el DMG: revisa el nuevo main.js."
  )
}

# Este bloque reproduce el comportamiento que se probó con éxito:
# registrar las ventanas auxiliares y cerrarlas al completar una descarga.
# No se bloquean las ventanas nuevas, porque ello podría impedir la descarga.
download_patch <- c(
  "  // HSMS PROOFER: cerrar ventanas auxiliares al finalizar una descarga.",
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

main_lines <- append(main_lines, download_patch, after = anchor_pos - 1L)
writeLines(main_lines, main_path, useBytes = TRUE)
message("[2/4] Corrección de descargas incorporada en main.js.")

# ---- 3. LOCALIZAR NODE Y NPM DE SHINYELECTRON ----
# shinyelectron instala Node.js en una carpeta privada; por eso macOS puede
# indicar «npm: command not found» al escribir npm en una Terminal normal.
node_cache <- path.expand("~/Library/Caches/shinyelectron/assets/nodejs")
node_versions <- list.dirs(node_cache, full.names = TRUE, recursive = FALSE)
node_versions <- node_versions[grepl("^v[0-9]", basename(node_versions))]

if (length(node_versions) == 0L) {
  stop("No encuentro Node.js local de shinyelectron en: ", node_cache)
}

# Escoger la versión instalada más reciente, no depender de v26.13.1.
version_values <- package_version(sub("^v", "", basename(node_versions)))
node_root <- node_versions[order(version_values, decreasing = TRUE)[1L]]
node_bin <- file.path(node_root, "darwin-arm64", "bin")
node_path <- file.path(node_bin, "node")
npm_path <- file.path(node_bin, "npm")

if (!file.exists(node_path) || !file.exists(npm_path)) {
  stop("No encuentro los ejecutables node y npm en: ", node_bin)
}

# Facilitar a npm el acceso a node durante esta sesión de R.
Sys.setenv(PATH = paste(node_bin, Sys.getenv("PATH"), sep = .Platform$path.sep))

# Comprobar que el main.js editado tiene sintaxis JavaScript válida.
message("[3/4] Comprobando la sintaxis de main.js...")
syntax_status <- system2(node_path, c("--check", shQuote(main_path)))
if (!identical(as.integer(syntax_status), 0L)) {
  stop("main.js contiene un error de sintaxis. No se reconstruirá el DMG.")
}

# ---- 4. RECONSTRUIR ELECTRON Y EL INSTALADOR DMG ----
# NO volver a llamar a export(): eso regeneraría main.js y perdería el parche.
electron_dir <- file.path(dest_dir, "electron-app")
old_wd <- getwd()
tryCatch({
  setwd(electron_dir)
  message("[4/4] Generando el DMG de macOS ARM64...")
  build_status <- system2(npm_path, c("run", "build-mac-arm64"))
  if (!identical(as.integer(build_status), 0L)) {
    stop("Falló npm run build-mac-arm64. Revisa los mensajes anteriores.")
  }
}, finally = {
  setwd(old_wd)
})

dist_dir <- file.path(electron_dir, "dist")
dmg_files <- list.files(dist_dir, pattern = "\\.dmg$", full.names = TRUE)
if (length(dmg_files) == 0L) {
  stop("La compilación terminó, pero no encuentro ningún .dmg en: ", dist_dir)
}

message("\n¡CONSTRUCCIÓN COMPLETADA!")
message("Instalador(es):\n", paste(dmg_files, collapse = "\n"))
message("Prueba de aceptación: instalar y comprobar validación, TSV y TXT.")
