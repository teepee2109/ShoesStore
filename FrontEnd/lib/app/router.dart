import 'package:go_router/go_router.dart';

import '../presentation/screens/auth_screen.dart';
import '../presentation/screens/address_book_screen.dart';
import '../presentation/screens/cart_screen.dart';
import '../presentation/screens/chat_screen.dart';
import '../presentation/screens/checkout_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/order_detail_screen.dart';
import '../presentation/screens/order_list_screen.dart';
import '../presentation/screens/notifications_screen.dart';
import '../presentation/screens/product_detail_screen.dart';
import '../presentation/screens/product_list_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/wishlist_screen.dart';
import '../presentation/screens/vnpay_webview_screen.dart';
import '../data/models/vnpay_payment.dart';
import '../presentation/widgets/store_scaffold.dart';
import '../providers/auth_provider.dart';

GoRouter buildRouter(AuthProvider authProvider) => GoRouter(
  initialLocation: '/',
  refreshListenable: authProvider,
  redirect: (context, state) {
    if (!authProvider.isReady) return null;

    final location = state.matchedLocation;
    if (location == '/' && authProvider.sessionRestoreError != null) {
      return null;
    }
    final isAuthPage = location == '/login' || location == '/register';
    if (!authProvider.isSignedIn && !isAuthPage) return '/login';
    if (authProvider.isSignedIn && (isAuthPage || location == '/')) {
      return '/home';
    }
    if (location == '/') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthScreen(isRegister: false),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const AuthScreen(isRegister: true),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          StoreScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => ProductListScreen(
                initialQuery: state.uri.queryParameters['q'] ?? '',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/wishlist',
              builder: (context, state) => const WishlistScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/products/:id',
      builder: (context, state) =>
          ProductDetailScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrderListScreen(),
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (context, state) =>
          OrderDetailScreen(orderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/payments/vnpay',
      builder: (context, state) =>
          VnpayWebViewScreen(payment: state.extra! as VnpayPaymentSession),
    ),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(
      path: '/addresses',
      builder: (context, state) => const AddressBookScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
