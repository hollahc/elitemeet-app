import 'package:flutter/material.dart';

/// Loading overlay shown over the WebView until the first page finishes.
/// Placeholder logo asset — swap `assets/branding/logo.png` with the real
/// EliteMeet mark; see docs/SETUP.md.
class AppLoading extends StatelessWidget {
  final int progress;

  const AppLoading({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/branding/logo.png',
            width: 96,
            height: 96,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.favorite_rounded,
              size: 64,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              value: progress > 0 ? progress / 100 : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
