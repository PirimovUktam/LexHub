import 'package:lexhub/core/utils/json_coerce.dart';
import 'package:equatable/equatable.dart';

/// Represents red flags, constitutional defense rights, and urgent emergency actions
class EmergencyProtocol extends Equatable {
  final bool isEmergency;
  final String title;
  final List<String> redFlags;
  final List<String> constitutionalRights;
  final List<String> immediateActions;
  final String emergencyHotline;

  const EmergencyProtocol({
    this.isEmergency = false,
    required this.title,
    this.redFlags = const [],
    this.constitutionalRights = const [],
    this.immediateActions = const [],
    this.emergencyHotline = "1002",
  });

  factory EmergencyProtocol.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return EmergencyProtocol(
      isEmergency:
          jsonFlag(json['is_emergency']) ?? jsonFlag(json['isEmergency']) ?? false,
      title: jsonText(json['title']) ?? '',
      redFlags: parseList(json['red_flags'] ?? json['redFlags']),
      constitutionalRights: parseList(json['constitutional_rights'] ?? json['constitutionalRights']),
      immediateActions: parseList(json['immediate_actions'] ?? json['immediateActions']),
      emergencyHotline: jsonText(json['emergency_hotline']) ??
          jsonText(json['emergencyHotline']) ??
          '1002',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_emergency': isEmergency,
      'title': title,
      'red_flags': redFlags,
      'constitutional_rights': constitutionalRights,
      'immediate_actions': immediateActions,
      'emergency_hotline': emergencyHotline,
    };
  }

  EmergencyProtocol copyWith({
    bool? isEmergency,
    String? title,
    List<String>? redFlags,
    List<String>? constitutionalRights,
    List<String>? immediateActions,
    String? emergencyHotline,
  }) {
    return EmergencyProtocol(
      isEmergency: isEmergency ?? this.isEmergency,
      title: title ?? this.title,
      redFlags: redFlags ?? this.redFlags,
      constitutionalRights: constitutionalRights ?? this.constitutionalRights,
      immediateActions: immediateActions ?? this.immediateActions,
      emergencyHotline: emergencyHotline ?? this.emergencyHotline,
    );
  }

  @override
  List<Object?> get props => [
        isEmergency,
        title,
        redFlags,
        constitutionalRights,
        immediateActions,
        emergencyHotline,
      ];
}
