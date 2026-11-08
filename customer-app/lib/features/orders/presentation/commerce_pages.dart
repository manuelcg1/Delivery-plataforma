import 'package:uuid/uuid.dart';
import '../data/yape_recovery.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/cart_feedback.dart';
import '../../home/data/customer_repository.dart';
import '../../home/presentation/home_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/commerce_repository.dart';
import '../data/yape_checkout.dart';
import 'yape_checkout_sheet.dart';
import 'order_detail_widgets.dart';
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

class ProductAddedResult {
  const ProductAddedResult({
    required this.productName,
    required this.quantity,
  });

  final String productName;
  final int quantity;
}

class _ProductPageState extends ConsumerState<ProductPage> {
  int quantity = 1;
  int imageIndex = 0;
  bool busy = false;
  final Set<String> selectedOptions = <String>{};

  bool get validOptions => widget.product.optionGroups.every((group) {
        final count = group.items
            .where((item) => selectedOptions.contains(item.id))
            .length;
        final minimum = group.required
            ? (group.minimumSelections < 1 ? 1 : group.minimumSelections)
            : group.minimumSelections;
        return count >= minimum &&
            (group.maximumSelections == null ||
                count <= group.maximumSelections!) &&
            (group.selectionType != 'SINGLE' || count <= 1);
      });
  double get optionsTotal => widget.product.optionGroups
      .expand((group) => group.items)
      .where((item) => selectedOptions.contains(item.id))
      .fold(0, (total, item) => total + item.priceAdjustment);

  String get formattedTotal =>
      '${widget.product.currency} ${(widget.product.price * quantity + optionsTotal).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Detalle del producto'),
            Text(widget.merchant.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ]),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _ProductGallery(
              product: widget.product,
              currentIndex: imageIndex,
              onPageChanged: (value) => setState(() => imageIndex = value),
            ),
            const SizedBox(height: 24),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
            ),
            if (widget.product.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.product.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      )),
            ],
            const SizedBox(height: 16),
            Text(
              '${widget.product.currency} ${widget.product.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (widget.product.optionGroups.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Personaliza tu pedido',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...widget.product.optionGroups.map((group) => Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(group.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700))),
                              _RequirementBadge(required: group.required),
                            ]),
                            const SizedBox(height: 3),
                            Text(
                                group.selectionType == 'SINGLE'
                                    ? 'Elige una opción'
                                    : group.maximumSelections == null
                                        ? 'Puedes elegir varias opciones'
                                        : 'Elige hasta ${group.maximumSelections} opciones',
                                style: Theme.of(context).textTheme.bodySmall),
                            ...group.items.map((item) {
                              final checked = selectedOptions.contains(item.id);
                              final price = item.priceAdjustment == 0
                                  ? 'Gratis'
                                  : '+ ${widget.product.currency} ${item.priceAdjustment.toStringAsFixed(2)}';
                              void change(bool value) {
                                setState(() {
                                  if (group.selectionType == 'SINGLE') {
                                    selectedOptions.removeAll(group.items
                                        .map((candidate) => candidate.id));
                                  }
                                  if (value)
                                    selectedOptions.add(item.id);
                                  else
                                    selectedOptions.remove(item.id);
                                });
                              }

                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: checked,
                                onChanged: (value) => change(value ?? false),
                                title: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(price),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              );
                            }),
                          ]),
                    ),
                  )),
              if (!validOptions)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text('Completa las opciones obligatorias.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600)),
                    ])),
            ],
            const SizedBox(height: 16),
            Row(children: [
              _QuantitySelector(
                  value: quantity,
                  onRemove:
                      quantity > 1 ? () => setState(() => quantity--) : null,
                  onAdd: () => setState(() => quantity++)),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: busy || !validOptions
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final navigator = Navigator.of(context);
                        final repository = ref.read(commerceRepositoryProvider);
                        try {
                          await repository.add(
                            merchantId: widget.merchant.id,
                            branchId: widget.merchant.branchId,
                            productId: widget.product.id,
                            quantity: quantity,
                            optionItemIds:
                                selectedOptions.toList(growable: false),
                          );
                          if (!context.mounted) return;
                          ref.invalidate(cartProvider);
                          showProductAddedSnackBar(
                            cartFeedbackMessengerKey.currentState ??
                                ScaffoldMessenger.of(context),
                            productName: widget.product.name,
                            quantity: quantity,
                          );
                          navigator.pop(ProductAddedResult(
                            productName: widget.product.name,
                            quantity: quantity,
                          ));
                        } catch (error) {
                          if (context.mounted) {
                            showCartErrorSnackBar(
                              cartFeedbackMessengerKey.currentState ??
                                  ScaffoldMessenger.of(context),
                              repository.errorMessage(error),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(busy ? 'Agregando…' : 'Agregar al carrito',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (!busy)
                    Text(formattedTotal,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: .85))),
                ]),
              )),
            ]),
          ],
        ),
      );
}

class _RequirementBadge extends StatelessWidget {
  const _RequirementBadge({required this.required});
  final bool required;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: required
              ? Theme.of(context).colorScheme.primaryContainer
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(required ? 'Obligatorio' : 'Opcional',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector(
      {required this.value, required this.onRemove, required this.onAdd});
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Quitar uno',
              onPressed: onRemove,
              icon: const Icon(Icons.remove, size: 20)),
          Semantics(
              label: 'Cantidad',
              value: '$value',
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Agregar uno',
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 20)),
        ]),
      );
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({
    required this.product,
    required this.currentIndex,
    required this.onPageChanged,
  });
  final Product product;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final images =
        product.images.where((image) => image.url.isNotEmpty).toList();
    const fallback = ColoredBox(
      color: Color(0xFFDBEAFE),
      child: Center(
        child: Icon(Icons.restaurant, size: 72, color: Color(0xFF2563EB)),
      ),
    );
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: images.isEmpty
                ? fallback
                : PageView.builder(
                    itemCount: images.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (_, index) => CachedNetworkImage(
                      imageUrl: images[index].url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => fallback,
                      errorWidget: (_, __, ___) => fallback,
                    ),
                  ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: index == currentIndex ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == currentIndex
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F4F4),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          title: const Text(
            'Carrito',
            style: TextStyle(
              color: Color(0xFF0F1E3A),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ref.watch(cartProvider).when(
              data: (cart) {
                if (cart.items.isEmpty) {
                  return const EmptyState(
                    title: 'Tu carrito está vacío',
                    message:
                        'Explora comercios y agrega tus productos favoritos.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    const Text(
                      'Tu pedido',
                      style: TextStyle(
                        color: Color(0xFF0F1E3A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...cart.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CartItemTile(
                          item: item,
                          currency: cart.currency,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE3E8F0),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A0F1E3A),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: Color(0xFF0F1E3A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${cart.currency} ${cart.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF0F1E3A),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(commerceRepositoryProvider)
                                  .clearCart();

                              ref.invalidate(cartProvider);
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              foregroundColor: const Color(0xFFFF5A5A),
                              side: const BorderSide(
                                color: Color(0xFFFF5A5A),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 20,
                            ),
                            label: const Text(
                              'Vaciar carrito',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const CheckoutPage(),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: const Color(0xFFFF5A5A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Continuar al checkout',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5A5A),
                ),
              ),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(cartProvider),
              ),
            ),
      );
}

class CartItemTile extends ConsumerWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.currency,
  });

  final CartItem item;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE3E8F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F1E3A),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Imagen / ícono del producto
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFFFF5A5A),
                size: 27,
              ),
            ),

            const SizedBox(width: 12),

            // Información del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F1E3A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$currency ${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFFF5A5A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Acciones
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Eliminar arriba a la derecha
                SizedBox(
                  width: 34,
                  height: 30,
                  child: IconButton(
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await ref
                          .read(commerceRepositoryProvider)
                          .removeItem(item.id);

                      ref.invalidate(cartProvider);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFF5A5A),
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Selector de cantidad
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE3E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reducir
                      IconButton(
                        tooltip: 'Reducir',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 36,
                        ),
                        onPressed: () async {
                          if (item.quantity <= 1) {
                            await ref
                                .read(commerceRepositoryProvider)
                                .removeItem(item.id);
                          } else {
                            await ref
                                .read(commerceRepositoryProvider)
                                .updateItem(
                                  item.id,
                                  item.quantity - 1,
                                );
                          }

                          ref.invalidate(cartProvider);
                        },
                        icon: const Icon(
                          Icons.remove,
                          color: Color(0xFF647185),
                          size: 17,
                        ),
                      ),

                      // Cantidad
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 28,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            color: Color(0xFF0F1E3A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Aumentar
                      IconButton(
                        tooltip: 'Aumentar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 36,
                        ),
                        onPressed: () async {
                          await ref.read(commerceRepositoryProvider).updateItem(
                                item.id,
                                item.quantity + 1,
                              );

                          ref.invalidate(cartProvider);
                        },
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFFFF5A5A),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
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
                label: Text(busy ? 'Confirmando…' : 'Crear pedido'),
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

class _CheckoutPageState extends ConsumerState<CheckoutPage>
    with WidgetsBindingObserver {
  YapeDeclaration? declaration;
  int declarationEpoch = 0;
  bool yapeSheetOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      setState(() {
        declaration = null;
        if (!yapeSheetOpen) declarationEpoch++;
      });
  }

  YapeCheckoutSnapshot? _snapshot(Cart? cart) {
    if (cart == null ||
        address == null ||
        coverage?.covered != true ||
        coverageAddress != address ||
        coverageMerchant != cart.merchantId ||
        coverage?.deliveryFee == null ||
        checkingCoverage) return null;
    return YapeCheckoutSnapshot(
        merchantId: cart.merchantId,
        addressId: address!,
        total: _quotedTotal(cart, coverage),
        deliveryFee: coverage!.deliveryFee!,
        currency: cart.currency);
  }

  String? address;
  String? coverageAddress;
  String? coverageMerchant;
  CoverageResult? coverage;
  bool checkingCoverage = false;
  String? errorMessage;
  bool busy = false;
  Future<void> _validateCoverage(String addressId) async {
    setState(() {
      checkingCoverage = true;
      declaration = null;
      declarationEpoch++;
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
    final confirmed = declaration;
    final initial = _snapshot(ref.read(cartProvider).valueOrNull);
    if (busy ||
        confirmed == null ||
        initial == null ||
        !confirmed.matches(initial, confirmed.version)) return;
    final epoch = declarationEpoch;
    setState(() {
      busy = true;
      errorMessage = null;
    });
    Order? createdOrder;
    YapeRecoveryStore? recoveryStore;
    YapeRecoveryIntent? recoveryIntent;
    final repository = ref.read(commerceRepositoryProvider);
    try {
      final currentCart = await repository.cart();
      final currentCoverage =
          await repository.coverage(currentCart.merchantId, initial.addressId);
      final settings = await repository.yapeSettings(currentCart.merchantId);
      final current = YapeCheckoutSnapshot(
          merchantId: currentCart.merchantId,
          addressId: initial.addressId,
          total: _quotedTotal(currentCart, currentCoverage),
          deliveryFee: currentCoverage.deliveryFee ?? -1,
          currency: currentCart.currency);
      if (!mounted) return;
      if (epoch != declarationEpoch ||
          address != initial.addressId ||
          !currentCoverage.covered ||
          !settings.available ||
          !confirmed.matches(current, settings.version)) {
        ref.invalidate(cartProvider);
        setState(() {
          declaration = null;
          coverage = currentCoverage;
          coverageMerchant = currentCart.merchantId;
          coverageAddress = initial.addressId;
          errorMessage =
              'Los datos del pedido o de Yape cambiaron. Revisa el total y confirma tu Yape nuevamente.';
        });
        return;
      }
      final scope = await repository.api.store.identityScope();
      if (scope != null) {
        final parts = scope.split('/');
        recoveryStore = YapeRecoveryStore(parts[0], parts[1],
            origin: repository.api.dio.options.baseUrl);
        if (await recoveryStore.read() != null) {
          if (mounted) {
            ref.read(customerMainTabProvider.notifier).state =
                customerOrdersTabIndex;
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          return;
        }
        recoveryIntent = YapeRecoveryIntent(
            snapshot: current,
            version: confirmed.version,
            checkoutKey: const Uuid().v4(),
            paymentKey: const Uuid().v4());
        await recoveryStore.save(recoveryIntent);
      }
      createdOrder =
          await repository.checkout(initial.addressId, current.deliveryFee);
      if (recoveryIntent != null) {
        recoveryIntent = recoveryIntent.withOrder(createdOrder.id);
        await recoveryStore!.save(recoveryIntent);
        await repository.payYape(createdOrder.id, confirmed.version,
            idempotencyKey: recoveryIntent.paymentKey);
        await recoveryStore.clear();
      } else {
        await repository.payYape(createdOrder.id, confirmed.version);
      }
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
        if (recoveryStore != null && recoveryIntent != null) {
          final code = repository.errorCode(error);
          if (const {
            'OUTSIDE_BUSINESS_HOURS',
            'EMPTY_CART',
            'DELIVERY_QUOTE_CHANGED',
            'PRICE_CHANGED',
            'CART_NOT_FOUND'
          }.contains(code)) {
            await recoveryStore.clear();
          }
        }
        if (repository.errorCode(error) == 'OUTSIDE_BUSINESS_HOURS') {
          setState(() {
            declaration = null;
            declarationEpoch++;
            errorMessage = 'Fuera de horario de atención';
          });
        } else if (repository.errorCode(error) == 'DELIVERY_QUOTE_CHANGED') {
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
    final snapshot = _snapshot(ref.read(cartProvider).valueOrNull);
    if (busy || snapshot == null) return;
    if (snapshot.currency != 'PEN') {
      setState(() =>
          errorMessage = 'Yape solo está disponible para pedidos en soles.');
      return;
    }
    final epoch = ++declarationEpoch;
    setState(() {
      declaration = null;
      errorMessage = null;
      busy = true;
    });
    try {
      final repository = ref.read(commerceRepositoryProvider);
      final scope = await repository.api.store.identityScope();
      if (scope != null) {
        final parts = scope.split('/');
        final pending = await YapeRecoveryStore(parts[0], parts[1],
                origin: repository.api.dio.options.baseUrl)
            .read();
        if (!mounted || epoch != declarationEpoch) return;
        if (pending != null) {
          setState(() => errorMessage =
              'Tienes una declaración pendiente en Pedidos. Revísala antes de realizar otro Yape.');
          return;
        }
      }
      final cart = ref.read(cartProvider).valueOrNull;
      if (cart == null) return;
      final availability = await ref
          .read(customerRepositoryProvider)
          .availability(cart.branchId);
      if (!mounted || epoch != declarationEpoch) return;
      if (!availability.open) {
        setState(() => errorMessage = 'Fuera de horario de atención');
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage =
            'No pudimos verificar la disponibilidad. Intenta nuevamente.');
      }
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted || epoch != declarationEpoch) return;
    final checkedCart = ref.read(cartProvider).valueOrNull;
    final checked = _snapshot(checkedCart);
    if (checkedCart == null || checked == null || !snapshot.sameAs(checked))
      return;
    yapeSheetOpen = true;
    final settings = await showModalBottomSheet<YapeSettings>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => YapeCheckoutSheet(
          total: snapshot.total,
          load: () async {
            final availability = await ref
                .read(customerRepositoryProvider)
                .availability(checkedCart.branchId);
            if (!availability.open) {
              throw const BranchClosedForYape();
            }
            return ref
                .read(commerceRepositoryProvider)
                .yapeSettings(snapshot.merchantId);
          }),
    );
    yapeSheetOpen = false;
    if (!mounted || settings == null || epoch != declarationEpoch) return;
    final current = _snapshot(ref.read(cartProvider).valueOrNull);
    if (current == null || !snapshot.sameAs(current)) return;
    setState(() => declaration = YapeDeclaration(snapshot, settings.version!));
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
    final snapshot = _snapshot(cart);
    final declared = snapshot != null &&
        declaration?.matches(snapshot, declaration?.version) == true;
    if (declaration != null && !declared) declaration = null;
    final canSubmit = !busy && declared;
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
          YapeCheckoutCard(
              declared: declared,
              onTap: !busy && snapshot != null ? _showPaymentMethods : null),
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

class _YapeRecoveryPanel extends ConsumerWidget {
  const _YapeRecoveryPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final origin = ref.watch(apiClientProvider).dio.options.baseUrl;
    return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .35),
        child: SingleChildScrollView(
            child: _YapeRecoveryAction(
          key: ValueKey('$origin/${user.tenantId}/${user.id}'),
          store: YapeRecoveryStore(user.tenantId, user.id, origin: origin),
          revision: ref.watch(ordersProvider),
        )));
  }
}

class _YapeRecoveryAction extends ConsumerStatefulWidget {
  const _YapeRecoveryAction(
      {super.key, required this.store, required this.revision});
  final YapeRecoveryStore store;
  final Object revision;
  @override
  ConsumerState<_YapeRecoveryAction> createState() =>
      _YapeRecoveryActionState();
}

class _YapeRecoveryActionState extends ConsumerState<_YapeRecoveryAction> {
  late Future<YapeRecoveryIntent?> pending;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    pending = widget.store.read();
  }

  @override
  void didUpdateWidget(covariant _YapeRecoveryAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!busy && oldWidget.revision != widget.revision)
      pending = widget.store.read();
  }

  Future<void> retry() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await YapeRecoveryService(widget.store).resume(
        createOrder: (_) async =>
            throw StateError('No se repite la creación del pedido.'),
        declare: (intent) => ref.read(commerceRepositoryProvider).payYape(
            intent.orderId!, intent.version,
            idempotencyKey: intent.paymentKey),
      );
      if (!mounted) return;
      ref.invalidate(ordersProvider);
      setState(() => pending = widget.store.read());
    } catch (_) {
      if (mounted)
        setState(() => error =
            'No pudimos registrar la declaración. No repitas el Yape. Si cambiaron los datos de pago, solicita al comercio revisar tu transferencia.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> acknowledge() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Revisión con el comercio'),
              content: const Text(
                  '¿El comercio ya revisó esta transferencia y el pedido? Cerrar este aviso no confirma ni modifica el pago.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Volver')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sí, ya lo revisó'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.clear();
      if (mounted) setState(() => pending = widget.store.read());
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'No se pudo cerrar el aviso. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<YapeRecoveryIntent?>(
      future: pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const SizedBox.shrink();
        if (snapshot.hasError)
          return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Text('No se pudo consultar la declaración pendiente.'),
                TextButton(
                    onPressed: () =>
                        setState(() => pending = widget.store.read()),
                    child: const Text('Reintentar'))
              ]));
        final intent = snapshot.data;
        if (intent == null) return const SizedBox.shrink();
        return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Declaración Yape pendiente',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(intent.orderId == null
                      ? 'La conexión se interrumpió al crear el pedido. Revisa tus pedidos y consulta al comercio. No crees otro pedido ni repitas el Yape para esta transferencia.'
                      : 'Tu pedido existe. Reintenta registrar la declaración de la transferencia realizada, sin volver a pagar.'),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  Wrap(spacing: 10, children: [
                    if (intent.orderId != null)
                      FilledButton(
                          onPressed: busy ? null : retry,
                          child: Text(busy
                              ? 'Registrando…'
                              : 'Reintentar declaración')),
                    TextButton(
                        onPressed: busy ? null : acknowledge,
                        child: const Text('Ya lo revisé con el comercio')),
                  ]),
                ]));
      });
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
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: Column(children: [
          const _YapeRecoveryPanel(),
          Expanded(
              child: ref.watch(ordersProvider).when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return const EmptyState(
                          title: 'Sin pedidos',
                          message:
                              'Tus pedidos activos e históricos aparecerán aquí.',
                        );
                      }
                      return LayoutBuilder(builder: (context, constraints) {
                        final horizontal =
                            constraints.maxWidth >= 700 ? 32.0 : 16.0;
                        return _OrderListEntrance(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                                horizontal, 20, horizontal, 32),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return OrderCard(
                                order: order,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        OrderDetailPage(order: order),
                                  ),
                                ),
                                onTrack: trackableDeliveryStatuses
                                        .contains(order.status)
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                CustomerOrderTrackingPage(
                                              orderId: order.id,
                                              orderNumber: order.number,
                                            ),
                                          ),
                                        )
                                    : null,
                              );
                            },
                          ),
                        );
                      });
                    },
                    loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF7C00)),
                    ),
                    error: (error, _) => ErrorState(message: error.toString()),
                  )),
        ]),
      );
}

class _OrderListEntrance extends StatelessWidget {
  const _OrderListEntrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        tween: Tween(begin: 0, end: 1),
        child: child,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        ),
      );
}

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onTrack,
  });

  final Order order;
  final VoidCallback onTap;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final delivered = order.status == 'DELIVERED';
    return Semantics(
      button: true,
      label: 'Pedido ${order.number}, ${_deliveryStatusLabel(order.status)}, '
          '${order.currency} ${order.total.toStringAsFixed(2)}',
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 80),
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              constraints: const BoxConstraints(minHeight: 112),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 330;
                return Row(children: [
                  Container(
                    width: compact ? 50 : 60,
                    height: compact ? 50 : 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: Color(0xFFFF7C00), size: 30),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.number,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF111827),
                              fontSize: compact ? 14 : 17,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 4),
                        _OrderStatusBadge(
                            status: order.status, delivered: delivered),
                        const SizedBox(height: 4),
                        Text(_orderDate(order.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontSize: compact ? 11 : 15,
                            )),
                        if (onTrack != null)
                          TextButton.icon(
                            onPressed: onTrack,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: EdgeInsets.zero,
                              foregroundColor: const Color(0xFFFF7C00),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.delivery_dining, size: 18),
                            label: Text('Seguir pedido',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(order.currency,
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280), fontSize: 11)),
                      Text(order.total.toStringAsFixed(2),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF111827),
                            fontSize: compact ? 16 : 19,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF)),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status, required this.delivered});
  final String status;
  final bool delivered;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: delivered ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(_deliveryStatusLabel(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color:
                  delivered ? const Color(0xFF16A34A) : const Color(0xFFF97316),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
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
        appBar: AppBar(title: const Text('Detalle del pedido')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: tracking,
          builder: (context, snapshot) {
            final deliveryId = snapshot.data?['deliveryId']?.toString();
            final currentStatus = realtimeStatus ??
                snapshot.data?['status']?.toString() ??
                order.status;
            return ListView(padding: const EdgeInsets.all(20), children: [
              OrderDetailSummary(
                number: order.number,
                statusLabel: _deliveryStatusLabel(currentStatus),
                currency: order.currency,
                total: order.total,
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'El tracking estará disponible cuando exista una entrega.'))),
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
              if (snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError)
                OrderCourierInfo(
                    name: snapshot.data?['courierName']?.toString() ??
                        'Por asignar'),
              const SizedBox(height: 12),
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
              OrderCourierChatButton(
                  status: currentStatus,
                  deliveryId: deliveryId,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => ChatPage(deliveryId: deliveryId!)))),
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
  late final RealtimeClient client;
  @override
  void initState() {
    super.initState();
    client = ref.read(realtimeClientProvider);
    Future.microtask(() async {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).value;
      if (user == null) return;
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
    client.disconnect();
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
              Row(children: [
                Icon(Icons.timeline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Seguimiento de tu pedido',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 4),
              Text('Historial de actualizaciones',
                  style: Theme.of(context).textTheme.bodySmall),
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
                    children: [
                      for (var i = 0; i < events.length; i++)
                        OrderTimelineEntry(
                          title: _deliveryStatusLabel(events[i].status),
                          date: _orderDate(events[i].createdAt),
                          last: i == events.length - 1,
                        )
                    ],
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
      'ARRIVED_AT_CUSTOMER': 'Tu repartidor llegó',
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
