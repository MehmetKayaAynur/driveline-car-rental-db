"""
Data-access layer for DriveLine.

Provides:
  * query()/execute()           - simple read / write helpers
  * create_rental()             - TRANSACTION 1  (SERIALIZABLE  + FOR UPDATE)
  * return_vehicle()            - TRANSACTION 2  (REPEATABLE READ + FOR UPDATE)
  * cancel_rental()             - TRANSACTION 3  (READ COMMITTED + FOR UPDATE)

The three transaction functions are atomic (commit-all-or-rollback) and each
uses an explicit isolation level plus row-level locking (SELECT ... FOR UPDATE)
for concurrency control, so two clerks cannot double-book the same vehicle.
"""
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import DB


def get_conn():
    return psycopg2.connect(**DB)


def query(sql, params=None):
    """Run a SELECT and return a list of dict rows."""
    conn = get_conn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Pass params through as-is: when None, psycopg2 skips binding so a
            # literal '%' in the SQL (e.g. LIKE 'dl\_%') is left untouched.
            cur.execute(sql, params)
            return cur.fetchall()
    finally:
        conn.close()


def execute(sql, params=None):
    """Run an INSERT/UPDATE/DELETE, commit, return affected row count."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            rc = cur.rowcount
        conn.commit()
        return rc
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# TRANSACTION 1 : create a rental (optionally with insurance + a payment)
#   Isolation : SERIALIZABLE
#   Locking   : SELECT ... FOR UPDATE on the vehicle row
# ---------------------------------------------------------------------------
def create_rental(vehicle_id, customer_id, employee_id, pickup_branch_id,
                  return_branch_id, pickup_date, return_date_planned,
                  daily_rate, status="reserved", insurance=None, payment=None):
    conn = get_conn()
    try:
        conn.set_session(isolation_level="SERIALIZABLE")
        with conn.cursor() as cur:
            # Concurrency control: lock the vehicle so a parallel rental waits.
            cur.execute("SELECT status FROM vehicle WHERE vehicle_id=%s FOR UPDATE",
                        (vehicle_id,))
            if cur.fetchone() is None:
                raise ValueError(f"Vehicle {vehicle_id} not found")

            cur.execute(
                """INSERT INTO rental(vehicle_id, customer_id, employee_id,
                       pickup_branch_id, return_branch_id, pickup_date,
                       return_date_planned, daily_rate, status)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                   RETURNING rental_id""",
                (vehicle_id, customer_id, employee_id, pickup_branch_id,
                 return_branch_id, pickup_date, return_date_planned,
                 daily_rate, status))
            rental_id = cur.fetchone()[0]

            if insurance:
                cur.execute(
                    """INSERT INTO insurance(rental_id, ins_type, daily_premium, coverage_limit)
                       VALUES (%s,%s,%s,%s)""",
                    (rental_id, insurance["ins_type"],
                     insurance["daily_premium"], insurance["coverage_limit"]))

            if payment:
                cur.execute(
                    """INSERT INTO payment(rental_id, amount, method, status)
                       VALUES (%s,%s,%s,'completed')""",
                    (rental_id, payment["amount"], payment["method"]))
        conn.commit()
        return rental_id
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# TRANSACTION 2 : return a vehicle (close rental + odometer + extra charge)
#   Isolation : REPEATABLE READ
#   Locking   : SELECT ... FOR UPDATE on the rental row
# ---------------------------------------------------------------------------
def return_vehicle(rental_id, return_date_actual, mileage_added=0,
                   extra_payment=None):
    conn = get_conn()
    try:
        conn.set_session(isolation_level="REPEATABLE READ")
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM rental WHERE rental_id=%s FOR UPDATE",
                        (rental_id,))
            r = cur.fetchone()
            if r is None:
                raise ValueError("Rental not found")
            if r["status"] not in ("reserved", "active"):
                raise ValueError(f"Rental is '{r['status']}' and cannot be returned")

            cur.execute(
                """UPDATE rental SET status='returned', return_date_actual=%s
                   WHERE rental_id=%s""",
                (return_date_actual, rental_id))

            if mileage_added:
                cur.execute("UPDATE vehicle SET mileage = mileage + %s WHERE vehicle_id=%s",
                            (mileage_added, r["vehicle_id"]))

            if extra_payment and extra_payment.get("amount"):
                cur.execute(
                    """INSERT INTO payment(rental_id, amount, method, status)
                       VALUES (%s,%s,%s,'completed')""",
                    (rental_id, extra_payment["amount"], extra_payment["method"]))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# TRANSACTION 3 : cancel a rental and refund its completed payments
#   Isolation : READ COMMITTED
#   Locking   : SELECT ... FOR UPDATE on the rental row
# ---------------------------------------------------------------------------
def cancel_rental(rental_id):
    conn = get_conn()
    try:
        conn.set_session(isolation_level="READ COMMITTED")
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT status FROM rental WHERE rental_id=%s FOR UPDATE",
                        (rental_id,))
            r = cur.fetchone()
            if r is None:
                raise ValueError("Rental not found")
            if r["status"] == "cancelled":
                raise ValueError("Rental is already cancelled")

            cur.execute("UPDATE rental SET status='cancelled' WHERE rental_id=%s",
                        (rental_id,))
            cur.execute(
                """UPDATE payment SET status='refunded'
                   WHERE rental_id=%s AND status='completed'""",
                (rental_id,))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
