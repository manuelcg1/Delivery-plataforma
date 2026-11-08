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
import '../domain/merchant_category.dart';
import 'merchant_category_carousel.dart';
import 'merchant_catalog_visuals.dart';

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

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  MerchantCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final addresses = ref.watch(addressesProvider);
    final merchants = ref.watch(merchantsProvider);
    final filteredMerchants = merchants.whenData((items) =>
        _selectedCategory == null
            ? items
            : items
                .where((merchant) =>
                    MerchantCategory.fromCode(merchant.merchantType) ==
                    _selectedCategory)
                .toList(growable: false));

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F4),
      ),
      child: RefreshIndicator(
        color: const Color(0xFFFF5A5A),
        backgroundColor: Colors.white,
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
                    constraints: BoxConstraints(
                      maxWidth: contentWidth,
                    ),
                    child: _HomeEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          //
                          // SALUDO
                          //
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hola, ${user?.firstName ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: const Color(
                                          0xFF0F1E3A,
                                        ),
                                        fontSize: constraints.maxWidth < 350
                                            ? 26
                                            : 28,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '¿Qué quieres pedir hoy?',
                                      style: GoogleFonts.poppins(
                                        color: const Color(
                                          0xFF647185,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              //
                              // ICONO PERFIL VISUAL
                              //
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE5E5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xFFFF5A5A),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          //
                          // DIRECCIÓN
                          //
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

                          const SizedBox(height: 26),

                          Text('Categorías',
                              style: GoogleFonts.poppins(
                                color: _homeNavy,
                                fontSize: constraints.maxWidth < 350 ? 18 : 20,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 10),
                          MerchantCategoryCarousel(
                            selected: _selectedCategory,
                            onChanged: (category) =>
                                setState(() => _selectedCategory = category),
                          ),
                          const SizedBox(height: 22),

                          //
                          // ENCABEZADO COMERCIOS
                          //
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Comercios disponibles',
                                  style: GoogleFonts.poppins(
                                    color: const Color(
                                      0xFF0F1E3A,
                                    ),
                                    fontSize:
                                        constraints.maxWidth < 350 ? 18 : 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE5E5),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  color: Color(0xFFFF5A5A),
                                  size: 19,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          //
                          // COMERCIOS
                          //
                          if (_selectedCategory != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    filteredMerchants.when(
                                      data: (items) =>
                                          '${_selectedCategory!.label} · ${items.length} ${items.length == 1 ? 'comercio' : 'comercios'}',
                                      loading: () => _selectedCategory!.label,
                                      error: (_, __) =>
                                          _selectedCategory!.label,
                                    ),
                                    style: GoogleFonts.poppins(
                                        color: _homeSecondary, fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _selectedCategory = null),
                                  style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFE00024)),
                                  child: const Text('Ver todos'),
                                ),
                              ],
                            ),
                          filteredMerchants.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      18,
                                    ),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFE3E8F0,
                                      ),
                                    ),
                                  ),
                                  child: EmptyState(
                                    title: 'Sin comercios',
                                    message: _selectedCategory == null
                                        ? 'No hay comercios activos con sucursales disponibles.'
                                        : 'No hay comercios disponibles en esta categoría.',
                                  ),
                                );
                              }

                              return Column(
                                children: [
                                  for (var index = 0;
                                      index < items.length;
                                      index++) ...[
                                    MerchantPreviewCard(
                                      merchant: items[index],
                                      onTap: () => Navigator.of(
                                        context,
                                      ).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MerchantPage(
                                            merchant: items[index],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (index < items.length - 1)
                                      const SizedBox(
                                        height: 12,
                                      ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const Column(
                              children: [
                                _HomeCardSkeleton(),
                                SizedBox(height: 12),
                                _HomeCardSkeleton(),
                              ],
                            ),
                            error: (error, _) => ErrorState(
                              message: error.toString(),
                              onRetry: () => ref.invalidate(
                                merchantsProvider,
                              ),
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

class MerchantPreviewCard extends StatelessWidget {
  const MerchantPreviewCard(
      {super.key,
      required this.merchant,
      required this.onTap,
      this.showDescription = false,
      this.animateLogo = true});
  final Merchant merchant;
  final VoidCallback onTap;
  final bool showDescription, animateLogo;

  @override
  Widget build(BuildContext context) => _HomeCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (animateLogo)
                  Hero(
                    tag: 'merchant-avatar-${merchant.id}',
                    child: _MerchantLogo(merchant: merchant),
                  ),
                if (!animateLogo) _MerchantLogo(merchant: merchant),
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
                      if (showDescription &&
                          merchant.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(merchant.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: _homeSecondary,
                                fontSize: 13,
                                height: 1.3)),
                      ],
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

  Future<void> _openForm(
    BuildContext context,
    Address? address,
  ) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerAddressFormPage(
            address: address,
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F4F4),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 20,
          iconTheme: const IconThemeData(
            color: Color(0xFF0F1E3A),
          ),
          title: const Text(
            'Mis direcciones',
            style: TextStyle(
              color: Color(0xFF0F1E3A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFFF5A5A),
          foregroundColor: Colors.white,
          elevation: 2,
          onPressed: () => _openForm(
            context,
            null,
          ),
          icon: const Icon(
            Icons.add_location_alt_outlined,
          ),
          label: const Text(
            'Agregar dirección',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: ref.watch(addressesProvider).when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5A5A),
                ),
              ),
              error: (error, _) => ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(
                  addressesProvider,
                ),
              ),
              data: (addresses) {
                if (addresses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE5E5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFFFF5A5A),
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Aún no tienes direcciones',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF0F1E3A),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Agrega una dirección para validar cobertura y recibir tus pedidos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF647185),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A5A),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _openForm(
                              context,
                              null,
                            ),
                            icon: const Icon(
                              Icons.add_location_alt_outlined,
                            ),
                            label: const Text(
                              'Agregar una dirección',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    112,
                  ),
                  children: [
                    const Text(
                      'Direcciones guardadas',
                      style: TextStyle(
                        color: Color(0xFF0F1E3A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...addresses.map(
                      (address) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openForm(
                              context,
                              address,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE3E8F0),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x080F1E3A),
                                    blurRadius: 14,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: address.isDefault
                                          ? const Color(
                                              0xFFFFE5E5,
                                            )
                                          : const Color(
                                              0xFFF4F4F4,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        14,
                                      ),
                                    ),
                                    child: Icon(
                                      address.isDefault
                                          ? Icons.home_rounded
                                          : Icons.location_on_outlined,
                                      color: address.isDefault
                                          ? const Color(
                                              0xFFFF5A5A,
                                            )
                                          : const Color(
                                              0xFF647185,
                                            ),
                                      size: 23,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                address.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(
                                                    0xFF0F1E3A,
                                                  ),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (address.isDefault)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFFE5E5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    99,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Principal',
                                                  style: TextStyle(
                                                    color: Color(
                                                      0xFFFF5A5A,
                                                    ),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          address.addressLine,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(
                                              0xFF647185,
                                            ),
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (!address.isDefault)
                                              _AddressActionButton(
                                                tooltip:
                                                    'Usar como predeterminada',
                                                icon: Icons.star_border_rounded,
                                                onPressed: () async {
                                                  await ref
                                                      .read(
                                                        customerRepositoryProvider,
                                                      )
                                                      .makeDefaultAddress(
                                                        address.id,
                                                      );

                                                  ref.invalidate(
                                                    addressesProvider,
                                                  );
                                                },
                                              ),
                                            if (!address.isDefault)
                                              const SizedBox(
                                                width: 8,
                                              ),
                                            _AddressActionButton(
                                              tooltip: 'Editar dirección',
                                              icon: Icons.edit_outlined,
                                              onPressed: () => _openForm(
                                                context,
                                                address,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 8,
                                            ),
                                            _AddressActionButton(
                                              tooltip: 'Eliminar dirección',
                                              icon:
                                                  Icons.delete_outline_rounded,
                                              destructive: true,
                                              onPressed: () async {
                                                await ref
                                                    .read(
                                                      customerRepositoryProvider,
                                                    )
                                                    .deleteAddress(
                                                      address.id,
                                                    );

                                                ref.invalidate(
                                                  addressesProvider,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      );
}

class _AddressActionButton extends StatelessWidget {
  const _AddressActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFFF5A5A) : const Color(0xFF647185);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: destructive ? const Color(0xFFFFF2F2) : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 19,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
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

class MerchantPage extends ConsumerStatefulWidget {
  const MerchantPage({super.key, required this.merchant});
  final Merchant merchant;

  @override
  ConsumerState<MerchantPage> createState() => _MerchantPageState();
}

class _MerchantPageState extends ConsumerState<MerchantPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final merchant = widget.merchant;
    final favorites = ref.watch(favoritesProvider);
    final favorite = favoriteForMerchant(
      favorites.valueOrNull ?? const <Favorite>[],
      merchant.id,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 74,
        titleSpacing: 8,
        iconTheme: const IconThemeData(
          color: Color(0xFF0F1E3A),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'merchant-avatar-${merchant.id}',
              child: _MerchantLogo(
                merchant: merchant,
                size: 40,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                merchant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF0F1E3A),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    favorite == null ? Colors.white : const Color(0xFFFFF0DC),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: favorite == null
                      ? const Color(0xFFE3E8F0)
                      : const Color(0xFFFFD5A3),
                ),
              ),
              child: IconButton(
                tooltip: favorite == null
                    ? 'Agregar a favoritos'
                    : 'Quitar de favoritos',
                padding: EdgeInsets.zero,
                icon: Icon(
                  favorite == null
                      ? Icons.favorite_border_rounded
                      : Icons.favorite_rounded,
                  color: const Color(0xFFFF7C00),
                  size: 22,
                ),
                onPressed: favorites.isLoading
                    ? null
                    : () async {
                        final repository = ref.read(customerRepositoryProvider);

                        if (favorite == null) {
                          await repository.addMerchantFavorite(
                            merchant.id,
                          );
                        } else {
                          await repository.removeFavorite(
                            favorite.id,
                          );
                        }

                        ref.invalidate(favoritesProvider);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF0F1E3A),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              content: Text(
                                favorite == null
                                    ? 'Comercio agregado a favoritos'
                                    : 'Comercio eliminado de favoritos',
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future:
            ref.read(customerRepositoryProvider).products(merchant.branchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF7C00),
              ),
            );
          }

          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error.toString(),
            );
          }

          final products = filterMerchantProducts(snapshot.data!, query);

          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF6F7FA),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                40,
              ),
              children: [
                MerchantCatalogHeader(merchant: merchant),

                const SizedBox(height: 18),

                //
                // Buscador
                //
                SearchBar(
                  hintText: 'Buscar en ${merchant.name}',
                  leading: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFFF7C00),
                  ),
                  hintStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      color: Color(0xFF647185),
                      fontSize: 14,
                    ),
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      color: Color(0xFF0F1E3A),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: const WidgetStatePropertyAll(
                    Colors.white,
                  ),
                  side: const WidgetStatePropertyAll(
                    BorderSide(
                      color: Color(0xFFE3E8F0),
                    ),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),

                const SizedBox(height: 26),

                //
                // Título productos
                //
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        query.trim().isEmpty ? 'Productos' : 'Resultados',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF0F1E3A),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (products.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0DC),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${products.length}',
                          style: const TextStyle(
                            color: Color(0xFFFF7C00),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                //
                // Productos
                //
                if (products.isEmpty)
                  EmptyState(
                    title: query.trim().isEmpty
                        ? 'Sin productos'
                        : 'Sin resultados',
                    message: query.trim().isEmpty
                        ? 'Este comercio todavía no tiene productos disponibles.'
                        : 'No encontramos productos que coincidan con tu búsqueda.',
                  )
                else
                  ...products.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: MerchantCatalogProductCard(
                        product: product,
                        priceLabel: merchantProductPrice(product),
                        onTap: () async {
                          final repository =
                              ref.read(customerRepositoryProvider);
                          Product detailedProduct;
                          try {
                            final availability = await repository
                                .availability(merchant.branchId);
                            if (!context.mounted) return;
                            if (!availability.open) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fuera de horario de atención'),
                                ),
                              );
                              return;
                            }
                            detailedProduct =
                                await repository.product(product.id);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No pudimos verificar la disponibilidad. Intenta nuevamente.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          if (!context.mounted) return;
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute<ProductAddedResult>(
                              builder: (_) => ProductPage(
                                merchant: merchant,
                                product: product.copyWithCatalogDetails(
                                  detailedProduct,
                                ),
                              ),
                            ),
                          );

                          if (result == null || !context.mounted) {
                            return;
                          }

                          ref.invalidate(cartProvider);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

List<Product> filterMerchantProducts(List<Product> products, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return products;
  return products
      .where((product) =>
          product.name.toLowerCase().contains(normalized) ||
          product.description.toLowerCase().contains(normalized))
      .toList(growable: false);
}

String merchantProductPrice(Product product) {
  final symbol = switch (product.currency.toUpperCase()) {
    'PEN' => 'S/',
    'USD' => r'$',
    _ => product.currency,
  };
  return '$symbol ${product.price.toStringAsFixed(2)}';
}
