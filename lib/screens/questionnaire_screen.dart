import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'news_feed_screen.dart';

class _QuizQuestion {
  final int id;
  final String title;
  final String subtitle;
  final bool multiSelect;
  final List<String> options;
  final Map<String, List<String>>? keywordMap;

  const _QuizQuestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.multiSelect,
    required this.options,
    this.keywordMap,
  });
}

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _pageController = PageController();
  final _customTopicController = TextEditingController();
  int _currentIndex = 0;
  bool _isSubmitting = false;
  bool _isDarkMode = true;

  final Map<int, Set<String>> _selected = {};

  static const _accent = Color(0xFFDF7357);

  Color get _bg => _isDarkMode ? const Color(0xFF0B0B0E) : Colors.white;
  Color get _surface =>
      _isDarkMode ? const Color(0xFF16161C) : const Color(0xFFF9FAFB);
  Color get _accentSoft =>
      _isDarkMode ? const Color(0xFF2D1813) : const Color(0xFFFCE9E3);
  Color get _border =>
      _isDarkMode ? const Color(0xFF2B2B36) : const Color(0xFFE5E7EB);
  Color get _textPrimary =>
      _isDarkMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  Color get _textSecondary =>
      _isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
  Color get _textMuted =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  static const List<_QuizQuestion> _questions = [
    _QuizQuestion(
      id: 1,
      title: 'Primary Field / Industry',
      subtitle: 'Select one or more domains you follow.',
      multiSelect: true,
      options: [
        'Artificial Intelligence',
        'Software Engineering',
        'Finance',
        'Healthcare',
        'Business',
        'Cybersecurity',
        'Data Science',
        'Design',
      ],
    ),
    _QuizQuestion(
      id: 2,
      title: 'Core Tech & Tools You Follow',
      subtitle: 'Pick technologies you want updates on.',
      multiSelect: true,
      options: [
        'Python',
        'JavaScript',
        'Cloud Computing',
        'Blockchain',
        'Robotics',
        'Mobile Development',
        'Web3',
        'DevOps',
      ],
    ),
    _QuizQuestion(
      id: 3,
      title: 'Current Role / Career Stage',
      subtitle: 'Choose the one that fits you best.',
      multiSelect: false,
      options: ['Student', 'Developer', 'Founder', 'Analyst', 'Researcher'],
      keywordMap: {
        'Student': ['Careers', 'Internships'],
        'Developer': ['Software Development'],
        'Founder': ['Startups'],
        'Analyst': ['Market Trends'],
        'Researcher': ['Research'],
      },
    ),
    _QuizQuestion(
      id: 4,
      title: 'Emerging Innovations You Care About',
      subtitle: 'Select future-tech topics.',
      multiSelect: true,
      options: [
        'Generative AI',
        'Quantum Computing',
        'Electric Vehicles',
        'Space Tech',
        'Biotech',
        'AR VR',
      ],
    ),
    _QuizQuestion(
      id: 5,
      title: 'Business & Markets Interest',
      subtitle: 'Pick financial & startup themes.',
      multiSelect: true,
      options: [
        'Stock Market',
        'Startups',
        'Venture Capital',
        'Cryptocurrency',
        'Global Economy',
        'Fintech',
      ],
    ),
    _QuizQuestion(
      id: 6,
      title: 'Global & Policy Topics',
      subtitle: 'Select world & regulation topics.',
      multiSelect: true,
      options: [
        'Tech Regulation',
        'Climate Change',
        'Geopolitics',
        'Renewable Energy',
        'Digital Privacy',
      ],
    ),
    _QuizQuestion(
      id: 7,
      title: 'Companies / Ecosystems You Track',
      subtitle: 'Who do you want to keep an eye on?',
      multiSelect: true,
      options: [
        'Google',
        'Apple',
        'Microsoft',
        'OpenAI',
        'Nvidia',
        'Tesla',
        'Meta',
        'Amazon',
      ],
    ),
    _QuizQuestion(
      id: 8,
      title: 'Lifestyle & Everyday Topics',
      subtitle: 'Balance your feed with extra interests.',
      multiSelect: true,
      options: [
        'Science',
        'Gaming',
        'Productivity',
        'Sports',
        'Health Tech',
        'Education',
      ],
    ),
    _QuizQuestion(
      id: 9,
      title: 'Preferred News Depth / Style',
      subtitle: 'Choose your favorite reading style.',
      multiSelect: false,
      options: [
        'Breaking News',
        'Deep Tech Analysis',
        'Product Launches',
        'Career Advice',
      ],
    ),
    _QuizQuestion(
      id: 10,
      title: 'Bonus Custom Topics',
      subtitle: 'Pick extra favorites or type 1-3 topics separated by commas.',
      multiSelect: true,
      options: ['Cricket', 'Machine Learning', 'FastAPI', 'Semiconductors', 'ISRO'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _customTopicController.dispose();
    super.dispose();
  }

  void _toggleOption(_QuizQuestion q, String option) {
    setState(() {
      final current = _selected.putIfAbsent(q.id, () => <String>{});
      if (q.multiSelect) {
        if (current.contains(option)) {
          current.remove(option);
        } else {
          current.add(option);
        }
      } else {
        current
          ..clear()
          ..add(option);
      }
    });
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submitQuiz() async {
    final userId = await SessionService.getUserId();
    if (userId == null || userId.isEmpty) return;

    final List<dynamic> answers = [];
    final interestSet = <String>{};

    for (final q in _questions) {
      final picked = (_selected[q.id] ?? <String>{}).toList();
      if (q.id == 10 && _customTopicController.text.trim().isNotEmpty) {
        final extras = _customTopicController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        picked.addAll(extras);
      }

      if (picked.isNotEmpty) {
        answers.add({
          'question_id': q.id,
          'question': q.title,
          'selected_options': picked,
        });
        for (final item in picked) {
          if (q.keywordMap != null && q.keywordMap!.containsKey(item)) {
            interestSet.addAll(q.keywordMap![item]!);
          } else {
            interestSet.add(item);
          }
        }
      }
    }

    if (interestSet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2-3 interests first.'),
        ),
      );
      return;
    }

    final extractedInterests = interestSet.take(12).toList();

    setState(() => _isSubmitting = true);
    try {
      await ApiService.submitQuestionnaire(
        userId: userId,
        answers: answers,
        extractedInterests: extractedInterests,
      );
      await SessionService.setHasOnboarded(true);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NewsFeedScreen()),
        (_) => false,
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _textPrimary),
        elevation: 0,
        title: Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? _accent : _textPrimary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: _isDarkMode
                      ? const Color(0xFF22222B)
                      : const Color(0xFFF3F4F6),
                  color: _accent,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  final picked = _selected[q.id] ?? <String>{};

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.title,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          q.subtitle,
                          style: TextStyle(fontSize: 14, color: _textMuted),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: q.options.map((opt) {
                            final isSelected = picked.contains(opt);
                            return FilterChip(
                              label: Text(opt),
                              selected: isSelected,
                              onSelected: (_) => _toggleOption(q, opt),
                              selectedColor: _accentSoft,
                              checkmarkColor: _accent,
                              backgroundColor: _surface,
                              side: BorderSide(
                                color: isSelected ? _accent : _border,
                              ),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? _accent : _textSecondary,
                              ),
                            );
                          }).toList(),
                        ),
                        if (q.id == 10) ...[
                          const SizedBox(height: 22),
                          TextField(
                            controller: _customTopicController,
                            style: TextStyle(color: _textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Custom Topics (optional)',
                              labelStyle: TextStyle(color: _textMuted),
                              floatingLabelStyle: const TextStyle(color: _accent),
                              hintText: 'e.g., AI Agents, Cricket, Startups',
                              hintStyle: TextStyle(color: _textMuted),
                              filled: true,
                              fillColor: _surface,
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
                                borderSide: const BorderSide(
                                  color: _accent,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting ? null : () => _goTo(_currentIndex - 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          side: BorderSide(color: _border),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : _currentIndex == _questions.length - 1
                              ? _submitQuiz
                              : () => _goTo(_currentIndex + 1),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentIndex == _questions.length - 1
                                  ? 'Build My Feed'
                                  : 'Next',
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
          ],
        ),
      ),
    );
  }
}