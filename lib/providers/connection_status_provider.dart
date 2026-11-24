import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

final networkServiceProvider =
    StateNotifierProvider<NetworkNotifier, bool>((ref) {
  return NetworkNotifier();
});

/// Tracks live network availability across mobile (Wi-Fi/cellular) and desktop
/// (Ethernet/VPN) interfaces.
class NetworkNotifier extends StateNotifier<bool> {
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _internetChecker =
      InternetConnectionChecker.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetConnectionStatus>? _internetCheckerSubscription;

  NetworkNotifier() : super(true) {
    _init();
    _setupListeners();
  }

  bool _hasNetworkInterface(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn);
  }

  Future<void> _evaluateConnectivity(List<ConnectivityResult> results) async {
    if (!_hasNetworkInterface(results)) {
      if (mounted) state = false;
      return;
    }

    if (kIsWeb) {
      if (mounted) state = true;
      return;
    }

    try {
      final hasInternet = await _internetChecker.hasConnection;
      if (mounted) state = hasInternet;
    } catch (_) {
      if (mounted) state = true;
    }
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _evaluateConnectivity(results);
    } catch (_) {}
  }

  void _setupListeners() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_evaluateConnectivity);

    if (!kIsWeb) {
      _internetCheckerSubscription =
          _internetChecker.onStatusChange.listen((status) {
        if (mounted) {
          state = status == InternetConnectionStatus.connected;
        }
      });
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _evaluateConnectivity(results);
    } catch (_) {}
    return state;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _internetCheckerSubscription?.cancel();
    super.dispose();
  }
}
