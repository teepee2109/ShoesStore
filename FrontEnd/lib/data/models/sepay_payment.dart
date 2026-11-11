class SePayPaymentSession {
  const SePayPaymentSession({
    required this.paymentId,
    required this.orderId,
    required this.checkoutUrl,
    required this.formFields,
    required this.returnUrl,
  });

  final int paymentId;
  final int orderId;
  final String checkoutUrl;
  final Map<String, String> formFields;
  final String returnUrl;

  factory SePayPaymentSession.fromJson(Map<String, dynamic> json) {
    final rawFields = json['form_fields'];
    final fields = rawFields is Map
        ? rawFields.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};
    return SePayPaymentSession(
      paymentId: _toInt(json['payment_id']),
      orderId: _toInt(json['order_id']),
      checkoutUrl: json['checkout_url']?.toString() ?? '',
      formFields: fields,
      returnUrl: json['return_url']?.toString() ?? '',
    );
  }
}

class SePayPaymentResult {
  const SePayPaymentResult({
    required this.orderId,
    required this.paymentStatus,
    required this.attemptStatus,
    required this.returnStatus,
  });

  final int orderId;
  final String paymentStatus;
  final String attemptStatus;
  final String returnStatus;

  bool get successful => paymentStatus == 'paid';

  factory SePayPaymentResult.fromJson(
    Map<String, dynamic> json, {
    required String returnStatus,
  }) =>
      SePayPaymentResult(
        orderId: _toInt(json['order_id']),
        paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
        attemptStatus: json['attempt_status']?.toString() ?? 'pending',
        returnStatus: returnStatus,
      );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
