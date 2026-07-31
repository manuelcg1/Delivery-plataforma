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
import '../../customer_tracking/presentation/customer_order_tracking_page.dart';
import '../../customer_tracking/presentation/customer_tracking_controller.dart';

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
  String method = 'CARD';
  String? errorMessage;
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
            items: checkoutPaymentMethods.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => method = value!),
            decoration: const InputDecoration(labelText: 'Método de pago'),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy || address == null
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      errorMessage = null;
                    });
                    Order? createdOrder;
                    final repository = ref.read(commerceRepositoryProvider);
                    try {
                      createdOrder = await repository.checkout(address!);
                      await repository.pay(createdOrder.id, method);
                      ref.invalidate(cartProvider);
                      ref.invalidate(ordersProvider);
                      if (context.mounted)
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OrderDetailPage(order: createdOrder!),
                          ),
                          (route) => route.isFirst,
                        );
                    } catch (error) {
                      final message = repository.errorMessage(error);
                      if (createdOrder != null) {
                        ref.invalidate(cartProvider);
                        ref.invalidate(ordersProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'El pedido fue creado, pero el pago quedó pendiente: $message',
                              ),
                            ),
                          );
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  OrderDetailPage(order: createdOrder!),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      } else if (mounted) {
                        setState(() => errorMessage = message);
                      }
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

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  StreamSubscription<RealtimeEvent>? subscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final user = ref.read(authControllerProvider).value;
      if (user == null) return;
      final client = ref.read(customerRealtimeClientProvider);
      subscription = client.events.listen((event) {
        if (event.type == 'ORDER_UPDATED') ref.invalidate(ordersProvider);
      });
      await client.connectAudience(
        tenantId: user.tenantId,
        audience: 'customers',
      );
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    ref.read(customerRealtimeClientProvider).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref.watch(ordersProvider).when(
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.status),
                          const SizedBox(height: 3),
                          Text(
                            _orderDate(order.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (trackableDeliveryStatuses
                              .contains(order.status)) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CustomerOrderTrackingPage(
                                    orderId: order.id,
                                    orderNumber: order.number,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.delivery_dining),
                              label: const Text('Seguir pedido'),
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '${order.currency} ${order.total.toStringAsFixed(2)}'),
                          if (order.status == 'DELIVERED')
                            const Text('Entregado',
                                style: TextStyle(color: Colors.green)),
                        ],
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

String _orderDate(String value) {
  final date = DateTime.parse(value).toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.order});
  final Order order;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late Future<Map<String, dynamic>> tracking;
  StreamSubscription<RealtimeEvent>? customerSubscription;
  Timer? fallbackRefresh;
  String? realtimeStatus;

  @override
  void initState() {
    super.initState();
    tracking = ref.read(commerceRepositoryProvider).tracking(widget.order.id);
    Future.microtask(() {
      customerSubscription =
          ref.read(customerRealtimeClientProvider).events.listen((event) {
        if (event.type == 'ORDER_UPDATED' && mounted) refresh();
      });
    });
    fallbackRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) refresh();
    });
  }

  void refresh([String? status]) {
    ref.invalidate(ordersProvider);
    setState(() {
      realtimeStatus = status ?? realtimeStatus;
      tracking = ref.read(commerceRepositoryProvider).tracking(widget.order.id);
    });
  }

  @override
  void dispose() {
    customerSubscription?.cancel();
    fallbackRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).valueOrNull;
    final order = orders
            ?.where((candidate) => candidate.id == widget.order.id)
            .firstOrNull ??
        widget.order;
    return Scaffold(
        appBar: AppBar(title: Text(order.number)),
        body: FutureBuilder<Map<String, dynamic>>(
          future: tracking,
          builder: (context, snapshot) {
            final deliveryId = snapshot.data?['deliveryId']?.toString();
            final currentStatus = realtimeStatus ??
                snapshot.data?['status']?.toString() ??
                order.status;
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text('Estado: ${_deliveryStatusLabel(currentStatus)}',
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
                RealtimeStatusBanner(
                  deliveryId: deliveryId,
                  onOrderUpdated: (status) => refresh(status),
                ),
              if (deliveryId != null)
                _CustomerDeliveryTimeline(
                  deliveryId: deliveryId,
                  currentStatus: currentStatus,
                ),
              if (trackableDeliveryStatuses.contains(currentStatus))
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerOrderTrackingPage(
                        orderId: order.id,
                        orderNumber: order.number,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Seguir pedido'),
                ),
              if (deliveryId != null &&
                  !terminalDeliveryStatuses.contains(currentStatus))
                FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ChatPage(deliveryId: deliveryId))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chatear con el repartidor')),
              if (currentStatus == 'DELIVERED')
                FilledButton.icon(
                    onPressed: () async {
                      final saved = await showDialog<bool>(
                          context: context,
                          builder: (_) => RatingDialog(orderId: order.id));
                      if (saved == true && context.mounted) {
                        ref.read(customerMainTabProvider.notifier).state = 0;
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Calificar pedido')),
            ]);
          },
        ));
  }
}

class RealtimeStatusBanner extends ConsumerStatefulWidget {
  const RealtimeStatusBanner({
    super.key,
    required this.deliveryId,
    required this.onOrderUpdated,
  });
  final String deliveryId;
  final ValueChanged<String?> onOrderUpdated;
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
        if (mounted) {
          setState(() => status = _label(event.type, event.payload));
          widget.onOrderUpdated(event.payload['status']?.toString());
        }
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

  String _label(String event, Map<String, dynamic> payload) => switch (event) {
        'LocationUpdated' => 'Ubicación del repartidor actualizada',
        'ChatMessageReceived' => 'Nuevo mensaje del repartidor',
        'CourierAssigned' => 'Repartidor asignado',
        'DeliveryStatusChanged' => 'Estado de entrega actualizado',
        _ => payload['status'] == null
            ? 'Pedido actualizado'
            : 'Estado: ${_deliveryStatusLabel(payload['status'].toString())}'
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

class _CustomerDeliveryTimeline extends ConsumerWidget {
  const _CustomerDeliveryTimeline({
    required this.deliveryId,
    required this.currentStatus,
  });
  final String deliveryId;
  final String currentStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Línea de tiempo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FutureBuilder<List<DeliveryStatusEvent>>(
                future: ref
                    .read(commerceRepositoryProvider)
                    .deliveryHistory(deliveryId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  final events = snapshot.data ?? const <DeliveryStatusEvent>[];
                  if (events.isEmpty) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 14,
                        child: Icon(Icons.check, size: 16),
                      ),
                      title: Text(_deliveryStatusLabel(currentStatus)),
                      subtitle: const Text('Actualizado en tiempo real'),
                    );
                  }
                  return Column(
                    children: events
                        .map((event) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                radius: 14,
                                child: Icon(Icons.check, size: 16),
                              ),
                              title: Text(_deliveryStatusLabel(event.status)),
                              subtitle: Text(_orderDate(event.createdAt)),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

String _deliveryStatusLabel(String status) =>
    const {
      'PENDING': 'Pedido creado',
      'ASSIGNED': 'Repartidor asignado',
      'ACCEPTED': 'Pedido aceptado',
      'PICKED_UP': 'Pedido recogido',
      'IN_TRANSIT': 'En camino',
      'DELIVERED': 'Entregado',
      'CANCELLED': 'Cancelado',
    }[status] ??
    status;

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
  bool saving = false;
  String? error;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

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
                    const InputDecoration(labelText: 'Comentario opcional')),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(commerceRepositoryProvider)
                              .rate(widget.orderId, score, comment.text.trim());
                          ref.invalidate(ordersProvider);
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (cause) {
                          if (mounted) {
                            setState(() {
                              saving = false;
                              error = ref
                                  .read(commerceRepositoryProvider)
                                  .errorMessage(cause);
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Guardando…' : 'Enviar'))
          ]);
}
