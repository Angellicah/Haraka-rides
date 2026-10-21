CREATE TABLE haraka_staging.trips_staging (
    trip_id TEXT,
    customer_name TEXT,
    customer_phone TEXT,
    customer_area TEXT,
    driver_name TEXT,
    driver_phone TEXT,
    vehicle_plate TEXT,
    vehicle_make TEXT,
    vehicle_model TEXT,
    pickup_area TEXT,
    dropoff_area TEXT,
    trip_date TEXT,
    pickup_time TEXT,
    distance_km TEXT,
    payment_method TEXT,
    status TEXT,
    fare_amount TEXT,
    customer_rating TEXT
);

SELECT COUNT(*)
FROM haraka_staging.trips_staging;

SELECT *
FROM haraka_staging.trips_staging
LIMIT 5;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (
        customer_name,
        customer_phone,
        customer_area,
        driver_name,
        driver_phone,
        vehicle_plate,
        vehicle_make,
        vehicle_model,
        pickup_area,
        dropoff_area,
        trip_date,
        pickup_time,
        distance_km,
        payment_method,
        status,
        fare_amount,
        customer_rating
    )) AS unique_rows
FROM haraka_staging.trips_staging;

SELECT
    status,
    COUNT(*) AS occurrences
FROM haraka_staging.trips_staging
GROUP BY status
ORDER BY occurrences DESC;

--Payment method
SELECT
    payment_method,
    COUNT(*) AS occurrences
FROM haraka_staging.trips_staging
GROUP BY payment_method
ORDER BY occurrences DESC;

--Vehicle make
SELECT
    payment_method,
    COUNT(*) AS occurrences
FROM haraka_staging.trips_staging
GROUP BY payment_method
ORDER BY occurrences DESC;

--Vehicle model
SELECT
    vehicle_make,
    COUNT(*) AS occurrences
FROM haraka_staging.trips_staging
GROUP BY vehicle_make
ORDER BY occurrences DESC;

--Find whitespace columns
SELECT
    vehicle_plate
FROM haraka_staging.trips_staging
WHERE vehicle_plate <> TRIM(vehicle_plate);

--Customer names
SELECT
    customer_name
FROM haraka_staging.trips_staging
WHERE customer_name <> TRIM(customer_name);

--Driver names
SELECT
    customer_name
FROM haraka_staging.trips_staging
WHERE customer_name <> TRIM(customer_name);

-- Profile NULLs n blanks
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(trip_id), '') IS NULL) AS trip_id_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_name), '') IS NULL) AS customer_name_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_phone), '') IS NULL) AS customer_phone_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_area), '') IS NULL) AS customer_area_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(driver_name), '') IS NULL) AS driver_name_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(driver_phone), '') IS NULL) AS driver_phone_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(vehicle_plate), '') IS NULL) AS vehicle_plate_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(trip_date), '') IS NULL) AS trip_date_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(pickup_area), '') IS NULL) AS pickup_area_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(dropoff_area), '') IS NULL) AS dropoff_area_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(distance_km), '') IS NULL) AS distance_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(fare_amount), '') IS NULL) AS fare_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_rating), '') IS NULL) AS rating_missing
FROM haraka_staging.trips_staging;

--Invalid distances
SELECT
    trip_id,
    distance_km
FROM haraka_staging.trips_staging
WHERE NULLIF(TRIM(distance_km), '') IS NOT NULL
  AND distance_km::NUMERIC < 0;

-- Invalid ratings
SELECT
    trip_id,
    customer_rating
FROM haraka_staging.trips_staging
WHERE NULLIF(TRIM(customer_rating), '') IS NOT NULL
  AND UPPER(TRIM(customer_rating)) <> 'NULL'
  AND TRIM(customer_rating)::NUMERIC NOT BETWEEN 1 AND 5;

--Currency formatting
SELECT DISTINCT fare_amount
FROM haraka_staging.trips_staging
ORDER BY fare_amount
LIMIT 30;

--

--Date formatting
SELECT DISTINCT trip_date
FROM haraka_staging.trips_staging
ORDER BY trip_date
LIMIT 50;

--Vehicle recon
SELECT
    COUNT(DISTINCT vehicle_plate) AS raw_trip_plates
FROM haraka_staging.trips_staging;

--Normalize
SELECT
    COUNT(DISTINCT UPPER(TRIM(vehicle_plate))) AS normalized_trip_plates
FROM haraka_staging.trips_staging;

--Trip vehicles that don't appear in fleet
SELECT DISTINCT
    UPPER(TRIM(t.vehicle_plate)) AS trip_plate
FROM haraka_staging.trips_staging t
LEFT JOIN haraka_staging.fleet_staging f
    ON UPPER(TRIM(t.vehicle_plate))
     = UPPER(TRIM(f.vehicle_plate))
WHERE f.vehicle_plate IS NULL;



