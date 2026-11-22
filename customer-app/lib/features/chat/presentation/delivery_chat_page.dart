import 'dart:async';

import 'package:flutter/material.dart';

import '../../orders/data/commerce_repository.dart' show ChatMessage;

/// El chat cliente-repartidor se habilita cuando el pedido va "En camino"
/// y se mantiene al llegar al destino.
const chatOpenDeliveryStatuses = {'IN_TRANSIT', 'ARRIVED_AT_CUSTOMER'};

bool isDeliveryChatOpen(String status) =>
    chatOpenDeliveryStatuses.contains(status);

/// Chat entre cliente y repartidor, compartido por ambas aplicaciones.
class DeliveryChatPage extends StatefulWidget {
  const DeliveryChatPage({
    super.key,
    required this.title,
    required this.viewerType,
    required this.load,
    required this.send,
    this.markRead,
    this.errorMessage,
    this.refreshInterval = const Duration(seconds: 5),
  });

  final String title;

  /// `CUSTOMER` o `COURIER`: define qué mensajes se alinean a la derecha.
  final String viewerType;
  final Future<List<ChatMessage>> Function() load;
  final Future<void> Function(String message) send;

  /// Marca como leídos los mensajes recibidos (apaga el aviso del botón).
  final Future<void> Function()? markRead;
  final String Function(Object error)? errorMessage;
  final Duration refreshInterval;

  @override
  State<DeliveryChatPage> createState() => _DeliveryChatPageState();
}

class _DeliveryChatPageState extends State<DeliveryChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  List<ChatMessage> messages = const [];
  bool loading = true;
  bool sending = false;
  String? error;
  Timer? timer;

  /// Primer mensaje que estaba sin leer al abrir el chat: ahí va "Nuevo".
  String? firstNewId;
  bool firstLoad = true;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    timer = Timer.periodic(widget.refreshInterval, (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final items = await widget.load();
      if (!mounted) return;
      final grew = items.length != messages.length;
      final unread = items.where((item) => item.unreadFor(widget.viewerType));
      setState(() {
        if (firstLoad) firstNewId = unread.firstOrNull?.id;
        firstLoad = false;
        messages = items;
        loading = false;
        error = null;
      });
      if (grew) _scrollToEnd();
      if (unread.isNotEmpty) unawaited(_markRead());
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.errorMessage?.call(cause) ??
            'No pudimos cargar los mensajes.';
      });
    }
  }

  Future<void> _markRead() async {
    try {
      await widget.markRead?.call();
    } catch (_) {
      // Se reintenta en la siguiente actualización.
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> submit() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.send(text);
      input.clear();
      await refresh();
    } catch (cause) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.errorMessage?.call(cause) ??
                'No pudimos enviar el mensaje.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        if (error != null)
          MaterialBanner(content: Text(error!), actions: [
            TextButton(onPressed: refresh, child: const Text('Reintentar'))
          ]),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aún no hay mensajes. Escribe el primero.',
                          textAlign: TextAlign.center),
                    ))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final item = messages[index];
                        final mine = item.senderType == widget.viewerType;
                        final bubble = Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Card(
                              color: mine
                                  ? theme.colorScheme.primaryContainer
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!mine)
                                        Text(_senderLabel(item.senderType),
                                            style: theme.textTheme.labelSmall),
                                      Text(item.message),
                                    ]),
                              ),
                            ),
                          ),
                        );
                        if (item.id != firstNewId) return bubble;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [const _NewMessagesDivider(), bubble],
                        );
                      }),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: input,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje', counterText: ''),
                ),
              ),
              IconButton(
                key: const Key('chat-send'),
                tooltip: 'Enviar mensaje',
                icon: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                onPressed: sending ? null : submit,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

String _senderLabel(String type) => switch (type) {
      'COURIER' => 'Repartidor',
      'CUSTOMER' => 'Cliente',
      'MERCHANT' => 'Comercio',
      _ => 'Soporte',
    };

/// Separador "Nuevo" antes del primer mensaje que no se había leído.
class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      key: const Key('chat-new-divider'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('Nuevo',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
      ]),
    );
  }
}

/// "9+" a partir de 10 mensajes.
String unreadBadgeLabel(int count) => count > 9 ? '9+' : '$count';

/// Botón "Chatear" con el número de mensajes sin leer en la esquina.
/// El contador flota sobre el borde: no cambia el tamaño del botón.
class ChatButtonWithBadge extends StatelessWidget {
  const ChatButtonWithBadge({
    super.key,
    required this.onPressed,
    required this.unread,
    this.label = 'Chatear',
    this.minimumSize = const Size(0, 44),
  });

  final VoidCallback onPressed;
  final int unread;
  final String label;
  final Size minimumSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alert = unread > 0;
    final button = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: minimumSize,
        foregroundColor: alert ? scheme.error : null,
        side: alert ? BorderSide(color: scheme.error, width: 1.5) : null,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: Text(label),
    );
    return Semantics(
      label: alert
          ? '$label, $unread ${unread == 1 ? 'mensaje nuevo' : 'mensajes nuevos'}'
          : null,
      child: Stack(
          clipBehavior: Clip.none,
          // Respeta el ancho que le dé la fila (Expanded o ancho propio).
          fit: StackFit.passthrough,
          children: [
            button,
            if (alert)
              Positioned(
                top: -7,
                right: 8,
                child: ExcludeSemantics(
                  child: Container(
                    key: const Key('chat-unread-badge'),
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: Text(unreadBadgeLabel(unread),
                        style: TextStyle(
                            color: scheme.onError,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1)),
                  ),
                ),
              ),
          ]),
    );
  }
}
