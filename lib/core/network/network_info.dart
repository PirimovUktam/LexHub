/// Contract for checking network connectivity
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Simple implementation for network connectivity
class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // In production, can use connectivity_plus or internet_connection_checker
    return true;
  }
}
