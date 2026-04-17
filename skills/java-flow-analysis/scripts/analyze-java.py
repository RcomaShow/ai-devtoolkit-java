#!/usr/bin/env python3
"""
analyze-java.py — Java AST and XHTML-to-database flow analysis using tree-sitter.

Commands:
  methods         <file.java>                  List all methods with line numbers and branch count
  branches        <file.java>                  List all conditional branches with line numbers
  callers         <directory> <Class.method>   Find all callers of a method across a directory
  impact          <directory> <ClassName>      Find all files that depend on a class (change impact)
  deps            <file.java>                  Extract direct class dependencies and layer profile
  legacy-xhtml    <source-root> <file.xhtml>   Compatibility alias for the richer XHTML -> DB graph report
  xhtml-db-graph  <source-root> <file.xhtml>   Build a JSON dependency graph from XHTML bindings to DB touchpoints
  test-matrix     <file.java>                  Generate a test coverage matrix per method

Requirements:
  pip install tree-sitter tree-sitter-language-pack
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
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
try:
    _HTML_PARSER = get_parser("html")
except Exception:
    _HTML_PARSER = None

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
    "xml-artifact": 4,
    "entity": 5,
    "database": 6,
    "config": 7,
    "unknown": 8,
}

_EL_PATTERN = re.compile(r"#\{([^}]+)\}")
_PACKAGE_PATTERN = re.compile(r"^\s*package\s+([\w.]+)\s*;", re.MULTILINE)
_ANNOTATION_PATTERN = re.compile(r"@(\w+)")
_NAMED_PATTERN = re.compile(r"@Named\(\s*\"([^\"]+)\"\s*\)")
_MANAGED_BEAN_PATTERN = re.compile(
    r"@ManagedBean(?:\(\s*(?:name\s*=\s*)?\"([^\"]+)\".*?\))?",
    re.DOTALL,
)
_XML_NAMESPACE_PATTERN = re.compile(r'\bxmlns:([A-Za-z_][\w.-]*)\s*=\s*"([^"]+)"')
_PREFIXED_TAG_PATTERN = re.compile(r"<\s*([A-Za-z_][\w.-]*):([A-Za-z_][\w.-]*)\b")
_XHTML_ATTRIBUTE_BINDING_PATTERN = re.compile(r'([:@A-Za-z_][\w:.-]*)\s*=\s*"([^"]*#\{[^"]+\}[^"]*)"')
_XHTML_FILE_REFERENCE_PATTERN = re.compile(r'\b(?:src|template|file)\s*=\s*"([^"]+\.xhtml(?:[?#][^"]*)?)"')
_CDATA_PATTERN = re.compile(r"<!\[CDATA\[(.*?)\]\]>", re.DOTALL | re.IGNORECASE)
_XML_SQL_TAG_PATTERN = re.compile(
    r"<\s*(?:sql-query|named-native-query|query|sql|select|insert|update|delete|statement)\b",
    re.IGNORECASE,
)
_CLASS_LITERAL_PATTERN = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\.class\b")
_SQL_KEYWORD_PATTERN = re.compile(r"\b(select|insert|update|delete|merge)\b", re.IGNORECASE)
_SQL_TABLE_PATTERN = re.compile(
    r"\b(?:from|join|update|into|delete\s+from|merge\s+into)\s+([A-Za-z_][\w$#.]*)\b(?:\s+[A-Za-z_][\w$#.]*)?",
    re.IGNORECASE,
)
_TABLE_ANNOTATION_PATTERN = re.compile(r"@(Table|JoinTable|SecondaryTable)\s*\((.*?)\)", re.DOTALL)
_NAME_ARGUMENT_PATTERN = re.compile(r'\bname\s*=\s*"([^\"]+)"')
_DECLARATION_TEMPLATE = r"\b(?:class|interface|enum)\s+{class_name}\b(?P<tail>[^{{]*)\{{"


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


def _dedupe_keep_order(values) -> list:
    seen = set()
    ordered = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        ordered.append(value)
    return ordered


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
        return "<unknown>", None
    class_node = class_nodes[0]
    identifier = next((child for child in class_node.children if child.type == "identifier"), None)
    return (_text(identifier, source) if identifier else "<unknown>", class_node)


def _extract_declaration_dependencies(class_name: str, source: str) -> list[str]:
    pattern = re.compile(_DECLARATION_TEMPLATE.format(class_name=re.escape(class_name)), re.DOTALL)
    match = pattern.search(source)
    if match is None:
        return []

    tail = " ".join(match.group("tail").split())
    dependencies = []

    extends_match = re.search(r"\bextends\s+(.+?)(?:\bimplements\b|$)", tail)
    if extends_match:
        dependencies.extend(
            _simple_type_name(token.strip())
            for token in extends_match.group(1).split(",")
            if token.strip()
        )

    implements_match = re.search(r"\bimplements\s+(.+)$", tail)
    if implements_match:
        dependencies.extend(
            _simple_type_name(token.strip())
            for token in implements_match.group(1).split(",")
            if token.strip()
        )

    return [dependency for dependency in dependencies if dependency and dependency != class_name]


def _extract_class_literal_dependencies(source: str, class_name: str) -> list[str]:
    return [
        match.group(1)
        for match in _CLASS_LITERAL_PATTERN.finditer(source)
        if match.group(1) != class_name
    ]


def _extract_string_literals(root, source: str) -> list[str]:
    strings = []
    for node in _find_all(root, "string_literal"):
        literal = _text(node, source)
        if len(literal) >= 2 and literal[0] == '"' and literal[-1] == '"':
            literal = literal[1:-1]
        try:
            literal = bytes(literal, "utf-8").decode("unicode_escape")
        except Exception:
            pass
        strings.append(literal)
    return strings


def _normalize_table_name(table_name: str) -> str:
    return table_name.strip().strip('"').strip("'")


def _extract_sql_tables(query_strings: list[str]) -> list[str]:
    tables = []
    for query in query_strings:
        for match in _SQL_TABLE_PATTERN.finditer(query):
            normalized = _normalize_table_name(match.group(1))
            if normalized:
                tables.append(normalized)
    return _dedupe_keep_order(tables)


def _extract_annotated_tables(source: str) -> list[str]:
    tables = []
    for _, arguments in _TABLE_ANNOTATION_PATTERN.findall(source):
        for match in _NAME_ARGUMENT_PATTERN.findall(arguments):
            normalized = _normalize_table_name(match)
            if normalized:
                tables.append(normalized)
    return _dedupe_keep_order(tables)


def _detect_persistence_features(source: str, imports: list[str], annotations: list[str]) -> list[str]:
    features = []
    annotation_set = set(annotations)
    import_set = set(imports)

    checks = [
        ("jpa-entity", bool({"Entity", "Embeddable", "MappedSuperclass"} & annotation_set)),
        ("panache", "PanacheRepository" in source or "PanacheEntity" in source),
        ("entity-manager", "EntityManager" in source or "EntityManager" in import_set),
        ("jdbc", any(token in source for token in ["DataSource", "PreparedStatement", "ResultSet", "JdbcTemplate"])),
        ("native-query", "createNativeQuery" in source or "NamedNativeQuery" in source),
        ("orm-query", "createQuery" in source or "NamedQuery" in source or "TypedQuery" in source),
    ]

    for feature_name, enabled in checks:
        if enabled:
            features.append(feature_name)
    return features


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
    declaration_dependencies = _extract_declaration_dependencies(class_name, source)
    class_literal_dependencies = _extract_class_literal_dependencies(source, class_name)

    bean_names = set(_NAMED_PATTERN.findall(source))
    bean_names.update(name for name in _MANAGED_BEAN_PATTERN.findall(source) if name)
    if {"ManagedBean", "Named", "ViewScoped", "SessionScoped", "RequestScoped"} & set(annotations) or class_name.endswith("Bean"):
        bean_names.add(_decapitalize(class_name))

    dependencies = sorted(
        {
            dependency
            for dependency in (
                field_dependencies
                + constructor_dependencies
                + imports
                + declaration_dependencies
                + class_literal_dependencies
            )
            if dependency and dependency != class_name
        }
    )

    dependency_sources: dict[str, set[str]] = defaultdict(set)
    for dependency in field_dependencies:
        if dependency and dependency != class_name:
            dependency_sources[dependency].add("field")
    for dependency in constructor_dependencies:
        if dependency and dependency != class_name:
            dependency_sources[dependency].add("constructor")
    for dependency in declaration_dependencies:
        if dependency and dependency != class_name:
            dependency_sources[dependency].add("declaration")
    for dependency in class_literal_dependencies:
        if dependency and dependency != class_name:
            dependency_sources[dependency].add("class-literal")

    flow_dependencies = sorted(dependency_sources)
    layer = _classify_layer(class_name, annotations, imports, source)

    string_literals = _extract_string_literals(tree.root_node, source)
    query_strings = [query for query in string_literals if _SQL_KEYWORD_PATTERN.search(query)]
    annotated_tables = _extract_annotated_tables(source)
    sql_tables = _extract_sql_tables(query_strings)
    persistence_features = _detect_persistence_features(source, imports, annotations)
    all_tables = _dedupe_keep_order(annotated_tables + sql_tables)
    has_database_access = bool(all_tables or persistence_features or layer in {"repository", "entity"})

    return {
        "class_name": class_name,
        "type_kind": class_node.type.replace("_declaration", ""),
        "file": str(Path(file_path).resolve()),
        "package": package_name,
        "annotations": annotations,
        "bean_names": sorted(bean_names),
        "fields": field_map,
        "imports": imports,
        "dependencies": dependencies,
        "flow_dependencies": flow_dependencies,
        "dependency_sources": {dependency: sorted(sources) for dependency, sources in dependency_sources.items()},
        "db_touchpoints": {
            "has_database_access": has_database_access,
            "annotated_tables": annotated_tables,
            "sql_tables": sql_tables,
            "tables": all_tables,
            "query_count": len(query_strings),
            "queries": query_strings[:5],
            "persistence_features": persistence_features,
        },
        "layer": layer,
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


def _extract_xml_namespaces(text: str) -> dict[str, str]:
    return {prefix: uri for prefix, uri in _XML_NAMESPACE_PATTERN.findall(text)}


def _collect_xhtml_fragments(text: str) -> list[str]:
    if _HTML_PARSER is None:
        return [text]

    try:
        tree = _HTML_PARSER.parse(text.encode("utf-8"))
    except Exception:
        return [text]

    fragments = []
    seen = set()
    for node in _walk(tree.root_node):
        if node.children:
            continue
        fragment = _text(node, text)
        if "#{" not in fragment:
            continue
        key = (node.start_byte, node.end_byte)
        if key in seen:
            continue
        seen.add(key)
        fragments.append(fragment)
    return fragments or [text]


def _parse_xhtml_bindings_text(text: str, source_file: str) -> list[dict]:
    bindings = []
    seen = set()
    for fragment in _collect_xhtml_fragments(text):
        for match in _EL_PATTERN.finditer(fragment):
            expression = match.group(1).strip()
            if expression in seen:
                continue
            seen.add(expression)
            bean = re.split(r"[.\[]", expression, maxsplit=1)[0]
            member = None
            if "." in expression:
                member = expression.split(".", 1)[1]
            bindings.append(
                {
                    "expression": expression,
                    "bean": bean,
                    "member": member,
                    "sourceFile": source_file,
                }
            )
    return bindings


def parse_xhtml_bindings(xhtml_file: str) -> list[dict]:
    text = Path(xhtml_file).read_text(encoding="utf-8", errors="replace")
    return _parse_xhtml_bindings_text(text, str(Path(xhtml_file).resolve()))


def _extract_prefixed_tag_counts(text: str, namespaces: dict[str, str]) -> list[dict]:
    counts: dict[tuple[str, str], int] = defaultdict(int)
    for prefix, local_name in _PREFIXED_TAG_PATTERN.findall(text):
        counts[(prefix, local_name)] += 1

    return [
        {
            "prefix": prefix,
            "localName": local_name,
            "namespace": namespaces.get(prefix),
            "count": count,
        }
        for (prefix, local_name), count in sorted(counts.items())
    ]


def _extract_attribute_bindings(text: str) -> list[dict]:
    bindings = []
    seen = set()
    for attribute_name, value in _XHTML_ATTRIBUTE_BINDING_PATTERN.findall(text):
        key = (attribute_name, value)
        if key in seen:
            continue
        seen.add(key)
        bindings.append({"attribute": attribute_name, "value": value})
    return bindings


def _normalize_xhtml_reference(reference: str) -> str:
    return reference.split("#", 1)[0].split("?", 1)[0].strip().replace("\\", "/")


def _resolve_xhtml_reference(reference: str, current_file: str, source_root: str) -> list[str]:
    normalized = _normalize_xhtml_reference(reference)
    if not normalized or "#{" in normalized or normalized.startswith("http://") or normalized.startswith("https://"):
        return []

    current_path = Path(current_file).resolve()
    root_path = Path(source_root).resolve()
    candidates = []

    if normalized.startswith("/"):
        stripped = normalized.lstrip("/")
        candidates.extend(
            [
                root_path / stripped,
                root_path / "src" / "main" / "webapp" / stripped,
            ]
        )
    else:
        candidates.extend(
            [
                current_path.parent / normalized,
                root_path / normalized,
                root_path / "src" / "main" / "webapp" / normalized,
            ]
        )

    resolved = []
    for candidate in candidates:
        try:
            candidate_path = candidate.resolve()
        except Exception:
            continue
        if candidate_path.exists() and candidate_path.suffix.lower() == ".xhtml":
            resolved.append(str(candidate_path))

    if resolved:
        return _dedupe_keep_order(resolved)

    filename = Path(normalized).name
    if not filename:
        return []

    suffix = normalized.lstrip("/")
    matches = []
    for candidate in root_path.rglob(filename):
        if candidate.suffix.lower() != ".xhtml":
            continue
        candidate_path = candidate.resolve()
        relative_path = candidate_path.relative_to(root_path).as_posix()
        if relative_path.endswith(suffix) or candidate_path.name == filename:
            matches.append(str(candidate_path))
    return _dedupe_keep_order(matches)


def _resolve_composite_component_links(text: str, source_root: str) -> tuple[list[dict], list[dict]]:
    namespaces = _extract_xml_namespaces(text)
    component_tags = _extract_prefixed_tag_counts(text, namespaces)
    root_path = Path(source_root).resolve()
    links = []
    unresolved = []

    for component_tag in component_tags:
        namespace = component_tag.get("namespace") or ""
        marker = None
        if "/jsf/composite/" in namespace:
            marker = "/jsf/composite/"
        elif "jsf/composite/" in namespace:
            marker = "jsf/composite/"
        if marker is None:
            continue

        library_path = namespace.split(marker, 1)[1].strip("/")
        local_name = component_tag["localName"]
        expected_suffix = f"resources/{library_path}/{local_name}.xhtml".strip("/")
        matches = []
        for candidate in root_path.rglob(f"{local_name}.xhtml"):
            relative_path = candidate.resolve().relative_to(root_path).as_posix()
            if relative_path.endswith(expected_suffix):
                matches.append(str(candidate.resolve()))

        if len(matches) == 1:
            links.append(
                {
                    "kind": "composite-component",
                    "prefix": component_tag["prefix"],
                    "tag": local_name,
                    "library": library_path,
                    "namespace": namespace,
                    "resolvedFile": matches[0],
                }
            )
        else:
            unresolved.append(
                {
                    "kind": "composite-component",
                    "prefix": component_tag["prefix"],
                    "tag": local_name,
                    "library": library_path,
                    "namespace": namespace,
                    "matches": matches,
                }
            )

    return links, unresolved


def collect_xhtml_artifacts(entry_xhtml: str, source_root: str) -> dict:
    root_file = str(Path(entry_xhtml).resolve())
    queue = deque([root_file])
    visited: set[str] = set()
    artifacts: dict[str, dict] = {}
    all_bindings = []
    edges = []
    edge_keys = set()
    unresolved_links = []

    while queue:
        current_file = queue.popleft()
        if current_file in visited:
            continue

        current_path = Path(current_file)
        if not current_path.exists():
            continue

        visited.add(current_file)
        text = current_path.read_text(encoding="utf-8", errors="replace")
        namespaces = _extract_xml_namespaces(text)
        component_tags = _extract_prefixed_tag_counts(text, namespaces)
        attribute_bindings = _extract_attribute_bindings(text)
        file_bindings = _parse_xhtml_bindings_text(text, current_file)
        all_bindings.extend(file_bindings)

        artifact_links = []
        for reference in _XHTML_FILE_REFERENCE_PATTERN.findall(text):
            matches = _resolve_xhtml_reference(reference, current_file, source_root)
            if len(matches) == 1:
                artifact_links.append(
                    {
                        "kind": "include",
                        "reference": reference,
                        "resolvedFile": matches[0],
                    }
                )
                queue.append(matches[0])
            else:
                unresolved_links.append(
                    {
                        "sourceFile": current_file,
                        "kind": "include",
                        "reference": reference,
                        "matches": matches,
                    }
                )

        composite_links, composite_unresolved = _resolve_composite_component_links(text, source_root)
        artifact_links.extend(composite_links)
        for link in composite_links:
            queue.append(link["resolvedFile"])
        for unresolved in composite_unresolved:
            unresolved_links.append({"sourceFile": current_file, **unresolved})

        deduped_links = []
        for link in artifact_links:
            key = json.dumps({"sourceFile": current_file, **link}, sort_keys=True)
            if key in edge_keys:
                continue
            edge_keys.add(key)
            deduped_links.append(link)
            edges.append({"sourceFile": current_file, **link})

        artifacts[current_file] = {
            "file": current_file,
            "namespaces": [{"prefix": prefix, "uri": uri} for prefix, uri in sorted(namespaces.items())],
            "componentTags": component_tags,
            "attributeBindings": attribute_bindings,
            "bindings": file_bindings,
            "links": deduped_links,
        }

    return {
        "entryFile": root_file,
        "files": [artifacts[file_path] for file_path in sorted(artifacts)],
        "bindings": all_bindings,
        "edges": sorted(edges, key=lambda edge: (edge["sourceFile"], edge["kind"], edge.get("resolvedFile", ""))),
        "unresolvedLinks": sorted(
            unresolved_links,
            key=lambda item: (item["sourceFile"], item["kind"], item.get("reference", item.get("tag", ""))),
        ),
    }


def _extract_root_tag_name(text: str) -> str | None:
    match = re.search(r"<\s*([A-Za-z_][\w:.-]*)\b", text)
    return match.group(1) if match else None


def _extract_xml_query_fragments(text: str) -> list[str]:
    fragments = []
    for fragment in _CDATA_PATTERN.findall(text):
        if _SQL_KEYWORD_PATTERN.search(fragment):
            fragments.append(" ".join(fragment.split()))

    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        root = None

    if root is not None:
        for fragment in root.itertext():
            candidate = " ".join(fragment.split())
            if candidate and _SQL_KEYWORD_PATTERN.search(candidate):
                fragments.append(candidate)

    stripped = " ".join(re.sub(r"<[^>]+>", " ", text).split())
    if stripped and _SQL_KEYWORD_PATTERN.search(stripped):
        fragments.append(stripped)

    return _dedupe_keep_order(fragment for fragment in fragments if fragment)


def _should_skip_xml_artifact(xml_file: Path, root_path: Path) -> bool:
    relative_path = xml_file.resolve().relative_to(root_path).as_posix().lower()
    path_parts = set(part.lower() for part in xml_file.parts)

    if {"target", "build", "node_modules", ".git"} & path_parts:
        return True
    if "/src/test/" in relative_path or relative_path.startswith("src/test/"):
        return True
    return False


def scan_xml_query_artifacts(source_root: str, reachable_profiles: dict[str, dict], known_tables: set[str]) -> list[dict]:
    root_path = Path(source_root).resolve()
    reachable_items = list(reachable_profiles.values())
    artifacts = []

    for xml_file in sorted(root_path.rglob("*.xml")):
        if _should_skip_xml_artifact(xml_file, root_path):
            continue

        try:
            text = xml_file.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        namespaces = _extract_xml_namespaces(text)
        query_fragments = _extract_xml_query_fragments(text)
        sql_tables = _extract_sql_tables(query_fragments)
        text_lower = text.lower()
        likely_query_artifact = bool(
            _XML_SQL_TAG_PATTERN.search(text)
            or "native-query" in text_lower
            or "resultmap" in text_lower
            or "mapper" in xml_file.name.lower()
        )

        referenced_classes = []
        reference_keys = set()
        for profile in reachable_items:
            fully_qualified_name = (
                f"{profile['package']}.{profile['class_name']}" if profile["package"] else None
            )
            match_kind = None
            if fully_qualified_name and fully_qualified_name in text:
                match_kind = "fqn"
            elif re.search(rf"\b{re.escape(profile['class_name'])}\b", text):
                match_kind = "simple-name"

            if match_kind is None:
                continue

            key = (profile["file"], match_kind)
            if key in reference_keys:
                continue
            reference_keys.add(key)
            referenced_classes.append(
                {
                    "class": profile["class_name"],
                    "file": profile["file"],
                    "layer": profile["layer"],
                    "match": match_kind,
                }
            )

        matched_tables = [table for table in sql_tables if not known_tables or table in known_tables]
        effective_tables = matched_tables or sql_tables
        if not effective_tables and not likely_query_artifact:
            continue

        referenced_classes = [
            reference
            for reference in referenced_classes
            if reference["match"] == "fqn" or effective_tables or likely_query_artifact
        ]

        artifacts.append(
            {
                "file": str(xml_file.resolve()),
                "rootTag": _extract_root_tag_name(text),
                "namespaces": [{"prefix": prefix, "uri": uri} for prefix, uri in sorted(namespaces.items())],
                "referencedClasses": sorted(
                    referenced_classes,
                    key=lambda item: (item["class"], item["file"], item["match"]),
                ),
                "sqlTables": effective_tables,
                "queryCount": len(query_fragments),
                "queryFragments": query_fragments[:5],
                "likelyQueryArtifact": likely_query_artifact,
            }
        )

    return artifacts


def _profile_node(profile: dict, entry: bool = False) -> dict:
    return {
        "id": f"class:{profile['file']}",
        "kind": "java-class",
        "layer": profile["layer"],
        "label": profile["class_name"],
        "className": profile["class_name"],
        "typeKind": profile.get("type_kind", "class"),
        "file": profile["file"],
        "beanNames": profile["bean_names"],
        "entry": entry,
    }


def _sort_nodes(nodes: dict[str, dict]) -> list[dict]:
    return sorted(
        nodes.values(),
        key=lambda node: (
            _LAYER_ORDER.get(node.get("layer", "unknown"), 99),
            node.get("kind", "unknown"),
            node.get("label", node.get("id", "")),
        ),
    )


def _sort_edges(edges: list[dict]) -> list[dict]:
    return sorted(
        edges,
        key=lambda edge: (
            edge.get("from", ""),
            edge.get("to", ""),
            edge.get("kind", ""),
        ),
    )


def build_xhtml_db_graph(source_root: str, xhtml_file: str) -> dict:
    profiles, class_map, bean_map = build_java_index(source_root)
    reverse_declaration_map: dict[str, list[dict]] = defaultdict(list)
    for profile in profiles:
        for dependency_name, sources in profile["dependency_sources"].items():
            if "declaration" in sources:
                reverse_declaration_map[dependency_name].append(profile)

    xhtml_context = collect_xhtml_artifacts(xhtml_file, source_root)
    bindings = xhtml_context["bindings"]
    bindings_by_bean: dict[str, list[dict]] = defaultdict(list)
    for binding in bindings:
        bindings_by_bean[binding["bean"]].append(binding)

    entry_beans = sorted(bindings_by_bean)
    resolved_entries = []
    unresolved_beans = []
    unresolved_bindings = []
    ambiguous_beans = []
    ambiguous_dependencies = []
    vertical_edges = []
    horizontal_edges = []
    reachable_profiles: dict[str, dict] = {}
    database_profiles: dict[str, dict] = {}
    table_sources: dict[str, list[dict]] = defaultdict(list)

    queue = deque()
    visited: set[str] = set()
    graph_nodes: dict[str, dict] = {}
    graph_edges = []
    graph_edge_keys = set()

    resolved_entry_path = str(Path(xhtml_file).resolve())

    def add_node(node: dict) -> str:
        node_id = node["id"]
        existing = graph_nodes.get(node_id)
        if existing is None:
            graph_nodes[node_id] = node
            return node_id

        if node.get("entry"):
            existing["entry"] = True
        if node.get("beanNames"):
            existing["beanNames"] = _dedupe_keep_order(existing.get("beanNames", []) + node["beanNames"])
        return node_id

    def add_edge(edge: dict) -> None:
        edge_key = json.dumps(edge, sort_keys=True)
        if edge_key in graph_edge_keys:
            return
        graph_edge_keys.add(edge_key)
        graph_edges.append(edge)

    xhtml_node_ids = {}
    for artifact in xhtml_context["files"]:
        node_id = add_node(
            {
                "id": f"xhtml:{artifact['file']}",
                "kind": "xhtml-view" if artifact["file"] == resolved_entry_path else "xhtml-fragment",
                "layer": "xhtml",
                "label": Path(artifact["file"]).name,
                "file": artifact["file"],
                "entry": artifact["file"] == resolved_entry_path,
            }
        )
        xhtml_node_ids[artifact["file"]] = node_id

    xhtml_node_id = xhtml_node_ids[resolved_entry_path]

    for xhtml_edge in xhtml_context["edges"]:
        source_file = xhtml_edge["sourceFile"]
        target_file = xhtml_edge.get("resolvedFile")
        source_node_id = xhtml_node_ids.get(source_file)
        if source_node_id is None or target_file is None:
            continue

        target_node_id = xhtml_node_ids.get(target_file)
        if target_node_id is None:
            target_node_id = add_node(
                {
                    "id": f"xhtml:{target_file}",
                    "kind": "xhtml-fragment",
                    "layer": "xhtml",
                    "label": Path(target_file).name,
                    "file": target_file,
                    "entry": False,
                }
            )
            xhtml_node_ids[target_file] = target_node_id

        edge = {
            "from": source_node_id,
            "to": target_node_id,
            "kind": xhtml_edge["kind"],
            "fromLayer": "xhtml",
            "toLayer": "xhtml",
        }
        if xhtml_edge["kind"] == "include":
            edge["reference"] = xhtml_edge.get("reference")
        else:
            edge["prefix"] = xhtml_edge.get("prefix")
            edge["tag"] = xhtml_edge.get("tag")
            edge["library"] = xhtml_edge.get("library")
        add_edge(edge)
        vertical_edges.append(
            {
                "from": Path(source_file).name,
                "fromLayer": "xhtml",
                "to": Path(target_file).name,
                "toLayer": "xhtml",
                "kind": xhtml_edge["kind"],
            }
        )

    def register_db_touchpoints(profile: dict, node_id: str) -> None:
        touchpoints = profile["db_touchpoints"]
        if not touchpoints["has_database_access"]:
            return

        database_profiles[profile["file"]] = {
            "class": profile["class_name"],
            "file": profile["file"],
            "layer": profile["layer"],
            "tables": touchpoints["tables"],
            "persistenceFeatures": touchpoints["persistence_features"],
            "queryCount": touchpoints["query_count"],
            "queries": touchpoints["queries"],
        }

        table_edge_map = {
            table: "maps-to-table" for table in touchpoints["annotated_tables"]
        }
        for table in touchpoints["sql_tables"]:
            table_edge_map[table] = "sql-table"

        for table in touchpoints["tables"]:
            table_node_id = f"table:{table}"
            add_node(
                {
                    "id": table_node_id,
                    "kind": "db-table",
                    "layer": "database",
                    "label": table,
                }
            )
            edge_kind = table_edge_map.get(table, "database-touchpoint")
            edge = {
                "from": node_id,
                "to": table_node_id,
                "kind": edge_kind,
                "fromLayer": profile["layer"],
                "toLayer": "database",
            }
            add_edge(edge)
            vertical_edges.append(
                {
                    "from": profile["class_name"],
                    "fromLayer": profile["layer"],
                    "to": table,
                    "toLayer": "database",
                    "kind": edge_kind,
                }
            )
            table_sources[table].append(
                {
                    "class": profile["class_name"],
                    "file": profile["file"],
                    "kind": edge_kind,
                }
            )

    for bean_name in entry_beans:
        bean_bindings = bindings_by_bean[bean_name]
        expressions = _dedupe_keep_order(binding["expression"] for binding in bean_bindings)
        members = _dedupe_keep_order(binding["member"] for binding in bean_bindings if binding["member"])
        source_files = sorted({binding["sourceFile"] for binding in bean_bindings})
        bindings_by_source: dict[str, list[dict]] = defaultdict(list)
        for binding in bean_bindings:
            bindings_by_source[binding["sourceFile"]].append(binding)
        matches = bean_map.get(bean_name, [])

        if len(matches) == 1:
            profile = matches[0]
            resolved_entries.append(
                {
                    "bean": bean_name,
                    "class": profile["class_name"],
                    "file": profile["file"],
                    "layer": profile["layer"],
                    "expressions": expressions,
                    "sourceFiles": source_files,
                }
            )
            target_node_id = add_node(_profile_node(profile, entry=True))
            for source_file, source_bindings in sorted(bindings_by_source.items()):
                source_node_id = xhtml_node_ids.get(source_file, xhtml_node_id)
                source_expressions = _dedupe_keep_order(binding["expression"] for binding in source_bindings)
                source_members = _dedupe_keep_order(binding["member"] for binding in source_bindings if binding["member"])
                edge = {
                    "from": source_node_id,
                    "to": target_node_id,
                    "kind": "binding",
                    "fromLayer": "xhtml",
                    "toLayer": profile["layer"],
                    "bean": bean_name,
                    "expressions": source_expressions,
                    "members": source_members,
                }
                add_edge(edge)
                vertical_edges.append(
                    {
                        "from": Path(source_file).name,
                        "fromLayer": "xhtml",
                        "to": profile["class_name"],
                        "toLayer": profile["layer"],
                        "kind": "binding",
                    }
                )
            queue.append(profile)
        elif len(matches) > 1:
            ambiguous_beans.append(
                {
                    "bean": bean_name,
                    "matches": [match["file"] for match in matches],
                    "expressions": expressions,
                    "sourceFiles": source_files,
                }
            )
        else:
            unresolved_beans.append(bean_name)
            unresolved_bindings.append(
                {
                    "bean": bean_name,
                    "expressions": expressions,
                    "sourceFiles": source_files,
                }
            )

    while queue:
        current = queue.popleft()
        current_key = current["file"]
        current_node_id = add_node(_profile_node(current))

        if current_key in visited:
            continue
        visited.add(current_key)
        reachable_profiles[current_key] = current
        register_db_touchpoints(current, current_node_id)

        for dependency_name in current["flow_dependencies"]:
            matches = class_map.get(dependency_name, [])
            if len(matches) == 1:
                target = matches[0]
                target_node_id = add_node(_profile_node(target))
                source_kinds = current["dependency_sources"].get(dependency_name, ["dependency"])
                edge_kind = source_kinds[0]
                edge = {
                    "from": current_node_id,
                    "to": target_node_id,
                    "kind": edge_kind,
                    "fromLayer": current["layer"],
                    "toLayer": target["layer"],
                    "dependency": dependency_name,
                    "sources": source_kinds,
                }
                add_edge(edge)

                flow_edge = {
                    "from": current["class_name"],
                    "fromLayer": current["layer"],
                    "to": target["class_name"],
                    "toLayer": target["layer"],
                    "kind": edge_kind,
                }
                if _LAYER_ORDER.get(current["layer"], 99) == _LAYER_ORDER.get(target["layer"], 99):
                    horizontal_edges.append(flow_edge)
                else:
                    vertical_edges.append(flow_edge)

                if target["file"] not in visited:
                    queue.append(target)
            elif len(matches) > 1:
                ambiguous_dependencies.append(
                    {
                        "from": current["class_name"],
                        "dependency": dependency_name,
                        "matches": [match["file"] for match in matches],
                        "sources": current["dependency_sources"].get(dependency_name, ["dependency"]),
                    }
                )

        for dependent in reverse_declaration_map.get(current["class_name"], []):
            if dependent["file"] == current["file"]:
                continue

            dependent_node_id = add_node(_profile_node(dependent))
            edge_kind = "implemented-by" if current.get("type_kind") == "interface" else "extended-by"
            edge = {
                "from": current_node_id,
                "to": dependent_node_id,
                "kind": edge_kind,
                "fromLayer": current["layer"],
                "toLayer": dependent["layer"],
                "dependency": current["class_name"],
                "sources": ["declaration"],
            }
            add_edge(edge)

            flow_edge = {
                "from": current["class_name"],
                "fromLayer": current["layer"],
                "to": dependent["class_name"],
                "toLayer": dependent["layer"],
                "kind": edge_kind,
            }
            if _LAYER_ORDER.get(current["layer"], 99) == _LAYER_ORDER.get(dependent["layer"], 99):
                horizontal_edges.append(flow_edge)
            else:
                vertical_edges.append(flow_edge)

            if dependent["file"] not in visited:
                queue.append(dependent)

    xml_artifacts = scan_xml_query_artifacts(source_root, reachable_profiles, set(table_sources))
    for artifact in xml_artifacts:
        xml_node_id = add_node(
            {
                "id": f"xml:{artifact['file']}",
                "kind": "xml-file",
                "layer": "xml-artifact",
                "label": Path(artifact["file"]).name,
                "file": artifact["file"],
                "rootTag": artifact.get("rootTag"),
                "queryCount": artifact["queryCount"],
                "likelyQueryArtifact": artifact["likelyQueryArtifact"],
            }
        )

        if artifact["referencedClasses"]:
            for reference in artifact["referencedClasses"]:
                target_profile = reachable_profiles.get(reference["file"])
                if target_profile is None:
                    continue
                class_node_id = add_node(_profile_node(target_profile))
                add_edge(
                    {
                        "from": class_node_id,
                        "to": xml_node_id,
                        "kind": "xml-reference",
                        "fromLayer": target_profile["layer"],
                        "toLayer": "xml-artifact",
                        "match": reference["match"],
                    }
                )
                vertical_edges.append(
                    {
                        "from": target_profile["class_name"],
                        "fromLayer": target_profile["layer"],
                        "to": Path(artifact["file"]).name,
                        "toLayer": "xml-artifact",
                        "kind": "xml-reference",
                    }
                )
        elif artifact["sqlTables"]:
            add_edge(
                {
                    "from": xhtml_node_id,
                    "to": xml_node_id,
                    "kind": "related-query-artifact",
                    "fromLayer": "xhtml",
                    "toLayer": "xml-artifact",
                }
            )
            vertical_edges.append(
                {
                    "from": Path(xhtml_file).name,
                    "fromLayer": "xhtml",
                    "to": Path(artifact["file"]).name,
                    "toLayer": "xml-artifact",
                    "kind": "related-query-artifact",
                }
            )

        for table in artifact["sqlTables"]:
            table_node_id = f"table:{table}"
            add_node(
                {
                    "id": table_node_id,
                    "kind": "db-table",
                    "layer": "database",
                    "label": table,
                }
            )
            add_edge(
                {
                    "from": xml_node_id,
                    "to": table_node_id,
                    "kind": "sql-table",
                    "fromLayer": "xml-artifact",
                    "toLayer": "database",
                }
            )
            vertical_edges.append(
                {
                    "from": Path(artifact["file"]).name,
                    "fromLayer": "xml-artifact",
                    "to": table,
                    "toLayer": "database",
                    "kind": "sql-table",
                }
            )
            table_sources[table].append(
                {
                    "class": Path(artifact["file"]).name,
                    "file": artifact["file"],
                    "kind": "sql-table",
                }
            )

    layer_groups: dict[str, list[dict]] = defaultdict(list)
    for artifact in xhtml_context["files"]:
        layer_groups["xhtml"].append(
            {
                "name": Path(artifact["file"]).name,
                "file": artifact["file"],
                "kind": "xhtml-view" if artifact["file"] == resolved_entry_path else "xhtml-fragment",
            }
        )
    for profile in sorted(
        reachable_profiles.values(),
        key=lambda item: (_LAYER_ORDER.get(item["layer"], 99), item["class_name"]),
    ):
        layer_groups[profile["layer"]].append(
            {
                "name": profile["class_name"],
                "file": profile["file"],
                "kind": "java-class",
            }
        )
    for artifact in sorted(xml_artifacts, key=lambda item: item["file"]):
        layer_groups["xml-artifact"].append(
            {
                "name": Path(artifact["file"]).name,
                "file": artifact["file"],
                "kind": "xml-file",
            }
        )
    for table_name in sorted(table_sources):
        layer_groups["database"].append({"name": table_name, "kind": "db-table"})

    reachable_files = sorted(
        {artifact["file"] for artifact in xhtml_context["files"]}
        | set(reachable_profiles)
        | {artifact["file"] for artifact in xml_artifacts}
    )
    database_touchpoints = {
        "classes": sorted(
            database_profiles.values(),
            key=lambda item: (_LAYER_ORDER.get(item["layer"], 99), item["class"], item["file"]),
        ),
        "tables": [
            {
                "name": table_name,
                "sources": sorted(
                    table_sources[table_name],
                    key=lambda item: (item["class"], item["file"], item["kind"]),
                ),
            }
            for table_name in sorted(table_sources)
        ],
        "xmlArtifacts": sorted(xml_artifacts, key=lambda item: item["file"]),
    }

    return {
        "entryFile": resolved_entry_path,
        "scanRoot": str(Path(source_root).resolve()),
        "bindings": bindings,
        "xhtmlArtifacts": {
            "files": xhtml_context["files"],
            "edges": xhtml_context["edges"],
            "unresolvedLinks": xhtml_context["unresolvedLinks"],
        },
        "xmlArtifacts": sorted(xml_artifacts, key=lambda item: item["file"]),
        "resolvedEntryBeans": resolved_entries,
        "unresolvedBeans": sorted(unresolved_beans),
        "unresolvedBindings": sorted(
            unresolved_bindings,
            key=lambda item: (item["bean"], ",".join(item.get("sourceFiles", []))),
        ),
        "ambiguousBeans": sorted(
            ambiguous_beans,
            key=lambda item: (item["bean"], ",".join(item.get("matches", []))),
        ),
        "verticalLayers": [
            {"layer": layer, "nodes": nodes}
            for layer, nodes in sorted(layer_groups.items(), key=lambda item: _LAYER_ORDER.get(item[0], 99))
        ],
        "verticalEdges": _sort_edges(vertical_edges),
        "horizontalDependencies": _sort_edges(horizontal_edges),
        "ambiguousDependencies": sorted(
            ambiguous_dependencies,
            key=lambda item: (item["from"], item["dependency"]),
        ),
        "reachableFiles": reachable_files,
        "databaseTouchpoints": database_touchpoints,
        "graph": {
            "format": "json",
            "nodes": _sort_nodes(graph_nodes),
            "edges": _sort_edges(graph_edges),
        },
        "summary": {
            "bindingCount": len(bindings),
            "xhtmlFileCount": len(xhtml_context["files"]),
            "xhtmlUnresolvedLinkCount": len(xhtml_context["unresolvedLinks"]),
            "resolvedEntryBeanCount": len(resolved_entries),
            "reachableClassCount": len(reachable_profiles),
            "xmlArtifactCount": len(xml_artifacts),
            "databaseClassCount": len(database_profiles),
            "tableCount": len(table_sources),
        },
    }


def build_legacy_xhtml_flow(source_root: str, xhtml_file: str) -> dict:
    return build_xhtml_db_graph(source_root, xhtml_file)


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

    elif command in {"legacy-xhtml", "xhtml-db-graph"}:
        _require_args(4, f"analyze-java.py {command} <source-root> <file.xhtml>")
        report = build_xhtml_db_graph(sys.argv[2], sys.argv[3])
        print(json.dumps(report, indent=2))
        print(
            (
                f"\nResolved {len(report['resolvedEntryBeans'])} entry bean(s), "
                f"{len(report['verticalEdges'])} vertical edge(s), "
                f"{len(report['horizontalDependencies'])} horizontal dependency edge(s), and "
                f"{len(report['databaseTouchpoints']['tables'])} database table touchpoint(s)."
            ),
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