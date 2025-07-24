# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development Commands
- `Rscript R/server.R` - Start the MCP server
- `Rscript inst/setup.R` - Configure Claude Desktop and install dependencies
- `R CMD INSTALL .` - Install the package locally
- `devtools::load_all()` - Load all functions for development (in R console)
- `testthat::test()` - Run tests (in R console)

### Important Notes
- This is an R implementation of an MCP server
- The server uses stdio for communication with Claude Desktop
- Always test changes with small data files first
- Check logs/ directory for debugging information

## Architecture

This is a Model Context Protocol (MCP) server for R that enables data exploration with tidyverse syntax.

### Core Components

1. **MCP Server** (`R/server.R`):
   - Implements stdio transport for Claude Desktop
   - Handles JSON-RPC communication
   - Routes requests to appropriate tools

2. **Tools**:
   - **`load_data`** (`R/tools/data_loader.R`): Loads CSV/Parquet/Arrow files
   - **`run_tidyverse`** (`R/tools/script_runner.R`): Executes R code safely
   - **`query_duckdb`** (`R/tools/query_runner.R`): SQL queries on data

3. **Data Storage** (`R/utils/data_manager.R`):
   - Three-tier system: tibbles (small), Arrow (medium), DuckDB (large)
   - Automatic backend selection based on file size
   - Unified dplyr interface regardless of backend

4. **Security** (`R/utils/security.R`):
   - Uses callr for sandboxed execution
   - Package whitelist enforcement
   - Resource limits (memory, CPU time)

### Key Technical Details

- **JSON Communication**: Uses jsonlite for parsing
- **Logging**: Comprehensive logs in logs/ directory
- **Error Handling**: All errors wrapped with context
- **Visualization**: ggplot2 plots converted to base64

### Development Workflow

1. Make changes to R files
2. Reload with `devtools::load_all()`
3. Test with small datasets first
4. Check logs for MCP communication issues
5. Test with Claude Desktop

### R-Specific Considerations

- **NSE**: Support both standard and non-standard evaluation
- **Tibbles vs data.frames**: Always return tibbles
- **Factor handling**: Preserve levels in operations
- **Missing values**: R's NA handling is different from NULL
- **Package loading**: Pre-load tidyverse in execution environment