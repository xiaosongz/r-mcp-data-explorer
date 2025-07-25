# R MCP Data Explorer API Reference

## Overview

The R MCP Data Explorer provides three main tools for data exploration and analysis through the Model Context Protocol (MCP). This API reference documents the available tools, their parameters, and response formats.

## Tools

### 1. load_data

Loads data from various file formats into the server's data management system.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Path to the data file |
| `name` | string | Yes | Name to assign to the loaded dataset |
| `options` | object | No | Additional loading options |

#### Options Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `header` | boolean | true | Whether the first row contains column names |
| `delimiter` | string | "," | Column delimiter for CSV files |
| `na_strings` | array | ["", "NA", "NULL", "null", "N/A", "n/a"] | Strings to interpret as NA |

#### Supported File Formats

- **CSV** (.csv) - Comma-separated values
- **TSV** (.tsv) - Tab-separated values  
- **Excel** (.xlsx, .xls) - Microsoft Excel files
- **JSON** (.json) - JavaScript Object Notation
- **Parquet** (.parquet) - Apache Parquet columnar format
- **Arrow** (.arrow, .feather) - Apache Arrow format
- **DuckDB** (.duckdb, .db) - DuckDB database files

#### Response Format

```
Successfully loaded dataset 'dataset_name'

Dataset Information:
  Rows: 1,000
  Columns: 5
  File size: 125.5 KB
  Load time: 0.23 seconds
  Storage backend: tibble

Column Information:
  id (integer)
  name (character)
  value (numeric) - 2.5% missing
  date (Date)
  category (character)

Numeric Column Summary:
  value:
    Mean: 42.3, SD: 15.7
    Range: [0.5, 99.8]

Sample Data (first 5 rows):
[Data preview]

Available helper functions:
  dataset_name_glimpse()     # View structure
  dataset_name_summary()    # Detailed summary
  dataset_name_slice_sample(n)  # Random sample
  dataset_name_to_duckdb()  # Convert to DuckDB
```

### 2. run_tidyverse

Executes R code using tidyverse functions on loaded data.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | R code to execute |
| `dataset` | string | No | Name of the dataset to operate on |
| `return_plot` | boolean | No | Whether to return plots as base64 images (default: false) |

#### Available Functions

All tidyverse packages are available, including:
- **dplyr**: Data manipulation (filter, select, mutate, summarize, etc.)
- **tidyr**: Data tidying (pivot_longer, pivot_wider, etc.)
- **ggplot2**: Data visualization
- **readr**: Data import/export
- **purrr**: Functional programming
- **stringr**: String manipulation
- **forcats**: Factor manipulation
- **lubridate**: Date/time manipulation

Additional packages:
- **arrow**: For Arrow dataset operations
- **duckdb**: For SQL operations
- **plotly**: Interactive visualizations
- **skimr**: Data summaries
- **janitor**: Data cleaning

#### Response Format

```
Console Output:
==================================================
[Any printed output from the code]

Result:
==================================================
[The final result of the code execution]

Plots:
==================================================
[Plot 1]
data:image/png;base64,iVBORw0KGgoAAAANS...
```

#### Security Restrictions

The following operations are blocked:
- System calls (system, shell)
- File operations outside allowed directories
- Package installation/removal
- Working directory changes
- Direct C/Fortran calls

### 3. query_duckdb

Executes SQL queries on loaded data using DuckDB.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | SQL query to execute |
| `dataset` | string | No | Name of specific dataset to query |

#### SQL Capabilities

DuckDB supports:
- Standard SQL syntax
- Window functions
- Common Table Expressions (CTEs)
- JSON operations
- Array operations
- Full-text search

#### Response Format

```
Query executed successfully

Execution Statistics:
  Rows returned: 42
  Columns: 3
  Execution time: 0.015 seconds

Results:
==================================================
   category  total_value  avg_value
   <chr>          <dbl>      <dbl>
1  A               1234       45.2
2  B               2345       52.1
3  C                987       38.5
```

#### Security Restrictions

The following SQL operations are blocked:
- DROP TABLE/DATABASE
- CREATE/ALTER DATABASE
- TRUNCATE
- DELETE/INSERT/UPDATE
- GRANT/REVOKE
- User management operations

## Data Storage Tiers

The server automatically selects the optimal storage backend based on file size:

| Tier | Size Threshold | Backend | Use Case |
|------|----------------|---------|----------|
| Small | < 100 MB | Tibble | In-memory R data frames |
| Medium | 100 MB - 1 GB | Arrow | Columnar format for efficient operations |
| Large | > 1 GB | DuckDB | SQL database for complex queries |

## Helper Functions

For each loaded dataset, the following helper functions are automatically created:

- `{dataset}_glimpse()` - View dataset structure
- `{dataset}_summary()` - Generate detailed summary statistics
- `{dataset}_slice_sample(n)` - Get random sample of n rows
- `{dataset}_to_duckdb()` - Convert dataset to DuckDB for SQL access

## Error Handling

All errors are returned in a consistent format:

```json
{
  "error": {
    "code": -32603,
    "message": "Detailed error description"
  }
}
```

Common error codes:
- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error

## Examples

### Loading and Exploring Data

```r
# Load a CSV file
load_data(
  path = "data/sales.csv",
  name = "sales",
  options = {
    header = true,
    delimiter = ","
  }
)

# Run tidyverse analysis
run_tidyverse(
  code = "
    sales %>%
      group_by(category) %>%
      summarize(
        total = sum(amount),
        avg = mean(amount),
        count = n()
      ) %>%
      arrange(desc(total))
  ",
  dataset = "sales"
)

# Create a visualization
run_tidyverse(
  code = "
    ggplot(sales, aes(x = date, y = amount, color = category)) +
      geom_line() +
      theme_minimal() +
      labs(title = 'Sales Over Time')
  ",
  dataset = "sales",
  return_plot = true
)
```

### SQL Queries

```sql
-- Simple aggregation
query_duckdb(
  query = "
    SELECT category, 
           COUNT(*) as count,
           SUM(amount) as total,
           AVG(amount) as average
    FROM sales
    GROUP BY category
    ORDER BY total DESC
  "
)

-- Window functions
query_duckdb(
  query = "
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY amount DESC) as rank,
           SUM(amount) OVER (PARTITION BY category) as category_total
    FROM sales
    WHERE date >= '2024-01-01'
  "
)
```