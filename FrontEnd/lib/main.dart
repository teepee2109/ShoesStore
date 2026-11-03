import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/dio_client.dart';
import 'core/storage/token_storage.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/datasources/address_remote_data_source.dart';
import 'data/datasources/cart_remote_data_source.dart';
import 'data/datasources/chat_socket_data_source.dart';
import 'data/datasources/notification_remote_data_source.dart';
import 'data/datasources/order_remote_data_source.dart';
import 'data/datasources/payment_remote_data_source.dart';
import 'data/datasources/product_remote_data_source.dart';
import 'data/datasources/review_remote_data_source.dart';
import 'data/datasources/wishlist_remote_data_source.dart';
import 'data/repositories/cart_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/address_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/wishlist_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/product_provider.dart';
import 'providers/wishlist_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage(SharedPreferencesAsync());
  late final AuthProvider authProvider;
  final dioClient = DioClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () => authProvider.handleUnauthorized(),
  );
  final authRepository = AuthRepository(AuthRemoteDataSource(dioClient));
  final productRepository = ProductRepository(
    ProductRemoteDataSource(dioClient),
  );
  final wishlistRepository = WishlistRepository(
    WishlistRemoteDataSource(dioClient),
  );
  final cartRepository = CartRepository(CartRemoteDataSource(dioClient));
  final orderRepository = OrderRepository(OrderRemoteDataSource(dioClient));
  final paymentRepository = PaymentRepository(
    PaymentRemoteDataSource(dioClient),
  );
  final addressRepository = AddressRepository(
    AddressRemoteDataSource(dioClient),
  );
  final notificationRepository = NotificationRepository(
    NotificationRemoteDataSource(dioClient),
  );
  final reviewRepository = ReviewRepository(ReviewRemoteDataSource(dioClient));
  final chatRepository = ChatRepository(ChatSocketDataSource(tokenStorage));
  authProvider = AuthProvider(authRepository, tokenStorage);
  final cartProvider = CartProvider(cartRepository);
  final productProvider = ProductProvider(productRepository);
  final wishlistProvider = WishlistProvider(wishlistRepository);
  final notificationProvider = NotificationProvider(notificationRepository);
  final chatProvider = ChatProvider(chatRepository);
  int? activeUserId;
  authProvider.addListener(() {
    final userId = authProvider.user?.id;
    if (userId == activeUserId) return;
    activeUserId = userId;
    cartProvider.reset();
    wishlistProvider.reset();
    notificationProvider.reset();
    chatProvider.reset();
    if (userId != null) {
      unawaited(cartProvider.loadCart(force: true));
      unawaited(wishlistProvider.load(force: true));
      notificationProvider.startPolling();
    }
  });
  unawaited(authProvider.restoreSession());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: cartProvider),
        ChangeNotifierProvider.value(value: productProvider),
        ChangeNotifierProvider.value(value: wishlistProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        Provider.value(value: dioClient),
        Provider.value(value: authRepository),
        Provider.value(value: productRepository),
        Provider.value(value: wishlistRepository),
        Provider.value(value: cartRepository),
        Provider.value(value: orderRepository),
        Provider.value(value: paymentRepository),
        Provider.value(value: addressRepository),
        Provider.value(value: notificationRepository),
        Provider.value(value: reviewRepository),
        Provider.value(value: chatRepository),
      ],
      child: StoreApp(authProvider: authProvider),
    ),
  );
}
