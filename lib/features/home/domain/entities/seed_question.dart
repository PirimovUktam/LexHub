import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';

/// Seed Question & Case Model to solve cold-start and provide instant legal guidance
class SeedQuestionModel extends Equatable {
  final String id;
  final String categoryId;
  final String categoryName;
  final String questionText;
  final String relatableSummary;
  final List<String> actionableSteps;
  final List<LawArticle> legalBasis;
  final RiskAssessment riskAssessment;

  const SeedQuestionModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.questionText,
    required this.relatableSummary,
    required this.actionableSteps,
    required this.legalBasis,
    required this.riskAssessment,
  });

  LegalResponse toLegalResponse() {
    return LegalResponse(
      id: "seed_resp_$id",
      queryId: "seed_q_$id",
      relatableSummary: relatableSummary,
      actionableSteps: actionableSteps,
      legalBasis: legalBasis,
      riskAssessment: riskAssessment,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        categoryName,
        questionText,
        relatableSummary,
        actionableSteps,
        legalBasis,
        riskAssessment,
      ];
}
