/// `LoginScreen` adalah layar untuk proses autentikasi pengguna.
/// Layar ini menampilkan form login dengan email dan password,
/// serta opsi untuk mengingat login dan lupa password.
/// Setelah login berhasil, pengguna akan diarahkan ke layar beranda.
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Widget untuk menampilkan layar login.
///
/// Fitur-fitur yang tersedia:
/// - Input email dan password
/// - Opsi "Remember me"
/// - Tombol "Forgot password"
/// - Tombol login dengan email
/// - Tombol sign up untuk pengguna baru
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Controller untuk input field email
  final TextEditingController _emailController = TextEditingController();

  /// Controller untuk input field password
  final TextEditingController _passwordController = TextEditingController();

  /// Status apakah opsi "Remember me" dipilih
  bool _rememberMe = false;

  /// Status loading saat proses login
  bool _isLoading = false;

  /// Pesan error jika login gagal
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Melakukan proses login dengan email dan password.
  ///
  /// Proses yang dilakukan:
  /// 1. Validasi input email dan password
  /// 2. Mencoba login menggunakan Supabase
  /// 3. Memuat profil pengguna jika login berhasil
  /// 4. Membuat profil default jika belum ada
  /// 5. Mengarahkan ke layar beranda jika berhasil
  /// 6. Menampilkan pesan error jika gagal
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Email dan password harus diisi';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.user != null) {
        debugPrint('Login successful for user: ${response.user!.id}');

        // Load user profile to ensure username is correct
        final userData = await SupabaseService.getUserProfile(
          response.user!.id,
        );
        debugPrint('User profile loaded: $userData');

        // If profile exists but username is wrong, don't override it
        if (userData.isNotEmpty && userData['username'] != null) {
          debugPrint('Profile found with username: ${userData['username']}');
        } else {
          // Only create profile if it doesn't exist
          final emailName = response.user!.email?.split('@')[0] ?? 'User';
          await SupabaseService.createDefaultProfile(
            response.user!.id,
            response.user!.email!,
            emailName,
          );
          debugPrint('Created default profile for: $emailName');
        }
      }

      // Navigate to home screen after successful login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('Email belum dikonfirmasi')) {
          _errorMessage =
              'Email belum dikonfirmasi. Link konfirmasi baru telah dikirim ke email Anda.';
          // Show a snackbar with instructions - dengan mounted check
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Silakan periksa email Anda untuk mengonfirmasi akun',
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
            }
          });
        } else if (e.toString().contains('Invalid login credentials') ||
            e.toString().contains('Email atau password salah')) {
          _errorMessage = 'Email atau password salah. Silakan coba lagi.';
        } else {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/login_background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header with Title and Close Button
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Cookbook',
                              style: TextStyle(
                                color: Color(0xFF4E4748),
                                fontSize: 18.40,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: const Color(0xFF4E4748),
                          onPressed: () {
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Welcome text
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Color(0xFF342C2C),
                      fontSize: 29.40,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Error message if any
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Email Field
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFF1E9EA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        hintText: 'Email',
                        hintStyle: TextStyle(
                          color: Color(0xFFAD8A8C),
                          fontSize: 16.20,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),

                  // Password Field
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFF1E9EA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        hintText: 'Password',
                        hintStyle: TextStyle(
                          color: Color(0xFFAD8A8C),
                          fontSize: 16.60,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),

                  // Remember me toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            color: Color(0xFF6E6869),
                            fontSize: 16.60,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _rememberMe = !_rememberMe;
                            });
                          },
                          child: Container(
                            width: 50,
                            height: 31,
                            decoration: ShapeDecoration(
                              color:
                                  _rememberMe
                                      ? const Color(0xFFE7B4B7)
                                      : Colors.white,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: const Color(0xFF6E6869),
                                  width: _rememberMe ? 0 : 1,
                                ),
                                borderRadius: BorderRadius.circular(14.25),
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (_rememberMe)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      width: 27,
                                      height: 27,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (!_rememberMe)
                                  Positioned(
                                    left: 2,
                                    top: 2,
                                    child: Container(
                                      width: 27,
                                      height: 27,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFE7B4B7),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Login Button
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8B4B7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF503C3D),
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Log in',
                                style: TextStyle(
                                  color: Color(0xFF503C3D),
                                  fontSize: 17.30,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                    ),
                  ),

                  // Forgot password
                  GestureDetector(
                    onTap: () {
                      // Handle forgot password
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Color(0xFFB29293),
                        fontSize: 14.50,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  // Spacer to push buttons to bottom
                  const SizedBox(height: 280),

                  // Bottom buttons
                  Row(
                    children: [
                      // Sign up button
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                if (mounted) {
                                  Navigator.pushNamed(context, '/signup');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF1E9EA),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(19),
                                ),
                              ),
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  color: Color(0xFF5C5556),
                                  fontSize: 14.90,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Continue with email button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              // Handle continue with email
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE7B4B7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Continue with email',
                              style: TextStyle(
                                color: Color(0xFF584243),
                                fontSize: 14.50,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
