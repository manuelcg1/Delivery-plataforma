import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const deliveryCodeLength = 5;

/// Normaliza lo que digita el repartidor: mayúsculas, sin espacios ni guiones.
String normalizeDeliveryCode(String value) =>
    value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// Casilla para ingresar el código de entrega que dicta el cliente.
/// Solo se muestra cuando el repartidor ya llegó al destino.
class CourierDeliveryCodeSection extends StatefulWidget {
  const CourierDeliveryCodeSection({
    super.key,
    required this.verified,
    required this.onVerify,
  });

  final bool verified;

  /// Devuelve `null` si el código fue validado o el mensaje de error a mostrar.
  final Future<String?> Function(String code) onVerify;

  @override
  State<CourierDeliveryCodeSection> createState() =>
      _CourierDeliveryCodeSectionState();
}

class _CourierDeliveryCodeSectionState
    extends State<CourierDeliveryCodeSection> {
  final controller = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final code = normalizeDeliveryCode(controller.text);
    if (code.length != deliveryCodeLength) {
      setState(() => error = 'Ingresa los $deliveryCodeLength caracteres.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final message = await widget.onVerify(code);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.verified) {
      return Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.primaryContainer,
        child: const ListTile(
          key: Key('delivery-code-verified'),
          leading: Icon(Icons.verified_outlined),
          title: Text('Código validado'),
          subtitle: Text('Ya puedes marcar el pedido como entregado.'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Código de entrega',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                'Pide al cliente su código de $deliveryCodeLength caracteres al entregarle el pedido.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delivery-code-input'),
              controller: controller,
              enabled: !busy,
              maxLength: deliveryCodeLength,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                TextInputFormatter.withFunction((oldValue, newValue) =>
                    newValue.copyWith(text: newValue.text.toUpperCase())),
              ],
              decoration: InputDecoration(
                labelText: 'Código del cliente',
                border: const OutlineInputBorder(),
                errorText: error,
                counterText: '',
              ),
              onSubmitted: (_) => busy ? null : submit(),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('delivery-code-submit'),
              onPressed: busy ? null : submit,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(busy ? 'Validando…' : 'Validar código'),
            ),
          ],
        ),
      ),
    );
  }
}
