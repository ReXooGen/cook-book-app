/// `SupabaseService` adalah kelas utilitas untuk mengelola interaksi dengan backend Supabase.
/// Kelas ini menyediakan metode untuk autentikasi, pengelolaan profil, penyimpanan resep,
/// dan berbagai operasi database lainnya.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Kelas untuk mengelola interaksi dengan Supabase.
///
/// Fitur-fitur yang tersedia:
/// - Autentikasi pengguna (login, register, logout)
/// - Pengelolaan profil pengguna
/// - Penyimpanan dan pengambilan resep
/// - Upload gambar profil dan resep
/// - Pencarian resep
/// - Pengelolaan resep favorit
class SupabaseService {
  /// Nama bucket untuk menyimpan gambar profil
  static const String bucketName = 'profile-images';

  /// Instance Supabase client
  static late final SupabaseClient _client;

  /// Menginisialisasi koneksi Supabase dengan URL dan kunci anonim.
  ///
  /// Proses:
  /// 1. Menginisialisasi Supabase dengan kredensial dari konfigurasi
  /// 2. Menyimpan instance client untuk penggunaan selanjutnya
  static Future<void> initializeSupabase() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    debugPrint('Supabase diinisialisasi dengan sukses');
  }

  /// Memvalidasi kekuatan password berdasarkan kriteria keamanan.
  ///
  /// Kriteria yang divalidasi:
  /// - Minimal 8 karakter
  /// - Minimal 1 huruf besar
  /// - Minimal 1 angka
  /// - Minimal 1 karakter khusus
  ///
  /// Parameter:
  /// - [password]: Password yang akan divalidasi
  ///
  /// Returns:
  /// - bool: true jika password memenuhi kriteria, false jika tidak
  static bool isPasswordStrong(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_-]'))) return false;
    return true;
  }

  /// Mendaftarkan pengguna baru dengan email dan password.
  ///
  /// Parameter:
  /// - [email]: Email pengguna
  /// - [password]: Password pengguna
  /// - [name]: Nama pengguna
  ///
  /// Returns:
  /// - AuthResponse: Response dari Supabase yang berisi data user dan session
  ///
  /// Proses:
  /// 1. Memanggil API Supabase untuk mendaftarkan pengguna
  /// 2. Menyimpan username dalam metadata
  /// 3. Menangani error jika terjadi kesalahan
  static Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      debugPrint('Registration attempt - Email: $email, Username: $name');

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': name}, // Store username in auth metadata
      );

      if (response.user != null) {
        debugPrint("User registered: ${response.user!.id}");
        debugPrint("Username to be saved: $name");
        debugPrint("Email confirmed at: ${response.user!.emailConfirmedAt}");
        debugPrint("Session exists: ${response.session != null}");

        // ✅ Don't create profile here - let the app handle it after proper authentication
        debugPrint("Registration successful, profile will be created later");
      }

      return response;
    } catch (e) {
      debugPrint("Error in registration: $e");
      rethrow;
    }
  }

  /// Melakukan login dengan email dan password.
  ///
  /// Parameter:
  /// - [email]: Email pengguna
  /// - [password]: Password pengguna
  ///
  /// Returns:
  /// - AuthResponse: Response dari Supabase yang berisi data user dan session
  ///
  /// Proses:
  /// 1. Memanggil API Supabase untuk login
  /// 2. Mengecek dan membuat profil jika belum ada
  /// 3. Menangani error jika terjadi kesalahan
  static Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('Login successful for user: ${response.user!.id}');
        debugPrint('User metadata after login: ${response.user!.userMetadata}');

        // ✅ If no profile exists, try to create one with metadata username
        final existingProfile = await getUserProfile(response.user!.id);
        if (existingProfile.isEmpty) {
          debugPrint('No profile found for user: ${response.user!.id}');

          // Get username from metadata
          final metadataUsername =
              response.user!.userMetadata?['username']?.toString();
          final metadataDisplayName =
              response.user!.userMetadata?['display_name']?.toString();
          final metadataFullName =
              response.user!.userMetadata?['full_name']?.toString();

          final username =
              metadataUsername ??
              metadataDisplayName ??
              metadataFullName ??
              'User';

          debugPrint('Creating profile with username from metadata: $username');

          try {
            await createDefaultProfile(
              response.user!.id,
              response.user!.email!,
              username,
            );
            debugPrint('Created default profile for: $username');
          } catch (e) {
            debugPrint('Error creating profile: $e');
          }
        }
      }

      return response;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  /// Melakukan logout pengguna saat ini.
  ///
  /// Proses:
  /// 1. Memanggil API Supabase untuk logout
  /// 2. Menghapus session pengguna
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Menambahkan resep baru ke database.
  ///
  /// Parameter:
  /// - [title]: Judul resep
  /// - [description]: Deskripsi resep
  /// - [imageUrl]: URL gambar resep
  /// - [ingredients]: Daftar bahan-bahan
  /// - [steps]: Daftar langkah-langkah
  /// - [cookingTime]: Waktu memasak dalam menit
  /// - [isPublic]: Apakah resep bersifat publik
  ///
  /// Returns:
  /// - Map<String, dynamic>: Data resep yang berhasil disimpan
  ///
  /// Proses:
  /// 1. Memvalidasi user yang sedang login
  /// 2. Menyiapkan data resep
  /// 3. Menyimpan ke database
  /// 4. Menangani error jika terjadi kesalahan
  static Future<Map<String, dynamic>> addRecipe({
    required String title,
    required String description,
    required String imageUrl,
    required List<String> ingredients,
    required List<String> steps,
    required int cookingTime,
    bool isPublic = true,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare recipe data
      final recipe = {
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'ingredients': ingredients,
        'steps': steps,
        'cooking_time': cookingTime,
        'user_id': user.id,
        'is_public': isPublic,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client.from('recipes').insert(recipe).select().single();

      debugPrint('Recipe added successfully: ${response['id']}');
      return response;
    } catch (e) {
      debugPrint('Error adding recipe: $e');
      rethrow;
    }
  }

  /// Mendapatkan stream daftar resep publik.
  ///
  /// Returns:
  /// - Stream<List<Map<String, dynamic>>>: Stream data resep publik
  ///
  /// Proses:
  /// 1. Membuat query untuk mendapatkan resep publik
  /// 2. Mengurutkan berdasarkan waktu pembuatan
  /// 3. Mengembalikan stream data
  static Stream<List<Map<String, dynamic>>> getRecipes() {
    return _client
        .from('recipes')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .map((events) => events);
  }

  /// Mendapatkan resep berdasarkan ID.
  ///
  /// Parameter:
  /// - [recipeId]: ID resep yang ingin didapatkan
  ///
  /// Returns:
  /// - Map<String, dynamic>: Data resep
  ///
  /// Proses:
  /// 1. Membuat query untuk mendapatkan resep berdasarkan ID
  /// 2. Menangani error jika terjadi kesalahan
  static Future<Map<String, dynamic>> getRecipeById(String recipeId) async {
    try {
      final response =
          await _client.from('recipes').select('*').eq('id', recipeId).single();

      debugPrint('Recipe found: $response');
      return response;
    } catch (e) {
      debugPrint('Error getting recipe by ID: $e');
      rethrow;
    }
  }

  /// Mendapatkan semua resep yang dibuat oleh pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep pengguna
  ///
  /// Proses:
  /// 1. Membuat query untuk mendapatkan resep berdasarkan user ID
  /// 2. Menggabungkan dengan data profil pengguna
  /// 3. Mengurutkan berdasarkan waktu pembuatan
  static Future<List<Map<String, dynamic>>> getUserRecipes(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('recipes')
          .select('''
          *,
          user_profiles!inner (
            username,
            profile_image_url
          )
        ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      debugPrint('Loaded ${response.length} user recipes');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user recipes: $e');
      return [];
    }
  }

  /// Mendapatkan jumlah resep yang dibuat pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - int: Jumlah resep
  static Future<int> getUserRecipesCount(String userId) async {
    try {
      final response = await _client
          .from('recipes')
          .select('id')
          .eq('user_id', userId);

      return response.length;
    } catch (e) {
      debugPrint('Error getting user recipes count: $e');
      return 0;
    }
  }

  /// Mendapatkan jumlah followers pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - int: Jumlah followers
  static Future<int> getUserFollowersCount(String userId) async {
    try {
      final response = await _client
          .from('followers')
          .select('id')
          .eq('following_id', userId);

      return response.length;
    } catch (e) {
      debugPrint('Error getting user followers count: $e');
      return 0;
    }
  }

  /// Mendapatkan jumlah following pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - int: Jumlah following
  static Future<int> getUserFollowingCount(String userId) async {
    try {
      final response = await _client
          .from('followers')
          .select('id')
          .eq('follower_id', userId);

      return response.length;
    } catch (e) {
      debugPrint('Error getting user following count: $e');
      return 0;
    }
  }

  /// Menghapus resep dari database.
  ///
  /// Parameter:
  /// - [recipeId]: ID resep yang akan dihapus
  ///
  /// Proses:
  /// 1. Memvalidasi user yang sedang login
  /// 2. Memverifikasi kepemilikan resep
  /// 3. Menghapus resep dari database
  /// 4. Menangani error jika terjadi kesalahan
  static Future<void> deleteRecipe(String recipeId) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Verify user owns this recipe
      final existingRecipe = await getRecipeById(recipeId);
      if (existingRecipe['user_id'] != user.id) {
        throw Exception('User not authorized to delete this recipe');
      }

      await _client.from('recipes').delete().eq('id', recipeId);

      debugPrint('Recipe deleted successfully: $recipeId');
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      rethrow;
    }
  }

  /// Mendapatkan resep yang disimpan oleh pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep yang disimpan
  ///
  /// Proses:
  /// 1. Mendapatkan ID resep yang disimpan
  /// 2. Mendapatkan detail resep
  /// 3. Mengurutkan berdasarkan waktu penyimpanan
  static Future<List<Map<String, dynamic>>> getUserSavedRecipes(
    String userId,
  ) async {
    try {
      debugPrint('Getting saved recipes for user: $userId');

      // Step 1: Get saved recipe IDs with timestamps
      final savedRecipeIds = await _client
          .from('saved_recipes')
          .select('recipe_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (savedRecipeIds.isEmpty) {
        debugPrint('No saved recipes found');
        return [];
      }

      // Step 2: Get recipe IDs list
      final recipeIds =
          savedRecipeIds.map((item) => item['recipe_id'] as String).toList();

      debugPrint('Found ${recipeIds.length} saved recipe IDs');

      // Step 3: Get actual recipes
      final recipes = await _client
          .from('recipes')
          .select('*')
          .inFilter('id', recipeIds);

      // Step 4: Sort recipes by saved date (preserve order from saved_recipes)
      final recipeMap = {for (var recipe in recipes) recipe['id']: recipe};
      final sortedRecipes = <Map<String, dynamic>>[];

      for (var savedItem in savedRecipeIds) {
        final recipe = recipeMap[savedItem['recipe_id']];
        if (recipe != null) {
          // Add saved timestamp to the recipe data
          recipe['saved_at'] = savedItem['created_at'];
          sortedRecipes.add(recipe);
        }
      }

      debugPrint('✅ Loaded ${sortedRecipes.length} saved recipes');
      return sortedRecipes;
    } catch (e) {
      debugPrint('❌ Error getting saved recipes: $e');
      return [];
    }
  }

  /// Mendapatkan pengguna yang saat ini login.
  ///
  /// Returns:
  /// - User?: Data pengguna yang sedang login
  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Mendapatkan data profil pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - Map<String, dynamic>: Data profil pengguna
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response =
          await _client
              .from('user_profiles')
              .select('*')
              .eq('user_id', userId)
              .maybeSingle();

      if (response == null) {
        debugPrint('No profile found for user: $userId');
        return {};
      }

      debugPrint('Profile found for user: $userId');
      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return {};
    }
  }

  /// Membuat profil default untuk pengguna baru.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  /// - [email]: Email pengguna
  /// - [defaultName]: Nama default untuk profil
  ///
  /// Proses:
  /// 1. Mengecek profil yang sudah ada
  /// 2. Membuat profil baru jika belum ada
  /// 3. Memperbarui username jika berbeda
  static Future<void> createDefaultProfile(
    String userId,
    String email,
    String defaultName,
  ) async {
    try {
      debugPrint('=== CREATE PROFILE DEBUG ===');
      debugPrint('Target User ID: $userId');
      debugPrint('Email: $email');
      debugPrint(
        'Username parameter: $defaultName',
      ); // ✅ This should be "Liaan"

      // Wait for auth to settle
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check current user
      final currentUser = getCurrentUser();
      debugPrint('Current authenticated user: ${currentUser?.id}');
      debugPrint('Current user metadata: ${currentUser?.userMetadata}');

      if (currentUser == null) {
        debugPrint('ERROR: No authenticated user found');
        throw Exception('No authenticated user found');
      }

      // ✅ Use the passed defaultName parameter, not email!
      final profileUsername = defaultName; // This should be "Liaan"
      debugPrint('Profile username to save: $profileUsername');

      // Check if profile already exists
      final existingProfile =
          await _client
              .from('user_profiles')
              .select('*')
              .eq('user_id', userId)
              .maybeSingle();

      if (existingProfile == null) {
        debugPrint('Creating new profile with username: $profileUsername');

        // Create new profile with the correct username
        await _client.from('user_profiles').insert({
          'user_id': userId,
          'username': profileUsername, // ✅ Use passed parameter, not email
          'profile_image_url': null,
          'bio': null,
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Profile created successfully: $profileUsername');
      } else {
        debugPrint('Profile already exists: ${existingProfile['username']}');

        // If username is different, update it
        if (existingProfile['username'] != profileUsername) {
          await _client
              .from('user_profiles')
              .update({'username': profileUsername})
              .eq('user_id', userId);
          debugPrint('✅ Profile username updated to: $profileUsername');
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating profile: $e');
      // Don't throw error to prevent blocking the flow
    }
  }

  /// Memperbarui profil pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  /// - [updates]: Data yang akan diperbarui
  ///
  /// Proses:
  /// 1. Memperbarui data profil di database
  /// 2. Menangani error jika terjadi kesalahan
  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Don't add updated_at if the column doesn't exist
      final updateData = Map<String, dynamic>.from(updates);

      // Only add updated_at if you're sure the column exists
      // updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('user_profiles')
          .update(updateData)
          .eq('user_id', userId);

      debugPrint('User profile updated successfully for user: $userId');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Mendapatkan semua resep dengan informasi pembuat.
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep dengan informasi pembuat
  ///
  /// Proses:
  /// 1. Membuat query untuk mendapatkan resep publik
  /// 2. Menggabungkan dengan data profil pembuat
  /// 3. Mengurutkan berdasarkan waktu pembuatan
  static Future<List<Map<String, dynamic>>> getAllRecipesWithUserInfo() async {
    try {
      final response = await _client
          .from('recipes')
          .select('''
          *,
          user_profiles!inner (
            username,
            profile_image_url
          )
        ''')
          .eq('is_public', true)
          .order('created_at', ascending: false);

      debugPrint('Loaded ${response.length} recipes with user info');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting recipes with user info: $e');
      return [];
    }
  }

  /// Membuat resep baru dengan validasi profil.
  ///
  /// Parameter:
  /// - [recipeData]: Data resep yang akan dibuat
  ///
  /// Returns:
  /// - String?: ID resep yang berhasil dibuat
  ///
  /// Proses:
  /// 1. Memvalidasi user yang sedang login
  /// 2. Memastikan profil user ada
  /// 3. Menyimpan resep ke database
  static Future<String?> createRecipe(Map<String, dynamic> recipeData) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await ensureUserProfile(user.id, user.email);

      // ✅ Only include columns that exist in your schema
      final recipeWithUser = {
        'title': recipeData['title'],
        'description': recipeData['description'],
        'image_url': recipeData['image_url'],
        'ingredients': recipeData['ingredients'],
        'steps': recipeData['steps'],
        'cooking_time': recipeData['cooking_time'],
        'is_public': recipeData['is_public'] ?? true,
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client
              .from('recipes')
              .insert(recipeWithUser)
              .select('id')
              .single();

      debugPrint('Recipe created successfully with ID: ${response['id']}');
      return response['id']?.toString();
    } catch (e) {
      debugPrint('Error creating recipe: $e');
      rethrow;
    }
  }

  /// Memastikan user memiliki profil.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  /// - [email]: Email pengguna
  ///
  /// Proses:
  /// 1. Mengecek profil yang sudah ada
  /// 2. Membuat profil baru jika belum ada
  static Future<void> ensureUserProfile(String userId, String? email) async {
    try {
      final existingProfile =
          await _client
              .from('user_profiles')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (existingProfile == null) {
        final defaultName = email?.split('@')[0] ?? 'User';

        // ✅ Only include columns that exist in user_profiles table
        await _client.from('user_profiles').insert({
          'user_id': userId,
          'username': defaultName,
          'profile_image_url': null,
          'bio': null,
          'created_at': DateTime.now().toIso8601String(),
          // Only add updated_at if the column exists in user_profiles table
        });

        debugPrint('Profile created for user: $userId');
      }
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
      rethrow;
    }
  }

  /// Upload gambar profil dengan beberapa metode fallback.
  ///
  /// Parameter:
  /// - [path]: Path file gambar
  /// - [file]: File gambar yang akan diupload
  ///
  /// Returns:
  /// - String: URL gambar yang berhasil diupload
  ///
  /// Proses:
  /// 1. Mencoba upload dengan metode sederhana
  /// 2. Mencoba upload dengan metode file
  /// 3. Mencoba upload dengan path alternatif
  /// 4. Mengembalikan placeholder jika semua metode gagal
  static Future<String> uploadProfileImage(String path, File file) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      // Method 1: Try simple upload first
      try {
        return await _uploadWithSimpleMethod(file, user.id);
      } catch (e) {
        debugPrint('Simple upload failed: $e');
      }

      // Method 2: Try upload with file method
      try {
        return await _uploadWithFileMethod(file, user.id);
      } catch (e) {
        debugPrint('File upload failed: $e');
      }

      // Method 3: Try upload with different path
      try {
        return await _uploadWithAlternatePath(file, user.id);
      } catch (e) {
        debugPrint('Alternate path upload failed: $e');
      }

      // If all methods fail, use placeholder
      throw Exception('All upload methods failed');
    } catch (e) {
      debugPrint('Upload completely failed: $e');
      // Return placeholder image as fallback
      return _generatePlaceholderImage();
    }
  }

  /// Method 1: Simple binary upload
  static Future<String> _uploadWithSimpleMethod(
    File file,
    String userId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = file.path.split('.').last.toLowerCase();
    final path = 'user_$userId/profile_$timestamp.$extension';

    final bytes = await file.readAsBytes();

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from(bucketName).getPublicUrl(path);
  }

  /// Method 2: Upload with File object
  static Future<String> _uploadWithFileMethod(File file, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = file.path.split('.').last.toLowerCase();
    final path = 'profiles/$userId\_$timestamp.$extension';

    await _client.storage
        .from(bucketName)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    return _client.storage.from(bucketName).getPublicUrl(path);
  }

  /// Method 3: Upload with alternate path structure
  static Future<String> _uploadWithAlternatePath(
    File file,
    String userId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId-profile-$timestamp.jpg';

    final bytes = await file.readAsBytes();

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return _client.storage.from(bucketName).getPublicUrl(path);
  }

  /// Generate placeholder image URL
  static String _generatePlaceholderImage() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'https://picsum.photos/seed/recipe$timestamp/400/300';
  }

  /// Menyimpan resep ke daftar favorit.
  ///
  /// Parameter:
  /// - [recipeId]: ID resep yang akan disimpan
  ///
  /// Returns:
  /// - bool: true jika berhasil disimpan, false jika sudah ada
  ///
  /// Proses:
  /// 1. Memvalidasi user yang sedang login
  /// 2. Mengecek apakah resep sudah disimpan
  /// 3. Menyimpan resep jika belum ada
  static Future<bool> saveRecipe(String recipeId) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if already saved
      final existing =
          await _client
              .from('saved_recipes')
              .select('id')
              .eq('user_id', user.id)
              .eq('recipe_id', recipeId)
              .maybeSingle();

      if (existing != null) {
        debugPrint('Recipe already saved');
        return false; // ✅ Return false if already saved
      }

      // Save the recipe
      await _client.from('saved_recipes').insert({
        'user_id': user.id,
        'recipe_id': recipeId,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Recipe saved successfully: $recipeId');
      return true; // ✅ Return true for successful save
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      return false;
    }
  }

  /// Upload gambar profil dengan struktur folder yang benar untuk RLS.
  ///
  /// Parameter:
  /// - [imageFile]: File gambar yang akan diupload
  ///
  /// Returns:
  /// - String: URL gambar yang berhasil diupload
  ///
  /// Proses:
  /// 1. Memvalidasi file dan user
  /// 2. Membuat path file dengan struktur folder yang benar
  /// 3. Upload file dengan opsi yang sesuai
  static Future<String> uploadProfileImageSimple(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('=== UPLOAD DEBUG INFO ===');
      debugPrint('User ID: ${user.id}');
      debugPrint('File exists: ${imageFile.existsSync()}');
      debugPrint('File size: ${await imageFile.length()} bytes');

      // Generate filename with user ID as folder (required by RLS policy)
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${user.id}/$fileName';

      debugPrint('Upload path: $filePath');

      // Upload with proper options
      await _client.storage
          .from(bucketName)
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Get public URL
      final publicUrl = _client.storage.from(bucketName).getPublicUrl(filePath);

      debugPrint('Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return '';
    }
  }

  /// Simple upload without folder structure
  static Future<String> uploadProfileImageAlternative(File imageFile) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      // Simple filename with user ID prefix
      final fileName =
          'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('Alternative upload with filename: $fileName');

      await _client.storage
          .from(bucketName)
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _client.storage.from(bucketName).getPublicUrl(fileName);
      debugPrint('Alternative upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Alternative upload failed: $e');
      return '';
    }
  }

  /// Memperbarui resep di database.
  ///
  /// Parameter:
  /// - [recipeId]: ID resep yang akan diperbarui
  /// - [title]: Judul baru
  /// - [description]: Deskripsi baru
  /// - [imageUrl]: URL gambar baru
  /// - [ingredients]: Daftar bahan-bahan baru
  /// - [steps]: Daftar langkah-langkah baru
  /// - [cookingTime]: Waktu memasak baru
  /// - [isPublic]: Status publikasi baru
  ///
  /// Proses:
  /// 1. Memvalidasi user yang sedang login
  /// 2. Memverifikasi kepemilikan resep
  /// 3. Memperbarui data resep
  static Future<void> updateRecipe({
    required String recipeId,
    required String title,
    required String description,
    required String imageUrl,
    required List<String> ingredients,
    required List<String> steps,
    required int cookingTime,
    bool? isPublic,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Verify user owns this recipe
      final existingRecipe = await getRecipeById(recipeId);
      if (existingRecipe['user_id'] != user.id) {
        throw Exception('User not authorized to update this recipe');
      }

      // ✅ Only update columns that exist in your schema
      final updateData = {
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'ingredients': ingredients,
        'steps': steps,
        'cooking_time': cookingTime,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add is_public if provided
      if (isPublic != null) {
        updateData['is_public'] = isPublic;
      }

      await _client.from('recipes').update(updateData).eq('id', recipeId);

      debugPrint('Recipe updated successfully: $recipeId');
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      rethrow;
    }
  }

  /// Upload gambar resep ke Supabase Storage.
  ///
  /// Parameter:
  /// - [imageFile]: File gambar yang akan diupload
  ///
  /// Returns:
  /// - String: URL gambar yang berhasil diupload
  ///
  /// Proses:
  /// 1. Memvalidasi file dan user
  /// 2. Upload file ke bucket yang sesuai
  /// 3. Mengembalikan URL publik
  static Future<String> uploadRecipeImage(File imageFile) async {
    try {
      final user = getCurrentUser();
      if (user == null || !imageFile.existsSync()) {
        return _generatePlaceholderImage();
      }

      // Use existing profile-images bucket for recipe images
      final fileName =
          'recipes/recipe_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('Uploading recipe image: $fileName');

      await _client.storage
          .from(bucketName) // Use existing profile-images bucket
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _client.storage.from(bucketName).getPublicUrl(fileName);

      debugPrint('Recipe image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Recipe upload failed: $e');
      return _generatePlaceholderImage();
    }
  }

  /// Metode fallback untuk upload gambar resep.
  ///
  /// Parameter:
  /// - [imageFile]: File gambar yang akan diupload
  ///
  /// Returns:
  /// - String: URL gambar yang berhasil diupload
  static Future<String> uploadRecipeImageFallback(File imageFile) async {
    try {
      final user = getCurrentUser();
      if (user == null || !imageFile.existsSync()) {
        return _generatePlaceholderImage();
      }

      // Try using a different path structure as fallback
      final fileName =
          'fallback_recipes/recipe_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('Fallback recipe image upload: $fileName');

      await _client.storage
          .from(bucketName)
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _client.storage.from(bucketName).getPublicUrl(fileName);

      debugPrint('Fallback recipe upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Fallback recipe upload failed: $e');
      return _generatePlaceholderImage();
    }
  }

  /// Mencari resep berdasarkan judul atau deskripsi.
  ///
  /// Parameter:
  /// - [query]: Kata kunci pencarian
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep yang ditemukan
  ///
  /// Proses:
  /// 1. Membuat query pencarian
  /// 2. Memfilter resep publik
  /// 3. Mengurutkan berdasarkan waktu pembuatan
  static Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    try {
      final response = await _client
          .from('recipes')
          .select('*')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .eq('is_public', true)
          .order('created_at', ascending: false);

      debugPrint('Found ${response.length} local recipes for query: $query');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      return [];
    }
  }

  /// Mendapatkan resep publik.
  ///
  /// Parameter:
  /// - [limit]: Jumlah maksimum resep yang akan diambil
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep publik
  ///
  /// Proses:
  /// 1. Membuat query untuk mendapatkan resep publik
  /// 2. Membatasi jumlah hasil
  /// 3. Mengurutkan berdasarkan waktu pembuatan
  static Future<List<Map<String, dynamic>>> getPublicRecipes({
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('recipes')
          .select('*')
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Loaded ${response.length} public recipes');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading public recipes: $e');
      return [];
    }
  }

  /// Menyimpan resep dari sumber eksternal.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  /// - [externalRecipeData]: Data resep dari sumber eksternal
  ///
  /// Returns:
  /// - bool: true jika berhasil disimpan, false jika sudah ada
  ///
  /// Proses:
  /// 1. Mengecek apakah resep sudah disimpan
  /// 2. Menambahkan timestamp dan flag eksternal
  /// 3. Menyimpan data resep
  static Future<bool> saveExternalRecipe({
    required String userId,
    required Map<String, dynamic> externalRecipeData,
  }) async {
    try {
      // Check if already saved
      final existing =
          await _client
              .from('saved_external_recipes')
              .select('id')
              .eq('user_id', userId)
              .eq(
                'external_recipe_id',
                externalRecipeData['id']?.toString() ?? '',
              )
              .maybeSingle();

      if (existing != null) {
        debugPrint('External recipe already saved');
        return false;
      }

      // ✅ Add saved_at timestamp to the recipe data
      final recipeDataWithTimestamp = Map<String, dynamic>.from(
        externalRecipeData,
      );
      recipeDataWithTimestamp['saved_at'] = DateTime.now().toIso8601String();
      recipeDataWithTimestamp['is_external'] = true; // Mark as external

      // Save external recipe data
      await _client.from('saved_external_recipes').insert({
        'user_id': userId,
        'external_recipe_id': externalRecipeData['id']?.toString() ?? '',
        'recipe_data': recipeDataWithTimestamp,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('External recipe saved successfully');
      return true;
    } catch (e) {
      debugPrint('Error saving external recipe: $e');
      return false;
    }
  }

  /// Mendapatkan resep eksternal yang disimpan oleh pengguna.
  ///
  /// Parameter:
  /// - [userId]: ID pengguna
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep eksternal yang disimpan
  ///
  /// Proses:
  /// 1. Mendapatkan data resep yang disimpan
  /// 2. Menambahkan timestamp penyimpanan
  /// 3. Mengurutkan berdasarkan waktu penyimpanan
  static Future<List<Map<String, dynamic>>> getUserSavedExternalRecipes(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('saved_external_recipes')
          .select('recipe_data, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> savedRecipes = [];
      for (var item in response) {
        if (item['recipe_data'] != null) {
          final recipeData = Map<String, dynamic>.from(item['recipe_data']);
          // Use the created_at from saved_external_recipes as saved_at
          recipeData['saved_at'] = item['created_at'];
          savedRecipes.add(recipeData);
        }
      }

      debugPrint('✅ Loaded ${savedRecipes.length} saved external recipes');
      return savedRecipes;
    } catch (e) {
      debugPrint('❌ Error getting saved external recipes: $e');
      return [];
    }
  }
}
