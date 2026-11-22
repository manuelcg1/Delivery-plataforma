import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../chat/presentation/delivery_chat_page.dart'
    show ChatButtonWithBadge;
import '../../orders/presentation/order_products.dart';
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

/// Abre el marcador del teléfono con el número del cliente.
Future<bool> callCustomer(String phone,
    {ExternalLauncher launcher = _launchExternal}) {
  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return Future.value(false);
  return launcher(Uri(scheme: 'tel', path: digits));
}

class CourierRouteSection extends ConsumerStatefulWidget {
  const CourierRouteSection({
    super.key,
    required this.deliveryId,
    required this.deliveryStatus,
    this.pickupNotes,
    this.onChat,
    this.chatUnread = 0,
  });

  final String deliveryId;
  final String deliveryStatus;
  final String? pickupNotes;
  final VoidCallback? onChat;
  final int chatUnread;

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
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Card(
            margin: EdgeInsets.zero,
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
          pickupNotes: widget.pickupNotes,
          onChat: widget.onChat,
          chatUnread: widget.chatUnread,
        );
      },
    );
  }
}

/// Detalle compacto de la entrega: pedido, progreso, destino y acciones.
class CourierOrderCard extends StatelessWidget {
  const CourierOrderCard({
    super.key,
    required this.route,
    this.currentLatitude,
    this.currentLongitude,
    this.pickupNotes,
    this.onChat,
    this.chatUnread = 0,
    this.navigationLauncher = openCourierNavigation,
    this.phoneLauncher = callCustomer,
  });

  final CourierDeliveryRoute route;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? pickupNotes;
  final VoidCallback? onChat;

  /// Mensajes del cliente sin leer: se muestran sobre "Chatear".
  final int chatUnread;
  final Future<String?> Function(double latitude, double longitude)
      navigationLauncher;
  final Future<bool> Function(String phone) phoneLauncher;

  @override
  Widget build(BuildContext context) {
    final destination = route.hasDestination
        ? (route.destinationLatitude!, route.destinationLongitude!)
        : null;
    final current = currentLatitude != null && currentLongitude != null
        ? LatLng(currentLatitude!, currentLongitude!)
        : null;
    final remainingKm = current == null || destination == null
        ? route.distanceKm
        : const Distance().as(
            LengthUnit.Kilometer,
            current,
            LatLng(destination.$1, destination.$2),
          );
    final remainingEta = _remainingEta(route, remainingKm);
    final navigate =
        destination != null && canNavigateToCustomer(route.deliveryStatus)
            ? () => _openMap(context, destination.$1, destination.$2)
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactCard(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text(
                  route.orderNumber.trim().isEmpty
                      ? 'Sin número'
                      : route.orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(label: courierStatusLabel(route.deliveryStatus)),
            ]),
            if (route.items.isNotEmpty) ...[
              const Divider(height: 16),
              OrderProductsSummaryRow(
                items: route.items,
                summary: '${orderItemsCount(route.items)} · '
                    '${orderItemsSummary(route.items)}',
                onView: () => showCourierProductsSheet(
                  context,
                  orderNumber: route.orderNumber,
                  items: route.items,
                  merchantName: route.merchantDisplayName ?? route.merchantName,
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        _CompactCard(child: CourierProgressStrip(status: route.deliveryStatus)),
        const SizedBox(height: 8),
        if (_isPickupPhase(route.deliveryStatus))
          _PickupCard(
            route: route,
            pickupNotes: pickupNotes,
            onOpenMap: route.hasOrigin
                ? () => _openMap(
                    context, route.originLatitude!, route.originLongitude!)
                : null,
          )
        else
          _CustomerCard(
            route: route,
            distanceKm: remainingKm,
            etaMinutes: remainingEta,
            onCall: route.customerPhone?.trim().isNotEmpty == true
                ? () => _call(context, route.customerPhone!)
                : null,
          ),
        if (navigate != null || onChat != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (navigate != null)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7C00),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: navigate,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Ir al destino del cliente',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            if (navigate != null && onChat != null) const SizedBox(width: 8),
            if (onChat != null)
              // Junto a "Ir al destino" ocupa solo su ancho; solo, toda la fila.
              navigate != null ? _chatButton() : Expanded(child: _chatButton()),
          ]),
        ],
      ],
    );
  }

  Widget _chatButton() => ChatButtonWithBadge(
        key: const Key('courier-chat-button'),
        onPressed: onChat!,
        unread: chatUnread,
      );

  Future<void> _openMap(
      BuildContext context, double latitude, double longitude) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = await navigationLauncher(latitude, longitude);
    if (provider == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo abrir una aplicación de mapas.'),
      ));
    }
  }

  Future<void> _call(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await phoneLauncher(phone)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo abrir el teléfono.'),
      ));
    }
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

/// "Ir al destino del cliente" solo se habilita con el pedido "En camino".
bool canNavigateToCustomer(String status) => status == 'IN_TRANSIT';

/// El punto de recojo se muestra solo después de aceptar la oferta.
bool _isPickupPhase(String status) =>
    status == 'ACCEPTED' || status == 'ARRIVED_AT_MERCHANT';

String courierStatusLabel(String status) =>
    const {
      'ASSIGNED': 'Nueva oferta',
      'ACCEPTED': 'Aceptado',
      'ARRIVED_AT_MERCHANT': 'En el comercio',
      'PICKED_UP': 'Recogido',
      'IN_TRANSIT': 'En camino',
      'ARRIVED_AT_CUSTOMER': 'Llegaste',
      'DELIVERED': 'Entregado',
    }[status] ??
    status;

const _progressSteps = <(String, IconData)>[
  ('Aceptado', Icons.check_rounded),
  ('Recogido', Icons.shopping_bag_outlined),
  ('En camino', Icons.delivery_dining_outlined),
  ('Llegaste', Icons.location_on_outlined),
  ('Entregado', Icons.home_outlined),
];

const _progressRank = {
  'ASSIGNED': 0,
  'ACCEPTED': 1,
  'ARRIVED_AT_MERCHANT': 1,
  'PICKED_UP': 2,
  'IN_TRANSIT': 3,
  'ARRIVED_AT_CUSTOMER': 4,
  'DELIVERED': 5,
};

/// Posición en el recorrido (0 = oferta sin aceptar, 5 = entregado).
int courierProgressRank(String status) => _progressRank[status] ?? 0;

/// Progreso horizontal de la entrega con un ícono por paso.
class CourierProgressStrip extends StatelessWidget {
  const CourierProgressStrip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rank = courierProgressRank(status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _progressSteps.length; i++)
          Expanded(
            child: _ProgressStep(
              label: _progressSteps[i].$1,
              icon: _progressSteps[i].$2,
              done: i + 1 < rank || (rank == 5 && i == 4),
              current: i + 1 == rank && rank < 5,
              first: i == 0,
              last: i == _progressSteps.length - 1,
              lineDone: i + 1 < rank,
              scheme: scheme,
            ),
          ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
    required this.first,
    required this.last,
    required this.lineDone,
    required this.scheme,
  });

  final String label;
  final IconData icon;
  final bool done, current, first, last, lineDone;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final fill = done
        ? scheme.primary
        : current
            ? scheme.primaryContainer
            : scheme.surface;
    final iconColor = done
        ? scheme.onPrimary
        : current
            ? scheme.primary
            : scheme.outline;
    final border = done || current ? scheme.primary : scheme.outlineVariant;
    Widget line(bool active) => Expanded(
          child: Container(
            height: 2,
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
        );
    return Semantics(
      label:
          '$label, ${done ? 'completado' : current ? 'paso actual' : 'pendiente'}',
      child: ExcludeSemantics(
        child: Column(children: [
          Row(children: [
            first ? const Spacer() : line(done || current),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: current ? 2 : 1.2),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            last ? const Spacer() : line(lineDone),
          ]),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                    color: done || current ? null : scheme.onSurfaceVariant,
                  )),
        ]),
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.route,
    required this.distanceKm,
    required this.etaMinutes,
    required this.onCall,
  });

  final CourierDeliveryRoute route;
  final double? distanceKm;
  final int? etaMinutes;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trip = [
      if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)} km',
      if (etaMinutes != null) '$etaMinutes min',
    ].join(' · ');
    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(Icons.person_outline,
                  size: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_textOrFallback(route.customerName, 'Cliente'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (trip.isNotEmpty)
                    Text(trip,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (onCall != null)
              IconButton.outlined(
                tooltip: 'Llamar al cliente',
                visualDensity: VisualDensity.compact,
                onPressed: onCall,
                icon: const Icon(Icons.phone_outlined, size: 18),
              ),
          ]),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.location_on_outlined,
            text: _textOrFallback(
                route.destinationAddress, 'Destino por confirmar'),
            secondary: route.destinationReference?.trim().isNotEmpty == true
                ? 'Ref.: ${route.destinationReference!.trim()}'
                : null,
          ),
          if (route.deliveryNotes?.trim().isNotEmpty == true)
            _DetailLine(
                icon: Icons.sticky_note_2_outlined,
                text: route.deliveryNotes!.trim()),
        ],
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({
    required this.route,
    required this.pickupNotes,
    required this.onOpenMap,
  });

  final CourierDeliveryRoute route;
  final String? pickupNotes;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final merchantName = _textOrFallback(
      route.merchantDisplayName,
      _textOrFallback(route.merchantName, 'Comercio'),
    );
    final branchName = route.branchName?.trim();
    final title = branchName != null &&
            branchName.isNotEmpty &&
            branchName != merchantName
        ? '$merchantName · $branchName'
        : merchantName;
    final address =
        _textOrFallback(route.merchantAddress, 'Dirección no disponible');
    final canNavigate =
        onOpenMap != null && route.merchantAddress?.trim().isNotEmpty == true;
    return _CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PUNTO DE RECOJO',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(Icons.storefront_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          if (canNavigate)
            Semantics(
              link: true,
              label: 'Abrir ubicación de $merchantName',
              child: InkWell(
                onTap: onOpenMap,
                borderRadius: BorderRadius.circular(8),
                child: _DetailLine(
                  icon: Icons.location_on_outlined,
                  text: address,
                  link: true,
                ),
              ),
            )
          else
            _DetailLine(icon: Icons.location_on_outlined, text: address),
          if (pickupNotes?.trim().isNotEmpty == true)
            _DetailLine(
                icon: Icons.sticky_note_2_outlined, text: pickupNotes!.trim()),
          const Divider(height: 14),
          _DetailLine(
            icon: Icons.person_outline,
            text:
                'Entregar a ${_textOrFallback(route.customerName, 'Cliente')}',
            secondary: route.destinationAddress?.trim(),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.text,
    this.secondary,
    this.link = false,
  });

  final IconData icon;
  final String text;
  final String? secondary;
  final bool link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: link ? const Color(0xFF175CD3) : null,
                    decoration: link ? TextDecoration.underline : null,
                    fontWeight: link ? FontWeight.w600 : null,
                  )),
              if (secondary != null && secondary!.isNotEmpty)
                Text(secondary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (link) Icon(Icons.open_in_new, size: 15, color: scheme.primary),
      ]),
    );
  }
}

String _textOrFallback(String? value, String fallback) =>
    value?.trim().isNotEmpty == true ? value!.trim() : fallback;
