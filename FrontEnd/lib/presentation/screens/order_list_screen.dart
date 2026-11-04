import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/store_order.dart';
import '../../data/repositories/order_repository.dart';
import '../widgets/async_error_view.dart';
import '../widgets/store_widgets.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late final OrderRepository _repository;
  late Future<OrderPage> _orders;

  @override
  void initState() {
    super.initState();
    _repository = context.read<OrderRepository>();
    _orders = _repository.getOrders();
  }

  void _retry() {
    final orders = _repository.getOrders();
    setState(() {
      _orders = orders;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
      ),
      title: const Text(
        'My orders',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: FutureBuilder<OrderPage>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AsyncErrorView(error: snapshot.error!, onRetry: _retry);
        }
        final orders = snapshot.data?.items ?? const <StoreOrder>[];
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 54,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bạn chưa có đơn hàng nào.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/search'),
                    child: const Text('Khám phá sản phẩm'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _retry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            children: [
              const Text(
                'ORDER HISTORY',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 15),
              ...orders.map((order) => _OrderCard(order: order)),
            ],
          ),
        );
      },
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final StoreOrder order;

  @override
  Widget build(BuildContext context) {
    final itemNames = order.items
        .map((item) => item.productName)
        .toSet()
        .join(', ');
    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đơn hàng #${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _OrderStatus(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(order.createdAt),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const Divider(height: 25),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFF0F0EC),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemNames.isEmpty ? 'Đơn hàng Adidas' : itemNames,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${order.itemCount} sản phẩm',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black45),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  'Tổng cộng',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  formatVnd(order.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatus extends StatelessWidget {
  const _OrderStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'confirmed' => (
        'Đã xác nhận',
        const Color(0xFF3D57A1),
        const Color(0xFFE9EEFF),
      ),
      'shipping' => (
        'Đang giao',
        const Color(0xFF3D57A1),
        const Color(0xFFE9EEFF),
      ),
      'delivered' => (
        'Đã giao',
        const Color(0xFF28783A),
        const Color(0xFFE6F3E7),
      ),
      'cancelled' => (
        'Đã hủy',
        const Color(0xFF8A3030),
        const Color(0xFFF8E7E7),
      ),
      _ => ('Đang xử lý', const Color(0xFF3D57A1), const Color(0xFFE9EEFF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? value : DateFormat('dd/MM/yyyy · HH:mm').format(date);
}
