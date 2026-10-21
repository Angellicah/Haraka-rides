CREATE TABLE haraka_fleet.vehicles (
    vehicle_id BIGSERIAL PRIMARY KEY,
    plate_number VARCHAR(20) NOT NULL UNIQUE,
    make VARCHAR(50),
    model VARCHAR(50),
    vehicle_year INTEGER,
    vehicle_type VARCHAR(50),
    vehicle_status VARCHAR(50)
);

--Load vehicles from fleet staging data
INSERT INTO haraka_fleet.vehicles (
    plate_number,
    make,
    model,
    vehicle_year,
    vehicle_type,
    vehicle_status
)
SELECT DISTINCT ON (UPPER(TRIM(vehicle_plate)))
    UPPER(TRIM(vehicle_plate)) AS plate_number,
    INITCAP(LOWER(TRIM(vehicle_make))) AS make,
    INITCAP(LOWER(TRIM(vehicle_model))) AS model,
    CASE
        WHEN TRIM(vehicle_year) ~ '^[0-9]{4}$'
        THEN TRIM(vehicle_year)::INTEGER
        ELSE NULL
    END AS vehicle_year,
    INITCAP(LOWER(TRIM(vehicle_type))) AS vehicle_type,
    CASE
        WHEN UPPER(TRIM(vehicle_status)) = 'ACTIVE'
            THEN 'Active'
        WHEN UPPER(TRIM(vehicle_status)) = 'UNDER REPAIR'
            THEN 'Under Repair'
        ELSE INITCAP(LOWER(TRIM(vehicle_status)))
    END AS vehicle_status
FROM haraka_staging.fleet_staging
WHERE NULLIF(TRIM(vehicle_plate), '') IS NOT NULL
ORDER BY
    UPPER(TRIM(vehicle_plate)),
    log_id;

--Check
SELECT *
FROM haraka_fleet.vehicles
ORDER BY vehicle_id;

--create fuel logs
CREATE TABLE haraka_fleet.fuel_logs (
    fuel_log_id VARCHAR(50) PRIMARY KEY,
    vehicle_id BIGINT NOT NULL REFERENCES haraka_fleet.vehicles(vehicle_id),
    event_date DATE,
    liters NUMERIC(10,2),
    fuel_cost NUMERIC(12,2),
    odometer_reading NUMERIC(12,2),
    station_name VARCHAR(150)
);

--Load
INSERT INTO haraka_fleet.fuel_logs (
    fuel_log_id,
    vehicle_id,
    event_date,
    liters,
    fuel_cost,
    odometer_reading,
    station_name
)
SELECT
    s.log_id,
    v.vehicle_id,
    CASE
        WHEN TRIM(s.event_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(s.event_date), 'YYYY-MM-DD')
        WHEN TRIM(s.event_date) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN TO_DATE(TRIM(s.event_date), 'DD/MM/YYYY')
        WHEN TRIM(s.event_date) ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN TO_DATE(TRIM(s.event_date), 'MM-DD-YYYY')
        WHEN TRIM(s.event_date) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{2}$'
            THEN TO_DATE(TRIM(s.event_date), 'DD/MM/YY')
        ELSE NULL
    END,
    NULLIF(TRIM(s.liters), '')::NUMERIC,
    CASE
        WHEN REGEXP_REPLACE(TRIM(s.fuel_cost), '[^0-9.-]', '', 'g') <> ''
        THEN REGEXP_REPLACE(
            TRIM(s.fuel_cost),
            '[^0-9.-]',
            '',
            'g'
        )::NUMERIC
        ELSE NULL
    END,
    NULLIF(TRIM(s.odometer_reading), '')::NUMERIC,
    NULLIF(INITCAP(LOWER(TRIM(s.station_name))), '')
FROM haraka_staging.fleet_staging s
JOIN haraka_fleet.vehicles v
    ON v.plate_number = UPPER(TRIM(s.vehicle_plate))
WHERE UPPER(TRIM(s.event_type)) = 'FUEL'
ON CONFLICT (fuel_log_id) DO NOTHING;

-- Create maintenance logs
CREATE TABLE haraka_fleet.maintenance_logs (
    maintenance_log_id VARCHAR(50) PRIMARY KEY,
    vehicle_id BIGINT NOT NULL REFERENCES haraka_fleet.vehicles(vehicle_id),
    event_date DATE,
    service_type VARCHAR(100),
    maintenance_cost NUMERIC(12,2),
    mechanic_name VARCHAR(150),
    next_service_due DATE
);

INSERT INTO haraka_fleet.maintenance_logs (
    maintenance_log_id,
    vehicle_id,
    event_date,
    service_type,
    maintenance_cost,
    mechanic_name,
    next_service_due
)
SELECT
    s.log_id,
    v.vehicle_id,
    CASE
        WHEN TRIM(s.event_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(s.event_date), 'YYYY-MM-DD')
        WHEN TRIM(s.event_date) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN TO_DATE(TRIM(s.event_date), 'DD/MM/YYYY')
        WHEN TRIM(s.event_date) ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN TO_DATE(TRIM(s.event_date), 'MM-DD-YYYY')
        WHEN TRIM(s.event_date) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{2}$'
            THEN TO_DATE(TRIM(s.event_date), 'DD/MM/YY')
        ELSE NULL
    END,
    NULLIF(INITCAP(LOWER(TRIM(s.service_type))), ''),
    CASE
        WHEN REGEXP_REPLACE(
                 TRIM(s.maintenance_cost),
                 '[^0-9.-]',
                 '',
                 'g'
             ) <> ''
        THEN REGEXP_REPLACE(
                 TRIM(s.maintenance_cost),
                 '[^0-9.-]',
                 '',
                 'g'
             )::NUMERIC
        ELSE NULL
    END,
    NULLIF(INITCAP(LOWER(TRIM(s.mechanic_name))), ''),
    CASE
        WHEN TRIM(s.next_service_due) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(s.next_service_due), 'YYYY-MM-DD')
        WHEN TRIM(s.next_service_due) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN TO_DATE(TRIM(s.next_service_due), 'DD/MM/YYYY')
        WHEN TRIM(s.next_service_due) ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN TO_DATE(TRIM(s.next_service_due), 'MM-DD-YYYY')
        WHEN TRIM(s.next_service_due) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{2}$'
            THEN TO_DATE(TRIM(s.next_service_due), 'DD/MM/YY')
        ELSE NULL
    END
FROM haraka_staging.fleet_staging s
JOIN haraka_fleet.vehicles v
    ON v.plate_number = UPPER(TRIM(s.vehicle_plate))
WHERE UPPER(TRIM(s.event_type)) = 'MAINTENANCE'
ON CONFLICT (maintenance_log_id) DO NOTHING;

SELECT COUNT(*) AS vehicles
FROM haraka_fleet.vehicles;

SELECT COUNT(*) AS fuel_logs
FROM haraka_fleet.fuel_logs;

SELECT COUNT(*) AS maintenance_logs
FROM haraka_fleet.maintenance_logs;

SELECT *
FROM haraka_fleet.fuel_logs
WHERE vehicle_id IS NULL;

SELECT *
FROM haraka_fleet.maintenance_logs
WHERE vehicle_id IS NULL;