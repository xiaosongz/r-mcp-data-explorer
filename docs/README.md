# R MCP Data Explorer Documentation

Welcome to the R MCP Data Explorer documentation. This directory contains comprehensive documentation for developers and users of the R MCP Data Explorer.

## Documentation Structure

### [API Reference](./API_REFERENCE.md)
Complete reference for all available tools, parameters, and response formats. Includes:
- Tool specifications (load_data, run_tidyverse, query_duckdb)
- Parameter details and options
- Response formats and examples
- Security restrictions
- Error handling

### [Developer Guide](./DEVELOPER_GUIDE.md)
In-depth guide for developers working with or extending the R MCP Data Explorer. Covers:
- Architecture overview
- Component deep-dives
- Security model
- Adding new features
- Testing strategies
- Debugging techniques
- Best practices

## Quick Links

- **Getting Started**: See the [main README](../README.md) for installation and setup
- **Source Code**: Browse the [R/](../R/) directory for implementation details
- **Configuration**: Check [inst/config/](../inst/config/) for configuration files
- **Examples**: Find example usage in the API Reference

## Overview

The R MCP Data Explorer is a Model Context Protocol (MCP) server that enables:

- **Data Loading**: Support for CSV, Parquet, Arrow, Excel, and DuckDB files
- **Tidyverse Analysis**: Execute R code using the tidyverse ecosystem
- **SQL Queries**: Run SQL queries on loaded data using DuckDB
- **Intelligent Storage**: Automatic backend selection based on data size
- **Security**: Sandboxed execution with comprehensive safety measures

## Architecture Highlights

### Three-Tier Data Storage
- **Tibbles** (< 100MB): In-memory R data frames for small datasets
- **Arrow** (100MB - 1GB): Columnar format for efficient medium-scale operations
- **DuckDB** (> 1GB): SQL database for large-scale data processing

### Security Model
- Package whitelisting with allowed package list
- Function blocking for dangerous operations
- Path restrictions to prevent file system access
- Execution timeouts to prevent resource exhaustion

### MCP Integration
- Stdio transport for communication with Claude Desktop
- JSON-RPC protocol implementation
- Comprehensive error handling and logging
- Tool discovery and introspection support

## Contributing

We welcome contributions! Please:

1. Read the Developer Guide for architecture details
2. Follow the coding standards outlined in Best Practices
3. Add tests for new functionality
4. Update documentation as needed

## Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Logs**: Check the `logs/` directory for debugging information
- **Configuration**: See `inst/config/` for customization options