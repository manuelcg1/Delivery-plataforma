import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/orders/presentation/commerce_pages.dart';
import 'theme/app_theme.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery',
      theme: AppTheme.light(),
      home: session.when(
        data: (user) => user == null ? const AuthPage() : const MainShell(),
        loading: () => const SplashPage(),
        error: (_, __) => const AuthPage(),
      ),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delivery_dining, size: 72, color: Color(0xFF2563EB)),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final pages = const [
    HomePage(),
    SearchPage(),
    OrdersPage(),
    FavoritesPage(),
    ProfilePage(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: IndexedStack(index: index, children: pages),
        ),
        floatingActionButton: index == 0
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const CartPage()),
                ),
                child: const Icon(Icons.shopping_cart_outlined),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              label: 'Favoritos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      );
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Buscar', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          SearchBar(
            hintText: 'Comercios y productos',
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: ref.read(customerRepositoryProvider).merchants(query),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Column(
                children: snapshot.data!
                    .map(
                      (merchant) => Card(
                        child: ListTile(
                          title: Text(merchant.name),
                          subtitle: Text(merchant.description),
                          onTap: () => Navigator.push(
                            context,
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
          ),
        ],
      );
}

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
        future: ref.read(customerRepositoryProvider).favorites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data ?? [];
          if (items.isEmpty)
            return const Center(
                child:
                    Text('Guarda aquí tus comercios y productos favoritos.'));
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('Favoritos',
                style: Theme.of(context).textTheme.headlineMedium),
            ...items.map((item) => Card(
                child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text(item.name),
                    subtitle: Text(item.description),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await ref
                              .read(customerRepositoryProvider)
                              .removeFavorite(item.id);
                          (context as Element).markNeedsBuild();
                        }))))
          ]);
        },
      );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.firstName ?? ''),
            subtitle: Text('Tenant: ${user?.tenantCode ?? ''}'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Mis direcciones'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const AddressDialog(),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const NotificationsPage())),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: FutureBuilder(
          future: ref.read(commerceRepositoryProvider).notifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            final items = snapshot.data ?? [];
            if (items.isEmpty)
              return const Center(child: Text('No tienes notificaciones.'));
            return ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map((item) => Card(
                        child: ListTile(
                            leading:
                                const Icon(Icons.notifications_active_outlined),
                            title: Text(item.title),
                            subtitle: Text(item.body))))
                    .toList());
          }));
}
