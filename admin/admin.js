const API = `${window.location.origin}/api/v1`;
const TOKEN_KEY = 'adidas_admin_token';
const USER_KEY = 'adidas_admin_user';
const statusLabels = {
  pending: 'Chờ xác nhận', confirmed: 'Đã xác nhận', shipping: 'Đang giao',
  delivered: 'Đã giao', cancelled: 'Đã hủy',
};
function allowedStatuses(order) {
  const next = {
    pending: ['confirmed'],
    confirmed: ['shipping'],
    shipping: ['delivered'],
    delivered: [],
    cancelled: [],
  }[order.status] || [];
  if (['pending', 'confirmed'].includes(order.status) && ['unpaid', 'failed'].includes(order.payment_status)) {
    next.push('cancelled');
  }
  return [order.status, ...next];
}
const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value = '') => String(value).replace(/[&<>"']/g, (character) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[character]));
const money = (value) => `${new Intl.NumberFormat('vi-VN').format(Number(value || 0))} ₫`;
let token = sessionStorage.getItem(TOKEN_KEY);
let currentUser = JSON.parse(sessionStorage.getItem(USER_KEY) || 'null');
let categories = [];
let activeProductId = null;
let productModal;
let variantModal;
let noticeTimer;
let adminSocket;
let activeChatCustomerId = null;
let revenueChart;
let orderStatusChart;
let chatTypingTimer;

function showNotice(message, kind = 'success') {
  const notice = $('#notice');
  notice.className = `alert alert-${kind} shadow-sm`;
  notice.textContent = message;
  clearTimeout(noticeTimer);
  noticeTimer = setTimeout(() => notice.classList.add('d-none'), 5000);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function setLoggedIn(user) {
  currentUser = user;
  $('#login-view').classList.add('d-none');
  $('#admin-view').classList.remove('d-none');
  $('#account-tools').classList.remove('d-none');
  $('#account-name').textContent = user.name || user.email;
  connectAdminChat();
  loadCategories().then(() => loadProducts()).catch((error) => showNotice(error.message, 'danger'));
}

function logout(message) {
  adminSocket?.disconnect();
  adminSocket = null;
  activeChatCustomerId = null;
  token = null;
  currentUser = null;
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem(USER_KEY);
  $('#login-view').classList.remove('d-none');
  $('#admin-view').classList.add('d-none');
  $('#account-tools').classList.add('d-none');
  if (message) showNotice(message, 'warning');
}

async function api(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (options.body && !(options.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  const response = await fetch(`${API}${path}`, { ...options, headers });
  const payload = await response.json().catch(() => ({ message: 'Phản hồi API không hợp lệ.' }));
  if (!response.ok || payload.success === false) {
    if (response.status === 401 && token) logout('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
    throw new Error(payload.message || `Yêu cầu thất bại (${response.status}).`);
  }
  return payload.data;
}

function showRows(tbody, rows, emptyMessage) {
  tbody.innerHTML = rows || `<tr><td class="empty-row" colspan="8">${escapeHtml(emptyMessage)}</td></tr>`;
}

async function loadCategories() {
  const result = await api('/categories');
  categories = result || [];
  $('#product-category').innerHTML = `<option value="">Chọn danh mục</option>${categories.map((item) => `<option value="${Number(item.id)}">${escapeHtml(item.name)}</option>`).join('')}`;
  showRows($('#categories-table'), categories.map((category) => `
    <tr><td class="fw-semibold">${escapeHtml(category.name)}</td><td class="text-secondary">${escapeHtml(category.slug)}</td>
    <td>${Number(category.product_count || 0)}</td><td><div class="row-actions">
      <button class="btn btn-sm btn-outline-dark" data-action="edit-category" data-id="${Number(category.id)}">Sửa</button>
      <button class="btn btn-sm btn-outline-danger" data-action="delete-category" data-id="${Number(category.id)}">Xóa</button>
    </div></td></tr>`).join(''), 'Chưa có danh mục.');
}

function imageUrl(url) {
  if (!url) return '';
  if (url.startsWith('/')) return `${window.location.origin}${url}`;
  return url;
}

async function loadProducts() {
  const query = new URLSearchParams({ page: '1', limit: '50' });
  const q = $('#product-search').value.trim();
  if (q) query.set('q', q);
  const result = await api(`/products?${query}`);
  const products = result.items || [];
  showRows($('#products-table'), products.map((product) => {
    const thumb = product.main_image
      ? `<img src="${escapeHtml(imageUrl(product.main_image))}" alt="">`
      : '<span>AD</span>';
    return `<tr><td><div class="product-cell"><div class="product-thumb">${thumb}</div><div><div class="product-name">${escapeHtml(product.name)}</div><div class="subtext">#${Number(product.id)}</div></div></div></td>
      <td>${escapeHtml(product.category_name || '—')}</td><td><div class="fw-semibold">${money(product.discount_price ?? product.price)}</div>${product.discount_price ? `<div class="subtext text-decoration-line-through">${money(product.price)}</div>` : ''}</td>
      <td>${Number(product.stock || 0)}</td><td><div class="row-actions"><button class="btn btn-sm btn-outline-dark" data-action="edit-product" data-id="${Number(product.id)}">Sửa</button><button class="btn btn-sm btn-outline-dark" data-action="variants" data-id="${Number(product.id)}">Size / màu</button><button class="btn btn-sm btn-outline-danger" data-action="deactivate-product" data-id="${Number(product.id)}">Ẩn</button></div></td></tr>`;
  }).join(''), 'Không có sản phẩm phù hợp.');
}

function fillProductForm(product = null) {
  $('#product-form').reset();
  $('#product-id').value = product?.id || '';
  $('#product-modal-title').textContent = product ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm';
  $('#product-name').value = product?.name || '';
  $('#product-category').value = product?.category_id || '';
  $('#product-price').value = product?.price ?? '';
  $('#product-discount').value = product?.discount_price ?? '';
  $('#product-description').value = product?.description || '';
}

async function saveProduct(event) {
  event.preventDefault();
  const id = $('#product-id').value;
  const discountValue = $('#product-discount').value;
  const data = {
    category_id: Number($('#product-category').value),
    name: $('#product-name').value.trim(),
    description: $('#product-description').value.trim() || null,
    price: Number($('#product-price').value),
    discount_price: discountValue === '' ? null : Number(discountValue),
  };
  const button = $('#save-product');
  button.disabled = true;
  try {
    const result = await api(id ? '/products/' + id : '/products', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
    const productId = Number(id || result.id);
    if (!productId) throw new Error('Không xác định được sản phẩm vừa lưu.');

    // Keep the newly created ID so retrying a failed image upload updates this
    // product instead of creating another product.
    if (!id) {
      $('#product-id').value = String(productId);
      $('#product-modal-title').textContent = 'Chỉnh sửa sản phẩm';
    }

    const files = $('#product-images').files;
    if (files.length) {
      const formData = new FormData();
      for (const file of files) formData.append('images', file);
      try {
        await api('/products/' + productId + '/images', {
          method: 'POST',
          body: formData,
        });
        $('#product-images').value = '';
      } catch (error) {
        throw new Error('Sản phẩm đã lưu nhưng tải ảnh thất bại: ' + error.message);
      }
    }
    productModal.hide();
    await loadProducts();
    showNotice(id ? 'Đã cập nhật sản phẩm.' : 'Đã tạo sản phẩm.');
  } catch (error) {
    showNotice(error.message, 'danger');
  } finally {
    button.disabled = false;
  }
}
async function openVariants(productId) {
  activeProductId = Number(productId);
  $('#variant-form').reset();
  $('#variant-id').value = '';
  const product = await api(`/products/${activeProductId}`);
  $('#variant-modal-title').textContent = `Size và màu · ${product.name}`;
  showRows($('#variants-table'), (product.variants || []).map((variant) => `
    <tr><td>${escapeHtml(variant.size)}</td><td>${escapeHtml(variant.color)}</td><td>${Number(variant.stock)}</td><td><div class="row-actions">
      <button class="btn btn-sm btn-outline-dark" data-action="edit-variant" data-id="${Number(variant.id)}" data-size="${escapeHtml(variant.size)}" data-color="${escapeHtml(variant.color)}" data-stock="${Number(variant.stock)}">Sửa</button>
      <button class="btn btn-sm btn-outline-danger" data-action="delete-variant" data-id="${Number(variant.id)}">Xóa</button>
    </div></td></tr>`).join(''), 'Sản phẩm chưa có biến thể.');
  variantModal.show();
}

async function saveVariant(event) {
  event.preventDefault();
  const variantId = $('#variant-id').value;
  const data = {
    size: $('#variant-size').value.trim(),
    color: $('#variant-color').value.trim(),
    stock: Number($('#variant-stock').value),
  };
  try {
    await api(variantId ? `/products/${activeProductId}/variants/${variantId}` : `/products/${activeProductId}/variants`, {
      method: variantId ? 'PUT' : 'POST', body: JSON.stringify(data),
    });
    await openVariants(activeProductId);
    await loadProducts();
    showNotice(variantId ? 'Đã cập nhật biến thể.' : 'Đã tạo biến thể.');
  } catch (error) { showNotice(error.message, 'danger'); }
}

async function loadOrders() {
  const query = new URLSearchParams({ page: '1', limit: '50' });
  if ($('#order-filter').value) query.set('status', $('#order-filter').value);
  const result = await api(`/admin/orders?${query}`);
  showRows($('#orders-table'), (result.items || []).map((order) => `
    <tr><td><div class="fw-bold">#${Number(order.id)} <span class="status-pill status-${escapeHtml(order.status)}">${escapeHtml(statusLabels[order.status] || order.status)}</span></div>
    <div class="subtext">${escapeHtml(order.customer_name)} · ${escapeHtml(order.customer_email)} · ${Number(order.item_count)} sản phẩm</div></td>
    <td><div>${escapeHtml(order.shipping_name)}</div><div class="subtext">${escapeHtml(order.shipping_phone)} · ${escapeHtml(order.shipping_address)}</div></td>
    <td class="fw-semibold">${money(order.total_amount)}<div class="subtext">${escapeHtml(order.payment_status)} · ${escapeHtml(order.payment_method)}</div></td>
    <td><select class="form-select form-select-sm status-select" data-order-status="${Number(order.id)}" ${allowedStatuses(order).length === 1 ? 'disabled' : ''}>${allowedStatuses(order).map((value) => `<option value="${value}">${escapeHtml(statusLabels[value])}</option>`).join('')}</select></td>
    <td><div class="row-actions"><button class="btn btn-sm btn-dark" data-action="save-order-status" data-id="${Number(order.id)}" ${allowedStatuses(order).length === 1 ? 'disabled' : ''}>Lưu</button></div></td></tr>`).join(''), 'Chưa có đơn hàng.');
}

async function loadUsers() {
  const query = new URLSearchParams({ page: '1', limit: '50' });
  const q = $('#user-search').value.trim();
  if (q) query.set('q', q);
  if ($('#user-role-filter').value) query.set('role', $('#user-role-filter').value);
  const result = await api(`/admin/users?${query}`);
  showRows($('#users-table'), (result.items || []).map((user) => `
    <tr><td><div class="fw-semibold">${escapeHtml(user.name)}</div><div class="subtext">${escapeHtml(user.email)} · #${Number(user.id)}</div><input class="form-control form-control-sm mt-2" data-user-name="${Number(user.id)}" value="${escapeHtml(user.name)}" aria-label="Tên"></td>
    <td><input class="form-control form-control-sm" data-user-phone="${Number(user.id)}" value="${escapeHtml(user.phone || '')}" aria-label="Điện thoại"></td>
    <td>${Number(user.order_count || 0)}</td><td><select class="form-select form-select-sm" data-user-role="${Number(user.id)}"><option value="customer" ${user.role === 'customer' ? 'selected' : ''}>Customer</option><option value="admin" ${user.role === 'admin' ? 'selected' : ''}>Admin</option></select></td>
    <td><div class="row-actions"><button class="btn btn-sm btn-dark" data-action="save-user" data-id="${Number(user.id)}">Lưu</button><button class="btn btn-sm btn-outline-danger" data-action="delete-user" data-id="${Number(user.id)}" data-orders="${Number(user.order_count || 0)}">Xóa</button></div></td></tr>`).join(''), 'Không có người dùng phù hợp.');
}

async function loadDashboardStats() {
  const period = $('#stats-period').value || 'day';
  const [revenueData, topProducts, lowStockData, orderCounts] = await Promise.all([
    api(`/admin/stats/revenue?group=${encodeURIComponent(period)}`),
    api('/admin/stats/top-products?limit=8'),
    api('/admin/stats/low-stock?threshold=5&limit=50'),
    api('/admin/stats/orders-by-status'),
  ]);
  const revenueItems = revenueData.items || [];
  const revenueTotal = revenueItems.reduce((sum, item) => sum + Number(item.revenue || 0), 0);
  $('#stats-revenue-total').textContent = money(revenueTotal);
  $('#stats-paid-orders').textContent = revenueItems.reduce((sum, item) => sum + Number(item.order_count || 0), 0);
  $('#stats-low-stock-count').textContent = (lowStockData.items || []).length;

  revenueChart?.destroy();
  revenueChart = new Chart($('#revenue-chart'), {
    type: 'line',
    data: {
      labels: revenueItems.map((item) => item.period),
      datasets: [{
        label: 'Doanh thu',
        data: revenueItems.map((item) => Number(item.revenue || 0)),
        borderColor: '#151515',
        backgroundColor: '#d8ff3e88',
        fill: true,
        tension: .28,
      }],
    },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } },
  });

  const statusEntries = Object.entries(orderCounts || {});
  orderStatusChart?.destroy();
  orderStatusChart = new Chart($('#orders-status-chart'), {
    type: 'doughnut',
    data: {
      labels: statusEntries.map(([status]) => statusLabels[status] || status),
      datasets: [{ data: statusEntries.map(([, count]) => Number(count)), backgroundColor: ['#ffe6a8', '#b9d2ff', '#d5c9ff', '#bde8c7', '#ffd0d0'] }],
    },
    options: { responsive: true, plugins: { legend: { position: 'bottom' } } },
  });

  showRows($('#top-products-table'), (topProducts || []).map((product) => `
    <tr><td>${escapeHtml(product.product_name)} <span class="subtext">#${Number(product.product_id)}</span></td>
    <td>${Number(product.quantity_sold || 0)}</td><td>${money(product.revenue)}</td></tr>`).join(''), 'Chưa có doanh thu đã thanh toán.');
  showRows($('#low-stock-table'), (lowStockData.items || []).map((variant) => `
    <tr><td>${escapeHtml(variant.product_name)}</td><td>${escapeHtml(variant.size)}</td>
    <td>${escapeHtml(variant.color)}</td><td><span class="status-pill ${Number(variant.stock) === 0 ? 'status-cancelled' : 'status-pending'}">${Number(variant.stock)}</span></td></tr>`).join(''), 'Không có biến thể sắp hết hàng.');
}

function formatChatTime(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleString('vi-VN', { dateStyle: 'short', timeStyle: 'short' });
}

function renderAdminChatMessages(messages = []) {
  const container = $('#chat-admin-messages');
  if (!messages.length) {
    container.innerHTML = '<div class="empty-row">Chưa có tin nhắn. Hãy gửi lời chào cho khách.</div>';
    return;
  }
  container.innerHTML = messages.map((message) => `
    <div class="chat-admin-row ${message.sender_role === 'admin' ? 'is-admin' : 'is-customer'}">
      <div class="chat-admin-bubble"><div>${escapeHtml(message.content)}</div><time>${escapeHtml(formatChatTime(message.created_at))}</time></div>
    </div>`).join('');
  container.scrollTop = container.scrollHeight;
}

async function loadAdminChats() {
  const chats = await api('/admin/chats');
  if (!chats.length) {
    $('#chat-list').innerHTML = '<div class="empty-row">Chưa có cuộc trò chuyện nào.</div>';
    return;
  }
  $('#chat-list').innerHTML = chats.map((chat) => `
    <button class="chat-list-item ${Number(chat.customer_id) === Number(activeChatCustomerId) ? 'active' : ''}" data-action="open-chat" data-id="${Number(chat.customer_id)}" data-name="${escapeHtml(chat.customer_name)}">
      <span class="chat-avatar">${escapeHtml((chat.customer_name || '?').slice(0, 1).toUpperCase())}</span>
      <span class="chat-list-copy"><strong>${escapeHtml(chat.customer_name)}</strong><small>${escapeHtml(chat.last_message || '')}</small></span>
      ${Number(chat.unread_count) > 0 ? `<span class="chat-unread">${Number(chat.unread_count)}</span>` : ''}
    </button>`).join('');
}

async function selectAdminChat(customerId, customerName) {
  activeChatCustomerId = Number(customerId);
  $('#chat-customer-title').textContent = customerName || `Khách hàng #${activeChatCustomerId}`;
  $('#chat-typing-indicator').textContent = '';
  $('#admin-chat-input').disabled = !adminSocket?.connected;
  $('#admin-chat-send').disabled = !adminSocket?.connected;
  $('#chat-admin-messages').innerHTML = '<div class="empty-row">Đang tải tin nhắn…</div>';
  await loadAdminChats();
  const result = await api(`/admin/chats/${activeChatCustomerId}/messages`);
  if (Number(result.customer_id) !== activeChatCustomerId) return;
  renderAdminChatMessages(result.messages || []);
  adminSocket?.emit('join', { customer_id: activeChatCustomerId });
}

function connectAdminChat() {
  if (!token || typeof io !== 'function') return;
  adminSocket?.disconnect();
  adminSocket = io(window.location.origin, {
    auth: { token },
    transports: ['websocket'],
  });
  adminSocket.on('connect', () => {
    $('#chat-connection-status').textContent = 'Đang trực tuyến';
    $('#chat-connection-status').classList.add('text-success');
    $('#admin-chat-input').disabled = activeChatCustomerId == null;
    $('#admin-chat-send').disabled = activeChatCustomerId == null;
    if (activeChatCustomerId != null) adminSocket.emit('join', { customer_id: activeChatCustomerId });
  });
  adminSocket.on('disconnect', () => {
    $('#chat-connection-status').textContent = 'Mất kết nối';
    $('#chat-connection-status').classList.remove('text-success');
    $('#admin-chat-input').disabled = true;
    $('#admin-chat-send').disabled = true;
  });
  adminSocket.on('connect_error', (error) => {
    $('#chat-connection-status').textContent = 'Không thể kết nối chat';
    showNotice(error.message || 'Không thể kết nối chat.', 'danger');
  });
  adminSocket.on('chat:history', (conversation) => {
    if (Number(conversation.customer_id) === Number(activeChatCustomerId)) {
      renderAdminChatMessages(conversation.messages || []);
    }
  });
  adminSocket.on('message:new', (message) => {
    if (Number(message.sender_id) === Number(activeChatCustomerId) || Number(message.receiver_id) === Number(activeChatCustomerId)) {
      loadAdminChats().catch((error) => showNotice(error.message, 'danger'));
      api(`/admin/chats/${activeChatCustomerId}/messages`)
        .then((result) => renderAdminChatMessages(result.messages || []))
        .catch((error) => showNotice(error.message, 'danger'));
    }
  });
  adminSocket.on('chat:inbox', () => {
    loadAdminChats().catch((error) => showNotice(error.message, 'danger'));
  });
  adminSocket.on('typing', (event) => {
    if (Number(event.customer_id) !== Number(activeChatCustomerId)) return;
    $('#chat-typing-indicator').textContent = event.role === 'customer' && event.is_typing ? 'Khách đang nhập…' : '';
  });
  adminSocket.on('chat:error', (event) => showNotice(event.message || 'Lỗi trò chuyện.', 'danger'));
}

async function loadCurrentView(name) {
  try {
    if (name === 'products') await loadProducts();
    if (name === 'categories') await loadCategories();
    if (name === 'orders') await loadOrders();
    if (name === 'users') await loadUsers();
    if (name === 'stats') await loadDashboardStats();
    if (name === 'chat') await loadAdminChats();
  } catch (error) { showNotice(error.message, 'danger'); }
}

$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = event.currentTarget.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    const result = await api('/auth/login', { method: 'POST', body: JSON.stringify({
      email: $('#login-email').value.trim(), password: $('#login-password').value,
    }) });
    if (result.user.role !== 'admin') throw new Error('Tài khoản này không có quyền quản trị viên.');
    token = result.token;
    sessionStorage.setItem(TOKEN_KEY, token);
    sessionStorage.setItem(USER_KEY, JSON.stringify(result.user));
    setLoggedIn(result.user);
  } catch (error) { showNotice(error.message, 'danger'); }
  finally { button.disabled = false; }
});

$('#logout-button').addEventListener('click', () => logout());
document.querySelectorAll('.side-nav .nav-link').forEach((button) => button.addEventListener('click', () => {
  document.querySelectorAll('.side-nav .nav-link').forEach((item) => item.classList.toggle('active', item === button));
  document.querySelectorAll('.data-view').forEach((view) => view.classList.toggle('d-none', view.id !== `view-${button.dataset.view}`));
  loadCurrentView(button.dataset.view);
}));

productModal = new bootstrap.Modal($('#product-modal'));
variantModal = new bootstrap.Modal($('#variant-modal'));
$('#add-product').addEventListener('click', async () => {
  try { await loadCategories(); fillProductForm(); productModal.show(); }
  catch (error) { showNotice(error.message, 'danger'); }
});
$('#product-form').addEventListener('submit', saveProduct);
$('#variant-form').addEventListener('submit', saveVariant);
$('#reload-products').addEventListener('click', () => loadCurrentView('products'));
$('#reload-orders').addEventListener('click', () => loadCurrentView('orders'));
$('#reload-users').addEventListener('click', () => loadCurrentView('users'));
$('#order-filter').addEventListener('change', () => loadCurrentView('orders'));

let productSearchTimer;
$('#product-search').addEventListener('input', () => {
  clearTimeout(productSearchTimer);
  productSearchTimer = setTimeout(() => loadCurrentView('products'), 250);
});
let userSearchTimer;
$('#user-search').addEventListener('input', () => {
  clearTimeout(userSearchTimer);
  userSearchTimer = setTimeout(() => loadCurrentView('users'), 250);
});
$('#user-role-filter').addEventListener('change', () => loadCurrentView('users'));
$('#stats-period').addEventListener('change', () => loadCurrentView('stats'));

$('#admin-chat-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const content = $('#admin-chat-input').value.trim();
  if (!content || !adminSocket?.connected || activeChatCustomerId == null) return;
  adminSocket.emit('message:send', { content }, (result) => {
    if (!result?.success) {
      showNotice(result?.message || 'Không thể gửi tin nhắn.', 'danger');
      return;
    }
    $('#admin-chat-input').value = '';
    adminSocket.emit('typing', { is_typing: false });
  });
});

$('#admin-chat-input').addEventListener('input', () => {
  if (!adminSocket?.connected || activeChatCustomerId == null) return;
  adminSocket.emit('typing', { is_typing: true });
  clearTimeout(chatTypingTimer);
  chatTypingTimer = setTimeout(() => adminSocket.emit('typing', { is_typing: false }), 900);
});

$('#category-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const id = $('#category-id').value;
  const data = { name: $('#category-name').value.trim() };
  const slug = $('#category-slug').value.trim();
  if (slug) data.slug = slug;
  try {
    await api(id ? `/categories/${id}` : '/categories', { method: id ? 'PUT' : 'POST', body: JSON.stringify(data) });
    form.reset();
    $('#category-id').value = '';
    $('#cancel-category-edit').classList.add('d-none');
    await loadCategories();
    showNotice(id ? 'Đã cập nhật danh mục.' : 'Đã tạo danh mục.');
  } catch (error) { showNotice(error.message, 'danger'); }
});

$('#cancel-category-edit').addEventListener('click', () => {
  $('#category-form').reset(); $('#category-id').value = ''; $('#cancel-category-edit').classList.add('d-none');
});

document.addEventListener('click', async (event) => {
  const button = event.target.closest('[data-action]');
  if (!button) return;
  const { action, id } = button.dataset;
  try {
    if (action === 'edit-product') {
      const product = await api(`/products/${id}`);
      fillProductForm(product); productModal.show();
    } else if (action === 'deactivate-product') {
      if (!window.confirm('Ẩn sản phẩm này khỏi cửa hàng?')) return;
      await api(`/products/${id}`, { method: 'DELETE' });
      await loadProducts(); showNotice('Đã ẩn sản phẩm.');
    } else if (action === 'variants') {
      await openVariants(id);
    } else if (action === 'edit-variant') {
      $('#variant-id').value = id; $('#variant-size').value = button.dataset.size;
      $('#variant-color').value = button.dataset.color; $('#variant-stock').value = button.dataset.stock;
      $('#variant-size').focus();
    } else if (action === 'delete-variant') {
      if (!window.confirm('Xóa biến thể này?')) return;
      await api(`/products/${activeProductId}/variants/${id}`, { method: 'DELETE' });
      await openVariants(activeProductId); await loadProducts(); showNotice('Đã xóa biến thể.');
    } else if (action === 'edit-category') {
      const category = categories.find((item) => Number(item.id) === Number(id));
      if (!category) return;
      $('#category-id').value = category.id; $('#category-name').value = category.name;
      $('#category-slug').value = category.slug; $('#cancel-category-edit').classList.remove('d-none');
      $('#category-name').focus();
    } else if (action === 'delete-category') {
      if (!window.confirm('Xóa danh mục này? Danh mục đang có sản phẩm sẽ được giữ lại.')) return;
      await api(`/categories/${id}`, { method: 'DELETE' }); await loadCategories(); showNotice('Đã xóa danh mục.');
    } else if (action === 'save-order-status') {
      const select = document.querySelector(`[data-order-status="${CSS.escape(id)}"]`);
      await api(`/admin/orders/${id}/status`, { method: 'PUT', body: JSON.stringify({ status: select.value }) });
      await loadOrders(); showNotice('Đã cập nhật trạng thái đơn và gửi thông báo khách hàng.');
    } else if (action === 'save-user') {
      const name = document.querySelector(`[data-user-name="${CSS.escape(id)}"]`).value.trim();
      const phone = document.querySelector(`[data-user-phone="${CSS.escape(id)}"]`).value.trim();
      const role = document.querySelector(`[data-user-role="${CSS.escape(id)}"]`).value;
      await api(`/admin/users/${id}`, { method: 'PUT', body: JSON.stringify({ name, phone: phone || null, role }) });
      await loadUsers(); showNotice('Đã cập nhật người dùng.');
    } else if (action === 'delete-user') {
      if (Number(button.dataset.orders) > 0) throw new Error('Người dùng có lịch sử đơn hàng và không thể xóa.');
      if (!window.confirm('Xóa tài khoản người dùng này?')) return;
      await api(`/admin/users/${id}`, { method: 'DELETE' }); await loadUsers(); showNotice('Đã xóa người dùng.');
    } else if (action === 'open-chat') {
      await selectAdminChat(id, button.dataset.name);
    }
  } catch (error) { showNotice(error.message, 'danger'); }
});

if (token && currentUser?.role === 'admin') setLoggedIn(currentUser);
else if (token) logout();
