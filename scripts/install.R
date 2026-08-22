# ==========================================
# LIBO INVENTORY - PACKAGE INSTALLER
# ==========================================

required_packages <- c(
  "shiny",
  "bslib",
  "bsicons",
  "dplyr",
  "DT",
  "openxlsx",
  "RSQLite",
  "DBI"
)

installed <- rownames(installed.packages())

missing <- setdiff(required_packages, installed)

if (length(missing) > 0) {
  install.packages(
    missing,
    repos = "https://cloud.r-project.org"
  )
}

cat("\n==========================================\n")
cat(" Libo Inventory installation completed\n")
cat("==========================================\n\n")