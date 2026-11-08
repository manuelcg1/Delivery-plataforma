import 'package:flutter/material.dart';

class OrderDetailSummary extends StatelessWidget {
  const OrderDetailSummary(
      {super.key,
      required this.number,
      required this.statusLabel,
      required this.currency,
      required this.total});

  final String number, statusLabel, currency;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PEDIDO',
              style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(number, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(statusLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('Total del pedido', style: theme.textTheme.bodyLarge),
                Text('$currency ${total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))
              ]),
        ]),
      ),
    );
  }
}

class OrderCourierInfo extends StatelessWidget {
  const OrderCourierInfo({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.delivery_dining_outlined,
            color: theme.colorScheme.onPrimaryContainer),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Repartidor',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          const SizedBox(height: 4),
          Text(name,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('La información se actualiza automáticamente.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
        ])),
      ]),
    );
  }
}

class OrderTimelineEntry extends StatelessWidget {
  const OrderTimelineEntry(
      {super.key, required this.title, required this.date, required this.last});
  final String title, date;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 32,
          child: Column(children: [
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle),
                child: Icon(Icons.check,
                    size: 18, color: theme.colorScheme.onPrimaryContainer)),
            if (!last)
              Expanded(
                  child: Center(
                      child: Container(
                          width: 2,
                          color: theme.colorScheme.primaryContainer))),
          ])),
      const SizedBox(width: 14),
      Expanded(
          child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 24, top: 3),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(date,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ]))),
    ]));
  }
}

class OrderCourierChatButton extends StatelessWidget {
  const OrderCourierChatButton(
      {super.key,
      required this.status,
      required this.deliveryId,
      required this.onPressed});
  final String status;
  final String? deliveryId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (status != 'IN_TRANSIT' || deliveryId == null)
      return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          onPressed: onPressed,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Chatear con el repartidor',
              textAlign: TextAlign.center),
        ));
  }
}
