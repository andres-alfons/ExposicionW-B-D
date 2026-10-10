import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conectalab/app.dart';
import 'package:conectalab/services/chat_service.dart';
import 'package:conectalab/services/connectivity_service.dart';
import 'package:conectalab/services/image_service.dart';
import 'package:conectalab/services/permission_service.dart';
import 'package:conectalab/widgets/chat_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'bluetooth_fakes.dart';
import 'connectivity_fakes.dart';
import 'image_fakes.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1440, 1000)]) {
    testWidgets(
      'Chat offline, validación, imágenes y diagnóstico compartido en $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final permissions = PermissionService(gateway: FakePermissionGateway());
        final gateway = FakeImageGateway()..supportsCamera = false;
        final chat = ChatService(
          images: ImageService(permissions: permissions, gateway: gateway),
          now: () => DateTime(2026, 10, 9, 21, 15),
        );
        final source = FakeNetworkSource()..values = [ConnectivityResult.none];
        final probe = FakeHttpsProbe()
          ..result = HttpsResult(
            HttpsStatus.failed,
            checkedAt: DateTime(2026, 10, 9, 21),
          );
        final connectivity = ConnectivityService(
          source: source,
          probe: probe,
          isWeb: false,
        );
        addTearDown(() async {
          chat.dispose();
          permissions.dispose();
          connectivity.dispose();
          await source.controller.close();
        });
        await tester.pumpWidget(
          ConectaLabApp(
            connectivityService: connectivity,
            permissionService: permissions,
            chatService: chat,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chat').last);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Modo local: los mensajes se muestran únicamente en este dispositivo',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Añadir mensaje local'));
        await tester.pumpAndSettle();
        expect(
          find.text('Escribe un mensaje o adjunta una imagen.'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), 'Hola sin Internet');
        await tester.tap(find.byTooltip('Añadir mensaje local'));
        await tester.pumpAndSettle();
        expect(find.text('Hola sin Internet'), findsOneWidget);
        expect(find.text('09/10 21:15'), findsOneWidget);
        expect(probe.calls, 1);
        await tester.tap(find.byTooltip('Adjuntar imagen'));
        await tester.pumpAndSettle();
        expect(find.text('Tomar fotografía'), findsNothing);
        await tester.runAsync(() async {
          await tester.tap(find.text('Seleccionar imagen'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(chat.messages.length, 1);
        expect(chat.preview, isNull);
        gateway.file = XFile.fromData(testPng(), name: 'archivo-elegido.png');
        await tester.runAsync(() => chat.selectImage(ImageSource.gallery));
        await tester.pumpAndSettle();
        expect(find.text('Vista previa'), findsOneWidget);
        expect(chat.messages.length, 1);
        await tester.tap(
          size.width < 400
              ? find.byTooltip('Cancelar imagen')
              : find.text('Cancelar imagen'),
        );
        await tester.pumpAndSettle();
        expect(chat.preview, isNull);
        expect(chat.messages.length, 1);
        await tester.runAsync(() => chat.selectImage(ImageSource.gallery));
        await tester.pumpAndSettle();
        await tester.tap(
          size.width < 400
              ? find.byTooltip('Confirmar imagen')
              : find.text('Confirmar imagen'),
        );
        await tester.pumpAndSettle();
        expect(chat.messages.length, 2);
        expect(find.byType(ChatImageView), findsOneWidget);
        await tester.tap(find.text('Inicio').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chat').last);
        await tester.pumpAndSettle();
        expect(chat.messages.length, 2);
        await tester.tap(
          find.byTooltip('Ver diagnóstico y funcionamiento sin Internet'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Transporte reportado: Sin transporte de red reportado'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Actualizar diagnóstico'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Actualizar diagnóstico'));
        await tester.pumpAndSettle();
        expect(probe.calls, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Auto desplazamiento, teclado y errores de imagen no rompen chat',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final permissions = PermissionService(gateway: FakePermissionGateway());
      final gateway = FakeImageGateway();
      final chat = ChatService(
        images: ImageService(permissions: permissions, gateway: gateway),
      );
      final source = FakeNetworkSource();
      final connectivity = ConnectivityService(
        source: source,
        probe: FakeHttpsProbe(),
      );
      addTearDown(() async {
        chat.dispose();
        permissions.dispose();
        connectivity.dispose();
        await source.controller.close();
      });
      await tester.pumpWidget(
        ConectaLabApp(
          connectivityService: connectivity,
          permissionService: permissions,
          chatService: chat,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 25; i++) {
        chat.send('Mensaje de prueba $i');
      }
      await tester.pumpAndSettle();
      expect(find.text('Mensaje de prueba 24'), findsOneWidget);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.controller!.offset,
        closeTo(list.controller!.position.maxScrollExtent, 1),
      );
      gateway.file = XFile.fromData(testPng(), name: 'teclado.png');
      await tester.runAsync(() => chat.selectImage(ImageSource.gallery));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      chat.cancelImage();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      gateway.failure = StateError('El selector falló');
      await chat.selectImage(ImageSource.gallery);
      await tester.pumpAndSettle();
      expect(chat.error, isNotNull);
      expect(chat.messages.length, 25);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
