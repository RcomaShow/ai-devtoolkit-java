#!/usr/bin/env python3
"""
analyze-java.py — Java AST and legacy flow analysis using tree-sitter.

Commands:
  methods       <file.java>                  List all methods with line numbers and branch count
  branches      <file.java>                  List all conditional branches with line numbers
  callers       <directory> <Class.method>   Find all callers of a method across a directory
  impact        <directory> <ClassName>      Find all files that depend on a class (change impact)
  deps          <file.java>                  Extract direct class dependencies and layer profile
  legacy-xhtml  <source-root> <file.xhtml>   Trace JSF/Facelets entrypoint -> bean -> downstream layers
  test-matrix   <file.java>                  Generate a test coverage matrix per method

Requirements:
  pip install tree-sitter tree-sitter-language-pack
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict, deque
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

_BRANCH_TYPES = {
    "if_statement",
    "switch_expression",
    "switch_block_statement_group",
    "catch_clause",
    "conditional_expression",
    "for_statement",
    "enhanced_for_statement",
    "while_statement",
    "do_statement",
}

_TYPE_NODE_TYPES = {
    "type_identifier",
    "void_type",
    "generic_type",
    "array_type",
    "integral_type",
    "floating_point_type",
    "boolean_type",
    "scoped_type_identifier",
}

_LAYER_ORDER = {
    "xhtml": 0,
    "backing-bean": 1,
    "rest-resource": 1,
    "dto": 1,
    "service": 2,
    "mapper": 2,
    "repository": 3,
    "external-client": 3,
    "entity": 4,
    "config": 5,
    "unknown": 6,
}

_EL_PATTERN = re.compile(r"#\{([^}]+)\}")
_PACKAGE_PATTERN = re.compile(r"^\s*package\s+([\w.]+)\s*;", re.MULTILINE)
_ANNOTATION_PATTERN = re.compile(r"@(\w+)")
_NAMED_PATTERN = re.compile(r"@Named\(\s*\"([^\"]+)\"\s*\)")
_MANAGED_BEAN_PATTERN = re.compile(
    r"@ManagedBean(?:\(\s*(?:name\s*=\s*)?\"([^\"]+)\".*?\))?",
    re.DOTALL,
)


def _parse(file_path: str):
    with open(file_path, "r", encoding="utf-8", errors="replace") as handle:
        source = handle.read()
    tree = _JAVA_PARSER.parse(source.encode("utf-8"))
    return tree, source


def _text(node, source: str) -> str:
    return source[node.start_byte : node.end_byte]


def _walk(root):
    stack = [root]
    while stack:
        node = stack.pop()
        yield node
        stack.extend(reversed(node.children))


def _find_all(root, *types):
    return [node for node in _walk(root) if node.type in types]


def _count_branches(root) -> int:
    count = 0
    for node in _walk(root):
        if node.type in _BRANCH_TYPES:
            count += 1
        if node.type == "else" and any(child.type == "if_statement" for child in node.children):
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


def _simple_type_name(type_text: str) -> str:
    normalized = re.sub(r"<.*?>", "", type_text)
    normalized = normalized.replace("[]", "").strip()
    normalized = normalized.replace("? extends ", "").replace("? super ", "")
    if "." in normalized:
        normalized = normalized.split(".")[-1]
    return normalized


def _decapitalize(name: str) -> str:
    if not name:
        return name
    return name[:1].lower() + name[1:]


def _extract_first_type(node, source: str) -> str | None:
    for child in node.children:
        if child.type in _TYPE_NODE_TYPES:
            return _simple_type_name(_text(child, source))
    return None


def _extract_field_dependencies(class_node, source: str) -> tuple[dict[str, str], list[str]]:
    field_map: dict[str, str] = {}
    dependencies: list[str] = []
    for field_node in _find_all(class_node, "field_declaration"):
        field_type = _extract_first_type(field_node, source)
        if not field_type:
            continue
        dependencies.append(field_type)
        for declarator in _find_all(field_node, "variable_declarator"):
            identifier = next((child for child in declarator.children if child.type == "identifier"), None)
            if identifier is not None:
                field_map[_text(identifier, source)] = field_type
    return field_map, dependencies


def _extract_constructor_dependencies(class_node, source: str) -> list[str]:
    dependencies: list[str] = []
    for constructor_node in _find_all(class_node, "constructor_declaration"):
        params = next((child for child in constructor_node.children if child.type == "formal_parameters"), None)
        if params is None:
            continue
        for param in _find_all(params, "formal_parameter"):
            param_type = _extract_first_type(param, source)
            if param_type:
                dependencies.append(param_type)
    return dependencies


def _extract_imports(root, source: str) -> list[str]:
    imports: list[str] = []
    for import_node in _find_all(root, "import_declaration"):
        text = _text(import_node, source)
        match = re.search(r"([A-Z][\w]*)\s*;", text)
        if match:
            imports.append(match.group(1))
    return imports


def _extract_class_name(root, source: str) -> tuple[str, object | None]:
    class_nodes = _find_all(root, "class_declaration", "interface_declaration", "enum_declaration")
    if not class_nodes:
        return Path("unknown").stem, None
    class_node = class_nodes[0]
    identifier = next((child for child in class_node.children if child.type == "identifier"), None)
    return (_text(identifier, source) if identifier else "<unknown>", class_node)


def _classify_layer(class_name: str, annotations: list[str], imports: list[str], source: str) -> str:
    annotation_set = set(annotations)
    import_set = set(imports)

    if class_name.endswith("Bean") or {"ManagedBean", "ViewScoped", "SessionScoped", "RequestScoped"} & annotation_set:
        return "backing-bean"
    if "Named" in annotation_set and "Path" not in annotation_set and class_name.endswith("Bean"):
        return "backing-bean"
    if "Path" in annotation_set:
        return "rest-resource"
    if class_name.endswith("Dto") or class_name.endswith("Request") or class_name.endswith("Response"):
        return "dto"
    if class_name.endswith("Repository") or class_name.endswith("Dao"):
        return "repository"
    if class_name.endswith("Service") or class_name.endswith("Ejb") or {"Stateless", "Stateful", "Singleton"} & annotation_set:
        return "service"
    if class_name.endswith("Mapper") or class_name.endswith("Translator"):
        return "mapper"
    if class_name.endswith("Client") or "RestClient" in import_set or "WebServiceRef" in annotation_set:
        return "external-client"
    if class_name.endswith("Entity") or "Entity" in annotation_set:
        return "entity"
    if class_name.endswith("Config"):
        return "config"
    if "PanacheRepository" in source or "EntityManager" in source:
        return "repository"
    return "unknown"


def extract_methods(file_path: str) -> list[dict]:
    tree, source = _parse(file_path)
    results = []

    for node in _find_all(tree.root_node, "method_declaration", "constructor_declaration"):
        identifier = next((child for child in node.children if child.type == "identifier"), None)
        name = _text(identifier, source) if identifier else "<unknown>"

        return_type = ""
        if node.type == "method_declaration":
            for child in node.children:
                if child.type in _TYPE_NODE_TYPES or child.type == "void_type":
                    return_type = _text(child, source)
                    break

        params = next((child for child in node.children if child.type == "formal_parameters"), None)
        modifiers = next((child for child in node.children if child.type == "modifiers"), None)
        body = next((child for child in node.children if child.type == "block"), None)

        branch_count = _count_branches(body) if body else 0
        params_text = _text(params, source) if params else "()"
        modifiers_text = _text(modifiers, source).replace("\n", " ") if modifiers else ""

        results.append(
            {
                "name": name,
                "modifiers": modifiers_text,
                "return_type": return_type,
                "parameters": params_text,
                "signature": f"{modifiers_text} {return_type} {name}{params_text}".strip(),
                "line_start": node.start_point[0] + 1,
                "line_end": node.end_point[0] + 1,
                "branch_count": branch_count,
                "min_tests_needed": max(1, branch_count + 1),
            }
        )

    return results


def extract_class_profile(file_path: str) -> dict:
    tree, source = _parse(file_path)
    class_name, class_node = _extract_class_name(tree.root_node, source)
    if class_node is None:
        raise ValueError(f"No class declaration found in {file_path}")

    package_match = _PACKAGE_PATTERN.search(source)
    package_name = package_match.group(1) if package_match else ""
    annotations = sorted(set(_ANNOTATION_PATTERN.findall(source)))
    imports = sorted(set(_extract_imports(tree.root_node, source)))
    field_map, field_dependencies = _extract_field_dependencies(class_node, source)
    constructor_dependencies = _extract_constructor_dependencies(class_node, source)

    bean_names = set(_NAMED_PATTERN.findall(source))
    bean_names.update(name for name in _MANAGED_BEAN_PATTERN.findall(source) if name)
    if {"ManagedBean", "Named", "ViewScoped", "SessionScoped", "RequestScoped"} & set(annotations) or class_name.endswith("Bean"):
        bean_names.add(_decapitalize(class_name))

    dependencies = sorted(
        {
            dep
            for dep in (field_dependencies + constructor_dependencies + imports)
            if dep and dep != class_name
        }
    )

    return {
        "class_name": class_name,
        "file": str(Path(file_path).resolve()),
        "package": package_name,
        "annotations": annotations,
        "bean_names": sorted(bean_names),
        "fields": field_map,
        "imports": imports,
        "dependencies": dependencies,
        "layer": _classify_layer(class_name, annotations, imports, source),
        "method_count": len(extract_methods(file_path)),
    }


def find_callers(directory: str, class_name: str, method_name: str) -> list[dict]:
    callers = []
    for java_file in sorted(Path(directory).rglob("*.java")):
        try:
            tree, source = _parse(str(java_file))
        except Exception:
            continue

        for node in _find_all(tree.root_node, "method_invocation"):
            identifiers = [_text(child, source) for child in node.children if child.type == "identifier"]
            if method_name in identifiers:
                callers.append(
                    {
                        "file": str(java_file),
                        "line": node.start_point[0] + 1,
                        "call": _text(node, source)[:120].replace("\n", " "),
                    }
                )
    return callers


def find_impact(directory: str, class_name: str) -> list[dict]:
    impacts = []
    for java_file in sorted(Path(directory).rglob("*.java")):
        if java_file.stem == class_name:
            continue
        try:
            with open(java_file, "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.readlines()
        except Exception:
            continue
        references = [
            {"line": index + 1, "text": line.rstrip()}
            for index, line in enumerate(lines)
            if class_name in line
        ]
        if references:
            impacts.append(
                {
                    "file": str(java_file),
                    "reference_count": len(references),
                    "references": references[:10],
                }
            )
    return sorted(impacts, key=lambda item: -item["reference_count"])


def generate_test_matrix(file_path: str) -> dict:
    tree, source = _parse(file_path)
    methods = extract_methods(file_path)
    branches = _collect_branches(tree.root_node, source)
    class_name, _ = _extract_class_name(tree.root_node, source)

    method_rows = []
    for method in methods:
        method_branches = [
            branch
            for branch in branches
            if method["line_start"] <= branch["line"] <= method["line_end"]
        ]
        suggestions = [f"should_completeSuccessfully_when_inputIsValid  // {method['name']} happy path"]
        for index, branch in enumerate(method_branches, 1):
            suggestions.append(
                f"should_handle{branch['type'].title().replace('-', '')}_{index}  // line {branch['line']}: {branch['text'][:60]}"
            )
        method_rows.append(
            {
                "name": method["name"],
                "signature": method["signature"],
                "lines": f"{method['line_start']}-{method['line_end']}",
                "branch_count": method["branch_count"],
                "min_tests_needed": method["min_tests_needed"],
                "suggested_tests": suggestions,
            }
        )

    return {"class": class_name, "file": file_path, "methods": method_rows}


def build_java_index(source_root: str) -> tuple[list[dict], dict[str, list[dict]], dict[str, list[dict]]]:
    profiles = []
    class_map: dict[str, list[dict]] = defaultdict(list)
    bean_map: dict[str, list[dict]] = defaultdict(list)

    for java_file in sorted(Path(source_root).rglob("*.java")):
        try:
            profile = extract_class_profile(str(java_file))
        except Exception:
            continue
        profiles.append(profile)
        class_map[profile["class_name"]].append(profile)
        for bean_name in profile["bean_names"]:
            bean_map[bean_name].append(profile)

    return profiles, class_map, bean_map


def parse_xhtml_bindings(xhtml_file: str) -> list[dict]:
    text = Path(xhtml_file).read_text(encoding="utf-8", errors="replace")
    bindings = []
    seen = set()
    for match in _EL_PATTERN.finditer(text):
        expression = match.group(1).strip()
        if expression in seen:
            continue
        seen.add(expression)
        bean = re.split(r"[.\[]", expression, maxsplit=1)[0]
        member = None
        if "." in expression:
            member = expression.split(".", 1)[1]
        bindings.append({"expression": expression, "bean": bean, "member": member})
    return bindings


def build_legacy_xhtml_flow(source_root: str, xhtml_file: str) -> dict:
    profiles, class_map, bean_map = build_java_index(source_root)
    bindings = parse_xhtml_bindings(xhtml_file)
    entry_beans = sorted({binding["bean"] for binding in bindings})

    resolved_entries = []
    unresolved_beans = []
    ambiguous_beans = []
    queue = deque()
    visited: set[str] = set()
    vertical_edges = []
    horizontal_edges = []
    ambiguous_dependencies = []
    reachable_profiles: dict[str, dict] = {}

    for bean_name in entry_beans:
        matches = bean_map.get(bean_name, [])
        if len(matches) == 1:
            profile = matches[0]
            resolved_entries.append({
                "bean": bean_name,
                "class": profile["class_name"],
                "file": profile["file"],
                "layer": profile["layer"],
            })
            queue.append(profile)
            vertical_edges.append(
                {
                    "from": Path(xhtml_file).name,
                    "fromLayer": "xhtml",
                    "to": profile["class_name"],
                    "toLayer": profile["layer"],
                    "kind": "binding",
                }
            )
        elif len(matches) > 1:
            ambiguous_beans.append(
                {
                    "bean": bean_name,
                    "matches": [match["file"] for match in matches],
                }
            )
        else:
            unresolved_beans.append(bean_name)

    while queue:
        current = queue.popleft()
        current_key = current["file"]
        if current_key in visited:
            continue
        visited.add(current_key)
        reachable_profiles[current_key] = current

        for dependency_name in current["dependencies"]:
            matches = class_map.get(dependency_name, [])
            if len(matches) == 1:
                target = matches[0]
                edge = {
                    "from": current["class_name"],
                    "fromLayer": current["layer"],
                    "to": target["class_name"],
                    "toLayer": target["layer"],
                    "kind": "dependency",
                }
                if _LAYER_ORDER.get(current["layer"], 99) == _LAYER_ORDER.get(target["layer"], 99):
                    horizontal_edges.append(edge)
                else:
                    vertical_edges.append(edge)
                if target["file"] not in visited:
                    queue.append(target)
            elif len(matches) > 1:
                ambiguous_dependencies.append(
                    {
                        "from": current["class_name"],
                        "dependency": dependency_name,
                        "matches": [match["file"] for match in matches],
                    }
                )

    layer_groups: dict[str, list[dict]] = defaultdict(list)
    layer_groups["xhtml"].append({"name": Path(xhtml_file).name, "file": str(Path(xhtml_file).resolve())})
    for profile in sorted(reachable_profiles.values(), key=lambda item: (_LAYER_ORDER.get(item["layer"], 99), item["class_name"])):
        layer_groups[profile["layer"]].append({
            "name": profile["class_name"],
            "file": profile["file"],
        })

    return {
        "entryFile": str(Path(xhtml_file).resolve()),
        "bindings": bindings,
        "resolvedEntryBeans": resolved_entries,
        "unresolvedBeans": unresolved_beans,
        "ambiguousBeans": ambiguous_beans,
        "verticalLayers": [
            {"layer": layer, "nodes": nodes}
            for layer, nodes in sorted(layer_groups.items(), key=lambda item: _LAYER_ORDER.get(item[0], 99))
        ],
        "verticalEdges": vertical_edges,
        "horizontalDependencies": horizontal_edges,
        "ambiguousDependencies": ambiguous_dependencies,
    }


def print_test_matrix(matrix: dict) -> None:
    print(f"\n## Test Coverage Matrix — {matrix['class']}")
    print(f"File: {matrix['file']}\n")
    total = 0
    for method in matrix["methods"]:
        print(f"### {method['name']}  (lines {method['lines']})")
        print(f"Branches: {method['branch_count']}  |  Min tests needed: {method['min_tests_needed']}\n")
        for suggestion in method["suggested_tests"]:
            print(f"  [ ] {suggestion}")
        print()
        total += method["min_tests_needed"]
    print(f"Total minimum tests across all methods: {total}")


def _require_args(count: int, usage: str) -> None:
    if len(sys.argv) < count:
        print(f"Usage: {usage}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    command = sys.argv[1]

    if command == "methods":
        _require_args(3, "analyze-java.py methods <file.java>")
        print(json.dumps(extract_methods(sys.argv[2]), indent=2))

    elif command == "branches":
        _require_args(3, "analyze-java.py branches <file.java>")
        tree, source = _parse(sys.argv[2])
        print(json.dumps(_collect_branches(tree.root_node, source), indent=2))

    elif command == "callers":
        _require_args(4, "analyze-java.py callers <directory> <ClassName.method>")
        target = sys.argv[3]
        if "." in target:
            class_name, method_name = target.rsplit(".", 1)
        else:
            class_name, method_name = target, target
        results = find_callers(sys.argv[2], class_name, method_name)
        print(json.dumps(results, indent=2))
        print(f"\nFound {len(results)} caller(s) of {target}", file=sys.stderr)

    elif command == "impact":
        _require_args(4, "analyze-java.py impact <directory> <ClassName>")
        results = find_impact(sys.argv[2], sys.argv[3])
        print(json.dumps(results, indent=2))
        print(f"\n{len(results)} file(s) reference {sys.argv[3]} — review all before changing it.", file=sys.stderr)

    elif command == "deps":
        _require_args(3, "analyze-java.py deps <file.java>")
        print(json.dumps(extract_class_profile(sys.argv[2]), indent=2))

    elif command == "legacy-xhtml":
        _require_args(4, "analyze-java.py legacy-xhtml <source-root> <file.xhtml>")
        report = build_legacy_xhtml_flow(sys.argv[2], sys.argv[3])
        print(json.dumps(report, indent=2))
        print(
            f"\nResolved {len(report['resolvedEntryBeans'])} entry bean(s), {len(report['verticalEdges'])} vertical edge(s), and {len(report['horizontalDependencies'])} horizontal dependency edge(s).",
            file=sys.stderr,
        )

    elif command == "test-matrix":
        _require_args(3, "analyze-java.py test-matrix <file.java>")
        print_test_matrix(generate_test_matrix(sys.argv[2]))

    else:
        print(f"Unknown command: {command}\n", file=sys.stderr)
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()