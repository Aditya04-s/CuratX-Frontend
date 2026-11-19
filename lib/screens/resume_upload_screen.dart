import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'news_feed_screen.dart';

class ResumeUploadPage extends StatefulWidget {
  const ResumeUploadPage({super.key});

  @override
  State<ResumeUploadPage> createState() => _ResumeUploadPageState();
}

class _ResumeUploadPageState extends State<ResumeUploadPage> {
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
  }


Future<void> _pickResume() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );

    if (!mounted || result.isEmpty) return;

    final selectedFile = result.first;

    // Check file size (maximum 10 MB)
    final fileSize = await selectedFile.length() ?? 0;

    if (!mounted) return;

    if (fileSize > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File size must be less than 10 MB.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedFileName = selectedFile.name;
    });

  } catch (e) {
    debugPrint('File picker error: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to select the file.'),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 18, 32, 47),
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 32,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                SizedBox(
                                  width: 342,
                                  child: Text(
                                    'STEP 1 OF 3: TAILOR YOUR FEED',
                                    style: TextStyle(
                                      color: const Color(0xFF4B5563),
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  height: 6,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 113,
                                        height: double.infinity,
                                        decoration: BoxDecoration(color: const Color(0xFFDF7357)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                SizedBox(
                                  width: 342,
                                  child: Text(
                                    'Upload Your Resume',
                                    style: TextStyle(
                                      color: const Color(0xFF111111),
                                      fontSize: 24,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 342,
                                  child: Text(
                                    'We curate news based on your skills and experience.',
                                    style: TextStyle(
                                      color: const Color(0xFF4B5563),
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                      height: 1.50,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Dashed upload box
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _pickResume,
                              child: CustomPaint(
                                painter: _DashedBorderPainter(
                                  color: const Color(0xFF9CA3AF),
                                  radius: 16,
                                  gap: 6,
                                  strokeWidth: 1.2,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  height: 220,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    spacing: 16,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFFFCE9E3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 24,
                                          color: Color(0xFFDF7357),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        spacing: 4,
                                        children: [
                                          SizedBox(
                                            width: 263,
                                            child: Text(
                                              'Drag & drop your PDF, DOCX, or TXT',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: const Color(0xFF111111),
                                                fontSize: 15,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 263,
                                            child: Text(
                                              '(Max 10MB)',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: const Color(0xFF9CA3AF),
                                                fontSize: 13,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w400,
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
                          if (_selectedFileName != null)
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Selected: $_selectedFileName',
                                style: const TextStyle(
                                  color: Color(0xFFDF7357),
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 20,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 6,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          Text(
                            'Your resume is encrypted and private.',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: const Color(0xFFDF7357),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          if (_selectedFileName == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select your resume first.'),
                              ),
                            );
                            return;
                          }

                          // Remember that this browser has completed the
                          // resume-selection step across page refreshes.
                          // Capture Navigator before awaiting so no
                          // BuildContext is accessed across the async gap.
                          final navigator = Navigator.of(context);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('resume_step_completed', true);
                          await prefs.setString(
                            'selected_resume_name',
                            _selectedFileName!,
                          );

                          if (!mounted) return;
                          navigator.pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const NewsFeedScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          alignment: Alignment.center,
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 34,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 134,
                            height: 5,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF9CA3AF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2.50),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border, since Flutter has no
/// built-in dashed BoxBorder.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double gap;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? gap : gap * 0.7;
        final next = distance + length;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            Offset.zero,
          );
        }
        distance = next;
        draw = !draw;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
