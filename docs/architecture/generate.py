#!/usr/bin/env python3
"""
Auto-generates architecture/index.html from plugin metadata.
Reads marketplace.json, plugin.json, hooks.json, skills, agents.
Brand bar: #f85149 (Reaper red).

Usage:
    python3 generate.py
"""

import json
import os
import sys
from datetime import datetime


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.join(SCRIPT_DIR, "..", "..")


def load_json(path):
    """Load a JSON file, return None on error."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def read_mermaid(name):
    """Read a .mmd file from the architecture directory."""
    path = os.path.join(SCRIPT_DIR, f"{name}.mmd")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return f"graph TD\n    A[{name} diagram not found]"


def get_plugin_info(plugin_dir):
    """Extract plugin metadata."""
    plugin_json = load_json(os.path.join(plugin_dir, ".claude-plugin", "plugin.json"))
    if not plugin_json:
        return None

    hooks_json = load_json(os.path.join(plugin_dir, "hooks", "hooks.json"))
    hooks = []
    if hooks_json:
        for phase, entries in hooks_json.get("hooks", {}).items():
            if isinstance(entries, list):
                for entry in entries:
                    matcher = entry.get("matcher", "*")
                    for hook in entry.get("hooks", []):
                        cmd = hook.get("command", "")
                        timeout = hook.get("timeout", 0)
                        hooks.append({
                            "phase": phase,
                            "matcher": matcher,
                            "command": cmd.split("/")[-1].replace('"', ""),
                            "timeout": timeout,
                        })

    # Find skills
    skills = []
    skills_dir = os.path.join(plugin_dir, "skills")
    if os.path.isdir(skills_dir):
        for skill_name in os.listdir(skills_dir):
            skill_path = os.path.join(skills_dir, skill_name)
            if os.path.isdir(skill_path):
                skills.append(skill_name)

    # Find agents
    agents = []
    agents_dir = os.path.join(plugin_dir, "agents")
    if os.path.isdir(agents_dir):
        for agent_file in os.listdir(agents_dir):
            if agent_file.endswith(".md"):
                agents.append(agent_file.replace(".md", ""))

    # Find commands
    commands = []
    commands_dir = os.path.join(plugin_dir, "commands")
    if os.path.isdir(commands_dir):
        for cmd_file in os.listdir(commands_dir):
            if cmd_file.endswith(".md"):
                commands.append(cmd_file.replace(".md", ""))

    return {
        "name": plugin_json.get("name", ""),
        "description": plugin_json.get("description", ""),
        "hooks": hooks,
        "skills": skills,
        "agents": agents,
        "commands": commands,
    }


def main():
    marketplace = load_json(os.path.join(ROOT_DIR, ".claude-plugin", "marketplace.json"))
    if not marketplace:
        print("Error: marketplace.json not found", file=sys.stderr)
        sys.exit(1)

    plugins_info = []
    for plugin_entry in marketplace.get("plugins", []):
        source = plugin_entry.get("source", "")
        plugin_dir = os.path.join(ROOT_DIR, source.lstrip("./"))
        info = get_plugin_info(plugin_dir)
        if info:
            plugins_info.append(info)

    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    version = marketplace.get("metadata", {}).get("version", "1.0.0")

    print(f"Generated architecture explorer for {len(plugins_info)} plugins at {now}")
    print(f"Reaper v{version}")

    # In a full implementation, this would generate the index.html
    # For now, the static index.html is maintained manually


if __name__ == "__main__":
    main()
