#include <Wire.h>
#include <Adafruit_INA219.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ==========================================
// 1. KONFIGURASI WIFI & FIREBASE RTDB
// ==========================================
const char* ssid = "V=IxR";       
const char* password = "50Hz_Sinkron";    

// Masukkan URL Firebase Realtime Database Anda di sini.
// Contoh: "https://nama-proyek-rtdb.firebaseio.com/"
const String firebase_url = "https://kombong-genz-default-rtdb.firebaseio.com/";

// Masukkan Database Secret / Auth Token jika database Anda diproteksi.
// Kosongkan jika database rules disetel public selama development.
const String firebase_auth = "";

// ==========================================
// 2. KONFIGURASI WAKTU (NTP) - WIB (GMT+7)
// ==========================================
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 7 * 3600;      
const int   daylightOffset_sec = 0;        

// ==========================================
// 3. KONFIGURASI SENSOR HC-SR04 & INA219
// ==========================================
Adafruit_INA219 ina219;
const int trigPin = 4;  // Pin D4
const int echoPin = 27; // Pin D27

unsigned long previousMillis = 0;
const long sensorInterval = 5000; // Kirim sensor setiap 5 detik

unsigned long lastScheduleCheck = 0;
const long scheduleInterval = 15000; // Cek jadwal pakan setiap 15 detik

bool sudahNotifMakan = false;

// ==========================================
// 4. VARIABEL GLOBAL UNTUK JADWAL PAKAN
// ==========================================
int activeFeedingHours[24]; // Menyimpan daftar jam pakan aktif
int activeFeedingHoursCount = 0; // Jumlah jadwal pakan aktif

// ==========================================
// FUNGSI REST CLIENT FIREBASE
// ==========================================
String firebaseGet(String path) {
  if (WiFi.status() != WL_CONNECTED) return "";
  
  HTTPClient http;
  String url = firebase_url + path + ".json";
  if (firebase_auth != "") {
    url += "?auth=" + firebase_auth;
  }
  
  http.begin(url);
  int httpResponseCode = http.GET();
  String response = "";
  
  if (httpResponseCode == 200) {
    response = http.getString();
  } else {
    Serial.print("[Firebase GET] Error code: ");
    Serial.println(httpResponseCode);
  }
  http.end();
  return response;
}

bool firebasePut(String path, String jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) return false;
  
  HTTPClient http;
  String url = firebase_url + path + ".json";
  if (firebase_auth != "") {
    url += "?auth=" + firebase_auth;
  }
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  int httpResponseCode = http.PUT(jsonPayload);
  
  bool success = (httpResponseCode == 200 || httpResponseCode == 201);
  if (!success) {
    Serial.print("[Firebase PUT] Error code: ");
    Serial.println(httpResponseCode);
  }
  http.end();
  return success;
}

bool firebasePost(String path, String jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) return false;
  
  HTTPClient http;
  String url = firebase_url + path + ".json";
  if (firebase_auth != "") {
    url += "?auth=" + firebase_auth;
  }
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  int httpResponseCode = http.POST(jsonPayload);
  
  bool success = (httpResponseCode == 200 || httpResponseCode == 201);
  if (!success) {
    Serial.print("[Firebase POST] Error code: ");
    Serial.println(httpResponseCode);
  }
  http.end();
  return success;
}

// ==========================================
// LOGIKA SINKRONISASI JADWAL
// ==========================================
void checkAndSyncSchedules() {
  Serial.println("[Firebase] Sinkronisasi jadwal pakan...");
  String response = firebaseGet("kontrol/jam_pakan");
  if (response == "" || response == "null") {
    Serial.println("[Firebase] Belum ada jadwal aktif.");
    activeFeedingHoursCount = 0;
    return;
  }

  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, response);
  if (error) {
    Serial.print("[Firebase] Gagal parsing JSON jadwal: ");
    Serial.println(error.c_str());
    return;
  }

  JsonArray jam_pakan = doc.as<JsonArray>();
  activeFeedingHoursCount = 0;
  
  for (size_t i = 0; i < jam_pakan.size() && i < 24; i++) {
    activeFeedingHours[activeFeedingHoursCount++] = jam_pakan[i].as<int>();
  }
  
  Serial.print("[Firebase] Jadwal pakan disinkronkan. Total: ");
  Serial.println(activeFeedingHoursCount);
  for (int i = 0; i < activeFeedingHoursCount; i++) {
    Serial.print("  - Jam: ");
    Serial.print(activeFeedingHours[i]);
    Serial.println(":00 WIB");
  }
}

// ==========================================
// FUNGSI KONEKSI WIFI
// ==========================================
void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
}

// ==========================================
// PROGRAM UTAMA
// ==========================================
void setup() {
  Serial.begin(115200);
  
  pinMode(trigPin, OUTPUT); 
  pinMode(echoPin, INPUT);
  if (!ina219.begin()) {
    Serial.println("Gagal menemukan INA219!");
    while (1) { delay(10); }
  }

  setup_wifi();

  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  Serial.println("Menunggu sinkronisasi waktu NTP...");
  
  // Ambil jadwal awal setelah terkoneksi
  checkAndSyncSchedules();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    setup_wifi();
  }

  // Polling Jadwal Aktif
  unsigned long currentMillis = millis();
  if (currentMillis - lastScheduleCheck >= scheduleInterval) {
    lastScheduleCheck = currentMillis;
    checkAndSyncSchedules();
  }

  // Cek Waktu Pakan
  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    int jam = timeinfo.tm_hour;
    int menit = timeinfo.tm_min;

    bool matchJadwal = false;
    for (int i = 0; i < activeFeedingHoursCount; i++) {
      if (jam == activeFeedingHours[i] && menit == 0) {
        matchJadwal = true;
        break;
      }
    }

    if (matchJadwal) {
      if (!sudahNotifMakan) {
        String title = "Pemberian Pakan";
        String body = "Waktunya ayam makan! Jam: " + String(jam) + ":00 WIB";
        
        // Buat trigger notifikasi di Realtime Database agar bisa disinkronkan oleh Flutter app
        StaticJsonDocument<256> notifDoc;
        notifDoc["title"] = title;
        notifDoc["body"] = body;
        notifDoc["is_read"] = false;
        notifDoc["created_at"] = int(time(NULL)) * 1000;
        
        String notifPayload;
        serializeJson(notifDoc, notifPayload);
        firebasePost("notifications_trigger", notifPayload);
        
        Serial.println(">>> NOTIFIKASI PAKAN DIKIRIM KE FIREBASE: " + body);
        sudahNotifMakan = true; 
      }
    } else {
      sudahNotifMakan = false; 
    }
  }

  // Pengiriman Data Sensor ke Firebase
  if (currentMillis - previousMillis >= sensorInterval) {
    previousMillis = currentMillis;

    // Baca Jarak (Terkalibrasi)
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);
    long duration = pulseIn(echoPin, HIGH, 30000); 
    
    float distanceCm = 0;
    if (duration > 0) {
      float rawDistance = duration * 0.034 / 2;
      distanceCm = (rawDistance * 1.0385) + 0.2070; 
    }

    // Hitung status ketinggian air tangki
    String status = "AMAN";
    float capacityPercent = (distanceCm / 55.0);
    if (capacityPercent < 0.3) status = "RENDAH";
    else if (capacityPercent < 0.6) status = "SEDANG";

    // Baca Daya
    float busVoltage_V = ina219.getBusVoltage_V();
    float current_mA = ina219.getCurrent_mA();
    float current_A = current_mA / 1000.0;
    if (current_A < 0) current_A = 0; // clamp noise
    float power_W = busVoltage_V * current_A;

    // Payload Water Tank
    StaticJsonDocument<256> waterDoc;
    waterDoc["current_height_cm"] = round(distanceCm * 10.0) / 10.0;
    waterDoc["max_capacity_cm"] = 55.0;
    waterDoc["status"] = status;
    waterDoc["recorded_at"] = int(time(NULL)) * 1000;

    // Payload Power
    StaticJsonDocument<256> powerDoc;
    powerDoc["voltage"] = round(busVoltage_V * 100.0) / 100.0;
    powerDoc["current"] = round(current_A * 100.0) / 100.0;
    powerDoc["power"] = round(power_W * 100.0) / 100.0;
    powerDoc["recorded_at"] = int(time(NULL)) * 1000;

    String waterPayload, powerPayload;
    serializeJson(waterDoc, waterPayload);
    serializeJson(powerDoc, powerPayload);

    firebasePut("sensors/water_tank", waterPayload);
    firebasePut("sensors/power", powerPayload);

    // Print ke Serial Monitor
    Serial.println("\n--- DATA TERKIRIM KE FIREBASE ---");
    Serial.print("Jarak    : "); Serial.print(distanceCm); Serial.print(" cm ("); Serial.print(status); Serial.println(")");
    Serial.print("Tegangan : "); Serial.print(busVoltage_V); Serial.println(" V");
    Serial.print("Arus     : "); Serial.print(current_A); Serial.println(" A");
    Serial.print("Daya     : "); Serial.print(power_W); Serial.println(" W");
  }
}

