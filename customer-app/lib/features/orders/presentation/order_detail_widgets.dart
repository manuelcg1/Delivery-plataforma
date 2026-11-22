import 'package:flutter/material.dart';

import '../../chat/presentation/delivery_chat_page.dart';

const deliveryCodeSecurityMessage =
    'Por tu seguridad, no compartas tu código de entrega hasta que tu pedido haya llegado.';

const _cardRadius = 14.0;

BoxDecoration _cardDecoration(ColorScheme scheme,
        {Color? color, Color? border}) =>
    BoxDecoration(
      color: color ?? scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(_cardRadius),
      border: Border.all(color: border ?? scheme.outlineVariant, width: 0.6),
    );

/// Código secreto de entrega en una sola fila, con el mensaje de seguridad.
class DeliveryCodeCard extends StatelessWidget {
  const DeliveryCodeCard({super.key, required this.code, this.footer});

  final String code;

  /// Contenido opcional bajo el código (p. ej. el resumen de productos).
  final Widget? footer;

  /// Color de texto dentro de la tarjeta, para que el pie combine.
  static Color inkOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSecondaryContainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = inkOf(context);
    final spaced = code.split('').join(' ');
    final codeRow = Semantics(
      container: true,
      label: 'Código de entrega $spaced. $deliveryCodeSecurityMessage',
      child: ExcludeSemantics(
          child: Row(children: [
        Icon(Icons.lock_outline, size: 20, color: ink),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código de entrega',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(deliveryCodeSecurityMessage,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: ink, height: 1.3)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SelectableText(code,
            key: const Key('delivery-code'),
            style: theme.textTheme.titleLarge?.copyWith(
                letterSpacing: 3, fontWeight: FontWeight.w800, color: ink)),
      ])),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(scheme,
          color: scheme.secondaryContainer, border: scheme.secondary),
      child: footer == null
          ? codeRow
          : Column(mainAxisSize: MainAxisSize.min, children: [
              codeRow,
              Divider(height: 16, color: ink.withValues(alpha: 0.25)),
              footer!,
            ]),
    );
  }
}

/// Aviso que se muestra al crear el pedido.
Future<void> showDeliveryCodeNotice(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Pedido creado!'),
        content: SingleChildScrollView(child: DeliveryCodeCard(code: code)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido')),
        ],
      ),
    );

/// Número, estado y total del pedido en una sola fila.
class OrderDetailSummary extends StatelessWidget {
  const OrderDetailSummary(
      {super.key,
      required this.number,
      required this.statusLabel,
      required this.currency,
      required this.total,
      this.footer});

  final String number, statusLabel, currency;
  final double total;

  /// Resumen de productos cuando la tarjeta del código ya no se muestra.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final header = Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999)),
              child: Text(statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Total',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        Text('$currency ${total.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(scheme),
      child: footer == null
          ? header
          : Column(mainAxisSize: MainAxisSize.min, children: [
              header,
              const Divider(height: 16),
              footer!,
            ]),
    );
  }
}

/// Repartidor en una fila: ícono y nombre.
class OrderCourierInfo extends StatelessWidget {
  const OrderCourierInfo({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _cardDecoration(scheme),
      child: Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(Icons.delivery_dining_outlined,
              size: 18, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Repartidor',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

/// El chat con el repartidor solo existe con una entrega en camino.
bool canChatWithCourier(String status, String? deliveryId) =>
    deliveryId != null && isDeliveryChatOpen(status);

/// "Seguir pedido" y "Chatear" en una sola fila; si solo aplica uno,
/// ocupa todo el ancho.
class OrderDetailActions extends StatelessWidget {
  const OrderDetailActions({
    super.key,
    required this.onTrack,
    required this.onChat,
    this.chatUnread = 0,
  });

  /// `null` oculta el botón.
  final VoidCallback? onTrack, onChat;

  /// Mensajes del repartidor sin leer: se muestran sobre "Chatear".
  final int chatUnread;

  @override
  Widget build(BuildContext context) {
    if (onTrack == null && onChat == null) return const SizedBox.shrink();
    const size = Size(0, 44);
    return Row(children: [
      if (onTrack != null)
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onTrack,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Seguir pedido'),
          ),
        ),
      if (onTrack != null && onChat != null) const SizedBox(width: 8),
      if (onChat != null)
        Expanded(
          child: ChatButtonWithBadge(
            onPressed: onChat!,
            unread: chatUnread,
            minimumSize: size,
          ),
        ),
    ]);
  }
}
