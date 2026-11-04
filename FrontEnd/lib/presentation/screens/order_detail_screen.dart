import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../data/models/store_order.dart';
import '../../data/repositories/order_repository.dart';
import '../widgets/async_error_view.dart';
import '../widgets/store_widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderRepository _repository;
  late Future<StoreOrder> _order;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<OrderRepository>();
    _order = _loadOrder();
  }

  Future<StoreOrder> _loadOrder() {
    final id = int.tryParse(widget.orderId);
    if (id == null || id <= 0) return Future.error('Mã đơn hàng không hợp lệ.');
    return _repository.getOrder(id);
  }

  void _retry() {
    final order = _loadOrder();
    setState(() {
      _order = order;
    });
  }

  Future<void> _cancelOrder(StoreOrder order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text('Đơn hàng sẽ được hủy và tồn kho được hoàn lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final updatedOrder = await _repository.cancelOrder(order.id);
      if (mounted) {
        setState(() {
          _order = Future.value(updatedOrder);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
      ),
      title: const Text(
        'Order details',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: FutureBuilder<StoreOrder>(
      future: _order,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AsyncErrorView(error: snapshot.error!, onRetry: _retry);
        }
        final order = snapshot.data;
        if (order == null) {
          return AsyncErrorView(
            error: 'Không tìm thấy đơn hàng.',
            onRetry: _retry,
          );
        }
        return _buildOrder(context, order);
      },
    ),
  );

  Widget _buildOrder(BuildContext context, StoreOrder order) {
    final currentStep = switch (order.status) {
      'confirmed' => 1,
      'shipping' => 2,
      'delivered' => 3,
      _ => 0,
    };
    final isCancelled = order.status == 'cancelled';
    final canCancel =
        order.status == 'pending' &&
        (order.paymentStatus == 'unpaid' || order.paymentStatus == 'failed');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFD7F542),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDER NUMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '#${order.id}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đặt ngày ${_formatDate(order.createdAt)} · ${_statusLabel(order.status)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (isCancelled)
          const _InfoCard(
            icon: Icons.cancel_outlined,
            title: 'Đơn hàng đã hủy',
            detail: 'Tồn kho của sản phẩm đã được hoàn lại.',
          )
        else ...[
          const Text(
            'Theo dõi đơn hàng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 15),
          _TrackingTimeline(current: currentStep),
        ],
        const SizedBox(height: 24),
        const Text(
          'Sản phẩm',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (order.items.isEmpty)
          const _InfoCard(
            icon: Icons.inventory_2_outlined,
            title: 'Không có dòng sản phẩm',
            detail: 'Chi tiết sản phẩm chưa được trả về từ máy chủ.',
          )
        else
          ...order.items.map((item) => _OrderItemCard(item: item)),
        const SizedBox(height: 10),
        const Text(
          'Địa chỉ nhận hàng',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: order.shippingName?.isNotEmpty == true
              ? order.shippingName!
              : 'Người nhận',
          detail: [
            order.shippingAddress,
            order.shippingPhone,
          ].where((value) => value?.isNotEmpty == true).join('\n'),
        ),
        const SizedBox(height: 18),
        _InfoCard(
          icon: Icons.payments_outlined,
          title: _paymentLabel(order.paymentMethod),
          detail:
              'Trạng thái thanh toán: ${_paymentStatusLabel(order.paymentStatus)}',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Tổng thanh toán',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              formatVnd(order.totalAmount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (canCancel)
          OutlinedButton.icon(
            onPressed: _cancelling ? null : () => _cancelOrder(order),
            icon: _cancelling
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: const Text('Hủy đơn hàng'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: const Color(0xFF8A3030),
              side: const BorderSide(color: Color(0xFF8A3030)),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.push('/chat'),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Liên hệ cửa hàng'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  const _OrderItemCard({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 76,
            height: 76,
            child: _OrderImage(path: item.mainImage),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Size ${item.size} · ${item.color}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 5),
              Text(
                '${formatVnd(item.unitPrice)} × ${item.quantity}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatVnd(item.lineTotal),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _OrderImage extends StatelessWidget {
  const _OrderImage({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = path == null || path!.isEmpty
        ? null
        : (Uri.tryParse(path!)?.hasScheme ?? false)
        ? path
        : '${AppConfig.serverOrigin}${path!.startsWith('/') ? '' : '/'}$path';
    if (url == null) return const _ImagePlaceholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
    );
  }
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    const steps = ['Đã đặt hàng', 'Đã xác nhận', 'Đang giao', 'Đã giao'];
    return Column(
      children: List.generate(steps.length, (index) {
        final done = index <= current;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: done ? Colors.black : Colors.black26,
                  ),
                  if (index < steps.length - 1)
                    Container(
                      width: 1.5,
                      height: 27,
                      color: index < current ? Colors.black : Colors.black12,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                steps[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: done ? FontWeight.w700 : FontWeight.normal,
                  color: done ? Colors.black : Colors.black45,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  height: 1.4,
                ),
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

String _formatDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? value : DateFormat('dd/MM/yyyy · HH:mm').format(date);
}

String _statusLabel(String status) => switch (status) {
  'confirmed' => 'Đã xác nhận',
  'shipping' => 'Đang giao',
  'delivered' => 'Đã giao',
  'cancelled' => 'Đã hủy',
  _ => 'Đang xử lý',
};

String _paymentLabel(String method) => switch (method) {
  'vnpay' => 'VNPay',
  'momo' => 'MoMo',
  'paypal' => 'PayPal',
  _ => 'Thanh toán khi nhận hàng',
};

String _paymentStatusLabel(String status) => switch (status) {
  'paid' => 'Đã thanh toán',
  'failed' => 'Thanh toán thất bại',
  'refunded' => 'Đã hoàn tiền',
  _ => 'Chưa thanh toán',
};
