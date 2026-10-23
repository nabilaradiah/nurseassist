import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'user_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _staffIdController  = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading       = false;
  bool _showPassword    = false;
  bool _staffAccessBlocked = false;
  String? _staffAccessMessage;

  // Animation
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
        parent: _controller, curve: Curves.easeIn);

    _scaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller, curve: Curves.elasticOut));

    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _checkStaffCollectionAccess();
  }

  Future<void> _checkStaffCollectionAccess() async {
    try {
      // A single-document get is all the rules allow before login; the
      // document doesn't need to exist for the probe to succeed.
      await FirebaseFirestore.instance
          .collection('staffLookup')
          .doc('_probe')
          .get();
      if (!mounted) return;
      setState(() {
        _staffAccessBlocked = false;
        _staffAccessMessage = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        setState(() {
          _staffAccessBlocked = true;
          _staffAccessMessage =
              'Firestore rules are blocking access to staff records. '
              'Please update security rules.';
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await AuthService().signInWithStaffId(
        _staffIdController.text.trim().toUpperCase(),
        _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final staffIdController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Reset Password',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Staff ID. A password reset link will be sent to your registered email.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: staffIdController,
              decoration: InputDecoration(
                hintText: 'e.g. WRN-001',
                filled: true,
                fillColor: kBgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final staffId = staffIdController.text.trim();
              if (staffId.isEmpty) return;
              Navigator.of(ctx).pop();

              try {
                await AuthService().sendPasswordReset(staffId);
                if (mounted) {
                  showSuccessSnack(
                    context,
                    'Password reset email sent. Check your inbox or spam/junk folder.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  showErrorSnack(
                    context,
                    e.toString().replaceFirst('Exception: ', ''),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: const Center(
                      child: BrandLogo(size: 80),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // App name
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: const Column(
                      children: [
                        Text(
                          'NurseAssist',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'DETECT WITH PRECISION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.6,
                            color: kMuted1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Firestore warning banner
                if (_staffAccessBlocked) ...[
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kSevModerateBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFFCC80)),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFEF6C00)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _staffAccessMessage ??
                                        'Staff access is blocked.',
                                    style: const TextStyle(
                                        color: Color(0xFF8A4B00),
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed:
                                        _checkStaffCollectionAccess,
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFFEF6C00),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                      minimumSize:
                                          const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap,
                                      visualDensity:
                                          VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.refresh,
                                        size: 16),
                                    label: const Text(
                                        'Retry Access Check'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Login card
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kBgLifted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Log in',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),

                          // Staff ID
                          const Text('Staff ID',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _staffIdController,
                            decoration: InputDecoration(
                              hintText: 'Please enter your staff ID',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            textCapitalization:
                                TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Please enter your Staff ID'
                                    : null,
                          ),

                          const SizedBox(height: 16),

                          // Password
                          const Text('Password',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: 'Please enter your password',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() =>
                                    _showPassword = !_showPassword),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Please enter your password'
                                    : null,
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize
                                    .shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                    color: kPrimary,
                                    fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Login button
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _staffAccessBlocked)
                        ? null
                        : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                            ),
                          )
                        : const Text('Login',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 16),

                // Register link
                FadeTransition(
                  opacity: _fadeAnim,
                  child: TextButton(
                    onPressed: _staffAccessBlocked
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const UserRegistrationScreen()),
                            ),
                    child: const Text(
                      'User Registration',
                      style: TextStyle(
                          color: kPrimary, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _staffIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
