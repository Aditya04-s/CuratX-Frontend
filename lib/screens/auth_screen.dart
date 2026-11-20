import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/curatx_logo.dart';
import 'news_feed_screen.dart';
import 'onboarding_choice_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isDarkMode = true;
  String? _errorText;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _accent = Color(0xFFDF7357);

  Color get _bg => _isDarkMode ? const Color(0xFF0B0B0E) : Colors.white;
  Color get _surface => _isDarkMode ? const Color(0xFF16161C) : const Color(0xFFF3F4F6);
  Color get _fieldFill => _isDarkMode ? const Color(0xFF16161C) : const Color(0xFFF9FAFB);
  Color get _border => _isDarkMode ? const Color(0xFF2B2B36) : const Color(0xFFE5E7EB);
  Color get _textPrimary => _isDarkMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  Color get _textMuted => _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if ((!_isLogin && name.isEmpty) || email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please fill in all required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final res = _isLogin
          ? await ApiService.login(email: email, password: password)
          : await ApiService.signup(name: name, email: email, password: password);

      final userId = (res['user_id'] ?? '').toString();
      if (userId.isEmpty) {
        throw Exception('Backend did not return a valid user_id.');
      }

      final hasOnboarded = res['has_onboarded'] == true;
      await SessionService.saveSession(
        userId: userId,
        name: (res['name'] ?? name).toString(),
        email: (res['email'] ?? email).toString(),
        hasOnboarded: hasOnboarded,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hasOnboarded
              ? const NewsFeedScreen()
              : const OnboardingChoiceScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBrandLogo() {
    if (!_isDarkMode) {
      return const Center(child: CuratXLogo(size: 54));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'CX',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 21,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Curat', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'X', style: TextStyle(color: _accent)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 12,
              child: IconButton(
                tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                icon: Icon(
                  _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: _isDarkMode ? _accent : _textPrimary,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBrandLogo(),
                      const SizedBox(height: 12),
                      Text(
                        'Personalized AI News & Audio Briefings',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            _tabButton('Login', _isLogin, () {
                              setState(() {
                                _isLogin = true;
                                _errorText = null;
                              });
                            }),
                            _tabButton('Sign Up', !_isLogin, () {
                              setState(() {
                                _isLogin = false;
                                _errorText = null;
                              });
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_isLogin) ...[
                        TextField(
                          controller: _nameController,
                          style: TextStyle(color: _textPrimary),
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Full Name', Icons.person_outline),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _emailController,
                        style: TextStyle(color: _textPrimary),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('Email Address', Icons.email_outlined),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        style: TextStyle(color: _textPrimary),
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _submit(),
                        decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: _textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF2B1414)
                                : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isDarkMode
                                  ? const Color(0xFF7F1D1D)
                                  : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              color: _isDarkMode
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFB91C1C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? (_isDarkMode ? const Color(0xFF23232D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active && _isDarkMode
                ? Border.all(color: _accent.withValues(alpha: 0.6))
                : null,
            boxShadow: active && !_isDarkMode
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? _textPrimary : _textMuted,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textMuted),
      floatingLabelStyle: const TextStyle(color: _accent),
      prefixIcon: Icon(icon, color: _textMuted),
      filled: true,
      fillColor: _fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.6),
      ),
    );
  }
}