DROP INDEX idx_reservations_member_id ON reservations;

SELECT 'Before' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM reservations
WHERE status = 'CONFIRMED'
  AND reserved_at >= DATE_SUB(NOW(), INTERVAL 3 DAY);

CREATE INDEX idx_reservations_status
ON reservations(status);

SELECT 'Status only result' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM reservations
WHERE status = 'CONFIRMED'
  AND reserved_at >= DATE_SUB(NOW(), INTERVAL 3 DAY);

DROP INDEX idx_reservations_status ON reservations;

CREATE INDEX idx_reservations_reserved_at
ON reservations(reserved_at);

SELECT 'Reserved_at result' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM reservations
WHERE status = 'CONFIRMED'
  AND reserved_at >= DATE_SUB(NOW(), INTERVAL 3 DAY);
