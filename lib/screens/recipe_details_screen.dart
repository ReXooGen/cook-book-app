/// `RecipeDetailsScreen` adalah layar yang menampilkan detail lengkap dari sebuah resep.
/// Layar ini menampilkan gambar resep, judul, deskripsi, waktu memasak,
/// daftar bahan-bahan, dan langkah-langkah pembuatan. Pengguna juga dapat
/// mengedit atau menghapus resep jika mereka adalah pemilik resep tersebut.
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Widget untuk menampilkan detail resep dengan fitur manajemen.
///
/// Fitur-fitur yang tersedia:
/// - Tampilan gambar resep
/// - Informasi dasar (judul, deskripsi, waktu memasak)
/// - Daftar bahan-bahan
/// - Langkah-langkah pembuatan
/// - Opsi edit dan hapus untuk pemilik resep
class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({super.key});

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  /// ID resep yang akan ditampilkan
  String? recipeId;

  /// Data resep yang akan ditampilkan
  Map<String, dynamic>? recipe;

  /// Status loading saat memuat data resep
  bool isLoading = true;

  /// Pesan error jika terjadi kesalahan
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get route arguments here instead of in initState()
    if (recipeId == null) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is String) {
        recipeId = arguments;
        _loadRecipe();
      } else {
        setState(() {
          error = 'Invalid recipe ID';
          isLoading = false;
        });
      }
    }
  }

  /// Memuat data resep dari database berdasarkan ID.
  ///
  /// Proses yang dilakukan:
  /// 1. Memeriksa ketersediaan ID resep
  /// 2. Mengatur status loading
  /// 3. Memanggil service untuk mengambil data resep
  /// 4. Memperbarui state dengan data yang diterima
  /// 5. Menangani error jika terjadi kesalahan
  Future<void> _loadRecipe() async {
    if (recipeId == null) return;

    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      debugPrint('Loading recipe with ID: $recipeId');
      final recipeData = await SupabaseService.getRecipeById(recipeId!);

      setState(() {
        recipe = recipeData;
        isLoading = false;
      });

      debugPrint('Recipe loaded successfully: ${recipeData['title']}');
    } catch (e) {
      debugPrint('Error loading recipe: $e');
      setState(() {
        error = 'Failed to load recipe';
        isLoading = false;
      });
    }
  }

  /// Menghapus resep dari database.
  ///
  /// Proses yang dilakukan:
  /// 1. Menampilkan dialog konfirmasi
  /// 2. Jika dikonfirmasi, memanggil service untuk menghapus resep
  /// 3. Menampilkan notifikasi sukses/gagal
  /// 4. Kembali ke layar sebelumnya jika berhasil
  Future<void> _deleteRecipe() async {
    if (recipeId == null) return;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Delete Recipe'),
              content: const Text(
                'Are you sure you want to delete this recipe? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        await SupabaseService.deleteRecipe(recipeId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe deleted successfully'),
              backgroundColor: Color(0xFF824E50),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete recipe'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading indicator saat memuat data
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCF8F8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF824E50)),
        ),
      );
    }

    // Tampilkan pesan error jika terjadi kesalahan
    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCF8F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFCF8F8),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Recipe Details',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF824E50),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tampilkan pesan jika data resep kosong
    if (recipe == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCF8F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFCF8F8),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Recipe Not Found',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Recipe not found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    // Periksa apakah pengguna saat ini adalah pemilik resep
    final currentUser = SupabaseService.getCurrentUser();
    final isOwner = currentUser != null && recipe!['user_id'] == currentUser.id;

    // Tampilkan detail resep
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
          recipe!['title'] ?? 'Recipe Details',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Tampilkan menu edit dan hapus jika pengguna adalah pemilik resep
        actions:
            isOwner
                ? [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          Navigator.pushNamed(
                            context,
                            '/edit-recipe',
                            arguments: recipeId,
                          ).then((_) => _loadRecipe()); // Reload after edit
                          break;
                        case 'delete':
                          _deleteRecipe();
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFF824E50)),
                                SizedBox(width: 8),
                                Text('Edit Recipe'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete Recipe'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ]
                : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar resep
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

            // Judul resep
            Text(
              recipe!['title'] ?? 'Untitled Recipe',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF635959),
              ),
            ),
            const SizedBox(height: 8),

            // Informasi resep
            Row(
              children: [
                if (recipe!['cooking_time'] != null) ...[
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe!['cooking_time']} min',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                if (isOwner) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF824E50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'YOUR RECIPE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Deskripsi resep
            if (recipe!['description'] != null &&
                recipe!['description'].toString().isNotEmpty) ...[
              Text(
                recipe!['description'],
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF635959),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Bagian bahan-bahan
            if (recipe!['ingredients'] != null &&
                recipe!['ingredients'] is List &&
                (recipe!['ingredients'] as List).isNotEmpty) ...[
              const Text(
                'Ingredients',
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

            // Bagian langkah-langkah
            if (recipe!['steps'] != null &&
                recipe!['steps'] is List &&
                (recipe!['steps'] as List).isNotEmpty) ...[
              const Text(
                'Instructions',
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

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
