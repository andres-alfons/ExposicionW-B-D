import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:conectalab/services/image_service.dart';

// Imagen de 1 píxel solo para pruebas; nunca forma parte del chat de producción.
Uint8List testPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class FakeImageGateway implements ImageGateway {
  @override
  bool supportsCamera = true;
  @override
  bool needsCameraPermission = false;
  XFile? file;
  XFile? recovered;
  Object? failure;
  Completer<XFile?>? pending;
  int calls = 0;
  int recoveryCalls = 0;
  @override
  Future<XFile?> pick(ImageSource source) async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? file : pending!.future;
  }

  @override
  Future<XFile?> recover() async {
    recoveryCalls++;
    return recovered;
  }
}

class UnreadableImage extends XFile {
  UnreadableImage() : super('archivo-inexistente.png');
  @override
  Future<int> length() async => 10;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) =>
      Stream.error(StateError('Archivo eliminado'));
}

class OversizedImage extends XFile {
  OversizedImage() : super('grande.png');
  bool opened = false;
  @override
  Future<int> length() async => maxImageBytes + 1;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    opened = true;
    return const Stream.empty();
  }
}
