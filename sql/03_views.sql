-- ============================================================================
-- DriveLine - File 03 : VIEWS (5 distinct views)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- VIEW 1 : Active / upcoming rentals (front-desk dashboard)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_active_rentals AS
SELECT r.rental_id,
       v.make || ' ' || v.model AS vehicle,
       v.plate,
       c.full_name              AS customer,
       e.full_name              AS agent,
       pb.name                  AS pickup_branch,
       r.pickup_date,
       r.return_date_planned,
       r.daily_rate,
       r.status
FROM rental r
JOIN vehicle  v  ON v.vehicle_id = r.vehicle_id
JOIN customer c  ON c.person_id  = r.customer_id
JOIN branch   pb ON pb.branch_id = r.pickup_branch_id
LEFT JOIN employee e ON e.person_id = r.employee_id
WHERE r.status IN ('reserved','active')
ORDER BY r.pickup_date, r.rental_id;

-- ----------------------------------------------------------------------------
-- VIEW 2 : Vehicle utilization (rentals, days out, revenue per vehicle)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_vehicle_utilization AS
SELECT v.vehicle_id,
       v.make || ' ' || v.model AS vehicle,
       v.plate,
       v.status,
       count(r.rental_id)       AS rentals,
       COALESCE(sum( (COALESCE(r.return_date_actual, r.return_date_planned)
                      - r.pickup_date) + 1 )
                 FILTER (WHERE r.status IN ('active','returned')), 0) AS days_out,
       COALESCE(sum(p.amount) FILTER (WHERE p.status = 'completed'), 0) AS revenue
FROM vehicle v
LEFT JOIN rental  r ON r.vehicle_id = v.vehicle_id
LEFT JOIN payment p ON p.rental_id  = r.rental_id
GROUP BY v.vehicle_id, v.make, v.model, v.plate, v.status
ORDER BY revenue DESC;

-- ----------------------------------------------------------------------------
-- VIEW 3 : Branch revenue summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_branch_revenue AS
SELECT br.branch_id,
       br.name                            AS branch,
       br.city,
       count(DISTINCT v.vehicle_id)       AS fleet_size,
       count(r.rental_id)                 AS rentals,
       COALESCE(sum(p.amount) FILTER (WHERE p.status='completed'), 0) AS revenue
FROM branch br
LEFT JOIN vehicle v ON v.branch_id        = br.branch_id
LEFT JOIN rental  r ON r.pickup_branch_id = br.branch_id
LEFT JOIN payment p ON p.rental_id        = r.rental_id
GROUP BY br.branch_id, br.name, br.city
ORDER BY revenue DESC;

-- ----------------------------------------------------------------------------
-- VIEW 4 : Customer history (spend, loyalty, last rental)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_history AS
SELECT c.person_id  AS customer_id,
       c.full_name,
       c.email,
       c.loyalty_points,
       count(r.rental_id)                                              AS rentals,
       COALESCE(sum(p.amount) FILTER (WHERE p.status='completed'), 0)  AS total_spent,
       max(r.pickup_date)                                             AS last_rental
FROM customer c
LEFT JOIN rental  r ON r.customer_id = c.person_id
LEFT JOIN payment p ON p.rental_id   = r.rental_id
GROUP BY c.person_id, c.full_name, c.email, c.loyalty_points
ORDER BY total_spent DESC;

-- ----------------------------------------------------------------------------
-- VIEW 5 : Fleet catalogue (demonstrates INHERITANCE)
--   Each sub-type contributes its own specialised attributes, surfaced
--   through a single unified catalogue.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_fleet AS
SELECT vehicle_id, make, model, model_year, plate, daily_rate, status,
       'car' AS vehicle_type,
       format('%s doors, %s, GPS:%s', num_doors, transmission, has_gps) AS spec
FROM car
UNION ALL
SELECT vehicle_id, make, model, model_year, plate, daily_rate, status,
       'van',
       format('%s m3 cargo, %s seats', cargo_volume_m3, passenger_capacity)
FROM van
UNION ALL
SELECT vehicle_id, make, model, model_year, plate, daily_rate, status,
       'motorcycle',
       format('%s cc, sidecar:%s', engine_cc, has_sidecar)
FROM motorcycle
ORDER BY vehicle_id;
