# DriveLine — Car Rental Company Database

A complete PostgreSQL database + Python/Tkinter desktop application for a
hypothetical car-rental chain (**DriveLine**). Built to demonstrate the full
range of relational-database concepts: inheritance, triggers, views,
transactions, concurrency control, outer joins, and role-based privileges.

---

## 1. Requirements

### Software
- **PostgreSQL 13+**
- **Python 3.9+** with Tkinter (bundled with the standard Windows installer)
- `psycopg2-binary` (see `requirements.txt`)

### Install Python deps
```powershell
pip install -r requirements.txt
```

---

## 2. Create and load the database

> **This machine:** PostgreSQL 17 runs as a *manual* cluster (not a Windows
> service), data dir `C:\Users\mkaya\pgdata`. Start the server after each reboot
> with:
> ```powershell
> powershell -ExecutionPolicy Bypass -File start_db.ps1
> ```
> The `driveline` database and all objects are already loaded, so you can skip
> straight to **section 3** once the server is running. Re-run `python setup_db.py`
> any time you want to reset to the original sample data.

1. Create an empty database (one time):
   ```powershell
   createdb driveline
   # or in psql:  CREATE DATABASE driveline;
   ```

2. Tell the app how to connect. Copy the template and set your password
   (`app/config.py` is git-ignored, so your password is never committed):
   ```powershell
   copy app\config.example.py app\config.py
   ```
   Then edit **`app/config.py`**, or set environment variables (`PGHOST`,
   `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`).
   Defaults: `localhost:5432`, db `driveline`, user `postgres`.

3. Load schema, triggers, views, roles and sample data:
   ```powershell
   python setup_db.py
   ```
   (The roles step needs a privileged user; if it fails the rest still loads.)

---

## 3. Run the application

```powershell
python run.py
```

A window opens with six tabs (modules).

---

## 4. Project structure

```
database/
├── run.py                 # launcher
├── setup_db.py            # loads all SQL files into the database
├── requirements.txt
├── README.md
├── start_db.ps1          # starts the local PostgreSQL cluster
├── sql/
│   ├── 01_schema.sql      # tables, keys, constraints, INHERITANCE
│   ├── 02_triggers.sql    # 5 triggers
│   ├── 03_views.sql       # 5 views
│   ├── 04_roles.sql       # roles & privileges
│   ├── 05_sample_data.sql # seed data
│   └── queries.sql        # the LEFT / RIGHT / FULL outer-join showcase queries
└── app/
    ├── config.example.py  # copy to config.py, then set your DB password
    ├── db.py              # data access + the 3 atomic transactions
    ├── widgets.py         # reusable Tkinter helpers
    ├── main.py            # builds the window / notebook
    └── modules/
        ├── customers.py   # Module 1
        ├── vehicles.py    # Module 3 (Fleet)
        ├── rentals.py     # Module 4
        ├── employees.py   # Module 2
        ├── reports.py     # Module 5
        └── admin.py       # Module 6
```

---

## 5. Where each project requirement lives

| Requirement | Implementation |
|---|---|
| **Report, slides, E-R diagram, FDs, normalization** | submitted separately (not in this code repo) |
| **Schema (tables/keys/relationships)** | `sql/01_schema.sql` |
| **SQL implementation** | all files in `sql/` |
| **User interface (6 modules)** | `app/modules/` |
| **Outer joins (LEFT / RIGHT / FULL)** | `sql/queries.sql`, shown in the **Reports** tab |
| **5 triggers** | `sql/02_triggers.sql`, effects visible in the **Admin → Audit log** tab |
| **5 views** | `sql/03_views.sql`, shown in the **Reports** tab |
| **3 atomic transactions** | `app/db.py` (`create_rental`, `return_vehicle`, `cancel_rental`), driven from the **Rentals** tab |
| **Concurrency control (3 transactions)** | each transaction sets an isolation level + uses `SELECT … FOR UPDATE` (see `app/db.py`) |
| **Inheritance** | `person → employee, customer` and `vehicle → car, van, motorcycle` (`sql/01_schema.sql`), surfaced in the **Fleet** tab and `v_fleet` |
| **Privileges & roles** | `sql/04_roles.sql`, shown in the **Admin** tab |

---

## 6. The six UI modules

1. **Customers** — list / add / delete customers (the `customer` sub-table).
2. **Employees** — list / add / delete staff (the `employee` sub-table).
3. **Fleet** — browse every vehicle via `v_fleet`; add cars, vans or
   motorcycles into the correct inheritance child table; toggle maintenance.
4. **Rentals** — create a rental (atomic, serializable), return a vehicle,
   cancel + refund. Trigger errors (overlap, vehicle in maintenance) pop up here.
5. **Reports** — run the 5 views and the 3 outer-join queries.
6. **Admin** — the trigger-produced audit log, the roles, and their grants.

---

## 7. Things to try (demonstrations)

- **Trigger – overlap guard:** create two rentals for the same vehicle with
  overlapping dates → the second is rejected.
- **Trigger – maintenance guard:** set a vehicle to *maintenance* in the Fleet
  tab, then try to rent it → rejected.
- **Trigger – loyalty:** take a payment on a rental, then check the customer’s
  `loyalty_points` grew (Customers tab).
- **Trigger – status sync:** mark a rental *active* → the vehicle becomes
  *rented* automatically; return it → it becomes *available*.
- **Trigger – audit:** every rental change appears in **Admin → Audit log**.
- **Transaction atomicity:** cancelling a rental flips the rental to *cancelled*
  **and** refunds its payments in one unit of work.
- **Inheritance:** `SELECT * FROM vehicle` returns cars, vans and motorcycles
  together; the Fleet tab shows each subtype’s special attributes.
