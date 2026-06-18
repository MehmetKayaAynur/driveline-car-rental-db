"""DriveLine - Tkinter entry point. Run with:  python run.py"""
import tkinter as tk
from tkinter import ttk, messagebox

from app import db, config
from app.modules.customers import CustomersTab
from app.modules.vehicles import VehiclesTab
from app.modules.rentals import RentalsTab
from app.modules.employees import EmployeesTab
from app.modules.reports import ReportsTab
from app.modules.admin import AdminTab


def main():
    root = tk.Tk()
    root.title("DriveLine - Car Rental Management")
    root.geometry("1040x660")

    try:
        ttk.Style().theme_use("clam")
    except tk.TclError:
        pass

    # Verify the connection up front so the user gets a clear message.
    try:
        db.query("SELECT 1")
    except Exception as e:
        messagebox.showerror(
            "Database connection failed",
            "Could not connect to PostgreSQL.\n\n"
            f"{e}\n\n"
            "Fix app/config.py (or the PG* environment variables) and make sure "
            "the database has been created with:  python setup_db.py")

    nb = ttk.Notebook(root)
    nb.pack(fill="both", expand=True)
    nb.add(CustomersTab(nb), text="Customers")
    nb.add(VehiclesTab(nb),  text="Fleet")
    nb.add(RentalsTab(nb),   text="Rentals")
    nb.add(EmployeesTab(nb), text="Employees")
    nb.add(ReportsTab(nb),   text="Reports")
    nb.add(AdminTab(nb),     text="Admin")

    status = ttk.Label(
        root, anchor="w", relief="sunken", padding=4,
        text=f"DB: {config.DB['dbname']} @ {config.DB['host']}:{config.DB['port']} "
             f"(user: {config.DB['user']})")
    status.pack(fill="x", side="bottom")

    root.mainloop()


if __name__ == "__main__":
    main()
