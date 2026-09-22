import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/data/datasources/advocate_profile_remote_datasource.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';

class AdvocateProfileRepositoryImpl implements AdvocateProfileRepository {
  AdvocateProfileRepositoryImpl({required this.remoteDataSource});
  final AdvocateProfileRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _result<T>(Future<T> Function() request) async {
    try {
      return Right(await request());
    } catch (error) {
      return Left(ErrorHandler.handle(error));
    }
  }

  @override
  Future<Either<Failure, AdvocateProfile>> getProfile(String expertId) =>
      _result(() => remoteDataSource.getProfile(expertId));

  @override
  Future<Either<Failure, AdvocateProfile?>> getMyProfile() =>
      _result(remoteDataSource.getMyProfile);

  @override
  Future<Either<Failure, AdvocateProfile>> saveProfile(
          AdvocateProfileInput input) =>
      _result(() => remoteDataSource.saveProfile(input));

  @override
  Future<Either<Failure, AdvocateService>> saveService(
          String expertId, AdvocateService service) =>
      _result(() => remoteDataSource.saveService(expertId, service));

  @override
  Future<Either<Failure, void>> deleteService(String id) =>
      _result(() => remoteDataSource.deleteService(id));

  @override
  Future<Either<Failure, AdvocateExperience>> saveExperience(
          String expertId, AdvocateExperience experience) =>
      _result(() => remoteDataSource.saveExperience(expertId, experience));

  @override
  Future<Either<Failure, void>> deleteExperience(String id) =>
      _result(() => remoteDataSource.deleteExperience(id));

  @override
  Future<Either<Failure, AdvocateEducation>> saveEducation(
          String expertId, AdvocateEducation education) =>
      _result(() => remoteDataSource.saveEducation(expertId, education));

  @override
  Future<Either<Failure, void>> deleteEducation(String id) =>
      _result(() => remoteDataSource.deleteEducation(id));

  @override
  Future<Either<Failure, AdvocateWorkingHours>> saveWorkingHours(
          String expertId, AdvocateWorkingHours hours) =>
      _result(() => remoteDataSource.saveWorkingHours(expertId, hours));

  @override
  Future<Either<Failure, void>> deleteWorkingHours(String id) =>
      _result(() => remoteDataSource.deleteWorkingHours(id));

  @override
  Future<Either<Failure, String>> uploadAvatar(
          Uint8List bytes, String contentType) =>
      _result(() => remoteDataSource.uploadAvatar(bytes, contentType));

  @override
  Future<Either<Failure, AdvocateDocument>> uploadDocument({
    required String expertId,
    required String title,
    required String kind,
    required Uint8List bytes,
    required String contentType,
    bool isPublic = false,
  }) =>
      _result(() => remoteDataSource.uploadDocument(
            expertId: expertId,
            title: title,
            kind: kind,
            bytes: bytes,
            contentType: contentType,
            isPublic: isPublic,
          ));

  @override
  Future<Either<Failure, void>> deleteDocument(AdvocateDocument document) =>
      _result(() => remoteDataSource.deleteDocument(document));

  @override
  Future<Either<Failure, AdvocateDocument>> updateDocument(
          AdvocateDocument document) =>
      _result(() => remoteDataSource.updateDocument(document));

  @override
  Future<Either<Failure, String>> getSignedUrl(String objectPath) =>
      _result(() => remoteDataSource.getSignedUrl(objectPath));

  @override
  Future<Either<Failure, AdvocateRequest>> sendRequest({
    required String expertId,
    required String message,
    String? serviceId,
    String kind = 'consultation',
  }) =>
      _result(() => remoteDataSource.sendRequest(
            expertId: expertId,
            message: message,
            serviceId: serviceId,
            kind: kind,
          ));

  @override
  Future<Either<Failure, List<AdvocateRequest>>> getRequests() =>
      _result(remoteDataSource.getRequests);

  @override
  Future<Either<Failure, AdvocateRequest>> getRequest(String requestId) =>
      _result(() => remoteDataSource.getRequest(requestId));

  @override
  Future<Either<Failure, AdvocateRequest>> updateRequestStatus(
          String requestId, String status) =>
      _result(() => remoteDataSource.updateRequestStatus(requestId, status));

  @override
  Future<Either<Failure, List<AdvocateMessage>>> getMessages(
          String requestId) =>
      _result(() => remoteDataSource.getMessages(requestId));

  @override
  Future<Either<Failure, AdvocateMessage>> sendMessage(
          String requestId, String body) =>
      _result(() => remoteDataSource.sendMessage(requestId, body));

  @override
  Future<Either<Failure, AdvocateReview>> saveReview({
    required String consultationId,
    required int rating,
    required String comment,
  }) =>
      _result(() => remoteDataSource.saveReview(
            consultationId: consultationId,
            rating: rating,
            comment: comment,
          ));
}
