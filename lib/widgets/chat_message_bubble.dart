import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatImageView extends StatelessWidget {
  const ChatImageView({super.key, required this.image, this.height = 180});
  final ChatImage image;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.memory(
      image.bytes,
      height: height,
      width: 360,
      fit: BoxFit.contain,
      cacheWidth: 800,
      semanticLabel: 'Imagen adjunta: ${image.name}',
      errorBuilder: (context, error, stack) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Esta imagen ya no se puede mostrar. El resto del chat sigue disponible.',
        ),
      ),
    ),
  );
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final time = message.createdAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${two(time.day)}/${two(time.month)} ${two(time.hour)}:${two(time.minute)}';
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          margin: const EdgeInsets.only(left: 24, bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: message.image == null
                ? const Color(0xFF12394B)
                : const Color(0xFF18304B),
            border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.sender,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message.image != null) ...[
                const SizedBox(height: 12),
                ChatImageView(image: message.image!),
              ],
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(message.text),
              ],
              const SizedBox(height: 8),
              Text(stamp, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
