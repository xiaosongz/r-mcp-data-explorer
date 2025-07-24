#!/usr/bin/env Rscript

#' R MCP Data Explorer Server
#' Main server implementation for Model Context Protocol

# Load required libraries
suppressPackageStartupMessages({
  library(jsonlite)
  library(tidyverse)
})

# Get script directory - handle different execution contexts
get_script_dir <- function() {
  # Try various methods to get script directory
  
  # Method 1: If sourced
  if (exists("ofile", where = sys.frame(1))) {
    return(dirname(sys.frame(1)$ofile))
  }
  
  # Method 2: Command line argument
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg))))
  }
  
  # Method 3: Use current working directory
  # Assuming we're in the R directory
  if (file.exists("server.R")) {
    return(getwd())
  }
  
  # Method 4: Look for server.R in parent directories
  current <- getwd()
  while (current != dirname(current)) {
    server_path <- file.path(current, "R", "server.R")
    if (file.exists(server_path)) {
      return(file.path(current, "R"))
    }
    current <- dirname(current)
  }
  
  # Fallback: Use the known project structure
  return(file.path(dirname(dirname(getwd())), "R"))
}

# Source utilities and tools
source_dir <- function(path, verbose = FALSE) {
  if (!dir.exists(path)) {
    if (verbose) message(paste("Directory not found, skipping:", path))
    return()
  }
  files <- list.files(path, pattern = "\\.R$", full.names = TRUE)
  for (file in files) {
    if (verbose) message(paste("Sourcing:", file))
    source(file)
  }
}

script_dir <- get_script_dir()

# Source all components (logging first!)
source_dir(file.path(script_dir, "utils"))
source_dir(file.path(script_dir, "tools"))
source_dir(file.path(script_dir, "prompts"))

# Initialize logging
log_file <- init_logging()
log_info("Starting R MCP Data Explorer Server")

# Initialize data manager
init_data_manager()

# Server capabilities
SERVER_INFO <- list(
  name = "r-mcp-data-explorer",
  version = "1.0.0",
  description = "MCP server for R data exploration with tidyverse"
)

# Tool definitions
TOOLS <- list(
  load_data = list(
    name = "load_data",
    description = "Load data from CSV, Parquet, Arrow, or DuckDB files",
    inputSchema = list(
      type = "object",
      properties = list(
        path = list(
          type = "string",
          description = "Path to the data file"
        ),
        name = list(
          type = "string",
          description = "Name to assign to the loaded dataset"
        ),
        options = list(
          type = "object",
          description = "Additional loading options",
          properties = list(
            header = list(type = "boolean", default = TRUE),
            delimiter = list(type = "string", default = ","),
            na_strings = list(type = "array", items = list(type = "string"))
          )
        )
      ),
      required = list("path", "name")
    )
  ),
  
  run_tidyverse = list(
    name = "run_tidyverse",
    description = "Execute R code using tidyverse functions on loaded data",
    inputSchema = list(
      type = "object",
      properties = list(
        code = list(
          type = "string",
          description = "R code to execute"
        ),
        dataset = list(
          type = "string",
          description = "Name of the dataset to operate on"
        ),
        return_plot = list(
          type = "boolean",
          description = "Whether to return plot as base64 image",
          default = FALSE
        )
      ),
      required = list("code")
    )
  ),
  
  query_duckdb = list(
    name = "query_duckdb",
    description = "Execute SQL queries on data using DuckDB",
    inputSchema = list(
      type = "object",
      properties = list(
        query = list(
          type = "string",
          description = "SQL query to execute"
        ),
        dataset = list(
          type = "string",
          description = "Name of the dataset to query"
        )
      ),
      required = list("query")
    )
  )
)

# Prompt definitions
PROMPTS <- list(
  explore_data = list(
    name = "explore_data",
    description = "Interactive data exploration workflow",
    arguments = list(
      list(
        name = "dataset_path",
        description = "Path to the dataset file",
        required = TRUE
      )
    )
  )
)

# Handle incoming requests
handle_request <- function(request) {
  log_debug(paste("Handling request:", request$method))
  
  response <- list(
    jsonrpc = "2.0",
    id = request$id
  )
  
  tryCatch({
    if (request$method == "initialize") {
      response$result <- list(
        protocolVersion = "0.1.0",
        capabilities = list(
          tools = list(list = TRUE),
          prompts = list(list = TRUE)
        ),
        serverInfo = SERVER_INFO
      )
      
    } else if (request$method == "initialized") {
      # Server is ready
      log_info("Server initialized successfully")
      return(NULL)  # No response needed
      
    } else if (request$method == "tools/list") {
      response$result <- list(
        tools = unname(TOOLS)
      )
      
    } else if (request$method == "tools/call") {
      tool_name <- request$params$name
      args <- request$params$arguments
      
      log_info(paste("Calling tool:", tool_name))
      
      if (tool_name == "load_data") {
        result <- load_data(args$path, args$name, args$options)
      } else if (tool_name == "run_tidyverse") {
        result <- run_tidyverse(args$code, args$dataset, args$return_plot)
      } else if (tool_name == "query_duckdb") {
        result <- query_duckdb(args$query, args$dataset)
      } else {
        stop(paste("Unknown tool:", tool_name))
      }
      
      response$result <- list(
        content = list(
          list(
            type = "text",
            text = if (is.character(result)) result else toJSON(result, auto_unbox = TRUE)
          )
        )
      )
      
    } else if (request$method == "prompts/list") {
      response$result <- list(
        prompts = unname(PROMPTS)
      )
      
    } else if (request$method == "prompts/get") {
      prompt_name <- request$params$name
      args <- request$params$arguments
      
      if (prompt_name == "explore_data") {
        messages <- get_explore_data_prompt(args$dataset_path)
        response$result <- list(messages = messages)
      } else {
        stop(paste("Unknown prompt:", prompt_name))
      }
      
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
  log_info("R MCP Data Explorer Server starting...")
  
  # Set up connection
  stdin_con <- file("stdin", "r", blocking = TRUE)
  stdout_con <- stdout()
  
  # Handle shutdown gracefully
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
        # EOF reached
        break
      }
      
      # Skip empty lines
      if (nchar(trimws(line)) == 0) {
        next
      }
      
      # Parse JSON request
      request <- fromJSON(line, simplifyVector = FALSE)
      log_debug(paste("Received:", line))
      
      # Handle request
      response <- handle_request(request)
      
      # Send response if not NULL
      if (!is.null(response)) {
        response_json <- toJSON(response, auto_unbox = TRUE)
        writeLines(response_json, stdout_con)
        flush(stdout_con)
        log_debug(paste("Sent:", response_json))
      }
      
    }, error = function(e) {
      log_error(paste("Server error:", e$message))
      
      # Send error response
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