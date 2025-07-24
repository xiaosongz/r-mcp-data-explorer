# R/Tidyverse MCP Data Explorer Server Specification

## Project Overview

This document provides a complete specification for building a Model Context Protocol (MCP) server for R that enables Claude Desktop to perform data exploration and analysis using tidyverse syntax, with support for Arrow and DuckDB for handling large datasets.

## Background: MCP Architecture

The Model Context Protocol (MCP) is a standardized protocol that enables communication between Claude Desktop and external tools/servers. Key characteristics:

1. **Transport**: Uses stdio (stdin/stdout) for bidirectional communication
2. **Message Format**: JSON-RPC style messages
3. **Lifecycle**: Server starts → registers capabilities → handles requests → graceful shutdown
4. **Tools**: Functions that Claude can invoke with parameters
5. **Prompts**: Pre-defined templates for common workflows

## Core Design Principles

1. **Memory Efficiency**: Use Arrow for memory-mapped file access and DuckDB for SQL queries on large data
2. **Tidyverse-First**: All data manipulation uses dplyr/tidyr syntax
3. **Safety**: Sandboxed R execution with resource limits
4. **Performance**: Lazy evaluation for large datasets, eager for small ones
5. **Visualization**: Integrated ggplot2 support with base64 image return

## Architecture Overview

```
r-mcp-data-explorer/
├── R/
│   ├── server.R              # Main MCP server implementation
│   ├── tools/
│   │   ├── data_loader.R     # Handles CSV, Arrow, Parquet, DuckDB
│   │   ├── script_runner.R   # Executes R code safely
│   │   └── query_runner.R    # DuckDB SQL queries
│   ├── utils/
│   │   ├── mcp_transport.R   # Stdio transport layer
│   │   ├── data_manager.R    # Data storage management
│   │   ├── security.R        # Sandboxing utilities
│   │   └── visualization.R   # Plot to base64 conversion
│   └── prompts/
│       └── explore_data.R    # Data exploration prompt templates
├── inst/
│   ├── setup.R               # Setup script for Claude Desktop
│   └── config/
│       └── allowed_packages.txt  # Whitelisted R packages
├── logs/                     # MCP server logs
├── data/                     # Sample data directory
└── tests/                    # Unit tests

```

## Detailed Component Specifications

### 1. MCP Server Core (server.R)

```r
# Key responsibilities:
# - Implement stdio transport for JSON-RPC communication
# - Handle tool registration and invocation
# - Manage server lifecycle and graceful shutdown
# - Comprehensive error handling and logging

# Critical implementation details:
# - Use jsonlite for JSON parsing
# - Handle Windows encoding issues (UTF-8 BOM)
# - Implement request routing for:
#   - ListToolsRequestSchema
#   - CallToolRequestSchema  
#   - ListPromptsRequestSchema
# - Log all operations to timestamped files in logs/
```

### 2. Data Storage Architecture

```r
# Global data storage manager with three tiers:
data_storage <- list(
  # Tier 1: In-memory tibbles for small data (<100MB)
  tibbles = list(),
  
  # Tier 2: Arrow datasets for medium data (100MB-1GB)
  # - Memory-mapped for efficiency
  # - Supports partitioned datasets
  arrow_datasets = list(),
  
  # Tier 3: DuckDB connection for large data (>1GB)
  # - Single persistent connection
  # - Tables registered from files
  # - SQL query interface
  duckdb_conn = NULL,
  
  # Metadata tracking
  metadata = list()  # Size, type, columns for each dataset
)

# Automatic tier selection based on file size
# Seamless dplyr interface regardless of backend
```

### 3. Tool Specifications

#### Tool 1: load_data
```r
# Input parameters:
# - file_path: Path to data file (required)
# - name: Dataset name (optional, auto-generated if missing)
# - backend: Force specific backend (optional: "tibble", "arrow", "duckdb")
# - options: Backend-specific options (optional)

# Supported formats:
# - CSV (via readr for small, arrow::open_csv for large)
# - Parquet (via arrow)
# - JSON (via jsonlite)
# - Excel (via readxl for small files)
# - DuckDB database files
# - Arrow datasets (multi-file)

# Returns:
# - Summary statistics
# - Column information with types
# - Memory usage estimate
# - First few rows preview
```

#### Tool 2: run_tidyverse
```r
# Input parameters:
# - code: R code to execute (required)
# - timeout: Execution timeout in seconds (default: 30)
# - return_plot: Whether to return plots as base64 (default: true)

# Execution environment includes:
# - All loaded datasets accessible by name
# - Pre-loaded packages: tidyverse, arrow, duckdb, ggplot2, plotly
# - Helper functions for each dataset:
#   - {name}_glimpse()
#   - {name}_summary() 
#   - {name}_slice_sample(n)
#   - {name}_to_duckdb()  # Convert to DuckDB if not already

# Security measures:
# - New environment for each execution
# - No file system access (except through tools)
# - No network access
# - No system() calls
# - Memory limit enforcement
# - CPU time limit

# Returns:
# - Console output (captured)
# - Plot images (base64 encoded)
# - Data results (if last expression returns data)
# - Error messages with stack traces
```

#### Tool 3: query_duckdb
```r
# Input parameters:
# - query: SQL query string (required)
# - parameters: Named list for parameterized queries (optional)
# - return_type: "tibble" or "arrow" (default: "tibble")

# Features:
# - All loaded datasets available as tables
# - CTEs and window functions supported
# - Can create temporary tables
# - Supports COPY for data export

# Returns:
# - Query results as tibble/arrow table
# - Execution time
# - Row count
```

### 4. Prompt System

```r
# Data exploration prompt with variables:
# - file_path: Path to data file
# - topic: Analysis focus area
# - output_format: "report", "dashboard", or "notebook"

# Prompt guides through:
# 1. Data loading with appropriate backend
# 2. Initial exploration (glimpse, summary stats)
# 3. Data quality checks (missing values, outliers)
# 4. Topic-specific analysis
# 5. Visualization generation
# 6. Insights and recommendations
```

### 5. Security Implementation

```r
# Sandboxed execution using callr package:
sandbox_config <- list(
  # Resource limits
  timeout = 30,          # seconds
  memory_limit = "2G",   # via ulimit on Unix
  
  # Package whitelist
  allowed_packages = c(
    "tidyverse", "arrow", "duckdb", "ggplot2", 
    "plotly", "DT", "skimr", "janitor"
  ),
  
  # Blocked functions
  blocked_functions = c(
    "system", "system2", "shell", "file.remove",
    "unlink", "download.file", "install.packages"
  ),
  
  # Restricted directories
  accessible_paths = c("data/", tempdir())
)
```

### 6. Implementation Guidelines

#### Phase 1: Core MCP Infrastructure (Week 1)
1. Implement stdio transport with proper encoding handling
2. Create message router for MCP protocol
3. Set up logging infrastructure
4. Build tool registration system
5. Test with Claude Desktop

#### Phase 2: Data Loading System (Week 2)
1. Implement file type detection
2. Build three-tier storage system
3. Create data loader for each format
4. Add automatic backend selection
5. Implement summary statistics generation

#### Phase 3: R Execution Engine (Week 3)
1. Set up callr-based sandbox
2. Implement package/function restrictions
3. Build execution environment with data access
4. Add plot capture system
5. Create comprehensive error handling

#### Phase 4: Advanced Features (Week 4)
1. DuckDB integration with dplyr translation
2. Arrow dataset partitioning support
3. Performance monitoring
4. Memory management optimizations
5. Caching system for repeated operations

### 7. Critical Implementation Details

#### Stdio Communication Pattern
```r
# Reading from stdin (handle partial messages):
input_buffer <- ""
while(TRUE) {
  line <- readLines(stdin, n = 1, warn = FALSE)
  if(length(line) == 0) break
  
  input_buffer <- paste0(input_buffer, line)
  
  # Try to parse complete JSON messages
  # Handle Content-Length headers if present
}

# Writing to stdout (ensure proper formatting):
send_response <- function(response) {
  json_str <- jsonlite::toJSON(response, auto_unbox = TRUE)
  writeLines(json_str, stdout)
  flush(stdout)  # Critical for immediate delivery
}
```

#### Data Access Patterns
```r
# Unified interface regardless of backend:
get_data <- function(name) {
  if(name %in% names(data_storage$tibbles)) {
    return(data_storage$tibbles[[name]])
  } else if(name %in% names(data_storage$arrow_datasets)) {
    # Return arrow Table that works with dplyr
    return(data_storage$arrow_datasets[[name]])
  } else if(name %in% DBI::dbListTables(data_storage$duckdb_conn)) {
    # Return duckdb table reference for lazy evaluation
    return(tbl(data_storage$duckdb_conn, name))
  }
}
```

#### Error Handling Strategy
```r
# Wrap all tool executions:
safe_tool_execution <- function(tool_name, args) {
  tryCatch({
    result <- switch(tool_name,
      "load_data" = load_data_tool(args),
      "run_tidyverse" = run_tidyverse_tool(args),
      "query_duckdb" = query_duckdb_tool(args)
    )
    
    list(success = TRUE, result = result)
  }, error = function(e) {
    log_error(e)
    list(
      success = FALSE, 
      error = list(
        message = e$message,
        call = deparse(e$call),
        traceback = traceback()
      )
    )
  })
}
```

### 8. Testing Strategy

1. **Unit Tests**: Each component tested in isolation
2. **Integration Tests**: Full message flow testing
3. **Performance Tests**: Large file handling benchmarks
4. **Security Tests**: Sandbox escape attempts
5. **Claude Desktop Tests**: End-to-end validation

### 9. Configuration Files

#### Claude Desktop Configuration
```json
{
  "r-data-explorer": {
    "command": "Rscript",
    "args": ["path/to/server.R"],
    "env": {
      "R_MCP_LOG_LEVEL": "INFO"
    }
  }
}
```

#### Allowed Packages List
```
# Core tidyverse
dplyr
tidyr
ggplot2
readr
purrr
tibble
stringr
forcats

# Data handling
arrow
duckdb
data.table
dtplyr

# Visualization  
plotly
ggplotly
DT

# Utilities
skimr
janitor
lubridate
```

### 10. Lessons from JavaScript Implementation

1. **Always handle Windows encoding**: Add UTF-8 BOM handling
2. **Comprehensive logging**: Essential for debugging MCP issues
3. **In-memory limits**: Original hits limits at ~1GB files
4. **Helper functions**: Users love the df_describe() style helpers
5. **Visual output**: Plot support dramatically improves utility
6. **Error context**: Include data samples in error messages
7. **Graceful degradation**: Fallback options for large files

### 11. Unique R/Tidyverse Features to Implement

1. **NSE (Non-Standard Evaluation)**: Support bare column names
2. **Pipe operator**: Both %>% and |> support
3. **List columns**: Handle nested data structures
4. **Factor handling**: Preserve factor levels
5. **Date/time**: Lubridate integration
6. **Missing values**: Sophisticated NA handling
7. **Grouped operations**: Maintain grouping through operations

### 12. Performance Optimizations

1. **Lazy evaluation**: Use collect() only when needed
2. **Query pushdown**: Translate dplyr to SQL for DuckDB
3. **Columnar operations**: Leverage Arrow's columnar format
4. **Parallel processing**: Use future/furrr for large operations
5. **Memory mapping**: Never load full file if not needed
6. **Result streaming**: Return results in chunks for large outputs

### 13. Example Usage Scenarios

```r
# Scenario 1: Large CSV analysis
# User: "Load sales_2024.csv (5GB) and analyze regional trends"
# System uses Arrow backend, performs aggregations lazily

# Scenario 2: Multi-file dataset
# User: "Load all parquet files in sales/ directory"  
# System creates Arrow dataset with partitioning

# Scenario 3: SQL + Tidyverse
# User: "Join customer and order tables, then visualize"
# System uses DuckDB for join, ggplot2 for visualization

# Scenario 4: Real-time data exploration
# User: "Sample 10000 rows and create correlation matrix"
# System uses slice_sample() and corrplot
```

### 14. Deployment Checklist

- [ ] R version >= 4.0 requirement check
- [ ] All required packages installation script
- [ ] Claude Desktop configuration setup
- [ ] Logging directory creation
- [ ] Sample data included
- [ ] Performance benchmarks run
- [ ] Security audit completed
- [ ] Documentation generated
- [ ] Error recovery tested
- [ ] Cross-platform validation

## Summary

This specification provides a complete blueprint for building an R-based MCP server that leverages the tidyverse ecosystem while addressing the scalability limitations of the original JavaScript implementation. The three-tier storage system (tibble/Arrow/DuckDB) ensures efficient handling of datasets from kilobytes to terabytes, while maintaining the familiar dplyr interface that R users expect.

Key innovations over the JavaScript version:
- Native R evaluation instead of JavaScript
- Integrated big data support via Arrow and DuckDB  
- Rich visualization with ggplot2
- SQL query capabilities
- Better security through callr sandboxing

The implementation should prioritize user experience, data safety, and performance, while maintaining full compatibility with the MCP protocol for seamless Claude Desktop integration.