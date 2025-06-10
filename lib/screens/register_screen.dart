/// `RegisterScreen` adalah layar untuk pendaftaran pengguna baru.
/// Layar ini menampilkan form pendaftaran dengan validasi untuk nama,
/// email, dan password. Pengguna harus menyetujui Terms of Service
/// sebelum dapat mendaftar.
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Widget untuk menampilkan form pendaftaran pengguna.
///
/// Fitur-fitur yang tersedia:
/// - Input nama pengguna
/// - Input email dengan validasi format
/// - Input password dengan validasi kompleksitas
/// - Checkbox persetujuan Terms of Service
/// - Validasi form sebelum submit
/// - Penanganan error dan loading state
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /// Status persetujuan Terms of Service
  bool _agreedToTerms = false;

  /// Controller untuk field nama
  final TextEditingController _nameController = TextEditingController();

  /// Controller untuk field email
  final TextEditingController _emailController = TextEditingController();

  /// Controller untuk field password
  final TextEditingController _passwordController = TextEditingController();

  /// Status loading saat proses pendaftaran
  bool _isLoading = false;

  /// Pesan error jika terjadi kesalahan
  String? _errorMessage;

  /// Key untuk form validasi
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Memvalidasi password berdasarkan kriteria keamanan.
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
  /// - String pesan error jika tidak valid
  /// - null jika password valid
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return "Password harus minimal 8 karakter";
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return "Password harus memiliki minimal satu huruf besar";
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return "Password harus memiliki minimal satu angka";
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_-]'))) {
      return "Password harus memiliki minimal satu karakter khusus";
    }

    return null; // Password valid
  }

  /// Memproses pendaftaran pengguna baru.
  ///
  /// Proses yang dilakukan:
  /// 1. Validasi form
  /// 2. Validasi field wajib
  /// 3. Validasi persetujuan Terms of Service
  /// 4. Memanggil service untuk mendaftarkan pengguna
  /// 5. Menangani konfirmasi email
  /// 6. Navigasi ke layar yang sesuai
  /// 7. Menangani error jika terjadi kesalahan
  Future<void> _register() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Name cannot be empty';
        _isLoading = false;
      });
      return;
    }

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'You must agree to the Terms of Service';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('=== REGISTRATION START ===');
      debugPrint('Username: ${_nameController.text.trim()}');
      debugPrint('Email: ${_emailController.text.trim()}');

      final response = await SupabaseService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );

      debugPrint('=== REGISTRATION RESPONSE ===');
      debugPrint('User: ${response.user?.id}');
      debugPrint('Session: ${response.session?.accessToken != null}');
      debugPrint('Email confirmed: ${response.user?.emailConfirmedAt != null}');

      if (response.user != null) {
        // Reset loading state first
        setState(() {
          _isLoading = false;
        });

        // Check if email confirmation is required
        if (response.user!.emailConfirmedAt == null) {
          // Email confirmation required
          debugPrint('Email confirmation required');

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Email Confirmation Required'),
                    content: const Text(
                      'Please check your email and click the confirmation link to complete registration.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text('Go to Login'),
                      ),
                    ],
                  ),
            );
          }
        } else {
          // Email already confirmed, check session
          if (response.session != null) {
            debugPrint('Session available, navigating to home');

            // Wait a bit for session to settle then navigate
            await Future.delayed(const Duration(milliseconds: 500));

            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          } else {
            debugPrint('No session, redirecting to login');

            if (mounted) {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Registration Successful'),
                      content: const Text(
                        'Your account has been created. Please log in to continue.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text('Login'),
                        ),
                      ],
                    ),
              );
            }
          }
        }
      } else {
        // Registration failed
        debugPrint('Registration failed - no user returned');
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('=== REGISTRATION ERROR ===');
      debugPrint('Error: $e');

      setState(() {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Mencegah keyboard mendorong konten
      body: SizedBox(
        width: MediaQuery.of(context).size.width, // Gunakan lebar penuh layar
        height:
            MediaQuery.of(context).size.height, // Gunakan tinggi penuh layar
        child: Stack(
          fit: StackFit.expand, // Pastikan stack mengisi seluruh ruang
          children: [
            // Background
            Container(color: const Color(0xFFFAF8F8)),

            // Content
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Create your account',
                            style: TextStyle(
                              color: const Color(0xFF494242),
                              fontSize: 20.70,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Error message if any
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Form fields
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Name field with validation
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFF1E8E9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            child: TextFormField(
                              controller: _nameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Name cannot be empty';
                                }
                                if (value.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                hintText: 'Name',
                                hintStyle: TextStyle(
                                  color: Color(0xFFAC898A),
                                  fontSize: 14.80,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),

                          // Email field with validation
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFF1E9EA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email cannot be empty';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                hintText: 'Email',
                                hintStyle: TextStyle(
                                  color: Color(0xFFAD8B8D),
                                  fontSize: 15.90,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),

                          // Password field with validation
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFF1E9EA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password cannot be empty';
                                }
                                return _validatePassword(value);
                              },
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                hintText: 'Password',
                                hintStyle: TextStyle(
                                  color: Color(0xFFB19091),
                                  fontSize: 15.50,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ),

                          // Terms checkbox
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _agreedToTerms = !_agreedToTerms;
                                  });
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF716B6C),
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    color:
                                        _agreedToTerms
                                            ? const Color(0xFFE8B4B7)
                                            : Colors.white,
                                  ),
                                  child:
                                      _agreedToTerms
                                          ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'I agree to the Terms of Service',
                                style: TextStyle(
                                  color: const Color(0xFF716B6C),
                                  fontSize: 14.60,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),

                          // Sign up button
                          Container(
                            margin: const EdgeInsets.only(top: 24),
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isLoading
                                        ? Colors.grey
                                        : const Color(0xFFE8B4B7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Creating account...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                      : const Text(
                                        'Sign up',
                                        style: TextStyle(
                                          color: Color(0xFF543F40),
                                          fontSize: 15.90,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                        ),
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

            // Bottom text - already have account
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    'Already have an account? Sign in',
                    style: TextStyle(
                      color: Color(0xFFB49596),
                      fontSize: 13.10,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
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
