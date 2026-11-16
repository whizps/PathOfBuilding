#!/usr/bin/env python3
import argparse
import io
import json
import os
import re
import shutil
import subprocess
import tarfile

HOOK_FILES = ["src/Modules/Build.lua", "src/Modules/Main.lua"]
PAYLOAD_PATHS = ["src/Classes", "src/Data/AtlasTreeVersions.lua", "src/TreeData/Atlas"]
SPEC_GLOB = re.compile(r"^spec/System/TestAtlas\w*_spec\.lua$")
MARKERS = {
    "Modules/Build.lua": "atlasTab",
    "Modules/Main.lua": "LoadAtlasTree",
    "UpdateCheck.lua": "atlasPatchedFiles",
}
UPDATE_CHECK_OPS = [
    {
        "type": "insertBefore",
        "anchor": "local deleteFiles = { }",
        "lines": [
            'local atlasPatchedFiles = { ["Modules/Build.lua"] = true, ["Modules/Main.lua"] = true, ["UpdateCheck.lua"] = true }',
            "for index = #updateFiles, 1, -1 do",
            "\tlocal data = updateFiles[index]",
            "\tlocal localData = localFiles[data.name]",
            "\tif atlasPatchedFiles[data.name] and localData and localData.sha1 == data.sha1 then",
            "\t\ttable.remove(updateFiles, index)",
            "\tend",
            "end",
        ],
    }
]


def git(repo, *args, binary=False):
    result = subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True)
    return result.stdout if binary else result.stdout.decode("utf-8")


def to_legacy(text):
    for match in list(re.finditer(r'^local (\w+) = newClass\("(\w+)"((?:, "\w+")*)\)$', text, re.M)):
        class_var, class_name, parent_text = match.groups()
        parents = re.findall(r'"(\w+)"', parent_text)
        ctor = re.search(rf"^function {class_var}:{class_name}\(([^)]*)\)\n(.*?)\n^end\n", text, re.M | re.S)
        if not ctor:
            raise SystemExit(f"constructor for {class_name} not found")
        params, body = ctor.groups()
        body = re.sub(r"\n\treturn self$", "", body)
        signature = "self" + (", " + params if params.strip() else "")
        header = f'local {class_var} = newClass("{class_name}"{parent_text}, function({signature})\n{body}\nend)'
        text = text[:ctor.start()] + text[ctor.end():]
        text = text.replace(match.group(0), header, 1)
        for parent in parents:
            text = text.replace(f"self:{parent}(", f"self.{parent}(")
    text = re.sub(r'new\("(\w+)"\):\1\(\)', r'new("\1")', text)
    text = re.sub(r'new\("(\w+)"\):\1\(', r'new("\1", ', text)
    return text


def hook_ops(repo, base, ref, path):
    diff = git(repo, "diff", "-U1", f"{base}..{ref}", "--", path)
    ops = []
    lines = diff.splitlines()
    index = 0
    while index < len(lines):
        if not lines[index].startswith("@@"):
            index += 1
            continue
        index += 1
        hunk = []
        while index < len(lines) and not lines[index].startswith("@@") and not lines[index].startswith("diff "):
            hunk.append(lines[index])
            index += 1
        position = 0
        while position < len(hunk):
            if hunk[position][:1] not in "+-":
                position += 1
                continue
            before = hunk[position - 1][1:] if position > 0 else None
            removed, added = [], []
            while position < len(hunk) and hunk[position][:1] in "+-":
                (removed if hunk[position][0] == "-" else added).append(hunk[position][1:])
                position += 1
            after = hunk[position][1:] if position < len(hunk) else None
            if not removed:
                if before is not None and before.strip():
                    ops.append({"type": "insertAfter", "anchor": before, "lines": added})
                elif after is not None and after.strip():
                    ops.append({"type": "insertBefore", "anchor": after, "lines": added})
                else:
                    raise SystemExit(f"no usable anchor in {path}")
            elif len(removed) == 1 and len(added) == 1 and added[0].startswith(removed[0]):
                ops.append({"type": "append", "suffix": removed[0].strip()[-60:], "text": added[0][len(removed[0]):]})
            elif len(removed) == 1 and len(added) == 1:
                ops.append({"type": "replace", "old": removed[0], "new": added[0]})
            else:
                raise SystemExit(f"unsupported change shape in {path}")
    return ops


def legacy_ops(ops):
    converted = json.loads(json.dumps(ops))
    for op in converted:
        for key in ("anchor", "old", "new", "text", "suffix"):
            if key in op:
                op[key] = to_legacy(op[key])
        if "lines" in op:
            op["lines"] = to_legacy("\n".join(op["lines"])).split("\n")
    return converted


def extract(repo, ref, paths, target):
    data = git(repo, "archive", "--format=tar", ref, "--", *paths, binary=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        archive.extractall(target, filter="data")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--base", default="origin/dev")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    repo = os.path.abspath(args.repo)
    base = git(repo, "merge-base", args.base, args.ref).strip()
    out = os.path.abspath(args.out)
    shutil.rmtree(out, ignore_errors=True)
    staging = os.path.join(out, "staging")
    extract(repo, args.ref, PAYLOAD_PATHS, staging)
    payload = os.path.join(out, "payload")
    shutil.copytree(os.path.join(staging, "src", "TreeData"), os.path.join(payload, "common", "TreeData"))
    os.makedirs(os.path.join(payload, "common", "Data"))
    shutil.copy(os.path.join(staging, "src", "Data", "AtlasTreeVersions.lua"), os.path.join(payload, "common", "Data"))
    for style in ("modern", "legacy"):
        os.makedirs(os.path.join(payload, style, "Classes"))
    for name in sorted(os.listdir(os.path.join(staging, "src", "Classes"))):
        if not name.startswith("Atlas"):
            continue
        with open(os.path.join(staging, "src", "Classes", name), encoding="utf-8") as source:
            text = source.read()
        for style, content in (("modern", text), ("legacy", to_legacy(text))):
            with open(os.path.join(payload, style, "Classes", name), "w", encoding="utf-8", newline="\n") as target:
                target.write(content)
    hooks = {"markers": MARKERS, "modern": {"UpdateCheck.lua": UPDATE_CHECK_OPS}, "legacy": {"UpdateCheck.lua": UPDATE_CHECK_OPS}}
    for path in HOOK_FILES:
        name = os.path.relpath(path, "src").replace(os.sep, "/")
        ops = hook_ops(repo, base, args.ref, path)
        hooks["modern"][name] = ops
        hooks["legacy"][name] = legacy_ops(ops)
    with open(os.path.join(payload, "hooks.json"), "w", encoding="utf-8") as target:
        json.dump(hooks, target, indent=1)
    specs = os.path.join(out, "specs")
    for style in ("modern", "legacy"):
        os.makedirs(os.path.join(specs, style))
    for path in git(repo, "ls-tree", "-r", "--name-only", args.ref, "spec/System").splitlines():
        if SPEC_GLOB.match(path):
            text = git(repo, "show", f"{args.ref}:{path}")
            for style, content in (("modern", text), ("legacy", to_legacy(text))):
                with open(os.path.join(specs, style, os.path.basename(path)), "w", encoding="utf-8") as target:
                    target.write(content)
    version = git(repo, "log", "-1", "--format=%cd-%h", "--date=format:%Y.%m.%d", args.ref).strip()
    with open(os.path.join(payload, "version.txt"), "w") as target:
        target.write(version + "\n")
    shutil.rmtree(staging)
    print(f"payload {version} -> {payload}")


if __name__ == "__main__":
    main()
