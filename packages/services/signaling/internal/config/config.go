package config

import (
	"os"
	"strconv"
)

// Config holds the application configuration
type Config struct {
	// Server settings
	Host string
	Port int

	// CORS settings
	AllowedOrigins []string

	// Logging
	LogLevel string
	LogJSON  bool
}

// Load loads configuration from environment variables with defaults
func Load() *Config {
	return &Config{
		Host:           getEnv("HOST", "0.0.0.0"),
		Port:           getEnvInt("PORT", 8080),
		AllowedOrigins: getEnvList("ALLOWED_ORIGINS", []string{"*"}),
		LogLevel:       getEnv("LOG_LEVEL", "info"),
		LogJSON:        getEnvBool("LOG_JSON", false),
	}
}

// getEnv returns an environment variable or a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt returns an environment variable as int or a default value
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// getEnvBool returns an environment variable as bool or a default value
func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolVal, err := strconv.ParseBool(value); err == nil {
			return boolVal
		}
	}
	return defaultValue
}

// getEnvList returns an environment variable as a comma-separated list
func getEnvList(key string, defaultValue []string) []string {
	if value := os.Getenv(key); value != "" {
		// Simple split by comma - could be enhanced with proper parsing
		return []string{value}
	}
	return defaultValue
}
