# Peloton Communicator

A cross-platform push-to-talk communication system designed for group activities like cycling, running, and fitness sessions.

## 🏗️ Architecture

This is a monorepo containing multiple packages that work together to provide a complete communication solution:

```
├── packages/
│   ├── mobile/          # Flutter mobile app (iOS/Android)
│   └── server/          # Go backend API server
├── docs/                # Documentation
├── scripts/             # Build and deployment scripts
└── .github/workflows/   # CI/CD pipelines
```

## 📱 Features

### Mobile App
- **Push-to-Talk (PTT)** functionality with Bluetooth headset support
- **Dual PTT modes**: Toggle mode and Hold mode
- **Cross-platform**: iOS and Android support
- **Real-time communication** ready infrastructure
- **Modern UI** with state-aware visual feedback

### Backend Server
- **RESTful API** built with Go
- **WebRTC signaling** support (planned)
- **Room management** for group communications
- **OpenAPI/Swagger** documentation

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK** >= 3.2.0
- **Go** >= 1.21
- **Node.js** >= 18 (for tooling)

### Mobile App Development
```bash
cd packages/mobile
flutter pub get
flutter run
```

### Backend Development
```bash
cd packages/server
go mod tidy
go run main.go
```

## 🛠️ Development

### Project Status
- ✅ **Flutter Mobile App**: Core PTT functionality implemented
- ✅ **Android Support**: Full Bluetooth headset button capture
- ⚠️ **iOS Support**: UI complete, button capture limited by system restrictions
- 🚧 **Backend API**: Basic structure in place, needs WebRTC integration
- 📋 **Documentation**: In progress

### Known Limitations
- **iOS**: Media button capture restricted by Apple's security policies
- **Long Press**: Triggers system voice assistants on both platforms
- **Recommendation**: Focus on Android deployment for full functionality

## 📚 Documentation

- [Mobile App Documentation](./packages/mobile/README.md)
- [Backend API Documentation](./packages/server/README.md)
- [Architecture Overview](./docs/architecture.md)
- [Development Guide](./docs/development.md)

## 🧪 Testing

Run all tests:
```bash
# Mobile tests
cd packages/mobile && flutter test

# Backend tests  
cd packages/server && go test ./...

# Integration tests
./scripts/test-all.sh
```

## 🚢 Deployment

### CI/CD
- **GitHub Actions** for automated testing and builds
- **Flutter**: Automated builds for iOS and Android
- **Go**: Automated testing and Docker builds
- **Quality Gates**: Linting, testing, and security checks

### Production
```bash
# Build mobile apps
./scripts/build-mobile.sh

# Deploy backend
./scripts/deploy-server.sh
```

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Development Standards
- **Code Style**: Follow language-specific style guides
- **Testing**: Maintain >80% test coverage
- **Documentation**: Update docs for all public APIs
- **Linting**: All code must pass linting checks

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Acknowledgments

- **Flutter Team** for the excellent cross-platform framework
- **WebRTC Community** for real-time communication protocols
- **Open Source Contributors** who make projects like this possible

---

**Built with ❤️ for better group communication**