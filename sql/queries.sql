-- ============================================================================
-- DriveLine - File 06 : SHOWCASE QUERIES (outer joins, used by the UI)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- LEFT OUTER JOIN
--   Every vehicle, including those that have NEVER been rented (rental cols
--   come back NULL for them).
-- ----------------------------------------------------------------------------
SELECT v.vehicle_id,
       v.make || ' ' || v.model AS vehicle,
       v.plate,
       v.status,
       count(r.rental_id) AS times_rented
FROM vehicle v
LEFT OUTER JOIN rental r ON r.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_id, v.make, v.model, v.plate, v.status
ORDER BY times_rented ASC, v.vehicle_id;

-- ----------------------------------------------------------------------------
-- RIGHT OUTER JOIN
--   Every rental together with its handling agent; written as a RIGHT JOIN so
--   that employees are the preserved (right) side -- agents who processed no
--   rentals still appear (rental columns NULL).
-- ----------------------------------------------------------------------------
SELECT e.full_name           AS agent,
       e.job_role,
       r.rental_id,
       r.pickup_date,
       r.status
FROM rental r
RIGHT OUTER JOIN employee e ON e.person_id = r.employee_id
ORDER BY e.full_name, r.rental_id;

-- ----------------------------------------------------------------------------
-- FULL OUTER JOIN
--   Reconcile employees against the rentals they handled: shows agents with no
--   rentals (right-only) AND any rental with no assigned agent (left-only) in
--   one result set.
-- ----------------------------------------------------------------------------
SELECT COALESCE(e.full_name, '(unassigned)') AS agent,
       r.rental_id,
       r.status,
       CASE
         WHEN e.person_id IS NULL THEN 'rental without agent'
         WHEN r.rental_id IS NULL THEN 'agent without rentals'
         ELSE 'matched'
       END AS note
FROM employee e
FULL OUTER JOIN rental r ON r.employee_id = e.person_id
ORDER BY note, agent;
