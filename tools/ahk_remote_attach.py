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
PROCESS_CREATE_THREAD = 0x0002
TH32CS_SNAPMODULE = 0x00000008
TH32CS_SNAPMODULE32 = 0x00000010
TH32CS_SNAPPROCESS = 0x00000002
MAX_PATH = 260
MEM_COMMIT = 0x1000
MEM_RESERVE = 0x2000
MEM_RELEASE = 0x8000
PAGE_EXECUTE_READWRITE = 0x40
INFINITE = 0xFFFFFFFF
MEM_COMMIT = 0x1000
MEM_PRIVATE = 0x20000
PAGE_READWRITE = 0x04
PAGE_EXECUTE_READWRITE = 0x40


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


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", wt.DWORD),
        ("cntUsage", wt.DWORD),
        ("th32ProcessID", wt.DWORD),
        ("th32DefaultHeapID", wt.LPVOID),
        ("th32ModuleID", wt.DWORD),
        ("cntThreads", wt.DWORD),
        ("th32ParentProcessID", wt.DWORD),
        ("pcPriClassBase", ctypes.c_long),
        ("dwFlags", wt.DWORD),
        ("szExeFile", ctypes.c_wchar * MAX_PATH),
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
kernel32.Process32FirstW.argtypes = [wt.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
kernel32.Process32FirstW.restype = wt.BOOL
kernel32.Process32NextW.argtypes = [wt.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
kernel32.Process32NextW.restype = wt.BOOL
kernel32.VirtualAllocEx.argtypes = [
    wt.HANDLE,
    wt.LPVOID,
    ctypes.c_size_t,
    wt.DWORD,
    wt.DWORD,
]
kernel32.VirtualAllocEx.restype = wt.LPVOID
kernel32.VirtualFreeEx.argtypes = [wt.HANDLE, wt.LPVOID, ctypes.c_size_t, wt.DWORD]
kernel32.VirtualFreeEx.restype = wt.BOOL
kernel32.CreateRemoteThread.argtypes = [
    wt.HANDLE,
    wt.LPVOID,
    ctypes.c_size_t,
    wt.LPVOID,
    wt.LPVOID,
    wt.DWORD,
    ctypes.POINTER(wt.DWORD),
]
kernel32.CreateRemoteThread.restype = wt.HANDLE
kernel32.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
kernel32.WaitForSingleObject.restype = wt.DWORD
kernel32.GetExitCodeThread.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]
kernel32.GetExitCodeThread.restype = wt.BOOL


class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BaseAddress", wt.LPVOID),
        ("AllocationBase", wt.LPVOID),
        ("AllocationProtect", wt.DWORD),
        ("RegionSize", ctypes.c_size_t),
        ("State", wt.DWORD),
        ("Protect", wt.DWORD),
        ("Type", wt.DWORD),
    ]


kernel32.VirtualQueryEx.argtypes = [
    wt.HANDLE,
    wt.LPCVOID,
    ctypes.POINTER(MEMORY_BASIC_INFORMATION),
    ctypes.c_size_t,
]
kernel32.VirtualQueryEx.restype = ctypes.c_size_t


class RemoteProcess:
    def __init__(self, pid: int, write_access: bool = False):
        self.pid = pid
        access = PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
        if write_access:
            access |= (
                PROCESS_VM_WRITE
                | PROCESS_VM_OPERATION
                | PROCESS_CREATE_THREAD
            )
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

    def alloc(self, size: int) -> int:
        addr = kernel32.VirtualAllocEx(
            self.handle,
            None,
            size,
            MEM_COMMIT | MEM_RESERVE,
            PAGE_EXECUTE_READWRITE,
        )
        if not addr:
            raise ctypes.WinError(ctypes.get_last_error())
        return addr

    def read_string(self, address: int, maxlen: int = 4096) -> str:
        out = b""
        chunk = 256
        while len(out) < maxlen:
            try:
                data = self.read(address + len(out), chunk)
            except OSError:
                break
            if not data:
                break
            out += data
            if b"\x00\x00" in out:
                break
        text = out.split(b"\x00\x00", 1)[0]
        return text.decode("utf-16-le", errors="replace")

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


def find_pid_by_name(name: str) -> int:
    snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if snapshot == -1:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        entry = PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(entry)
        if not kernel32.Process32FirstW(snapshot, ctypes.byref(entry)):
            raise ctypes.WinError(ctypes.get_last_error())
        while True:
            if entry.szExeFile.lower() == name.lower():
                return entry.th32ProcessID
            if not kernel32.Process32NextW(snapshot, ctypes.byref(entry)):
                break
    finally:
        kernel32.CloseHandle(snapshot)
    raise RuntimeError("process not found: %s" % name)


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


def _ahk_hex_const(name: str) -> bytes:
    text = (ROOT / "ahk_hack_single.ahk").read_text(encoding="utf-8")
    marker = '%s := "' % name
    start = text.index(marker) + len(marker)
    end = text.index('"', start)
    return bytes.fromhex(text[start:end])


def _remote_find_utf16(secs, text: str):
    needle = text.encode("utf-16-le") + b"\x00\x00"
    hits = []
    for sec in secs:
        if sec["name"] == ".rsrc" or not sec["data"]:
            continue
        pos = sec["data"].find(needle)
        while pos >= 0 and len(hits) < 8:
            hits.append(sec["rva"] + pos)
            pos = sec["data"].find(needle, pos + 2)
    return hits


def _remote_rip_refs(text_sec, target_rva: int):
    data = text_sec["data"]
    base = text_sec["rva"]
    refs = []
    for i in range(len(data) - 7):
        if data[i] not in (0x48, 0x4C):
            continue
        if data[i + 1] != 0x8D:
            continue
        if data[i + 2] not in (0x05, 0x0D, 0x15, 0x1D, 0x25, 0x2D, 0x35, 0x3D):
            continue
        disp = struct.unpack_from("<i", data, i + 3)[0]
        if base + i + 7 + disp == target_rva:
            refs.append(base + i)
    return refs


def _remote_function_start(text_sec, ref_rva: int) -> int:
    data = text_sec["data"]
    base = text_sec["rva"]
    off = ref_rva - base
    i = off
    while i > 0:
        if data[i - 1] == 0xCC and i >= 2 and data[i - 2] == 0xCC:
            break
        i -= 1
    return base + i


def _remote_best_start(text_sec, refs):
    starts = {}
    for ref in refs:
        start = _remote_function_start(text_sec, ref)
        starts[start] = starts.get(start, 0) + 1
    if not starts:
        return 0
    return max(starts, key=starts.get)


def _remote_text_section(pe):
    text = pe.section(".text")
    if text:
        return text
    for sec in pe.sections:
        if sec["name"] != ".rsrc" and sec["data"]:
            return sec
    raise RuntimeError("remote text section not found")


def remote_locate_internal(pe):
    text = _remote_text_section(pe)
    postfix_refs = []
    for str_rva in _remote_find_utf16(pe.sections, "Missing operand."):
        postfix_refs.extend(_remote_rip_refs(text, str_rva))
    postfix = _remote_best_start(text, postfix_refs)
    expand_refs = []
    for str_rva in _remote_find_utf16(pe.sections, "Error evaluating expression."):
        expand_refs.extend(_remote_rip_refs(text, str_rva))
    expand = _remote_best_start(text, expand_refs)
    if not postfix or not expand:
        raise RuntimeError("remote expression functions not found")
    return postfix, expand


def remote_curr_line_slot(pe, getter_rva: int) -> int:
    text = _remote_text_section(pe)
    off = getter_rva - text["rva"]
    data = text["data"]
    if data[off : off + 3] != b"\x48\x8b\x05":
        raise RuntimeError("unexpected A_LineNumber getter code")
    disp = struct.unpack_from("<i", data, off + 3)[0]
    return pe.image_base + getter_rva + 7 + disp


def remote_eval_in_target(proc: RemoteProcess, pe: RemotePE, expr: str, report):
    text = _remote_text_section(pe)
    postfix_rva, expand_rva = remote_locate_internal(pe)
    biv = report["tables"].get("builtin_vars") or {}
    line_entry = next(
        (e for e in biv.get("entries", []) if e["name"] == "LineNumber"), None
    )
    if not line_entry:
        raise RuntimeError("LineNumber getter not found")
    curr_slot = remote_curr_line_slot(pe, line_entry["getter_rva"])

    stub = _ahk_hex_const("MC_REMOTE_EVAL_STUB_X64")
    locator = _ahk_hex_const("MC_INTERNAL_LOCATOR_X64")
    eval_blob = _ahk_hex_const("MC_INPROC_EVAL_X64")
    code_size = len(stub) + len(locator) + len(eval_blob)
    param_off = (code_size + 15) // 16 * 16
    loc_off = param_off + 136
    out_off = loc_off + 64
    expr_off = out_off + 512
    scratch_off = expr_off + (len(expr) + 1) * 2
    total = scratch_off + 8 * 1024 * 1024

    block = proc.alloc(total)
    try:
        proc.write(block, stub)
        proc.write(block + len(stub), locator)
        proc.write(block + len(stub) + len(locator), eval_blob)

        loc_out = block + loc_off
        out = block + out_off
        expr_ptr = block + expr_off
        scratch = block + scratch_off
        param = bytearray(136)
        struct.pack_into("<Q", param, 0, block + len(stub))
        struct.pack_into("<Q", param, 8, block + len(stub) + len(locator))
        struct.pack_into("<Q", param, 16, pe.image_base)
        struct.pack_into("<Q", param, 24, text["rva"])
        struct.pack_into("<Q", param, 32, text["size"])
        struct.pack_into("<Q", param, 40, postfix_rva)
        struct.pack_into("<Q", param, 48, expand_rva)
        struct.pack_into("<Q", param, 56, loc_out)
        struct.pack_into("<Q", param, 64, pe.image_base + postfix_rva)
        struct.pack_into("<Q", param, 72, pe.image_base + expand_rva)
        struct.pack_into("<Q", param, 80, curr_slot)
        struct.pack_into("<Q", param, 88, scratch)
        struct.pack_into("<Q", param, 96, expr_ptr)
        struct.pack_into("<Q", param, 104, out)
        struct.pack_into("<Q", param, 112, 0)
        struct.pack_into("<i", param, 120, 0)
        struct.pack_into("<i", param, 124, 0)
        proc.write(block + param_off, bytes(param))
        proc.write(expr_ptr, expr.encode("utf-16-le") + b"\x00\x00")

        thread_id = wt.DWORD(0)
        thread = kernel32.CreateRemoteThread(
            proc.handle,
            None,
            0,
            block,
            block + param_off,
            0,
            ctypes.byref(thread_id),
        )
        if not thread:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if kernel32.WaitForSingleObject(thread, 10000) != 0:
                raise RuntimeError("remote eval thread timed out")
            param_data = proc.read(block + param_off, 136)
            loc_rc = struct.unpack_from("<i", param_data, 120)[0]
            eval_rc = struct.unpack_from("<i", param_data, 124)[0]
            loc_out_data = proc.read(loc_out, 64)
            thread_code = wt.DWORD(0)
            kernel32.GetExitCodeThread(thread, ctypes.byref(thread_code))
            report["eval_debug"] = {
                "loc_rc": loc_rc,
                "eval_rc": eval_rc,
                "thread_code": thread_code.value,
                "loc_out_head": loc_out_data[:40].hex(),
                "param_head": param_data[:80].hex(),
            }
            if loc_rc:
                raise RuntimeError("remote internal locator rc=%d" % loc_rc)
            if eval_rc:
                raise RuntimeError("remote eval rc=%d" % eval_rc)
            out_data = proc.read(out, 512)
            status = struct.unpack_from("<I", out_data, 0)[0]
            result_type = struct.unpack_from("<I", out_data, 4)[0]
            if status:
                raise RuntimeError("remote eval status=%d" % status)
            if result_type == 1:
                return struct.unpack_from("<q", out_data, 8)[0]
            if result_type == 2:
                return struct.unpack_from("<d", out_data, 8)[0]
            if result_type == 0:
                ptr = struct.unpack_from("<Q", out_data, 16)[0]
                text = proc.read_string(ptr) if ptr else ""
                report["eval_debug"].update({
                    "status": status,
                    "type": result_type,
                    "ptr": ptr,
                    "text_len": len(text),
                    "out_head": out_data[:32].hex(),
                })
                return text
            raise RuntimeError("unknown remote result type %d" % result_type)
        finally:
            kernel32.CloseHandle(thread)
    finally:
        kernel32.VirtualFreeEx(proc.handle, block, 0, MEM_RELEASE)


def remote_deep_redirect(proc: RemoteProcess, pe: RemotePE, report, src: str, dst: str):
    table = report["tables"].get("builtins") or {}
    if not table.get("found"):
        raise RuntimeError("builtins table not found")
    entries = table.get("entries", [])
    by_name = {e["name"]: e for e in entries}
    if src not in by_name or dst not in by_name:
        raise RuntimeError("deep redirect names not found")
    names = [e["name"] for e in entries]
    idx = names.index(src)
    slot = pe.image_base + table["table_rva"] + idx * table["stride"]
    name_ptr = struct.unpack_from("<Q", proc.read(slot, 8))[0]
    old_fn = struct.unpack_from("<Q", proc.read(slot + 8, 8))[0]
    new_fn = pe.image_base + by_name[dst]["bif_rva"]

    patches = []
    addr = 0
    mbi = MEMORY_BASIC_INFORMATION()
    old_bytes = struct.pack("<Q", old_fn)
    name_bytes = struct.pack("<Q", name_ptr)
    while True:
        size = kernel32.VirtualQueryEx(
            proc.handle,
            ctypes.c_void_p(addr),
            ctypes.byref(mbi),
            ctypes.sizeof(mbi),
        )
        if not size:
            break
        if (
            mbi.State == MEM_COMMIT
            and mbi.Type == MEM_PRIVATE
            and (mbi.Protect & (PAGE_READWRITE | PAGE_EXECUTE_READWRITE))
        ):
            region = mbi.RegionSize
            read_addr = mbi.BaseAddress or 0
            chunk = 0x10000
            off = 0
            while off < region:
                want = min(chunk, region - off)
                try:
                    data = proc.read(read_addr + off, want)
                except OSError:
                    off += want
                    continue
                pos = data.find(old_bytes)
                while pos >= 0:
                    start = max(0, pos - 0x200)
                    end = min(len(data), pos + 0x200)
                    if name_bytes in data[start:end]:
                        patches.append(read_addr + off + pos)
                    pos = data.find(old_bytes, pos + 1)
                off += want
        region = mbi.RegionSize or 0x1000
        next_addr = addr + region
        if next_addr <= addr:
            break
        addr = next_addr

    if not patches:
        raise RuntimeError("no Func object found for %s" % src)
    for p in patches:
        proc.write(p, struct.pack("<Q", new_fn))
    return patches


def attach(pid: int, redirect=None, eval_expr=None, deep_redirect=None):
    proc = RemoteProcess(
        pid,
        write_access=redirect is not None
        or eval_expr is not None
        or deep_redirect is not None,
    )
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
        if deep_redirect:
            src, dst = deep_redirect
            patches = remote_deep_redirect(proc, pe, report, src, dst)
            report["deep_redirect"] = {
                "src": src,
                "dst": dst,
                "patched": ["0x%X" % p for p in patches],
            }
        if eval_expr is not None:
            report["eval_result"] = remote_eval_in_target(
                proc, pe, eval_expr, report
            )
        return report
    finally:
        proc.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, help="target process id")
    parser.add_argument(
        "--name",
        help="attach to a process by image name (for example AutoHotkey64.exe)",
    )
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
    parser.add_argument(
        "--deep-redirect",
        nargs=2,
        metavar=("SRC", "DST"),
        help="also patch already-resolved Func objects (e.g. Abs Sin)",
    )
    parser.add_argument(
        "--eval",
        help="evaluate an expression inside the running process",
    )
    args = parser.parse_args(argv)

    if args.pid is not None:
        pid = args.pid
    elif args.name:
        pid = find_pid_by_name(args.name)
    else:
        parser.error("one of --pid or --name is required")
    report = attach(
        pid,
        redirect=args.redirect,
        eval_expr=args.eval,
        deep_redirect=args.deep_redirect,
    )
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
    if "eval_result" in report:
        print("eval: %s" % report["eval_result"])
    if report.get("deep_redirect"):
        d = report["deep_redirect"]
        print(
            "deep redirected %s -> %s at %d object(s)"
            % (d["src"], d["dst"], len(d["patched"]))
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
