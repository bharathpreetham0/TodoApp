import 'package:equatable/equatable.dart';

/// Note model for domain layer
class NoteModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final String? summary;
  final String? category;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEncrypted;
  final bool isFavorite;
  final bool isArchived;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.summary,
    this.category,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isEncrypted = false,
    this.isFavorite = false,
    this.isArchived = false,
  });

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    String? category,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEncrypted,
    bool? isFavorite,
    bool? isArchived,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'summary': summary,
      'category': category,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_encrypted': isEncrypted,
      'is_favorite': isFavorite,
      'is_archived': isArchived,
    };
  }

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      summary: json['summary'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isEncrypted: json['is_encrypted'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        summary,
        category,
        tags,
        createdAt,
        updatedAt,
        isEncrypted,
        isFavorite,
        isArchived,
      ];
}
