import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wishlist_provider.dart';
import '../widgets/async_error_view.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    final wishlist = context.read<WishlistProvider>();
    if (!wishlist.hasLoaded) unawaited(wishlist.load(force: true));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Wishlist',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: Consumer<WishlistProvider>(
      builder: (context, wishlist, child) {
        if (wishlist.isLoading && !wishlist.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (wishlist.error != null && !wishlist.hasLoaded) {
          return AsyncErrorView(
            error: wishlist.error!,
            onRetry: () => wishlist.load(force: true),
          );
        }
        if (wishlist.products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 58,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Your wishlist is waiting',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  const Text('Lưu những đôi giày bạn yêu thích tại đây.'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/search'),
                    child: const Text('Khám phá sản phẩm'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => wishlist.load(force: true),
          child: CustomScrollView(
            slivers: [
              if (wishlist.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Không thể đồng bộ wishlist: ${wishlist.error}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => wishlist.load(force: true),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
                  child: Row(
                    children: [
                      Text(
                        '${wishlist.products.length} saved styles',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      const Text(
                        'Chạm trái tim để xóa',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  itemCount: wishlist.products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .57,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 18,
                  ),
                  itemBuilder: (context, index) =>
                      ProductCard(product: wishlist.products[index]),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
