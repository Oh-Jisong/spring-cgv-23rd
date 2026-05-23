DROP DATABASE IF EXISTS cgv_index_lab;
CREATE DATABASE cgv_index_lab;
USE cgv_index_lab;

CREATE TABLE digits (
    n INT PRIMARY KEY
);

INSERT INTO digits (n)
VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9);

CREATE TABLE seq_100k (
    n INT PRIMARY KEY
);

INSERT INTO seq_100k (n)
SELECT
    ones.n
    + tens.n * 10
    + hundreds.n * 100
    + thousands.n * 1000
    + ten_thousands.n * 10000
    + 1 AS n
FROM digits ones
CROSS JOIN digits tens
CROSS JOIN digits hundreds
CROSS JOIN digits thousands
CROSS JOIN digits ten_thousands
WHERE
    ones.n
    + tens.n * 10
    + hundreds.n * 100
    + thousands.n * 1000
    + ten_thousands.n * 10000
    + 1 <= 100000;

CREATE TABLE movies (
    id BIGINT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    genre VARCHAR(30) NOT NULL,
    running_time INT NOT NULL,
    created_at DATETIME NOT NULL
);

INSERT INTO movies (id, title, genre, running_time, created_at)
SELECT
    n AS id,
    CONCAT('Movie ', n) AS title,
    CASE
        WHEN MOD(n, 5) = 0 THEN 'ACTION'
        WHEN MOD(n, 5) = 1 THEN 'DRAMA'
        WHEN MOD(n, 5) = 2 THEN 'COMEDY'
        WHEN MOD(n, 5) = 3 THEN 'THRILLER'
        ELSE 'ANIMATION'
    END AS genre,
    90 + MOD(n, 60) AS running_time,
    NOW() - INTERVAL MOD(n, 365) DAY AS created_at
FROM seq_100k
WHERE n <= 200;

CREATE TABLE screenings (
    id BIGINT PRIMARY KEY,
    movie_id BIGINT NOT NULL,
    theater_id BIGINT NOT NULL,
    screen_name VARCHAR(50) NOT NULL,
    start_time DATETIME NOT NULL,
    remaining_seats INT NOT NULL,
    created_at DATETIME NOT NULL
);

INSERT INTO screenings (
    id,
    movie_id,
    theater_id,
    screen_name,
    start_time,
    remaining_seats,
    created_at
)
SELECT
    n AS id,
    1 + MOD(n, 200) AS movie_id,
    1 + MOD(n, 30) AS theater_id,
    CONCAT(1 + MOD(n, 10), '관') AS screen_name,
    DATE_ADD(
        DATE_ADD(CURDATE(), INTERVAL (MOD(n, 90) - 30) DAY),
        INTERVAL (8 + MOD(n, 14)) HOUR
    ) AS start_time,
    MOD(n * 7, 180) AS remaining_seats,
    NOW() - INTERVAL MOD(n, 180) DAY AS created_at
FROM seq_100k
WHERE n <= 50000;

CREATE TABLE reservations (
    id BIGINT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    screening_id BIGINT NOT NULL,
    movie_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    reserved_at DATETIME NOT NULL,
    total_price INT NOT NULL,
    created_at DATETIME NOT NULL
);

INSERT INTO reservations (
    id,
    member_id,
    screening_id,
    movie_id,
    status,
    reserved_at,
    total_price,
    created_at
)
SELECT
    n AS id,
    CASE
        WHEN n <= 150 THEN 1
        ELSE 2 + MOD(n, 4999)
    END AS member_id,
    1 + MOD(n, 50000) AS screening_id,
    1 + MOD(1 + MOD(n, 50000), 200) AS movie_id,
    CASE
        WHEN MOD(n, 100) < 80 THEN 'CONFIRMED'
        WHEN MOD(n, 100) < 95 THEN 'CANCELLED'
        ELSE 'PENDING'
    END AS status,
    DATE_SUB(NOW(), INTERVAL MOD(n * 37, 180 * 24 * 60) MINUTE) AS reserved_at,
    12000 + MOD(n * 137, 60000) AS total_price,
    DATE_SUB(NOW(), INTERVAL MOD(n * 37, 180 * 24 * 60) MINUTE) AS created_at
FROM seq_100k
WHERE n <= 100000;

CREATE TABLE store_orders (
    id BIGINT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    ordered_at DATETIME NOT NULL,
    total_price INT NOT NULL,
    created_at DATETIME NOT NULL
);

INSERT INTO store_orders (
    id,
    member_id,
    status,
    ordered_at,
    total_price,
    created_at
)
SELECT
    n AS id,
    CASE
        WHEN n <= 200 THEN 1
        ELSE 2 + MOD(n, 4999)
    END AS member_id,
    CASE
        WHEN MOD(n, 100) < 70 THEN 'PAID'
        WHEN MOD(n, 100) < 85 THEN 'COMPLETED'
        WHEN MOD(n, 100) < 95 THEN 'READY'
        ELSE 'CANCELLED'
    END AS status,
    DATE_SUB(NOW(), INTERVAL MOD(n * 53, 180 * 24 * 60) MINUTE) AS ordered_at,
    3000 + MOD(n * 97, 50000) AS total_price,
    DATE_SUB(NOW(), INTERVAL MOD(n * 53, 180 * 24 * 60) MINUTE) AS created_at
FROM seq_100k
WHERE n <= 100000;

ANALYZE TABLE movies;
ANALYZE TABLE screenings;
ANALYZE TABLE reservations;
ANALYZE TABLE store_orders;
