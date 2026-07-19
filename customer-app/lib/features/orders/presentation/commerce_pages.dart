import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/widgets/app_states.dart';
import '../../home/data/customer_repository.dart';
import '../../home/presentation/home_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/commerce_repository.dart';

final commerceRepositoryProvider = Provider(
  (ref) => CommerceRepository(ref.watch(apiClientProvider)),
);
final cartProvider = FutureProvider(
  (ref) => ref.watch(commerceRepositoryProvider).cart(),
);
final ordersProvider = FutureProvider(
  (ref) => ref.watch(commerceRepositoryProvider).orders(),
);

class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({super.key, required this.merchant, required this.product});
  final Merchant merchant;
  final Product product;
  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  int quantity = 1;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.product.name)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restaurant,
                size: 72,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(widget.product.description),
            const SizedBox(height: 12),
            Text(
              '${widget.product.currency} ${(widget.product.price * quantity).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Row(
              children: [
                IconButton(
                  onPressed:
                      quantity > 1 ? () => setState(() => quantity--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$quantity'),
                IconButton(
                  onPressed: () => setState(() => quantity++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await ref.read(commerceRepositoryProvider).add(
                              merchantId: widget.merchant.id,
                              branchId: widget.merchant.branchId,
                              productId: widget.product.id,
                              quantity: quantity,
                            );
                        ref.invalidate(cartProvider);
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Producto agregado al carrito'),
                            ),
                          );
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(busy ? 'Agregando…' : 'Agregar al carrito'),
            ),
          ],
        ),
      );
}

class CartPage extends ConsumerWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Carrito')),
        body: ref.watch(cartProvider).when(
              data: (cart) {
                if (cart.items.isEmpty)
                  return const EmptyState(
                    title: 'Tu carrito está vacío',
                    message:
                        'Explora comercios y agrega tus productos favoritos.',
                  );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...cart.items.map((item) =>
                        CartItemTile(item: item, currency: cart.currency)),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Total: ${cart.currency} ${cart.total.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(commerceRepositoryProvider)
                                      .clearCart();
                                  ref.invalidate(cartProvider);
                                },
                                icon: const Icon(Icons.delete_sweep_outlined),
                                label: const Text('Vaciar carrito')),
                            FilledButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const CheckoutPage(),
                                ),
                              ),
                              child: const Text('Continuar al checkout'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(cartProvider),
              ),
            ),
      );
}

class CartItemTile extends ConsumerWidget {
  const CartItemTile({super.key, required this.item, required this.currency});
  final CartItem item;
  final String currency;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('$currency ${item.subtotal.toStringAsFixed(2)}')
                ])),
            IconButton(
                tooltip: 'Reducir',
                onPressed: () async {
                  if (item.quantity <= 1) {
                    await ref
                        .read(commerceRepositoryProvider)
                        .removeItem(item.id);
                  } else {
                    await ref
                        .read(commerceRepositoryProvider)
                        .updateItem(item.id, item.quantity - 1);
                  }
                  ref.invalidate(cartProvider);
                },
                icon: const Icon(Icons.remove_circle_outline)),
            Text('${item.quantity}'),
            IconButton(
                tooltip: 'Aumentar',
                onPressed: () async {
                  await ref
                      .read(commerceRepositoryProvider)
                      .updateItem(item.id, item.quantity + 1);
                  ref.invalidate(cartProvider);
                },
                icon: const Icon(Icons.add_circle_outline)),
            IconButton(
                tooltip: 'Eliminar',
                onPressed: () async {
                  await ref
                      .read(commerceRepositoryProvider)
                      .removeItem(item.id);
                  ref.invalidate(cartProvider);
                },
                icon: const Icon(Icons.delete_outline))
          ])));
}

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});
  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String? address;
  String method = 'CARD_SIMULATED';
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Dirección', style: Theme.of(context).textTheme.titleLarge),
          addresses.when(
            data: (items) => DropdownButtonFormField<String>(
              initialValue: address,
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text('${e.label} · ${e.addressLine}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => address = value),
              decoration: const InputDecoration(
                labelText: 'Dirección de entrega',
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(e.toString()),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField(
            initialValue: method,
            items: const [
              DropdownMenuItem(
                value: 'CARD_SIMULATED',
                child: Text('Pago simulado'),
              ),
              DropdownMenuItem(
                value: 'CASH_ON_DELIVERY',
                child: Text('Pago contra entrega'),
              ),
            ],
            onChanged: (value) => setState(() => method = value!),
            decoration: const InputDecoration(labelText: 'Método de pago'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy || address == null
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final order = await ref
                          .read(commerceRepositoryProvider)
                          .checkout(address!);
                      await ref
                          .read(commerceRepositoryProvider)
                          .pay(order.id, method);
                      ref.invalidate(cartProvider);
                      ref.invalidate(ordersProvider);
                      if (context.mounted)
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => OrderDetailPage(order: order),
                          ),
                          (route) => route.isFirst,
                        );
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Confirmando…' : 'Crear pedido y pagar'),
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(ordersProvider).when(
            data: (orders) {
              if (orders.isEmpty)
                return const EmptyState(
                  title: 'Sin pedidos',
                  message: 'Tus pedidos activos e históricos aparecerán aquí.',
                );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: orders
                    .map(
                      (order) => Card(
                        child: ListTile(
                          title: Text(order.number),
                          subtitle: Text(order.status),
                          trailing: Text(
                            '${order.currency} ${order.total.toStringAsFixed(2)}',
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => OrderDetailPage(order: order),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: e.toString()),
          );
}

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.order});
  final Order order;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(order.number)),
        body: FutureBuilder<Map<String, dynamic>>(
          future: ref.read(commerceRepositoryProvider).tracking(order.id),
          builder: (context, snapshot) {
            final deliveryId = snapshot.data?['deliveryId']?.toString();
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text('Estado: ${order.status}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                  'Total: ${order.currency} ${order.total.toStringAsFixed(2)}'),
              const SizedBox(height: 24),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: snapshot.connectionState != ConnectionState.done
                          ? const LinearProgressIndicator()
                          : Text(snapshot.hasError
                              ? 'El tracking estará disponible cuando exista una entrega.'
                              : 'Seguimiento actualizado. Repartidor: ${snapshot.data?['courierName'] ?? 'por asignar'}'))),
              if (deliveryId != null)
                RealtimeStatusBanner(deliveryId: deliveryId),
              if (deliveryId != null)
                FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ChatPage(deliveryId: deliveryId))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chatear con el repartidor')),
              if (order.status == 'DELIVERED')
                FilledButton.icon(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => RatingDialog(orderId: order.id)),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Calificar pedido')),
            ]);
          },
        ),
      );
}

class RealtimeStatusBanner extends ConsumerStatefulWidget {
  const RealtimeStatusBanner({super.key, required this.deliveryId});
  final String deliveryId;
  @override
  ConsumerState<RealtimeStatusBanner> createState() =>
      _RealtimeStatusBannerState();
}

class _RealtimeStatusBannerState extends ConsumerState<RealtimeStatusBanner> {
  String status = 'Conectando seguimiento…';
  StreamSubscription<RealtimeEvent>? subscription;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final user = ref.read(authControllerProvider).value;
      if (user == null) return;
      final client = ref.read(realtimeClientProvider);
      subscription = client.events.listen((event) {
        if (mounted) setState(() => status = _label(event.type));
      });
      await client.connect(
          tenantId: user.tenantId, deliveryId: widget.deliveryId);
      if (mounted) setState(() => status = 'Seguimiento en vivo conectado');
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    ref.read(realtimeClientProvider).disconnect();
    super.dispose();
  }

  String _label(String event) => switch (event) {
        'LocationUpdated' => 'Ubicación del repartidor actualizada',
        'ChatMessageReceived' => 'Nuevo mensaje del repartidor',
        'CourierAssigned' => 'Repartidor asignado',
        'DeliveryStatusChanged' => 'Estado de entrega actualizado',
        _ => 'Pedido actualizado'
      };
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.wifi_tethering),
            const SizedBox(width: 10),
            Expanded(child: Text(status))
          ])));
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.deliveryId});
  final String deliveryId;
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final input = TextEditingController();
  late Future<List<ChatMessage>> messages;
  @override
  void initState() {
    super.initState();
    messages = ref.read(commerceRepositoryProvider).messages(widget.deliveryId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Chat de la entrega')),
      body: Column(children: [
        Expanded(
            child: FutureBuilder<List<ChatMessage>>(
                future: messages,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  return ListView(
                      padding: const EdgeInsets.all(16),
                      children: items
                          .map((item) => Align(
                              alignment: item.senderType == 'CUSTOMER'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                  color: item.senderType == 'CUSTOMER'
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : null,
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(item.message)))))
                          .toList());
                })),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: input,
                          decoration: const InputDecoration(
                              hintText: 'Escribe un mensaje'))),
                  IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = input.text.trim();
                        if (text.isEmpty) return;
                        await ref
                            .read(commerceRepositoryProvider)
                            .sendMessage(widget.deliveryId, text);
                        input.clear();
                        setState(() => messages = ref
                            .read(commerceRepositoryProvider)
                            .messages(widget.deliveryId));
                      })
                ])))
      ]));
}

class RatingDialog extends ConsumerStatefulWidget {
  const RatingDialog({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  int score = 5;
  final comment = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Califica tu experiencia'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => IconButton(
                        onPressed: () => setState(() => score = index + 1),
                        icon: Icon(
                            index < score ? Icons.star : Icons.star_border,
                            color: Colors.amber)))),
            TextField(
                controller: comment,
                maxLength: 500,
                decoration:
                    const InputDecoration(labelText: 'Comentario opcional'))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () async {
                  await ref
                      .read(commerceRepositoryProvider)
                      .rate(widget.orderId, score, comment.text);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Enviar'))
          ]);
}
