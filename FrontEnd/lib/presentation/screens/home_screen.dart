import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../providers/notification_provider.dart';
import '../widgets/async_error_view.dart';
import '../widgets/product_results_sliver.dart';
import '../widgets/store_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final products = context.read<ProductProvider>();
    if (!products.catalog('home').hasLoaded) {
      unawaited(
        products.loadInitial(
          scope: 'home',
          query: '',
          category: null,
          sort: 'latest',
        ),
      );
    }
    unawaited(products.loadCategories());
  }

  @override
  Widget build(BuildContext context) => Consumer<ProductProvider>(
    builder: (context, provider, child) {
      final catalog = provider.catalog('home');
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: 20,
            title: const _AdidasWordmark(),
            actions: [
              IconButton(
                onPressed: () => context.push('/chat'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                tooltip: 'Chat với cửa hàng',
              ),
              Consumer<NotificationProvider>(
                builder: (context, notifications, child) => IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: notifications.unreadCount > 0,
                    label: Text('${notifications.unreadCount}'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  tooltip: 'Thông báo',
                ),
              ),
              IconButton(
                onPressed: () => context.go('/cart'),
                icon: const Icon(Icons.shopping_bag_outlined),
                tooltip: 'Giỏ hàng',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.go('/search'),
                    child: Container(
                      width: double.infinity,
                      height: 340,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF191B18),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (catalog.products.isNotEmpty &&
                              catalog.products.first.imageUrl != null)
                            Opacity(
                              opacity: .66,
                              child: Image.network(
                                catalog.products.first.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(),
                              ),
                            ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xD9000000), Color(0x11000000)],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  'RUN YOUR\nOWN WAY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    height: .95,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Nhẹ hơn. Xa hơn. Mỗi ngày.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: () => context.go('/search'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFD7F542),
                                    foregroundColor: Colors.black,
                                  ),
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('Khám phá ngay'),
                                ),
                              ],
                            ),
                          ),
                          const Positioned(
                            top: 20,
                            right: 20,
                            child: _AdidasMark(light: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading(title: 'Shop theo danh mục'),
                  const SizedBox(height: 12),
                  _CategorySelector(provider: provider),
                  const SizedBox(height: 22),
                  SectionHeading(
                    title: catalog.category == null
                        ? 'Sản phẩm mới nhất'
                        : 'Sản phẩm theo danh mục',
                    action: 'Xem tất cả',
                    onAction: () => context.go('/search'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          ProductResultsSliver(
            catalog: catalog,
            onRetry: () => provider.retryInitial(scope: 'home'),
            onRetryLoadMore: () => provider.retryLoadMore(scope: 'home'),
            emptyMessage: 'Chưa có sản phẩm trong danh mục này.',
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    },
  );
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.provider});

  final ProductProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.categoriesError != null && provider.categories.isEmpty) {
      return SizedBox(
        height: 74,
        child: AsyncErrorView(
          error: provider.categoriesError!,
          onRetry: () => provider.loadCategories(force: true),
        ),
      );
    }
    if (provider.isLoadingCategories && provider.categories.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (provider.categories.isEmpty) {
      return const SizedBox(height: 36, child: Text('Chưa có danh mục.'));
    }
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: provider.catalog('home').category == null,
              onSelected: (_) => provider.loadInitial(
                scope: 'home',
                query: '',
                category: null,
                sort: 'latest',
              ),
            ),
          ),
          ...provider.categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(category: category, provider: provider),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.provider});

  final Category category;
  final ProductProvider provider;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(category.name),
    selected: provider.catalog('home').category == category.slug,
    onSelected: (_) => provider.loadInitial(
      scope: 'home',
      query: '',
      category: category.slug,
      sort: 'latest',
    ),
  );
}

class _AdidasWordmark extends StatelessWidget {
  const _AdidasWordmark();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _AdidasMark(),
      SizedBox(width: 9),
      Text(
        'ADIDAS',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _AdidasMark extends StatelessWidget {
  const _AdidasMark({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.change_history_rounded,
    size: 28,
    color: light ? Colors.white : Colors.black,
  );
}
