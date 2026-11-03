-- =====================================================================
-- Adidas Shoe Store - schema.sql (MySQL 8.x / MariaDB 10.5+)
-- Chay:  mysql -u root -p < database/schema.sql
-- =====================================================================

DROP DATABASE IF EXISTS adidas_shop;
CREATE DATABASE adidas_shop
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE adidas_shop;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 1. users
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name           VARCHAR(100)    NOT NULL,
  email          VARCHAR(150)    NOT NULL,
  password_hash  VARCHAR(255)    NOT NULL,
  phone          VARCHAR(20)     NULL,
  role           ENUM('customer','admin') NOT NULL DEFAULT 'customer',
  avatar         VARCHAR(255)    NULL,
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role (role)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. addresses
-- ---------------------------------------------------------------------
CREATE TABLE addresses (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  receiver_name  VARCHAR(100)    NOT NULL,
  phone          VARCHAR(20)     NOT NULL,
  address_line   VARCHAR(255)    NOT NULL,
  city           VARCHAR(100)    NOT NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_addresses_user (user_id),
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. categories
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name   VARCHAR(100)    NOT NULL,
  slug   VARCHAR(120)    NOT NULL,
  image  VARCHAR(255)    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_slug (slug)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. products
-- ---------------------------------------------------------------------
CREATE TABLE products (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id     BIGINT UNSIGNED NOT NULL,
  name            VARCHAR(200)    NOT NULL,
  description     TEXT            NULL,
  price           DECIMAL(12,0)   NOT NULL,            -- VND, khong co phan thap phan
  discount_price  DECIMAL(12,0)   NULL,
  main_image      VARCHAR(255)    NULL,
  is_active       TINYINT(1)      NOT NULL DEFAULT 1,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_products_category (category_id),
  KEY idx_products_active_created (is_active, created_at),
  KEY idx_products_price (price),
  FULLTEXT KEY ft_products_name (name),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id)
    REFERENCES categories (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_products_price CHECK (price >= 0),
  CONSTRAINT chk_products_discount CHECK (discount_price IS NULL OR (discount_price >= 0 AND discount_price <= price))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. product_images
-- ---------------------------------------------------------------------
CREATE TABLE product_images (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id  BIGINT UNSIGNED NOT NULL,
  url         VARCHAR(255)    NOT NULL,
  PRIMARY KEY (id),
  KEY idx_product_images_product (product_id),
  CONSTRAINT fk_product_images_product FOREIGN KEY (product_id)
    REFERENCES products (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. product_variants (size + mau + ton kho)
-- ---------------------------------------------------------------------
CREATE TABLE product_variants (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id  BIGINT UNSIGNED NOT NULL,
  size        VARCHAR(10)     NOT NULL,                -- vi du: 40, 41, 42 (EU)
  color       VARCHAR(50)     NOT NULL,
  stock       INT UNSIGNED    NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_variant (product_id, size, color),
  KEY idx_variants_size (size),
  KEY idx_variants_color (color),
  CONSTRAINT fk_variants_product FOREIGN KEY (product_id)
    REFERENCES products (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. carts (moi user 1 gio hang)
-- ---------------------------------------------------------------------
CREATE TABLE carts (
  id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_carts_user (user_id),
  CONSTRAINT fk_carts_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. cart_items
-- ---------------------------------------------------------------------
CREATE TABLE cart_items (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cart_id     BIGINT UNSIGNED NOT NULL,
  variant_id  BIGINT UNSIGNED NOT NULL,
  quantity    INT UNSIGNED    NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cart_variant (cart_id, variant_id),
  KEY idx_cart_items_variant (variant_id),
  CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id)
    REFERENCES carts (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cart_items_variant FOREIGN KEY (variant_id)
    REFERENCES product_variants (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_cart_quantity CHECK (quantity > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. wishlists
-- ---------------------------------------------------------------------
CREATE TABLE wishlists (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_wishlist (user_id, product_id),
  KEY idx_wishlists_product (product_id),
  CONSTRAINT fk_wishlists_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_wishlists_product FOREIGN KEY (product_id)
    REFERENCES products (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 10. orders
--   address_id giu tham chieu; shipping_* la ban sao tai thoi diem dat
--   hang de xoa/sua dia chi khong lam sai don cu.
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id          BIGINT UNSIGNED NOT NULL,
  address_id       BIGINT UNSIGNED NULL,
  shipping_name    VARCHAR(100)    NOT NULL,
  shipping_phone   VARCHAR(20)     NOT NULL,
  shipping_address VARCHAR(400)    NOT NULL,
  total_amount     DECIMAL(12,0)   NOT NULL,
  status           ENUM('pending','confirmed','shipping','delivered','cancelled')
                   NOT NULL DEFAULT 'pending',
  payment_method   VARCHAR(30)     NOT NULL DEFAULT 'cod',   -- cod | vnpay | momo | paypal
  payment_status   ENUM('unpaid','paid','failed','refunded')
                   NOT NULL DEFAULT 'unpaid',
  created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_orders_user (user_id),
  KEY idx_orders_address (address_id),
  KEY idx_orders_status (status),
  KEY idx_orders_created (created_at),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_orders_address FOREIGN KEY (address_id)
    REFERENCES addresses (id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_orders_total CHECK (total_amount >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 11. order_items (unit_price = gia luc mua)
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id    BIGINT UNSIGNED NOT NULL,
  variant_id  BIGINT UNSIGNED NOT NULL,
  quantity    INT UNSIGNED    NOT NULL,
  unit_price  DECIMAL(12,0)   NOT NULL,
  PRIMARY KEY (id),
  KEY idx_order_items_order (order_id),
  KEY idx_order_items_variant (variant_id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id)
    REFERENCES orders (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_order_items_variant FOREIGN KEY (variant_id)
    REFERENCES product_variants (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_order_items_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 12. payments (1 don co the co nhieu lan thanh toan)
-- ---------------------------------------------------------------------
CREATE TABLE payments (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id        BIGINT UNSIGNED NOT NULL,
  provider        VARCHAR(30)     NOT NULL,                  -- cod | vnpay | momo | paypal
  transaction_id  VARCHAR(100)    NULL,
  amount          DECIMAL(12,0)   NOT NULL,
  status          ENUM('pending','success','failed','refunded') NOT NULL DEFAULT 'pending',
  raw_response    TEXT            NULL,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_payments_order (order_id),
  UNIQUE KEY uq_payments_provider_txn (provider, transaction_id),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
    REFERENCES orders (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 13. reviews (moi user danh gia 1 san pham 1 lan)
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id  BIGINT UNSIGNED NOT NULL,
  user_id     BIGINT UNSIGNED NOT NULL,
  rating      TINYINT UNSIGNED NOT NULL,
  comment     TEXT            NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_review (user_id, product_id),
  KEY idx_reviews_product (product_id),
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id)
    REFERENCES products (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reviews_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 14. messages (chat)
-- ---------------------------------------------------------------------
CREATE TABLE messages (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sender_id    BIGINT UNSIGNED NOT NULL,
  receiver_id  BIGINT UNSIGNED NOT NULL,
  content      TEXT            NOT NULL,
  is_read      TINYINT(1)      NOT NULL DEFAULT 0,
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_messages_pair (sender_id, receiver_id, created_at),
  KEY idx_messages_receiver (receiver_id, is_read),
  CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_messages_receiver FOREIGN KEY (receiver_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 15. notifications
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  title       VARCHAR(200)    NOT NULL,
  body        TEXT            NULL,
  is_read     TINYINT(1)      NOT NULL DEFAULT 0,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notifications_user (user_id, is_read, created_at),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
