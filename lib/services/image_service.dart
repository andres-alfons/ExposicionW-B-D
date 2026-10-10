import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import 'permission_service.dart';

const maxImageBytes = 5 * 1024 * 1024;

enum ImageSelectionStatus { selected, cancelled, failed }

class ImageSelection {
  const ImageSelection(this.status, {this.image, this.message});
  final ImageSelectionStatus status;
  final ChatImage? image;
  final String? message;
}

abstract interface class ImageGateway {
  bool get supportsCamera;
  bool get needsCameraPermission;
  Future<XFile?> pick(ImageSource source);
  Future<XFile?> recover();
}

class SystemImageGateway implements ImageGateway {
  final ImagePicker _picker = ImagePicker();
  @override
  bool get supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  bool get needsCameraPermission =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  @override
  Future<XFile?> pick(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
    requestFullMetadata: false,
  );
  @override
  Future<XFile?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    return response.files?.firstOrNull;
  }
}

class ImageService {
  ImageService({required this.permissions, ImageGateway? gateway})
    : _gateway = gateway ?? SystemImageGateway();
  final PermissionService permissions;
  final ImageGateway _gateway;
  bool get supportsCamera => _gateway.supportsCamera;

  Future<ImageSelection> pick(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        if (!supportsCamera) {
          return const ImageSelection(
            ImageSelectionStatus.failed,
            message:
                'La captura de cámara no está configurada en esta plataforma. Puedes seleccionar un archivo.',
          );
        }
        if (_gateway.needsCameraPermission) {
          await permissions.refresh();
          if (permissions.busy ||
              !permissions.availablePermissions.contains(
                AppPermission.camera,
              )) {
            return const ImageSelection(
              ImageSelectionStatus.failed,
              message:
                  'No se pudo consultar la cámara. Revisa el centro de permisos.',
            );
          }
          await permissions.request(AppPermission.camera);
          if (permissions.states[AppPermission.camera] != AccessState.granted) {
            return const ImageSelection(
              ImageSelectionStatus.failed,
              message:
                  'La cámara no está autorizada. Revisa Permisos o selecciona una imagen existente.',
            );
          }
        }
      }
      return await _read(await _gateway.pick(source));
    } on PlatformException catch (error) {
      return ImageSelection(
        ImageSelectionStatus.failed,
        message: _platformError(error),
      );
    } catch (_) {
      return const ImageSelection(
        ImageSelectionStatus.failed,
        message:
            'No se pudo abrir o leer la imagen. Selecciona un archivo disponible en este dispositivo.',
      );
    }
  }

  Future<ImageSelection> recover() async {
    try {
      return await _read(await _gateway.recover());
    } catch (_) {
      return const ImageSelection(
        ImageSelectionStatus.failed,
        message:
            'No se pudo recuperar la selección interrumpida. Puedes elegir una imagen otra vez.',
      );
    }
  }

  Future<ImageSelection> _read(XFile? file) async {
    if (file == null) {
      return const ImageSelection(ImageSelectionStatus.cancelled);
    }
    if (await file.length() > maxImageBytes) {
      return const ImageSelection(
        ImageSelectionStatus.failed,
        message: 'La imagen supera 5 MiB. Selecciona una imagen más pequeña.',
      );
    }
    // Lectura acotada: también se verifica el límite si el tamaño cambió o es inexacto.
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > maxImageBytes) {
        return const ImageSelection(
          ImageSelectionStatus.failed,
          message: 'La imagen supera 5 MiB. Selecciona una imagen más pequeña.',
        );
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      return const ImageSelection(
        ImageSelectionStatus.failed,
        message: 'El archivo está vacío o no está disponible.',
      );
    }
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.Codec? codec;
      try {
        // ImageDescriptor.width/height no están disponibles para imágenes
        // codificadas en Web. Esta API ofrece dimensiones en todas las plataformas
        // y se encarga de liberar el buffer (Web puede decodificar antes de medir).
        codec = await ui.instantiateImageCodecWithSize(
          buffer,
          getTargetSize: (width, height) {
            if (width * height > 16000000) {
              throw const FormatException('Demasiados píxeles');
            }
            final scale = math.min(1.0, 800 / math.max(width, height));
            return ui.TargetImageSize(
              width: math.max(1, (width * scale).round()),
              height: math.max(1, (height * scale).round()),
            );
          },
        );
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec?.dispose();
      }
    } on FormatException {
      return const ImageSelection(
        ImageSelectionStatus.failed,
        message:
            'La imagen tiene demasiados píxeles. Reduce su resolución y vuelve a seleccionarla.',
      );
    } catch (_) {
      return const ImageSelection(
        ImageSelectionStatus.failed,
        message:
            'El archivo no es una imagen legible o su formato no es compatible.',
      );
    }
    return ImageSelection(
      ImageSelectionStatus.selected,
      image: ChatImage(
        bytes: bytes,
        name: file.name.isEmpty ? 'Imagen seleccionada' : file.name,
      ),
    );
  }

  String _platformError(PlatformException error) => switch (error.code) {
    'camera_access_denied' ||
    'photo_access_denied' ||
    'camera_access_restricted' ||
    'photo_access_restricted' =>
      'El sistema no autorizó el acceso. Revisa los ajustes de la app o selecciona otra imagen.',
    'no_available_camera' =>
      'No hay una cámara disponible. Puedes seleccionar una imagen existente.',
    'already_active' =>
      'El selector ya está abierto. Termina o cancela la selección actual.',
    _ =>
      'El selector no pudo completar la operación. Intenta con una imagen local disponible.',
  };
}
