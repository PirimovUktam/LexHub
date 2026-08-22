import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

abstract class LegalAssistantLocalDataSource {
  Future<void> saveCase(LegalResponse response);
  Future<List<LegalResponse>> getSavedCases();
  Future<void> deleteSavedCase(String id);
}

class LegalAssistantLocalDataSourceImpl implements LegalAssistantLocalDataSource {
  static const String boxName = 'saved_legal_cases_box';
  final Box<String> box;

  LegalAssistantLocalDataSourceImpl({required this.box});

  @override
  Future<void> saveCase(LegalResponse response) async {
    try {
      final jsonMap = response.toJson();
      // mark as saved
      jsonMap['isSaved'] = true;
      final encoded = jsonEncode(jsonMap);
      await box.put(response.id, encoded);
    } catch (e) {
      throw CacheException(message: "Keysni xotiraga saqlashda xatolik yuz berdi: $e");
    }
  }

  @override
  Future<List<LegalResponse>> getSavedCases() async {
    try {
      final List<LegalResponse> cases = [];
      for (final key in box.keys) {
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
      await box.delete(id);
    } catch (e) {
      throw CacheException(message: "Keysni o'chirishda xatolik yuz berdi: $e");
    }
  }
}
