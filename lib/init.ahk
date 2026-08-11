; ahk-hack library entry point.
;
; The core of the library is the scanning layer: MCode + AhkMagic, which
; locates AutoHotkey interpreter tables (g_BIF / sMdFunc / g_BIV_A) and
; scans the PE export tables of arbitrary DLL/EXE modules.
;
; cnumpy conversion is a separate practice integration, not part of this
; core entry.  Include lib\cnumpy\init.ahk when you want it.

#Include ahk_hack.ahk
