import 'package:equatable/equatable.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook_author.dart';
import 'package:avdibook/features/audiobooks/domain/models/audiobook_chapter.dart';


enum BookStatus {
  newBook,
  started,
  finished;

  static BookStatus fromProgress(double progress) {
    final normalized = progress.clamp(0.0, 1.0);
    if (normalized >= 0.98) return BookStatus.finished;
    if (normalized > 0.01) return BookStatus.started;
    return BookStatus.newBook;
  }

  String get label => switch (this) {
        BookStatus.newBook => 'New',
        BookStatus.started => 'Started',
        BookStatus.finished => 'Finished',
      };
}

class Audiobook extends Equatable {
  const Audiobook({
    required this.id,
    required this.title,
    required this.chapters,
    required this.sourcePaths,
    required this.primaryFormat,
    required this.importedAt,
    this.author,
    this.narrator,
    this.description,
    this.coverPath,
    this.series,
    this.genre,
    this.progress = 0.0,
    this.resumePosition,
    this.lastPlayedAt,
    this.status = BookStatus.newBook,
    this.completedAt,
    this.preferredSpeed,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final AudiobookAuthor? author;
  final String? narrator;
  final String? description;
  final String? coverPath;
  final String? series;
  final String? genre;
  final List<AudiobookChapter> chapters;
  final List<String> sourcePaths;
  final String primaryFormat;
  final DateTime importedAt;
  final double progress;
  final Duration? resumePosition;
  final DateTime? lastPlayedAt;
  final BookStatus status;
  final DateTime? completedAt;
  final double? preferredSpeed;
  final bool isFavorite;

  bool get isSingleFile => sourcePaths.length == 1;
  int get chapterCount => chapters.length;
  bool get isFinished => status == BookStatus.finished;
  bool get hasProgress => progress > 0;

  Audiobook copyWith({
    String? id,
    String? title,
    AudiobookAuthor? author,
    bool clearAuthor = false,
    String? narrator,
    bool clearNarrator = false,
    String? description,
    bool clearDescription = false,
    String? coverPath,
    bool clearCoverPath = false,
    String? series,
    bool clearSeries = false,
    String? genre,
    bool clearGenre = false,
    List<AudiobookChapter>? chapters,
    List<String>? sourcePaths,
    String? primaryFormat,
    DateTime? importedAt,
    double? progress,
    Duration? resumePosition,
    bool clearResumePosition = false,
    DateTime? lastPlayedAt,
    bool clearLastPlayedAt = false,
    BookStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    double? preferredSpeed,
    bool clearPreferredSpeed = false,
    bool? isFavorite,
  }) {
    return Audiobook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: clearAuthor ? null : (author ?? this.author),
      narrator: clearNarrator ? null : (narrator ?? this.narrator),
      description:
          clearDescription ? null : (description ?? this.description),
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      series: clearSeries ? null : (series ?? this.series),
      genre: clearGenre ? null : (genre ?? this.genre),
      chapters: chapters ?? this.chapters,
      sourcePaths: sourcePaths ?? this.sourcePaths,
      primaryFormat: primaryFormat ?? this.primaryFormat,
      importedAt: importedAt ?? this.importedAt,
        progress: progress ?? this.progress,
        resumePosition: clearResumePosition
          ? null
          : (resumePosition ?? this.resumePosition),
        lastPlayedAt:
          clearLastPlayedAt ? null : (lastPlayedAt ?? this.lastPlayedAt),
        status: status ?? this.status,
        completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      preferredSpeed:
          clearPreferredSpeed ? null : (preferredSpeed ?? this.preferredSpeed),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        author,
        narrator,
        description,
        coverPath,
        series,
        genre,
        chapters,
        sourcePaths,
        primaryFormat,
        importedAt,
        progress,
        resumePosition,
        lastPlayedAt,
        status,
        completedAt,
        preferredSpeed,
        isFavorite,
      ];
}
