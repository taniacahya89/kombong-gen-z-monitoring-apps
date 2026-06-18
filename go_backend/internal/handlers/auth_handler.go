// internal/handlers/auth_handler.go
//
// Handler autentikasi untuk Go Fiber - Implementasi Penuh (Fase 2).
//
// Endpoint yang ditangani:
//   POST /api/v1/auth/register       - Registrasi pengguna baru (role default: guest)
//   POST /api/v1/auth/login          - Login dan mendapatkan JWT token
//   POST /api/v1/auth/logout         - Logout (invalidasi di sisi client)
//   PUT  /api/v1/auth/change-password - Ubah kata sandi (butuh token JWT)
//   GET  /api/v1/auth/me             - Ambil profil user yang sedang login

package handlers

import (
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"kombong-genz-backend/internal/database"
	"kombong-genz-backend/internal/middleware"
	"kombong-genz-backend/internal/models"
)

// AuthHandler menyimpan dependensi untuk handler autentikasi.
type AuthHandler struct {
	jwtSecret          string
	jwtExpirationHours int
}

// NewAuthHandler membuat instance AuthHandler baru dengan JWT secret dari konfigurasi.
func NewAuthHandler(jwtSecret string, expirationHours int) *AuthHandler {
	return &AuthHandler{
		jwtSecret:          jwtSecret,
		jwtExpirationHours: expirationHours,
	}
}

// Register menangani permintaan registrasi pengguna baru.
//
// POST /api/v1/auth/register
// Body: { "name": "...", "email": "...", "password": "..." }
//
// Alur:
//  1. Parse dan validasi request body.
//  2. Cek duplikasi email di database.
//  3. Hash password menggunakan bcrypt (cost = 12).
//  4. Simpan user baru dengan role default 'guest'.
//  5. Generate JWT token dengan klaim user.
//  6. Kembalikan AuthResponse.
func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req models.RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Format request tidak valid"),
		)
	}

	// Validasi field wajib
	if req.Name == "" || req.Email == "" || req.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Nama, email, dan password tidak boleh kosong"),
		)
	}
	if len(req.Password) < 8 {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Password minimal 8 karakter"),
		)
	}

	// Cek apakah email sudah terdaftar
	var existingID int
	err := database.DB.Get(&existingID, `SELECT id FROM users WHERE email = $1`, req.Email)
	if err == nil {
		// err == nil berarti record ditemukan (email duplikat)
		return c.Status(fiber.StatusConflict).JSON(
			models.NewErrorResponse("Email sudah terdaftar"),
		)
	}

	// Hash password dengan bcrypt, cost 12 memberikan keseimbangan keamanan vs performa
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal memproses password"),
		)
	}

	// Simpan user baru ke database dengan role default 'guest'
	var newUser models.User
	err = database.DB.QueryRowx(
		`INSERT INTO users (name, email, password, role, created_at, updated_at)
		 VALUES ($1, $2, $3, 'guest', NOW(), NOW())
		 RETURNING id, name, email, role, created_at, updated_at`,
		req.Name,
		req.Email,
		string(hashedPassword),
	).StructScan(&newUser)

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse(fmt.Sprintf("Gagal menyimpan pengguna: %v", err)),
		)
	}

	// Generate JWT token untuk user yang baru terdaftar
	token, err := h.generateToken(newUser)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal membuat token autentikasi"),
		)
	}

	return c.Status(fiber.StatusCreated).JSON(
		models.NewSuccessResponse("Registrasi berhasil", models.AuthResponse{
			Token: token,
			User: models.UserInfo{
				ID:    newUser.ID,
				Name:  newUser.Name,
				Email: newUser.Email,
				Role:  newUser.Role,
			},
		}),
	)
}

// Login menangani permintaan login pengguna.
//
// POST /api/v1/auth/login
// Body: { "user": { "email": "...", "password": "..." } }
//
// Alur:
//  1. Parse dan validasi request body.
//  2. Cari user berdasarkan email.
//  3. Verifikasi password dengan bcrypt.CompareHashAndPassword.
//  4. Generate JWT token dengan klaim (user_id, email, role).
//  5. Kembalikan AuthResponse.
func (h *AuthHandler) Login(c *fiber.Ctx) error {
	var req models.LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Format request tidak valid"),
		)
	}

	if req.User.Email == "" || req.User.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Email dan password tidak boleh kosong"),
		)
	}

	// Cari user berdasarkan email
	var user models.User
	err := database.DB.Get(
		&user,
		`SELECT id, name, email, password, role, created_at, updated_at
		 FROM users WHERE email = $1`,
		req.User.Email,
	)
	if err != nil {
		// Kembalikan pesan generik untuk mencegah user enumeration
		return c.Status(fiber.StatusUnauthorized).JSON(
			models.NewErrorResponse("Email atau password tidak valid"),
		)
	}

	// Verifikasi password
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.User.Password)); err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(
			models.NewErrorResponse("Email atau password tidak valid"),
		)
	}

	// Generate JWT token
	token, err := h.generateToken(user)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal membuat token autentikasi"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Login berhasil", models.AuthResponse{
			Token: token,
			User: models.UserInfo{
				ID:    user.ID,
				Name:  user.Name,
				Email: user.Email,
				Role:  user.Role,
			},
		}),
	)
}

// Logout menangani permintaan logout.
// Karena menggunakan JWT stateless, invalidasi sesungguhnya terjadi di sisi client
// dengan cara menghapus token dari local/secure storage.
//
// POST /api/v1/auth/logout
func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Logout berhasil. Silakan hapus token dari perangkat Anda.", nil),
	)
}

// GetMe mengembalikan informasi profil user yang sedang login.
// Endpoint ini dilindungi oleh JWTProtected middleware.
//
// GET /api/v1/auth/me
func (h *AuthHandler) GetMe(c *fiber.Ctx) error {
	userID, ok := c.Locals(middleware.LocalsKeyUserID).(int)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(
			models.NewErrorResponse("Tidak dapat membaca identitas pengguna dari token"),
		)
	}

	var user models.User
	err := database.DB.Get(
		&user,
		`SELECT id, name, email, role, created_at, updated_at FROM users WHERE id = $1`,
		userID,
	)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Pengguna tidak ditemukan"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Profil berhasil diambil", models.UserInfo{
			ID:    user.ID,
			Name:  user.Name,
			Email: user.Email,
			Role:  user.Role,
		}),
	)
}

// ChangePassword menangani permintaan perubahan kata sandi.
// Endpoint ini dilindungi oleh JWTProtected middleware.
//
// PUT /api/v1/auth/change-password
// Body: { "old_password": "...", "new_password": "..." }
//
// Alur:
//  1. Ambil user ID dari klaim JWT.
//  2. Ambil record user dari database untuk mendapatkan password hash lama.
//  3. Verifikasi old_password terhadap hash yang tersimpan.
//  4. Hash new_password baru dengan bcrypt.
//  5. Update kolom password dan updated_at di database.
func (h *AuthHandler) ChangePassword(c *fiber.Ctx) error {
	userID, ok := c.Locals(middleware.LocalsKeyUserID).(int)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(
			models.NewErrorResponse("Tidak dapat membaca identitas pengguna dari token"),
		)
	}

	var req models.ChangePasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Format request tidak valid"),
		)
	}

	if req.OldPassword == "" || req.NewPassword == "" {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Password lama dan password baru tidak boleh kosong"),
		)
	}
	if len(req.NewPassword) < 8 {
		return c.Status(fiber.StatusBadRequest).JSON(
			models.NewErrorResponse("Password baru minimal 8 karakter"),
		)
	}

	// Ambil password hash yang tersimpan di database
	var storedHash string
	if err := database.DB.Get(&storedHash, `SELECT password FROM users WHERE id = $1`, userID); err != nil {
		return c.Status(fiber.StatusNotFound).JSON(
			models.NewErrorResponse("Pengguna tidak ditemukan"),
		)
	}

	// Verifikasi password lama
	if err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(req.OldPassword)); err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(
			models.NewErrorResponse("Password lama tidak sesuai"),
		)
	}

	// Hash password baru
	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal memproses password baru"),
		)
	}

	// Update password di database
	if _, err := database.DB.Exec(
		`UPDATE users SET password = $1, updated_at = NOW() WHERE id = $2`,
		string(newHash),
		userID,
	); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(
			models.NewErrorResponse("Gagal menyimpan password baru"),
		)
	}

	return c.Status(fiber.StatusOK).JSON(
		models.NewSuccessResponse("Password berhasil diubah", nil),
	)
}

// ---------------------------------------------------------------------------
// HELPER PRIVAT
// ---------------------------------------------------------------------------

// generateToken membuat JWT token baru untuk pengguna yang diberikan.
// Klaim yang disertakan: user_id, email, role, exp (waktu kadaluarsa), iat (waktu pembuatan).
func (h *AuthHandler) generateToken(user models.User) (string, error) {
	expiration := time.Now().Add(time.Duration(h.jwtExpirationHours) * time.Hour)

	claims := middleware.JWTClaims{
		UserID: user.ID,
		Email:  user.Email,
		Role:   user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expiration),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   fmt.Sprintf("%d", user.ID),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(h.jwtSecret))
	if err != nil {
		return "", fmt.Errorf("gagal menandatangani token: %w", err)
	}

	return signed, nil
}
