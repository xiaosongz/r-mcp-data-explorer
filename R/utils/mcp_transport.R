#' MCP Transport Layer
#' Handles stdio communication for MCP protocol

# Buffer for incomplete messages
.MESSAGE_BUFFER <- ""

#' Send MCP response
#' @param response Response object to send
#' @param con Output connection (default: stdout)
send_response <- function(response, con = stdout()) {
  # Convert to JSON
  json_str <- jsonlite::toJSON(response, auto_unbox = TRUE, null = "null")
  
  # Handle Windows UTF-8 encoding
  if (.Platform$OS.type == "windows") {
    # Ensure UTF-8 encoding
    Encoding(json_str) <- "UTF-8"
  }
  
  # Write to stdout
  writeLines(json_str, con = con, useBytes = TRUE)
  flush(con)
  
  log_debug(paste("Sent response:", substr(json_str, 1, 200)))
}

#' Read MCP request
#' @param con Input connection
#' @return Parsed request or NULL
read_request <- function(con) {
  tryCatch({
    # Read line from stdin
    line <- readLines(con, n = 1, warn = FALSE, encoding = "UTF-8")
    
    if (length(line) == 0) {
      return(NULL)  # EOF
    }
    
    # Skip empty lines
    if (nchar(trimws(line)) == 0) {
      return(list(type = "empty"))
    }
    
    # Handle potential BOM on Windows
    if (.Platform$OS.type == "windows") {
      # Remove UTF-8 BOM if present
      if (substr(line, 1, 1) == "\ufeff") {
        line <- substr(line, 2, nchar(line))
      }
    }
    
    # Try to parse JSON
    request <- jsonlite::fromJSON(line, simplifyVector = FALSE)
    log_debug(paste("Received request:", line))
    
    return(request)
    
  }, error = function(e) {
    log_error(paste("Error reading request:", e$message))
    return(list(type = "error", message = e$message))
  })
}

#' Handle partial messages (for future Content-Length support)
#' @param line Input line
#' @return Complete message or NULL
handle_partial_message <- function(line) {
  # Add to buffer
  .MESSAGE_BUFFER <<- paste0(.MESSAGE_BUFFER, line)
  
  # Check if we have a complete JSON object
  tryCatch({
    # Try to parse
    msg <- jsonlite::fromJSON(.MESSAGE_BUFFER, simplifyVector = FALSE)
    
    # Success - clear buffer and return
    .MESSAGE_BUFFER <<- ""
    return(msg)
    
  }, error = function(e) {
    # Not complete yet
    return(NULL)
  })
}

#' Create error response
#' @param id Request ID
#' @param code Error code
#' @param message Error message
#' @return Error response object
create_error_response <- function(id = NULL, code = -32603, message = "Internal error") {
  list(
    jsonrpc = "2.0",
    id = id,
    error = list(
      code = code,
      message = message
    )
  )
}

#' Create success response
#' @param id Request ID
#' @param result Result object
#' @return Success response object
create_success_response <- function(id, result) {
  list(
    jsonrpc = "2.0",
    id = id,
    result = result
  )
}

#' Validate MCP request
#' @param request Request object
#' @return TRUE if valid, error message if not
validate_request <- function(request) {
  # Check required fields
  if (is.null(request$jsonrpc) || request$jsonrpc != "2.0") {
    return("Invalid JSON-RPC version")
  }
  
  if (is.null(request$method)) {
    return("Missing method field")
  }
  
  # ID is optional for notifications
  # Params are optional
  
  return(TRUE)
}

#' Setup stdio connections with proper encoding
#' @return List with stdin and stdout connections
setup_stdio_connections <- function() {
  # Configure stdin
  stdin_con <- file("stdin", "r", blocking = TRUE, encoding = "UTF-8")
  
  # Configure stdout - use binary mode on Windows
  if (.Platform$OS.type == "windows") {
    stdout_con <- stdout()
    # Force UTF-8 output
    Sys.setlocale("LC_CTYPE", "en_US.UTF-8")
  } else {
    stdout_con <- stdout()
  }
  
  list(
    stdin = stdin_con,
    stdout = stdout_con
  )
}