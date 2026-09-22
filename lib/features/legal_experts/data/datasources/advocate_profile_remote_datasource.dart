import 'dart:async';
import 'dart:typed_data';

import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/network/request_timeout.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/legal_experts/data/models/advocate_profile_model.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

abstract class AdvocateProfileRemoteDataSource {
  Future<AdvocateProfile> getProfile(String expertId);
  Future<AdvocateProfile?> getMyProfile();
  Future<AdvocateProfile> saveProfile(AdvocateProfileInput input);
  Future<AdvocateService> saveService(String expertId, AdvocateService service);
  Future<void> deleteService(String id);
  Future<AdvocateExperience> saveExperience(
      String expertId, AdvocateExperience experience);
  Future<void> deleteExperience(String id);
  Future<AdvocateEducation> saveEducation(
      String expertId, AdvocateEducation education);
  Future<void> deleteEducation(String id);
  Future<AdvocateWorkingHours> saveWorkingHours(
      String expertId, AdvocateWorkingHours hours);
  Future<void> deleteWorkingHours(String id);
  Future<String> uploadAvatar(Uint8List bytes, String contentType);
  Future<AdvocateDocument> uploadDocument({
    required String expertId,
    required String title,
    required String kind,
    required Uint8List bytes,
    required String contentType,
    bool isPublic = false,
  });
  Future<void> deleteDocument(AdvocateDocument document);
  Future<AdvocateDocument> updateDocument(AdvocateDocument document);
  Future<String> getSignedUrl(String objectPath);
  Future<AdvocateRequest> sendRequest({
    required String expertId,
    required String message,
    String? serviceId,
    String kind = 'consultation',
  });
  Future<List<AdvocateRequest>> getRequests();
  Future<AdvocateRequest> getRequest(String requestId);
  Future<AdvocateRequest> updateRequestStatus(String requestId, String status);
  Future<List<AdvocateMessage>> getMessages(String requestId);
  Future<AdvocateMessage> sendMessage(String requestId, String body);
  Future<AdvocateReview> saveReview({
    required String consultationId,
    required int rating,
    required String comment,
  });
}

class AdvocateProfileRemoteDataSourceImpl
    implements AdvocateProfileRemoteDataSource {
  AdvocateProfileRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;
  static const _bucket = 'advocate-documents';
  static final _objectPath = RegExp(
    r'^[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}\.(jpg|png|webp|pdf)$',
  );

  String _requireUser() {
    final user = supabaseClient.auth.currentUser;
    if (user == null) throw const UnauthorizedException();
    return user.id;
  }

  /// Never includes server payloads, SQL, messages or contact data in errors.
  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation()
          .withTimeout(kDbRequestTimeout, label: 'advocate_profile');
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw TimeoutException('Advocate request timed out');
    } on PostgrestException catch (error) {
      final rateLimited = error.code == 'P0001' &&
          const {
            'advocate_request_rate_limited',
            'advocate_message_rate_limited'
          }.contains(error.message);
      final status = rateLimited
          ? 429
          : switch (error.code) {
              '42501' || 'PT403' => 403,
              'PT401' => 401,
              'PGRST116' || 'PT404' => 404,
              '23514' || '23505' || '22P02' || '22023' || 'PT422' => 422,
              'LX429' || 'PT429' => 429,
              _ => 502,
            };
      throw ServerException(
        message: 'Advokat ma’lumotlari bilan amal bajarilmadi.',
        statusCode: status,
      );
    } on StorageException catch (error) {
      throw ServerException(
        message: 'Hujjat bilan amal bajarilmadi.',
        statusCode: int.tryParse(error.statusCode ?? '') ?? 502,
      );
    } on FormatException {
      throw const ServerException(
        message: 'Advokat ma’lumotlari javobi tushunilmadi.',
        statusCode: 502,
      );
    } catch (_) {
      throw const ServerException(
        message: 'Advokat ma’lumotlari bilan aloqa o‘rnatilmadi.',
        statusCode: 502,
      );
    }
  }

  @override
  Future<AdvocateProfile> getProfile(String expertId) => _run(() async {
        final result = await supabaseClient.rpc(
          'get_advocate_profile',
          params: {'p_expert_id': expertId},
        );
        if (result == null) {
          throw const ServerException(
              message: 'Advokat profili topilmadi.', statusCode: 404);
        }
        final profile = AdvocateProfileModel.fromJson(result);
        if (profile.id != expertId) {
          throw const ServerException(
              message: 'Profil javobi mos kelmadi.', statusCode: 502);
        }
        return profile;
      });

  @override
  Future<AdvocateProfile?> getMyProfile() => _run(() async {
        final userId = _requireUser();
        final result = await supabaseClient
            .rpc('get_my_advocate_profile', params: const <String, dynamic>{});
        if (result == null) return null;
        final profile = AdvocateProfileModel.fromJson(result);
        if (!profile.isOwner || profile.userId != userId) {
          throw const ServerException(
              message: 'Profil javobi mos kelmadi.', statusCode: 502);
        }
        return profile;
      });

  @override
  Future<AdvocateProfile> saveProfile(AdvocateProfileInput input) =>
      _run(() async {
        final userId = _requireUser();
        final result =
            await supabaseClient.rpc('save_advocate_profile', params: {
          'p_profile': AdvocateProfileModel.inputToJson(input),
        });
        final profile = AdvocateProfileModel.fromJson(result);
        if (!profile.isOwner || profile.userId != userId) {
          throw const ServerException(
              message: 'Profil saqlangani tasdiqlanmadi.', statusCode: 502);
        }
        return profile;
      });

  Future<Map<String, dynamic>> _save(String table, String expertId, String id,
      Map<String, dynamic> values) async {
    _requireUser();
    final Object? result;
    if (id.isEmpty) {
      result = await supabaseClient
          .db(table)
          .insert({...values, 'expert_id': expertId})
          .select()
          .single();
    } else {
      result = await supabaseClient
          .db(table)
          .update(values)
          .eq('id', id)
          .eq('expert_id', expertId)
          .select()
          .single();
    }
    return AdvocateProfileModel.map(result);
  }

  Future<Map<String, dynamic>> _delete(String table, String id) async {
    _requireUser();
    return AdvocateProfileModel.map(
        await supabaseClient.db(table).delete().eq('id', id).select().single());
  }

  @override
  Future<AdvocateService> saveService(
          String expertId, AdvocateService service) =>
      _run(() async => AdvocateProfileModel.serviceFromJson(await _save(
          'advocate_services',
          expertId,
          service.id,
          AdvocateProfileModel.serviceToJson(service))));

  @override
  Future<void> deleteService(String id) => _run(() async {
        await _delete('advocate_services', id);
      });

  @override
  Future<AdvocateExperience> saveExperience(
          String expertId, AdvocateExperience experience) =>
      _run(() async => AdvocateProfileModel.experienceFromJson(await _save(
          'advocate_experience',
          expertId,
          experience.id,
          AdvocateProfileModel.experienceToJson(experience))));

  @override
  Future<void> deleteExperience(String id) => _run(() async {
        await _delete('advocate_experience', id);
      });

  @override
  Future<AdvocateEducation> saveEducation(
          String expertId, AdvocateEducation education) =>
      _run(() async => AdvocateProfileModel.educationFromJson(await _save(
          'advocate_education',
          expertId,
          education.id,
          AdvocateProfileModel.educationToJson(education))));

  @override
  Future<void> deleteEducation(String id) => _run(() async {
        await _delete('advocate_education', id);
      });

  @override
  Future<AdvocateWorkingHours> saveWorkingHours(
          String expertId, AdvocateWorkingHours hours) =>
      _run(() async => AdvocateProfileModel.workingHoursFromJson(await _save(
          'advocate_working_hours',
          expertId,
          hours.id,
          AdvocateProfileModel.workingHoursToJson(hours))));

  @override
  Future<void> deleteWorkingHours(String id) => _run(() async {
        await _delete('advocate_working_hours', id);
      });

  Future<String> _upload(Uint8List bytes, String contentType,
      {bool avatar = false}) async {
    final userId = _requireUser();
    final extension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'application/pdf' when !avatar => 'pdf',
      _ => null,
    };
    if (extension == null ||
        bytes.isEmpty ||
        bytes.length > 10 * 1024 * 1024 ||
        !_matchesMedia(bytes, extension)) {
      throw const ValidationException(
          message: 'Fayl turi yoki hajmi yaroqsiz.');
    }
    // No original filename, personal data or predictable object identifier.
    final path = '$userId/${const Uuid().v4()}.$extension';
    await supabaseClient.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  static bool _matchesMedia(Uint8List bytes, String extension) {
    bool prefix(List<int> signature, [int offset = 0]) =>
        bytes.length >= offset + signature.length &&
        signature.indexed
            .every((entry) => bytes[offset + entry.$1] == entry.$2);
    return switch (extension) {
      'jpg' => prefix([0xff, 0xd8, 0xff]),
      'png' => prefix([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      'webp' =>
        prefix([0x52, 0x49, 0x46, 0x46]) && prefix([0x57, 0x45, 0x42, 0x50], 8),
      'pdf' => prefix([0x25, 0x50, 0x44, 0x46, 0x2d]),
      _ => false,
    };
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, String contentType) =>
      _run(() => _upload(bytes, contentType, avatar: true));

  @override
  Future<AdvocateDocument> uploadDocument({
    required String expertId,
    required String title,
    required String kind,
    required Uint8List bytes,
    required String contentType,
    bool isPublic = false,
  }) =>
      _run(() async {
        final path = await _upload(bytes, contentType);
        try {
          return AdvocateProfileModel.documentFromJson(await _save(
            'advocate_documents',
            expertId,
            '',
            {
              'title': title.trim(),
              'kind': kind,
              'object_path': path,
              'is_public': isPublic,
            },
          ));
        } on PostgrestException catch (error) {
          // Only a definite transaction rejection proves no metadata persisted.
          // A timeout/lost response may follow a committed insert: deleting in
          // that case would destroy the object of a saved document.
          if (const {'42501', '22023', '23514', '23505', '23503', '23502'}
              .contains(error.code)) {
            await supabaseClient.storage.from(_bucket).remove([path]);
          }
          rethrow;
        }
      });

  @override
  Future<void> deleteDocument(AdvocateDocument document) => _run(() async {
        final row = await _delete('advocate_documents', document.id);
        // Use the authorized deleted row, never a caller-supplied path.
        final path = AdvocateProfileModel.requiredText(row, 'object_path');
        await supabaseClient.storage.from(_bucket).remove([path]);
      });

  @override
  Future<AdvocateDocument> updateDocument(AdvocateDocument document) =>
      _run(() async {
        _requireUser();
        final row = await supabaseClient
            .db('advocate_documents')
            .update({
              'title': document.title.trim(),
              'kind': document.kind,
              'is_public': document.isPublic,
            })
            .eq('id', document.id)
            .select()
            .single();
        return AdvocateProfileModel.documentFromJson(
            AdvocateProfileModel.map(row));
      });

  @override
  Future<String> getSignedUrl(String objectPath) => _run(() async {
        if (!_objectPath.hasMatch(objectPath)) {
          throw const ValidationException(message: 'Hujjat yo‘li yaroqsiz.');
        }
        // Storage SELECT policy independently decides publication/ownership.
        // The bucket is private; URLs are deliberately short-lived.
        return supabaseClient.storage
            .from(_bucket)
            .createSignedUrl(objectPath, 60);
      });

  @override
  Future<AdvocateRequest> sendRequest({
    required String expertId,
    required String message,
    String? serviceId,
    String kind = 'consultation',
  }) =>
      _run(() async {
        _requireUser();
        final row = await supabaseClient.rpc('send_advocate_request', params: {
          'p_expert_id': expertId,
          'p_message': message.trim(),
          'p_service_id': serviceId,
          'p_kind': kind,
        });
        return AdvocateProfileModel.requestFromJson(
            AdvocateProfileModel.map(row));
      });

  @override
  Future<List<AdvocateRequest>> getRequests() => _run(() async {
        _requireUser();
        final rows = await supabaseClient
            .db('advocate_consultation_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        return AdvocateProfileModel.rows(rows)
            .map(AdvocateProfileModel.requestFromJson)
            .toList();
      });

  @override
  Future<AdvocateRequest> getRequest(String requestId) => _run(() async {
        _requireUser();
        final row = await supabaseClient
            .db('advocate_consultation_requests')
            .select()
            .eq('id', requestId)
            .single();
        final request =
            AdvocateProfileModel.requestFromJson(AdvocateProfileModel.map(row));
        if (request.id != requestId) {
          throw const ServerException(
              message: 'So‘rov javobi mos kelmadi.', statusCode: 502);
        }
        return request;
      });

  @override
  Future<AdvocateRequest> updateRequestStatus(
          String requestId, String status) =>
      _run(() async {
        _requireUser();
        final row = await supabaseClient.rpc(
          'update_advocate_request_status',
          params: {'p_request_id': requestId, 'p_status': status},
        );
        return AdvocateProfileModel.requestFromJson(
            AdvocateProfileModel.map(row));
      });

  @override
  Future<List<AdvocateMessage>> getMessages(String requestId) => _run(() async {
        _requireUser();
        final rows = await supabaseClient
            .db('advocate_messages')
            .select()
            .eq('request_id', requestId)
            .order('created_at')
            .limit(100);
        return AdvocateProfileModel.rows(rows)
            .map(AdvocateProfileModel.messageFromJson)
            .toList();
      });

  @override
  Future<AdvocateMessage> sendMessage(String requestId, String body) =>
      _run(() async {
        _requireUser();
        final row = await supabaseClient.rpc('send_advocate_message', params: {
          'p_request_id': requestId,
          'p_body': body.trim(),
        });
        return AdvocateProfileModel.messageFromJson(
            AdvocateProfileModel.map(row));
      });

  @override
  Future<AdvocateReview> saveReview({
    required String consultationId,
    required int rating,
    required String comment,
  }) =>
      _run(() async {
        _requireUser();
        final row = await supabaseClient.rpc('save_advocate_review', params: {
          'p_consultation_id': consultationId,
          'p_rating': rating,
          'p_comment': comment.trim(),
        });
        return AdvocateProfileModel.reviewFromJson(
            AdvocateProfileModel.map(row));
      });
}
