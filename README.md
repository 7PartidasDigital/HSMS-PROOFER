# HSMS-PROOFER

Validation and proofing tool for HSMS manuscript transcriptions.

HSMS Proofer is a Shiny application for validating manuscript transcriptions prepared according to the conventions of the Hispanic Seminary of Medieval Studies (HSMS). It detects structural, editorial, and technical inconsistencies and produces human-readable and TSV reports, but it does not modify the text.

**Proofer points; the editor decides.**

## Authors

* José Manuel Fradejas Rueda (Universidad de Valladolid)
* Francisco Gago Jover (The College of the Holy Cross)

## Features

* Structural validation
* Editorial validation
* Technical validation
* UTF-8 checks
* Detection of Unicode combining diacritics
* TSV and TXT reports
* Bilingual interface (English/Spanish)
* Shiny application

## Running the application

Open RStudio and execute:

```r
source("proofer_app.R")
```

or just double click on `proofer_app.R` and it will open RStudio and load the code.

Then launch the Shiny app.

More details in the app [manual](https://hispanicseminary.org/manuales/proofer/index.html)

## Desktop application
### macOS desktop application

HSMS Proofer can be packaged as a standalone macOS application using Electron and Shinylive. The resulting application runs independently of R and RStudio.

The `build_hsms_proofer_macos.R` script automates the conversion, applies the necessary Electron download compatibility fix, and generates a distributable DMG installer.

For requirements and detailed build instructions, see [BUILDING_MACOS.md](BUILDING_MACOS.md).

### Windows

Windows support is planned.


## Repository

Developed within the framework of the Hispanic Seminary of Medieval Studies.

https://www.hispanicseminary.org/

Corrected and annotated transcriptions are incorporated into the Old Spanish Textual Archive (OSTA):

https://oldspanishtextualarchive.org/

## License

MIT License
