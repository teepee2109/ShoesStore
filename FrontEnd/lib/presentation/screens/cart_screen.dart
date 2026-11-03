import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/cart.dart';
import '../../providers/cart_provider.dart';
import '../widgets/async_error_view.dart';
import '../widgets/store_widgets.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    if (cart.cart == null) unawaited(cart.loadCart());
  }

  @override
  Widget build(BuildContext context) => Consumer<CartProvider>(
    builder: (context, provider, child) {
      final cart = provider.cart;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Your bag',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (cart != null)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Text(
                    '${cart.itemCount} ITEMS',
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: provider.isLoading && cart == null
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null && cart == null
            ? AsyncErrorView(error: provider.error!, onRetry: provider.loadCart)
            : cart == null || cart.items.isEmpty
            ? _EmptyCart(onShop: () => context.go('/search'))
            : _buildCart(context, provider, cart),
      );
    },
  );

  Widget _buildCart(
    BuildContext context,
    CartProvider provider,
    Cart cart,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
    children: [
      const Text(
        'ITEMS IN YOUR BAG',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: Colors.black54,
        ),
      ),
      const SizedBox(height: 14),
      ...cart.items.map(
        (item) => _CartLineTile(
          item: item,
          isUpdating: provider.updatingItems.contains(item.id),
          onQuantityChanged: (quantity) async {
            try {
              await provider.updateQuantity(item, quantity);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }
          },
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.local_shipping_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Miễn phí giao hàng tiêu chuẩn cho mọi đơn hàng.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          const Text('Tạm tính', style: TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(
            formatVnd(cart.subtotal),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 9),
      const Row(
        children: [
          Text('Giao hàng', style: TextStyle(color: Colors.black54)),
          Spacer(),
          Text('Miễn phí', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      const Divider(height: 28),
      Row(
        children: [
          const Text(
            'Tổng cộng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            formatVnd(cart.subtotal),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => context.push('/checkout'),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Tiến hành thanh toán'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD7F542),
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(54),
        ),
      ),
      if (provider.error != null) ...[
        const SizedBox(height: 8),
        Text(
          'Giỏ hàng chưa được đồng bộ: ${provider.error}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 11),
        ),
        TextButton(
          onPressed: () => provider.loadCart(force: true),
          child: const Text('Tải lại giỏ hàng'),
        ),
      ],
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Thanh toán an toàn · Đổi trả dễ dàng',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
    ],
  );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.black26,
          ),
          const SizedBox(height: 18),
          const Text(
            'Túi hàng đang trống',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Khám phá những đôi giày phù hợp với bạn.'),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onShop,
            child: const Text('Khám phá sản phẩm'),
          ),
        ],
      ),
    ),
  );
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
    required this.isUpdating,
    required this.onQuantityChanged,
  });

  final CartItem item;
  final bool isUpdating;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 96,
            height: 106,
            child: item.imageUrl == null
                ? const _ImagePlaceholder()
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _ImagePlaceholder(),
                  ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: isUpdating ? null : () => onQuantityChanged(0),
                    icon: const Icon(Icons.close, size: 19),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Xóa sản phẩm',
                  ),
                ],
              ),
              Text(
                '${item.color} · Size ${item.size}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE6E6E2)),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuantityButton(
                          icon: Icons.remove,
                          onPressed: isUpdating
                              ? null
                              : () => onQuantityChanged(item.quantity - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: isUpdating
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        _QuantityButton(
                          icon: Icons.add,
                          onPressed: isUpdating || item.quantity >= item.stock
                              ? null
                              : () => onQuantityChanged(item.quantity + 1),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatVnd(item.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF0F0EC),
    child: Center(
      child: Icon(
        Icons.directions_run_rounded,
        size: 38,
        color: Colors.black26,
      ),
    ),
  );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    constraints: const BoxConstraints.tightFor(width: 31, height: 31),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );
}
