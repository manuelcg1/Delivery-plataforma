import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/customer_repository.dart';

const _navy = Color(0xFF06163A);
const _secondary = Color(0xFF637086);
const _orange = Color(0xFFFF7C00);

class MerchantCatalogHeader extends StatelessWidget {
  const MerchantCatalogHeader({super.key, required this.merchant});
  final Merchant merchant;

  Widget _bannerFallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFFFFF0CF), Color(0xFFFFDA9D)]),
        ),
        child: Center(
            child: Icon(Icons.storefront_outlined, size: 52, color: _orange)),
      );

  @override
  Widget build(BuildContext context) {
    final banner = merchant.bannerUrl?.trim();
    final logo = merchant.logoUrl?.trim();
    final initial = merchant.name.trim().isEmpty
        ? 'C'
        : String.fromCharCode(merchant.name.trim().runes.first).toUpperCase();
    final logoFallback = ColoredBox(
        color: _navy,
        child: Center(
            child: Text(initial,
                style: GoogleFonts.poppins(
                    color: const Color(0xFFFFCC72),
                    fontSize: 24,
                    fontWeight: FontWeight.w600))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
          label: 'Banner de ${merchant.name}',
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
                aspectRatio: 2.05,
                child: banner == null || banner.isEmpty
                    ? _bannerFallback()
                    : CachedNetworkImage(
                        imageUrl: banner,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _bannerFallback(),
                        errorWidget: (_, __, ___) => _bannerFallback())),
          )),
      const SizedBox(height: 18),
      Row(children: [
        ExcludeSemantics(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    width: 48,
                    height: 48,
                    child: logo == null || logo.isEmpty
                        ? logoFallback
                        : CachedNetworkImage(
                            imageUrl: logo,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => logoFallback,
                            errorWidget: (_, __, ___) => logoFallback)))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(merchant.name,
              style: GoogleFonts.poppins(
                  color: _navy, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(merchant.branchName,
              style: GoogleFonts.poppins(color: _secondary, fontSize: 12)),
        ])),
      ]),
      if (merchant.description.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(merchant.description,
            style: GoogleFonts.poppins(
                color: _secondary, fontSize: 13, height: 1.5)),
      ],
    ]);
  }
}

class MerchantCatalogProductCard extends StatelessWidget {
  const MerchantCatalogProductCard(
      {super.key,
      required this.product,
      required this.priceLabel,
      required this.onTap});
  final Product product;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = product.primaryImage;
    const fallback = ColoredBox(
        color: Color(0xFFFFF0DC),
        child: Center(child: Icon(Icons.restaurant, color: _orange, size: 30)));
    return Semantics(
        button: true,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E9EF)),
                    borderRadius: BorderRadius.circular(17)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  width: 82,
                                  height: 94,
                                  child: image == null || image.url.isEmpty
                                      ? fallback
                                      : CachedNetworkImage(
                                          imageUrl: image.url,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => fallback,
                                          errorWidget: (_, __, ___) =>
                                              fallback)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(product.name,
                                style: GoogleFonts.poppins(
                                    color: _navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            if (product.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(product.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      color: _secondary,
                                      fontSize: 12,
                                      height: 1.4)),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  Text(priceLabel,
                                      style: GoogleFonts.poppins(
                                          color: _navy,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  Text('Ver detalle',
                                      style: GoogleFonts.poppins(
                                          color: Color(0xFFB65300),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ])),
                    ]),
              )),
        ));
  }
}
