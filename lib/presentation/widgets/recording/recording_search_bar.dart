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
    this.hintText = 'Titles, Transcripts',
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
        color: Colors.grey[800]?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[400],
            size: 20,
          ),
          suffixIcon: widget.showVoiceIcon
              ? GestureDetector(
                  onTap: widget.onVoiceSearch,
                  child: Icon(
                    Icons.mic,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                )
              : _controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _controller.clear();
                        widget.onSearchChanged('');
                      },
                      child: Icon(
                        Icons.clear,
                        color: Colors.grey[400],
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