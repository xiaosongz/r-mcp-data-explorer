# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development Commands
- `npm install` - Install dependencies
- `npm run build` - Build TypeScript to JavaScript (outputs to `dist/`)
- `npm start` - Build and start the MCP server
- `npm run setup` - Configure Claude Desktop and build the project

### Important Notes
- No test command is currently implemented
- Always run `npm run build` before testing changes
- The TypeScript implementation in `src/` is the primary codebase

## Architecture

This is a Model Context Protocol (MCP) server for Claude Desktop that enables data exploration capabilities.

### Core Components

1. **MCP Server** (`src/index.ts`):
   - Implements stdio transport for Claude Desktop communication
   - Handles Windows-specific encoding
   - Logs to `logs/mcp-server-{timestamp}.log`

2. **Tools**:
   - **`load-csv`** (`src/tools/data-loader.ts`): Loads CSV files, provides statistical summaries
   - **`run-script`** (`src/tools/script-runner.ts`): Executes JavaScript in sandboxed environment with loaded data

3. **Data Storage**:
   - Global in-memory storage for DataFrames
   - Each DataFrame gets helper methods (e.g., `df_1_describe()`, `df_1_groupBy()`)
   - DataFrames persist across script executions

4. **Setup Script** (`setup.js`):
   - Modifies Claude Desktop's `claude_desktop_config.json`
   - Creates required directories: `logs/`, `data/`, `dist/`
   - Cross-platform support (Windows/macOS)

### Key Technical Details

- **Module System**: ES2022 with NodeNext, use `.js` extensions in imports
- **Security**: Script runner restricts module access to `simple-statistics` and `papaparse`
- **Logging**: Comprehensive MCP connection logging for debugging
- **Cross-Platform**: Special handling for Windows stdin/stdout encoding

### Development Workflow

1. Make changes to TypeScript files in `src/`
2. Run `npm run build` to compile
3. Test with Claude Desktop or run `npm start` to debug
4. Check logs in `logs/` directory for debugging MCP issues