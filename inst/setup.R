#!/usr/bin/env Rscript

#' Setup script for R MCP Data Explorer
#' Configures Claude Desktop and installs required dependencies

library(jsonlite)

# Function to install required packages
install_dependencies <- function() {
  message("Installing required R packages...")
  
  required_packages <- c(
    "tidyverse",
    "arrow",
    "duckdb",
    "callr",
    "jsonlite",
    "base64enc",
    "ggplot2",
    "testthat",
    "devtools"
  )
  
  # Check which packages need installation
  missing_packages <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
  
  if (length(missing_packages) > 0) {
    message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
    install.packages(missing_packages, repos = "https://cran.r-project.org")
  } else {
    message("All required packages are already installed.")
  }
}

# Function to configure Claude Desktop
configure_claude_desktop <- function() {
  message("\nConfiguring Claude Desktop...")
  
  # Get Claude Desktop config path
  config_path <- file.path(
    Sys.getenv("HOME"),
    "Library/Application Support/Claude/claude_desktop_config.json"
  )
  
  # Read existing config or create new one
  if (file.exists(config_path)) {
    config <- fromJSON(config_path, simplifyVector = FALSE)
    message("Found existing Claude Desktop configuration")
  } else {
    config <- list(mcpServers = list())
    message("Creating new Claude Desktop configuration")
  }
  
  # Add R MCP Data Explorer configuration
  server_path <- normalizePath(file.path(dirname(dirname(getwd())), "R", "server.R"))
  
  config$mcpServers$`r-data-explorer` <- list(
    command = "Rscript",
    args = list(server_path),
    env = list(
      R_MCP_LOG_DIR = normalizePath(file.path(dirname(dirname(getwd())), "logs"))
    )
  )
  
  # Write updated config
  write_json(config, config_path, pretty = TRUE, auto_unbox = TRUE)
  message("Updated Claude Desktop configuration at: ", config_path)
  
  # Create logs directory if it doesn't exist
  log_dir <- file.path(dirname(dirname(getwd())), "logs")
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
    message("Created logs directory at: ", log_dir)
  }
  
  message("\nConfiguration complete! Please restart Claude Desktop for changes to take effect.")
  message("The R MCP Data Explorer server will be available as 'r-data-explorer' in Claude.")
}

# Function to test the installation
test_installation <- function() {
  message("\nTesting R installation...")
  
  # Test loading packages
  suppressPackageStartupMessages({
    library(tidyverse)
    library(arrow)
    library(duckdb)
    library(callr)
  })
  
  message("✓ All packages loaded successfully")
  
  # Test creating a simple tibble
  test_data <- tibble(
    x = 1:10,
    y = rnorm(10)
  )
  
  message("✓ Tibble creation works")
  
  # Test DuckDB connection
  con <- dbConnect(duckdb())
  dbDisconnect(con)
  
  message("✓ DuckDB connection works")
  
  message("\nAll tests passed!")
}

# Main setup function
main <- function() {
  cat("\n")
  cat("==============================================\n")
  cat("   R MCP Data Explorer Setup Script\n")
  cat("==============================================\n")
  cat("\n")
  
  # Install dependencies
  install_dependencies()
  
  # Configure Claude Desktop
  configure_claude_desktop()
  
  # Test installation
  test_installation()
  
  cat("\n")
  cat("Setup complete! Next steps:\n")
  cat("1. Restart Claude Desktop\n")
  cat("2. Look for 'r-data-explorer' in the MCP servers list\n")
  cat("3. Try loading a CSV file with: load_data('path/to/file.csv')\n")
  cat("\n")
}

# Run setup if script is executed directly
if (!interactive()) {
  main()
}