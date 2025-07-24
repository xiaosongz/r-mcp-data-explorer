#' Script Runner Tool
#' Executes R code in a sandboxed environment with tidyverse

#' Run tidyverse code
#' @param code R code to execute
#' @param dataset Optional dataset name to use as primary data
#' @param return_plot Whether to return plots as base64
#' @return Execution results
run_tidyverse <- function(code, dataset = NULL, return_plot = TRUE) {
  log_info("Executing tidyverse code")
  log_debug(paste("Code:", substr(code, 1, 100), "..."))
  
  # Validate code first
  validation <- validate_code(code)
  if (!isTRUE(validation)) {
    stop(validation)
  }
  
  # For now, use simple execution without full sandboxing
  # Full sandboxing with callr will be implemented in production
  result <- execute_simple_sandbox(code, dataset, return_plot)
  
  # Format response
  response <- format_execution_response(result)
  
  log_info("Code execution completed")
  
  return(response)
}

#' Simple sandboxed execution
#' @param code Code to execute
#' @param dataset Primary dataset name
#' @param return_plot Whether to capture plots
execute_simple_sandbox <- function(code, dataset = NULL, return_plot = TRUE) {
  # Initialize result structure
  result <- list(
    success = TRUE,
    output = character(),
    error = character(),
    result = NULL,
    plots = list()
  )
  
  # Create execution environment
  exec_env <- new.env(parent = globalenv())
  
  # Load all datasets into environment
  all_datasets <- list_datasets()
  for (name in all_datasets) {
    assign(name, get_dataset(name), envir = exec_env)
    
    # Add helper functions
    assign(paste0(name, "_glimpse"), 
           eval(parse(text = sprintf("function() glimpse(%s)", name))),
           envir = exec_env)
    
    assign(paste0(name, "_summary"),
           eval(parse(text = sprintf("function() summary(%s)", name))),
           envir = exec_env)
  }
  
  # Add primary dataset as 'data' if specified
  if (!is.null(dataset) && dataset %in% all_datasets) {
    assign("data", get_dataset(dataset), envir = exec_env)
  }
  
  # Add utility functions
  assign("list_data", list_datasets, envir = exec_env)
  assign("get_data", get_dataset, envir = exec_env)
  
  # Set up plot capture if needed
  if (return_plot) {
    # Save current device
    old_dev <- dev.cur()
    
    # Create temporary file for plots
    plot_files <- character()
    
    # Override plot function in environment
    assign("plot", function(...) {
      temp_file <- tempfile(fileext = ".png")
      png(temp_file, width = 800, height = 600)
      graphics::plot(...)
      dev.off()
      plot_files <<- c(plot_files, temp_file)
      invisible()
    }, envir = exec_env)
  }
  
  # Capture output
  output_capture <- character()
  output_conn <- textConnection("output_capture", "w", local = TRUE)
  
  sink(output_conn)
  sink(output_conn, type = "message")
  
  # Execute code
  tryCatch({
    # Parse and evaluate
    parsed <- parse(text = code)
    result$result <- eval(parsed, envir = exec_env)
    
    # Check if result is a ggplot
    if (inherits(result$result, "ggplot") && return_plot) {
      temp_file <- tempfile(fileext = ".png")
      ggsave(temp_file, plot = result$result, width = 8, height = 6, dpi = 150)
      plot_files <- c(plot_files, temp_file)
    }
    
  }, error = function(e) {
    result$success <- FALSE
    result$error <- e$message
  })
  
  # Restore output
  sink(type = "message")
  sink()
  close(output_conn)
  
  result$output <- output_capture
  
  # Process plot files
  if (return_plot && exists("plot_files")) {
    for (plot_file in plot_files) {
      if (file.exists(plot_file)) {
        encoded <- base64enc::base64encode(plot_file)
        result$plots[[length(result$plots) + 1]] <- paste0("data:image/png;base64,", encoded)
        unlink(plot_file)
      }
    }
  }
  
  return(result)
}

#' Format execution response
format_execution_response <- function(result) {
  lines <- character()
  
  # Check if execution was successful
  if (!result$success) {
    lines <- c(lines, "Error in code execution:")
    lines <- c(lines, result$error)
    return(paste(lines, collapse = "\n"))
  }
  
  # Add console output
  if (length(result$output) > 0) {
    lines <- c(lines, "Console Output:")
    lines <- c(lines, paste(rep("=", 50), collapse = ""))
    lines <- c(lines, result$output)
    lines <- c(lines, "")
  }
  
  # Add result if not NULL
  if (!is.null(result$result)) {
    lines <- c(lines, "Result:")
    lines <- c(lines, paste(rep("=", 50), collapse = ""))
    
    # Format based on type
    if (is.data.frame(result$result)) {
      # Show data frame preview
      preview <- capture.output(print(result$result, n = 20))
      lines <- c(lines, preview)
    } else if (inherits(result$result, "ggplot")) {
      lines <- c(lines, "[ggplot object returned]")
    } else {
      # Generic output
      output <- capture.output(print(result$result))
      if (length(output) > 100) {
        output <- c(output[1:100], "... [output truncated]")
      }
      lines <- c(lines, output)
    }
    lines <- c(lines, "")
  }
  
  # Add plots
  if (length(result$plots) > 0) {
    lines <- c(lines, "Plots:")
    lines <- c(lines, paste(rep("=", 50), collapse = ""))
    
    for (i in seq_along(result$plots)) {
      if (!is.null(result$plots[[i]])) {
        lines <- c(lines, paste0("[Plot ", i, "]"))
        lines <- c(lines, result$plots[[i]])
        lines <- c(lines, "")
      }
    }
  }
  
  return(paste(lines, collapse = "\n"))
}