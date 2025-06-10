import 'package:flutter/material.dart';

/// Widget untuk menampilkan gambar resep dengan penanganan berbagai kasus.
///
/// Widget ini menangani:
/// - Loading gambar dari URL
/// - Placeholder saat gambar sedang dimuat
/// - Placeholder saat gambar gagal dimuat
/// - Validasi URL gambar
/// - Penerapan border radius
///
/// Fitur:
/// - Mendukung berbagai ukuran gambar
/// - Custom border radius
/// - Custom BoxFit
/// - Loading indicator
/// - Placeholder gradient
class RecipeImage extends StatelessWidget {
  /// URL gambar resep yang akan ditampilkan
  final String? imageUrl;

  /// Lebar widget gambar
  final double? width;

  /// Tinggi widget gambar
  final double? height;

  /// Cara gambar menyesuaikan dengan container
  final BoxFit fit;

  /// Border radius untuk gambar
  final BorderRadius? borderRadius;

  /// Membuat widget RecipeImage baru.
  ///
  /// Parameter:
  /// - [imageUrl]: URL gambar resep (opsional)
  /// - [width]: Lebar widget (opsional)
  /// - [height]: Tinggi widget (opsional)
  /// - [fit]: Cara gambar menyesuaikan dengan container (default: BoxFit.cover)
  /// - [borderRadius]: Border radius untuk gambar (opsional)
  const RecipeImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    // Check if imageUrl is valid
    if (_isValidImageUrl(imageUrl)) {
      imageWidget = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image loading error for URL: $imageUrl');
          return _buildPlaceholder();
        },
      );
    } else {
      imageWidget = _buildPlaceholder();
    }

    // Apply border radius if provided
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  /// Memvalidasi URL gambar.
  ///
  /// Parameter:
  /// - [url]: URL yang akan divalidasi
  ///
  /// Returns:
  /// - bool: true jika URL valid, false jika tidak
  ///
  /// Validasi yang dilakukan:
  /// - URL tidak null dan tidak kosong
  /// - Bukan URL placeholder yang rusak
  /// - URL memiliki skema http/https yang valid
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    // Check for broken placeholder services
    if (url.contains('via.placeholder.com')) return false;

    // Check if it's a valid URL
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Membangun widget placeholder untuk gambar yang tidak tersedia.
  ///
  /// Returns:
  /// - Widget: Container dengan gradient dan ikon
  ///
  /// Fitur:
  /// - Gradient warna merah muda
  /// - Ikon menu restoran
  /// - Teks "Recipe Image"
  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0C2C4), Color(0xFFD4A5A8)],
        ),
        borderRadius: borderRadius,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 48, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'Recipe Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Membangun widget placeholder saat gambar sedang dimuat.
  ///
  /// Returns:
  /// - Widget: Container dengan loading indicator
  ///
  /// Fitur:
  /// - Background abu-abu
  /// - CircularProgressIndicator
  /// - Teks "Loading image..."
  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF824E50)),
          SizedBox(height: 16),
          Text(
            'Loading image...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
