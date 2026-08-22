library(shiny)
library(bslib)
library(dplyr)
library(DT)
library(openxlsx)
library(RSQLite)
library(DBI)

# ==========================================
# 1. DATABASE & PERSISTENCE INITIALIZATION
# ==========================================
app_data_dir <- file.path(
  Sys.getenv("LOCALAPPDATA"),
  "LiboInventory"
)

if (!dir.exists(app_data_dir)) {
  dir.create(
    app_data_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

db_path <- file.path(
  app_data_dir,
  "libo_inventory.sqlite"
)

init_db <- function() {
  conn <- dbConnect(SQLite(), db_path)
  
  dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS live_scans (
      accession_no TEXT PRIMARY KEY,
      scan_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS master_catalog (
      accession_no TEXT PRIMARY KEY,
      title TEXT,
      author TEXT,
      class_no TEXT
    )
  ")
  
  dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS exceptions_log (
      accession_no TEXT PRIMARY KEY,
      status TEXT,
      notes TEXT
    )
  ")
  
  dbDisconnect(conn)
}

init_db()

# Sample Data Generators
get_sample_master <- function() {
  data.frame(
    `Accession No` = paste0("ACC", 1001:1050),
    Title = c(
      "To Kill a Mockingbird", "1984", "The Great Gatsby", "Pride and Prejudice", "The Catcher in the Rye",
      "The Hobbit", "Fahrenheit 451", "Jane Eyre", "Animal Farm", "Brave New World",
      "The Grapes of Wrath", "One Hundred Years of Solitude", "Crime and Punishment", "The Brothers Karamazov", "Wuthering Heights",
      "Great Expectations", "Moby-Dick", "War and Peace", "The Odyssey", "The Divine Comedy",
      "Madame Bovary", "The Sound and the Fury", "Catch-22", "Lolita", "In Search of Lost Time",
      "Ulysses", "The Lord of the Rings", "The Chronicles of Narnia", "Frankenstein", "Dracula",
      "The Picture of Dorian Gray", "Les Misérables", "The Count of Monte Cristo", "Anna Karenina", "Don Quixote",
      "The Metamorphosis", "Heart of Darkness", "The Stranger", "Beloved", "Invisible Man",
      "To the Lighthouse", "Mrs Dalloway", "Slaughterhouse-Five", "The Sun Also Rises", "A Farewell to Arms",
      "For Whom the Bell Tolls", "The Old Man and the Sea", "Of Mice and Men", "East of Eden", "A Tale of Two Cities"
    ),
    Author = c(
      "Harper Lee", "George Orwell", "F. Scott Fitzgerald", "Jane Austen", "J.D. Salinger",
      "J.R.R. Tolkien", "Ray Bradbury", "Charlotte Brontë", "George Orwell", "Aldous Huxley",
      "John Steinbeck", "Gabriel García Márquez", "Fyodor Dostoevsky", "Fyodor Dostoevsky", "Emily Brontë",
      "Charles Dickens", "Herman Melville", "Leo Tolstoy", "Homer", "Dante Alighieri",
      "Gustave Flaubert", "William Faulkner", "Joseph Heller", "Vladimir Nabokov", "Marcel Proust",
      "James Joyce", "J.R.R. Tolkien", "C.S. Lewis", "Mary Shelley", "Bram Stoker",
      "Oscar Wilde", "Victor Hugo", "Alexandre Dumas", "Leo Tolstoy", "Miguel de Cervantes",
      "Franz Kafka", "Joseph Conrad", "Albert Camus", "Toni Morrison", "Ralph Ellison",
      "Virginia Woolf", "Virginia Woolf", "Kurt Vonnegut", "Ernest Hemingway", "Ernest Hemingway",
      "Ernest Hemingway", "Ernest Hemingway", "John Steinbeck", "John Steinbeck", "Charles Dickens"
    ),
    `Class No` = sprintf("%03d.12", round(seq(100, 950, length.out = 50), 1)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

get_sample_scanned <- function() {
  accs <- c(paste0("ACC", 1001:1029), paste0("ACC", 1045:1050))
  data.frame(
    `Accession No` = accs,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

get_sample_exceptions <- function() {
  data.frame(
    `Accession No` = paste0("ACC", 1030:1039),
    Status = c("Checked Out", "Checked Out", "Checked Out", "Damage", "Binding", 
               "Old Missing", "Old Missing", "Binding", "Checked Out", "Damage"),
    Notes = c("Due 2026-09-15", "Due 2026-09-20", "Due 2026-10-01", "Cover torn", 
              "Sent to bindery", "Missing in 2024 audit", "Missing in 2025 audit", 
              "At bindery", "Faculty loan", "Water damaged"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

# Enter key listener script for scanner
scan_js <- tags$script(HTML("
  $(document).on('keypress', '#barcode_input', function(e) {
    if (e.which == 13) {
      e.preventDefault();
      $('#add_scan_btn').click();
    }
  });
"))

# ==========================================
# 2. USER INTERFACE (UI)
# ==========================================
ui <- page_navbar(
  title = "Libo Inventory",
  theme = bs_theme(bootswatch = "flatly", primary = "#2c3e50"),
  footer = div(
    style = paste(
      "width: 100%;",
      "text-align: center;",
      "padding: 12px 16px;",
      "font-size: 13px;",
      "color: #6c757d;",
      "border-top: 1px solid #dee2e6;",
      "background: #f8f9fa;"
    ),
    "designed by Ashkar Kairali, Assitant Librarian, Indian Institute Science Education and Research Thiruvananthapuram"
  ),
  header = scan_js,
  
  # --- TAB 1: FILE UPLOAD & PREPARATION ---
  tabPanel(
    "Data Input & Upload",
    layout_sidebar(
      sidebar = sidebar(
        width = 340,
        h5("Upload Custom Data"),
        fileInput("file_master", "1. Master Catalog (.csv/.xlsx)", accept = c(".csv", ".xlsx")),
        uiOutput("master_upload_hint"),
        fileInput("file_scanned", "2. Scanned Physical Books (.csv/.xlsx)", accept = c(".csv", ".xlsx")),
        fileInput("file_exceptions", "3. Exceptions / Loans (.csv/.xlsx)", accept = c(".csv", ".xlsx")),
        hr(),
        actionButton("clear_db_btn", "Reset All Database Records", class = "btn-outline-danger w-100 mb-2"),
        actionButton("process_btn", "Run Verification Audit", class = "btn-primary w-100 btn-lg")
      ),
      card(
        card_header("Data Format Requirements & Downloads"),
        uiOutput("restore_prompt_ui"),
        hr(),
        layout_column_wrap(
          width = 1/3,
          card(
            card_header("1. Master Catalog"),
            p(tags$b("Required Columns:")),
            tags$ul(
              tags$li(tags$code("Accession No")),
              tags$li(tags$code("Title")),
              tags$li(tags$code("Author")),
              tags$li(tags$code("Class No"))
            ),
            downloadButton("dl_master_tpl", "Download Template", class = "btn-outline-secondary btn-sm")
          ),
          card(
            card_header("2. Scanned Inventory"),
            p(tags$b("Required Columns:")),
            tags$ul(
              tags$li(tags$code("Accession No"))
            ),
            p(tags$em("Collected during physical stock taking.")),
            downloadButton("dl_scanned_tpl", "Download Template", class = "btn-outline-secondary btn-sm")
          ),
          card(
            card_header("3. Exceptions List"),
            p(tags$b("Required Columns:")),
            tags$ul(
              tags$li(tags$code("Accession No")),
              tags$li(tags$code("Status"))
            ),
            p(tags$em("Status e.g.: Checked Out, Binding, Damage")),
            downloadButton("dl_exc_tpl", "Download Template", class = "btn-outline-secondary btn-sm")
          )
        ),
        hr(),
        uiOutput("upload_status_ui")
      )
    )
  ),
  
  # --- TAB 2: LIVE BARCODE SCANNING ---
  tabPanel(
    "Live Barcode Scanning",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        title = "Barcode Entry Station",
        textInput("barcode_input", "Scan / Enter Accession No:", value = "", placeholder = "e.g., ACC1001"),
        actionButton("add_scan_btn", "Submit Accession No", class = "btn-success w-100 mb-3"),
        hr(),
        actionButton("clear_scans_btn", "Clear All Live Scans", class = "btn-outline-warning w-100")
      ),
      layout_column_wrap(
        width = 1,
        card(
          card_header("Recorded Physical Scans"),
          DTOutput("live_scans_dt")
        )
      )
    )
  ),
  
  # --- TAB 3: AUDIT SUMMARY DASHBOARD ---
  tabPanel(
    "Verification Summary",
    fluidRow(
      column(3, value_box(title = "Total Master Collection", value = textOutput("vbox_total"), showcase = bsicons::bs_icon("bookshelf"), theme = "primary")),
      column(3, value_box(title = "Physically Verified", value = textOutput("vbox_verified"), showcase = bsicons::bs_icon("check-circle-fill"), theme = "success")),
      column(3, value_box(title = "Known Exceptions", value = textOutput("vbox_exceptions"), showcase = bsicons::bs_icon("info-circle-fill"), theme = "warning")),
      column(3, value_box(title = "Unaccounted / Missing", value = textOutput("vbox_missing"), showcase = bsicons::bs_icon("exclamation-triangle-fill"), theme = "danger"))
    ),
    hr(),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Stock Verification Status Breakdown"),
        tableOutput("summary_table")
      ),
      card(
        card_header("Audit Guidelines & Reconciliation"),
        p("This automated verification process classifies items into four categories:"),
        tags$ul(
          tags$li(tags$b("Present (Physically Verified):"), " Items physically scanned on shelves."),
          tags$li(tags$b("Accounted Exceptions:"), " Items physically absent but accounted for in status records."),
          tags$li(tags$b("Unaccounted / Missing:"), " Items listed in the master catalog but missing from scans and exception logs.")
        )
      )
    )
  ),
  
  # --- TAB 4: DETAILED REPORT & EXPORT ---
  tabPanel(
    "Detailed Audit Records",
    layout_sidebar(
      sidebar = sidebar(
        width = 280,
        title = "Filter & Export",
        selectInput("filter_status", "Filter by Audit Status:", choices = "All", selected = "All"),
        hr(),
        downloadButton("download_report", "Export Complete Excel Report", class = "btn-success w-100")
      ),
      card(
        card_header("Itemized Audit Results"),
        DTOutput("audit_dt")
      )
    )
  ),
  
  # --- TAB 5: GENERATE OFFICIAL REPORT ---
  tabPanel(
    "Generate Report",
    layout_sidebar(
      sidebar = sidebar(
        width = 360,
        title = "Institutional & Audit Details",
        textInput("inst_name", "Institute Name", value = ""),
        textInput("lib_name", "Library Name", value = ""),
        textInput("sv_year", "Stock Verification Year", value = ""),
        textInput("sv_period", "Period of Stock Verification", value = ""),
        textInput("last_sv_year", "Last Stock Verification Year", value = ""),
        numericInput("total_transactions", "Total Transactions Since Last SV", value = NULL, min = 0, step = 100),
        hr(),
        actionButton("print_pdf_btn", "Print / Save PDF Report", class = "btn-danger w-100 mt-2", onclick = "window.print()"),
        downloadButton("download_official_pdf_excel", "Download Comprehensive Excel Report", class = "btn-primary w-100 mt-2")
      ),
      card(
        id = "printable_report_card",
        card_header("Official Stock Verification Executive Summary"),
        uiOutput("official_report_view")
      )
    )
  )
)

# ==========================================
# 3. SERVER LOGIC
# ==========================================
server <- function(input, output, session) {
  
  rv <- reactiveValues(
    master = NULL,
    scanned = NULL,
    exceptions = NULL,
    audit_result = NULL,
    master_source_file = NULL,
    master_source_rows = NULL
  )
  
  # Load database records on launch
  observe({
    tryCatch({
      conn <- dbConnect(SQLite(), db_path)
      on.exit(dbDisconnect(conn), add = TRUE)
      
      m_df <- dbReadTable(conn, "master_catalog")
      e_df <- dbReadTable(conn, "exceptions_log")
      s_df <- dbReadTable(conn, "live_scans")
      
      if (nrow(m_df) > 0) {
        names(m_df) <- c("Accession No", "Title", "Author", "Class No")
        rv$master <- m_df
      }
      
      if (nrow(e_df) > 0) {
        names(e_df) <- c("Accession No", "Status", "Notes")
        rv$exceptions <- e_df
      }
      
      if (nrow(s_df) > 0) {
        names(s_df) <- c("Accession No", "Timestamp")
        rv$scanned <- s_df
      }
    }, error = function(e) {
      showNotification(
        paste("Database could not be loaded:", conditionMessage(e)),
        type = "error", duration = 10
      )
    })
  })
  
  # Robust file reader.
  # The supplied Master Catalog contains Windows-1252 characters (for example
  # accented author/title text). Reading the raw bytes first and converting
  # them explicitly prevents partial/incorrect imports.
  read_data <- function(file_info) {
    req(file_info)
    
    ext <- tolower(tools::file_ext(file_info$name))
    
    tryCatch({
      if (ext == "csv") {
        
        raw <- readBin(
          file_info$datapath,
          what = "raw",
          n = file.info(file_info$datapath)$size
        )
        
        # Detect UTF-8 BOM. Otherwise treat the CSV as Windows-1252 first.
        if (length(raw) >= 3 &&
            identical(as.integer(raw[1:3]), c(239L, 187L, 191L))) {
          
          txt <- rawToChar(raw)
          txt <- sub(
            "^\ufeff",
            "",
            iconv(txt, from = "UTF-8", to = "UTF-8",
                  sub = "byte")
          )
          
        } else {
          
          txt <- iconv(
            rawToChar(raw),
            from = "Windows-1252",
            to = "UTF-8",
            sub = ""
          )
          
          # If conversion failed, retry as Latin-1.
          if (is.na(txt) || !nzchar(txt)) {
            txt <- iconv(
              rawToChar(raw),
              from = "latin1",
              to = "UTF-8",
              sub = ""
            )
          }
        }
        
        out <- read.csv(
          text = txt,
          stringsAsFactors = FALSE,
          check.names = FALSE,
          quote = "\"",
          fill = TRUE,
          comment.char = "",
          na.strings = character(0)
        )
        
        # Remove a possible BOM from the first column name.
        names(out) <- trimws(
          sub("^\ufeff", "", names(out))
        )
        
        out
        
      } else if (ext == "xlsx") {
        
        openxlsx::read.xlsx(
          file_info$datapath,
          check.names = FALSE
        )
        
      } else {
        
        showNotification(
          "Invalid file type. Upload .csv or .xlsx.",
          type = "error",
          duration = 8
        )
        NULL
      }
      
    }, error = function(e) {
      
      showNotification(
        paste(
          "Unable to read uploaded file:",
          conditionMessage(e)
        ),
        type = "error",
        duration = 10
      )
      NULL
    })
  }
  
  normalize_names <- function(x) {
    x <- trimws(as.character(x))
    sub("^\\ufeff", "", x)
  }
  
  clean_accession <- function(x) {
    x <- trimws(as.character(x))
    x[is.na(x)] <- ""
    x
  }
  
  validate_columns <- function(df, required, label) {
    if (is.null(df) || !is.data.frame(df) || ncol(df) == 0) {
      showNotification(paste(label, "is empty or could not be read."),
                       type = "error", duration = 8)
      return(FALSE)
    }
    
    names(df) <- normalize_names(names(df))
    missing_cols <- setdiff(required, names(df))
    
    if (length(missing_cols) > 0) {
      showNotification(
        paste0(label, " is missing required column(s): ",
               paste(missing_cols, collapse = ", "), "."),
        type = "error", duration = 10
      )
      return(FALSE)
    }
    TRUE
  }
  
  # IMPORTANT: SQLite uses snake_case column names. The original code tried
  # to append data frames containing "Accession No", "Title", etc. directly
  # into tables whose columns are accession_no, title, etc. That causes a
  # DBI/SQLite error and can make the Shiny session appear to close.
  replace_master_db <- function(df) {
    db_df <- data.frame(
      accession_no = clean_accession(df$`Accession No`),
      title = as.character(df$Title),
      author = as.character(df$Author),
      class_no = as.character(df$`Class No`),
      stringsAsFactors = FALSE
    )
    db_df <- db_df[db_df$accession_no != "", , drop = FALSE]
    db_df <- db_df[!duplicated(db_df$accession_no), , drop = FALSE]
    
    conn <- dbConnect(SQLite(), db_path)
    on.exit(dbDisconnect(conn), add = TRUE)
    dbExecute(conn, "DELETE FROM master_catalog")
    if (nrow(db_df) > 0) {
      dbWriteTable(conn, "master_catalog", db_df,
                   append = TRUE, row.names = FALSE)
    }
  }
  
  replace_scanned_db <- function(df) {
    db_df <- data.frame(
      accession_no = clean_accession(df$`Accession No`),
      stringsAsFactors = FALSE
    )
    db_df <- db_df[db_df$accession_no != "", , drop = FALSE]
    db_df <- db_df[!duplicated(db_df$accession_no), , drop = FALSE]
    
    conn <- dbConnect(SQLite(), db_path)
    on.exit(dbDisconnect(conn), add = TRUE)
    dbExecute(conn, "DELETE FROM live_scans")
    if (nrow(db_df) > 0) {
      dbWriteTable(conn, "live_scans", db_df,
                   append = TRUE, row.names = FALSE)
    }
  }
  
  replace_exceptions_db <- function(df) {
    db_df <- data.frame(
      accession_no = clean_accession(df$`Accession No`),
      status = as.character(df$Status),
      notes = as.character(df$Notes),
      stringsAsFactors = FALSE
    )
    db_df$status[is.na(db_df$status)] <- ""
    db_df$notes[is.na(db_df$notes)] <- ""
    db_df <- db_df[db_df$accession_no != "", , drop = FALSE]
    db_df <- db_df[!duplicated(db_df$accession_no), , drop = FALSE]
    
    conn <- dbConnect(SQLite(), db_path)
    on.exit(dbDisconnect(conn), add = TRUE)
    dbExecute(conn, "DELETE FROM exceptions_log")
    if (nrow(db_df) > 0) {
      dbWriteTable(conn, "exceptions_log", db_df,
                   append = TRUE, row.names = FALSE)
    }
  }
  
  output$dl_master_tpl <- downloadHandler(
    filename = function() { "Master_Catalog_Template.csv" },
    content = function(file) { write.csv(get_sample_master(), file, row.names = FALSE) }
  )
  
  output$dl_scanned_tpl <- downloadHandler(
    filename = function() { "Scanned_Inventory_Template.csv" },
    content = function(file) { write.csv(get_sample_scanned(), file, row.names = FALSE) }
  )
  
  output$dl_exc_tpl <- downloadHandler(
    filename = function() { "Exceptions_List_Template.csv" },
    content = function(file) { write.csv(get_sample_exceptions(), file, row.names = FALSE) }
  )
  
  output$restore_prompt_ui <- renderUI({
    has_m <- !is.null(rv$master) && nrow(rv$master) > 0
    has_s <- !is.null(rv$scanned) && nrow(rv$scanned) > 0
    has_e <- !is.null(rv$exceptions) && nrow(rv$exceptions) > 0
    
    if (has_m || has_s || has_e) {
      div(class = "alert alert-info",
          h5("Active SQLite Local Database Storage Active"),
          p(paste("Loaded Records — Master:", ifelse(has_m, nrow(rv$master), 0),
                  "| Scanned:", ifelse(has_s, nrow(rv$scanned), 0),
                  "| Exceptions:", ifelse(has_e, nrow(rv$exceptions), 0))))
    }
  })
  
  observeEvent(input$load_sample, {
    tryCatch({
      m <- get_sample_master()
      s <- get_sample_scanned()
      e <- get_sample_exceptions()
      
      replace_master_db(m)
      replace_exceptions_db(e)
      replace_scanned_db(s)
      
      rv$master <- m
      rv$scanned <- s
      rv$exceptions <- e
      rv$audit_result <- NULL
      
      showNotification(
        "Demo datasets loaded into persistent store!",
        type = "message"
      )
    }, error = function(e) {
      showNotification(
        paste("Demo data could not be loaded:", conditionMessage(e)),
        type = "error", duration = 10
      )
    })
  })
  
  observeEvent(
    input$file_master,
    ignoreInit = TRUE,
    {
      req(input$file_master)
      
      df <- read_data(input$file_master)
      req(df)
      
      if (!validate_columns(
        df,
        c("Accession No", "Title", "Author", "Class No"),
        "Master Catalog"
      )) return()
      
      # Keep all valid records. Do NOT limit the catalogue to the old
      # database count or to the sample catalogue size.
      df <- df[
        ,
        c("Accession No", "Title", "Author", "Class No"),
        drop = FALSE
      ]
      
      source_rows <- nrow(df)
      
      df$`Accession No` <- clean_accession(
        df$`Accession No`
      )
      
      blank_accessions <- sum(
        df$`Accession No` == ""
      )
      
      if (blank_accessions > 0) {
        df <- df[
          df$`Accession No` != "",
          ,
          drop = FALSE
        ]
      }
      
      duplicate_accessions <- sum(
        duplicated(df$`Accession No`)
      )
      
      if (duplicate_accessions > 0) {
        df <- df[
          !duplicated(df$`Accession No`),
          ,
          drop = FALSE
        ]
      }
      
      imported_rows <- nrow(df)
      
      # IMPORTANT: write the complete imported catalogue to SQLite.
      # replace_master_db performs a full replacement, not a sample merge.
      tryCatch({
        
        replace_master_db(df)
        
        # Verify the number written directly in SQLite.
        conn <- dbConnect(
          SQLite(),
          db_path
        )
        on.exit(
          dbDisconnect(conn),
          add = TRUE
        )
        
        db_count <- dbGetQuery(
          conn,
          "SELECT COUNT(*) AS n FROM master_catalog"
        )$n[[1]]
        
        if (as.integer(db_count) != imported_rows) {
          stop(
            paste0(
              "Database verification failed. ",
              "File contains ",
              imported_rows,
              " valid records but SQLite contains ",
              db_count,
              "."
            )
          )
        }
        
        # Only update the reactive data after the database has been
        # successfully verified.
        rv$master <- df
        rv$master_source_file <- input$file_master$name
        rv$master_source_rows <- imported_rows
        rv$audit_result <- NULL
        
        message(
          sprintf(
            "MASTER IMPORT: source rows=%d; imported=%d; database=%d",
            source_rows,
            imported_rows,
            db_count
          )
        )
        
        notify_text <- paste0(
          "Master Catalog imported successfully: ",
          format(imported_rows, big.mark = ","),
          " records."
        )
        
        if (blank_accessions > 0 ||
            duplicate_accessions > 0) {
          
          notify_text <- paste0(
            notify_text,
            " Source rows: ",
            format(source_rows, big.mark = ","),
            "."
          )
          
          if (blank_accessions > 0) {
            notify_text <- paste0(
              notify_text,
              " Blank accession rows removed: ",
              format(blank_accessions, big.mark = ","),
              "."
            )
          }
          
          if (duplicate_accessions > 0) {
            notify_text <- paste0(
              notify_text,
              " Duplicate accession rows removed: ",
              format(duplicate_accessions, big.mark = ","),
              "."
            )
          }
        }
        
        showNotification(
          notify_text,
          type = "message",
          duration = 8
        )
        
      }, error = function(e) {
        
        showNotification(
          paste(
            "Master Catalog import FAILED:",
            conditionMessage(e)
          ),
          type = "error",
          duration = 12
        )
      })
    }
  )
  
  observeEvent(input$file_scanned, {
    df <- read_data(input$file_scanned)
    req(df)
    
    if (!validate_columns(df, "Accession No", "Scanned Inventory")) return()
    
    df <- df[, "Accession No", drop = FALSE]
    df$`Accession No` <- clean_accession(df$`Accession No`)
    df <- df[df$`Accession No` != "", , drop = FALSE]
    df <- df[!duplicated(df$`Accession No`), , drop = FALSE]
    
    tryCatch({
      replace_scanned_db(df)
      
      conn <- dbConnect(SQLite(), db_path)
      on.exit(dbDisconnect(conn), add = TRUE)
      s_df <- dbReadTable(conn, "live_scans")
      
      if (nrow(s_df) > 0) {
        names(s_df) <- c("Accession No", "Timestamp")
        rv$scanned <- s_df
      } else {
        rv$scanned <- NULL
      }
      
      rv$audit_result <- NULL
      showNotification(
        paste("Scanned inventory stored successfully:",
              nrow(df), "unique scans."),
        type = "message", duration = 5
      )
    }, error = function(e) {
      showNotification(
        paste("Scanned Inventory could not be stored:",
              conditionMessage(e)),
        type = "error", duration = 10
      )
    })
  })
  
  observeEvent(input$file_exceptions, {
    df <- read_data(input$file_exceptions)
    req(df)
    
    if (!validate_columns(
      df, c("Accession No", "Status"), "Exceptions List"
    )) return()
    
    if (!"Notes" %in% names(df)) df$Notes <- ""
    
    df <- df[, c("Accession No", "Status", "Notes"), drop = FALSE]
    df$`Accession No` <- clean_accession(df$`Accession No`)
    df <- df[df$`Accession No` != "", , drop = FALSE]
    df <- df[!duplicated(df$`Accession No`), , drop = FALSE]
    
    tryCatch({
      replace_exceptions_db(df)
      rv$exceptions <- df
      rv$audit_result <- NULL
      showNotification(
        paste("Exceptions log stored successfully:",
              nrow(df), "records."),
        type = "message", duration = 5
      )
    }, error = function(e) {
      showNotification(
        paste("Exceptions List could not be stored:",
              conditionMessage(e)),
        type = "error", duration = 10
      )
    })
  })
  
  observeEvent(input$clear_db_btn, {
    tryCatch({
      conn <- dbConnect(SQLite(), db_path)
      on.exit(dbDisconnect(conn), add = TRUE)
      
      dbExecute(conn, "DELETE FROM master_catalog")
      dbExecute(conn, "DELETE FROM exceptions_log")
      dbExecute(conn, "DELETE FROM live_scans")
      
      rv$master <- NULL
      rv$exceptions <- NULL
      rv$scanned <- NULL
      rv$audit_result <- NULL
      
      showNotification(
        "Database reset completely.",
        type = "warning"
      )
    }, error = function(e) {
      showNotification(
        paste("Database reset failed:", conditionMessage(e)),
        type = "error", duration = 10
      )
    })
  })
  
  # Live Barcode Scanning Engine
  observeEvent(input$add_scan_btn, {
    barcode <- trimws(as.character(input$barcode_input))
    req(nzchar(barcode))
    
    tryCatch({
      conn <- dbConnect(SQLite(), db_path)
      on.exit(dbDisconnect(conn), add = TRUE)
      
      chk_stmt <- dbSendQuery(
        conn,
        "SELECT COUNT(*) FROM live_scans WHERE accession_no = ?"
      )
      dbBind(chk_stmt, list(barcode))
      is_dup <- dbFetch(chk_stmt)[[1]] > 0
      dbClearResult(chk_stmt)
      
      if (is_dup) {
        showNotification(
          paste("Duplicate Scan Alert! Accession No:",
                barcode, "already scanned."),
          type = "warning", duration = 4
        )
      } else {
        stmt <- dbSendQuery(
          conn,
          "INSERT INTO live_scans (accession_no) VALUES (?)"
        )
        dbBind(stmt, list(barcode))
        dbClearResult(stmt)
        showNotification(
          paste("Successfully Scanned:", barcode),
          type = "message", duration = 2
        )
      }
      
      s_df <- dbReadTable(conn, "live_scans")
      if (nrow(s_df) > 0) {
        names(s_df) <- c("Accession No", "Timestamp")
        rv$scanned <- s_df
      } else {
        rv$scanned <- NULL
      }
      
      rv$audit_result <- NULL
      updateTextInput(session, "barcode_input", value = "")
    }, error = function(e) {
      showNotification(
        paste("Barcode scan failed:", conditionMessage(e)),
        type = "error", duration = 8
      )
    })
  })
  
  observeEvent(input$clear_scans_btn, {
    tryCatch({
      conn <- dbConnect(SQLite(), db_path)
      on.exit(dbDisconnect(conn), add = TRUE)
      dbExecute(conn, "DELETE FROM live_scans")
      rv$scanned <- NULL
      rv$audit_result <- NULL
      showNotification(
        "Cleared live barcode scans.",
        type = "warning"
      )
    }, error = function(e) {
      showNotification(
        paste("Could not clear scans:", conditionMessage(e)),
        type = "error", duration = 8
      )
    })
  })
  
  output$live_scans_dt <- renderDT({
    req(rv$scanned)
    datatable(rv$scanned, options = list(pageLength = 10), rownames = FALSE)
  })
  
  output$master_upload_hint <- renderUI({
    if (!is.null(rv$master_source_rows)) {
      div(
        class = "alert alert-success",
        style = "padding:6px 10px; margin-top:5px; margin-bottom:5px;",
        tags$b(
          paste0(
            format(rv$master_source_rows, big.mark = ","),
            " records imported"
          )
        )
      )
    }
  })
  
  output$upload_status_ui <- renderUI({
    has_m <- !is.null(rv$master) &&
      nrow(rv$master) > 0
    
    has_s <- !is.null(rv$scanned) &&
      nrow(rv$scanned) > 0
    
    has_e <- !is.null(rv$exceptions) &&
      nrow(rv$exceptions) > 0
    
    source_line <- if (!is.null(rv$master_source_file)) {
      tagList(
        p(
          tags$b("Current Master File: "),
          rv$master_source_file
        ),
        p(
          tags$b("Rows imported from file: "),
          format(
            rv$master_source_rows,
            big.mark = ","
          )
        )
      )
    } else {
      NULL
    }
    
    tagList(
      h5("Loaded Dataset Summary:"),
      source_line,
      p(
        tags$b("Master Catalog: "),
        ifelse(
          has_m,
          paste(
            format(nrow(rv$master), big.mark = ","),
            "records loaded"
          ),
          "Not loaded"
        )
      ),
      p(
        tags$b("Scanned Inventory: "),
        ifelse(
          has_s,
          paste(
            format(nrow(rv$scanned), big.mark = ","),
            "scans loaded"
          ),
          "Not loaded"
        )
      ),
      p(
        tags$b("Exceptions Log: "),
        ifelse(
          has_e,
          paste(
            format(nrow(rv$exceptions), big.mark = ","),
            "records loaded"
          ),
          "Optional (None loaded)"
        )
      )
    )
  })
  
  # Audit Processing Engine with safe joining
  observeEvent(input$process_btn, {
    req(rv$master)
    
    master_df <- rv$master
    master_df$`Accession No` <- trimws(as.character(master_df$`Accession No`))
    
    scanned_accs <- if (!is.null(rv$scanned) && nrow(rv$scanned) > 0) {
      unique(trimws(as.character(rv$scanned$`Accession No`)))
    } else {
      c()
    }
    
    master_df <- master_df %>%
      mutate(Physical_Found = `Accession No` %in% scanned_accs)
    
    if (!is.null(rv$exceptions) && nrow(rv$exceptions) > 0) {
      exc_df <- rv$exceptions
      exc_df$`Accession No` <- trimws(as.character(exc_df$`Accession No`))
      
      # Ensure distinct keys to prevent row expansion and dataframe assignment crashes
      exc_df <- exc_df %>% distinct(`Accession No`, .keep_all = TRUE)
      
      exc_cols <- c("Accession No", "Status")
      if ("Notes" %in% names(exc_df)) exc_cols <- c(exc_cols, "Notes")
      
      master_df <- master_df %>%
        left_join(exc_df %>% select(all_of(exc_cols)), by = "Accession No")
    } else {
      master_df$Status <- NA_character_
      master_df$Notes <- NA_character_
    }
    
    master_df <- master_df %>%
      mutate(
        Audit_Status = case_when(
          Physical_Found ~ "Present (Verified)",
          !Physical_Found & !is.na(Status) & Status != "" ~ paste0("Exception: ", Status),
          TRUE ~ "Unaccounted / Missing"
        )
      )
    
    rv$audit_result <- master_df
    statuses <- c("All", unique(master_df$Audit_Status))
    updateSelectInput(session, "filter_status", choices = statuses, selected = "All")
    
    showNotification("Audit completed successfully!", type = "message")
  })
  
  # Dashboard outputs
  output$vbox_total <- renderText({ req(rv$audit_result); nrow(rv$audit_result) })
  output$vbox_verified <- renderText({ req(rv$audit_result); sum(rv$audit_result$Physical_Found) })
  output$vbox_exceptions <- renderText({ req(rv$audit_result); sum(!rv$audit_result$Physical_Found & !is.na(rv$audit_result$Status) & rv$audit_result$Status != "") })
  output$vbox_missing <- renderText({ req(rv$audit_result); sum(rv$audit_result$Audit_Status == "Unaccounted / Missing") })
  
  output$summary_table <- renderTable({
    req(rv$audit_result)
    rv$audit_result %>%
      group_by(`Audit Status` = Audit_Status) %>%
      summarise(
        `Total Books` = n(),
        `Percentage (%)` = round((n() / nrow(rv$audit_result)) * 100, 2)
      )
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
  
  output$audit_dt <- renderDT({
    req(rv$audit_result)
    df <- rv$audit_result
    if (input$filter_status != "All") {
      df <- df %>% filter(Audit_Status == input$filter_status)
    }
    datatable(df, options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE)
  })
  
  output$official_report_view <- renderUI({
    req(rv$audit_result)
    
    tot_books <- nrow(rv$audit_result)
    verified_books <- sum(rv$audit_result$Physical_Found)
    unaccounted_books <- sum(rv$audit_result$Audit_Status == "Unaccounted / Missing")
    transactions <- ifelse(is.na(input$total_transactions), 0, input$total_transactions)
    permissible_loss <- floor((transactions / 1000) * 5)
    
    loss_status <- if (unaccounted_books <= permissible_loss) {
      span(style = "color: green; font-weight: bold;", 
           paste0("WITHIN ALLOWABLE LIMITS (Permissible loss: ", permissible_loss, " volumes for ", transactions, " transactions). No negligence inferred."))
    } else {
      span(style = "color: red; font-weight: bold;", 
           paste0("EXCEEDS ALLOWABLE LIMITS (Permissible loss: ", permissible_loss, " volumes for ", transactions, " transactions). Investigation recommended."))
    }
    
    tagList(
      div(style = "text-align: center; margin-bottom: 20px;",
          h3(input$inst_name),
          h4(input$lib_name),
          h5(paste("STOCK VERIFICATION REPORT - YEAR", input$sv_year))
      ),
      hr(),
      tags$table(class = "table table-bordered",
                 tags$tr(tags$td(tags$b("Period of Stock Verification:")), tags$td(input$sv_period)),
                 tags$tr(tags$td(tags$b("Last Stock Verification Year:")), tags$td(input$last_sv_year)),
                 tags$tr(tags$td(tags$b("Total Circulation / Transactions:")), tags$td(format(transactions, big.mark = ","))),
                 tags$tr(tags$td(tags$b("Total Collection in Master Catalog:")), tags$td(format(tot_books, big.mark = ","))),
                 tags$tr(tags$td(tags$b("Physically Verified Collection:")), tags$td(format(verified_books, big.mark = ","))),
                 tags$tr(tags$td(tags$b("Total Unaccounted / Missing Books:")), tags$td(format(unaccounted_books, big.mark = ",")))
      ),
      hr(),
      h4("Reasonable Loss Allowance Analysis"),
      tags$blockquote(
        class = "blockquote p-3 bg-light border-start border-3 border-primary",
        p(tags$b("Standard Policy:"), " A loss of up to 5 volumes per 1,000 volumes of books issued/consulted in a year is considered reasonable, provided there is no negligence or dishonesty.")
      ),
      p(tags$b("Permissible Loss Threshold: "), permissible_loss, " volumes"),
      p(tags$b("Actual Unaccounted Loss: "), unaccounted_books, " volumes"),
      p(tags$b("Audit Finding: "), loss_status)
    )
  })
  
  output$download_report <- downloadHandler(
    filename = function() {
      paste0("Library_Stock_Verification_Report_", Sys.Date(), ".xlsx")
    },
    content = function(file) {
      req(rv$audit_result)
      wb <- createWorkbook()
      addWorksheet(wb, "Executive Summary")
      summary_df <- rv$audit_result %>%
        group_by(Audit_Status) %>%
        summarise(Count = n(), Percentage = round((n() / nrow(rv$audit_result)) * 100, 2))
      
      writeData(wb, "Executive Summary", "LIBRARY STOCK VERIFICATION AUDIT REPORT", startRow = 1)
      writeData(wb, "Executive Summary", paste("Audit Date:", Sys.Date()), startRow = 2)
      writeData(wb, "Executive Summary", summary_df, startRow = 4)
      
      addWorksheet(wb, "Full Audit Log")
      writeData(wb, "Full Audit Log", rv$audit_result)
      
      addWorksheet(wb, "Missing Books Action List")
      missing_df <- rv$audit_result %>% filter(Audit_Status == "Unaccounted / Missing")
      writeData(wb, "Missing Books Action List", missing_df)
      
      saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
  
  output$download_official_pdf_excel <- downloadHandler(
    filename = function() {
      paste0("Official_Stock_Verification_Report_", input$sv_year, ".xlsx")
    },
    content = function(file) {
      req(rv$audit_result)
      tot_books <- nrow(rv$audit_result)
      verified_books <- sum(rv$audit_result$Physical_Found)
      unaccounted_books <- sum(rv$audit_result$Audit_Status == "Unaccounted / Missing")
      transactions <- ifelse(is.na(input$total_transactions), 0, input$total_transactions)
      permissible_loss <- floor((transactions / 1000) * 5)
      
      wb <- createWorkbook()
      addWorksheet(wb, "Official Report")
      writeData(wb, "Official Report", input$inst_name, startRow = 1)
      writeData(wb, "Official Report", input$lib_name, startRow = 2)
      writeData(wb, "Official Report", paste("STOCK VERIFICATION REPORT - YEAR", input$sv_year), startRow = 3)
      
      meta_info <- data.frame(
        Parameter = c("Period of Stock Verification", "Last Stock Verification Year", 
                      "Total Transactions/Consultations", "Total Master Collection", 
                      "Physically Verified Collection", "Total Unaccounted / Missing",
                      "Permissible Loss Threshold (5 per 1,000)", "Loss Assessment"),
        Value = c(input$sv_period, input$last_sv_year, 
                  as.character(transactions), as.character(tot_books), 
                  as.character(verified_books), as.character(unaccounted_books),
                  as.character(permissible_loss),
                  if (unaccounted_books <= permissible_loss) "WITHIN ALLOWABLE LIMITS" else "EXCEEDS ALLOWABLE LIMITS - INVESTIGATION REQUIRED")
      )
      
      writeData(wb, "Official Report", meta_info, startRow = 5)
      addWorksheet(wb, "Unaccounted Missing Items")
      writeData(wb, "Unaccounted Missing Items", rv$audit_result %>% filter(Audit_Status == "Unaccounted / Missing"))
      
      saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
}

# Run App
shinyApp(ui = ui, server = server)