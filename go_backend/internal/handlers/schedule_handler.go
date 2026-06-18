// internal/handlers/schedule_handler.go
//
// Handler CRUD untuk Jadwal Pakan.
//
// Endpoint yang ditangani:
//   GET    /api/v1/feeding/schedules     - Ambil semua jadwal (semua role)
//   POST   /api/v1/feeding/schedules     - Buat jadwal baru (role: warga, pakan only)
//   PUT    /api/v1/feeding/schedules/:id - Update jadwal (role: warga, pakan only)
//   DELETE /api/v1/feeding/schedules/:id - Hapus jadwal (role: warga, pakan only)
//
// Lapisan proteksi (berlapis dua):
//   1. Middleware RequireRole("warga") di routes.go: memblokir user dengan role
//      "guest" sebelum request masuk ke handler.
//   2. Validasi feed_type di dalam handler: memblokir modifikasi pada jadwal
//      bertipe "minum" meskipun dilakukan oleh user dengan role "warga".
//      Jadwal minum hanya boleh dibuat via seed database; tidak boleh diubah
//      melalui API. Response: 403 Forbidden.

package handlers

import (
	"strconv"

	"github.com/gofiber/fiber/v2"

	"kombong-genz-backend/internal/database"
	"kombong-genz-backend/internal/models"
	mqttclient "kombong-genz-backend/internal/mqtt"
)

// ScheduleHandler menyimpan dependensi untuk handler jadwal pakan.
// Referensi ke MQTT client diperlukan agar setiap perubahan jadwal
// langsung dipublikasikan ke perangkat IoT.
type ScheduleHandler struct {
	mqttClient *mqttclient.Client
}

// NewScheduleHandler membuat instance ScheduleHandler baru.
func NewScheduleHandler(client *mqttclient.Client) *ScheduleHandler {
	return &ScheduleHandler{mqttClient: client}
}

// GetAll mengembalikan seluruh jadwal pakan yang tersimpan di database.
//
// GET /api/v1/feeding/schedules
// Dikelompokkan berdasarkan feed_type untuk kemudahan konsumsi di frontend.
func (h *ScheduleHandler) GetAll(c *fiber.Ctx) error {
	var schedules []models.FeedingSchedule

	err := database.DB.Select(
		&schedules,
		`SELECT id, label, time, feed_type, is_active, created_at, updated_at
		 FROM feeding_schedules
		 ORDER BY feed_type ASC, time ASC`,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal mengambil jadwal pakan dari database"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Jadwal pakan berhasil diambil", fiber.Map{
			"feeding_schedules": schedules,
			"total":             len(schedules),
		}),
	)
}

// Create membuat jadwal pakan baru.
//
// POST /api/v1/feeding/schedules
// Body: { "label": "Pakan Pagi", "time": "07:00", "feed_type": "pakan", "is_active": true }
// Akses: role warga
func (h *ScheduleHandler) Create(c *fiber.Ctx) error {
	var req models.CreateFeedingScheduleRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Format request tidak valid"),
		)
	}

	// Validasi field wajib
	if req.Label == "" || req.Time == "" || req.FeedType == "" {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Field label, time, dan feed_type tidak boleh kosong"),
		)
	}
	if req.FeedType != "pakan" && req.FeedType != "minum" {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Nilai feed_type hanya boleh 'pakan' atau 'minum'"),
		)
	}

	// Aturan bisnis: jadwal minum tidak dapat dibuat melalui API.
	// Jadwal minum hanya disediakan melalui seed database dan bersifat tetap.
	if req.FeedType == "minum" {
		return c.Status(fiber.StatusForbidden).JSON(
			models.NewErrorResponse("Jadwal minum tidak dapat dibuat melalui API. Hanya jadwal pakan yang dapat dikelola."),
		)
	}

	// Simpan ke database
	var newSchedule models.FeedingSchedule
	err := database.DB.QueryRowx(
		`INSERT INTO feeding_schedules (label, time, feed_type, is_active, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, NOW(), NOW())
		 RETURNING id, label, time, feed_type, is_active, created_at, updated_at`,
		req.Label,
		req.Time,
		req.FeedType,
		req.IsActive,
	).StructScan(&newSchedule)

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal menyimpan jadwal pakan"),
		)
	}

	// Publikasikan semua jadwal aktif terbaru ke perangkat IoT via MQTT
	h.publishSchedulesToDevice()

	return c.Status(fiber.StatusCreated).JSON(
		models.NewSuccessResponse("Jadwal pakan berhasil dibuat", newSchedule),
	)
}

// Update memperbarui jadwal pakan berdasarkan ID.
//
// PUT /api/v1/feeding/schedules/:id
// Body: { "label": "...", "time": "...", "feed_type": "...", "is_active": true/false }
// Akses: role warga
func (h *ScheduleHandler) Update(c *fiber.Ctx) error {
	id, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("ID jadwal tidak valid"),
		)
	}

	var req models.UpdateFeedingScheduleRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Format request tidak valid"),
		)
	}

	// Validasi feed_type jika disertakan
	if req.FeedType != "" && req.FeedType != "pakan" && req.FeedType != "minum" {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Nilai feed_type hanya boleh 'pakan' atau 'minum'"),
		)
	}

	// Ambil data jadwal yang ada terlebih dahulu untuk nilai default
	var existing models.FeedingSchedule
	if err := database.DB.Get(
		&existing,
		`SELECT id, label, time, feed_type, is_active FROM feeding_schedules WHERE id = $1`,
		id,
	); err != nil {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Jadwal pakan tidak ditemukan"),
		)
	}

	// Aturan bisnis: jadwal minum tidak dapat diubah melalui API.
	if existing.FeedType == "minum" {
		return c.Status(fiber.StatusForbidden).JSON(
			models.NewErrorResponse("Jadwal minum tidak dapat diubah. Hanya jadwal pakan yang dapat dikelola."),
		)
	}

	// Terapkan perubahan parsial (merge dengan data yang sudah ada)
	if req.Label != "" {
		existing.Label = req.Label
	}
	if req.Time != "" {
		existing.Time = req.Time
	}
	if req.FeedType != "" {
		existing.FeedType = req.FeedType
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}

	// Update di database
	var updated models.FeedingSchedule
	err = database.DB.QueryRowx(
		`UPDATE feeding_schedules
		 SET label = $1, time = $2, feed_type = $3, is_active = $4, updated_at = NOW()
		 WHERE id = $5
		 RETURNING id, label, time, feed_type, is_active, created_at, updated_at`,
		existing.Label,
		existing.Time,
		existing.FeedType,
		existing.IsActive,
		id,
	).StructScan(&updated)

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal memperbarui jadwal pakan"),
		)
	}

	// Publikasikan jadwal terbaru ke perangkat IoT
	h.publishSchedulesToDevice()

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Jadwal pakan berhasil diperbarui", updated),
	)
}

// Delete menghapus jadwal pakan berdasarkan ID.
//
// DELETE /api/v1/feeding/schedules/:id
// Akses: role warga
//
// Validasi dua lapis:
//   1. Cek keberadaan record → 404 jika tidak ada.
//   2. Cek feed_type → 403 jika bertipe "minum".
func (h *ScheduleHandler) Delete(c *fiber.Ctx) error {
	id, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("ID jadwal tidak valid"),
		)
	}

	// Ambil record terlebih dahulu untuk memvalidasi feed_type sebelum menghapus.
	// Ini lebih aman daripada DELETE langsung, karena memberi kesempatan
	// untuk memeriksa aturan bisnis sebelum operasi destruktif dilakukan.
	var existing models.FeedingSchedule
	if err := database.DB.Get(
		&existing,
		`SELECT id, label, feed_type FROM feeding_schedules WHERE id = $1`,
		id,
	); err != nil {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Jadwal pakan tidak ditemukan"),
		)
	}

	// Aturan bisnis: jadwal minum tidak dapat dihapus melalui API.
	if existing.FeedType == "minum" {
		return c.Status(fiber.StatusForbidden).JSON(
			models.NewErrorResponse("Jadwal minum tidak dapat dihapus. Hanya jadwal pakan yang dapat dikelola."),
		)
	}

	if _, err := database.DB.Exec(`DELETE FROM feeding_schedules WHERE id = $1`, id); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal menghapus jadwal pakan"),
		)
	}

	// Publikasikan jadwal terbaru setelah penghapusan
	h.publishSchedulesToDevice()

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Jadwal pakan berhasil dihapus", nil),
	)
}

// ---------------------------------------------------------------------------
// HELPER PRIVAT
// ---------------------------------------------------------------------------

// publishSchedulesToDevice mengambil seluruh jadwal aktif dari database
// dan mempublikasikannya ke topik MQTT kontrol pakan.
// Dipanggil setelah setiap operasi create, update, atau delete.
// Error publikasi hanya dicatat sebagai log; tidak menggagalkan response HTTP.
func (h *ScheduleHandler) publishSchedulesToDevice() {
	var activeSchedules []models.FeedingSchedule

	err := database.DB.Select(
		&activeSchedules,
		`SELECT id, label, time, feed_type, is_active FROM feeding_schedules WHERE is_active = true ORDER BY time ASC`,
	)
	if err != nil {
		return
	}

	// Bangun payload MQTT
	payload := models.FeedingSchedulePayload{}
	for _, s := range activeSchedules {
		payload.FeedingSchedules = append(payload.FeedingSchedules, struct {
			ID       int    `json:"id"`
			Label    string `json:"label"`
			Time     string `json:"time"`
			FeedType string `json:"feed_type"`
			IsActive bool   `json:"is_active"`
		}{
			ID:       s.ID,
			Label:    s.Label,
			Time:     s.Time,
			FeedType: s.FeedType,
			IsActive: s.IsActive,
		})
	}

	// Publikasi bersifat best-effort; error tidak dipropagasi ke HTTP response
	_ = h.mqttClient.PublishFeedingSchedule(payload)
}
