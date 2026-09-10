import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/track_model.dart';
import '../../providers/audio_provider.dart';
import '../../providers/lyrics_provider.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final Track track;

  const LyricsScreen({super.key, required this.track});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _followPlayback = true;

  @override
  void initState() {
    super.initState();
    ref.read(lyricsProvider.notifier).load(widget.track);
    ref.listen<LyricsState>(lyricsProvider, (previous, next) {
      if (_followPlayback &&
          next.currentLineIndex >= 0 &&
          next.currentLineIndex != previous?.currentLineIndex) {
        _scrollToCurrent(next.currentLineIndex);
      }
    });
  }

  void _scrollToCurrent(int index) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (index * 64.0).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final lyrics = lyricsState.trackId == widget.track.id ? lyricsState.lyrics : null;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        title: Text(
          'Lyrics',
          style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Return to current line',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: lyricsState.currentLineIndex < 0
                ? null
                : () {
                    setState(() => _followPlayback = true);
                    _scrollToCurrent(lyricsState.currentLineIndex);
                  },
          ),
        ],
      ),
      body: lyricsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : lyrics == null || lyrics.isEmpty
              ? Center(
                  child: Text(
                    'No local lyrics found',
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                )
              : lyrics.isSynced
                  ? NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction != ScrollDirection.idle) {
                          _followPlayback = false;
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                        itemCount: lyrics.lines.length,
                        itemExtent: 64,
                        itemBuilder: (context, index) {
                          final line = lyrics.lines[index];
                          final current = index == lyricsState.currentLineIndex;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => ref.read(audioProvider.notifier).seek(line.timestamp),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                line.text.isEmpty ? '♪' : line.text,
                                style: TextStyle(
                                  color: current
                                      ? (AppColors.isDark(context)
                                          ? AppColors.darkAccent
                                          : AppColors.buttonBlack)
                                      : AppColors.textSecondary(context),
                                  fontSize: current ? 19 : 16,
                                  fontWeight: current ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        lyrics.plainText ?? '',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ),
                    ),
    );
  }
}
