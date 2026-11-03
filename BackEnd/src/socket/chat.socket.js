import jwt from 'jsonwebtoken';

import { env } from '../config/env.js';
import * as chatService from '../services/chat.service.js';

const roomForCustomer = (customerId) => `chat:user:${customerId}`;
const adminInboxRoom = 'chat:admin-inbox';

function ackError(socket, callback, error) {
  const message = error?.message || 'Không thể xử lý trò chuyện lúc này.';
  socket.emit('chat:error', { message });
  if (typeof callback === 'function') callback({ success: false, message });
}

export function attachChatSocket(io) {
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token || typeof token !== 'string') {
      return next(new Error('Vui lòng đăng nhập để kết nối chat.'));
    }
    try {
      socket.data.auth = jwt.verify(token, env.jwtSecret);
      return next();
    } catch {
      return next(new Error('Phiên đăng nhập không hợp lệ hoặc đã hết hạn.'));
    }
  });

  io.on('connection', (socket) => {
    const auth = socket.data.auth;
    if (auth.role === 'admin') socket.join(adminInboxRoom);

    socket.on('join', async (payload = {}, callback) => {
      try {
        const conversation = await chatService.joinConversation(
          auth,
          payload.customer_id ?? payload.customerId,
        );
        const oldCustomerId = socket.data.customerId;
        if (oldCustomerId) socket.leave(roomForCustomer(oldCustomerId));
        socket.data.customerId = conversation.customer_id;
        socket.join(roomForCustomer(conversation.customer_id));
        socket.emit('chat:history', conversation);
        if (typeof callback === 'function') callback({ success: true });
      } catch (error) {
        ackError(socket, callback, error);
      }
    });

    socket.on('message:send', async (payload = {}, callback) => {
      try {
        const customerId = socket.data.customerId;
        if (!customerId) throw new Error('Hãy tham gia cuộc trò chuyện trước khi gửi tin nhắn.');
        const result = await chatService.sendMessage(auth, customerId, payload.content);
        const room = roomForCustomer(result.customer_id);
        io.to(room).emit('message:new', result.message);
        io.to(adminInboxRoom).emit('chat:inbox', {
          customer_id: result.customer_id,
          message: result.message,
        });
        if (typeof callback === 'function') callback({ success: true });
      } catch (error) {
        ackError(socket, callback, error);
      }
    });

    socket.on('typing', (payload = {}) => {
      const customerId = socket.data.customerId;
      if (!customerId) return;
      socket.to(roomForCustomer(customerId)).emit('typing', {
        customer_id: customerId,
        user_id: Number(auth.sub),
        role: auth.role,
        is_typing: Boolean(payload.is_typing ?? payload.isTyping),
      });
    });

    socket.on('leave', () => {
      const customerId = socket.data.customerId;
      if (customerId) socket.leave(roomForCustomer(customerId));
      socket.data.customerId = null;
    });
  });
}
