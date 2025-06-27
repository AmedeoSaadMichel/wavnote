// File: presentation/widgets/common/skeleton_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '/core/utils/performance_logger.dart';

/// Skeleton loading screen that mimics the main app content
/// 
/// Shows a fake version of the main screen while the real content loads.
/// Provides better user experience than a loading spinner.
class SkeletonScreen extends StatefulWidget {
  const SkeletonScreen({super.key});

  @override
  State<SkeletonScreen> createState() => _SkeletonScreenState();
}

class _SkeletonScreenState extends State<SkeletonScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Match splash screen color exactly
          color: Color(0xFF8E2DE2),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildSkeletonHeader(),

              // Folders List Section
              Expanded(
                child: _buildSkeletonFolders(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build skeleton header that mimics the real header
  Widget _buildSkeletonHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Main header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // App title skeleton
                  _buildShimmerBox(
                    width: 140,
                    height: 24,
                    color: Colors.yellowAccent.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  // Format selector skeleton
                  _buildShimmerBox(
                    width: 60,
                    height: 24,
                    borderRadius: 16,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ],
              ),
              // Edit button skeleton
              _buildShimmerBox(
                width: 50,
                height: 32,
                borderRadius: 16,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build skeleton folders that mimic the real folder list
  Widget _buildSkeletonFolders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Default folders (always 3)
          ...List.generate(3, (index) => _buildSkeletonFolderItem()),
          
          const SizedBox(height: 20),
          
          // Custom folders section header
          Align(
            alignment: Alignment.centerLeft,
            child: _buildShimmerBox(
              width: 100,
              height: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Custom folders (1-2 fake ones)
          ...List.generate(2, (index) => _buildSkeletonFolderItem()),
          
          const Spacer(),
          
          // Add folder button skeleton
          _buildSkeletonAddButton(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Build a single skeleton folder item
  Widget _buildSkeletonFolderItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Folder icon skeleton
          _buildShimmerBox(
            width: 40,
            height: 40,
            borderRadius: 20,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          
          const SizedBox(width: 12),
          
          // Folder details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folder name skeleton
                _buildShimmerBox(
                  width: double.infinity,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                
                const SizedBox(height: 6),
                
                // Recording count skeleton
                _buildShimmerBox(
                  width: 80,
                  height: 14,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
          
          // Chevron icon skeleton
          _buildShimmerBox(
            width: 20,
            height: 20,
            borderRadius: 10,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  /// Build skeleton add folder button
  Widget _buildSkeletonAddButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildShimmerBox(
            width: 20,
            height: 20,
            borderRadius: 10,
            color: Colors.yellowAccent.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8),
          _buildShimmerBox(
            width: 80,
            height: 16,
            color: Colors.yellowAccent.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  /// Build a shimmer box with animation
  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _shimmerAnimation.value - 0.3,
                _shimmerAnimation.value,
                _shimmerAnimation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
              colors: [
                color,
                color.withValues(alpha: (color.a * 1.5).clamp(0.0, 1.0)),
                color,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Simple skeleton screen without animation (for better performance)
class SimpleSkeletonScreen extends StatelessWidget {
  const SimpleSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Match splash screen color exactly
        color: const Color(0xFF8E2DE2),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App title
                    Container(
                      width: 140,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.yellowAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Edit button
                    Container(
                      width: 50,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Folder items
                ...List.generate(5, (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 80,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recording List Skeleton Screen
/// Shows skeleton placeholders for recording cards while loading
class RecordingListSkeleton extends StatefulWidget {
  final String folderName;

  const RecordingListSkeleton({
    super.key,
    required this.folderName,
  });

  @override
  State<RecordingListSkeleton> createState() => _RecordingListSkeletonState();
}

class _RecordingListSkeletonState extends State<RecordingListSkeleton>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('💀 VERBOSE: RecordingListSkeleton build() called for folder: ${widget.folderName}');
    PerformanceLogger.logRebuild('RecordingListSkeleton');
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8E2DE2), // Recording card purple
            Color(0xFFDA22FF), // Recording card magenta
            Color(0xFFFF4E50), // Recording card coral
          ],
        ),
      ),
      child: Column(
        children: [
          // Header skeleton
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Back button skeleton
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Folder name
                  Text(
                    widget.folderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Format button skeleton
                  Container(
                    width: 50,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit button skeleton
                  Container(
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Recording cards skeleton
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 8, // Show 8 skeleton cards
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSkeletonRecordingCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRecordingCard() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Shimmer effect
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Transform.translate(
                    offset: Offset(_shimmerAnimation.value * 200, 0),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Card content skeleton
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Play button skeleton
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Recording info skeleton
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title skeleton
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Duration skeleton
                          Container(
                            height: 12,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Actions skeleton
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}