import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothAdapterState;
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:conectalab/services/bluetooth_service.dart';
import 'package:conectalab/services/permission_service.dart';
import 'bluetooth_fakes.dart';

void main() {
  test('Hardware no compatible mantiene controles bloqueados', () async {
    final permissions = PermissionService(gateway: FakePermissionGateway());
    final backend = FakeBleGateway()..available = false;
    final service = BluetoothService(
      permissions: permissions,
      gateway: backend,
    );
    await service.activate();
    await service.start();
    expect(service.hardwareSupported, isFalse);
    expect(service.canScan, isFalse);
    expect(backend.starts, 0);
    service.dispose();
    permissions.dispose();
    await backend.close();
  });

  test(
    'Revocar permiso detiene escaneo; error de resultados no se oculta',
    () async {
      final gateway = FakePermissionGateway();
      final permissions = PermissionService(gateway: gateway);
      final backend = FakeBleGateway();
      final service = BluetoothService(
        permissions: permissions,
        gateway: backend,
      );
      await service.activate();
      await service.start();
      expect(service.scanning, isTrue);
      gateway.current = AccessState.denied;
      await permissions.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(service.scanning, isFalse);
      expect(service.canScan, isFalse);
      gateway.current = AccessState.granted;
      await service.activate();
      await service.start();
      backend.resultEvents.addError(StateError('Error de radio'));
      await Future<void>.delayed(Duration.zero);
      expect(service.error, contains('error'));
      expect(service.scanning, isFalse);
      expect(service.canScan, isFalse);
      service.dispose();
      permissions.dispose();
      await Future<void>.delayed(Duration.zero);
      await backend.close();
    },
  );
  test('Política por versión Android y plataforma', () {
    expect(
      const PermissionPolicy(
        TargetPlatform.android,
        androidSdk: 31,
      ).requiredPermissions,
      [AppPermission.scan, AppPermission.connect],
    );
    expect(
      const PermissionPolicy(
        TargetPlatform.android,
        androidSdk: 30,
      ).requiredPermissions,
      [AppPermission.location],
    );
    expect(
      const PermissionPolicy(
        TargetPlatform.android,
        androidSdk: 22,
      ).requiredPermissions,
      isEmpty,
    );
    expect(const PermissionPolicy(TargetPlatform.android).supported, isFalse);
    expect(const PermissionPolicy(TargetPlatform.iOS).requiredPermissions, [
      AppPermission.bluetooth,
    ]);
    expect(
      const PermissionPolicy(
        TargetPlatform.android,
        androidSdk: 35,
        isWeb: true,
      ).supported,
      isFalse,
    );
    expect(const PermissionPolicy(TargetPlatform.windows).supported, isFalse);
  });
  test(
    'Clasifica todos los resultados sin convertir limitado en concedido',
    () {
      final expected = [
        AccessState.denied,
        AccessState.granted,
        AccessState.restricted,
        AccessState.limited,
        AccessState.settings,
        AccessState.limited,
      ];
      for (var i = 0; i < ph.PermissionStatus.values.length; i++) {
        expect(classifyPermission(ph.PermissionStatus.values[i]), expected[i]);
      }
      expect(
        adapterDescription(BluetoothAdapterState.off),
        contains('Apagado'),
      );
      expect(
        adapterDescription(BluetoothAdapterState.unauthorized),
        contains('autorización'),
      );
    },
  );
  test(
    'Sin solicitudes automáticas; denegación detiene ventanas encadenadas',
    () async {
      final gateway = FakePermissionGateway()
        ..current = AccessState.denied
        ..answer = AccessState.settings;
      final service = PermissionService(gateway: gateway);
      await service.refresh();
      expect(gateway.requests, 0);
      await service.requestBluetooth();
      expect(gateway.requests, 1);
      expect(service.granted, isFalse);
      expect(
        service.requestResults[AppPermission.scan],
        contains('permanentemente'),
      );
      await service.request(AppPermission.scan);
      expect(gateway.requests, 1);
      await service.openSettings();
      expect(service.error, isNotNull);
      service.dispose();
    },
  );
  test('Errores de consulta y solicitud no habilitan el escaneo', () async {
    final gateway = FakePermissionGateway()..current = AccessState.denied;
    final service = PermissionService(gateway: gateway);
    await service.refresh();
    gateway.fail = true;
    await service.request(AppPermission.scan);
    expect(service.states[AppPermission.scan], AccessState.unknown);
    expect(service.granted, isFalse);
    await service.refresh();
    expect(service.supported, isFalse);
    expect(service.error, isNotNull);
    service.dispose();
  });
  test('No toca BLE sin permiso ni en Web', () async {
    final gateway = FakePermissionGateway()..current = AccessState.denied;
    final permissions = PermissionService(gateway: gateway);
    final backend = FakeBleGateway();
    final service = BluetoothService(
      permissions: permissions,
      gateway: backend,
    );
    await service.activate();
    await service.start();
    expect(backend.supportChecks, 0);
    expect(backend.starts, 0);
    gateway.configuration = const PermissionPolicy(
      TargetPlatform.android,
      isWeb: true,
    );
    gateway.current = AccessState.granted;
    await service.activate();
    expect(backend.supportChecks, 0);
    service.dispose();
    permissions.dispose();
    await backend.close();
  });
  test(
    'Escaneo único, resultados por identificador y apagado del adaptador',
    () async {
      final permissions = PermissionService(gateway: FakePermissionGateway());
      final backend = FakeBleGateway();
      final service = BluetoothService(
        permissions: permissions,
        gateway: backend,
      );
      await service.activate();
      await Future<void>.delayed(Duration.zero);
      expect(service.canScan, isTrue);
      final first = service.start();
      await service.start();
      await first;
      expect(backend.starts, 1);
      backend.resultEvents.add(const [
        BleDeviceReport(id: 'test', name: '', rssi: -80),
      ]);
      backend.resultEvents.add(const [
        BleDeviceReport(id: 'test', name: 'Sensor de prueba', rssi: -50),
      ]);
      expect(service.devices.length, 1);
      expect(service.devices.single.rssi, -50);
      backend.adapterEvents.add(BluetoothAdapterState.off);
      await Future<void>.delayed(Duration.zero);
      expect(service.scanning, isFalse);
      expect(service.canScan, isFalse);
      service.dispose();
      permissions.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(backend.resultEvents.hasListener, isFalse);
      await backend.close();
    },
  );
  test('Fallo de escaneo se presenta y permite reintentar', () async {
    final permissions = PermissionService(gateway: FakePermissionGateway());
    final backend = FakeBleGateway()..fail = true;
    final service = BluetoothService(
      permissions: permissions,
      gateway: backend,
    );
    await service.activate();
    await Future<void>.delayed(Duration.zero);
    await service.start();
    expect(service.error, isNotNull);
    expect(service.busy, isFalse);
    expect(service.scanning, isFalse);
    backend.fail = false;
    await service.start();
    expect(service.scanning, isTrue);
    service.deactivate();
    await Future<void>.delayed(Duration.zero);
    expect(service.scanning, isFalse);
    service.dispose();
    permissions.dispose();
    await Future<void>.delayed(Duration.zero);
    await backend.close();
  });
  test(
    'Salir durante inicio detiene la búsqueda y dispose no notifica',
    () async {
      final permissions = PermissionService(gateway: FakePermissionGateway());
      final backend = FakeBleGateway()..pendingStart = Completer<void>();
      final service = BluetoothService(
        permissions: permissions,
        gateway: backend,
      );
      await service.activate();
      await Future<void>.delayed(Duration.zero);
      final operation = service.start();
      await Future<void>.delayed(Duration.zero);
      expect(backend.starts, 1);
      var notifications = 0;
      service.addListener(() => notifications++);
      service.deactivate();
      service.dispose();
      final count = notifications;
      backend.pendingStart!.complete();
      await operation;
      await Future<void>.delayed(Duration.zero);
      expect(backend.stops, greaterThan(0));
      expect(notifications, count);
      permissions.dispose();
      await backend.close();
    },
  );
}
