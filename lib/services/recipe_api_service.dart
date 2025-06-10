/// `RecipeApiService` adalah kelas utilitas untuk berinteraksi dengan TheMealDB API.
/// Kelas ini menyediakan metode untuk mencari, mendapatkan resep acak, dan
/// mendapatkan resep berdasarkan kategori.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Kelas untuk mengelola interaksi dengan TheMealDB API.
///
/// Fitur-fitur yang tersedia:
/// - Pencarian resep berdasarkan nama
/// - Mendapatkan resep acak
/// - Mendapatkan resep berdasarkan kategori
/// - Mendapatkan daftar kategori yang tersedia
/// - Konversi format data dari API ke format aplikasi
class RecipeApiService {
  /// URL dasar untuk TheMealDB API
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Mencari resep berdasarkan nama.
  ///
  /// Parameter:
  /// - [query]: Kata kunci pencarian
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep yang ditemukan
  ///
  /// Proses:
  /// 1. Melakukan request ke API dengan query
  /// 2. Mengkonversi response ke format yang sesuai
  /// 3. Menangani error jika terjadi kesalahan
  static Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    try {
      debugPrint('🔍 Searching recipes for: $query');

      final response = await http.get(
        Uri.parse('$_baseUrl/search.php?s=$query'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'] as List?;

        if (meals != null) {
          final recipes =
              meals.map((meal) => _convertMealToRecipe(meal)).toList();
          debugPrint('✅ Found ${recipes.length} recipes');
          return recipes;
        }
      }

      debugPrint('⚠️ No recipes found for: $query');
      return [];
    } catch (e) {
      debugPrint('❌ Error searching recipes: $e');
      return [];
    }
  }

  /// Mendapatkan sejumlah resep acak dari API.
  ///
  /// Parameter:
  /// - [count]: Jumlah resep yang ingin didapatkan (default: 10)
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep acak
  ///
  /// Proses:
  /// 1. Melakukan request berulang ke API untuk mendapatkan resep acak
  /// 2. Menambahkan delay kecil untuk menghindari rate limiting
  /// 3. Mengkonversi response ke format yang sesuai
  static Future<List<Map<String, dynamic>>> getRandomRecipes({
    int count = 10,
  }) async {
    try {
      debugPrint('🎲 Getting $count random recipes');

      List<Map<String, dynamic>> recipes = [];

      for (int i = 0; i < count; i++) {
        final response = await http.get(
          Uri.parse('$_baseUrl/random.php'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final meals = data['meals'] as List?;

          if (meals != null && meals.isNotEmpty) {
            recipes.add(_convertMealToRecipe(meals[0]));
          }
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('✅ Got ${recipes.length} random recipes');
      return recipes;
    } catch (e) {
      debugPrint('❌ Error getting random recipes: $e');
      return [];
    }
  }

  /// Mendapatkan resep berdasarkan kategori.
  ///
  /// Parameter:
  /// - [category]: Kategori resep yang ingin dicari
  ///
  /// Returns:
  /// - List<Map<String, dynamic>>: Daftar resep dalam kategori tersebut
  ///
  /// Proses:
  /// 1. Mendapatkan daftar resep berdasarkan kategori
  /// 2. Mendapatkan detail untuk setiap resep
  /// 3. Membatasi jumlah resep yang diambil (20)
  /// 4. Mengkonversi response ke format yang sesuai
  static Future<List<Map<String, dynamic>>> getRecipesByCategory(
    String category,
  ) async {
    try {
      debugPrint('📂 Getting recipes for category: $category');

      final response = await http.get(
        Uri.parse('$_baseUrl/filter.php?c=$category'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'] as List?;

        if (meals != null) {
          // Get detailed info for each recipe
          List<Map<String, dynamic>> recipes = [];

          for (var meal in meals.take(20)) {
            // Limit to 20 recipes
            final detailResponse = await http.get(
              Uri.parse('$_baseUrl/lookup.php?i=${meal['idMeal']}'),
            );

            if (detailResponse.statusCode == 200) {
              final detailData = json.decode(detailResponse.body);
              final detailMeals = detailData['meals'] as List?;

              if (detailMeals != null && detailMeals.isNotEmpty) {
                recipes.add(_convertMealToRecipe(detailMeals[0]));
              }
            }

            // Small delay
            await Future.delayed(const Duration(milliseconds: 100));
          }

          debugPrint('✅ Got ${recipes.length} recipes for category: $category');
          return recipes;
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error getting recipes by category: $e');
      return [];
    }
  }

  /// Mendapatkan daftar kategori yang tersedia.
  ///
  /// Returns:
  /// - List<String>: Daftar nama kategori
  ///
  /// Proses:
  /// 1. Melakukan request ke API untuk mendapatkan daftar kategori
  /// 2. Mengekstrak nama kategori dari response
  /// 3. Menangani error jika terjadi kesalahan
  static Future<List<String>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/categories.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final categories = data['categories'] as List?;

        if (categories != null) {
          return categories.map((cat) => cat['strCategory'] as String).toList();
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error getting categories: $e');
      return [];
    }
  }

  /// Mengkonversi format data dari TheMealDB ke format aplikasi.
  ///
  /// Parameter:
  /// - [meal]: Data resep dari TheMealDB API
  ///
  /// Returns:
  /// - Map<String, dynamic>: Data resep dalam format aplikasi
  ///
  /// Proses:
  /// 1. Mengekstrak bahan-bahan dari data API
  /// 2. Mengekstrak langkah-langkah dari instruksi
  /// 3. Menambahkan informasi tambahan seperti ID, kategori, dll
  static Map<String, dynamic> _convertMealToRecipe(Map<String, dynamic> meal) {
    // Extract ingredients
    List<String> ingredients = [];
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i']?.toString().trim();
      final measure = meal['strMeasure$i']?.toString().trim();

      if (ingredient != null && ingredient.isNotEmpty && ingredient != 'null') {
        final fullIngredient =
            measure != null && measure.isNotEmpty && measure != 'null'
                ? '$measure $ingredient'
                : ingredient;
        ingredients.add(fullIngredient);
      }
    }

    // Extract steps from instructions
    List<String> steps = [];
    final instructions = meal['strInstructions']?.toString();
    if (instructions != null && instructions.isNotEmpty) {
      // Split by common step indicators
      final splitInstructions =
          instructions
              .split(RegExp(r'\d+\.|\n\n|\r\n\r\n'))
              .where((step) => step.trim().isNotEmpty)
              .map((step) => step.trim())
              .toList();

      if (splitInstructions.length > 1) {
        steps = splitInstructions;
      } else {
        // If no clear steps, split by sentences
        steps =
            instructions
                .split('.')
                .where(
                  (step) => step.trim().isNotEmpty && step.trim().length > 10,
                )
                .map((step) => '${step.trim()}.')
                .toList();
      }
    }

    return {
      'id': 'api_${meal['idMeal']}', // Prefix to distinguish from local recipes
      'title': meal['strMeal'] ?? 'Unknown Recipe',
      'description':
          meal['strInstructions']?.toString().substring(
            0,
            meal['strInstructions'].toString().length > 100
                ? 100
                : meal['strInstructions'].toString().length,
          ) ??
          'Delicious recipe from TheMealDB',
      'image_url': meal['strMealThumb'] ?? '',
      'ingredients': ingredients,
      'steps':
          steps.isNotEmpty
              ? steps
              : ['Follow the instructions in the description'],
      'cooking_time': 30, // Default since API doesn't provide this
      'category': meal['strCategory'] ?? 'General',
      'area': meal['strArea'] ?? 'International',
      'source': 'TheMealDB',
      'external_id': meal['idMeal'],
      'youtube_url': meal['strYoutube'],
      'source_url': meal['strSource'],
      'is_external': true, // Flag to identify API recipes
    };
  }
}
