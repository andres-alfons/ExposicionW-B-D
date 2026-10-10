import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothAdapterState;
import 'package:conectalab/services/bluetooth_service.dart';
import 'package:conectalab/services/permission_service.dart';

class FakePermissionGateway implements PermissionGateway {
  PermissionPolicy configuration = const PermissionPolicy(
    TargetPlatform.android,
    androidSdk: 33,
  );
  AccessState current = AccessState.granted;
  AccessState answer = AccessState.granted;
  int requests = 0;
  bool fail = false;
  @override
  Future<PermissionPolicy> policy() async {
    if (fail) throw StateError('Plugin no disponible');
    return configuration;
  }

  @override
  Future<AccessState> check(AppPermission permission) async => current;
  @override
  Future<AccessState> request(AppPermission permission) async {
    requests++;
    if (fail) throw StateError('Solicitud fallida');
    return current = answer;
  }

  @override
  Future<bool> openSettings() async => false;
}

class FakeBleGateway implements BleGateway {
  final adapterEvents = StreamController<BluetoothAdapterState>.broadcast(
    sync: true,
  );
  final scanEvents = StreamController<bool>.broadcast(sync: true);
  final resultEvents = StreamController<List<BleDeviceReport>>.broadcast(
    sync: true,
  );
  BluetoothAdapterState state = BluetoothAdapterState.on;
  bool available = true;
  bool fail = false;
  int starts = 0;
  int stops = 0;
  int supportChecks = 0;
  Completer<void>? pendingStart;
  @override
  Future<bool> isSupported() async {
    supportChecks++;
    return available;
  }

  @override
  Stream<BluetoothAdapterState> get adapter async* {
    yield state;
    yield* adapterEvents.stream;
  }

  @override
  Stream<bool> get scanning => scanEvents.stream;
  @override
  Stream<List<BleDeviceReport>> get results => resultEvents.stream;
  @override
  Future<void> start() async {
    starts++;
    if (fail) throw StateError('Escaneo fallido');
    if (pendingStart != null) await pendingStart!.future;
    scanEvents.add(true);
  }

  @override
  Future<void> stop() async {
    stops++;
    scanEvents.add(false);
  }

  Future<void> close() async {
    await adapterEvents.close();
    await scanEvents.close();
    await resultEvents.close();
  }
}
