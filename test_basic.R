#!/usr/bin/env Rscript

#' Basic test for R MCP server without arrow/duckdb dependencies

# Change to R directory
setwd("R")

# Mock the required functions from arrow/duckdb
.DATA_STORAGE <- list(
  tibbles = list(),
  arrow_datasets = list(),
  duckdb_conn = NULL,
  metadata = list()
)

# Source only the core components we need
source("utils/logging.R")
source("utils/mcp_transport.R")

# Initialize logging
log_file <- init_logging()
log_info("Starting basic R MCP server test")

# Test MCP message handling
cat("\n=== Testing MCP Protocol ===\n")

# Test 1: Initialize request
request <- list(
  jsonrpc = "2.0",
  id = 1,
  method = "initialize",
  params = list()
)

# Create a minimal handle_request function for testing
handle_request <- function(request) {
  response <- list(
    jsonrpc = "2.0",
    id = request$id
  )
  
  if (request$method == "initialize") {
    response$result <- list(
      protocolVersion = "0.1.0",
      capabilities = list(
        tools = list(list = TRUE)
      ),
      serverInfo = list(
        name = "r-mcp-data-explorer",
        version = "1.0.0"
      )
    )
  }
  
  return(response)
}

response <- handle_request(request)
cat("Initialize response:\n")
cat("  Protocol version:", response$result$protocolVersion, "\n")
cat("  Server name:", response$result$serverInfo$name, "\n")

# Test 2: JSON serialization
cat("\n=== Testing JSON Serialization ===\n")

test_data <- list(
  method = "test",
  params = list(
    string = "hello",
    number = 42,
    boolean = TRUE,
    null_value = NULL,
    array = c(1, 2, 3),
    object = list(key = "value")
  )
)

json_output <- jsonlite::toJSON(test_data, auto_unbox = TRUE, null = "null")
cat("JSON output:\n", json_output, "\n")

# Test 3: Transport functions
cat("\n=== Testing Transport Functions ===\n")

# Test response creation
test_response <- create_success_response(
  id = 123,
  result = list(message = "Test successful")
)

cat("Success response structure:\n")
str(test_response)

# Test error response
error_response <- create_error_response(
  id = 456,
  code = -32603,
  message = "Test error"
)

cat("\nError response structure:\n")
str(error_response)

# Test 4: Basic data handling
cat("\n=== Testing Basic Data Handling ===\n")

# Create test tibble
test_tibble <- data.frame(
  id = 1:5,
  value = rnorm(5),
  category = c("A", "B", "A", "B", "C")
)

# Store in .DATA_STORAGE
.DATA_STORAGE$tibbles[["test_data"]] <- test_tibble
.DATA_STORAGE$metadata[["test_data"]] <- list(
  backend = "tibble",
  size = object.size(test_tibble),
  columns = names(test_tibble),
  nrow = nrow(test_tibble)
)

cat("Stored test_data in memory\n")
cat("  Rows:", nrow(test_tibble), "\n")
cat("  Columns:", paste(names(test_tibble), collapse = ", "), "\n")

cat("\n=== Basic tests completed successfully ===\n")
cat("Check", log_file, "for detailed logs\n")