/// `HomeScreen` adalah kelas utama yang menampilkan layar utama aplikasi Cook Book.
/// Layar ini menampilkan resep unggulan, opsi akses cepat, kategori, informasi pengguna,
/// dan fitur pencarian & penemuan resep.
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/recipe_api_service.dart';

/// Widget untuk menampilkan layar utama aplikasi Cook Book.
///
/// Widget ini terdiri dari beberapa bagian utama:
/// 1. Resep Unggulan - Menampilkan resep pilihan dengan gambar
/// 2. Akses Cepat - Menu navigasi cepat ke fitur populer
/// 3. Kategori - Filter resep berdasarkan waktu, kesulitan, dan jenis masakan
/// 4. Dasbor Pribadi - Informasi profil dan statistik pengguna
/// 5. Pencarian & Penemuan - Fitur pencarian dan penemuan resep
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Nama pengguna yang diambil dari profil
  String? userName;

  /// Peran pengguna dalam aplikasi (saat ini hardcoded)
  String userRole = 'Foodie & Chef';

  /// Jumlah hari berturut-turut pengguna memasak (saat ini hardcoded)
  int cookingStreak = 5;

  /// URL gambar profil pengguna yang disimpan di Supabase Storage
  String? profileImageUrl;

  /// Resep yang direkomendasikan untuk ditampilkan di dasbor
  Map<String, dynamic>? recommendedRecipe;

  @override
  void initState() {
    super.initState();
    // Memuat data pengguna saat layar diinisialisasi
    _loadUserData();
    _loadRecommendedRecipe();
  }

  /// Mengambil data pengguna dari Supabase termasuk nama profil dan URL gambar.
  /// Membuat profil default jika tidak ada.
  ///
  /// Fungsi ini:
  /// 1. Mendapatkan pengguna terotentikasi saat ini
  /// 2. Mengambil profil mereka dari tabel user_profiles
  /// 3. Memperbarui UI dengan informasi mereka
  /// 4. Membuat profil default jika tidak ada
  Future<void> _loadUserData() async {
    try {
      final user = SupabaseService.getCurrentUser();
      debugPrint("=== HOME SCREEN USER DATA ===");
      debugPrint("Current user: ${user?.id}");
      debugPrint("User email: ${user?.email}");
      debugPrint("Auth metadata: ${user?.userMetadata}");

      if (user != null) {
        // Try to load existing profile
        final userData = await SupabaseService.getUserProfile(user.id);
        debugPrint("Profile data: $userData");

        if (userData.isNotEmpty) {
          // Profile exists - use it
          final username = userData['username']?.toString();
          final profileImg = userData['profile_image_url']?.toString();

          setState(() {
            userName = username?.isNotEmpty == true ? username : 'User';
            profileImageUrl =
                profileImg?.isNotEmpty == true ? profileImg : null;
          });

          debugPrint("Username loaded from profile: $userName");
        } else {
          // No profile found - create one safely
          debugPrint("No profile found, creating one");

          // Prioritas untuk username:
          // 1. Auth metadata username
          // 2. Auth metadata display_name
          // 3. Generic "User" (TIDAK menggunakan email)
          final authUsername = user.userMetadata?['username']?.toString();
          final authDisplayName =
              user.userMetadata?['display_name']?.toString();
          final fallbackName = authUsername ?? authDisplayName ?? 'User';

          // Jika masih tidak ada username, periksa apakah pengguna baru mendaftar
          String finalUsername = fallbackName;
          if (finalUsername == 'User') {
            // Gunakan nama default untuk pengguna baru
            finalUsername = 'New User';
          }

          setState(() {
            userName = finalUsername;
            profileImageUrl = null;
          });

          debugPrint("Using fallback username: $finalUsername");
          debugPrint("Auth username: $authUsername");
          debugPrint("Auth display_name: $authDisplayName");

          // Buat profil di background dengan username yang benar
          _createProfileInBackground(user.id, user.email!, finalUsername);
        }
      } else {
        debugPrint("No current user, scheduling redirect to login");

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() {
        userName = 'User';
        profileImageUrl = null;
      });
    }
  }

  /// Membuat profil pengguna di background tanpa memblokir UI
  ///
  /// [userId] - ID pengguna dari Supabase Auth
  /// [email] - Email pengguna
  /// [username] - Nama pengguna yang akan digunakan
  Future<void> _createProfileInBackground(
    String userId,
    String email,
    String username,
  ) async {
    try {
      debugPrint("Creating profile in background for: $username");

      // Tunggu sebentar agar sesi stabil
      await Future.delayed(const Duration(seconds: 2));

      await SupabaseService.createDefaultProfile(userId, email, username);
      debugPrint("Profile created successfully in background");

      // Opsional: muat ulang data profil
      final userData = await SupabaseService.getUserProfile(userId);
      if (userData.isNotEmpty && mounted) {
        setState(() {
          userName = userData['username'] ?? username;
        });
      }
    } catch (e) {
      debugPrint("Background profile creation failed: $e");
      // Jangan tampilkan error ke pengguna, lanjutkan dengan username fallback
    }
  }

  /// Membangun widget gambar profil dengan fallback yang sesuai
  ///
  /// Urutan prioritas:
  /// 1. Jika ada profileImageUrl yang valid, tampilkan network image
  /// 2. Jika tidak ada atau kosong, tampilkan default asset image
  /// 3. Jika asset gagal load, tampilkan icon default
  Widget _buildProfileImageWidget() {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      // Gunakan gambar profil default dari asset
      return Image.asset(
        'assets/images/default_profile.png',
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Jika gambar default gagal, tampilkan ikon default
          return Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          );
        },
      );
    } else {
      return Image.network(
        profileImageUrl!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading profile image: $error');
          // Jika gambar jaringan gagal, tampilkan gambar asset default
          return Image.asset(
            'assets/images/default_profile.png',
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Jika bahkan asset default gagal, tampilkan ikon sederhana
              return Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              );
            },
          );
        },
      );
    }
  }

  /// Memuat resep yang direkomendasikan dari API
  ///
  /// Method ini akan:
  /// 1. Memanggil API untuk mendapatkan resep acak
  /// 2. Memperbarui state dengan resep yang diterima
  /// 3. Menangani error jika terjadi masalah
  Future<void> _loadRecommendedRecipe() async {
    try {
      final recipes = await RecipeApiService.getRandomRecipes(count: 1);
      if (recipes.isNotEmpty) {
        setState(() {
          recommendedRecipe = recipes.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommended recipe: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar dengan judul aplikasi
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F8),
        elevation: 2,
        shadowColor: const Color(0xFFFAF8F8),
        title: const Text(
          'My Cookbook',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17.80,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),

      // Konten utama dalam container yang dapat di-scroll
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAGIAN 1: RESEP UNGGULAN
            // Menampilkan resep unggulan dengan gambar dan judul
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFFAF8F8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Featured Recipes', // Resep Unggulan
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22.70,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tata letak gambar dengan rasio 2:1 untuk resep unggulan
                  SizedBox(
                    height: 190,
                    child: Row(
                      children: [
                        // Gambar fitur besar (lebar 2/3)
                        Expanded(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              image: const DecorationImage(
                                image: NetworkImage(
                                  "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9",
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Gambar fitur kecil (lebar 1/3)
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              image: const DecorationImage(
                                image: NetworkImage(
                                  "https://images.unsplash.com/photo-1607532941433-304659e8198a",
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Judul resep untuk item yang ditampilkan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Creamy Tomato Pasta', // Pasta Tomat Krim
                        style: TextStyle(
                          color: const Color(0xFF625B5C),
                          fontSize: 16.30,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        'Fresh Salad', // Salad Segar
                        style: TextStyle(
                          color: const Color(0xFF60595A),
                          fontSize: 15.80,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // BAGIAN 2: AKSES CEPAT
            // Menyediakan navigasi cepat ke kategori resep umum
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Access', // Akses Cepat
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 21.70,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Opsi Baru Dilihat dengan ikon
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFE6D8D9),
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Color(0xFF6F6869),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Recently Viewed', // Baru Dilihat
                          style: TextStyle(
                            color: const Color(0xFF6F6869),
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Opsi Favorit dengan ikon
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFE6D8D9),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFF70696A),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Favorites', // Favorit
                          style: TextStyle(
                            color: const Color(0xFF70696A),
                            fontSize: 16.20,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Opsi Cepat & Mudah dengan ikon
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFE6D8D9),
                          ),
                          child: const Icon(
                            Icons.timer,
                            color: Color(0xFF716A6B),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Quick & Easy', // Cepat & Mudah
                          style: TextStyle(
                            color: const Color(0xFF716A6B),
                            fontSize: 15.60,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // BAGIAN 3: KATEGORI
            // Menampilkan pilihan filter resep
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories', // Kategori
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22.20,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Baris pertama filter kategori
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Filter Berdasarkan Waktu
                      Expanded(
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF9F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE6D8D9)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFF565051),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'By Time', // Berdasarkan Waktu
                                style: TextStyle(
                                  color: const Color(0xFF565051),
                                  fontSize: 15.60,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filter Berdasarkan Kesulitan
                      Expanded(
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF8F8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE6D8D9)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Color(0xFF554F4F),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'By Difficulty', // Berdasarkan Kesulitan
                                style: TextStyle(
                                  color: const Color(0xFF554F4F),
                                  fontSize: 16.90,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filter Berdasarkan Jenis Masakan
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF9F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE6D8D9)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          color: Color(0xFF524C4D),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'By Cuisine', // Berdasarkan Jenis Masakan
                          style: TextStyle(
                            color: const Color(0xFF524C4D),
                            fontSize: 16.50,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // BAGIAN 4: DASBOR PRIBADI
            // Menampilkan informasi profil pengguna dan statistik pribadi
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Dashboard', // Dasbor Pribadi
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22.30,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Informasi profil pengguna dengan gambar dan nama
                  Row(
                    children: [
                      // Profile picture with same logic as profile_screen
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: ClipOval(child: _buildProfileImageWidget()),
                      ),
                      const SizedBox(width: 20),
                      // Nama dan peran pengguna
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName ?? 'User',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 21.68,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userRole, // Foodie & Chef
                            style: TextStyle(
                              color: const Color(0xFFFF002A),
                              fontSize: 16.50,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Kartu statistik pengguna (rangkaian memasak dan resep hari ini)
                  Row(
                    children: [
                      // Kartu Rangkaian Memasak
                      Expanded(
                        child: Container(
                          height: 196,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF9F9),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFFE6D8D9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cooking Streak', // Rangkaian Memasak
                                style: TextStyle(
                                  color: const Color(0xFF605A5B),
                                  fontSize: 16.50,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$cookingStreak days', // 5 hari
                                style: TextStyle(
                                  color: const Color(0xFF403839),
                                  fontSize: 24.30,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Kartu Resep Hari Ini
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              recommendedRecipe != null
                                  ? () {
                                    Navigator.pushNamed(
                                      context,
                                      '/external-recipe-details',
                                      arguments: {
                                        ...recommendedRecipe!,
                                        'isSaved': false,
                                        'fromProfile': false,
                                      },
                                    );
                                  }
                                  : null,
                          child: Container(
                            height: 196,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF9F9),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: const Color(0xFFE6D8D9),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rekomendasi Hari Ini',
                                  style: TextStyle(
                                    color: const Color(0xFF5F5859),
                                    fontSize: 17.10,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (recommendedRecipe != null) ...[
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        recommendedRecipe!['image_url'] ?? '',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.restaurant,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    recommendedRecipe!['title'] ?? '-',
                                    style: TextStyle(
                                      color: const Color(0xFF373030),
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      height: 1.21,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ] else ...[
                                  const Text('Memuat rekomendasi...'),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // BAGIAN 5: PENCARIAN & PENEMUAN
            // Menyediakan fungsi pencarian dan opsi penemuan tambahan
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search & Discovery', // Pencarian & Penemuan
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22.70,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kolom pencarian
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E9EA),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search, color: Color(0xFFB08E90)),
                        const SizedBox(width: 12),
                        Text(
                          'Search recipes', // Cari resep
                          style: TextStyle(
                            color: const Color(0xFFB08E90),
                            fontSize: 16.90,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Opsi Pencarian berdasarkan Bahan
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFE6D8D9),
                          ),
                          child: const Icon(
                            Icons.local_dining,
                            color: Color(0xFF736D6E),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Search by Ingredients', // Cari berdasarkan Bahan
                          style: TextStyle(
                            color: const Color(0xFF736D6E),
                            fontSize: 16.50,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Opsi Resep Musiman & Liburan
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFE6D8D9),
                          ),
                          child: const Icon(
                            Icons.event,
                            color: Color(0xFF736D6E),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Seasonal & Holiday Recipes', // Resep Musiman & Liburan
                          style: TextStyle(
                            color: const Color(0xFF736D6E),
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bar Navigasi Bawah
      // Memungkinkan navigasi antara bagian utama aplikasi
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFBF9F9),
        selectedItemColor: const Color(0xFF824E50),
        unselectedItemColor: Colors.grey,
        currentIndex: 0, // Index untuk Home
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.pushNamed(
                context,
                '/search',
              ); // ✅ Changed from pushReplacementNamed
              break;
            case 2:
              Navigator.pushNamed(context, '/recipes');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
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
