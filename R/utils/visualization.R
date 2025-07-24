#' Visualization utilities
#' Handles plot capture and conversion to base64

# Load required packages
suppressPackageStartupMessages({
  library(ggplot2)
  library(base64enc)
})

#' Capture current plot as base64
#' @param width Plot width in inches
#' @param height Plot height in inches
#' @param dpi Resolution
#' @return Base64 encoded image string
capture_plot_base64 <- function(width = 7, height = 5, dpi = 150) {
  # Create temporary file
  temp_file <- tempfile(fileext = ".png")
  on.exit(unlink(temp_file))
  
  # Check if there's a current plot
  if (dev.cur() == 1) {
    return(NULL)  # No plot device open
  }
  
  # Save current device
  current_dev <- dev.cur()
  
  # Create PNG device
  png(temp_file, width = width, height = height, units = "in", res = dpi)
  
  # Copy plot
  dev.set(current_dev)
  dev.copy(png, filename = temp_file, width = width, height = height, units = "in", res = dpi)
  dev.off()
  
  # Read and encode
  if (file.exists(temp_file)) {
    base64_str <- base64encode(temp_file)
    return(paste0("data:image/png;base64,", base64_str))
  }
  
  return(NULL)
}

#' Capture ggplot as base64
#' @param plot ggplot object
#' @param width Plot width in inches
#' @param height Plot height in inches
#' @param dpi Resolution
#' @return Base64 encoded image string
capture_ggplot_base64 <- function(plot, width = 7, height = 5, dpi = 150) {
  if (!inherits(plot, "ggplot")) {
    return(NULL)
  }
  
  # Create temporary file
  temp_file <- tempfile(fileext = ".png")
  on.exit(unlink(temp_file))
  
  # Save plot
  ggsave(temp_file, plot = plot, width = width, height = height, dpi = dpi)
  
  # Read and encode
  if (file.exists(temp_file)) {
    base64_str <- base64encode(temp_file)
    return(paste0("data:image/png;base64,", base64_str))
  }
  
  return(NULL)
}

#' Set up plot capture hooks
#' @param env Environment to modify
setup_plot_capture <- function(env) {
  # Store captured plots
  assign(".captured_plots", list(), envir = env)
  
  # Override plot function
  assign("plot", function(...) {
    # Call original plot
    graphics::plot(...)
    
    # Capture plot
    plot_base64 <- capture_plot_base64()
    if (!is.null(plot_base64)) {
      plots <- get(".captured_plots", envir = env)
      plots[[length(plots) + 1]] <- plot_base64
      assign(".captured_plots", plots, envir = env)
    }
  }, envir = env)
  
  # Override print.ggplot
  assign("print.ggplot", function(x, ...) {
    # Call original print
    ggplot2:::print.ggplot(x, ...)
    
    # Capture plot
    plot_base64 <- capture_ggplot_base64(x)
    if (!is.null(plot_base64)) {
      plots <- get(".captured_plots", envir = env)
      plots[[length(plots) + 1]] <- plot_base64
      assign(".captured_plots", plots, envir = env)
    }
  }, envir = env)
}

#' Create plot capture device
#' @return List with device functions
create_plot_device <- function() {
  # Storage for plots
  plots <- list()
  
  # Custom device functions
  list(
    start = function(width = 7, height = 5, dpi = 150) {
      # Create temporary file
      temp_file <- tempfile(fileext = ".png")
      png(temp_file, width = width, height = height, units = "in", res = dpi)
      
      # Store file path
      plots[[length(plots) + 1]] <<- temp_file
      
      return(temp_file)
    },
    
    finish = function() {
      # Close device
      dev.off()
      
      # Get last plot file
      if (length(plots) > 0) {
        plot_file <- plots[[length(plots)]]
        if (file.exists(plot_file)) {
          # Read and encode
          base64_str <- base64encode(plot_file)
          # Clean up
          unlink(plot_file)
          return(paste0("data:image/png;base64,", base64_str))
        }
      }
      
      return(NULL)
    },
    
    get_all = function() {
      # Get all captured plots
      all_plots <- list()
      
      for (plot_file in plots) {
        if (file.exists(plot_file)) {
          base64_str <- base64encode(plot_file)
          all_plots[[length(all_plots) + 1]] <- paste0("data:image/png;base64,", base64_str)
          unlink(plot_file)
        }
      }
      
      plots <<- list()  # Clear
      return(all_plots)
    }
  )
}

#' Convert plotly to static image
#' @param plotly_obj Plotly object
#' @param width Width in pixels
#' @param height Height in pixels
#' @return Base64 encoded image or NULL
plotly_to_base64 <- function(plotly_obj, width = 700, height = 500) {
  # Check if kaleido is available
  if (!requireNamespace("plotly", quietly = TRUE)) {
    return(NULL)
  }
  
  tryCatch({
    # Create temporary file
    temp_file <- tempfile(fileext = ".png")
    on.exit(unlink(temp_file))
    
    # Export plotly to static image
    plotly::orca(plotly_obj, file = temp_file, width = width, height = height)
    
    # Read and encode
    if (file.exists(temp_file)) {
      base64_str <- base64encode(temp_file)
      return(paste0("data:image/png;base64,", base64_str))
    }
    
    return(NULL)
    
  }, error = function(e) {
    log_warn(paste("Failed to convert plotly:", e$message))
    return(NULL)
  })
}

#' Format plot output for MCP response
#' @param plots List of base64 encoded plots
#' @return Formatted string for response
format_plot_output <- function(plots) {
  if (length(plots) == 0) return("")
  
  output <- character()
  for (i in seq_along(plots)) {
    output <- c(output, paste0("\n[Plot ", i, "]"))
    output <- c(output, plots[[i]])
  }
  
  return(paste(output, collapse = "\n"))
}