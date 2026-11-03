import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/datasources/chat_socket_data_source.dart';
import '../data/models/chat_message.dart';
import '../data/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._repository);

  final ChatRepository _repository;
  List<ChatMessage> messages = const [];
  Object? error;
  bool isConnecting = false;
  bool isConnected = false;
  bool isTyping = false;
  int? _userId;
  Timer? _typingTimer;

  Future<void> connect(int userId) async {
    if (isConnected && _userId == userId) return;
    _repository.dispose();
    _userId = userId;
    messages = const [];
    error = null;
    isConnecting = true;
    isConnected = false;
    notifyListeners();
    try {
      final socket = await _repository.connect();
      socket.on('connect', (_) {
        isConnected = true;
        isConnecting = false;
        error = null;
        _repository.join(userId);
        notifyListeners();
      });
      socket.on('chat:history', (payload) {
        try {
          messages = ChatSocketDataSource.parseHistory(payload);
          error = null;
        } catch (value) {
          error = value;
        }
        notifyListeners();
      });
      socket.on('message:new', (payload) {
        try {
          final message = ChatSocketDataSource.parseMessage(payload);
          if (!messages.any((item) => item.id == message.id)) {
            messages = [...messages, message];
          }
          notifyListeners();
        } catch (value) {
          error = value;
          notifyListeners();
        }
      });
      socket.on('typing', (payload) {
        final data = payload is Map ? payload : const {};
        isTyping = data['is_typing'] == true || data['is_typing'] == 1;
        notifyListeners();
      });
      socket.on('chat:error', (payload) {
        final data = payload is Map ? payload : const {};
        error = data['message']?.toString() ?? 'Không thể gửi tin nhắn.';
        isConnecting = false;
        notifyListeners();
      });
      socket.on('connect_error', (value) {
        error = value?.toString() ?? 'Không kết nối được chat.';
        isConnecting = false;
        isConnected = false;
        notifyListeners();
      });
      socket.on('disconnect', (_) {
        isConnected = false;
        notifyListeners();
      });
      socket.connect();
    } catch (value) {
      error = value;
      isConnecting = false;
      notifyListeners();
    }
  }

  void send(String content) {
    final value = content.trim();
    if (value.isEmpty || !isConnected) return;
    _repository.typing(false);
    _repository.send(value);
  }

  void setTyping(bool typing) {
    if (!isConnected) return;
    _typingTimer?.cancel();
    _repository.typing(typing);
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _repository.typing(false);
      });
    }
  }

  void stopConversation() {
    _typingTimer?.cancel();
    _repository.leave();
    _repository.dispose();
    isConnected = false;
    isConnecting = false;
    isTyping = false;
  }

  void reset() {
    _typingTimer?.cancel();
    _repository.dispose();
    messages = const [];
    error = null;
    isConnecting = false;
    isConnected = false;
    isTyping = false;
    _userId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
