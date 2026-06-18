// internal/routes/routes.go
//
// Pendaftaran seluruh route API untuk Go Fiber - Implementasi Penuh (Fase 2).
//
// Arsitektur proteksi endpoint menggunakan dua lapisan middleware:
//   1. middleware.JWTProtected(secret): memvalidasi token JWT pada semua
//      endpoint yang memerlukan autentikasi.
//   2. middleware.RequireRole("warga"): memblokir endpoint mutasi (POST/PUT/DELETE)
//      dari user dengan role 'guest'.
//
// Struktur route lengkap:
//   /api/v1/
//   ├── auth/           (Public)
//   │   ├── POST /register          -> AuthHandler.Register
//   │   ├── POST /login             -> AuthHandler.Login
//   │   └── POST /logout            -> AuthHandler.Logout
//   ├── auth/           (Protected - JWT)
//   │   ├── GET  /me                -> AuthHandler.GetMe
//   │   └── PUT  /change-password   -> AuthHandler.ChangePassword
//   ├── sensors/        (Protected - JWT, semua role)
//   │   ├── GET  /water-tank        -> SensorHandler.GetLatestWaterTank
//   │   ├── GET  /water-tank/history-> SensorHandler.GetWaterTankHistory
//   │   ├── GET  /power             -> SensorHandler.GetLatestPower
//   │   └── GET  /power/history     -> SensorHandler.GetPowerHistory
//   ├── feeding/        (Protected - JWT)
//   │   └── schedules/
//   │       ├── GET    /            -> ScheduleHandler.GetAll   (semua role)
//   │       ├── POST   /            -> ScheduleHandler.Create   (warga only)
//   │       ├── PUT    /:id         -> ScheduleHandler.Update   (warga only)
//   │       └── DELETE /:id         -> ScheduleHandler.Delete   (warga only)
//   └── notifications/  (Protected - JWT, semua role)
//       ├── GET  /                  -> SensorHandler.GetNotifications
//       ├── PUT  /:id/read          -> SensorHandler.MarkNotificationRead
//       └── PUT  /read-all          -> SensorHandler.MarkAllNotificationsRead

package routes

import (
	"github.com/gofiber/fiber/v2"

	"kombong-genz-backend/internal/config"
	"kombong-genz-backend/internal/handlers"
	"kombong-genz-backend/internal/middleware"
	mqttclient "kombong-genz-backend/internal/mqtt"
)

// Setup mendaftarkan seluruh route ke instance Fiber.
// Menerima konfigurasi dan MQTT client sebagai dependensi.
func Setup(app *fiber.App, cfg *config.Config, mqttClient *mqttclient.Client) {
	// Inisialisasi handler dengan dependensi yang diperlukan
	authHandler := handlers.NewAuthHandler(cfg.JWTSecret, cfg.JWTExpirationHours)
	sensorHandler := handlers.NewSensorHandler(mqttClient)
	scheduleHandler := handlers.NewScheduleHandler(mqttClient)

	// Prefix API v1
	api := app.Group("/api/v1")

	// Health check - selalu publik
	api.Get("/health", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"status":  "OK",
			"service": "Kombong GenZ API v2.0.0",
		})
	})

	// -------------------------------------------------------------------------
	// AUTH Routes
	// -------------------------------------------------------------------------
	auth := api.Group("/auth")

	// Endpoint publik (tidak memerlukan token)
	auth.Post("/register", authHandler.Register)
	auth.Post("/login", authHandler.Login)
	auth.Post("/logout", authHandler.Logout)

	// Endpoint terproteksi JWT (memerlukan token yang valid)
	authProtected := auth.Group("/", middleware.JWTProtected(cfg.JWTSecret))
	authProtected.Get("/me", authHandler.GetMe)
	authProtected.Put("/change-password", authHandler.ChangePassword)

	// -------------------------------------------------------------------------
	// SENSOR Routes (Terproteksi JWT, dapat diakses semua role)
	// -------------------------------------------------------------------------
	sensors := api.Group("/sensors", middleware.JWTProtected(cfg.JWTSecret))
	sensors.Get("/water-tank", sensorHandler.GetLatestWaterTank)
	sensors.Get("/water-tank/history", sensorHandler.GetWaterTankHistory)
	sensors.Get("/power", sensorHandler.GetLatestPower)
	sensors.Get("/power/history", sensorHandler.GetPowerHistory)
	// Endpoint deteksi online/offline perangkat IoT berdasarkan timestamp data terakhir
	sensors.Get("/status", sensorHandler.GetDeviceStatus)

	// -------------------------------------------------------------------------
	// FEEDING SCHEDULE Routes
	// Lapisan pertama: JWT wajib untuk semua operasi.
	// Lapisan kedua: role 'warga' wajib untuk operasi mutasi (POST/PUT/DELETE).
	// -------------------------------------------------------------------------
	feeding := api.Group("/feeding", middleware.JWTProtected(cfg.JWTSecret))
	schedules := feeding.Group("/schedules")

	// GET diizinkan untuk semua role yang sudah login (guest maupun warga)
	schedules.Get("/", scheduleHandler.GetAll)

	// POST, PUT, DELETE hanya diizinkan untuk role 'warga'
	schedules.Post("/", middleware.RequireRole("warga"), scheduleHandler.Create)
	schedules.Put("/:id", middleware.RequireRole("warga"), scheduleHandler.Update)
	schedules.Delete("/:id", middleware.RequireRole("warga"), scheduleHandler.Delete)

	// -------------------------------------------------------------------------
	// NOTIFICATION Routes (Terproteksi JWT, semua role)
	//
	// PENTING: /read-all HARUS didaftarkan SEBELUM /:id/read.
	// Jika dibalik, Fiber akan mencocokkan string "read-all" sebagai nilai
	// parameter :id, sehingga MarkAllNotificationsRead tidak pernah terpanggil.
	// -------------------------------------------------------------------------
	notifications := api.Group("/notifications", middleware.JWTProtected(cfg.JWTSecret))
	notifications.Get("/", sensorHandler.GetNotifications)
	// Route statis eksak harus didaftarkan lebih dulu dari route parametrik
	notifications.Put("/read-all", sensorHandler.MarkAllNotificationsRead)
	notifications.Put("/:id/read", sensorHandler.MarkNotificationRead)
}
