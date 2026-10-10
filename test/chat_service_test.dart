import 'dart:async';
import 'package:conectalab/models/chat_message.dart';
import 'package:conectalab/services/chat_service.dart';
import 'package:conectalab/services/image_service.dart';
import 'package:conectalab/services/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'bluetooth_fakes.dart';
import 'image_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PermissionService permissions;
  late FakePermissionGateway permissionGateway;
  late FakeImageGateway gateway;
  late ImageService images;
  setUp(() {
    permissionGateway = FakePermissionGateway();
    permissions = PermissionService(gateway: permissionGateway);
    gateway = FakeImageGateway();
    images = ImageService(permissions: permissions, gateway: gateway);
  });
  tearDown(() => permissions.dispose());

  test('Valida vacío, espacios, longitud y mensajes solo con imagen', () {
    expect(validateMessage(' \n '), isNotNull);
    expect(validateMessage('hola'), isNull);
    expect(validateMessage('a' * 4001), isNotNull);
    expect(
      validateMessage(
        '',
        image: ChatImage(bytes: testPng(), name: 'test.png'),
      ),
      isNull,
    );
  });
  test(
    'Mensajes locales con remitente y hora; una nueva sesión queda vacía',
    () {
      final time = DateTime(2026, 10, 9, 20, 30);
      final chat = ChatService(images: images, now: () => time);
      expect(chat.send('  '), isNotNull);
      expect(chat.messages, isEmpty);
      expect(chat.send(' hola sin red '), isNull);
      expect(chat.messages.single.text, 'hola sin red');
      expect(chat.messages.single.createdAt, time);
      expect(chat.messages.single.sender, 'Tú · este dispositivo');
      expect(() => chat.messages.clear(), throwsUnsupportedError);
      chat.dispose();
      final fresh = ChatService(images: images);
      expect(fresh.messages, isEmpty);
      fresh.dispose();
    },
  );
  test(
    'Cancelación del selector y cancelación de vista previa no crean mensajes',
    () async {
      final chat = ChatService(images: images);
      await chat.selectImage(ImageSource.gallery);
      expect(chat.preview, isNull);
      expect(chat.messages, isEmpty);
      expect(chat.notice, contains('cancelada'));
      gateway.file = XFile.fromData(testPng(), name: 'test.png');
      await chat.selectImage(ImageSource.gallery);
      expect(chat.preview, isNotNull);
      expect(chat.messages, isEmpty);
      chat.cancelImage();
      expect(chat.preview, isNull);
      expect(chat.messages, isEmpty);
      chat.dispose();
    },
  );
  test(
    'Lee imagen real del proveedor, previsualiza y confirma sin usar rutas',
    () async {
      gateway.file = XFile.fromData(testPng(), name: 'foto.png');
      final chat = ChatService(images: images);
      await chat.selectImage(ImageSource.gallery);
      expect(chat.preview!.bytes, orderedEquals(testPng()));
      expect(chat.messages, isEmpty);
      expect(chat.send('Mi imagen'), isNull);
      gateway.file = null;
      expect(chat.messages.single.image!.name, 'Imagen seleccionada');
      expect(chat.messages.single.image!.bytes, orderedEquals(testPng()));
      expect(chat.preview, isNull);
      chat.clear();
      expect(chat.messages, isEmpty);
      chat.dispose();
    },
  );
  test('Archivos ilegibles, corruptos, vacíos y grandes se rechazan', () async {
    for (final file in [
      UnreadableImage(),
      XFile.fromData(Uint8List.fromList([1, 2, 3])),
      XFile.fromData(Uint8List(0)),
    ]) {
      gateway.file = file;
      expect(
        (await images.pick(ImageSource.gallery)).status,
        ImageSelectionStatus.failed,
      );
    }
    final big = OversizedImage();
    gateway.file = big;
    final result = await images.pick(ImageSource.gallery);
    expect(result.message, contains('5 MiB'));
    expect(big.opened, isFalse);
  });
  test('Error y denegación nativa del selector se explican', () async {
    gateway.failure = PlatformException(code: 'photo_access_denied');
    expect(
      (await images.pick(ImageSource.gallery)).message,
      contains('autorizó'),
    );
    gateway.failure = StateError('Archivo no disponible');
    expect(
      (await images.pick(ImageSource.gallery)).status,
      ImageSelectionStatus.failed,
    );
  });
  test(
    'Permiso cámara iOS independiente de BLE; galería no pide permiso global',
    () async {
      permissionGateway.configuration = const PermissionPolicy(
        TargetPlatform.iOS,
      );
      permissionGateway.current = AccessState.denied;
      permissionGateway.answer = AccessState.settings;
      gateway.needsCameraPermission = true;
      gateway.file = XFile.fromData(testPng(), name: 'foto.png');
      expect(
        (await images.pick(ImageSource.camera)).status,
        ImageSelectionStatus.failed,
      );
      expect(gateway.calls, 0);
      expect(permissionGateway.requests, 1);
      expect(permissions.states[AppPermission.camera], AccessState.settings);
      expect(permissions.requiredPermissions, [AppPermission.bluetooth]);
      expect(
        (await images.pick(ImageSource.gallery)).status,
        ImageSelectionStatus.selected,
      );
      expect(permissionGateway.requests, 1);
    },
  );
  test(
    'Captura incompatible no abre selector; Android no solicita CAMERA',
    () async {
      gateway.supportsCamera = false;
      expect(
        (await images.pick(ImageSource.camera)).status,
        ImageSelectionStatus.failed,
      );
      expect(gateway.calls, 0);
      gateway.supportsCamera = true;
      gateway.file = XFile.fromData(testPng());
      expect(
        (await images.pick(ImageSource.camera)).status,
        ImageSelectionStatus.selected,
      );
      expect(permissionGateway.requests, 0);
    },
  );
  test(
    'Recuperación Android se hace una vez y necesita confirmación',
    () async {
      gateway.recovered = XFile.fromData(testPng(), name: 'recuperada.png');
      final chat = ChatService(images: images);
      await chat.recoverImage();
      await chat.recoverImage();
      expect(gateway.recoveryCalls, 1);
      expect(chat.messages, isEmpty);
      expect(chat.preview!.name, 'Imagen seleccionada');
      expect(chat.notice, contains('recuperada'));
      chat.dispose();
    },
  );
  test('Evita selectores simultáneos y notificaciones tras dispose', () async {
    gateway.pending = Completer<XFile?>();
    final chat = ChatService(images: images);
    final pending = chat.selectImage(ImageSource.gallery);
    await chat.selectImage(ImageSource.gallery);
    expect(gateway.calls, 1);
    expect(chat.send('texto'), isNotNull);
    var notifications = 0;
    chat.addListener(() => notifications++);
    chat.dispose();
    final count = notifications;
    gateway.pending!.complete(XFile.fromData(testPng()));
    await pending;
    expect(notifications, count);
    expect(chat.messages, isEmpty);
  });
  test(
    'El historial tiene un límite explícito, sin borrar mensajes silenciosamente',
    () {
      final chat = ChatService(images: images);
      for (var i = 0; i < 200; i++) {
        expect(chat.send('Mensaje local $i'), isNull);
      }
      expect(chat.send('Mensaje extra'), contains('200'));
      expect(chat.messages.length, 200);
      chat.clear();
      expect(chat.send('Nueva sesión'), isNull);
      chat.dispose();
    },
  );
}
