import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/courier_repository.dart';
import '../tracking/presentation/courier_tracking_controller.dart';
import 'courier_pages.dart' show courierRepositoryProvider;

typedef ExternalLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

List<Uri> courierNavigationUris(double latitude, double longitude) => [
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        Uri.parse(
            'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving')
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
  ConsumerState<CourierRouteSection> createState() =>
      _CourierRouteSectionState();
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
        return CourierOrderCard(
          route: route,
          currentLatitude: current?.latitude,
          currentLongitude: current?.longitude,
        );
      },
    );
  }
}

class CourierOrderCard extends StatefulWidget {
  const CourierOrderCard({
    super.key,
    required this.route,
    this.currentLatitude,
    this.currentLongitude,
    this.navigationLauncher = openCourierNavigation,
  });

  final CourierDeliveryRoute route;
  final double? currentLatitude;
  final double? currentLongitude;
  final Future<String?> Function(double latitude, double longitude)
      navigationLauncher;

  @override
  State<CourierOrderCard> createState() => _CourierOrderCardState();
}

class _CourierOrderCardState extends State<CourierOrderCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final destination = route.hasDestination
        ? (route.destinationLatitude!, route.destinationLongitude!)
        : null;
    final current =
        widget.currentLatitude != null && widget.currentLongitude != null
            ? LatLng(widget.currentLatitude!, widget.currentLongitude!)
            : null;
    final remainingKm = current == null || destination == null
        ? route.distanceKm
        : const Distance().as(
            LengthUnit.Kilometer,
            current,
            LatLng(destination.$1, destination.$2),
          );
    final remainingEta = _remainingEta(route, remainingKm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _OrderHeader(
                orderNumber: route.orderNumber,
                expanded: expanded,
                onToggle: () => setState(() => expanded = !expanded),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeIn,
                sizeCurve: Curves.easeInOut,
                crossFadeState: expanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    _SummaryContent(
                      route: route,
                      distanceKm: remainingKm,
                      etaMinutes: remainingEta,
                    ),
                    _CustomerDetails(route: route),
                  ],
                ),
                secondChild: const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
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
              final provider = await widget.navigationLauncher(
                destination.$1,
                destination.$2,
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

  int? _remainingEta(CourierDeliveryRoute route, double? distance) {
    final baseDistance = route.distanceKm;
    final baseEta = route.etaMinutes;
    if (distance == null ||
        baseDistance == null ||
        baseDistance <= 0 ||
        baseEta == null) {
      return baseEta;
    }
    return math.max(1, (baseEta * distance / baseDistance).round());
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.orderNumber,
    required this.expanded,
    required this.onToggle,
  });

  final String orderNumber;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF06163A),
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            child: Row(
              children: [
                const Text(
                  'Pedido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    orderNumber.trim().isEmpty ? 'Sin número' : orderNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Contraer pedido' : 'Expandir pedido',
                  onPressed: onToggle,
                  color: Colors.white,
                  icon: AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.route,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final CourierDeliveryRoute route;
  final double? distanceKm;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF06163A),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: _SummaryValue(
                      label: 'Cliente',
                      value: route.customerName ?? 'Cliente')),
              Expanded(
                  child: _SummaryValue(
                      label: 'Distancia',
                      value: distanceKm == null
                          ? '--'
                          : '${distanceKm!.toStringAsFixed(1)} km')),
              Expanded(
                  child: _SummaryValue(
                      label: 'ETA',
                      value: etaMinutes == null ? '--' : '$etaMinutes min')),
            ]),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF33466B), height: 1),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_outlined,
                  color: Colors.white, size: 21),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      route.destinationAddress ?? 'Destino por confirmar',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
            ]),
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
          Text(label,
              style: const TextStyle(color: Color(0xFFAFC0DE), fontSize: 12)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      );
}

class _CustomerDetails extends StatelessWidget {
  const _CustomerDetails({required this.route});
  final CourierDeliveryRoute route;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(children: [
            _InfoRow(
                icon: Icons.person_outline,
                label: 'Cliente',
                value: route.customerName),
            _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Dirección',
                value: route.destinationAddress),
            _InfoRow(
                icon: Icons.info_outline,
                label: 'Referencia',
                value: route.destinationReference),
            _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                value: route.customerPhone),
          ]),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: const Color(0xFF06163A)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value?.trim().isNotEmpty == true
                    ? value!
                    : 'No especificado'),
              ])),
        ]),
      );
}
