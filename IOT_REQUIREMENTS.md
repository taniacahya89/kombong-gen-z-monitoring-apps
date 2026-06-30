# IOT_REQUIREMENTS.md

## Panduan Teknis Integrasi Perangkat Keras (Edisi Firebase REST)
### Sistem Monitoring IoT - Kombong GenZ (Pengabdian Masyarakat)

---

## 1. Gambaran Umum Arsitektur

Komunikasi antara perangkat mikrokontroler (ESP32) dan backend Firebase menggunakan protokol **HTTPS REST API**. Mikrokontroler bertindak sebagai HTTP client untuk mengirim data sensor dan mengambil jadwal pakan aktif.

```
[ESP32]  ----HTTPS PUT---->  [Firebase Realtime Database]  <----Stream----  [Flutter App]
                                 (/sensors/water_tank)
                                 (/sensors/power)

[ESP32]  <---HTTPS GET-----  [Firebase Realtime Database]  <----Write-----  [Flutter App]
                                 (/kontrol/jam_pakan)
```

Alur data:
1. ESP32 mengukur data sensor (level air tangki, tegangan, arus, daya panel surya).
2. ESP32 mengirim data sensor ke Firebase Realtime Database menggunakan HTTP PUT request setiap 5 detik.
3. ESP32 mengambil jam pakan aktif dari Realtime Database (`/kontrol/jam_pakan.json`) menggunakan HTTP GET setiap 15 detik.
4. Jika jam sekarang cocok dengan salah satu jam pakan aktif, ESP32 mengaktifkan servo pakan dan memposting notifikasi pakan ke `/notifications_trigger.json`.

---

## 2. Struktur Data Realtime Database

### 2.1 Sensor Tangki Air (`/sensors/water_tank`)
**Method:** `PUT`  
**Path:** `https://<your-project>.firebaseio.com/sensors/water_tank.json`  
**Payload:**
```json
{
  "current_height_cm": 42.5,
  "max_capacity_cm": 55.0,
  "status": "AMAN",
  "recorded_at": 1719662400000
}
```

### 2.2 Sensor Kelistrikan (`/sensors/power`)
**Method:** `PUT`  
**Path:** `https://<your-project>.firebaseio.com/sensors/power.json`  
**Payload:**
```json
{
  "voltage": 12.4,
  "current": 2.5,
  "power": 31.0,
  "recorded_at": 1719662400000
}
```

### 2.3 Jadwal Pakan (`/kontrol/jam_pakan`)
**Method:** `GET`  
**Path:** `https://<your-project>.firebaseio.com/kontrol/jam_pakan.json`  
**Response:**
```json
[7, 12, 16]
```

### 2.4 Trigger Notifikasi Pakan (`/notifications_trigger`)
**Method:** `POST`  
**Path:** `https://<your-project>.firebaseio.com/notifications_trigger.json`  
**Payload:**
```json
{
  "title": "Pemberian Pakan",
  "body": "Waktunya ayam makan! Jam: 07:00 WIB",
  "is_read": false,
  "created_at": 1719662400000
}
```

---

## 3. Library Arduino yang Diperlukan

Instal melalui Arduino IDE > Library Manager:
- `Adafruit INA219` - Library sensor arus/tegangan DC
- `ArduinoJson` by Benoit Blanchon (versi 6.x) - Serialisasi JSON
- `WiFi` - Built-in untuk ESP32
- `HTTPClient` - Built-in untuk ESP32

---

## 4. Keamanan & Konfigurasi Firebase Rules

Selama masa pengembangan (development), Anda dapat mengatur rules Realtime Database menjadi public:
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

Untuk mode produksi, Anda disarankan menggunakan **Database Secret** atau OAuth2 Auth Token dan melewatkannya di url parameter:
`https://<your-project>.firebaseio.com/sensors/power.json?auth=YOUR_DATABASE_SECRET`
