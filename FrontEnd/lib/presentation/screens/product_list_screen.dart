import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../widgets/async_error_view.dart';
import '../widgets/product_results_sliver.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.initialQuery});

  final String initialQuery;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late ProductProvider _products;
  Timer? _debounce;
  String _sort = 'latest';
  double? _minPrice;
  double? _maxPrice;
  String? _size;
  String? _color;

  @override
  void initState() {
    super.initState();
    _products = context.read<ProductProvider>();
    _searchController = TextEditingController(text: widget.initialQuery);
    _scrollController = ScrollController()..addListener(_onScroll);
    unawaited(_products.loadCategories());
    unawaited(
      _products.loadInitial(
        scope: 'search',
        query: widget.initialQuery,
        category: null,
        sort: _sort,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _searchController.text = widget.initialQuery;
      _products.catalog('search').category = null;
      unawaited(_applyFilters());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 420) {
      unawaited(_products.loadMore(scope: 'search'));
    }
  }

  Future<void> _applyFilters() async {
    await _products.loadInitial(
      scope: 'search',
      query: _searchController.text,
      category: _products.catalog('search').category,
      sort: _sort,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      size: _size,
      color: _color,
    );
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductFilterSheet(
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        size: _size,
        color: _color,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result['clear'] == true) {
        _minPrice = null;
        _maxPrice = null;
        _size = null;
        _color = null;
      } else {
        _minPrice = result['minPrice'] as double?;
        _maxPrice = result['maxPrice'] as double?;
        final size = (result['size'] as String?)?.trim();
        final color = (result['color'] as String?)?.trim();
        _size = size?.isEmpty == true ? null : size;
        _color = color?.isEmpty == true ? null : color;
      }
    });
    await _applyFilters();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_applyFilters());
    });
  }

  @override
  Widget build(BuildContext context) => Consumer<ProductProvider>(
    builder: (context, provider, child) {
      final catalog = provider.catalog('search');
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: _showFilters,
                tooltip: 'Lọc sản phẩm',
                icon: Badge(
                  isLabelVisible:
                      _minPrice != null ||
                      _maxPrice != null ||
                      _size != null ||
                      _color != null,
                  child: const Icon(Icons.tune_rounded),
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _sort,
                onSelected: (value) {
                  setState(() => _sort = value);
                  unawaited(_applyFilters());
                },
                icon: const Icon(Icons.sort_rounded),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'latest', child: Text('Mới nhất')),
                  PopupMenuItem(
                    value: 'price_asc',
                    child: Text('Giá thấp đến cao'),
                  ),
                  PopupMenuItem(
                    value: 'price_desc',
                    child: Text('Giá cao đến thấp'),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      _debounce?.cancel();
                      unawaited(_applyFilters());
                    },
                    decoration: InputDecoration(
                      hintText: 'Tìm giày, bộ sưu tập...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                unawaited(_applyFilters());
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CategoryFilters(
                    provider: provider,
                    selectedCategory: catalog.category,
                    onSelect: (slug) {
                      catalog.category = slug;
                      unawaited(_applyFilters());
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        '${catalog.total} styles',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        _sortLabel(_sort),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ProductResultsSliver(
            catalog: catalog,
            onRetry: () => provider.retryInitial(scope: 'search'),
            onRetryLoadMore: () => provider.retryLoadMore(scope: 'search'),
            emptyMessage: 'Không tìm thấy sản phẩm phù hợp.',
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        ],
      );
    },
  );

  String _sortLabel(String value) => switch (value) {
    'price_asc' => 'Giá thấp đến cao',
    'price_desc' => 'Giá cao đến thấp',
    _ => 'Mới nhất',
  };
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.provider,
    required this.selectedCategory,
    required this.onSelect,
  });

  final ProductProvider provider;
  final String? selectedCategory;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (provider.categoriesError != null && provider.categories.isEmpty) {
      return SizedBox(
        height: 74,
        child: AsyncErrorView(
          error: provider.categoriesError!,
          onRetry: () => provider.loadCategories(force: true),
        ),
      );
    }
    if (provider.isLoadingCategories && provider.categories.isEmpty) {
      return const SizedBox(
        height: 38,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (provider.categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: selectedCategory == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...provider.categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                category: category,
                selected: selectedCategory == category.slug,
                onSelect: onSelect,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelect,
  });

  final Category category;
  final bool selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(category.name),
    selected: selected,
    onSelected: (_) => onSelect(category.slug),
  );
}

class _ProductFilterSheet extends StatefulWidget {
  const _ProductFilterSheet({
    required this.minPrice,
    required this.maxPrice,
    required this.size,
    required this.color,
  });

  final double? minPrice;
  final double? maxPrice;
  final String? size;
  final String? color;

  @override
  State<_ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<_ProductFilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _minController = TextEditingController(
    text: widget.minPrice?.toStringAsFixed(0) ?? '',
  );
  late final _maxController = TextEditingController(
    text: widget.maxPrice?.toStringAsFixed(0) ?? '',
  );
  late final _sizeController = TextEditingController(text: widget.size ?? '');
  late final _colorController = TextEditingController(text: widget.color ?? '');

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  String? _validatePrice(
    String? value,
    String otherValue, {
    required bool isMinimum,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final price = double.tryParse(text);
    if (price == null || price < 0) return 'Nhập mức giá hợp lệ.';
    final otherText = otherValue.trim();
    if (otherText.isEmpty) return null;
    final otherPrice = double.tryParse(otherText);
    if (otherPrice == null || otherPrice < 0) return 'Nhập mức giá hợp lệ.';
    if (isMinimum && price > otherPrice) {
      return 'Giá từ cần nhỏ hơn hoặc bằng giá đến.';
    }
    if (!isMinimum && price < otherPrice) {
      return 'Giá đến cần lớn hơn hoặc bằng giá từ.';
    }
    return null;
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, Object?>{
      'minPrice': double.tryParse(_minController.text.trim()),
      'maxPrice': double.tryParse(_maxController.text.trim()),
      'size': _sizeController.text.trim(),
      'color': _colorController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lọc sản phẩm',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Giá từ',
                        suffixText: '₫',
                      ),
                      validator: (value) => _validatePrice(
                        value,
                        _maxController.text,
                        isMinimum: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Giá đến',
                        suffixText: '₫',
                      ),
                      validator: (value) => _validatePrice(
                        value,
                        _minController.text,
                        isMinimum: false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sizeController,
                      decoration: const InputDecoration(labelText: 'Size'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(labelText: 'Màu sắc'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop({'clear': true}),
                    child: const Text('Xóa bộ lọc'),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: _apply, child: const Text('Áp dụng')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
