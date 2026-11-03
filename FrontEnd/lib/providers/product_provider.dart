import 'package:flutter/foundation.dart' hide Category;

import '../data/models/category.dart';
import '../data/models/product.dart';
import '../data/repositories/product_repository.dart';

class ProductCatalogState {
  List<Product> products = const [];
  Object? error;
  Object? loadMoreError;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasLoaded = false;
  int page = 1;
  int total = 0;
  int totalPages = 0;
  int generation = 0;
  String query = '';
  String? category;
  String sort = 'latest';
  double? minPrice;
  double? maxPrice;
  String? size;
  String? color;

  bool get hasMore => page < totalPages;
}

class ProductProvider extends ChangeNotifier {
  ProductProvider(this._repository);

  final ProductRepository _repository;
  static const _pageSize = 20;
  final Map<String, ProductCatalogState> _catalogs = {};

  ProductCatalogState catalog(String scope) =>
      _catalogs.putIfAbsent(scope, ProductCatalogState.new);

  List<Category> categories = const [];
  Product? detailProduct;
  String? detailProductId;
  Object? categoriesError;
  Object? detailError;
  bool isLoadingCategories = false;
  bool isLoadingDetail = false;
  int _detailGeneration = 0;

  Future<void> loadInitial({
    String scope = 'search',
    String? query,
    String? category,
    String? sort,
    double? minPrice,
    double? maxPrice,
    String? size,
    String? color,
  }) async {
    final state = catalog(scope);
    state.query = query?.trim() ?? '';
    state.category = category;
    state.sort = sort ?? 'latest';
    state.minPrice = minPrice;
    state.maxPrice = maxPrice;
    state.size = size;
    state.color = color;

    final generation = ++state.generation;
    state.isLoading = true;
    state.isLoadingMore = false;
    state.error = null;
    state.loadMoreError = null;
    state.products = const [];
    state.page = 1;
    state.total = 0;
    state.totalPages = 0;
    state.hasLoaded = false;
    notifyListeners();
    try {
      final result = await _repository.getProducts(
        query: state.query,
        category: state.category,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        size: state.size,
        color: state.color,
        sort: state.sort,
        page: 1,
        limit: _pageSize,
      );
      if (generation != state.generation) return;
      state.products = result.items;
      state.page = result.page;
      state.total = result.total;
      state.totalPages = result.totalPages;
      state.hasLoaded = true;
    } catch (value) {
      if (generation != state.generation) return;
      state.error = value;
    } finally {
      if (generation == state.generation) {
        state.isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({String scope = 'search'}) async {
    final state = catalog(scope);
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.error != null) {
      return;
    }
    final generation = state.generation;
    final nextPage = state.page + 1;
    state.isLoadingMore = true;
    state.loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getProducts(
        query: state.query,
        category: state.category,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        size: state.size,
        color: state.color,
        sort: state.sort,
        page: nextPage,
        limit: _pageSize,
      );
      if (generation != state.generation) return;
      state.products = [...state.products, ...result.items];
      state.page = result.page;
      state.total = result.total;
      state.totalPages = result.totalPages;
    } catch (value) {
      if (generation == state.generation) state.loadMoreError = value;
    } finally {
      if (generation == state.generation) {
        state.isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryInitial({String scope = 'search'}) {
    final state = catalog(scope);
    return loadInitial(
      scope: scope,
      query: state.query,
      category: state.category,
      sort: state.sort,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
      size: state.size,
      color: state.color,
    );
  }

  Future<void> retryLoadMore({String scope = 'search'}) =>
      loadMore(scope: scope);

  Future<void> loadCategories({bool force = false}) async {
    if (isLoadingCategories || (categories.isNotEmpty && !force)) return;
    isLoadingCategories = true;
    categoriesError = null;
    notifyListeners();
    try {
      categories = await _repository.getCategories();
    } catch (value) {
      categoriesError = value;
    } finally {
      isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<Product?> loadProduct(String id, {bool force = false}) async {
    if (!force && detailProductId == id && detailProduct != null) {
      return detailProduct;
    }
    final generation = ++_detailGeneration;
    detailProductId = id;
    detailProduct = null;
    detailError = null;
    isLoadingDetail = true;
    notifyListeners();
    try {
      final product = await _repository.getProduct(id);
      if (generation != _detailGeneration) return null;
      detailProduct = product;
      return product;
    } catch (value) {
      if (generation == _detailGeneration) detailError = value;
      return null;
    } finally {
      if (generation == _detailGeneration) {
        isLoadingDetail = false;
        notifyListeners();
      }
    }
  }
}
