# R MCP Data Explorer

A Model Context Protocol (MCP) server for Claude Desktop that enables data exploration and analysis using R and tidyverse syntax, with support for Arrow and DuckDB for handling large datasets.

## Overview

This project is an R implementation of an MCP server, inspired by the [JavaScript MCP Data Explorer](https://github.com/xiaosongz/claude-mcp-data-explorer). It provides Claude with the ability to:

- Load and analyze CSV, Parquet, and other data formats
- Execute R code with tidyverse syntax
- Handle large datasets efficiently using Arrow and DuckDB
- Create visualizations with ggplot2
- Run SQL queries on loaded data

## Quick Start

### Prerequisites

- R 4.0 or higher
- Claude Desktop application

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/r-mcp-data-explorer.git
cd r-mcp-data-explorer
```

2. Install required R packages:
```r
install.packages(c("jsonlite", "tidyverse", "base64enc", "callr"))
# For full version (optional):
# install.packages(c("arrow", "duckdb"))
```

3. Run the setup script:
```bash
# For minimal version (recommended for initial setup):
Rscript setup_minimal.R

# For full version with arrow/duckdb support:
# Rscript inst/setup.R
```

4. Restart Claude Desktop

## Usage

Once configured, the R MCP Data Explorer will be available in Claude Desktop. You can use it through two main tools:

### 1. load_data

Load CSV files into memory:

```
Use the load_data tool to load "path/to/your/data.csv" as "mydata"
```

### 2. run_tidyverse

Execute R code on loaded datasets:

```
Use run_tidyverse to execute:
mydata %>%
  group_by(category) %>%
  summarise(
    count = n(),
    mean_value = mean(value, na.rm = TRUE)
  )
```

### 3. query_duckdb (Full version only)

Run SQL queries on loaded data:

```
Use query_duckdb to run:
SELECT category, COUNT(*) as count, AVG(value) as avg_value
FROM mydata
GROUP BY category
ORDER BY count DESC
```

## Examples

### Basic Data Analysis

1. Load sample data:
```
Load the file "data/sample_data.csv" as "df"
```

2. Explore the data:
```
Run this tidyverse code:
# View structure
glimpse(df)

# Summary statistics
df %>%
  summary()
```

3. Create visualizations:
```
Run this code to create a plot:
library(ggplot2)
ggplot(df, aes(x = category, y = value, fill = region)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Value Distribution by Category and Region")
```

### Data Transformation

```
Run this tidyverse code:
df %>%
  filter(value > 50) %>%
  mutate(
    value_squared = value^2,
    month = format(date, "%Y-%m")
  ) %>%
  group_by(category, region, month) %>%
  summarise(
    n = n(),
    mean_value = mean(value),
    mean_squared = mean(value_squared),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_squared))
```

## Architecture

The project uses a three-tier storage system:
- **Small data (<100MB)**: In-memory tibbles for fast access
- **Medium data (100MB-1GB)**: Arrow datasets with memory mapping
- **Large data (>1GB)**: DuckDB for SQL-based operations

## Project Structure

```
r-mcp-data-explorer/
├── R/
│   ├── server.R            # Full MCP server implementation
│   ├── server_minimal.R    # Minimal version (no arrow/duckdb)
│   ├── tools/             
│   │   ├── data_loader.R   # Handles data loading
│   │   ├── script_runner.R # Executes R code
│   │   └── query_runner.R  # SQL query execution
│   ├── utils/
│   │   ├── mcp_transport.R # MCP protocol handling
│   │   ├── data_manager.R  # Data storage management
│   │   ├── security.R      # Sandboxing utilities
│   │   ├── visualization.R # Plot capture
│   │   └── logging.R       # Logging utilities
│   └── prompts/
│       └── explore_data.R  # Data exploration prompts
├── data/                   # Sample data directory
├── logs/                   # Server logs
├── inst/                   # Installation files
│   ├── setup.R            # Full setup script
│   └── config/
│       └── allowed_packages.txt
├── tests/                  # Test files
└── setup_minimal.R         # Minimal setup script
```

## Minimal vs Full Version

This repository includes two versions:

### Minimal Version (`server_minimal.R`)
- ✅ No external dependencies beyond tidyverse
- ✅ Quick to set up and debug
- ✅ Supports CSV files
- ✅ Basic R code execution
- ❌ No support for large files
- ❌ No SQL queries

### Full Version (`server.R`)
- ✅ Supports multiple file formats (CSV, Parquet, Arrow, DuckDB)
- ✅ Three-tier storage for efficient large data handling
- ✅ SQL query support via DuckDB
- ✅ Advanced security sandboxing
- ❌ Requires arrow and duckdb packages
- ❌ More complex setup

## Troubleshooting

### Server not appearing in Claude Desktop
1. Ensure Claude Desktop is fully closed before running setup
2. Check the configuration at:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
3. Verify R is in your PATH: `which Rscript`

### Package installation issues
- For arrow package compilation issues, see: https://arrow.apache.org/docs/r/articles/install.html
- Consider using the minimal version if you encounter installation problems

### Errors when loading data
1. Check file paths are absolute or relative to the working directory
2. Ensure CSV files are properly formatted
3. Check server logs in `R/logs/` (minimal) or `logs/` (full version)

### Code execution errors
1. The error message will indicate which packages need to be loaded
2. Check that dataset names match exactly (R is case-sensitive)
3. Ensure your tidyverse syntax is correct

## Development Status

✅ **Implemented**:
- Core MCP protocol handling
- CSV data loading
- Tidyverse code execution
- Basic data storage
- Logging system
- Minimal server version

🚧 **In Progress**:
- Full arrow/duckdb integration
- Advanced sandboxing with callr
- Plot capture and base64 encoding
- Comprehensive test suite

📋 **Planned**:
- Support for more file formats (Excel, JSON)
- Performance optimizations
- Interactive plot support
- Memory usage monitoring

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built for use with [Claude Desktop](https://claude.ai) and the [Model Context Protocol](https://www.anthropic.com/mcp)
- Inspired by the [JavaScript MCP data explorer](https://github.com/xiaosongz/claude-mcp-data-explorer)
- Uses the [tidyverse](https://www.tidyverse.org/) ecosystem for data analysis
- Leverages [Apache Arrow](https://arrow.apache.org/) and [DuckDB](https://duckdb.org/) for large data handling

## References

- [Original JavaScript Implementation](README_ORIGINAL.md)
- [JavaScript Architecture Notes](CLAUDE_JS_REFERENCE.md)
- [Complete R Implementation Spec](R_MCP_SERVER_SPECIFICATION.md)