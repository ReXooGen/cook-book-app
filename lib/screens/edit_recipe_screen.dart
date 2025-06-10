/// `EditRecipeScreen` adalah layar untuk mengedit resep yang sudah ada.
/// Layar ini memungkinkan pengguna untuk mengubah detail resep seperti
/// judul, deskripsi, bahan-bahan, langkah-langkah, dan gambar.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';

/// Widget untuk mengedit resep yang sudah ada.
///
/// Widget ini menampilkan form untuk mengedit detail resep seperti:
/// - Judul resep
/// - Deskripsi resep
/// - Daftar bahan-bahan
/// - Langkah-langkah memasak
/// - Gambar resep
///
/// Pengguna dapat menambah, menghapus, atau mengubah semua detail resep
/// dan menyimpan perubahan ke database.
class EditRecipeScreen extends StatefulWidget {
  /// ID resep yang akan diedit
  final String recipeId;

  const EditRecipeScreen({super.key, required this.recipeId});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  /// Form key untuk validasi form
  final _formKey = GlobalKey<FormState>();

  /// Controller untuk field judul resep
  final TextEditingController _titleController = TextEditingController();

  /// Controller untuk field deskripsi resep
  final TextEditingController _descriptionController = TextEditingController();

  /// Daftar controller untuk field bahan-bahan
  List<TextEditingController> _ingredientControllers = [];

  /// Daftar controller untuk field langkah-langkah
  List<TextEditingController> _instructionControllers = [];

  /// File gambar yang dipilih pengguna
  File? _imageFile;

  /// URL gambar resep saat ini
  String? _currentImageUrl;

  /// Status loading saat menyimpan perubahan
  bool _isLoading = false;

  /// Status loading saat memuat data resep
  bool _isLoadingData = true;

  /// Data resep yang akan diedit
  Map<String, dynamic>? _recipeData;

  /// Instance ImagePicker untuk memilih gambar
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadRecipeData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _ingredientControllers) {
      controller.dispose();
    }
    for (var controller in _instructionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Memuat data resep dari database berdasarkan ID
  ///
  /// Method ini akan:
  /// 1. Mengambil data resep dari database
  /// 2. Mengisi form dengan data yang ada
  /// 3. Menangani error jika terjadi masalah saat memuat data
  Future<void> _loadRecipeData() async {
    try {
      debugPrint('Loading recipe data for ID: ${widget.recipeId}');

      final recipeData = await SupabaseService.getRecipeById(widget.recipeId);

      if (mounted) {
        setState(() {
          _recipeData = recipeData;
          _currentImageUrl = recipeData['image_url'];

          // Fill form fields
          _titleController.text = recipeData['title'] ?? '';
          _descriptionController.text = recipeData['description'] ?? '';

          // Load ingredients
          final ingredients = List<String>.from(
            recipeData['ingredients'] ?? [],
          );
          _ingredientControllers =
              ingredients.map((ingredient) {
                final controller = TextEditingController();
                controller.text = ingredient;
                return controller;
              }).toList();

          // Ensure at least one ingredient controller
          if (_ingredientControllers.isEmpty) {
            _ingredientControllers.add(TextEditingController());
          }

          // Load steps/instructions
          final steps = List<String>.from(recipeData['steps'] ?? []);
          _instructionControllers =
              steps.map((step) {
                final controller = TextEditingController();
                controller.text = step;
                return controller;
              }).toList();

          // Ensure at least one instruction controller
          if (_instructionControllers.isEmpty) {
            _instructionControllers.add(TextEditingController());
          }

          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipe data: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load recipe data')),
        );
        Navigator.pop(context);
      }
    }
  }

  /// Menampilkan bottom sheet untuk memilih sumber gambar
  ///
  /// Pengguna dapat memilih untuk mengambil gambar dari:
  /// - Galeri
  /// - Kamera
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF2E6E7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Update Photo',
                    style: TextStyle(
                      color: Color(0xFF584D4D),
                      fontSize: 18,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImagePickerOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            setState(() {
                              _imageFile = File(image.path);
                            });
                          }
                        },
                      ),
                      _buildImagePickerOption(
                        icon: Icons.photo_camera,
                        label: 'Camera',
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.camera,
                          );
                          if (image != null) {
                            setState(() {
                              _imageFile = File(image.path);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Membangun widget untuk opsi pemilihan gambar
  ///
  /// [icon] - Icon yang ditampilkan
  /// [label] - Label untuk opsi
  /// [onTap] - Callback ketika opsi dipilih
  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
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
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menambahkan field bahan baru ke form
  void _addIngredient() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  /// Menghapus field bahan dari form
  ///
  /// [index] - Index field bahan yang akan dihapus
  void _removeIngredient(int index) {
    if (_ingredientControllers.length > 1) {
      setState(() {
        _ingredientControllers[index].dispose();
        _ingredientControllers.removeAt(index);
      });
    }
  }

  /// Menambahkan field instruksi baru ke form
  void _addInstruction() {
    setState(() {
      _instructionControllers.add(TextEditingController());
    });
  }

  /// Menghapus field instruksi dari form
  ///
  /// [index] - Index field instruksi yang akan dihapus
  void _removeInstruction(int index) {
    if (_instructionControllers.length > 1) {
      setState(() {
        _instructionControllers[index].dispose();
        _instructionControllers.removeAt(index);
      });
    }
  }

  /// Menyimpan perubahan resep ke database
  ///
  /// Method ini akan:
  /// 1. Memvalidasi form
  /// 2. Mengupload gambar baru jika ada
  /// 3. Menyimpan perubahan ke database
  /// 4. Menampilkan feedback ke pengguna
  Future<void> _updateRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Filter bahan yang tidak kosong
    final filteredIngredients =
        _ingredientControllers
            .map((controller) => controller.text.trim())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();

    // Filter instruksi yang tidak kosong
    final filteredInstructions =
        _instructionControllers
            .map((controller) => controller.text.trim())
            .where((instruction) => instruction.isNotEmpty)
            .toList();

    if (filteredIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    if (filteredInstructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one instruction')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String imageUrl =
          _currentImageUrl ??
          'https://picsum.photos/seed/recipe${DateTime.now().millisecondsSinceEpoch}/400/300';

      // Upload new image if selected
      if (_imageFile != null) {
        try {
          debugPrint('Uploading new recipe image...');
          imageUrl = await SupabaseService.uploadRecipeImage(_imageFile!);

          if (imageUrl.contains('picsum.photos')) {
            debugPrint('Image upload failed, keeping current image');
            imageUrl =
                _currentImageUrl ??
                'https://picsum.photos/seed/recipe${DateTime.now().millisecondsSinceEpoch}/400/300';
          }
        } catch (e) {
          debugPrint('Error uploading image: $e');
          imageUrl =
              _currentImageUrl ??
              'https://picsum.photos/seed/recipe${DateTime.now().millisecondsSinceEpoch}/400/300';
        }
      }

      debugPrint('=== UPDATING RECIPE ===');
      debugPrint('Recipe ID: ${widget.recipeId}');
      debugPrint('Final image URL: $imageUrl');

      // Update recipe in database
      await SupabaseService.updateRecipe(
        recipeId: widget.recipeId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        ingredients: filteredIngredients,
        steps: filteredInstructions,
        cookingTime: _recipeData?['cooking_time'] ?? 30,
      );

      debugPrint('Recipe updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe updated successfully!'),
            backgroundColor: Color(0xFF824E50),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCF8F8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF824E50)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header dengan tombol back dan judul
              Container(
                width: double.infinity,
                height: 45,
                margin: const EdgeInsets.only(top: 50, left: 2),
                decoration: const BoxDecoration(color: Color(0xFFFCF8F8)),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 143,
                      top: 14,
                      child: Text(
                        'Edit Recipe',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Recipe Title Field
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 58,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 5,
                            top: 5,
                            child: Container(
                              width: 358,
                              height: 49,
                              decoration: ShapeDecoration(
                                color: const Color(0xFFF3E7E8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 5,
                            top: 5,
                            child: Container(
                              width: 358,
                              height: 49,
                              child: TextFormField(
                                controller: _titleController,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.50,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  hintText: 'Recipe Title',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFB88285),
                                    fontSize: 16.50,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter recipe title';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Description Field
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 157,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 3,
                            top: 3,
                            child: Container(
                              width: 361,
                              height: 151,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3E7E8),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 21,
                            top: 24,
                            child: Text(
                              'Description',
                              style: TextStyle(
                                color: Color(0xFFB78184),
                                fontSize: 15.90,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 21,
                            top: 50,
                            child: Container(
                              width: 340,
                              height: 100,
                              child: TextFormField(
                                controller: _descriptionController,
                                maxLines: 4,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter recipe description...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFB78184),
                                    fontSize: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter description';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Ingredients Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 0),
                      child: Text(
                        'Ingredients',
                        style: TextStyle(
                          color: Color(0xFF685F5F),
                          fontSize: 16.60,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Ingredients List
                    ..._ingredientControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      TextEditingController controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            // Checkbox placeholder
                            Container(
                              width: 22,
                              height: 21,
                              decoration: ShapeDecoration(
                                color: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  side: const BorderSide(
                                    width: 1,
                                    color: Color(0xFFC5BABB),
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            // TextField untuk ingredient
                            Expanded(
                              child: TextFormField(
                                controller: controller,
                                style: const TextStyle(
                                  color: Color(0xFF847C7C),
                                  fontSize: 16.20,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'e.g., 1 lb pasta',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFFB88285),
                                    fontSize: 16.20,
                                  ),
                                  suffixIcon:
                                      _ingredientControllers.length > 1
                                          ? IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed:
                                                () => _removeIngredient(index),
                                          )
                                          : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    // Tombol Tambah Bahan
                    GestureDetector(
                      onTap: _addIngredient,
                      child: Container(
                        width: 358,
                        height: 49,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF3E7E8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Tambah Bahan',
                            style: TextStyle(
                              color: Color(0xFF685F5F),
                              fontSize: 16.60,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Instructions Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructions',
                      style: TextStyle(
                        color: Color(0xFF665D5D),
                        fontSize: 15.90,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Instructions List
                    ..._instructionControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      TextEditingController controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step number
                            Container(
                              width: 25,
                              height: 25,
                              margin: const EdgeInsets.only(top: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF824E50),
                                shape: BoxShape.circle,
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
                            const SizedBox(width: 11),
                            // TextField untuk instruction
                            Expanded(
                              child: Container(
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF3E7E8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: controller,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    color: Color(0xFF847C7C),
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(12),
                                    hintText:
                                        'Enter step ${index + 1} instructions...',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFFB88285),
                                      fontSize: 14,
                                    ),
                                    suffixIcon:
                                        _instructionControllers.length > 1
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _removeInstruction(index),
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    // Tombol Tambah Instruksi
                    GestureDetector(
                      onTap: _addInstruction,
                      child: Container(
                        width: 358,
                        height: 49,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF3E7E8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Tambah Instruksi',
                            style: TextStyle(
                              color: Color(0xFF685F5F),
                              fontSize: 16.60,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Update Photo Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 23),
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 367,
                    height: 50,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 5,
                          child: Container(
                            width: 358,
                            height: 40,
                            decoration: ShapeDecoration(
                              color: const Color(0xFFF2E6E7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 130,
                          top: 15,
                          child: Text(
                            _imageFile != null
                                ? 'New Photo Selected'
                                : 'Update Photo',
                            style: const TextStyle(
                              color: Color(0xFF584D4D),
                              fontSize: 14.90,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (_imageFile != null)
                          Positioned(
                            right: 16,
                            top: 10,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        else if (_currentImageUrl != null &&
                            _currentImageUrl!.isNotEmpty)
                          Positioned(
                            right: 16,
                            top: 10,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: NetworkImage(_currentImageUrl!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Update Recipe Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                child: GestureDetector(
                  onTap: _isLoading ? null : _updateRecipe,
                  child: Container(
                    width: 366,
                    height: 56,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 4,
                          top: 5,
                          child: Container(
                            width: 358,
                            height: 48,
                            decoration: ShapeDecoration(
                              color:
                                  _isLoading
                                      ? const Color(0xFFE92932).withOpacity(0.6)
                                      : const Color(0xFFE92932),
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(
                                  width: 1,
                                  color: Color(0xFFEA3B44),
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 132,
                          top: 17,
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 103,
                                    height: 21,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFF6BDBF),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                  : const SizedBox(
                                    width: 103,
                                    height: 21,
                                    child: Text(
                                      'Update Recipe',
                                      style: TextStyle(
                                        color: Color(0xFFF6BDBF),
                                        fontSize: 16.90,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
