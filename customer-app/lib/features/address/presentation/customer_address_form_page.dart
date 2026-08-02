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
    label = ['Casa', 'Trabajo', 'Otro'].contains(widget.address?.label)
        ? widget.address!.label
        : 'Otro';
    if (label == 'Otro') customLabel = widget.address?.label ?? '';
  }

  @override
  void dispose() {
    debounce?.cancel();
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
    setState(() => busy = true);
    try {
      final value = await places.details(suggestion.placeId);
      setState(() {
        selected = value;
        search.text = value.formattedAddress;
        suggestions = [];
      });
      map.move(LatLng(value.latitude, value.longitude), 16);
    } catch (e) {
      setState(() => error = e.toString());
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
    final value = selected;
    if (value == null || !validCoordinates(value.latitude, value.longitude)) {
      setState(() =>
          error = 'Selecciona una ubicación válida en la búsqueda o el mapa');
      return;
    }
    if (recipient.text.trim().isEmpty || phone.text.trim().isEmpty) {
      setState(() => error = 'Completa el nombre y teléfono de quien recibe');
      return;
    }
    final actualLabel = label == 'Otro' ? customLabel.trim() : label;
    if (actualLabel.isEmpty) {
      setState(() => error = 'Escribe una etiqueta');
      return;
    }
    setState(() => busy = true);
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dirección guardada')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
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
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('¿Dónde entregamos?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SearchBar(
              controller: search,
              hintText: 'Buscar dirección',
              leading: const Icon(Icons.search),
              onChanged: query),
          if (searchError != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(searchError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (busy) const LinearProgressIndicator(),
            ...suggestions.map((s) => ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(s.description),
                onTap: () => choose(s))),
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
          const SizedBox(height: 12),
          SizedBox(
              height: 260,
              child: Stack(alignment: Alignment.center, children: [
                FlutterMap(
                    mapController: map,
                    options: MapOptions(
                        initialCenter: center,
                        initialZoom: AppConfig.defaultMapZoom,
                        onPositionChanged: moved),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.delivery.platform.customer')
                    ]),
                const IgnorePointer(
                    child:
                        Icon(Icons.location_pin, size: 48, color: Colors.red))
              ])),
          const Text('Mueve el mapa para ajustar el pin.',
              textAlign: TextAlign.center),
          OutlinedButton.icon(
              onPressed: locating ? null : current,
              icon: const Icon(Icons.my_location),
              label: Text(locating
                  ? 'Obteniendo ubicación…'
                  : 'Usar mi ubicación actual')),
          if (selected != null)
            ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Ubicación seleccionada'),
                subtitle: Text(selected!.formattedAddress)),
          DropdownButtonFormField<String>(
              initialValue: label,
              decoration: const InputDecoration(labelText: 'Etiqueta'),
              items: ['Casa', 'Trabajo', 'Otro']
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (v) => setState(() => label = v!)),
          if (label == 'Otro')
            TextFormField(
                initialValue: customLabel,
                decoration:
                    const InputDecoration(labelText: 'Etiqueta personalizada'),
                onChanged: (v) => customLabel = v),
          TextField(
              controller: recipient,
              decoration:
                  const InputDecoration(labelText: 'Nombre de quien recibe')),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono')),
          TextField(
              controller: apartment,
              decoration:
                  const InputDecoration(labelText: 'Número / departamento')),
          TextField(
              controller: reference,
              decoration: const InputDecoration(labelText: 'Referencia')),
          TextField(
              controller: instructions,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Instrucciones para el repartidor')),
          if (error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(busy ? 'Guardando dirección…' : 'Guardar dirección'))
        ]));
  }
}
