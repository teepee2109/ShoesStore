import 'package:flutter/material.dart';

import '../../providers/product_provider.dart';
import 'async_error_view.dart';
import 'product_card.dart';

class ProductResultsSliver extends StatelessWidget {
  const ProductResultsSliver({
    super.key,
    required this.catalog,
    required this.onRetry,
    required this.onRetryLoadMore,
    required this.emptyMessage,
  });

  final ProductCatalogState catalog;
  final VoidCallback onRetry;
  final VoidCallback onRetryLoadMore;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (catalog.isLoading && catalog.products.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 270,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (catalog.error != null && catalog.products.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 290,
          child: AsyncErrorView(error: catalog.error!, onRetry: onRetry),
        ),
      );
    }
    if (catalog.hasLoaded && catalog.products.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(height: 220, child: Center(child: Text(emptyMessage))),
      );
    }
    if (catalog.products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          sliver: SliverGrid.builder(
            itemCount: catalog.products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) =>
                ProductCard(product: catalog.products[index]),
          ),
        ),
        if (catalog.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (catalog.loadMoreError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
              child: Column(
                children: [
                  Text(
                    catalog.loadMoreError.toString(),
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: onRetryLoadMore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tải thêm lần nữa'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
