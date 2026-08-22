import 'package:equatable/equatable.dart';

/// Entity representing a legal document generated and saved by a user
class SavedUserDocument extends Equatable {
  final String id;
  final String userId;
  final String? templateId;
  final String title;
  final String category;
  final Map<String, String> formValues;
  final String generatedText;
  final String? legalBasis;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedUserDocument({
    required this.id,
    required this.userId,
    this.templateId,
    required this.title,
    required this.category,
    required this.formValues,
    required this.generatedText,
    this.legalBasis,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        templateId,
        title,
        category,
        formValues,
        generatedText,
        legalBasis,
        createdAt,
        updatedAt,
      ];
}
