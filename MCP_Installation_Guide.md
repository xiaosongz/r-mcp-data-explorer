# MCP Server Installation Guide and Action Plan

## Prerequisites

Before installing MCP servers, ensure you have the following:

### System Requirements
- **Operating System**: macOS, Windows 10/11, or Linux (Ubuntu 20.04+)
- **Node.js**: v16.0.0 or higher (v18+ recommended)
- **npm**: v8.0.0 or higher
- **Git**: v2.25.0 or higher
- **Disk Space**: At least 500MB free
- **RAM**: Minimum 4GB (8GB recommended)

### Installation Commands
```bash
# Check Node.js version
node --version

# Check npm version
npm --version

# Check git version
git --version

# If Node.js is not installed:
# macOS: brew install node
# Ubuntu/Debian: sudo apt install nodejs npm
# Windows: Download from https://nodejs.org/
```

## Summary of Installed MCP Servers

This document details the installation process for various MCP (Model Context Protocol) servers on macOS and provides an action plan for replicating these installations on other environments.

### Installed Servers:
1. **File System MCP Server** - Local file operations
2. **Sequential Thinking MCP Server** - Step-by-step problem solving
3. **Puppeteer MCP Server** - Browser automation
4. **Memory Bank MCP Server** - Persistent context across sessions
5. **Obsidian MCP Server** - Integration with Obsidian notes

## Detailed Installation Steps

### 1. File System MCP Server

**Purpose**: Enables file read/write operations on local machine

**Installation Steps**:
```bash
# Clone the MCP servers repository
cd ~/git
git clone https://github.com/modelcontextprotocol/servers.git

# Navigate to filesystem server
cd servers/src/filesystem

# Install dependencies
npm install

# Build the server
npm run build
```

**Configuration** (in `claude_desktop_config.json`):
```json
"filesystem": {
  "command": "node",
  "args": [
    "/Users/xiaosong/git/servers/src/filesystem/dist/index.js",
    "/Users/xiaosong"
  ]
}
```

**Cross-Platform Configuration**:
```json
// Windows
"filesystem": {
  "command": "node",
  "args": [
    "C:\\Users\\YourName\\git\\servers\\src\\filesystem\\dist\\index.js",
    "C:\\Users\\YourName"
  ]
}

// Linux
"filesystem": {
  "command": "node",
  "args": [
    "/home/yourname/git/servers/src/filesystem/dist/index.js",
    "/home/yourname"
  ]
}
```

**Verification**:
```bash
# Test the server directly
node /path/to/servers/src/filesystem/dist/index.js --help
```

### 2. Sequential Thinking MCP Server

**Purpose**: Helps break down complex tasks into logical steps

**Installation Steps**:
```bash
# Install globally via npm
npm install -g @modelcontextprotocol/server-sequential-thinking
```

**Configuration**:
```json
// macOS (Apple Silicon)
"sequential-thinking": {
  "command": "node",
  "args": [
    "/opt/homebrew/lib/node_modules/@modelcontextprotocol/server-sequential-thinking/dist/index.js"
  ]
}

// macOS (Intel) / Linux
"sequential-thinking": {
  "command": "node",
  "args": [
    "/usr/local/lib/node_modules/@modelcontextprotocol/server-sequential-thinking/dist/index.js"
  ]
}

// Windows
"sequential-thinking": {
  "command": "node",
  "args": [
    "C:\\Users\\YourName\\AppData\\Roaming\\npm\\node_modules\\@modelcontextprotocol\\server-sequential-thinking\\dist\\index.js"
  ]
}
```

**Finding npm global path**:
```bash
# Find where npm installs global packages
npm config get prefix

# List global packages to verify installation
npm list -g @modelcontextprotocol/server-sequential-thinking
```

**Verification**:
```bash
# Test the server
node $(npm root -g)/@modelcontextprotocol/server-sequential-thinking/dist/index.js --version
```

### 3. Puppeteer MCP Server

**Purpose**: Browser automation, screenshots, web scraping

**Installation Steps**:
```bash
# Install globally via npm
npm install -g puppeteer-mcp-server
```

**Configuration**:
```json
"puppeteer": {
  "command": "node",
  "args": [
    "/opt/homebrew/lib/node_modules/puppeteer-mcp-server/dist/index.js"
  ]
}
```

### 4. Memory Bank MCP Server

**Purpose**: Maintains context across Claude sessions

**Installation Steps**:
```bash
# Already cloned with the servers repository
cd ~/git/servers/src/memory

# Install dependencies
npm install

# Build the server
npm run build
```

**Configuration**:
```json
"memory": {
  "command": "node",
  "args": [
    "/Users/xiaosong/git/servers/src/memory/dist/index.js"
  ]
}
```

### 5. Obsidian MCP Server

**Purpose**: Integration with Obsidian knowledge base

**Prerequisites**:
- Install Obsidian
- Install "Local REST API" plugin in Obsidian
- Generate API key in plugin settings
- Enable HTTP server (port 27123)

**Installation Steps**:
```bash
# Install globally via npm
npm install -g obsidian-mcp-server
```

**Configuration**:
```json
"obsidian": {
  "command": "npx",
  "args": ["obsidian-mcp-server"],
  "env": {
    "OBSIDIAN_API_KEY": "YOUR_API_KEY_HERE",
    "OBSIDIAN_BASE_URL": "http://127.0.0.1:27123"
  }
}
```

## Automated Installation

### Quick Install Script

#### macOS/Linux

An automated installation script is available that handles all setup steps:

```bash
# Download and run the installation script
curl -O https://raw.githubusercontent.com/YOUR_REPO/main/install_mcp_servers.sh
chmod +x install_mcp_servers.sh
./install_mcp_servers.sh
```

#### Windows (PowerShell)

Run PowerShell as Administrator:

```powershell
# Download and run the installation script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOUR_REPO/main/install_mcp_servers.ps1" -OutFile "install_mcp_servers.ps1"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install_mcp_servers.ps1
```

#### What the Scripts Do

The automated scripts will:
1. Check all prerequisites (Node.js, npm, git)
2. Install all MCP servers in the correct order
3. Configure Claude Desktop automatically
4. Verify all installations work correctly
5. Create a backup of existing configuration
6. Provide clear error messages if something fails

### Manual Installation Using Action Plan

If you prefer manual installation or need more control, use this prompt when installing MCP servers on a new environment:

---

**PROMPT FOR CLAUDE:**

I need to install and configure MCP servers on my system. Please help me install the following servers in order, using the TodoWrite tool to track progress:

1. **File System MCP Server**
   - Clone https://github.com/modelcontextprotocol/servers.git to ~/git/
   - Navigate to src/filesystem, run npm install and npm run build
   - Add configuration to claude_desktop_config.json with correct paths

2. **Sequential Thinking MCP Server**
   - Install globally: npm install -g @modelcontextprotocol/server-sequential-thinking
   - Find installation path and configure in claude_desktop_config.json

3. **Puppeteer MCP Server**
   - Install globally: npm install -g puppeteer-mcp-server
   - Find installation path and configure in claude_desktop_config.json

4. **Memory Bank MCP Server**
   - Use the already cloned servers repo
   - Navigate to src/memory, run npm install and npm run build
   - Configure with correct dist path

5. **Obsidian MCP Server**
   - First, guide me to install Obsidian Local REST API plugin
   - Install globally: npm install -g obsidian-mcp-server
   - Configure with placeholder for API key

For each server:
- Verify the installation works
- Update claude_desktop_config.json
- Provide clear instructions for any manual steps

Please track all tasks with TodoWrite and complete them systematically.

---

## Configuration File Location

### Platform-Specific Paths
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

### Finding Your Configuration
```bash
# macOS/Linux
find ~ -name "claude_desktop_config.json" 2>/dev/null

# Windows (PowerShell)
Get-ChildItem -Path $env:APPDATA -Filter "claude_desktop_config.json" -Recurse
```

## Important Notes

1. **Path Differences**: 
   - npm global installations typically go to `/opt/homebrew/lib/node_modules/` on Apple Silicon Macs
   - Adjust paths based on your system (use `npm config get prefix` to find npm prefix)

2. **Build Steps**: 
   - Servers from the modelcontextprotocol/servers repo need to be built with `npm run build`
   - Global npm packages are pre-built

3. **API Keys**:
   - Obsidian server requires manual API key generation
   - Other servers typically don't need authentication

4. **Restart Required**:
   - Always restart Claude Desktop after configuration changes

## Troubleshooting

### Common Issues and Solutions

1. **Server doesn't appear after restart**
   - Check file paths are absolute and correct
   - Verify build steps completed (check for dist/ folder)
   - Validate JSON syntax: `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq .`
   - Check Claude Desktop logs: `~/Library/Logs/Claude/`

2. **"Cannot find module" errors**
   ```bash
   # Reinstall dependencies
   cd /path/to/server
   rm -rf node_modules package-lock.json
   npm install
   npm run build
   ```

3. **Permission denied errors**
   ```bash
   # Fix permissions (macOS/Linux)
   chmod +x /path/to/server/dist/index.js
   ```

4. **"Command not found" for npx**
   ```bash
   # Install npx if missing
   npm install -g npx
   ```

5. **Build failures**
   ```bash
   # Clean build
   npm run clean
   npm install --force
   npm run build
   ```

### Verification Commands

```bash
# Test each server individually
node /path/to/filesystem/dist/index.js --help
node /path/to/sequential-thinking/dist/index.js --version
node /path/to/puppeteer-mcp-server/dist/index.js --help
node /path/to/memory/dist/index.js --help
npx obsidian-mcp-server --version
```

### Debug Mode

Add debug environment variables to see detailed logs:
```json
"filesystem": {
  "command": "node",
  "args": ["..."],
  "env": {
    "DEBUG": "mcp:*"
  }
}
```

## Update and Uninstall Procedures

### Updating MCP Servers

**Global npm packages**:
```bash
# Update a specific server
npm update -g @modelcontextprotocol/server-sequential-thinking
npm update -g puppeteer-mcp-server
npm update -g obsidian-mcp-server

# Check for outdated packages
npm outdated -g
```

**Git-based servers**:
```bash
cd ~/git/servers
git pull origin main

# Rebuild each server
cd src/filesystem && npm install && npm run build
cd ../memory && npm install && npm run build
```

### Uninstalling MCP Servers

1. **Remove from configuration**:
   - Edit `claude_desktop_config.json`
   - Remove the server entry
   - Save and restart Claude Desktop

2. **Uninstall packages**:
   ```bash
   # Global packages
   npm uninstall -g @modelcontextprotocol/server-sequential-thinking
   npm uninstall -g puppeteer-mcp-server
   npm uninstall -g obsidian-mcp-server
   
   # Git-based servers
   rm -rf ~/git/servers
   ```

## Complete Configuration Example

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": [
        "/path/to/servers/src/filesystem/dist/index.js",
        "/home/directory"
      ]
    },
    "sequential-thinking": {
      "command": "node",
      "args": [
        "/path/to/node_modules/@modelcontextprotocol/server-sequential-thinking/dist/index.js"
      ]
    },
    "puppeteer": {
      "command": "node",
      "args": [
        "/path/to/node_modules/puppeteer-mcp-server/dist/index.js"
      ]
    },
    "memory": {
      "command": "node",
      "args": [
        "/path/to/servers/src/memory/dist/index.js"
      ]
    },
    "obsidian": {
      "command": "npx",
      "args": ["obsidian-mcp-server"],
      "env": {
        "OBSIDIAN_API_KEY": "YOUR_API_KEY",
        "OBSIDIAN_BASE_URL": "http://127.0.0.1:27123"
      }
    }
  }
}
```