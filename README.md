# Smart AC Control App

Aplikasi Flutter untuk monitoring dan kontrol AC pintar menggunakan ESP32, DHT22 sensor, radar HLK-LD2410C, dan IR transmitter.

## Arsitektur Sistem

```
┌─────────────────┐     MQTT      ┌──────────────────┐     MQTT      ┌─────────────────┐
│   Flutter App   │◄────────────►│  MQTT Broker     │◄────────────►│     ESP32       │
│   (Mobile)      │              │  broker.emqx.io  │              │   + Sensors     │
└─────────────────┘              └──────────────────┘              └─────────────────┘
```

## MQTT Topics

| Topic | Direction | Description |
|-------|-----------|-------------|
| `smartac/sensor/{device_id}` | ESP32 → App | Data sensor (suhu, kehadiran) |
| `smartac/control/{device_id}` | App → ESP32 | Perintah kontrol AC |
| `smartac/status/{device_id}` | Bidirectional | Status update |

## Format Data

### Sensor Data (ESP32 → App)
```json
{
  "suhu": 27.5,
  "kehadiran": 1
}
```
- `suhu`: Suhu dalam Celsius (float)
- `kehadiran`: 0 = kosong, 1 = ada orang

### Control Commands (App → ESP32)

**Power ON/OFF:**
```json
{
  "merk": "DAIKIN",
  "power": "ON"
}
```

**Mode TURBO/NORMAL:**
```json
{
  "merk": "DAIKIN",
  "mode": "TURBO"
}
```

**Settings Update:**
```json
{
  "merk": "DAIKIN",
  "batas_atas": 29,
  "batas_bawah": 28
}
```

## Device ID Mapping

| Device ID | Room Name |
|-----------|-----------|
| ESP32-DOSEN-01 | Ruang Dosen 1 |
| ESP32-KELAS-01 | Ruang Kelas C301 |
| ESP32-LAB-01 | Lab Komputer A |

## Konfigurasi ESP32

```cpp
const char* mqtt_server = "broker.emqx.io";
const char* device_id = "ESP32-DOSEN-01";  // Sesuaikan dengan ruangan
```

## Merk AC yang Didukung
- Daikin
- Panasonic
- LG
- Samsung
- Sharp
- Mitsubishi
- Gree
- Haier

## Fitur Aplikasi

### 1. Dashboard (Home)
- Monitoring semua ruangan
- Status MQTT connection
- Statistik (jumlah ruangan, AC aktif, ruangan terisi)
- Dark/Light mode toggle

### 2. Detail Ruangan
- Temperature gauge real-time
- Status AC (ON/OFF) dan kehadiran
- Mode kontrol: Otomatis (Hysteresis) / Manual
- Mode pendinginan: TURBO / NORMAL
- Pengaturan: Merk AC, Batas Atas, Batas Bawah

### 3. Tambah Perangkat
- Input nama ruangan
- Input Device ID (harus sama dengan ESP32)
- Pilih merk AC
- Set batas suhu hysteresis

### 4. Riwayat Aktivitas
- Log aktivitas AC
- Filter berdasarkan tanggal

## Algoritma Hysteresis

Mode otomatis menggunakan algoritma hysteresis:
- Jika suhu ≥ batas_atas → AC mode TURBO (kipas max, suhu 18°C)
- Jika suhu ≤ batas_bawah → AC mode NORMAL (kipas auto, suhu 24°C)

## Getting Started

### Prerequisites
- Flutter SDK 3.11+
- Android Studio / VS Code
- ESP32 dengan Arduino IDE

### Installation

1. Clone repository
2. Install dependencies:
```bash
flutter pub get
```

3. Run app:
```bash
flutter run
```

### Switch Mock/Real MQTT

Di `lib/controllers/mqtt_controller.dart`:
```dart
bool _useMockData = true;  // true = mock data, false = real MQTT
```

## Hardware Setup ESP32

| Component | GPIO Pin |
|-----------|----------|
| DHT22 (Data) | GPIO 4 |
| Radar HLK-LD2410C (OUT) | GPIO 5 |
| IR Transmitter KY-005 | GPIO 14 |

## Troubleshooting

### MQTT Connection Failed
1. Pastikan WiFi credentials benar di ESP32
2. Cek koneksi internet
3. Pastikan broker.emqx.io accessible

### Data Tidak Update
1. Pastikan device_id di ESP32 sama dengan mapping di app
2. Cek topic subscribe/publish
3. Pastikan format JSON sesuai

### IR Tidak Berfungsi
1. Pastikan merk AC benar
2. Posisikan IR transmitter menghadap AC
3. Jarak optimal: 3-5 meter
