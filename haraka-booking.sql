CREATE TABLE haraka_booking.customers (
    customer_id BIGSERIAL PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    customer_phone VARCHAR(30),
    customer_area VARCHAR(100)
);

-- Normalize phones
INSERT INTO haraka_booking.customers (
    customer_name,
    customer_phone,
    customer_area
)
SELECT
    INITCAP(LOWER(TRIM(customer_name))) AS customer_name,
    CASE
        WHEN UPPER(TRIM(customer_phone)) IN ('', 'NULL')
            THEN NULL
        WHEN REGEXP_REPLACE(TRIM(customer_phone), '[^0-9+]', '', 'g')
             LIKE '+254%'
            THEN '0' || SUBSTRING(
                REGEXP_REPLACE(TRIM(customer_phone), '[^0-9+]', '', 'g')
                FROM 5
            )
        ELSE REGEXP_REPLACE(
            TRIM(customer_phone),
            '[^0-9]',
            '',
            'g'
        )
    END AS customer_phone,
    NULLIF(INITCAP(LOWER(TRIM(customer_area))), '') AS customer_area
FROM (
    SELECT DISTINCT ON (
        UPPER(TRIM(customer_name)),
        NULLIF(
            REGEXP_REPLACE(
                TRIM(customer_phone),
                '[^0-9]',
                '',
                'g'
            ),
            ''
        )
    )
        customer_name,
        customer_phone,
        customer_area
    FROM haraka_staging.trips_staging
    WHERE NULLIF(TRIM(customer_name), '') IS NOT NULL
    ORDER BY
        UPPER(TRIM(customer_name)),
        NULLIF(
            REGEXP_REPLACE(
                TRIM(customer_phone),
                '[^0-9]',
                '',
                'g'
            ),
            ''
        ),
        customer_area
) c;

--Check
SELECT *
FROM haraka_booking.customers
ORDER BY customer_id;

--Create drivers
CREATE TABLE haraka_booking.drivers (
    driver_id BIGSERIAL PRIMARY KEY,
    driver_name VARCHAR(150) NOT NULL,
    driver_phone VARCHAR(30)
);
INSERT INTO haraka_booking.drivers (
    driver_name,
    driver_phone
)
SELECT
    INITCAP(LOWER(TRIM(driver_name))) AS driver_name,
    CASE
        WHEN UPPER(TRIM(driver_phone)) IN ('', 'NULL')
            THEN NULL
        WHEN REGEXP_REPLACE(TRIM(driver_phone), '[^0-9+]', '', 'g')
             LIKE '+254%'
            THEN '0' || SUBSTRING(
                REGEXP_REPLACE(TRIM(driver_phone), '[^0-9+]', '', 'g')
                FROM 5
            )
        ELSE REGEXP_REPLACE(
            TRIM(driver_phone),
            '[^0-9]',
            '',
            'g'
        )
    END AS driver_phone
FROM (
    SELECT DISTINCT ON (
        UPPER(TRIM(driver_name)),
        NULLIF(
            REGEXP_REPLACE(
                TRIM(driver_phone),
                '[^0-9]',
                '',
                'g'
            ),
            ''
        )
    )
        driver_name,
        driver_phone
    FROM haraka_staging.trips_staging
    WHERE NULLIF(TRIM(driver_name), '') IS NOT NULL
    ORDER BY
        UPPER(TRIM(driver_name)),
        NULLIF(
            REGEXP_REPLACE(
                TRIM(driver_phone),
                '[^0-9]',
                '',
                'g'
            ),
            ''
        )
) d;

--Cleaningg
CREATE TABLE haraka_booking.trips (
    trip_id VARCHAR(50) PRIMARY KEY,
    customer_id BIGINT REFERENCES haraka_booking.customers(customer_id),
    driver_id BIGINT REFERENCES haraka_booking.drivers(driver_id),
    vehicle_id BIGINT REFERENCES haraka_fleet.vehicles(vehicle_id), 
    pickup_area VARCHAR(100),
    dropoff_area VARCHAR(100),    
    trip_date DATE,
    pickup_time TIME,
    distance_km NUMERIC(10,2),
    payment_method VARCHAR(30),
    status VARCHAR(30),
    fare_amount NUMERIC(12,2),
    customer_rating NUMERIC(3,1)
);

-- Dates
INSERT INTO haraka_booking.trips (
    trip_id,
    customer_id,
    driver_id,
    vehicle_id,
    pickup_area,
    dropoff_area,
    trip_date,
    pickup_time,
    distance_km,
    payment_method,
    status,
    fare_amount,
    customer_rating
)
SELECT
    s.trip_id,
    c.customer_id,
    d.driver_id,
    v.vehicle_id,
    NULLIF(INITCAP(LOWER(TRIM(s.pickup_area))), '') AS pickup_area,
    NULLIF(INITCAP(LOWER(TRIM(s.dropoff_area))), '') AS dropoff_area,
    CASE
        WHEN TRIM(s.trip_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(s.trip_date), 'YYYY-MM-DD')
        WHEN TRIM(s.trip_date) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN TO_DATE(TRIM(s.trip_date), 'DD/MM/YYYY')
        WHEN TRIM(s.trip_date) ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN TO_DATE(TRIM(s.trip_date), 'MM-DD-YYYY')
        WHEN TRIM(s.trip_date) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{2}$'
            THEN TO_DATE(TRIM(s.trip_date), 'DD/MM/YY')
        WHEN TRIM(s.trip_date) ~ '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(s.trip_date), 'MM-DD-YY')
        ELSE NULL
    END AS trip_date,
    CASE
        WHEN NULLIF(TRIM(s.pickup_time), '') IS NOT NULL
             AND UPPER(TRIM(s.pickup_time)) <> 'NULL'
        THEN TRIM(s.pickup_time)::TIME
        ELSE NULL
    END AS pickup_time,
    CASE
        WHEN TRIM(s.distance_km) ~ '^-?[0-9]+(\.[0-9]+)?$'
             AND TRIM(s.distance_km)::NUMERIC >= 0
        THEN TRIM(s.distance_km)::NUMERIC
        ELSE NULL
    END AS distance_km,
    CASE
        WHEN UPPER(TRIM(s.payment_method)) IN ('MPESA', 'M-PESA')
            THEN 'M-Pesa'
        WHEN UPPER(TRIM(s.payment_method)) = 'CARD'
            THEN 'Card'
        WHEN UPPER(TRIM(s.payment_method)) = 'CASH'
            THEN 'Cash'
        ELSE NULL
    END AS payment_method,
    CASE
        WHEN UPPER(TRIM(s.status)) IN ('COMPLETED', 'COMPLETE')
            THEN 'Completed'
        WHEN UPPER(REPLACE(TRIM(s.status), '-', ' '))
             IN ('CANCELLED', 'CANCELED')
            THEN 'Cancelled'
        WHEN UPPER(REPLACE(TRIM(s.status), '-', ' '))
             = 'NO SHOW'
            THEN 'No-Show'
        ELSE NULL
    END AS status,
    CASE
        WHEN REGEXP_REPLACE(
                 UPPER(TRIM(s.fare_amount)),
                 '[^0-9.-]',
                 '',
                 'g'
             ) <> ''
        THEN REGEXP_REPLACE(
                 UPPER(TRIM(s.fare_amount)),
                 '[^0-9.-]',
                 '',
                 'g'
             )::NUMERIC
        ELSE NULL
    END AS fare_amount,
    CASE
        WHEN TRIM(s.customer_rating) ~ '^[0-9]+(\.[0-9]+)?$'
             AND TRIM(s.customer_rating)::NUMERIC BETWEEN 1 AND 5
        THEN TRIM(s.customer_rating)::NUMERIC
        ELSE NULL
    END AS customer_rating
FROM haraka_staging.trips_staging s
LEFT JOIN haraka_booking.customers c
    ON UPPER(TRIM(c.customer_name))
       = UPPER(TRIM(s.customer_name))
   AND (
       c.customer_phone IS NULL
       OR c.customer_phone =
          CASE
              WHEN REGEXP_REPLACE(TRIM(s.customer_phone), '[^0-9+]', '', 'g')
                   LIKE '+254%'
              THEN '0' || SUBSTRING(
                   REGEXP_REPLACE(TRIM(s.customer_phone), '[^0-9+]', '', 'g')
                   FROM 5
              )
              ELSE REGEXP_REPLACE(
                   TRIM(s.customer_phone),
                   '[^0-9]',
                   '',
                   'g'
              )
          END
   )
LEFT JOIN haraka_booking.drivers d
    ON UPPER(TRIM(d.driver_name))
       = UPPER(TRIM(s.driver_name))
LEFT JOIN haraka_fleet.vehicles v
    ON v.plate_number = UPPER(TRIM(s.vehicle_plate))
ON CONFLICT (trip_id) DO NOTHING;

SELECT COUNT(*) AS customers
FROM haraka_booking.customers;

SELECT COUNT(*) AS drivers
FROM haraka_booking.drivers;

SELECT *
FROM haraka_booking.trips
LIMIT 50;

SELECT *
FROM haraka_booking.trips
WHERE customer_id IS NULL
   OR driver_id IS NULL
   OR vehicle_id IS NULL;

SELECT COUNT(*) AS trips