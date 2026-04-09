#!/usr/bin/env python3
"""
analyze-java.py — Java AST analysis using tree-sitter.

Commands:
  methods     <file.java>                 List all methods with line numbers and branch count
  branches    <file.java>                 List all conditional branches with line numbers
  callers     <directory> <Class.method>  Find all callers of a method across a directory
  impact      <directory> <ClassName>     Find all files that depend on a class (change impact)
  test-matrix <file.java>                 Generate a test coverage matrix per method

Requirements:
  pip install tree-sitter tree-sitter-language-pack

Examples:
  python analyze-java.py methods src/main/java/com/company/domain/service/OrderService.java
  python analyze-java.py branches src/main/java/com/company/domain/service/OrderService.java
  python analyze-java.py callers src/main/java OrderService.create
  python analyze-java.py impact src/main/java OrderRepository
  python analyze-java.py test-matrix src/main/java/com/company/domain/service/OrderService.java
"""

import sys
import os
import json
from pathlib import Path

try:
    from tree_sitter_language_pack import get_parser
except ImportError:
    print(
        "ERROR: Required packages not found.\n"
        "Install with: pip install tree-sitter tree-sitter-language-pack",
        file=sys.stderr,
    )
    sys.exit(1)

_JAVA_PARSER = get_parser("java")

# ─── Core helpers ────────────────────────────────────────────────────────────


def _parse(file_path: str):
    """Return (tree, source_str) for a Java file."""
    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        source = f.read()
    tree = _JAVA_PARSER.parse(bytes(source, "utf-8"))
    return tree, source


def _text(node, source: str) -> str:
    return source[node.start_byte : node.end_byte]


def _walk(root):
    """DFS generator over all nodes."""
    stack = [root]
    while stack:
        node = stack.pop()
        yield node
        stack.extend(reversed(node.children))


def _find_all(root, *types):
    return [n for n in _walk(root) if n.type in types]


# ─── Branch counting ─────────────────────────────────────────────────────────

_BRANCH_TYPES = {
    "if_statement",
    "switch_expression",
    "switch_block_statement_group",
    "catch_clause",
    "conditional_expression",  # ternary
    "for_statement",
    "enhanced_for_statement",
    "while_statement",
    "do_statement",
}


def _count_branches(root) -> int:
    """Count distinct branching constructs inside a node."""
    count = 0
    for node in _walk(root):
        if node.type in _BRANCH_TYPES:
            count += 1
        # else-if counts as an extra branch
        if node.type == "else" and node.children:
            if any(c.type == "if_statement" for c in node.children):
                count += 1
    return count


def _collect_branches(root, source: str) -> list[dict]:
    results = []
    for node in _walk(root):
        if node.type in _BRANCH_TYPES:
            results.append(
                {
                    "type": node.type.replace("_", "-"),
                    "line": node.start_point[0] + 1,
                    "text": _text(node, source)[:100].replace("\n", " "),
                }
            )
    return results


# ─── Method extraction ───────────────────────────────────────────────────────


def extract_methods(file_path: str) -> list[dict]:
    """Return metadata for every method in a Java file."""
    tree, source = _parse(file_path)
    results = []

    for node in _find_all(tree.root_node, "method_declaration", "constructor_declaration"):
        # name
        name_node = next((c for c in node.children if c.type == "identifier"), None)
        name = _text(name_node, source) if name_node else "<unknown>"

        # return type (method only)
        ret = ""
        if node.type == "method_declaration":
            for c in node.children:
                if c.type in ("type_identifier", "void_type", "generic_type", "array_type",
                               "integral_type", "floating_point_type", "boolean_type"):
                    ret = _text(c, source)
                    break

        # parameters
        params_node = next((c for c in node.children if c.type == "formal_parameters"), None)
        params = _text(params_node, source) if params_node else "()"

        # modifiers
        mods_node = next((c for c in node.children if c.type == "modifiers"), None)
        mods = _text(mods_node, source).replace("\n", " ") if mods_node else ""

        # body branch count
        body_node = next((c for c in node.children if c.type == "block"), None)
        branches = _count_branches(body_node) if body_node else 0

        results.append(
            {
                "name": name,
                "modifiers": mods,
                "return_type": ret,
                "parameters": params,
                "signature": f"{mods} {ret} {name}{params}".strip(),
                "line_start": node.start_point[0] + 1,
                "line_end": node.end_point[0] + 1,
                "branch_count": branches,
                "min_tests_needed": max(1, branches + 1),
            }
        )

    return results


# ─── Caller search ───────────────────────────────────────────────────────────


def find_callers(directory: str, class_name: str, method_name: str) -> list[dict]:
    """
    Find all Java files in *directory* that contain a call to
    `class_name.method_name(...)` or any invocation named `method_name`.
    """
    callers = []
    dir_path = Path(directory)

    for java_file in sorted(dir_path.rglob("*.java")):
        try:
            tree, source = _parse(str(java_file))
        except Exception:
            continue

        for node in _find_all(tree.root_node, "method_invocation"):
            # Collect identifier children
            ids = [_text(c, source) for c in node.children if c.type == "identifier"]
            # ids[0] may be method name (no receiver), or ids[-1] is method name with receiver
            if method_name in ids:
                callers.append(
                    {
                        "file": str(java_file),
                        "line": node.start_point[0] + 1,
                        "call": _text(node, source)[:120].replace("\n", " "),
                    }
                )

    return callers


# ─── Impact analysis ─────────────────────────────────────────────────────────


def find_impact(directory: str, class_name: str) -> list[dict]:
    """
    Find all Java files that reference *class_name* (import, field, parameter, etc.).
    Returns files sorted by reference count descending.
    """
    impacts = []
    dir_path = Path(directory)

    for java_file in sorted(dir_path.rglob("*.java")):
        if java_file.stem == class_name:
            continue  # skip the class itself
        try:
            with open(java_file, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except Exception:
            continue

        refs = [
            {"line": i + 1, "text": line.rstrip()}
            for i, line in enumerate(lines)
            if class_name in line
        ]

        if refs:
            impacts.append(
                {
                    "file": str(java_file),
                    "reference_count": len(refs),
                    "references": refs[:10],  # cap to avoid noise
                }
            )

    return sorted(impacts, key=lambda x: -x["reference_count"])


# ─── Test matrix ─────────────────────────────────────────────────────────────


def generate_test_matrix(file_path: str) -> dict:
    """
    Build a test-coverage matrix:
    for each method — list branches and suggest test-method names.
    """
    tree, source = _parse(file_path)

    # Detect class name
    class_name = Path(file_path).stem
    class_nodes = _find_all(tree.root_node, "class_declaration")
    if class_nodes:
        id_node = next((c for c in class_nodes[0].children if c.type == "identifier"), None)
        if id_node:
            class_name = _text(id_node, source)

    methods = extract_methods(file_path)
    all_branches = _collect_branches(tree.root_node, source)

    method_rows = []
    for m in methods:
        method_branches = [
            b for b in all_branches if m["line_start"] <= b["line"] <= m["line_end"]
        ]

        # Generate suggested test names
        suggestions = [f"should_completeSuccessfully_when_inputIsValid  // {m['name']} happy path"]
        for i, b in enumerate(method_branches, 1):
            suggestions.append(
                f"should_handle{b['type'].title().replace('-', '')}_{i}  // line {b['line']}: {b['text'][:60]}"
            )

        method_rows.append(
            {
                "name": m["name"],
                "signature": m["signature"],
                "lines": f"{m['line_start']}-{m['line_end']}",
                "branch_count": m["branch_count"],
                "min_tests_needed": m["min_tests_needed"],
                "suggested_tests": suggestions,
            }
        )

    return {"class": class_name, "file": file_path, "methods": method_rows}


# ─── Pretty printers ─────────────────────────────────────────────────────────


def print_test_matrix(matrix: dict) -> None:
    print(f"\n## Test Coverage Matrix — {matrix['class']}")
    print(f"File: {matrix['file']}\n")
    total = 0
    for m in matrix["methods"]:
        print(f"### {m['name']}  (lines {m['lines']})")
        print(f"Branches: {m['branch_count']}  |  Min tests needed: {m['min_tests_needed']}\n")
        for s in m["suggested_tests"]:
            print(f"  [ ] {s}")
        print()
        total += m["min_tests_needed"]
    print(f"Total minimum tests across all methods: {total}")


# ─── CLI ─────────────────────────────────────────────────────────────────────


def _require_args(n: int, usage: str) -> None:
    if len(sys.argv) < n:
        print(f"Usage: {usage}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    cmd = sys.argv[1]

    if cmd == "methods":
        _require_args(3, "analyze-java.py methods <file.java>")
        print(json.dumps(extract_methods(sys.argv[2]), indent=2))

    elif cmd == "branches":
        _require_args(3, "analyze-java.py branches <file.java>")
        tree, source = _parse(sys.argv[2])
        print(json.dumps(_collect_branches(tree.root_node, source), indent=2))

    elif cmd == "callers":
        _require_args(4, "analyze-java.py callers <directory> <ClassName.method>")
        target = sys.argv[3]
        if "." in target:
            class_name, method_name = target.rsplit(".", 1)
        else:
            class_name, method_name = target, target
        results = find_callers(sys.argv[2], class_name, method_name)
        print(json.dumps(results, indent=2))
        print(f"\nFound {len(results)} caller(s) of {target}", file=sys.stderr)

    elif cmd == "impact":
        _require_args(4, "analyze-java.py impact <directory> <ClassName>")
        results = find_impact(sys.argv[2], sys.argv[3])
        print(json.dumps(results, indent=2))
        print(
            f"\n{len(results)} file(s) reference {sys.argv[3]} — review all before changing it.",
            file=sys.stderr,
        )

    elif cmd == "test-matrix":
        _require_args(3, "analyze-java.py test-matrix <file.java>")
        matrix = generate_test_matrix(sys.argv[2])
        print_test_matrix(matrix)

    else:
        print(f"Unknown command: {cmd}\n", file=sys.stderr)
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
