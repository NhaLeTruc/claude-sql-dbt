-- Mock order data: 50,000 orders spanning 2022-2024
-- Distributed across customers with realistic patterns

INSERT INTO raw_data.orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    order_total,
    campaign_id,
    created_at,
    updated_at
)
SELECT
    order_id,
    -- Customers with varying order frequencies (some high, some low)
    CASE
        WHEN RANDOM() < 0.2 THEN FLOOR(RANDOM() * 1000 + 1)::INTEGER  -- 20% orders from top 1000 customers
        ELSE FLOOR(RANDOM() * 10000 + 1)::INTEGER  -- 80% spread across all customers
    END AS customer_id,
    DATE '2022-01-01' + (RANDOM() * 1095)::INTEGER AS order_date,
    (ARRAY['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned'])[
        FLOOR(
            CASE
                WHEN RANDOM() < 0.70 THEN 4  -- 70% delivered
                WHEN RANDOM() < 0.85 THEN 3  -- 15% shipped
                WHEN RANDOM() < 0.95 THEN 2  -- 10% processing
                ELSE 1 + RANDOM() * 2  -- 5% other statuses
            END
        )
    ] AS order_status,
    ROUND((20 + RANDOM() * 480)::NUMERIC, 2) AS order_total,
    -- 30% of orders attributed to campaigns
    CASE WHEN RANDOM() < 0.3 THEN FLOOR(RANDOM() * 10 + 1)::INTEGER ELSE NULL END AS campaign_id,
    DATE '2022-01-01' + (RANDOM() * 1095)::INTEGER + (RANDOM() * INTERVAL '1 day') AS created_at,
    DATE '2022-01-01' + (RANDOM() * 1095)::INTEGER + (RANDOM() * INTERVAL '2 days') AS updated_at
FROM generate_series(1, 50000) AS order_id;
