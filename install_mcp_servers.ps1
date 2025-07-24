# MCP Server Automated Installation Script for Windows
# This script installs all MCP servers and configures them for Claude Desktop

# Requires running as Administrator for global npm installs
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to print colored output
function Write-Status {
    param($Message)
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Error-Message {
    param($Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Warning-Message {
    param($Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

# Check prerequisites
function Check-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check Node.js
    try {
        $nodeVersion = node -v
        $nodeVersionNum = [version]($nodeVersion -replace 'v', '')
        if ($nodeVersionNum -lt [version]"16.0.0") {
            Write-Error-Message "Node.js version $nodeVersion is too old. Please upgrade to v16 or higher."
            exit 1
        }
        Write-Status "Node.js $nodeVersion found"
    } catch {
        Write-Error-Message "Node.js is not installed. Please install Node.js v16 or higher."
        exit 1
    }
    
    # Check npm
    try {
        $npmVersion = npm -v
        Write-Status "npm $npmVersion found"
    } catch {
        Write-Error-Message "npm is not installed. Please install npm."
        exit 1
    }
    
    # Check git
    try {
        $gitVersion = git --version
        Write-Status "$gitVersion found"
    } catch {
        Write-Error-Message "git is not installed. Please install git."
        exit 1
    }
    
    Write-Status "Prerequisites check passed!"
}

# Setup directories
function Setup-Directories {
    Write-Status "Setting up directories..."
    
    $gitDir = "$env:USERPROFILE\git"
    $configDir = "$env:APPDATA\Claude"
    
    if (!(Test-Path $gitDir)) {
        New-Item -ItemType Directory -Path $gitDir | Out-Null
    }
    
    if (!(Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir | Out-Null
    }
    
    $configFile = "$configDir\claude_desktop_config.json"
    if (!(Test-Path $configFile)) {
        '{"mcpServers": {}}' | Out-File -FilePath $configFile -Encoding UTF8
    }
}

# Install File System MCP Server
function Install-FilesystemServer {
    Write-Status "Installing File System MCP Server..."
    
    Set-Location "$env:USERPROFILE\git"
    
    if (!(Test-Path "servers")) {
        git clone https://github.com/modelcontextprotocol/servers.git
    } else {
        Set-Location servers
        git pull origin main
        Set-Location ..
    }
    
    Set-Location "servers\src\filesystem"
    npm install
    npm run build
    
    Write-Status "File System MCP Server installed successfully!"
}

# Install Sequential Thinking MCP Server
function Install-SequentialThinkingServer {
    Write-Status "Installing Sequential Thinking MCP Server..."
    
    npm install -g @modelcontextprotocol/server-sequential-thinking
    
    Write-Status "Sequential Thinking MCP Server installed successfully!"
}

# Install Puppeteer MCP Server
function Install-PuppeteerServer {
    Write-Status "Installing Puppeteer MCP Server..."
    
    npm install -g puppeteer-mcp-server
    
    Write-Status "Puppeteer MCP Server installed successfully!"
}

# Install Memory Bank MCP Server
function Install-MemoryServer {
    Write-Status "Installing Memory Bank MCP Server..."
    
    Set-Location "$env:USERPROFILE\git\servers\src\memory"
    npm install
    npm run build
    
    Write-Status "Memory Bank MCP Server installed successfully!"
}

# Install Obsidian MCP Server
function Install-ObsidianServer {
    Write-Status "Installing Obsidian MCP Server..."
    
    npm install -g obsidian-mcp-server
    
    Write-Warning-Message "Note: You'll need to install the 'Local REST API' plugin in Obsidian and generate an API key"
    
    Write-Status "Obsidian MCP Server installed successfully!"
}

# Update Claude Desktop configuration
function Update-Config {
    Write-Status "Updating Claude Desktop configuration..."
    
    $configDir = "$env:APPDATA\Claude"
    $configFile = "$configDir\claude_desktop_config.json"
    
    # Backup existing config
    if (Test-Path $configFile) {
        Copy-Item $configFile "$configFile.backup"
    }
    
    # Get npm global path
    $npmPrefix = npm config get prefix
    $npmGlobal = "$npmPrefix\node_modules"
    
    # Create new config
    $config = @{
        mcpServers = @{
            filesystem = @{
                command = "node"
                args = @(
                    "$env:USERPROFILE\git\servers\src\filesystem\dist\index.js".Replace('\', '\\'),
                    "$env:USERPROFILE".Replace('\', '\\')
                )
            }
            "sequential-thinking" = @{
                command = "node"
                args = @(
                    "$npmGlobal\@modelcontextprotocol\server-sequential-thinking\dist\index.js".Replace('\', '\\')
                )
            }
            puppeteer = @{
                command = "node"
                args = @(
                    "$npmGlobal\puppeteer-mcp-server\dist\index.js".Replace('\', '\\')
                )
            }
            memory = @{
                command = "node"
                args = @(
                    "$env:USERPROFILE\git\servers\src\memory\dist\index.js".Replace('\', '\\')
                )
            }
            obsidian = @{
                command = "npx"
                args = @("obsidian-mcp-server")
                env = @{
                    OBSIDIAN_API_KEY = "YOUR_API_KEY_HERE"
                    OBSIDIAN_BASE_URL = "http://127.0.0.1:27123"
                }
            }
        }
    }
    
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8
    
    Write-Status "Configuration updated successfully!"
}

# Verify installations
function Verify-Installations {
    Write-Status "Verifying installations..."
    
    $errors = 0
    
    # Test filesystem server
    if (Test-Path "$env:USERPROFILE\git\servers\src\filesystem\dist\index.js") {
        Write-Status "✓ File System MCP Server verified"
    } else {
        Write-Error-Message "✗ File System MCP Server verification failed"
        $errors++
    }
    
    # Test sequential thinking server
    $npmPrefix = npm config get prefix
    if (Test-Path "$npmPrefix\node_modules\@modelcontextprotocol\server-sequential-thinking\dist\index.js") {
        Write-Status "✓ Sequential Thinking MCP Server verified"
    } else {
        Write-Error-Message "✗ Sequential Thinking MCP Server verification failed"
        $errors++
    }
    
    # Test puppeteer server
    if (Test-Path "$npmPrefix\node_modules\puppeteer-mcp-server\dist\index.js") {
        Write-Status "✓ Puppeteer MCP Server verified"
    } else {
        Write-Error-Message "✗ Puppeteer MCP Server verification failed"
        $errors++
    }
    
    # Test memory server
    if (Test-Path "$env:USERPROFILE\git\servers\src\memory\dist\index.js") {
        Write-Status "✓ Memory Bank MCP Server verified"
    } else {
        Write-Error-Message "✗ Memory Bank MCP Server verification failed"
        $errors++
    }
    
    # Test obsidian server
    try {
        $null = Get-Command obsidian-mcp-server -ErrorAction Stop
        Write-Status "✓ Obsidian MCP Server verified"
    } catch {
        Write-Error-Message "✗ Obsidian MCP Server verification failed"
        $errors++
    }
    
    if ($errors -eq 0) {
        Write-Status "All servers verified successfully!"
    } else {
        Write-Error-Message "$errors server(s) failed verification"
    }
}

# Main installation flow
function Main {
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "MCP Server Automated Installer" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    
    Check-Prerequisites
    Setup-Directories
    
    # Save current location
    $originalLocation = Get-Location
    
    try {
        # Install servers
        Install-FilesystemServer
        Install-SequentialThinkingServer
        Install-PuppeteerServer
        Install-MemoryServer
        Install-ObsidianServer
        
        # Update configuration
        Update-Config
        
        # Verify installations
        Verify-Installations
    } finally {
        # Return to original location
        Set-Location $originalLocation
    }
    
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Status "Installation complete!"
    Write-Warning-Message "Please restart Claude Desktop to use the new MCP servers"
    Write-Warning-Message "Don't forget to update the Obsidian API key in the configuration"
    Write-Host "Configuration file: $env:APPDATA\Claude\claude_desktop_config.json"
    Write-Host "=====================================" -ForegroundColor Cyan
}

# Run main function
Main