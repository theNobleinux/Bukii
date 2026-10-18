import 'package:flutter/material.dart';

const _orange = Color(0xFFF04B16);
const _ink = Color(0xFF25231F);
const _paper = Color(0xFFFBF9F6);

enum _LibraryTab { explore, bookings, history, profile }

class _Book {
  const _Book({
    required this.title,
    required this.author,
    required this.genre,
    required this.colors,
    required this.icon,
    this.progress = 0,
  });

  final String title;
  final String author;
  final String genre;
  final List<Color> colors;
  final IconData icon;
  final double progress;
}

const _books = [
  _Book(
    title: 'The Quiet Between',
    author: 'Mira Ellery',
    genre: 'Fiction',
    colors: [Color(0xFF8AA39A), Color(0xFF435C56)],
    icon: Icons.waves_rounded,
    progress: 0.42,
  ),
  _Book(
    title: 'Small Hours',
    author: 'Noah Winters',
    genre: 'Romance',
    colors: [Color(0xFFF1B7A1), Color(0xFFD87456)],
    icon: Icons.wb_twilight_rounded,
  ),
  _Book(
    title: 'A Map of Elsewhere',
    author: 'Leonie Hart',
    genre: 'Fantasy',
    colors: [Color(0xFFB6A4D1), Color(0xFF67577F)],
    icon: Icons.auto_awesome_rounded,
  ),
  _Book(
    title: 'Wildflower Season',
    author: 'June Parker',
    genre: 'Fiction',
    colors: [Color(0xFFE6C982), Color(0xFFAE7449)],
    icon: Icons.local_florist_rounded,
  ),
  _Book(
    title: 'The Long Way Home',
    author: 'Sam Rivera',
    genre: 'Adventure',
    colors: [Color(0xFF86A9C0), Color(0xFF42677D)],
    icon: Icons.nights_stay_rounded,
  ),
];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  final Set<String> _savedTitles = {'A Map of Elsewhere'};
  _LibraryTab _selectedTab = _LibraryTab.explore;
  String _selectedGenre = 'All';
  String _query = '';
  double _readingProgress = 0.42;

  static const _genres = ['All', 'Fiction', 'Romance', 'Fantasy', 'Adventure'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Book> get _visibleBooks {
    Iterable<_Book> books = _books;
    if (_selectedTab == _LibraryTab.history ||
        _selectedTab == _LibraryTab.profile) {
      books = books.where((book) => _savedTitles.contains(book.title));
    }
    if (_selectedGenre != 'All') {
      books = books.where((book) => book.genre == _selectedGenre);
    }
    if (_query.isNotEmpty) {
      final query = _query.toLowerCase();
      books = books.where(
        (book) =>
            book.title.toLowerCase().contains(query) ||
            book.author.toLowerCase().contains(query) ||
            book.genre.toLowerCase().contains(query),
      );
    }
    return books.toList();
  }

  void _toggleSaved(_Book book) {
    setState(() {
      if (!_savedTitles.add(book.title)) {
        _savedTitles.remove(book.title);
      }
    });
  }

  void _showBook(_Book book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D4CD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BookCover(book: book, width: 112, height: 150),

                  const SizedBox(width: 20),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.genre.toUpperCase(),
                          style: const TextStyle(
                            color: _orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          book.title,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'by ${book.author}',
                          style: const TextStyle(
                            color: Color(0xFF77716A),
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          'A lovely story to get lost in. Find a quiet moment and pick up where your imagination takes you.',
                          style: TextStyle(
                            color: Color(0xFF625D56),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (book.title == _books.first.title) {
                      setState(() => _readingProgress = 0.52);
                    } else {
                      _toggleSaved(book);
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          book.title == _books.first.title
                              ? 'Welcome back to ${book.title}.'
                              : '${book.title} added to your reading list.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(
                    book.title == _books.first.title
                        ? Icons.menu_book_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    book.title == _books.first.title
                        ? 'Continue reading'
                        : 'Add to reading list',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedTab == _LibraryTab.explore;
    final isBookings = _selectedTab == _LibraryTab.bookings;
    final title = switch (_selectedTab) {
      _LibraryTab.explore => 'Your little library',
      _LibraryTab.bookings => 'Find your next read',
      _LibraryTab.history => 'Your reading history',
      _LibraryTab.profile => 'Your profile',
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'Bukii',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3EDE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: _ink,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHome ? 'SUNDAY, OCTOBER 18' : 'A WORLD OF STORIES',
                      style: const TextStyle(
                        color: Color(0xFF8B837A),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Books, authors, moods...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9B958E),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF817B73),
                          size: 21,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEDE8E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEDE8E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: _orange,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isHome && _query.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: _ContinueReadingCard(
                    progress: _readingProgress,
                    onTap: () => _showBook(_books.first),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isNotEmpty
                            ? 'Search results'
                            : _selectedTab == _LibraryTab.history ||
                                  _selectedTab == _LibraryTab.profile
                            ? 'Saved for later'
                            : isBookings
                            ? 'Explore by genre'
                            : 'Made for your shelf',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    if (_selectedTab != _LibraryTab.history &&
                        _selectedTab != _LibraryTab.profile &&
                        _query.isEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedTab = _LibraryTab.bookings;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: _orange,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('See all'),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _genres.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      final selected = _selectedGenre == genre;
                      return ChoiceChip(
                        label: Text(genre),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedGenre = genre),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF716B64),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: _ink,
                        side: BorderSide(
                          color: selected ? _ink : const Color(0xFFEAE5DE),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_visibleBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_stories_outlined,
                          size: 42,
                          color: Color(0xFFB0A79D),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (_selectedTab == _LibraryTab.history ||
                                      _selectedTab == _LibraryTab.profile) &&
                                  _query.isEmpty
                              ? 'Your saved shelf is waiting.'
                              : 'No books found. Try another search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF77716A),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 230,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _visibleBooks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final book = _visibleBooks[index];
                        return _BookCard(
                          book: book,
                          isSaved: _savedTitles.contains(book.title),
                          onTap: () => _showBook(book),
                          onSave: () => _toggleSaved(book),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? _orange : const Color(0xFF686868),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _orange : const Color(0xFF686868),
              size: 25,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTab.index,
          onDestinationSelected: (index) => setState(() {
            _selectedTab = _LibraryTab.values[index];
            _selectedGenre = 'All';
            _query = '';
            _searchController.clear();
          }),
          backgroundColor: Colors.white,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_outlined),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_outlined),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.progress, required this.onTap});

  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final book = _books.first;
    return Material(
      color: const Color(0xFF293D39),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 174,
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -22,
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _BookCover(book: book, width: 92, height: 132),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'PICK UP WHERE YOU LEFT OFF',
                            style: TextStyle(
                              color: Color(0xFFC8D7CF),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.author,
                            style: const TextStyle(
                              color: Color(0xFFD0D8D3),
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    color: const Color(0xFFFFB08F),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 19,
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

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.isSaved,
    required this.onTap,
    required this.onSave,
  });

  final _Book book;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onTap,
                child: _BookCover(book: book, width: 138, height: 174),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: onSave,
                  tooltip: isSaved ? 'Remove from saved' : 'Save book',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.93),
                    foregroundColor: isSaved ? _orange : _ink,
                    minimumSize: const Size(34, 34),
                    maximumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF89827A), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.book,
    required this.width,
    required this.height,
  });

  final _Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: book.colors,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A25231F),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -22,
            bottom: -28,
            child: Icon(
              book.icon,
              size: height * 0.88,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              width * 0.13,
              height * 0.13,
              width * 0.1,
              height * 0.1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const Spacer(),
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width < 120 ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                    letterSpacing: -0.2,
                    shadows: const [
                      Shadow(color: Color(0x33000000), blurRadius: 5),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  book.author.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
