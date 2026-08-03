import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/cart_feedback.dart';
import '../../home/data/customer_repository.dart';
import '../../home/presentation/home_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/commerce_repository.dart';
import '../../customer_tracking/presentation/customer_order_tracking_page.dart';
import '../../customer_tracking/presentation/customer_tracking_controller.dart';
import '../../address/presentation/customer_address_form_page.dart';
import '../../address/domain/customer_address.dart';

final commerceRepositoryProvider = Provider(
  (ref) => CommerceRepository(ref.watch(apiClientProvider)),
);
final cartProvider = FutureProvider(
  (ref) => ref.watch(commerceRepositoryProvider).cart(),
);
final ordersProvider = FutureProvider(
  (ref) => ref.watch(commerceRepositoryProvider).orders(),
);

bool shouldPollOrderDetail(String status) =>
    !terminalDeliveryStatuses.contains(status);

const customerOrdersTabIndex = 2;

class CheckoutAddressSelector extends StatelessWidget {
  const CheckoutAddressSelector({
    super.key,
    required this.addresses,
    required this.value,
    required this.onChanged,
    this.onAdd,
    this.onEdit,
  });

  final List<CustomerAddress> addresses;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAdd;
  final ValueChanged<CustomerAddress>? onEdit;

  @override
  Widget build(BuildContext context) {
    final selected = addresses.where((item) => item.id == value).firstOrNull;
    return Semantics(
      button: true,
      label: selected == null
          ? 'Seleccionar dirección de entrega'
          : 'Dirección de entrega, ${selected.label}, ${selected.addressLine}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showAddressSelector(context),
        child: _CheckoutCard(
          child: selected == null
              ? const _EmptyCheckoutChoice(
                  icon: Icons.add_location_alt_outlined,
                  title: 'Seleccionar dirección',
                )
              : Row(
                  children: [
                    const _CheckoutIcon(icon: Icons.home_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.isDefault
                                ? '${selected.label} · Predeterminada'
                                : selected.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selected.addressLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: _success),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Ubicación validada',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: _success, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: _orange),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showAddressSelector(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddressPickerSheet(
        addresses: addresses,
        selectedId: value,
        onAdd: onAdd,
        onEdit: onEdit,
      ),
    );
    if (result != null) onChanged(result);
  }
}

class CheckoutCoverageStatus extends StatelessWidget {
  const CheckoutCoverageStatus({
    super.key,
    required this.coverage,
    this.onChangeAddress,
  });
  final CoverageResult coverage;
  final VoidCallback? onChangeAddress;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: coverage.covered
              ? const Color(0xFFF0FDF4)
              : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: coverage.covered
                ? const Color(0xFFBBF7D0)
                : const Color(0xFFFED7AA),
          ),
        ),
        child: coverage.covered
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: _success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Entrega disponible',
                            style: TextStyle(
                                color: _success,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            _CoverageDetail(
                              icon: Icons.schedule_rounded,
                              text: coverage.minimumEstimatedMinutes != null &&
                                      coverage.maximumEstimatedMinutes != null
                                  ? '${coverage.minimumEstimatedMinutes}–${coverage.maximumEstimatedMinutes} min'
                                  : coverage.estimatedMinutes == null
                                      ? 'Tiempo por confirmar'
                                      : '${coverage.estimatedMinutes} min',
                            ),
                            _CoverageDetail(
                              icon: Icons.delivery_dining_rounded,
                              text:
                                  'S/ ${(coverage.deliveryFee ?? 0).toStringAsFixed(2)}',
                            ),
                            if (coverage.distanceKm != null)
                              _CoverageDetail(
                                icon: Icons.route_rounded,
                                text:
                                    '${coverage.distanceKm!.toStringAsFixed(1)} km',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEA580C), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No entregamos todavía en esta dirección.',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (onChangeAddress != null) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: onChangeAddress,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: EdgeInsets.zero,
                              foregroundColor: const Color(0xFFEA580C),
                            ),
                            child: const Text('Cambiar dirección'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      );
}

const _navy = Color(0xFF06163A);
const _orange = Color(0xFFFF7C00);
const _surface = Color(0xFFF5F7FA);
const _primaryText = Color(0xFF111827);
const _secondaryText = Color(0xFF6B7280);
const _success = Color(0xFF16A34A);

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A06163A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );
}

class _CheckoutIcon extends StatelessWidget {
  const _CheckoutIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      );
}

class _EmptyCheckoutChoice extends StatelessWidget {
  const _EmptyCheckoutChoice({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _CheckoutIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.chevron_right_rounded, color: _orange),
        ],
      );
}

class _CoverageDetail extends StatelessWidget {
  const _CoverageDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _navy),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: _primaryText, fontSize: 12)),
        ],
      );
}

class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet({
    required this.addresses,
    required this.selectedId,
    this.onAdd,
    this.onEdit,
  });
  final List<CustomerAddress> addresses;
  final String? selectedId;
  final VoidCallback? onAdd;
  final ValueChanged<CustomerAddress>? onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Elige una dirección',
                style: TextStyle(
                    color: _navy, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = addresses[index];
                  return ListTile(
                    minTileHeight: 56,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.id == selectedId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: item.id == selectedId ? _orange : _secondaryText,
                    ),
                    title: Text(item.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(item.addressLine,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, item.id),
                    trailing: onEdit == null
                        ? null
                        : IconButton(
                            tooltip: 'Editar dirección',
                            onPressed: () {
                              Navigator.pop(context);
                              onEdit!(item);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                  );
                },
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAdd!();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: _navy,
                ),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Agregar nueva dirección'),
              ),
            ],
          ],
        ),
      );
}

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
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final repository = ref.read(commerceRepositoryProvider);
                      try {
                        await repository.add(
                          merchantId: widget.merchant.id,
                          branchId: widget.merchant.branchId,
                          productId: widget.product.id,
                          quantity: quantity,
                        );
                        ref.invalidate(cartProvider);
                        if (!context.mounted) return;
                        showProductAddedSnackBar(
                          messenger,
                          productName: widget.product.name,
                          quantity: quantity,
                          onViewCart: () =>
                              navigator.push(MaterialPageRoute<void>(
                            builder: (_) => const CartPage(),
                          )),
                        );
                        navigator.pop();
                      } catch (error) {
                        if (context.mounted) {
                          showCartErrorSnackBar(
                              messenger, repository.errorMessage(error));
                        }
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

Widget _fadeSlide(Widget child, Animation<double> animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );

String _currency(String value) => value == 'PEN' ? 'S/' : value;

double _quotedTotal(Cart cart, CoverageResult? coverage) {
  final delivery = coverage?.covered == true ? coverage?.deliveryFee ?? 0 : 0;
  return cart.subtotal + delivery - cart.discount;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _navy, fontSize: 16, fontWeight: FontWeight.w500));
}

class _CoverageLoading extends StatelessWidget {
  const _CoverageLoading({super.key});

  @override
  Widget build(BuildContext context) => const _CheckoutCard(
        child: Row(children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
          ),
          SizedBox(width: 12),
          Text('Validando cobertura…',
              style: TextStyle(color: _secondaryText, fontSize: 14)),
        ]),
      );
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart, required this.coverage});
  final Cart cart;
  final CoverageResult? coverage;

  @override
  Widget build(BuildContext context) {
    final subtotal = cart.subtotal;
    final delivery = coverage?.covered == true ? coverage?.deliveryFee ?? 0 : 0;
    final discount = cart.discount;
    final total = _quotedTotal(cart, coverage);
    final currency = _currency(cart.currency);
    return _CheckoutCard(
      child: Column(children: [
        _SummaryRow(
            label: 'Subtotal (${cart.items.length} productos)',
            value: '$currency ${subtotal.toStringAsFixed(2)}'),
        const SizedBox(height: 12),
        _SummaryRow(
            label: 'Envío', value: '$currency ${delivery.toStringAsFixed(2)}'),
        const SizedBox(height: 12),
        _SummaryRow(
          label: 'Descuentos',
          value: discount == 0
              ? '$currency 0.00'
              : '-$currency ${discount.toStringAsFixed(2)}',
          valueColor: _success,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),
        _SummaryRow(
          label: 'Total',
          value: '$currency ${total.toStringAsFixed(2)}',
          emphasized: true,
        ),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                color: emphasized ? _primaryText : _secondaryText,
                fontSize: emphasized ? 16 : 14,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
        const SizedBox(width: 12),
        Text(value,
            style: TextStyle(
              color: valueColor ?? (emphasized ? _navy : _primaryText),
              fontSize: emphasized ? 20 : 14,
              fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
            )),
      ]);
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.cart,
    required this.coverage,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });
  final Cart? cart;
  final CoverageResult? coverage;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Color(0x1406163A),
                blurRadius: 16,
                offset: Offset(0, -4)),
          ]),
          child: Row(children: [
            if (cart != null) ...[
              SizedBox(
                width: 92,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(color: _secondaryText, fontSize: 12)),
                    Text(
                      '${_currency(cart!.currency)} ${_quotedTotal(cart!, coverage).toStringAsFixed(2)}',
                      maxLines: 1,
                      style: const TextStyle(
                          color: _navy,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled ? onPressed : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: _orange,
                  disabledBackgroundColor: const Color(0xFFFFC58F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 19),
                label: Text(busy ? 'Confirmando…' : 'Crear pedido y pagar'),
              ),
            ),
          ]),
        ),
      );
}

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});
  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String? address;
  String? coverageAddress;
  String? coverageMerchant;
  CoverageResult? coverage;
  bool checkingCoverage = false;
  String method = 'CARD';
  String? errorMessage;
  bool busy = false;
  Future<void> _validateCoverage(String addressId) async {
    setState(() {
      checkingCoverage = true;
      coverage = null;
      errorMessage = null;
    });
    try {
      final repository = ref.read(commerceRepositoryProvider);
      final cart = await repository.cart();
      final result = await repository.coverage(cart.merchantId, addressId);
      if (mounted && address == addressId)
        setState(() {
          coverage = result;
          coverageAddress = addressId;
          coverageMerchant = cart.merchantId;
        });
    } catch (error) {
      if (mounted)
        setState(() => errorMessage =
            ref.read(commerceRepositoryProvider).coverageErrorMessage(error));
    } finally {
      if (mounted) setState(() => checkingCoverage = false);
    }
  }

  Future<void> _openAddressForm([CustomerAddress? selected]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerAddressFormPage(address: selected),
      ),
    );
    ref.invalidate(addressesProvider);
    coverageAddress = null;
    if (selected != null) {
      setState(() => address = selected.id);
      await _validateCoverage(selected.id);
    } else if (address != null) {
      await _validateCoverage(address!);
    }
  }

  Future<void> _submitOrder() async {
    setState(() {
      busy = true;
      errorMessage = null;
    });
    Order? createdOrder;
    final repository = ref.read(commerceRepositoryProvider);
    try {
      createdOrder =
          await repository.checkout(address!, coverage!.deliveryFee!);
      await repository.pay(createdOrder.id, method);
      ref.invalidate(cartProvider);
      ref.invalidate(ordersProvider);
      if (mounted) {
        ref.read(customerMainTabProvider.notifier).state =
            customerOrdersTabIndex;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      final message = repository.errorMessage(error);
      if (createdOrder != null) {
        ref.invalidate(cartProvider);
        ref.invalidate(ordersProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El pedido fue creado, pero el pago quedó pendiente: $message',
              ),
            ),
          );
          ref.read(customerMainTabProvider.notifier).state =
              customerOrdersTabIndex;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else if (mounted) {
        if (repository.errorCode(error) == 'DELIVERY_QUOTE_CHANGED') {
          await _validateCoverage(address!);
          if (mounted) {
            setState(() => errorMessage =
                'El costo de entrega cambió. Revisa el nuevo total.');
          }
        } else {
          setState(() => errorMessage = message);
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showPaymentMethods() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Método de pago',
                style: TextStyle(
                    color: _navy, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...checkoutPaymentMethods.entries.map(
              (entry) => ListTile(
                minTileHeight: 56,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.key == method
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: entry.key == method ? _orange : _secondaryText,
                ),
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => method = selected);
  }

  Future<void> _selectAddress(List<CustomerAddress> items) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddressPickerSheet(
        addresses: items,
        selectedId: address,
        onAdd: _openAddressForm,
        onEdit: _openAddressForm,
      ),
    );
    if (selected != null && mounted) {
      setState(() => address = selected);
      await _validateCoverage(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final cart = ref.watch(cartProvider).valueOrNull;
    final activeMerchant = cart?.merchantId;
    final canSubmit = !busy &&
        address != null &&
        !checkingCoverage &&
        coverage?.covered == true;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Confirmar pedido',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _SectionTitle('Entregar en'),
          const SizedBox(height: 10),
          addresses.when(
            data: (items) {
              if (address == null && items.isNotEmpty) {
                address = items
                    .firstWhere((item) => item.isDefault,
                        orElse: () => items.first)
                    .id;
              }
              if (address != null &&
                  (coverageAddress != address ||
                      coverageMerchant != activeMerchant) &&
                  !checkingCoverage) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _validateCoverage(address!));
              }
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: _fadeSlide,
                child: CheckoutAddressSelector(
                  key: ValueKey(address),
                  addresses: items,
                  value: address,
                  onAdd: _openAddressForm,
                  onEdit: _openAddressForm,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => address = value);
                      _validateCoverage(value);
                    }
                  },
                ),
              );
            },
            loading: () => const LinearProgressIndicator(color: _orange),
            error: (error, _) => Text(error.toString()),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: _fadeSlide,
            child: checkingCoverage
                ? const _CoverageLoading(key: ValueKey('loading'))
                : coverage == null
                    ? const SizedBox.shrink(key: ValueKey('empty'))
                    : CheckoutCoverageStatus(
                        key: ValueKey(
                            '${coverage!.covered}-${coverage!.reasonCode}'),
                        coverage: coverage!,
                        onChangeAddress: addresses.valueOrNull == null
                            ? null
                            : () => _selectAddress(addresses.valueOrNull!),
                      ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Método de pago'),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: _fadeSlide,
            child: Semantics(
              key: ValueKey(method),
              button: true,
              label: 'Método de pago, ${checkoutPaymentMethods[method]}',
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _showPaymentMethods,
                child: _CheckoutCard(
                  child: Row(children: [
                    const _CheckoutIcon(icon: Icons.credit_card_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(checkoutPaymentMethods[method]!,
                          style: const TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _orange),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Resumen del pedido'),
          const SizedBox(height: 10),
          if (cart != null) _OrderSummary(cart: cart, coverage: coverage),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(errorMessage!,
                  style: const TextStyle(color: Color(0xFFDC2626))),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _CheckoutBottomBar(
        cart: cart,
        coverage: coverage,
        busy: busy,
        enabled: canSubmit,
        onPressed: _submitOrder,
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
  Timer? fallbackRefresh;

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
    fallbackRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(ordersProvider);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    fallbackRefresh?.cancel();
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
  late bool ratingSubmitted = widget.order.ratingSubmitted;

  @override
  void initState() {
    super.initState();
    tracking = _loadTracking();
    if (!shouldPollOrderDetail(widget.order.status)) return;
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
    if (!mounted) return;
    ref.invalidate(ordersProvider);
    if (status != null && !shouldPollOrderDetail(status)) {
      _stopUpdates();
      setState(() => realtimeStatus = status);
      return;
    }
    setState(() {
      realtimeStatus = status ?? realtimeStatus;
      tracking = _loadTracking();
    });
  }

  Future<Map<String, dynamic>> _loadTracking() async {
    final result =
        await ref.read(commerceRepositoryProvider).tracking(widget.order.id);
    final status =
        result['deliveryStatus']?.toString() ?? result['status']?.toString();
    if (status != null && !shouldPollOrderDetail(status)) {
      _stopUpdates();
    }
    return result;
  }

  void _stopUpdates() {
    fallbackRefresh?.cancel();
    fallbackRefresh = null;
    customerSubscription?.cancel();
    customerSubscription = null;
  }

  @override
  void dispose() {
    _stopUpdates();
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
              if (deliveryId != null &&
                  !terminalDeliveryStatuses.contains(currentStatus))
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
              if (canRateOrder(order, currentStatus: currentStatus) &&
                  !ratingSubmitted)
                FilledButton.icon(
                    onPressed: () async {
                      final saved = await showDialog<bool>(
                          context: context,
                          builder: (_) => RatingDialog(orderId: order.id));
                      if (saved == true && context.mounted) {
                        setState(() => ratingSubmitted = true);
                        ref.invalidate(ordersProvider);
                      }
                    },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Calificar pedido')),
              if (currentStatus == 'DELIVERED' &&
                  (order.ratingSubmitted || ratingSubmitted))
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Calificación enviada'),
                ),
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
          final nextStatus = event.payload['status']?.toString();
          if (nextStatus != null || event.type == 'DeliveryStatusChanged') {
            widget.onOrderUpdated(nextStatus);
          }
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
