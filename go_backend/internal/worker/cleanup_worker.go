// internal/worker/cleanup_worker.go
//
// Background worker untuk pembersihan data historis sensor secara periodik.
//
// Masalah yang diselesaikan:
//   Dengan interval pengiriman sensor 30 detik, tabel solar_readings dan
//   water_tank_readings akan mengakumulasi ~2.880 dan ~1.440 baris per hari.
//   Dalam 1 tahun: lebih dari 1,5 juta baris tanpa pembersihan.
//
// Strategi:
//   - Data sensor (water_tank_readings, solar_readings) disimpan selama 30 hari.
//     Cukup untuk grafik historis jangka panjang.
//   - Data notifikasi (notifications) disimpan selama 90 hari.
//   - Worker berjalan pertama kali saat startup (untuk membersihkan data lama
//     yang terakumulasi saat server mati), kemudian setiap 24 jam setelahnya.
//
// Cara menjalankan:
//   Panggil worker.StartCleanupWorker(ctx) dari main.go sebagai goroutine.
//   Worker akan berhenti saat context di-cancel (saat server shutdown).
//
// Contoh di main.go:
//
//	ctx, cancel := context.WithCancel(context.Background())
//	defer cancel()
//	go worker.StartCleanupWorker(ctx)

package worker

import (
	"context"
	"log"
	"time"

	"kombong-genz-backend/internal/database"
)

// Konfigurasi retensi data
const (
	sensorRetentionDays       = 30 // hari
	notificationRetentionDays = 90 // hari
	cleanupInterval           = 24 * time.Hour
)

// StartCleanupWorker memulai goroutine yang membersihkan data lama secara periodik.
// Fungsi ini bersifat blocking; panggil sebagai goroutine: go worker.StartCleanupWorker(ctx).
func StartCleanupWorker(ctx context.Context) {
	log.Println("[CLEANUP] Background worker dimulai.")

	// Jalankan sekali langsung saat startup untuk membersihkan akumulasi data lama
	runCleanup()

	ticker := time.NewTicker(cleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			runCleanup()
		case <-ctx.Done():
			log.Println("[CLEANUP] Background worker dihentikan.")
			return
		}
	}
}

// tableCleanupConfig mendefinisikan konfigurasi pembersihan untuk setiap tabel:
// nama tabel, nama kolom timestamp yang digunakan, dan jumlah hari retensi.
type tableCleanupConfig struct {
	TableName       string
	TimestampColumn string
	RetentionDays   int
}

// runCleanup menjalankan satu siklus pembersihan data.
// Setiap tabel dibersihkan secara terpisah agar kegagalan satu tabel
// tidak mempengaruhi pembersihan tabel lainnya.
//
// Setiap tabel memiliki nama kolom timestamp eksplisit untuk menghindari
// fallback try-catch yang menyembunyikan error database sungguhan.
func runCleanup() {
	log.Printf("[CLEANUP] Memulai siklus pembersihan data (retensi sensor: %d hari, notifikasi: %d hari).",
		sensorRetentionDays, notificationRetentionDays)

	tables := []tableCleanupConfig{
		// Tabel sensor menggunakan kolom `recorded_at`
		{TableName: "water_tank_readings", TimestampColumn: "recorded_at", RetentionDays: sensorRetentionDays},
		{TableName: "solar_readings", TimestampColumn: "recorded_at", RetentionDays: sensorRetentionDays},
		// Tabel notifikasi menggunakan kolom `created_at`
		{TableName: "notifications", TimestampColumn: "created_at", RetentionDays: notificationRetentionDays},
	}

	for _, t := range tables {
		cleanTable(t)
	}

	log.Println("[CLEANUP] Siklus pembersihan selesai.")
}

// cleanTable menghapus semua baris di tabel yang usianya melebihi RetentionDays.
// Menggunakan kolom timestamp eksplisit dari konfigurasi — tidak ada fallback ganda
// yang bisa menyembunyikan error database sungguhan.
func cleanTable(cfg tableCleanupConfig) {
	// Gunakan make_interval untuk menghindari interpolasi string pada interval,
	// lebih aman dari SQL injection dan lebih eksplisit dari cast string.
	query := `DELETE FROM ` + cfg.TableName +
		` WHERE ` + cfg.TimestampColumn + ` < NOW() - make_interval(days := $1)`

	result, err := database.DB.Exec(query, cfg.RetentionDays)
	if err != nil {
		log.Printf("[CLEANUP] ERROR: Gagal membersihkan tabel %s (kolom: %s): %v",
			cfg.TableName, cfg.TimestampColumn, err)
		return
	}

	rowsDeleted, _ := result.RowsAffected()
	if rowsDeleted > 0 {
		log.Printf("[CLEANUP] Tabel %s: %d baris dihapus (lebih dari %d hari).",
			cfg.TableName, rowsDeleted, cfg.RetentionDays)
	} else {
		log.Printf("[CLEANUP] Tabel %s: tidak ada data lama untuk dihapus.", cfg.TableName)
	}
}
