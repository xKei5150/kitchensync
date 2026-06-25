import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// Screen 28 · Works on the subway.
///
/// Watches real connectivity and pins [OfflineBanner] above the app when the
/// device drops offline. KitchenSync is offline-first — Firestore keeps cached
/// shelves fully readable and queues edits locally — so being offline is a
/// fact, not a failure. The banner says so calmly and gets out of the way.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({required this.child, super.key});

  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final offline = !results.any(_isOnline);
      if (mounted && offline != _offline) {
        setState(() => _offline = offline);
      }
    });
    unawaited(_initialCheck());
  }

  Future<void> _initialCheck() async {
    final results = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() => _offline = !results.any(_isOnline));
    }
  }

  bool _isOnline(ConnectivityResult r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.vpn;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_offline) const OfflineBanner(),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// The offline notice itself — warm-brown ([KsTokens.lowStock]) and
/// *informational*, never alarm red. A conflict or a true sync failure wears
/// red; being offline is neither. Split out from [ConnectivityBanner] so the
/// copy and treatment are testable without the connectivity plugin.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const Color _accent = KsTokens.lowStock;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Color.alphaBlend(
        _accent.withValues(alpha: 0.12),
        ks.surfaceRaised,
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _accent, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: KsTokens.space16,
            vertical: KsTokens.space10,
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 18, color: _accent),
              const SizedBox(width: KsTokens.space10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're offline",
                      style: KsTokens.titleSmall.copyWith(
                        color: Color.alphaBlend(
                          _accent.withValues(alpha: 0.85),
                          ks.textPrimary,
                        ),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Edits are saved here and sync when you’re back.',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
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
