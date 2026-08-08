import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/maps/encoded_polyline.dart';
import '../../../core/providers.dart';
import '../data/courier_repository.dart';
import '../tracking/presentation/courier_tracking_controller.dart';
import '../tracking/domain/courier_location_update.dart';
import 'courier_pages.dart' show courierRepositoryProvider;

typedef ExternalLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

List<Uri> courierNavigationUris(double latitude, double longitude) => [
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        Uri.parse('comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving')
      else
        Uri.parse('google.navigation:q=$latitude,$longitude&mode=d'),
      Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes'),
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
        'travelmode': 'driving',
      }),
    ];

Future<String?> openCourierNavigation(
  double latitude,
  double longitude, {
  ExternalLauncher launcher = _launchExternal,
}) async {
  const providers = ['Google Maps', 'Waze', 'Google Maps Web'];
  final uris = courierNavigationUris(latitude, longitude);
  for (var index = 0; index < uris.length; index++) {
    try {
      if (await launcher(uris[index])) return providers[index];
    } catch (_) {
      // Continue with the next installed provider.
    }
  }
  return null;
}

class CourierRouteSection extends ConsumerStatefulWidget {
  const CourierRouteSection({
    super.key,
    required this.deliveryId,
    required this.deliveryStatus,
  });

  final String deliveryId;
  final String deliveryStatus;

  @override
  ConsumerState<CourierRouteSection> createState() => _CourierRouteSectionState();
}

class _CourierRouteSectionState extends ConsumerState<CourierRouteSection> {
  late Future<CourierDeliveryRoute> _route;

  @override
  void initState() {
    super.initState();
    _route = _loadRoute();
  }

  Future<CourierDeliveryRoute> _loadRoute() async {
    final repository = ref.read(courierRepositoryProvider);
    final first = await repository.route(widget.deliveryId);
    if (widget.deliveryStatus != 'PICKED_UP' ||
        first.routePolyline?.isNotEmpty == true) return first;
    await Future<void>.delayed(const Duration(seconds: 2));
    return repository.route(widget.deliveryId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CourierDeliveryRoute>(
      future: _route,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.map_outlined),
              title: Text('Ruta de entrega no disponible'),
              subtitle: Text('La entrega puede continuar normalmente.'),
            ),
          );
        }
        final route = snapshot.data!;
        final tracking = ref.watch(courierTrackingControllerProvider);
        final current = tracking is TrackingActive ? tracking.location : null;
        return _RouteContent(
          route: route,
          current: current,
          tileUrl: ref.watch(configProvider).mapTileUrl,
        );
      },
    );
  }
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({required this.route, required this.current, required this.tileUrl});

  final CourierDeliveryRoute route;
  final CourierLocationUpdate? current;
  final String tileUrl;

  @override
  Widget build(BuildContext context) {
    final destination = route.hasDestination
        ? LatLng(route.destinationLatitude!, route.destinationLongitude!)
        : null;
    final currentPoint = current == null
        ? null
        : LatLng(current!.latitude, current!.longitude);
    final remainingKm = currentPoint == null || destination == null
        ? route.distanceKm
        : const Distance().as(LengthUnit.Kilometer, currentPoint, destination);
    final remainingEta = _remainingEta(remainingKm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(route: route, distanceKm: remainingKm, eta: remainingEta),
        const SizedBox(height: 12),
        SizedBox(height: 320, child: _CourierRouteMap(
          route: route,
          current: currentPoint,
          tileUrl: tileUrl,
        )),
        const SizedBox(height: 12),
        _DestinationCard(route: route),
        if (destination != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7C00),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final provider = await openCourierNavigation(
                destination.latitude,
                destination.longitude,
              );
              if (provider == null && context.mounted) {
                messenger.showSnackBar(const SnackBar(
                  content: Text('No se pudo abrir una aplicación de mapas.'),
                ));
              }
            },
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('Ir al destino'),
          ),
        ],
      ],
    );
  }

  int? _remainingEta(double? distance) {
    final baseDistance = route.distanceKm;
    final baseEta = route.etaMinutes;
    if (distance == null || baseDistance == null || baseDistance <= 0 || baseEta == null) {
      return baseEta;
    }
    return math.max(1, (baseEta * distance / baseDistance).round());
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.route, required this.distanceKm, required this.eta});
  final CourierDeliveryRoute route;
  final double? distanceKm;
  final int? eta;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF06163A),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pedido ${route.orderNumber}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _SummaryValue(label: 'Cliente', value: route.customerName ?? 'Cliente')),
              Expanded(child: _SummaryValue(label: 'Distancia', value: distanceKm == null ? '--' : '${distanceKm!.toStringAsFixed(1)} km')),
              Expanded(child: _SummaryValue(label: 'ETA', value: eta == null ? '--' : '$eta min')),
            ]),
            const SizedBox(height: 10),
            Text(route.destinationAddress ?? 'Destino por confirmar',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFDDE6F8))),
          ]),
        ),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFAFC0DE), fontSize: 12)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      );
}

class _CourierRouteMap extends StatelessWidget {
  const _CourierRouteMap({required this.route, required this.current, required this.tileUrl});
  final CourierDeliveryRoute route;
  final LatLng? current;
  final String tileUrl;

  @override
  Widget build(BuildContext context) {
    final origin = route.hasOrigin ? LatLng(route.originLatitude!, route.originLongitude!) : null;
    final destination = route.hasDestination ? LatLng(route.destinationLatitude!, route.destinationLongitude!) : null;
    final encoded = route.routePolyline;
    final points = encoded == null || encoded.isEmpty
        ? const <LatLng>[]
        : decodePolyline(encoded).map((p) => LatLng(p.latitude, p.longitude)).toList(growable: false);
    final center = current ?? origin ?? destination;
    if (center == null) {
      return const Card(child: Center(child: Text('Coordenadas no disponibles')));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: points.isEmpty ? 15 : 13),
        children: [
          TileLayer(
            urlTemplate: tileUrl,
            userAgentPackageName: 'com.delivery.platform.customer',
          ),
          if (points.length >= 2)
            PolylineLayer(polylines: [
              Polyline(points: points, strokeWidth: 5, color: const Color(0xFFFF7C00)),
            ]),
          MarkerLayer(markers: [
            if (origin != null) Marker(point: origin, width: 46, height: 46,
                child: const _MapMarker(icon: Icons.store, color: Color(0xFF06163A))),
            if (destination != null) Marker(point: destination, width: 46, height: 46,
                child: const _MapMarker(icon: Icons.home, color: Color(0xFFFF7C00))),
            if (current != null) Marker(point: current!, width: 50, height: 50,
                child: const _MapMarker(icon: Icons.delivery_dining, color: Color(0xFF2563EB))),
          ]),
          RichAttributionWidget(attributions: const [TextSourceAttribution('OpenStreetMap contributors')]),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(blurRadius: 7, color: Colors.black26)]),
        child: Icon(icon, color: Colors.white, size: 25),
      );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.route});
  final CourierDeliveryRoute route;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _InfoRow(icon: Icons.person_outline, label: 'Cliente', value: route.customerName),
            _InfoRow(icon: Icons.location_on_outlined, label: 'Dirección', value: route.destinationAddress),
            _InfoRow(icon: Icons.info_outline, label: 'Referencia', value: route.destinationReference),
            _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: route.customerPhone),
          ]),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: const Color(0xFF06163A)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value?.trim().isNotEmpty == true ? value! : 'No especificado'),
          ])),
        ]),
      );
}
