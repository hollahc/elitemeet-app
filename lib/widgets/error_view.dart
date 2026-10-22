import 'dart:async';

import 'package:flutter/material.dart';

/// Shown instead of the raw WebView or server error page, so users never see
/// browser/LiteSpeed/Cloudflare error screens. Two cases:
///   offline = true  → no internet on the phone
///   offline = false → internet is fine but EliteMeet couldn't be reached
/// While visible it retries on its own every few seconds.
class ErrorView extends StatefulWidget {
  final VoidCallback onRetry;
  final bool offline;

  const ErrorView({super.key, required this.onRetry, this.offline = true});

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  static const _bg = Color(0xFF091123);
  static const _pink = Color(0xFFE11D74);
  static const _purple = Color(0xFF7C3AED);

  Timer? _auto;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    // Quiet background retry; connectivity changes also trigger one.
    _auto = Timer.periodic(const Duration(seconds: 8), (_) => widget.onRetry());
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  Future<void> _tapRetry() async {
    setState(() => _retrying = true);
    widget.onRetry();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.offline;
    return Container(
      color: _bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/branding/icon.png', width: 84, height: 84, fit: BoxFit.cover),
          ),
          const SizedBox(height: 28),
          Icon(offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded, size: 34, color: Colors.white54),
          const SizedBox(height: 14),
          Text(
            offline ? "You're offline" : "We'll be right back",
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            offline
                ? 'Check your Wi-Fi or mobile data. EliteMeet will reconnect automatically as soon as you\'re back online.'
                : "EliteMeet is taking a moment to respond. We'll keep trying — you can also tap below.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _pink]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextButton(
                onPressed: _retrying ? null : _tapRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: _retrying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : const Text('Try again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
