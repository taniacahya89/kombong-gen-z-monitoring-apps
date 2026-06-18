// internal/handlers/sensor_handler.go
//
// Handler data sensor untuk Go Fiber - Implementasi Penuh (Fase 2).
//
// Endpoint yang ditangani:
//   GET /api/v1/sensors/water-tank          - Data terbaru tangki air
//   GET /api/v1/sensors/water-tank/history  - Riwayat 24 jam terakhir
//   GET /api/v1/sensors/power               - Data terbaru kelistrikan
//   GET /api/v1/sensors/power/history       - Riwayat kelistrikan untuk grafik
//   GET /api/v1/sensors/status              - Status online/offline perangkat IoT
//   GET /api/v1/notifications               - Daftar riwayat notifikasi
//   PUT /api/v1/notifications/:id/read      - Tandai notifikasi sebagai sudah dibaca

package handlers

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"

	"kombong-genz-backend/internal/database"
	"kombong-genz-backend/internal/models"
	mqttclient "kombong-genz-backend/internal/mqtt"
)

// SensorHandler menyimpan dependensi untuk handler sensor dan notifikasi.
// Menerima referensi MQTT client untuk endpoint device-status.
type SensorHandler struct {
	mqttClient *mqttclient.Client
}

// NewSensorHandler membuat instance SensorHandler baru.
func NewSensorHandler(mqttClient *mqttclient.Client) *SensorHandler {
	return &SensorHandler{mqttClient: mqttClient}
}

// GetLatestWaterTank mengembalikan data terbaru tangki air dari database.
//
// GET /api/v1/sensors/water-tank
func (h *SensorHandler) GetLatestWaterTank(c *fiber.Ctx) error {
	var reading models.WaterTankReading

	err := database.DB.Get(
		&reading,
		`SELECT id, current_height_cm, max_capacity_cm, status, recorded_at
		 FROM water_tank_readings
		 ORDER BY recorded_at DESC
		 LIMIT 1`,
	)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Belum ada data sensor tangki air"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Data tangki air berhasil diambil", reading),
	)
}

// GetWaterTankHistory mengembalikan riwayat pembacaan tangki air selama 24 jam terakhir.
// Digunakan untuk menampilkan grafik tren level air.
//
// GET /api/v1/sensors/water-tank/history?limit=50
func (h *SensorHandler) GetWaterTankHistory(c *fiber.Ctx) error {
	limit := c.QueryInt("limit", 50)
	if limit > 200 {
		limit = 200
	}

	var readings []models.WaterTankReading

	err := database.DB.Select(
		&readings,
		`SELECT id, current_height_cm, max_capacity_cm, status, recorded_at
		 FROM water_tank_readings
		 WHERE recorded_at >= NOW() - INTERVAL '24 hours'
		 ORDER BY recorded_at ASC
		 LIMIT $1`,
		limit,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal mengambil riwayat data tangki air"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Riwayat tangki air berhasil diambil", fiber.Map{
			"history": readings,
			"count":   len(readings),
		}),
	)
}

// GetLatestPower mengembalikan data terbaru kelistrikan (daya, tegangan, arus).
//
// GET /api/v1/sensors/power
func (h *SensorHandler) GetLatestPower(c *fiber.Ctx) error {
	var reading models.SolarReading

	err := database.DB.Get(
		&reading,
		`SELECT id, voltage, current, power, recorded_at
		 FROM solar_readings
		 ORDER BY recorded_at DESC
		 LIMIT 1`,
	)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Belum ada data sensor kelistrikan"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Data kelistrikan berhasil diambil", reading),
	)
}

// GetPowerHistory mengembalikan riwayat data kelistrikan untuk ditampilkan
// sebagai grafik garis pada halaman Daya di aplikasi mobile.
//
// Query mendukung parameter:
//   - limit: jumlah maksimum data point (default 100, maksimum 500)
//   - hours: rentang waktu dalam jam (default 12, maksimum 72)
//
// GET /api/v1/sensors/power/history?limit=100&hours=12
func (h *SensorHandler) GetPowerHistory(c *fiber.Ctx) error {
	limit := c.QueryInt("limit", 100)
	hours := c.QueryInt("hours", 12)

	if limit > 500 {
		limit = 500
	}
	if hours > 72 {
		hours = 72
	}

	var readings []models.SolarReading

	err := database.DB.Select(
		&readings,
		`SELECT id, voltage, current, power, recorded_at
		 FROM solar_readings
		 WHERE recorded_at >= NOW() - make_interval(hours := $1)
		 ORDER BY recorded_at ASC
		 LIMIT $2`,
		hours,
		limit,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal mengambil riwayat data kelistrikan"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Riwayat kelistrikan berhasil diambil", fiber.Map{
			"history": readings,
			"count":   len(readings),
		}),
	)
}

// GetNotifications mengembalikan daftar notifikasi sistem, diurutkan dari terbaru.
//
// GET /api/v1/notifications?limit=50
func (h *SensorHandler) GetNotifications(c *fiber.Ctx) error {
	limit := c.QueryInt("limit", 50)
	if limit > 200 {
		limit = 200
	}

	var notifications []models.Notification

	err := database.DB.Select(
		&notifications,
		`SELECT id, title, body, is_read, created_at
		 FROM notifications
		 ORDER BY created_at DESC
		 LIMIT $1`,
		limit,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal mengambil notifikasi"),
		)
	}

	// Hitung jumlah notifikasi yang belum dibaca.
	// Jika query gagal (misal koneksi DB putus sementara), kembalikan -1
	// sebagai sinyal ke client bahwa unread_count tidak tersedia, bukan 0 palsu.
	var unreadCount int
	unreadCount = -1
	if err := database.DB.Get(&unreadCount, `SELECT COUNT(*) FROM notifications WHERE is_read = false`); err != nil {
		unreadCount = -1
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Notifikasi berhasil diambil", fiber.Map{
			"notifications": notifications,
			"unread_count":  unreadCount,
			"total":         len(notifications),
		}),
	)
}

// MarkNotificationRead menandai satu notifikasi sebagai sudah dibaca.
//
// PUT /api/v1/notifications/:id/read
func (h *SensorHandler) MarkNotificationRead(c *fiber.Ctx) error {
	id, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("ID notifikasi tidak valid"),
		)
	}

	result, err := database.DB.Exec(
		`UPDATE notifications SET is_read = true WHERE id = $1`,
		id,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal memperbarui status notifikasi"),
		)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Notifikasi tidak ditemukan"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Notifikasi ditandai sebagai sudah dibaca", nil),
	)
}

// MarkAllNotificationsRead menandai semua notifikasi sebagai sudah dibaca.
//
// PUT /api/v1/notifications/read-all
func (h *SensorHandler) MarkAllNotificationsRead(c *fiber.Ctx) error {
	if _, err := database.DB.Exec(`UPDATE notifications SET is_read = true WHERE is_read = false`); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal memperbarui status notifikasi"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Semua notifikasi ditandai sudah dibaca", nil),
	)
}

// GetDeviceStatus mengembalikan status online/offline perangkat IoT.
//
// GET /api/v1/sensors/status
//
// Logika deteksi offline:
//   - Ambil timestamp data terakhir dari tabel water_tank_readings dan solar_readings.
//   - Hitung selisih antara NOW() dan timestamp tersebut.
//   - Jika selisih > 5 menit, status = "offline".
//   - Jika tidak ada data sama sekali di database, status = "no_data".
//   - Jika koneksi MQTT server sendiri terputus, status = "server_mqtt_disconnected".
//
// Response tambahan:
//   - last_water_data_at: timestamp data tangki terakhir (RFC3339)
//   - last_power_data_at: timestamp data listrik terakhir (RFC3339)
//   - minutes_since_last_data: selisih waktu dalam menit (ambil yang terbaru)
func (h *SensorHandler) GetDeviceStatus(c *fiber.Ctx) error {
	// Threshold offline: jika tidak ada data selama ini, perangkat dianggap offline
	const offlineThresholdMinutes = 5

	// Periksa koneksi MQTT server itu sendiri
	if h.mqttClient != nil && !h.mqttClient.IsConnected() {
		return c.Status(fiber.StatusOK).JSON(
			models.NewSuccessResponse("Status perangkat berhasil diambil", fiber.Map{
				"status":  "server_mqtt_disconnected",
				"message": "Server backend tidak terhubung ke MQTT Broker. Periksa konfigurasi broker.",
			}),
		)
	}

	// Ambil timestamp data sensor terakhir dari kedua tabel
	var lastWaterAt, lastPowerAt time.Time

	waterErr := database.DB.Get(
		&lastWaterAt,
		`SELECT recorded_at FROM water_tank_readings ORDER BY recorded_at DESC LIMIT 1`,
	)
	powerErr := database.DB.Get(
		&lastPowerAt,
		`SELECT recorded_at FROM solar_readings ORDER BY recorded_at DESC LIMIT 1`,
	)

	// Jika kedua tabel kosong: belum pernah menerima data
	if waterErr != nil && powerErr != nil {
		return c.Status(fiber.StatusOK).JSON(
			models.NewSuccessResponse("Status perangkat berhasil diambil", fiber.Map{
				"status":  "no_data",
				"message": "Belum ada data sensor yang diterima. Pastikan perangkat sudah dinyalakan.",
			}),
		)
	}

	// Tentukan timestamp terbaru dari kedua sensor
	var mostRecentAt time.Time
	if waterErr == nil && powerErr == nil {
		if lastWaterAt.After(lastPowerAt) {
			mostRecentAt = lastWaterAt
		} else {
			mostRecentAt = lastPowerAt
		}
	} else if waterErr == nil {
		mostRecentAt = lastWaterAt
	} else {
		mostRecentAt = lastPowerAt
	}

	minutesSinceLastData := time.Since(mostRecentAt).Minutes()

	deviceStatus := "online"
	statusMessage := "Perangkat aktif dan mengirimkan data."
	if minutesSinceLastData > offlineThresholdMinutes {
		deviceStatus = "offline"
		statusMessage = "Perangkat tidak mengirimkan data selama lebih dari 5 menit. Kemungkinan perangkat mati atau koneksi jaringan terputus."
	}

	response := fiber.Map{
		"status":                   deviceStatus,
		"message":                  statusMessage,
		"minutes_since_last_data":  int(minutesSinceLastData),
		"offline_threshold_minutes": offlineThresholdMinutes,
	}
	if waterErr == nil {
		response["last_water_data_at"] = lastWaterAt.Format(time.RFC3339)
	}
	if powerErr == nil {
		response["last_power_data_at"] = lastPowerAt.Format(time.RFC3339)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Status perangkat berhasil diambil", response),
	)
}
