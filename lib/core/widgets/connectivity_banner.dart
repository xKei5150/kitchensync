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
  Timer? _onlineBannerTimer;
  bool _offline = false;
  bool _offlineBannerDismissed = false;
  bool _showOnlineBanner = false;

  @override
  void initState() {
    super.initState();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final offline = !results.any(_isOnline);
      if (mounted && offline != _offline) {
        _setOffline(offline);
      }
    });
    unawaited(_initialCheck());
  }

  Future<void> _initialCheck() async {
    final results = await _connectivity.checkConnectivity();
    if (mounted) {
      _setOffline(!results.any(_isOnline), initial: true);
    }
  }

  void _setOffline(bool offline, {bool initial = false}) {
    _onlineBannerTimer?.cancel();
    setState(() {
      _offline = offline;
      if (offline) {
        _offlineBannerDismissed = false;
        _showOnlineBanner = false;
      } else {
        _offlineBannerDismissed = false;
        _showOnlineBanner = !initial;
      }
    });
    if (!offline && !initial) {
      _onlineBannerTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showOnlineBanner = false);
      });
    }
  }

  bool _isOnline(ConnectivityResult r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.vpn;

  @override
  void dispose() {
    _onlineBannerTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_offline && !_offlineBannerDismissed)
          Align(
            alignment: Alignment.topCenter,
            child: OfflineBanner(
              onDismiss: () => setState(() => _offlineBannerDismissed = true),
            ),
          )
        else if (_offline)
          const Align(alignment: Alignment.topRight, child: OfflineIndicator())
        else if (_showOnlineBanner)
          Align(
            alignment: Alignment.topCenter,
            child: OnlineBanner(
              onDismiss: () {
                _onlineBannerTimer?.cancel();
                setState(() => _showOnlineBanner = false);
              },
            ),
          ),
      ],
    );
  }
}

/// The offline notice itself — warm-brown ([KsTokens.lowStock]) and
/// *informational*, never alarm red. A conflict or a true sync failure wears
/// red; being offline is neither. Split out from [ConnectivityBanner] so the
/// copy and treatment are testable without the connectivity plugin.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.onDismiss, super.key});

  static const Color _accent = KsTokens.lowStock;
  final VoidCallback? onDismiss;

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
              const SizedBox(width: KsTokens.space8),
              _BannerCloseButton(color: _accent, onDismiss: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}

class OnlineBanner extends StatelessWidget {
  const OnlineBanner({this.onDismiss, super.key});

  static const Color _accent = KsTokens.brandPrimary;
  final VoidCallback? onDismiss;

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
              const Icon(Icons.cloud_done_rounded, size: 18, color: _accent),
              const SizedBox(width: KsTokens.space10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're back online",
                      style: KsTokens.titleSmall.copyWith(
                        color: ks.brandPrimary,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Queued edits will sync in the background.',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              _BannerCloseButton(color: _accent, onDismiss: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  static const Color _accent = KsTokens.lowStock;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: KsTokens.space8,
          right: KsTokens.space12,
        ),
        child: Semantics(
          label: "You're offline",
          child: Material(
            color: Color.alphaBlend(
              _accent.withValues(alpha: 0.16),
              ks.surfaceRaised,
            ),
            shape: const CircleBorder(
              side: BorderSide(color: _accent, width: 0.75),
            ),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.cloud_off_rounded, size: 17, color: _accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCloseButton extends StatelessWidget {
  const _BannerCloseButton({required this.color, this.onDismiss});

  final Color color;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dismiss',
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onDismiss,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(Icons.close_rounded, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
