import 'dart:async';

import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlitfilms/components/movie_carousel.dart';
import 'package:starlitfilms/components/new_review_sheet.dart';
import 'package:starlitfilms/config.dart';
import 'package:starlitfilms/models/movie.dart';
import 'package:starlitfilms/screens/filme.dart';
import 'package:starlitfilms/services/tmdb_service.dart';
import 'package:starlitfilms/components/review_card.dart';
import 'package:starlitfilms/controllers/authProvider.dart';
import 'package:starlitfilms/models/review.dart';
import 'package:starlitfilms/screens/Perfil/perfil.dart';
import 'package:starlitfilms/screens/amigos.dart';
import 'package:starlitfilms/screens/review.dart';
import 'package:starlitfilms/services/supabase_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _controller = NotchBottomBarController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;

  Future<List<TmdbMovie>>? _nowPlaying;
  Future<List<TmdbMovie>>? _upcoming;
  Future<List<TmdbMovie>>? _trending;
  Future<List<TmdbMovie>>? _searchResults;

  void _loadMovies() {
    if (!AppConfig.hasTmdb) return;
    final tmdb = TmdbService.instance;
    _nowPlaying = tmdb.nowPlaying();
    _upcoming = tmdb.upcoming();
    _trending = tmdb.trending();
  }

  void _openMovie(TmdbMovie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
    ).then((_) => _loadFeed());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.profile == null) auth.loadProfile();
    });
    _loadMovies();
    _loadFeed();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = _reviews.isEmpty;
      _error = null;
    });
    try {
      final reviews = await SupabaseService.instance
          .fetchFeed(search: _searchController.text);
      if (mounted) setState(() => _reviews = reviews);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final q = _searchController.text.trim();
      setState(() {
        _searchResults = (AppConfig.hasTmdb && q.isNotEmpty)
            ? TmdbService.instance.search(q)
            : null;
      });
      _loadFeed();
    });
  }

  Future<void> _refreshAll() async {
    setState(_loadMovies);
    await _loadFeed();
  }

  Future<void> _openReview(int index) async {
    final updated = await Navigator.push<Review?>(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewDetailPage(review: _reviews[index]),
      ),
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPage(int index) {
    switch (index) {
      case 1:
        return const Perfil();
      case 2:
        return const AmigosPage();
      default:
        return _homePageContent();
    }
  }

  Widget _homePageContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A1266), Color(0xFF150B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 60),
            const Center(
              child: Text(
                'StarlitFilms',
                style: TextStyle(
                  fontFamily: "Poppins",
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF35286D).withOpacity(0.5),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0),
                      child: Icon(Icons.search, color: Colors.white),
                    ),
                    hintText: 'Buscar filme',
                    hintStyle: const TextStyle(
                      color: Colors.white,
                      fontFamily: "Poppins",
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_searchResults != null)
              MovieCarousel(
                title: 'Filmes encontrados',
                future: _searchResults!,
                onTap: _openMovie,
              )
            else if (_nowPlaying != null) ...[
              MovieCarousel(
                title: 'Em cartaz',
                future: _nowPlaying!,
                onTap: _openMovie,
              ),
              MovieCarousel(
                title: 'Em breve',
                future: _upcoming!,
                onTap: _openMovie,
                showReleaseDate: true,
              ),
              MovieCarousel(
                title: 'Em alta na semana',
                future: _trending!,
                onTap: _openMovie,
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 30, right: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Reviews da comunidade',
                      style: TextStyle(
                        fontFamily: "Poppins",
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _newReview,
                    icon: const Icon(Icons.add, color: Color(0xff9670F5)),
                    label: const Text('Nova review',
                        style: TextStyle(color: Color(0xff9670F5))),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _message(_error!, action: 'Tentar novamente', onAction: _loadFeed)
            else if (_reviews.isEmpty)
              _message(
                _searchController.text.isEmpty
                    ? 'Ainda não há reviews. Que tal escrever a primeira?'
                    : 'Nenhuma review encontrada para "${_searchController.text}".',
                action: _searchController.text.isEmpty ? 'Escrever review' : null,
                onAction: _newReview,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) => ReviewCard(
                    review: _reviews[index],
                    onTap: () => _openReview(index),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          if (action != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff7E56E4)),
              child: Text(action, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _selectedIndex == 1 
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 100,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(10, 15, 0, 0),
                child: Image.asset(
                  'assets/logoSmall.png',
                  height: 50,
                  width: 50,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: _getPage(_selectedIndex),
      extendBody: true,
      bottomNavigationBar: AnimatedNotchBottomBar(
        notchBottomBarController: _controller,
        bottomBarItems: [
          BottomBarItem(
            inActiveItem: Image.asset(
              'assets/home_icon.png',
              width: 30,
              height: 30,
            ),
            activeItem: Image.asset(
              'assets/home_icon.png',
              width: 30,
              height: 30,
            ),
            itemLabel: 'Home',
          ),
          BottomBarItem(
            inActiveItem: Image.asset(
              'assets/perfil_icon.png',
              width: 30,
              height: 30,
            ),
            activeItem: Image.asset(
              'assets/perfil_icon.png',
              width: 30,
              height: 30,
            ),
            itemLabel: 'Perfil',
          ),
          BottomBarItem(
            inActiveItem: Image.asset(
              'assets/amigos_icon.png',
              width: 50,
              height: 50,
            ),
            activeItem: Image.asset(
              'assets/amigos_icon.png',
              width: 50,
              height: 50,
            ),
            itemLabel: 'Amigos',
          ),
        ],
        onTap: _onItemTapped,
        notchColor: const Color(0xFF42326A),
        showLabel: false,
        itemLabelStyle: const TextStyle(
          fontSize: 16.0,
        ),
        bottomBarHeight: 20.0,
        elevation: 8.0,
        color: const Color(0xff2C2247),
        durationInMilliSeconds: 200,
        showBlurBottomBar: false,
        kBottomRadius: 40,
        kIconSize: 24,
      ),
    );
  }
}

