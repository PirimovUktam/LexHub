import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_remote_datasource.dart';
import 'package:lexhub/features/citizen_services/data/repositories/citizen_services_repository_impl.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

class MockRemoteDataSource implements CitizenServicesRemoteDataSource {
  bool shouldThrow = false;
  List<CitizenService> mockServices = [
    const CitizenService(
      id: 'service_remote_1',
      title: 'Remote Xizmat',
      category: 'Yo\'l harakati',
      department: 'IIV',
      description: 'Remote tavsif',
      sourceUrl: 'https://lex.uz',
    ),
  ];

  @override
  Future<List<CitizenService>> getServices({String? category, String? searchQuery}) async {
    if (shouldThrow) throw Exception('Remote network failure');
    return mockServices;
  }

  @override
  Future<CitizenService> getServiceById(String serviceId) async {
    if (shouldThrow) throw Exception('Remote network failure');
    return mockServices.first;
  }
}

class MockLocalDataSource implements CitizenServicesLocalDataSource {
  List<CitizenService> mockServices = [
    const CitizenService(
      id: 'service_local_1',
      title: 'Local Fallback Xizmat',
      category: 'Mehnat huquqi',
      department: 'Bandlik vazirligi',
      description: 'Local tavsif',
    ),
  ];

  @override
  Future<List<CitizenService>> getServices({String? category, String? searchQuery}) async {
    return mockServices;
  }

  @override
  Future<CitizenService> getServiceById(String serviceId) async {
    return mockServices.first;
  }
}

void main() {
  late MockRemoteDataSource mockRemote;
  late MockLocalDataSource mockLocal;
  late CitizenServicesRepositoryImpl repository;

  setUp(() {
    mockRemote = MockRemoteDataSource();
    mockLocal = MockLocalDataSource();
    repository = CitizenServicesRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
    );
  });

  group('CitizenServicesRepositoryImpl Offline-First Pattern', () {
    test('should return remote data when remote call succeeds', () async {
      mockRemote.shouldThrow = false;

      final result = await repository.getServices();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should have returned Right'),
        (services) {
          expect(services.length, 1);
          expect(services.first.id, 'service_remote_1');
          expect(services.first.sourceUrl, 'https://lex.uz');
        },
      );
    });

    test('should fallback to local data when remote call fails', () async {
      mockRemote.shouldThrow = true;

      final result = await repository.getServices();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should have returned Right via fallback'),
        (services) {
          expect(services.length, 1);
          expect(services.first.id, 'service_local_1');
          expect(services.first.title, 'Local Fallback Xizmat');
        },
      );
    });
  });
}
