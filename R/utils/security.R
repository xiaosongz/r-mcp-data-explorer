#' Security utilities for sandboxed R execution
#' Provides safe execution environment for user code

# Load required packages
suppressPackageStartupMessages({
  library(callr)
})

# Security configuration
.SECURITY_CONFIG <- list(
  timeout = 30,  # seconds
  memory_limit = "2G",
  allowed_packages = c(
    "tidyverse", "dplyr", "tidyr", "ggplot2", "readr", 
    "purrr", "tibble", "stringr", "forcats", "lubridate",
    "arrow", "duckdb", "DBI", "dbplyr",
    "plotly", "DT", "skimr", "janitor", "scales",
    "glue", "rlang", "magrittr"
  ),
  blocked_functions = c(
    "system", "system2", "shell", "shell.exec",
    "file.remove", "unlink", "file.rename", "file.copy",
    "download.file", "install.packages", "remove.packages",
    "source", "sys.source", "library.dynam",
    "dyn.load", "dyn.unload", ".Call", ".C", ".Fortran",
    "setwd", "q", "quit", "stop"
  ),
  allowed_paths = c("data/", tempdir())
)

#' Create sandboxed environment
#' @param datasets Named list of available datasets
#' @return Environment for code execution
create_sandbox_env <- function(datasets = list()) {
  # Create new environment
  env <- new.env(parent = globalenv())
  
  # Load allowed packages
  for (pkg in .SECURITY_CONFIG$allowed_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      # Attach package to environment
      ns <- getNamespace(pkg)
      exports <- getNamespaceExports(pkg)
      
      for (name in exports) {
        # Skip blocked functions
        if (name %in% .SECURITY_CONFIG$blocked_functions) next
        
        # Add to environment
        assign(name, get(name, ns), envir = env)
      }
    }
  }
  
  # Add datasets to environment
  for (name in names(datasets)) {
    assign(name, datasets[[name]], envir = env)
  }
  
  # Add safe utility functions
  add_safe_utilities(env)
  
  # Override dangerous functions
  override_dangerous_functions(env)
  
  return(env)
}

#' Add safe utility functions to environment
add_safe_utilities <- function(env) {
  # Safe print function
  assign("print", function(x, ...) {
    # Limit output size
    output <- capture.output(base::print(x, ...))
    if (length(output) > 1000) {
      output <- c(output[1:1000], "... [output truncated]")
    }
    cat(output, sep = "\n")
  }, envir = env)
  
  # Safe file reading (restricted paths)
  assign("read_csv", function(file, ...) {
    if (!is_safe_path(file)) {
      stop("Access denied: File outside allowed directories")
    }
    readr::read_csv(file, ...)
  }, envir = env)
  
  # Add helper for getting datasets
  assign("get_data", function(name) {
    get_dataset(name)
  }, envir = env)
  
  # Add list datasets function
  assign("list_data", function() {
    list_datasets()
  }, envir = env)
}

#' Override dangerous functions
override_dangerous_functions <- function(env) {
  # Block all dangerous functions
  for (fn in .SECURITY_CONFIG$blocked_functions) {
    assign(fn, function(...) {
      stop(paste("Function", fn, "is not allowed in sandbox"))
    }, envir = env)
  }
  
  # Override file operations with safe versions
  assign("list.files", function(path = ".", ...) {
    if (!is_safe_path(path)) {
      stop("Access denied: Path outside allowed directories")
    }
    base::list.files(path, ...)
  }, envir = env)
  
  assign("dir", function(path = ".", ...) {
    if (!is_safe_path(path)) {
      stop("Access denied: Path outside allowed directories")
    }
    base::dir(path, ...)
  }, envir = env)
}

#' Check if path is safe
is_safe_path <- function(path) {
  # Normalize path
  norm_path <- normalizePath(path, mustWork = FALSE)
  
  # Check against allowed paths
  for (allowed in .SECURITY_CONFIG$allowed_paths) {
    allowed_norm <- normalizePath(allowed, mustWork = FALSE)
    if (startsWith(norm_path, allowed_norm)) {
      return(TRUE)
    }
  }
  
  return(FALSE)
}

#' Execute code in sandbox using callr
#' @param code Code to execute
#' @param env Environment with datasets
#' @param timeout Execution timeout
#' @return List with result, output, errors, plots
execute_sandboxed <- function(code, env = NULL, timeout = 30) {
  # Create temporary script file
  script_file <- tempfile(fileext = ".R")
  on.exit(unlink(script_file))
  
  # Prepare code with capture
  wrapped_code <- sprintf('
# Load packages
suppressPackageStartupMessages({
  %s
})

# Capture output and plots
output_capture <- character()
plot_files <- character()
errors <- character()
result <- NULL

# Override plot devices
png_orig <- grDevices::png
assign("png", function(filename = NULL, ...) {
  if (is.null(filename)) {
    filename <- tempfile(fileext = ".png")
  }
  plot_files <<- c(plot_files, filename)
  png_orig(filename, ...)
}, envir = .GlobalEnv)

# Capture output
sink_file <- textConnection("output_capture", "w", local = TRUE)
sink(sink_file)
sink(sink_file, type = "message")

# Execute code
tryCatch({
  result <- eval(parse(text = %s))
}, error = function(e) {
  errors <<- c(errors, e$message)
}, warning = function(w) {
  output_capture <<- c(output_capture, paste("Warning:", w$message))
})

# Restore output
sink(type = "message")
sink()
close(sink_file)

# Return results
list(
  result = result,
  output = output_capture,
  errors = errors,
  plots = plot_files
)
', 
    paste(sprintf('library(%s)', .SECURITY_CONFIG$allowed_packages), collapse = '\n'),
    deparse(code)
  )
  
  # Write script
  writeLines(wrapped_code, script_file)
  
  # Execute with callr
  tryCatch({
    # Run in subprocess with timeout
    result <- callr::r(
      function(script) {
        source(script, local = TRUE)
      },
      args = list(script = script_file),
      timeout = timeout,
      error = "error"
    )
    
    # Read plot files if any
    plots <- list()
    if (length(result$plots) > 0) {
      for (plot_file in result$plots) {
        if (file.exists(plot_file)) {
          plots[[basename(plot_file)]] <- base64enc::base64encode(plot_file)
          unlink(plot_file)
        }
      }
    }
    
    # Add plots to result
    result$plots <- plots
    
    return(result)
    
  }, error = function(e) {
    if (grepl("timeout", e$message, ignore.case = TRUE)) {
      return(list(
        result = NULL,
        output = character(),
        errors = "Execution timeout exceeded",
        plots = list()
      ))
    } else {
      return(list(
        result = NULL,
        output = character(),
        errors = e$message,
        plots = list()
      ))
    }
  })
}

#' Validate code before execution
#' @param code Code to validate
#' @return TRUE if valid, error message otherwise
validate_code <- function(code) {
  # Parse code to check syntax
  tryCatch({
    parsed <- parse(text = code)
    
    # Check for dangerous patterns
    code_str <- deparse(parsed)
    
    # Check for system calls
    if (grepl("system\\s*\\(|system2\\s*\\(|shell\\s*\\(", code_str)) {
      return("System calls are not allowed")
    }
    
    # Check for file operations outside allowed paths
    if (grepl("setwd\\s*\\(|file\\.remove\\s*\\(|unlink\\s*\\(", code_str)) {
      return("File system modifications are not allowed")
    }
    
    # Check for package installation
    if (grepl("install\\.packages\\s*\\(|remove\\.packages\\s*\\(", code_str)) {
      return("Package installation is not allowed")
    }
    
    return(TRUE)
    
  }, error = function(e) {
    return(paste("Syntax error:", e$message))
  })
}