# My MCP Servers Configuration

This document lists all MCP servers configured for Claude Desktop as of July 24, 2025.

## Configured MCP Servers

### 1. **filesystem**
- **Purpose**: File system operations (read, write, navigate directories)
- **Location**: `/Users/xiaosong/git/servers/src/filesystem/dist/index.js`
- **Access Path**: `/Users/xiaosong`

### 2. **sequential-thinking**
- **Purpose**: Step-by-step problem solving and logical reasoning
- **Location**: `/opt/homebrew/lib/node_modules/@modelcontextprotocol/server-sequential-thinking/dist/index.js`
- **Global npm package**: `@modelcontextprotocol/server-sequential-thinking`

### 3. **puppeteer**
- **Purpose**: Browser automation, web scraping, screenshots
- **Location**: `/opt/homebrew/lib/node_modules/puppeteer-mcp-server/dist/index.js`
- **Global npm package**: `puppeteer-mcp-server`

### 4. **memory**
- **Purpose**: Persistent context storage across Claude sessions
- **Location**: `/Users/xiaosong/git/servers/src/memory/dist/index.js`

### 5. **obsidian**
- **Purpose**: Integration with Obsidian note-taking app
- **Command**: Uses npx to run `obsidian-mcp-server`
- **Note**: Requires Obsidian API key configuration

### 6. **composio-github**
- **Purpose**: GitHub integration and operations
- **Command**: Uses npx to run `@composio/mcp@latest`
- **URL**: Configured for GitHub

### 7. **r-data-explorer**
- **Purpose**: R language data analysis and tidyverse operations
- **Location**: `/Users/xiaosong/git/r-mcp-data-explorer/R/server_minimal.R`
- **Log Directory**: `/Users/xiaosong/git/r-mcp-data-explorer/logs`

### 8. **ide**
- **Purpose**: VS Code integration for code editing and IDE features
- **Command**: Uses npx to run `@mcp-get/mcp-vscode`

## Important Notes

1. **Restart Required**: After any configuration changes, you must completely quit and restart Claude Desktop
2. **Configuration Location**: `~/Library/Application Support/Claude/claude_desktop_config.json`
3. **Backup Created**: A backup of your previous configuration was saved with timestamp

## Regarding "context7"

No server named "context7" was found in your system. All available MCP servers have been documented above. If you're looking for specific functionality, please check if one of the above servers provides it.

## Verification

To verify all servers are working after restart:
1. Open a new Claude Desktop window
2. Type `/mcp` to see available MCP tools
3. All servers listed above should appear

## Troubleshooting

If a server doesn't appear:
1. Check the file paths exist
2. Verify npm global packages are installed
3. Check Claude Desktop logs
4. Ensure JSON syntax is correct in config file