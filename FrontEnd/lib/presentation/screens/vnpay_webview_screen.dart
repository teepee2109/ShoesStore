import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/models/vnpay_payment.dart';
import '../../data/repositories/payment_repository.dart';

class VnpayWebViewScreen extends StatefulWidget {
  const VnpayWebViewScreen({super.key, required this.payment});

  final VnpayPaymentSession payment;

  @override
  State<VnpayWebViewScreen> createState() => _VnpayWebViewScreenState();
}

class _VnpayWebViewScreenState extends State<VnpayWebViewScreen> {
  late final WebViewController _controller;
  late final PaymentRepository _paymentRepository;
  VnpayPaymentResult? _result;
  Object? _error;
  bool _isLoading = true;
  bool _handlingReturn = false;

  @override
  void initState() {
    super.initState();
    _paymentRepository = context.read<PaymentRepository>();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted && _result == null && _error == null) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted && _result == null && _error == null) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted && !_handlingReturn) {
              setState(() {
                _isLoading = false;
                _error = 'Không tải được trang thanh toán. Hãy thử lại.';
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isReturnUrl(uri)) {
              unawaited(_handleReturn(uri));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.payment.paymentUrl));
  }

  bool _isReturnUrl(Uri uri) {
    final expected = Uri.tryParse(widget.payment.returnUrl);
    return expected != null &&
        uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        uri.port == expected.port &&
        uri.path == expected.path;
  }

  Future<void> _handleReturn(Uri uri) async {
    if (_handlingReturn) return;
    _handlingReturn = true;
    if (mounted) setState(() => _isLoading = true);
    try {
      final result = await _paymentRepository.verifyVnpayReturn(
        uri.queryParameters,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(
        onPressed: () => context.go('/orders/${widget.payment.orderId}'),
      ),
      title: const Text(
        'Thanh toán VNPay',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: _result != null
        ? _buildResult(_result!)
        : _error != null
        ? _buildError(_error!)
        : Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
  );

  Widget _buildResult(VnpayPaymentResult result) {
    final confirmed = result.paymentStatus == 'paid';
    final success = result.successful;
    final title = confirmed
        ? 'Thanh toán thành công'
        : success
        ? 'Đang xác nhận thanh toán'
        : 'Thanh toán chưa hoàn tất';
    final detail = confirmed
        ? 'Đơn hàng #${result.orderId} đã được xác nhận thanh toán.'
        : success
        ? 'VNPay đã trả kết quả thành công. Hệ thống đang chờ IPN xác nhận giao dịch.'
        : 'Giao dịch chưa thành công (mã ${result.responseCode}). Bạn có thể kiểm tra lại đơn hàng.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              confirmed
                  ? Icons.check_circle_rounded
                  : success
                  ? Icons.hourglass_top_rounded
                  : Icons.error_outline_rounded,
              size: 64,
              color: confirmed
                  ? Colors.green
                  : success
                  ? Colors.orange
                  : Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.go('/orders/${result.orderId}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Quay lại đơn hàng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.black38),
          const SizedBox(height: 14),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go('/orders/${widget.payment.orderId}'),
            child: const Text('Quay lại đơn hàng'),
          ),
        ],
      ),
    ),
  );
}
