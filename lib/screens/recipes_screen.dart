/// `RecipesScreen` adalah layar yang menampilkan daftar resep yang telah dibuat atau disimpan oleh pengguna.
/// Layar ini menampilkan resep dalam bentuk daftar dengan gambar, judul, deskripsi, dan waktu memasak.
/// Pengguna dapat mencari resep, membuat resep baru, mengedit, dan menghapus resep yang ada.
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/recipe_image.dart';

/// Widget untuk menampilkan daftar resep pengguna.
///
/// Fitur-fitur yang tersedia:
/// - Daftar resep yang dibuat dan disimpan
/// - Pencarian resep
/// - Pembuatan resep baru
/// - Edit dan hapus resep
/// - Navigasi ke detail resep
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  /// Daftar resep yang dimuat dari database
  List<Map<String, dynamic>> recipes = [];

  /// Status loading untuk menampilkan indikator
  bool isLoading = true;

  /// Controller untuk field pencarian
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Memuat resep dari database Supabase.
  ///
  /// Proses yang dilakukan:
  /// 1. Mengatur status loading
  /// 2. Mengambil data pengguna saat ini
  /// 3. Mengambil resep yang dibuat oleh pengguna
  /// 4. Mengambil resep yang disimpan oleh pengguna
  /// 5. Menggabungkan kedua daftar resep
  /// 6. Memperbarui state dengan data yang diterima
  Future<void> _loadRecipes() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        // Ambil resep yang dibuat oleh pengguna
        final userRecipes = await SupabaseService.getUserRecipes(user.id);

        // Ambil resep yang disimpan oleh pengguna
        final savedRecipes = await SupabaseService.getUserSavedRecipes(user.id);

        setState(() {
          recipes = [...userRecipes, ...savedRecipes];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading recipes: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Navigasi ke layar pembuatan resep baru.
  ///
  /// Setelah kembali dari layar pembuatan resep,
  /// daftar resep akan diperbarui untuk menampilkan resep baru.
  void _navigateToCreateRecipe() {
    Navigator.pushNamed(context, '/create-recipe').then((_) {
      // Refresh data setelah kembali dari create recipe
      _loadRecipes();
    });
  }

  /// Widget untuk menampilkan state kosong ketika belum ada resep.
  ///
  /// Menampilkan:
  /// - Ikon resep
  /// - Pesan bahwa belum ada resep
  /// - Tombol untuk membuat resep baru
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No recipes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first recipe or save some from the community!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateRecipe,
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
              label: const Text('Create Recipe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF824E50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget untuk menampilkan item resep individual.
  ///
  /// Menampilkan:
  /// - Gambar resep
  /// - Judul resep
  /// - Waktu memasak
  /// - Deskripsi singkat
  /// - Menu opsi (edit/hapus)
  Widget _buildRecipeItem(Map<String, dynamic> recipe) {
    return GestureDetector(
      onTap: () {
        // Navigasi ke detail resep
        Navigator.pushNamed(
          context,
          '/recipe-details',
          arguments: recipe['id'].toString(),
        );
      },
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gambar resep
            RecipeImage(
              imageUrl: recipe['image_url']?.toString(),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
            ),

            const SizedBox(width: 16),

            // Informasi resep
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    recipe['title'] ?? 'Untitled Recipe',
                    style: const TextStyle(
                      color: Color(0xFF635959),
                      fontSize: 16.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (recipe['cooking_time'] != null) ...[
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['cooking_time']} min',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Text(
                          recipe['description'] ?? 'No description',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.0,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu opsi
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    // Navigasi ke edit resep
                    Navigator.pushNamed(
                      context,
                      '/edit-recipe',
                      arguments: recipe['id'].toString(),
                    ).then((result) {
                      // Refresh daftar jika ada perubahan
                      if (result == true) {
                        _loadRecipes();
                      }
                    });
                    break;
                  case 'delete':
                    _showDeleteConfirmation(recipe);
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  /// Menampilkan dialog konfirmasi untuk menghapus resep.
  ///
  /// Parameter:
  /// - [recipe]: Data resep yang akan dihapus
  void _showDeleteConfirmation(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Recipe'),
            content: Text(
              'Are you sure you want to delete "${recipe['title']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteRecipe(recipe['id']);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Menghapus resep dari database.
  ///
  /// Parameter:
  /// - [recipeId]: ID resep yang akan dihapus
  ///
  /// Proses yang dilakukan:
  /// 1. Memanggil service untuk menghapus resep
  /// 2. Memperbarui daftar resep
  /// 3. Menampilkan notifikasi sukses/gagal
  Future<void> _deleteRecipe(String recipeId) async {
    try {
      await SupabaseService.deleteRecipe(recipeId);
      _loadRecipes(); // Refresh list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete recipe')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF8F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Recipes',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Tombol untuk membuat resep baru
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black, size: 24),
            onPressed: _navigateToCreateRecipe,
          ),
          const SizedBox(width: 8),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 48,
              decoration: ShapeDecoration(
                color: const Color(0xFFF2E6E7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintText: 'Search recipes',
                  hintStyle: TextStyle(
                    color: Color(0xFFB98487),
                    fontSize: 16.90,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFFB98487),
                    size: 20,
                  ),
                ),
                onChanged: (value) {
                  // TODO: Implementasi pencarian real-time
                },
              ),
            ),
          ),

          // Content Area
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : recipes.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),

                            // Recipe List
                            ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: recipes.length,
                              itemBuilder: (context, index) {
                                return _buildRecipeItem(recipes[index]);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFBF9F9),
        selectedItemColor: const Color(0xFF824E50),
        unselectedItemColor: Colors.grey,
        currentIndex: 2, // Index untuk Saved
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/search');
              break;
            case 2:
              // Sudah di saved recipes, tidak perlu navigate
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
