"""Module 1 - Customers : list / add / delete customers (customer sub-table)."""
import tkinter as tk
from tkinter import ttk, messagebox

from app import db
from app.widgets import show_rows, FormDialog


class CustomersTab(ttk.Frame):
    def __init__(self, master):
        super().__init__(master, padding=8)

        bar = ttk.Frame(self)
        bar.pack(fill="x")
        ttk.Button(bar, text="Refresh", command=self.refresh).pack(side="left")
        ttk.Button(bar, text="Add customer", command=self.add).pack(side="left", padx=4)
        ttk.Button(bar, text="Delete selected", command=self.delete).pack(side="left")

        self.tree = ttk.Treeview(self, show="headings", height=16)
        self.tree.pack(fill="both", expand=True, pady=6)
        self.refresh()

    def refresh(self):
        rows = db.query(
            """SELECT person_id, full_name, email, phone, license_no,
                      join_date, loyalty_points
               FROM customer ORDER BY person_id""")
        show_rows(self.tree, rows)

    def add(self):
        d = FormDialog(self, "New customer", [
            ("full_name",  "Full name",  None, "text"),
            ("email",      "Email",      None, "text"),
            ("phone",      "Phone",      None, "text"),
            ("license_no", "License no", None, "text"),
        ])
        if not d.result:
            return
        try:
            db.execute(
                """INSERT INTO customer(full_name, email, phone, license_no)
                   VALUES (%(full_name)s, %(email)s, %(phone)s, %(license_no)s)""",
                d.result)
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def delete(self):
        sel = self.tree.selection()
        if not sel:
            return
        pid = self.tree.item(sel[0])["values"][0]
        if not messagebox.askyesno("Confirm", f"Delete customer {pid}?"):
            return
        try:
            db.execute("DELETE FROM customer WHERE person_id=%s", (pid,))
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))
