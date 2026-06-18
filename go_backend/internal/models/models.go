// internal/models/models.go
//
// Definisi struct model database untuk seluruh entitas aplikasi.
// Tag `db` digunakan oleh sqlx untuk mapping kolom database ke struct.
// Tag `json` digunakan oleh Fiber untuk serialisasi response API.

package models

import "time"

// ---------------------------------------------------------------------------
// USER
// ---------------------------------------------------------------------------

// UserRole mendefinisikan nilai-nilai yang sah untuk kolom role pada tabel users.
// Nilai ini digunakan oleh middleware RBAC untuk otorisasi endpoint.
type UserRole string

const (
	RoleGuest UserRole = "guest"
	RoleWarga UserRole = "warga"
)

// User merepresentasikan pengguna aplikasi.
// Kolom `role` menentukan tingkat akses: 'guest' (read-only) atau 'warga' (full CRUD).
type User struct {
	ID        int       `db:"id"         json:"id"`
	Name      string    `db:"name"       json:"name"`
	Email     string    `db:"email"      json:"email"`
	Password  string    `db:"password"   json:"-"` // Tidak pernah dikirim ke client
	Role      string    `db:"role"       json:"role"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

// LoginRequest adalah payload untuk endpoint login.
type LoginRequest struct {
	User struct {
		Email    string `json:"email"    validate:"required,email"`
		Password string `json:"password" validate:"required,min=8"`
	} `json:"user"`
}

// RegisterRequest adalah payload untuk endpoint registrasi.
type RegisterRequest struct {
	Name     string `json:"name"     validate:"required"`
	Email    string `json:"email"    validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

// ChangePasswordRequest adalah payload untuk endpoint ubah kata sandi.
type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=8"`
}

// AuthResponse adalah response setelah login/register berhasil.
type AuthResponse struct {
	Token string   `json:"token"`
	User  UserInfo `json:"user"`
}

// UserInfo adalah versi publik dari User (tanpa password).
// Field Role disertakan agar client dapat menerapkan logika RBAC di UI.
type UserInfo struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
	Role  string `json:"role"`
}

// ---------------------------------------------------------------------------
// WATER TANK
// ---------------------------------------------------------------------------

// WaterTankReading merepresentasikan satu pembacaan sensor tangki air.
type WaterTankReading struct {
	ID              int       `db:"id"                json:"id"`
	CurrentHeightCm float64   `db:"current_height_cm" json:"current_height_cm"`
	MaxCapacityCm   float64   `db:"max_capacity_cm"   json:"max_capacity_cm"`
	Status          string    `db:"status"            json:"status"`
	RecordedAt      time.Time `db:"recorded_at"       json:"recorded_at"`
}

// WaterTankPayload adalah struktur payload MQTT dari sensor tangki.
// Topik: iot/pengabdian/sensor/tangki
type WaterTankPayload struct {
	WaterTank struct {
		CurrentHeightCm float64 `json:"current_height_cm"`
		MaxCapacityCm   float64 `json:"max_capacity_cm"`
		Status          string  `json:"status"`
	} `json:"water_tank"`
}

// ---------------------------------------------------------------------------
// SOLAR / POWER METRICS
// ---------------------------------------------------------------------------

// SolarReading merepresentasikan satu pembacaan sensor panel surya.
type SolarReading struct {
	ID         int       `db:"id"          json:"id"`
	Voltage    float64   `db:"voltage"     json:"voltage"`
	Current    float64   `db:"current"     json:"current"`
	Power      float64   `db:"power"       json:"power"`
	RecordedAt time.Time `db:"recorded_at" json:"recorded_at"`
}

// SolarPayload adalah struktur payload MQTT dari sensor surya.
// Topik: iot/pengabdian/sensor/listrik
type SolarPayload struct {
	SolarMetrics struct {
		Voltage float64 `json:"voltage"`
		Current float64 `json:"current"`
		Power   float64 `json:"power"`
	} `json:"solar_metrics"`
}

// ---------------------------------------------------------------------------
// FEEDING SCHEDULE
// ---------------------------------------------------------------------------

// FeedType mendefinisikan kategori jadwal pakan.
type FeedType string

const (
	FeedTypePakan FeedType = "pakan"
	FeedTypeMinum FeedType = "minum"
)

// FeedingSchedule merepresentasikan satu jadwal pakan.
// Kolom `feed_type` membedakan antara jadwal pakan ayam dan minum ayam.
// Kolom `label` adalah nama jadwal yang dapat dikustomisasi.
type FeedingSchedule struct {
	ID        int       `db:"id"         json:"id"`
	Label     string    `db:"label"      json:"label"`
	Time      string    `db:"time"       json:"time"`
	FeedType  string    `db:"feed_type"  json:"feed_type"`
	IsActive  bool      `db:"is_active"  json:"is_active"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

// CreateFeedingScheduleRequest adalah payload untuk membuat jadwal baru.
type CreateFeedingScheduleRequest struct {
	Label    string `json:"label"     validate:"required"`
	Time     string `json:"time"      validate:"required"`
	FeedType string `json:"feed_type" validate:"required,oneof=pakan minum"`
	IsActive bool   `json:"is_active"`
}

// UpdateFeedingScheduleRequest adalah payload untuk memperbarui jadwal.
type UpdateFeedingScheduleRequest struct {
	Label    string `json:"label"`
	Time     string `json:"time"`
	FeedType string `json:"feed_type"`
	IsActive *bool  `json:"is_active"` // Pointer agar false dapat dibedakan dari zero-value
}

// FeedingSchedulePayload adalah struktur payload MQTT untuk kontrol pakan.
// Topik: iot/pengabdian/kontrol/pakan
type FeedingSchedulePayload struct {
	FeedingSchedules []struct {
		ID       int    `json:"id"`
		Label    string `json:"label"`
		Time     string `json:"time"`
		FeedType string `json:"feed_type"`
		IsActive bool   `json:"is_active"`
	} `json:"feeding_schedules"`
}

// ---------------------------------------------------------------------------
// NOTIFICATION
// ---------------------------------------------------------------------------

// Notification merepresentasikan satu entri notifikasi sistem.
// Dibuat secara otomatis oleh backend saat terjadi event tertentu
// (misalnya: level air rendah, tegangan abnormal).
type Notification struct {
	ID        int       `db:"id"         json:"id"`
	Title     string    `db:"title"      json:"title"`
	Body      string    `db:"body"       json:"body"`
	IsRead    bool      `db:"is_read"    json:"is_read"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

// ---------------------------------------------------------------------------
// API RESPONSE WRAPPER
// ---------------------------------------------------------------------------

// APIResponse adalah wrapper standar untuk semua response API.
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// NewSuccessResponse membuat response API yang berhasil.
func NewSuccessResponse(message string, data interface{}) APIResponse {
	return APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	}
}

// NewErrorResponse membuat response API yang gagal.
func NewErrorResponse(errorMsg string) APIResponse {
	return APIResponse{
		Success: false,
		Error:   errorMsg,
	}
}
