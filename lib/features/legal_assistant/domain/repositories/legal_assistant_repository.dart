import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

/// Contract for Legal Assistant data operations
abstract class LegalAssistantRepository {
  /// Analyzes a legal query and returns dual-layer response with Lex.uz citations
  Future<Either<Failure, LegalResponse>> getLegalAdvice(LegalQuery query);

  /// Performs instant rule-based and AI emergency/red-flag detection
  Future<Either<Failure, EmergencyProtocol?>> detectEmergency(String queryText);

  /// Saves a legal response for offline access
  Future<Either<Failure, void>> saveCase(LegalResponse response);

  /// Retrieves all saved legal consultation cases
  Future<Either<Failure, List<LegalResponse>>> getSavedCases();

  /// Deletes a saved case by ID
  Future<Either<Failure, void>> deleteSavedCase(String id);
}
