import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NewsArticle {
  final int rank;
  final double relevanceScore;
  final List<String> matchedTags;
  final String title;
  final String source;
  final String url;
  final String? image;
  final String? publishedAt;
  final bool hasAiSummary;
  final String summary;
  final String? audioUrl;
  final bool hasAudio;
  final bool isFeatured;

  const NewsArticle({
    required this.rank,
    required this.relevanceScore,
    required this.matchedTags,
    required this.title,
    required this.source,
    required this.url,
    required this.image,
    required this.publishedAt,
    required this.hasAiSummary,
    required this.summary,
    required this.audioUrl,
    required this.hasAudio,
    required this.isFeatured,
  });

  factory NewsArticle.fromJson(
    Map<String, dynamic> json, {
    required bool isFeatured,
  }) {
    return NewsArticle(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0,
      matchedTags: (json['matched_tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      title: json['title'] as String? ?? 'Untitled article',
      source: json['source'] as String? ?? 'Unknown source',
      url: json['url'] as String? ?? '',
      image: json['image'] as String?,
      publishedAt: json['published_at'] as String?,
      hasAiSummary: json['has_ai_summary'] as bool? ?? false,
      summary: json['summary'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      hasAudio: json['has_audio'] as bool? ?? false,
      isFeatured: isFeatured,
    );
  }
}

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  // Must match the host/port where FastAPI serves its /audio route.
  static const String _backendBaseUrl = 'http://127.0.0.1:8000';

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  String? _playingAudioUrl;
  bool _isAudioLoading = false;
  bool _isAudioPlaying = false;
  final PageController _pageController = PageController();
  List<NewsArticle> _articles = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
        _isAudioLoading = false;
      });
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isAudioPlaying = false;
        _isAudioLoading = false;
        _playingAudioUrl = null;
      });
    });

    _loadLiveFeed();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveFeed() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // The backend returns either a completed cached feed or a processing
      // acknowledgement while its background worker creates the feed.
      Map<String, dynamic> result = await ApiService.fetchUserFeed();

      if (result['status'] == 'processing') {
        if (!mounted) return;
        setState(() {
          _articles = [];
          _errorMessage =
              'Your personalized feed is being generated. Wait a little, then tap Retry.';
          _isLoading = false;
        });
        return;
      }

      final rawArticles = result['articles'] as List<dynamic>? ?? const [];
      final articles = rawArticles.map((item) {
        final json = Map<String, dynamic>.from(item as Map);
        final rank = (json['rank'] as num?)?.toInt() ?? 0;

        return NewsArticle.fromJson(
          json,
          isFeatured: rank > 0 && rank <= 3,
        );
      }).toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));

      if (!mounted) return;
      setState(() {
        _articles = articles;
        _currentIndex = 0;
        _errorMessage = articles.isEmpty
            ? 'Your feed is empty. Check the backend feed generation logs, then retry.'
            : null;
        _isLoading = false;
      });

      debugPrint('Live CuratX feed loaded: ${articles.length} articles');
    } catch (error, stackTrace) {
      debugPrint('Live feed loading error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your live feed: $error';
        _isLoading = false;
      });
    }
  }

  int get _pageCount => _articles.length + 1;
  bool get _isOnLastPage => _currentIndex >= _articles.length;

  void _goToPage(int delta) {
    _stopAudio();
    final target = _currentIndex + delta;
    if (target < 0 || target >= _pageCount) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _sendInteraction(
    NewsArticle article, {
    required String actionType,
  }) async {
    try {
      await ApiService.logInteraction(
        actionType: actionType,
        matchedTags: article.matchedTags,
      );
      debugPrint('CuratX interaction sent: $actionType, ${article.title}');
    } catch (error) {
      debugPrint('CuratX interaction API error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not sync interaction: $error'),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  void _onArticleTapped(NewsArticle article) {
    _sendInteraction(article, actionType: 'tap');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Article interaction recorded.'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  String _resolveAudioUrl(String audioUrl) {
    final trimmed = audioUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$_backendBaseUrl$path';
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (error) {
      debugPrint('Audio stop error: $error');
    }
    if (!mounted) return;
    setState(() {
      _playingAudioUrl = null;
      _isAudioPlaying = false;
      _isAudioLoading = false;
    });
  }

  Future<void> _onAudioPressed(NewsArticle article) async {
    final audioUrl = article.audioUrl;
    if (!article.hasAudio || audioUrl == null || audioUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio is not available for this article yet.'),
        ),
      );
      return;
    }

    final resolvedUrl = _resolveAudioUrl(audioUrl);

    if (_playingAudioUrl == resolvedUrl && _isAudioPlaying) {
      await _audioPlayer.pause();
      return;
    }

    try {
      setState(() {
        _isAudioLoading = true;
        _playingAudioUrl = resolvedUrl;
      });

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(resolvedUrl));
      _sendInteraction(article, actionType: 'play');
    } catch (error) {
      debugPrint('Audio playback error: $error');
      if (!mounted) return;
      setState(() {
        _isAudioLoading = false;
        _isAudioPlaying = false;
        _playingAudioUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play audio: $error'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE5E7EB),
                    child: Icon(Icons.person_outline, color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  const Text(
                    'CuratX Feed',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Feed settings',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings coming soon.')),
                    ),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildFeed()),
            if (!_isLoading && _errorMessage == null && _articles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onPressed: _currentIndex > 0 ? () => _goToPage(-1) : null,
                    ),
                    const SizedBox(width: 16),
                    _RoundAction(
                      icon: Icons.close_rounded,
                      onPressed: _isOnLastPage ? null : () => _goToPage(1),
                    ),
                    const SizedBox(width: 16),
                    _RoundAction(
                      icon: Icons.bookmark_border_rounded,
                      onPressed: _isOnLastPage
                          ? null
                          : () {
                              final article = _articles[_currentIndex];
                              _sendInteraction(article, actionType: 'save');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved: ${article.title}')),
                              );
                              _goToPage(1);
                            },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadLiveFeed();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_articles.isEmpty) {
      return const Center(child: Text('No articles are available in your live feed yet.'));
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      itemCount: _pageCount,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) {
        if (index == _articles.length) return const _CaughtUpCard();
        final article = _articles[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _ArticleCard(
            article: article,
            onArticleTapped: () => _onArticleTapped(article),
            onAudioPressed: () => _onAudioPressed(article),
            isAudioLoading: _isAudioLoading &&
                _playingAudioUrl == _resolveAudioUrl(article.audioUrl ?? ''),
            isAudioPlaying: _isAudioPlaying &&
                _playingAudioUrl == _resolveAudioUrl(article.audioUrl ?? ''),
          ),
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onArticleTapped;
  final VoidCallback onAudioPressed;
  final bool isAudioLoading;
  final bool isAudioPlaying;

  const _ArticleCard({
    required this.article,
    required this.onArticleTapped,
    required this.onAudioPressed,
    required this.isAudioLoading,
    required this.isAudioPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                color: const Color(0xFFF3F4F6),
                child: article.image != null && article.image!.startsWith('http')
                    ? Image.network(
                        article.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.article_outlined, size: 48, color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.article_outlined, size: 48, color: Color(0xFF9CA3AF)),
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _InfoChip(
                            label: article.isFeatured ? 'FEATURED' : 'FOR YOU',
                            color: article.isFeatured
                                ? const Color(0xFFFCE9E3)
                                : const Color(0xFFEFF6FF),
                          ),
                          Text('Rank ${article.rank}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          Text('${(article.relevanceScore * 100).round()}% match', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: onArticleTapped,
                        child: Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 21,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(article.source, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      Text(
                        article.summary,
                        style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: article.matchedTags.map((tag) => _TagChip(label: tag)).toList(),
                      ),
                      if (article.hasAiSummary) ...[
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 15, color: Color(0xFFDF7357)),
                            SizedBox(width: 6),
                            Text('AI summary', style: TextStyle(fontSize: 12, color: Color(0xFFDF7357), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: onArticleTapped,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Mark as read'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Listen to summary',
                        style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: article.hasAudio ? 'Audio available' : 'No audio yet',
                      onPressed: onAudioPressed,
                      style: IconButton.styleFrom(
                        backgroundColor: article.hasAudio ? const Color(0xFFDF7357) : const Color(0xFF9CA3AF),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(article.hasAudio ? Icons.play_arrow_rounded : Icons.volume_off_outlined),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      );
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(30)),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
      );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _RoundAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 50,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF374151),
            disabledForegroundColor: const Color(0xFFD1D5DB),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          icon: Icon(icon),
        ),
      );
}

class _CaughtUpCard extends StatelessWidget {
  const _CaughtUpCard();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 44, color: Color(0xFF9CA3AF)),
              SizedBox(height: 12),
              Text("You're all caught up", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              SizedBox(height: 6),
              Text('Swipe up to revisit earlier stories.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      );
}
