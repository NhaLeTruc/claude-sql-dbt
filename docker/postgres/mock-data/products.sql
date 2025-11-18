-- Mock product data: 100 products across 5 categories

INSERT INTO raw_data.products (
    product_id,
    product_name,
    sku,
    category,
    subcategory,
    unit_cost,
    list_price,
    is_active,
    updated_at
)
SELECT
    product_id,
    category || ' Product ' || product_id AS product_name,
    'SKU-' || LPAD(product_id::TEXT, 5, '0') AS sku,
    category,
    CASE
        WHEN category = 'Electronics' THEN (ARRAY['Phones', 'Laptops', 'Accessories'])[FLOOR(RANDOM() * 3 + 1)]
        WHEN category = 'Clothing' THEN (ARRAY['Mens', 'Womens', 'Kids'])[FLOOR(RANDOM() * 3 + 1)]
        WHEN category = 'Home & Garden' THEN (ARRAY['Furniture', 'Decor', 'Tools'])[FLOOR(RANDOM() * 3 + 1)]
        WHEN category = 'Books' THEN (ARRAY['Fiction', 'Non-Fiction', 'Reference'])[FLOOR(RANDOM() * 3 + 1)]
        WHEN category = 'Toys' THEN (ARRAY['Educational', 'Games', 'Outdoor'])[FLOOR(RANDOM() * 3 + 1)]
    END AS subcategory,
    FLOOR(RANDOM() * (100 - 60 + 1) + 60)::NUMERIC AS unit_cost,
    FLOOR(RANDOM() * (300 - 100 + 1) + 100)::NUMERIC AS list_price,
    CASE WHEN RANDOM() < 0.9 THEN TRUE ELSE FALSE END AS is_active,
    CURRENT_TIMESTAMP - (RANDOM() * INTERVAL '730 days') AS updated_at
FROM (
    SELECT
        product_id,
        (ARRAY['Electronics', 'Clothing', 'Home & Garden', 'Books', 'Toys'])[((product_id - 1) % 5) + 1] AS category
    FROM generate_series(1, 100) AS product_id
) p;
