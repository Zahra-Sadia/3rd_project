import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  Future<void> _register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name.')),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email.')));
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a password.')));
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
        ),
      );
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least one uppercase letter.'),
        ),
      );
      return;
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least one lowercase letter.'),
        ),
      );
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least one number.'),
        ),
      );
      return;
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must contain at least one special character.',
          ),
        ),
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm your password.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BACK
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primaryText,
                  size: 20,
                ),
              ),

              const SizedBox(height: 25),

              // LOGO
              const Center(child: AppLogo(fontSize: 46)),

              const SizedBox(height: 15),

              const Center(
                child: Text(
                  'Create your account',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 23,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'Start discovering opportunities made for you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              _label('FULL NAME'),

              const SizedBox(height: 8),

              _textField(
                controller: nameController,
                hint: 'Enter your full name',
                icon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 18),

              _label('EMAIL'),

              const SizedBox(height: 8),

              _textField(
                controller: emailController,
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 18),

              _label('PASSWORD'),

              const SizedBox(height: 8),

              _textField(
                controller: passwordController,
                hint: 'Create a password',
                icon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Password must be at least 8 characters and contain '
                  'uppercase, lowercase, number and special character.',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _label('CONFIRM PASSWORD'),

              const SizedBox(height: 8),

              _textField(
                controller: confirmPasswordController,
                hint: 'Confirm your password',
                icon: Icons.lock_outline_rounded,
                obscureText: obscureConfirmPassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // CREATE ACCOUNT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.roseGold,
                    foregroundColor: AppColors.background,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      color: AppColors.softPeach,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.secondaryText,
        fontSize: 10,
        letterSpacing: 2,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return GlassCard(
      borderRadius: 16.0,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.mutedText),
          prefixIcon: Icon(icon, color: AppColors.roseGold),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
      ),
    );
  }
}
