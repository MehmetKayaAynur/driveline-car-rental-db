"""
Module 5 - Reports : run the 5 views and the 3 outer-join showcase queries,
displaying each result in the grid.
"""
import tkinter as tk
from tkinter import ttk, messagebox

from app import db
from app.widgets import show_rows


REPORTS = {
    # views
    "Active rentals (view)":       "SELECT * FROM v_active_rentals",
    "Vehicle utilization (view)":  "SELECT * FROM v_vehicle_utilization",
    "Branch revenue (view)":       "SELECT * FROM v_branch_revenue",
    "Customer history (view)":     "SELECT * FROM v_customer_history",
    "Fleet catalogue (view)":      "SELECT * FROM v_fleet",
    # outer joins
    "LEFT JOIN - vehicles & rentals": """
        SELECT v.vehicle_id, v.make||' '||v.model AS vehicle, v.plate, v.status,
               count(r.rental_id) AS times_rented
        FROM vehicle v
        LEFT OUTER JOIN rental r ON r.vehicle_id = v.vehicle_id
        GROUP BY v.vehicle_id, v.make, v.model, v.plate, v.status
        ORDER BY times_rented ASC, v.vehicle_id""",
    "RIGHT JOIN - agents & rentals": """
        SELECT e.full_name AS agent, e.job_role, r.rental_id, r.pickup_date, r.status
        FROM rental r
        RIGHT OUTER JOIN employee e ON e.person_id = r.employee_id
        ORDER BY e.full_name, r.rental_id""",
    "FULL OUTER JOIN - agents vs rentals": """
        SELECT COALESCE(e.full_name,'(unassigned)') AS agent, r.rental_id, r.status,
               CASE WHEN e.person_id IS NULL THEN 'rental without agent'
                    WHEN r.rental_id IS NULL THEN 'agent without rentals'
                    ELSE 'matched' END AS note
        FROM employee e
        FULL OUTER JOIN rental r ON r.employee_id = e.person_id
        ORDER BY note, agent""",
}


class ReportsTab(ttk.Frame):
    def __init__(self, master):
        super().__init__(master, padding=8)

        bar = ttk.Frame(self)
        bar.pack(fill="x")
        ttk.Label(bar, text="Report:").pack(side="left")
        self.choice = ttk.Combobox(bar, values=list(REPORTS.keys()),
                                   state="readonly", width=42)
        self.choice.current(0)
        self.choice.pack(side="left", padx=6)
        ttk.Button(bar, text="Run", command=self.run).pack(side="left")

        self.tree = ttk.Treeview(self, show="headings", height=16)
        vs = ttk.Scrollbar(self, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vs.set)
        self.tree.pack(side="left", fill="both", expand=True, pady=6)
        vs.pack(side="right", fill="y")
        self.run()

    def run(self):
        sql = REPORTS[self.choice.get()]
        try:
            show_rows(self.tree, db.query(sql))
        except Exception as e:
            messagebox.showerror("Query failed", str(e))
