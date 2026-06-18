-- ============================================================================
-- DriveLine - File 05 : SAMPLE DATA
-- ----------------------------------------------------------------------------
-- Uses sub-queries (by natural key) instead of hard-coded ids so it stays
-- correct regardless of sequence values.  Triggers fire during these inserts
-- (loyalty points, vehicle-status sync and audit rows are produced here).
-- ============================================================================

-- BRANCHES -------------------------------------------------------------------
INSERT INTO branch (name, city, address, phone, opened_date) VALUES
 ('DriveLine Kadikoy', 'Istanbul', 'Bagdat Cad. 120, Kadikoy', '+90 216 111 1111', '2019-03-01'),
 ('DriveLine Cankaya', 'Ankara',   'Tunali Hilmi 45, Cankaya',  '+90 312 222 2222', '2020-06-15'),
 ('DriveLine Konak',   'Izmir',    'Kibris Sehitleri 8, Konak', '+90 232 333 3333', '2021-09-10');

-- EMPLOYEES (child of person) ------------------------------------------------
INSERT INTO employee (full_name, email, phone, hire_date, salary, job_role, branch_id) VALUES
 ('Ayse Demir',  'ayse.demir@driveline.com',  '+90 532 000 0001', '2019-04-01', 65000, 'manager',
     (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy')),
 ('Mehmet Yilmaz','mehmet.yilmaz@driveline.com','+90 532 000 0002', '2020-01-15', 38000, 'agent',
     (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy')),
 ('Elif Kaya',   'elif.kaya@driveline.com',   '+90 532 000 0003', '2021-03-20', 39000, 'agent',
     (SELECT branch_id FROM branch WHERE name='DriveLine Cankaya')),
 ('Can Ozturk',  'can.ozturk@driveline.com',  '+90 532 000 0004', '2020-07-01', 42000, 'mechanic',
     (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy')),
 ('Deniz Arslan','deniz.arslan@driveline.com','+90 532 000 0005', '2021-10-05', 60000, 'manager',
     (SELECT branch_id FROM branch WHERE name='DriveLine Konak'));

-- CUSTOMERS (child of person) ------------------------------------------------
INSERT INTO customer (full_name, email, phone, license_no, join_date) VALUES
 ('Kerem Sahin',  'kerem.sahin@example.com',  '+90 555 100 0001', 'B34-100001', '2022-02-10'),
 ('Zeynep Aydin', 'zeynep.aydin@example.com', '+90 555 100 0002', 'B34-100002', '2022-05-22'),
 ('Burak Celik',  'burak.celik@example.com',  '+90 555 100 0003', 'B06-100003', '2023-01-05'),
 ('Selin Yildiz', 'selin.yildiz@example.com', '+90 555 100 0004', 'B35-100004', '2023-04-18'),
 ('Emre Koc',     'emre.koc@example.com',     '+90 555 100 0005', 'B34-100005', '2023-08-30'),
 ('Gizem Aksoy',  'gizem.aksoy@example.com',  '+90 555 100 0006', 'B06-100006', '2024-01-12');

-- VEHICLES (children of vehicle) ---------------------------------------------
-- Cars
INSERT INTO car (branch_id, make, model, model_year, plate, daily_rate, mileage,
                 num_doors, transmission, has_gps) VALUES
 ((SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),'Toyota','Corolla',2022,'34ABC01',45,32000,4,'automatic',true),
 ((SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),'Renault','Clio',  2021,'34ABC02',30,51000,5,'manual',   false),
 ((SELECT branch_id FROM branch WHERE name='DriveLine Cankaya'),'Ford','Focus',    2023,'06DEF03',40,18000,4,'automatic',false),
 ((SELECT branch_id FROM branch WHERE name='DriveLine Konak'),  'Volkswagen','Golf',2022,'35GHI04',38,27000,5,'manual',   false),
 ((SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),'BMW','320i',       2023,'34ABC05',80,12000,4,'automatic',true);

-- Vans
INSERT INTO van (branch_id, make, model, model_year, plate, daily_rate, mileage,
                 cargo_volume_m3, passenger_capacity) VALUES
 ((SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),'Ford','Transit',   2021,'34VAN10',70,88000,8.5,3),
 ((SELECT branch_id FROM branch WHERE name='DriveLine Cankaya'),'Mercedes','Sprinter',2022,'06VAN11',90,64000,11.0,3);

-- Motorcycles
INSERT INTO motorcycle (branch_id, make, model, model_year, plate, daily_rate, mileage,
                        engine_cc, has_sidecar) VALUES
 ((SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),'Honda','CBR600',2022,'34MOT20',35,9000,600,false),
 ((SELECT branch_id FROM branch WHERE name='DriveLine Konak'),  'Yamaha','MT-07',2023,'35MOT21',33,4000,689,false);

-- RENTALS --------------------------------------------------------------------
-- Helper macros via sub-queries: vehicle by plate, customer/employee by email.
INSERT INTO rental (vehicle_id, customer_id, employee_id, pickup_branch_id,
                    return_branch_id, pickup_date, return_date_planned,
                    return_date_actual, daily_rate, status) VALUES
 -- returned history
 ((SELECT vehicle_id FROM vehicle WHERE plate='34ABC01'),
  (SELECT person_id FROM customer WHERE email='kerem.sahin@example.com'),
  (SELECT person_id FROM employee WHERE email='mehmet.yilmaz@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  '2026-05-01','2026-05-05','2026-05-05',45,'returned'),
 ((SELECT vehicle_id FROM vehicle WHERE plate='34ABC02'),
  (SELECT person_id FROM customer WHERE email='burak.celik@example.com'),
  (SELECT person_id FROM employee WHERE email='mehmet.yilmaz@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  '2026-05-10','2026-05-12','2026-05-12',30,'returned'),
 ((SELECT vehicle_id FROM vehicle WHERE plate='34ABC05'),
  (SELECT person_id FROM customer WHERE email='kerem.sahin@example.com'),
  (SELECT person_id FROM employee WHERE email='mehmet.yilmaz@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  '2026-05-20','2026-05-23','2026-05-23',80,'returned'),
 ((SELECT vehicle_id FROM vehicle WHERE plate='34MOT20'),
  (SELECT person_id FROM customer WHERE email='zeynep.aydin@example.com'),
  (SELECT person_id FROM employee WHERE email='mehmet.yilmaz@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  '2026-04-15','2026-04-18','2026-04-18',35,'returned'),
 -- currently active
 ((SELECT vehicle_id FROM vehicle WHERE plate='34ABC01'),
  (SELECT person_id FROM customer WHERE email='zeynep.aydin@example.com'),
  (SELECT person_id FROM employee WHERE email='mehmet.yilmaz@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  '2026-06-12','2026-06-16',NULL,45,'active'),
 ((SELECT vehicle_id FROM vehicle WHERE plate='06DEF03'),
  (SELECT person_id FROM customer WHERE email='selin.yildiz@example.com'),
  (SELECT person_id FROM employee WHERE email='elif.kaya@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Cankaya'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Cankaya'),
  '2026-06-13','2026-06-18',NULL,40,'active'),
 -- future reservations
 ((SELECT vehicle_id FROM vehicle WHERE plate='35GHI04'),
  (SELECT person_id FROM customer WHERE email='emre.koc@example.com'),
  (SELECT person_id FROM employee WHERE email='deniz.arslan@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Konak'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Konak'),
  '2026-06-20','2026-06-25',NULL,38,'reserved'),
 ((SELECT vehicle_id FROM vehicle WHERE plate='34VAN10'),
  (SELECT person_id FROM customer WHERE email='gizem.aksoy@example.com'),
  (SELECT person_id FROM employee WHERE email='mehmet.yilmaz@driveline.com'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  (SELECT branch_id FROM branch WHERE name='DriveLine Kadikoy'),
  '2026-06-25','2026-06-28',NULL,70,'reserved');

-- INSURANCE ------------------------------------------------------------------
INSERT INTO insurance (rental_id, ins_type, daily_premium, coverage_limit)
SELECT r.rental_id, 'standard', 15, 50000
FROM rental r WHERE r.vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC01')
              AND r.status='active';
INSERT INTO insurance (rental_id, ins_type, daily_premium, coverage_limit)
SELECT r.rental_id, 'premium', 25, 100000
FROM rental r WHERE r.vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='06DEF03')
              AND r.status='active';
INSERT INTO insurance (rental_id, ins_type, daily_premium, coverage_limit)
SELECT r.rental_id, 'basic', 8, 20000
FROM rental r WHERE r.vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='35GHI04')
              AND r.status='reserved';

-- PAYMENTS (completed -> loyalty trigger awards points) ----------------------
INSERT INTO payment (rental_id, amount, method, status)
SELECT rental_id, 225, 'card', 'completed' FROM rental
 WHERE vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC01') AND status='returned';
INSERT INTO payment (rental_id, amount, method, status)
SELECT rental_id, 90, 'cash', 'completed' FROM rental
 WHERE vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC02') AND status='returned';
INSERT INTO payment (rental_id, amount, method, status)
SELECT rental_id, 320, 'card', 'completed' FROM rental
 WHERE vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC05') AND status='returned';
INSERT INTO payment (rental_id, amount, method, status)
SELECT rental_id, 140, 'online', 'completed' FROM rental
 WHERE vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34MOT20') AND status='returned';
INSERT INTO payment (rental_id, amount, method, status)
SELECT rental_id, 180, 'card', 'completed' FROM rental
 WHERE vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC01') AND status='active';
INSERT INTO payment (rental_id, amount, method, status)
SELECT rental_id, 240, 'card', 'completed' FROM rental
 WHERE vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='06DEF03') AND status='active';

-- MAINTENANCE ----------------------------------------------------------------
INSERT INTO maintenance (vehicle_id, service_date, service_type, cost, notes) VALUES
 ((SELECT vehicle_id FROM vehicle WHERE plate='34ABC02'),'2026-06-01','Oil change',60,'Routine'),
 ((SELECT vehicle_id FROM vehicle WHERE plate='35MOT21'),'2026-06-10','Tire replacement',200,'Rear tire worn');

-- RENTAL_ITEM (weak entity) : add-ons charged on a rental -------------------
INSERT INTO rental_item (rental_id, item_no, description, quantity, unit_fee)
SELECT r.rental_id, 1, 'GPS unit', 1, 5
FROM rental r WHERE r.vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC01') AND r.status='active';
INSERT INTO rental_item (rental_id, item_no, description, quantity, unit_fee)
SELECT r.rental_id, 2, 'Child seat', 1, 4
FROM rental r WHERE r.vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='34ABC01') AND r.status='active';
INSERT INTO rental_item (rental_id, item_no, description, quantity, unit_fee)
SELECT r.rental_id, 1, 'Additional driver', 1, 8
FROM rental r WHERE r.vehicle_id=(SELECT vehicle_id FROM vehicle WHERE plate='06DEF03') AND r.status='active';

-- Put the Yamaha into maintenance (UPDATE on parent reaches the child row) ---
UPDATE vehicle SET status='maintenance' WHERE plate='35MOT21';
