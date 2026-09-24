import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/motion.dart';
import 'package:starlitfilms/components/movie_carousel.dart';
import 'package:starlitfilms/components/new_review_sheet.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/components/user_avatar.dart';
import 'package:starlitfilms/config.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/Perfil/perfil.dart';
import 'package:starlitfilms/screens/amigos.dart';
import 'package:starlitfilms/screens/filme.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';
import 'package:starlitfilms/services/tmdb_service.dart';
import 'package:starlitfilms/theme/tokens.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.profile == null) auth.loadProfile();
    });
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = [_FeedTab(), Perfil(), AmigosPage()];
    return Scaffold(
      extendBody: true,
      backgroundColor: SC.bg,
      body: Stack(
        children: [
          for (var i = 0; i < pages.length; i++)
            if (_visited.contains(i))
              _TabLayer(active: i == _index, child: pages[i]),
        ],
      ),
      bottomNavigationBar: StarlitNavBar(index: _index, onSelect: _select),
    );
  }
}

/// Troca de aba com um leve fade + escala, preservando o estado de cada aba.
class _TabLayer extends StatelessWidget {
  final bool active;
  final Widget child;

  const _TabLayer({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    final d = SMotion.of(context, SMotion.medium);
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: d,
          curve: SMotion.standard,
          child: AnimatedScale(
            scale: active ? 1 : 0.985,
            duration: d,
            curve: SMotion.emphasized,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Barra inferior flutuante com indicador que desliza até a aba ativa.
class StarlitNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const StarlitNavBar({super.key, required this.index, required this.onSelect});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Amigos'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = SMotion.of(context, SMotion.medium);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: SC.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(SRadius.xl),
          border: Border.all(color: SC.outline.withValues(alpha: 0.5)),
          boxShadow: SShadow.raised,
        ),
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / _items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: d,
                  curve: SMotion.emphasized,
                  left: w * index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: SC.buttonGradient,
                      borderRadius: BorderRadius.circular(SRadius.lg),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: i == index,
                          button: true,
                          label: _items[i].$3,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(i),
                            child: AnimatedDefaultTextStyle(
                              duration: d,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: i == index ? Colors.white : SC.textFaint,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: SMotion.of(context, SMotion.quick),
                                    child: Icon(
                                      i == index ? _items[i].$2 : _items[i].$1,
                                      key: ValueKey(i == index),
                                      color: i == index ? Colors.white : SC.textFaint,
                                      size: 23,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  ExcludeSemantics(child: Text(_items[i].$3)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Aba inicial: saudação, busca, filmes do TMDB e reviews da comunidade.
class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;

  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;

  Future<List<TmdbMovie>>? _nowPlaying;
  Future<List<TmdbMovie>>? _upcoming;
  Future<List<TmdbMovie>>? _trending;
  Future<List<TmdbMovie>>? _searchResults;

  String get _query => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _loadFeed();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _loadMovies() {
    if (!AppConfig.hasTmdb) return;
    final tmdb = TmdbService.instance;
    _nowPlaying = tmdb.nowPlaying();
    _upcoming = tmdb.upcoming();
    _trending = tmdb.trending();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = _reviews.isEmpty;
      _error = null;
    });
    try {
      final reviews = await SupabaseService.instance.fetchFeed(search: _query);
      if (mounted) setState(() => _reviews = reviews);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchResults = (AppConfig.hasTmdb && _query.isNotEmpty)
            ? TmdbService.instance.search(_query)
            : null;
      });
      _loadFeed();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    _onSearchChanged('');
  }

  Future<void> _refreshAll() async {
    setState(_loadMovies);
    await _loadFeed();
  }

  void _openMovie(TmdbMovie movie, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MovieDetailPage(movie: movie, heroTag: heroTag)),
    ).then((_) => _loadFeed());
  }

  Future<void> _openReview(int index) async {
    final updated = await Navigator.push<Review?>(
      context,
      MaterialPageRoute(builder: (_) => ReviewDetailPage(review: _reviews[index])),
    );
    if (!mounted) return;
    setState(() {
      if (updated == null) {
        _reviews.removeAt(index);
      } else {
        _reviews[index] = updated;
      }
    });
  }

  Future<void> _newReview() async {
    if (await showNewReviewSheet(context)) _loadFeed();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Boa madrugada';
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final firstName = (auth.nome?.trim().isNotEmpty ?? false)
        ? auth.nome!.trim().split(' ').first
        : (auth.username ?? '');

    return SkyBackground(
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        color: SC.star,
        backgroundColor: SC.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Entrance(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(SSpace.page, 16, SSpace.page, 0),
                    child: Row(
                      children: [
                        Image.asset('assets/logoSmall.png', height: 34, width: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                firstName.isEmpty ? _greeting() : '${_greeting()},',
                                style: const TextStyle(color: SC.textMuted, fontSize: 13),
                              ),
                              if (firstName.isNotEmpty)
                                Text(
                                  firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: SC.text,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    height: 1.2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        UserAvatar(url: auth.avatar, radius: 20, ring: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Entrance(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(SSpace.page, 20, SSpace.page, 0),
                  child: AnimatedContainer(
                    duration: SMotion.of(context, SMotion.quick),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SRadius.lg),
                      boxShadow: _searchFocus.hasFocus ? SShadow.glowButton : null,
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(color: SC.text),
                      decoration: InputDecoration(
                        hintText: 'Buscar filmes e reviews',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _clearSearch,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SRadius.lg),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SRadius.lg),
                          borderSide: BorderSide(color: SC.outline.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SRadius.lg),
                          borderSide: const BorderSide(color: SC.star, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: SMotion.of(context, SMotion.medium),
                switchInCurve: SMotion.emphasized,
                child: _searchResults != null
                    ? MovieCarousel(
                        key: ValueKey('search-$_query'),
                        title: 'Filmes encontrados',
                        future: _searchResults!,
                        onTap: _openMovie,
                      )
                    : _nowPlaying == null
                        ? const SizedBox.shrink()
                        : Column(
                            key: const ValueKey('discover'),
                            children: [
                              MovieCarousel(
                                  title: 'Em cartaz', future: _nowPlaying!, onTap: _openMovie),
                              MovieCarousel(
                                title: 'Em breve',
                                future: _upcoming!,
                                onTap: _openMovie,
                                showReleaseDate: true,
                              ),
                              MovieCarousel(
                                  title: 'Em alta na semana',
                                  future: _trending!,
                                  onTap: _openMovie),
                            ],
                          ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Reviews da comunidade',
                trailing: TextButton.icon(
                  onPressed: _newReview,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Escrever'),
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(child: ReviewGridSkeleton())
            else if (_error != null)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não foi possível carregar as reviews',
                  message: _error,
                  actionLabel: 'Tentar novamente',
                  onAction: _loadFeed,
                ),
              )
            else if (_reviews.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.rate_review_rounded,
                  title: _query.isEmpty
                      ? 'Ainda não há reviews'
                      : 'Nada encontrado para "$_query"',
                  message: _query.isEmpty
                      ? 'Escolha um filme que você viu e conte o que achou.'
                      : 'Tente outro título ou escreva a primeira review dele.',
                  actionLabel: 'Escrever review',
                  onAction: _newReview,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: SSpace.page),
                sliver: SliverGrid.builder(
                  gridDelegate: reviewGridDelegate,
                  itemCount: _reviews.length,
                  itemBuilder: (context, i) => Entrance(
                    key: ValueKey(_reviews[i].id),
                    index: i,
                    child: ReviewCard(review: _reviews[i], onTap: () => _openReview(i)),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}
