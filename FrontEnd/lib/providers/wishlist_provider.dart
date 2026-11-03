import 'package:flutter/foundation.dart';

import '../data/models/product.dart';
import '../data/repositories/wishlist_repository.dart';

class WishlistProvider extends ChangeNotifier {
  WishlistProvider(this._repository);

  final WishlistRepository _repository;
  List<Product> products = const [];
  Object? error;
  bool isLoading = false;
  bool hasLoaded = false;
  bool isMutating = false;
  int? updatingProductId;
  int _generation = 0;

  bool contains(int productId) =>
      products.any((product) => product.id == productId);

  Future<void> load({bool force = false}) async {
    if (isLoading || isMutating || (hasLoaded && !force)) return;
    final generation = ++_generation;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.getWishlist();
      if (generation != _generation) return;
      products = result;
      hasLoaded = true;
    } catch (value) {
      if (generation == _generation) error = value;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggle(Product product) async {
    if (isMutating || isLoading) return;
    final generation = _generation;
    final wasSaved = contains(product.id);
    final previousProducts = products;
    isMutating = true;
    updatingProductId = product.id;
    products = wasSaved
        ? products.where((saved) => saved.id != product.id).toList()
        : [...products, product];
    error = null;
    notifyListeners();

    try {
      final result = wasSaved
          ? await _repository.removeItem(product.id)
          : await _repository.addItem(product.id);
      if (generation == _generation) {
        products = result;
        hasLoaded = true;
      }
    } catch (value) {
      if (generation == _generation) {
        products = previousProducts;
        error = value;
      }
      rethrow;
    } finally {
      if (generation == _generation) {
        isMutating = false;
        updatingProductId = null;
        notifyListeners();
      }
    }
  }

  void reset() {
    ++_generation;
    products = const [];
    error = null;
    isLoading = false;
    hasLoaded = false;
    isMutating = false;
    updatingProductId = null;
    notifyListeners();
  }
}
