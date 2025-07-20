# Peloton Communicator Backend Server

Go-based REST API server providing backend services for the Peloton Communicator platform with WebRTC signaling support.

## 🎯 Features

- **RESTful API** with OpenAPI/Swagger documentation
- **WebRTC Signaling** for real-time communication
- **Room Management** for group communication sessions
- **User Management** with authentication
- **Scalable Architecture** ready for production deployment

## 🏗️ Architecture

```
├── api/                   # API specifications
│   └── swagger.yaml       # OpenAPI documentation
├── generated/             # Auto-generated code from OpenAPI
│   ├── go/               # Generated Go server stubs
│   └── Dockerfile        # Container configuration
├── main.go               # Server entry point
└── test/                 # Test files
    └── main_test.go      # Unit tests
```

## 🚀 Getting Started

### Prerequisites
- **Go** >= 1.21
- **Docker** (optional, for containerized deployment)
- **OpenAPI Generator** (for API code generation)

### Installation
```bash
# Install dependencies
go mod tidy

# Run the server
go run main.go

# Or run with hot reload
go install github.com/cosmtrek/air@latest
air
```

### Development
```bash
# Generate API code from OpenAPI spec
openapi-generator generate -i api/swagger.yaml -g go-server -o generated/

# Run tests
go test ./...

# Build binary
go build -o bin/server main.go
```

## 📡 API Documentation

The server provides the following endpoints:

### Health Check
```
GET /health
```

### User Management
```
POST /users          # Create user
GET /users/{id}      # Get user details
PUT /users/{id}      # Update user
DELETE /users/{id}   # Delete user
```

### Room Management
```
POST /rooms          # Create communication room
GET /rooms/{id}      # Get room details
PUT /rooms/{id}      # Update room
DELETE /rooms/{id}   # Delete room
POST /rooms/{id}/join    # Join room
POST /rooms/{id}/leave   # Leave room
```

### WebRTC Signaling
```
WebSocket /ws/signaling/{roomId}  # WebRTC signaling endpoint
```

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
go test ./...

# Run with coverage
go test -cover ./...

# Run with verbose output
go test -v ./...
```

### Integration Tests
```bash
# Run integration tests
go test -tags=integration ./...
```

### Load Testing
```bash
# Install load testing tools
go install github.com/golang/go@latest

# Run load tests
./scripts/load-test.sh
```

## 🐳 Docker Deployment

### Build Image
```bash
# Build Docker image
docker build -t peloton-communicator-server .

# Run container
docker run -p 8080:8080 peloton-communicator-server
```

### Docker Compose
```bash
# Run with dependencies
docker-compose up -d
```

## ⚙️ Configuration

### Environment Variables
```env
# Server configuration
PORT=8080
HOST=0.0.0.0

# Database configuration (future)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=peloton_communicator
DB_USER=postgres
DB_PASSWORD=password

# Redis configuration (future)
REDIS_URL=redis://localhost:6379

# JWT configuration (future)
JWT_SECRET=your-secret-key
JWT_EXPIRATION=24h
```

### Configuration File
Create `config.yaml`:
```yaml
server:
  port: 8080
  host: "0.0.0.0"
  timeout: 30s

logging:
  level: "info"
  format: "json"

cors:
  allowed_origins: ["*"]
  allowed_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  allowed_headers: ["*"]
```

## 🔒 Security

### Authentication (Planned)
- **JWT tokens** for stateless authentication
- **OAuth2** integration for social login
- **Rate limiting** to prevent abuse

### Data Protection
- **Input validation** on all endpoints
- **SQL injection** prevention
- **CORS** configuration for web security

## 📊 Monitoring

### Health Checks
```bash
# Check server health
curl http://localhost:8080/health

# Check detailed metrics (planned)
curl http://localhost:8080/metrics
```

### Logging
- **Structured logging** with configurable levels
- **Request/response logging** for debugging
- **Error tracking** with stack traces

## 🚢 Deployment

### Production Build
```bash
# Build optimized binary
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server main.go

# Build Docker image for production
docker build -f Dockerfile.prod -t peloton-server:latest .
```

### Kubernetes
```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: peloton-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: peloton-server
  template:
    metadata:
      labels:
        app: peloton-server
    spec:
      containers:
      - name: server
        image: peloton-server:latest
        ports:
        - containerPort: 8080
```

### Cloud Deployment
- **AWS ECS/EKS** for container orchestration
- **Google Cloud Run** for serverless deployment
- **Azure Container Instances** for simple hosting

## 🤝 Contributing

### Code Style
- Follow **Go best practices** and **Effective Go** guidelines
- Use **gofmt** for formatting
- Run **golangci-lint** before commits

### API Changes
1. **Update OpenAPI spec** in `api/swagger.yaml`
2. **Regenerate code** with OpenAPI generator
3. **Implement handlers** in the main application
4. **Add tests** for new functionality
5. **Update documentation**

### Development Setup
```bash
# Install development tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/swaggo/swag/cmd/swag@latest

# Setup git hooks
cp scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

## 🛣️ Roadmap

### Current Status
- ✅ **Basic REST API** structure
- ✅ **OpenAPI specification**
- ✅ **Docker support**
- 🚧 **WebRTC signaling** implementation
- 📋 **Database integration**
- 📋 **Authentication system**

### Planned Features
- **Real-time messaging** via WebSocket
- **Voice chat rooms** with WebRTC
- **User authentication** and authorization
- **Push notifications** for mobile apps
- **Admin dashboard** for room management

---

For questions or support, please see the [main project documentation](../../README.md).