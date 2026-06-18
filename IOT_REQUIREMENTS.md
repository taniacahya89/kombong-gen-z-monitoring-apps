# IOT_REQUIREMENTS.md

## Panduan Teknis Integrasi Perangkat Keras
### Sistem Monitoring IoT - Kombong GenZ (Pengabdian Masyarakat)

---

## 1. Gambaran Umum Arsitektur

Komunikasi antara perangkat mikrokontroler dan backend Go Fiber menggunakan protokol MQTT. Backend bertindak sebagai subscriber untuk data sensor dan sebagai publisher untuk kontrol jadwal pakan.

```
[ESP32/ESP8266]  ----Publish---->  [MQTT Broker]  ----Subscribe---->  [Go Backend]
                                                                           |
                                                                    [PostgreSQL]
                                                                           |
[ESP32/ESP8266]  <---Subscribe---  [MQTT Broker]  <-----Publish-----  [Go Backend]
```

Alur data:
1. Mikrokontroler mengukur data sensor (level air, tegangan, arus, daya).
2. Mikrokontroler mempublikasikan payload JSON ke topik MQTT yang sesuai.
3. Backend Go menerima pesan, memvalidasi format, dan menyimpannya ke PostgreSQL.
4. Saat warga mengubah jadwal pakan melalui aplikasi, backend mempublikasikan
   jadwal aktif terbaru ke topik kontrol.
5. Mikrokontroler berlangganan topik kontrol dan menyesuaikan aktuator pakan.

---

## 2. Konfigurasi MQTT Broker

### Opsi Broker

| Pilihan | Keterangan | Port Default |
|---|---|---|
| Mosquitto (lokal) | Disarankan untuk development dan deployment lokal | 1883 (non-TLS), 8883 (TLS) |
| HiveMQ Cloud | Tersedia tier gratis, mendukung TLS | 8883 |
| EMQX | Broker open-source berperforma tinggi | 1883 / 8883 |

### Konfigurasi Minimal Mosquitto (`/etc/mosquitto/mosquitto.conf`)

```
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

### Environment Variables Backend (`.env`)

```env
MQTT_BROKER_HOST=192.168.1.100
MQTT_BROKER_PORT=1883
MQTT_CLIENT_ID=kombong_genz_server
MQTT_USERNAME=server_user
MQTT_PASSWORD=server_password_aman
```

---

## 3. Library Arduino yang Diperlukan

Instal melalui Arduino IDE > Library Manager:

- `PubSubClient` by Nick O'Leary (versi 2.8 atau lebih baru) - MQTT client
- `ArduinoJson` by Benoit Blanchon (versi 6.x) - Serialisasi JSON
- `WiFi` - Built-in untuk ESP32 / `ESP8266WiFi` untuk ESP8266

---

## 4. Struktur Topik MQTT

Semua topik menggunakan format hierarki `domain/project/kategori/perangkat`.

| Topik | Arah | Pengirim | Penerima | QoS | Deskripsi |
|---|---|---|---|---|---|
| `iot/pengabdian/sensor/tangki` | Device ke Server | ESP32 | Go Backend | 1 | Data level air tangki |
| `iot/pengabdian/sensor/listrik` | Device ke Server | ESP32 | Go Backend | 1 | Data tegangan, arus, daya |
| `iot/pengabdian/kontrol/pakan` | Server ke Device | Go Backend | ESP32 | 1 | Jadwal pakan aktif |

### Pemilihan QoS

- **QoS 0** (At Most Once): Tidak disarankan untuk data sensor karena pesan dapat hilang.
- **QoS 1** (At Least Once): Digunakan pada semua topik sistem ini. Menjamin pesan
  tersampaikan minimal satu kali, dengan kemungkinan duplikasi yang dapat ditangani
  di sisi penerima melalui pemeriksaan timestamp.
- **QoS 2** (Exactly Once): Overhead terlalu tinggi untuk data sensor real-time.

---

## 5. Format Payload JSON

### 5.1 Sensor Tangki Air

**Topik:** `iot/pengabdian/sensor/tangki`

**Deskripsi field:**
- `current_height_cm`: Tinggi air saat ini dalam sentimeter (dari sensor ultrasonik)
- `max_capacity_cm`: Kapasitas maksimum tangki dalam sentimeter (nilai tetap/konstanta)
- `status`: Kategori level (`AMAN`, `SEDANG`, atau `RENDAH`)

**Contoh Payload:**
```json
{
  "water_tank": {
    "current_height_cm": 42.5,
    "max_capacity_cm": 55.0,
    "status": "AMAN"
  }
}
```

**Tabel nilai `status`:**

| Nilai | Kondisi | Persentase Level |
|---|---|---|
| `AMAN` | Level air normal, cukup untuk kebutuhan | >= 60% kapasitas |
| `SEDANG` | Level air menengah, perlu diperhatikan | 30% - 59% kapasitas |
| `RENDAH` | Level air kritis, segera isi ulang | < 30% kapasitas |

### 5.2 Sensor Kelistrikan (Panel Surya / PLN)

**Topik:** `iot/pengabdian/sensor/listrik`

**Deskripsi field:**
- `voltage`: Tegangan dalam Volt (V)
- `current`: Arus dalam Ampere (A)
- `power`: Daya dalam Watt (W), idealnya dihitung di mikrokontroler sebagai `voltage * current`

**Contoh Payload:**
```json
{
  "solar_metrics": {
    "voltage": 24.6,
    "current": 8.2,
    "power": 201.72
  }
}
```

### 5.3 Kontrol Jadwal Pakan (Server ke Device)

**Topik:** `iot/pengabdian/kontrol/pakan`

**Deskripsi field:**
- `id`: ID unik jadwal di database
- `label`: Nama jadwal yang dapat dibaca manusia
- `time`: Waktu eksekusi dalam format `HH:MM` (24 jam)
- `feed_type`: Tipe aktuator yang diaktifkan (`pakan` = servo pakan, `minum` = pompa air)
- `is_active`: Hanya jadwal dengan nilai `true` yang dikirimkan

**Contoh Payload:**
```json
{
  "feeding_schedules": [
    {
      "id": 1,
      "label": "Pakan Pagi",
      "time": "07:00",
      "feed_type": "pakan",
      "is_active": true
    },
    {
      "id": 2,
      "label": "Minum Pagi",
      "time": "07:30",
      "feed_type": "minum",
      "is_active": true
    },
    {
      "id": 3,
      "label": "Pakan Siang",
      "time": "12:00",
      "feed_type": "pakan",
      "is_active": true
    }
  ]
}
```

---

## 6. Contoh Kode ESP32 (Arduino)

### 6.1 Sensor Tangki Air (HC-SR04)

```cpp
// Kode ini menggunakan sensor ultrasonik HC-SR04 untuk mengukur level air.
// Jarak diukur dari sensor (di atas tangki) ke permukaan air.
// Level air = tinggi_tangki - jarak_terukur

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// --- Konfigurasi WiFi ---
const char* WIFI_SSID     = "nama_wifi_anda";
const char* WIFI_PASSWORD = "password_wifi_anda";

// --- Konfigurasi MQTT ---
const char* MQTT_BROKER   = "192.168.1.100";  // IP server broker
const int   MQTT_PORT     = 1883;
const char* MQTT_USER     = "device_user";
const char* MQTT_PASS     = "device_password";
const char* MQTT_TOPIC    = "iot/pengabdian/sensor/tangki";
const char* CLIENT_ID     = "esp32_tangki_001";

// --- Konfigurasi Sensor HC-SR04 ---
const int TRIG_PIN        = 5;
const int ECHO_PIN        = 18;
const float MAX_HEIGHT_CM = 55.0;  // Tinggi tangki dalam cm

// --- Interval pengiriman data (dalam milliseconds) ---
const long INTERVAL_MS    = 30000; // Kirim setiap 30 detik

WiFiClient   espClient;
PubSubClient mqttClient(espClient);
unsigned long lastSendTime = 0;

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  connectWiFi();

  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  connectMQTT();
}

void loop() {
  // Pertahankan koneksi MQTT
  if (!mqttClient.connected()) {
    connectMQTT();
  }
  mqttClient.loop();

  // Kirim data sesuai interval
  unsigned long now = millis();
  if (now - lastSendTime >= INTERVAL_MS) {
    lastSendTime = now;
    sendWaterTankData();
  }
}

void connectWiFi() {
  Serial.print("Menghubungkan ke WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi terhubung. IP: " + WiFi.localIP().toString());
}

void connectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Menghubungkan ke MQTT Broker...");
    if (mqttClient.connect(CLIENT_ID, MQTT_USER, MQTT_PASS)) {
      Serial.println("terhubung.");
    } else {
      Serial.print("gagal, kode error: ");
      Serial.println(mqttClient.state());
      delay(5000);
    }
  }
}

float measureHeightCm() {
  // Kirim pulsa trigger
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  // Hitung durasi echo dan konversi ke jarak
  long duration = pulseIn(ECHO_PIN, HIGH);
  float distanceCm = (duration * 0.034) / 2.0;

  // Level air = tinggi tangki - jarak sensor ke permukaan air
  float heightCm = MAX_HEIGHT_CM - distanceCm;
  return constrain(heightCm, 0.0, MAX_HEIGHT_CM);
}

String determineStatus(float heightCm) {
  float percentage = (heightCm / MAX_HEIGHT_CM) * 100.0;
  if (percentage >= 60) return "AMAN";
  if (percentage >= 30) return "SEDANG";
  return "RENDAH";
}

void sendWaterTankData() {
  float currentHeight = measureHeightCm();
  String status = determineStatus(currentHeight);

  // Serialisasi JSON menggunakan ArduinoJson
  StaticJsonDocument<200> doc;
  JsonObject waterTank = doc.createNestedObject("water_tank");
  waterTank["current_height_cm"] = round(currentHeight * 10.0) / 10.0;
  waterTank["max_capacity_cm"]   = MAX_HEIGHT_CM;
  waterTank["status"]            = status;

  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);

  if (mqttClient.publish(MQTT_TOPIC, jsonBuffer)) {
    Serial.print("Data tangki terkirim: ");
    Serial.println(jsonBuffer);
  } else {
    Serial.println("Gagal mengirim data tangki.");
  }
}
```

### 6.2 Sensor Kelistrikan (PZEM-004T / INA219)

```cpp
// Contoh menggunakan sensor PZEM-004T untuk mengukur tegangan dan arus AC.
// Untuk sistem DC (panel surya), gunakan INA219 dengan library Adafruit_INA219.

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// Konfigurasi WiFi dan MQTT sama seperti contoh di atas.
// Ganti MQTT_TOPIC dengan topik listrik:
const char* MQTT_TOPIC_LISTRIK = "iot/pengabdian/sensor/listrik";

// Contoh nilai yang dibaca dari sensor (ganti dengan pembacaan sensor nyata).
// Untuk PZEM-004T: gunakan library PZEM004Tv30 dan panggil pzem.voltage(), dll.
// Untuk INA219 DC: gunakan ina219.getBusVoltage_V(), ina219.getCurrent_mA(), dll.

void sendPowerData(float voltage, float current) {
  float power = voltage * current;  // Hitung daya

  StaticJsonDocument<200> doc;
  JsonObject metrics = doc.createNestedObject("solar_metrics");
  metrics["voltage"] = round(voltage * 100.0) / 100.0;
  metrics["current"] = round(current * 100.0) / 100.0;
  metrics["power"]   = round(power * 100.0) / 100.0;

  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);

  if (mqttClient.publish(MQTT_TOPIC_LISTRIK, jsonBuffer)) {
    Serial.print("Data listrik terkirim: ");
    Serial.println(jsonBuffer);
  }
}
```

### 6.3 Subscribe Kontrol Jadwal Pakan

```cpp
// Mikrokontroler berlangganan topik kontrol untuk menerima jadwal pakan.
// Saat jadwal diterima, simpan ke memori dan aktifkan aktuator pada waktu yang tepat.

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* MQTT_TOPIC_CONTROL = "iot/pengabdian/kontrol/pakan";
const int   SERVO_PAKAN_PIN    = 13;  // Pin servo untuk pakan
const int   POMPA_MINUM_PIN    = 14;  // Pin relay untuk pompa minum

// Struktur untuk menyimpan satu jadwal
struct FeedingSchedule {
  int  id;
  char label[50];
  int  hour;
  int  minute;
  char feedType[10]; // "pakan" atau "minum"
  bool isActive;
};

FeedingSchedule schedules[20]; // Simpan maks 20 jadwal
int scheduleCount = 0;

void onMQTTMessage(char* topic, byte* payload, unsigned int length) {
  // Salin payload ke buffer null-terminated
  char buffer[512];
  memcpy(buffer, payload, min(length, (unsigned int)511));
  buffer[min(length, (unsigned int)511)] = '\0';

  if (String(topic) == MQTT_TOPIC_CONTROL) {
    parseAndSaveSchedules(buffer);
  }
}

void parseAndSaveSchedules(const char* jsonStr) {
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, jsonStr);

  if (error) {
    Serial.print("Gagal parsing JSON jadwal: ");
    Serial.println(error.c_str());
    return;
  }

  JsonArray schedulesJson = doc["feeding_schedules"].as<JsonArray>();
  scheduleCount = 0;

  for (JsonObject s : schedulesJson) {
    if (scheduleCount >= 20) break;

    schedules[scheduleCount].id       = s["id"].as<int>();
    schedules[scheduleCount].isActive = s["is_active"].as<bool>();
    strlcpy(schedules[scheduleCount].label,    s["label"],    50);
    strlcpy(schedules[scheduleCount].feedType, s["feed_type"], 10);

    // Parse waktu "HH:MM"
    String timeStr = s["time"].as<String>();
    schedules[scheduleCount].hour   = timeStr.substring(0, 2).toInt();
    schedules[scheduleCount].minute = timeStr.substring(3, 5).toInt();

    scheduleCount++;
  }

  Serial.print("Jadwal diperbarui. Total: ");
  Serial.println(scheduleCount);
}

void checkAndActivateSchedules(int currentHour, int currentMinute) {
  for (int i = 0; i < scheduleCount; i++) {
    if (!schedules[i].isActive) continue;
    if (schedules[i].hour != currentHour) continue;
    if (schedules[i].minute != currentMinute) continue;

    // Cocok dengan waktu saat ini - aktifkan aktuator
    if (strcmp(schedules[i].feedType, "pakan") == 0) {
      activateFeeder();
    } else if (strcmp(schedules[i].feedType, "minum") == 0) {
      activateWaterPump();
    }
  }
}

void activateFeeder() {
  Serial.println("Mengaktifkan servo pakan...");
  // Implementasi: putar servo ke posisi buka selama 3 detik, kemudian tutup.
  // Contoh: servo.write(90); delay(3000); servo.write(0);
}

void activateWaterPump() {
  Serial.println("Mengaktifkan pompa minum...");
  // Implementasi: aktifkan relay pompa selama 5 detik.
  // Contoh: digitalWrite(POMPA_MINUM_PIN, HIGH); delay(5000); digitalWrite(POMPA_MINUM_PIN, LOW);
}
```

---

## 7. Rekomendasi Teknis

### Manajemen Koneksi

Selalu implementasikan mekanisme reconnect di loop utama:

```cpp
void loop() {
  if (!mqttClient.connected()) {
    reconnect(); // Panggil fungsi reconnect dengan exponential backoff
  }
  mqttClient.loop();
  // ... logika lainnya
}
```

### Frekuensi Pengiriman Data yang Disarankan

| Jenis Data | Interval Disarankan | Alasan |
|---|---|---|
| Level Air | 60 detik | Data berubah lambat; mengurangi beban database |
| Tegangan/Arus/Daya | 30 detik | Perubahan moderat; cukup untuk grafik historis |
| Status Jadwal | Event-driven | Hanya kirim saat ada perubahan dari server |

### Penanganan Error Jaringan

Implementasikan buffer lokal di mikrokontroler untuk menyimpan data saat koneksi WiFi
atau MQTT terputus. Saat koneksi pulih, kirimkan data yang tertunda dengan menambahkan
field `recorded_at` menggunakan NTP timestamp untuk akurasi waktu yang benar.

### Keamanan

- Gunakan username dan password yang berbeda antara backend server dan perangkat IoT.
- Untuk deployment production, aktifkan TLS pada broker MQTT (port 8883).
- Jangan hardcode kredensial dalam kode; simpan di EEPROM atau SPIFFS terenkripsi.

---

## 8. Pengujian Koneksi

### Menggunakan MQTT Explorer atau MQTTX

1. Hubungkan ke broker dengan kredensial yang sama dengan perangkat.
2. Subscribe ke topik `iot/pengabdian/#` untuk memantau semua pesan.
3. Publikasikan pesan uji ke topik sensor untuk memverifikasi backend menerima dan
   menyimpan data ke database.

### Contoh Pesan Uji (via MQTTX)

Topik: `iot/pengabdian/sensor/tangki`

```json
{
  "water_tank": {
    "current_height_cm": 35.0,
    "max_capacity_cm": 55.0,
    "status": "SEDANG"
  }
}
```

Setelah publish, verifikasi data tersimpan dengan memanggil endpoint:

```
GET http://localhost:3000/api/v1/sensors/water-tank
Authorization: Bearer <token>
```

---

*Dokumen ini berlaku untuk versi sistem Kombong GenZ v2.0.0 (Fase 2).*
*Diperbarui: Juni 2026.*
