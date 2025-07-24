#' Data Loader Tool
#' Handles loading data from various file formats

# Load required packages
suppressPackageStartupMessages({
  library(readr)
  library(readxl)
  library(jsonlite)
  library(arrow)
  library(duckdb)
})

#' Load data from file
#' @param path File path
#' @param name Dataset name (optional, auto-generated if NULL)
#' @param options Loading options
#' @return Summary information about loaded data
load_data <- function(path, name = NULL, options = list()) {
  log_info(paste("Loading data from:", path))
  
  # Check if file exists
  if (!file.exists(path)) {
    stop(paste("File not found:", path))
  }
  
  # Get file info
  file_info <- file.info(path)
  file_size <- file_info$size
  file_ext <- tolower(tools::file_ext(path))
  
  # Auto-generate name if not provided
  if (is.null(name) || name == "") {
    name <- tools::file_path_sans_ext(basename(path))
    name <- make.names(name)  # Ensure valid R name
  }
  
  # Load based on file type
  data <- NULL
  load_time <- system.time({
    data <- switch(file_ext,
      "csv" = load_csv(path, options),
      "tsv" = load_tsv(path, options),
      "xlsx" = load_excel(path, options),
      "xls" = load_excel(path, options),
      "json" = load_json(path, options),
      "parquet" = load_parquet(path, options),
      "arrow" = load_arrow(path, options),
      "feather" = load_arrow(path, options),
      "duckdb" = load_duckdb_file(path, options),
      "db" = load_duckdb_file(path, options),
      stop(paste("Unsupported file type:", file_ext))
    )
  })
  
  # Store dataset with automatic tier selection
  store_dataset(data, name, path)
  
  # Generate summary
  summary_info <- generate_data_summary(data, name, file_size, load_time[3])
  
  # Format response
  response <- format_load_response(summary_info)
  
  log_info(paste("Successfully loaded", name, 
                 "- Rows:", summary_info$nrow, 
                 "- Cols:", summary_info$ncol))
  
  return(response)
}

#' Load CSV file
load_csv <- function(path, options) {
  # Merge with default options
  opts <- modifyList(list(
    header = TRUE,
    delimiter = ",",
    na_strings = c("", "NA", "NULL", "null", "N/A", "n/a"),
    guess_max = 10000
  ), options)
  
  # Determine if we should use Arrow for large files
  file_size <- file.info(path)$size
  
  if (file_size > .SIZE_THRESHOLD_ARROW) {
    # Use Arrow for large files
    log_info("Using Arrow for large CSV file")
    return(read_csv_arrow(
      path,
      col_names = opts$header,
      delimiter = opts$delimiter,
      na = opts$na_strings,
      as_data_frame = TRUE
    ))
  } else {
    # Use readr for smaller files
    return(read_delim(
      path,
      delim = opts$delimiter,
      col_names = opts$header,
      na = opts$na_strings,
      guess_max = opts$guess_max,
      show_col_types = FALSE
    ))
  }
}

#' Load TSV file
load_tsv <- function(path, options) {
  options$delimiter <- "\t"
  load_csv(path, options)
}

#' Load Excel file
load_excel <- function(path, options) {
  # Merge with default options
  opts <- modifyList(list(
    sheet = 1,
    col_names = TRUE,
    na = c("", "NA", "NULL", "null", "N/A", "n/a"),
    skip = 0
  ), options)
  
  # Check file size
  file_size <- file.info(path)$size
  
  if (file_size > 50 * 1024 * 1024) {  # 50MB
    warning("Large Excel file detected. Consider converting to CSV or Parquet for better performance.")
  }
  
  read_excel(
    path,
    sheet = opts$sheet,
    col_names = opts$col_names,
    na = opts$na,
    skip = opts$skip
  )
}

#' Load JSON file
load_json <- function(path, options) {
  # Read JSON
  json_data <- fromJSON(path, flatten = TRUE)
  
  # Convert to data frame if possible
  if (is.list(json_data) && !is.data.frame(json_data)) {
    if (length(json_data) > 0 && all(sapply(json_data, is.list))) {
      # Try to convert to data frame
      json_data <- bind_rows(json_data)
    }
  }
  
  as_tibble(json_data)
}

#' Load Parquet file
load_parquet <- function(path, options) {
  # Use Arrow to read Parquet
  read_parquet(path)
}

#' Load Arrow/Feather file
load_arrow <- function(path, options) {
  # Check if it's a dataset directory
  if (dir.exists(path)) {
    # Open as Arrow dataset
    open_dataset(path)
  } else {
    # Read as single file
    read_feather(path)
  }
}

#' Load DuckDB database file
load_duckdb_file <- function(path, options) {
  # Connect to DuckDB file
  conn <- dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(dbDisconnect(conn))
  
  # Get tables
  tables <- dbListTables(conn)
  
  if (length(tables) == 0) {
    stop("No tables found in DuckDB file")
  }
  
  # Use first table by default or specified table
  table_name <- options$table %||% tables[1]
  
  if (!table_name %in% tables) {
    stop(paste("Table not found:", table_name))
  }
  
  # Read table
  dbReadTable(conn, table_name)
}

#' Generate data summary
generate_data_summary <- function(data, name, file_size, load_time) {
  # Basic info
  info <- list(
    name = name,
    nrow = nrow(data),
    ncol = ncol(data),
    file_size = file_size,
    load_time = load_time,
    backend = .DATA_STORAGE$metadata[[name]]$backend
  )
  
  # Column information
  col_info <- tibble(
    column = names(data),
    type = sapply(data, function(x) class(x)[1]),
    missing = sapply(data, function(x) sum(is.na(x))),
    missing_pct = round(100 * missing / info$nrow, 2)
  )
  
  info$columns <- col_info
  
  # Numeric columns summary
  numeric_cols <- names(data)[sapply(data, is.numeric)]
  if (length(numeric_cols) > 0) {
    numeric_summary <- data %>%
      select(all_of(numeric_cols)) %>%
      summarise(across(everything(), list(
        mean = ~mean(.x, na.rm = TRUE),
        sd = ~sd(.x, na.rm = TRUE),
        min = ~min(.x, na.rm = TRUE),
        max = ~max(.x, na.rm = TRUE)
      ), .names = "{.col}_{.fn}")) %>%
      pivot_longer(everything(), names_to = c("column", "stat"), 
                   names_sep = "_(?=[^_]+$)") %>%
      pivot_wider(names_from = stat, values_from = value)
    
    info$numeric_summary <- numeric_summary
  }
  
  # Sample rows
  sample_size <- min(5, nrow(data))
  if (inherits(data, "tbl_lazy")) {
    info$sample <- data %>% head(sample_size) %>% collect()
  } else {
    info$sample <- head(data, sample_size)
  }
  
  return(info)
}

#' Format load response
format_load_response <- function(info) {
  lines <- character()
  
  # Header
  lines <- c(lines, paste0("Successfully loaded dataset '", info$name, "'"))
  lines <- c(lines, "")
  
  # Basic info
  lines <- c(lines, "Dataset Information:")
  lines <- c(lines, paste0("  Rows: ", format(info$nrow, big.mark = ",")))
  lines <- c(lines, paste0("  Columns: ", info$ncol))
  lines <- c(lines, paste0("  File size: ", format_bytes(info$file_size)))
  lines <- c(lines, paste0("  Load time: ", round(info$load_time, 2), " seconds"))
  lines <- c(lines, paste0("  Storage backend: ", info$backend))
  lines <- c(lines, "")
  
  # Column info
  lines <- c(lines, "Column Information:")
  col_table <- info$columns %>%
    mutate(info = paste0(column, " (", type, ")", 
                        ifelse(missing > 0, paste0(" - ", missing_pct, "% missing"), "")))
  
  for (i in 1:nrow(col_table)) {
    lines <- c(lines, paste0("  ", col_table$info[i]))
  }
  lines <- c(lines, "")
  
  # Numeric summary
  if (!is.null(info$numeric_summary)) {
    lines <- c(lines, "Numeric Column Summary:")
    for (i in 1:nrow(info$numeric_summary)) {
      row <- info$numeric_summary[i,]
      lines <- c(lines, paste0("  ", row$column, ":"))
      lines <- c(lines, paste0("    Mean: ", round(row$mean, 2), 
                              ", SD: ", round(row$sd, 2)))
      lines <- c(lines, paste0("    Range: [", round(row$min, 2), 
                              ", ", round(row$max, 2), "]"))
    }
    lines <- c(lines, "")
  }
  
  # Sample data
  lines <- c(lines, "Sample Data (first 5 rows):")
  sample_output <- capture.output(print(info$sample, n = 5, width = 80))
  lines <- c(lines, sample_output)
  lines <- c(lines, "")
  
  # Helper functions
  lines <- c(lines, "Available helper functions:")
  lines <- c(lines, paste0("  ", info$name, "_glimpse()     # View structure"))
  lines <- c(lines, paste0("  ", info$name, "_summary()    # Detailed summary"))
  lines <- c(lines, paste0("  ", info$name, "_slice_sample(n)  # Random sample"))
  lines <- c(lines, paste0("  ", info$name, "_to_duckdb()  # Convert to DuckDB"))
  
  return(paste(lines, collapse = "\n"))
}

#' Format bytes to human readable
format_bytes <- function(bytes) {
  units <- c("B", "KB", "MB", "GB", "TB")
  unit_index <- 1
  size <- bytes
  
  while (size >= 1024 && unit_index < length(units)) {
    size <- size / 1024
    unit_index <- unit_index + 1
  }
  
  paste0(round(size, 2), " ", units[unit_index])
}