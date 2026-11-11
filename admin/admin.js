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
let productPage = 1;
let productLimit = 10;
let productTotalPages = 1;
let categoryPage = 1;
let categoryLimit = 10;
let categoryTotalPages = 1;
let orderPage = 1;
let orderLimit = 10;
let orderTotalPages = 1;
let userPage = 1;
let userLimit = 10;
let userTotalPages = 1;
let productModal;
let variantModal;
let noticeTimer;
let adminSocket;
let activeChatCustomerId = null;
let reportChart;
let selectedReport = null;
let chatTypingTimer;
const adminReports = [
  { id: 'revenue', category: 'Tài chính', title: 'Doanh thu theo kỳ', description: 'Theo dõi doanh thu đã thanh toán và số đơn theo ngày hoặc tháng.', keywords: 'doanh thu tiền bán hàng tài chính revenue' },
  { id: 'orders', category: 'Vận hành', title: 'Đơn hàng theo trạng thái', description: 'Xem cơ cấu đơn đang chờ, đang giao, đã hoàn tất hoặc đã hủy.', keywords: 'đơn hàng trạng thái vận hành giao hàng orders' },
  { id: 'top-products', category: 'Kinh doanh', title: 'Sản phẩm bán chạy', description: 'Xếp hạng sản phẩm theo số lượng bán và doanh thu trong kỳ.', keywords: 'sản phẩm bán chạy top doanh số kinh doanh' },
  { id: 'low-stock', category: 'Kho hàng', title: 'Tồn kho cần bổ sung', description: 'Tìm các biến thể có số lượng tồn dưới ngưỡng đặt hàng.', keywords: 'tồn kho sắp hết hàng nhập bổ sung size màu inventory' },
];

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

function updatePagination(prefix, page, limit, total, totalPages) {
  const labels = { products: 'sản phẩm', categories: 'danh mục', orders: 'đơn hàng', users: 'người dùng' };
  const first = total ? (page - 1) * limit + 1 : 0;
  const last = Math.min(page * limit, total);
  const label = labels[prefix] || 'mục';
  $(`#${prefix}-page-summary`).textContent = total
    ? `Hiển thị ${first}–${last} trong ${total} ${label}`
    : `0 ${label}`;
  $(`#${prefix}-page-indicator`).textContent = `Trang ${page} / ${totalPages}`;
  $(`#${prefix}-prev-page`).disabled = page <= 1;
  $(`#${prefix}-next-page`).disabled = page >= totalPages;
}

async function loadCategories() {
  const result = await api('/categories');
  categories = result || [];
  $('#product-category').innerHTML = `<option value="">Chọn danh mục</option>${categories.map((item) => `<option value="${Number(item.id)}">${escapeHtml(item.name)}</option>`).join('')}`;
  categoryTotalPages = Math.max(1, Math.ceil(categories.length / categoryLimit));
  if (categoryPage > categoryTotalPages) categoryPage = categoryTotalPages;
  const pageCategories = categories.slice((categoryPage - 1) * categoryLimit, categoryPage * categoryLimit);
  showRows($('#categories-table'), pageCategories.map((category) => `
    <tr><td class="fw-semibold">${escapeHtml(category.name)}</td><td class="text-secondary">${escapeHtml(category.slug)}</td>
    <td>${Number(category.product_count || 0)}</td><td><div class="row-actions">
      <button class="btn btn-sm btn-outline-dark" data-action="edit-category" data-id="${Number(category.id)}">Sửa</button>
      <button class="btn btn-sm btn-outline-danger" data-action="delete-category" data-id="${Number(category.id)}">Xóa</button>
    </div></td></tr>`).join(''), 'Chưa có danh mục.');
  updatePagination('categories', categoryPage, categoryLimit, categories.length, categoryTotalPages);
}

function imageUrl(url) {
  if (!url) return '';
  if (url.startsWith('/')) return `${window.location.origin}${url}`;
  return url;
}

async function loadProducts() {
  const query = new URLSearchParams({ page: String(productPage), limit: String(productLimit) });
  const q = $('#product-search').value.trim();
  if (q) query.set('q', q);
  const result = await api(`/products?${query}`);
  const pagination = result.pagination || {};
  productTotalPages = Math.max(1, Number(pagination.total_pages || 1));
  if (productPage > productTotalPages) {
    productPage = productTotalPages;
    return loadProducts();
  }
  const products = result.items || [];
  showRows($('#products-table'), products.map((product) => {
    const thumb = product.main_image
      ? `<img src="${escapeHtml(imageUrl(product.main_image))}" alt="">`
      : '<span>AD</span>';
    return `<tr><td><div class="product-cell"><div class="product-thumb">${thumb}</div><div><div class="product-name">${escapeHtml(product.name)}</div><div class="subtext">#${Number(product.id)}</div></div></div></td>
      <td>${escapeHtml(product.category_name || '—')}</td><td><div class="fw-semibold">${money(product.discount_price ?? product.price)}</div>${product.discount_price ? `<div class="subtext text-decoration-line-through">${money(product.price)}</div>` : ''}</td>
      <td>${Number(product.stock || 0)}</td><td><div class="row-actions"><button class="btn btn-sm btn-outline-dark" data-action="edit-product" data-id="${Number(product.id)}">Sửa</button><button class="btn btn-sm btn-outline-dark" data-action="variants" data-id="${Number(product.id)}">Size / màu</button><button class="btn btn-sm btn-outline-danger" data-action="deactivate-product" data-id="${Number(product.id)}">Ẩn</button></div></td></tr>`;
  }).join(''), 'Không có sản phẩm phù hợp.');
  updatePagination('products', productPage, productLimit, Number(pagination.total || 0), productTotalPages);
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
  const query = new URLSearchParams({ page: String(orderPage), limit: String(orderLimit) });
  if ($('#order-filter').value) query.set('status', $('#order-filter').value);
  const result = await api(`/admin/orders?${query}`);
  const pagination = result.pagination || {};
  orderTotalPages = Math.max(1, Number(pagination.total_pages || 1));
  if (orderPage > orderTotalPages) {
    orderPage = orderTotalPages;
    return loadOrders();
  }
  showRows($('#orders-table'), (result.items || []).map((order) => `
    <tr><td><div class="fw-bold">#${Number(order.id)} <span class="status-pill status-${escapeHtml(order.status)}">${escapeHtml(statusLabels[order.status] || order.status)}</span></div>
    <div class="subtext">${escapeHtml(order.customer_name)} · ${escapeHtml(order.customer_email)} · ${Number(order.item_count)} sản phẩm</div></td>
    <td><div>${escapeHtml(order.shipping_name)}</div><div class="subtext">${escapeHtml(order.shipping_phone)} · ${escapeHtml(order.shipping_address)}</div></td>
    <td class="fw-semibold">${money(order.total_amount)}<div class="subtext">${escapeHtml(order.payment_status)} · ${escapeHtml(order.payment_method)}</div></td>
    <td><select class="form-select form-select-sm status-select" data-order-status="${Number(order.id)}" ${allowedStatuses(order).length === 1 ? 'disabled' : ''}>${allowedStatuses(order).map((value) => `<option value="${value}">${escapeHtml(statusLabels[value])}</option>`).join('')}</select></td>
    <td><div class="row-actions"><button class="btn btn-sm btn-dark" data-action="save-order-status" data-id="${Number(order.id)}" ${allowedStatuses(order).length === 1 ? 'disabled' : ''}>Lưu</button></div></td></tr>`).join(''), 'Chưa có đơn hàng.');
  updatePagination('orders', orderPage, orderLimit, Number(pagination.total || 0), orderTotalPages);
}

async function loadUsers() {
  const query = new URLSearchParams({ page: String(userPage), limit: String(userLimit) });
  const q = $('#user-search').value.trim();
  if (q) query.set('q', q);
  if ($('#user-role-filter').value) query.set('role', $('#user-role-filter').value);
  const result = await api(`/admin/users?${query}`);
  const pagination = result.pagination || {};
  userTotalPages = Math.max(1, Number(pagination.total_pages || 1));
  if (userPage > userTotalPages) {
    userPage = userTotalPages;
    return loadUsers();
  }
  showRows($('#users-table'), (result.items || []).map((user) => `
    <tr><td><div class="fw-semibold">${escapeHtml(user.name)}</div><div class="subtext">${escapeHtml(user.email)} · #${Number(user.id)}</div><input class="form-control form-control-sm mt-2" data-user-name="${Number(user.id)}" value="${escapeHtml(user.name)}" aria-label="Tên"></td>
    <td><input class="form-control form-control-sm" data-user-phone="${Number(user.id)}" value="${escapeHtml(user.phone || '')}" aria-label="Điện thoại"></td>
    <td>${Number(user.order_count || 0)}</td><td><select class="form-select form-select-sm" data-user-role="${Number(user.id)}"><option value="customer" ${user.role === 'customer' ? 'selected' : ''}>Customer</option><option value="admin" ${user.role === 'admin' ? 'selected' : ''}>Admin</option></select></td>
    <td><div class="row-actions"><button class="btn btn-sm btn-dark" data-action="save-user" data-id="${Number(user.id)}">Lưu</button><button class="btn btn-sm btn-outline-danger" data-action="delete-user" data-id="${Number(user.id)}" data-orders="${Number(user.order_count || 0)}">Xóa</button></div></td></tr>`).join(''), 'Không có người dùng phù hợp.');
  updatePagination('users', userPage, userLimit, Number(pagination.total || 0), userTotalPages);
}

function localDateValue(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function defaultReportDateRange() {
  const today = new Date();
  return {
    from: localDateValue(new Date(today.getFullYear(), today.getMonth(), 1)),
    to: localDateValue(today),
  };
}

function renderReportCatalog() {
  const query = $('#report-search-input').value.trim().toLocaleLowerCase('vi');
  const filtered = adminReports.filter((report) =>
    `${report.title} ${report.category} ${report.description} ${report.keywords}`
      .toLocaleLowerCase('vi').includes(query));
  $('#report-count').textContent = `${filtered.length} / ${adminReports.length} báo cáo`;
  $('#report-no-match').classList.toggle('d-none', filtered.length > 0);
  $('#report-catalog').innerHTML = filtered.map((report, index) => `
    <button class="report-card ${selectedReport?.id === report.id ? 'active' : ''}" type="button" data-report="${report.id}">
      <span class="report-card-index">${String(index + 1).padStart(2, '0')}</span>
      <span class="report-card-copy"><span class="report-category">${escapeHtml(report.category)}</span><strong>${escapeHtml(report.title)}</strong><small>${escapeHtml(report.description)}</small></span>
      <span class="report-card-arrow" aria-hidden="true">→</span>
    </button>`).join('');
}

function renderReportFilters(report) {
  const dateRange = defaultReportDateRange();
  const dateFields = `
    <div class="report-field"><label class="form-label" for="report-from">Từ ngày</label><input id="report-from" name="from" class="form-control" type="date" value="${dateRange.from}" required></div>
    <div class="report-field"><label class="form-label" for="report-to">Đến ngày</label><input id="report-to" name="to" class="form-control" type="date" value="${dateRange.to}" required></div>`;
  let fields = dateFields;
  if (report.id === 'revenue') {
    fields += `<div class="report-field"><label class="form-label" for="report-group">Chi tiết theo</label><select id="report-group" name="group" class="form-select"><option value="day">Ngày</option><option value="month">Tháng</option></select></div>`;
  } else if (report.id === 'top-products') {
    fields += `<div class="report-field"><label class="form-label" for="report-limit">Số sản phẩm</label><select id="report-limit" name="limit" class="form-select"><option value="10">Top 10</option><option value="20">Top 20</option><option value="50">Top 50</option></select></div>`;
  } else if (report.id === 'low-stock') {
    fields = `
      <div class="report-field"><label class="form-label" for="report-threshold">Ngưỡng tồn kho</label><input id="report-threshold" name="threshold" class="form-control" type="number" min="0" max="100000" value="5" required><small class="form-text">Tìm biến thể có tồn bằng hoặc thấp hơn ngưỡng.</small></div>
      <div class="report-field"><label class="form-label" for="report-limit">Số dòng tối đa</label><select id="report-limit" name="limit" class="form-select"><option value="25">25 dòng</option><option value="50" selected>50 dòng</option><option value="100">100 dòng</option></select></div>`;
  }
  $('#report-filter-fields').innerHTML = fields;
}

function selectReport(reportId) {
  selectedReport = adminReports.find((report) => report.id === reportId) || null;
  if (!selectedReport) return;
  reportChart?.destroy();
  reportChart = null;
  $('#report-builder-category').textContent = selectedReport.category;
  $('#report-builder-title').textContent = selectedReport.title;
  $('#report-builder-description').textContent = selectedReport.description;
  $('#report-builder').classList.remove('d-none');
  $('#report-results').classList.add('d-none');
  $('#report-result-content').innerHTML = '';
  renderReportFilters(selectedReport);
  renderReportCatalog();
}

function clearSelectedReport() {
  selectedReport = null;
  reportChart?.destroy();
  reportChart = null;
  $('#report-builder').classList.add('d-none');
  $('#report-results').classList.add('d-none');
  $('#report-result-content').innerHTML = '';
  renderReportCatalog();
}

function reportSummaryCard(label, value, detail = '') {
  return `<article class="report-summary-card"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong>${detail ? `<small>${escapeHtml(detail)}</small>` : ''}</article>`;
}

function renderReportChart(type, labels, values, label) {
  const canvas = $('#report-chart');
  if (!canvas || !labels.length) return;
  reportChart?.destroy();
  reportChart = new Chart(canvas, {
    type,
    data: {
      labels,
      datasets: [{
        label,
        data: values,
        borderColor: '#151515',
        backgroundColor: type === 'doughnut'
          ? ['#d8ff3e', '#b9d2ff', '#d5c9ff', '#bde8c7', '#ffd0d0']
          : '#d8ff3e88',
        fill: type !== 'doughnut',
        tension: .28,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: type === 'doughnut', position: 'bottom' } },
      scales: type === 'doughnut' ? {} : { y: { beginAtZero: true } },
    },
  });
}

function renderRevenueReport(data) {
  const items = data.items || [];
  const totalRevenue = items.reduce((sum, item) => sum + Number(item.revenue || 0), 0);
  const totalOrders = items.reduce((sum, item) => sum + Number(item.order_count || 0), 0);
  const averageOrder = totalOrders ? totalRevenue / totalOrders : 0;
  $('#report-result-summary').innerHTML = [
    reportSummaryCard('Doanh thu đã thu', money(totalRevenue)),
    reportSummaryCard('Đơn đã thanh toán', new Intl.NumberFormat('vi-VN').format(totalOrders)),
    reportSummaryCard('Giá trị trung bình / đơn', money(averageOrder)),
  ].join('');
  $('#report-result-content').innerHTML = `
    <div class="panel report-chart-panel"><canvas id="report-chart"></canvas></div>
    <div class="table-responsive panel"><table class="table align-middle mb-0"><thead><tr><th>Kỳ</th><th>Số đơn</th><th>Doanh thu</th><th>Trung bình / đơn</th></tr></thead><tbody>${items.map((item) => {
      const count = Number(item.order_count || 0);
      const revenue = Number(item.revenue || 0);
      return `<tr><td>${escapeHtml(item.period)}</td><td>${count}</td><td class="fw-semibold">${money(revenue)}</td><td>${money(count ? revenue / count : 0)}</td></tr>`;
    }).join('') || '<tr><td class="empty-row" colspan="4">Không có giao dịch đã thanh toán trong kỳ này.</td></tr>'}</tbody></table></div>`;
  renderReportChart('line', items.map((item) => item.period), items.map((item) => Number(item.revenue || 0)), 'Doanh thu');
}

function renderOrderStatusReport(counts) {
  const entries = Object.entries(counts || {});
  const total = entries.reduce((sum, [, count]) => sum + Number(count || 0), 0);
  $('#report-result-summary').innerHTML = [
    reportSummaryCard('Tổng số đơn', new Intl.NumberFormat('vi-VN').format(total)),
    reportSummaryCard('Đang xử lý', new Intl.NumberFormat('vi-VN').format(Number(counts.pending || 0) + Number(counts.confirmed || 0) + Number(counts.shipping || 0))),
    reportSummaryCard('Đã giao', new Intl.NumberFormat('vi-VN').format(Number(counts.delivered || 0))),
  ].join('');
  $('#report-result-content').innerHTML = `
    <div class="panel report-chart-panel report-doughnut"><canvas id="report-chart"></canvas></div>
    <div class="table-responsive panel"><table class="table align-middle mb-0"><thead><tr><th>Trạng thái đơn</th><th>Số đơn</th><th>Tỷ trọng</th></tr></thead><tbody>${entries.map(([status, count]) => {
      const amount = Number(count || 0);
      const percentage = total ? (amount / total * 100).toFixed(1) : '0.0';
      return `<tr><td>${escapeHtml(statusLabels[status] || status)}</td><td>${amount}</td><td>${percentage}%</td></tr>`;
    }).join('') || '<tr><td class="empty-row" colspan="3">Không có đơn hàng trong kỳ này.</td></tr>'}</tbody></table></div>`;
  renderReportChart('doughnut', entries.map(([status]) => statusLabels[status] || status), entries.map(([, count]) => Number(count)), 'Số đơn');
}

function renderTopProductsReport(products) {
  const items = products || [];
  const totalUnits = items.reduce((sum, product) => sum + Number(product.quantity_sold || 0), 0);
  const totalRevenue = items.reduce((sum, product) => sum + Number(product.revenue || 0), 0);
  $('#report-result-summary').innerHTML = [
    reportSummaryCard('Sản phẩm trong bảng', new Intl.NumberFormat('vi-VN').format(items.length)),
    reportSummaryCard('Tổng số lượng bán', new Intl.NumberFormat('vi-VN').format(totalUnits)),
    reportSummaryCard('Doanh thu nhóm sản phẩm', money(totalRevenue)),
  ].join('');
  $('#report-result-content').innerHTML = `
    <div class="table-responsive panel"><table class="table align-middle mb-0"><thead><tr><th>Hạng</th><th>Sản phẩm</th><th>Số lượng bán</th><th>Doanh thu</th></tr></thead><tbody>${items.map((product, index) => `
      <tr><td><span class="report-rank">${index + 1}</span></td><td class="fw-semibold">${escapeHtml(product.product_name)} <span class="subtext">#${Number(product.product_id)}</span></td><td>${Number(product.quantity_sold || 0)}</td><td class="fw-semibold">${money(product.revenue)}</td></tr>`).join('') || '<tr><td class="empty-row" colspan="4">Không có sản phẩm bán ra trong kỳ này.</td></tr>'}</tbody></table></div>`;
}

function renderLowStockReport(data) {
  const items = data.items || [];
  const outOfStock = items.filter((variant) => Number(variant.stock) === 0).length;
  $('#report-result-summary').innerHTML = [
    reportSummaryCard('Biến thể cần kiểm tra', new Intl.NumberFormat('vi-VN').format(items.length), `Ngưỡng tồn ≤ ${Number(data.threshold)}`),
    reportSummaryCard('Đã hết hàng', new Intl.NumberFormat('vi-VN').format(outOfStock)),
  ].join('');
  $('#report-result-content').innerHTML = `
    <div class="table-responsive panel"><table class="table align-middle mb-0"><thead><tr><th>Sản phẩm</th><th>Size</th><th>Màu</th><th>Tồn hiện tại</th></tr></thead><tbody>${items.map((variant) => `
      <tr><td class="fw-semibold">${escapeHtml(variant.product_name)}</td><td>${escapeHtml(variant.size)}</td><td>${escapeHtml(variant.color)}</td><td><span class="status-pill ${Number(variant.stock) === 0 ? 'status-cancelled' : 'status-pending'}">${Number(variant.stock)}</span></td></tr>`).join('') || '<tr><td class="empty-row" colspan="4">Không có biến thể nào dưới ngưỡng đã chọn.</td></tr>'}</tbody></table></div>`;
}

async function runSelectedReport(event) {
  event.preventDefault();
  if (!selectedReport) return;
  const formData = new FormData(event.currentTarget);
  const from = String(formData.get('from') || '');
  const to = String(formData.get('to') || '');
  if (from && to && from > to) {
    showNotice('Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.', 'warning');
    return;
  }
  const button = $('#run-report');
  button.disabled = true;
  button.textContent = 'Đang tải…';
  $('#report-results').classList.remove('d-none');
  $('#report-result-title').textContent = selectedReport.title;
  $('#report-result-period').textContent = selectedReport.id === 'low-stock' ? 'Tồn kho hiện tại' : `${from} – ${to}`;
  $('#report-result-summary').innerHTML = '';
  $('#report-result-content').innerHTML = '<div class="panel report-loading">Đang tổng hợp dữ liệu…</div>';
  reportChart?.destroy();
  reportChart = null;
  try {
    let result;
    if (selectedReport.id === 'revenue') {
      const query = new URLSearchParams({ from, to, group: String(formData.get('group') || 'day') });
      result = await api(`/admin/stats/revenue?${query}`);
      $('#report-result-period').textContent = `${from} – ${to} · ${query.get('group') === 'month' ? 'theo tháng' : 'theo ngày'}`;
      renderRevenueReport(result);
    } else if (selectedReport.id === 'orders') {
      const query = new URLSearchParams({ from, to });
      result = await api(`/admin/stats/orders-by-status?${query}`);
      renderOrderStatusReport(result);
    } else if (selectedReport.id === 'top-products') {
      const query = new URLSearchParams({ from, to, limit: String(formData.get('limit') || '10') });
      result = await api(`/admin/stats/top-products?${query}`);
      renderTopProductsReport(result);
    } else if (selectedReport.id === 'low-stock') {
      const query = new URLSearchParams({
        threshold: String(formData.get('threshold') || '5'),
        limit: String(formData.get('limit') || '50'),
      });
      result = await api(`/admin/stats/low-stock?${query}`);
      renderLowStockReport(result);
      $('#report-result-period').textContent = `Ngưỡng tồn ≤ ${Number(result.threshold)}`;
    }
  } catch (error) {
    $('#report-result-summary').innerHTML = '';
    $('#report-result-content').innerHTML = `<div class="panel report-error">${escapeHtml(error.message)}</div>`;
  } finally {
    button.disabled = false;
    button.textContent = 'Xem báo cáo';
  }
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
    if (name === 'stats') renderReportCatalog();
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
$('#order-filter').addEventListener('change', () => {
  orderPage = 1;
  loadCurrentView('orders');
});
$('#report-search-input').addEventListener('input', renderReportCatalog);
$('#report-catalog').addEventListener('click', (event) => {
  const card = event.target.closest('[data-report]');
  if (card) selectReport(card.dataset.report);
});
$('#clear-selected-report').addEventListener('click', clearSelectedReport);
$('#report-filter-form').addEventListener('submit', runSelectedReport);

let productSearchTimer;
$('#product-search').addEventListener('input', () => {
  productPage = 1;
  clearTimeout(productSearchTimer);
  productSearchTimer = setTimeout(() => loadCurrentView('products'), 250);
});
$('#products-page-size').addEventListener('change', (event) => {
  productLimit = Number(event.currentTarget.value) || 10;
  productPage = 1;
  loadCurrentView('products');
});
$('#products-prev-page').addEventListener('click', () => {
  if (productPage <= 1) return;
  productPage -= 1;
  loadCurrentView('products');
});
$('#products-next-page').addEventListener('click', () => {
  if (productPage >= productTotalPages) return;
  productPage += 1;
  loadCurrentView('products');
});
$('#categories-page-size').addEventListener('change', (event) => {
  categoryLimit = Number(event.currentTarget.value) || 10;
  categoryPage = 1;
  loadCurrentView('categories');
});
$('#categories-prev-page').addEventListener('click', () => {
  if (categoryPage <= 1) return;
  categoryPage -= 1;
  loadCurrentView('categories');
});
$('#categories-next-page').addEventListener('click', () => {
  if (categoryPage >= categoryTotalPages) return;
  categoryPage += 1;
  loadCurrentView('categories');
});
$('#orders-page-size').addEventListener('change', (event) => {
  orderLimit = Number(event.currentTarget.value) || 10;
  orderPage = 1;
  loadCurrentView('orders');
});
$('#orders-prev-page').addEventListener('click', () => {
  if (orderPage <= 1) return;
  orderPage -= 1;
  loadCurrentView('orders');
});
$('#orders-next-page').addEventListener('click', () => {
  if (orderPage >= orderTotalPages) return;
  orderPage += 1;
  loadCurrentView('orders');
});
$('#users-page-size').addEventListener('change', (event) => {
  userLimit = Number(event.currentTarget.value) || 10;
  userPage = 1;
  loadCurrentView('users');
});
$('#users-prev-page').addEventListener('click', () => {
  if (userPage <= 1) return;
  userPage -= 1;
  loadCurrentView('users');
});
$('#users-next-page').addEventListener('click', () => {
  if (userPage >= userTotalPages) return;
  userPage += 1;
  loadCurrentView('users');
});
let userSearchTimer;
$('#user-search').addEventListener('input', () => {
  userPage = 1;
  clearTimeout(userSearchTimer);
  userSearchTimer = setTimeout(() => loadCurrentView('users'), 250);
});
$('#user-role-filter').addEventListener('change', () => {
  userPage = 1;
  loadCurrentView('users');
});
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
    if (!id) categoryPage = 1;
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
