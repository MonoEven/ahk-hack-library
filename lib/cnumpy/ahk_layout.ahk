; ahk_layout.ahk - runtime discovery of the AHK v2 Array object layout.
;
; No hardcoded Array offsets and no machine code.  The layout is derived
; from live objects with mutation diffing and cross-validated with a second
; independent probe set.  Any inconsistency raises an explicit error.
;
; Discovered layout keys:
;   mItem / mLength / mCapacity   Array field offsets
;   variantSize / valueOffset / symbolOffset
;   symInt / symFloat / symObject

class AhkLayout {
    static _cached := 0
    static _window := 64

    static Discover(force := false) {
        if AhkLayout._cached and !force
            return AhkLayout._cached
        if A_PtrSize != 8
            throw Error("AhkLayout currently requires x64 AutoHotkey", -1)

        layout := AhkLayout._DiscoverFromProbes()
        layout2 := AhkLayout._DiscoverFromProbes(true)
        for key in ["mItem", "mLength", "mCapacity", "variantSize",
                    "valueOffset", "symbolOffset",
                    "symInt", "symFloat", "symObject"] {
            if layout[key] != layout2[key]
                throw Error("AhkLayout cross-validation failed for " key
                    ": " layout[key] " != " layout2[key])
        }
        AhkLayout._cached := layout
        return layout
    }

    ; Pack the discovered layout into the public CnpAhkArrayLayout buffer.
    static ToBuffer(layout) {
        buf := Buffer(64, 0)
        NumPut("UInt", 1, buf, 0)      ; abi_version
        NumPut("UInt", 64, buf, 4)     ; struct_size
        NumPut("UInt", layout["mItem"], buf, 8)
        NumPut("UInt", layout["mLength"], buf, 12)
        NumPut("UInt", layout["mCapacity"], buf, 16)
        NumPut("UInt", layout["variantSize"], buf, 20)
        NumPut("UInt", layout["valueOffset"], buf, 24)
        NumPut("UInt", layout["symbolOffset"], buf, 28)
        NumPut("UInt", layout["symInt"], buf, 32)
        NumPut("UInt", layout["symFloat"], buf, 36)
        NumPut("UInt", layout["symObject"], buf, 40)
        return buf
    }

    static _DiscoverFromProbes(second := false) {
        probe := Array()
        base := ObjPtr(probe)
        q0 := AhkLayout._SnapQwords(base)
        capacityTarget := second ? 96 : 64
        needle := second ? 22222 : 12345
        probe.Capacity := capacityTarget
        q1 := AhkLayout._SnapQwords(base)
        probe.Push(needle)
        q2 := AhkLayout._SnapQwords(base)
        probe.Push(needle + 1)
        q3 := AhkLayout._SnapQwords(base)

        mItem := AhkLayout._FindChangedPointer(q0, q1, q2, q3, needle)
        mLength := AhkLayout._FindLengthOffset()
        mCapacity := AhkLayout._FindCapacityOffset()

        iarr := second ? [123, 456, 789] : [7, 8, 9]
        farr := second ? [1.5, 2.5, 3.5] : [7.0, 8.0, 9.0]
        nested := second ? [[9], [8]] : [[1], [2]]
        firstFloat := second ? 1.5 : 7.0

        iItem := NumGet(ObjPtr(iarr), mItem, "Ptr")
        fItem := NumGet(ObjPtr(farr), mItem, "Ptr")
        nItem := NumGet(ObjPtr(nested), mItem, "Ptr")
        AhkLayout._RequireReadable(iItem, 64, "integer item buffer")
        AhkLayout._RequireReadable(fItem, 64, "float item buffer")
        AhkLayout._RequireReadable(nItem, 64, "object item buffer")

        first := second ? 123 : 7
        secondValue := second ? 456 : 8
        third := second ? 789 : 9
        variant := AhkLayout._DiscoverVariant(iItem, fItem, nItem,
            first, secondValue, third, firstFloat, ObjPtr(nested[1]))

        if mLength < 0 or mCapacity < 0 or mItem < 0
            throw Error("AhkLayout failed to locate Array fields")
        if NumGet(ObjPtr(iarr), mLength, "UInt") != 3
            throw Error("mLength offset does not match the live array")
        if NumGet(ObjPtr(iarr), mCapacity, "UInt") < 3
            throw Error("mCapacity offset does not match the live array")

        return Map(
            "mItem", mItem,
            "mLength", mLength,
            "mCapacity", mCapacity,
            "variantSize", variant["size"],
            "valueOffset", variant["value"],
            "symbolOffset", variant["symbol"],
            "symInt", variant["symInt"],
            "symFloat", variant["symFloat"],
            "symObject", variant["symObject"]
        )
    }

    static _SnapQwords(ptr) {
        result := []
        loop AhkLayout._window // 8
            result.Push(NumGet(ptr, (A_Index - 1) * 8, "Int64"))
        return result
    }

    static _FindChangedPointer(q0, q1, q2, q3, needle) {
        matches := []
        loop AhkLayout._window // 8 {
            off := (A_Index - 1) * 8
            if q0[A_Index] != 0 or q1[A_Index] = 0
                or q1[A_Index] != q2[A_Index]
                or q2[A_Index] != q3[A_Index]
                continue
            ptr := q1[A_Index]
            if ptr <= 0x10000 or ptr >= 0x00007FFFFFFFFFFF
                continue
            if !AhkLayout._Readable(ptr, 64)
                continue
            found := false
            loop 64 - 8 + 1 {
                if NumGet(ptr, A_Index - 1, "Int64") = needle {
                    found := true
                    break
                }
            }
            if found
                matches.Push(off)
        }
        if matches.Length != 1
            throw Error("AhkLayout mItem candidates = " matches.Length
                " offsets: " AhkLayout._Join(matches))
        return matches[1]
    }

    static _FindLengthOffset() {
        probe := Array()
        base := ObjPtr(probe)
        probe.Push(1)
        snapA := AhkLayout._SnapDwords(base)
        probe.Push(2)
        snapB := AhkLayout._SnapDwords(base)
        probe.RemoveAt(1)
        snapC := AhkLayout._SnapDwords(base)
        probe.RemoveAt(1)
        snapD := AhkLayout._SnapDwords(base)
        probe.Push(3)
        snapE := AhkLayout._SnapDwords(base)
        matches := []
        loop AhkLayout._window // 4 {
            i := A_Index
            if snapA[i] = 1 and snapB[i] = 2 and snapC[i] = 1
                and snapD[i] = 0 and snapE[i] = 1
                matches.Push((i - 1) * 4)
        }
        if matches.Length != 1
            throw Error("AhkLayout mLength candidates = " matches.Length
                " offsets: " AhkLayout._Join(matches))
        return matches[1]
    }

    static _FindCapacityOffset() {
        probe := Array()
        base := ObjPtr(probe)
        probe.Capacity := 32
        snapA := AhkLayout._SnapDwords(base)
        probe.Capacity := 16
        snapB := AhkLayout._SnapDwords(base)
        probe.Capacity := 64
        snapC := AhkLayout._SnapDwords(base)
        matches := []
        loop AhkLayout._window // 4 {
            i := A_Index
            if snapA[i] = 32 and snapB[i] = 16 and snapC[i] = 64
                matches.Push((i - 1) * 4)
        }
        if matches.Length != 1
            throw Error("AhkLayout mCapacity candidates = " matches.Length
                " offsets: " AhkLayout._Join(matches))
        return matches[1]
    }

    static _SnapDwords(ptr) {
        result := []
        loop AhkLayout._window // 4
            result.Push(NumGet(ptr, (A_Index - 1) * 4, "UInt"))
        return result
    }

    static _DiscoverVariant(iItem, fItem, nItem,
            first, secondValue, third, firstFloat, childPtr) {
        valueCandidates := []
        loop 16 // 8 + 1 {
            off := (A_Index - 1) * 8
            if NumGet(iItem, off, "Int64") = first
                valueCandidates.Push(off)
        }
        size := 0
        value := -1
        for off in valueCandidates {
            step := 0
            loop 64 - 8 {
                if NumGet(iItem, off + A_Index, "Int64") = secondValue {
                    step := A_Index
                    break
                }
            }
            if step <= 0 or Mod(step, 8) != 0 or step < 16
                continue
            if NumGet(iItem, off + step, "Int64") != secondValue
                continue
            if NumGet(iItem, off + step * 2, "Int64") != third
                continue
            size := step
            value := off
            break
        }
        if size = 0 or value < 0
            throw Error("AhkLayout failed to discover Variant value/stride")

        symbol := -1
        symInt := 0
        symFloat := 0
        loop 16 // 4 {
            off := (A_Index - 1) * 4
            if off = value or off = value + 4
                continue
            ui1 := NumGet(iItem, off, "UInt")
            ui2 := NumGet(iItem, off + size, "UInt")
            ui3 := NumGet(iItem, off + size * 2, "UInt")
            uf1 := NumGet(fItem, off, "UInt")
            uf2 := NumGet(fItem, off + size, "UInt")
            uf3 := NumGet(fItem, off + size * 2, "UInt")
            if ui1 = ui2 and ui2 = ui3
                and uf1 = uf2 and uf2 = uf3
                and ui1 != uf1 {
                if symbol >= 0
                    throw Error("AhkLayout found multiple symbol candidates")
                symbol := off
                symInt := ui1
                symFloat := uf1
            }
        }
        if symbol < 0
            throw Error("AhkLayout failed to discover Variant symbol offset")
        if symInt = symFloat or symInt = 0 or symFloat = 0
            throw Error("AhkLayout invalid int/float symbol constants")

        childStored := NumGet(nItem, value, "Int64")
        symObject := NumGet(nItem, symbol, "UInt")
        if childStored != childPtr
            throw Error("AhkLayout object variant does not store the child pointer")
        if symObject = symInt or symObject = symFloat or symObject = 0
            throw Error("AhkLayout invalid object symbol constant")
        if NumGet(fItem, value, "Double") != firstFloat
            throw Error("AhkLayout value field does not hold the float value")

        return Map(
            "size", size,
            "value", value,
            "symbol", symbol,
            "symInt", symInt,
            "symFloat", symFloat,
            "symObject", symObject
        )
    }

    static _RequireReadable(ptr, size, label) {
        if ptr = 0
            throw Error("AhkLayout null pointer for " label)
        if !AhkLayout._Readable(ptr, size)
            throw Error("AhkLayout unreadable " label
                " at 0x" Format("{:X}", ptr))
    }

    static _Readable(ptr, size) {
        mbi := Buffer(48)
        if !DllCall("VirtualQuery", "Ptr", ptr, "Ptr", mbi, "UPtr", 48)
            return false
        regionBase := NumGet(mbi, 0, "Int64")
        regionSize := NumGet(mbi, 24, "Int64")
        state := NumGet(mbi, 32, "UInt")
        protect := NumGet(mbi, 36, "UInt")
        if state != 0x1000
            return false
        if protect & 0x100
            return false
        readable := (protect & 0x02) != 0
            or (protect & 0x04) != 0
            or (protect & 0x08) != 0
            or (protect & 0x20) != 0
            or (protect & 0x40) != 0
            or (protect & 0x80) != 0
        if !readable
            return false
        offset := ptr - regionBase
        return offset >= 0 and offset + size <= regionSize
    }

    static _Join(values) {
        text := ""
        for v in values
            text .= (text = "" ? "" : ",") v
        return text
    }
}
