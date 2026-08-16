import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/presentation/commerce_pages.dart';
import '../../address/presentation/customer_address_form_page.dart';
import '../data/customer_repository.dart';

final customerRepositoryProvider = Provider(
  (ref) => CustomerRepository(ref.watch(apiClientProvider)),
);
final addressesProvider = FutureProvider(
  (ref) => ref.watch(customerRepositoryProvider).addresses(),
);
final merchantsProvider = FutureProvider(
  (ref) => ref.watch(customerRepositoryProvider).merchants(),
);
final favoritesProvider = FutureProvider(
  (ref) => ref.watch(customerRepositoryProvider).favorites(),
);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final addresses = ref.watch(addressesProvider);
    final merchants = ref.watch(merchantsProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        gradient: RadialGradient(
          center: Alignment(1.08, -1.05),
          radius: .72,
          colors: [Color(0xFFFFF4E8), Colors.white],
          stops: [0, .72],
        ),
      ),
      child: RefreshIndicator(
        color: _homeOrange,
        onRefresh: () async {
          ref.invalidate(addressesProvider);
          ref.invalidate(merchantsProvider);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 700 ? 40.0 : 20.0;
            final contentWidth = constraints.maxWidth >= 900 ? 760.0 : 680.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                constraints.maxHeight < 650 ? 16 : 24,
                horizontalPadding,
                112,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: _HomeEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hola, ${user?.firstName ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: _homeNavy,
                              fontSize: constraints.maxWidth < 350 ? 26 : 28,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¿Qué quieres pedir hoy?',
                            style: GoogleFonts.poppins(
                              color: _homeSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          addresses.when(
                            data: (items) => _AddressHomeCard(
                              label: items.isEmpty
                                  ? 'Agrega una dirección'
                                  : items.first.label,
                              address: items.isEmpty
                                  ? 'Necesaria para validar cobertura'
                                  : items.first.addressLine,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const AddressesPage(),
                                ),
                              ),
                            ),
                            loading: () => const _HomeCardSkeleton(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Comercios disponibles',
                            style: GoogleFonts.poppins(
                              color: _homeNavy,
                              fontSize: constraints.maxWidth < 350 ? 18 : 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          merchants.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return const EmptyState(
                                  title: 'Sin comercios',
                                  message: 'No hay comercios activos con '
                                      'sucursales disponibles.',
                                );
                              }
                              return Column(
                                children: [
                                  for (var index = 0;
                                      index < items.length;
                                      index++) ...[
                                    _MerchantHomeCard(
                                      merchant: items[index],
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MerchantPage(
                                            merchant: items[index],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (index < items.length - 1)
                                      const SizedBox(height: 8),
                                  ],
                                ],
                              );
                            },
                            loading: () => const Column(
                              children: [
                                _HomeCardSkeleton(),
                                SizedBox(height: 8),
                                _HomeCardSkeleton(),
                              ],
                            ),
                            error: (error, _) => ErrorState(
                              message: error.toString(),
                              onRetry: () => ref.invalidate(merchantsProvider),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

const _homeNavy = Color(0xFF06163A);
const _homeOrange = Color(0xFFFF7C00);
const _homePrimary = Color(0xFF111827);
const _homeSecondary = Color(0xFF6B7280);
const _homeDivider = Color(0xFFF1F5F9);

class _HomeEntrance extends StatelessWidget {
  const _HomeEntrance({required this.child});
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
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        ),
      );
}

class _AddressHomeCard extends StatelessWidget {
  const _AddressHomeCard({
    required this.label,
    required this.address,
    required this.onTap,
  });
  final String label;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _HomeCard(
        onTap: onTap,
        child: Row(
          children: [
            const _HomeIconBox(
              icon: Icons.location_on_outlined,
              background: Color(0xFFFFF4E8),
              foreground: _homeOrange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _homePrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _homeSecondary,
                        fontSize: 12,
                        height: 1.35,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _homeNavy, size: 28),
          ],
        ),
      );
}

class _MerchantHomeCard extends StatelessWidget {
  const _MerchantHomeCard({required this.merchant, required this.onTap});
  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _HomeCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'merchant-avatar-${merchant.id}',
                  child: _MerchantLogo(merchant: merchant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _homePrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Text('${merchant.branchName} · ${merchant.description}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _homeSecondary,
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: _homeNavy, size: 28),
              ],
            ),
            if (merchant.bannerUrl != null) ...[
              const SizedBox(height: 10),
              _MerchantBanner(url: merchant.bannerUrl!),
            ],
          ],
        ),
      );
}

class _MerchantBanner extends StatefulWidget {
  const _MerchantBanner({required this.url});
  final String url;

  @override
  State<_MerchantBanner> createState() => _MerchantBannerState();
}

class _MerchantBannerState extends State<_MerchantBanner> {
  bool failed = false;

  @override
  void didUpdateWidget(covariant _MerchantBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) failed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 6,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, __) => const ColoredBox(color: Color(0xFFF8FAFC)),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
          errorListener: (_) {
            if (mounted) setState(() => failed = true);
          },
        ),
      ),
    );
  }
}

class _MerchantLogo extends StatelessWidget {
  const _MerchantLogo({required this.merchant, this.size = 48});
  final Merchant merchant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = _HomeIconBox(
      text: merchant.name.isEmpty
          ? '?'
          : merchant.name.characters.first.toUpperCase(),
      size: size,
      background: const Color(0xFFF0EEFF),
      foreground: const Color(0xFF4F46E5),
    );
    if (merchant.logoUrl == null) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: merchant.logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          overlayColor: const WidgetStatePropertyAll(Color(0x14FF7C00)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _homeDivider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
}

class _HomeIconBox extends StatelessWidget {
  const _HomeIconBox({
    this.icon,
    this.text,
    this.size = 48,
    required this.background,
    required this.foreground,
  });
  final IconData? icon;
  final String? text;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: icon != null
            ? Icon(icon, color: foreground, size: size * .53)
            : Text(text!,
                style: GoogleFonts.poppins(
                  color: foreground,
                  fontSize: size * .44,
                  fontWeight: FontWeight.w600,
                )),
      );
}

class _HomeCardSkeleton extends StatelessWidget {
  const _HomeCardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 80),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _homeDivider),
        ),
        child: const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
}

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  Future<void> _openForm(BuildContext context, Address? address) =>
      Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => CustomerAddressFormPage(address: address)));

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Mis direcciones')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Agregar dirección'),
        ),
        body: ref.watch(addressesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(addressesProvider),
              ),
              data: (addresses) => addresses.isEmpty
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: () => _openForm(context, null),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Agregar una dirección'),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: addresses
                          .map(
                            (address) => Card(
                              child: ListTile(
                                leading: Icon(address.isDefault
                                    ? Icons.home
                                    : Icons.location_on_outlined),
                                title: Text(address.label),
                                subtitle: Text(
                                  '${address.addressLine}\n${address.district}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!address.isDefault)
                                      IconButton(
                                        tooltip: 'Usar como predeterminada',
                                        icon: const Icon(Icons.star_border),
                                        onPressed: () async {
                                          await ref
                                              .read(customerRepositoryProvider)
                                              .makeDefaultAddress(address.id);
                                          ref.invalidate(addressesProvider);
                                        },
                                      ),
                                    IconButton(
                                      tooltip: 'Editar dirección',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () =>
                                          _openForm(context, address),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar dirección',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        await ref
                                            .read(customerRepositoryProvider)
                                            .deleteAddress(address.id);
                                        ref.invalidate(addressesProvider);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _openForm(context, address),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
      );
}

class AddressDialog extends ConsumerStatefulWidget {
  const AddressDialog({super.key, this.address});
  final Address? address;
  @override
  ConsumerState<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends ConsumerState<AddressDialog> {
  late final TextEditingController label;
  late final TextEditingController recipient;
  late final TextEditingController line;
  late final TextEditingController district;
  late final TextEditingController phone;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    label = TextEditingController(text: address?.label ?? 'Casa');
    recipient =
        TextEditingController(text: address?.recipientName ?? 'Cliente');
    line = TextEditingController(text: address?.addressLine ?? '');
    district = TextEditingController(text: address?.district ?? '');
    phone = TextEditingController(text: address?.phone ?? '');
  }

  @override
  void dispose() {
    label.dispose();
    recipient.dispose();
    line.dispose();
    district.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.address == null ? 'Nueva dirección' : 'Editar dirección',
        ),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: recipient,
              decoration: const InputDecoration(labelText: 'Destinatario'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: line,
              decoration: const InputDecoration(labelText: 'Dirección'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: district,
              decoration: const InputDecoration(labelText: 'Distrito'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final data = addressRequestData(
                      label: label.text,
                      recipientName: recipient.text,
                      phone: phone.text,
                      addressLine: line.text,
                      district: district.text,
                      isDefault: widget.address?.isDefault ?? false,
                    );
                    final repository = ref.read(customerRepositoryProvider);
                    if (widget.address == null) {
                      await repository.addAddress(data);
                    } else {
                      await repository.updateAddress(widget.address!.id, data);
                    }
                    ref.invalidate(addressesProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text(widget.address == null ? 'Agregar' : 'Guardar cambios'),
          ),
        ],
      );
}

class MerchantPage extends ConsumerWidget {
  const MerchantPage({super.key, required this.merchant});
  final Merchant merchant;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final favorite = favoriteForMerchant(
      favorites.valueOrNull ?? const <Favorite>[],
      merchant.id,
    );
    return Scaffold(
      appBar: AppBar(
          title: Row(children: [
            Hero(
              tag: 'merchant-avatar-${merchant.id}',
              child: _MerchantLogo(merchant: merchant, size: 36),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(merchant.name, overflow: TextOverflow.ellipsis),
            ),
          ]),
          actions: [
            IconButton(
                tooltip: favorite == null
                    ? 'Agregar a favoritos'
                    : 'Quitar de favoritos',
                icon: Icon(
                  favorite == null ? Icons.favorite_border : Icons.favorite,
                  color: favorite == null ? null : Colors.red,
                ),
                onPressed: favorites.isLoading
                    ? null
                    : () async {
                        final repository = ref.read(customerRepositoryProvider);
                        if (favorite == null) {
                          await repository.addMerchantFavorite(merchant.id);
                        } else {
                          await repository.removeFavorite(favorite.id);
                        }
                        ref.invalidate(favoritesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(favorite == null
                                ? 'Comercio agregado a favoritos'
                                : 'Comercio eliminado de favoritos'),
                          ));
                        }
                      })
          ]),
      body: FutureBuilder<List<Product>>(
        future:
            ref.read(customerRepositoryProvider).products(merchant.branchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return ErrorState(message: snapshot.error.toString());
          final products = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                merchant.branchName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...products.map(
                (product) => Card(
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.description,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          '${product.currency} ${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    trailing: _ProductThumbnail(product: product),
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute<ProductAddedResult>(
                          builder: (_) =>
                              ProductPage(merchant: merchant, product: product),
                        ),
                      );
                      if (result == null || !context.mounted) return;
                      ref.invalidate(cartProvider);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFDBEAFE),
      child: Center(
        child: Icon(Icons.restaurant, color: Color(0xFF2563EB), size: 32),
      ),
    );
    final image = product.primaryImage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 82,
        child: image == null || image.url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: image.url,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}
