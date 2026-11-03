import * as chatModel from '../models/chat.model.js';
import { AppError } from '../utils/app-error.js';

const historyLimit = 100;

function parseCustomerId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) {
    throw new AppError('Mã khách hàng không hợp lệ.', 400);
  }
  return id;
}

function serializeMessage(message) {
  return {
    id: Number(message.id),
    sender_id: Number(message.sender_id),
    receiver_id: Number(message.receiver_id),
    sender_name: message.sender_name,
    sender_role: message.sender_role,
    content: message.content,
    is_read: Boolean(message.is_read),
    created_at: message.created_at,
  };
}

async function loadConversation(customerId, { markReadAs }) {
  if (markReadAs === 'customer') await chatModel.markAdminMessagesRead(customerId);
  if (markReadAs === 'admin') await chatModel.markCustomerMessagesRead(customerId);
  const messages = await chatModel.listConversationMessages(customerId, historyLimit);
  return messages.map(serializeMessage);
}

export async function joinConversation(auth, requestedCustomerId) {
  let customerId;
  let supportAdmin;
  if (auth.role === 'customer') {
    customerId = parseCustomerId(auth.sub);
    supportAdmin = await chatModel.findSupportAdmin();
    if (!supportAdmin) throw new AppError('Hiện chưa có nhân viên hỗ trợ.', 503);
  } else if (auth.role === 'admin') {
    customerId = parseCustomerId(requestedCustomerId);
    const customer = await chatModel.findCustomer(customerId);
    if (!customer) throw new AppError('Không tìm thấy khách hàng.', 404);
    supportAdmin = { id: parseCustomerId(auth.sub) };
  } else {
    throw new AppError('Bạn không có quyền truy cập trò chuyện.', 403);
  }

  return {
    customer_id: customerId,
    support_admin_id: Number(supportAdmin.id),
    messages: await loadConversation(customerId, {
      markReadAs: auth.role === 'customer' ? 'customer' : 'admin',
    }),
  };
}

export async function sendMessage(auth, customerIdValue, contentValue) {
  const content = typeof contentValue === 'string' ? contentValue.trim() : '';
  if (!content || content.length > 2000) {
    throw new AppError('Tin nhắn cần có từ 1 đến 2000 ký tự.', 400);
  }

  let customerId;
  let senderId;
  let receiverId;
  if (auth.role === 'customer') {
    customerId = parseCustomerId(auth.sub);
    senderId = customerId;
    const supportAdmin = await chatModel.findSupportAdmin();
    if (!supportAdmin) throw new AppError('Hiện chưa có nhân viên hỗ trợ.', 503);
    receiverId = Number(supportAdmin.id);
  } else if (auth.role === 'admin') {
    customerId = parseCustomerId(customerIdValue);
    const customer = await chatModel.findCustomer(customerId);
    if (!customer) throw new AppError('Không tìm thấy khách hàng.', 404);
    senderId = parseCustomerId(auth.sub);
    receiverId = customerId;
  } else {
    throw new AppError('Bạn không có quyền gửi tin nhắn.', 403);
  }

  const message = await chatModel.insertMessage(senderId, receiverId, content);
  return { customer_id: customerId, message: serializeMessage(message) };
}

export async function listAdminConversations() {
  return chatModel.listAdminConversations(100);
}

export async function getAdminConversation(customerIdValue) {
  const customerId = parseCustomerId(customerIdValue);
  if (!(await chatModel.findCustomer(customerId))) {
    throw new AppError('Không tìm thấy khách hàng.', 404);
  }
  return {
    customer_id: customerId,
    messages: await loadConversation(customerId, { markReadAs: 'admin' }),
  };
}
