import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers.dart';
import '../core/widgets/app_states.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/courier/presentation/courier_pages.dart';
import '../features/courier/notifications/courier_notification_service.dart';
import '../features/courier/data/courier_repository.dart';
import '../features/home/presentation/home_page.dart';
import '../features/orders/presentation/commerce_pages.dart';
import 'theme/app_theme.dart';
import '../core/lifecycle/app_lifecycle_coordinator.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final connection=ref.watch(appConnectionStatusProvider);
    ref.listen(authControllerProvider,(previous,next) {
      if(previous?.value==null && next.value!=null) {
        ref.read(appLifecycleCoordinatorProvider).recover();
      }
    });
    return AppLifecycleCoordinatorHost(child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery',
      theme: AppTheme.light(),
      home: session.when(
        data: (user) => user == null
            ? const AuthPage()
            : user.isCourier
                ? const CourierShell()
                : const MainShell(),
        loading: () => const SplashPage(),
        error: (_, __) => const AuthPage(),
      ),
      builder:(context,child)=>Column(children:[
        if(session.value!=null && connection!=AppConnectionStatus.online &&
            connection!=AppConnectionStatus.checking)
          _ConnectionBanner(status:connection),
        Expanded(child:child??const SizedBox.shrink()),
      ]),
    ));
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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  CourierNotificationService? notifications;
  final pages = const [
    HomePage(),
    SearchPage(),
    OrdersPage(),
    FavoritesPage(),
    ProfilePage(),
  ];
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final api=ref.read(apiClientProvider);
      notifications=CourierNotificationService(api,CourierRepository(api),
        onOpenDelivery: (_) async {
          if(mounted) ref.read(customerMainTabProvider.notifier).state=2;
        });
      await notifications!.initialize();
    });
  }

  @override
  void dispose() {
    notifications?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final index = ref.watch(customerMainTabProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFFF7C00),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const CartPage()),
              ),
              child: const Icon(Icons.shopping_cart_outlined),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 22,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFFFF4E8),
              elevation: 0,
              height: 76,
              iconTheme:
                  WidgetStateProperty.resolveWith((states) => IconThemeData(
                        color: states.contains(WidgetState.selected)
                            ? const Color(0xFFFF7C00)
                            : const Color(0xFF6B7280),
                        size: 27,
                      )),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => GoogleFonts.poppins(
                  color: states.contains(WidgetState.selected)
                      ? const Color(0xFFFF7C00)
                      : const Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) =>
                  ref.read(customerMainTabProvider.notifier).state = value,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                    icon: Icon(Icons.search_rounded), label: 'Buscar'),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Pedidos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: 'Favoritos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.status});
  final AppConnectionStatus status;
  @override Widget build(BuildContext context) {
    final message=switch(status) {
      AppConnectionStatus.checking=>'Comprobando conexión…',
      AppConnectionStatus.offline=>'Sin conexión a Internet.',
      AppConnectionStatus.backendUnavailable=>'No pudimos conectar con Cerka. Intenta nuevamente.',
      AppConnectionStatus.sessionExpired=>'Tu sesión expiró. Inicia sesión nuevamente.',
      AppConnectionStatus.realtimeDisconnected=>'Reconectando seguimiento…',
      AppConnectionStatus.online=>'',
    };
    return Material(color:const Color(0xFFFFF3CD),child:SafeArea(bottom:false,child:
      Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),child:Text(message,textAlign:TextAlign.center))));
  }
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
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(favoritesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (items) {
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
                          ref.invalidate(favoritesProvider);
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AddressesPage()),
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
