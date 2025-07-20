#!/bin/bash

# Peloton Communicator Development Setup Script
# This script sets up the development environment for the monorepo

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system requirements
check_requirements() {
    log "🔍 Checking system requirements..."
    
    # Check Node.js
    if command_exists node; then
        NODE_VERSION=$(node --version)
        log "✅ Node.js found: $NODE_VERSION"
    else
        error "❌ Node.js not found. Please install Node.js >= 18.0.0"
        exit 1
    fi
    
    # Check npm
    if command_exists npm; then
        NPM_VERSION=$(npm --version)
        log "✅ npm found: $NPM_VERSION"
    else
        error "❌ npm not found. Please install npm"
        exit 1
    fi
    
    # Check Flutter
    if command_exists flutter; then
        FLUTTER_VERSION=$(flutter --version | head -n 1)
        log "✅ Flutter found: $FLUTTER_VERSION"
    else
        error "❌ Flutter not found. Please install Flutter SDK >= 3.2.0"
        exit 1
    fi
    
    # Check Dart
    if command_exists dart; then
        DART_VERSION=$(dart --version)
        log "✅ Dart found: $DART_VERSION"
    else
        warn "⚠️ Dart not found separately (should be included with Flutter)"
    fi
    
    # Check Go
    if command_exists go; then
        GO_VERSION=$(go version)
        log "✅ Go found: $GO_VERSION"
    else
        error "❌ Go not found. Please install Go >= 1.21"
        exit 1
    fi
    
    # Check Git
    if command_exists git; then
        GIT_VERSION=$(git --version)
        log "✅ Git found: $GIT_VERSION"
    else
        error "❌ Git not found. Please install Git"
        exit 1
    fi
    
    # Check Docker (optional)
    if command_exists docker; then
        DOCKER_VERSION=$(docker --version)
        log "✅ Docker found: $DOCKER_VERSION"
    else
        warn "⚠️ Docker not found. Docker is optional but recommended for backend development"
    fi
}

# Setup Flutter development tools
setup_flutter() {
    log "📱 Setting up Flutter development environment..."
    
    cd packages/mobile
    
    # Get Flutter dependencies
    log "Installing Flutter dependencies..."
    flutter pub get
    
    # Check Flutter doctor
    log "Running Flutter doctor..."
    flutter doctor
    
    # Enable Flutter platforms
    log "Enabling Flutter platforms..."
    flutter config --enable-web
    flutter config --enable-macos-desktop
    flutter config --enable-windows-desktop
    flutter config --enable-linux-desktop
    
    cd ../..
    log "✅ Flutter setup complete"
}

# Setup Go development tools
setup_go() {
    log "🔧 Setting up Go development environment..."
    
    cd packages/server
    
    # Download Go modules
    log "Downloading Go modules..."
    go mod download
    go mod tidy
    
    # Install development tools
    log "Installing Go development tools..."
    
    # golangci-lint for linting
    if ! command_exists golangci-lint; then
        log "Installing golangci-lint..."
        curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.54.2
    fi
    
    # air for hot reloading
    if ! command_exists air; then
        log "Installing air for hot reloading..."
        go install github.com/cosmtrek/air@latest
    fi
    
    # govulncheck for security scanning
    if ! command_exists govulncheck; then
        log "Installing govulncheck..."
        go install golang.org/x/vuln/cmd/govulncheck@latest
    fi
    
    # swag for API documentation
    if ! command_exists swag; then
        log "Installing swag for API documentation..."
        go install github.com/swaggo/swag/cmd/swag@latest
    fi
    
    cd ../..
    log "✅ Go setup complete"
}

# Setup Node.js development tools
setup_nodejs() {
    log "📦 Setting up Node.js development environment..."
    
    # Install npm dependencies
    log "Installing npm dependencies..."
    npm install
    
    # Install global tools
    log "Installing global development tools..."
    
    # Prettier for formatting
    if ! command_exists prettier; then
        npm install -g prettier
    fi
    
    # Commitizen for conventional commits
    if ! command_exists git-cz; then
        npm install -g commitizen
        npm install -g cz-conventional-changelog
    fi
    
    log "✅ Node.js setup complete"
}

# Setup Git hooks
setup_git_hooks() {
    log "🪝 Setting up Git hooks..."
    
    # Install husky if not already done
    if [ ! -d ".husky" ]; then
        npx husky install
    fi
    
    # Create pre-commit hook
    cat << 'EOF' > .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "🔍 Running pre-commit checks..."

# Run linting and tests
npm run precommit

echo "✅ Pre-commit checks passed!"
EOF
    chmod +x .husky/pre-commit
    
    # Create commit message hook
    cat << 'EOF' > .husky/commit-msg
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx --no-install commitlint --edit $1
EOF
    chmod +x .husky/commit-msg
    
    log "✅ Git hooks setup complete"
}

# Setup development environment files
setup_env_files() {
    log "📄 Setting up environment files..."
    
    # Mobile environment
    if [ ! -f "packages/mobile/.env" ]; then
        cat << 'EOF' > packages/mobile/.env
# Development environment
DEV_API_URL=http://localhost:8080
DEBUG_LOGGING=true

# Production environment (uncomment for production builds)
# PROD_API_URL=https://api.peloton-communicator.com
# DEBUG_LOGGING=false
EOF
        log "📱 Created mobile .env file"
    fi
    
    # Server environment
    if [ ! -f "packages/server/.env" ]; then
        cat << 'EOF' > packages/server/.env
# Server configuration
PORT=8080
HOST=0.0.0.0
ENV=development

# Database configuration (when implemented)
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=peloton_communicator
# DB_USER=postgres
# DB_PASSWORD=password

# Redis configuration (when implemented)
# REDIS_URL=redis://localhost:6379

# JWT configuration (when implemented)
# JWT_SECRET=your-development-secret-key-change-in-production
# JWT_EXPIRATION=24h

# CORS configuration
CORS_ALLOWED_ORIGINS=*
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS
CORS_ALLOWED_HEADERS=*

# Logging
LOG_LEVEL=debug
LOG_FORMAT=text
EOF
        log "🔧 Created server .env file"
    fi
    
    log "✅ Environment files setup complete"
}

# Setup VSCode workspace
setup_vscode() {
    log "💻 Setting up VSCode workspace..."
    
    mkdir -p .vscode
    
    # VSCode settings
    cat << 'EOF' > .vscode/settings.json
{
  "dart.flutterSdkPath": null,
  "go.useLanguageServer": true,
  "go.formatTool": "goimports",
  "go.lintTool": "golangci-lint",
  "go.testFlags": ["-v", "-race"],
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  },
  "files.exclude": {
    "**/build/": true,
    "**/coverage/": true,
    "**/.dart_tool/": true,
    "**/node_modules/": true
  },
  "files.watcherExclude": {
    "**/build/**": true,
    "**/.dart_tool/**": true,
    "**/node_modules/**": true
  }
}
EOF
    
    # VSCode extensions recommendations
    cat << 'EOF' > .vscode/extensions.json
{
  "recommendations": [
    "dart-code.dart-code",
    "dart-code.flutter",
    "golang.go",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-typescript-next",
    "github.vscode-pull-request-github",
    "github.copilot",
    "ms-azuretools.vscode-docker"
  ]
}
EOF
    
    # VSCode launch configurations
    cat << 'EOF' > .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter: Launch Mobile App",
      "cwd": "packages/mobile",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart"
    },
    {
      "name": "Go: Launch Server",
      "type": "go",
      "request": "launch",
      "mode": "auto",
      "cwd": "${workspaceFolder}/packages/server",
      "program": "main.go",
      "env": {},
      "args": []
    }
  ]
}
EOF
    
    # VSCode tasks
    cat << 'EOF' > .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Flutter: Get Packages",
      "type": "shell",
      "command": "flutter",
      "args": ["pub", "get"],
      "options": {
        "cwd": "${workspaceFolder}/packages/mobile"
      },
      "group": "build",
      "problemMatcher": []
    },
    {
      "label": "Flutter: Run Tests",
      "type": "shell",
      "command": "flutter",
      "args": ["test"],
      "options": {
        "cwd": "${workspaceFolder}/packages/mobile"
      },
      "group": "test",
      "problemMatcher": []
    },
    {
      "label": "Go: Build Server",
      "type": "shell",
      "command": "go",
      "args": ["build", "-o", "bin/server", "."],
      "options": {
        "cwd": "${workspaceFolder}/packages/server"
      },
      "group": "build",
      "problemMatcher": []
    },
    {
      "label": "Go: Run Tests",
      "type": "shell",
      "command": "go",
      "args": ["test", "./..."],
      "options": {
        "cwd": "${workspaceFolder}/packages/server"
      },
      "group": "test",
      "problemMatcher": []
    }
  ]
}
EOF
    
    log "✅ VSCode workspace setup complete"
}

# Run initial tests
run_initial_tests() {
    log "🧪 Running initial tests..."
    
    # Test Flutter
    log "Testing Flutter setup..."
    cd packages/mobile
    flutter test --no-coverage || warn "Flutter tests failed - this is expected for new projects"
    cd ../..
    
    # Test Go
    log "Testing Go setup..."
    cd packages/server
    go test ./... || warn "Go tests failed - this is expected for new projects"
    cd ../..
    
    log "✅ Initial tests complete"
}

# Main setup function
main() {
    log "🚀 Starting Peloton Communicator development setup..."
    log "This script will set up your development environment for the monorepo."
    echo
    
    check_requirements
    echo
    
    setup_nodejs
    echo
    
    setup_flutter
    echo
    
    setup_go
    echo
    
    setup_git_hooks
    echo
    
    setup_env_files
    echo
    
    setup_vscode
    echo
    
    run_initial_tests
    echo
    
    log "🎉 Setup complete! Your development environment is ready."
    echo
    info "Next steps:"
    echo "  1. 📱 Start mobile development: cd packages/mobile && flutter run"
    echo "  2. 🔧 Start server development: cd packages/server && air"
    echo "  3. 📖 Read the documentation: open README.md"
    echo "  4. 🧪 Run tests: npm test"
    echo "  5. 🎨 Format code: npm run format"
    echo
    info "Useful commands:"
    echo "  • npm run dev          - Start both mobile and server in development mode"
    echo "  • npm run test         - Run all tests"
    echo "  • npm run lint         - Run all linters"
    echo "  • npm run build        - Build all packages"
    echo "  • npm run clean        - Clean all build artifacts"
    echo
    log "Happy coding! 🚀"
}

# Run main function
main "$@"