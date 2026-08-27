import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_remote_datasource.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:lexhub/features/citizen_services/domain/repositories/citizen_services_repository.dart';

/// XATO MAPPINGI MARKAZDAN (`ErrorHandler.handle`) o'tadi.
///
/// Ilgari ikkala shox `ServerFailure(message: "...: $e")` qurardi. Ikki nuqson:
/// (1) `code` (`FailureCode`) TO'LDIRILMASDI — ingliz UI xato matnini ARB'dan
/// tanlay olmasdi va timeout "server xatosi" bo'lib ko'rinardi; (2) XOM
/// `$e` (`TimeoutException after 0:00:20.000000: ...`) to'g'ridan-to'g'ri
/// foydalanuvchi ekraniga chiqardi. `ErrorHandler` matnni sanitizatsiya qiladi
/// va texnik tafsilotni `details` ga yuboradi.
class CitizenServicesRepositoryImpl implements CitizenServicesRepository {
  final CitizenServicesRemoteDataSource remoteDataSource;
  final CitizenServicesLocalDataSource localDataSource;

  CitizenServicesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<CitizenService>>> getServices({String? category, String? searchQuery}) async {
    try {
      final services = await remoteDataSource.getServices(category: category, searchQuery: searchQuery);
      return Right(services);
    } catch (e) {
      try {
        final localServices = await localDataSource.getServices(category: category, searchQuery: searchQuery);
        return Right(localServices);
      } catch (localError) {
        // Foydalanuvchiga BIRINCHI sabab (`e` — tarmoq/timeout) ko'rsatiladi:
        // u aynan shu narsani hal qila oladi. Mahalliy katalogning yiqilishi
        // (bundle nosozligi) log'da qoladi, jim yo'qolmaydi.
        if (kDebugMode) {
          debugPrint('[citizen-services] mahalliy katalog ham yiqildi: $localError');
        }
        return Left(ErrorHandler.handle(e));
      }
    }
  }

  @override
  Future<Either<Failure, CitizenService>> getServiceById(String serviceId) async {
    try {
      final service = await remoteDataSource.getServiceById(serviceId);
      return Right(service);
    } catch (e) {
      try {
        final localService = await localDataSource.getServiceById(serviceId);
        return Right(localService);
      } catch (localError) {
        if (kDebugMode) {
          debugPrint('[citizen-services] mahalliy xizmat ham topilmadi: $localError');
        }
        return Left(ErrorHandler.handle(e));
      }
    }
  }
}
