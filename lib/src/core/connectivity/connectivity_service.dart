import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device is on an unmetered (Wi-Fi/ethernet) connection,
/// used to honor the "voice over Wi-Fi only" setting. Subclass and override
/// [isWifi] in tests to simulate a connection type.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Whether the active connection is Wi-Fi or ethernet (i.e. unmetered).
  /// Returns `false` if connectivity can't be determined.
  Future<bool> isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }
}
