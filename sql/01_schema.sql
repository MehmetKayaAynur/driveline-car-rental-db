-- ============================================================================
-- DriveLine  -  Car Rental Company Database
-- File 01 : SCHEMA (tables, keys, constraints, INHERITANCE)
-- Target  : PostgreSQL 13+
-- ----------------------------------------------------------------------------
-- Run order: 01_schema -> 02_triggers -> 03_views -> 04_roles -> 05_sample_data
--
-- INHERITANCE in this design (PostgreSQL table inheritance):
--    person  ->  employee , customer
--    vehicle ->  car , van , motorcycle
-- ============================================================================

-- Clean start (safe to re-run) ----------------------------------------------
DROP TABLE IF EXISTS audit_log    CASCADE;
DROP TABLE IF EXISTS maintenance  CASCADE;
DROP TABLE IF EXISTS rental_item  CASCADE;
DROP TABLE IF EXISTS payment      CASCADE;
DROP TABLE IF EXISTS insurance    CASCADE;
DROP TABLE IF EXISTS rental       CASCADE;
DROP TABLE IF EXISTS car          CASCADE;
DROP TABLE IF EXISTS van          CASCADE;
DROP TABLE IF EXISTS motorcycle   CASCADE;
DROP TABLE IF EXISTS vehicle      CASCADE;
DROP TABLE IF EXISTS customer     CASCADE;
DROP TABLE IF EXISTS employee     CASCADE;
DROP TABLE IF EXISTS person       CASCADE;
DROP TABLE IF EXISTS branch       CASCADE;
DROP SEQUENCE IF EXISTS person_id_seq;
DROP SEQUENCE IF EXISTS vehicle_id_seq;

-- ----------------------------------------------------------------------------
-- BRANCH : a physical DriveLine rental office
-- ----------------------------------------------------------------------------
CREATE TABLE branch (
    branch_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         VARCHAR(80)  NOT NULL,
    city         VARCHAR(60)  NOT NULL,
    address      VARCHAR(160) NOT NULL,
    phone        VARCHAR(30),
    opened_date  DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_branch_name UNIQUE (name)
);

-- ----------------------------------------------------------------------------
-- PERSON hierarchy  (super-class + two sub-classes)
--   A shared sequence backs person_id so the id is unique across the whole
--   hierarchy (PostgreSQL inherits column DEFAULTs but NOT UNIQUE/PK
--   constraints, so each child re-declares its key + unique email).
-- ----------------------------------------------------------------------------
CREATE SEQUENCE person_id_seq;

CREATE TABLE person (
    person_id  INT          PRIMARY KEY DEFAULT nextval('person_id_seq'),
    full_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(120) NOT NULL UNIQUE,
    phone      VARCHAR(30),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE employee (
    hire_date  DATE          NOT NULL DEFAULT CURRENT_DATE,
    salary     NUMERIC(10,2) NOT NULL CHECK (salary >= 0),
    job_role   VARCHAR(20)   NOT NULL
               CHECK (job_role IN ('manager','agent','mechanic')),
    branch_id  INT           NOT NULL REFERENCES branch(branch_id),
    PRIMARY KEY (person_id),
    UNIQUE (email)
) INHERITS (person);

CREATE TABLE customer (
    license_no     VARCHAR(30) NOT NULL,
    join_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    loyalty_points INT  NOT NULL DEFAULT 0 CHECK (loyalty_points >= 0),
    PRIMARY KEY (person_id),
    UNIQUE (email),
    UNIQUE (license_no)
) INHERITS (person);

-- ----------------------------------------------------------------------------
-- VEHICLE hierarchy  (super-class + three sub-classes)
--   NOTE: PostgreSQL FOREIGN KEYs do NOT "see" rows stored in inheritance
--   children, so tables that reference an arbitrary vehicle (rental,
--   maintenance) keep vehicle_id as a logical reference validated by a
--   trigger instead of a hard FK.  Querying the parent `vehicle` DOES return
--   all sub-type rows (that is the inheritance benefit we exploit in views).
-- ----------------------------------------------------------------------------
CREATE SEQUENCE vehicle_id_seq;

CREATE TABLE vehicle (
    vehicle_id  INT          PRIMARY KEY DEFAULT nextval('vehicle_id_seq'),
    branch_id   INT          NOT NULL REFERENCES branch(branch_id),
    make        VARCHAR(40)  NOT NULL,
    model       VARCHAR(40)  NOT NULL,
    model_year  SMALLINT     NOT NULL CHECK (model_year BETWEEN 1990 AND 2100),
    plate       VARCHAR(15)  NOT NULL UNIQUE,
    daily_rate  NUMERIC(8,2) NOT NULL CHECK (daily_rate >= 0),
    mileage     INT          NOT NULL DEFAULT 0 CHECK (mileage >= 0),
    status      VARCHAR(12)  NOT NULL DEFAULT 'available'
                CHECK (status IN ('available','rented','maintenance','retired'))
);

CREATE TABLE car (
    num_doors    SMALLINT    NOT NULL CHECK (num_doors BETWEEN 2 AND 5),
    transmission VARCHAR(10) NOT NULL CHECK (transmission IN ('manual','automatic')),
    has_gps      BOOLEAN     NOT NULL DEFAULT false,
    PRIMARY KEY (vehicle_id),
    UNIQUE (plate)
) INHERITS (vehicle);

CREATE TABLE van (
    cargo_volume_m3    NUMERIC(5,2) NOT NULL CHECK (cargo_volume_m3 > 0),
    passenger_capacity SMALLINT     NOT NULL CHECK (passenger_capacity BETWEEN 2 AND 20),
    PRIMARY KEY (vehicle_id),
    UNIQUE (plate)
) INHERITS (vehicle);

CREATE TABLE motorcycle (
    engine_cc   SMALLINT NOT NULL CHECK (engine_cc > 0),
    has_sidecar BOOLEAN  NOT NULL DEFAULT false,
    PRIMARY KEY (vehicle_id),
    UNIQUE (plate)
) INHERITS (vehicle);

-- ----------------------------------------------------------------------------
-- RENTAL : a customer rents a vehicle for a date range, handled by an agent
-- ----------------------------------------------------------------------------
CREATE TABLE rental (
    rental_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id          INT  NOT NULL,                 -- logical ref (inheritance)
    customer_id         INT  NOT NULL REFERENCES customer(person_id),
    employee_id         INT           REFERENCES employee(person_id),
    pickup_branch_id    INT  NOT NULL REFERENCES branch(branch_id),
    return_branch_id    INT           REFERENCES branch(branch_id),
    pickup_date         DATE NOT NULL,
    return_date_planned DATE NOT NULL,
    return_date_actual  DATE,
    daily_rate          NUMERIC(8,2) NOT NULL CHECK (daily_rate >= 0),
    status              VARCHAR(12) NOT NULL DEFAULT 'reserved'
                        CHECK (status IN ('reserved','active','returned','cancelled')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_rental_dates CHECK (return_date_planned >= pickup_date)
);

-- ----------------------------------------------------------------------------
-- INSURANCE : optional cover purchased with a rental (1 rental : 0..1)
-- ----------------------------------------------------------------------------
CREATE TABLE insurance (
    insurance_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rental_id      INT NOT NULL UNIQUE REFERENCES rental(rental_id) ON DELETE CASCADE,
    ins_type       VARCHAR(10) NOT NULL CHECK (ins_type IN ('basic','standard','premium')),
    daily_premium  NUMERIC(8,2)  NOT NULL CHECK (daily_premium >= 0),
    coverage_limit NUMERIC(10,2) NOT NULL CHECK (coverage_limit >= 0)
);

-- ----------------------------------------------------------------------------
-- PAYMENT : money taken for a rental (1 rental : many payments allowed)
-- ----------------------------------------------------------------------------
CREATE TABLE payment (
    payment_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rental_id   INT           NOT NULL REFERENCES rental(rental_id) ON DELETE CASCADE,
    amount      NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    method      VARCHAR(10)   NOT NULL CHECK (method IN ('card','cash','online')),
    status      VARCHAR(10)   NOT NULL DEFAULT 'completed'
                CHECK (status IN ('pending','completed','refunded','failed')),
    paid_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- RENTAL_ITEM : WEAK ENTITY — optional add-ons charged on a rental
--   (e.g. GPS unit, child seat, additional driver).
--   It has no key of its own: it is existence-dependent on its owner RENTAL
--   and identified by the owner key (rental_id) plus a partial/discriminator
--   key (item_no).  PRIMARY KEY (rental_id, item_no) expresses exactly that,
--   and ON DELETE CASCADE enforces the existence dependency.
-- ----------------------------------------------------------------------------
CREATE TABLE rental_item (
    rental_id   INT          NOT NULL REFERENCES rental(rental_id) ON DELETE CASCADE,
    item_no     SMALLINT     NOT NULL,            -- partial (discriminator) key
    description VARCHAR(60)  NOT NULL,
    quantity    SMALLINT     NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_fee    NUMERIC(8,2) NOT NULL CHECK (unit_fee >= 0),
    PRIMARY KEY (rental_id, item_no)              -- owner key + partial key
);

-- ----------------------------------------------------------------------------
-- MAINTENANCE : service records for a vehicle
-- ----------------------------------------------------------------------------
CREATE TABLE maintenance (
    maint_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id   INT          NOT NULL,                -- logical ref (inheritance)
    service_date DATE         NOT NULL DEFAULT CURRENT_DATE,
    service_type VARCHAR(40)  NOT NULL,
    cost         NUMERIC(10,2) NOT NULL CHECK (cost >= 0),
    notes        VARCHAR(200)
);

-- ----------------------------------------------------------------------------
-- AUDIT_LOG : populated by triggers (change history)
-- ----------------------------------------------------------------------------
CREATE TABLE audit_log (
    log_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  TEXT        NOT NULL,
    action      TEXT        NOT NULL,
    row_pk      TEXT,
    detail      TEXT,
    changed_by  TEXT        NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Helpful indexes ------------------------------------------------------------
CREATE INDEX idx_rental_vehicle  ON rental(vehicle_id, pickup_date, return_date_planned);
CREATE INDEX idx_rental_customer ON rental(customer_id);
CREATE INDEX idx_payment_rental  ON payment(rental_id);
CREATE INDEX idx_vehicle_branch  ON vehicle(branch_id);
