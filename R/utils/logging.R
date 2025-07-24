#' Logging utilities for MCP server
#' Provides comprehensive logging for debugging MCP communication

# Global logging variables
.LOG_FILE <- NULL
.LOG_LEVEL <- "INFO"

#' Initialize logging
#' @return Path to log file
init_logging <- function() {
  # Create logs directory if it doesn't exist
  log_dir <- "logs"
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  
  # Create timestamped log file
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
  .LOG_FILE <<- file.path(log_dir, paste0("r-mcp-server-", timestamp, ".log"))
  
  # Set log level from environment
  if (Sys.getenv("R_MCP_LOG_LEVEL") != "") {
    .LOG_LEVEL <<- Sys.getenv("R_MCP_LOG_LEVEL")
  }
  
  # Write initial log entry
  log_info("=== R MCP Data Explorer Server Log ===")
  log_info(paste("Log level:", .LOG_LEVEL))
  log_info(paste("R version:", R.version.string))
  log_info(paste("Platform:", Sys.info()["sysname"]))
  
  return(.LOG_FILE)
}

#' Write log entry
#' @param level Log level
#' @param message Log message
log_write <- function(level, message) {
  if (is.null(.LOG_FILE)) return()
  
  # Check log level
  levels <- c("DEBUG" = 1, "INFO" = 2, "WARN" = 3, "ERROR" = 4)
  if (levels[level] < levels[.LOG_LEVEL]) return()
  
  # Format log entry
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  entry <- paste0("[", timestamp, "] [", level, "] ", message, "\n")
  
  # Write to file
  cat(entry, file = .LOG_FILE, append = TRUE)
}

#' Log debug message
log_debug <- function(message) {
  log_write("DEBUG", message)
}

#' Log info message
log_info <- function(message) {
  log_write("INFO", message)
}

#' Log warning message
log_warn <- function(message) {
  log_write("WARN", message)
}

#' Log error message
log_error <- function(message) {
  log_write("ERROR", message)
  
  # Also capture traceback on errors
  tb <- traceback(max.lines = 5)
  if (length(tb) > 0) {
    log_write("ERROR", "Traceback:")
    for (i in seq_along(tb)) {
      log_write("ERROR", paste("  ", tb[[i]]))
    }
  }
}