-- ==========================================================
-- STORED PROCEDURES, FUNCTIONS & TRIGGERS
-- ==========================================================

-- 1. Stored Procedure for Atomic Order Placement (ACID Compliant)
CREATE OR REPLACE PROCEDURE process_order(
    p_customer_id INT,
    p_product_id INT,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_price NUMERIC(10, 2);
    v_available_stock INT;
    v_customer_balance NUMERIC(10, 2);
    v_total_cost NUMERIC(10, 2);
    v_new_order_id INT;
BEGIN
    -- Lock product and customer rows to prevent race conditions (Concurrency Control)
    SELECT price, stock_quantity INTO v_product_price, v_available_stock 
    FROM products WHERE product_id = p_product_id FOR UPDATE;

    SELECT wallet_balance INTO v_customer_balance 
    FROM customers WHERE customer_id = p_customer_id FOR UPDATE;

    -- Validation Checks
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product or Customer not found.';
    END IF;

    IF v_available_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', v_available_stock, p_quantity;
    END IF;

    v_total_cost := v_product_price * p_quantity;

    IF v_customer_balance < v_total_cost THEN
        RAISE EXCEPTION 'Insufficient funds. Balance: %, Required: %', v_customer_balance, v_total_cost;
    END IF;

    -- Execute Transaction Operations
    -- Deduct customer wallet balance
    UPDATE customers 
    SET wallet_balance = wallet_balance - v_total_cost 
    WHERE customer_id = p_customer_id;

    -- Deduct product stock
    UPDATE products 
    SET stock_quantity = stock_quantity - p_quantity, 
        updated_at = CURRENT_TIMESTAMP 
    WHERE product_id = p_product_id;

    -- Insert Order Record
    INSERT INTO orders (customer_id, total_amount, status) 
    VALUES (p_customer_id, v_total_cost, 'COMPLETED')
    RETURNING order_id INTO v_new_order_id;

    -- Insert Order Item Detail
    INSERT INTO order_items (order_id, product_id, quantity, subtotal) 
    VALUES (v_new_order_id, p_product_id, p_quantity, v_total_cost);

    -- Log transaction success
    INSERT INTO audit_logs (event_description) 
    VALUES ('Successfully processed order #' || v_new_order_id || ' for customer #' || p_customer_id);

    COMMIT;
    RAISE NOTICE 'Order #% processed successfully!', v_new_order_id;
END;
$$;


-- 2. Custom Function to Calculate Total Customer Spend
CREATE OR REPLACE FUNCTION get_customer_lifetime_value(p_customer_id INT)
RETURNS NUMERIC AS $$
DECLARE
    v_total_spend NUMERIC(10, 2);
BEGIN
    SELECT COALESCE(SUM(total_amount), 0.00) INTO v_total_spend
    FROM orders
    WHERE customer_id = p_customer_id AND status = 'COMPLETED';
    
    RETURN v_total_spend;
END;
$$ LANGUAGE plpgsql;


-- 3. Trigger Function for Auto-Logging Stock Updates
CREATE OR REPLACE FUNCTION log_product_update()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.stock_quantity <> NEW.stock_quantity THEN
        INSERT INTO audit_logs (event_description)
        VALUES ('Product ID ' || NEW.product_id || ' stock updated from ' || OLD.stock_quantity || ' to ' || NEW.stock_quantity);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Bind Trigger to Products Table
CREATE TRIGGER trg_audit_stock_change
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_product_update();