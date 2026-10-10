import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/connectivity_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat, required this.connectivity});
  final ChatService chat;
  final ConnectivityService connectivity;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;
  @override
  void initState() {
    super.initState();
    _lastCount = widget.chat.messages.length;
    widget.chat.addListener(_chatChanged);
    _scrollToLatest();
  }

  void _chatChanged() {
    if (!mounted) return;
    final count = widget.chat.messages.length;
    if (_lastCount != count) {
      _lastCount = count;
      _scrollToLatest();
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    if (widget.chat.send(_text.text) == null) {
      _text.clear();
      _scrollToLatest();
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar el historial local?'),
        content: const Text(
          'Se quitarán los mensajes y las imágenes de esta sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.chat.clear();
  }

  void _diagnosis() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Funciones locales y operaciones remotas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Escribir, mostrar mensajes y leer una imagen disponible son acciones locales: no necesitan Internet ni una conexión con otro dispositivo. Una imagen almacenada solo en la nube puede necesitar conexión para que el selector la descargue.',
            ),
            const SizedBox(height: 12),
            const Text(
              'El transporte reportado (Wi-Fi, celular u otros) es distinto del acceso a un servidor. La prueba HTTPS sí realiza una operación remota; sus errores se muestran tal como ocurren. Un fallo puede deberse también a DNS, TLS, CORS o al servidor.',
            ),
            const SizedBox(height: 20),
            ConnectivityCard(service: widget.connectivity),
            const SizedBox(height: 12),
            const Text(
              'No existe comunicación remota de chat. Los mensajes no se envían por Internet ni por Bluetooth.',
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    widget.chat.removeListener(_chatChanged);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListenableBuilder(
        listenable: widget.chat,
        builder: (context, _) {
          final chat = widget.chat;
          final compact =
              MediaQuery.sizeOf(context).width < 400 ||
              MediaQuery.sizeOf(context).height < 600 ||
              MediaQuery.viewInsetsOf(context).bottom > 0;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, compact ? 4 : 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Chat local',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _diagnosis,
                          tooltip:
                              'Ver diagnóstico y funcionamiento sin Internet',
                          icon: const Icon(Icons.monitor_heart_outlined),
                        ),
                        IconButton(
                          onPressed: chat.busy || chat.messages.isEmpty
                              ? null
                              : _clear,
                          tooltip: 'Borrar historial local',
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const Text(
                      'Modo local: los mensajes se muestran únicamente en este dispositivo',
                      style: TextStyle(color: Color(0xFF83E5F7)),
                    ),
                    if (!compact)
                      const Text(
                        'Historial de sesión: se pierde al cerrar la app o recargar Web.',
                        style: TextStyle(fontSize: 12),
                      ),
                    if (!compact) const SizedBox(height: 4),
                    if (!compact)
                      ListenableBuilder(
                        listenable: widget.connectivity,
                        builder: (context, _) => Text(switch (widget
                            .connectivity
                            .https
                            .status) {
                          HttpsStatus.notChecked =>
                            'HTTPS: pendiente o sin verificar',
                          HttpsStatus.checking =>
                            'HTTPS: comprobación en curso',
                          HttpsStatus.response =>
                            'HTTPS: respuesta del servidor HTTP ${widget.connectivity.https.code}',
                          HttpsStatus.timeout =>
                            'HTTPS: tiempo de espera agotado',
                          HttpsStatus.failed =>
                            'HTTPS: la petición no pudo completarse',
                        }, style: Theme.of(context).textTheme.labelMedium),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: chat.messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Todavía no hay mensajes. Escribe o adjunta una imagen para empezar.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: chat.messages.length,
                        itemBuilder: (context, index) => ChatMessageBubble(
                          key: ValueKey(chat.messages[index].id),
                          message: chat.messages[index],
                        ),
                      ),
              ),
              if (chat.error != null || chat.notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      chat.error ?? chat.notice!,
                      style: TextStyle(
                        color: chat.error != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (chat.busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Abriendo o leyendo imagen',
                ),
              if (chat.preview != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  padding: EdgeInsets.all(compact ? 4 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11243A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: compact ? 64 : 100,
                        child: ChatImageView(
                          image: chat.preview!,
                          height: compact ? 64 : 100,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vista previa'),
                            if (!compact)
                              Text(
                                chat.preview!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (compact)
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Cancelar imagen',
                                    onPressed: chat.busy
                                        ? null
                                        : chat.cancelImage,
                                    icon: const Icon(Icons.close),
                                  ),
                                  IconButton.filled(
                                    tooltip: 'Confirmar imagen',
                                    onPressed: chat.busy ? null : _send,
                                    icon: const Icon(Icons.check),
                                  ),
                                ],
                              )
                            else
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: chat.busy
                                        ? null
                                        : chat.cancelImage,
                                    child: const Text('Cancelar imagen'),
                                  ),
                                  FilledButton(
                                    onPressed: chat.busy ? null : _send,
                                    child: const Text('Confirmar imagen'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(compact ? 8 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<ImageSource>(
                      tooltip: 'Adjuntar imagen',
                      enabled: !chat.busy,
                      icon: const Icon(Icons.attach_file),
                      onSelected: chat.selectImage,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: ImageSource.gallery,
                          child: Text('Seleccionar imagen'),
                        ),
                        if (chat.images.supportsCamera)
                          const PopupMenuItem(
                            value: ImageSource.camera,
                            child: Text('Tomar fotografía'),
                          ),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: !chat.busy,
                        minLines: 1,
                        maxLines: compact ? 2 : 4,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje local',
                          labelText: 'Mensaje',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: chat.busy || chat.preview != null
                          ? null
                          : _send,
                      tooltip: 'Añadir mensaje local',
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
