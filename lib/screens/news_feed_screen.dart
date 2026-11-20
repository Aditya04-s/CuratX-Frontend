import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/curatx_logo.dart';
import 'auth_screen.dart';
import 'onboarding_choice_screen.dart';

class NewsArticle {
  final int rank;
  final String title;
  final String source;
  final String description;
  final String summary;
  final String url;
  final String? image;
  final double relevanceScore;
  final List<String> matchedTags;
  final bool hasAiSummary;
  final bool hasAudio;
  final String? audioUrl;

  NewsArticle({
    required this.rank,
    required this.title,
    required this.source,
    required this.description,
    required this.summary,
    required this.url,
    this.image,
    required this.relevanceScore,
    required this.matchedTags,
    required this.hasAiSummary,
    required this.hasAudio,
    this.audioUrl,
  });

  bool get isHero => hasAudio || rank <= 3;

  factory NewsArticle.fromJson(Map<String, dynamic> json, int index) {
    final rawTags = json['matched_tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final desc = (json['description'] ?? '').toString();
    final sum = (json['summary'] ?? '').toString();

    return NewsArticle(
      rank: (json['rank'] is num) ? (json['rank'] as num).toInt() : index + 1,
      title: (json['title'] ?? 'Untitled Article').toString(),
      source: (json['source'] is Map)
          ? (json['source']['name'] ?? 'CuratX News').toString()
          : (json['source'] ?? 'CuratX News').toString(),
      description: desc,
      summary: sum.isNotEmpty ? sum : desc,
      url: (json['url'] ?? '').toString(),
      image: json['image']?.toString(),
      relevanceScore: (json['relevance_score'] is num)
          ? (json['relevance_score'] as num).toDouble()
          : 0.0,
      matchedTags: tags,
      hasAiSummary: json['has_ai_summary'] == true,
      hasAudio: json['has_audio'] == true &&
          (json['audio_url'] ?? '').toString().trim().isNotEmpty,
      audioUrl: json['audio_url']?.toString(),
    );
  }
}

class _CuratXPalette {
  final bool isDark;
  const _CuratXPalette(this.isDark);

  Color get accent => const Color(0xFFDF7357);
  Color get accentSoft =>
      isDark ? const Color(0xFF2D1813) : const Color(0xFFFCE9E3);
  Color get bg => isDark ? const Color(0xFF0B0B0E) : const Color(0xFFF3F4F6);
  Color get surface => isDark ? const Color(0xFF16161C) : Colors.white;
  Color get surfaceAlt =>
      isDark ? const Color(0xFF22222B) : const Color(0xFFF3F4F6);
  Color get border =>
      isDark ? const Color(0xFF2B2B36) : const Color(0xFFE5E7EB);
  Color get textPrimary =>
      isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  Color get textSecondary =>
      isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
  Color get textMuted =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get chipBg =>
      isDark ? const Color(0xFF23232D) : const Color(0xFFF3F4F6);
  Color get chipText =>
      isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151);
}

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.89);
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isRefining = false;
  bool _hasLoadedOnce = false;
  bool _isDarkMode = true;
  String? _errorMessage;
  String? _userId;

  int _currentIndex = 0;
  DateTime _cardEnteredAt = DateTime.now();
  Timer? _pollTimer;

  String? _playingAudioUrl;
  bool _isAudioPlaying = false;
  bool _isAudioLoading = false;

  int get _pageCount => _articles.length + 1;
  bool get _isOnLastPage => _currentIndex >= _articles.length;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
        if (state == PlayerState.playing ||
            state == PlayerState.paused ||
            state == PlayerState.stopped ||
            state == PlayerState.completed) {
          _isAudioLoading = false;
        }
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _playingAudioUrl = null;
        }
      });
    });
    _initAndLoad();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad({bool forceRefresh = false}) async {
    _pollTimer?.cancel();
    final uid = await SessionService.getUserId();
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    _userId = uid;
    await _loadLiveFeed(forceRefresh: forceRefresh);
  }

  Future<void> _loadLiveFeed({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (_userId == null) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _isRefining = forceRefresh || _hasLoadedOnce;
        _errorMessage = null;
      });
    }

    try {
      final data = await ApiService.fetchUserFeed(
        userId: _userId!,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      final status = (data['status'] ?? '').toString().toLowerCase();
      final rawList = data['articles'];

      if (status == 'processing' ||
          (rawList is List && rawList.isEmpty && status != 'completed')) {
        setState(() {
          _isLoading = false;
          _isProcessing = true;
          _errorMessage = null;
        });
        _schedulePoll();
        return;
      }

      final seenTitles = <String>{};
      final parsed = <NewsArticle>[];
      if (rawList is List) {
        for (var i = 0; i < rawList.length; i++) {
          final article = NewsArticle.fromJson(
            Map<String, dynamic>.from(rawList[i] as Map),
            parsed.length,
          );
          final normalizedTitle = article.title
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (normalizedTitle.isEmpty || seenTitles.add(normalizedTitle)) {
            parsed.add(article);
          }
        }
      }

      _pollTimer?.cancel();
      setState(() {
        _articles = parsed;
        _hasLoadedOnce = true;
        _isLoading = false;
        _isProcessing = false;
        _errorMessage = null;
        _currentIndex = 0;
        _cardEnteredAt = DateTime.now();
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _isLoading = false;
        _isProcessing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _loadLiveFeed(silent: true);
    });
  }

  int _currentDwellSeconds() {
    final secs = DateTime.now().difference(_cardEnteredAt).inSeconds;
    return secs < 1 ? 1 : secs;
  }

  Future<void> _sendInteraction(
    NewsArticle article, {
    required String actionType,
  }) async {
    if (_userId == null) return;
    try {
      await ApiService.logInteraction(
        userId: _userId!,
        actionType: actionType,
        interestTokens: article.matchedTags,
        articleUrl: article.url,
        articleTitle: article.title,
        matchedTags: article.matchedTags,
        durationSeconds: _currentDwellSeconds(),
      );
    } catch (e) {
      debugPrint('Interaction sync error: $e');
    }
  }

  void _goToPage(int delta) {
    final next = (_currentIndex + delta).clamp(0, _pageCount - 1);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onAudioPressed(NewsArticle article) async {
    if (!article.hasAudio || article.audioUrl == null) return;
    final resolvedUrl = ApiConfig.resolveUrl(article.audioUrl!);

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAudioLoading = false;
        _isAudioPlaying = false;
        _playingAudioUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio error: $e')),
      );
    }
  }

  Future<void> _handleMenu(String value) async {
    await _audioPlayer.stop();
    if (value == 'reonboard') {
      await SessionService.setHasOnboarded(false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingChoiceScreen()),
      );
    } else if (value == 'logout') {
      await SessionService.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  Widget _buildHeaderBrand(_CuratXPalette p, {double iconSize = 30, double fontSize = 20}) {
    if (!p.isDark && iconSize == 30) {
      return const CuratXLogo(size: 30);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(iconSize * 0.3),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'CX',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: iconSize * 0.4,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(width: iconSize * 0.28),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            children: [
              TextSpan(
                text: 'Curat',
                style: TextStyle(color: p.textPrimary),
              ),
              TextSpan(
                text: 'X',
                style: TextStyle(color: p.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandedLoader(_CuratXPalette p, {bool showCheckButton = false}) {
    final title = _isRefining
        ? 'Refining & Redesigning Your Feed...'
        : 'Building Your Personalized Feed...';
    final subtitle = _isRefining
        ? 'Re-ranking fresh stories and tailoring AI audio briefings to your latest activity.'
        : 'Scanning live news, crafting DistilBART summaries, and synthesizing AI audio briefings.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderBrand(p, iconSize: 54, fontSize: 30),
            const SizedBox(height: 28),
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: p.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: p.textMuted,
                height: 1.5,
              ),
            ),
            if (showCheckButton) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _loadLiveFeed(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.accent),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check Now'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _CuratXPalette(_isDarkMode);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  _buildHeaderBrand(p),
                  const Spacer(),
                  IconButton(
                    tooltip: _isDarkMode
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                    onPressed: () {
                      setState(() => _isDarkMode = !_isDarkMode);
                    },
                    icon: Icon(
                      _isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: _isDarkMode ? p.accent : p.textPrimary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh & Re-rank Feed',
                    onPressed: () => _initAndLoad(forceRefresh: true),
                    icon: Icon(Icons.refresh_rounded, color: p.textPrimary),
                  ),
                  PopupMenuButton<String>(
                    color: p.surface,
                    iconColor: p.textPrimary,
                    onSelected: _handleMenu,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'reonboard',
                        child: Text(
                          'Re-onboard (Resume / Quiz)',
                          style: TextStyle(color: p.textPrimary),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Text(
                          'Logout',
                          style: TextStyle(color: p.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_isLoading &&
                !_isProcessing &&
                _errorMessage == null &&
                _articles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Row(
                  children: [
                    Text(
                      'For You',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        _isOnLastPage
                            ? 'Caught Up'
                            : '${_currentIndex + 1} / ${_articles.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isOnLastPage ? p.accent : p.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildBody(p)),
            if (!_isLoading &&
                !_isProcessing &&
                _errorMessage == null &&
                _articles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                      palette: p,
                      icon: Icons.chevron_left_rounded,
                      onPressed: _currentIndex > 0 ? () => _goToPage(-1) : null,
                    ),
                    const SizedBox(width: 16),
                    _RoundAction(
                      palette: p,
                      icon: Icons.close_rounded,
                      onPressed: _isOnLastPage
                          ? null
                          : () {
                              _sendInteraction(
                                _articles[_currentIndex],
                                actionType: 'skip',
                              );
                              _goToPage(1);
                            },
                    ),
                    const SizedBox(width: 16),
                    _RoundAction(
                      palette: p,
                      icon: Icons.bookmark_border_rounded,
                      isHighlighted: true,
                      onPressed: _isOnLastPage
                          ? null
                          : () {
                              final article = _articles[_currentIndex];
                              _sendInteraction(article, actionType: 'save');
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text('Saved: ${article.title}'),
                                  ),
                                );
                              _goToPage(1);
                            },
                    ),
                    const SizedBox(width: 16),
                    _RoundAction(
                      palette: p,
                      icon: Icons.chevron_right_rounded,
                      onPressed: _currentIndex < _pageCount - 1
                          ? () => _goToPage(1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(_CuratXPalette p) {
    if (_isLoading) {
      return _buildBrandedLoader(p);
    }

    if (_isProcessing) {
      return _buildBrandedLoader(p, showCheckButton: true);
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _loadLiveFeed(),
                style: FilledButton.styleFrom(backgroundColor: p.accent),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No articles in your feed yet.',
              style: TextStyle(color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadLiveFeed(forceRefresh: true),
              style: FilledButton.styleFrom(backgroundColor: p.accent),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      padEnds: false,
      physics: const BouncingScrollPhysics(),
      itemCount: _pageCount,
      onPageChanged: (index) {
        _audioPlayer.stop();
        setState(() {
          _currentIndex = index;
          _cardEnteredAt = DateTime.now();
        });
      },
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double page = _currentIndex.toDouble();
            if (_pageController.hasClients &&
                _pageController.position.haveDimensions) {
              page = _pageController.page ?? _currentIndex.toDouble();
            }
            final dist = (page - index).abs().clamp(0.0, 1.0);
            final scale = 1.0 - (dist * 0.065);
            final opacity = 1.0 - (dist * 0.25);

            return Transform.scale(
              scale: scale,
              alignment: Alignment.centerLeft,
              child: Opacity(opacity: opacity, child: child),
            );
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              index == 0 ? 16 : 6,
              4,
              index == _pageCount - 1 ? 16 : 6,
              8,
            ),
            child: index == _articles.length
                ? _CaughtUpCard(
                    palette: p,
                    onRefresh: () => _initAndLoad(forceRefresh: true),
                  )
                : _buildArticleCard(_articles[index], p),
          ),
        );
      },
    );
  }

  Widget _buildArticleCard(NewsArticle article, _CuratXPalette p) {
    final resolved =
        article.audioUrl != null ? ApiConfig.resolveUrl(article.audioUrl!) : '';
    return _ArticleCard(
      article: article,
      palette: p,
      isAudioLoading: _isAudioLoading && _playingAudioUrl == resolved,
      isAudioPlaying: _isAudioPlaying && _playingAudioUrl == resolved,
      onArticleTapped: () {
        _sendInteraction(article, actionType: 'tap');
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Interaction logged — feed will adapt on refresh.'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      onAudioPressed: () => _onAudioPressed(article),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final NewsArticle article;
  final _CuratXPalette palette;
  final VoidCallback onArticleTapped;
  final VoidCallback onAudioPressed;
  final bool isAudioLoading;
  final bool isAudioPlaying;

  const _ArticleCard({
    required this.article,
    required this.palette,
    required this.onArticleTapped,
    required this.onAudioPressed,
    required this.isAudioLoading,
    required this.isAudioPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: p.isDark ? 6 : 2,
      shadowColor:
          p.isDark ? Colors.black.withValues(alpha: 0.6) : Colors.black12,
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: article.isHero ? p.accent : p.border,
          width: article.isHero ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 185,
                width: double.infinity,
                color: p.surfaceAlt,
                child: article.image != null &&
                        article.image!.startsWith('http')
                    ? Image.network(
                        article.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            Icons.article_outlined,
                            size: 46,
                            color: p.textMuted,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.article_outlined,
                          size: 46,
                          color: p.textMuted,
                        ),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        p.surface,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: article.isHero
                          ? p.accent
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    article.isHero
                        ? 'TOP HERO #${article.rank}'
                        : 'FOR YOU #${article.rank}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: article.isHero ? p.accent : Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    article.relevanceScore > 1.0
                        ? '${article.relevanceScore.round()} topics matched'
                        : '${(article.relevanceScore * 100).round()}% match',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onArticleTapped,
                    child: Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 19.5,
                        height: 1.26,
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.source,
                    style: TextStyle(
                      color: p.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.summary,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: article.matchedTags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.chipBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: p.border),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.chipText,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (article.hasAiSummary) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 15, color: p.accent),
                        const SizedBox(width: 6),
                        Text(
                          'DistilBART AI Summary',
                          style: TextStyle(
                            fontSize: 12,
                            color: p.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onArticleTapped,
                    style: TextButton.styleFrom(
                      foregroundColor: p.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.touch_app_outlined, size: 16),
                    label: const Text('Boost Similar Topics'),
                  ),
                ],
              ),
            ),
          ),
          if (article.hasAudio) ...[
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Listen to AI Audio Briefing',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: onAudioPressed,
                    style: IconButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: isAudioLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isAudioPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final _CuratXPalette palette;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isHighlighted;

  const _RoundAction({
    required this.palette,
    required this.icon,
    required this.onPressed,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isHighlighted ? p.accentSoft : p.surface,
          foregroundColor: isHighlighted ? p.accent : p.textPrimary,
          disabledForegroundColor: p.textMuted.withValues(alpha: 0.35),
          side: BorderSide(
            color: isHighlighted ? p.accent : p.border,
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _CaughtUpCard extends StatelessWidget {
  final _CuratXPalette palette;
  final VoidCallback onRefresh;

  const _CaughtUpCard({
    required this.palette,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: p.accent,
            ),
            const SizedBox(height: 12),
            Text(
              "You're all caught up",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Refresh to pull your newly re-ranked feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              style: FilledButton.styleFrom(backgroundColor: p.accent),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Feed'),
            ),
          ],
        ),
      ),
    );
  }
}