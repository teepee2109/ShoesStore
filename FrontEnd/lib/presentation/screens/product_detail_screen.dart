import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../data/models/product_review.dart';
import '../../data/repositories/review_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../widgets/async_error_view.dart';
import '../widgets/product_image.dart';
import '../widgets/store_widgets.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductProvider? _provider;
  String? _selectedSize;
  String? _selectedColor;
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= context.read<ProductProvider>();
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _selectedSize = null;
      _selectedColor = null;
      _loadProduct(force: true);
    }
  }

  void _loadProduct({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider ??= context.read<ProductProvider>();
      unawaited(_provider!.loadProduct(widget.productId, force: force));
    });
  }

  Future<void> _addToCart(Product product, String size, String color) async {
    final variants = product.variants
        .where(
          (variant) =>
              variant.size == size &&
              variant.color == color &&
              variant.stock > 0,
        )
        .toList();
    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn size và màu còn hàng trước.')),
      );
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await context.read<CartProvider>().addItem(variantId: variants.first.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm sản phẩm vào giỏ hàng.')),
      );
      context.go('/cart');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<ProductProvider>(
    builder: (context, provider, child) {
      final isCurrentProduct = provider.detailProductId == widget.productId;
      final product = isCurrentProduct ? provider.detailProduct : null;
      if (provider.isLoadingDetail && isCurrentProduct || !isCurrentProduct) {
        return Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (product == null && provider.detailError != null) {
        return Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
          body: AsyncErrorView(
            error: provider.detailError!,
            onRetry: () => _loadProduct(force: true),
          ),
        );
      }
      if (product == null) {
        return Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
          body: const Center(child: Text('Không tìm thấy sản phẩm.')),
        );
      }
      return _buildProductPage(product);
    },
  );

  Widget _buildProductPage(Product product) {
    final sizes = product.variants
        .map((variant) => variant.size)
        .toSet()
        .toList();
    final selectedSize = _selectedSize ?? (sizes.isEmpty ? null : sizes.first);
    final colors = product.variants
        .where(
          (variant) => selectedSize == null || variant.size == selectedSize,
        )
        .map((variant) => variant.color)
        .toSet()
        .toList();
    final selectedColor = colors.contains(_selectedColor)
        ? _selectedColor
        : (colors.isEmpty ? null : colors.first);
    final stock = product.variants
        .where(
          (variant) =>
              variant.size == selectedSize && variant.color == selectedColor,
        )
        .fold<int>(0, (sum, variant) => sum + variant.stock);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(
          (product.categoryName ?? 'PRODUCT').toUpperCase(),
          style: const TextStyle(fontSize: 13, letterSpacing: 1.1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: .92,
              child: ProductImage(url: product.imageUrl),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            product.categoryName?.toUpperCase() ?? 'ADIDAS',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: Color(0xFFE4A500),
              ),
              const SizedBox(width: 4),
              Text(
                product.ratingAverage.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 5),
              Text(
                product.reviewCount == 0
                    ? 'Chưa có đánh giá'
                    : '(${product.reviewCount} đánh giá)',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                formatVnd(product.currentPrice),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (product.discountPrice != null) ...[
                const SizedBox(width: 10),
                Text(
                  formatVnd(product.price),
                  style: const TextStyle(
                    color: Colors.black45,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Màu sắc',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (colors.isEmpty)
            const Text('Chưa có biến thể màu sắc.')
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: colors
                  .map(
                    (color) => ChoiceChip(
                      label: Text(color),
                      selected: selectedColor == color,
                      onSelected: (_) => setState(() {
                        _selectedSize = selectedSize;
                        _selectedColor = color;
                      }),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kích cỡ',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              const Text(
                'Hướng dẫn chọn size',
                style: TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sizes.isEmpty)
            const Text('Sản phẩm chưa có biến thể kích cỡ.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sizes.map((size) {
                final inStock = product.variants.any(
                  (variant) => variant.size == size && variant.stock > 0,
                );
                return ChoiceChip(
                  label: Text(inStock ? size : '$size · Hết hàng'),
                  selected: selectedSize == size,
                  onSelected: inStock
                      ? (_) => setState(() {
                          _selectedSize = size;
                          _selectedColor = null;
                        })
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          Text(
            stock > 0 ? 'Còn $stock sản phẩm' : 'Tạm hết hàng',
            style: TextStyle(
              color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Mô tả',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            product.description?.isNotEmpty == true
                ? product.description!
                : 'Chưa có mô tả sản phẩm.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: .65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const _FeatureRow(
            icon: Icons.local_shipping_outlined,
            label: 'Giao hàng tiêu chuẩn miễn phí',
          ),
          const _FeatureRow(
            icon: Icons.assignment_return_outlined,
            label: 'Đổi trả trong vòng 30 ngày',
          ),
          const SizedBox(height: 24),
          _ProductReviews(productId: product.id),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton.icon(
            onPressed: stock > 0 && !_addingToCart
                ? () => _addToCart(product, selectedSize!, selectedColor!)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD7F542),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(54),
            ),
            icon: _addingToCart
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            label: Text(
              _addingToCart ? 'Đang thêm...' : 'Thêm vào giỏ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductReviews extends StatefulWidget {
  const _ProductReviews({required this.productId});
  final int productId;

  @override
  State<_ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<_ProductReviews> {
  late final ReviewRepository _repository;
  late Future<ProductReviewPage> _reviews;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ReviewRepository>();
    _reviews = _repository.list(widget.productId);
  }

  void _reload() =>
      setState(() => _reviews = _repository.list(widget.productId));

  @override
  void didUpdateWidget(covariant _ProductReviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _reviews = _repository.list(widget.productId);
    }
  }

  Future<void> _writeReview() async {
    var rating = 5;
    final comment = TextEditingController();
    final result = await showDialog<(int, String)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đánh giá sản phẩm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFE4A500),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Chia sẻ trải nghiệm của bạn',
                ),
              ),
              const Text(
                'Chỉ tài khoản đã nhận sản phẩm mới có thể đánh giá.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (rating, comment.text.trim())),
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
    comment.dispose();
    if (result == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      await _repository.create(
        productId: widget.productId,
        rating: result.$1,
        comment: result.$2,
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã gửi đánh giá.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(error))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProductReviewPage>(
    future: _reviews,
    builder: (context, snapshot) {
      final page = snapshot.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Đánh giá sản phẩm',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (page != null)
                Text(
                  '${page.ratingAverage.toStringAsFixed(1)} ★ · ${page.total}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (snapshot.hasError)
            Row(
              children: [
                Expanded(child: Text(_friendly(snapshot.error!))),
                TextButton(onPressed: _reload, child: const Text('Thử lại')),
              ],
            )
          else if ((page?.items ?? []).isEmpty)
            const Text(
              'Chưa có đánh giá nào cho sản phẩm này.',
              style: TextStyle(color: Colors.black54),
            )
          else
            ...(page!.items.map((review) => _ReviewTile(review: review))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _writeReview,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rate_review_outlined),
            label: const Text('Viết đánh giá'),
          ),
        ],
      );
    },
  );

  String _friendly(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ProductReview review;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.userName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 15,
                  color: const Color(0xFFE4A500),
                ),
              ),
            ),
          ],
        ),
        if (review.comment?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(review.comment!, style: const TextStyle(height: 1.4)),
        ],
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}
