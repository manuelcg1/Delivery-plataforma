import 'package:flutter/material.dart';
import '../data/yape_checkout.dart';

class BranchClosedForYape implements Exception {
  const BranchClosedForYape();
}

class YapeCheckoutSheet extends StatefulWidget {
  const YapeCheckoutSheet({super.key, required this.load, required this.total});
  final Future<YapeSettings> Function() load;
  final double total;
  @override
  State<YapeCheckoutSheet> createState() => _YapeCheckoutSheetState();
}

class _YapeCheckoutSheetState extends State<YapeCheckoutSheet>
    with WidgetsBindingObserver {
  late Future<YapeSettings> _settings;
  bool _qrLoaded = false;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retry();
  }

  Future<YapeSettings> _loadSettings() {
    final settings = Future<YapeSettings>.sync(widget.load);
    // Retry can complete before the next frame attaches FutureBuilder.
    // Handle that interval while preserving the same future and its error UI.
    settings.ignore();
    return settings;
  }

  void _retry() => setState(() {
        _qrLoaded = false;
        _attempt++;
        _settings = _loadSettings();
      });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: FutureBuilder<YapeSettings>(
            future: _settings,
            builder: (context, state) {
              if (state.connectionState != ConnectionState.done)
                return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()));
              final attempt = _attempt;
              final settings = state.data;
              if (settings == null || !settings.available)
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(state.error is BranchClosedForYape
                      ? 'Fuera de horario de atención'
                      : state.hasError
                          ? 'No pudimos cargar Yape. Intenta nuevamente.'
                          : 'Yape no está disponible para este comercio.'),
                  TextButton(
                      onPressed: _retry, child: const Text('Reintentar')),
                ]);
              return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Paga con Yape',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF06163A),
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Image.network(
                      settings.qrUrl!,
                      key: ValueKey(_attempt),
                      height: 210,
                      fit: BoxFit.contain,
                      frameBuilder: (context, child, frame, synchronous) {
                        if ((frame != null || synchronous) && !_qrLoaded) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && attempt == _attempt)
                              setState(() => _qrLoaded = true);
                          });
                        }
                        return child;
                      },
                      errorBuilder: (_, __, ___) {
                        if (_qrLoaded)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && attempt == _attempt)
                              setState(() => _qrLoaded = false);
                          });
                        return const SizedBox(
                            height: 150,
                            child: Center(
                                child: Text(
                                    'No pudimos cargar el QR. Intenta nuevamente.')));
                      },
                    ),
                    TextButton(
                        onPressed: _retry, child: const Text('Reintentar')),
                    Text(settings.phone!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(settings.holderName!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text('S/ ${widget.total.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF06163A))),
                    const SizedBox(height: 16),
                    const Text('¿Realizaste tu Yape?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7C00),
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: _qrLoaded
                            ? () => Navigator.pop(context, settings)
                            : null,
                        child: const Text('Sí, ya realicé mi Yape')),
                    const SizedBox(height: 8),
                    const Text(
                        'Tu pago quedará pendiente de validación por el comercio.',
                        textAlign: TextAlign.center),
                  ]);
            }),
      );
}

class YapeCheckoutCard extends StatelessWidget {
  const YapeCheckoutCard(
      {super.key, required this.declared, required this.onTap});
  final bool declared;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: declared ? const Color(0xFFF0FDF4) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
                color: declared
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFE2E8F0))),
        child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
                declared
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_checked,
                color: declared
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFFF7C00)),
            title: const Text('Yape',
                style: TextStyle(
                    color: Color(0xFF06163A), fontWeight: FontWeight.w700)),
            subtitle: Text(declared
                ? 'Yape declarado · Pendiente de validación'
                : 'Escanea el QR y confirma tu Yape'),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFFF7C00)),
            onTap: onTap),
      );
}
