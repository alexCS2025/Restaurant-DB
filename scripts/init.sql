CREATE DATABASE IF NOT EXISTS restaurant_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE restaurant_db;

CREATE TABLE restaurants (
    restaurant_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(85) NOT NULL,
    address VARCHAR(255) NOT NULL,
    restaurant_phone VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    customer_email VARCHAR(254) NOT NULL UNIQUE,
    customer_phone VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(150) NOT NULL UNIQUE,
    contact_person_name VARCHAR(100) NOT NULL,
    contact_person_phone VARCHAR(20) NOT NULL
);

CREATE TABLE ingredients (
    ingredient_id INT AUTO_INCREMENT PRIMARY KEY,
    ingredient_name VARCHAR(100) NOT NULL UNIQUE,
    ingredient_unit VARCHAR(10) NOT NULL,
    CONSTRAINT chk_ingredients_unit CHECK (CHAR_LENGTH(TRIM(ingredient_unit)) > 0)
);

CREATE TABLE meals (
    meal_id INT AUTO_INCREMENT PRIMARY KEY,
    meal_name VARCHAR(120) NOT NULL UNIQUE,
    meal_category VARCHAR(50) NOT NULL,
    meal_price DECIMAL(10, 2) NOT NULL,
    meal_weight_grams DECIMAL(8, 2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_meals_price CHECK (meal_price >= 0),
    CONSTRAINT chk_meals_weight CHECK (meal_weight_grams > 0)
);

CREATE TABLE restaurant_stock (
    restaurant_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    min_threshold DECIMAL(10, 3) NOT NULL DEFAULT 0.000,
    PRIMARY KEY (restaurant_id, ingredient_id),
    CONSTRAINT chk_restaurant_stock_threshold CHECK (min_threshold >= 0),
    CONSTRAINT fk_restaurant_stock_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants (restaurant_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_restaurant_stock_ingredient
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (ingredient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE recipes (
    meal_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    quantity_per_serving DECIMAL(10, 3) NOT NULL,
    PRIMARY KEY (meal_id, ingredient_id),
    CONSTRAINT chk_recipes_quantity CHECK (quantity_per_serving > 0),
    CONSTRAINT fk_recipes_meal
        FOREIGN KEY (meal_id) REFERENCES meals (meal_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_recipes_ingredient
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (ingredient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    login VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    user_role VARCHAR(20) NOT NULL,
    customer_id INT NULL UNIQUE,
    restaurant_id INT NULL,
    CONSTRAINT fk_users_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_users_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants (restaurant_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_users_role CHECK (user_role IN ('admin', 'staff', 'customer')),
    CONSTRAINT chk_users_role_exclusive CHECK (
        (user_role = 'admin' AND restaurant_id IS NULL AND customer_id IS NULL) OR
        (user_role = 'staff' AND restaurant_id IS NOT NULL AND customer_id IS NULL) OR
        (user_role = 'customer' AND customer_id IS NOT NULL AND restaurant_id IS NULL)
    )
);

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NULL,
    restaurant_id INT NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    order_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status VARCHAR(20) NOT NULL DEFAULT 'new',
    INDEX idx_orders_restaurant_datetime (restaurant_id, order_datetime),
    CONSTRAINT chk_orders_payment_method CHECK (payment_method IN ('card', 'cash')),
    CONSTRAINT chk_orders_status CHECK (order_status IN ('new', 'preparing', 'ready', 'completed', 'cancelled')),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_orders_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants (restaurant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE order_items (
    order_id INT NOT NULL,
    meal_id INT NOT NULL,
    item_quantity INT NOT NULL,
    price_at_order DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, meal_id),
    CONSTRAINT chk_order_items_quantity CHECK (item_quantity > 0),
    CONSTRAINT chk_order_items_price CHECK (price_at_order >= 0),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_order_items_meal
        FOREIGN KEY (meal_id) REFERENCES meals (meal_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE supplies (
    supply_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    restaurant_id INT NOT NULL,
    supply_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    supply_status VARCHAR(20) NOT NULL DEFAULT 'draft',
    CONSTRAINT chk_supplies_status CHECK (supply_status IN ('draft', 'received', 'cancelled')),
    CONSTRAINT fk_supplies_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_supplies_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants (restaurant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE supply_items (
    supply_item_id INT AUTO_INCREMENT PRIMARY KEY,
    supply_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    supplied_quantity DECIMAL(10, 3) NOT NULL,
    purchase_price_per_unit DECIMAL(10, 2) NOT NULL,
    expires_at DATETIME NOT NULL,
    remaining_quantity DECIMAL(10, 3) NOT NULL DEFAULT (supplied_quantity),
    UNIQUE (supply_id, ingredient_id),
    CONSTRAINT chk_remaining_quantity CHECK (remaining_quantity >= 0 AND remaining_quantity <= supplied_quantity),
    CONSTRAINT chk_supply_items_quantity CHECK (supplied_quantity > 0),
    CONSTRAINT chk_supply_items_price CHECK (purchase_price_per_unit >= 0),
    CONSTRAINT fk_supply_items_supply
        FOREIGN KEY (supply_id) REFERENCES supplies (supply_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_supply_items_ingredient
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (ingredient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE stock_movements (
    movement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    supply_item_id INT NOT NULL,
    order_id INT NULL,
    quantity_delta DECIMAL(10, 3) NOT NULL,
    movement_type VARCHAR(30) NOT NULL,
    movement_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_movements_batch_datetime (supply_item_id, movement_datetime),
    INDEX idx_movements_datetime (movement_datetime),
    CONSTRAINT chk_movements_type CHECK (movement_type IN ('order_out', 'order_return', 'expired_writeoff')),
    CONSTRAINT chk_movements_delta_sign CHECK (
        (movement_type IN ('order_out', 'expired_writeoff') AND quantity_delta < 0) OR
        (movement_type = 'order_return' AND quantity_delta > 0)
    ),
    CONSTRAINT fk_supply_item_id
        FOREIGN KEY (supply_item_id) REFERENCES supply_items (supply_item_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_movements_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_movements_order_id
        CHECK ((movement_type IN ('order_out', 'order_return') AND order_id IS NOT NULL)
        OR (movement_type = 'expired_writeoff' AND order_id IS NULL))
);