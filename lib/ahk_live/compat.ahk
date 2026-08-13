class AhkLiveCompat {
    static ExportCsv(hook, path) {
        funcs := AhkLive.ListFunctions(hook)
        classes := AhkLive.ListClasses(hook)
        try FileDelete(path)
        FileAppend("kind,name,arity,params`n", path, "UTF-8")
        for name, info in funcs {
            params := ""
            for item in info["params"]
                params .= (params = "" ? "" : "|") . item
            FileAppend("function," name "," info["max"] "," params "`n", path, "UTF-8")
        }
        for cls, methods in classes {
            for method, info in methods {
                params := ""
                for item in info["params"]
                    params .= (params = "" ? "" : "|") . item
                FileAppend("class," cls "." method "," info["max"] "," params "`n", path, "UTF-8")
            }
        }
        return path
    }
}
