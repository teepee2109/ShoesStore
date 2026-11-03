import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../providers/wishlist_provider.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  String _formatPrice(double value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/products/${product.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: product.imageUrl),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlist, child) {
                        final saved = wishlist.contains(product.id);
                        final isUpdating =
                            wishlist.updatingProductId == product.id;
                        return IconButton.filledTonal(
                          tooltip: saved
                              ? 'Bỏ yêu thích'
                              : 'Thêm vào yêu thích',
                          onPressed: wishlist.isMutating || wishlist.isLoading
                              ? null
                              : () async {
                                  try {
                                    await wishlist.toggle(product);
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .92,
                            ),
                            foregroundColor: saved
                                ? Colors.redAccent
                                : Colors.black87,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: isUpdating
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  saved
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 19,
                                ),
                        );
                      },
                    ),
                  ),
                  if (product.discountPrice != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7F542),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'SALE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.categoryName != null)
                    Text(
                      product.categoryName!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: Colors.black54, letterSpacing: 0.6),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatPrice(product.currentPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
