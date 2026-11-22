import 'package:flutter/material.dart';

import '../data/commerce_repository.dart' show OrderHistoryEntry;

/// Un paso del recorrido del pedido que ve el cliente.
class OrderProgressStep {
  const OrderProgressStep({
    required this.title,
    required this.done,
    required this.current,
    this.icon = Icons.check,
    this.date,
    this.failed = false,
  });
  final String title;
  final IconData icon;
  final bool done, current, failed;
  final DateTime? date;
}

const _steps = <(String, String, IconData)>[
  ('PENDING', 'Pedido creado', Icons.receipt_long_outlined),
  ('CONFIRMED', 'Aceptado por el comercio', Icons.storefront_outlined),
  ('PREPARING', 'En preparación', Icons.soup_kitchen_outlined),
  ('READY', 'Listo para recoger', Icons.inventory_2_outlined),
  ('COURIER', 'Repartidor asignado', Icons.how_to_reg_outlined),
  ('PICKED_UP', 'Recogido por el repartidor', Icons.shopping_bag_outlined),
  ('ON_THE_WAY', 'En camino', Icons.delivery_dining_outlined),
  ('ARRIVED', 'Tu repartidor llegó', Icons.location_on_outlined),
  ('DELIVERED', 'Entregado', Icons.home_outlined),
];

const _orderRank = {
  'PENDING': 0,
  'CONFIRMED': 1,
  'PREPARING': 2,
  'READY': 3,
  'ASSIGNED': 4,
  'PICKED_UP': 5,
  'ON_THE_WAY': 6,
  'DELIVERED': 8,
};

/// Solo cuentan los estados de entrega posteriores a que el repartidor aceptó.
const _deliveryRank = {
  'ACCEPTED': 4,
  'ARRIVED_AT_MERCHANT': 4,
  'PICKED_UP': 5,
  'IN_TRANSIT': 6,
  'ARRIVED_AT_CUSTOMER': 7,
  'DELIVERED': 8,
};

/// Combina el estado del pedido, el de la entrega y el historial para que el
/// cliente vea siempre en qué paso está, incluso antes de tener repartidor.
List<OrderProgressStep> customerOrderProgress({
  required String orderStatus,
  String? deliveryStatus,
  List<OrderHistoryEntry> history = const [],
}) {
  final dates = <String, DateTime>{};
  for (final entry in history) {
    final date = DateTime.tryParse(entry.createdAt)?.toLocal();
    if (date != null) dates[entry.status] = date;
  }
  final terminal = orderStatus == 'CANCELLED' || orderStatus == 'REJECTED';
  var reached = terminal
      ? history.fold<int>(
          0, (rank, entry) => _max(rank, _orderRank[entry.status] ?? -1))
      : _max(_orderRank[orderStatus] ?? 0,
          _deliveryRank[deliveryStatus ?? ''] ?? -1);
  if (dates.containsKey('DELIVERED')) reached = _max(reached, 8);

  final steps = <OrderProgressStep>[];
  for (var i = 0; i < _steps.length; i++) {
    final (key, title, icon) = _steps[i];
    if (terminal && i > reached) break;
    steps.add(OrderProgressStep(
      title: title,
      icon: icon,
      done: i <= reached,
      // Un pedido entregado no tiene paso "actual": todo queda completado.
      current: !terminal && i == reached && reached < _steps.length - 1,
      date: dates[key],
    ));
  }
  if (terminal) {
    steps.add(OrderProgressStep(
      title: orderStatus == 'REJECTED'
          ? 'Rechazado por el comercio'
          : 'Pedido cancelado',
      icon: Icons.close,
      done: true,
      current: true,
      failed: true,
      date: dates[orderStatus],
    ));
  }
  return steps;
}

int _max(int a, int b) => a > b ? a : b;

/// Hora para pasos de hoy; fecha corta y hora para días anteriores.
String formatProgressTime(DateTime date, {DateTime? now}) {
  String two(int number) => number.toString().padLeft(2, '0');
  final today = now ?? DateTime.now();
  final time = '${two(date.hour)}:${two(date.minute)}';
  final sameDay = date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
  return sameDay ? time : '${two(date.day)}/${two(date.month)} $time';
}

/// Línea de tiempo con un ícono por paso: completados en color con su hora,
/// el actual resaltado y los siguientes en gris.
class OrderProgressTimeline extends StatelessWidget {
  const OrderProgressTimeline({super.key, required this.steps});
  final List<OrderProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seguimiento de tu pedido',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            _ProgressRow(step: steps[i], last: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.step, required this.last});
  final OrderProgressStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = !step.done;
    final completed = step.done && !step.current;
    final Color fill, iconColor, border;
    if (step.failed) {
      fill = scheme.error;
      iconColor = scheme.onError;
      border = scheme.error;
    } else if (completed) {
      fill = scheme.primary;
      iconColor = scheme.onPrimary;
      border = scheme.primary;
    } else if (step.current) {
      fill = scheme.primaryContainer;
      iconColor = scheme.primary;
      border = scheme.primary;
    } else {
      fill = scheme.surface;
      iconColor = scheme.outline;
      border = scheme.outlineVariant;
    }
    final trailing = step.date != null
        ? formatProgressTime(step.date!)
        : step.current && !step.failed
            ? 'Ahora'
            : null;
    final state = pending
        ? 'pendiente'
        : step.current
            ? 'paso actual'
            : 'completado';
    return Semantics(
      label: '${step.title}, $state',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 30,
              child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: border, width: step.current ? 2 : 1.2),
                  ),
                  child: Icon(step.icon, size: 16, color: iconColor),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: completed ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 12),
                child: Text(step.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          step.current ? FontWeight.w800 : FontWeight.w500,
                      color: step.failed
                          ? scheme.error
                          : pending
                              ? scheme.onSurfaceVariant
                              : null,
                    )),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 7, left: 8),
                child: Text(trailing,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: step.current
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight:
                            step.current ? FontWeight.w700 : FontWeight.w400)),
              ),
          ]),
        ),
      ),
    );
  }
}
