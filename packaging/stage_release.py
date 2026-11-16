#!/usr/bin/env python3
import argparse
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as Et

UPSTREAM_BASE = "https://raw.githubusercontent.com/PathOfBuildingCommunity/PathOfBuilding/{branch}/"
EXTRA_RUNTIME_FILES = ["Update.exe", "msvcr100.dll"]
PART_ROOTS = {"runtime": "runtime", "program": "src", "tree": "src", "default": ""}


def regenerate_manifest(tree, version, repo_slug):
    subprocess.run([sys.executable, "update_manifest.py", "--in-place", "--set-version", version, "--quiet"], cwd=tree, check=True)
    path = os.path.join(tree, "manifest.xml")
    with open(path, encoding="utf-8") as source:
        text = source.read()
    fork_base = f"https://raw.githubusercontent.com/{repo_slug}/{{branch}}/"
    if UPSTREAM_BASE not in text:
        raise SystemExit("manifest.xml does not contain the expected upstream source URL")
    text = text.replace(UPSTREAM_BASE, fork_base)
    with open(path, "w", encoding="utf-8", newline="\n") as target:
        target.write(text)
    return path


def stage(tree, out, channel):
    manifest_path = os.path.join(tree, "manifest.xml")
    root = Et.parse(manifest_path).getroot()
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)
    count = 0
    for node in root.findall("File"):
        name = node.get("name")
        part = node.get("part")
        source = os.path.join(tree, PART_ROOTS[part], name)
        target = os.path.join(out, name.replace("{space}", " "))
        if not os.path.exists(source):
            raise SystemExit(f"listed in manifest but missing: {source}")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copy2(source, target)
        count += 1
    for name in EXTRA_RUNTIME_FILES:
        shutil.copy2(os.path.join(tree, "runtime", name), os.path.join(out, name))
    version = root.find("Version")
    version.set("platform", "win32")
    version.set("branch", channel)
    Et.indent(root, "\t")
    Et.ElementTree(root).write(os.path.join(out, "manifest.xml"), encoding="UTF-8", xml_declaration=True)
    return count


def main():
    parser = argparse.ArgumentParser(description="Generate the manifest and stage a Windows release of Path of Building")
    parser.add_argument("--tree", required=True, help="source tree (repository layout) to package")
    parser.add_argument("--out", required=True, help="staging folder to create")
    parser.add_argument("--version", required=True, help="version number shown in the program")
    parser.add_argument("--repo", required=True, help="GitHub owner/name that serves updates")
    parser.add_argument("--channel", required=True, help="branch in that repository that serves updates")
    args = parser.parse_args()
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", args.repo):
        raise SystemExit(f"invalid repository: {args.repo}")
    regenerate_manifest(args.tree, args.version, args.repo)
    count = stage(args.tree, args.out, args.channel)
    print(f"staged {count} files (+{len(EXTRA_RUNTIME_FILES)} runtime extras and manifest.xml) in {args.out}")


if __name__ == "__main__":
    main()
