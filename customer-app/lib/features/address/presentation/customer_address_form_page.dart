import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../home/presentation/home_page.dart';
import '../data/google_places_service.dart';
import '../domain/customer_address.dart';

class CustomerAddressFormPage extends ConsumerStatefulWidget {
  const CustomerAddressFormPage({super.key, this.address});
  final CustomerAddress? address;
  @override
  ConsumerState<CustomerAddressFormPage> createState() =>
      _CustomerAddressFormPageState();
}

class _CustomerAddressFormPageState
    extends ConsumerState<CustomerAddressFormPage> {
  final formKey = GlobalKey<FormState>();
  final map = MapController();
  late final GooglePlacesService places;
  Timer? debounce;
  late final search =
          TextEditingController(text: widget.address?.formattedAddress ?? ''),
      recipient =
          TextEditingController(text: widget.address?.recipientName ?? ''),
      phone = TextEditingController(text: widget.address?.phone ?? ''),
      apartment = TextEditingController(text: widget.address?.apartment ?? ''),
      reference = TextEditingController(text: widget.address?.reference ?? ''),
      instructions = TextEditingController(
          text: widget.address?.deliveryInstructions ?? '');
  CustomerAddress? selected;
  List<PlaceSuggestion> suggestions = [];
  String label = 'Casa', customLabel = '';
  bool busy = false, locating = false;
  String? error, searchError;
  @override
  void initState() {
    super.initState();
    places = GooglePlacesService(ref.read(apiClientProvider).dio);
    selected = widget.address;
    final savedLabel = widget.address?.label;
    label = savedLabel == null
        ? 'Casa'
        : ['Casa', 'Trabajo', 'Otro'].contains(savedLabel)
            ? savedLabel
            : 'Otro';
    if (label == 'Otro') customLabel = widget.address?.label ?? '';
  }

  @override
  void dispose() {
    debounce?.cancel();
    places.dispose();
    map.dispose();
    for (final c in [
      search,
      recipient,
      phone,
      apartment,
      reference,
      instructions
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void query(String value) {
    debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        suggestions = [];
        searchError = null;
      });
      return;
    }
    debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await places.autocomplete(value,
            latitude: selected?.latitude, longitude: selected?.longitude);
        if (mounted) {
          setState(() {
            suggestions = result;
            searchError = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            suggestions = [];
            searchError =
                'No pudimos buscar direcciones. Intenta nuevamente en unos minutos.';
          });
        }
      }
    });
  }

  Future<void> choose(PlaceSuggestion suggestion) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await places.details(suggestion.placeId);
      if (!mounted) return;
      setState(() {
        selected = value;
        search.text = value.formattedAddress;
        suggestions = [];
      });
      map.move(LatLng(value.latitude, value.longitude), 16);
    } catch (e) {
      if (mounted) {
        setState(
            () => error = ref.read(apiClientProvider).exception(e).message);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> current() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw StateError('GPS desactivado');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw StateError('Permiso de ubicación requerido');
      if (permission == LocationPermission.deniedForever)
        throw StateError(
            'Permiso denegado permanentemente; actívalo en Ajustes');
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15)));
      final value = await places.reverse(p.latitude, p.longitude);
      selected = CustomerAddress(
          id: '',
          label: 'Casa',
          formattedAddress: value.formattedAddress,
          latitude: value.latitude,
          longitude: value.longitude,
          countryCode: 'PE',
          isDefault: false,
          placeId: value.placeId,
          street: value.street,
          streetNumber: value.streetNumber,
          district: value.district,
          city: value.city,
          province: value.province,
          region: value.region,
          postalCode: value.postalCode,
          locationSource: 'CURRENT');
      search.text = value.formattedAddress;
      map.move(LatLng(value.latitude, value.longitude), 16);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> moved(MapCamera camera, bool gesture) async {
    if (!gesture) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final value = await places.reverse(
            camera.center.latitude, camera.center.longitude);
        if (mounted)
          setState(() {
            selected = value;
            search.text = value.formattedAddress;
          });
      } catch (_) {}
    });
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    final value = selected;
    if (value == null || !validCoordinates(value.latitude, value.longitude)) {
      setState(() =>
          error = 'Selecciona una ubicación válida en la búsqueda o el mapa');
      return;
    }
    final actualLabel = label == 'Otro' ? customLabel.trim() : label;
    if (!(formKey.currentState?.validate() ?? false)) {
      setState(() => error = 'Revisa los campos marcados antes de continuar');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final request = CustomerAddress(
        id: value.id,
        label: actualLabel,
        formattedAddress: value.formattedAddress,
        latitude: value.latitude,
        longitude: value.longitude,
        countryCode: 'PE',
        isDefault: widget.address?.isDefault ?? false,
        recipientName: recipient.text.trim(),
        phone: phone.text.trim(),
        placeId: value.placeId,
        street: value.street,
        streetNumber: value.streetNumber,
        district: value.district,
        city: value.city,
        province: value.province,
        region: value.region,
        postalCode: value.postalCode,
        apartment: apartment.text.trim(),
        reference: reference.text.trim(),
        deliveryInstructions: instructions.text.trim(),
        locationSource: value.locationSource);
    try {
      final repo = ref.read(customerRepositoryProvider);
      if (widget.address == null) {
        await repo.addAddress(request.toRequest());
      } else {
        await repo.updateAddress(widget.address!.id, request.toRequest());
      }
      ref.invalidate(addressesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dirección guardada')));
      Navigator.of(context).pop(request);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = ref.read(apiClientProvider).exception(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(selected?.latitude ?? AppConfig.defaultMapLatitude,
        selected?.longitude ?? AppConfig.defaultMapLongitude);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.address == null
              ? 'Agregar dirección'
              : 'Editar dirección')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          key: const Key('save-address'),
          onPressed: busy ? null : save,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(busy ? 'Guardando dirección…' : 'Guardar dirección'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(children: [
              Text('¿Dónde entregamos?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 14),
              SearchBar(
                controller: search,
                hintText: 'Buscar calle o lugar',
                leading: const Icon(Icons.search),
                onChanged: query,
              ),
              if (searchError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(searchError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              if (busy) const LinearProgressIndicator(),
              ...suggestions.map((suggestion) => ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(suggestion.description),
                    onTap: busy ? null : () => choose(suggestion),
                  )),
              if (suggestions.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Image.network(
                      'https://maps.gstatic.com/mapfiles/api-3/images/powered-by-google-on-white3.png',
                      height: 18,
                      semanticLabel: 'Resultados proporcionados por Google',
                      errorBuilder: (_, __, ___) => const Text(
                        'Resultados proporcionados por Google',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FlutterMap(
                        mapController: map,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: AppConfig.defaultMapZoom,
                          onPositionChanged: moved,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.delivery.platform.customer',
                          )
                        ],
                      ),
                      const IgnorePointer(
                        child: Icon(Icons.location_pin,
                            size: 48, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Mueve el mapa para ajustar el pin',
                    textAlign: TextAlign.center),
              ),
              OutlinedButton.icon(
                onPressed: locating || busy ? null : current,
                icon: const Icon(Icons.my_location),
                label: Text(locating
                    ? 'Obteniendo ubicación…'
                    : 'Usar mi ubicación actual'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF15803D)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ubicación seleccionada',
                                style: TextStyle(
                                    color: Color(0xFF166534),
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(selected!.formattedAddress),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const _AddressSectionTitle('DATOS DE LA DIRECCIÓN'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: label,
                decoration: _fieldDecoration(
                    label: 'Etiqueta', icon: Icons.home_outlined),
                items: ['Casa', 'Trabajo', 'Otro']
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged:
                    busy ? null : (value) => setState(() => label = value!),
              ),
              if (label == 'Otro') ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: customLabel,
                  decoration: _fieldDecoration(
                      label: 'Etiqueta personalizada *',
                      icon: Icons.label_outline),
                  onChanged: (value) => customLabel = value,
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Escribe una etiqueta'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: recipient,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                    label: 'Nombre de quien recibe *',
                    icon: Icons.person_outline),
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Ingresa el nombre de quien recibe'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                    label: 'Teléfono *', icon: Icons.phone_outlined),
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Ingresa un teléfono de contacto'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: apartment,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                    label: 'Número / departamento (opcional)',
                    icon: Icons.apartment_outlined),
              ),
              const SizedBox(height: 24),
              const _AddressSectionTitle('INDICACIONES OPCIONALES'),
              const SizedBox(height: 10),
              TextFormField(
                controller: reference,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                    label: 'Referencia', icon: Icons.bookmark_border),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: instructions,
                maxLines: 3,
                decoration: _fieldDecoration(
                    label: 'Instrucciones para el repartidor',
                    icon: Icons.chat_outlined),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error!)),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _AddressSectionTitle extends StatelessWidget {
  const _AddressSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF667085),
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
      );
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
}) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
