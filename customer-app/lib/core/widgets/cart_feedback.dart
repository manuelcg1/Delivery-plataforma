import 'package:flutter/material.dart';

void showProductAddedSnackBar(
  ScaffoldMessengerState messenger, {
  required String productName,
  required int quantity,
  required VoidCallback onViewCart,
}) {
  final colors = Theme.of(messenger.context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: colors.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: colors.primaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Producto agregado',
                      style: TextStyle(
                          color: colors.onInverseSurface,
                          fontWeight: FontWeight.w700)),
                  Text('$quantity × $productName',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color:
                              colors.onInverseSurface.withValues(alpha: .75))),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Ver carrito',
          textColor: colors.tertiaryContainer,
          onPressed: onViewCart,
        ),
      ),
    );
}

void showCartErrorSnackBar(
  ScaffoldMessengerState messenger,
  String message,
) {
  final colors = Theme.of(messenger.context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.errorContainer,
      content: Row(children: [
        Icon(Icons.error_outline, color: colors.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(
            child: Text(message,
                style: TextStyle(color: colors.onErrorContainer))),
      ]),
    ));
}
