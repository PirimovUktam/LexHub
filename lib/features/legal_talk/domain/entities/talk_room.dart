import 'package:equatable/equatable.dart';

/// Entity representing a discussion room in Legal Talk
class TalkRoom extends Equatable {
  final String id;
  final String title;
  final String category;
  final String description;
  final int participantsCount;
  final int activeNowCount;
  final bool isLive;
  final DateTime createdAt;

  const TalkRoom({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.participantsCount,
    required this.activeNowCount,
    required this.isLive,
    required this.createdAt,
  });

  TalkRoom copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    int? participantsCount,
    int? activeNowCount,
    bool? isLive,
    DateTime? createdAt,
  }) {
    return TalkRoom(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      participantsCount: participantsCount ?? this.participantsCount,
      activeNowCount: activeNowCount ?? this.activeNowCount,
      isLive: isLive ?? this.isLive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        description,
        participantsCount,
        activeNowCount,
        isLive,
        createdAt,
      ];
}
