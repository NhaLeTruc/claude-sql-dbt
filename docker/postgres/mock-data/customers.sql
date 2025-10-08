-- Mock customer data: 10,000 customers
-- Uses generate_series for reproducible synthetic data

INSERT INTO raw_data.customers (
    customer_id,
    email,
    name,
    signup_date,
    segment,
    state,
    country,
    updated_at
)
SELECT
    customer_id,
    'customer' || customer_id || '@example.com' AS email,
    'Customer ' || customer_id AS name,
    DATE '2022-01-01' + (RANDOM() * 1095)::INTEGER AS signup_date,
    (ARRAY['new', 'active', 'at-risk', 'dormant', 'vip'])[FLOOR(RANDOM() * 5 + 1)] AS segment,
    (ARRAY['CA', 'NY', 'TX', 'FL', 'WA', 'IL', 'PA', 'OH', 'GA', 'NC'])[FLOOR(RANDOM() * 10 + 1)] AS state,
    'USA' AS country,
    CURRENT_TIMESTAMP - (RANDOM() * INTERVAL '365 days') AS updated_at
FROM generate_series(1, 10000) AS customer_id;
