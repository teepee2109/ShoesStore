import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/config/app_config.dart';
import '../../core/storage/token_storage.dart';
import '../models/chat_message.dart';
import 'api_payload.dart';

class ChatSocketDataSource {
  ChatSocketDataSource(this._tokenStorage);

  final TokenStorage _tokenStorage;
  io.Socket? _socket;

  io.Socket? get socket => _socket;

  Future<io.Socket> connect() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Vui lòng đăng nhập để chat.');
    }
    _socket?.disconnect();
    _socket = io.io(
      AppConfig.serverOrigin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    return _socket!;
  }

  void join(int customerId) =>
      _socket?.emit('join', {'customer_id': customerId});

  void send(String content) =>
      _socket?.emit('message:send', {'content': content});

  void typing(bool isTyping) =>
      _socket?.emit('typing', {'is_typing': isTyping});

  void leave() => _socket?.emit('leave');

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  static List<ChatMessage> parseHistory(Object? payload) {
    final data = asJsonMap(payload);
    return (data['messages'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((message) => ChatMessage.fromJson(message.cast<String, dynamic>()))
        .toList();
  }

  static ChatMessage parseMessage(Object? payload) =>
      ChatMessage.fromJson(asJsonMap(payload));
}
