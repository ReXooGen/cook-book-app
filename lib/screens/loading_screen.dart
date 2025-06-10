/// `LoadingScreen` adalah layar splash yang ditampilkan saat aplikasi dimuat.
/// Layar ini menampilkan animasi Lottie, bilah kemajuan, dan pesan loading.
/// Setelah loading selesai, layar ini akan mengalihkan pengguna ke layar home atau login
/// berdasarkan status otentikasi.
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:cook_book_app/services/supabase_service.dart';

/// Widget untuk menampilkan layar loading saat aplikasi dimulai.
///
/// Widget ini menampilkan:
/// - Animasi Lottie yang menarik
/// - Bilah kemajuan yang menunjukkan status loading
/// - Pesan "Loading..." di tengah layar
///
/// Setelah loading selesai, pengguna akan diarahkan ke:
/// - Layar Home jika sudah login
/// - Layar Login jika belum login
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  /// Nilai kemajuan bilah loading (0.0 - 1.0)
  double _progressValue = 0.0;

  /// Timer untuk memperbarui bilah kemajuan secara berkala
  late Timer _timer;

  /// Controller untuk animasi fallback jika animasi Lottie gagal dimuat
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Inisialisasi controller animasi untuk animasi fallback
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(
      reverse: true,
    ); // Aktifkan animasi berulang dengan efek bolak-balik

    // Mulai timer untuk memperbarui bilah kemajuan
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        // Tambahkan nilai kemajuan sebesar 1% setiap 50ms
        _progressValue += 0.01;

        // Ketika kemajuan mencapai 100%, periksa status login pengguna
        if (_progressValue >= 1.0) {
          _timer.cancel(); // Hentikan timer
          _animationController.stop(); // Hentikan animasi

          // Tunda navigasi selama 500ms untuk efek visual yang lebih baik
          Future.delayed(const Duration(milliseconds: 500), () {
            // Periksa apakah pengguna sudah login
            final currentUser = SupabaseService.getCurrentUser();
            if (currentUser != null) {
              // Jika pengguna sudah login, arahkan ke layar beranda
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              // Jika pengguna belum login, arahkan ke layar login
              Navigator.pushReplacementNamed(context, '/login');
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    // Bersihkan resource untuk mencegah memory leak
    _timer.cancel(); // Hentikan timer saat widget dihapus
    _animationController.dispose(); // Buang controller animasi
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior:
            Clip.antiAlias, // Potong elemen yang melewati batas container
        decoration: const BoxDecoration(
          color: Color(0xFFFBF9F9),
        ), // Latar belakang krem muda
        child: Stack(
          children: [
            // Animasi Lottie dari asset lokal
            Positioned(
              left: 0,
              right: 0,
              top: 341, // Posisi vertikal dari atas layar
              child: Container(
                width: 190,
                height: 133,
                margin: const EdgeInsets.symmetric(
                  horizontal: 92,
                ), // Margin horizontal untuk penempatan
                child: Lottie.asset(
                  'assets/animations/loadingscreen3.json', // File animasi Lottie
                  fit: BoxFit.contain, // Pastikan animasi muat dalam container
                  repeat: true, // Ulangi animasi
                  animate: true, // Aktifkan animasi
                  errorBuilder: (context, error, stackTrace) {
                    // Jika animasi Lottie gagal dimuat, tampilkan animasi fallback
                    print("Error loading Lottie: $error");

                    // Fallback ke logo animasi yang sudah ada
                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        // Animasi skala menggunakan Transform.scale
                        return Transform.scale(
                          // Skala dari 0.8 hingga 1.0 berdasarkan nilai animasi
                          scale: 0.8 + (_animationController.value * 0.2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Ikon lingkaran sebagai logo
                              Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8B4B7), // Warna pink muda
                                  shape: BoxShape.circle, // Bentuk lingkaran
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant_menu, // Ikon menu restoran
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8), // Spasi vertikal
                              // Teks nama aplikasi
                              const Text(
                                "CookBook",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF543F40), // Warna coklat tua
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Bilah Kemajuan (Progress Bar)
            Positioned(
              left: 54,
              right: 54,
              top: 692, // Posisi dari atas layar
              child: SizedBox(
                width: 266,
                height: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    30,
                  ), // Sudut melengkung pada progress bar
                  child: LinearProgressIndicator(
                    value: _progressValue, // Nilai kemajuan dari state
                    backgroundColor: Colors.white, // Latar belakang putih
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0F0F0F), // Warna hitam untuk indikator kemajuan
                    ),
                    minHeight: 14, // Tinggi minimum bilah kemajuan
                  ),
                ),
              ),
            ),

            // Teks Loading
            const Positioned(
              left: 0,
              right: 0,
              top: 641, // Posisi dari atas layar
              child: SizedBox(
                width: 119,
                height: 35,
                child: Center(
                  child: Text(
                    'Loading...', // Teks yang ditampilkan
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700, // Bold
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
