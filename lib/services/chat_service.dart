import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import 'image_service.dart';

/// Historial de sesión compartido por las pestañas. No depende de una red.
class ChatService extends ChangeNotifier {
  ChatService({required this.images, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final ImageService images;
  final DateTime Function() _now;
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatImage? preview;
  bool busy = false;
  String? error;
  String? notice;
  bool _disposed = false;
  bool _recovered = false;
  int _nextId = 0;
  int _imageBytes = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? send(String text) {
    if (_disposed) return 'El chat ya se cerró.';
    if (busy) return 'Espera a que termine la selección de imagen.';
    final validation = validateMessage(text, image: preview);
    if (validation != null) return _fail(validation);
    if (_messages.length >= 200) {
      return _fail(
        'La sesión admite 200 mensajes. Borra el historial para continuar.',
      );
    }
    if (_imageBytes + (preview?.bytes.length ?? 0) > 25 * 1024 * 1024) {
      return _fail(
        'Las imágenes de esta sesión alcanzaron el límite de 25 MiB. Cancela la imagen o borra el historial.',
      );
    }
    _messages.add(
      ChatMessage(
        id: _nextId++,
        createdAt: _now(),
        text: text.trim(),
        image: preview,
      ),
    );
    _imageBytes += preview?.bytes.length ?? 0;
    preview = null;
    error = null;
    notice = 'Mensaje añadido al historial local.';
    _notify();
    return null;
  }

  String _fail(String message) {
    error = message;
    _notify();
    return message;
  }

  Future<void> selectImage(ImageSource source) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notice = null;
    _notify();
    final result = await images.pick(source);
    if (_disposed) return;
    _applySelection(result);
    busy = false;
    _notify();
  }

  Future<void> recoverImage() async {
    if (_recovered || _disposed || busy) return;
    _recovered = true;
    busy = true;
    _notify();
    final result = await images.recover();
    if (_disposed) return;
    _applySelection(result, recovered: true);
    busy = false;
    _notify();
  }

  void _applySelection(ImageSelection result, {bool recovered = false}) {
    switch (result.status) {
      case ImageSelectionStatus.selected:
        preview = result.image;
        error = null;
        notice = recovered
            ? 'Selección recuperada tras una interrupción. Confirma antes de añadirla al chat.'
            : 'Imagen lista para previsualizar. Confirma o cancela.';
      case ImageSelectionStatus.cancelled:
        if (!recovered) {
          notice = 'Selección cancelada; no se añadió ningún mensaje.';
        }
      case ImageSelectionStatus.failed:
        error = result.message;
    }
  }

  void cancelImage() {
    if (_disposed || busy) return;
    preview = null;
    error = null;
    notice = 'Imagen descartada.';
    _notify();
  }

  void clear() {
    if (_disposed || busy) return;
    _messages.clear();
    preview = null;
    _imageBytes = 0;
    error = null;
    notice = 'Historial local borrado.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _messages.clear();
    preview = null;
    super.dispose();
  }
}
