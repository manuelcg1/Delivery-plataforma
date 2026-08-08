import 'package:flutter/material.dart';

final cartFeedbackMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showProductAddedSnackBar(
  ScaffoldMessengerState messenger, {
  required String productName,
  required int quantity,
}) {
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF06163A),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Producto agregado',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('$quantity × $productName',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .78))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
}

void showCartErrorSnackBar(
  ScaffoldMessengerState messenger,
  String message,
) {
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFFDC2626),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white))),
      ]),
    ));
}
