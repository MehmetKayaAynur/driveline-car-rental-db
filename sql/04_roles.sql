-- ============================================================================
-- DriveLine - File 04 : ROLES & PRIVILEGES
-- ----------------------------------------------------------------------------
-- Four roles: admin (full), manager (operational), agent (front desk),
-- analyst (read-only reporting).  Run as the database owner. Safe to re-run.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dl_admin')   THEN CREATE ROLE dl_admin   NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dl_manager') THEN CREATE ROLE dl_manager NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dl_agent')   THEN CREATE ROLE dl_agent   NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dl_analyst') THEN CREATE ROLE dl_analyst NOLOGIN; END IF;
END$$;

-- dl_admin : everything ------------------------------------------------------
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO dl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dl_admin;

-- dl_manager : full DML on operational data, read audit -----------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
      branch, vehicle, car, van, motorcycle,
      customer, employee, rental, insurance, payment, maintenance
   TO dl_manager;
GRANT SELECT ON audit_log TO dl_manager;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dl_manager;

-- dl_agent (front desk):
--   handle rentals, insurance, payments and customers; read the fleet.
--   May NOT alter vehicles, salaries or branches.
GRANT SELECT, INSERT, UPDATE ON rental, insurance, payment TO dl_agent;
GRANT SELECT, INSERT, UPDATE ON customer                   TO dl_agent;
GRANT SELECT ON vehicle, car, van, motorcycle, branch, employee TO dl_agent;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public      TO dl_agent;

-- dl_analyst : read-only (base tables + all reporting views) ------------------
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dl_analyst;

-- Example login users mapped to roles (placeholder passwords) -----------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='alice_mgr') THEN
        CREATE ROLE alice_mgr LOGIN PASSWORD 'changeme'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='bob_desk') THEN
        CREATE ROLE bob_desk  LOGIN PASSWORD 'changeme'; END IF;
END$$;

GRANT dl_manager TO alice_mgr;
GRANT dl_agent   TO bob_desk;

-- New objects created later by the owner stay readable to analysts -----------
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dl_analyst;
