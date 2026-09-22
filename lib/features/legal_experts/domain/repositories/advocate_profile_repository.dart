import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';

abstract class AdvocateProfileRepository {
  Future<Either<Failure, AdvocateProfile>> getProfile(String expertId);
  Future<Either<Failure, AdvocateProfile?>> getMyProfile();
  Future<Either<Failure, AdvocateProfile>> saveProfile(
      AdvocateProfileInput input);
  Future<Either<Failure, AdvocateService>> saveService(
      String expertId, AdvocateService service);
  Future<Either<Failure, void>> deleteService(String id);
  Future<Either<Failure, AdvocateExperience>> saveExperience(
      String expertId, AdvocateExperience experience);
  Future<Either<Failure, void>> deleteExperience(String id);
  Future<Either<Failure, AdvocateEducation>> saveEducation(
      String expertId, AdvocateEducation education);
  Future<Either<Failure, void>> deleteEducation(String id);
  Future<Either<Failure, AdvocateWorkingHours>> saveWorkingHours(
      String expertId, AdvocateWorkingHours hours);
  Future<Either<Failure, void>> deleteWorkingHours(String id);
  Future<Either<Failure, String>> uploadAvatar(
      Uint8List bytes, String contentType);
  Future<Either<Failure, AdvocateDocument>> uploadDocument({
    required String expertId,
    required String title,
    required String kind,
    required Uint8List bytes,
    required String contentType,
    bool isPublic = false,
  });
  Future<Either<Failure, void>> deleteDocument(AdvocateDocument document);
  Future<Either<Failure, AdvocateDocument>> updateDocument(
      AdvocateDocument document);
  Future<Either<Failure, String>> getSignedUrl(String objectPath);
  Future<Either<Failure, AdvocateRequest>> sendRequest({
    required String expertId,
    required String message,
    String? serviceId,
    String kind = 'consultation',
  });
  Future<Either<Failure, List<AdvocateRequest>>> getRequests();
  Future<Either<Failure, AdvocateRequest>> getRequest(String requestId);
  Future<Either<Failure, AdvocateRequest>> updateRequestStatus(
      String requestId, String status);
  Future<Either<Failure, List<AdvocateMessage>>> getMessages(String requestId);
  Future<Either<Failure, AdvocateMessage>> sendMessage(
      String requestId, String body);
  Future<Either<Failure, AdvocateReview>> saveReview({
    required String consultationId,
    required int rating,
    required String comment,
  });
}
