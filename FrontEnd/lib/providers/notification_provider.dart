import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/store_notification.dart';
import '../data/repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._repository);

  final NotificationRepository _repository;
  List<StoreNotification> notifications = const [];
  Object? error;
  bool isLoading = false;
  bool hasLoaded = false;
  bool isMutating = false;
  int unreadCount = 0;
  int _generation = 0;
  Timer? _pollTimer;

  void startPolling({Duration interval = const Duration(seconds: 45)}) {
    _pollTimer?.cancel();
    unawaited(load(force: true));
    _pollTimer = Timer.periodic(interval, (_) => unawaited(load(force: true)));
  }

  Future<void> load({bool force = false}) async {
    if (isLoading || isMutating || (hasLoaded && !force)) return;
    final generation = ++_generation;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.getNotifications();
      if (generation != _generation) return;
      notifications = result.items;
      unreadCount = result.unreadCount;
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

  Future<void> markRead(int id) async {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0 || notifications[index].isRead || isMutating) return;
    final previous = notifications[index];
    isMutating = true;
    notifications = [...notifications]
      ..[index] = previous.copyWith(isRead: true);
    unreadCount = (unreadCount - 1).clamp(0, 1 << 30);
    notifyListeners();
    try {
      await _repository.markRead(id);
      error = null;
    } catch (value) {
      notifications = [...notifications]..[index] = previous;
      unreadCount += 1;
      error = value;
      rethrow;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0 || isMutating) return;
    final previous = notifications;
    final previousUnread = unreadCount;
    isMutating = true;
    notifications = notifications
        .map((item) => item.copyWith(isRead: true))
        .toList();
    unreadCount = 0;
    notifyListeners();
    try {
      await _repository.markAllRead();
      error = null;
    } catch (value) {
      notifications = previous;
      unreadCount = previousUnread;
      error = value;
      rethrow;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  void reset() {
    ++_generation;
    _pollTimer?.cancel();
    _pollTimer = null;
    notifications = const [];
    error = null;
    isLoading = false;
    hasLoaded = false;
    isMutating = false;
    unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
