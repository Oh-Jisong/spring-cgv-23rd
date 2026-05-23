SELECT 'Before' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM store_orders
ORDER BY total_price DESC
LIMIT 100;

CREATE INDEX idx_store_orders_total_price
ON store_orders(total_price);

SELECT 'After' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM store_orders
ORDER BY total_price DESC
LIMIT 100;
