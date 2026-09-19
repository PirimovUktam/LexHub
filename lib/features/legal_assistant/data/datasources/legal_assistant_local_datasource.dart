import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/storage/local_case_scope.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

abstract class LegalAssistantLocalDataSource {
  Future<void> saveCase(LegalResponse response);
  Future<List<LegalResponse>> getSavedCases();
  Future<void> deleteSavedCase(String id);
}

class LegalAssistantLocalDataSourceImpl implements LegalAssistantLocalDataSource {
  static const String boxName = 'saved_legal_cases_box';
  final Box<String> box;
  final LocalCaseScope scope;

  LegalAssistantLocalDataSourceImpl({required this.box, required this.scope});

  @override
  Future<void> saveCase(LegalResponse response) async {
    try {
      if (response.storageScope != null && response.storageScope != scope.value) {
        throw StateError('local_case_scope_changed');
      }
      final key = scope.keyFor(response.id);
      final jsonMap = response.copyWith(storageScope: scope.value).toJson();
      // mark as saved
      jsonMap['isSaved'] = true;
      final encoded = jsonEncode(jsonMap);
      await box.put(key, encoded);
    } catch (e) {
      throw CacheException(message: "Keysni xotiraga saqlashda xatolik yuz berdi: $e");
    }
  }

  @override
  Future<List<LegalResponse>> getSavedCases() async {
    try {
      final List<LegalResponse> cases = [];
      for (final key in box.keys) {
        if (!scope.ownsKey(key)) continue;
        final raw = box.get(key);
        if (raw != null) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          cases.add(LegalResponse.fromJson(map));
        }
      }
      // Sort newest first
      cases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return cases;
    } catch (e) {
      throw CacheException(message: "Saqlangan keyslarni yuklashda xatolik yuz berdi: $e");
    }
  }

  @override
  Future<void> deleteSavedCase(String id) async {
    try {
      await box.delete(scope.keyFor(id));
    } catch (e) {
      throw CacheException(message: "Keysni o'chirishda xatolik yuz berdi: $e");
    }
  }
}
