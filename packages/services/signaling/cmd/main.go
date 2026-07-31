package main

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/peloton-communicator/signaling/internal/config"
	ws "github.com/peloton-communicator/signaling/internal/websocket"
)

var (
	upgrader = websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		// For MVP, allow all origins. In production, restrict this.
		CheckOrigin: func(r *http.Request) bool {
			return true
		},
	}
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Setup logging
	setupLogging(cfg)

	// Create the WebSocket hub
	hub := ws.NewHub()
	go hub.Run()

	// Setup HTTP routes
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		handleWebSocket(hub, w, r)
	})

	http.HandleFunc("/health", handleHealth)

	http.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		handleStats(hub, w, r)
	})

	// Start server
	addr := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)
	log.Info().
		Str("address", addr).
		Msg("Starting signaling server")

	server := &http.Server{
		Addr:         addr,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatal().Err(err).Msg("Server failed to start")
	}
}

// setupLogging configures the zerolog logger
func setupLogging(cfg *config.Config) {
	// Set log level
	level, err := zerolog.ParseLevel(cfg.LogLevel)
	if err != nil {
		level = zerolog.InfoLevel
	}
	zerolog.SetGlobalLevel(level)

	// Configure output format
	if cfg.LogJSON {
		// JSON output for production
		log.Logger = zerolog.New(os.Stdout).With().Timestamp().Logger()
	} else {
		// Pretty console output for development
		log.Logger = zerolog.New(zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: time.RFC3339,
		}).With().Timestamp().Logger()
	}
}

// handleWebSocket upgrades HTTP connections to WebSocket
func handleWebSocket(hub *ws.Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to upgrade connection")
		return
	}

	// Extract client identifiers from query params or headers
	// For MVP, we generate simple IDs. In production, use JWT tokens.
	userID := r.URL.Query().Get("userId")
	if userID == "" {
		userID = fmt.Sprintf("user_%d", time.Now().UnixNano())
	}

	deviceInfo := r.URL.Query().Get("deviceInfo")
	if deviceInfo == "" {
		deviceInfo = r.UserAgent()
	}

	clientID := fmt.Sprintf("client_%d", time.Now().UnixNano())

	// Create client
	client := ws.NewClient(clientID, userID, deviceInfo, hub, conn)

	// Register client with hub
	hub.Register(client)

	log.Info().
		Str("clientID", clientID).
		Str("userID", userID).
		Str("remoteAddr", r.RemoteAddr).
		Msg("WebSocket connection established")

	// Start client goroutines
	go client.WritePump()
	go client.ReadPump()
}

// handleHealth returns a simple health check response
func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy"}`))
}

// handleStats returns server statistics
func handleStats(hub *ws.Hub, w http.ResponseWriter, r *http.Request) {
	clients, rooms := hub.Stats()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf(`{"clients":%d,"rooms":%d}`, clients, rooms)))
}
