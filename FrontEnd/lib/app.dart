import 'package:flutter/material.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'providers/auth_provider.dart';

class StoreApp extends StatefulWidget {
  const StoreApp({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  State<StoreApp> createState() => _StoreAppState();
}

class _StoreAppState extends State<StoreApp> {
  late final _router = buildRouter(widget.authProvider);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Adidas Shoe Store',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
