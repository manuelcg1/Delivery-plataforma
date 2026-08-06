import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../domain/tracking_location.dart';
import 'customer_tracking_controller.dart';

class CustomerOrderTrackingPage extends ConsumerStatefulWidget {
  const CustomerOrderTrackingPage({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });
  final String orderId;
  final String orderNumber;

  @override
  ConsumerState<CustomerOrderTrackingPage> createState() =>
      _CustomerOrderTrackingPageState();
}

class _CustomerOrderTrackingPageState
    extends ConsumerState<CustomerOrderTrackingPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  TrackingLocation? _displayed;
  TrackingLocation? _previous;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(
              customerOrderTrackingControllerProvider(widget.orderId).notifier)
          .refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CustomerTrackingState>(
      customerOrderTrackingControllerProvider(widget.orderId),
      (previous,next) {
        if(next.arrivalNoticeId!=null && next.arrivalNoticeId!=previous?.arrivalNoticeId) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Tu repartidor llegó.'),
            action: SnackBarAction(label:'Ver pedido',onPressed:() {}),
          ));
        }
      },
    );
    final state =
        ref.watch(customerOrderTrackingControllerProvider(widget.orderId));
    final location = state.tracking?.location;
    if (location != null &&
        (_displayed == null ||
            location.gpsTimestamp.isAfter(_displayed!.gpsTimestamp))) {
      _previous = _displayed;
      _displayed = location;
    }
    return Scaffold(
      appBar: AppBar(title: Text('Pedido ${widget.orderNumber}')),
      body: state.loading && state.tracking == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _TrackingMap(
                    mapController: _mapController,
                    previous: _previous,
                    location: _displayed,
                    stale: state.stale,
                    tileUrl: ref.watch(configProvider).mapTileUrl,
                    onUserMoved: () {},
                  ),
                ),
                CustomerTrackingStatusPanel(
                  state: state,
                  onRetry: () => ref
                      .read(customerOrderTrackingControllerProvider(
                              widget.orderId)
                          .notifier)
                      .refresh(),
                ),
              ],
            ),
      floatingActionButton: _displayed == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                _mapController.move(
                  LatLng(_displayed!.latitude, _displayed!.longitude),
                  math.max(_mapController.camera.zoom, 16),
                );
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Centrar repartidor'),
            ),
    );
  }
}

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({
    required this.mapController,
    required this.previous,
    required this.location,
    required this.stale,
    required this.tileUrl,
    required this.onUserMoved,
  });
  final MapController mapController;
  final TrackingLocation? previous, location;
  final bool stale;
  final String tileUrl;
  final VoidCallback onUserMoved;

  @override
  Widget build(BuildContext context) {
    final target = location;
    if (target == null) {
      return const ColoredBox(
        color: Color(0xFFEFF6FF),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_searching,
                  size: 64, color: Color(0xFF2563EB)),
              SizedBox(height: 16),
              Text('El repartidor inició la entrega. Esperando ubicación…',
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    final from = previous;
    final distance = from == null
        ? 0.0
        : const Distance().as(
            LengthUnit.Meter,
            LatLng(from.latitude, from.longitude),
            LatLng(target.latitude, target.longitude),
          );
    final animate = from != null && !stale && distance < 5000;
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(target.latitude, target.longitude),
        initialZoom: 16,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture) onUserMoved();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: 'com.delivery.platform.customer',
        ),
        TweenAnimationBuilder<double>(
          key: ValueKey(target.gpsTimestamp),
          duration: animate ? const Duration(milliseconds: 800) : Duration.zero,
          tween: Tween(begin: 0, end: 1),
          builder: (_, value, __) {
            final latitude = animate
                ? from.latitude + (target.latitude - from.latitude) * value
                : target.latitude;
            final longitude = animate
                ? from.longitude + (target.longitude - from.longitude) * value
                : target.longitude;
            return MarkerLayer(markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 52,
                height: 52,
                child: Transform.rotate(
                  angle: (target.heading ?? 0) * math.pi / 180,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(blurRadius: 8, color: Colors.black26)
                      ],
                    ),
                    child: Icon(Icons.delivery_dining,
                        color: Colors.white, size: 30),
                  ),
                ),
              ),
            ]);
          },
        ),
        RichAttributionWidget(
          attributions: const [
            TextSourceAttribution('OpenStreetMap contributors')
          ],
        ),
      ],
    );
  }
}

class CustomerTrackingStatusPanel extends StatelessWidget {
  const CustomerTrackingStatusPanel({
    super.key,
    required this.state,
    required this.onRetry,
  });
  final CustomerTrackingState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tracking = state.tracking;
    final delivered = tracking?.deliveryStatus == 'DELIVERED';
    final arrived = tracking?.deliveryStatus == 'ARRIVED_AT_CUSTOMER';
    final (icon, color, title) = delivered
        ? (Icons.check_circle, Colors.green, 'Pedido entregado')
        : arrived
            ? (Icons.location_on, Colors.green, 'Tu repartidor llegó')
        : !state.trackingActive
            ? (
                Icons.stop_circle_outlined,
                Colors.grey,
                'El seguimiento ha finalizado'
              )
            : state.stale
                ? (Icons.schedule, Colors.orange, 'Ubicación desactualizada')
                : state.reconnecting
                    ? (Icons.sync, Colors.orange, 'Reconectando seguimiento…')
                    : (Icons.wifi, Colors.green, 'Ubicación en tiempo real');
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text('Estado: ${tracking?.deliveryStatus ?? 'Consultando'}'),
          Text(
              'Repartidor: ${tracking?.courier?.displayName ?? 'Por asignar'}'),
          if (tracking?.updatedAt != null)
            Text(
                'Última actualización: ${DateFormat.Hm().format(tracking!.updatedAt!.toLocal())}'),
          if (state.polling)
            const Text('Actualizando ubicación periódicamente',
                style: TextStyle(color: Colors.orange)),
          if (state.error != null) ...[
            Text(state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ]),
      ),
    );
  }
}
