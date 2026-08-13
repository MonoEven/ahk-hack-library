class AhkLiveDesktop {
    static List() {
        result := []
        try {
            wmi := ComObjGet("winmgmts:")
            items := wmi.ExecQuery("SELECT ProcessId,Name FROM Win32_Process")
            for item in items {
                name := item.Name
                if InStr(name, "AutoHotkey", false) or InStr(name, "autohotkey", false)
                    result.Push(Map("pid", item.ProcessId, "name", name))
            }
        }
        return result
    }

    static AttachByName(name) {
        return AhkLive.AttachByName(name)
    }
}
