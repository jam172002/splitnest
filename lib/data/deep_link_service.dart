import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Listens for `splitnest://join?code=<groupId>` links (shared from the
/// group invite sheet via the OS share sheet) and routes them into the
/// existing join-group flow. Mobile/desktop only — on web the browser URL
/// already goes straight through go_router, no custom scheme needed.
class DeepLinkService {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> init(void Function(String path) navigate) async {
    if (kIsWeb) return;

    try {
      final initial = await _appLinks.getInitialLink();
      _handle(initial, navigate);
    } catch (_) {
      // No initial link, or platform doesn't support it — ignore.
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, navigate),
      onError: (_) {},
    );
  }

  void _handle(Uri? uri, void Function(String path) navigate) {
    if (uri == null) return;
    if (uri.scheme != 'splitnest' || uri.host != 'join') return;

    final code = uri.queryParameters['code'] ??
        (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null);
    if (code == null || code.isEmpty) return;

    navigate('/join-group?code=$code');
  }

  void dispose() {
    _sub?.cancel();
  }
}
