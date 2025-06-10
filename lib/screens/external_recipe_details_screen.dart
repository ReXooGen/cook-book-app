/// `ExternalRecipeDetailsScreen` adalah layar untuk menampilkan detail resep dari sumber eksternal.
/// Layar ini menampilkan informasi lengkap tentang resep seperti judul, deskripsi,
/// bahan-bahan, langkah-langkah, dan gambar. Pengguna juga dapat menyimpan atau
/// menghapus resep dari daftar tersimpan.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Widget untuk menampilkan detail resep dari sumber eksternal.
///
/// Widget ini menampilkan:
/// - Gambar resep
/// - Judul resep
/// - Informasi waktu memasak dan kategori
/// - Deskripsi resep
/// - Daftar bahan-bahan
/// - Langkah-langkah memasak
///
/// Pengguna dapat:
/// - Menyimpan resep ke daftar tersimpan
/// - Menghapus resep dari daftar tersimpan
class ExternalRecipeDetailsScreen extends StatefulWidget {
  const ExternalRecipeDetailsScreen({super.key});

  @override
  State<ExternalRecipeDetailsScreen> createState() =>
      _ExternalRecipeDetailsScreenState();
}

class _ExternalRecipeDetailsScreenState
    extends State<ExternalRecipeDetailsScreen> {
  /// Data resep yang ditampilkan
  Map<String, dynamic>? recipe;

  /// Status apakah resep sudah tersimpan
  bool isSaved = false;

  /// Status apakah layar dibuka dari profil pengguna
  bool fromProfile = false;

  /// Mendapatkan deskripsi resep dari berbagai kemungkinan field
  ///
  /// Method ini akan mencari deskripsi resep dari field-field berikut:
  /// - description
  /// - summary
  /// - desc
  /// - instructions (jika berupa string)
  ///
  /// Returns null jika tidak ada deskripsi yang ditemukan
  String? getRecipeDescription(Map<String, dynamic> recipe) {
    return recipe['description'] ??
        recipe['summary'] ??
        recipe['desc'] ??
        (recipe['instructions'] is String ? recipe['instructions'] : null);
  }

  /// Menyimpan resep ke daftar tersimpan pengguna
  ///
  /// Method ini akan:
  /// 1. Memeriksa apakah pengguna sudah login
  /// 2. Menyimpan resep ke database
  /// 3. Memperbarui status isSaved
  /// 4. Menampilkan feedback ke pengguna
  Future<void> _saveRecipe() async {
    final user = SupabaseService.getCurrentUser();
    if (user == null || recipe == null) return;
    try {
      final success = await SupabaseService.saveExternalRecipe(
        userId: user.id,
        externalRecipeData: recipe!,
      );
      if (success) {
        setState(() {
          isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep berhasil disimpan!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep sudah ada di tersimpan!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan resep!')));
    }
  }

  /// Menghapus resep dari daftar tersimpan pengguna
  ///
  /// Method ini akan:
  /// 1. Memeriksa apakah pengguna sudah login
  /// 2. Menghapus resep dari database
  /// 3. Memperbarui status isSaved
  /// 4. Menampilkan feedback ke pengguna
  /// 5. Kembali ke layar sebelumnya
  Future<void> _removeSavedRecipe() async {
    final user = SupabaseService.getCurrentUser();
    if (user == null || recipe == null) return;
    try {
      await Supabase.instance.client
          .from('saved_external_recipes')
          .delete()
          .eq('user_id', user.id)
          .eq('external_recipe_id', recipe!['id']);
      if (mounted) {
        setState(() {
          isSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep dihapus dari tersimpan!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menghapus resep!')));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (recipe == null) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map<String, dynamic>) {
        setState(() {
          recipe = arguments;
          isSaved = arguments['isSaved'] == true;
          fromProfile = arguments['fromProfile'] == true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCF8F8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF824E50)),
        ),
      );
    }

    final description = getRecipeDescription(recipe!);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          recipe!['title'] ?? 'Detail Resep',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isSaved)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF824E50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'TERSIMPAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child:
                    recipe!['image_url'] != null &&
                            recipe!['image_url'].toString().isNotEmpty
                        ? Image.network(
                          recipe!['image_url'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF824E50),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.restaurant,
                                size: 80,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                        : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.restaurant,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 24),

            // Recipe Title
            Text(
              recipe!['title'] ?? 'Tanpa Judul',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF635959),
              ),
            ),

            const SizedBox(height: 8),

            // Recipe Info
            Row(
              children: [
                if (recipe!['cooking_time'] != null) ...[
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe!['cooking_time']} menit',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                ],
                if (recipe!['category'] != null) ...[
                  Icon(
                    Icons.restaurant_menu,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      recipe!['category'],
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Description
            if (description != null && description.toString().isNotEmpty) ...[
              Text(
                description!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF635959),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Ingredients Section
            if (recipe!['ingredients'] != null &&
                recipe!['ingredients'] is List &&
                (recipe!['ingredients'] as List).isNotEmpty) ...[
              const Text(
                'Bahan-bahan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF635959),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate((recipe!['ingredients'] as List).length, (
                index,
              ) {
                final ingredient = (recipe!['ingredients'] as List)[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8, right: 12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF824E50),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ingredient.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF635959),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Instructions Section
            if (recipe!['steps'] != null &&
                recipe!['steps'] is List &&
                (recipe!['steps'] as List).isNotEmpty) ...[
              const Text(
                'Langkah-langkah',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF635959),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate((recipe!['steps'] as List).length, (index) {
                final step = (recipe!['steps'] as List)[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF824E50),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF635959),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // If no ingredients or steps, show a message
            if ((recipe!['ingredients'] == null ||
                    (recipe!['ingredients'] as List).isEmpty) &&
                (recipe!['steps'] == null ||
                    (recipe!['steps'] as List).isEmpty)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    const Text(
                      'Detail resep tidak tersedia',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Resep eksternal ini tidak memiliki detail bahan atau langkah.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            if (fromProfile || isSaved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus dari Tersimpan'),
                  onPressed: _removeSavedRecipe,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF824E50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Simpan'),
                  onPressed: _saveRecipe,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
