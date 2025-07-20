#!/bin/bash

# Build All Packages Script
# Builds all packages for production deployment

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Create dist directory
mkdir -p dist

log "🏗️ Building all packages for production..."

# Build Mobile Package
log "📱 Building Mobile Package..."
cd packages/mobile

# Clean previous builds
flutter clean
flutter pub get

# Build Android
log "🤖 Building Android APK..."
if flutter build apk --release; then
    log "✅ Android APK build successful"
    cp build/app/outputs/flutter-apk/app-release.apk ../../dist/peloton-communicator-android.apk
else
    error "❌ Android APK build failed"
    ANDROID_FAILED=1
fi

# Build Android App Bundle
log "📦 Building Android App Bundle..."
if flutter build appbundle --release; then
    log "✅ Android App Bundle build successful"
    cp build/app/outputs/bundle/release/app-release.aab ../../dist/peloton-communicator-android.aab
else
    error "❌ Android App Bundle build failed"
    AAB_FAILED=1
fi

# Build iOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    log "🍎 Building iOS..."
    if flutter build ios --release --no-codesign; then
        log "✅ iOS build successful"
        # Create IPA-ready directory structure
        mkdir -p ../../dist/ios-build
        cp -r build/ios/iphoneos/Runner.app ../../dist/ios-build/
        log "📁 iOS app copied to dist/ios-build/"
    else
        error "❌ iOS build failed"
        IOS_FAILED=1
    fi
else
    warn "⚠️ Skipping iOS build (not on macOS)"
fi

cd ../..

# Build Server Package
log "🔧 Building Server Package..."
cd packages/server

# Build for multiple platforms
PLATFORMS=("linux/amd64" "darwin/amd64" "darwin/arm64" "windows/amd64")

for platform in "${PLATFORMS[@]}"; do
    GOOS=${platform%/*}
    GOARCH=${platform#*/}
    
    log "🏗️ Building for $GOOS/$GOARCH..."
    
    OUTPUT_NAME="peloton-server-$GOOS-$GOARCH"
    if [ "$GOOS" = "windows" ]; then
        OUTPUT_NAME="$OUTPUT_NAME.exe"
    fi
    
    if CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go build -a -installsuffix cgo -ldflags="-w -s" -o "../../dist/$OUTPUT_NAME" .; then
        log "✅ $GOOS/$GOARCH build successful"
    else
        error "❌ $GOOS/$GOARCH build failed"
        SERVER_FAILED=1
    fi
done

cd ../..

# Build Docker Images
log "🐳 Building Docker Images..."

# Server Docker image
cd packages/server
if docker build -t peloton-communicator-server:latest .; then
    log "✅ Server Docker image built successfully"
    # Save Docker image
    docker save peloton-communicator-server:latest | gzip > ../../dist/peloton-server-docker.tar.gz
    log "💾 Docker image saved to dist/peloton-server-docker.tar.gz"
else
    error "❌ Server Docker build failed"
    DOCKER_FAILED=1
fi

cd ../..

# Generate build info
log "📄 Generating build information..."
cat << EOF > dist/build-info.json
{
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gitCommit": "$(git rev-parse HEAD)",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD)",
  "version": "$(git describe --tags --always --dirty)",
  "builds": {
    "mobile": {
      "android": {
        "apk": "$([ ! "${ANDROID_FAILED}" = "1" ] && echo "success" || echo "failed")",
        "aab": "$([ ! "${AAB_FAILED}" = "1" ] && echo "success" || echo "failed")"
      },
      "ios": "$([ ! "${IOS_FAILED}" = "1" ] && echo "success" || echo "skipped/failed")"
    },
    "server": {
      "binaries": "$([ ! "${SERVER_FAILED}" = "1" ] && echo "success" || echo "failed")",
      "docker": "$([ ! "${DOCKER_FAILED}" = "1" ] && echo "success" || echo "failed")"
    }
  }
}
EOF

# Generate checksums
log "🔐 Generating checksums..."
cd dist
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum * > checksums.sha256
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 * > checksums.sha256
else
    warn "⚠️ No checksum utility found, skipping checksum generation"
fi
cd ..

# Create README for dist directory
cat << 'EOF' > dist/README.md
# Peloton Communicator Build Artifacts

This directory contains production-ready build artifacts for the Peloton Communicator project.

## Mobile Apps

### Android
- `peloton-communicator-android.apk` - Release APK for direct installation
- `peloton-communicator-android.aab` - App Bundle for Google Play Store

### iOS
- `ios-build/` - iOS application build (requires signing and packaging)

## Server

### Binaries
- `peloton-server-linux-amd64` - Linux x64 binary
- `peloton-server-darwin-amd64` - macOS Intel binary  
- `peloton-server-darwin-arm64` - macOS Apple Silicon binary
- `peloton-server-windows-amd64.exe` - Windows x64 binary

### Docker
- `peloton-server-docker.tar.gz` - Docker image archive

## Verification

- `checksums.sha256` - SHA256 checksums for all artifacts
- `build-info.json` - Build metadata and status

## Usage

### Android Installation
```bash
adb install peloton-communicator-android.apk
```

### Server Deployment
```bash
# Linux/macOS
chmod +x peloton-server-linux-amd64
./peloton-server-linux-amd64

# Docker
docker load < peloton-server-docker.tar.gz
docker run -p 8080:8080 peloton-communicator-server:latest
```
EOF

# Summary
log "📊 Build Summary:"
echo "────────────────────────────────────────────────"

if [ ! "${ANDROID_FAILED}" = "1" ]; then
    log "✅ Android APK: SUCCESS"
else
    error "❌ Android APK: FAILED"
fi

if [ ! "${AAB_FAILED}" = "1" ]; then
    log "✅ Android App Bundle: SUCCESS"
else
    error "❌ Android App Bundle: FAILED"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ ! "${IOS_FAILED}" = "1" ]; then
        log "✅ iOS: SUCCESS"
    else
        error "❌ iOS: FAILED"
    fi
else
    warn "⚠️ iOS: SKIPPED (not on macOS)"
fi

if [ ! "${SERVER_FAILED}" = "1" ]; then
    log "✅ Server Binaries: SUCCESS"
else
    error "❌ Server Binaries: FAILED"
fi

if [ ! "${DOCKER_FAILED}" = "1" ]; then
    log "✅ Docker Image: SUCCESS"
else
    error "❌ Docker Image: FAILED"
fi

echo "────────────────────────────────────────────────"

# Check overall success
if [ "${ANDROID_FAILED}" = "1" ] || [ "${AAB_FAILED}" = "1" ] || [ "${IOS_FAILED}" = "1" ] || [ "${SERVER_FAILED}" = "1" ] || [ "${DOCKER_FAILED}" = "1" ]; then
    error "❌ Some builds failed. Check the output above for details."
    exit 1
else
    log "🎉 All builds completed successfully!"
    log "📁 Build artifacts available in: dist/"
    
    # Show dist directory contents
    echo
    info "📦 Build artifacts:"
    ls -la dist/
fi