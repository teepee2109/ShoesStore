import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/cart.dart';
import '../../data/models/shipping_address.dart';
import '../../data/models/store_order.dart';
import '../../data/repositories/address_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../providers/cart_provider.dart';
import '../widgets/async_error_view.dart';
import '../widgets/store_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _lineController = TextEditingController();
  final _cityController = TextEditingController();
  late final AddressRepository _addressRepository;
  late final OrderRepository _orderRepository;
  late final PaymentRepository _paymentRepository;
  List<ShippingAddress> _addresses = const [];
  ShippingAddress? _selectedAddress;
  Object? _error;
  bool _loading = true;
  bool _savingAddress = false;
  bool _placingOrder = false;
  String _paymentMethod = 'cod';

  @override
  void initState() {
    super.initState();
    _addressRepository = context.read<AddressRepository>();
    _orderRepository = context.read<OrderRepository>();
    _paymentRepository = context.read<PaymentRepository>();
    unawaited(_loadCheckout());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _lineController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cartProvider = context.read<CartProvider>();
      if (cartProvider.cart == null) await cartProvider.loadCart(force: true);
      if (cartProvider.error != null && cartProvider.cart == null) {
        throw cartProvider.error!;
      }
      final addresses = await _addressRepository.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddress ??=
            addresses.where((address) => address.isDefault).firstOrNull ??
            (addresses.isEmpty ? null : addresses.first);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_addressFormKey.currentState!.validate()) return;
    setState(() => _savingAddress = true);
    try {
      final address = await _addressRepository.createAddress(
        receiverName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        addressLine: _lineController.text.trim(),
        city: _cityController.text.trim(),
        isDefault: _addresses.isEmpty,
      );
      if (!mounted) return;
      setState(() {
        _addresses = [..._addresses, address];
        _selectedAddress = address;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu địa chỉ giao hàng.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _placeOrder() async {
    final address = _selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn hoặc thêm địa chỉ giao hàng.')),
      );
      return;
    }
    setState(() => _placingOrder = true);
    final cartProvider = context.read<CartProvider>();
    StoreOrder? createdOrder;
    try {
      createdOrder = await _orderRepository.createOrder(
        addressId: address.id,
        paymentMethod: _paymentMethod,
      );
      await cartProvider.loadCart(force: true);
      if (!mounted) return;
      if (_paymentMethod == 'vnpay') {
        final payment = await _paymentRepository.createVnpay(createdOrder.id);
        if (mounted) context.push('/payments/vnpay', extra: payment);
      } else {
        context.go('/orders/${createdOrder.id}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        if (createdOrder != null) context.go('/orders/${createdOrder.id}');
      }
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<CartProvider>(
    builder: (context, cartProvider, child) {
      if (_loading && cartProvider.cart == null) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.pop()),
            title: const Text('Checkout'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (_error != null && cartProvider.cart == null) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.pop()),
            title: const Text('Checkout'),
          ),
          body: AsyncErrorView(error: _error!, onRetry: _loadCheckout),
        );
      }
      final cart = cartProvider.cart;
      if (cart == null || cart.items.isEmpty) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.pop()),
            title: const Text('Checkout'),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 54,
                  color: Colors.black26,
                ),
                const SizedBox(height: 12),
                const Text('Giỏ hàng đang trống.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/search'),
                  child: const Text('Tiếp tục mua sắm'),
                ),
              ],
            ),
          ),
        );
      }
      return _buildCheckout(cart);
    },
  );

  Widget _buildCheckout(Cart cart) {
    // The current order API stores the product subtotal and has no shipping field.
    const shipping = 0;
    final total = cart.subtotal + shipping;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Không tải được địa chỉ: $_error')),
                  TextButton(
                    onPressed: _loadCheckout,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _StepHeader(),
          const SizedBox(height: 22),
          const _SectionTitle(number: '01', title: 'Địa chỉ giao hàng'),
          const SizedBox(height: 12),
          if (_addresses.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              key: ValueKey(_selectedAddress?.id),
              initialValue: _selectedAddress?.id,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: _addresses
                  .map(
                    (address) => DropdownMenuItem(
                      value: address.id,
                      child: Text(
                        '${address.receiverName} · ${address.city}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() {
                _selectedAddress = _addresses
                    .where((address) => address.id == id)
                    .firstOrNull;
              }),
            ),
            if (_selectedAddress != null) ...[
              const SizedBox(height: 9),
              _AddressCard(address: _selectedAddress!),
            ],
          ],
          const SizedBox(height: 12),
          _NewAddressForm(
            formKey: _addressFormKey,
            nameController: _nameController,
            phoneController: _phoneController,
            lineController: _lineController,
            cityController: _cityController,
            saving: _savingAddress,
            onSave: _saveAddress,
          ),
          const SizedBox(height: 24),
          const _SectionTitle(number: '02', title: 'Phương thức thanh toán'),
          const SizedBox(height: 12),
          _PaymentOption(
            value: 'cod',
            groupValue: _paymentMethod,
            title: 'Thanh toán khi nhận hàng',
            subtitle: 'Tiền mặt hoặc thẻ khi giao đến',
            icon: Icons.payments_outlined,
            onChanged: (value) => setState(() => _paymentMethod = value),
          ),
          const SizedBox(height: 9),
          _PaymentOption(
            value: 'vnpay',
            groupValue: _paymentMethod,
            title: 'VNPay',
            subtitle: 'Thanh toán trực tuyến',
            icon: Icons.qr_code_2_rounded,
            onChanged: (value) => setState(() => _paymentMethod = value),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(number: '03', title: 'Tóm tắt đơn hàng'),
          const SizedBox(height: 10),
          ...cart.items.map((item) => _CheckoutLine(item: item)),
          const Divider(height: 25),
          _SummaryRow(label: 'Tạm tính', value: formatVnd(cart.subtotal)),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Giao hàng',
            value: shipping == 0 ? 'Miễn phí' : formatVnd(shipping),
          ),
          const Divider(height: 25),
          _SummaryRow(
            label: 'Tổng cộng',
            value: formatVnd(total),
            emphasized: true,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _placingOrder || _selectedAddress == null
                ? null
                : _placeOrder,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD7F542),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(54),
            ),
            child: _placingOrder
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Đặt hàng · ${formatVnd(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Bằng cách đặt hàng, bạn đồng ý với điều khoản mua hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final ShippingAddress address;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${address.receiverName} · ${address.phone}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                '${address.addressLine}, ${address.city}',
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NewAddressForm extends StatelessWidget {
  const _NewAddressForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.lineController,
    required this.cityController,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController lineController;
  final TextEditingController cityController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(
      nameController.text.isEmpty
          ? 'Thêm địa chỉ mới'
          : 'Thêm / cập nhật địa chỉ',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    childrenPadding: const EdgeInsets.only(bottom: 10),
    children: [
      Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Người nhận'),
              validator: _required,
            ),
            const SizedBox(height: 9),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: (value) {
                if (value == null ||
                    !RegExp(r'^\+?[0-9\s-]{9,20}$').hasMatch(value.trim())) {
                  return 'Số điện thoại chưa hợp lệ.';
                }
                return null;
              },
            ),
            const SizedBox(height: 9),
            TextFormField(
              controller: lineController,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
              validator: (value) => value == null || value.trim().length < 5
                  ? 'Nhập địa chỉ chi tiết.'
                  : null,
            ),
            const SizedBox(height: 9),
            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'Tỉnh / thành phố'),
              validator: _required,
            ),
            const SizedBox(height: 11),
            OutlinedButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu địa chỉ'),
            ),
          ],
        ),
      ),
    ],
  );

  static String? _required(String? value) =>
      value == null || value.trim().length < 2
      ? 'Trường này là bắt buộc.'
      : null;
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 54,
            height: 54,
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${item.color} · Size ${item.size} · Qty ${item.quantity}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        Text(
          formatVnd(item.lineTotal),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const _StepDot(number: '1', label: 'Bag', active: true),
      Expanded(child: Container(height: 1, color: Colors.black12)),
      const _StepDot(number: '2', label: 'Checkout', active: true),
      Expanded(child: Container(height: 1, color: Colors.black12)),
      const _StepDot(number: '3', label: 'Done', active: false),
    ],
  );
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.label,
    required this.active,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: active ? const Color(0xFFD7F542) : Colors.black12,
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: active ? Colors.black : Colors.black45,
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        number,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black45,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? Colors.black : Colors.black38,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: emphasized ? 16 : 13,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
          color: emphasized ? Colors.black : Colors.black54,
        ),
      ),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          fontSize: emphasized ? 18 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
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
        size: 30,
        color: Colors.black26,
      ),
    ),
  );
}
