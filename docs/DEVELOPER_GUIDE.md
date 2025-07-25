# R MCP Data Explorer Developer Guide

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Getting Started](#getting-started)
3. [Core Components](#core-components)
4. [Data Management System](#data-management-system)
5. [Security Model](#security-model)
6. [Adding New Features](#adding-new-features)
7. [Testing](#testing)
8. [Debugging](#debugging)
9. [Best Practices](#best-practices)

## Architecture Overview

The R MCP Data Explorer follows a modular architecture with clear separation of concerns:

```
r-mcp-data-explorer/
├── R/
│   ├── server.R              # Main server entry point
│   ├── tools/                # MCP tool implementations
│   │   ├── data_loader.R     # File loading tool
│   │   ├── script_runner.R   # R code execution tool
│   │   └── query_runner.R    # SQL query tool
│   └── utils/                # Utility modules
│       ├── data_manager.R    # Three-tier data storage
│       ├── security.R        # Sandboxing and validation
│       ├── logging.R         # Logging system
│       ├── mcp_transport.R   # MCP protocol handling
│       └── visualization.R   # Plot generation utilities
```

### Key Design Decisions

1. **Three-Tier Storage**: Automatically selects optimal backend based on data size
2. **Security-First**: Multiple layers of protection for code execution
3. **Modular Tools**: Each tool is self-contained with clear interfaces
4. **Comprehensive Logging**: Detailed logs for debugging MCP communication

## Getting Started

### Prerequisites

- R >= 4.0.0
- Required R packages (see DESCRIPTION file)
- Claude Desktop application

### Development Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd r-mcp-data-explorer
```

2. Install dependencies:
```r
# In R console
install.packages("devtools")
devtools::install_deps()
```

3. Configure Claude Desktop:
```r
Rscript inst/setup.R
```

4. Run the server:
```bash
Rscript R/server.R
```

### Development Workflow

1. Load all functions for development:
```r
devtools::load_all()
```

2. Make changes to R files
3. Reload with `devtools::load_all()`
4. Test with small datasets first
5. Check logs in `logs/` directory

## Core Components

### Server Component (`R/server.R`)

The main server implements the MCP protocol over stdio:

```r
# Main request handler
handle_request <- function(request) {
  response <- list(
    jsonrpc = "2.0",
    id = request$id
  )
  
  # Route to appropriate handler
  if (request$method == "tools/call") {
    # Handle tool execution
  } else if (request$method == "tools/list") {
    # Return available tools
  }
  
  return(response)
}
```

Key responsibilities:
- Parse JSON-RPC requests
- Route to appropriate handlers
- Format and send responses
- Handle errors gracefully

### MCP Transport (`R/utils/mcp_transport.R`)

Handles low-level communication:

```r
# Read request from stdin
read_request <- function(con) {
  line <- readLines(con, n = 1, warn = FALSE, encoding = "UTF-8")
  request <- jsonlite::fromJSON(line, simplifyVector = FALSE)
  return(request)
}

# Send response to stdout
send_response <- function(response, con = stdout()) {
  json_str <- jsonlite::toJSON(response, auto_unbox = TRUE)
  writeLines(json_str, con = con, useBytes = TRUE)
  flush(con)
}
```

### Tool Implementation Pattern

Each tool follows a consistent pattern:

```r
#' Tool function
#' @param ... Tool parameters
#' @return Formatted response string
tool_function <- function(param1, param2, options = list()) {
  # 1. Validate inputs
  validation <- validate_inputs(param1, param2)
  if (!isTRUE(validation)) {
    stop(validation)
  }
  
  # 2. Execute core logic
  result <- execute_logic(param1, param2, options)
  
  # 3. Format response
  response <- format_response(result)
  
  # 4. Log completion
  log_info("Tool execution completed")
  
  return(response)
}
```

## Data Management System

### Three-Tier Architecture

The data manager automatically selects the optimal storage backend:

```r
# Size thresholds
.SIZE_THRESHOLD_ARROW <- 100 * 1024 * 1024   # 100MB
.SIZE_THRESHOLD_DUCKDB <- 1024 * 1024 * 1024 # 1GB

# Backend selection logic
backend <- if (file_size < .SIZE_THRESHOLD_ARROW) {
  "tibble"  # In-memory R data frame
} else if (file_size < .SIZE_THRESHOLD_DUCKDB) {
  "arrow"   # Columnar format
} else {
  "duckdb"  # SQL database
}
```

### Storage Operations

```r
# Store dataset
store_dataset(data, name, file_path, force_backend = NULL)

# Retrieve dataset
data <- get_dataset(name)

# List all datasets
datasets <- list_datasets()

# Get dataset metadata
info <- get_dataset_info(name)
```

### Helper Functions

For each dataset, helper functions are automatically created:

```r
# Create helper functions
create_helper_functions <- function(name) {
  # {dataset}_glimpse() - View structure
  assign(paste0(name, "_glimpse"), 
         function() glimpse(get_dataset(name)))
  
  # {dataset}_summary() - Summary statistics
  assign(paste0(name, "_summary"),
         function() summary(get_dataset(name)))
  
  # Additional helpers...
}
```

## Security Model

### Sandboxed Execution

Code execution happens in a restricted environment:

```r
# Create sandbox environment
create_sandbox_env <- function(datasets = list()) {
  env <- new.env(parent = globalenv())
  
  # Add only allowed packages
  for (pkg in .SECURITY_CONFIG$allowed_packages) {
    # Attach package exports to environment
  }
  
  # Override dangerous functions
  for (fn in .SECURITY_CONFIG$blocked_functions) {
    assign(fn, function(...) {
      stop(paste("Function", fn, "is not allowed"))
    }, envir = env)
  }
  
  return(env)
}
```

### Security Configuration

```r
.SECURITY_CONFIG <- list(
  timeout = 30,  # Execution timeout in seconds
  memory_limit = "2G",
  allowed_packages = c("tidyverse", "dplyr", ...),
  blocked_functions = c("system", "setwd", ...),
  allowed_paths = c("data/", tempdir())
)
```

### Code Validation

Before execution, code is validated:

```r
validate_code <- function(code) {
  # Parse to check syntax
  parsed <- parse(text = code)
  
  # Check for dangerous patterns
  if (grepl("system\\s*\\(", code)) {
    return("System calls are not allowed")
  }
  
  return(TRUE)
}
```

## Adding New Features

### Adding a New Tool

1. Create tool file in `R/tools/`:
```r
# R/tools/new_tool.R
new_tool <- function(param1, param2) {
  # Implementation
}
```

2. Add tool definition in `server.R`:
```r
TOOLS <- list(
  new_tool = list(
    name = "new_tool",
    description = "Tool description",
    inputSchema = list(
      type = "object",
      properties = list(
        param1 = list(type = "string"),
        param2 = list(type = "number")
      ),
      required = list("param1")
    )
  )
)
```

3. Add handler in `handle_request()`:
```r
if (tool_name == "new_tool") {
  result <- new_tool(args$param1, args$param2)
}
```

### Adding File Format Support

1. Add loader function in `data_loader.R`:
```r
load_newformat <- function(path, options) {
  # Load file
  data <- read_newformat(path)
  
  # Convert to tibble
  return(as_tibble(data))
}
```

2. Update switch statement:
```r
data <- switch(file_ext,
  "csv" = load_csv(path, options),
  "newformat" = load_newformat(path, options),
  # ...
)
```

## Testing

### Unit Testing

Create tests in `tests/testthat/`:

```r
# tests/testthat/test-data-loader.R
test_that("CSV files load correctly", {
  # Create test file
  test_data <- data.frame(x = 1:3, y = c("a", "b", "c"))
  test_file <- tempfile(fileext = ".csv")
  write.csv(test_data, test_file, row.names = FALSE)
  
  # Test loading
  result <- load_data(test_file, "test")
  
  # Assertions
  expect_equal(nrow(get_dataset("test")), 3)
  expect_equal(ncol(get_dataset("test")), 2)
  
  # Cleanup
  unlink(test_file)
})
```

### Integration Testing

Test MCP communication:

```r
# tests/testthat/test-mcp-protocol.R
test_that("MCP initialize works", {
  request <- list(
    jsonrpc = "2.0",
    id = 1,
    method = "initialize",
    params = list()
  )
  
  response <- handle_request(request)
  
  expect_equal(response$result$protocolVersion, "0.1.0")
  expect_true("tools" %in% names(response$result$capabilities))
})
```

## Debugging

### Enable Debug Logging

Set environment variable:
```bash
export R_MCP_LOG_LEVEL=DEBUG
Rscript R/server.R
```

### Common Issues

1. **JSON parsing errors**
   - Check log files for raw JSON
   - Validate JSON structure
   - Look for encoding issues

2. **Tool execution failures**
   - Check security restrictions
   - Verify package availability
   - Review error logs

3. **Data loading issues**
   - Verify file permissions
   - Check file format support
   - Monitor memory usage

### Debugging Tools

```r
# In development, add debug helpers
debug_request <- function(request) {
  log_debug(paste("Request method:", request$method))
  log_debug(paste("Request params:", toJSON(request$params)))
  
  # Save request for inspection
  saveRDS(request, paste0("debug/request_", Sys.time(), ".rds"))
}
```

## Best Practices

### Code Style

1. **Function Documentation**: Use roxygen2 style
```r
#' Function description
#' @param x Parameter description
#' @return Return value description
function_name <- function(x) {
  # Implementation
}
```

2. **Error Handling**: Always use informative messages
```r
if (!file.exists(path)) {
  stop(paste("File not found:", path))
}
```

3. **Logging**: Log at appropriate levels
```r
log_debug("Detailed information for debugging")
log_info("General information")
log_warn("Warning conditions")
log_error("Error conditions")
```

### Performance

1. **Use Appropriate Backend**: Let the data manager choose
2. **Lazy Evaluation**: Use Arrow/DuckDB for large data
3. **Minimize Data Movement**: Process in-place when possible

### Security

1. **Never Trust User Input**: Always validate
2. **Use Whitelists**: Not blacklists for security
3. **Fail Securely**: Deny by default
4. **Log Security Events**: For audit trails

### MCP Protocol

1. **Handle All Methods**: Even if just to return error
2. **Validate Requests**: Check required fields
3. **Format Responses**: Follow JSON-RPC spec
4. **Handle Errors Gracefully**: Return proper error codes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Code Review Checklist

- [ ] Follows R style guide
- [ ] Includes appropriate documentation
- [ ] Has test coverage
- [ ] Handles errors appropriately
- [ ] Includes logging
- [ ] Considers security implications
- [ ] Performance impact assessed
- [ ] MCP protocol compliance