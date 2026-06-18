// internal/database/postgres.go
//
// Koneksi dan inisialisasi database PostgreSQL.
// Menggunakan sqlx di atas database/sql untuk kemudahan scanning struct.
//
// Skema database (dijalankan saat server start pertama kali dan idempoten):
//   - Tabel users            : autentikasi + role RBAC
//   - Tabel water_tank_readings : histori sensor tangki
//   - Tabel solar_readings   : histori sensor panel surya / daya listrik
//   - Tabel feeding_schedules: jadwal pakan + tipe (pakan/minum)
//   - Tabel notifications    : riwayat notifikasi sistem
//
// Strategi migrasi:
//   Seluruh DDL menggunakan CREATE TABLE IF NOT EXISTS dan ADD COLUMN IF NOT EXISTS
//   agar aman dijalankan berulang kali tanpa merusak data yang sudah ada.

package database

import (
	"fmt"
	"log"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq" // Driver PostgreSQL
	"golang.org/x/crypto/bcrypt"
	"kombong-genz-backend/internal/config"
)

// DB adalah instance database global yang dapat digunakan oleh semua handler.
var DB *sqlx.DB

// Connect membuka koneksi ke PostgreSQL dan melakukan ping untuk verifikasi.
func Connect(cfg *config.Config) error {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.DBHost,
		cfg.DBPort,
		cfg.DBUser,
		cfg.DBPassword,
		cfg.DBName,
		cfg.DBSSLMode,
	)

	db, err := sqlx.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("gagal membuka koneksi database: %w", err)
	}

	// Verifikasi koneksi aktif
	if err = db.Ping(); err != nil {
		return fmt.Errorf("gagal ping ke database: %w", err)
	}

	// Konfigurasi connection pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)

	DB = db
	log.Println("[DATABASE] Koneksi ke PostgreSQL berhasil.")

	return nil
}

// Migrate menjalankan inisialisasi dan evolusi skema database.
// Setiap query bersifat idempoten: aman dijalankan berulang kali.
func Migrate() error {
	// Daftar query DDL dieksekusi secara berurutan.
	// Urutan penting: tabel yang direferensikan harus dibuat terlebih dahulu.
	queries := []string{
		// Tabel pengguna dengan kolom role untuk RBAC.
		// Default role adalah 'guest'; admin mengubah ke 'warga' secara manual.
		`CREATE TABLE IF NOT EXISTS users (
			id         SERIAL PRIMARY KEY,
			name       VARCHAR(100) NOT NULL,
			email      VARCHAR(150) UNIQUE NOT NULL,
			password   VARCHAR(255) NOT NULL,
			role       VARCHAR(20)  NOT NULL DEFAULT 'guest',
			created_at TIMESTAMPTZ  DEFAULT NOW(),
			updated_at TIMESTAMPTZ  DEFAULT NOW()
		)`,

		// Tambahkan kolom role jika tabel sudah ada tapi belum punya kolom ini.
		// Diperlukan untuk database yang dibuat di Fase 1.
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'guest'`,

		// Tabel histori sensor tangki air.
		`CREATE TABLE IF NOT EXISTS water_tank_readings (
			id                 SERIAL PRIMARY KEY,
			current_height_cm  NUMERIC(6,2)  NOT NULL,
			max_capacity_cm    NUMERIC(6,2)  NOT NULL,
			status             VARCHAR(50)   NOT NULL,
			recorded_at        TIMESTAMPTZ   DEFAULT NOW()
		)`,

		// Tabel histori sensor panel surya / kelistrikan.
		`CREATE TABLE IF NOT EXISTS solar_readings (
			id          SERIAL PRIMARY KEY,
			voltage     NUMERIC(8,3)  NOT NULL,
			current     NUMERIC(8,3)  NOT NULL,
			power       NUMERIC(10,3) NOT NULL,
			recorded_at TIMESTAMPTZ   DEFAULT NOW()
		)`,

		// Tabel jadwal pakan dengan kolom tambahan label dan feed_type.
		// feed_type: 'pakan' atau 'minum' untuk membedakan kategori jadwal.
		`CREATE TABLE IF NOT EXISTS feeding_schedules (
			id         SERIAL PRIMARY KEY,
			label      VARCHAR(100) NOT NULL DEFAULT 'Jadwal Pakan',
			time       VARCHAR(5)   NOT NULL,
			feed_type  VARCHAR(10)  NOT NULL DEFAULT 'pakan',
			is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
			created_at TIMESTAMPTZ  DEFAULT NOW(),
			updated_at TIMESTAMPTZ  DEFAULT NOW()
		)`,

		// Tambahkan kolom baru ke tabel jadwal jika tabel lama sudah ada.
		`ALTER TABLE feeding_schedules ADD COLUMN IF NOT EXISTS label VARCHAR(100) NOT NULL DEFAULT 'Jadwal Pakan'`,
		`ALTER TABLE feeding_schedules ADD COLUMN IF NOT EXISTS feed_type VARCHAR(10) NOT NULL DEFAULT 'pakan'`,

		// Tabel riwayat notifikasi sistem.
		// Notifikasi dibuat oleh backend saat event sensor tertentu terjadi.
		`CREATE TABLE IF NOT EXISTS notifications (
			id         SERIAL PRIMARY KEY,
			title      VARCHAR(200) NOT NULL,
			body       TEXT         NOT NULL,
			is_read    BOOLEAN      NOT NULL DEFAULT FALSE,
			created_at TIMESTAMPTZ  DEFAULT NOW()
		)`,

		// Seed data awal untuk jadwal pakan agar halaman Jadwal tidak kosong
		// saat database baru pertama kali dibuat.
		// ON CONFLICT DO NOTHING memastikan query ini tidak duplikat data.
		`INSERT INTO feeding_schedules (id, label, time, feed_type, is_active)
		 VALUES
		   (1, 'Pakan Pagi',  '07:00', 'pakan', true),
		   (2, 'Minum Pagi',  '07:30', 'minum', true),
		   (3, 'Pakan Siang', '12:00', 'pakan', true),
		   (4, 'Minum Siang', '12:30', 'minum', true),
		   (5, 'Pakan Sore',  '17:00', 'pakan', false),
		   (6, 'Minum Sore',  '17:30', 'minum', false)
		 ON CONFLICT (id) DO NOTHING`,
	}

	for _, query := range queries {
		if _, err := DB.Exec(query); err != nil {
			return fmt.Errorf("gagal menjalankan migrasi: %w\nQuery: %s", err, query)
		}
	}

	log.Println("[DATABASE] Migrasi skema selesai.")
	return nil
}

// SeedDefaultUsers menyisipkan akun-akun default ke database jika belum ada.
// Fungsi ini bersifat idempoten: aman dipanggil berulang kali tanpa
// menyebabkan duplikasi data.
//
// Akun yang diseed:
//   - warga@gmail.com / warga1234 / role: warga
//     Digunakan sebagai akun demonstrasi dengan akses penuh CRUD jadwal.
func SeedDefaultUsers() error {
	type seedUser struct {
		Name     string
		Email    string
		Password string
		Role     string
	}

	users := []seedUser{
		{
			Name:     "Warga Demo",
			Email:    "warga@gmail.com",
			Password: "warga1234",
			Role:     "warga",
		},
	}

	for _, u := range users {
		// Cek apakah email sudah terdaftar; lewati jika sudah ada
		var existingID int
		err := DB.Get(&existingID, `SELECT id FROM users WHERE email = $1`, u.Email)
		if err == nil {
			// Record ditemukan: email sudah ada, lewati
			log.Printf("[DATABASE] Seed user '%s' sudah ada, dilewati.", u.Email)
			continue
		}

		// Hash password menggunakan bcrypt dengan cost 12
		hashed, err := bcrypt.GenerateFromPassword([]byte(u.Password), 12)
		if err != nil {
			return fmt.Errorf("gagal hash password untuk seed user '%s': %w", u.Email, err)
		}

		// Sisipkan user baru ke database
		_, err = DB.Exec(
			`INSERT INTO users (name, email, password, role, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, NOW(), NOW())`,
			u.Name,
			u.Email,
			string(hashed),
			u.Role,
		)
		if err != nil {
			return fmt.Errorf("gagal menyisipkan seed user '%s': %w", u.Email, err)
		}

		log.Printf("[DATABASE] Seed user '%s' (role: %s) berhasil dibuat.", u.Email, u.Role)
	}

	return nil
}

// Close menutup koneksi database. Dipanggil saat server shutdown.
func Close() {
	if DB != nil {
		if err := DB.Close(); err != nil {
			log.Printf("[DATABASE] Error saat menutup koneksi: %v", err)
		}
	}
}
