// File: presentation/widgets/recording/recording_search_bar.dart
import 'package:flutter/material.dart';

/// Search bar widget for filtering recordings
class RecordingSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearchChanged;
  final VoidCallback? onVoiceSearch;
  final bool showVoiceIcon;

  const RecordingSearchBar({
    Key? key,
    this.hintText = 'Titles',
    required this.onSearchChanged,
    this.onVoiceSearch,
    this.showVoiceIcon = true,
  }) : super(key: key);

  @override
  State<RecordingSearchBar> createState() => _RecordingSearchBarState();
}

class _RecordingSearchBarState extends State<RecordingSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8E2DE2), // Recording card purple
            Color(0xFFDA22FF), // Recording card magenta
            Color(0xFFFF4E50), // Recording card coral
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          color: Color(0xFFF3E8FF), // Light cosmic purple
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFD1C4E9), // Mystic light purple
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFFA855F7), // Ethereal purple
            size: 20,
          ),
          suffixIcon: widget.showVoiceIcon
              ? GestureDetector(
                  onTap: widget.onVoiceSearch,
                  child: const Icon(
                    Icons.mic,
                    color: Color(0xFFA855F7), // Ethereal purple
                    size: 20,
                  ),
                )
              : _controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _controller.clear();
                        widget.onSearchChanged('');
                      },
                      child: const Icon(
                        Icons.clear,
                        color: Color(0xFFA855F7), // Ethereal purple
                        size: 20,
                      ),
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          widget.onSearchChanged(value);
          setState(() {}); // Rebuild to show/hide clear button
        },
      ),
    );
  }
}