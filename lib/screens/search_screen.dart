/// `SearchScreen` adalah layar untuk mencari resep masakan.
/// Layar ini menampilkan hasil pencarian dari API Spoonacular dan
/// memungkinkan pengguna untuk menyimpan resep yang ditemukan.
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/recipe_api_service.dart';
import '../widgets/recipe_image.dart';

/// Widget untuk menampilkan hasil pencarian resep.
///
/// Fitur-fitur yang tersedia:
/// - Pencarian resep berdasarkan kata kunci
/// - Tampilan hasil pencarian dalam bentuk grid
/// - Opsi untuk menyimpan resep ke daftar favorit
/// - Navigasi ke detail resep
/// - Penanganan loading state dan error
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// Controller untuk field pencarian
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _localRecipes = [];
  List<Map<String, dynamic>> _apiRecipes = [];
  List<String> _categories = [];
  Set<String> _savedRecipeIds = {}; // ✅ Use Set for better performance
  bool _isLoading = false;
  bool _showingResults = false;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFeaturedRecipes();
    _loadSavedRecipeIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Improved method to load saved recipe IDs
  Future<void> _loadSavedRecipeIds() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        // Load both regular saved recipes and external saved recipes IDs
        final savedRecipes = await SupabaseService.getUserSavedRecipes(user.id);
        final savedExternalRecipes =
            await SupabaseService.getUserSavedExternalRecipes(user.id);

        final allSavedIds = <String>{};

        // Add regular saved recipe IDs
        allSavedIds.addAll(
          savedRecipes.map((recipe) => recipe['id'].toString()),
        );

        // Add external saved recipe IDs
        allSavedIds.addAll(
          savedExternalRecipes.map((recipe) => recipe['id']?.toString() ?? ''),
        );

        setState(() {
          _savedRecipeIds = allSavedIds;
        });

        debugPrint(
          '✅ Loaded ${allSavedIds.length} total saved recipe IDs for search screen',
        );
      }
    } catch (e) {
      debugPrint('Error loading saved recipe IDs: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await RecipeApiService.getCategories();
      setState(() {
        _categories = categories.take(10).toList(); // Show top 10 categories
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadFeaturedRecipes() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final apiRecipes = await RecipeApiService.getRandomRecipes(count: 20);

      setState(() {
        _apiRecipes = apiRecipes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading featured recipes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Melakukan pencarian resep berdasarkan kata kunci.
  ///
  /// Proses yang dilakukan:
  /// 1. Validasi input pencarian
  /// 2. Memanggil service untuk mencari resep
  /// 3. Memperbarui state dengan hasil pencarian
  /// 4. Menangani error jika terjadi kesalahan
  Future<void> _searchRecipes(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _showingResults = false;
        _localRecipes = [];
        _apiRecipes = [];
      });
      _loadFeaturedRecipes();
      return;
    }

    setState(() {
      _isLoading = true;
      _showingResults = true;
    });

    try {
      // Search local recipes
      final localResults = await SupabaseService.searchRecipes(query);

      // Search API recipes
      final apiResults = await RecipeApiService.searchRecipes(query);

      setState(() {
        _localRecipes = localResults;
        _apiRecipes = apiResults;
        _isLoading = false;
      });

      debugPrint(
        'Found ${localResults.length} local and ${apiResults.length} API recipes',
      );
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchByCategory(String category) async {
    setState(() {
      _isLoading = true;
      _showingResults = true;
    });

    try {
      final apiResults = await RecipeApiService.getRecipesByCategory(category);

      setState(() {
        _localRecipes = [];
        _apiRecipes = apiResults;
        _isLoading = false;
      });

      debugPrint('Found ${apiResults.length} recipes for category: $category');
    } catch (e) {
      debugPrint('Error searching by category: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Menyimpan resep ke daftar favorit pengguna.
  ///
  /// Proses yang dilakukan:
  /// 1. Validasi status login pengguna
  /// 2. Memanggil service untuk menyimpan resep
  /// 3. Memperbarui state setelah penyimpanan
  /// 4. Menangani error jika terjadi kesalahan
  ///
  /// Parameter:
  /// - [recipe]: Resep yang akan disimpan
  Future<void> _saveRecipe(Map<String, dynamic> recipe) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to save recipes'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ✅ Save external recipe directly to saved_external_recipes table
      // Don't create a recipe entry in the main recipes table
      final success = await SupabaseService.saveExternalRecipe(
        userId: user.id,
        externalRecipeData: recipe,
      );

      if (success) {
        // Update local state immediately
        setState(() {
          _savedRecipeIds.add(recipe['id']?.toString() ?? '');
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe saved to your collection!'),
              backgroundColor: Color(0xFF824E50),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe already saved'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving external recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save recipe'),
            backgroundColor: Colors.red,
          ),
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
          'Discover Recipes',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
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
                  hintText: 'Search thousands of recipes...',
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
                onSubmitted: _searchRecipes,
                onChanged: (value) {
                  if (value.isEmpty) {
                    _searchRecipes('');
                  }
                },
              ),
            ),
          ),

          // Categories (when not showing search results)
          if (!_showingResults && _categories.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Browse Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 35,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => _searchByCategory(category),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF824E50),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],

          // Content Area
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF824E50)),
                          SizedBox(height: 16),
                          Text('Searching recipes...'),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Local Results Section
                            if (_localRecipes.isNotEmpty) ...[
                              const Text(
                                'Your Recipes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: _localRecipes.length,
                                itemBuilder: (context, index) {
                                  return _buildRecipeItem(_localRecipes[index]);
                                },
                              ),
                              const SizedBox(height: 24),
                            ],

                            // API Results Section
                            if (_apiRecipes.isNotEmpty) ...[
                              Text(
                                _showingResults
                                    ? 'More Recipes'
                                    : 'Featured Recipes',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: _apiRecipes.length,
                                itemBuilder: (context, index) {
                                  return _buildRecipeItem(_apiRecipes[index]);
                                },
                              ),
                            ],

                            // Empty State
                            if (_showingResults &&
                                _localRecipes.isEmpty &&
                                _apiRecipes.isEmpty) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 80,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No recipes found',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Try searching with different keywords',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
        currentIndex: 1, // Search tab
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              // Already on search
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/recipes');
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

  // ✅ Update recipe item widget
  Widget _buildRecipeItem(Map<String, dynamic> recipe) {
    final isExternal =
        recipe['is_external'] == true ||
        recipe['id']?.toString().startsWith('api_') == true;
    final user = SupabaseService.getCurrentUser();
    final isOwnRecipe =
        !isExternal && user != null && recipe['user_id'] == user.id;

    // Check if recipe is already saved
    final recipeId = recipe['id']?.toString() ?? '';
    final isAlreadySaved = _savedRecipeIds.contains(recipeId);

    return GestureDetector(
      onTap: () {
        if (isExternal) {
          // ✅ Navigate to external recipe detail
          Navigator.pushNamed(
            context,
            '/external-recipe-details',
            arguments: {
              ...recipe,
              'isSaved': isAlreadySaved,
              'fromProfile': false,
            },
          );
        } else {
          // ✅ Navigate to local recipe detail
          Navigator.pushNamed(
            context,
            '/recipe-details',
            arguments: recipe['id'].toString(),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12), // ✅ Increased padding
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
        child: IntrinsicHeight(
          // ✅ Use IntrinsicHeight to prevent overflow
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // ✅ Align to start
            children: [
              // Recipe Image
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      recipe['image_url'] != null
                          ? Image.network(
                            recipe['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.restaurant,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              );
                            },
                          )
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.restaurant,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                ),
              ),

              const SizedBox(width: 12),

              // Recipe Info - ✅ Use Expanded to prevent overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ✅ Use minimum space needed
                  children: [
                    // Title
                    Text(
                      recipe['title'] ?? 'Untitled Recipe',
                      style: const TextStyle(
                        color: Color(0xFF635959),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2, // ✅ Allow 2 lines for title
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Recipe Details
                    Row(
                      children: [
                        if (recipe['cooking_time'] != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe['cooking_time']} min',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        if (recipe['cooking_time'] != null &&
                            recipe['category'] != null)
                          const SizedBox(width: 12),
                        if (recipe['category'] != null) ...[
                          Icon(
                            Icons.restaurant_menu,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            // ✅ Use Flexible to prevent overflow
                            child: Text(
                              recipe['category'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Description - ✅ Only show if there's space
                    if (recipe['description'] != null && !isExternal) ...[
                      Text(
                        recipe['description'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Save Button - ✅ Fixed positioning
              if (!isOwnRecipe) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero, // ✅ Remove default padding
                    constraints:
                        const BoxConstraints(), // ✅ Remove default constraints
                    icon: Icon(
                      isAlreadySaved ? Icons.bookmark : Icons.bookmark_outline,
                      color:
                          isAlreadySaved
                              ? const Color(0xFF824E50)
                              : const Color(0xFF824E50),
                      size: 18,
                    ),
                    onPressed:
                        isAlreadySaved
                            ? null
                            : () =>
                                isExternal
                                    ? _saveRecipe(recipe)
                                    : _saveRecipe(recipe),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
