SELECT 'Before' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM reservations
WHERE member_id = 1;

CREATE INDEX idx_reservations_member_id
ON reservations(member_id);

SELECT 'After' AS stage;
EXPLAIN ANALYZE
SELECT *
FROM reservations
WHERE member_id = 1;
