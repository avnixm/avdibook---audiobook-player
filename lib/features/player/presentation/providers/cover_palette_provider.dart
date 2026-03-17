import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../shared/providers/library_provider.dart';

/// Extracts the dominant color from a book's cover art file.
///
/// Returns `null` when:
/// - The book has no [Audiobook.coverPath]
/// - The cover file does not exist on disk
/// - Palette generation fails
final coverPaletteProvider =
  FutureProvider.family<Color?, String>((ref, bookId) async {
  final library = ref.read(libraryProvider);
  final matching = library.where((b) => b.id == bookId);
  if (matching.isEmpty) return null;

  final coverPath = matching.first.coverPath;
  if (coverPath == null) return null;

  final file = File(coverPath);
  if (!file.existsSync()) return null;

  try {
    final palette = await PaletteGenerator.fromImageProvider(
      FileImage(file),
        size: const Size(120, 120),
      maximumColorCount: 20,
    );
    return palette.vibrantColor?.color ??
        palette.dominantColor?.color;
  } catch (_) {
    return null;
  }
});
