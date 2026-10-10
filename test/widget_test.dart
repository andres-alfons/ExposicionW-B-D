import 'package:conectalab/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conectalab/services/connectivity_service.dart';
import 'connectivity_fakes.dart';
import 'bluetooth_fakes.dart';
import 'package:conectalab/services/permission_service.dart';
import 'package:conectalab/services/bluetooth_service.dart';
import 'package:conectalab/services/chat_service.dart';
import 'package:conectalab/services/image_service.dart';
import 'image_fakes.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1440, 1000),
    const Size(320, 640),
  ]) {
    testWidgets('Navegación y diagnóstico en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FakeNetworkSource();
      final probe = FakeHttpsProbe();
      final service = ConnectivityService(
        source: source,
        probe: probe,
        isWeb: false,
      );
      final permissions = PermissionService(gateway: FakePermissionGateway());
      final chat = ChatService(
        images: ImageService(
          permissions: permissions,
          gateway: FakeImageGateway(),
        ),
      );
      final backend = FakeBleGateway();
      final bluetooth = BluetoothService(
        permissions: permissions,
        gateway: backend,
      );
      addTearDown(() async {
        service.dispose();
        await source.controller.close();
        bluetooth.dispose();
        chat.dispose();
        permissions.dispose();
        await Future<void>.delayed(Duration.zero);
        await backend.close();
      });
      await tester.pumpWidget(
        ConectaLabApp(
          connectivityService: service,
          permissionService: permissions,
          bluetoothService: bluetooth,
          chatService: chat,
        ),
      );
      await tester.pumpAndSettle();
      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('ConectaLab'), findsOneWidget);
      await reveal(find.text('Transporte reportado: Wi-Fi'));
      expect(find.text('Transporte reportado: Wi-Fi'), findsOneWidget);
      await reveal(find.text('Actualizar diagnóstico'));
      await tester.tap(find.text('Actualizar diagnóstico'));
      await tester.pumpAndSettle();
      expect(
        find.text('HTTPS: Acceso al servidor verificado · HTTP 204'),
        findsOneWidget,
      );
      expect(probe.calls, 2);
      for (final title in ['Datos móviles', 'Wi-Fi']) {
        await reveal(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        await reveal(find.text('Qué observar'));
        expect(find.text('Qué observar'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      for (final title in ['Bluetooth', 'Chat', 'Permisos']) {
        await tester.tap(find.text(title).last);
        await tester.pumpAndSettle();
        expect(
          find.text(switch (title) {
            'Bluetooth' => 'Descubrimiento Bluetooth BLE',
            'Permisos' => 'Centro de permisos',
            _ => 'Chat local',
          }),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('Inicio').last);
      await tester.pumpAndSettle();
      expect(find.text('ConectaLab'), findsOneWidget);
      await reveal(
        find.text(
          'Comunica dispositivos cercanos, como audífonos, sensores y otros accesorios.',
        ),
      );
      await tester.tap(
        find.text(
          'Comunica dispositivos cercanos, como audífonos, sensores y otros accesorios.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Descubrimiento Bluetooth BLE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
