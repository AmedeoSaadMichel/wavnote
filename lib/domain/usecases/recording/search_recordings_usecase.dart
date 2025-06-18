// File: domain/usecases/recording/search_recordings_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../../core/enums/audio_format.dart';

/// Use case for searching recordings with various criteria
///
/// Provides comprehensive search capabilities including text search,
/// format filtering, favorite filtering, and advanced criteria matching.
/// Works in conjunction with FilterRecordingsUseCase for complete search functionality.
class SearchRecordingsUseCase {
  final IRecordingRepository _repository;

  const SearchRecordingsUseCase(this._repository);

  /// Perform basic text search across recordings
  Future<Either<Failure, SearchResult>> call(SearchCriteria criteria) async {
    try {
      // Validate search criteria
      final validationResult = _validateSearchCriteria(criteria);
      if (validationResult != null) {
        return Left(validationResult);
      }

      List<RecordingEntity> recordings;

      // Get base recordings list
      if (criteria.folderId != null) {
        recordings = await _repository.getRecordingsByFolder(criteria.folderId!);
      } else {
        recordings = await _repository.getAllRecordings();
      }

      // Apply search filters
      final searchResults = _performSearch(recordings, criteria);

      // Apply sorting
      final sortedResults = _applySorting(searchResults, criteria);

      return Right(SearchResult(
        recordings: sortedResults,
        query: criteria.query,
        totalFound: searchResults.length,
        totalSearched: recordings.length,
        criteria: criteria,
        searchedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_recordings',
        'Search operation failed: ${e.toString()}',
      ));
    }
  }

  /// Quick search by text query only
  Future<Either<Failure, List<RecordingEntity>>> quickSearch(String query) async {
    if (query.trim().isEmpty) {
      return const Right([]);
    }

    final criteria = SearchCriteria(query: query.trim());
    final result = await call(criteria);

    return result.fold(
          (failure) => Left(failure),
          (searchResult) => Right(searchResult.recordings),
    );
  }

  /// Search recordings by name or location
  Future<Either<Failure, List<RecordingEntity>>> searchByText(String query) async {
    try {
      if (query.trim().isEmpty) {
        return const Right([]);
      }

      final recordings = await _repository.searchRecordings(query.trim());
      return Right(recordings);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_by_text',
        'Failed to search recordings by text: ${e.toString()}',
      ));
    }
  }

  /// Search favorite recordings
  Future<Either<Failure, List<RecordingEntity>>> searchFavorites({String? query}) async {
    try {
      final favorites = await _repository.getFavoriteRecordings();

      if (query == null || query.trim().isEmpty) {
        return Right(favorites);
      }

      // Filter favorites by query
      final filtered = favorites.where((recording) =>
      recording.name.toLowerCase().contains(query.toLowerCase()) ||
          (recording.locationName?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();

      return Right(filtered);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_favorites',
        'Failed to search favorite recordings: ${e.toString()}',
      ));
    }
  }

  /// Search recordings by format
  Future<Either<Failure, List<RecordingEntity>>> searchByFormat(
      AudioFormat format, {
        String? query,
      }) async {
    try {
      final recordings = await _repository.getRecordingsByFormat(format);

      if (query == null || query.trim().isEmpty) {
        return Right(recordings);
      }

      // Filter by query
      final filtered = recordings.where((recording) =>
      recording.name.toLowerCase().contains(query.toLowerCase()) ||
          (recording.locationName?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();

      return Right(filtered);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_by_format',
        'Failed to search recordings by format: ${e.toString()}',
      ));
    }
  }

  /// Search recordings by date range
  Future<Either<Failure, List<RecordingEntity>>> searchByDateRange(
      DateTime startDate,
      DateTime endDate, {
        String? query,
      }) async {
    try {
      final recordings = await _repository.getRecordingsByDateRange(startDate, endDate);

      if (query == null || query.trim().isEmpty) {
        return Right(recordings);
      }

      // Filter by query
      final filtered = recordings.where((recording) =>
      recording.name.toLowerCase().contains(query.toLowerCase()) ||
          (recording.locationName?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();

      return Right(filtered);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_by_date_range',
        'Failed to search recordings by date range: ${e.toString()}',
      ));
    }
  }

  /// Search recordings by duration range
  Future<Either<Failure, List<RecordingEntity>>> searchByDurationRange(
      Duration minDuration,
      Duration maxDuration, {
        String? query,
      }) async {
    try {
      final recordings = await _repository.getRecordingsByDurationRange(minDuration, maxDuration);

      if (query == null || query.trim().isEmpty) {
        return Right(recordings);
      }

      // Filter by query
      final filtered = recordings.where((recording) =>
      recording.name.toLowerCase().contains(query.toLowerCase()) ||
          (recording.locationName?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();

      return Right(filtered);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_by_duration_range',
        'Failed to search recordings by duration range: ${e.toString()}',
      ));
    }
  }

  /// Search recordings with tags
  Future<Either<Failure, List<RecordingEntity>>> searchByTags(
      List<String> tags, {
        String? query,
        bool matchAll = false,
      }) async {
    try {
      final allRecordings = await _repository.getAllRecordings();

      // Filter by tags
      List<RecordingEntity> tagFiltered;
      if (matchAll) {
        // All tags must be present
        tagFiltered = allRecordings.where((recording) =>
            tags.every((tag) => recording.tags.contains(tag))
        ).toList();
      } else {
        // Any tag must be present
        tagFiltered = allRecordings.where((recording) =>
            tags.any((tag) => recording.tags.contains(tag))
        ).toList();
      }

      if (query == null || query.trim().isEmpty) {
        return Right(tagFiltered);
      }

      // Filter by query
      final filtered = tagFiltered.where((recording) =>
      recording.name.toLowerCase().contains(query.toLowerCase()) ||
          (recording.locationName?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();

      return Right(filtered);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_by_tags',
        'Failed to search recordings by tags: ${e.toString()}',
      ));
    }
  }

  /// Get search suggestions based on existing recordings
  Future<Either<Failure, List<String>>> getSearchSuggestions(String partialQuery) async {
    try {
      if (partialQuery.trim().isEmpty) {
        return const Right([]);
      }

      final allRecordings = await _repository.getAllRecordings();
      final suggestions = <String>{};
      final query = partialQuery.toLowerCase();

      for (final recording in allRecordings) {
        // Add matching names
        if (recording.name.toLowerCase().contains(query)) {
          suggestions.add(recording.name);
        }

        // Add matching locations
        if (recording.locationName?.toLowerCase().contains(query) ?? false) {
          suggestions.add(recording.locationName!);
        }

        // Add matching tags
        for (final tag in recording.tags) {
          if (tag.toLowerCase().contains(query)) {
            suggestions.add(tag);
          }
        }
      }

      final sortedSuggestions = suggestions.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // Limit suggestions to 10
      final limitedSuggestions = sortedSuggestions.take(10).toList();

      return Right(limitedSuggestions);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'search_suggestions',
        'Failed to get search suggestions: ${e.toString()}',
      ));
    }
  }

  // ==== PRIVATE METHODS ====

  /// Validate search criteria
  ValidationFailure? _validateSearchCriteria(SearchCriteria criteria) {
    // Validate query length
    if (criteria.query.length > 200) {
      return ValidationFailure.invalidInput(
        'Search query',
        'Search query cannot exceed 200 characters',
      );
    }

    // Validate date range if provided
    if (criteria.startDate != null && criteria.endDate != null) {
      if (criteria.startDate!.isAfter(criteria.endDate!)) {
        return ValidationFailure.invalidInput(
          'Date range',
          'Start date must be before end date',
        );
      }
    }

    // Validate duration range if provided
    if (criteria.minDuration != null && criteria.maxDuration != null) {
      if (criteria.minDuration! > criteria.maxDuration!) {
        return ValidationFailure.invalidInput(
          'Duration range',
          'Minimum duration must be less than maximum duration',
        );
      }
    }

    return null;
  }

  /// Perform search against recordings list
  List<RecordingEntity> _performSearch(
      List<RecordingEntity> recordings,
      SearchCriteria criteria,
      ) {
    return recordings.where((recording) {
      // Text search
      if (criteria.query.isNotEmpty) {
        final query = criteria.query.toLowerCase();
        final matchesName = recording.name.toLowerCase().contains(query);
        final matchesLocation = recording.locationName?.toLowerCase().contains(query) ?? false;
        final matchesTags = recording.tags.any((tag) => tag.toLowerCase().contains(query));

        if (!matchesName && !matchesLocation && !matchesTags) {
          return false;
        }
      }

      // Format filter
      if (criteria.format != null && recording.format != criteria.format) {
        return false;
      }

      // Favorite filter
      if (criteria.isFavorite != null && recording.isFavorite != criteria.isFavorite) {
        return false;
      }

      // Date range filter
      if (criteria.startDate != null && recording.createdAt.isBefore(criteria.startDate!)) {
        return false;
      }
      if (criteria.endDate != null && recording.createdAt.isAfter(criteria.endDate!)) {
        return false;
      }

      // Duration range filter
      if (criteria.minDuration != null && recording.duration < criteria.minDuration!) {
        return false;
      }
      if (criteria.maxDuration != null && recording.duration > criteria.maxDuration!) {
        return false;
      }

      // Tags filter
      if (criteria.tags.isNotEmpty) {
        if (criteria.matchAllTags) {
          // All tags must be present
          if (!criteria.tags.every((tag) => recording.tags.contains(tag))) {
            return false;
          }
        } else {
          // Any tag must be present
          if (!criteria.tags.any((tag) => recording.tags.contains(tag))) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  /// Apply sorting to search results
  List<RecordingEntity> _applySorting(
      List<RecordingEntity> recordings,
      SearchCriteria criteria,
      ) {
    final sortBy = criteria.sortBy ?? SearchSortBy.relevance;

    switch (sortBy) {
      case SearchSortBy.relevance:
      // Sort by relevance (exact matches first, then partial matches)
        return _sortByRelevance(recordings, criteria.query);
      case SearchSortBy.nameAscending:
        recordings.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SearchSortBy.nameDescending:
        recordings.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SearchSortBy.dateAscending:
        recordings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SearchSortBy.dateDescending:
        recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SearchSortBy.durationAscending:
        recordings.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SearchSortBy.durationDescending:
        recordings.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }

    return recordings;
  }

  /// Sort recordings by relevance to search query
  List<RecordingEntity> _sortByRelevance(List<RecordingEntity> recordings, String query) {
    if (query.isEmpty) {
      // No query, sort by date descending
      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return recordings;
    }

    final queryLower = query.toLowerCase();

    recordings.sort((a, b) {
      final aScore = _calculateRelevanceScore(a, queryLower);
      final bScore = _calculateRelevanceScore(b, queryLower);

      // Higher scores first
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;

      // If same score, sort by date (newer first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return recordings;
  }

  /// Calculate relevance score for a recording
  int _calculateRelevanceScore(RecordingEntity recording, String query) {
    int score = 0;
    final nameLower = recording.name.toLowerCase();
    final locationLower = recording.locationName?.toLowerCase() ?? '';

    // Exact name match gets highest score
    if (nameLower == query) {
      score += 100;
    }
    // Name starts with query
    else if (nameLower.startsWith(query)) {
      score += 50;
    }
    // Name contains query
    else if (nameLower.contains(query)) {
      score += 25;
    }

    // Location matches
    if (locationLower == query) {
      score += 75;
    } else if (locationLower.startsWith(query)) {
      score += 35;
    } else if (locationLower.contains(query)) {
      score += 15;
    }

    // Tag matches
    for (final tag in recording.tags) {
      final tagLower = tag.toLowerCase();
      if (tagLower == query) {
        score += 60;
      } else if (tagLower.startsWith(query)) {
        score += 30;
      } else if (tagLower.contains(query)) {
        score += 10;
      }
    }

    // Bonus for favorite recordings
    if (recording.isFavorite) {
      score += 5;
    }

    return score;
  }
}

// ==== FAILURE CLASSES ====

/// Base failure class
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Database-related failures
class DatabaseFailure extends Failure {
  final String operation;

  const DatabaseFailure._(String message, this.operation) : super(message);

  factory DatabaseFailure.queryFailed(String operation, String details) {
    return DatabaseFailure._('Database query failed: $details', operation);
  }
}

/// Validation-related failures
class ValidationFailure extends Failure {
  final String field;

  const ValidationFailure._(String message, this.field) : super(message);

  factory ValidationFailure.invalidInput(String field, String details) {
    return ValidationFailure._('Invalid $field: $details', field);
  }
}

// ==== SEARCH CRITERIA ====

/// Comprehensive search criteria for recordings
class SearchCriteria {
  final String query;
  final String? folderId;
  final AudioFormat? format;
  final bool? isFavorite;
  final DateTime? startDate;
  final DateTime? endDate;
  final Duration? minDuration;
  final Duration? maxDuration;
  final List<String> tags;
  final bool matchAllTags;
  final SearchSortBy? sortBy;

  const SearchCriteria({
    this.query = '',
    this.folderId,
    this.format,
    this.isFavorite,
    this.startDate,
    this.endDate,
    this.minDuration,
    this.maxDuration,
    this.tags = const [],
    this.matchAllTags = false,
    this.sortBy,
  });

  /// Create criteria for simple text search
  factory SearchCriteria.text(String query) {
    return SearchCriteria(
      query: query,
      sortBy: SearchSortBy.relevance,
    );
  }

  /// Create criteria for format search
  factory SearchCriteria.format(AudioFormat format, {String query = ''}) {
    return SearchCriteria(
      query: query,
      format: format,
      sortBy: SearchSortBy.dateDescending,
    );
  }

  /// Create criteria for favorite search
  factory SearchCriteria.favorites({String query = ''}) {
    return SearchCriteria(
      query: query,
      isFavorite: true,
      sortBy: SearchSortBy.dateDescending,
    );
  }

  /// Create criteria for tag search
  factory SearchCriteria.tags(List<String> tags, {
    String query = '',
    bool matchAll = false,
  }) {
    return SearchCriteria(
      query: query,
      tags: tags,
      matchAllTags: matchAll,
      sortBy: SearchSortBy.relevance,
    );
  }

  /// Check if criteria has any filters
  bool get hasFilters {
    return query.isNotEmpty ||
        folderId != null ||
        format != null ||
        isFavorite != null ||
        startDate != null ||
        endDate != null ||
        minDuration != null ||
        maxDuration != null ||
        tags.isNotEmpty;
  }

  /// Get human-readable description of search criteria
  String get description {
    final parts = <String>[];

    if (query.isNotEmpty) {
      parts.add('Query: "$query"');
    }

    if (format != null) {
      parts.add('Format: ${format!.name.toUpperCase()}');
    }

    if (isFavorite == true) {
      parts.add('Favorites only');
    }

    if (tags.isNotEmpty) {
      final tagOp = matchAllTags ? 'all' : 'any';
      parts.add('Tags ($tagOp): ${tags.join(', ')}');
    }

    if (startDate != null || endDate != null) {
      if (startDate != null && endDate != null) {
        parts.add('Date: ${_formatDate(startDate!)} - ${_formatDate(endDate!)}');
      } else if (startDate != null) {
        parts.add('After: ${_formatDate(startDate!)}');
      } else {
        parts.add('Before: ${_formatDate(endDate!)}');
      }
    }

    return parts.isEmpty ? 'All recordings' : parts.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Sort options for search results
enum SearchSortBy {
  relevance,
  nameAscending,
  nameDescending,
  dateAscending,
  dateDescending,
  durationAscending,
  durationDescending,
}

// ==== SEARCH RESULT ====

/// Result of search operation with metadata
class SearchResult {
  final List<RecordingEntity> recordings;
  final String query;
  final int totalFound;
  final int totalSearched;
  final SearchCriteria criteria;
  final DateTime searchedAt;

  const SearchResult({
    required this.recordings,
    required this.query,
    required this.totalFound,
    required this.totalSearched,
    required this.criteria,
    required this.searchedAt,
  });

  /// Check if search has results
  bool get hasResults => recordings.isNotEmpty;

  /// Check if search was filtered (didn't return all recordings)
  bool get wasFiltered => totalFound < totalSearched;

  /// Get search efficiency (0.0 to 1.0)
  double get searchEfficiency {
    if (totalSearched == 0) return 0.0;
    return totalFound / totalSearched;
  }

  /// Get search summary for UI
  String get searchSummary {
    if (!hasResults) {
      return query.isEmpty ? 'No recordings found' : 'No recordings match "$query"';
    }

    if (!wasFiltered) {
      return 'All $totalSearched recordings shown';
    }

    if (query.isEmpty) {
      return 'Found $totalFound of $totalSearched recordings';
    }

    return 'Found $totalFound results for "$query"';
  }

  /// Get detailed search description
  String get detailedDescription {
    final summary = searchSummary;
    if (!criteria.hasFilters) {
      return summary;
    }

    return '$summary\nCriteria: ${criteria.description}';
  }
}