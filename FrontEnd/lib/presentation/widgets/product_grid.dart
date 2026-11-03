import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import 'async_error_view.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.future,
    required this.onRetry,
    required this.emptyMessage,
  });

  final Future<List<Product>> future;
  final VoidCallback onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AsyncErrorView(error: snapshot.error!, onRetry: onRetry);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final products = snapshot.data!;
      if (products.isEmpty) return Center(child: Text(emptyMessage));

      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 0.68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) =>
                ProductCard(product: products[index]),
          );
        },
      );
    },
  );
}

class ProductGridSliver extends StatelessWidget {
  const ProductGridSliver({
    super.key,
    required this.future,
    required this.onRetry,
    required this.emptyMessage,
  });

  final Future<List<Product>> future;
  final VoidCallback onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 260,
            child: AsyncErrorView(error: snapshot.error!, onRetry: onRetry),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      final products = snapshot.data!;
      if (products.isEmpty) {
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 160,
            child: Center(child: Text(emptyMessage)),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.crossAxisExtent >= 700 ? 3 : 2;
            return SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => ProductCard(product: products[index]),
                childCount: products.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 0.68,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
            );
          },
        ),
      );
    },
  );
}
