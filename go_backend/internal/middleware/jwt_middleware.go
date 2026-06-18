// internal/middleware/jwt_middleware.go
//
// Middleware JWT dan RBAC untuk Go Fiber.
//
// Terdiri dari dua lapisan:
//
//  1. JWTProtected: Memvalidasi keberadaan dan keabsahan JWT token pada
//     header Authorization. Jika valid, klaim token disimpan ke c.Locals
//     agar dapat diakses oleh handler berikutnya.
//
//  2. RequireRole(roles ...string): Middleware kedua yang dijalankan setelah
//     JWTProtected. Memeriksa apakah role user (dari klaim JWT) termasuk
//     dalam daftar role yang diizinkan. Jika tidak, endpoint me-return 403.
//
// Contoh penggunaan di routes.go:
//
//	protected := api.Group("/", middleware.JWTProtected(jwtSecret))
//	protected.Post("/schedules", middleware.RequireRole("warga"), handler.Create)

package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

// JWTClaims mendefinisikan struktur klaim yang disimpan di dalam token JWT.
// Selain klaim standar (exp, iat), disertakan id, email, dan role pengguna.
type JWTClaims struct {
	UserID int    `json:"user_id"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

// LocalsKeyUserID adalah kunci untuk menyimpan user ID ke c.Locals.
const LocalsKeyUserID = "userID"

// LocalsKeyRole adalah kunci untuk menyimpan role user ke c.Locals.
const LocalsKeyRole = "userRole"

// LocalsKeyClaims adalah kunci untuk menyimpan seluruh klaim ke c.Locals.
const LocalsKeyClaims = "jwtClaims"

// JWTProtected mengembalikan middleware Fiber yang memvalidasi JWT token.
//
// Alur validasi:
//  1. Ambil header Authorization dari request.
//  2. Pastikan formatnya adalah "Bearer <token>".
//  3. Parse dan validasi tanda tangan token menggunakan jwtSecret.
//  4. Jika valid, simpan klaim ke c.Locals dan panggil c.Next().
//  5. Jika tidak valid (token kadaluarsa, tanda tangan salah, dll.), return 401.
func JWTProtected(jwtSecret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"error":   "Token autentikasi tidak ditemukan",
			})
		}

		// Format yang diharapkan: "Bearer <token>"
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"error":   "Format Authorization header tidak valid. Gunakan: Bearer <token>",
			})
		}

		tokenString := parts[1]

		// Parse token dan validasi klaim
		token, err := jwt.ParseWithClaims(
			tokenString,
			&JWTClaims{},
			func(t *jwt.Token) (interface{}, error) {
				// Pastikan algoritma yang digunakan adalah HMAC (HS256)
				if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fiber.NewError(
						fiber.StatusUnauthorized,
						"Algoritma signing token tidak valid",
					)
				}
				return []byte(jwtSecret), nil
			},
		)

		if err != nil || !token.Valid {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"error":   "Token tidak valid atau sudah kadaluarsa",
			})
		}

		claims, ok := token.Claims.(*JWTClaims)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"error":   "Tidak dapat membaca klaim token",
			})
		}

		// Simpan klaim ke context agar handler dapat mengaksesnya
		c.Locals(LocalsKeyUserID, claims.UserID)
		c.Locals(LocalsKeyRole, claims.Role)
		c.Locals(LocalsKeyClaims, claims)

		return c.Next()
	}
}

// RequireRole mengembalikan middleware Fiber yang memeriksa role pengguna.
// Middleware ini harus dipasang SETELAH JWTProtected karena bergantung
// pada data yang disimpan di c.Locals oleh JWTProtected.
//
// Jika role pengguna tidak termasuk dalam daftar `allowedRoles`,
// endpoint mengembalikan status 403 Forbidden.
//
// Contoh: RequireRole("warga") hanya mengizinkan user dengan role "warga".
func RequireRole(allowedRoles ...string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Ambil role dari Locals yang telah diset oleh JWTProtected
		userRole, ok := c.Locals(LocalsKeyRole).(string)
		if !ok || userRole == "" {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"error":   "Akses ditolak: informasi role tidak tersedia",
			})
		}

		// Periksa apakah role user ada dalam daftar yang diizinkan
		for _, role := range allowedRoles {
			if userRole == role {
				return c.Next()
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Akses ditolak: hak akses Anda tidak mencukupi untuk operasi ini",
		})
	}
}
