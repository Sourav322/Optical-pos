-- ============================================================
-- OPTICAL SAAS - Complete PostgreSQL Database Schema
-- Multi-Tenant Architecture
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- SUBSCRIPTION PLANS
-- ============================================================
CREATE TABLE subscription_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  price_monthly DECIMAL(10,2) NOT NULL,
  price_yearly DECIMAL(10,2),
  max_users INTEGER DEFAULT 5,
  max_products INTEGER DEFAULT 500,
  max_invoices_per_month INTEGER DEFAULT 1000,
  features JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TENANTS (Shops)
-- ============================================================
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(20),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100) DEFAULT 'India',
  pincode VARCHAR(20),
  gst_number VARCHAR(20),
  pan_number VARCHAR(20),
  logo_url TEXT,
  subscription_plan_id UUID REFERENCES subscription_plans(id),
  subscription_status VARCHAR(20) DEFAULT 'trial' CHECK (subscription_status IN ('trial','active','suspended','expired','cancelled')),
  subscription_start_date DATE,
  subscription_end_date DATE,
  trial_end_date DATE DEFAULT (CURRENT_DATE + INTERVAL '14 days'),
  is_active BOOLEAN DEFAULT TRUE,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'staff' CHECK (role IN ('super_admin','shop_admin','staff','optometrist')),
  is_active BOOLEAN DEFAULT TRUE,
  last_login TIMESTAMPTZ,
  refresh_token TEXT,
  avatar_url TEXT,
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, email)
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);

-- ============================================================
-- SUPPLIERS
-- ============================================================
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  contact_person VARCHAR(200),
  email VARCHAR(255),
  phone VARCHAR(20),
  address TEXT,
  gst_number VARCHAR(20),
  payment_terms VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suppliers_tenant ON suppliers(tenant_id);

-- ============================================================
-- PRODUCT CATEGORIES
-- ============================================================
CREATE TABLE product_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  parent_id UUID REFERENCES product_categories(id),
  description TEXT,
  icon VARCHAR(50),
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_categories_tenant ON product_categories(tenant_id);

-- ============================================================
-- PRODUCTS / INVENTORY
-- ============================================================
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  category_id UUID REFERENCES product_categories(id),
  supplier_id UUID REFERENCES suppliers(id),
  name VARCHAR(300) NOT NULL,
  brand VARCHAR(100),
  model VARCHAR(100),
  barcode VARCHAR(100),
  sku VARCHAR(100),
  description TEXT,
  cost_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  selling_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  mrp DECIMAL(10,2),
  tax_rate DECIMAL(5,2) DEFAULT 18.00,
  hsn_code VARCHAR(20),
  stock_quantity INTEGER DEFAULT 0,
  min_stock_level INTEGER DEFAULT 5,
  unit VARCHAR(20) DEFAULT 'piece',
  -- Optical specific fields
  lens_type VARCHAR(50),
  coating VARCHAR(100),
  index_value DECIMAL(4,2),
  color VARCHAR(50),
  size VARCHAR(50),
  frame_type VARCHAR(50),
  material VARCHAR(100),
  gender VARCHAR(20),
  -- Contact lens specific
  base_curve DECIMAL(4,2),
  diameter DECIMAL(4,2),
  water_content INTEGER,
  wear_duration VARCHAR(50),
  -- Media
  image_url TEXT,
  images JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT TRUE,
  is_service BOOLEAN DEFAULT FALSE,
  track_inventory BOOLEAN DEFAULT TRUE,
  barcode_type VARCHAR(20) DEFAULT 'CODE128',
  tags JSONB DEFAULT '[]',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, barcode),
  UNIQUE(tenant_id, sku)
);

CREATE INDEX idx_products_tenant ON products(tenant_id);
CREATE INDEX idx_products_barcode ON products(tenant_id, barcode);
CREATE INDEX idx_products_category ON products(tenant_id, category_id);
CREATE INDEX idx_products_name ON products USING gin(to_tsvector('english', name));

-- ============================================================
-- STOCK MOVEMENTS
-- ============================================================
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  movement_type VARCHAR(20) NOT NULL CHECK (movement_type IN ('purchase','sale','return','adjustment','transfer','damage')),
  quantity INTEGER NOT NULL,
  quantity_before INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  reference_type VARCHAR(50),
  reference_id UUID,
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_tenant ON stock_movements(tenant_id);

-- ============================================================
-- PURCHASE ORDERS
-- ============================================================
CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES suppliers(id),
  po_number VARCHAR(50) NOT NULL,
  invoice_number VARCHAR(100),
  invoice_date DATE,
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft','ordered','received','partial','cancelled')),
  subtotal DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) DEFAULT 0,
  paid_amount DECIMAL(10,2) DEFAULT 0,
  notes TEXT,
  received_by UUID REFERENCES users(id),
  received_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, po_number)
);

CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL,
  received_quantity INTEGER DEFAULT 0,
  cost_price DECIMAL(10,2) NOT NULL,
  tax_rate DECIMAL(5,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL
);

-- ============================================================
-- CUSTOMERS
-- ============================================================
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(255),
  date_of_birth DATE,
  gender VARCHAR(10),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  pincode VARCHAR(20),
  gstin VARCHAR(20),
  notes TEXT,
  total_purchases DECIMAL(12,2) DEFAULT 0,
  total_visits INTEGER DEFAULT 0,
  last_visit DATE,
  loyalty_points INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_customers_tenant ON customers(tenant_id);
CREATE INDEX idx_customers_phone ON customers(tenant_id, phone);
CREATE INDEX idx_customers_name ON customers USING gin(to_tsvector('english', name));

-- ============================================================
-- PRESCRIPTIONS
-- ============================================================
CREATE TABLE prescriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id),
  prescribed_by UUID REFERENCES users(id),
  prescription_date DATE DEFAULT CURRENT_DATE,
  -- Right Eye (OD)
  od_sph DECIMAL(5,2),
  od_cyl DECIMAL(5,2),
  od_axis INTEGER,
  od_add DECIMAL(4,2),
  od_pd DECIMAL(4,1),
  od_va VARCHAR(10),
  od_prism DECIMAL(4,2),
  -- Left Eye (OS)
  os_sph DECIMAL(5,2),
  os_cyl DECIMAL(5,2),
  os_axis INTEGER,
  os_add DECIMAL(4,2),
  os_pd DECIMAL(4,1),
  os_va VARCHAR(10),
  os_prism DECIMAL(4,2),
  -- Combined PD
  pd_combined DECIMAL(5,1),
  near_pd DECIMAL(5,1),
  -- Lens specifications
  lens_type VARCHAR(50),
  coating VARCHAR(200),
  is_bluecut BOOLEAN DEFAULT FALSE,
  is_photochromic BOOLEAN DEFAULT FALSE,
  is_high_index BOOLEAN DEFAULT FALSE,
  index_value VARCHAR(10),
  -- Remarks
  remarks TEXT,
  diagnosis TEXT,
  next_checkup_date DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_prescriptions_customer ON prescriptions(customer_id);
CREATE INDEX idx_prescriptions_tenant ON prescriptions(tenant_id);

-- ============================================================
-- ORDERS
-- ============================================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  order_number VARCHAR(50) NOT NULL,
  customer_id UUID REFERENCES customers(id),
  prescription_id UUID REFERENCES prescriptions(id),
  status VARCHAR(30) DEFAULT 'frame_selected' CHECK (status IN (
    'frame_selected','prescription_added','lens_selected',
    'order_created','lab_processing','fitting_done','ready','delivered','cancelled'
  )),
  -- Pricing
  subtotal DECIMAL(10,2) DEFAULT 0,
  discount_type VARCHAR(10) DEFAULT 'flat',
  discount_value DECIMAL(10,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) DEFAULT 0,
  paid_amount DECIMAL(10,2) DEFAULT 0,
  balance_amount DECIMAL(10,2) DEFAULT 0,
  -- Dates
  expected_delivery_date DATE,
  delivered_date DATE,
  -- Staff
  created_by UUID REFERENCES users(id),
  assigned_to UUID REFERENCES users(id),
  optometrist_id UUID REFERENCES users(id),
  -- Notes
  notes TEXT,
  internal_notes TEXT,
  -- Invoice
  invoice_number VARCHAR(50),
  invoice_date DATE DEFAULT CURRENT_DATE,
  -- Lab
  lab_name VARCHAR(200),
  lab_order_number VARCHAR(100),
  lab_sent_date DATE,
  -- Advance
  advance_amount DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, order_number)
);

CREATE INDEX idx_orders_tenant ON orders(tenant_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(tenant_id, status);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  item_type VARCHAR(20) DEFAULT 'product' CHECK (item_type IN ('frame','lens','contact_lens','accessory','service','other')),
  name VARCHAR(300) NOT NULL,
  brand VARCHAR(100),
  sku VARCHAR(100),
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  discount_percent DECIMAL(5,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  tax_rate DECIMAL(5,2) DEFAULT 18,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL,
  -- Lens specific
  lens_power VARCHAR(200),
  coating VARCHAR(200),
  notes TEXT
);

CREATE TABLE order_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  payment_mode VARCHAR(20) NOT NULL CHECK (payment_mode IN ('cash','upi','card','cheque','bank_transfer','credit')),
  amount DECIMAL(10,2) NOT NULL,
  reference_number VARCHAR(100),
  payment_date TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE order_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status VARCHAR(30),
  to_status VARCHAR(30) NOT NULL,
  notes TEXT,
  changed_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INVOICES (POS Billing)
-- ============================================================
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  invoice_number VARCHAR(50) NOT NULL,
  order_id UUID REFERENCES orders(id),
  customer_id UUID REFERENCES customers(id),
  customer_name VARCHAR(200),
  customer_phone VARCHAR(20),
  customer_gstin VARCHAR(20),
  invoice_date DATE DEFAULT CURRENT_DATE,
  due_date DATE,
  -- Amounts
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  cgst_amount DECIMAL(10,2) DEFAULT 0,
  sgst_amount DECIMAL(10,2) DEFAULT 0,
  igst_amount DECIMAL(10,2) DEFAULT 0,
  total_tax DECIMAL(10,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  round_off DECIMAL(4,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  paid_amount DECIMAL(10,2) DEFAULT 0,
  balance_amount DECIMAL(10,2) DEFAULT 0,
  -- Status
  status VARCHAR(20) DEFAULT 'paid' CHECK (status IN ('draft','sent','paid','partial','cancelled','refunded')),
  payment_mode VARCHAR(20),
  -- Meta
  notes TEXT,
  terms_conditions TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, invoice_number)
);

CREATE INDEX idx_invoices_tenant ON invoices(tenant_id);
CREATE INDEX idx_invoices_date ON invoices(tenant_id, invoice_date);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);

CREATE TABLE invoice_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  name VARCHAR(300) NOT NULL,
  hsn_code VARCHAR(20),
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  discount_percent DECIMAL(5,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  taxable_amount DECIMAL(10,2) NOT NULL,
  cgst_rate DECIMAL(5,2) DEFAULT 9,
  cgst_amount DECIMAL(10,2) DEFAULT 0,
  sgst_rate DECIMAL(5,2) DEFAULT 9,
  sgst_amount DECIMAL(10,2) DEFAULT 0,
  igst_rate DECIMAL(5,2) DEFAULT 0,
  igst_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL
);

-- ============================================================
-- EXPENSE TRACKING
-- ============================================================
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  category VARCHAR(100),
  description TEXT,
  amount DECIMAL(10,2) NOT NULL,
  expense_date DATE DEFAULT CURRENT_DATE,
  payment_mode VARCHAR(20),
  receipt_url TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUDIT LOG
-- ============================================================
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id),
  user_id UUID REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50),
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_tenant ON audit_logs(tenant_id, created_at);

-- ============================================================
-- SYSTEM SETTINGS
-- ============================================================
CREATE TABLE tenant_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE UNIQUE,
  invoice_prefix VARCHAR(20) DEFAULT 'INV',
  order_prefix VARCHAR(20) DEFAULT 'ORD',
  currency VARCHAR(10) DEFAULT 'INR',
  currency_symbol VARCHAR(5) DEFAULT '₹',
  tax_type VARCHAR(10) DEFAULT 'GST',
  default_tax_rate DECIMAL(5,2) DEFAULT 18,
  thermal_printer_width INTEGER DEFAULT 80,
  upi_id VARCHAR(100),
  upi_qr_url TEXT,
  bank_name VARCHAR(100),
  bank_account_number VARCHAR(50),
  bank_ifsc VARCHAR(20),
  invoice_footer_text TEXT,
  low_stock_alert_email BOOLEAN DEFAULT TRUE,
  email_invoices BOOLEAN DEFAULT FALSE,
  whatsapp_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Default subscription plans
INSERT INTO subscription_plans (name, description, price_monthly, price_yearly, max_users, max_products, features) VALUES
('Starter', 'Perfect for small optical shops', 999.00, 9990.00, 3, 200, '{"pos":true,"inventory":true,"crm":true,"reports":false,"multi_branch":false}'),
('Professional', 'For growing optical businesses', 1999.00, 19990.00, 10, 1000, '{"pos":true,"inventory":true,"crm":true,"reports":true,"multi_branch":false,"barcode":true}'),
('Enterprise', 'For optical chains and franchises', 4999.00, 49990.00, 50, 10000, '{"pos":true,"inventory":true,"crm":true,"reports":true,"multi_branch":true,"barcode":true,"api":true}');

-- Super Admin User (no tenant)
INSERT INTO users (name, email, password_hash, role) VALUES
('Super Admin', 'admin@opticalsaas.com', crypt('SuperAdmin@123', gen_salt('bf', 12)), 'super_admin');

-- Sample Tenant
INSERT INTO tenants (name, slug, email, phone, address, city, state, gst_number, subscription_plan_id, subscription_status, subscription_start_date, subscription_end_date)
SELECT 'Clear Eyes Optical', 'clear-eyes-optical', 'admin@cleareyesoptical.com', '+91-9876543210',
       '123 Main Street, MG Road', 'Bengaluru', 'Karnataka', '29ABCDE1234F1Z5',
       id, 'active', CURRENT_DATE, CURRENT_DATE + INTERVAL '365 days'
FROM subscription_plans WHERE name = 'Professional' LIMIT 1;

-- ============================================================
-- VIEWS FOR REPORTING
-- ============================================================

CREATE VIEW v_daily_sales AS
SELECT
  i.tenant_id,
  i.invoice_date,
  COUNT(*) as invoice_count,
  SUM(i.subtotal) as subtotal,
  SUM(i.total_tax) as tax_collected,
  SUM(i.discount_amount) as discounts_given,
  SUM(i.total_amount) as gross_revenue,
  SUM(CASE WHEN i.status = 'paid' THEN i.total_amount ELSE 0 END) as collected_revenue
FROM invoices i
WHERE i.status != 'cancelled'
GROUP BY i.tenant_id, i.invoice_date;

CREATE VIEW v_product_sales_summary AS
SELECT
  ii.product_id,
  p.tenant_id,
  p.name as product_name,
  p.brand,
  p.category_id,
  COUNT(*) as times_sold,
  SUM(ii.quantity) as total_quantity,
  SUM(ii.total_amount) as total_revenue,
  SUM(ii.quantity * p.cost_price) as total_cost,
  SUM(ii.total_amount) - SUM(ii.quantity * p.cost_price) as gross_profit
FROM invoice_items ii
JOIN products p ON p.id = ii.product_id
JOIN invoices inv ON inv.id = ii.invoice_id
WHERE inv.status != 'cancelled'
GROUP BY ii.product_id, p.tenant_id, p.name, p.brand, p.category_id, p.cost_price;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ language 'plpgsql';

-- Apply to relevant tables
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
