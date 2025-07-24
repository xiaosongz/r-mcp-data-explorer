#!/usr/bin/env Rscript

#' Minimal R MCP Data Explorer Server
#' Version without arrow/duckdb dependencies for testing

# Load required libraries
suppressPackageStartupMessages({
  library(jsonlite)
  library(tidyverse)
})

# Initialize global storage (simplified)
.DATA_STORAGE <- list(
  tibbles = list(),
  metadata = list()
)

# Simple logging functions
log_info <- function(msg) {
  cat(paste("[INFO]", Sys.time(), msg, "\n"), file = stderr())
}

log_error <- function(msg) {
  cat(paste("[ERROR]", Sys.time(), msg, "\n"), file = stderr())
}

# Initialize data storage
init_data_manager <- function() {
  log_info("Data manager initialized (minimal mode)")
}

cleanup_data_manager <- function() {
  log_info("Data manager cleaned up")
}

# Data management functions
store_dataset <- function(data, name) {
  .DATA_STORAGE$tibbles[[name]] <<- as_tibble(data)
  .DATA_STORAGE$metadata[[name]] <<- list(
    nrow = nrow(data),
    ncol = ncol(data),
    columns = names(data)
  )
}

get_dataset <- function(name) {
  .DATA_STORAGE$tibbles[[name]]
}

list_datasets <- function() {
  names(.DATA_STORAGE$tibbles)
}

# Simplified load_data function
load_data <- function(path, name, options = list()) {
  log_info(paste("Loading data from:", path))
  
  if (!file.exists(path)) {
    stop(paste("File not found:", path))
  }
  
  # Only support CSV for now
  data <- read_csv(path, show_col_types = FALSE)
  
  # Store the data
  store_dataset(data, name)
  
  # Return summary
  summary_text <- paste0(
    "Successfully loaded dataset '", name, "'\n",
    "Rows: ", nrow(data), "\n",
    "Columns: ", ncol(data), " (", paste(names(data), collapse = ", "), ")\n",
    "\nFirst 5 rows:\n",
    paste(capture.output(print(head(data, 5))), collapse = "\n")
  )
  
  return(summary_text)
}

# Simplified run_tidyverse function
run_tidyverse <- function(code, dataset = NULL, return_plot = TRUE) {
  log_info("Executing tidyverse code")
  
  result <- tryCatch({
    # Create environment with datasets
    env <- new.env(parent = globalenv())
    
    # Add all datasets
    for (name in list_datasets()) {
      assign(name, get_dataset(name), envir = env)
    }
    
    # Capture output
    output <- capture.output({
      res <- eval(parse(text = code), envir = env)
    })
    
    # Format response
    response <- paste(output, collapse = "\n")
    if (!is.null(res) && !identical(res, "")) {
      response <- paste0(response, "\n\nResult:\n", 
                        paste(capture.output(print(res)), collapse = "\n"))
    }
    
    response
    
  }, error = function(e) {
    paste("Error:", e$message)
  })
  
  return(result)
}

# Simplified query_duckdb (just returns not implemented)
query_duckdb <- function(query, dataset = NULL) {
  return("DuckDB queries not available in minimal mode. Please use tidyverse syntax instead.")
}

# Server info
SERVER_INFO <- list(
  name = "r-mcp-data-explorer-minimal",
  version = "1.0.0",
  description = "Minimal MCP server for R data exploration"
)

# Tool definitions
TOOLS <- list(
  load_data = list(
    name = "load_data",
    description = "Load CSV data files",
    inputSchema = list(
      type = "object",
      properties = list(
        path = list(type = "string", description = "Path to CSV file"),
        name = list(type = "string", description = "Dataset name")
      ),
      required = list("path", "name")
    )
  ),
  
  run_tidyverse = list(
    name = "run_tidyverse",
    description = "Execute R tidyverse code",
    inputSchema = list(
      type = "object",
      properties = list(
        code = list(type = "string", description = "R code to execute")
      ),
      required = list("code")
    )
  )
)

# Handle requests
handle_request <- function(request) {
  log_info(paste("Handling request:", request$method))
  
  response <- list(
    jsonrpc = "2.0",
    id = request$id
  )
  
  tryCatch({
    if (request$method == "initialize") {
      response$result <- list(
        protocolVersion = "0.1.0",
        capabilities = list(
          tools = list(list = TRUE)
        ),
        serverInfo = SERVER_INFO
      )
      
    } else if (request$method == "initialized") {
      log_info("Server initialized successfully")
      return(NULL)
      
    } else if (request$method == "tools/list") {
      response$result <- list(
        tools = unname(TOOLS)
      )
      
    } else if (request$method == "tools/call") {
      tool_name <- request$params$name
      args <- request$params$arguments
      
      log_info(paste("Calling tool:", tool_name))
      
      if (tool_name == "load_data") {
        result <- load_data(args$path, args$name)
      } else if (tool_name == "run_tidyverse") {
        result <- run_tidyverse(args$code)
      } else {
        stop(paste("Unknown tool:", tool_name))
      }
      
      response$result <- list(
        content = list(
          list(
            type = "text",
            text = result
          )
        )
      )
      
    } else {
      stop(paste("Unknown method:", request$method))
    }
    
  }, error = function(e) {
    log_error(paste("Error handling request:", e$message))
    response$error <- list(
      code = -32603,
      message = e$message
    )
  })
  
  return(response)
}

# Main server loop
main <- function() {
  log_info("R MCP Data Explorer Server (Minimal) starting...")
  
  # Initialize
  init_data_manager()
  
  # Set up connection
  stdin_con <- file("stdin", "r", blocking = TRUE)
  stdout_con <- stdout()
  
  # Handle shutdown
  on.exit({
    log_info("Shutting down server...")
    cleanup_data_manager()
    close(stdin_con)
  })
  
  while (TRUE) {
    tryCatch({
      # Read line from stdin
      line <- readLines(stdin_con, n = 1, warn = FALSE)
      
      if (length(line) == 0) {
        break
      }
      
      if (nchar(trimws(line)) == 0) {
        next
      }
      
      # Parse JSON request
      request <- fromJSON(line, simplifyVector = FALSE)
      log_info(paste("Received:", substr(line, 1, 100)))
      
      # Handle request
      response <- handle_request(request)
      
      # Send response
      if (!is.null(response)) {
        response_json <- toJSON(response, auto_unbox = TRUE, null = "null")
        writeLines(response_json, stdout_con)
        flush(stdout_con)
        log_info(paste("Sent response"))
      }
      
    }, error = function(e) {
      log_error(paste("Server error:", e$message))
      
      error_response <- list(
        jsonrpc = "2.0",
        id = NULL,
        error = list(
          code = -32700,
          message = paste("Parse error:", e$message)
        )
      )
      
      writeLines(toJSON(error_response, auto_unbox = TRUE), stdout_con)
      flush(stdout_con)
    })
  }
  
  log_info("Server shutting down normally")
}

# Run server
if (!interactive()) {
  main()
}