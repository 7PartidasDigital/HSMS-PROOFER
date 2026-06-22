# =========================================================
# HSMS Proofer
# ---------------------------------------------------------
# Shiny application for the validation and proofing of
# manuscript transcriptions prepared according to the
# conventions of the Hispanic Seminary of Medieval Studies.
#
# The application performs structural, editorial and
# technical checks and produces TSV and human-readable
# diagnostic reports.
#
# Developed within the framework of the
# Hispanic Seminary of Medieval Studies (HSMS).
#
# Authors:
#
# José Manuel Fradejas Rueda
# Universidad de Valladolid
#
# Francisco Gago Jover
# The College of the Holy Cross
#
# Historical background:
#
# The present application is the successor of the
# original HSMS Proofer developed for the generation,
# proofing and correction of machine-readable
# transcriptions.
#
# References:
#
# Nitti, John J. (1978).
# "The Computer Processing of Medieval Texts".
# Computers and the Humanities, 12, 3-9.
#
# Repository:
#
# https://github.com/7PartidasDigital/HSMS-PROOFER
#
# License:
#
# MIT License
#
# Motto:
#
# Proofer points; the editor decides.
# Proofer señala; el editor decide.
#
# =========================================================


library(shiny)
library(DT)

source("technical_fixers.R", encoding = "UTF-8")
source("validator_core.R", encoding = "UTF-8")
source("validator_structure.R", encoding = "UTF-8")
source("validator_editorial.R", encoding = "UTF-8")
source("validator_main.R", encoding = "UTF-8")

APP_VERSION <- "0.1.0"

make_caret <- function(col) {
  if (is.na(col)) return("")
  paste0(strrep(" ", max(0, col - 1)), "^")
}

format_issue_text <- function(issue_row) {
  
  line_info <- paste0("Line ", issue_row$line)
  
  if (!is.na(issue_row$col)) {
    line_info <- paste0(line_info, ", col ", issue_row$col)
  }
  
  line_info <- paste0(line_info, " [", issue_row$type, "]")
  
  paste(
    line_info,
    "",
    issue_row$text,
    make_caret(issue_row$col),
    "",
    issue_row$explanation,
    sep = "\n"
  )
}

ui <- navbarPage(
  
  title = "HSMS Proofer",
  
  tabPanel(
    
    "Validation",
    
    sidebarLayout(
      
      sidebarPanel(
        
        fileInput(
          inputId = "file",
          label = "Select transcription file",
          accept = c(".txt", "text/plain")
        ),
        
        br(),
        
        downloadButton(
          outputId = "download_tsv",
          label = "Download TSV report"
        ),
        
        br(),
        br(),
        
        downloadButton(
          outputId = "download_txt",
          label = "Download TXT report"
        )
      ),
      
      mainPanel(
        
        h3("Validation results"),
        
        uiOutput("summary"),
        
        br(),
        
        uiOutput("issues_ui")
      )
    )
  ),
  
  tabPanel(
    
    "About",
    
    fluidPage(
      
      br(),
      
      tags$a(
        href = "https://www.hispanicseminary.org/",
        target = "_blank",
        tags$img(
          src = "https://oldspanishtextualarchive.org/css/hsms.png",
          height = "120px"
        )
      ),
      
      br(),
      br(),
      
      h2("HSMS Proofer"),
      
      p(paste("Version", APP_VERSION)),
      
      p(
        "HSMS Proofer is a validation tool for transcriptions prepared according to the conventions of the Hispanic Seminary of Medieval Studies (HSMS). It automatically detects structural, typographic, and encoding problems, but it does not modify the text. Editorial responsibility remains with the scholar."
      ),
      
      h3("Authors"),
      
      p(
        HTML(
          "José Manuel Fradejas Rueda<br>
           Universidad de Valladolid<br><br>
           Francisco Gago Jover<br>
           The College of the Holy Cross"
        )
      ),
      
      h3("The Hispanic Seminary of Medieval Studies"),
      
      p(
        "Corrected and linguistically annotated transcriptions produced with HSMS Proofer are ultimately incorporated into the Old Spanish Textual Archive (OSTA)."
      ),
      
      tags$a(
        href = "https://oldspanishtextualarchive.org/",
        target = "_blank",
        "https://oldspanishtextualarchive.org/"
      ),
      
      h3("Historical Background"),
      
      p(
        "The name Proofer recalls the procedures for the generation, proofing, and correction of machine-readable transcriptions described by John J. Nitti (1978)."
      ),
      
      tags$blockquote(
        HTML(
          "\"...the generation, proofing, and correction of machine-readable transcriptions...\"<br>
           — John J. Nitti (1978)"
        )
      ),
      
      h3("Reference"),
      
      p(
        HTML(
          "Nitti, John J. (1978). <i>Computers and the Old Spanish Dictionary</i>. <i>Computers and the Humanities</i> 12: 43–52."
        )
      ),
      
      h3("Manual"),
      
      tags$a(
        href = "http://www.hispanicseminary.org/docs/HSMS-manual.pdf",
        target = "_blank",
        "HSMS Manual of Manuscript Transcription"
      ),
      
      h3("Repository"),
      
      p("GitHub repository"),
      p("Zenodo archive: DOI to be assigned"),
      
      h3("License"),
      
      p("MIT License"),
      
      h3("Disclaimer"),
      
      p(
        "HSMS Proofer is distributed \"as is\", without warranty of any kind. Users remain solely responsible for the preparation, revision, and publication of their texts."
      ),
      
      h3("Acknowledgements"),
      
      p(
        "The program was developed within the framework of the Hispanic Seminary of Medieval Studies and continues nearly fifty years of computational work devoted to the generation, proofing, and analysis of machine-readable transcriptions."
      ),
      
      br(),
      
      tags$hr(),
      
      tags$blockquote(
        
        style = "font-size: 1.1em;",
        
        tags$em(
          "From machine-readable transcriptions to digital textual archives."
        ),
        
        br(),
        br(),
        
        tags$strong(
          "Proofer points; the editor decides."
        ),
        
        br(),
        
        tags$strong(
          "Proofer señala; el editor decide."
        )
        
      )
    )
  )
)

server <- function(input, output, session) {
  
  validation_result <- reactive({
    
    req(input$file)
    
    withProgress(
      
      message = "Validating file / Validando fichero",
      detail = "Please wait. Large files may take several minutes. / Espere, por favor. Los ficheros grandes pueden tardar varios minutos.",
      value = 0,
      
      {
        incProgress(
          0.2,
          detail = "Reading and checking file / Leyendo y comprobando el fichero"
        )
        
        result <- validate_file(
          filepath = input$file$datapath,
          uploaded_name = input$file$name
        )
        
        incProgress(
          0.8,
          detail = "Preparing report / Preparando el informe"
        )
        
        result
      }
    )
  })
  
  issues_df <- reactive({
    
    result <- validation_result()
    
    df <- result$df
    
    if (is.null(df) || nrow(df) == 0) {
      return(data.frame(
        line = integer(0),
        col = integer(0),
        type = character(0),
        text = character(0),
        explanation = character(0),
        stringsAsFactors = FALSE
      ))
    }
    
    df
  })
  
  output$summary <- renderUI({
    
    if (is.null(input$file)) {
      return(
        tags$p(
          HTML(
            "Select a TXT file to start validation.<br/>
           Seleccione un fichero TXT para iniciar la validación."
          )
        )
      )
    }
    
    df <- issues_df()
    
    if (nrow(df) == 0) {
      
      tags$div(
        
        h4(
          style = "color: #228B22;",
          HTML(
            "&#10004; No issues detected.<br/>
           No se han detectado incidencias."
          )
        ),
        
        p(
          HTML(
            paste0(
              "<strong>",
              input$file$name,
              "</strong><br/>",
              "Successfully validated.<br/>",
              "Validación completada correctamente."
            )
          )
        )
      )
      
    } else {
      
      tags$div(
        
        h4(
          style = "color: #B22222;",
          HTML(
            paste0(
              "&#9888; ",
              nrow(df),
              " issue(s) detected.<br/>",
              nrow(df),
              " incidencia(s) detectada(s)."
            )
          )
        ),
        
        p(
          HTML(
            paste0(
              "<strong>",
              input$file$name,
              "</strong><br/>",
              "Validation completed with issues.<br/>",
              "Validación completada con incidencias."
            )
          )
        )
      )
    }
  })

  
  output$issues_ui <- renderUI({
    
    df <- issues_df()
    
    if (nrow(df) == 0) {
      
      return(NULL)
      
    }
    
    tagList(
      
      DTOutput("issues_table"),
      
      br(),
      
      h4("Diagnostic preview"),
      
      verbatimTextOutput("diagnostic_preview")
      
    )
    
  })
  
output$issues_table <- renderDT({
    
    df <- issues_df()
    
    datatable(
      df,
      rownames = FALSE,
      selection = "single",
      options = list(
        pageLength = 25,
        scrollX = TRUE
      )
    )
  })
  
  output$diagnostic_preview <- renderText({
    
    df <- issues_df()
    
    if (nrow(df) == 0) {
      return("No diagnostic information to display.")
    }
    
    selected <- input$issues_table_rows_selected
    
    if (length(selected) == 0) {
      selected <- 1
    }
    
    format_issue_text(df[selected, , drop = FALSE])
  })
  
  output$download_tsv <- downloadHandler(
    
    filename = function() {
      paste0(
        tools::file_path_sans_ext(input$file$name),
        "_proofer_report.tsv"
      )
    },
    
    content = function(file) {
      write.table(
        issues_df(),
        file = file,
        sep = "\t",
        quote = TRUE,
        row.names = FALSE,
        fileEncoding = "UTF-8"
      )
    }
  )
  
  output$download_txt <- downloadHandler(
    
    filename = function() {
      paste0(
        tools::file_path_sans_ext(input$file$name),
        "_proofer_report.txt"
      )
    },
    
    content = function(file) {
      
      df <- issues_df()
      
      if (nrow(df) == 0) {
        report <- paste(
          "HSMS Proofer report",
          "",
          paste0("File: ", input$file$name),
          "",
          "No issues detected.",
          sep = "\n"
        )
      } else {
        diagnostics <- vapply(
          seq_len(nrow(df)),
          function(i) format_issue_text(df[i, , drop = FALSE]),
          character(1)
        )
        
        report <- paste(
          "HSMS Proofer report",
          "",
          paste0("File: ", input$file$name),
          paste0("Issues: ", nrow(df)),
          "",
          paste(diagnostics, collapse = "\n\n"),
          sep = "\n"
        )
      }
      
      writeLines(
        report,
        con = file,
        useBytes = TRUE
      )
    }
  )
}

shinyApp(ui = ui, server = server)
