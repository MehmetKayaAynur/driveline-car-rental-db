"""
Database connection settings — TEMPLATE.

Copy this file to  app/config.py  and fill in your own PostgreSQL password
(app/config.py is git-ignored so your password is never committed):

    copy app\\config.example.py app\\config.py     (Windows)
    cp   app/config.example.py app/config.py        (macOS/Linux)

You can also override any value with the standard libpq environment variables
(PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD).
"""
import os

DB = {
    "host":     os.getenv("PGHOST", "localhost"),
    "port":     os.getenv("PGPORT", "5432"),
    "dbname":   os.getenv("PGDATABASE", "driveline"),
    "user":     os.getenv("PGUSER", "postgres"),
    "password": os.getenv("PGPASSWORD", "your_password_here"),
}
