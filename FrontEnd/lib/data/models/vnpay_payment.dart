class VnpayPaymentSession {
  const VnpayPaymentSession({
    required this.paymentId,
    required this.orderId,
    required this.paymentUrl,
    required this.returnUrl,
    required this.expiresAt,
  });

  final int paymentId;
  final int orderId;
  final String paymentUrl;
  final String returnUrl;
  final String expiresAt;

  factory VnpayPaymentSession.fromJson(Map<String, dynamic> json) =>
      VnpayPaymentSession(
        paymentId: _toInt(json['payment_id']),
        orderId: _toInt(json['order_id']),
        paymentUrl: json['payment_url']?.toString() ?? '',
        returnUrl: json['return_url']?.toString() ?? '',
        expiresAt: json['expires_at']?.toString() ?? '',
      );
}

class VnpayPaymentResult {
  const VnpayPaymentResult({
    required this.orderId,
    required this.paymentId,
    required this.paymentStatus,
    required this.attemptStatus,
    required this.successful,
    required this.responseCode,
    required this.transactionStatus,
  });

  final int orderId;
  final int paymentId;
  final String paymentStatus;
  final String attemptStatus;
  final bool successful;
  final String responseCode;
  final String transactionStatus;

  factory VnpayPaymentResult.fromJson(Map<String, dynamic> json) =>
      VnpayPaymentResult(
        orderId: _toInt(json['order_id']),
        paymentId: _toInt(json['payment_id']),
        paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
        attemptStatus: json['attempt_status']?.toString() ?? 'pending',
        successful: json['successful'] == true,
        responseCode: json['response_code']?.toString() ?? '',
        transactionStatus: json['transaction_status']?.toString() ?? '',
      );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
