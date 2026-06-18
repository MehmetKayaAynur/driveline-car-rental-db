"""Small reusable Tkinter helpers shared by the module tabs."""
import tkinter as tk
from tkinter import ttk, messagebox


def show_rows(tree, rows):
    """Populate a ttk.Treeview from a list of dict rows (columns inferred)."""
    tree.delete(*tree.get_children())
    tree["show"] = "headings"
    if not rows:
        tree["columns"] = ("info",)
        tree.heading("info", text="(no rows)")
        tree.column("info", width=240, anchor="w")
        return
    cols = list(rows[0].keys())
    tree["columns"] = cols
    for c in cols:
        tree.heading(c, text=c)
        tree.column(c, width=max(90, min(220, 11 * len(c))), anchor="w")
    for r in rows:
        tree.insert("", "end", values=[r[c] for c in cols])


class FormDialog(tk.Toplevel):
    """
    Modal form built from a field spec.

    fields: list of (key, label, default, kind) where kind is one of:
        'text', 'int', 'float', 'bool', or 'combo:opt1,opt2,...'
    Result is available as `dialog.result` (dict) or None if cancelled.
    """

    def __init__(self, parent, title, fields):
        super().__init__(parent)
        self.title(title)
        self.result = None
        self._spec = fields
        self._vars = {}

        body = ttk.Frame(self, padding=12)
        body.pack(fill="both", expand=True)

        for i, (key, label, default, kind) in enumerate(fields):
            ttk.Label(body, text=label).grid(row=i, column=0, sticky="w", padx=6, pady=4)
            if kind.startswith("combo:"):
                opts = kind.split(":", 1)[1].split(",")
                var = tk.StringVar(value=default if default is not None else opts[0])
                ttk.Combobox(body, textvariable=var, values=opts,
                             state="readonly", width=30).grid(row=i, column=1, padx=6, pady=4)
            elif kind == "bool":
                var = tk.BooleanVar(value=bool(default))
                ttk.Checkbutton(body, variable=var).grid(row=i, column=1, sticky="w", padx=6, pady=4)
            else:
                var = tk.StringVar(value="" if default is None else str(default))
                ttk.Entry(body, textvariable=var, width=32).grid(row=i, column=1, padx=6, pady=4)
            self._vars[key] = (var, kind)

        btns = ttk.Frame(body)
        btns.grid(row=len(fields), column=0, columnspan=2, pady=(12, 0))
        ttk.Button(btns, text="OK", command=self._ok).pack(side="left", padx=6)
        ttk.Button(btns, text="Cancel", command=self.destroy).pack(side="left", padx=6)

        self.transient(parent)
        self.grab_set()
        self.bind("<Return>", lambda e: self._ok())
        self.bind("<Escape>", lambda e: self.destroy())
        self.wait_window()

    def _ok(self):
        out = {}
        try:
            for key, (var, kind) in self._vars.items():
                raw = var.get()
                if kind == "int":
                    out[key] = int(raw) if str(raw).strip() else None
                elif kind == "float":
                    out[key] = float(raw) if str(raw).strip() else None
                elif kind == "bool":
                    out[key] = bool(raw)
                else:
                    out[key] = (str(raw).strip() or None)
        except ValueError as e:
            messagebox.showerror("Invalid input", str(e), parent=self)
            return
        self.result = out
        self.destroy()
