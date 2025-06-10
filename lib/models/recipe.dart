/// Model untuk merepresentasikan data resep dalam aplikasi.
///
/// Kelas ini menyimpan informasi lengkap tentang sebuah resep, termasuk:
/// - Informasi dasar (id, judul, deskripsi)
/// - Bahan-bahan dan langkah-langkah
/// - Gambar resep
/// - Informasi pembuat dan waktu pembuatan
/// - Jumlah likes
///
/// Kelas ini juga menyediakan metode untuk:
/// - Konversi dari data Supabase ke objek Recipe
/// - Konversi dari objek Recipe ke format yang dapat disimpan di Supabase
class Recipe {
  /// ID unik resep
  final String id;

  /// Judul resep
  final String title;

  /// Deskripsi resep
  final String description;

  /// Daftar bahan-bahan yang diperlukan
  final List<String> ingredients;

  /// Daftar langkah-langkah pembuatan
  final List<String> steps;

  /// URL gambar resep
  final String imageUrl;

  /// ID pengguna yang membuat resep
  final String createdBy;

  /// Waktu resep dibuat
  final DateTime createdAt;

  /// Jumlah likes yang diterima resep
  final int likes;

  /// Membuat instance Recipe baru.
  ///
  /// Parameter:
  /// - [id]: ID unik resep
  /// - [title]: Judul resep
  /// - [description]: Deskripsi resep
  /// - [ingredients]: Daftar bahan-bahan
  /// - [steps]: Daftar langkah-langkah
  /// - [imageUrl]: URL gambar resep
  /// - [createdBy]: ID pembuat resep
  /// - [createdAt]: Waktu pembuatan
  /// - [likes]: Jumlah likes
  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.likes,
  });

  /// Membuat instance Recipe dari data Supabase.
  ///
  /// Parameter:
  /// - [data]: Map yang berisi data resep dari Supabase
  ///
  /// Returns:
  /// - Recipe: Instance Recipe yang baru dibuat
  ///
  /// Proses:
  /// 1. Mengambil nilai dari map data
  /// 2. Mengkonversi format data sesuai kebutuhan
  /// 3. Membuat instance Recipe baru
  factory Recipe.fromSupabase(Map<String, dynamic> data) {
    return Recipe(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ingredients: _parseStringList(data['ingredients']),
      steps: _parseStringList(data['steps']),
      imageUrl: data['image_url'] ?? '',
      createdBy: data['user_id'] ?? '',
      createdAt:
          data['created_at'] != null
              ? DateTime.parse(data['created_at'])
              : DateTime.now(),
      likes: data['likes'] ?? 0,
    );
  }

  /// Mengkonversi berbagai format array dari Supabase menjadi List<String>.
  ///
  /// Parameter:
  /// - [value]: Nilai yang akan dikonversi
  ///
  /// Returns:
  /// - List<String>: Daftar string hasil konversi
  ///
  /// Format yang didukung:
  /// - List langsung
  /// - String JSON array (format ["item1","item2"])
  ///
  /// Catatan:
  /// - Mengembalikan list kosong jika value null
  /// - Menghapus tanda kutip dari string JSON
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      // Jika datang sebagai string JSON
      try {
        // Coba parsing sebagai JSON jika seperti ["item1","item2"]
        final strValue = value.trim();
        if (strValue.startsWith('[') && strValue.endsWith(']')) {
          final parsed =
              strValue
                  .substring(1, strValue.length - 1)
                  .split(',')
                  .map((e) => e.trim().replaceAll('"', ''))
                  .toList();
          return parsed;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Mengkonversi objek Recipe menjadi Map untuk disimpan di Supabase.
  ///
  /// Returns:
  /// - Map<String, dynamic>: Data resep dalam format yang sesuai untuk Supabase
  ///
  /// Catatan:
  /// - ID tidak disertakan karena biasanya di-generate oleh Supabase
  /// - DateTime dikonversi ke format ISO 8601
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'image_url': imageUrl,
      'user_id': createdBy,
      'created_at': createdAt.toIso8601String(),
      'likes': likes,
    };
  }
}
