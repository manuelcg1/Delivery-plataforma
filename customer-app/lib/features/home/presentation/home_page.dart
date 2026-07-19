import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/presentation/commerce_pages.dart';
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
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AddressDialog(),
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

class AddressDialog extends ConsumerStatefulWidget {
  const AddressDialog({super.key});
  @override
  ConsumerState<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends ConsumerState<AddressDialog> {
  final line = TextEditingController(),
      district = TextEditingController(),
      phone = TextEditingController();
  bool busy = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nueva dirección'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
          ],
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
                    await ref.read(customerRepositoryProvider).addAddress({
                      'label': 'Casa',
                      'recipientName': 'Cliente',
                      'phone': phone.text,
                      'addressLine': line.text,
                      'district': district.text,
                      'countryCode': 'PE',
                      'isDefault': true,
                    });
                    ref.invalidate(addressesProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('Guardar'),
          ),
        ],
      );
}

class MerchantPage extends ConsumerWidget {
  const MerchantPage({super.key, required this.merchant});
  final Merchant merchant;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(merchant.name), actions: [
          IconButton(
              tooltip: 'Agregar a favoritos',
              icon: const Icon(Icons.favorite_border),
              onPressed: () async {
                await ref
                    .read(customerRepositoryProvider)
                    .addMerchantFavorite(merchant.id);
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Comercio agregado a favoritos')));
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
