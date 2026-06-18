"""
Module 4 - Rentals : create / return / cancel rentals.

Every action here runs through one of the atomic TRANSACTION functions in
app.db (with isolation level + row locking).  Trigger errors (overlap,
vehicle in maintenance, ...) surface as message boxes.
"""
import datetime as dt
import tkinter as tk
from tkinter import ttk, messagebox

from app import db
from app.widgets import show_rows, FormDialog


def _id_of(combo_value):
    """Parse the leading id from a 'id | label' combo string."""
    return int(str(combo_value).split(" | ", 1)[0])


class RentalsTab(ttk.Frame):
    def __init__(self, master):
        super().__init__(master, padding=8)

        bar = ttk.Frame(self)
        bar.pack(fill="x")
        ttk.Button(bar, text="Refresh", command=self.refresh).pack(side="left")
        ttk.Button(bar, text="New rental", command=self.new_rental).pack(side="left", padx=4)
        ttk.Button(bar, text="Return vehicle", command=self.return_vehicle).pack(side="left")
        ttk.Button(bar, text="Cancel rental", command=self.cancel_rental).pack(side="left", padx=4)
        ttk.Button(bar, text="Mark active", command=self.mark_active).pack(side="left")

        self.tree = ttk.Treeview(self, show="headings", height=16)
        self.tree.pack(fill="both", expand=True, pady=6)
        self.refresh()

    def refresh(self):
        rows = db.query(
            """SELECT r.rental_id, v.make||' '||v.model AS vehicle, v.plate,
                      c.full_name AS customer, r.pickup_date,
                      r.return_date_planned, r.daily_rate, r.status
               FROM rental r
               JOIN vehicle  v ON v.vehicle_id = r.vehicle_id
               JOIN customer c ON c.person_id  = r.customer_id
               ORDER BY r.rental_id DESC""")
        show_rows(self.tree, rows)

    def _selected_id(self):
        sel = self.tree.selection()
        if not sel:
            messagebox.showinfo("Select", "Please select a rental first.")
            return None
        return self.tree.item(sel[0])["values"][0]

    # -- TRANSACTION 1 : create -------------------------------------------------
    def new_rental(self):
        vehicles = db.query(
            "SELECT vehicle_id, make, model, plate, daily_rate, status "
            "FROM vehicle WHERE status <> 'retired' ORDER BY vehicle_id")
        custs = db.query("SELECT person_id, full_name FROM customer ORDER BY person_id")
        emps = db.query("SELECT person_id, full_name FROM employee ORDER BY person_id")
        branches = db.query("SELECT branch_id, name FROM branch ORDER BY name")

        v_opts = [f"{v['vehicle_id']} | {v['make']} {v['model']} ({v['plate']}) [{v['status']}]"
                  for v in vehicles]
        c_opts = [f"{c['person_id']} | {c['full_name']}" for c in custs]
        e_opts = ["0 | (none)"] + [f"{e['person_id']} | {e['full_name']}" for e in emps]
        b_names = [b["name"] for b in branches]
        today = dt.date.today().isoformat()

        d = FormDialog(self, "New rental", [
            ("vehicle",  "Vehicle",        None, "combo:" + ",".join(v_opts)),
            ("customer", "Customer",       None, "combo:" + ",".join(c_opts)),
            ("agent",    "Agent",          None, "combo:" + ",".join(e_opts)),
            ("pickup_b", "Pickup branch",  None, "combo:" + ",".join(b_names)),
            ("return_b", "Return branch",  None, "combo:" + ",".join(b_names)),
            ("pickup",   "Pickup date",    today, "text"),
            ("plan_ret", "Planned return", today, "text"),
            ("rate",     "Daily rate (blank=vehicle default)", None, "float"),
            ("status",   "Status",         "reserved", "combo:reserved,active"),
            ("ins",      "Add insurance?", False, "bool"),
            ("ins_type", "Insurance type", "standard", "combo:basic,standard,premium"),
            ("ins_prem", "Daily premium",  15, "float"),
            ("ins_cov",  "Coverage limit", 50000, "float"),
            ("pay",      "Take payment now?", False, "bool"),
            ("pay_amt",  "Payment amount",  None, "float"),
            ("pay_mth",  "Payment method",  "card", "combo:card,cash,online"),
        ])
        if not d.result:
            return
        r = d.result
        vehicle_id = _id_of(r["vehicle"])
        customer_id = _id_of(r["customer"])
        agent_id = _id_of(r["agent"]) or None
        pickup_bid = next(b["branch_id"] for b in branches if b["name"] == r["pickup_b"])
        return_bid = next(b["branch_id"] for b in branches if b["name"] == r["return_b"])

        rate = r["rate"]
        if rate is None:
            rate = next(v["daily_rate"] for v in vehicles if v["vehicle_id"] == vehicle_id)

        insurance = None
        if r["ins"]:
            insurance = {"ins_type": r["ins_type"], "daily_premium": r["ins_prem"],
                         "coverage_limit": r["ins_cov"]}
        payment = None
        if r["pay"] and r["pay_amt"]:
            payment = {"amount": r["pay_amt"], "method": r["pay_mth"]}

        try:
            rid = db.create_rental(
                vehicle_id, customer_id, agent_id, pickup_bid, return_bid,
                r["pickup"], r["plan_ret"], rate, status=r["status"],
                insurance=insurance, payment=payment)
            messagebox.showinfo("Success", f"Rental #{rid} created.")
            self.refresh()
        except Exception as e:
            messagebox.showerror("Rental failed", str(e))

    # -- TRANSACTION 2 : return -------------------------------------------------
    def return_vehicle(self):
        rid = self._selected_id()
        if rid is None:
            return
        d = FormDialog(self, f"Return rental #{rid}", [
            ("actual",  "Actual return date", dt.date.today().isoformat(), "text"),
            ("mileage", "Mileage added",      0, "int"),
            ("extra",   "Extra charge",       None, "float"),
            ("method",  "Charge method",      "card", "combo:card,cash,online"),
        ])
        if not d.result:
            return
        extra = None
        if d.result["extra"]:
            extra = {"amount": d.result["extra"], "method": d.result["method"]}
        try:
            db.return_vehicle(rid, d.result["actual"], d.result["mileage"], extra)
            messagebox.showinfo("Done", f"Rental #{rid} returned.")
            self.refresh()
        except Exception as e:
            messagebox.showerror("Return failed", str(e))

    # -- TRANSACTION 3 : cancel -------------------------------------------------
    def cancel_rental(self):
        rid = self._selected_id()
        if rid is None:
            return
        if not messagebox.askyesno("Confirm", f"Cancel rental #{rid} and refund payments?"):
            return
        try:
            db.cancel_rental(rid)
            messagebox.showinfo("Done", f"Rental #{rid} cancelled.")
            self.refresh()
        except Exception as e:
            messagebox.showerror("Cancel failed", str(e))

    def mark_active(self):
        rid = self._selected_id()
        if rid is None:
            return
        try:
            db.execute("UPDATE rental SET status='active' WHERE rental_id=%s "
                       "AND status='reserved'", (rid,))
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))
