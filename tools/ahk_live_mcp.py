import json
import os
import shutil
import subprocess
import sys

AHK = os.environ.get("AHK_LIVE_AHK") or shutil.which("AutoHotkey64.exe")
REPO = os.environ.get("AHK_LIVE_REPO") or os.getcwd()
if not AHK:
    raise SystemExit("set AHK_LIVE_AHK or put AutoHotkey64.exe on PATH")
CLI = os.path.join(REPO, "ahk_live_cli.ahk")
OUT = os.path.join(os.environ.get("TEMP", "."), "ahk_live_cli.out")


def run_cli(*args):
    if os.path.exists(OUT):
        os.remove(OUT)
    cmd = [AHK, CLI, *map(str, args)]
    proc = subprocess.run(
        cmd,
        cwd=REPO,
        capture_output=True,
        timeout=30,
        text=True,
        errors="replace",
    )
    text = ""
    if os.path.exists(OUT):
        with open(OUT, "r", encoding="utf-8") as f:
            text = f.read()
    text = text.lstrip("\ufeff")
    return proc.returncode, text


def write(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


TOOLS = [
    {
        "name": "ahk_eval",
        "description": "Evaluate an expression in a running AutoHotkey process.",
        "inputSchema": {
            "type": "object",
            "properties": {"pid": {"type": "integer"}, "expr": {"type": "string"}},
            "required": ["pid", "expr"],
        },
    },
    {
        "name": "ahk_functions",
        "description": "List functions in a running AutoHotkey process.",
        "inputSchema": {
            "type": "object",
            "properties": {"pid": {"type": "integer"}},
            "required": ["pid"],
        },
    },
    {
        "name": "ahk_classes",
        "description": "List classes in a running AutoHotkey process.",
        "inputSchema": {
            "type": "object",
            "properties": {"pid": {"type": "integer"}},
            "required": ["pid"],
        },
    },
    {
        "name": "ahk_version",
        "description": "Return the AhkLive SDK version.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            write({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}})
            continue
        mid = msg.get("id")
        method = msg.get("method")
        try:
            if method == "initialize":
                write({
                    "jsonrpc": "2.0",
                    "id": mid,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "ahk_live_mcp", "version": "1.0.0"},
                    },
                })
            elif method == "notifications/initialized":
                pass
            elif method == "tools/list":
                write({"jsonrpc": "2.0", "id": mid, "result": {"tools": TOOLS}})
            elif method == "tools/call":
                name = msg["params"]["name"]
                args = msg["params"].get("arguments", {})
                if name == "ahk_eval":
                    code, text = run_cli("--eval", args["pid"], args["expr"])
                elif name == "ahk_functions":
                    code, text = run_cli("--functions", args["pid"])
                elif name == "ahk_classes":
                    code, text = run_cli("--classes", args["pid"])
                elif name == "ahk_version":
                    code, text = run_cli("--version")
                else:
                    raise RuntimeError(f"unknown tool: {name}")
                if code != 0:
                    write({"jsonrpc": "2.0", "id": mid, "error": {"code": -32000, "message": text}})
                else:
                    write({
                        "jsonrpc": "2.0",
                        "id": mid,
                        "result": {
                            "content": [{"type": "text", "text": text}],
                            "isError": False,
                        },
                    })
            elif method == "ping":
                write({"jsonrpc": "2.0", "id": mid, "result": {}})
            else:
                write({"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "method not found"}})
        except Exception as exc:
            write({"jsonrpc": "2.0", "id": mid, "error": {"code": -32603, "message": str(exc)}})


if __name__ == "__main__":
    main()
