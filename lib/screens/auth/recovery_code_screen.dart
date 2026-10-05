import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecoveryCodeScreen extends StatefulWidget {
  final String email;

  const RecoveryCodeScreen({super.key, required this.email});

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  Future<void> _resetPassword() async {
    final code = codeController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Empty field validation
    if (code.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the code, new password, and confirm password.'),
        ),
      );
      return;
    }

    // Minimum 8 characters
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
        ),
      );
      return;
    }

    // At least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least one uppercase letter.'),
        ),
      );
      return;
    }

    // At least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least one lowercase letter.'),
        ),
      );
      return;
    }

    // At least one number
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least one number.'),
        ),
      );
      return;
    }

    // At least one special character
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

    // Confirm password
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => isLoading = true);

    try {
      // Verify recovery OTP
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.recovery,
      );

      // Update password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      // Sign out after successful password change
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Please log in.')),
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reset password. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter the recovery code sent to ${widget.email}',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // RECOVERY CODE
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Recovery code',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // NEW PASSWORD
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // PASSWORD RULES
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Password must be at least 8 characters and contain '
                'uppercase, lowercase, number and special character.',
                style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
              ),
            ),

            const SizedBox(height: 16),

            // CONFIRM PASSWORD
            TextField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // UPDATE PASSWORD BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _resetPassword,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('UPDATE PASSWORD'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
