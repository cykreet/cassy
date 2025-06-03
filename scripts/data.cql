-- --------------------------------------------------
-- KEYSPACE 1: user
-- --------------------------------------------------

CREATE KEYSPACE user WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 1,
  'DC2': 1
};

-- Q6: Authenticate user (username/email + password)
CREATE TABLE user.user_login (
  username text,
  email text,
  password_hash text,
  user_id uuid,
  is_active boolean,
  created_at timestamp,
  PRIMARY KEY (username)
);

CREATE TABLE user.user_logins_by_email (
  email text,
  username text,
  password_hash text,
  user_id uuid,
  is_active boolean,
  PRIMARY KEY (email)
);

-- Q7: Get user profile information
-- Q10: Update user profile
CREATE TABLE user.user_profile (
  user_id uuid,
  username text,
  email text,
  first_name text,
  last_name text,
  phone text,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (user_id)
);

-- Q8, Q9: Get/manage all addresses for user
CREATE TABLE user.user_address (
  user_id uuid,
  address_id uuid,
  address_type text, -- 'shipping', 'billing'
  street_address text,
  city text,
  state text,
  postal_code text,
  country text,
  is_default boolean,
  created_at timestamp,
  PRIMARY KEY ((user_id), address_id)
);

-- Q22: Authenticate vendor user
-- Q39: Manage user accounts (admin)
CREATE TABLE user.vendor_user (
  vendor_id uuid,
  user_id uuid,
  username text,
  role text, -- 'admin', 'manager', 'staff'
  permissions set<text>,
  is_active boolean,
  created_at timestamp,
  PRIMARY KEY ((vendor_id), user_id)
);

-- ------------------------------------------------
-- KEYSPACE 2: product
-- ------------------------------------------------

CREATE KEYSPACE product WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 1,
  'DC2': 1
};

-- Q1: Get products by category (with pagination)
CREATE TABLE product.products_by_category (
  category_id uuid,
  product_id uuid,
  vendor_id uuid,
  product_name text,
  description text,
  current_price decimal,
  image_urls list<text>,
  rating_avg decimal,
  review_count int,
  created_at timestamp,
  PRIMARY KEY ((category_id), created_at, product_id)
) WITH CLUSTERING ORDER BY (created_at DESC, product_id ASC);

-- Q2: Search products by keyword/filters
CREATE TABLE product.products_by_search (
  search_term text,
  product_id uuid,
  vendor_id uuid,
  category_id uuid,
  product_name text,
  description text,
  current_price decimal,
  image_urls list<text>,
  rating_avg decimal,
  review_count int,
  relevance_score int,
  PRIMARY KEY ((search_term), relevance_score, product_id)
) WITH CLUSTERING ORDER BY (relevance_score DESC, product_id ASC);

-- Q3: Get product details with current price
-- Q27: Update product details
CREATE TABLE product.product_details (
  product_id uuid,
  vendor_id uuid,
  category_id uuid,
  product_name text,
  description text,
  current_price decimal,
  specifications map<text, text>,
  image_urls list<text>,
  tags set<text>,
  is_active boolean,
  stock_quantity int,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (product_id)
);

-- Q4, Q28: Get product price history / Update pricing
CREATE TABLE product.price_history (
  product_id uuid,
  effective_date timestamp,
  price decimal,
  vendor_id uuid,
  change_reason text,
  PRIMARY KEY ((product_id), effective_date)
) WITH CLUSTERING ORDER BY (effective_date DESC);

-- Q5: Get related/similar products in same category
CREATE TABLE product.related_product (
  product_id uuid,
  related_product_id uuid,
  category_id uuid,
  similarity_score decimal,
  relation_type text, -- 'similar', 'frequently_bought_together', 'viewed_together'
  PRIMARY KEY ((product_id), similarity_score, related_product_id)
) WITH CLUSTERING ORDER BY (similarity_score DESC);

-- Q24: Get all products for vendor
CREATE TABLE product.product_by_vendor (
  vendor_id uuid,
  product_id uuid,
  category_id uuid,
  product_name text,
  current_price decimal,
  stock_quantity int,
  is_active boolean,
  created_at timestamp,
  PRIMARY KEY ((vendor_id), created_at, product_id)
) WITH CLUSTERING ORDER BY (created_at DESC);

-- Q26: Add new product to catalog
-- Q30: Manage product categories
-- Q36: Get all categories
CREATE TABLE product.category (
  category_id uuid,
  parent_category_id uuid,
  category_name text,
  description text,
  level int,
  is_active boolean,
  sort_order int,
  PRIMARY KEY ((category_id))
);

CREATE TABLE product.category_hierarchy (
  parent_category_id uuid,
  level int,
  category_id uuid,
  category_name text,
  sort_order int,
  PRIMARY KEY ((parent_category_id), level, sort_order, category_id)
);

-- Q23: Get vendor details and associated users
CREATE TABLE product.vendor_details (
  vendor_id uuid,
  vendor_name text,
  description text,
  contact_email text,
  contact_phone text,
  business_address text,
  tax_id text,
  is_verified boolean,
  rating_avg decimal,
  total_sales bigint,
  created_at timestamp,
  PRIMARY KEY (vendor_id)
);

-- ------------------------------------------------
-- KEYSPACE 3: order
-- ------------------------------------------------

-- don't try this at home
CREATE KEYSPACE "order" WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 1,
  'DC2': 1
};

-- Q13: Create new order with multiple items
-- Q14: Get order details with all items
CREATE TABLE "order".order_details (
  order_id uuid,
  user_id uuid,
  order_status text, -- 'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'
  total_amount decimal,
  tax_amount decimal,
  shipping_amount decimal,
  shipping_address map<text, text>,
  billing_address map<text, text>,
  payment_method text,
  payment_status text,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (order_id)
);

-- Q15: Get all orders for user (with pagination)
CREATE TABLE "order".orders_by_user (
  user_id uuid,
  order_date timestamp,
  order_id uuid,
  order_status text,
  total_amount decimal,
  item_count int,
  PRIMARY KEY ((user_id), order_date, order_id)
) WITH CLUSTERING ORDER BY (order_date DESC);

-- Q14: Get order details with all items (order items part)
CREATE TABLE "order".order_item (
  order_id uuid,
  item_sequence int,
  product_id uuid,
  vendor_id uuid,
  quantity int,
  unit_price decimal,
  total_price decimal,
  product_name text,
  product_image_url text,
  item_status text, -- 'pending', 'confirmed', 'shipped', 'delivered', 'returned'
  PRIMARY KEY ((order_id), item_sequence)
);

-- Q25: Get vendor's order items (items sold)
-- Q31: Get pending orders for vendor's products
CREATE TABLE "order".order_items_by_vendor (
  vendor_id uuid,
  order_date timestamp,
  order_id uuid,
  item_sequence int,
  product_id uuid,
  user_id uuid,
  quantity int,
  unit_price decimal,
  total_price decimal,
  item_status text,
  PRIMARY KEY ((vendor_id), order_date, order_id, item_sequence)
) WITH CLUSTERING ORDER BY (order_date DESC);

-- Q32: Update order item status
CREATE TABLE "order".order_item_status_history (
  order_id uuid,
  item_sequence int,
  status_timestamp timestamp,
  status text,
  notes text,
  updated_by uuid,
  PRIMARY KEY ((order_id, item_sequence), status_timestamp)
) WITH CLUSTERING ORDER BY (status_timestamp DESC);

-- Q19: Initiate return for order items
-- Q20, Q21: Get return status and details
CREATE TABLE "order".order_return (
  return_id uuid,
  order_id uuid,
  item_sequence int,
  user_id uuid,
  vendor_id uuid,
  product_id uuid,
  return_reason text,
  return_status text, -- 'requested', 'approved', 'rejected', 'processing', 'completed'
  return_quantity int,
  refund_amount decimal,
  return_shipping_cost decimal,
  notes text,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (return_id)
);

CREATE TABLE "order".returns_by_user (
  user_id uuid,
  created_at timestamp,
  return_id uuid,
  order_id uuid,
  return_status text,
  refund_amount decimal,
  PRIMARY KEY ((user_id), created_at, return_id)
) WITH CLUSTERING ORDER BY (created_at DESC);

-- Q35: Track returns for vendor's products
CREATE TABLE "order".returns_by_vendor (
  vendor_id uuid,
  created_at timestamp,
  return_id uuid,
  order_id uuid,
  user_id uuid,
  product_id uuid,
  return_status text,
  refund_amount decimal,
  PRIMARY KEY ((vendor_id), created_at, return_id)
) WITH CLUSTERING ORDER BY (created_at DESC);

-- ------------------------------------------------
-- KEYSPACE 4: shipment
-- ------------------------------------------------

CREATE KEYSPACE shipment WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 1,
  'DC2': 1
};

-- Q16: Get order status and shipment tracking
-- Q17: Get shipment details with tracking info
CREATE TABLE shipment.shipment_details (
  shipment_id uuid,
  order_id uuid,
  vendor_id uuid,
  carrier text,
  tracking_number text,
  shipment_status text, -- 'preparing', 'shipped', 'in_transit', 'delivered', 'exception'
  shipping_address map<text, text>,
  estimated_delivery timestamp,
  actual_delivery timestamp,
  shipping_cost decimal,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (shipment_id)
);

CREATE TABLE shipment.shipments_by_order (
  order_id uuid,
  shipment_id uuid,
  vendor_id uuid,
  tracking_number text,
  shipment_status text,
  carrier text,
  created_at timestamp,
  PRIMARY KEY ((order_id), created_at, shipment_id)
) WITH CLUSTERING ORDER BY (created_at DESC);

-- Q18: Get items in specific shipment
-- Q33: Create shipments for order items
CREATE TABLE shipment.shipment_item (
  shipment_id uuid,
  order_id uuid,
  item_sequence int,
  product_id uuid,
  quantity int,
  product_name text,
  PRIMARY KEY ((shipment_id), item_sequence)
);

-- Q34: Get shipment details for vendor's orders
CREATE TABLE shipment.shipments_by_vendor (
  vendor_id uuid,
  created_at timestamp,
  shipment_id uuid,
  order_id uuid,
  tracking_number text,
  shipment_status text,
  carrier text,
  PRIMARY KEY ((vendor_id), created_at, shipment_id)
) WITH CLUSTERING ORDER BY (created_at DESC);

CREATE TABLE shipment.shipment_tracking_event (
  shipment_id uuid,
  event_timestamp timestamp,
  event_type text, -- 'label_created', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'exception'
  location text,
  description text,
  carrier_event_id text,
  PRIMARY KEY ((shipment_id), event_timestamp)
) WITH CLUSTERING ORDER BY (event_timestamp DESC);

-- --------------------------------------------------
-- KEYSPACE 5: shopping
-- --------------------------------------------------

CREATE KEYSPACE shopping WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 1,
  'DC2': 1
};

-- Q11, Q12: Get/manage user's cart items
CREATE TABLE shopping.user_cart (
  user_id uuid,
  product_id uuid,
  vendor_id uuid,
  quantity int,
  unit_price decimal,
  product_name text,
  product_image_url text,
  added_at timestamp,
  updated_at timestamp,
  PRIMARY KEY ((user_id), product_id)
);

CREATE TABLE shopping.cart_session (
  session_id text,
  user_id uuid,
  created_at timestamp,
  updated_at timestamp,
  expires_at timestamp,
  PRIMARY KEY (session_id)
);

-- --------------------------------------------------
-- KEYSPACE 6: analytics
-- --------------------------------------------------

CREATE KEYSPACE analytics WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 1,
  'DC2': 1
};

-- Q29: Get product performance metrics
CREATE TABLE analytics.product_metric (
  product_id uuid,
  metric_date date,
  views_count decimal,
  orders_count decimal,
  revenue decimal,
  returns_count decimal,
  PRIMARY KEY ((product_id), metric_date)
) WITH CLUSTERING ORDER BY (metric_date DESC);

-- Q37: Manage vendor relationships
CREATE TABLE analytics.vendor_metric (
  vendor_id uuid,
  metric_date date,
  total_orders decimal,
  total_revenue decimal,
  total_returns decimal,
  avg_rating decimal,
  PRIMARY KEY ((vendor_id), metric_date)
) WITH CLUSTERING ORDER BY (metric_date DESC);

-- Q38: Get platform-wide metrics
CREATE TABLE analytics.platform_metric (
  metric_date date,
  metric_type text, -- 'daily_orders', 'daily_revenue', 'new_users', 'active_users'
  value decimal,
  PRIMARY KEY ((metric_date), metric_type)
);