import 'package:flutter/material.dart';

import '../data/commerce_repository.dart' show OrderLineItem;

/// "2× Torta Chocolate, 1× Café americano".
String orderItemsSummary(List<OrderLineItem> items) =>
    items.map((item) => '${item.quantity}× ${item.productName}').join(', ');

/// "3 productos" sumando cantidades.
String orderItemsCount(List<OrderLineItem> items) {
  final count = items.fold<int>(0, (total, item) => total + item.quantity);
  return count == 1 ? '1 producto' : '$count productos';
}

String _options(OrderLineItem item, {required bool withPrices}) => item.options
    .map((option) {
      final label = option.groupName.isEmpty
          ? option.itemName
          : '${option.groupName}: ${option.itemName}';
      final price = option.priceAdjustment ?? 0;
      return withPrices && price > 0
          ? '$label (+S/ ${price.toStringAsFixed(2)})'
          : label;
    })
    .where((text) => text.trim().isNotEmpty)
    .join(' · ');

/// Fila con el resumen de productos y el botón "Ver productos".
class OrderProductsSummaryRow extends StatelessWidget {
  const OrderProductsSummaryRow({
    super.key,
    required this.items,
    required this.onView,
    this.color,
    this.summary,
  });

  final List<OrderLineItem> items;
  final VoidCallback onView;

  /// Color del texto e ícono (p. ej. dentro de la tarjeta del código).
  final Color? color;

  /// Texto alternativo al resumen por defecto.
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(children: [
      Icon(Icons.shopping_bag_outlined, size: 18, color: ink),
      const SizedBox(width: 8),
      Expanded(
        child: Text(summary ?? orderItemsSummary(items),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: ink)),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        key: const Key('view-products'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: color,
          side: color == null ? null : BorderSide(color: color!, width: 0.8),
          backgroundColor: theme.colorScheme.surface,
        ),
        onPressed: onView,
        child: const Text('Ver productos'),
      ),
    ]);
  }
}

/// Ventana del cliente: productos con opciones, notas, precios y totales.
Future<void> showOrderProductsSheet(
  BuildContext context, {
  required String orderNumber,
  required List<OrderLineItem> items,
  required String currency,
  required double total,
  double? subtotal,
  double? deliveryFee,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        String money(double value) => '$currency ${value.toStringAsFixed(2)}';
        return _SheetFrame(
          title: 'Productos del pedido',
          subtitle: '$orderNumber · ${orderItemsCount(items)}',
          children: [
            for (final item in items)
              _ItemRow(
                item: item,
                options: _options(item, withPrices: true),
                trailing: item.subtotal == null
                    ? null
                    : Text(money(item.subtotal!),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 8),
            if (subtotal != null) _TotalRow('Subtotal', money(subtotal)),
            if (deliveryFee != null) _TotalRow('Envío', money(deliveryFee)),
            const Divider(height: 16),
            _TotalRow('Total', money(total), strong: true),
          ],
        );
      },
    );

/// Ventana del repartidor: sin precios y con casillas para revisar el
/// pedido antes de salir del comercio. Las marcas son solo una ayuda local.
Future<void> showCourierProductsSheet(
  BuildContext context, {
  required String orderNumber,
  required List<OrderLineItem> items,
  String? merchantName,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CourierChecklist(
        orderNumber: orderNumber,
        items: items,
        merchantName: merchantName,
      ),
    );

class _CourierChecklist extends StatefulWidget {
  const _CourierChecklist({
    required this.orderNumber,
    required this.items,
    required this.merchantName,
  });
  final String orderNumber;
  final List<OrderLineItem> items;
  final String? merchantName;

  @override
  State<_CourierChecklist> createState() => _CourierChecklistState();
}

class _CourierChecklistState extends State<_CourierChecklist> {
  late final checked = List<bool>.filled(widget.items.length, false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = checked.where((value) => value).length;
    final subtitle = [
      widget.orderNumber,
      if (widget.merchantName?.trim().isNotEmpty == true)
        widget.merchantName!.trim(),
    ].join(' · ');
    return _SheetFrame(
      title: 'Revisa el pedido antes de salir',
      subtitle: subtitle,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          InkWell(
            onTap: () => setState(() => checked[i] = !checked[i]),
            child: _ItemRow(
              item: widget.items[i],
              options: _options(widget.items[i], withPrices: false),
              leading: Checkbox(
                visualDensity: VisualDensity.compact,
                value: checked[i],
                onChanged: (value) =>
                    setState(() => checked[i] = value ?? false),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text('$done de ${widget.items.length} verificados',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title, subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: children),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.options,
    this.leading,
    this.trailing,
  });
  final OrderLineItem item;
  final String options;
  final Widget? leading, trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = item.notes?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.6))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (leading != null)
          leading!
        else
          Container(
            width: 32,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8)),
            child: Text('${item.quantity}×',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  leading != null
                      ? '${item.quantity}× ${item.productName}'
                      : item.productName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (options.isNotEmpty)
                Text(options,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              if (notes != null && notes.isNotEmpty)
                Text('Nota: $notes',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.strong = false});
  final String label, value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = strong
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: strong
                    ? style
                    : style?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant))),
        Text(value, style: style),
      ]),
    );
  }
}
