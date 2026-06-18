// internal/config/config.go
//
// Konfigurasi aplikasi.
// Membaca environment variables dari file .env menggunakan godotenv.
// Semua konfigurasi (database, server, MQTT, JWT) dipusatkan di sini.

package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config menyimpan seluruh konfigurasi aplikasi.
type Config struct {
	// Server
	AppPort string
	AppEnv  string

	// Database PostgreSQL
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string

	// MQTT Broker
	MQTTBrokerHost string
	MQTTBrokerPort string
	MQTTClientID   string
	MQTTUsername   string
	MQTTPassword   string

	// JWT
	JWTSecret          string
	JWTExpirationHours int
}

// Load membaca konfigurasi dari environment variables.
// File .env akan dimuat jika tersedia (untuk development lokal).
func Load() *Config {
	// Coba muat file .env. Jika tidak ada, gunakan env variables sistem.
	if err := godotenv.Load(); err != nil {
		log.Println("[CONFIG] File .env tidak ditemukan, menggunakan environment variables sistem.")
	}

	return &Config{
		// Server
		AppPort: getEnv("APP_PORT", "3000"),
		AppEnv:  getEnv("APP_ENV", "development"),

		// Database
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "postgres"),
		DBPassword: getEnv("DB_PASSWORD", "postgres"),
		DBName:     getEnv("DB_NAME", "kombong_genz"),
		DBSSLMode:  getEnv("DB_SSLMODE", "disable"),

		// MQTT
		MQTTBrokerHost: getEnv("MQTT_BROKER_HOST", "localhost"),
		MQTTBrokerPort: getEnv("MQTT_BROKER_PORT", "1883"),
		MQTTClientID:   getEnv("MQTT_CLIENT_ID", "kombong_genz_server"),
		MQTTUsername:   getEnv("MQTT_USERNAME", ""),
		MQTTPassword:   getEnv("MQTT_PASSWORD", ""),

		// JWT
		JWTSecret:          getEnv("JWT_SECRET", "GANTI_DENGAN_SECRET_YANG_AMAN"),
		JWTExpirationHours: getEnvInt("JWT_EXPIRATION_HOURS", 24),
	}
}

// getEnv mengambil nilai environment variable.
// Jika tidak ada, mengembalikan nilai defaultValue.
func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

// getEnvInt mengambil nilai environment variable sebagai integer.
// Jika tidak ada atau tidak dapat diparse, mengembalikan defaultValue.
func getEnvInt(key string, defaultValue int) int {
	if value, exists := os.LookupEnv(key); exists {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
		log.Printf("[CONFIG] Nilai env %s='%s' bukan integer yang valid, menggunakan default: %d", key, value, defaultValue)
	}
	return defaultValue
}
