// lib/widgets/crossfade_background.dart
import 'dart:async';
import 'package:flutter/material.dart';

class CrossfadeBackground extends StatefulWidget {
  final List<String> images;
  final int intervalMs;

  const CrossfadeBackground({
    super.key,
    required this.images,
    this.intervalMs = 4000,
  });

  @override
  State<CrossfadeBackground> createState() => _CrossfadeBackgroundState();
}

class _CrossfadeBackgroundState extends State<CrossfadeBackground> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer =
          Timer.periodic(Duration(milliseconds: widget.intervalMs), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.images.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1000),
      child: Image.network(
        widget.images[_currentIndex],
        key: ValueKey<int>(_currentIndex),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.black26),
      ),
    );
  }
}
