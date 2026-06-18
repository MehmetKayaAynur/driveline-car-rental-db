"""
Module 3 - Fleet : browse all vehicles via the v_fleet view and add new ones
into the correct INHERITANCE sub-table (car / van / motorcycle).
"""
import tkinter as tk
from tkinter import ttk, messagebox

from app import db
from app.widgets import show_rows, FormDialog


class VehiclesTab(ttk.Frame):
    def __init__(self, master):
        super().__init__(master, padding=8)

        bar = ttk.Frame(self)
        bar.pack(fill="x")
        ttk.Button(bar, text="Refresh", command=self.refresh).pack(side="left")
        ttk.Button(bar, text="Add car", command=lambda: self.add("car")).pack(side="left", padx=4)
        ttk.Button(bar, text="Add van", command=lambda: self.add("van")).pack(side="left")
        ttk.Button(bar, text="Add motorcycle", command=lambda: self.add("motorcycle")).pack(side="left", padx=4)
        ttk.Button(bar, text="Set maintenance", command=self.toggle_maintenance).pack(side="left")

        self.tree = ttk.Treeview(self, show="headings", height=16)
        self.tree.pack(fill="both", expand=True, pady=6)
        self.refresh()

    def refresh(self):
        show_rows(self.tree, db.query("SELECT * FROM v_fleet"))

    def _branches(self):
        return db.query("SELECT branch_id, name FROM branch ORDER BY name")

    def add(self, vtype):
        branches = self._branches()
        names = [b["name"] for b in branches]
        common = [
            ("branch",     "Branch",      None, "combo:" + ",".join(names)),
            ("make",       "Make",        None, "text"),
            ("model",      "Model",       None, "text"),
            ("model_year", "Year",        2024, "int"),
            ("plate",      "Plate",       None, "text"),
            ("daily_rate", "Daily rate",  None, "float"),
            ("mileage",    "Mileage",     0,    "int"),
        ]
        if vtype == "car":
            extra = [("num_doors", "Doors", 4, "int"),
                     ("transmission", "Transmission", None, "combo:automatic,manual"),
                     ("has_gps", "Has GPS", False, "bool")]
        elif vtype == "van":
            extra = [("cargo_volume_m3", "Cargo m3", None, "float"),
                     ("passenger_capacity", "Passengers", 3, "int")]
        else:  # motorcycle
            extra = [("engine_cc", "Engine cc", None, "int"),
                     ("has_sidecar", "Has sidecar", False, "bool")]

        d = FormDialog(self, f"New {vtype}", common + extra)
        if not d.result:
            return
        r = d.result
        branch_id = next(b["branch_id"] for b in branches if b["name"] == r["branch"])
        base = (branch_id, r["make"], r["model"], r["model_year"],
                r["plate"], r["daily_rate"], r["mileage"])
        try:
            if vtype == "car":
                db.execute(
                    """INSERT INTO car(branch_id,make,model,model_year,plate,daily_rate,
                           mileage,num_doors,transmission,has_gps)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    base + (r["num_doors"], r["transmission"], r["has_gps"]))
            elif vtype == "van":
                db.execute(
                    """INSERT INTO van(branch_id,make,model,model_year,plate,daily_rate,
                           mileage,cargo_volume_m3,passenger_capacity)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    base + (r["cargo_volume_m3"], r["passenger_capacity"]))
            else:
                db.execute(
                    """INSERT INTO motorcycle(branch_id,make,model,model_year,plate,daily_rate,
                           mileage,engine_cc,has_sidecar)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    base + (r["engine_cc"], r["has_sidecar"]))
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def toggle_maintenance(self):
        sel = self.tree.selection()
        if not sel:
            return
        vid = self.tree.item(sel[0])["values"][0]
        cur = self.tree.item(sel[0])["values"][6]  # status column in v_fleet
        new = "available" if cur == "maintenance" else "maintenance"
        try:
            db.execute("UPDATE vehicle SET status=%s WHERE vehicle_id=%s", (new, vid))
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))
