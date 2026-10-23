import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../services/auth_service.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey               = GlobalKey<FormState>();
  final _deptFieldKey          = GlobalKey<FormFieldState<String>>();
  final _staffIdController     = TextEditingController();
  final _fullNameController    = TextEditingController();
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPassController = TextEditingController();

  String? _selectedDepartment;
  bool    _isSubmitting = false;
  bool    _showPassword = false;
  bool    _showConfirm  = false;

  final List<String> _departments = [
    'Basic Medical Sciences for Nursing',
    'Critical Care Nursing',
    'Medical Surgical Nursing',
    'Professional Nursing Studies',
    'Special Care Nursing',
  ];

  Future<void> _openDepartmentPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(kRadius3xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Department', style: kH3),
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _departments.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: kLine,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (_, i) {
                final dept = _departments[i];
                final isSelected = _selectedDepartment == dept;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDepartment = dept);
                    _deptFieldKey.currentState?.didChange(dept);
                    Navigator.pop(ctx);
                  },
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dept,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_rounded,
                                color: kPrimary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await AuthService().registerStaff(
        staffId:    _staffIdController.text,
        fullName:   _fullNameController.text,
        department: _selectedDepartment!,
        email:      _emailController.text,
        password:   _passwordController.text,
      );

      if (!mounted) return;

      // Show success dialog with email confirmation notice
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: kSevMildBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: kSevMild, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registration Successful!',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'A confirmation email has been sent to\n${_emailController.text.trim().toLowerCase()}',
                style: const TextStyle(
                    fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Please verify your email before logging in.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline,
                      size: 13, color: kWarning),
                  const SizedBox(width: 4),
                  const Text(
                    "Can't find it? Check your spam or junk folder.",
                    style: TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Go to Login'),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration(String hintText,
      {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: kBgInput,
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBlue400, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kDanger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCanvas,
      appBar: AppBar(
        title: const Text('User Registration',
            style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: 22, vertical: 14),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),

                // Icon
                const Center(child: BrandLogo(size: 56)),
                const SizedBox(height: 14),
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: kInk1),
                ),
                const SizedBox(height: 22),

                // ── Form card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: kBgLifted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Staff ID
                      const Text('STAFF ID',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted1,
                          )),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _staffIdController,
                        decoration: _fieldDecoration('e.g. WRN-001'),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9-]')),
                          UpperCaseTextFormatter(),
                        ],
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter your Staff ID'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Full Name
                      const Text('FULL NAME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted1,
                          )),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _fieldDecoration(
                            'e.g. Aisha Binti Ali'),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter your full name'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Department
                      const Text('DEPARTMENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted1,
                          )),
                      const SizedBox(height: 6),
                      FormField<String>(
                        key: _deptFieldKey,
                        initialValue: _selectedDepartment,
                        validator: (v) =>
                            (v == null || v.isEmpty)
                                ? 'Please select your department'
                                : null,
                        builder: (state) => Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _openDepartmentPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: kBgInput,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: state.hasError
                                      ? Border.all(color: kDanger)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedDepartment ??
                                            'Select your department',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _selectedDepartment !=
                                                  null
                                              ? kInk1
                                              : kMuted3,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: kMuted1),
                                  ],
                                ),
                              ),
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 6, left: 4),
                                child: Text(
                                  state.errorText!,
                                  style: const TextStyle(
                                      color: kDanger, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email
                      const Text('EMAIL ADDRESS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted1,
                          )),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        decoration: _fieldDecoration(
                            'e.g. aisha@iium.edu.my'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                                  r'^[\w.-]+@[\w.-]+\.\w{2,}$')
                              .hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password
                      const Text('PASSWORD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted1,
                          )),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: _fieldDecoration(
                          'Minimum 8 characters',
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _showPassword = !_showPassword),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      const Text('CONFIRM PASSWORD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted1,
                          )),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPassController,
                        obscureText: !_showConfirm,
                        decoration: _fieldDecoration(
                          'Re-enter your password',
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _showConfirm = !_showConfirm),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Register button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                            ),
                          )
                        : const Text('Register',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _staffIdController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
