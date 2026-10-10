import 'package:conectalab/app.dart';
import 'package:conectalab/services/bluetooth_service.dart';
import 'package:conectalab/services/connectivity_service.dart';
import 'package:conectalab/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bluetooth_fakes.dart';
import 'connectivity_fakes.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 844);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });
  testWidgets(
    'Solicitud denegada mantiene escaneo deshabilitado y diagnóstico accesible',
    (tester) async {
      final gateway = FakePermissionGateway()
        ..current = AccessState.denied
        ..answer = AccessState.settings;
      final permissions = PermissionService(gateway: gateway);
      final backend = FakeBleGateway();
      final bluetooth = BluetoothService(
        permissions: permissions,
        gateway: backend,
      );
      final source = FakeNetworkSource();
      final connectivity = ConnectivityService(
        source: source,
        probe: FakeHttpsProbe(),
      );
      await tester.pumpWidget(
        ConectaLabApp(
          connectivityService: connectivity,
          permissionService: permissions,
          bluetoothService: bluetooth,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bluetooth').last);
      await tester.pumpAndSettle();
      expect(gateway.requests, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Iniciar escaneo'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(find.text('Solicitar permisos'), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solicitar permisos'));
      await tester.pumpAndSettle();
      expect(gateway.requests, 1);
      expect(backend.starts, 0);
      await tester.scrollUntilVisible(
        find.text('Abrir ajustes de la app'),
        120,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir ajustes de la app'));
      await tester.pumpAndSettle();
      expect(permissions.error, contains('manualmente'));
      await tester.tap(find.text('Inicio').last);
      await tester.pumpAndSettle();
      expect(find.text('ConectaLab'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      bluetooth.dispose();
      permissions.dispose();
      connectivity.dispose();
      await backend.close();
      await source.controller.close();
    },
  );

  testWidgets(
    'Escanea, muestra datos reales del proveedor y detiene al navegar',
    (tester) async {
      final permissions = PermissionService(gateway: FakePermissionGateway());
      final backend = FakeBleGateway();
      final bluetooth = BluetoothService(
        permissions: permissions,
        gateway: backend,
      );
      final source = FakeNetworkSource();
      final connectivity = ConnectivityService(
        source: source,
        probe: FakeHttpsProbe(),
      );
      await tester.pumpWidget(
        ConectaLabApp(
          connectivityService: connectivity,
          permissionService: permissions,
          bluetoothService: bluetooth,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bluetooth').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Iniciar escaneo'), 120);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar escaneo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(backend.starts, 1);
      backend.resultEvents.add(const [
        BleDeviceReport(
          id: 'solo-prueba',
          name: 'Sensor simulado en test',
          rssi: -65,
        ),
      ]);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Sensor simulado en test'),
        120,
      );
      expect(find.text('RSSI recibido: -65 dBm'), findsOneWidget);
      await tester.ensureVisible(find.text('Detener escaneo'));
      await tester.pump();
      await tester.tap(find.text('Detener escaneo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Iniciar escaneo'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.text('Iniciar escaneo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar escaneo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(backend.starts, 2);
      await tester.tap(find.text('Permisos').last);
      await tester.pumpAndSettle();
      expect(bluetooth.scanning, isFalse);
      expect(backend.stops, greaterThan(0));
      expect(find.text('Centro de permisos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      bluetooth.dispose();
      permissions.dispose();
      connectivity.dispose();
      await backend.close();
      await source.controller.close();
    },
  );

  testWidgets('Plataforma Web informativa no usa el proveedor BLE', (
    tester,
  ) async {
    final gateway = FakePermissionGateway()
      ..configuration = const PermissionPolicy(
        TargetPlatform.android,
        isWeb: true,
      );
    final permissions = PermissionService(gateway: gateway);
    final backend = FakeBleGateway();
    final bluetooth = BluetoothService(
      permissions: permissions,
      gateway: backend,
    );
    final source = FakeNetworkSource();
    final connectivity = ConnectivityService(
      source: source,
      probe: FakeHttpsProbe(),
    );
    await tester.pumpWidget(
      ConectaLabApp(
        connectivityService: connectivity,
        permissionService: permissions,
        bluetoothService: bluetooth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bluetooth').last);
    await tester.pumpAndSettle();
    expect(backend.supportChecks, 0);
    expect(backend.starts, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Iniciar escaneo'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('No está disponible en esta plataforma'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    bluetooth.dispose();
    permissions.dispose();
    connectivity.dispose();
    await backend.close();
    await source.controller.close();
  });
}
