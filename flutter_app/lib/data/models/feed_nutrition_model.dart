// lib/data/models/feed_nutrition_model.dart
//
// Model data panduan nutrisi pakan ayam.
//
// Data ini bersifat lokal (tidak memerlukan API call) karena merupakan
// panduan nutrisi tetap berbasis standar peternakan ayam layer, bukan
// data dinamis yang dikelola pengguna.
//
// Struktur hierarki:
//   FeedNutritionSchedule     => satu slot waktu (pagi / sore)
//     FeedNutritionAgeGroup   => kelompok umur dalam satu slot waktu
//       List<String> items    => baris komposisi pakan

// ---------------------------------------------------------------------------
// SUB-MODEL: SATU KELOMPOK UMUR
// ---------------------------------------------------------------------------

class FeedNutritionAgeGroup {
  /// Label kelompok umur, contoh: "15-20 Minggu (Ayam Persiapan Produksi)"
  final String ageLabel;

  /// Porsi pakan dalam satu kali pemberian, contoh: "50 gram per ekor"
  final String porsi;

  /// Daftar baris komposisi bahan, satu baris per bahan.
  final List<String> komposisi;

  /// Catatan fungsi / keterangan tambahan.
  final String keterangan;

  const FeedNutritionAgeGroup({
    required this.ageLabel,
    required this.porsi,
    required this.komposisi,
    required this.keterangan,
  });
}

// ---------------------------------------------------------------------------
// MODEL UTAMA: SATU SLOT WAKTU (PAGI / SORE)
// ---------------------------------------------------------------------------

class FeedNutritionSchedule {
  /// Label waktu, contoh: "Jadwal Pagi (07.00)"
  final String timeLabel;

  /// Daftar kelompok umur dalam slot waktu ini.
  final List<FeedNutritionAgeGroup> ageGroups;

  const FeedNutritionSchedule({
    required this.timeLabel,
    required this.ageGroups,
  });
}

// ---------------------------------------------------------------------------
// DATA STATIS: SELURUH KONTEN PANDUAN NUTRISI
// ---------------------------------------------------------------------------
//
// Sumber: Standar pemberian pakan ayam layer berdasarkan program pengabdian
// masyarakat Kombong Gen Z.

class FeedNutritionData {
  FeedNutritionData._();

  static const List<FeedNutritionSchedule> schedules = [
    // -----------------------------------------------------------------------
    // JADWAL PAGI (07.00)
    // -----------------------------------------------------------------------
    FeedNutritionSchedule(
      timeLabel: 'Jadwal Pagi (07.00)',
      ageGroups: [
        FeedNutritionAgeGroup(
          ageLabel: '15 – 20 Minggu',
          porsi: '50 gram / ekor',
          komposisi: [
            'Jagung giling       25 g',
            'Konsentrat Layer    17,5 g',
            'Dedak Padi Halus    7,5 g',
          ],
          keterangan:
              'Kandungan nutrisi pagi dan sore disamakan. Fokus pada persiapan pembentukan organ reproduksi ayam telur.',
        ),
        FeedNutritionAgeGroup(
          ageLabel: '20 – 50 Minggu',
          porsi: '50 gram / ekor',
          komposisi: [
            'Jagung giling       25 g',
            'Konsentrat Layer    17,5 g',
            'Dedak Padi Halus    7,5 g',
          ],
          keterangan:
              'Porsi lebih kecil, fokus energi untuk pembentukan putih telur.',
        ),
        FeedNutritionAgeGroup(
          ageLabel: '> 50 Minggu',
          porsi: '60 gram / ekor',
          komposisi: [
            'Jagung giling       30 g',
            'Konsentrat Layer    21 g',
            'Dedak Padi Halus    9 g',
          ],
          keterangan:
              'Porsi lebih kecil, fokus energi untuk pembentukan putih telur.',
        ),
      ],
    ),

    // -----------------------------------------------------------------------
    // JADWAL SORE (16.00)
    // -----------------------------------------------------------------------
    FeedNutritionSchedule(
      timeLabel: 'Jadwal Sore (16.00)',
      ageGroups: [
        FeedNutritionAgeGroup(
          ageLabel: '15 – 20 Minggu',
          porsi: '50 gram / ekor',
          komposisi: [
            'Jagung giling       25 g',
            'Konsentrat Layer    17,5 g',
            'Dedak Padi Halus    7,5 g',
          ],
          keterangan:
              'Kandungan nutrisi pagi dan sore disamakan. Fokus pada persiapan pembentukan organ reproduksi ayam telur.',
        ),
        FeedNutritionAgeGroup(
          ageLabel: '20 – 50 Minggu',
          porsi: '70 gram / ekor',
          komposisi: [
            'Jagung giling       35 g',
            'Konsentrat Layer    24,5 g',
            'Dedak Padi Halus    10,5 g',
            'Tepung Kalsium      3 g',
          ],
          keterangan:
              'Porsi lebih besar dan wajib ditambah tepung kalsium sebagai sumber kalsium lambat larut untuk pembentukan cangkang telur di malam hari.',
        ),
        FeedNutritionAgeGroup(
          ageLabel: '> 50 Minggu',
          porsi: '70 gram / ekor',
          komposisi: [
            'Jagung giling       35 g',
            'Konsentrat Layer    24,5 g',
            'Dedak Padi Halus    10,5 g',
            'Tepung Kalsium      4 g',
          ],
          keterangan:
              'Ayam usia tua rentan menghasilkan telur berkulit tipis. Ekstra tepung kalsium di sore hari ditingkatkan menjadi 4 gram per ekor.',
        ),
      ],
    ),
  ];
}
