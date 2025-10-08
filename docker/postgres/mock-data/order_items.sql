-- Mock order items data: ~150,000 items (average 3 per order)
-- Generates line items for orders with realistic product distributions

INSERT INTO raw_data.order_items (
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount,
    line_total
)
SELECT
    ROW_NUMBER() OVER () AS order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount,
    ROUND((quantity * unit_price - discount)::NUMERIC, 2) AS line_total
FROM (
    SELECT
        order_id,
        FLOOR(RANDOM() * 100 + 1)::INTEGER AS product_id,
        FLOOR(RANDOM() * 5 + 1)::INTEGER AS quantity,
        ROUND((20 + RANDOM() * 180)::NUMERIC, 2) AS unit_price,
        CASE
            WHEN RANDOM() < 0.3 THEN ROUND((RANDOM() * 20)::NUMERIC, 2)  -- 30% have discount
            ELSE 0
        END AS discount
    FROM (
        -- Generate 1-5 line items per order
        SELECT
            order_id,
            item_num
        FROM generate_series(1, 50000) AS order_id,
             generate_series(1, FLOOR(RANDOM() * 5 + 1)::INTEGER) AS item_num
    ) items
) final;
