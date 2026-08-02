import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final addresses = ref.watch(addressesProvider),
        merchants = ref.watch(merchantsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(addressesProvider);
        ref.invalidate(merchantsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hola, ${user?.firstName ?? ''}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text('¿Qué quieres pedir hoy?'),
          const SizedBox(height: 20),
          addresses.when(
            data: (items) => Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  items.isEmpty ? 'Agrega una dirección' : items.first.label,
                ),
                subtitle: Text(
                  items.isEmpty
                      ? 'Necesaria para validar cobertura'
                      : items.first.addressLine,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AddressesPage(),
                  ),
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 20),
          Text(
            'Comercios disponibles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          merchants.when(
            data: (items) {
              if (items.isEmpty)
                return const EmptyState(
                  title: 'Sin comercios',
                  message:
                      'No hay comercios activos con sucursales disponibles.',
                );
              return Column(
                children: items
                    .map(
                      (merchant) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(merchant.name.substring(0, 1)),
                          ),
                          title: Text(merchant.name),
                          subtitle: Text(
                            '${merchant.branchName} · ${merchant.description}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MerchantPage(merchant: merchant),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(merchantsProvider),
            ),
          ),
        ],
      ),
    );
  }
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
      appBar: AppBar(title: Text(merchant.name), actions: [
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
                    subtitle: Text(product.description),
                    trailing: Text(
                      '${product.currency} ${product.price.toStringAsFixed(2)}',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductPage(merchant: merchant, product: product),
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
}
