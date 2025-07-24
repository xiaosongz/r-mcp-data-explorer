#!/usr/bin/env Rscript

#' Test script for R MCP Data Explorer Server
#' Tests basic functionality without full MCP protocol

# Change to R directory
setwd("R")

# Source the server components
source("server.R")

# Test 1: Load a CSV file
cat("\n=== Test 1: Loading CSV data ===\n")
tryCatch({
  # Create sample data
  sample_data <- data.frame(
    id = 1:10,
    value = rnorm(10),
    category = sample(c("A", "B", "C"), 10, replace = TRUE)
  )
  
  # Write to CSV
  write.csv(sample_data, "../data/test_data.csv", row.names = FALSE)
  
  # Test load_data function
  result <- load_data("../data/test_data.csv", "test_data")
  cat(result)
  cat("\n\n")
  
}, error = function(e) {
  cat("Error in Test 1:", e$message, "\n")
})

# Test 2: Run tidyverse code
cat("\n=== Test 2: Running tidyverse code ===\n")
tryCatch({
  code <- "
test_data %>%
  group_by(category) %>%
  summarise(
    count = n(),
    mean_value = mean(value),
    sd_value = sd(value)
  )
"
  
  result <- run_tidyverse(code)
  cat(result)
  cat("\n\n")
  
}, error = function(e) {
  cat("Error in Test 2:", e$message, "\n")
})

# Test 3: Create a plot
cat("\n=== Test 3: Creating a plot ===\n")
tryCatch({
  code <- "
library(ggplot2)
ggplot(test_data, aes(x = category, y = value)) +
  geom_boxplot(fill = 'steelblue', alpha = 0.7) +
  labs(title = 'Value Distribution by Category',
       x = 'Category',
       y = 'Value') +
  theme_minimal()
"
  
  result <- run_tidyverse(code, return_plot = TRUE)
  
  # Extract plot info
  if (grepl("\\[Plot", result)) {
    cat("Plot successfully generated!\n")
  } else {
    cat("No plot generated\n")
  }
  
}, error = function(e) {
  cat("Error in Test 3:", e$message, "\n")
})

# Test 4: DuckDB query
cat("\n=== Test 4: DuckDB SQL query ===\n")
tryCatch({
  query <- "
SELECT 
  category,
  COUNT(*) as count,
  AVG(value) as avg_value,
  MIN(value) as min_value,
  MAX(value) as max_value
FROM test_data
GROUP BY category
ORDER BY count DESC
"
  
  result <- query_duckdb(query)
  cat(result)
  cat("\n\n")
  
}, error = function(e) {
  cat("Error in Test 4:", e$message, "\n")
})

# Test 5: Test MCP message handling
cat("\n=== Test 5: MCP message handling ===\n")
tryCatch({
  # Test initialize request
  request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "initialize",
    params = list()
  )
  
  response <- handle_request(request)
  cat("Initialize response received:\n")
  cat("  Protocol version:", response$result$protocolVersion, "\n")
  cat("  Server name:", response$result$serverInfo$name, "\n")
  cat("  Capabilities:", paste(names(response$result$capabilities), collapse = ", "), "\n")
  
  # Test tools/list request
  request <- list(
    jsonrpc = "2.0",
    id = 2,
    method = "tools/list"
  )
  
  response <- handle_request(request)
  cat("\nAvailable tools:\n")
  for (tool in response$result$tools) {
    cat("  -", tool$name, ":", tool$description, "\n")
  }
  
}, error = function(e) {
  cat("Error in Test 5:", e$message, "\n")
})

cat("\n=== All tests completed ===\n")
cat("Check logs/ directory for detailed server logs\n")