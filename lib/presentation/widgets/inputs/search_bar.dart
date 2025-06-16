// File: presentation/widgets/inputs/search_bar.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_constants.dart';

/// Custom search bar widget for searching recordings and folders
///
/// Features debouncing, filtering options, and smooth animations.
/// Integrates with the app's design system and provides callbacks for search events.
class CustomSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearchChanged;
  final Function(String)? onSearchSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClearTap;
  final bool showFilterButton;
  final bool autofocus;
  final String initialValue;
  final Duration debounceTime;

  const CustomSearchBar({
    super.key,
    this.hintText = 'Search recordings...',
    required this.onSearchChanged,
    this.onSearchSubmitted,
    this.onFilterTap,
    this.onClearTap,
    this.showFilterButton = true,
    this.autofocus = false,
    this.initialValue = '',
    this.debounceTime = const Duration(milliseconds: 500),
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar>
    with SingleTickerProviderStateMixin {

  late TextEditingController _controller;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _debounceTimer;
  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialValue);
    _hasText = widget.initialValue.isNotEmpty;

    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _controller.addListener(_onTextChanged);
    _animationController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }

    // Debounce search
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceTime, () {
      widget.onSearchChanged(_controller.text);
    });
  }

  void _onSubmitted(String value) {
    widget.onSearchSubmitted?.call(value);
  }

  void _onFocusChanged(bool focused) {
    setState(() {
      _isFocused = focused;
    });

    if (focused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _clearSearch() {
    _controller.clear();
    widget.onClearTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppConstants.surfacePurple.withValues(alpha: 0.8),
                    AppConstants.backgroundDark.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
                border: Border.all(
                  color: _isFocused
                      ? AppConstants.accentCyan.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                  width: _isFocused ? 2 : 1,
                ),
                boxShadow: _isFocused
                    ? [
                  BoxShadow(
                    color: AppConstants.accentCyan.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Search icon
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(
                      Icons.search,
                      color: _isFocused
                          ? AppConstants.accentCyan
                          : Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),

                  // Text field
                  Expanded(
                    child: Focus(
                      onFocusChange: _onFocusChanged,
                      child: TextField(
                        controller: _controller,
                        autofocus: widget.autofocus,
                        onSubmitted: _onSubmitted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),

                  // Clear button
                  if (_hasText)
                    AnimatedOpacity(
                      opacity: _hasText ? 1.0 : 0.0,
                      duration: AppConstants.shortAnimationDuration,
                      child: GestureDetector(
                        onTap: _clearSearch,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Filter button
                  if (widget.showFilterButton)
                    GestureDetector(
                      onTap: widget.onFilterTap,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryPink.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppConstants.primaryPink.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: AppConstants.primaryPink,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated search results widget
class SearchResults extends StatefulWidget {
  final List<SearchResultItem> results;
  final bool isLoading;
  final String query;
  final VoidCallback? onLoadMore;
  final Widget Function(SearchResultItem) itemBuilder;

  const SearchResults({
    super.key,
    required this.results,
    this.isLoading = false,
    required this.query,
    this.onLoadMore,
    required this.itemBuilder,
  });

  @override
  State<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<SearchResults>
    with TickerProviderStateMixin {

  late AnimationController _listAnimationController;
  List<AnimationController> _itemControllers = [];

  @override
  void initState() {
    super.initState();

    _listAnimationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );

    _setupItemAnimations();
    _listAnimationController.forward();
  }

  @override
  void didUpdateWidget(SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.results.length != oldWidget.results.length) {
      _setupItemAnimations();
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupItemAnimations() {
    // Dispose old controllers
    for (final controller in _itemControllers) {
      controller.dispose();
    }

    // Create new controllers
    _itemControllers = List.generate(
      widget.results.length,
          (index) => AnimationController(
        duration: Duration(milliseconds: 200 + (index * 50)),
        vsync: this,
      ),
    );

    // Start animations with stagger
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          _itemControllers[i].forward();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.results.isEmpty && widget.query.isNotEmpty) {
      return _buildEmptyState();
    }

    return _buildResultsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppConstants.accentCyan,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Searching...',
            style: AppConstants.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: AppConstants.titleMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: AppConstants.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: widget.results.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.results.length) {
          return _buildLoadMoreIndicator();
        }

        final item = widget.results[index];
        final controller = _itemControllers[index];

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - controller.value) * 50),
              child: Opacity(
                opacity: controller.value,
                child: widget.itemBuilder(item),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: GestureDetector(
          onTap: widget.onLoadMore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppConstants.accentCyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppConstants.accentCyan.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Load More',
              style: TextStyle(
                color: AppConstants.accentCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Search result item data class
class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'recording' or 'folder'
  final dynamic data; // Original entity data

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.data,
  });
}

/// Search filter options
class SearchFilter {
  final String? folderId;
  final List<String>? formats;
  final DateRange? dateRange;
  final DurationRange? durationRange;
  final bool? onlyFavorites;

  const SearchFilter({
    this.folderId,
    this.formats,
    this.dateRange,
    this.durationRange,
    this.onlyFavorites,
  });

  bool get hasActiveFilters =>
      folderId != null ||
          formats?.isNotEmpty == true ||
          dateRange != null ||
          durationRange != null ||
          onlyFavorites == true;
}

/// Date range for filtering
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({
    required this.start,
    required this.end,
  });
}

/// Duration range for filtering
class DurationRange {
  final Duration min;
  final Duration max;

  const DurationRange({
    required this.min,
    required this.max,
  });
}