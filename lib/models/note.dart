import 'package:flutter/foundation.dart';

@immutable
class Note {
  /// Index into AppColors.noteColors; 5 is white.
  static const defaultColorIndex = 5;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.colorIndex = defaultColorIndex,
  });

  factory Note.create({
    String title = '',
    String body = '',
    int colorIndex = defaultColorIndex,
    String? id,
  }) {
    final now = DateTime.now();
    return Note(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      createdAt: now,
      updatedAt: now,
      colorIndex: colorIndex,
    );
  }

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        colorIndex: j['colorIndex'] as int? ?? defaultColorIndex,
      );

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorIndex;

  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title.trim();
  int get wordCount => RegExp(r'\S+').allMatches(body).length;

  Note copyWith({String? title, String? body, DateTime? updatedAt, int? colorIndex}) =>
      Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        colorIndex: colorIndex ?? this.colorIndex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'colorIndex': colorIndex,
      };
}
