// internal/mqtt/mqtt_client.go
//
// MQTT Client untuk Go Fiber Backend.
//
// Perubahan dari versi sebelumnya (Fase 3 - Self-Audit):
//
//  1. SetCleanSession(false): Broker mempertahankan state subscription setelah
//     reconnect, mencegah subscription duplikat.
//
//  2. Validasi payload sensor yang ketat: JSON rusak, null, atau tipe data
//     tidak sesuai ditangkap saat unmarshal. Nilai numerik di luar rentang
//     sanity diabaikan. Server tidak pernah panic.
//
//  3. Notifikasi otomatis ke tabel notifications: Saat sensor mendeteksi
//     kondisi kritis (tangki hampir kosong/penuh, tegangan abnormal),
//     createNotification() menyisipkan baris ke tabel notifications.
//     Notifikasi bersifat idempoten: throttle 1 jam per jenis event
//     agar tidak membanjiri tabel.
//
//  4. Fungsi IsConnected: Digunakan oleh SensorHandler untuk endpoint
//     device-status (deteksi perangkat offline).

package mqtt

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	paho "github.com/eclipse/paho.mqtt.golang"
	"kombong-genz-backend/internal/config"
	"kombong-genz-backend/internal/database"
	"kombong-genz-backend/internal/models"
)

// Batas validasi nilai sensor. Nilai di luar rentang ini dianggap glitch hardware.
const (
	maxVoltageSanity     = 500.0  // Volt
	maxCurrentSanity     = 100.0  // Ampere
	maxPowerSanity       = 50000.0 // Watt
	maxWaterHeightSanity = 500.0  // cm

	// Ambang batas peringatan kondisi sensor yang memicu notifikasi
	waterLowThresholdPct  = 20.0 // % - tangki hampir kosong
	waterHighThresholdPct = 90.0 // % - tangki hampir penuh
	voltageLowThreshold   = 10.0 // Volt - tegangan terlalu rendah
	voltageHighThreshold  = 60.0 // Volt - tegangan terlalu tinggi (untuk panel surya DC)

	// Throttle notifikasi: notifikasi yang sama tidak akan dikirim ulang
	// dalam rentang waktu ini, untuk mencegah flooding tabel notifications.
	notificationThrottleDuration = 1 * time.Hour
)

// notificationThrottle menyimpan timestamp terakhir notifikasi per jenis event.
// Key: string deskriptif event (misal "water_low", "voltage_high").
// Ini adalah in-memory throttle; akan reset setiap kali server restart.
var notificationThrottle = make(map[string]time.Time)

// Client adalah wrapper di atas paho.Client.
type Client struct {
	pahoClient paho.Client
	cfg        *config.Config
}

// NewClient membuat instance MQTT client baru tanpa langsung terkoneksi.
func NewClient(cfg *config.Config) *Client {
	return &Client{cfg: cfg}
}

// Connect melakukan koneksi ke MQTT Broker.
//
// Konfigurasi reconnect:
//   - SetAutoReconnect(true): Library Paho menangani reconnect secara otomatis.
//   - SetConnectRetryInterval(5s): Jeda antara percobaan reconnect.
//   - SetCleanSession(false): Broker mempertahankan state subscription setelah
//     koneksi terputus dan pulih kembali.
func (c *Client) Connect() error {
	brokerURL := fmt.Sprintf("tcp://%s:%s", c.cfg.MQTTBrokerHost, c.cfg.MQTTBrokerPort)

	opts := paho.NewClientOptions().
		AddBroker(brokerURL).
		SetClientID(c.cfg.MQTTClientID).
		SetUsername(c.cfg.MQTTUsername).
		SetPassword(c.cfg.MQTTPassword).
		SetCleanSession(false).
		SetAutoReconnect(true).
		SetConnectRetry(true).
		SetConnectRetryInterval(5 * time.Second).
		SetMaxReconnectInterval(2 * time.Minute).
		SetOnConnectHandler(c.onConnected).
		SetConnectionLostHandler(c.onConnectionLost).
		SetReconnectingHandler(func(_ paho.Client, opts *paho.ClientOptions) {
			log.Printf("[MQTT] Mencoba reconnect ke broker %s...", brokerURL)
		})

	c.pahoClient = paho.NewClient(opts)

	token := c.pahoClient.Connect()
	token.Wait()

	if err := token.Error(); err != nil {
		return fmt.Errorf("gagal koneksi ke MQTT Broker: %w", err)
	}

	return nil
}

// IsConnected mengembalikan true jika koneksi ke broker aktif.
func (c *Client) IsConnected() bool {
	return c.pahoClient != nil && c.pahoClient.IsConnected()
}

// onConnected dipanggil otomatis saat koneksi ke broker berhasil.
func (c *Client) onConnected(pahoClient paho.Client) {
	log.Printf("[MQTT] Terhubung ke broker: %s:%s", c.cfg.MQTTBrokerHost, c.cfg.MQTTBrokerPort)
	c.subscribeToSensors(pahoClient)
}

// onConnectionLost dipanggil otomatis saat koneksi terputus.
func (c *Client) onConnectionLost(_ paho.Client, err error) {
	log.Printf("[MQTT] Koneksi terputus: %v", err)
	log.Println("[MQTT] Reconnect otomatis akan dimulai dalam 5 detik...")
}

// subscribeToSensors mendaftarkan subscription ke topik sensor.
func (c *Client) subscribeToSensors(pahoClient paho.Client) {
	subscriptions := map[string]paho.MessageHandler{
		"iot/pengabdian/sensor/tangki":  c.handleWaterTankMessage,
		"iot/pengabdian/sensor/listrik": c.handleSolarMessage,
	}

	for topic, handler := range subscriptions {
		token := pahoClient.Subscribe(topic, 1, handler)
		token.Wait()
		if err := token.Error(); err != nil {
			log.Printf("[MQTT] Gagal subscribe ke topik %s: %v", topic, err)
		} else {
			log.Printf("[MQTT] Subscribe berhasil: %s", topic)
		}
	}
}

// handleWaterTankMessage memproses pesan dari sensor tangki air.
//
// Alur validasi:
//  1. json.Unmarshal: menangkap JSON rusak, tipe data tidak sesuai (string masuk ke float64), dll.
//     Go akan mengembalikan error — tidak ada panic.
//  2. Sanity check nilai numerik: negatif, nol, atau melampaui batas fisik yang masuk akal.
//  3. INSERT ke database.
//  4. Cek kondisi kritis (level rendah/penuh) → buat notifikasi jika diperlukan.
func (c *Client) handleWaterTankMessage(_ paho.Client, msg paho.Message) {
	rawPayload := string(msg.Payload())
	log.Printf("[MQTT] Pesan diterima dari %s: %s", msg.Topic(), rawPayload)

	var payload models.WaterTankPayload
	if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
		// json.Unmarshal menangani: bukan JSON, null, mismatched types (string -> float64), dll.
		// Tidak ada panic — error dikembalikan secara eksplisit.
		log.Printf("[MQTT] ERROR: Payload tangki tidak dapat diurai. Pesan dibuang. Payload mentah: '%s'. Error: %v",
			rawPayload, err)
		return
	}

	wt := payload.WaterTank

	// Sanity check: nilai numerik harus dalam rentang fisik yang masuk akal
	if wt.CurrentHeightCm < 0 {
		log.Printf("[MQTT] PERINGATAN: current_height_cm bernilai negatif (%.2f). Pesan dibuang.", wt.CurrentHeightCm)
		return
	}
	if wt.CurrentHeightCm > maxWaterHeightSanity {
		log.Printf("[MQTT] PERINGATAN: current_height_cm melampaui batas sanity (%.2f > %.0f cm). Pesan dibuang.",
			wt.CurrentHeightCm, maxWaterHeightSanity)
		return
	}
	if wt.MaxCapacityCm <= 0 {
		// MaxCapacityCm nol akan menyebabkan division by zero di frontend saat menghitung persentase
		log.Printf("[MQTT] PERINGATAN: max_capacity_cm nol atau negatif (%.2f). Pesan dibuang.", wt.MaxCapacityCm)
		return
	}
	if wt.Status == "" {
		log.Printf("[MQTT] PERINGATAN: field status kosong. Menggunakan nilai default 'TIDAK DIKETAHUI'.")
		wt.Status = "TIDAK DIKETAHUI"
	}

	// Simpan ke database
	if _, err := database.DB.Exec(
		`INSERT INTO water_tank_readings (current_height_cm, max_capacity_cm, status) VALUES ($1, $2, $3)`,
		wt.CurrentHeightCm,
		wt.MaxCapacityCm,
		wt.Status,
	); err != nil {
		log.Printf("[MQTT] Error menyimpan data tangki ke DB: %v", err)
		return // Jika simpan gagal, jangan lanjutkan ke cek notifikasi
	}

	// Evaluasi kondisi kritis dan kirim notifikasi jika perlu
	fillPct := (wt.CurrentHeightCm / wt.MaxCapacityCm) * 100.0

	if fillPct <= waterLowThresholdPct {
		createNotification(
			"water_low",
			"⚠️ Level Air Rendah",
			fmt.Sprintf("Level air tangki hanya %.1f%% (%.1f cm dari kapasitas %.1f cm). Segera isi ulang.",
				fillPct, wt.CurrentHeightCm, wt.MaxCapacityCm),
		)
	} else if fillPct >= waterHighThresholdPct {
		createNotification(
			"water_high",
			"💧 Tangki Air Hampir Penuh",
			fmt.Sprintf("Level air tangki mencapai %.1f%% (%.1f cm dari kapasitas %.1f cm).",
				fillPct, wt.CurrentHeightCm, wt.MaxCapacityCm),
		)
	}
}

// handleSolarMessage memproses pesan dari sensor panel surya / kelistrikan.
//
// Alur validasi sama dengan handleWaterTankMessage: unmarshal → sanity check → INSERT → notifikasi.
func (c *Client) handleSolarMessage(_ paho.Client, msg paho.Message) {
	rawPayload := string(msg.Payload())
	log.Printf("[MQTT] Pesan diterima dari %s: %s", msg.Topic(), rawPayload)

	var payload models.SolarPayload
	if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
		log.Printf("[MQTT] ERROR: Payload listrik tidak dapat diurai. Pesan dibuang. Payload mentah: '%s'. Error: %v",
			rawPayload, err)
		return
	}

	sm := payload.SolarMetrics

	// Sanity check nilai numerik
	if sm.Voltage < 0 {
		log.Printf("[MQTT] PERINGATAN: voltage negatif (%.3f). Pesan dibuang.", sm.Voltage)
		return
	}
	if sm.Current < 0 {
		log.Printf("[MQTT] PERINGATAN: current negatif (%.3f). Pesan dibuang.", sm.Current)
		return
	}
	if sm.Power < 0 {
		log.Printf("[MQTT] PERINGATAN: power negatif (%.3f). Pesan dibuang.", sm.Power)
		return
	}
	if sm.Voltage > maxVoltageSanity || sm.Current > maxCurrentSanity || sm.Power > maxPowerSanity {
		log.Printf("[MQTT] PERINGATAN: nilai melampaui batas sanity (V=%.1f, A=%.1f, W=%.1f). Pesan dibuang.",
			sm.Voltage, sm.Current, sm.Power)
		return
	}

	// Simpan ke database
	if _, err := database.DB.Exec(
		`INSERT INTO solar_readings (voltage, current, power) VALUES ($1, $2, $3)`,
		sm.Voltage,
		sm.Current,
		sm.Power,
	); err != nil {
		log.Printf("[MQTT] Error menyimpan data solar ke DB: %v", err)
		return
	}

	// Evaluasi kondisi kritis tegangan
	if sm.Voltage > 0 && sm.Voltage < voltageLowThreshold {
		createNotification(
			"voltage_low",
			"🔋 Tegangan Panel Surya Rendah",
			fmt.Sprintf("Tegangan panel surya sangat rendah: %.2f V. Periksa kondisi panel atau baterai.", sm.Voltage),
		)
	} else if sm.Voltage > voltageHighThreshold {
		createNotification(
			"voltage_high",
			"⚡ Tegangan Panel Surya Tinggi",
			fmt.Sprintf("Tegangan panel surya abnormal: %.2f V (batas normal %.1f V). Periksa regulator.", sm.Voltage, voltageHighThreshold),
		)
	}
}

// PublishFeedingSchedule mempublikasikan jadwal pakan ke perangkat IoT.
// Dipanggil oleh ScheduleHandler setiap kali ada perubahan jadwal.
func (c *Client) PublishFeedingSchedule(payload models.FeedingSchedulePayload) error {
	if !c.IsConnected() {
		return fmt.Errorf("MQTT client tidak terhubung; jadwal tidak dapat dipublish ke perangkat")
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("gagal marshal payload jadwal: %w", err)
	}

	token := c.pahoClient.Publish(
		"iot/pengabdian/kontrol/pakan",
		1,     // QoS 1: at least once
		false, // bukan retained message
		data,
	)
	token.Wait()

	if err := token.Error(); err != nil {
		return fmt.Errorf("gagal publish jadwal pakan: %w", err)
	}

	log.Printf("[MQTT] Jadwal pakan berhasil dipublish (%d bytes).", len(data))
	return nil
}

// Disconnect memutuskan koneksi dari broker secara bersih.
func (c *Client) Disconnect() {
	if c.pahoClient != nil && c.pahoClient.IsConnected() {
		c.pahoClient.Disconnect(500)
		log.Println("[MQTT] Koneksi MQTT ditutup.")
	}
}

// ---------------------------------------------------------------------------
// HELPER PRIVAT
// ---------------------------------------------------------------------------

// createNotification menyisipkan notifikasi ke tabel notifications dengan throttle.
//
// Parameter eventKey adalah string unik yang mengidentifikasi jenis event
// (misal "water_low", "voltage_high"). Notifikasi yang sama tidak akan dibuat
// ulang sebelum notificationThrottleDuration berlalu, mencegah flooding tabel.
//
// Fungsi ini berjalan di goroutine MQTT handler — error dicatat ke log,
// tidak pernah dipropagasi ke atas karena MQTT handler tidak mengembalikan error.
func createNotification(eventKey, title, body string) {
	now := time.Now()

	// Cek throttle: jika notifikasi jenis ini sudah dikirim dalam rentang waktu throttle, lewati
	if lastSent, exists := notificationThrottle[eventKey]; exists {
		if now.Sub(lastSent) < notificationThrottleDuration {
			log.Printf("[MQTT] Notifikasi '%s' di-throttle (terakhir dikirim: %s yang lalu).",
				eventKey, now.Sub(lastSent).Round(time.Second))
			return
		}
	}

	// Simpan notifikasi ke database
	if _, err := database.DB.Exec(
		`INSERT INTO notifications (title, body, is_read) VALUES ($1, $2, false)`,
		title,
		body,
	); err != nil {
		log.Printf("[MQTT] ERROR: Gagal membuat notifikasi '%s': %v", eventKey, err)
		return
	}

	// Update throttle timestamp hanya setelah berhasil disimpan
	notificationThrottle[eventKey] = now
	log.Printf("[MQTT] Notifikasi dibuat: [%s] %s", eventKey, title)
}
