/// `main.dart` adalah file utama aplikasi Cook Book.
/// File ini berisi inisialisasi aplikasi, konfigurasi tema,
/// dan definisi rute-rute navigasi.
import 'package:flutter/material.dart';
import 'package:cook_book_app/services/supabase_service.dart';
import 'package:cook_book_app/screens/login_screen.dart';
import 'package:cook_book_app/screens/register_screen.dart';
import 'package:cook_book_app/screens/home_screen.dart';
import 'package:cook_book_app/screens/profile_screen.dart';
import 'package:cook_book_app/screens/recipes_screen.dart';
import 'package:cook_book_app/screens/recipe_details_screen.dart';
import 'package:cook_book_app/screens/create_recipe_screen.dart';
import 'package:cook_book_app/screens/edit_recipe_screen.dart';
import 'screens/search_screen.dart';
import 'screens/external_recipe_details_screen.dart';

/// Fungsi utama yang dijalankan saat aplikasi dimulai.
///
/// Proses yang dilakukan:
/// 1. Menginisialisasi Flutter bindings
/// 2. Menginisialisasi koneksi Supabase
/// 3. Menjalankan aplikasi
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initializeSupabase();

  runApp(const MyApp());
}

/// Widget utama aplikasi yang mendefinisikan tema dan rute.
///
/// Fitur-fitur yang tersedia:
/// - Konfigurasi tema aplikasi
/// - Definisi rute-rute navigasi
/// - Penanganan argumen rute
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cook Book App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF824E50)),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/search': (context) => const SearchScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/create-recipe': (context) => const CreateRecipeScreen(),
        '/recipe-details': (context) => const RecipeDetailsScreen(),
        '/external-recipe-details':
            (context) => const ExternalRecipeDetailsScreen(),
        '/edit-recipe': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return EditRecipeScreen(recipeId: args ?? '');
        },
        '/recipes': (context) => const RecipesScreen(),
      },
    );
  }
}
