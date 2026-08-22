import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';

class TalkRoomModel extends TalkRoom {
  const TalkRoomModel({
    required super.id,
    required super.title,
    required super.category,
    required super.description,
    required super.participantsCount,
    required super.activeNowCount,
    required super.isLive,
    required super.createdAt,
  });

  factory TalkRoomModel.fromJson(Map<String, dynamic> json) {
    return TalkRoomModel(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      participantsCount: json['participantsCount'] as int? ?? 0,
      activeNowCount: json['activeNowCount'] as int? ?? 0,
      isLive: json['isLive'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'participantsCount': participantsCount,
      'activeNowCount': activeNowCount,
      'isLive': isLive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TalkRoomModel.fromEntity(TalkRoom entity) {
    return TalkRoomModel(
      id: entity.id,
      title: entity.title,
      category: entity.category,
      description: entity.description,
      participantsCount: entity.participantsCount,
      activeNowCount: entity.activeNowCount,
      isLive: entity.isLive,
      createdAt: entity.createdAt,
    );
  }
}
