-- ====================================================================
-- Project: E-Commerce Sales Funnel & Marketing Attribution Analysis
-- Database: PostgreSQL
-- Author: Rakesh Mahanta
-- ====================================================================

-- 1. Table Schema Setup
CREATE TABLE IF NOT EXISTS user_events (
    event_id INT PRIMARY KEY,
    user_id INT,
    event_type VARCHAR(50),
    event_date TIMESTAMP,
    product_id INT,
    amount NUMERIC(10, 2),
    traffic_source VARCHAR(50)
);

-- 2. Overall Funnel & Step-by-Step Drop-Off Analysis
WITH stage_counts AS (
    SELECT 
        CASE 
            WHEN event_type = 'page_view' THEN 1
            WHEN event_type = 'add_to_cart' THEN 2
            WHEN event_type = 'checkout_start' THEN 3
            WHEN event_type = 'payment_info' THEN 4
            WHEN event_type = 'purchase' THEN 5
        END AS step_order,
        event_type AS stage,
        COUNT(DISTINCT user_id) AS total_users
    FROM user_events
    GROUP BY event_type
)
SELECT 
    step_order,
    stage,
    total_users,
    ROUND(100.0 * total_users / FIRST_VALUE(total_users) OVER (ORDER BY step_order), 2) AS overall_conversion_pct,
    ROUND(100.0 * total_users / LAG(total_users, 1, total_users) OVER (ORDER BY step_order), 2) AS step_conversion_pct,
    ROUND(100.0 - (100.0 * total_users / LAG(total_users, 1, total_users) OVER (ORDER BY step_order)), 2) AS step_drop_off_pct
FROM stage_counts
ORDER BY step_order;

-- 3. Marketing Channel Performance & Attribution
SELECT 
    traffic_source,
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS visitors,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS buyers,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END), 0), 2) AS conversion_rate_pct,
    ROUND(SUM(CASE WHEN event_type = 'purchase' THEN amount ELSE 0 END), 2) AS total_revenue,
    ROUND(AVG(CASE WHEN event_type = 'purchase' THEN amount END), 2) AS avg_order_value
FROM user_events
GROUP BY traffic_source
ORDER BY total_revenue DESC;

-- 4. Cart Abandonment Rate Analysis
WITH cart_users AS (
    SELECT DISTINCT user_id 
    FROM user_events 
    WHERE event_type = 'add_to_cart'
),
purchase_users AS (
    SELECT DISTINCT user_id 
    FROM user_events 
    WHERE event_type = 'purchase'
)
SELECT 
    COUNT(c.user_id) AS added_to_cart,
    COUNT(p.user_id) AS completed_purchase,
    COUNT(c.user_id) - COUNT(p.user_id) AS abandoned_carts,
    ROUND(100.0 * (COUNT(c.user_id) - COUNT(p.user_id)) / COUNT(c.user_id), 2) AS cart_abandonment_pct
FROM cart_users c
LEFT JOIN purchase_users p ON c.user_id = p.user_id;

-- 5. Product-Level Sales & Revenue Contribution
SELECT 
    product_id,
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS total_views,
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS cart_adds,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS total_orders,
    ROUND(SUM(CASE WHEN event_type = 'purchase' THEN amount ELSE 0 END), 2) AS total_revenue,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END), 0), 2) AS view_to_purchase_pct
FROM user_events
GROUP BY product_id
ORDER BY total_revenue DESC;