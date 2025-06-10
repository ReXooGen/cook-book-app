/// `ProfileScreen` adalah layar yang menampilkan profil pengguna.
/// Layar ini menampilkan informasi pengguna seperti foto profil, nama,
/// handle, dan statistik (resep, pengikut, mengikuti). Pengguna juga dapat
/// melihat resep yang dibuat dan disimpan, serta mengelola pengaturan akun.
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';

/// Widget untuk menampilkan layar profil pengguna.
///
/// Fitur-fitur yang tersedia:
/// - Tampilan foto profil dengan opsi untuk mengubah
/// - Informasi pengguna (nama, handle, tahun bergabung)
/// - Statistik (jumlah resep, pengikut, mengikuti)
/// - Tab untuk resep yang dibuat dan disimpan
/// - Pengaturan akun dan logout
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Nama pengguna yang ditampilkan
  String? userName;

  /// Email pengguna
  String? userEmail;

  /// ID unik pengguna
  String? userId;

  /// URL foto profil pengguna
  String? profileImageUrl;

  /// Handle pengguna (format: @username)
  String? userHandle;

  /// Tahun bergabung pengguna
  String? userJoinedYear;

  /// Data profil lengkap pengguna
  Map<String, dynamic>? userProfile;

  /// Status loading saat memuat data
  bool isLoading = true;

  /// Jumlah resep yang dibuat pengguna
  int recipesCountDisplay = 0;

  /// Jumlah pengikut pengguna
  int followersCountDisplay = 0;

  /// Jumlah akun yang diikuti pengguna
  int followingCountDisplay = 0;

  /// Daftar resep yang dibuat pengguna
  List<Map<String, dynamic>> userCreatedRecipes = [];

  /// Daftar resep yang disimpan pengguna
  List<Map<String, dynamic>> savedRecipes = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  /// Memuat semua data profil pengguna sekaligus.
  ///
  /// Data yang dimuat:
  /// - Profil pengguna
  /// - Resep yang dibuat
  /// - Resep yang disimpan (reguler dan eksternal)
  /// - Jumlah resep, pengikut, dan mengikuti
  Future<void> _loadAllData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = SupabaseService.getCurrentUser();
      if (user == null) return;

      // Load all data
      final profile = await SupabaseService.getUserProfile(user.id);
      final createdRecipes = await SupabaseService.getUserRecipes(user.id);

      // Load both regular saved recipes AND external saved recipes
      final savedRecipesList = await SupabaseService.getUserSavedRecipes(
        user.id,
      );
      final savedExternalRecipesList =
          await SupabaseService.getUserSavedExternalRecipes(user.id);

      // Combine both lists for saved recipes tab
      final allSavedRecipes = <Map<String, dynamic>>[];
      allSavedRecipes.addAll(savedRecipesList);
      allSavedRecipes.addAll(savedExternalRecipesList);

      // Sort by saved date
      allSavedRecipes.sort((a, b) {
        final aDate =
            DateTime.tryParse(
              a['saved_at']?.toString() ?? a['created_at']?.toString() ?? '',
            ) ??
            DateTime.now();
        final bDate =
            DateTime.tryParse(
              b['saved_at']?.toString() ?? b['created_at']?.toString() ?? '',
            ) ??
            DateTime.now();
        return bDate.compareTo(aDate);
      });

      final recipesCount = await SupabaseService.getUserRecipesCount(user.id);
      final followersCount = await SupabaseService.getUserFollowersCount(
        user.id,
      );
      final followingCount = await SupabaseService.getUserFollowingCount(
        user.id,
      );

      if (mounted) {
        setState(() {
          userProfile = profile;
          userName = profile['username'] ?? user.email?.split('@')[0] ?? 'User';
          userEmail = user.email;
          userId = user.id;
          userHandle =
              '@${profile['username']?.toString().toLowerCase().replaceAll(' ', '_') ?? user.email?.split('@')[0] ?? 'user'}';

          profileImageUrl = profile['profile_image_url'];

          try {
            final createdAtString = user.createdAt;
            final parsedDate = DateTime.parse(createdAtString);
            userJoinedYear = 'Joined ${parsedDate.year}';
          } catch (dateError) {
            debugPrint('Error parsing date: $dateError');
            userJoinedYear = 'Joined ${DateTime.now().year}';
          }

          userCreatedRecipes = createdRecipes;
          savedRecipes = allSavedRecipes;

          recipesCountDisplay = recipesCount;
          followersCountDisplay = followersCount;
          followingCountDisplay = followingCount;
          isLoading = false;
        });

        debugPrint('✅ Loaded ${createdRecipes.length} created recipes');
        debugPrint('✅ Loaded ${savedRecipesList.length} regular saved recipes');
        debugPrint(
          '✅ Loaded ${savedExternalRecipesList.length} external saved recipes',
        );
        debugPrint('✅ Total saved recipes: ${allSavedRecipes.length}');
      }
    } catch (e) {
      debugPrint('❌ Error loading profile data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Memuat ulang daftar resep yang disimpan pengguna.
  ///
  /// Method ini mengambil data dari database dan menggabungkan
  /// resep reguler dan eksternal yang disimpan.
  Future<void> _loadSavedRecipes() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        final recipes = await SupabaseService.getUserSavedRecipes(user.id);
        final externalRecipes =
            await SupabaseService.getUserSavedExternalRecipes(user.id);

        final allSavedRecipes = <Map<String, dynamic>>[];
        allSavedRecipes.addAll(recipes);
        allSavedRecipes.addAll(externalRecipes);

        setState(() {
          savedRecipes = allSavedRecipes;
        });
        debugPrint('Loaded ${allSavedRecipes.length} total saved recipes');
      }
    } catch (e) {
      debugPrint('Error loading saved recipes: $e');
      setState(() {
        savedRecipes = [];
      });
    }
  }

  /// Menampilkan dialog untuk memilih sumber foto profil.
  ///
  /// Opsi yang tersedia:
  /// - Galeri: memilih foto dari galeri
  /// - Kamera: mengambil foto menggunakan kamera
  Future<void> _updateProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF2E6E7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text(
              'Update Profile Picture',
              style: TextStyle(
                color: Color(0xFF584D4D),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose how you want to update your profile picture:',
                  style: TextStyle(color: Color(0xFF584D4D)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 80,
                          );
                          if (image != null) {
                            await _handleImageUpload(File(image.path));
                          }
                        } catch (e) {
                          debugPrint('Error picking image from gallery: $e');
                        }
                      },
                    ),
                    _buildImageSourceButton(
                      icon: Icons.photo_camera,
                      label: 'Camera',
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 80,
                          );
                          if (image != null) {
                            await _handleImageUpload(File(image.path));
                          }
                        } catch (e) {
                          debugPrint('Error taking photo: $e');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF824E50)),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error in _updateProfilePicture: $e');
    }
  }

  /// Menangani proses upload foto profil.
  ///
  /// Proses yang dilakukan:
  /// 1. Menampilkan dialog loading
  /// 2. Mencoba upload foto menggunakan metode utama
  /// 3. Jika gagal, mencoba metode alternatif
  /// 4. Memperbarui URL foto profil di database
  /// 5. Memperbarui tampilan foto profil
  Future<void> _handleImageUpload(File imageFile) async {
    if (!mounted) return;

    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading profile picture...'),
                ],
              ),
            ),
      );

      String imageUrl = '';

      try {
        // Try to upload image
        imageUrl = await SupabaseService.uploadProfileImageSimple(imageFile);
      } catch (uploadError) {
        debugPrint('Upload error: $uploadError');
        try {
          imageUrl = await SupabaseService.uploadProfileImageAlternative(
            imageFile,
          );
        } catch (e) {
          debugPrint('Alternative upload also failed: $e');
        }
      }

      if (imageUrl.isNotEmpty) {
        // Update profile with uploaded image URL
        await SupabaseService.updateUserProfile(user.id, {
          'profile_image_url': imageUrl,
        });

        setState(() {
          profileImageUrl = imageUrl;
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _handleImageUpload: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  /// Menangani proses logout pengguna.
  ///
  /// Proses yang dilakukan:
  /// 1. Memanggil service untuk logout
  /// 2. Mengarahkan ke layar login
  /// 3. Menampilkan pesan error jika gagal
  Future<void> _handleLogout() async {
    try {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error during logout')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBF9F9),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF824E50)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17.80,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Section
            Container(
              alignment: Alignment.center,
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _updateProfilePicture,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(child: _buildProfileImage()),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    userName ?? 'User',
                    style: const TextStyle(
                      color: Color(0xFF020000),
                      fontSize: 21.68,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // User Handle
                  Text(
                    userHandle ?? '@user',
                    style: const TextStyle(
                      color: Color(0xFF824E50),
                      fontSize: 16.71,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Joined Year
                  Text(
                    userJoinedYear ?? 'Joined ${DateTime.now().year}',
                    style: const TextStyle(
                      color: Color(0xFF804C4E),
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Recipes', recipesCountDisplay),
                _buildStatCard('Followers', followersCountDisplay),
                _buildStatCard('Following', followingCountDisplay),
              ],
            ),

            const SizedBox(height: 30),

            // Tabs untuk My Recipes dan Saved Recipes
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: Color(0xFF824E50),
                    labelColor: Color(0xFF824E50),
                    unselectedLabelColor: Colors.grey,
                    tabs: [Tab(text: 'My Recipes'), Tab(text: 'Saved Recipes')],
                  ),
                  const SizedBox(height: 20),
                  // ✅ Fix: Increase height and add constraints
                  SizedBox(
                    height: 450, // ✅ Increased from 400 to 450
                    child: TabBarView(
                      children: [
                        // My Recipes Tab - Updated dengan tombol create recipe
                        _buildMyRecipeGrid(),
                        // Saved Recipes Tab - Hanya menampilkan saved recipes
                        _buildSavedRecipeGrid(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Settings Section
            _buildSettingsSection(),

            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFBF9F9),
        selectedItemColor: const Color(0xFF824E50),
        unselectedItemColor: Colors.grey,
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/search');
              break;
            case 2:
              Navigator.pushNamed(context, '/recipes').then((_) {
                _loadSavedRecipes();
              });
              break;
            case 3:
              // Already on profile
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

  /// Widget untuk menampilkan My Recipe grid dengan tombol create
  Widget _buildMyRecipeGrid() {
    return Column(
      children: [
        // Header with create button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Recipes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF020000),
              ),
            ),
            Container(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/create-recipe').then((_) {
                    _loadAllData();
                  });
                },
                icon: const Icon(Icons.add, color: Colors.black, size: 35),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Recipe Grid - ✅ Fix: Better constraints
        Expanded(
          child:
              userCreatedRecipes.isEmpty
                  ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No recipes created yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button above to add your first recipe',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                  : GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(), // ✅ Add physics
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio:
                              167 / 180, // ✅ Reduced from 200 to 180
                        ),
                    itemCount: userCreatedRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = userCreatedRecipes[index];
                      return _buildRecipeCard(
                        recipe['title'] ?? 'Untitled Recipe',
                        recipe['image_url'],
                        recipe['id']?.toString() ?? '',
                      );
                    },
                  ),
        ),
      ],
    );
  }

  /// Widget untuk menampilkan Saved Recipe grid
  Widget _buildSavedRecipeGrid() {
    if (savedRecipes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No saved recipes yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Save recipes from search to see them here',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(), // ✅ Add physics
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 167 / 180, // ✅ Reduced from 200 to 180
      ),
      itemCount: savedRecipes.length,
      itemBuilder: (context, index) {
        final recipe = savedRecipes[index];
        return _buildSavedRecipeCard(recipe);
      },
    );
  }

  /// ✅ Fixed _buildSavedRecipeCard method
  Widget _buildSavedRecipeCard(Map<String, dynamic> recipe) {
    final recipeId = recipe['id']?.toString() ?? '';
    final title = recipe['title'] ?? 'Untitled Recipe';
    final imageUrl = recipe['image_url'];
    final isExternal =
        recipe['is_external'] == true || recipeId.startsWith('api_');

    return GestureDetector(
      onTap: () async {
        debugPrint(
          'Navigating to recipe with ID: $recipeId, isExternal: $isExternal',
        );

        if (isExternal) {
          // ✅ Navigate to external recipe detail screen
          final result = await Navigator.pushNamed(
            context,
            '/external-recipe-details',
            arguments: {...recipe, 'isSaved': true, 'fromProfile': true},
          );
          // If result == true, reload saved recipes
          if (result == true) {
            _loadAllData();
          }
        } else {
          // ✅ Navigate to local recipe detail screen
          if (recipeId.isNotEmpty) {
            final result = await Navigator.pushNamed(
              context,
              '/recipe-details',
              arguments: recipeId,
            );
            // Reload data after returning from recipe details
            if (result != null) {
              _loadAllData();
            }
          }
        }
      },
      child: SizedBox(
        width: 167,
        height: 180, // ✅ Reduced from 200 to 180
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 167,
              height: 150, // ✅ Reduced from 167 to 150
              decoration: ShapeDecoration(
                image:
                    imageUrl != null && imageUrl.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                        : const DecorationImage(
                          image: NetworkImage("https://placehold.co/167x167"),
                          fit: BoxFit.cover,
                        ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child:
                  isExternal
                      ? Stack(
                        children: [
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SAVED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : null,
            ),
            const SizedBox(height: 8),
            Expanded(
              // ✅ Use Expanded for flexible text height
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF080505),
                  fontSize: 15, // ✅ Slightly reduced font size
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(String title, String? imageUrl, String recipeId) {
    return GestureDetector(
      onTap: () async {
        debugPrint('Navigating to recipe with ID: $recipeId');
        if (recipeId.isNotEmpty) {
          final result = await Navigator.pushNamed(
            context,
            '/recipe-details',
            arguments: recipeId,
          );
          // Reload data after returning from recipe details
          if (result != null) {
            _loadAllData();
          }
        }
      },
      child: SizedBox(
        width: 167,
        height: 180, // ✅ Reduced from 200 to 180
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 167,
              height: 150, // ✅ Reduced from 167 to 150
              decoration: ShapeDecoration(
                image:
                    imageUrl != null && imageUrl.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                        : const DecorationImage(
                          image: NetworkImage("https://placehold.co/167x167"),
                          fit: BoxFit.cover,
                        ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              // ✅ Use Expanded for flexible text height
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF080505),
                  fontSize: 15, // ✅ Slightly reduced font size
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Color(0xFF020101),
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingsItem('Account', Icons.person_outline, () {}),
          const SizedBox(height: 15),
          _buildSettingsItem(
            'Notifications',
            Icons.notifications_outlined,
            () {},
          ),
          const SizedBox(height: 15),
          _buildSettingsItem('Privacy', Icons.privacy_tip_outlined, () {}),
          const SizedBox(height: 15),
          _buildSettingsItem('Help', Icons.help_outline, () {}),
          const SizedBox(height: 15),
          _buildSettingsItem('Logout', Icons.logout, () async {
            await _handleLogout();
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count) {
    return Container(
      width: 107,
      height: 82,
      decoration: ShapeDecoration(
        color: const Color(0xFFFBF9F9),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 3, color: Color(0xFFEADEDF)),
          borderRadius: BorderRadius.circular(9.85),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: ShapeDecoration(
          color: const Color(0xFFFBF9F9),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 2, color: Color(0xFFF6F1F2)),
            borderRadius: BorderRadius.circular(8.60),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFF0B0102),
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF89585A),
                fontSize: 13,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: ShapeDecoration(
              color: const Color(0xFFF1E9EA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF824E50)),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0D0304),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC5BABB)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF584D4D)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF584D4D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF824E50),
        ),
        child: const Icon(Icons.person, size: 60, color: Colors.white),
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
          return Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF824E50),
            ),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          );
        },
      );
    }
  }
}
