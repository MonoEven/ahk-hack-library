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


def _remote_find_callers(text_sec, target_rva: int):
    data = text_sec["data"]
    base = text_sec["rva"]
    calls = []
    for i in range(len(data) - 5):
        if data[i] != 0xE8:
            continue
        disp = struct.unpack_from("<i", data, i + 1)[0]
        if base + i + 5 + disp == target_rva:
            calls.append(base + i)
    return calls


def _remote_find_byte_pattern(text_sec, hex_pattern: str, start_rva: int = 0):
    needle = bytes.fromhex(hex_pattern)
    data = text_sec["data"]
    off = text_sec["rva"] + start_rva - text_sec["rva"]
    pos = data.find(needle, off)
    return text_sec["rva"] + pos if pos >= 0 else 0


def _remote_find_byte_pattern_in_func(text_sec, start_rva: int, hex_pattern: str):
    data = text_sec["data"]
    off = start_rva - text_sec["rva"]
    limit = min(len(data) - 4, off + 0x4000)
    needle = bytes.fromhex(hex_pattern)
    i = off
    while i < limit:
        if data[i] == 0xCC and data[i + 1] == 0xCC:
            break
        if data.startswith(needle, i):
            return True
        i += 1
    return False


def _remote_locate_preprocess(sec):
    data = sec["data"]
    for i in range(len(data) - 8):
        if data[i] != 0x41 or data[i + 1] != 0x0F or data[i + 2] != 0xB6:
            continue
        if data[i + 3] not in (0x76, 0x7E) or data[i + 4] != 0x23:
            continue
        limit = min(len(data) - 4, i + 0x300)
        for j in range(i + 5, limit):
            if (
                data[j] == 0x80
                and data[j + 1] == 0x78
                and data[j + 2] == 0x23
                and data[j + 3] == 0x02
            ):
                return _remote_function_start(sec, sec["rva"] + i)
    return 0


def _remote_locate_gptr(sec, preparse_rva: int):
    data = sec["data"]
    for caller in _remote_find_callers(sec, preparse_rva):
        start = _remote_function_start(sec, caller)
        off = start - sec["rva"]
        limit = min(len(data) - 16, off + 0x4000)
        i = off
        while i < limit:
            if data[i] == 0xCC and data[i + 1] == 0xCC:
                break
            if data[i] == 0x48 and data[i + 1] == 0x8B and data[i + 2] == 0x05:
                for j in range(i + 7, min(i + 24, limit)):
                    if (
                        data[j] == 0x48
                        and data[j + 1] == 0x89
                        and data[j + 2] == 0x58
                        and data[j + 3] == 0x28
                    ) or (
                        data[j] == 0x48
                        and data[j + 1] == 0x89
                        and data[j + 2] == 0x50
                        and data[j + 3] == 0x28
                    ):
                        disp = struct.unpack_from("<i", data, i + 3)[0]
                        return sec["rva"] + i + 7 + disp
            i += 1
    return 0


def _remote_has_bytes_near(sec, rva: int, hex_pattern: str, range_size: int = 40):
    found = _remote_find_byte_pattern(sec, hex_pattern, rva - sec["rva"])
    return bool(found) and found - rva < range_size


def _remote_locate_load_ts(sec, open_rva: int):
    data = sec["data"]
    base = sec["rva"]
    for caller in _remote_find_callers(sec, open_rva):
        off = caller - base + 5
        limit = min(len(data) - 5, off + 0x300)
        i = off
        while i < limit:
            is_cmp = (
                data[i] == 0x83
                and data[i + 1] == 0xF8
                and data[i + 2] == 0x03
            )
            is_cmp2 = data[i] == 0x3D and data[i + 1] == 0x03
            if is_cmp or is_cmp2:
                j = i + 3
                call_limit = min(len(data) - 5, j + 0x200)
                while j < call_limit:
                    if data[j] == 0xE8:
                        disp = struct.unpack_from("<i", data, j + 1)[0]
                        target = base + j + 5 + disp
                        if _remote_has_bytes_near(
                            sec, target, "555356574154415541564157", 40
                        ):
                            return target
                    j += 1
                break
            i += 1
    return 0


def _remote_locate_curr_off(sec, preparse_rva: int):
    data = sec["data"]
    for caller in _remote_find_callers(sec, preparse_rva):
        start = _remote_function_start(sec, caller)
        off = start - sec["rva"]
        limit = min(len(data) - 16, off + 0x4000)
        i = off
        while i < limit:
            if data[i] == 0xCC and data[i + 1] == 0xCC:
                break
            if data[i] == 0x48 and data[i + 1] == 0x8B and data[i + 2] == 0x05:
                for j in range(i + 7, min(i + 24, limit)):
                    if (
                        data[j] == 0x48
                        and (
                            data[j + 1] == 0x89
                            and data[j + 2] in (0x58, 0x50)
                        )
                    ):
                        return data[j + 3]
            i += 1
    return 0


def _remote_discover_parser_offsets(sec, load_ts_rva: int):
    data = sec["data"]
    base = sec["rva"]
    off = load_ts_rva - base
    limit = min(len(data) - 8, off + 0x100)
    q_cmp = -1
    d_cmp = -1
    i = off
    while i < limit:
        if data[i] == 0x48 and data[i + 1] == 0x83:
            modrm = data[i + 2]
            if modrm == 0x79 and data[i + 4] == 0 and q_cmp < 0:
                q_cmp = data[i + 3]
            elif modrm == 0xB9 and data[i + 7] == 0 and q_cmp < 0:
                q_cmp = struct.unpack_from("<i", data, i + 3)[0]
        if (
            data[i] == 0x83
            and data[i + 1] == 0xB9
            and (i == off or data[i - 1] != 0x48)
            and data[i + 6] == 0
            and d_cmp < 0
        ):
            d_cmp = struct.unpack_from("<i", data, i + 2)[0]
        if q_cmp >= 0 and d_cmp >= 0:
            break
        i += 1
    if q_cmp < 0 or d_cmp < 0:
        raise RuntimeError("parser state anchors not found")
    if d_cmp > 0x100:
        return {
            "mclass_count": d_cmp,
            "mline_parent": d_cmp - 0x30,
            "mpending_related": d_cmp - 0x28,
            "mlast_param_init": d_cmp - 0x20,
            "mpending_hotkey": d_cmp - 0x18,
            "mexpr_func": d_cmp - 0x10,
            "mexpr_func_index": d_cmp - 8,
            "mnext_func_body": d_cmp - 4,
            "mignore_block": d_cmp - 3,
            "mbackcompat": d_cmp - 2,
            "mcurrent_module": d_cmp - 0x50,
            "mlast_module": d_cmp - 0x48,
        }
    return {
        "mopen": q_cmp,
        "mpending_parent": q_cmp + 8,
        "mpending_related": q_cmp + 16,
        "mlast_param_init": q_cmp + 24,
        "mnext_func_body": q_cmp + 32,
        "mclass_count": d_cmp,
    }


def remote_locate_eval_script(pe):
    text = _remote_text_section(pe)
    postfix_rva, expand_rva = remote_locate_internal(pe)
    preparse = 0
    for caller in _remote_find_callers(text, postfix_rva):
        start = _remote_function_start(text, caller)
        if _remote_find_byte_pattern_in_func(text, start, "803B03") and _remote_find_byte_pattern_in_func(
            text, start, "803B04"
        ):
            preparse = start
            break
    if not preparse:
        raise RuntimeError("PreparseExpressions not found")
    preprocess = _remote_locate_preprocess(text)
    if not preprocess:
        raise RuntimeError("PreprocessLocalVars not found")
    open_needle = "48895C240848895424105556574154415541564157488DAC243000FEFFB8D0000200"
    open_needle21 = "40535556574154415541564157B8D8000100"
    open_rva = _remote_find_byte_pattern(text, open_needle)
    if not open_rva:
        open_rva = _remote_find_byte_pattern(text, open_needle21)
    if not open_rva:
        raise RuntimeError("OpenIncludedFile not found")
    load_ts = _remote_locate_load_ts(text, open_rva)
    if not load_ts:
        raise RuntimeError("LoadIncludedFile(TextStream) not found")
    gptr = _remote_locate_gptr(text, preparse)
    if not gptr:
        raise RuntimeError("g pointer not found")
    curr_off = _remote_locate_curr_off(text, preparse)
    if not curr_off:
        raise RuntimeError("g->curr offset not found")
    parser = _remote_discover_parser_offsets(text, load_ts)
    return {
        "postfix_rva": postfix_rva,
        "expand_rva": expand_rva,
        "preparse_rva": preparse,
        "preprocess_rva": preprocess,
        "open_rva": open_rva,
        "load_ts_rva": load_ts,
        "src_count_rva": 0,
        "gptr_rva": gptr,
        "curr_off": curr_off,
        "parser": parser,
    }


def remote_call(proc: RemoteProcess, fn_addr: int, args):
    stub = _ahk_hex_const("MC_REMOTE_CALL_STUB_X64")
    param = bytearray(72)
    struct.pack_into("<Q", param, 0, fn_addr)
    for i, a in enumerate(args[:6]):
        struct.pack_into("<Q", param, 8 + 8 * i, a)
    block = proc.alloc(len(stub) + 72)
    try:
        proc.write(block, stub)
        proc.write(block + len(stub), bytes(param))
        thread_id = wt.DWORD(0)
        thread = kernel32.CreateRemoteThread(
            proc.handle,
            None,
            0,
            block,
            block + len(stub),
            0,
            ctypes.byref(thread_id),
        )
        if not thread:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if kernel32.WaitForSingleObject(thread, 10000) != 0:
                raise RuntimeError("remote call timed out")
            data = proc.read(block + len(stub), 72)
            return struct.unpack_from("<i", data, 56)[0]
        finally:
            kernel32.CloseHandle(thread)
    finally:
        kernel32.VirtualFreeEx(proc.handle, block, 0, MEM_RELEASE)


def remote_internal_locator(proc: RemoteProcess, pe: RemotePE, postfix_rva: int, expand_rva: int):
    text = _remote_text_section(pe)
    locator = _ahk_hex_const("MC_INTERNAL_LOCATOR_X64")
    block = proc.alloc(len(locator) + 64)
    try:
        proc.write(block, locator)
        loc_out = block + len(locator)
        rc = remote_call(
            proc,
            block,
            [
                pe.image_base,
                text["rva"],
                text["size"],
                postfix_rva,
                expand_rva,
                loc_out,
            ],
        )
        if rc != 0:
            raise RuntimeError("remote internal locator rc=%d" % rc)
        return proc.read(loc_out, 64)
    finally:
        kernel32.VirtualFreeEx(proc.handle, block, 0, MEM_RELEASE)


def remote_load_script(proc: RemoteProcess, pe: RemotePE, loc, text: str):
    mem_script = _ahk_hex_const("MC_MEM_SCRIPT_X64")
    text_bytes = text.encode("utf-16-le") + b"\x00\x00"
    scratch_size = 0x400
    block = proc.alloc(len(mem_script) + len(text_bytes) + scratch_size)
    try:
        proc.write(block, mem_script)
        text_addr = block + len(mem_script)
        scratch_addr = text_addr + len(text_bytes)
        proc.write(text_addr, text_bytes)
        gscript = struct.unpack_from("<Q", loc["loc_out"], 0)[0]
        load_ts = pe.image_base + loc["load_ts_rva"]
        src_count = pe.image_base + loc["src_count_rva"] if loc.get("src_count_rva") else 0
        rc = remote_call(
            proc,
            block,
            [
                load_ts,
                gscript,
                src_count,
                text_addr,
                len(text_bytes) - 2,
                scratch_addr,
            ],
        )
        return rc
    finally:
        kernel32.VirtualFreeEx(proc.handle, block, 0, MEM_RELEASE)


def remote_discover_layout(proc: RemoteProcess, pe: RemotePE, loc):
    text = _remote_text_section(pe)
    loc_out = remote_internal_locator(
        proc, pe, loc["postfix_rva"], loc["expand_rva"]
    )
    loc = dict(loc)
    loc["loc_out"] = loc_out
    gscript = struct.unpack_from("<Q", loc_out, 0)[0]
    g_addr = pe.image_base + loc["gptr_rva"]
    g = struct.unpack_from("<Q", proc.read(g_addr, 8))[0]
    curr_off = loc["curr_off"]

    snap = proc.read(gscript, 0x200)
    gsnap = proc.read(g, 0x100)
    saved_cur = struct.unpack_from("<Q", proc.read(g + curr_off, 8))[0]
    proc.write(g + curr_off, struct.pack("<Q", 0))
    parser = loc["parser"]
    for key in [
        "mopen",
        "mpending_parent",
        "mline_parent",
        "mpending_related",
        "mlast_param_init",
        "mpending_hotkey",
        "mexpr_func",
    ]:
        if key in parser:
            proc.write(gscript + parser[key], struct.pack("<Q", 0))
    if "mexpr_func_index" in parser:
        proc.write(gscript + parser["mexpr_func_index"], struct.pack("<i", 0x7FFFFFFF))
    if "mnext_func_body" in parser:
        proc.write(gscript + parser["mnext_func_body"], b"\x00")
    if "mignore_block" in parser:
        proc.write(gscript + parser["mignore_block"], b"\x00")
    if "mbackcompat" in parser:
        proc.write(gscript + parser["mbackcompat"], b"\x01")
    if "mclass_count" in parser:
        proc.write(gscript + parser["mclass_count"], struct.pack("<i", 0))

    probe = "ahkHackLayoutProbe() {\n    return 1\n}"
    rc = remote_load_script(proc, pe, loc, probe)
    if rc != 0:
        raise RuntimeError("layout probe load rc=%d" % rc)
    after = proc.read(gscript, 0x200)

    count_off = 0
    for i in range(0x200 // 4):
        off = i * 4
        before = struct.unpack_from("<i", snap, off)[0]
        after_val = struct.unpack_from("<i", after, off)[0]
        if after_val == before + 1 and before >= 0 and after_val < 100000:
            count_off = off
            break
    if not count_off:
        raise RuntimeError("mFuncsCount offset not found")
    old_count = struct.unpack_from("<i", snap, count_off)[0]

    last_off = -1
    for i in range(0x200 // 8):
        off = i * 8
        before = struct.unpack_from("<Q", snap, off)[0]
        after_val = struct.unpack_from("<Q", after, off)[0]
        if before != after_val and after_val > 0x10000:
            last_off = off
            break
    if last_off < 0:
        raise RuntimeError("mLastLine offset not found")

    old_last = struct.unpack_from("<Q", snap, last_off)[0]
    new_last = struct.unpack_from("<Q", after, last_off)[0]
    line_set = set()
    line = struct.unpack_from("<Q", proc.read(old_last, 8))[0] if old_last else 0
    line = struct.unpack_from("<Q", proc.read(old_last + 32, 8))[0] if old_last else 0
    for _ in range(10000):
        if not line:
            break
        line_set.add(line)
        if line == new_last:
            break
        line = struct.unpack_from("<Q", proc.read(line + 32, 8))[0]

    funcs_off = 0
    jump_off = 0
    for i in range(0x200 // 8):
        off = i * 8
        p = struct.unpack_from("<Q", after, off)[0]
        if p <= 0x10000 or p >= 0x7FFFFFFFFFFFFFFF:
            continue
        try:
            new_func = struct.unpack_from(
                "<Q", proc.read(p + old_count * 8, 8)
            )[0]
        except OSError:
            continue
        if new_func <= 0x10000 or new_func >= 0x7FFFFFFFFFFFFFFF:
            continue
        for joff in range(0x100 // 8):
            try:
                q = struct.unpack_from(
                    "<Q", proc.read(new_func + joff * 8, 8)
                )[0]
            except OSError:
                continue
            if q > 0x10000 and q in line_set:
                funcs_off = off
                jump_off = joff * 8
                break
        if funcs_off:
            break
    if not funcs_off or not jump_off:
        raise RuntimeError("mFuncs/mJumpLine offset not found")

    proc.write(gscript, snap)
    proc.write(g, gsnap)
    proc.write(g + curr_off, struct.pack("<Q", saved_cur))

    return {
        "gscript": gscript,
        "g": g,
        "curr_off": curr_off,
        "mfuncs_off": funcs_off,
        "mfuncs_count_off": count_off,
        "mlast_line_off": last_off,
        "mjump_line_off": jump_off,
        "parser": loc["parser"],
    }


def remote_eval_script(proc: RemoteProcess, pe: RemotePE, report, text: str, layout=None):
    loc = remote_locate_eval_script(pe)
    if layout is None:
        layout = remote_discover_layout(proc, pe, loc)
    loc_out = remote_internal_locator(
        proc, pe, loc["postfix_rva"], loc["expand_rva"]
    )
    loc["loc_out"] = loc_out
    gscript = layout["gscript"]
    g = layout["g"]
    curr_off = layout["curr_off"]
    parser = layout["parser"]
    old_last = struct.unpack_from(
        "<Q", proc.read(gscript + layout["mlast_line_off"], 8)
    )[0]
    old_func_count = struct.unpack_from(
        "<i", proc.read(gscript + layout["mfuncs_count_off"], 4)
    )[0]
    saved_cur = struct.unpack_from("<Q", proc.read(g + curr_off, 8))[0]

    ptr_keys = [
        "mopen",
        "mpending_parent",
        "mline_parent",
        "mpending_related",
        "mlast_param_init",
        "mpending_hotkey",
        "mexpr_func",
        "mcurrent_module",
    ]
    int_keys = ["mexpr_func_index", "mclass_count"]
    char_keys = ["mnext_func_body", "mignore_block", "mbackcompat"]
    saved = []
    for key in ptr_keys:
        if key in parser:
            saved.append((key, "<Q", proc.read(gscript + parser[key], 8)))
    for key in int_keys:
        if key in parser:
            saved.append((key, "<i", proc.read(gscript + parser[key], 4)))
    for key in char_keys:
        if key in parser:
            saved.append((key, "B", proc.read(gscript + parser[key], 1)))

    try:
        for key, fmt, _ in saved:
            if key in ptr_keys:
                proc.write(gscript + parser[key], struct.pack("<Q", 0))
        if "mexpr_func_index" in parser:
            proc.write(gscript + parser["mexpr_func_index"], struct.pack("<i", 0x7FFFFFFF))
        if "mnext_func_body" in parser:
            proc.write(gscript + parser["mnext_func_body"], b"\x00")
        if "mignore_block" in parser:
            proc.write(gscript + parser["mignore_block"], b"\x00")
        if "mbackcompat" in parser:
            proc.write(gscript + parser["mbackcompat"], b"\x01")
        if "mclass_count" in parser:
            proc.write(gscript + parser["mclass_count"], struct.pack("<i", 0))
        proc.write(g + curr_off, struct.pack("<Q", 0))

        rc = remote_load_script(proc, pe, loc, text)
        if rc != 0:
            raise RuntimeError("LoadIncludedFile(memory) rc=%d" % rc)

        funcs_item = struct.unpack_from(
            "<Q", proc.read(gscript + layout["mfuncs_off"], 8)
        )[0]
        func_count = struct.unpack_from(
            "<i", proc.read(gscript + layout["mfuncs_count_off"], 4)
        )[0]
        if func_count > old_func_count:
            first_new = (
                struct.unpack_from("<Q", proc.read(old_last + 32, 8))[0]
                if old_last
                else 0
            )
            if first_new:
                rc = remote_call(
                    proc,
                    pe.image_base + loc["preparse_rva"],
                    [gscript, first_new],
                )
                if rc != 1:
                    raise RuntimeError("PreparseExpressions(tail) rc=%d" % rc)
            for idx in range(old_func_count, func_count):
                new_func = struct.unpack_from(
                    "<Q", proc.read(funcs_item + idx * 8, 8)
                )[0]
                jump = struct.unpack_from(
                    "<Q", proc.read(new_func + layout["mjump_line_off"], 8)
                )[0]
                if not jump:
                    continue
                rc = remote_call(
                    proc,
                    pe.image_base + loc["preparse_rva"],
                    [gscript, jump],
                )
                if rc != 1:
                    raise RuntimeError("PreparseExpressions rc=%d" % rc)
                proc.write(g + curr_off, struct.pack("<Q", new_func))
                line = jump
                while line:
                    line_data = proc.read(line, 40)
                    action = line_data[0]
                    attr = struct.unpack_from("<Q", line_data, 16)[0]
                    if action == 3 and attr:
                        proc.write(g + curr_off, struct.pack("<Q", attr))
                    argc = line_data[1]
                    if argc:
                        arg = struct.unpack_from("<Q", line_data, 8)[0]
                        if arg:
                            arg_flags = proc.read(arg + 1, 1)[0]
                            if arg_flags:
                                postfix = struct.unpack_from(
                                    "<Q", proc.read(arg + 24, 8)
                                )[0]
                                if postfix:
                                    while True:
                                        token = proc.read(postfix, 24)
                                        symbol = struct.unpack_from(
                                            "<I", token, 16
                                        )[0]
                                        if symbol == struct.unpack_from(
                                            "<I", loc_out, 32
                                        )[0]:
                                            break
                                        usage = struct.unpack_from(
                                            "<I", token, 8
                                        )[0]
                                        if symbol == 4 and usage < 3:
                                            deref = struct.unpack_from(
                                                "<Q", token, 0
                                            )[0]
                                            if deref:
                                                deref_data = proc.read(deref, 24)
                                                deref_type = deref_data[16]
                                                marker = struct.unpack_from(
                                                    "<Q", deref_data, 0
                                                )[0]
                                                deref_len = struct.unpack_from(
                                                    "<I", deref_data, 20
                                                )[0]
                                                if deref_type == 7:
                                                    value = struct.unpack_from(
                                                        "<Q",
                                                        proc.read(deref + 8, 8),
                                                    )[0]
                                                    proc.write(
                                                        postfix,
                                                        struct.pack("<Q", value),
                                                    )
                                                elif (
                                                    deref_type == 0
                                                    and marker
                                                    and 0 < deref_len <= 64
                                                ):
                                                    var = remote_call(
                                                        proc,
                                                        struct.unpack_from(
                                                            "<Q", loc_out, 16
                                                        )[0],
                                                        [
                                                            gscript,
                                                            marker,
                                                            deref_len,
                                                            0x103,
                                                        ],
                                                    )
                                                    if var:
                                                        proc.write(
                                                            postfix,
                                                            struct.pack("<Q", var),
                                                        )
                                        postfix += 24
                    line = struct.unpack_from("<Q", proc.read(line + 32, 8))[0]
                proc.write(g + curr_off, struct.pack("<Q", saved_cur))
                rc = remote_call(
                    proc,
                    pe.image_base + loc["preprocess_rva"],
                    [gscript, new_func],
                )
                if rc != 1:
                    raise RuntimeError("PreprocessLocalVars rc=%d" % rc)

        proc.write(g + curr_off, struct.pack("<Q", 0))
        last = ""
        for raw in text.splitlines():
            t = raw.strip()
            if not t:
                continue
            if t.startswith(
                (
                    "if ",
                    "else",
                    "for ",
                    "while ",
                    "loop",
                    "try",
                    "catch",
                    "finally",
                    "return",
                    "break",
                    "continue",
                    "class ",
                    "static",
                    "global",
                    "local",
                    "throw",
                )
            ):
                continue
            if t.endswith("{"):
                continue
            last = t
        if not last:
            raise RuntimeError("no expression result found in script text")
        return remote_eval_in_target(proc, pe, last, report)
    finally:
        for key, fmt, data in saved:
            proc.write(gscript + parser[key], data)
        proc.write(g + curr_off, struct.pack("<Q", saved_cur))


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


def attach(
    pid: int,
    redirect=None,
    eval_expr=None,
    deep_redirect=None,
    eval_script=None,
):
    proc = RemoteProcess(
        pid,
        write_access=(
            redirect is not None
            or eval_expr is not None
            or deep_redirect is not None
            or eval_script is not None
        ),
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
        if eval_script is not None:
            report["eval_script_result"] = remote_eval_script(
                proc, pe, report, eval_script
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
    parser.add_argument(
        "--eval-script",
        help="load and evaluate a multi-line script inside the target",
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
        eval_script=args.eval_script,
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
    if "eval_script_result" in report:
        print("eval script: %s" % report["eval_script_result"])
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
