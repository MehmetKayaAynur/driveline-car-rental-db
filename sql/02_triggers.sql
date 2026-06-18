-- ============================================================================
-- DriveLine - File 02 : TRIGGERS (5 distinct triggers)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1 : Availability guard + vehicle existence check
--   A rental may only be created for a vehicle that exists and is NOT in
--   maintenance / retired.  (Also enforces the logical vehicle_id reference
--   that we cannot express as a FK because of inheritance.)
--   (BEFORE INSERT/UPDATE on rental)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_check_available() RETURNS trigger AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT status INTO v_status FROM vehicle WHERE vehicle_id = NEW.vehicle_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vehicle % does not exist', NEW.vehicle_id;
    END IF;
    IF v_status IN ('maintenance','retired') THEN
        RAISE EXCEPTION 'Vehicle % is % and cannot be rented',
            NEW.vehicle_id, v_status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rental_check_available
    BEFORE INSERT OR UPDATE ON rental
    FOR EACH ROW EXECUTE FUNCTION trg_check_available();

-- ----------------------------------------------------------------------------
-- TRIGGER 2 : Overlap guard
--   The same vehicle cannot have two ACTIVE/RESERVED rentals whose date
--   ranges overlap.  (BEFORE INSERT/UPDATE on rental)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_prevent_overlap() RETURNS trigger AS $$
DECLARE
    clashes INT;
BEGIN
    IF NEW.status NOT IN ('reserved','active') THEN
        RETURN NEW;                       -- returned/cancelled never clash
    END IF;
    SELECT count(*) INTO clashes
    FROM rental
    WHERE vehicle_id = NEW.vehicle_id
      AND status IN ('reserved','active')
      AND rental_id <> COALESCE(NEW.rental_id, -1)
      AND daterange(pickup_date, return_date_planned, '[]')
          && daterange(NEW.pickup_date, NEW.return_date_planned, '[]');
    IF clashes > 0 THEN
        RAISE EXCEPTION
            'Vehicle % is already booked for an overlapping period (% to %)',
            NEW.vehicle_id, NEW.pickup_date, NEW.return_date_planned;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rental_no_overlap
    BEFORE INSERT OR UPDATE ON rental
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_overlap();

-- ----------------------------------------------------------------------------
-- TRIGGER 3 : Loyalty points
--   A COMPLETED payment awards the customer 1 point per 50 currency spent.
--   (AFTER INSERT on payment)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_award_loyalty() RETURNS trigger AS $$
DECLARE
    cust_id INT;
BEGIN
    IF NEW.status = 'completed' THEN
        SELECT customer_id INTO cust_id FROM rental WHERE rental_id = NEW.rental_id;
        UPDATE customer
           SET loyalty_points = loyalty_points + floor(NEW.amount / 50)::INT
         WHERE person_id = cust_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payment_award_loyalty
    AFTER INSERT ON payment
    FOR EACH ROW EXECUTE FUNCTION trg_award_loyalty();

-- ----------------------------------------------------------------------------
-- TRIGGER 4 : Keep vehicle status in sync with its rental lifecycle
--   active   -> vehicle 'rented'
--   returned -> vehicle 'available' (unless it is in maintenance/retired)
--   cancelled-> vehicle 'available'
--   (AFTER INSERT/UPDATE on rental).  UPDATE on the parent `vehicle`
--   transparently reaches the car/van/motorcycle child row.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_sync_vehicle_status() RETURNS trigger AS $$
BEGIN
    IF NEW.status = 'active' THEN
        UPDATE vehicle SET status = 'rented'
         WHERE vehicle_id = NEW.vehicle_id
           AND status NOT IN ('maintenance','retired');
    ELSIF NEW.status IN ('returned','cancelled') THEN
        UPDATE vehicle SET status = 'available'
         WHERE vehicle_id = NEW.vehicle_id
           AND status = 'rented';
    END IF;
    RETURN NULL;     -- AFTER trigger
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rental_sync_vehicle
    AFTER INSERT OR UPDATE ON rental
    FOR EACH ROW EXECUTE FUNCTION trg_sync_vehicle_status();

-- ----------------------------------------------------------------------------
-- TRIGGER 5 : Audit log
--   Record every INSERT/UPDATE/DELETE on rental into audit_log.
--   (AFTER INSERT/UPDATE/DELETE on rental)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_audit_rental() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(table_name, action, row_pk, detail)
        VALUES ('rental','DELETE', OLD.rental_id::text,
                format('was %s, vehicle %s', OLD.status, OLD.vehicle_id));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, action, row_pk, detail)
        VALUES ('rental','UPDATE', NEW.rental_id::text,
                format('status %s -> %s', OLD.status, NEW.status));
        RETURN NEW;
    ELSE
        INSERT INTO audit_log(table_name, action, row_pk, detail)
        VALUES ('rental','INSERT', NEW.rental_id::text,
                format('vehicle %s, %s to %s',
                       NEW.vehicle_id, NEW.pickup_date, NEW.return_date_planned));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rental_audit
    AFTER INSERT OR UPDATE OR DELETE ON rental
    FOR EACH ROW EXECUTE FUNCTION trg_audit_rental();
