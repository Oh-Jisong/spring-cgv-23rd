DROP INDEX idx_reservations_reserved_at ON reservations;

SELECT 'Before' AS stage;
EXPLAIN ANALYZE
SELECT id, status, reserved_at, total_price
FROM reservations
WHERE member_id = 1
ORDER BY reserved_at DESC
LIMIT 10;

CREATE INDEX idx_reservations_member_id
ON reservations(member_id);

SELECT 'Single index result' AS stage;
EXPLAIN ANALYZE
SELECT id, status, reserved_at, total_price
FROM reservations
WHERE member_id = 1
ORDER BY reserved_at DESC
LIMIT 10;

DROP INDEX idx_reservations_member_id ON reservations;

CREATE INDEX idx_reservations_member_reserved_at_cover
ON reservations(member_id, reserved_at DESC, status, total_price);

SELECT 'Covering result' AS stage;
EXPLAIN ANALYZE
SELECT id, status, reserved_at, total_price
FROM reservations
WHERE member_id = 1
ORDER BY reserved_at DESC
LIMIT 10;
