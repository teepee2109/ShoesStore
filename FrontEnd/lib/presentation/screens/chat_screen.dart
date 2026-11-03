import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  ChatProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      _provider = context.read<ChatProvider>();
      if (user != null) unawaited(_provider!.connect(user.id));
    });
  }

  @override
  void dispose() {
    _provider?.stopConversation();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final provider = context.read<ChatProvider>();
    final text = _controller.text.trim();
    if (text.isEmpty || !provider.isConnected) return;
    provider.send(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: const Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFFD7F542),
            child: Icon(
              Icons.storefront_outlined,
              size: 20,
              color: Colors.black,
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'adidas store',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                'Hỗ trợ khách hàng',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9),
          color: const Color(0xFFF0F0EC),
          child: const Text(
            'Tin nhắn được lưu trong lịch sử hỗ trợ của bạn',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, provider, child) {
              if (provider.isConnecting && provider.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.error != null && provider.messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          _friendly(provider.error!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            final user = context.read<AuthProvider>().user;
                            if (user != null) {
                              unawaited(provider.connect(user.id));
                            }
                          },
                          child: const Text('Kết nối lại'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  if (!provider.isConnected)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      itemCount:
                          provider.messages.length +
                          (provider.isTyping ? 1 : 0) +
                          1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const _ChatDayDivider(label: 'HỖ TRỢ');
                        }
                        if (provider.isTyping &&
                            index == provider.messages.length + 1) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(
                          message: provider.messages[index - 1],
                          isMine:
                              provider.messages[index - 1].senderRole ==
                              'customer',
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) => Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: provider.isConnected,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => provider.setTyping(true),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: provider.isConnected
                            ? 'Nhập tin nhắn...'
                            : 'Đang kết nối chat...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          onPressed: provider.isConnected ? _send : null,
                          icon: const Icon(Icons.arrow_upward_rounded),
                          tooltip: 'Gửi tin nhắn',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  String _friendly(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(message.createdAt)?.toLocal();
    final timeText = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFFD7F542) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(isMine ? 17 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 17),
                ),
              ),
              child: Text(
                message.content,
                style: const TextStyle(height: 1.35),
              ),
            ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeText,
                style: const TextStyle(fontSize: 9, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        'Cửa hàng đang nhập tin nhắn…',
        style: TextStyle(
          fontSize: 11,
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}

class _ChatDayDivider extends StatelessWidget {
  const _ChatDayDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.black45,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}
