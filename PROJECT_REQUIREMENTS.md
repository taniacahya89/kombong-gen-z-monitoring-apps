# PROJECT REQUIREMENTS — IoT Monitoring Pengabdian Masyarakat (Edisi Firebase)

## Ringkasan Proyek

Sistem monitoring IoT terintegrasi yang dirancang untuk program pengabdian masyarakat. Perangkat keras menggunakan panel surya sebagai sumber daya. Sistem ini digerakkan oleh **Firebase** untuk autentikasi pengguna, penyimpanan data sensor secara real-time, manajemen jadwal pakan, dan log notifikasi.

---

## Arsitektur Sistem

```
[Perangkat IoT (ESP32)]
        |
        | HTTPS REST API (PUT/GET/POST)
        v
[Firebase Realtime Database]  ←──────────────────────┐
        |                                             |
        | Stream Real-Time (onValue Listener)    [Cloud Firestore]
        v                                             |
  [Flutter App] ────── Firebase Auth ─────────────────┘
                    (Jadwal Pakan, Notifikasi, Akun)
```

---

## Stack Teknologi

| Layer      | Teknologi                    | Keterangan |
|------------|------------------------------|------------|
| Frontend   | Flutter (Mobile Android)     | SDK >= 3.x |
| Database   | Firebase Realtime Database   | Untuk data sensor real-time |
| Database   | Cloud Firestore              | Untuk jadwal pakan & notifikasi |
| Auth       | Firebase Authentication      | Login & Register |
| IoT Proto  | HTTPS REST API               | Komunikasi ESP32 -> Firebase |
| State Mgmt | flutter_riverpod             | v2.5.1 |

---

## Model Data Realtime Database

### 1. Tangki Air (`/sensors/water_tank`)
```json
{
  "current_height_cm": 45.0,
  "max_capacity_cm": 55.0,
  "status": "AMAN",
  "recorded_at": 1719662400000
}
```

### 2. Panel Surya / Listrik (`/sensors/power`)
```json
{
  "voltage": 12.4,
  "current": 2.5,
  "power": 31.0,
  "recorded_at": 1719662400000
}
```

### 3. Kontrol Jadwal Pakan (`/kontrol/jam_pakan`)
```json
[7, 16]
```

---

## Model Data Firestore

### 1. Koleksi `/users/{uid}`
- `name`: String
- `email`: String
- `created_at`: Timestamp

### 2. Koleksi `/feeding_schedules/{id}`
- `label`: String
- `time`: String ("07:00")
- `feed_type`: String ("pakan")
- `is_active`: Boolean

### 3. Koleksi `/notifications/{id}`
- `title`: String
- `body`: String
- `is_read`: Boolean
- `created_at`: Timestamp

---

## Fitur Aplikasi (Detail)

### 1. Splash Screen
- Menampilkan background gambar dari: **`assets/images/splash_bg.png`**
- Timer otomatis 3 detik, kemudian routing ke Dashboard jika sudah login, atau Login jika belum.
- File: `lib/presentation/screens/auth/splash_screen.dart`

### 2. Autentikasi — Login
- Form input Email dan Password menggunakan Firebase Auth
- Navigasi otomatis ke Dashboard setelah sukses
- File: `lib/presentation/screens/auth/login_screen.dart`

### 3. Autentikasi — Sign Up
- Form input: Nama Lengkap, Email, Password via Firebase Auth + simpan profil ke Firestore
- File: `lib/presentation/screens/auth/signup_screen.dart`

### 4. Dashboard
- Header: avatar + nama "Kombong Gen Z" + greeting "Selamat Datang, User"
- Kartu Water Tank: visualisasi level air bertingkat (gradient merah-kuning-hijau), nilai cm, status
- Kartu Next Schedule: menampilkan jadwal pakan berikutnya (PAKAN AYAM)
- Kartu Live Energy: menampilkan CURRENT (A), VOLTAGE (V), POWER (W) dengan mini sparkline chart
- Bottom Navigation Bar: Dashboard, Jadwal Pakan, Daya, Profil
- File: `lib/presentation/screens/dashboard/dashboard_screen.dart`

### 5. Jadwal Pakan
- Daftar jadwal pakan (CRUD) langsung ke Firestore
- Sinkronisasi otomatis jam aktif pakan ke Realtime Database (`/kontrol/jam_pakan`) untuk dibaca oleh ESP32
- File: `lib/presentation/screens/schedule/schedule_screen.dart`

### 6. Daya / Power
- Menampilkan grafik historis dinamis tegangan, arus, dan daya dari panel surya
- File: `lib/presentation/screens/power/power_screen.dart`

### 7. Profil
- Informasi akun pengguna & Ubah Password
- Tombol Logout
- File: `lib/presentation/screens/profile/profile_screen.dart`

---

## Struktur Direktori Proyek

```
iot_pengabdian_masyarakat/
├── PROJECT_REQUIREMENTS.md
├── IOT_REQUIREMENTS.md
├── esp32_iot.ino
└── flutter_app/
    ├── pubspec.yaml
    ├── assets/
    │   └── images/
    │       ├── splash_bg.png
    │       └── avatar_default.png
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── constants/
        │   │   └── app_constants.dart
        │   ├── theme/
        │   │   └── app_theme.dart
        │   ├── routes/
        │   │   └── app_routes.dart
        │   └── providers/
        │       ├── auth_provider.dart
        │       ├── dashboard_provider.dart
        │       ├── schedule_provider.dart
        │       ├── notification_provider.dart
        │       ├── power_provider.dart
        │       └── water_alert_provider.dart
        ├── data/
        │   ├── models/
        │   │   ├── water_tank_model.dart
        │   │   ├── solar_metrics_model.dart
        │   │   ├── feeding_schedule_model.dart
        │   │   └── user_model.dart
        │   └── services/
        │       ├── firebase_auth_service.dart
        │       ├── firebase_database_service.dart
        │       └── firestore_service.dart
        └── presentation/
```
