import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

abstract class CitizenServicesDataSource {
  Future<List<CitizenService>> getServices({String? category, String? searchQuery});
  Future<CitizenService> getServiceById(String serviceId);
}

class CitizenServicesDataSourceImpl implements CitizenServicesDataSource {
  final CitizenServicesLocalDataSource _local = CitizenServicesLocalDataSourceImpl();

  @override
  Future<List<CitizenService>> getServices({String? category, String? searchQuery}) {
    return _local.getServices(category: category, searchQuery: searchQuery);
  }

  @override
  Future<CitizenService> getServiceById(String serviceId) {
    return _local.getServiceById(serviceId);
  }
}
