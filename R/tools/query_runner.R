#' Query Runner Tool
#' Executes SQL queries using DuckDB

#' Run DuckDB query
#' @param query SQL query to execute
#' @param dataset Optional specific dataset to query
#' @return Query results
query_duckdb <- function(query, dataset = NULL) {
  log_info("Executing DuckDB query")
  log_debug(paste("Query:", substr(query, 1, 200), "..."))
  
  # Validate query
  if (!is_safe_query(query)) {
    stop("Query contains potentially unsafe operations")
  }
  
  # Get DuckDB connection
  conn <- .DATA_STORAGE$duckdb_conn
  if (is.null(conn)) {
    stop("DuckDB connection not initialized")
  }
  
  # Ensure all datasets are available in DuckDB
  ensure_datasets_in_duckdb(dataset)
  
  # Execute query
  query_result <- execute_query(conn, query)
  
  # Format response
  response <- format_query_response(query_result)
  
  log_info("Query execution completed")
  
  return(response)
}

#' Check if query is safe
is_safe_query <- function(query) {
  # Convert to lowercase for checking
  query_lower <- tolower(query)
  
  # List of dangerous operations
  dangerous_patterns <- c(
    "drop\\s+table",
    "drop\\s+database", 
    "drop\\s+schema",
    "create\\s+database",
    "alter\\s+database",
    "truncate",
    "delete\\s+from",
    "insert\\s+into",
    "update\\s+.*\\s+set",
    "grant",
    "revoke",
    "create\\s+user",
    "alter\\s+user",
    "drop\\s+user"
  )
  
  # Check for dangerous patterns
  for (pattern in dangerous_patterns) {
    if (grepl(pattern, query_lower)) {
      log_warn(paste("Unsafe query pattern detected:", pattern))
      return(FALSE)
    }
  }
  
  return(TRUE)
}

#' Ensure datasets are available in DuckDB
ensure_datasets_in_duckdb <- function(specific_dataset = NULL) {
  conn <- .DATA_STORAGE$duckdb_conn
  existing_tables <- dbListTables(conn)
  
  if (!is.null(specific_dataset)) {
    # Ensure specific dataset is in DuckDB
    if (!specific_dataset %in% existing_tables) {
      transfer_to_duckdb(specific_dataset)
    }
  } else {
    # Ensure all datasets are available
    all_datasets <- list_datasets()
    
    for (name in all_datasets) {
      if (!name %in% existing_tables) {
        transfer_to_duckdb(name)
      }
    }
  }
}

#' Transfer dataset to DuckDB
transfer_to_duckdb <- function(name) {
  log_info(paste("Transferring", name, "to DuckDB for SQL access"))
  
  # Get dataset
  data <- get_dataset(name)
  if (is.null(data)) {
    warning(paste("Dataset not found:", name))
    return()
  }
  
  # Get metadata
  meta <- get_dataset_info(name)
  
  if (meta$backend == "duckdb") {
    # Already in DuckDB
    return()
  }
  
  conn <- .DATA_STORAGE$duckdb_conn
  
  if (meta$backend == "arrow") {
    # Convert Arrow to DuckDB
    if (inherits(data, "Table")) {
      # Arrow Table - write directly
      arrow::write_dataset(data, 
                          tempfile(fileext = ".parquet"),
                          format = "parquet")
      dbExecute(conn, sprintf(
        "CREATE OR REPLACE TABLE %s AS SELECT * FROM read_parquet('%s')",
        name, tempfile(fileext = ".parquet")
      ))
    } else {
      # Collect and write
      dbWriteTable(conn, name, collect(data), overwrite = TRUE)
    }
  } else {
    # Tibble - write directly
    dbWriteTable(conn, name, data, overwrite = TRUE)
  }
  
  log_info(paste("Successfully transferred", name, "to DuckDB"))
}

#' Execute query with timing
execute_query <- function(conn, query) {
  # Time the query
  start_time <- Sys.time()
  
  result <- tryCatch({
    # Execute query
    res <- dbGetQuery(conn, query)
    
    end_time <- Sys.time()
    execution_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
    
    list(
      success = TRUE,
      data = as_tibble(res),
      execution_time = execution_time,
      row_count = nrow(res),
      col_count = ncol(res)
    )
    
  }, error = function(e) {
    list(
      success = FALSE,
      error = e$message,
      execution_time = as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    )
  })
  
  return(result)
}

#' Format query response
format_query_response <- function(result) {
  lines <- character()
  
  if (!result$success) {
    lines <- c(lines, "Query Error:")
    lines <- c(lines, result$error)
    lines <- c(lines, "")
    lines <- c(lines, paste("Execution time:", round(result$execution_time, 3), "seconds"))
    return(paste(lines, collapse = "\n"))
  }
  
  # Success header
  lines <- c(lines, "Query executed successfully")
  lines <- c(lines, "")
  
  # Execution stats
  lines <- c(lines, "Execution Statistics:")
  lines <- c(lines, paste0("  Rows returned: ", format(result$row_count, big.mark = ",")))
  lines <- c(lines, paste0("  Columns: ", result$col_count))
  lines <- c(lines, paste0("  Execution time: ", round(result$execution_time, 3), " seconds"))
  lines <- c(lines, "")
  
  # Results
  if (result$row_count > 0) {
    lines <- c(lines, "Results:")
    lines <- c(lines, "=" * 50)
    
    # Limit display rows
    display_rows <- min(result$row_count, 100)
    if (result$row_count > display_rows) {
      lines <- c(lines, paste("(Showing first", display_rows, "of", 
                             format(result$row_count, big.mark = ","), "rows)"))
    }
    
    # Format data
    data_output <- capture.output(
      print(result$data, n = display_rows, width = 120)
    )
    lines <- c(lines, data_output)
    
    if (result$row_count > display_rows) {
      lines <- c(lines, "... [additional rows not shown]")
    }
  } else {
    lines <- c(lines, "No results returned")
  }
  
  return(paste(lines, collapse = "\n"))
}

#' Get available tables for query
get_query_tables <- function() {
  conn <- .DATA_STORAGE$duckdb_conn
  if (is.null(conn)) return(character())
  
  # Get DuckDB tables
  duckdb_tables <- dbListTables(conn)
  
  # Get all available datasets
  all_datasets <- list_datasets()
  
  # Return union
  unique(c(duckdb_tables, all_datasets))
}

#' Generate SQL from dplyr code (helper)
#' @param dplyr_code dplyr pipeline as string
#' @return SQL query
dplyr_to_sql <- function(dplyr_code) {
  # This is a helper that could be expanded
  # For now, just inform user to use show_query()
  
  return("To see SQL for dplyr code, use show_query() on your pipeline")
}

#' Common SQL templates
get_sql_templates <- function() {
  list(
    summary = "SELECT COUNT(*) as row_count, COUNT(DISTINCT {column}) as unique_values FROM {table}",
    
    groupby = "SELECT {group_col}, COUNT(*) as count, AVG({numeric_col}) as avg_value 
               FROM {table} 
               GROUP BY {group_col} 
               ORDER BY count DESC",
    
    join = "SELECT * 
            FROM {table1} t1
            INNER JOIN {table2} t2 ON t1.{key} = t2.{key}",
    
    window = "SELECT *, 
              ROW_NUMBER() OVER (PARTITION BY {partition_col} ORDER BY {order_col}) as rn,
              LAG({column}) OVER (PARTITION BY {partition_col} ORDER BY {order_col}) as prev_value
              FROM {table}",
    
    cte = "WITH summary AS (
             SELECT {group_col}, COUNT(*) as count
             FROM {table}
             GROUP BY {group_col}
           )
           SELECT * FROM summary WHERE count > {threshold}"
  )
}