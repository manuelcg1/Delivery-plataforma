import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers.dart';
import '../core/widgets/app_states.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/courier/presentation/courier_pages.dart';
import '../features/customer_tracking/notifications/customer_arrival_notification_service.dart';
import '../features/customer_tracking/notifications/arrival_notification_provider.dart';
import '../features/customer_tracking/notifications/arrival_notice_coordinator.dart';
import '../features/customer_tracking/presentation/customer_order_tracking_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/orders/presentation/commerce_pages.dart';
import 'theme/app_theme.dart';
import '../core/lifecycle/app_lifecycle_coordinator.dart';
import '../core/widgets/cart_feedback.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final connection = ref.watch(appConnectionStatusProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.value == null && next.value != null) {
        ref.read(appLifecycleCoordinatorProvider).recover();
      }
    });
    return AppLifecycleCoordinatorHost(
        child: MaterialApp(
      scaffoldMessengerKey: cartFeedbackMessengerKey,
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
      builder: (context, child) => Column(children: [
        if (session.value != null &&
            connection != AppConnectionStatus.online &&
            connection != AppConnectionStatus.checking)
          _ConnectionBanner(status: connection),
        Expanded(child: child ?? const SizedBox.shrink()),
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
  CustomerArrivalNotificationService? notifications;
  ArrivalNoticeCoordinator? arrivalNotices;
  String? _openingOrder;
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
      if (!mounted) return;
      final api = ref.read(apiClientProvider);
      final coordinator = ref.read(arrivalNoticeCoordinatorProvider);
      arrivalNotices = coordinator;
      coordinator.onNotice = (orderId) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(arrivalSnackBar(
          onOpen: () => unawaited(_openOrder(orderId)),
        ));
      };
      notifications = CustomerArrivalNotificationService(api, coordinator,
          onOpenOrder: _openOrder);
      await notifications!.initialize();
    });
  }

  Future<void> _openOrder(String orderId) async {
    if (!mounted || _openingOrder == orderId) return;
    _openingOrder = orderId;
    try {
      final order = await ref.read(commerceRepositoryProvider).order(orderId);
      if (!mounted) return;
      ref.read(customerMainTabProvider.notifier).state = 2;
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: order),
      ));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo abrir el pedido. Intenta nuevamente.')));
    } finally {
      if (_openingOrder == orderId) _openingOrder = null;
    }
  }

  @override
  void dispose() {
    arrivalNotices?.onNotice = null;
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
  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      AppConnectionStatus.checking => 'Comprobando conexión…',
      AppConnectionStatus.offline => 'Sin conexión a Internet.',
      AppConnectionStatus.backendUnavailable =>
        'No pudimos conectar con Cerka. Intenta nuevamente.',
      AppConnectionStatus.sessionExpired =>
        'Tu sesión expiró. Inicia sesión nuevamente.',
      AppConnectionStatus.realtimeDisconnected => 'Reconectando seguimiento…',
      AppConnectionStatus.online => '',
    };
    return Material(
        color: const Color(0xFFFFF3CD),
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(message, textAlign: TextAlign.center))));
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
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF4F4F4),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const Text(
              'Buscar',
              style: TextStyle(
                color: Color(0xFF0F1E3A),
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            SearchBar(
              hintText: 'Comercios y productos',
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
              leading: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.search_rounded,
                  color: Color(0xFFFF5A5A),
                  size: 23,
                ),
              ),
              backgroundColor: const WidgetStatePropertyAll(
                Colors.white,
              ),
              elevation: const WidgetStatePropertyAll(0),
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
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 22),
            FutureBuilder(
              future: ref.read(customerRepositoryProvider).merchants(query),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(
                      color: Color(0xFFFF5A5A),
                      backgroundColor: Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.all(
                        Radius.circular(20),
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!
                      .map(
                        (merchant) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MerchantPreviewCard(
                            merchant: merchant,
                            showDescription: true,
                            animateLogo: false,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MerchantPage(merchant: merchant))),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
}

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ColoredBox(
        color: const Color(0xFFF4F4F4),
        child: ref.watch(favoritesProvider).when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5A5A),
                ),
              ),
              error: (error, _) => ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(favoritesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE5E5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_border_rounded,
                              color: Color(0xFFFF5A5A),
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Aún no tienes favoritos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF0F1E3A),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Guarda aquí tus comercios y productos favoritos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF647185),
                              fontSize: 14,
                              height: 1.4,
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
                    24,
                    20,
                    32,
                  ),
                  children: [
                    const Text(
                      'Favoritos',
                      style: TextStyle(
                        color: Color(0xFF0F1E3A),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tus comercios y productos guardados',
                      style: TextStyle(
                        color: Color(0xFF647185),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Icono favorito
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE5E5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFFFF5A5A),
                                  size: 24,
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Información
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF0F1E3A),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF647185),
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Eliminar
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  tooltip: 'Eliminar favorito',
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFFF5A5A),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(
                                          customerRepositoryProvider,
                                        )
                                        .removeFavorite(item.id);

                                    ref.invalidate(
                                      favoritesProvider,
                                    );
                                  },
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
      );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    final firstName = user?.firstName ?? '';

    final initial =
        firstName.isNotEmpty ? firstName.substring(0, 1).toUpperCase() : 'C';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mi perfil',
            style: TextStyle(
              color: Color(0xFF0F1E3A),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5A5A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFFFE5E5),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF647185),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty ? firstName : 'Cliente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'CLIENTE',
                              style: TextStyle(
                                color: Color(0xFFFF5A5A),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFFF5A5A),
                              side: const BorderSide(
                                color: Color(0xFFFF5A5A),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Editar perfil',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mi cuenta',
            style: TextStyle(
              color: Color(0xFF0F1E3A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFFF5A5A),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Mis direcciones',
                    style: TextStyle(
                      color: Color(0xFF0F1E3A),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF647185),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AddressesPage(),
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 62,
                  color: Color(0xFFE3E8F0),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFFF5A5A),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: Color(0xFF0F1E3A),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF647185),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Color(0xFFFF5A5A),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
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
