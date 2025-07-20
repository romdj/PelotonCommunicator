#!/bin/bash

# Test All Packages Script
# Runs tests for all packages in the monorepo with coverage and reporting

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Create reports directory
mkdir -p reports/coverage

log "🧪 Running all tests with coverage..."

# Test Mobile Package
log "📱 Testing Mobile Package..."
cd packages/mobile

if flutter test --coverage; then
    log "✅ Mobile tests passed"
    # Move coverage report
    if [ -f "coverage/lcov.info" ]; then
        cp coverage/lcov.info ../../reports/coverage/mobile-coverage.lcov
        log "📊 Mobile coverage report saved"
    fi
else
    error "❌ Mobile tests failed"
    MOBILE_FAILED=1
fi

cd ../..

# Test Server Package
log "🔧 Testing Server Package..."
cd packages/server

if go test -v -race -coverprofile=../../reports/coverage/server-coverage.out ./...; then
    log "✅ Server tests passed"
    # Generate HTML coverage report
    go tool cover -html=../../reports/coverage/server-coverage.out -o ../../reports/coverage/server-coverage.html
    log "📊 Server coverage report saved"
else
    error "❌ Server tests failed"
    SERVER_FAILED=1
fi

cd ../..

# Generate combined coverage report
log "📊 Generating combined coverage report..."
cat << 'EOF' > reports/coverage/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Peloton Communicator - Test Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .package { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 8px; }
        .package h3 { color: #27ae60; margin-top: 0; }
        .links a { display: inline-block; margin: 10px 10px 10px 0; padding: 8px 16px; 
                   background: #3498db; color: white; text-decoration: none; border-radius: 4px; }
        .links a:hover { background: #2980b9; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Peloton Communicator Test Coverage</h1>
        <p>Generated on: $(date)</p>
    </div>
    
    <div class="package">
        <h3>📱 Mobile Package (Flutter)</h3>
        <p>Flutter application with PTT functionality</p>
        <div class="links">
            <a href="mobile-coverage.lcov">LCOV Report</a>
        </div>
    </div>
    
    <div class="package">
        <h3>🔧 Server Package (Go)</h3>
        <p>Backend API server with WebRTC signaling</p>
        <div class="links">
            <a href="server-coverage.html">HTML Report</a>
            <a href="server-coverage.out">Coverage Data</a>
        </div>
    </div>
    
    <div class="package">
        <h3>📊 Summary</h3>
        <p>Test execution completed. Check individual reports for detailed coverage information.</p>
    </div>
</body>
</html>
EOF

log "📄 Combined coverage report generated at reports/coverage/index.html"

# Check if any tests failed
if [ "${MOBILE_FAILED}" = "1" ] || [ "${SERVER_FAILED}" = "1" ]; then
    error "❌ Some tests failed. Check the output above for details."
    exit 1
else
    log "✅ All tests passed successfully!"
    log "📊 View coverage reports:"
    log "   • Combined: reports/coverage/index.html"
    log "   • Mobile: reports/coverage/mobile-coverage.lcov"
    log "   • Server: reports/coverage/server-coverage.html"
fi