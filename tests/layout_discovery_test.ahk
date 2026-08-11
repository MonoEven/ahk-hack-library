#SingleInstance Force
#NoTrayIcon

#Include ..\lib\ahk_layout.ahk

out := ""
outFile := A_ScriptDir "\layout_discovery_test.out"

DeepEq(a, b) {
    if a is Array or b is Array {
        if !(a is Array) or !(b is Array)
            return false
        if a.Length != b.Length
            return false
        for i, v in a
            if !DeepEq(v, b[i])
                return false
        return true
    }
    if a is Number and b is Number
        return Abs(a - b) <= 1e-9
    return a = b
}

try {
    layout := AhkLayout.Discover()
    out .= "version=" A_AhkVersion "`n"
    out .= "mItem=0x" Format("{:X}", layout["mItem"]) "`n"
    out .= "mLength=0x" Format("{:X}", layout["mLength"]) "`n"
    out .= "mCapacity=0x" Format("{:X}", layout["mCapacity"]) "`n"
    out .= "variantSize=" layout["variantSize"] "`n"
    out .= "valueOffset=" layout["valueOffset"] "`n"
    out .= "symbolOffset=" layout["symbolOffset"] "`n"
    out .= "symInt=" layout["symInt"] " symFloat=" layout["symFloat"]
        . " symObject=" layout["symObject"] "`n"

    ; f64 leaf.
    expected := [1.5, 2.5, 3.5]
    data := Buffer(3 * 8, 0)
    NumPut("Double", 1.5, data, 0)
    NumPut("Double", 2.5, data, 8)
    NumPut("Double", 3.5, data, 16)
    leaf := Array()
    leaf.Capacity := 3
    AhkLayout.FillLeaf(leaf, data.Ptr, 3, 8, 0, layout)
    if !DeepEq(leaf, expected)
        throw Error("f64 leaf mismatch")
    out .= "f64_leaf=ok`n"

    ; i64 leaf with capacity slack.
    expectedI := [10, 20, 30]
    dataI := Buffer(3 * 8, 0)
    NumPut("Int64", 10, dataI, 0)
    NumPut("Int64", 20, dataI, 8)
    NumPut("Int64", 30, dataI, 16)
    leafI := Array()
    leafI.Capacity := 16
    AhkLayout.FillLeaf(leafI, dataI.Ptr, 3, 8, 1, layout)
    if !DeepEq(leafI, expectedI)
        throw Error("i64 leaf mismatch")
    if leafI.Capacity != 3
        throw Error("i64 leaf capacity should be tightened to 3")
    out .= "i64_leaf=ok`n"

    ; u8 leaf.
    expectedU := [200, 201, 202]
    dataU := Buffer(3, 0)
    NumPut("UChar", 200, dataU, 0)
    NumPut("UChar", 201, dataU, 1)
    NumPut("UChar", 202, dataU, 2)
    leafU := Array()
    leafU.Capacity := 3
    AhkLayout.FillLeaf(leafU, dataU.Ptr, 3, 1, 9, layout)
    if !DeepEq(leafU, expectedU)
        throw Error("u8 leaf mismatch")
    out .= "u8_leaf=ok`n"

    ; Nested 2-D: 3 rows x 2 columns via leaf fill + public Push.
    rows := 3
    cols := 2
    nestedData := Buffer(rows * cols * 8, 0)
    for r in [0, 1, 2]
        for c in [0, 1]
            NumPut("Double", r * 10 + c + 1, nestedData, (r * cols + c) * 8)
    parent := Array()
    parent.Capacity := rows
    expected2d := []
    for r in [0, 1, 2] {
        child := Array()
        child.Capacity := cols
        AhkLayout.FillLeaf(
            child, nestedData.Ptr + r * cols * 8, cols, 8, 0, layout)
        parent.Push(child)
        row := []
        for c in [0, 1]
            row.Push(r * 10 + c + 1)
        expected2d.Push(row)
    }
    if !DeepEq(parent, expected2d)
        throw Error("2-D mismatch")
    if parent[2][1] != 11 or parent.Length != 3 or parent[1].Length != 2
        throw Error("2-D spot check failed")
    out .= "2d_nested=ok`n"

    ; Mutation through the public API after direct fill.
    leaf.Push(4.5)
    if leaf.Length != 4 or leaf[4] != 4.5
        throw Error("post-fill Push failed")
    leaf.RemoveAt(1)
    if leaf.Length != 3 or leaf[1] != 2.5
        throw Error("post-fill RemoveAt failed")
    out .= "post_fill_mutation=ok`n"

    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message
        . " | line " e.Line " | " e.Extra "`n"
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
