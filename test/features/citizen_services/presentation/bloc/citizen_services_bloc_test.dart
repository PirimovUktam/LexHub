import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:lexhub/features/citizen_services/domain/repositories/citizen_services_repository.dart';
import 'package:lexhub/features/citizen_services/domain/usecases/get_citizen_services_usecase.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_bloc.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_event.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_state.dart';

class MockCitizenServicesRepository implements CitizenServicesRepository {
  final List<CitizenService> services = [
    const CitizenService(
      id: 'test_service_1',
      title: "YHQ jarimalari bo'yicha 50% chegirma",
      category: "Yo'l harakati",
      department: "IIV",
      description: "Tavsif",
      processingDays: 15,
      isFree: true,
      onlineUrl: "https://my.gov.uz",
    ),
  ];

  @override
  Future<Either<Failure, List<CitizenService>>> getServices({String? category, String? searchQuery}) async {
    return Right(services);
  }

  @override
  Future<Either<Failure, CitizenService>> getServiceById(String serviceId) async {
    return Right(services.first);
  }
}

void main() {
  late MockCitizenServicesRepository repository;
  late CitizenServicesBloc bloc;

  setUp(() {
    repository = MockCitizenServicesRepository();
    bloc = CitizenServicesBloc(
      getCitizenServicesUseCase: GetCitizenServicesUseCase(repository),
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be CitizenServicesInitial', () {
    expect(bloc.state, isA<CitizenServicesInitial>());
  });

  test('emits CitizenServicesLoading and CitizenServicesLoaded on LoadCitizenServicesEvent', () async {
    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<CitizenServicesLoading>(),
        isA<CitizenServicesLoaded>(),
      ]),
    );

    bloc.add(const LoadCitizenServicesEvent());
  });

  test('filters services by category properly', () async {
    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<CitizenServicesLoading>(),
        isA<CitizenServicesLoaded>(),
      ]),
    );

    bloc.add(const FilterServicesByCategoryEvent("Yo'l harakati"));
  });
}
