const bearer = [{ bearerAuth: [] }];
const idParam = (name) => ({ name, in: 'path', required: true, schema: { type: 'integer', minimum: 1 } });
const queryParam = (name, schema, description = '') => ({ name, in: 'query', description, schema });
const pageParams = [
  queryParam('page', { type: 'integer', minimum: 1, default: 1 }),
  queryParam('limit', { type: 'integer', minimum: 1, maximum: 50, default: 20 }),
];
const body = (schema) => ({ required: true, content: { 'application/json': { schema: { $ref: `#/components/schemas/${schema}` } } } });
const response = (description) => ({
  description,
  content: { 'application/json': { schema: { $ref: '#/components/schemas/Envelope' } } },
});
const operation = (summary, tag, { private: isPrivate = false, params, request, created = false, conflict = false } = {}) => ({
  summary,
  tags: [tag],
  ...(isPrivate ? { security: bearer } : {}),
  ...(params ? { parameters: params } : {}),
  ...(request ? { requestBody: request } : {}),
  responses: {
    [created ? '201' : '200']: response(created ? 'Tạo thành công' : 'Thành công'),
    '400': response('Dữ liệu không hợp lệ'),
    ...(isPrivate ? { '401': response('Chưa đăng nhập'), '403': response('Không đủ quyền') } : {}),
    '404': response('Không tìm thấy dữ liệu'),
    ...(conflict ? { '409': response('Dữ liệu hoặc trạng thái xung đột') } : {}),
  },
});

export const openapiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'Adidas Shoe Store API',
    version: '1.0.0',
    description: 'REST API cho Flutter và Web Admin. API JSON dùng envelope success/data/message.',
  },
  servers: [{ url: '/api/v1', description: 'API v1' }],
  tags: [
    { name: 'Auth' }, { name: 'Catalog' }, { name: 'Cart' }, { name: 'Wishlist' },
    { name: 'Addresses' }, { name: 'Orders' }, { name: 'Payments' }, { name: 'Reviews' },
    { name: 'Notifications' }, { name: 'Admin' }, { name: 'System' },
  ],
  paths: {
    '/health': { servers: [{ url: '/' }], get: operation('Kiểm tra backend', 'System') },
    '/auth/register': { post: operation('Đăng ký customer', 'Auth', { request: body('Register'), created: true, conflict: true }) },
    '/auth/login': { post: operation('Đăng nhập', 'Auth', { request: body('Login') }) },
    '/auth/me': {
      get: operation('Lấy tài khoản hiện tại', 'Auth', { private: true }),
      put: operation('Cập nhật tên và số điện thoại', 'Auth', { private: true, request: body('ProfileUpdate') }),
    },
    '/auth/password': { put: operation('Đổi mật khẩu', 'Auth', { private: true, request: body('PasswordChange') }) },
    '/categories': {
      get: operation('Danh sách danh mục', 'Catalog'),
      post: operation('Tạo danh mục', 'Catalog', { private: true, request: body('Category'), created: true, conflict: true }),
    },
    '/categories/{id}': {
      put: operation('Cập nhật danh mục', 'Catalog', { private: true, params: [idParam('id')], request: body('Category'), conflict: true }),
      delete: operation('Xóa danh mục chưa có sản phẩm', 'Catalog', { private: true, params: [idParam('id')], conflict: true }),
    },
    '/products': {
      get: operation('Tìm kiếm và lọc sản phẩm', 'Catalog', { params: [
        queryParam('q', { type: 'string' }), queryParam('category', { type: 'string' }),
        queryParam('minPrice', { type: 'number' }), queryParam('maxPrice', { type: 'number' }),
        queryParam('size', { type: 'string' }), queryParam('color', { type: 'string' }),
        queryParam('sort', { type: 'string', enum: ['latest', 'price_asc', 'price_desc'] }), ...pageParams,
      ] }),
      post: operation('Tạo sản phẩm', 'Catalog', { private: true, request: body('Product'), created: true }),
    },
    '/products/{id}': {
      get: operation('Chi tiết sản phẩm', 'Catalog', { params: [idParam('id')] }),
      put: operation('Cập nhật sản phẩm', 'Catalog', { private: true, params: [idParam('id')], request: body('Product') }),
      delete: operation('Ẩn sản phẩm', 'Catalog', { private: true, params: [idParam('id')] }),
    },
    '/products/{id}/reviews': {
      get: operation('Danh sách đánh giá và điểm trung bình', 'Reviews', { params: [idParam('id'), ...pageParams] }),
      post: operation('Đánh giá sản phẩm đã nhận', 'Reviews', { private: true, params: [idParam('id')], request: body('Review'), created: true, conflict: true }),
    },
    '/products/{id}/images': {
      post: {
        ...operation('Tải ảnh sản phẩm (multipart field images)', 'Catalog', { private: true, params: [idParam('id')], created: true }),
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                properties: { images: { type: 'array', items: { type: 'string', format: 'binary' } } },
              },
            },
          },
        },
      },
    },
    '/products/{id}/images/{imageId}': { delete: operation('Xóa ảnh sản phẩm', 'Catalog', { private: true, params: [idParam('id'), idParam('imageId')] }) },
    '/products/{id}/variants': { post: operation('Tạo biến thể', 'Catalog', { private: true, params: [idParam('id')], request: body('Variant'), created: true, conflict: true }) },
    '/products/{id}/variants/{variantId}': {
      put: operation('Cập nhật biến thể', 'Catalog', { private: true, params: [idParam('id'), idParam('variantId')], request: body('Variant'), conflict: true }),
      delete: operation('Xóa biến thể chưa nằm trong giỏ/đơn', 'Catalog', { private: true, params: [idParam('id'), idParam('variantId')], conflict: true }),
    },
    '/cart': { get: operation('Xem giỏ hàng', 'Cart', { private: true }) },
    '/cart/items': {
      post: operation('Thêm biến thể vào giỏ', 'Cart', { private: true, request: body('CartItem'), created: true, conflict: true }),
      delete: operation('Xóa toàn bộ giỏ hàng', 'Cart', { private: true }),
    },
    '/cart/items/{itemId}': {
      put: operation('Cập nhật số lượng giỏ', 'Cart', { private: true, params: [idParam('itemId')], request: body('Quantity'), conflict: true }),
      delete: operation('Xóa dòng giỏ', 'Cart', { private: true, params: [idParam('itemId')] }),
    },
    '/wishlist': { get: operation('Xem wishlist', 'Wishlist', { private: true }) },
    '/wishlist/items': { post: operation('Thêm sản phẩm yêu thích', 'Wishlist', { private: true, request: body('WishlistItem'), created: true, conflict: true }) },
    '/wishlist/items/{productId}': { delete: operation('Bỏ yêu thích', 'Wishlist', { private: true, params: [idParam('productId')] }) },
    '/addresses': {
      get: operation('Danh sách địa chỉ', 'Addresses', { private: true }),
      post: operation('Tạo địa chỉ', 'Addresses', { private: true, request: body('Address'), created: true }),
    },
    '/addresses/{id}': {
      put: operation('Cập nhật địa chỉ', 'Addresses', { private: true, params: [idParam('id')], request: body('Address') }),
      delete: operation('Xóa địa chỉ', 'Addresses', { private: true, params: [idParam('id')] }),
    },
    '/orders': {
      get: operation('Lịch sử đơn hàng', 'Orders', { private: true, params: [queryParam('status', { type: 'string', enum: ['pending', 'confirmed', 'shipping', 'delivered', 'cancelled'] }), ...pageParams] }),
      post: operation('Đặt hàng từ giỏ trong transaction', 'Orders', { private: true, request: body('CreateOrder'), created: true, conflict: true }),
    },
    '/orders/{id}': { get: operation('Chi tiết đơn của tôi', 'Orders', { private: true, params: [idParam('id')] }) },
    '/orders/{id}/cancel': { put: operation('Hủy đơn chưa thanh toán và hoàn tồn kho', 'Orders', { private: true, params: [idParam('id')], conflict: true }) },
    '/payments/sepay/create': { post: operation('Tạo form checkout SePay', 'Payments', { private: true, request: body('SePayCreate'), created: true, conflict: true }) },
    '/payments/sepay/return': { get: operation('URL return để đưa khách hàng về ứng dụng; IPN xác nhận trạng thái', 'Payments') },
    '/payments/sepay/status/{order_id}': { get: operation('Xem trạng thái thanh toán SePay của đơn hàng', 'Payments', { private: true, params: [idParam('order_id')] }) },
    '/payments/sepay/ipn': { post: { summary: 'SePay IPN callback (cần URL HTTPS public)', tags: ['Payments'], parameters: [{ name: 'X-Secret-Key', in: 'header', required: true, schema: { type: 'string' } }], requestBody: body('SePayIpn'), responses: { '200': { description: 'IPN đã được nhận hoặc đã xử lý trước đó' } } } },
    '/notifications': { get: operation('Thông báo của tôi', 'Notifications', { private: true, params: [...pageParams, queryParam('unread', { type: 'string', enum: ['true', 'false'] })] }) },
    '/notifications/read-all': { patch: operation('Đánh dấu tất cả đã đọc', 'Notifications', { private: true }) },
    '/notifications/{id}/read': { patch: operation('Đánh dấu một thông báo đã đọc', 'Notifications', { private: true, params: [idParam('id')] }) },
    '/admin/orders': { get: operation('Danh sách đơn hàng', 'Admin', { private: true, params: [queryParam('status', { type: 'string' }), queryParam('q', { type: 'string' }), ...pageParams] }) },
    '/admin/stats/revenue': { get: operation('Doanh thu đã thanh toán theo ngày hoặc tháng', 'Admin', { private: true, params: [queryParam('group', { type: 'string', enum: ['day', 'month'] }), queryParam('from', { type: 'string', format: 'date' }), queryParam('to', { type: 'string', format: 'date' })] }) },
    '/admin/stats/top-products': { get: operation('Sản phẩm bán chạy theo đơn đã thanh toán', 'Admin', { private: true, params: [queryParam('from', { type: 'string', format: 'date' }), queryParam('to', { type: 'string', format: 'date' }), queryParam('limit', { type: 'integer', minimum: 1, maximum: 50 })] }) },
    '/admin/stats/low-stock': { get: operation('Biến thể tồn kho thấp', 'Admin', { private: true, params: [queryParam('threshold', { type: 'integer', minimum: 0 }), queryParam('limit', { type: 'integer', minimum: 1, maximum: 100 })] }) },
    '/admin/stats/orders-by-status': { get: operation('Số đơn theo trạng thái', 'Admin', { private: true, params: [queryParam('from', { type: 'string', format: 'date' }), queryParam('to', { type: 'string', format: 'date' })] }) },
    '/admin/orders/{id}/status': { put: operation('Cập nhật trạng thái và gửi thông báo khách hàng', 'Admin', { private: true, params: [idParam('id')], request: body('OrderStatus'), conflict: true }) },
    '/admin/users': { get: operation('Tìm kiếm người dùng, không trả password hash', 'Admin', { private: true, params: [queryParam('q', { type: 'string' }), queryParam('role', { type: 'string', enum: ['customer', 'admin'] }), ...pageParams] }) },
    '/admin/users/{id}': {
      get: operation('Chi tiết người dùng', 'Admin', { private: true, params: [idParam('id')] }),
      put: operation('Cập nhật thông tin hoặc quyền người dùng', 'Admin', { private: true, params: [idParam('id')], request: body('AdminUserUpdate'), conflict: true }),
      delete: operation('Xóa người dùng không có đơn hàng', 'Admin', { private: true, params: [idParam('id')], conflict: true }),
    },
    '/admin/chats': { get: operation('Danh sách hội thoại hỗ trợ', 'Admin', { private: true }) },
    '/admin/chats/{customerId}/messages': { get: operation('Lịch sử chat với khách', 'Admin', { private: true, params: [idParam('customerId')] }) },
  },
  components: {
    securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
    schemas: {
      Envelope: { type: 'object', properties: { success: { type: 'boolean' }, data: {}, message: { type: 'string' } } },
      Register: { type: 'object', required: ['name', 'email', 'password'], properties: { name: { type: 'string' }, email: { type: 'string', format: 'email' }, password: { type: 'string', minLength: 6 }, phone: { type: 'string' } } },
      Login: { type: 'object', required: ['email', 'password'], properties: { email: { type: 'string', format: 'email' }, password: { type: 'string' } } },
      ProfileUpdate: { type: 'object', required: ['name'], properties: { name: { type: 'string', minLength: 2, maxLength: 100 }, phone: { type: 'string', maxLength: 20 } } },
      PasswordChange: { type: 'object', required: ['current_password', 'new_password'], properties: { current_password: { type: 'string' }, new_password: { type: 'string', minLength: 6 } } },
      SePayCreate: { type: 'object', required: ['order_id'], properties: { order_id: { type: 'integer', minimum: 1 } } },
      SePayIpn: { type: 'object', required: ['notification_type', 'order', 'transaction'], properties: { timestamp: { type: 'integer' }, notification_type: { type: 'string', enum: ['ORDER_PAID', 'TRANSACTION_VOID'] }, order: { type: 'object', required: ['order_status', 'order_currency', 'order_amount', 'order_invoice_number'], properties: { order_status: { type: 'string' }, order_currency: { type: 'string' }, order_amount: { type: 'string' }, order_invoice_number: { type: 'string' } } }, transaction: { type: 'object', required: ['transaction_status', 'transaction_amount', 'transaction_currency'], properties: { transaction_status: { type: 'string' }, transaction_amount: { type: 'string' }, transaction_currency: { type: 'string' } } } } },
      Category: { type: 'object', required: ['name'], properties: { name: { type: 'string', maxLength: 100 }, slug: { type: 'string', maxLength: 120 }, image: { type: 'string', nullable: true } } },
      Product: { type: 'object', required: ['category_id', 'name', 'price'], properties: { category_id: { type: 'integer' }, name: { type: 'string' }, description: { type: 'string', nullable: true }, price: { type: 'integer', minimum: 0 }, discount_price: { type: 'integer', nullable: true } } },
      Variant: { type: 'object', required: ['size', 'color', 'stock'], properties: { size: { type: 'string' }, color: { type: 'string' }, stock: { type: 'integer', minimum: 0 } } },
      CartItem: { type: 'object', required: ['variant_id'], properties: { variant_id: { type: 'integer' }, quantity: { type: 'integer', minimum: 1, default: 1 } } },
      Quantity: { type: 'object', required: ['quantity'], properties: { quantity: { type: 'integer', minimum: 1 } } },
      WishlistItem: { type: 'object', required: ['product_id'], properties: { product_id: { type: 'integer' } } },
      Address: { type: 'object', required: ['receiver_name', 'phone', 'address_line', 'city'], properties: { receiver_name: { type: 'string' }, phone: { type: 'string' }, address_line: { type: 'string' }, city: { type: 'string' }, is_default: { type: 'boolean' } } },
      CreateOrder: { type: 'object', required: ['address_id'], properties: { address_id: { type: 'integer' }, payment_method: { type: 'string', enum: ['cod', 'sepay', 'momo', 'paypal'] } } },
      OrderStatus: { type: 'object', required: ['status'], properties: { status: { type: 'string', enum: ['pending', 'confirmed', 'shipping', 'delivered', 'cancelled'] } } },
      Review: { type: 'object', required: ['rating'], properties: { rating: { type: 'integer', minimum: 1, maximum: 5 }, comment: { type: 'string', nullable: true } } },
      AdminUserUpdate: { type: 'object', minProperties: 1, properties: { name: { type: 'string' }, phone: { type: 'string', nullable: true }, role: { type: 'string', enum: ['customer', 'admin'] } } },
    },
  },
};
