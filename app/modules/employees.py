"""Module 2 - Employees : list / add employees (employee sub-table)."""
import tkinter as tk
from tkinter import ttk, messagebox

from app import db
from app.widgets import show_rows, FormDialog


class EmployeesTab(ttk.Frame):
    def __init__(self, master):
        super().__init__(master, padding=8)

        bar = ttk.Frame(self)
        bar.pack(fill="x")
        ttk.Button(bar, text="Refresh", command=self.refresh).pack(side="left")
        ttk.Button(bar, text="Add employee", command=self.add).pack(side="left", padx=4)
        ttk.Button(bar, text="Delete selected", command=self.delete).pack(side="left")

        self.tree = ttk.Treeview(self, show="headings", height=16)
        self.tree.pack(fill="both", expand=True, pady=6)
        self.refresh()

    def refresh(self):
        rows = db.query(
            """SELECT e.person_id, e.full_name, e.email, e.job_role,
                      e.salary, e.hire_date, b.name AS branch
               FROM employee e JOIN branch b ON b.branch_id = e.branch_id
               ORDER BY e.person_id""")
        show_rows(self.tree, rows)

    def _branches(self):
        return db.query("SELECT branch_id, name FROM branch ORDER BY name")

    def add(self):
        branches = self._branches()
        names = [b["name"] for b in branches]
        d = FormDialog(self, "New employee", [
            ("full_name", "Full name", None, "text"),
            ("email",     "Email",     None, "text"),
            ("phone",     "Phone",     None, "text"),
            ("job_role",  "Role",      None, "combo:manager,agent,mechanic"),
            ("salary",    "Salary",    None, "float"),
            ("branch",    "Branch",    None, "combo:" + ",".join(names)),
        ])
        if not d.result:
            return
        branch_id = next(b["branch_id"] for b in branches if b["name"] == d.result["branch"])
        try:
            db.execute(
                """INSERT INTO employee(full_name, email, phone, job_role, salary, branch_id)
                   VALUES (%s,%s,%s,%s,%s,%s)""",
                (d.result["full_name"], d.result["email"], d.result["phone"],
                 d.result["job_role"], d.result["salary"], branch_id))
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def delete(self):
        sel = self.tree.selection()
        if not sel:
            return
        pid = self.tree.item(sel[0])["values"][0]
        if not messagebox.askyesno("Confirm", f"Delete employee {pid}?"):
            return
        try:
            db.execute("DELETE FROM employee WHERE person_id=%s", (pid,))
            self.refresh()
        except Exception as e:
            messagebox.showerror("Error", str(e))
