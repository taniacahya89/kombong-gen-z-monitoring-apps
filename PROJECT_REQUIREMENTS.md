# PROJECT REQUIREMENTS — IoT Monitoring Pengabdian Masyarakat

## Ringkasan Proyek

Sistem monitoring IoT terintegrasi yang dirancang untuk program pengabdian masyarakat. Perangkat keras menggunakan panel surya sebagai sumber daya. Aplikasi memungkinkan warga dan pengelola untuk memantau kondisi tangki air, metrik kelistrikan panel surya, serta mengatur jadwal pakan ternak secara real-time melalui protokol MQTT.

---

## Arsitektur Sistem

```
[Perangkat IoT (ESP32/Arduino)]
        |
        | MQTT Protocol
        v
[MQTT Broker (Mosquitto / HiveMQ)]
        |
        v
[Go Fiber Backend]
   |           |
   v           v
[PostgreSQL] [REST API]
               |
               v
         [Flutter App]
```

---

## Stack Teknologi

| Layer      | Teknologi                    | Versi Target  |
|------------|------------------------------|---------------|
| Frontend   | Flutter (Mobile App)         | >= 3.x        |
| Backend    | Go + Fiber Framework         | Go >= 1.21    |
| Database   | PostgreSQL                   | >= 14         |
| IoT Proto  | MQTT (paho.mqtt.golang)      | v1.x          |
| State Mgmt | Provider / Riverpod          | TBD           |
| HTTP Client| Dio                          | >= 5.x        |

---

## Topik MQTT

| Sensor / Kontrol | Topik MQTT                             | Arah           |
|------------------|----------------------------------------|----------------|
| Tangki Air       | `iot/pengabdian/sensor/tangki`         | Device -> App  |
| Panel Surya      | `iot/pengabdian/sensor/listrik`        | Device -> App  |
| Jadwal Pakan     | `iot/pengabdian/kontrol/pakan`         | App -> Device  |

---

## Kontrak Data JSON Payload

### 1. Tangki Air (Subscribe: `iot/pengabdian/sensor/tangki`)
```json
{
  "water_tank": {
    "current_height_cm": 45,
    "max_capacity_cm": 55,
    "status": "Aman"
  }
}
```

### 2. Panel Surya / Listrik (Subscribe: `iot/pengabdian/sensor/listrik`)
```json
{
  "solar_metrics": {
    "voltage": 12.4,
    "current": 2.5,
    "power": 31.0
  }
}
```

### 3. Jadwal Pakan (Publish: `iot/pengabdian/kontrol/pakan`)
```json
{
  "feeding_schedules": [
    {"id": 1, "time": "08:00", "is_active": true},
    {"id": 2, "time": "17:00", "is_active": false}
  ]
}
```

### 4. Pengguna / Autentikasi (REST API)
```json
{
  "user": {
    "email": "warga@gmail.com",
    "password": "warga1234"
  }
}
```

---

## Fitur Aplikasi (Detail)

### 1. Splash Screen
- Menampilkan background gambar dari: **`assets/images/splash_bg.png`**
- Timer otomatis 3 detik, kemudian routing ke halaman Login
- File: `lib/presentation/screens/auth/splash_screen.dart`

### 2. Autentikasi — Login
- Form input Email dan Password
- Tombol "Masuk" sementara diarahkan ke Dashboard (tanpa validasi backend)
- Link navigasi ke halaman Sign Up
- File: `lib/presentation/screens/auth/login_screen.dart`

### 3. Autentikasi — Sign Up
- Form input: Nama Lengkap, Email, Password
- Tombol "Daftar"
- Link navigasi kembali ke Login
- File: `lib/presentation/screens/auth/signup_screen.dart`

### 4. Dashboard
- Header: avatar + nama "Kombong Gen Z" + greeting "Selamat Datang, User"
- Kartu Water Tank: visualisasi level air bertingkat (gradient merah-kuning-hijau), nilai cm, status
- Kartu Next Schedule: menampilkan jadwal pakan berikutnya (PAKAN AYAM & MINUM AYAM)
- Kartu Live Energy: menampilkan CURRENT (A), VOLTAGE (V), POWER (W) dengan mini sparkline chart
- Bottom Navigation Bar: Dashboard, Jadwal Pakan, Daya, Profil
- File: `lib/presentation/screens/dashboard/dashboard_screen.dart`

### 5. Jadwal Pakan (Placeholder)
- Akan berisi daftar jadwal pakan yang dapat diatur (CRUD)
- Integrasi publish MQTT ke topik `iot/pengabdian/kontrol/pakan`
- File: `lib/presentation/screens/schedule/schedule_screen.dart`

### 6. Daya / Power (Placeholder)
- Akan berisi grafik historis tegangan, arus, dan daya dari panel surya
- Data historis dari PostgreSQL via REST API
- File: `lib/presentation/screens/power/power_screen.dart`

### 7. Profil (Placeholder)
- Informasi akun pengguna
- Tombol Logout
- File: `lib/presentation/screens/profile/profile_screen.dart`

---

## Alur Kerja Pengembangan

### Fase 1 (SEKARANG): Frontend Flutter
- Master scaffolding struktur proyek
- Implementasi tema dan konstanta
- Kode UI lengkap: Splash, Login, Sign Up, Dashboard
- Placeholder halaman: Schedule, Power, Profile

### Fase 2 (MENUNGGU Hardware IoT Siap): Backend Go Fiber
- REST API untuk autentikasi (register, login, JWT)
- REST API untuk data historis sensor (read dari PostgreSQL)
- MQTT client untuk subscribe sensor dan publish kontrol pakan
- Sinkronisasi data real-time ke Flutter via polling atau WebSocket

---

## Catatan Penting

> **SPLASH SCREEN**: Menggunakan aset gambar dari path `assets/images/splash_bg.png`.
> File aset ini WAJIB ditempatkan di direktori tersebut sebelum build.
> Path sudah didaftarkan di `pubspec.yaml` pada bagian `flutter.assets`.

---

## Struktur Direktori Proyek

```
iot_pengabdian_masyarakat/
├── PROJECT_REQUIREMENTS.md
├── flutter_app/
│   ├── pubspec.yaml
│   ├── assets/
│   │   ├── images/
│   │   │   └── splash_bg.png          <- WAJIB ada sebelum build
│   │   └── fonts/
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── constants/
│       │   │   └── app_constants.dart
│       │   ├── theme/
│       │   │   └── app_theme.dart
│       │   ├── routes/
│       │   │   └── app_routes.dart
│       │   └── utils/
│       │       └── app_utils.dart
│       ├── data/
│       │   ├── models/
│       │   │   ├── water_tank_model.dart
│       │   │   ├── solar_metrics_model.dart
│       │   │   ├── feeding_schedule_model.dart
│       │   │   └── user_model.dart
│       │   └── services/
│       │       ├── api_service.dart
│       │       └── mqtt_service.dart
│       └── presentation/
│           ├── screens/
│           │   ├── auth/
│           │   │   ├── splash_screen.dart
│           │   │   ├── login_screen.dart
│           │   │   └── signup_screen.dart
│           │   ├── dashboard/
│           │   │   └── dashboard_screen.dart
│           │   ├── schedule/
│           │   │   └── schedule_screen.dart
│           │   ├── power/
│           │   │   └── power_screen.dart
│           │   └── profile/
│           │       └── profile_screen.dart
│           └── widgets/
│               ├── common/
│               │   └── custom_text_field.dart
│               └── dashboard/
│                   ├── water_tank_card.dart
│                   ├── schedule_card.dart
│                   └── energy_card.dart
└── go_backend/
    ├── go.mod
    ├── cmd/
    │   └── server/
    │       └── main.go
    └── internal/
        ├── config/
        │   └── config.go
        ├── database/
        │   └── postgres.go
        ├── mqtt/
        │   └── mqtt_client.go
        ├── handlers/
        │   ├── auth_handler.go
        │   └── sensor_handler.go
        ├── models/
        │   └── models.go
        └── routes/
            └── routes.go
```
