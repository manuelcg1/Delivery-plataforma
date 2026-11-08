import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/merchant_category.dart';

class MerchantCategoryCarousel extends StatefulWidget {
  const MerchantCategoryCarousel({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MerchantCategory? selected;
  final ValueChanged<MerchantCategory?> onChanged;

  @override
  State<MerchantCategoryCarousel> createState() =>
      _MerchantCategoryCarouselState();
}

class _MerchantCategoryCarouselState extends State<MerchantCategoryCarousel> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant MerchantCategoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != null &&
        widget.selected == null &&
        _scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 66 + MediaQuery.textScalerOf(context).scale(12) * 2,
        child: ListView.separated(
          key: const ValueKey('merchant-category-carousel'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: MerchantCategory.values.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final category =
                index == 0 ? null : MerchantCategory.values[index - 1];
            final selected = widget.selected == category;
            final foreground =
                selected ? Colors.white : const Color(0xFF111827);
            final label = category?.label ?? 'Todos';
            final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
            return Semantics(
              selected: selected,
              button: true,
              child: SizedBox(
                width: (label.length > 10 ? 124 : 94) *
                    textScale.clamp(1, double.infinity),
                child: Material(
                  color: selected ? const Color(0xFFE00024) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                        color: selected
                            ? const Color(0xFFE00024)
                            : const Color(0xFFFFCAD2)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('category-${category?.code ?? 'ALL'}'),
                    onTap: () => widget.onChanged(category),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_icon(category), color: foreground, size: 28),
                          const SizedBox(height: 6),
                          Text(label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  IconData _icon(MerchantCategory? category) => switch (category) {
        null => Icons.grid_view_rounded,
        MerchantCategory.restaurant => Icons.restaurant_rounded,
        MerchantCategory.polleria => Icons.outdoor_grill_rounded,
        MerchantCategory.burgers => Icons.lunch_dining_rounded,
        MerchantCategory.chifa => Icons.ramen_dining_rounded,
        MerchantCategory.iceCream => Icons.icecream_rounded,
        MerchantCategory.pharmacy => Icons.local_pharmacy_rounded,
        MerchantCategory.bodega => Icons.storefront_rounded,
        MerchantCategory.grocery => Icons.local_grocery_store_rounded,
        MerchantCategory.retail => Icons.shopping_bag_rounded,
        MerchantCategory.darkStore => Icons.warehouse_rounded,
        MerchantCategory.services => Icons.handyman_rounded,
        MerchantCategory.other => Icons.more_horiz_rounded,
      };
}
