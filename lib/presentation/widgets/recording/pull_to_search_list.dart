// File: presentation/widgets/recording/pull_to_search_list.dart
import 'package:flutter/material.dart';
import 'recording_search_bar.dart';

/// List widget with pull-to-reveal search functionality
class PullToSearchList extends StatefulWidget {
  final Widget Function(BuildContext, int) itemBuilder;
  final int itemCount;
  final Function(String) onSearchChanged;
  final String searchQuery;
  final Widget? emptyState;
  final EdgeInsets? padding;

  const PullToSearchList({
    Key? key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onSearchChanged,
    this.searchQuery = '',
    this.emptyState,
    this.padding,
  }) : super(key: key);

  @override
  State<PullToSearchList> createState() => _PullToSearchListState();
}

class _PullToSearchListState extends State<PullToSearchList>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _searchBarController;
  late Animation<double> _searchBarAnimation;
  
  bool _isSearchVisible = false;
  double _searchBarHeight = 0;
  static const double _maxSearchBarHeight = 60.0;

  @override
  void initState() {
    super.initState();
    
    _searchBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchBarController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchBarController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    
    // Show search bar when pulling down beyond the top
    if (offset < -30 && !_isSearchVisible) {
      _showSearchBar();
    }
    // Hide search bar when scrolling back up (only if no search query)
    else if (offset > 10 && _isSearchVisible && widget.searchQuery.isEmpty) {
      _hideSearchBar();
    }
  }

  void _showSearchBar() {
    if (_isSearchVisible) return;
    
    setState(() {
      _isSearchVisible = true;
      _searchBarHeight = _maxSearchBarHeight;
    });
    _searchBarController.forward();
  }

  void _hideSearchBar() {
    setState(() {
      _isSearchVisible = false;
      _searchBarHeight = 0;
    });
    _searchBarController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0 && widget.emptyState != null) {
      return widget.emptyState!;
    }

    return Column(
      children: [
        // Search bar that appears/disappears
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _searchBarHeight,
          child: _isSearchVisible
              ? RecordingSearchBar(
                  onSearchChanged: widget.onSearchChanged,
                  onVoiceSearch: () {
                    print('🎤 Voice search tapped');
                  },
                )
              : const SizedBox.shrink(),
        ),
        
        // Main list content
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8),
            itemCount: widget.itemCount,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemBuilder: widget.itemBuilder,
          ),
        ),
      ],
    );
  }
}