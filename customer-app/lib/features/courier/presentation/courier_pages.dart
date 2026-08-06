import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/courier_repository.dart';
import '../notifications/courier_notification_service.dart';
import '../tracking/domain/tracking_policy.dart';
import '../tracking/presentation/courier_tracking_controller.dart';

final courierRepositoryProvider = Provider(
  (ref) => CourierRepository(ref.watch(apiClientProvider)),
);
final courierDataRevisionProvider = StateProvider<int>((ref) => 0);

class CourierShell extends ConsumerStatefulWidget {
  const CourierShell({super.key});

  @override
  ConsumerState<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends ConsumerState<CourierShell> {
  int index = 0;
  StreamSubscription<RealtimeEvent>? realtimeSubscription;
  CourierNotificationService? notificationService;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final user = ref.read(authControllerProvider).value;
      if (user == null) return;
      final realtime = ref.read(realtimeClientProvider);
      notificationService = CourierNotificationService(
          ref.read(apiClientProvider), ref.read(courierRepositoryProvider),
          onOpenDelivery: (id) async {
        final delivery = await ref.read(courierRepositoryProvider).delivery(id);
        if (mounted)
          await Navigator.of(context).push<void>(MaterialPageRoute(
              builder: (_) => CourierDeliveryPage(delivery: delivery)));
      });
      await notificationService!.initialize();
      realtimeSubscription = realtime.events.listen((event) {
        if (!mounted) return;
        ref.read(courierDataRevisionProvider.notifier).state++;
        notificationService?.receiveRealtime(event);
      });
      await realtime.connectAudience(
        tenantId: user.tenantId,
        audience: 'courier/${user.id}',
      );
    });
  }

  @override
  void dispose() {
    realtimeSubscription?.cancel();
    notificationService?.dispose();
    ref.read(realtimeClientProvider).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(courierDataRevisionProvider);
    final pages = [
      CourierDeliveriesPage(key: ValueKey('deliveries-$revision')),
      CourierNotificationsPage(key: ValueKey('notifications-$revision')),
      const CourierProfilePage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Entregas',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Avisos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class CourierDeliveriesPage extends ConsumerStatefulWidget {
  const CourierDeliveriesPage({super.key});

  @override
  ConsumerState<CourierDeliveriesPage> createState() =>
      _CourierDeliveriesPageState();
}

class _CourierDeliveriesPageState extends ConsumerState<CourierDeliveriesPage> {
  late Future<(CourierProfile, List<CourierDelivery>)> future;
  StreamSubscription<RealtimeEvent>? assignmentSubscription;
  Timer? fallbackRefresh;

  @override
  void initState() {
    super.initState();
    future = load();
    Future.microtask(() {
      assignmentSubscription = ref.read(realtimeClientProvider).events.listen(
        (event) {
          if (mounted &&
              const {'COURIER_ASSIGNMENT_PENDING', 'CourierAssigned'}
                  .contains(event.type)) {
            refresh();
          }
        },
      );
    });
    fallbackRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    assignmentSubscription?.cancel();
    fallbackRefresh?.cancel();
    super.dispose();
  }

  Future<(CourierProfile, List<CourierDelivery>)> load() async {
    final repository = ref.read(courierRepositoryProvider);
    final profile = await repository.profile();
    final deliveries = await repository.deliveries();
    Future.microtask(() => ref
        .read(courierTrackingControllerProvider.notifier)
        .restoreFromBackend(deliveries));
    return (profile, deliveries);
  }

  void refresh() {
    if (!mounted) return;
    final nextLoad = load();
    setState(() {
      future = nextLoad;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CourierError(
              message: ref
                  .read(apiClientProvider)
                  .exception(snapshot.error!)
                  .message,
              onRetry: refresh,
            );
          }
          final (profile, deliveries) = snapshot.data!;
          final active = deliveries
              .where((item) => !const {
                    'DELIVERED',
                    'FAILED',
                    'CANCELLED',
                    'REJECTED',
                    'EXPIRED',
                  }.contains(item.status))
              .toList();
          final delivered =
              deliveries.where((item) => item.status == 'DELIVERED').toList();
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Hola, ${profile.name}',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                    '${profile.activeDeliveries}/${profile.maxActiveDeliveries} entregas activas'),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Disponibilidad')),
                        DropdownButton<String>(
                          value: profile.status,
                          items: const [
                            DropdownMenuItem(
                                value: 'ONLINE', child: Text('En línea')),
                            DropdownMenuItem(
                                value: 'PAUSED', child: Text('En pausa')),
                            DropdownMenuItem(
                                value: 'OFFLINE', child: Text('Desconectado')),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            await ref
                                .read(courierRepositoryProvider)
                                .updateAvailability(value);
                            refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Mis entregas',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('No tienes entregas asignadas.')),
                  ),
                ...active.map(
                  (delivery) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.local_shipping_outlined)),
                      title: Text('Pedido ${delivery.orderId.substring(0, 8)}'),
                      subtitle: Text(_statusLabel(delivery.status)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CourierDeliveryPage(delivery: delivery),
                          ),
                        );
                        refresh();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Entregados',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (delivered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('Aún no tienes pedidos entregados.')),
                  ),
                ...delivered.map((delivery) => Card(
                      color: const Color(0xFFE8F8EF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFF86D5A8)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF169B62),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.check_rounded),
                        ),
                        title:
                            Text('Pedido ${delivery.orderId.substring(0, 8)}'),
                        subtitle: _DeliveredAt(deliveryId: delivery.id),
                        trailing: const Icon(Icons.chevron_right,
                            color: Color(0xFF087A49)),
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CourierDeliveryPage(delivery: delivery),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          );
        },
      );
}

class CourierDeliveryPage extends ConsumerStatefulWidget {
  const CourierDeliveryPage({super.key, required this.delivery});
  final CourierDelivery delivery;

  @override
  ConsumerState<CourierDeliveryPage> createState() =>
      _CourierDeliveryPageState();
}

class _CourierDeliveryPageState extends ConsumerState<CourierDeliveryPage> {
  late CourierDelivery delivery = widget.delivery;
  late Future<List<CourierDeliveryHistory>> history;
  bool busy = false;

  static const nextStatus = <String, String>{
    'ASSIGNED': 'ACCEPTED',
    'ACCEPTED': 'PICKED_UP',
    'PICKED_UP': 'IN_TRANSIT',
    'IN_TRANSIT': 'DELIVERED',
  };

  @override
  void initState() {
    super.initState();
    history = ref.read(courierRepositoryProvider).history(delivery.id);
  }

  void refreshHistory() =>
      history = ref.read(courierRepositoryProvider).history(delivery.id);

  Future<void> advance() async {
    final next = nextStatus[delivery.status];
    if (next == null) return;
    setState(() => busy = true);
    try {
      final tracking = ref.read(courierTrackingControllerProvider.notifier);
      if (shouldStartTracking(next)) {
        final started = await tracking.startTracking(
          deliveryId: delivery.id,
          status: next,
        );
        if (!started) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                'Activa la ubicación para iniciar la entrega.',
              ),
            ));
          }
          return;
        }
      }
      if (next == 'DELIVERED') {
        await tracking.sendFinalLocation();
      }
      delivery = await ref
          .read(courierRepositoryProvider)
          .updateDelivery(delivery.id, next);
      if (!isCourierNoticeActive(delivery.status)) {
        await CourierNotificationService.cancelLocal(delivery.id);
        ref.read(courierDataRevisionProvider.notifier).state++;
      }
      await tracking.synchronizeDelivery(delivery);
      refreshHistory();
      if (next == 'DELIVERED' && mounted) {
        Navigator.pop(context);
        return;
      }
    } catch (error) {
      if (mounted) {
        final message = ref.read(apiClientProvider).exception(error).message;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      if (shouldStartTracking(next)) {
        await ref
            .read(courierTrackingControllerProvider.notifier)
            .stopTracking();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> respond(String status) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      delivery = await ref
          .read(courierRepositoryProvider)
          .updateDelivery(delivery.id, status);
      await CourierNotificationService.cancelLocal(delivery.id);
      if (!isCourierNoticeActive(delivery.status)) {
        ref.read(courierDataRevisionProvider.notifier).state++;
      }
      refreshHistory();
      if (mounted && status == 'REJECTED') Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        final message = ref.read(apiClientProvider).exception(error).message;
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> markArrived() async {
    setState(() => busy=true);
    try {
      final notified=await ref.read(courierRepositoryProvider).markArrived(delivery.orderId);
      delivery=await ref.read(courierRepositoryProvider).delivery(delivery.id);
      refreshHistory();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        notified?'Llegada registrada. El cliente fue notificado.':'La llegada ya había sido registrada.')));
    } catch(error) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(apiClientProvider).exception(error).message)));
    } finally { if(mounted) setState(()=>busy=false); }
  }

  @override
  Widget build(BuildContext context) {
    final next = nextStatus[delivery.status];
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de entrega')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Pedido ${delivery.orderId.substring(0, 8)}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Chip(label: Text(_statusLabel(delivery.status))),
          if (shouldContinueTracking(delivery.status)) ...[
            const SizedBox(height: 12),
            const _TrackingStatusCard(),
          ],
          const SizedBox(height: 20),
          Text('Línea de tiempo',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<CourierDeliveryHistory>>(
            future: history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final events = (snapshot.data ?? const <CourierDeliveryHistory>[])
                  .where((event) => const {
                        'ACCEPTED',
                        'PICKED_UP',
                        'IN_TRANSIT',
                        'DELIVERED',
                      }.contains(event.status));
              return Column(
                children: events
                    .map((event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(0xFFDCFCE7),
                            child: Icon(Icons.check,
                                size: 17, color: Color(0xFF15803D)),
                          ),
                          title: Text(_statusLabel(event.status)),
                          subtitle: Text(_dateTime(event.createdAt)),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          if (delivery.pickupNotes?.isNotEmpty == true)
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Indicaciones de recojo'),
              subtitle: Text(delivery.pickupNotes!),
            ),
          if (delivery.deliveryNotes?.isNotEmpty == true)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Indicaciones de entrega'),
              subtitle: Text(delivery.deliveryNotes!),
            ),
          if (delivery.status == 'ASSIGNED') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: busy ? null : () => respond('REJECTED'),
                        icon: const Icon(Icons.close),
                        label: const Text('Rechazar'))),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: busy ? null : () => respond('ACCEPTED'),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(busy ? 'Procesando…' : 'Aceptar'))),
              ],
            ),
          ] else if (next != null) ...[
            const SizedBox(height: 24),
            if (const {'PICKED_UP','IN_TRANSIT'}.contains(delivery.status)) ...[
              OutlinedButton.icon(
                onPressed: busy ? null : markArrived,
                icon: const Icon(Icons.location_on),
                label: const Text('He llegado'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: busy ? null : advance,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                  busy ? 'Actualizando…' : 'Marcar: ${_statusLabel(next)}'),
            ),
          ],
        ],
      ),
    );
  }
}

class CourierNotificationsPage extends ConsumerStatefulWidget {
  const CourierNotificationsPage({super.key});

  @override
  ConsumerState<CourierNotificationsPage> createState() =>
      _CourierNotificationsPageState();
}

class _TrackingStatusCard extends ConsumerWidget {
  const _TrackingStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courierTrackingControllerProvider);
    final (icon, color, title, detail, retry) = switch (state) {
      TrackingActive(:final lastSentAt, :final sending) => (
          Icons.gps_fixed,
          Colors.green,
          sending ? 'Enviando ubicación' : 'Ubicación compartida',
          lastSentAt == null
              ? 'GPS activo'
              : 'Actualizada ${_relativeTime(lastSentAt)}',
          false,
        ),
      TrackingOffline() => (
          Icons.cloud_off,
          Colors.orange,
          'Sin conexión',
          'Se enviará al reconectar',
          true,
        ),
      TrackingGpsDisabled() => (
          Icons.location_disabled,
          Colors.red,
          'GPS desactivado',
          'Activa la ubicación para continuar',
          true,
        ),
      TrackingPermissionDenied(:final permanently) => (
          Icons.location_off,
          Colors.red,
          'Permiso requerido',
          permanently
              ? 'El permiso fue bloqueado. Actívalo desde Configuración.'
              : 'Cerka necesita acceso a tu ubicación durante la entrega.',
          true,
        ),
      TrackingError(:final message) => (
          Icons.error_outline,
          Colors.red,
          'Error de ubicación',
          message,
          true,
        ),
      TrackingStarting() || TrackingRequestingPermission() => (
          Icons.gps_not_fixed,
          Colors.blue,
          'Iniciando GPS',
          'Comprobando ubicación…',
          false,
        ),
      _ => (
          Icons.location_off,
          Colors.grey,
          'Seguimiento detenido',
          'La ubicación no se está compartiendo',
          true,
        ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(detail),
                ],
              ),
            ),
            if (retry)
              TextButton(
                onPressed: () => ref
                    .read(courierTrackingControllerProvider.notifier)
                    .resumeTracking(),
                child: const Text('Reintentar ubicación'),
              ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime value) {
  final seconds = DateTime.now().difference(value).inSeconds.clamp(0, 9999);
  if (seconds < 60) return 'hace $seconds segundos';
  return 'hace ${seconds ~/ 60} min';
}

class _CourierNotificationsPageState
    extends ConsumerState<CourierNotificationsPage> {
  late Future<List<CourierNotification>> future;
  Timer? fallbackRefresh;

  @override
  void initState() {
    super.initState();
    future = ref.read(courierRepositoryProvider).notifications();
    fallbackRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) reload();
    });
  }

  void reload() {
    final next=ref.read(courierRepositoryProvider).notifications();
    setState(() { future=next; });
  }

  Future<void> refresh() async {
    reload();
    await future;
  }

  @override
  void dispose() {
    fallbackRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<CourierNotification>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final message = ref
                  .read(apiClientProvider)
                  .exception(snapshot.error!)
                  .message;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Notificaciones',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  _CourierError(
                      message: message,
                      onRetry: reload),
                ],
              );
            }
            final items = snapshot.data ?? const <CourierNotification>[];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Notificaciones',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const LinearProgressIndicator(),
                if (snapshot.connectionState == ConnectionState.done &&
                    items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('No tienes notificaciones.')),
                  ),
                ...items.map((item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: Text(item.title),
                        subtitle: Text(item.body),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          try {
                            final delivery = await ref
                                .read(courierRepositoryProvider)
                                .delivery(item.deliveryId);
                            if (!context.mounted) return;
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CourierDeliveryPage(delivery: delivery),
                              ),
                            );
                            if (mounted) reload();
                          } catch (error) {
                            if (!context.mounted) return;
                            final message = ref
                                .read(apiClientProvider)
                                .exception(error)
                                .message;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          }
                        },
                      ),
                    )),
              ],
            );
          },
        ),
      );
}

class CourierProfilePage extends ConsumerWidget {
  const CourierProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Perfil del repartidor',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
            title: Text(user?.firstName ?? ''),
            subtitle: Text('Empresa: ${user?.tenantCode ?? ''}'),
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

class _DeliveredAt extends ConsumerWidget {
  const _DeliveredAt({required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<List<CourierDeliveryHistory>>(
        future: ref.read(courierRepositoryProvider).history(deliveryId),
        builder: (context, snapshot) {
          final delivered = snapshot.data
              ?.where((event) => event.status == 'DELIVERED')
              .lastOrNull;
          return Text(delivered == null
              ? 'Entregado'
              : 'Entregado · ${_dateTime(delivered.createdAt)}');
        },
      );
}

class _CourierError extends StatelessWidget {
  const _CourierError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}

String _statusLabel(String status) =>
    const {
      'ASSIGNED': 'Asignada',
      'ACCEPTED': 'Aceptada',
      'ARRIVED_AT_MERCHANT': 'Llegué al comercio',
      'PICKED_UP': 'Pedido recogido',
      'IN_TRANSIT': 'En camino',
      'ARRIVED_AT_CUSTOMER': 'Llegué al destino',
      'DELIVERED': 'Entregada',
      'FAILED': 'Fallida',
      'CANCELLED': 'Cancelada',
      'REJECTED': 'Rechazada',
    }[status] ??
    status;

String _dateTime(String value) =>
    DateFormat('dd/MM/yyyy · HH:mm').format(DateTime.parse(value).toLocal());
