; Optional cnumpy integration for the ahk-hack library.
;
; This is the "practice result" layer built on top of the core scanner:
; it converts CnpArray <-> native AHK values and uses the native Array
; builder from the core.
;
; Set Numpy.DllPath before first use when the cnumpy DLL is not at the
; default location expected by numpy.ahk.

#Include ..\ahk_hack.ahk
#Include numpy.ahk
#Include cnumpy_bridge.ahk
