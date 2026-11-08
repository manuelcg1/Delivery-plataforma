enum MerchantCategory {
  restaurant('RESTAURANT', 'Restaurantes'),
  polleria('POLLERIA', 'Pollería'),
  burgers('BURGERS', 'Hamburguesas'),
  chifa('CHIFA', 'Chifa'),
  iceCream('ICE_CREAM', 'Heladería'),
  pharmacy('PHARMACY', 'Farmacia'),
  bodega('BODEGA', 'Bodegas'),
  grocery('GROCERY', 'Supermercados'),
  retail('RETAIL', 'Tiendas'),
  darkStore('DARK_STORE', 'Despacho'),
  services('SERVICES', 'Servicios'),
  other('OTHER', 'Otros');

  const MerchantCategory(this.code, this.label);
  final String code;
  final String label;

  static MerchantCategory fromCode(String code) => values.firstWhere(
        (category) => category.code == code,
        orElse: () => other,
      );
}
