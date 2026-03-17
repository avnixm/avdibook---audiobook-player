import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaControlBridge {
  MediaControlBridge(this.ref);

  final Ref ref;

  Future<void> initialize() async {
    // Placeholder bridge.
    // Next step: integrate BaseAudioHandler and map playerProvider state.
  }

  Future<void> dispose() async {
    // No-op for now.
  }
}
