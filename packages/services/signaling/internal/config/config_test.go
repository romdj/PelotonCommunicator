package config

import (
	"reflect"
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	for _, key := range []string{"HOST", "PORT", "ALLOWED_ORIGINS", "LOG_LEVEL", "LOG_JSON"} {
		t.Setenv(key, "")
	}

	cfg := Load()

	if cfg.Host != "0.0.0.0" {
		t.Errorf("Host = %q, want %q", cfg.Host, "0.0.0.0")
	}
	if cfg.Port != 8080 {
		t.Errorf("Port = %d, want 8080", cfg.Port)
	}
	if !reflect.DeepEqual(cfg.AllowedOrigins, []string{"*"}) {
		t.Errorf("AllowedOrigins = %v, want [*]", cfg.AllowedOrigins)
	}
	if cfg.LogLevel != "info" {
		t.Errorf("LogLevel = %q, want %q", cfg.LogLevel, "info")
	}
	if cfg.LogJSON {
		t.Error("LogJSON = true, want false")
	}
}

func TestLoadFromEnvironment(t *testing.T) {
	t.Setenv("HOST", "127.0.0.1")
	t.Setenv("PORT", "9090")
	t.Setenv("LOG_LEVEL", "debug")
	t.Setenv("LOG_JSON", "true")

	cfg := Load()

	if cfg.Host != "127.0.0.1" || cfg.Port != 9090 || cfg.LogLevel != "debug" || !cfg.LogJSON {
		t.Errorf("Load() = %+v, want values from environment", cfg)
	}
}

func TestLoadFallsBackOnMalformedValues(t *testing.T) {
	t.Setenv("PORT", "not-a-port")
	t.Setenv("LOG_JSON", "maybe")

	cfg := Load()

	if cfg.Port != 8080 {
		t.Errorf("Port = %d, want default 8080 for malformed value", cfg.Port)
	}
	if cfg.LogJSON {
		t.Error("LogJSON = true, want default false for malformed value")
	}
}

func TestAllowedOriginsIsCommaSeparated(t *testing.T) {
	t.Setenv("ALLOWED_ORIGINS", "https://a.example, https://b.example,,")

	cfg := Load()

	want := []string{"https://a.example", "https://b.example"}
	if !reflect.DeepEqual(cfg.AllowedOrigins, want) {
		t.Errorf("AllowedOrigins = %q, want %q", cfg.AllowedOrigins, want)
	}
}
