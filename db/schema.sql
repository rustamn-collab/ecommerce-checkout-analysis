-- ============================================
-- E-commerce Checkout System — Database Schema
-- PostgreSQL 14
-- ============================================

-- Расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 1. USERS — Пользователи
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20) UNIQUE,
    name VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);

-- ============================================
-- 2. PRODUCTS — Товары
-- ============================================
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(64) NOT NULL UNIQUE,
    price DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
    dimensions JSONB,
    weight DECIMAL(8, 2) CHECK (weight >= 0),
    category VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category ON products(category);

-- ============================================
-- 3. WAREHOUSES — Склады
-- ============================================
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    address JSONB NOT NULL,
    region VARCHAR(64),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_warehouses_region ON warehouses(region);
CREATE INDEX idx_warehouses_is_active ON warehouses(is_active);

-- ============================================
-- 4. STOCK — Остатки
-- ============================================
CREATE TABLE stock (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    reserved INT NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_stock_product_warehouse UNIQUE (product_id, warehouse_id),
    CONSTRAINT check_quantity_reserved CHECK (quantity >= reserved)
);

CREATE INDEX idx_stock_product_id ON stock(product_id);

-- ============================================
-- 5. CARTS — Корзины
-- ============================================
CREATE TABLE carts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_carts_user_id ON carts(user_id);

-- ============================================
-- 6. CART_ITEMS — Позиции корзины
-- ============================================
CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    quantity INT NOT NULL CHECK (quantity > 0 AND quantity <= 99),
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_cart_product UNIQUE (cart_id, product_id)
);

CREATE INDEX idx_cart_items_cart_id ON cart_items(cart_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);

-- ============================================
-- 7. ORDERS — Заказы (партиционирование по месяцам)
-- ============================================
CREATE TABLE orders (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(32) NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL CHECK (subtotal >= 0),
    delivery_amount DECIMAL(12, 2) NOT NULL CHECK (delivery_amount >= 0),
    total_amount DECIMAL(12, 2) NOT NULL CHECK (total_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'RUB',
    erp_order_number VARCHAR(64),
    reservation_expires_at TIMESTAMPTZ,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2026_10 PARTITION OF orders
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE orders_2026_11 PARTITION OF orders
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE orders_2026_12 PARTITION OF orders
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_orders_reservation_expires_at ON orders(reservation_expires_at);
CREATE INDEX idx_orders_idempotency_key ON orders(idempotency_key);

-- ============================================
-- 8. ORDER_ITEMS — Позиции заказа
-- ============================================
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL,
    product_id UUID NOT NULL REFERENCES products(id),
    warehouse_id UUID REFERENCES warehouses(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    price DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
    total DECIMAL(12, 2) NOT NULL CHECK (total >= 0),
    status VARCHAR(32) NOT NULL DEFAULT 'RESERVED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_warehouse_id ON order_items(warehouse_id);

-- ============================================
-- 9. ORDER_STATUS_HISTORY — История статусов
-- ============================================
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL,
    from_status VARCHAR(32),
    to_status VARCHAR(32) NOT NULL,
    reason VARCHAR(255),
    triggered_by VARCHAR(64),
    event_id UUID UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_status_history_order_id ON order_status_history(order_id);
CREATE INDEX idx_status_history_event_id ON order_status_history(event_id);
CREATE INDEX idx_status_history_created_at ON order_status_history(created_at);

-- ============================================
-- 10. PAYMENTS — Платежи
-- ============================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    amount DECIMAL(12, 2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'RUB',
    status VARCHAR(32) NOT NULL,
    method VARCHAR(32) NOT NULL,
    external_id VARCHAR(128) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_external_id ON payments(external_id);
CREATE INDEX idx_payments_status ON payments(status);

-- ============================================
-- 11. DELIVERIES — Доставки
-- ============================================
CREATE TABLE deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    address JSONB NOT NULL,
    slot_start TIMESTAMPTZ NOT NULL,
    slot_end TIMESTAMPTZ NOT NULL,
    courier_service VARCHAR(64),
    tracking_number VARCHAR(128),
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_slot_interval CHECK (slot_end > slot_start)
);

CREATE INDEX idx_deliveries_order_id ON deliveries(order_id);
CREATE INDEX idx_deliveries_tracking_number ON deliveries(tracking_number);
CREATE INDEX idx_deliveries_status ON deliveries(status);
CREATE INDEX idx_deliveries_slot_start ON deliveries(slot_start);

-- ============================================
-- ТРИГГЕРЫ: auto-update updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_carts_updated_at
    BEFORE UPDATE ON carts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_deliveries_updated_at
    BEFORE UPDATE ON deliveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_stock_updated_at
    BEFORE UPDATE ON stock
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- КОММЕНТАРИИ К ТАБЛИЦАМ
-- ============================================
COMMENT ON TABLE users IS 'Пользователи системы';
COMMENT ON TABLE carts IS 'Корзины пользователей';
COMMENT ON TABLE cart_items IS 'Позиции корзин';
COMMENT ON TABLE orders IS 'Заказы (партиционированы по месяцам)';
COMMENT ON TABLE order_items IS 'Позиции заказов';
COMMENT ON TABLE order_status_history IS 'История изменения статусов заказов';
COMMENT ON TABLE payments IS 'Платежи';
COMMENT ON TABLE deliveries IS 'Доставки';
COMMENT ON TABLE products IS 'Товары';
COMMENT ON TABLE warehouses IS 'Склады';
COMMENT ON TABLE stock IS 'Остатки товаров на складах';

COMMENT ON COLUMN orders.status IS 'DRAFT, PENDING_PAYMENT, PAID, CONFIRMED, ASSEMBLING, READY_FOR_SHIPMENT, IN_TRANSIT, DELIVERED, PAYMENT_FAILED, EXPIRED, CANCELLED, REFUND_PENDING';
COMMENT ON COLUMN payments.status IS 'INIT, PENDING, SUCCESS, FAILED, REFUNDED';
COMMENT ON COLUMN deliveries.status IS 'PENDING, ASSIGNED, IN_TRANSIT, DELIVERED, CANCELLED';
COMMENT ON COLUMN order_items.status IS 'RESERVED, SHIPPED, CANCELLED';
