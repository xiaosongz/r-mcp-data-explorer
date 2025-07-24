#!/bin/bash

# MCP Server Automated Installation Script
# This script installs all MCP servers and configures them for Claude Desktop

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js v16 or higher."
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2)
    MIN_NODE_VERSION="16.0.0"
    if [ "$(printf '%s\n' "$MIN_NODE_VERSION" "$NODE_VERSION" | sort -V | head -n1)" != "$MIN_NODE_VERSION" ]; then
        print_error "Node.js version $NODE_VERSION is too old. Please upgrade to v16 or higher."
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm."
        exit 1
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git is not installed. Please install git."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Detect operating system and set paths
detect_os() {
    print_status "Detecting operating system..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        CONFIG_DIR="$HOME/Library/Application Support/Claude"
        if [[ $(uname -m) == "arm64" ]]; then
            NPM_GLOBAL="/opt/homebrew/lib/node_modules"
        else
            NPM_GLOBAL="/usr/local/lib/node_modules"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        CONFIG_DIR="$HOME/.config/Claude"
        NPM_GLOBAL="/usr/local/lib/node_modules"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    print_status "Detected $OS"
}

# Create directory structure
setup_directories() {
    print_status "Setting up directories..."
    
    mkdir -p "$HOME/git"
    mkdir -p "$CONFIG_DIR"
    
    if [ ! -f "$CONFIG_DIR/claude_desktop_config.json" ]; then
        echo '{"mcpServers": {}}' > "$CONFIG_DIR/claude_desktop_config.json"
    fi
}

# Install File System MCP Server
install_filesystem_server() {
    print_status "Installing File System MCP Server..."
    
    cd "$HOME/git"
    
    if [ ! -d "servers" ]; then
        git clone https://github.com/modelcontextprotocol/servers.git
    else
        cd servers
        git pull origin main
        cd ..
    fi
    
    cd servers/src/filesystem
    npm install
    npm run build
    
    print_status "File System MCP Server installed successfully!"
}

# Install Sequential Thinking MCP Server
install_sequential_thinking_server() {
    print_status "Installing Sequential Thinking MCP Server..."
    
    npm install -g @modelcontextprotocol/server-sequential-thinking
    
    print_status "Sequential Thinking MCP Server installed successfully!"
}

# Install Puppeteer MCP Server
install_puppeteer_server() {
    print_status "Installing Puppeteer MCP Server..."
    
    npm install -g puppeteer-mcp-server
    
    print_status "Puppeteer MCP Server installed successfully!"
}

# Install Memory Bank MCP Server
install_memory_server() {
    print_status "Installing Memory Bank MCP Server..."
    
    cd "$HOME/git/servers/src/memory"
    npm install
    npm run build
    
    print_status "Memory Bank MCP Server installed successfully!"
}

# Install Obsidian MCP Server
install_obsidian_server() {
    print_status "Installing Obsidian MCP Server..."
    
    npm install -g obsidian-mcp-server
    
    print_warning "Note: You'll need to install the 'Local REST API' plugin in Obsidian and generate an API key"
    
    print_status "Obsidian MCP Server installed successfully!"
}

# Update Claude Desktop configuration
update_config() {
    print_status "Updating Claude Desktop configuration..."
    
    # Backup existing config
    cp "$CONFIG_DIR/claude_desktop_config.json" "$CONFIG_DIR/claude_desktop_config.json.backup"
    
    # Create new config
    cat > "$CONFIG_DIR/claude_desktop_config.json" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "node",
      "args": [
        "$HOME/git/servers/src/filesystem/dist/index.js",
        "$HOME"
      ]
    },
    "sequential-thinking": {
      "command": "node",
      "args": [
        "$NPM_GLOBAL/@modelcontextprotocol/server-sequential-thinking/dist/index.js"
      ]
    },
    "puppeteer": {
      "command": "node",
      "args": [
        "$NPM_GLOBAL/puppeteer-mcp-server/dist/index.js"
      ]
    },
    "memory": {
      "command": "node",
      "args": [
        "$HOME/git/servers/src/memory/dist/index.js"
      ]
    },
    "obsidian": {
      "command": "npx",
      "args": ["obsidian-mcp-server"],
      "env": {
        "OBSIDIAN_API_KEY": "YOUR_API_KEY_HERE",
        "OBSIDIAN_BASE_URL": "http://127.0.0.1:27123"
      }
    }
  }
}
EOF
    
    print_status "Configuration updated successfully!"
}

# Verify installations
verify_installations() {
    print_status "Verifying installations..."
    
    ERRORS=0
    
    # Test filesystem server
    if node "$HOME/git/servers/src/filesystem/dist/index.js" --help &> /dev/null; then
        print_status "✓ File System MCP Server verified"
    else
        print_error "✗ File System MCP Server verification failed"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Test sequential thinking server
    if [ -f "$NPM_GLOBAL/@modelcontextprotocol/server-sequential-thinking/dist/index.js" ]; then
        print_status "✓ Sequential Thinking MCP Server verified"
    else
        print_error "✗ Sequential Thinking MCP Server verification failed"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Test puppeteer server
    if [ -f "$NPM_GLOBAL/puppeteer-mcp-server/dist/index.js" ]; then
        print_status "✓ Puppeteer MCP Server verified"
    else
        print_error "✗ Puppeteer MCP Server verification failed"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Test memory server
    if node "$HOME/git/servers/src/memory/dist/index.js" --help &> /dev/null; then
        print_status "✓ Memory Bank MCP Server verified"
    else
        print_error "✗ Memory Bank MCP Server verification failed"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Test obsidian server
    if command -v obsidian-mcp-server &> /dev/null; then
        print_status "✓ Obsidian MCP Server verified"
    else
        print_error "✗ Obsidian MCP Server verification failed"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ $ERRORS -eq 0 ]; then
        print_status "All servers verified successfully!"
    else
        print_error "$ERRORS server(s) failed verification"
    fi
}

# Main installation flow
main() {
    echo "====================================="
    echo "MCP Server Automated Installer"
    echo "====================================="
    echo
    
    check_prerequisites
    detect_os
    setup_directories
    
    # Install servers
    install_filesystem_server
    install_sequential_thinking_server
    install_puppeteer_server
    install_memory_server
    install_obsidian_server
    
    # Update configuration
    update_config
    
    # Verify installations
    verify_installations
    
    echo
    echo "====================================="
    print_status "Installation complete!"
    print_warning "Please restart Claude Desktop to use the new MCP servers"
    print_warning "Don't forget to update the Obsidian API key in the configuration"
    echo "Configuration file: $CONFIG_DIR/claude_desktop_config.json"
    echo "====================================="
}

# Run main function
main