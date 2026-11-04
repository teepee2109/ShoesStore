import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/shipping_address.dart';
import '../../data/repositories/address_repository.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late final AddressRepository _repository;
  late Future<List<ShippingAddress>> _addresses;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AddressRepository>();
    _addresses = _repository.getAddresses();
  }

  void _reload() {
    final addresses = _repository.getAddresses();
    setState(() {
      _addresses = addresses;
    });
  }

  Future<void> _edit([ShippingAddress? address]) async {
    final result = await showDialog<_AddressDraft>(
      context: context,
      builder: (_) => _AddressDialog(address: address),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      if (address == null) {
        await _repository.createAddress(
          receiverName: result.receiverName,
          phone: result.phone,
          addressLine: result.addressLine,
          city: result.city,
          isDefault: result.isDefault,
        );
      } else {
        await _repository.updateAddress(
          id: address.id,
          receiverName: result.receiverName,
          phone: result.phone,
          addressLine: result.addressLine,
          city: result.city,
          isDefault: result.isDefault,
        );
      }
      _reload();
    } catch (error) {
      _notice(_friendly(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(ShippingAddress address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa địa chỉ?'),
        content: Text('Bạn muốn xóa địa chỉ của ${address.receiverName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repository.deleteAddress(address.id);
      _reload();
    } catch (error) {
      _notice(_friendly(error));
    }
  }

  String _friendly(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Địa chỉ giao hàng',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : () => _edit(),
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Thêm địa chỉ'),
    ),
    body: FutureBuilder<List<ShippingAddress>>(
      future: _addresses,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_friendly(snapshot.error!)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        final addresses = snapshot.data ?? const [];
        if (addresses.isEmpty) {
          return const Center(child: Text('Bạn chưa lưu địa chỉ giao hàng.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: addresses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final address = addresses[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.receiverName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (address.isDefault)
                          const Chip(
                            label: Text('Mặc định'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    Text(address.phone),
                    const SizedBox(height: 4),
                    Text('${address.addressLine}, ${address.city}'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _saving ? null : () => _edit(address),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Sửa'),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : () => _delete(address),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Xóa'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _AddressDraft {
  const _AddressDraft(
    this.receiverName,
    this.phone,
    this.addressLine,
    this.city,
    this.isDefault,
  );
  final String receiverName, phone, addressLine, city;
  final bool isDefault;
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.address});
  final ShippingAddress? address;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.address?.receiverName ?? '',
  );
  late final _phone = TextEditingController(text: widget.address?.phone ?? '');
  late final _line = TextEditingController(
    text: widget.address?.addressLine ?? '',
  );
  late final _city = TextEditingController(text: widget.address?.city ?? '');
  late bool _default = widget.address?.isDefault ?? true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line.dispose();
    _city.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().length < 2
      ? 'Vui lòng nhập ít nhất 2 ký tự.'
      : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.address == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Người nhận'),
                validator: _required,
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (value) =>
                    value == null ||
                        value.replaceAll(RegExp(r'[^0-9]'), '').length < 9
                    ? 'Số điện thoại chưa hợp lệ.'
                    : null,
              ),
              TextFormField(
                controller: _line,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                validator: _required,
              ),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'Tỉnh / thành phố',
                ),
                validator: _required,
              ),
              CheckboxListTile(
                value: _default,
                onChanged: (value) => setState(() => _default = value ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text('Đặt làm địa chỉ mặc định'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _AddressDraft(
              _name.text.trim(),
              _phone.text.trim(),
              _line.text.trim(),
              _city.text.trim(),
              _default,
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
