# Haraka Rides: Data Cleaning, Schema Design & Fleet Profitability

## Phase 1: Where staging lives
I put both raw tables in a separate `haraka_staging` schema, not inside `haraka_booking` or `haraka_fleet`. Staging data is dirty, all TEXT, and has no keys or constraints, so mixing it with the clean tables would make it easy to query the wrong thing. Both CSVs also feed two different clean schemas, so neither schema is the natural home. Keeping staging separate means I can reload or drop it without touching the clean data. Every staging column is TEXT, so nothing failed to load, and casting only happens on the way out.

## Phase 2: What was wrong
| Problem | What I found |
|---|---|
| Exact duplicates | 6 duplicate trip rows (406 → 400) and 4 duplicate fleet rows (106 → 102) |
| Casing/variants | Status had variants like "complete"/"Completed"; payment method had "mpesa"/"M-Pesa"; names and makes were mixed case |
| Whitespace | Leading/trailing spaces on plates and names; double spaces in areas ("Ngong  Road") |
| Dates | Four formats mixed in one column: ISO, DD/MM/YYYY, MM-DD-YYYY and DD/MM/YY. I confirmed dashed dates are month-first (no first value above 12) and slashed ones are day-first |
| Money | Values like "KES 1,320" stored as text |
| Invalid values | Ratings of 0 and 6, the literal text "NULL" in ratings, and negative distances |
| Missing values | Blank phones, areas, distances and ratings; fuel-only and maintenance-only columns blank by design |
| Same entity, different spelling | Plates differed by case/whitespace: **[fill in: raw distinct plates vs normalised distinct plates in trips and in fleet]**. After normalising, both files agree on 12 vehicles |
| Typos in areas | Doubled-letter typos such as Runnda, Karren, Cbbd |

## Phase 3: Schema design
1. **Entities.** A trip row mixes three things: the trip, the customer and the driver. Customers and drivers get their own tables in `haraka_booking`; `trips` holds only trip facts plus foreign keys.
2. **Where vehicle lives.** One canonical `vehicles` table in `haraka_fleet`, because the fleet system owns vehicle facts (year, type, status). The booking side only references it. The vehicle columns in the staging tables (make, model, etc.) are not copied into `trips`.
3. **Reconciliation key.** `plate_number`, normalised with `UPPER(TRIM(...))`, is unique in `vehicles`. Every trip, fuel log and maintenance log looks up its `vehicle_id` through that normalised plate.
4. **Keys.** Surrogate `BIGSERIAL` primary keys for vehicles, customers and drivers. Trips, fuel logs and maintenance logs keep their source IDs as primary keys. Foreign keys: trips → customers, drivers (same schema) and trips → vehicles (cross-schema); fuel_logs and maintenance_logs → vehicles.

## Phase 4: Cleaning decisions
- **Who is "the same person":** the cleaned name. Phone is blank on some rows, so name + phone created duplicate people (my first attempt gave 72 customers instead of 29). Each name has exactly one real phone and no phone is shared across names, so name is a safe key, and `MAX()` fills phones from the rows where they exist.
- **Duplicates:** `DISTINCT ON` for vehicles and `ON CONFLICT DO NOTHING` for trips and logs. The duplicates were exact copies with the same ID.
- **Invalid values are NULL, not guessed:** ratings outside 1–5 (and the text "NULL"), negative distances. A negative distance could be a sign error or a bad reading, and I can't tell which, so averages use valid data only.
- **Dates:** parsed by format with regex checks, so an unrecognised value becomes NULL instead of failing. Result: 0 unparsed dates.
- **Areas:** collapsed doubled-letter typos and whitespace with a helper function, leaving 14 clean areas.
- **Phones:** normalised to the local 10-digit format.
- **Remaining blanks are genuinely missing:** 10 pickup areas, 25 dropoff areas, 26 distances, 127 ratings. They stay NULL.
- **Checks:** 29 customers, 14 drivers, 12 vehicles, 400 trips, 69 fuel logs and 33 maintenance logs (102 total), and no trip with a missing customer, driver or vehicle.

## Phase 5: Notes on the answers
- **B1:** "Completed" means `status = 'Completed'`, which lives in `trips`. Top driver: David Kiprotich with 30.
- **B2:** An anti-join (LEFT JOIN … IS NULL). It returned zero rows, which is correct: every customer has at least 3 completed trips.
- **B3:** Completed trips only, grouped by payment method. Cash 110,614; M-Pesa 95,508; Card 80,369.
- **F3:** KDE169J has no fuel log. I proved it with a LEFT JOIN and checked the right table's primary key for NULL.
- **X2:** LEFT JOIN with the status filter in the join condition, not WHERE, so zero-revenue vehicles are kept.
- **X3:** Empty, and that's meaningful. The one Under Repair vehicle (KDB869I) has no trips, so the booking and fleet systems agree. If a result had appeared, it would mean a car in the workshop was still taking rides, so either the status or the booking data would be wrong.
- **S1:** "Average" is the average distance across all trips, from a scalar subquery, compared with each customer's own average.
- **S2:** Fuel is totalled per vehicle first, then those totals are averaged. A plain average of fuel_logs rows would be a different question.
- **S3:** A correlated subquery that recalculates the average fare for each row's own payment method.

## Capstone: Vehicle profitability
Net profit = completed-trip revenue − fuel − maintenance, built with one CTE per source so the joins don't multiply rows.

**11 of Haraka's 12 vehicles lose money, and the worst is KDB869I (Toyota Probox, Under Repair) at about −KES 128,000, with zero completed trips against KES 116,804 in maintenance over 6 events.** 
I recommend retiring or selling it, and reviewing KDA496F, KDC384M and KDD693I (4 maintenance events each) before they follow.
Maintenance spend is the main driver of losses across the fleet, so management should set a repair-cost ceiling per vehicle and move to preventive servicing. KDE169J looks profitable only because it has no fuel logs, so its fuel data should be verified before drawing conclusions.
