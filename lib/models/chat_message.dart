import 'dart:typed_data';

/// Copia de sesión del archivo elegido: nunca almacena una ruta temporal.
class ChatImage {
  ChatImage({required Uint8List bytes, required this.name})
    : bytes = bytes.asUnmodifiableView();
  final Uint8List bytes;
  final String name;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.createdAt,
    required this.text,
    this.image,
  });
  final int id;
  final DateTime createdAt;
  final String text;
  final ChatImage? image;
  String get sender => 'Tú · este dispositivo';
}

String? validateMessage(String text, {ChatImage? image}) {
  if (text.trim().isEmpty && image == null) {
    return 'Escribe un mensaje o adjunta una imagen.';
  }
  if (text.trim().length > 4000) {
    return 'El mensaje admite hasta 4000 caracteres.';
  }
  return null;
}
