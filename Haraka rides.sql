CREATE SCHEMA staging;

CREATE TABLE staging.trips_staging (
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

CREATE TABLE staging.fleet_staging (
    log_id TEXT,
    vehicle_plate TEXT,
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_year TEXT,
    vehicle_type TEXT,
    vehicle_status TEXT,
    event_type TEXT,
    event_date TEXT,
    liters TEXT,
    fuel_cost TEXT,
    odometer_reading TEXT,
    station_name TEXT,
    service_type TEXT,
    maintenance_cost TEXT,
    mechanic_name TEXT,
    next_service_due TEXT
);


SELECT 'trips_staging' AS table_name, COUNT(*) AS row_count
FROM staging.trips_staging
UNION ALL
SELECT 'fleet_staging', COUNT(*)
FROM staging.fleet_staging;

WITH values_to_check AS (
    SELECT 'trips.status' AS column_name, status AS raw_value
    FROM staging.trips_staging
    UNION ALL
    SELECT 'trips.payment_method', payment_method
    FROM staging.trips_staging
    UNION ALL
    SELECT 'fleet.event_type', event_type
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'fleet.vehicle_status', vehicle_status
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'fleet.vehicle_make', vehicle_make
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'fleet.vehicle_model', vehicle_model
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'fleet.vehicle_type', vehicle_type
    FROM staging.fleet_staging
)
SELECT
    column_name,
    lower(trim(raw_value)) AS normalized_value,
    count(DISTINCT raw_value) AS raw_variants,
    array_agg(DISTINCT raw_value ORDER BY raw_value) AS examples
FROM values_to_check
WHERE raw_value IS NOT NULL
  AND trim(raw_value) <> ''
GROUP BY column_name, lower(trim(raw_value))
HAVING count(DISTINCT raw_value) > 1
ORDER BY column_name, normalized_value;

WITH fields AS (
    SELECT 'date' AS kind, 'trips.trip_date' AS field, trip_date AS raw_value
    FROM staging.trips_staging
    UNION ALL
    SELECT 'date', 'fleet.event_date', event_date
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'date', 'fleet.next_service_due', next_service_due
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'money', 'trips.fare_amount', fare_amount
    FROM staging.trips_staging
    UNION ALL
    SELECT 'money', 'fleet.fuel_cost', fuel_cost
    FROM staging.fleet_staging
    UNION ALL
    SELECT 'money', 'fleet.maintenance_cost', maintenance_cost
    FROM staging.fleet_staging
),
classified AS (
    SELECT
        kind,
        field,
        CASE
            WHEN raw_value IS NULL OR trim(raw_value) = '' THEN 'blank'
            WHEN kind = 'date' AND raw_value ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 'YYYY-MM-DD'
            WHEN kind = 'date' AND raw_value ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 'D/M/YYYY or M/D/YYYY'
            WHEN kind = 'date' AND raw_value ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$' THEN 'D/M/YY or M/D/YY'
            WHEN kind = 'date' AND raw_value ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$' THEN 'M-D-YYYY or D-M-YYYY'
            WHEN kind = 'date' AND raw_value ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}$' THEN 'M-D-YY or D-M-YY'
            WHEN kind = 'date' THEN 'other date format'
            WHEN raw_value ~* '^KES[[:space:]]*[0-9,]+([.][0-9]+)?$' THEN 'KES-prefixed'
            WHEN raw_value ~ '^[0-9]+,[0-9]{3}([.][0-9]+)?$' THEN 'comma-formatted number'
            WHEN raw_value ~ '^[0-9]+([.][0-9]+)?$' THEN 'plain number'
            ELSE 'other money format'
        END AS format_type,
        raw_value
    FROM fields
)
SELECT
    field,
    format_type,
    count(*) AS rows,
    min(raw_value) AS example
FROM classified
GROUP BY field, format_type
ORDER BY field, format_type;

SELECT 'trips' AS dataset, c.column_name,
       count(*) FILTER (
           WHERE c.raw_value IS NULL OR trim(c.raw_value) = ''
       ) AS blank_rows
FROM staging.trips_staging t
CROSS JOIN LATERAL (VALUES
    ('trip_id', t.trip_id),
    ('customer_name', t.customer_name),
    ('customer_phone', t.customer_phone),
    ('customer_area', t.customer_area),
    ('driver_name', t.driver_name),
    ('driver_phone', t.driver_phone),
    ('vehicle_plate', t.vehicle_plate),
    ('vehicle_make', t.vehicle_make),
    ('vehicle_model', t.vehicle_model),
    ('pickup_area', t.pickup_area),
    ('dropoff_area', t.dropoff_area),
    ('trip_date', t.trip_date),
    ('pickup_time', t.pickup_time),
    ('distance_km', t.distance_km),
    ('payment_method', t.payment_method),
    ('status', t.status),
    ('fare_amount', t.fare_amount),
    ('customer_rating', t.customer_rating)
) AS c(column_name, raw_value)
GROUP BY c.column_name

UNION ALL

SELECT 'fleet', c.column_name,
       count(*) FILTER (
           WHERE c.raw_value IS NULL OR trim(c.raw_value) = ''
       )
FROM staging.fleet_staging f
CROSS JOIN LATERAL (VALUES
    ('log_id', f.log_id),
    ('vehicle_plate', f.vehicle_plate),
    ('vehicle_make', f.vehicle_make),
    ('vehicle_model', f.vehicle_model),
    ('vehicle_year', f.vehicle_year),
    ('vehicle_type', f.vehicle_type),
    ('vehicle_status', f.vehicle_status),
    ('event_type', f.event_type),
    ('event_date', f.event_date),
    ('liters', f.liters),
    ('fuel_cost', f.fuel_cost),
    ('odometer_reading', f.odometer_reading),
    ('station_name', f.station_name),
    ('service_type', f.service_type),
    ('maintenance_cost', f.maintenance_cost),
    ('mechanic_name', f.mechanic_name),
    ('next_service_due', f.next_service_due)
) AS c(column_name, raw_value)
GROUP BY c.column_name
ORDER BY dataset, column_name;


WITH trip_plates AS (
    SELECT DISTINCT vehicle_plate, upper(trim(vehicle_plate)) AS normalized
    FROM staging.trips_staging
),
fleet_plates AS (
    SELECT DISTINCT vehicle_plate, upper(trim(vehicle_plate)) AS normalized
    FROM staging.fleet_staging
),
trip_normalized AS (
    SELECT DISTINCT normalized FROM trip_plates
),
fleet_normalized AS (
    SELECT DISTINCT normalized FROM fleet_plates
)
SELECT
    (SELECT count(*) FROM trip_plates) AS trips_raw_distinct,
    (SELECT count(*) FROM trip_normalized) AS trips_normalized_distinct,
    (SELECT count(*) FROM fleet_plates) AS fleet_raw_distinct,
    (SELECT count(*) FROM fleet_normalized) AS fleet_normalized_distinct,
    (SELECT count(*) FROM trip_normalized t
     JOIN fleet_normalized f USING (normalized)) AS plates_in_both;


WITH trip_plates AS (
    SELECT DISTINCT upper(trim(vehicle_plate)) AS plate
    FROM staging.trips_staging
),
fleet_plates AS (
    SELECT DISTINCT upper(trim(vehicle_plate)) AS plate
    FROM staging.fleet_staging
)
SELECT
    upper(trim(f.vehicle_plate)) AS normalized_plate,
    array_agg(DISTINCT f.vehicle_plate ORDER BY f.vehicle_plate) AS raw_spellings
FROM staging.fleet_staging f
WHERE upper(trim(f.vehicle_plate)) NOT IN (SELECT plate FROM trip_plates)
GROUP BY upper(trim(f.vehicle_plate));

CREATE SCHEMA fleet;
CREATE SCHEMA booking;

CREATE TABLE fleet.vehicles (
    vehicle_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plate_number TEXT NOT NULL UNIQUE,
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_year SMALLINT,
    vehicle_type TEXT,
    vehicle_status TEXT
);

CREATE TABLE booking.customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    customer_area TEXT
);

CREATE TABLE booking.drivers (
    driver_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    driver_name TEXT NOT NULL,
    driver_phone TEXT
);

CREATE TABLE fleet.fuel_logs (
    fuel_log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_log_id TEXT,
    vehicle_id BIGINT NOT NULL REFERENCES fleet.vehicles(vehicle_id),
    event_date DATE,
    liters NUMERIC(10, 2),
    fuel_cost NUMERIC(12, 2),
    odometer_reading INTEGER,
    station_name TEXT
);

CREATE TABLE fleet.fuel_logs (
    fuel_log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_log_id TEXT,
    vehicle_id BIGINT NOT NULL REFERENCES fleet.vehicles(vehicle_id),
    event_date DATE,
    liters NUMERIC(10, 2),
    fuel_cost NUMERIC(12, 2),
    odometer_reading INTEGER,
    station_name TEXT
);

CREATE TABLE fleet.maintenance_logs (
    maintenance_log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_log_id TEXT,
    vehicle_id BIGINT NOT NULL REFERENCES fleet.vehicles(vehicle_id),
    event_date DATE,
    service_type TEXT,
    maintenance_cost NUMERIC(12, 2),
    mechanic_name TEXT,
    next_service_due DATE
);

CREATE TABLE booking.trips (
    trip_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_trip_id TEXT,
    customer_id BIGINT NOT NULL REFERENCES booking.customers(customer_id),
    driver_id BIGINT NOT NULL REFERENCES booking.drivers(driver_id),
    vehicle_id BIGINT NOT NULL REFERENCES fleet.vehicles(vehicle_id),
    pickup_area TEXT,
    dropoff_area TEXT,
    trip_date DATE,
    pickup_time TIME,
    distance_km NUMERIC(10, 2),
    payment_method TEXT,
    status TEXT,
    fare_amount NUMERIC(12, 2),
    customer_rating SMALLINT
);

INSERT INTO fleet.vehicles (
    plate_number,
    vehicle_make,
    vehicle_model,
    vehicle_year,
    vehicle_type,
    vehicle_status
)
SELECT
    upper(trim(vehicle_plate)) AS plate_number,
    initcap(min(lower(trim(vehicle_make)))) AS vehicle_make,
    initcap(min(lower(trim(vehicle_model)))) AS vehicle_model,
    min(NULLIF(trim(vehicle_year), '')::SMALLINT) AS vehicle_year,
    initcap(min(lower(trim(vehicle_type)))) AS vehicle_type,
    initcap(min(lower(trim(vehicle_status)))) AS vehicle_status
FROM staging.fleet_staging
GROUP BY upper(trim(vehicle_plate))
ON CONFLICT (plate_number) DO NOTHING;

SELECT vehicle_id, plate_number, vehicle_make, vehicle_model, vehicle_year
FROM fleet.vehicles
ORDER BY plate_number;


WITH people AS (
    SELECT
        'customer' AS person_type,
        lower(trim(customer_name)) AS normalized_name,
        NULLIF(regexp_replace(customer_phone, '[^0-9]', '', 'g'), '') AS normalized_phone
    FROM staging.trips_staging

    UNION ALL

    SELECT
        'driver',
        lower(trim(driver_name)),
        NULLIF(regexp_replace(driver_phone, '[^0-9]', '', 'g'), '')
    FROM staging.trips_staging
)
SELECT
    person_type,
    normalized_name,
    count(DISTINCT normalized_phone) AS different_phones,
    array_agg(DISTINCT normalized_phone ORDER BY normalized_phone) AS phones
FROM people
WHERE normalized_phone IS NOT NULL
GROUP BY person_type, normalized_name
HAVING count(DISTINCT normalized_phone) > 1
ORDER BY person_type, normalized_name;

WITH people AS (
    SELECT
        'customer' AS person_type,
        lower(trim(customer_name)) AS normalized_name,
        CASE
            WHEN digits ~ '^254' THEN '0' || substr(digits, 4)
            ELSE digits
        END AS normalized_phone
    FROM (
        SELECT customer_name,
               NULLIF(regexp_replace(customer_phone, '[^0-9]', '', 'g'), '') AS digits
        FROM staging.trips_staging
    ) c

    UNION ALL

    SELECT
        'driver',
        lower(trim(driver_name)),
        CASE
            WHEN digits ~ '^254' THEN '0' || substr(digits, 4)
            ELSE digits
        END
    FROM (
        SELECT driver_name,
               NULLIF(regexp_replace(driver_phone, '[^0-9]', '', 'g'), '') AS digits
        FROM staging.trips_staging
    ) d
),
conflicts AS (
    SELECT person_type, 'name_has_multiple_phones' AS issue,
           normalized_name AS key_value,
           count(DISTINCT normalized_phone) AS count_found,
           array_agg(DISTINCT normalized_phone ORDER BY normalized_phone) AS examples
    FROM people
    WHERE normalized_phone IS NOT NULL
    GROUP BY person_type, normalized_name
    HAVING count(DISTINCT normalized_phone) > 1

    UNION ALL

    SELECT person_type, 'phone_has_multiple_names',
           normalized_phone,
           count(DISTINCT normalized_name),
           array_agg(DISTINCT normalized_name ORDER BY normalized_name)
    FROM people
    WHERE normalized_phone IS NOT NULL
    GROUP BY person_type, normalized_phone
    HAVING count(DISTINCT normalized_name) > 1
)
SELECT *
FROM conflicts
ORDER BY person_type, issue, key_value;

WITH customer_rows AS (
    SELECT
        lower(trim(customer_name)) AS name_key,
        CASE
            WHEN digits ~ '^254' THEN '0' || substr(digits, 4)
            ELSE digits
        END AS phone,
        NULLIF(lower(trim(customer_area)), '') AS area
    FROM (
        SELECT customer_name,
               customer_area,
               NULLIF(regexp_replace(customer_phone, '[^0-9]', '', 'g'), '') AS digits
        FROM staging.trips_staging
    ) s
)
INSERT INTO booking.customers (customer_name, customer_phone, customer_area)
SELECT
    initcap(name_key),
    max(phone),
    mode() WITHIN GROUP (ORDER BY area)
FROM customer_rows
GROUP BY name_key;

WITH driver_rows AS (
    SELECT
        lower(trim(driver_name)) AS name_key,
        CASE
            WHEN digits ~ '^254' THEN '0' || substr(digits, 4)
            ELSE digits
        END AS phone
    FROM (
        SELECT driver_name,
               NULLIF(regexp_replace(driver_phone, '[^0-9]', '', 'g'), '') AS digits
        FROM staging.trips_staging
    ) s
)
INSERT INTO booking.drivers (driver_name, driver_phone)
SELECT initcap(name_key), max(phone)
FROM driver_rows
GROUP BY name_key;

SELECT 'customers' AS table_name, count(*) AS row_count
FROM booking.customers
UNION ALL
SELECT 'drivers', count(*)
FROM booking.drivers;

SELECT
    trip_id,
    distance_km,
    customer_rating
FROM staging.trips_staging
WHERE
    CASE
        WHEN trim(distance_km) ~ '^-?[0-9]+([.][0-9]+)?$'
        THEN trim(distance_km)::NUMERIC < 0
        ELSE false
    END
    OR
    CASE
        WHEN trim(customer_rating) ~ '^-?[0-9]+$'
        THEN trim(customer_rating)::INTEGER NOT BETWEEN 1 AND 5
        ELSE false
    END
ORDER BY trip_id;

SELECT
    count(*) AS duplicate_groups,
    coalesce(sum(copies - 1), 0) AS extra_duplicate_rows
FROM (
    SELECT count(*) AS copies
    FROM staging.trips_staging t
    GROUP BY to_jsonb(t)
    HAVING count(*) > 1
) d;


WITH unique_trips AS (
    SELECT DISTINCT *
    FROM staging.trips_staging
)
SELECT
    count(*) AS unique_trip_rows,
    count(*) FILTER (WHERE c.customer_id IS NULL) AS unmatched_customers,
    count(*) FILTER (WHERE d.driver_id IS NULL) AS unmatched_drivers,
    count(*) FILTER (WHERE v.vehicle_id IS NULL) AS unmatched_vehicles
FROM unique_trips t
LEFT JOIN booking.customers c
    ON lower(trim(c.customer_name)) = lower(trim(t.customer_name))
LEFT JOIN booking.drivers d
    ON lower(trim(d.driver_name)) = lower(trim(t.driver_name))
LEFT JOIN fleet.vehicles v
    ON upper(trim(v.plate_number)) = upper(trim(t.vehicle_plate));

WITH unique_trips AS (
    SELECT DISTINCT *
    FROM staging.trips_staging
),
mapped_trips AS (
    SELECT
        t.trip_id AS source_trip_id,
        c.customer_id,
        d.driver_id,
        v.vehicle_id,
        t.pickup_area,
        t.dropoff_area,

        CASE
            WHEN t.trip_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN t.trip_date::DATE
            WHEN t.trip_date ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN to_date(t.trip_date, 'DD/MM/YYYY')
            WHEN t.trip_date ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                THEN to_date(t.trip_date, 'DD/MM/YY')
            WHEN t.trip_date ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$'
                THEN to_date(t.trip_date, 'MM-DD-YYYY')
        END AS trip_date,

        t.pickup_time::TIME AS pickup_time,

        CASE
            WHEN trim(t.distance_km) ~ '^-?[0-9]+([.][0-9]+)?$'
             AND trim(t.distance_km)::NUMERIC >= 0
                THEN trim(t.distance_km)::NUMERIC
            ELSE NULL
        END AS distance_km,

        CASE
            WHEN lower(trim(t.payment_method)) = 'm-pesa' THEN 'M-Pesa'
            ELSE initcap(lower(trim(t.payment_method)))
        END AS payment_method,

        lower(trim(t.status)) AS status,
        regexp_replace(t.fare_amount, '[^0-9.]', '', 'g')::NUMERIC AS fare_amount,

        CASE
            WHEN trim(t.customer_rating) ~ '^[0-9]+$'
             AND trim(t.customer_rating)::INTEGER BETWEEN 1 AND 5
                THEN trim(t.customer_rating)::SMALLINT
            ELSE NULL
        END AS customer_rating
    FROM unique_trips t
    JOIN booking.customers c
      ON lower(trim(c.customer_name)) = lower(trim(t.customer_name))
    JOIN booking.drivers d
      ON lower(trim(d.driver_name)) = lower(trim(t.driver_name))
    JOIN fleet.vehicles v
      ON upper(trim(v.plate_number)) = upper(trim(t.vehicle_plate))
)
INSERT INTO booking.trips (
    source_trip_id, customer_id, driver_id, vehicle_id,
    pickup_area, dropoff_area, trip_date, pickup_time,
    distance_km, payment_method, status, fare_amount, customer_rating
)
SELECT
    source_trip_id, customer_id, driver_id, vehicle_id,
    pickup_area, dropoff_area, trip_date, pickup_time,
    distance_km, payment_method, status, fare_amount, customer_rating
FROM mapped_trips;

SELECT count(*) AS loaded_trips
FROM booking.trips;

SELECT
    count(*) AS duplicate_groups,
    coalesce(sum(copies - 1), 0) AS extra_duplicate_rows
FROM (
    SELECT count(*) AS copies
    FROM staging.fleet_staging f
    GROUP BY to_jsonb(f)
    HAVING count(*) > 1
) d;

WITH unique_events AS (
    SELECT DISTINCT *
    FROM staging.fleet_staging
),
prepared AS (
    SELECT
        e.log_id AS source_log_id,
        v.vehicle_id,
        lower(trim(e.event_type)) AS event_type,

        CASE
            WHEN e.event_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN e.event_date::DATE
            WHEN e.event_date ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN to_date(e.event_date, 'DD/MM/YYYY')
            WHEN e.event_date ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                THEN to_date(e.event_date, 'DD/MM/YY')
            WHEN e.event_date ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$'
                THEN to_date(e.event_date, 'MM-DD-YYYY')
        END AS event_date,

        NULLIF(trim(e.liters), '')::NUMERIC AS liters,
        NULLIF(regexp_replace(e.fuel_cost, '[^0-9.]', '', 'g'), '')::NUMERIC AS fuel_cost,
        NULLIF(trim(e.odometer_reading), '')::INTEGER AS odometer_reading,
        NULLIF(trim(e.station_name), '') AS station_name,
        NULLIF(trim(e.service_type), '') AS service_type,
        NULLIF(regexp_replace(e.maintenance_cost, '[^0-9.]', '', 'g'), '')::NUMERIC
            AS maintenance_cost,
        NULLIF(trim(e.mechanic_name), '') AS mechanic_name,

        CASE
            WHEN e.next_service_due ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN e.next_service_due::DATE
            WHEN e.next_service_due ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN to_date(e.next_service_due, 'DD/MM/YYYY')
            WHEN e.next_service_due ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                THEN to_date(e.next_service_due, 'DD/MM/YY')
            WHEN e.next_service_due ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$'
                THEN to_date(e.next_service_due, 'MM-DD-YYYY')
        END AS next_service_due
    FROM unique_events e
    JOIN fleet.vehicles v
      ON upper(trim(v.plate_number)) = upper(trim(e.vehicle_plate))
),
fuel_insert AS (
    INSERT INTO fleet.fuel_logs (
        source_log_id, vehicle_id, event_date, liters,
        fuel_cost, odometer_reading, station_name
    )
    SELECT
        source_log_id, vehicle_id, event_date, liters,
        fuel_cost, odometer_reading, station_name
    FROM prepared
    WHERE event_type = 'fuel'
    RETURNING 1
),
maintenance_insert AS (
    INSERT INTO fleet.maintenance_logs (
        source_log_id, vehicle_id, event_date, service_type,
        maintenance_cost, mechanic_name, next_service_due
    )
    SELECT
        source_log_id, vehicle_id, event_date, service_type,
        maintenance_cost, mechanic_name, next_service_due
    FROM prepared
    WHERE event_type = 'maintenance'
    RETURNING 1
)
SELECT
    (SELECT count(*) FROM fuel_insert) AS fuel_logs_inserted,
    (SELECT count(*) FROM maintenance_insert) AS maintenance_logs_inserted;
        
        
        ---DRIVERS WITH THE MOST COMPLETEED TRIPS
        SELECT
    d.driver_id,
    d.driver_name,
    count(*) AS completed_trips
FROM booking.trips t
JOIN booking.drivers d
    ON d.driver_id = t.driver_id
WHERE t.status = 'completed'
GROUP BY d.driver_id, d.driver_name
ORDER BY completed_trips DESC, d.driver_name
LIMIT 5;

--Find customers with no completed trips
SELECT
    c.customer_id,
    c.customer_name
FROM booking.customers c
LEFT JOIN booking.trips t
    ON t.customer_id = c.customer_id
   AND t.status = 'completed'
WHERE t.trip_key IS NULL
ORDER BY c.customer_name;

---Total revenue by payment method
SELECT
    payment_method,
    count(*) AS completed_trips,
    sum(fare_amount) AS total_revenue_kes
FROM booking.trips
WHERE status = 'completed'
GROUP BY payment_method
ORDER BY total_revenue_kes DESC;

UPDATE booking.trips
SET payment_method = 'M-Pesa'
WHERE regexp_replace(lower(payment_method), '[^a-z]', '', 'g') = 'mpesa';


---Rank vehicles by total fuel cost.
SELECT
    v.vehicle_id,
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model,
    coalesce(sum(f.fuel_cost), 0) AS total_fuel_cost_kes
FROM fleet.vehicles v
LEFT JOIN fleet.fuel_logs f
    ON f.vehicle_id = v.vehicle_id
GROUP BY
    v.vehicle_id, v.plate_number, v.vehicle_make, v.vehicle_model
ORDER BY total_fuel_cost_kes DESC, v.plate_number;

---Vehicles with more than three maintenance events, using HAVING to filter groups:
SELECT
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model,
    count(m.maintenance_log_id) AS maintenance_events,
    coalesce(sum(m.maintenance_cost), 0) AS total_maintenance_cost_kes
FROM fleet.vehicles v
JOIN fleet.maintenance_logs m
    ON m.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_id, v.plate_number, v.vehicle_make, v.vehicle_model
HAVING count(m.maintenance_log_id) > 3
ORDER BY maintenance_events DESC, total_maintenance_cost_kes DESC;

---Find vehicles with no fuel log
SELECT
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model,
    v.vehicle_status
FROM fleet.vehicles v
WHERE NOT EXISTS (
    SELECT 1
    FROM fleet.fuel_logs f
    WHERE f.vehicle_id = v.vehicle_id
)
ORDER BY v.plate_number;

---Show vehicle details alongside each completed trip
SELECT
    t.source_trip_id,
    t.trip_date,
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model
FROM booking.trips t
JOIN fleet.vehicles v
    ON v.vehicle_id = t.vehicle_id
WHERE t.status = 'completed'
ORDER BY t.trip_date, t.source_trip_id;

SELECT count(*) AS completed_trip_rows
FROM booking.trips
WHERE status = 'completed';

---completed-trip revenue per vehicle
SELECT
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model,
    coalesce(
        sum(t.fare_amount) FILTER (WHERE t.status = 'completed'),
        0
    ) AS completed_trip_revenue_kes
FROM fleet.vehicles v
LEFT JOIN booking.trips t
    ON t.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_id, v.plate_number, v.vehicle_make, v.vehicle_model
ORDER BY completed_trip_revenue_kes DESC, v.plate_number;

----Check vehicles marked “Under Repair” and their trips
SELECT
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model,
    count(t.trip_key) AS total_trips,
    count(t.trip_key) FILTER (WHERE t.status = 'completed') AS completed_trips
FROM fleet.vehicles v
LEFT JOIN booking.trips t
    ON t.vehicle_id = v.vehicle_id
WHERE lower(trim(v.vehicle_status)) = 'under repair'
GROUP BY v.vehicle_id, v.plate_number, v.vehicle_make, v.vehicle_model
ORDER BY v.plate_number;

---customers ride further than average
WITH overall_average AS (
    SELECT avg(distance_km) AS average_distance_km
    FROM booking.trips
    WHERE distance_km IS NOT NULL
)
SELECT
    c.customer_name,
    count(t.trip_key) AS trips_with_valid_distance,
    round(avg(t.distance_km), 2) AS customer_average_km,
    round(o.average_distance_km, 2) AS overall_average_km
FROM booking.customers c
JOIN booking.trips t
    ON t.customer_id = c.customer_id
CROSS JOIN overall_average o
WHERE t.distance_km IS NOT NULL
GROUP BY c.customer_id, c.customer_name, o.average_distance_km
HAVING avg(t.distance_km) > o.average_distance_km
ORDER BY customer_average_km DESC, c.customer_name;

---Find vehicles whose total fuel spend is above the average vehicle total.
WITH vehicle_totals AS (
    SELECT
        v.vehicle_id,
        v.plate_number,
        v.vehicle_make,
        v.vehicle_model,
        coalesce(sum(f.fuel_cost), 0) AS total_fuel_cost_kes
    FROM fleet.vehicles v
    LEFT JOIN fleet.fuel_logs f
        ON f.vehicle_id = v.vehicle_id
    GROUP BY v.vehicle_id, v.plate_number, v.vehicle_make, v.vehicle_model
),
average_spend AS (
    SELECT avg(total_fuel_cost_kes) AS average_vehicle_fuel_spend
    FROM vehicle_totals
)
SELECT
    vt.plate_number,
    vt.vehicle_make,
    vt.vehicle_model,
    vt.total_fuel_cost_kes,
    round(a.average_vehicle_fuel_spend, 2) AS average_vehicle_fuel_spend_kes
FROM vehicle_totals vt
CROSS JOIN average_spend a
WHERE vt.total_fuel_cost_kes > a.average_vehicle_fuel_spend
ORDER BY vt.total_fuel_cost_kes DESC;

---Find completed trips with a fare above the average for their payment method.
SELECT
    t.source_trip_id,
    t.payment_method,
    t.fare_amount,
    (
        SELECT avg(t2.fare_amount)
        FROM booking.trips t2
        WHERE t2.payment_method = t.payment_method
          AND t2.status = 'completed'
    ) AS method_average_fare_kes
FROM booking.trips t
WHERE t.status = 'completed'
  AND t.fare_amount > (
        SELECT avg(t2.fare_amount)
        FROM booking.trips t2
        WHERE t2.payment_method = t.payment_method
          AND t2.status = 'completed'
  )
ORDER BY t.payment_method, t.fare_amount DESC;

---Vehicle profitability.
WITH revenue_by_vehicle AS (
    SELECT
        vehicle_id,
        sum(fare_amount) AS total_revenue
    FROM booking.trips
    WHERE status = 'completed'
    GROUP BY vehicle_id
),
fuel_by_vehicle AS (
    SELECT
        vehicle_id,
        sum(fuel_cost) AS total_fuel_cost
    FROM fleet.fuel_logs
    GROUP BY vehicle_id
),
maintenance_by_vehicle AS (
    SELECT
        vehicle_id,
        sum(maintenance_cost) AS total_maintenance_cost
    FROM fleet.maintenance_logs
    GROUP BY vehicle_id
)
SELECT
    v.plate_number,
    v.vehicle_make,
    v.vehicle_model,
    coalesce(r.total_revenue, 0) AS total_revenue_kes,
    coalesce(f.total_fuel_cost, 0) AS total_fuel_cost_kes,
    coalesce(m.total_maintenance_cost, 0) AS total_maintenance_cost_kes,
    coalesce(r.total_revenue, 0)
      - coalesce(f.total_fuel_cost, 0)
      - coalesce(m.total_maintenance_cost, 0) AS net_profit_kes
FROM fleet.vehicles v
LEFT JOIN revenue_by_vehicle r ON r.vehicle_id = v.vehicle_id
LEFT JOIN fuel_by_vehicle f ON f.vehicle_id = v.vehicle_id
LEFT JOIN maintenance_by_vehicle m ON m.vehicle_id = v.vehicle_id
ORDER BY net_profit_kes DESC, v.plate_number;



/*Management should review KDB869I first because it is marked Under Repair, has no recorded trips, and has KES 116,804 in maintenance costs.

Confirm its repair status and verify the costs before deciding whether to repair, redeploy, or retire it.

KDA496F and KDA542H also need maintenance cost reviews because they have the next largest losses.

Reassess the fleet after reviewing the cost records and operating plans.*/