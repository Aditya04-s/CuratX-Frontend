import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/curatx_logo.dart';
import 'auth_screen.dart';
import 'news_feed_screen.dart';
import 'questionnaire_screen.dart';

class OnboardingChoiceScreen extends StatefulWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  State<OnboardingChoiceScreen> createState() => _OnboardingChoiceScreenState();
}

class _OnboardingChoiceScreenState extends State<OnboardingChoiceScreen> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isDarkMode = true;

  static const _accent = Color(0xFFDF7357);

  Color get _bg => _isDarkMode ? const Color(0xFF0B0B0E) : Colors.white;
  Color get _surface =>
      _isDarkMode ? const Color(0xFF16161C) : const Color(0xFFF9FAFB);
  Color get _resumeCardBg =>
      _isDarkMode ? const Color(0xFF1A1414) : const Color(0xFFFFF8F6);
  Color get _resumeCardBorder =>
      _isDarkMode ? _accent.withValues(alpha: 0.45) : const Color(0xFFF3C6B8);
  Color get _accentSoft =>
      _isDarkMode ? const Color(0xFF2D1813) : const Color(0xFFFCE9E3);
  Color get _border =>
      _isDarkMode ? const Color(0xFF2B2B36) : const Color(0xFFE5E7EB);
  Color get _textPrimary =>
      _isDarkMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  Color get _textMuted =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (!mounted || result.isEmpty) return;

      final file = result.first;
      final size = (await file.length()) ?? 0;
      if (!mounted) return;

      if (size > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF size must be under 10 MB.')),
        );
        return;
      }

      setState(() => _selectedFile = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }

  Future<void> _uploadResume() async {
    if (_selectedFile == null) {
      await _pickPdf();
      if (_selectedFile == null) return;
    }

    final userId = await SessionService.getUserId();
    if (userId == null || userId.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await _selectedFile!.readAsBytes();
      await ApiService.uploadResume(
        userId: userId,
        fileBytes: bytes,
        fileName: _selectedFile!.name,
      );
      await SessionService.setHasOnboarded(true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NewsFeedScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Widget _buildHeaderBrand() {
    if (!_isDarkMode) {
      return const CuratXLogo(size: 30);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: const Text(
            'CX',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 9),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
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
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: _buildHeaderBrand(),
        actions: [
          IconButton(
            tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? _accent : _textPrimary,
            ),
          ),
          TextButton.icon(
            onPressed: _logout,
            style: TextButton.styleFrom(foregroundColor: _accent),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personalize Your Feed',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how CuratX should learn your interests - zero cold start.',
                style: TextStyle(fontSize: 14, color: _textMuted, height: 1.5),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _resumeCardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _resumeCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _accentSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: _accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Your Resume (PDF)',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Fastest - AI extracts your skills & domains automatically.',
                                style: TextStyle(fontSize: 12.5, color: _textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _isUploading ? null : _pickPdf,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF0F0F14) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_file_rounded, color: _accent),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _selectedFile?.name ??
                                    'Tap to select Resume PDF (Max 10MB)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _selectedFile != null
                                      ? _accent
                                      : _textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _isUploading ? null : _uploadResume,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _selectedFile == null
                                    ? 'Select & Upload PDF'
                                    : 'Upload & Build Feed',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: _border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: _border)),
                ],
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _isUploading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const QuestionnaireScreen(),
                          ),
                        ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.quiz_outlined,
                          color: _accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Resume? Answer 10 Quick Questions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pick your favorite domains, tech & topics in 60 seconds.',
                              style: TextStyle(fontSize: 12.5, color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: _textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}