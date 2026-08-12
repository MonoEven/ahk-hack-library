#!/usr/bin/env python3
"""Attach to a running AutoHotkey process and locate its interpreter tables.

Reads the target process through ReadProcessMemory, parses the loaded PE
image, and reuses the same anchor/run scanning as ahk_inspect.py. It works on
regular and UPX/MPRESS-packed AutoHotkey executables because the image is
already unpacked in memory.

Usage:
    python tools/ahk_remote_attach.py --pid 1234
    python tools/ahk_remote_attach.py --pid 1234 --filter Abs,MsgBox --json
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.wintypes as wt
import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ahk_inspect import find_table  # noqa: E402


PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010
PROCESS_VM_WRITE = 0x0020
PROCESS_VM_OPERATION = 0x0008
TH32CS_SNAPMODULE = 0x00000008
TH32CS_SNAPMODULE32 = 0x00000010
MAX_PATH = 260


class MODULEENTRY32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", wt.DWORD),
        ("th32ModuleID", wt.DWORD),
        ("th32ProcessID", wt.DWORD),
        ("GlblcntUsage", wt.DWORD),
        ("ProccntUsage", wt.DWORD),
        ("modBaseAddr", wt.LPVOID),
        ("modBaseSize", wt.DWORD),
        ("hModule", wt.HMODULE),
        ("szModule", ctypes.c_wchar * 256),
        ("szExePath", ctypes.c_wchar * MAX_PATH),
    ]


kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
kernel32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
kernel32.OpenProcess.restype = wt.HANDLE
kernel32.ReadProcessMemory.argtypes = [
    wt.HANDLE,
    wt.LPCVOID,
    wt.LPVOID,
    ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_size_t),
]
kernel32.ReadProcessMemory.restype = wt.BOOL
kernel32.WriteProcessMemory.argtypes = [
    wt.HANDLE,
    wt.LPVOID,
    wt.LPCVOID,
    ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_size_t),
]
kernel32.WriteProcessMemory.restype = wt.BOOL
kernel32.CloseHandle.argtypes = [wt.HANDLE]
kernel32.CloseHandle.restype = wt.BOOL
kernel32.CreateToolhelp32Snapshot.argtypes = [wt.DWORD, wt.DWORD]
kernel32.CreateToolhelp32Snapshot.restype = wt.HANDLE
kernel32.Module32FirstW.argtypes = [wt.HANDLE, ctypes.POINTER(MODULEENTRY32W)]
kernel32.Module32FirstW.restype = wt.BOOL
kernel32.Module32NextW.argtypes = [wt.HANDLE, ctypes.POINTER(MODULEENTRY32W)]
kernel32.Module32NextW.restype = wt.BOOL


class RemoteProcess:
    def __init__(self, pid: int, write_access: bool = False):
        self.pid = pid
        access = PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
        if write_access:
            access |= PROCESS_VM_WRITE | PROCESS_VM_OPERATION
        self.handle = kernel32.OpenProcess(
            access, False, pid
        )
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())

    def read(self, address: int, size: int) -> bytes:
        buf = ctypes.create_string_buffer(size)
        read = ctypes.c_size_t(0)
        ok = kernel32.ReadProcessMemory(
            self.handle,
            ctypes.c_void_p(address),
            buf,
            size,
            ctypes.byref(read),
        )
        if not ok:
            raise ctypes.WinError(ctypes.get_last_error())
        return buf.raw[: read.value]

    def write(self, address: int, data: bytes):
        written = ctypes.c_size_t(0)
        ok = kernel32.WriteProcessMemory(
            self.handle,
            ctypes.c_void_p(address),
            data,
            len(data),
            ctypes.byref(written),
        )
        if not ok:
            raise ctypes.WinError(ctypes.get_last_error())
        return written.value

    def close(self):
        if self.handle:
            kernel32.CloseHandle(self.handle)
            self.handle = None


def find_main_module(pid: int):
    snapshot = kernel32.CreateToolhelp32Snapshot(
        TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid
    )
    if snapshot == -1:
        raise ctypes.WinError(ctypes.get_last_error())
    modules = []
    try:
        entry = MODULEENTRY32W()
        entry.dwSize = ctypes.sizeof(entry)
        if not kernel32.Module32FirstW(snapshot, ctypes.byref(entry)):
            raise ctypes.WinError(ctypes.get_last_error())
        while True:
            modules.append((entry.modBaseAddr, entry.szExePath, entry.szModule))
            if not kernel32.Module32NextW(snapshot, ctypes.byref(entry)):
                break
    finally:
        kernel32.CloseHandle(snapshot)
    if not modules:
        raise RuntimeError("no modules found for pid %d" % pid)
    for base, path, name in modules:
        if "autohotkey" in name.lower():
            return base, path
    return modules[0][0], modules[0][1]


class RemotePE:
    def __init__(self, proc: RemoteProcess, base: int, module_path: str):
        self.proc = proc
        self.image_base = base
        self.is64 = True
        self.ptr_size = 8
        self.ptr_fmt = "<Q"
        self.module_path = module_path
        self.sections = self._read_sections()
        self._section_by_name = {s["name"]: s for s in self.sections}

    def _read_sections(self):
        dos = self.proc.read(self.image_base, 0x40)
        e_lfanew = struct.unpack_from("<I", dos, 0x3C)[0]
        pe = self.proc.read(self.image_base + e_lfanew, 0x18)
        num_sections = struct.unpack_from("<H", pe, 6)[0]
        opt_size = struct.unpack_from("<H", pe, 20)[0]
        sec_table = self.image_base + e_lfanew + 24 + opt_size
        hdrs = self.proc.read(sec_table, num_sections * 40)
        sections = []
        for i in range(num_sections):
            off = i * 40
            name = hdrs[off : off + 8].split(b"\0", 1)[0].decode("latin1")
            vsize, va, raw_size = struct.unpack_from("<III", hdrs, off + 8)
            size = vsize or raw_size
            try:
                data = self.proc.read(self.image_base + va, size)
            except OSError:
                data = b""
            sections.append(
                {
                    "name": name,
                    "rva": va,
                    "size": size,
                    "data": data,
                }
            )
        return sections

    def section(self, name):
        return self._section_by_name.get(name)

    def in_section(self, rva: int, name: str) -> bool:
        for sec in self.sections:
            if sec["name"] == name and sec["rva"] <= rva < sec["rva"] + sec["size"]:
                return True
        if name == ".text" and not self.section(".text"):
            return any(
                sec["name"] != ".rsrc"
                and sec["rva"] <= rva < sec["rva"] + sec["size"]
                for sec in self.sections
            )
        return False

    def rva_to_offset(self, rva: int):
        return None

    def read_ptr(self, section, offset: int):
        data = section["data"]
        if offset + self.ptr_size > len(data):
            return None
        value = struct.unpack_from(self.ptr_fmt, data, offset)[0]
        return value if value >= self.image_base else None

    def read_utf16(self, rva: int, maxlen: int = 256):
        for sec in self.sections:
            if not (sec["rva"] <= rva < sec["rva"] + sec["size"]):
                continue
            data = sec["data"]
            off = rva - sec["rva"]
            end = min(len(data), off + maxlen)
            i = off
            while i + 1 < end:
                if data[i] == 0 and data[i + 1] == 0:
                    try:
                        text = data[off:i].decode("utf-16-le")
                    except UnicodeDecodeError:
                        return None
                    if text and all(32 <= ord(c) <= 126 for c in text):
                        return text
                    return None
                i += 2
        return None


def attach(pid: int, redirect=None):
    proc = RemoteProcess(pid, write_access=redirect is not None)
    try:
        base, module_path = find_main_module(pid)
        pe = RemotePE(proc, base, module_path)
        tables = {}
        for kind, key in (
            ("bif", "builtins"),
            ("mdfunc", "native_functions"),
            ("biv", "builtin_vars"),
        ):
            table = find_table(pe, kind)
            if table is None:
                tables[key] = {"found": False}
            else:
                tables[key] = {
                    "found": True,
                    "section": table["section"],
                    "table_rva": table["table_rva"],
                    "stride": table["stride"],
                    "count": table["count"],
                    "seed_hits": table["seed_hits"],
                    "sorted": table["sorted"],
                    "entries": table["entries"],
                }
        report = {
            "pid": pid,
            "module": module_path,
            "image_base": base,
            "sections": [
                {"name": s["name"], "rva": s["rva"], "size": s["size"]}
                for s in pe.sections
            ],
            "tables": tables,
        }
        if redirect:
            src, dst = redirect
            table = tables.get("builtins")
            if not table or not table["found"]:
                raise RuntimeError("builtins table not found; cannot redirect")
            by_name = {e["name"]: e for e in table["entries"]}
            if src not in by_name or dst not in by_name:
                raise RuntimeError("redirect names not found in builtins table")
            src_entry = by_name[src]
            dst_entry = by_name[dst]
            src_index = table["entries"].index(src_entry)
            fn_slot = (
                base
                + table["table_rva"]
                + src_index * table["stride"]
                + 8
            )
            proc.write(fn_slot, struct.pack("<Q", base + dst_entry["bif_rva"]))
            report["redirect"] = {
                "src": src,
                "dst": dst,
                "fn_slot": fn_slot,
            }
        return report
    finally:
        proc.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True, help="target process id")
    parser.add_argument("--json", action="store_true", help="print JSON report")
    parser.add_argument(
        "--filter",
        help="comma-separated entry names to print per table",
    )
    parser.add_argument(
        "--quiet", action="store_true", help="suppress the human-readable summary"
    )
    parser.add_argument(
        "--redirect",
        nargs=2,
        metavar=("SRC", "DST"),
        help="redirect a builtin in the running process (e.g. Abs Sin)",
    )
    args = parser.parse_args(argv)

    report = attach(args.pid, redirect=args.redirect)
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0
    if args.quiet:
        return 0

    names = [n.strip() for n in (args.filter or "").split(",") if n.strip()]
    print("pid: %d" % report["pid"])
    print("module: %s" % report["module"])
    print("image_base: 0x%X" % report["image_base"])
    if report.get("redirect"):
        r = report["redirect"]
        print(
            "redirected %s -> %s at 0x%X"
            % (r["src"], r["dst"], r["fn_slot"])
        )
    for key, label in (
        ("builtins", "builtins"),
        ("native_functions", "native functions"),
        ("builtin_vars", "builtin vars"),
    ):
        table = report["tables"][key]
        if not table["found"]:
            print("%s: not found" % label)
            continue
        print(
            "%s: %d entries @ 0x%X stride 0x%X (%s)"
            % (
                label,
                table["count"],
                table["table_rva"],
                table["stride"],
                table["section"],
            )
        )
        if names:
            by_name = {e["name"]: e for e in table["entries"]}
            for name in names:
                entry = by_name.get(name)
                if entry:
                    if key == "builtins":
                        print(
                            "  %s rva=0x%X min=%d max=%d fid=%d"
                            % (
                                name,
                                entry["bif_rva"],
                                entry["min_params"],
                                entry["max_params"],
                                entry["fid"],
                            )
                        )
                    elif key == "native_functions":
                        print(
                            "  %s rva=0x%X ret=%d"
                            % (name, entry["function_rva"], entry["ret_type"])
                        )
                    else:
                        print(
                            "  %s getter_rva=0x%X setter_rva=%s"
                            % (
                                name,
                                entry["getter_rva"],
                                "0x%X" % entry["setter_rva"]
                                if entry["setter_rva"]
                                else "none",
                            )
                        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
