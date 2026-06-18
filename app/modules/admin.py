"""
Module 6 - Admin : inspect the trigger-produced audit log, the roles and the
table privileges granted to them.
"""
import tkinter as tk
from tkinter import ttk, messagebox

from app import db
from app.widgets import show_rows


QUERIES = {
    "Audit log (latest 100)":
        "SELECT log_id, table_name, action, row_pk, detail, changed_by, "
        "to_char(changed_at,'YYYY-MM-DD HH24:MI:SS') AS changed_at "
        "FROM audit_log ORDER BY log_id DESC LIMIT 100",
    "Roles":
        "SELECT rolname, rolcanlogin AS can_login, rolsuper AS superuser "
        "FROM pg_roles WHERE rolname LIKE 'dl\\_%' OR rolname IN ('alice_mgr','bob_desk') "
        "ORDER BY rolname",
    "Role privileges (grants)":
        "SELECT grantee, table_name, privilege_type "
        "FROM information_schema.role_table_grants "
        "WHERE grantee LIKE 'dl\\_%' "
        "ORDER BY grantee, table_name, privilege_type",
}


class AdminTab(ttk.Frame):
    def __init__(self, master):
        super().__init__(master, padding=8)

        bar = ttk.Frame(self)
        bar.pack(fill="x")
        ttk.Label(bar, text="View:").pack(side="left")
        self.choice = ttk.Combobox(bar, values=list(QUERIES.keys()),
                                   state="readonly", width=30)
        self.choice.current(0)
        self.choice.pack(side="left", padx=6)
        ttk.Button(bar, text="Show", command=self.run).pack(side="left")

        self.tree = ttk.Treeview(self, show="headings", height=16)
        vs = ttk.Scrollbar(self, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vs.set)
        self.tree.pack(side="left", fill="both", expand=True, pady=6)
        vs.pack(side="right", fill="y")
        self.run()

    def run(self):
        try:
            show_rows(self.tree, db.query(QUERIES[self.choice.get()]))
        except Exception as e:
            messagebox.showerror("Query failed", str(e))
