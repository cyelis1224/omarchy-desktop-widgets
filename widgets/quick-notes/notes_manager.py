#!/usr/bin/env python3
import sys
import os
import json

DIR_PATH = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(DIR_PATH, "notes.json")
MD_FILE = os.path.join(DIR_PATH, "notes.md")

DEFAULT_DATA = {
    "todos": [
        {"id": 1, "text": "Set up desktop widgets repository", "done": True, "tag": "#work"},
        {"id": 2, "text": "Build QuickNotesWidget proof of concept", "done": False, "tag": "#todo"},
        {"id": 3, "text": "Test custom widget import pipeline", "done": False, "tag": "#idea"},
        {"id": 4, "text": "Design Circular Pomodoro Timer", "done": False, "tag": "#idea"}
    ],
    "scratchpad": "# Desktop Scratchpad\n\nQuick notes synced to markdown.\n- High-performance Omarchy UI\n- Quickshell QML & Hyprland\n",
    "commands": [
        {"id": 1, "name": "Restart Shell", "cmd": "omarchy-restart-shell", "desc": "Reload Quickshell desktop environment"},
        {"id": 2, "name": "Git Status", "cmd": "git status", "desc": "Inspect current repository status"},
        {"id": 3, "name": "System Info", "cmd": "fastfetch", "desc": "Show system and hardware overview"}
    ]
}

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "todos" not in data: data["todos"] = DEFAULT_DATA["todos"]
                if "scratchpad" not in data: data["scratchpad"] = DEFAULT_DATA["scratchpad"]
                if "commands" not in data: data["commands"] = DEFAULT_DATA["commands"]
                
                # Ensure all commands have an ID
                needs_save = False
                cmds = data.get("commands", [])
                max_id = 0
                for c in cmds:
                    if isinstance(c.get("id"), int) and c["id"] > max_id:
                        max_id = c["id"]
                for c in cmds:
                    if "id" not in c or not isinstance(c.get("id"), int):
                        max_id += 1
                        c["id"] = max_id
                        needs_save = True
                data["commands"] = cmds
                if needs_save:
                    save_data(data)
                return data
        except Exception:
            pass
    save_data(DEFAULT_DATA)
    return DEFAULT_DATA

def sync_markdown(data):
    try:
        lines = ["# Quick Notes & Tasks\n", "## Tasks\n"]
        for t in data.get("todos", []):
            mark = "x" if t.get("done") else " "
            tag = f" `{t.get('tag')}`" if t.get("tag") else ""
            lines.append(f"- [{mark}] {t.get('text', '')}{tag}\n")
        lines.append("\n## Scratchpad\n\n")
        lines.append(data.get("scratchpad", ""))
        lines.append("\n")
        lines.append("\n## Snippets\n\n")
        for c in data.get("commands", []):
            lines.append(f"- **{c.get('name', '')}**: `{c.get('cmd', '')}`\n")
        with open(MD_FILE, "w", encoding="utf-8") as f:
            f.writelines(lines)
    except Exception:
        pass

def save_data(data):
    try:
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        sync_markdown(data)
    except Exception as e:
        sys.stderr.write(f"Error saving data: {e}\n")

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "load"
    data = load_data()

    if action == "add_todo" and len(sys.argv) >= 3:
        text = sys.argv[2].strip()
        tag = sys.argv[3].strip() if len(sys.argv) >= 4 else "#todo"
        if text:
            todos = data.get("todos", [])
            new_id = max([t.get("id", 0) for t in todos], default=0) + 1
            todos.insert(0, {"id": new_id, "text": text, "done": False, "tag": tag})
            data["todos"] = todos
            save_data(data)
            print(json.dumps({"status": "added", "todos": todos}))
            return

    elif action == "toggle_todo" and len(sys.argv) >= 3:
        try:
            todo_id = int(sys.argv[2])
            todos = data.get("todos", [])
            for t in todos:
                if t.get("id") == todo_id:
                    t["done"] = not t.get("done", False)
                    break
            data["todos"] = todos
            save_data(data)
            print(json.dumps({"status": "toggled", "todos": todos}))
            return
        except Exception as e:
            print(json.dumps({"status": "error", "error": str(e)}))
            return

    elif action == "delete_todo" and len(sys.argv) >= 3:
        try:
            todo_id = int(sys.argv[2])
            todos = [t for t in data.get("todos", []) if t.get("id") != todo_id]
            data["todos"] = todos
            save_data(data)
            print(json.dumps({"status": "deleted", "todos": todos}))
            return
        except Exception as e:
            print(json.dumps({"status": "error", "error": str(e)}))
            return

    elif action == "clear_completed":
        todos = [t for t in data.get("todos", []) if not t.get("done")]
        data["todos"] = todos
        save_data(data)
        print(json.dumps({"status": "cleared", "todos": todos}))
        return

    elif action == "save_scratchpad" and len(sys.argv) >= 3:
        content = sys.argv[2]
        data["scratchpad"] = content
        save_data(data)
        print(json.dumps({"status": "saved_scratchpad"}))
        return

    elif action == "add_command" and len(sys.argv) >= 4:
        name = sys.argv[2].strip()
        cmd = sys.argv[3].strip()
        desc = sys.argv[4].strip() if len(sys.argv) >= 5 else ""
        if name and cmd:
            commands = data.get("commands", [])
            new_id = max([c.get("id", 0) for c in commands], default=0) + 1
            commands.append({"id": new_id, "name": name, "cmd": cmd, "desc": desc})
            data["commands"] = commands
            save_data(data)
            print(json.dumps({"status": "added_command", "commands": commands}))
            return

    elif action == "edit_command" and len(sys.argv) >= 5:
        try:
            cmd_id = int(sys.argv[2])
            name = sys.argv[3].strip()
            cmd = sys.argv[4].strip()
            desc = sys.argv[5].strip() if len(sys.argv) >= 6 else ""
            commands = data.get("commands", [])
            for c in commands:
                if c.get("id") == cmd_id:
                    c["name"] = name
                    c["cmd"] = cmd
                    if desc:
                        c["desc"] = desc
                    break
            data["commands"] = commands
            save_data(data)
            print(json.dumps({"status": "edited_command", "commands": commands}))
            return
        except Exception as e:
            print(json.dumps({"status": "error", "error": str(e)}))
            return

    elif action == "delete_command" and len(sys.argv) >= 3:
        try:
            cmd_id = int(sys.argv[2])
            commands = [c for c in data.get("commands", []) if c.get("id") != cmd_id]
            data["commands"] = commands
            save_data(data)
            print(json.dumps({"status": "deleted_command", "commands": commands}))
            return
        except Exception as e:
            print(json.dumps({"status": "error", "error": str(e)}))
            return

    # Default: output all data
    print(json.dumps({
        "status": "ok",
        "todos": data.get("todos", []),
        "scratchpad": data.get("scratchpad", ""),
        "commands": data.get("commands", [])
    }))

if __name__ == "__main__":
    main()
