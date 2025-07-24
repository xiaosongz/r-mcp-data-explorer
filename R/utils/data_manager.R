#' Data Manager
#' Manages three-tier storage: tibbles, Arrow datasets, and DuckDB

# Load required packages
suppressPackageStartupMessages({
  library(arrow)
  library(duckdb)
  library(DBI)
})

# Global data storage
.DATA_STORAGE <- list(
  tibbles = list(),
  arrow_datasets = list(),
  duckdb_conn = NULL,
  metadata = list()
)

# Size thresholds (in bytes)
.SIZE_THRESHOLD_ARROW <- 100 * 1024 * 1024  # 100MB
.SIZE_THRESHOLD_DUCKDB <- 1024 * 1024 * 1024  # 1GB

#' Initialize data manager
init_data_manager <- function() {
  log_info("Initializing data manager...")
  
  # Initialize DuckDB connection
  .DATA_STORAGE$duckdb_conn <<- dbConnect(duckdb::duckdb(), ":memory:")
  
  # Create data directory if needed
  if (!dir.exists("data")) {
    dir.create("data", recursive = TRUE)
  }
  
  log_info("Data manager initialized")
}

#' Cleanup data manager
cleanup_data_manager <- function() {
  log_info("Cleaning up data manager...")
  
  # Close DuckDB connection
  if (!is.null(.DATA_STORAGE$duckdb_conn)) {
    dbDisconnect(.DATA_STORAGE$duckdb_conn)
  }
  
  # Clear Arrow datasets
  .DATA_STORAGE$arrow_datasets <<- list()
  
  log_info("Data manager cleaned up")
}

#' Store dataset with automatic tier selection
#' @param data Data to store
#' @param name Dataset name
#' @param file_path Original file path
#' @param force_backend Force specific backend
store_dataset <- function(data, name, file_path = NULL, force_backend = NULL) {
  # Get file size if path provided
  file_size <- if (!is.null(file_path) && file.exists(file_path)) {
    file.info(file_path)$size
  } else {
    object.size(data)
  }
  
  # Determine backend
  backend <- if (!is.null(force_backend)) {
    force_backend
  } else if (file_size < .SIZE_THRESHOLD_ARROW) {
    "tibble"
  } else if (file_size < .SIZE_THRESHOLD_DUCKDB) {
    "arrow"
  } else {
    "duckdb"
  }
  
  log_info(paste("Storing", name, "using backend:", backend, 
                 "(size:", format(file_size, big.mark = ","), "bytes)"))
  
  # Store based on backend
  if (backend == "tibble") {
    store_as_tibble(data, name)
  } else if (backend == "arrow") {
    store_as_arrow(data, name, file_path)
  } else {
    store_as_duckdb(data, name, file_path)
  }
  
  # Store metadata
  .DATA_STORAGE$metadata[[name]] <<- list(
    backend = backend,
    size = file_size,
    columns = names(data),
    nrow = nrow(data),
    created = Sys.time()
  )
  
  # Create helper functions
  create_helper_functions(name)
}

#' Store as tibble
store_as_tibble <- function(data, name) {
  # Ensure it's a tibble
  if (!inherits(data, "tbl_df")) {
    data <- as_tibble(data)
  }
  
  .DATA_STORAGE$tibbles[[name]] <<- data
}

#' Store as Arrow dataset
store_as_arrow <- function(data, name, file_path = NULL) {
  if (!is.null(file_path) && file.exists(file_path)) {
    # Read directly as Arrow
    ext <- tools::file_ext(file_path)
    
    if (ext == "parquet") {
      dataset <- read_parquet(file_path, as_data_frame = FALSE)
    } else if (ext == "csv") {
      dataset <- read_csv_arrow(file_path, as_data_frame = FALSE)
    } else {
      # Convert to Arrow Table
      dataset <- arrow_table(data)
    }
  } else {
    # Convert to Arrow Table
    dataset <- arrow_table(data)
  }
  
  .DATA_STORAGE$arrow_datasets[[name]] <<- dataset
}

#' Store in DuckDB
store_as_duckdb <- function(data, name, file_path = NULL) {
  conn <- .DATA_STORAGE$duckdb_conn
  
  if (!is.null(file_path) && file.exists(file_path)) {
    ext <- tools::file_ext(file_path)
    
    if (ext == "parquet") {
      # Register parquet file
      query <- sprintf("CREATE OR REPLACE VIEW %s AS SELECT * FROM read_parquet('%s')",
                      name, file_path)
      dbExecute(conn, query)
    } else if (ext == "csv") {
      # Register CSV file
      query <- sprintf("CREATE OR REPLACE VIEW %s AS SELECT * FROM read_csv_auto('%s')",
                      name, file_path)
      dbExecute(conn, query)
    } else {
      # Write data to DuckDB
      dbWriteTable(conn, name, data, overwrite = TRUE)
    }
  } else {
    # Write data to DuckDB
    dbWriteTable(conn, name, data, overwrite = TRUE)
  }
}

#' Get dataset by name
#' @param name Dataset name
#' @return Dataset or NULL
get_dataset <- function(name) {
  # Check tibbles
  if (name %in% names(.DATA_STORAGE$tibbles)) {
    return(.DATA_STORAGE$tibbles[[name]])
  }
  
  # Check Arrow datasets
  if (name %in% names(.DATA_STORAGE$arrow_datasets)) {
    return(.DATA_STORAGE$arrow_datasets[[name]])
  }
  
  # Check DuckDB
  if (!is.null(.DATA_STORAGE$duckdb_conn)) {
    tables <- dbListTables(.DATA_STORAGE$duckdb_conn)
    if (name %in% tables) {
      return(tbl(.DATA_STORAGE$duckdb_conn, name))
    }
  }
  
  return(NULL)
}

#' List all datasets
list_datasets <- function() {
  datasets <- c(
    names(.DATA_STORAGE$tibbles),
    names(.DATA_STORAGE$arrow_datasets)
  )
  
  if (!is.null(.DATA_STORAGE$duckdb_conn)) {
    datasets <- c(datasets, dbListTables(.DATA_STORAGE$duckdb_conn))
  }
  
  unique(datasets)
}

#' Get dataset info
get_dataset_info <- function(name) {
  if (name %in% names(.DATA_STORAGE$metadata)) {
    return(.DATA_STORAGE$metadata[[name]])
  }
  
  # Generate info on the fly
  data <- get_dataset(name)
  if (is.null(data)) return(NULL)
  
  list(
    backend = "unknown",
    columns = names(data),
    nrow = nrow(data)
  )
}

#' Create helper functions for dataset
create_helper_functions <- function(name) {
  # Create environment for helper functions
  env <- globalenv()
  
  # glimpse function
  assign(paste0(name, "_glimpse"), 
         function() {
           data <- get_dataset(name)
           if (!is.null(data)) {
             glimpse(data)
           }
         }, 
         envir = env)
  
  # summary function
  assign(paste0(name, "_summary"), 
         function() {
           data <- get_dataset(name)
           if (!is.null(data)) {
             if (inherits(data, "tbl_lazy")) {
               # For lazy tables, compute summary
               data %>% 
                 summarise(across(where(is.numeric), 
                                list(mean = ~mean(.x, na.rm = TRUE),
                                     sd = ~sd(.x, na.rm = TRUE),
                                     min = ~min(.x, na.rm = TRUE),
                                     max = ~max(.x, na.rm = TRUE)))) %>%
                 collect()
             } else {
               summary(data)
             }
           }
         }, 
         envir = env)
  
  # slice_sample function
  assign(paste0(name, "_slice_sample"), 
         function(n = 10) {
           data <- get_dataset(name)
           if (!is.null(data)) {
             if (inherits(data, "tbl_lazy")) {
               # For lazy tables, use SQL sampling
               data %>% 
                 filter(runif(n()) < (n / n())) %>%
                 head(n) %>%
                 collect()
             } else {
               slice_sample(data, n = min(n, nrow(data)))
             }
           }
         }, 
         envir = env)
  
  # to_duckdb function
  assign(paste0(name, "_to_duckdb"), 
         function() {
           if (name %in% dbListTables(.DATA_STORAGE$duckdb_conn)) {
             message("Already in DuckDB")
             return(invisible(TRUE))
           }
           
           data <- get_dataset(name)
           if (!is.null(data)) {
             store_as_duckdb(collect(data), name)
             message(paste("Converted", name, "to DuckDB"))
           }
         }, 
         envir = env)
  
  log_info(paste("Created helper functions for", name))
}