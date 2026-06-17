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
source("proofer.R")
```

Then launch the Shiny app.

## Repository

Developed within the framework of the Hispanic Seminary of Medieval Studies.

https://www.hispanicseminary.org/

Corrected and annotated transcriptions are incorporated into the Old Spanish Textual Archive (OSTA):

https://oldspanishtextualarchive.org/

## License

MIT License
