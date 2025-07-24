#!/usr/bin/env Rscript

#' Minimal setup script for R MCP Data Explorer
#' Configures Claude Desktop to use the minimal server

library(jsonlite)

# Function to configure Claude Desktop
configure_claude_desktop <- function() {
  message("\nConfiguring Claude Desktop for minimal R MCP server...")
  
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
  server_path <- normalizePath(file.path(getwd(), "R", "server_minimal.R"))
  
  config$mcpServers$`r-data-explorer` <- list(
    command = "Rscript",
    args = list(server_path)
  )
  
  # Write updated config
  write_json(config, config_path, pretty = TRUE, auto_unbox = TRUE)
  message("Updated Claude Desktop configuration at: ", config_path)
  message("Server script path: ", server_path)
  
  message("\nConfiguration complete! Please restart Claude Desktop for changes to take effect.")
  message("The R MCP Data Explorer server will be available as 'r-data-explorer' in Claude.")
}

# Create sample data
create_sample_data <- function() {
  message("\nCreating sample data...")
  
  # Create data directory
  if (!dir.exists("data")) {
    dir.create("data")
  }
  
  # Create sample CSV
  sample_data <- data.frame(
    id = 1:100,
    date = seq(as.Date("2024-01-01"), by = "day", length.out = 100),
    value = rnorm(100, mean = 50, sd = 10),
    category = sample(c("A", "B", "C", "D"), 100, replace = TRUE),
    region = sample(c("North", "South", "East", "West"), 100, replace = TRUE)
  )
  
  write.csv(sample_data, "data/sample_data.csv", row.names = FALSE)
  message("Created sample data at: data/sample_data.csv")
}

# Main setup
main <- function() {
  cat("\n")
  cat("==============================================\n")
  cat("   R MCP Data Explorer Minimal Setup\n")
  cat("==============================================\n")
  cat("\n")
  
  # Check required packages
  required_packages <- c("jsonlite", "tidyverse")
  missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  
  if (length(missing) > 0) {
    cat("Missing required packages:", paste(missing, collapse = ", "), "\n")
    cat("Please install them with: install.packages(c('", paste(missing, collapse = "', '"), "'))\n")
    return()
  }
  
  # Configure Claude Desktop
  configure_claude_desktop()
  
  # Create sample data
  create_sample_data()
  
  cat("\n")
  cat("Setup complete! Next steps:\n")
  cat("1. Restart Claude Desktop\n")
  cat("2. Look for 'r-data-explorer' in the MCP servers list\n")
  cat("3. Try: Use the load_data tool to load 'data/sample_data.csv' as 'sample'\n")
  cat("4. Then: Use run_tidyverse to analyze it with code like:\n")
  cat("   sample %>% group_by(category) %>% summarise(mean_value = mean(value))\n")
  cat("\n")
}

# Run setup
main()