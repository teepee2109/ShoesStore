import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../data/models/cart.dart';
import '../data/repositories/cart_repository.dart';

class CartProvider extends ChangeNotifier {
  CartProvider(this._repository);

  final CartRepository _repository;
  Cart? cart;
  Cart? _serverCart;
  Object? error;
  bool isLoading = false;
  final Set<int> updatingItems = {};
  final Map<int, int> _pendingQuantities = {};
  Future<void> _mutationQueue = Future<void>.value();
  int _sessionGeneration = 0;

  Future<void> loadCart({bool force = false}) async {
    if (isLoading || (cart != null && !force)) return;
    final generation = _sessionGeneration;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.getCart();
      if (generation == _sessionGeneration) {
        _serverCart = result;
        cart = _applyPending(result);
      }
    } catch (value) {
      if (generation == _sessionGeneration) error = value;
    } finally {
      if (generation == _sessionGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Cart> addItem({required int variantId, int quantity = 1}) async {
    final generation = _sessionGeneration;
    try {
      final result = await _repository.addItem(
        variantId: variantId,
        quantity: quantity,
      );
      if (generation == _sessionGeneration) {
        _serverCart = result;
        cart = _applyPending(result);
        error = null;
        notifyListeners();
      }
      return result;
    } catch (value) {
      if (generation == _sessionGeneration) {
        error = value;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> updateQuantity(CartItem item, int quantity) {
    if (updatingItems.contains(item.id)) return Future<void>.value();
    final baseCart = _serverCart ?? cart;
    if (baseCart == null) {
      return Future<void>.error(
        const ApiException('Giỏ hàng chưa tải xong. Hãy thử lại.'),
      );
    }
    final currentItem = baseCart.items.where((entry) => entry.id == item.id);
    final serverItem = currentItem.isEmpty ? item : currentItem.first;
    if (quantity > serverItem.stock) {
      final stockError = ApiException(
        'Chỉ còn ${serverItem.stock} sản phẩm ${serverItem.productName} size ${serverItem.size} trong kho.',
        statusCode: 409,
      );
      error = stockError;
      notifyListeners();
      return Future<void>.error(stockError);
    }

    _pendingQuantities[item.id] = quantity;
    updatingItems.add(item.id);
    final generation = _sessionGeneration;
    cart = _applyPending(baseCart);
    error = null;
    notifyListeners();

    final operation = _mutationQueue.then((_) async {
      try {
        if (generation != _sessionGeneration) {
          throw const ApiException('Phiên đăng nhập đã thay đổi.');
        }
        final result = quantity <= 0
            ? await _repository.removeItem(item.id)
            : await _repository.updateItem(itemId: item.id, quantity: quantity);
        if (generation == _sessionGeneration) {
          _serverCart = result;
          error = null;
        }
      } catch (value) {
        if (generation == _sessionGeneration) error = value;
        rethrow;
      } finally {
        if (generation == _sessionGeneration) {
          _pendingQuantities.remove(item.id);
          updatingItems.remove(item.id);
          final latestServerCart = _serverCart;
          if (latestServerCart != null) cart = _applyPending(latestServerCart);
          notifyListeners();
        }
      }
    });
    _mutationQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Cart _applyPending(Cart base) {
    if (_pendingQuantities.isEmpty) return base;
    final items = <CartItem>[];
    for (final item in base.items) {
      final pendingQuantity = _pendingQuantities[item.id];
      if (pendingQuantity == null) {
        items.add(item);
      } else if (pendingQuantity > 0) {
        items.add(item.withQuantity(pendingQuantity));
      }
    }
    return base.withItems(items);
  }

  void reset() {
    ++_sessionGeneration;
    cart = null;
    _serverCart = null;
    error = null;
    isLoading = false;
    updatingItems.clear();
    _pendingQuantities.clear();
    _mutationQueue = Future<void>.value();
    notifyListeners();
  }
}
