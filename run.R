# ==========================================
# LIBO INVENTORY - SERVER LAUNCHER
# ==========================================

# Find the folder where this run.R file is located
args <- commandArgs(trailingOnly = FALSE)

file_arg <- grep("^--file=", args, value = TRUE)

if (length(file_arg) > 0) {
  app_dir <- dirname(
    normalizePath(
      sub("^--file=", "", file_arg[1]),
      winslash = "/"
    )
  )
} else {
  app_dir <- getwd()
}

# Start Libo Inventory
shiny::runApp(
  appDir = app_dir,
  host = "0.0.0.0",
  port = 3838,
  launch.browser = TRUE
)