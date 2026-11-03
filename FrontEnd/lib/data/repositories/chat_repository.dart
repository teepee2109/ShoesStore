import 'package:socket_io_client/socket_io_client.dart' as io;

import '../datasources/chat_socket_data_source.dart';

class ChatRepository {
  ChatRepository(this._socketDataSource);

  final ChatSocketDataSource _socketDataSource;

  Future<io.Socket> connect() => _socketDataSource.connect();
  void join(int customerId) => _socketDataSource.join(customerId);
  void send(String content) => _socketDataSource.send(content);
  void typing(bool isTyping) => _socketDataSource.typing(isTyping);
  void leave() => _socketDataSource.leave();
  void dispose() => _socketDataSource.dispose();
}
