import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/note_model.dart';
import '../../../data/database/app_database.dart';
import '../../../services/ai/ai_service.dart';

// States
abstract class SearchState extends Equatable {
  const SearchState();
}

class SearchInitial extends SearchState {
  @override
  List<Object> get props => [];
}

class SearchLoading extends SearchState {
  @override
  List<Object> get props => [];
}

class SearchResults extends SearchState {
  final String query;
  final List<NoteModel> results;
  final String? aiAnswer;

  const SearchResults({
    required this.query,
    required this.results,
    this.aiAnswer,
  });

  @override
  List<Object?> get props => [query, results, aiAnswer];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object> get props => [message];
}

// Cubit
class SearchCubit extends Cubit<SearchState> {
  final AppDatabase _database;
  final AIService _aiService;

  SearchCubit({
    required AppDatabase database,
    required AIService aiService,
  })  : _database = database,
        _aiService = aiService,
        super(SearchInitial());

  /// Perform full-text search
  Future<void> search(String query) async {
    if (query.isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading());
    
    try {
      // TODO: Use FTS search once database code is generated
      // final results = await _database.searchNotes(query);
      
      emit(SearchResults(
        query: query,
        results: [],
      ));
    } catch (e) {
      emit(SearchError('Failed to search: $e'));
    }
  }

  /// Perform semantic search with AI
  Future<void> semanticSearch(String query) async {
    if (query.isEmpty) {
      emit(SearchInitial());
      return;
    }

    if (!_aiService.isEnabled) {
      await search(query); // Fall back to regular search
      return;
    }

    emit(SearchLoading());
    
    try {
      // First, get relevant notes using FTS
      // TODO: Use FTS search once database code is generated
      final relevantNotes = <NoteModel>[];

      if (relevantNotes.isEmpty) {
        emit(SearchResults(
          query: query,
          results: [],
          aiAnswer: 'No notes found matching your query.',
        ));
        return;
      }

      // Use AI to answer the query
      final noteContents = relevantNotes.map((n) => n.content).toList();
      final aiAnswer = await _aiService.searchNotes(
        query: query,
        relevantNotes: noteContents,
      );

      emit(SearchResults(
        query: query,
        results: relevantNotes,
        aiAnswer: aiAnswer,
      ));
    } catch (e) {
      emit(SearchError('Failed to perform semantic search: $e'));
    }
  }

  /// Clear search
  void clear() {
    emit(SearchInitial());
  }
}
