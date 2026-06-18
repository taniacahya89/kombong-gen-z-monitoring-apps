// cmd/server/main.go
//
// Titik masuk utama aplikasi Go Fiber Backend.
// Menginisialisasi komponen berikut secara berurutan:
//   1. Konfigurasi (dari .env / environment variables)
//   2. Koneksi PostgreSQL
//   3. Migrasi skema database
//   4. Koneksi MQTT Broker
//   5. Go Fiber app (dengan middleware: CORS, Logger, Recover)
//   6. Pendaftaran route
//   7. Graceful shutdown
//
// Cara menjalankan:
//   go run ./cmd/server/main.go
//
// Atau setelah build:
//   ./server

package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"

	"kombong-genz-backend/internal/config"
	"kombong-genz-backend/internal/database"
	"kombong-genz-backend/internal/mqtt"
	"kombong-genz-backend/internal/routes"
	"kombong-genz-backend/internal/worker"
)

func main() {
	// -------------------------------------------------------------------------
	// 1. LOAD KONFIGURASI
	// -------------------------------------------------------------------------
	cfg := config.Load()
	log.Printf("[MAIN] Menjalankan server dalam mode: %s", cfg.AppEnv)

	// -------------------------------------------------------------------------
	// 2. KONEKSI DATABASE POSTGRESQL
	// -------------------------------------------------------------------------
	if err := database.Connect(cfg); err != nil {
		log.Fatalf("[MAIN] Gagal koneksi ke database: %v", err)
	}
	defer database.Close()

	// -------------------------------------------------------------------------
	// 3. MIGRASI SKEMA DATABASE
	// -------------------------------------------------------------------------
	if err := database.Migrate(); err != nil {
		log.Fatalf("[MAIN] Gagal migrasi database: %v", err)
	}

	// Seed akun default (idempoten: lewati jika sudah ada)
	if err := database.SeedDefaultUsers(); err != nil {
		log.Fatalf("[MAIN] Gagal seed user default: %v", err)
	}

	// -------------------------------------------------------------------------
	// 4. BACKGROUND WORKER: Pembersihan data historis
	// Context untuk graceful shutdown: cancel() dipanggil saat sinyal OS diterima.
	// Worker berhenti bersih tanpa mengganggu request yang sedang diproses.
	// -------------------------------------------------------------------------
	workerCtx, workerCancel := context.WithCancel(context.Background())
	defer workerCancel()
	go worker.StartCleanupWorker(workerCtx)

	// -------------------------------------------------------------------------
	// 4. KONEKSI MQTT BROKER
	// Jalankan di goroutine terpisah agar tidak memblokir startup server.
	// -------------------------------------------------------------------------
	mqttClient := mqtt.NewClient(cfg)
	go func() {
		if err := mqttClient.Connect(); err != nil {
			log.Printf("[MAIN] Peringatan: MQTT tidak terhubung: %v", err)
			log.Println("[MAIN] Server tetap berjalan tanpa MQTT.")
		}
	}()
	defer mqttClient.Disconnect()

	// -------------------------------------------------------------------------
	// 5. INISIALISASI FIBER APP
	// -------------------------------------------------------------------------
	app := fiber.New(fiber.Config{
		AppName:      "Kombong GenZ API v1.0.0",
		// Custom error handler untuk format respons yang konsisten
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if e, ok := err.(*fiber.Error); ok {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{
				"success": false,
				"error":   err.Error(),
			})
		},
	})

	// Middleware: Recovery dari panic
	app.Use(recover.New())

	// Middleware: Logger request/response
	app.Use(logger.New(logger.Config{
		Format: "[${time}] ${method} ${path} -> ${status} (${latency})\n",
	}))

	// Middleware: CORS
	// Sesuaikan AllowOrigins sebelum deploy ke production.
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	// -------------------------------------------------------------------------
	// 6. DAFTARKAN ROUTE
	// -------------------------------------------------------------------------
	routes.Setup(app, cfg, mqttClient)

	// -------------------------------------------------------------------------
	// 7. JALANKAN SERVER + GRACEFUL SHUTDOWN
	// -------------------------------------------------------------------------
	serverAddr := fmt.Sprintf(":%s", cfg.AppPort)

	// Channel untuk mendengarkan sinyal OS (Ctrl+C, SIGTERM)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	// Jalankan server di goroutine terpisah
	go func() {
		log.Printf("[MAIN] Server berjalan di http://localhost%s", serverAddr)
		if err := app.Listen(serverAddr); err != nil {
			log.Fatalf("[MAIN] Error menjalankan server: %v", err)
		}
	}()

	// Tunggu sinyal shutdown
	<-quit

	log.Println("[MAIN] Mematikan server secara graceful...")
	if err := app.Shutdown(); err != nil {
		log.Printf("[MAIN] Error saat shutdown: %v", err)
	}

	log.Println("[MAIN] Server berhenti. Sampai jumpa!")
}
