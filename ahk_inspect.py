#!/usr/bin/env python3
"""Structural analyzer for AutoHotkey executables.

Given any AutoHotkey.exe (v2 family), this tool locates the three main
interpreter tables by scanning the PE data sections:

  * g_BIF       - built-in script functions (name + C function + params)
  * sMdFunc     - typed native functions such as MsgBox, WinActivate, etc.
  * g_BIV_A     - built-in variables beginning with "A_"

The output is a JSON report containing image-relative RVAs for every entry,
which can be consumed by runtime tools (see ahk_magic.ahk) to resolve
addresses inside a live AutoHotkey process.

Dependencies:
    pefile (pip install pefile)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

import pefile


# Seed names from the AutoHotkey v2.0.26 source.  They are used only to rank
# candidate tables; the final report is read directly from the binary.
BIF_SEED = [
    "Abs", "ACos", "ASin", "ATan", "CaretGetPos", "Ceil", "Chr", "Click",
    "ComCall", "ComObjActive", "ComObjConnect", "ComObjFlags",
    "ComObjFromPtr", "ComObjGet", "ComObjQuery", "ComObjType",
    "ComObjValue", "Cos", "DllCall", "Exp", "FileOpen", "Floor", "Format",
    "FormatTime", "GetMethod", "HasBase", "HasMethod", "HasProp", "InStr",
    "IsAlnum", "IsAlpha", "IsDigit", "IsFloat", "IsInteger", "IsLower",
    "IsNumber", "IsObject", "IsSetRef", "IsSpace", "IsTime", "IsUpper",
    "IsXDigit", "Ln", "Log", "LTrim", "Max", "Min", "Mod", "NumGet",
    "NumPut", "ObjAddRef", "ObjBindMethod", "ObjFromPtr", "ObjFromPtrAddRef",
    "ObjGetBase", "ObjGetCapacity", "ObjHasOwnProp", "ObjOwnPropCount",
    "ObjOwnProps", "ObjPtr", "ObjPtrAddRef", "ObjRelease", "ObjSetBase",
    "ObjSetCapacity", "Ord", "Random", "RegCreateKey", "RegDelete",
    "RegDeleteKey", "RegExMatch", "RegExReplace", "RegRead", "RegWrite",
    "Round", "RTrim", "RunWait", "Sin", "Sort", "SoundGetInterface",
    "SoundGetMute", "SoundGetName", "SoundGetVolume", "SoundSetMute",
    "SoundSetVolume", "SplitPath", "Sqrt", "StrCompare", "StrGet", "StrLen",
    "StrLower", "StrPtr", "StrPut", "StrReplace", "StrTitle", "StrUpper",
    "SubStr", "Tan", "Trim", "Type", "VarSetStrCapacity", "VerCompare",
    "WinActive", "WinExist",
    # Present in newer 2.1 alpha builds.
    "ATan2", "DefineProp", "Props", "Throw",
]

MDFUNC_SEED = [
    "BlockInput", "CallbackCreate", "CallbackFree", "ClipWait",
    "ControlAddItem", "ControlChooseIndex", "ControlChooseString",
    "ControlClick", "ControlDeleteItem", "ControlFindItem", "ControlFocus",
    "ControlGetChecked", "ControlGetChoice", "ControlGetClassNN",
    "ControlGetEnabled", "ControlGetExStyle", "ControlGetFocus",
    "ControlGetHwnd", "ControlGetIndex", "ControlGetItems", "ControlGetPos",
    "ControlGetStyle", "ControlGetText", "ControlGetVisible", "ControlHide",
    "ControlHideDropDown", "ControlMove", "ControlSend", "ControlSendText",
    "ControlSetChecked", "ControlSetEnabled", "ControlSetExStyle",
    "ControlSetStyle", "ControlSetText", "ControlShow", "ControlShowDropDown",
    "CoordMode", "Critical", "DateAdd", "DateDiff", "DetectHiddenText",
    "DetectHiddenWindows", "DirCopy", "DirCreate", "DirDelete", "DirMove",
    "DirSelect", "Download", "DriveEject", "DriveGetCapacity",
    "DriveGetFilesystem", "DriveGetLabel", "DriveGetList", "DriveGetSerial",
    "DriveGetSpaceFree", "DriveGetStatus", "DriveGetStatusCD", "DriveGetType",
    "DriveLock", "DriveRetract", "DriveSetLabel", "DriveUnlock",
    "EditGetCurrentCol", "EditGetCurrentLine", "EditGetLine",
    "EditGetLineCount", "EditGetSelectedText", "EditPaste", "EnvGet",
    "EnvSet", "FileAppend", "FileCopy", "FileCreateShortcut", "FileDelete",
    "FileEncoding", "FileGetAttrib", "FileGetShortcut", "FileGetSize",
    "FileGetTime", "FileGetVersion", "FileInstall", "FileMove", "FileRead",
    "FileRecycle", "FileRecycleEmpty", "FileSelect", "FileSetAttrib",
    "FileSetTime", "GetKeyState", "GroupActivate", "GroupAdd", "GroupClose",
    "GroupDeactivate", "HotIf", "HotIfWinActive", "HotIfWinExist",
    "HotIfWinNotActive", "HotIfWinNotExist", "IL_Add", "ImageSearch",
    "IniDelete", "IniRead", "IniWrite", "InputBox", "KeyHistory",
    "KeyWait", "ListViewGetContent", "LoadPicture", "MenuSelect",
    "MonitorGet", "MonitorGetName", "MonitorGetWorkArea", "MouseClick",
    "MouseClickDrag", "MouseGetPos", "MouseMove", "MsgBox",
    "OnClipboardChange", "OnError", "OnExit", "OnMessage", "Pause",
    "PixelGetColor", "PixelSearch", "ProcessClose", "ProcessGetName",
    "ProcessGetPath", "ProcessSetPriority", "ProcessWait", "ProcessWaitClose",
    "Reload", "Run", "SendLevel", "SendMode", "SetCapsLockState",
    "SetControlDelay", "SetDefaultMouseSpeed", "SetKeyDelay",
    "SetMouseDelay", "SetNumLockState", "SetRegView", "SetScrollLockState",
    "SetTimer", "SetTitleMatchMode", "SetWinDelay", "SetWorkingDir",
    "Shutdown", "SoundPlay", "StatusBarGetText", "StatusBarWait", "StrSplit",
    "Suspend", "SysGetIPAddresses", "Thread", "ToolTip", "TraySetIcon",
    "TrayTip", "WinActivate", "WinActivateBottom", "WinClose",
    "WinGetClass", "WinGetClientPos", "WinGetControls", "WinGetControlsHwnd",
    "WinGetCount", "WinGetExStyle", "WinGetID", "WinGetIDLast", "WinGetList",
    "WinGetMinMax", "WinGetPID", "WinGetPos", "WinGetProcessName",
    "WinGetProcessPath", "WinGetStyle", "WinGetText", "WinGetTitle",
    "WinGetTransColor", "WinGetTransparent", "WinHide", "WinKill",
    "WinMaximize", "WinMinimize", "WinMove", "WinMoveBottom", "WinMoveTop",
    "WinRedraw", "WinRestore", "WinSetAlwaysOnTop", "WinSetEnabled",
    "WinSetExStyle", "WinSetRegion", "WinSetStyle", "WinSetTitle",
    "WinSetTransColor", "WinSetTransparent", "WinShow", "WinWait",
    "WinWaitActive", "WinWaitClose", "WinWaitNotActive",
]

BIV_SEED = [
    "AhkPath", "AhkVersion", "AllowMainWindow", "AppData", "AppDataCommon",
    "Clipboard", "ComputerName", "ComSpec", "ControlDelay", "CoordModeCaret",
    "CoordModeMenu", "CoordModeMouse", "CoordModePixel", "CoordModeToolTip",
    "Cursor", "DD", "DDD", "DDDD", "DefaultMouseSpeed", "Desktop",
    "DesktopCommon", "DetectHiddenText", "DetectHiddenWindows", "EndChar",
    "EventInfo", "FileEncoding", "HotkeyInterval", "HotkeyModifierTimeout",
    "Hour", "IconFile", "IconHidden", "IconNumber", "IconTip", "Index",
    "InitialWorkingDir", "Is64bitOS", "IsAdmin", "IsCompiled", "IsCritical",
    "IsPaused", "IsSuspended", "KeyDelay", "KeyDelayPlay", "KeyDuration",
    "KeyDurationPlay", "Language", "LastError", "LineFile", "LineNumber",
    "ListLines", "LoopField", "LoopFileAttrib", "LoopFileDir", "LoopFileExt",
    "LoopFileFullPath", "LoopFileName", "LoopFilePath", "LoopFileShortName",
    "LoopFileShortPath", "LoopFileSize", "LoopFileSizeKB", "LoopFileSizeMB",
    "LoopFileTimeAccessed", "LoopFileTimeCreated", "LoopFileTimeModified",
    "LoopReadLine", "LoopRegKey", "LoopRegName", "LoopRegTimeModified",
    "LoopRegType", "MaxHotkeysPerInterval", "MDay", "MenuMaskKey", "Min",
    "MM", "MMM", "MMMM", "Mon", "MouseDelay", "MouseDelayPlay", "MSec",
    "MyDocuments", "Now", "NowUTC", "OSVersion", "PriorHotkey", "PriorKey",
    "ProgramFiles", "Programs", "ProgramsCommon", "PtrSize", "RegView",
    "ScreenDPI", "ScreenHeight", "ScreenWidth", "ScriptDir", "ScriptFullPath",
    "ScriptHwnd", "ScriptName", "Sec", "SendLevel", "SendMode", "Space",
    "StartMenu", "StartMenuCommon", "Startup", "StartupCommon",
    "StoreCapsLockMode", "Tab", "Temp", "ThisFunc", "ThisHotkey", "TickCount",
    "TimeIdle", "TimeIdleKeyboard", "TimeIdleMouse", "TimeIdlePhysical",
    "TimeSincePriorHotkey", "TimeSinceThisHotkey", "TitleMatchMode",
    "TitleMatchModeSpeed", "TrayMenu", "UserName", "WDay", "WinDelay",
    "WinDir", "WorkingDir", "YDay", "Year", "YWeek", "YYYY",
]


def _printable(name):
    return bool(name) and all(32 <= ord(c) <= 126 for c in name)


class AhkPE:
    def __init__(self, path):
        self.path = Path(path)
        self.pe = pefile.PE(str(self.path), fast_load=False)
        self.image_base = self.pe.OPTIONAL_HEADER.ImageBase
        self.machine = self.pe.FILE_HEADER.Machine
        self.is64 = self.machine == 0x8664
        self.ptr_size = 8 if self.is64 else 4
        self.ptr_fmt = "<Q" if self.is64 else "<I"
        self.sections = []
        for sec in self.pe.sections:
            name = sec.Name.decode("latin1").rstrip("\x00")
            data = sec.get_data()
            self.sections.append(
                {
                    "name": name,
                    "rva": sec.VirtualAddress,
                    "size": sec.Misc_VirtualSize or len(data),
                    "data": data,
                }
            )
        self._section_by_name = {s["name"]: s for s in self.sections}

    def section(self, name):
        return self._section_by_name.get(name)

    def in_section(self, rva, name):
        sec = self.section(name)
        if not sec:
            return False
        return sec["rva"] <= rva < sec["rva"] + sec["size"]

    def rva_to_offset(self, rva):
        return self.pe.get_offset_from_rva(rva)

    def read_utf16(self, rva, maxlen=256):
        """Read a null-terminated UTF-16 string at an image RVA."""
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
                    return text if _printable(text) else None
                i += 2
            return None
        return None

    def read_ptr(self, section, offset):
        data = section["data"]
        if offset + self.ptr_size > len(data):
            return None
        value = struct.unpack_from(self.ptr_fmt, data, offset)[0]
        return value if value >= self.image_base else None

    def version_info(self):
        info = {}
        try:
            for file_info in getattr(self.pe, "FileInfo", []) or []:
                for entry in file_info:
                    if not hasattr(entry, "StringTable"):
                        continue
                    for table in entry.StringTable:
                        for key, value in table.entries.items():
                            try:
                                info[key.decode("utf-8", "replace")] = value.decode(
                                    "utf-8", "replace"
                                )
                            except Exception:
                                pass
        except Exception:
            pass
        return info

    def detect_family(self):
        version = self.version_info()
        text = version.get("FileVersion", "") or version.get("ProductVersion", "")
        if text.startswith("2"):
            return "v2"
        if text.startswith("1"):
            return "v1"
        return "unknown"


def _slot_looks_like_entry(pe, sec, off, kind):
    """Cheap structural test used to build the run-length bitmap."""
    name_ptr = pe.read_ptr(sec, off)
    if name_ptr is None:
        return False
    name = pe.read_utf16(name_ptr - pe.image_base, maxlen=96)
    if name is None:
        return False
    if kind == "biv":
        getter = pe.read_ptr(sec, off + pe.ptr_size)
        return getter is not None and pe.in_section(
            getter - pe.image_base, ".text"
        )
    fn_ptr = pe.read_ptr(sec, off + pe.ptr_size)
    return fn_ptr is not None and pe.in_section(fn_ptr - pe.image_base, ".text")


def _find_candidates(pe, kind):
    if pe.is64:
        strides = {
            "bif": (0x20, 0x18, 0x28),
            "mdfunc": (0x28, 0x20, 0x30),
            "biv": (0x18, 0x20, 0x10),
        }[kind]
    else:
        strides = {
            "bif": (0x14, 0x18, 0x10),
            "mdfunc": (0x20, 0x1C, 0x24),
            "biv": (0x0C, 0x10, 0x14),
        }[kind]
    min_run = {"bif": 30, "mdfunc": 20, "biv": 30}[kind]
    candidates = []
    for sec in pe.sections:
        if sec["name"] not in (".data", ".rdata"):
            continue
        max_off = min(len(sec["data"]), sec["size"])
        n = (max_off - 2 * pe.ptr_size) // pe.ptr_size + 1
        if n <= 0:
            continue
        valid = bytearray(n)
        for i in range(n):
            valid[i] = 1 if _slot_looks_like_entry(pe, sec, i * pe.ptr_size, kind) else 0
        for stride in strides:
            if stride % pe.ptr_size:
                continue
            step = stride // pe.ptr_size
            run = [0] * n
            best_run = 0
            best_i = 0
            for i in range(n - 1, -1, -1):
                if valid[i]:
                    run[i] = 1 + (run[i + step] if i + step < n else 0)
                    if run[i] > best_run:
                        best_run = run[i]
                        best_i = i
            if best_run >= min_run:
                candidates.append(
                    {
                        "run": best_run,
                        "stride": stride,
                        "section": sec["name"],
                        "start_rva": sec["rva"] + best_i * pe.ptr_size,
                    }
                )
    candidates.sort(key=lambda c: -c["run"])
    return candidates


def _parse_bif_entry(pe, sec, off):
    name_ptr = pe.read_ptr(sec, off)
    fn_ptr = pe.read_ptr(sec, off + pe.ptr_size)
    if name_ptr is None or fn_ptr is None:
        return None
    name = pe.read_utf16(name_ptr - pe.image_base, maxlen=96)
    if name is None or not pe.in_section(fn_ptr - pe.image_base, ".text"):
        return None
    base = off + 2 * pe.ptr_size
    if base + 8 > len(sec["data"]):
        return None
    raw = sec["data"][base : base + 8]
    min_params, max_params, fid = raw[0], raw[1], raw[2]
    output_vars = [i + 1 for i, v in enumerate(raw[3:]) if v]
    return {
        "name": name,
        "bif_rva": fn_ptr - pe.image_base,
        "min_params": min_params,
        "max_params": max_params,
        "fid": fid,
        "output_vars": output_vars,
    }


def _parse_mdfunc_entry(pe, sec, off):
    name_ptr = pe.read_ptr(sec, off)
    fn_ptr = pe.read_ptr(sec, off + pe.ptr_size)
    if name_ptr is None or fn_ptr is None:
        return None
    name = pe.read_utf16(name_ptr - pe.image_base, maxlen=96)
    if name is None or not pe.in_section(fn_ptr - pe.image_base, ".text"):
        return None
    base = off + 2 * pe.ptr_size
    if base + 24 > len(sec["data"]):
        return None
    raw = sec["data"][base : base + 24]
    return {
        "name": name,
        "function_rva": fn_ptr - pe.image_base,
        "ret_type": raw[0],
        "arg_types": list(raw[1:]),
    }


def _parse_biv_entry(pe, sec, off):
    name_ptr = pe.read_ptr(sec, off)
    getter_ptr = pe.read_ptr(sec, off + pe.ptr_size)
    if name_ptr is None or getter_ptr is None:
        return None
    name = pe.read_utf16(name_ptr - pe.image_base, maxlen=96)
    if name is None or not pe.in_section(getter_ptr - pe.image_base, ".text"):
        return None
    setter_ptr = pe.read_ptr(sec, off + 2 * pe.ptr_size)
    return {
        "name": name,
        "getter_rva": getter_ptr - pe.image_base,
        "setter_rva": (
            setter_ptr - pe.image_base
            if setter_ptr is not None and pe.in_section(
                setter_ptr - pe.image_base, ".text"
            )
            else None
        ),
    }


_PARSERS = {
    "bif": _parse_bif_entry,
    "mdfunc": _parse_mdfunc_entry,
    "biv": _parse_biv_entry,
}


def _read_table_raw(pe, candidate, kind):
    """Read entries until the pointer structure clearly ends.

    The result may include a short non-table prefix (for example the final
    entry of an adjacent table) and a tail of unrelated data.  Callers trim
    both with _trim_table().
    """
    sec = pe.section(candidate["section"])
    if sec is None:
        return []
    parse = _PARSERS[kind]
    base = candidate["start_rva"] - sec["rva"]
    stride = candidate["stride"]
    entries = []
    invalid_streak = 0
    max_entries = 600
    for i in range(max_entries):
        off = base + i * stride
        if off + 2 * pe.ptr_size > len(sec["data"]):
            break
        entry = parse(pe, sec, off)
        if entry is None:
            invalid_streak += 1
            if invalid_streak >= 4:
                break
            continue
        invalid_streak = 0
        entries.append(entry)
    return entries


def _trim_table(entries, kind):
    """Keep the longest sorted run with the most known seed names."""
    seeds = {
        "bif": BIF_SEED,
        "mdfunc": MDFUNC_SEED,
        "biv": BIV_SEED,
    }[kind]
    seed_set = set(seeds)
    best_start = 0
    best_end = -1
    best_key = (-1, -1)
    n = len(entries)
    for start in range(n):
        end = start
        while end + 1 < n and entries[end + 1]["name"].lower() >= entries[end]["name"].lower():
            end += 1
        segment = entries[start : end + 1]
        key = (
            sum(1 for e in segment if e["name"] in seed_set),
            len(segment),
        )
        if key > best_key:
            best_key = key
            best_start = start
            best_end = end
    if best_end < best_start:
        return [], 0
    return entries[best_start : best_end + 1], best_start


def find_table(pe, kind):
    candidates = _find_candidates(pe, kind)
    if not candidates:
        return None
    seed_set = set(
        {"bif": BIF_SEED, "mdfunc": MDFUNC_SEED, "biv": BIV_SEED}[kind]
    )
    scored = []
    for candidate in candidates[:20]:
        raw_entries = _read_table_raw(pe, candidate, kind)
        entries, trim_start = _trim_table(raw_entries, kind)
        if not entries:
            continue
        seed_hits = sum(1 for e in entries if e["name"] in seed_set)
        sorted_ok = all(
            entries[i]["name"].lower() <= entries[i + 1]["name"].lower()
            for i in range(len(entries) - 1)
            if entries[i]["name"] and entries[i + 1]["name"]
        )
        scored.append((seed_hits, sorted_ok, candidate, entries, trim_start))
    if not scored:
        return None
    scored.sort(key=lambda item: (-item[0], -len(item[3])))
    seed_hits, sorted_ok, candidate, entries, trim_start = scored[0]
    if seed_hits < 10:
        return None
    table_rva = candidate["start_rva"] + trim_start * candidate["stride"]
    return {
        "found": True,
        "section": candidate["section"],
        "table_rva": table_rva,
        "file_offset": pe.rva_to_offset(table_rva),
        "stride": candidate["stride"],
        "count": len(entries),
        "seed_hits": seed_hits,
        "sorted": sorted_ok,
        "entries": entries,
    }


def analyze_exe(path):
    pe = AhkPE(path)
    report = {
        "file": str(Path(path).resolve()),
        "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
        "size": Path(path).stat().st_size,
        "pe": {
            "is64": pe.is64,
            "image_base": pe.image_base,
            "entry_rva": pe.pe.OPTIONAL_HEADER.AddressOfEntryPoint,
            "sections": [
                {
                    "name": s["name"],
                    "rva": s["rva"],
                    "size": s["size"],
                }
                for s in pe.sections
            ],
        },
        "version": pe.version_info(),
        "detected_family": pe.detect_family(),
    }
    for kind, key in (
        ("bif", "builtins"),
        ("mdfunc", "native_functions"),
        ("biv", "builtin_vars"),
    ):
        table = find_table(pe, kind)
        if table is None:
            report[key] = {"found": False}
        else:
            report[key] = {
                "found": True,
                "section": table["section"],
                "table_rva": table["table_rva"],
                "file_offset": table["file_offset"],
                "stride": table["stride"],
                "count": table["count"],
                "seed_hits": table["seed_hits"],
                "sorted": table["sorted"],
                "entries": table["entries"],
            }
    return report


def _ahk_str(value):
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return '"' + escaped + '"'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        if value and value >= 0x10000:
            return "0x{:X}".format(value)
        return str(value)
    raise TypeError("unsupported value: {!r}".format(value))


def _ahk_map(pairs):
    parts = ["Map("]
    for key, value in pairs:
        parts.append(_ahk_str(key) + ", " + _ahk_value(value) + ",")
    parts.append(")")
    return " ".join(parts)


def _ahk_value(value):
    if isinstance(value, dict):
        return _ahk_map(value.items())
    if isinstance(value, list):
        return "[" + ", ".join(_ahk_value(v) for v in value) + "]"
    return _ahk_str(value)


def write_ahk_data(report, out_path):
    builtins = report.get("builtins") or {}
    native = report.get("native_functions") or {}
    vars_ = report.get("builtin_vars") or {}
    lines = [
        "; generated by ahk_inspect.py - do not edit by hand",
        "_ahk_data_builtins := Map()",
        "_ahk_data_native := Map()",
        "_ahk_data_vars := Map()",
    ]
    table_specs = [
        ("builtins", builtins, "functions", "_ahk_data_builtins"),
        ("native_functions", native, "functions", "_ahk_data_native"),
        ("builtin_vars", vars_, "vars", "_ahk_data_vars"),
    ]
    for key, table, entry_key, var_name in table_specs:
        if not table.get("found"):
            continue
        entries = table["entries"]
        if entry_key == "vars":
            for i, entry in enumerate(entries):
                value = {
                    "i": i,
                    "getter_rva": entry["getter_rva"],
                    "setter_rva": entry["setter_rva"] or 0,
                }
                lines.append(
                    '{}[{}] := {}'.format(
                        var_name, _ahk_str(entry["name"]), _ahk_value(value)
                    )
                )
        else:
            for i, entry in enumerate(entries):
                if entry_key == "functions" and key == "builtins":
                    value = {
                        "i": i,
                        "rva": entry["bif_rva"],
                        "min": entry["min_params"],
                        "max": entry["max_params"],
                        "fid": entry["fid"],
                        "output": ",".join(str(v) for v in entry["output_vars"]),
                    }
                elif entry_key == "functions":
                    value = {
                        "i": i,
                        "rva": entry["function_rva"],
                        "ret": entry["ret_type"],
                        "args": ",".join(str(v) for v in entry["arg_types"]),
                    }
                else:
                    value = entry
                lines.append(
                    '{}[{}] := {}'.format(
                        var_name, _ahk_str(entry["name"]), _ahk_value(value)
                    )
                )

    lines.append("AhkHackReport := Map(")
    lines.append('    "file", ' + _ahk_str(report["file"]) + ",")
    lines.append(
        '    "file_version", '
        + _ahk_str(report["version"].get("FileVersion", ""))
        + ","
    )
    lines.append(
        '    "detected_family", ' + _ahk_str(report["detected_family"]) + ","
    )
    lines.append('    "is64", ' + _ahk_value(report["pe"]["is64"]) + ",")
    lines.append(
        '    "image_base", ' + _ahk_value(report["pe"]["image_base"]) + ","
    )
    for key, table, entry_key, var_name in table_specs:
        if not table.get("found"):
            lines.append('    "' + key + '", Map("found", false),')
            continue
        lines.append(
            '    "' + key + '", Map('
            + '"count", ' + _ahk_value(table.get("count", 0)) + ","
            + '"stride", ' + _ahk_value(table.get("stride", 0)) + ","
            + '"table_rva", ' + _ahk_value(table.get("table_rva", 0)) + ","
            + '"functions", ' + var_name
            + "),"
        )
    lines.append(")")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exe", help="path to an AutoHotkey executable")
    parser.add_argument("-o", "--out", help="output JSON report path")
    parser.add_argument(
        "--ahk-data",
        help="also write an AutoHotkey v2 data file (Map literal)",
    )
    parser.add_argument(
        "--quiet", action="store_true", help="suppress the human-readable summary"
    )
    args = parser.parse_args(argv)

    report = analyze_exe(args.exe)
    if args.out:
        Path(args.out).write_text(
            json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
        )
    if args.ahk_data:
        write_ahk_data(report, Path(args.ahk_data))

    if not args.quiet:
        print("file: {}".format(report["file"]))
        print(
            "version: {} | family: {} | {}".format(
                report["version"].get("FileVersion", "?"),
                report["detected_family"],
                "x64" if report["pe"]["is64"] else "x86",
            )
        )
        for key, label in (
            ("builtins", "builtin functions"),
            ("native_functions", "native functions"),
            ("builtin_vars", "builtin vars"),
        ):
            table = report[key]
            if table.get("found"):
                print(
                    "{}: {} entries at rva 0x{:X} (stride 0x{:X}, {} seed hits)".format(
                        label,
                        table["count"],
                        table["table_rva"],
                        table["stride"],
                        table["seed_hits"],
                    )
                )
            else:
                print("{}: not detected".format(label))
        if args.out:
            print("report: {}".format(args.out))
        if args.ahk_data:
            print("ahk data: {}".format(args.ahk_data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
