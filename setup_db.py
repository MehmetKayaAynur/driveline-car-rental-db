"""
Bootstrap the DriveLine database.

It runs the SQL files in order against the database named in app/config.py
(or the PG* environment variables).  The target database must already exist:

    createdb driveline           # or:  CREATE DATABASE driveline;

Then:

    python setup_db.py

Each file is executed and committed on its own.  The roles file (04) needs a
privileged user; if it fails the script prints a warning and keeps going so the
rest of the schema and data still load.
"""
import os
import sys

from app import db

FILES = [
    "01_schema.sql",
    "02_triggers.sql",
    "03_views.sql",
    "04_roles.sql",
    "05_sample_data.sql",
]

CRITICAL = {"01_schema.sql", "02_triggers.sql", "03_views.sql", "05_sample_data.sql"}


def run():
    here = os.path.dirname(os.path.abspath(__file__))
    sql_dir = os.path.join(here, "sql")

    conn = db.get_conn()
    conn.autocommit = True
    try:
        cur = conn.cursor()
        for fname in FILES:
            path = os.path.join(sql_dir, fname)
            with open(path, encoding="utf-8") as fh:
                sql = fh.read()
            print(f"-- running {fname} ...", end=" ")
            try:
                cur.execute(sql)
                print("OK")
            except Exception as e:
                print("FAILED")
                print(f"   {e}")
                if fname in CRITICAL:
                    print("   This file is required; aborting.")
                    sys.exit(1)
                else:
                    print("   Skipping (non-critical) and continuing.")
        print("\nDatabase ready.  Start the app with:  python run.py")
    finally:
        conn.close()


if __name__ == "__main__":
    run()
