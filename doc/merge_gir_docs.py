#!/usr/bin/env python3

# Copyright 2026 Princeton Ferro <princetonferro@gmail.com>
# SPDX-License-Identifier: LGPL-2.1-or-later

"""Merge Valadoc comments into valac's authoritative GIR.

Valac writes the accurate ABI metadata, while stable Valadoc is currently the
only Vala tool that writes source comments to GIR. The two files are checked
for the same API before documentation is copied. Valadoc's HTML output is used
only for source properties on records and compact classes, which its GIR writer
otherwise loses.
"""

import copy
import re
import sys
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path


CORE_NAMESPACE = "http://www.gtk.org/introspection/core/1.0"
C_NAMESPACE = "http://www.gtk.org/introspection/c/1.0"
DOC_NAMESPACE = "http://www.gtk.org/introspection/doc/1.0"
GLIB_NAMESPACE = "http://www.gtk.org/introspection/glib/1.0"
XML_NAMESPACE = "http://www.w3.org/XML/1998/namespace"

ElementTree.register_namespace("", CORE_NAMESPACE)
ElementTree.register_namespace("c", C_NAMESPACE)
ElementTree.register_namespace("doc", DOC_NAMESPACE)
ElementTree.register_namespace("glib", GLIB_NAMESPACE)


def qualified_name(namespace: str, name: str) -> str:
    return f"{{{namespace}}}{name}"


def local_name(element: ElementTree.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


DOC_TAG = qualified_name(CORE_NAMESPACE, "doc")
DEPRECATED_DOC_TAG = qualified_name(CORE_NAMESPACE, "doc-deprecated")
SOURCE_POSITION_TAG = qualified_name(CORE_NAMESPACE, "source-position")
DOC_FORMAT_TAG = qualified_name(DOC_NAMESPACE, "format")
TYPE_TAG = qualified_name(CORE_NAMESPACE, "type")
RETURN_VALUE_TAG = qualified_name(CORE_NAMESPACE, "return-value")
PARAMETERS_TAG = qualified_name(CORE_NAMESPACE, "parameters")
PARAMETER_TAG = qualified_name(CORE_NAMESPACE, "parameter")
PROPERTY_TAG = qualified_name(CORE_NAMESPACE, "property")
METHOD_TAG = qualified_name(CORE_NAMESPACE, "method")
FIELD_TAG = qualified_name(CORE_NAMESPACE, "field")
MEMBER_TAG = qualified_name(CORE_NAMESPACE, "member")

C_IDENTIFIER_ATTRIBUTE = qualified_name(C_NAMESPACE, "identifier")
C_TYPE_ATTRIBUTE = qualified_name(C_NAMESPACE, "type")
GLIB_GET_PROPERTY_ATTRIBUTE = qualified_name(GLIB_NAMESPACE, "get-property")
GLIB_SET_PROPERTY_ATTRIBUTE = qualified_name(GLIB_NAMESPACE, "set-property")
GLIB_ERROR_DOMAIN_ATTRIBUTE = qualified_name(GLIB_NAMESPACE, "error-domain")
XML_SPACE_ATTRIBUTE = qualified_name(XML_NAMESPACE, "space")
XML_WHITESPACE_ATTRIBUTE = qualified_name(XML_NAMESPACE, "whitespace")

DOCUMENTATION_TAGS = {DOC_TAG, DEPRECATED_DOC_TAG}
IGNORED_CHILD_TAGS = DOCUMENTATION_TAGS | {SOURCE_POSITION_TAG}
API_TYPE_TAGS = {
    "alias",
    "bitfield",
    "callback",
    "class",
    "enumeration",
    "interface",
    "record",
    "union",
}
CALLABLE_TAGS = {"constructor", "function", "method"}

# Valadoc renders external links with C names and drops their namespaces. Most
# are present in API type references; these documentation-only types are not.
DOCUMENTATION_TYPE_ALIASES = {
    "GMainLoop": "GLib.MainLoop",
    "JsonrpcClient": "Jsonrpc.Client",
}


@dataclass(frozen=True)
class GirLink:
    """A validated gi-docgen cross-reference."""

    fragment: str
    endpoint: str

    def render(self, label: str | None = None) -> str:
        reference = f"[{self.fragment}@{self.endpoint}]"
        if label and re.fullmatch(r"[\w\s,\-_:]+", label):
            return f"[{label}]{reference}"
        return reference


def normalize_c_type(c_type: str) -> str:
    c_type = re.sub(r"\b(?:const|struct|volatile)\b", "", c_type)
    return re.sub(r"[\s*&\[\]]", "", c_type)


class SymbolIndex:
    """Resolve Valadoc's C-style links through the compiler GIR."""

    def __init__(self, namespace: ElementTree.Element) -> None:
        self.namespace = namespace.get("name") or ""
        self.types: dict[str, GirLink] = {}
        self.callables: dict[str, GirLink] = {}
        self.constants: dict[str, GirLink] = {}
        self.members: dict[str, GirLink] = {}
        self.properties: dict[str, GirLink] = {}

        self._index_definitions(namespace)
        self._index_referenced_types(namespace)
        for c_name, full_name in DOCUMENTATION_TYPE_ALIASES.items():
            self._add_type(c_name, full_name)

    def _add_type(self, key: str | None, full_name: str) -> None:
        if not key:
            return
        self.types.setdefault(key, GirLink("type", full_name))
        self.types.setdefault(normalize_c_type(key), GirLink("type", full_name))

    def _index_definitions(self, namespace: ElementTree.Element) -> None:
        for element in namespace:
            kind = local_name(element)
            name = element.get("name")
            if not name:
                continue

            if kind == "constant":
                link = GirLink("const", f"{self.namespace}.{name}")
                self.constants[name] = link
                identifier = element.get(C_IDENTIFIER_ATTRIBUTE)
                if identifier:
                    self.constants[identifier] = link
                continue

            if kind == "function":
                self._index_callable(element, None)
                continue

            if kind not in API_TYPE_TAGS:
                continue

            full_name = f"{self.namespace}.{name}"
            self._add_type(name, full_name)
            self._add_type(full_name, full_name)
            self._add_type(element.get(C_TYPE_ATTRIBUTE), full_name)

            member_fragment = "flags" if kind == "bitfield" else "enum"
            if element.get(GLIB_ERROR_DOMAIN_ATTRIBUTE):
                member_fragment = "error"

            for child in element:
                child_kind = local_name(child)
                if child_kind in CALLABLE_TAGS:
                    self._index_callable(child, name)
                elif child_kind == "property":
                    property_name = child.get("name")
                    if property_name:
                        source_name = property_name.replace("-", "_")
                        self.properties[
                            f"{full_name}.{source_name}"
                        ] = GirLink(
                            "property",
                            f"{full_name}:{property_name}",
                        )
                elif child.tag == MEMBER_TAG:
                    member_name = child.get("name")
                    if not member_name:
                        continue
                    link = GirLink(
                        member_fragment,
                        f"{full_name}.{member_name.upper()}",
                    )
                    self.members[f"{full_name}.{member_name.upper()}"] = link
                    identifier = child.get(C_IDENTIFIER_ATTRIBUTE)
                    if identifier:
                        self.members[identifier] = link

    def _index_callable(
        self,
        element: ElementTree.Element,
        owner: str | None,
    ) -> None:
        identifier = element.get(C_IDENTIFIER_ATTRIBUTE)
        name = element.get("name")
        if not identifier or not name:
            return

        link = GirLink("id", identifier)
        self.callables[identifier] = link
        if owner:
            self.callables[f"{self.namespace}.{owner}.{name}"] = link
        else:
            self.callables[f"{self.namespace}.{name}"] = link

    def _index_referenced_types(self, namespace: ElementTree.Element) -> None:
        for element in namespace.iter(TYPE_TAG):
            name = element.get("name")
            if not name or "." not in name:
                continue
            self._add_type(name, name)
            self._add_type(element.get(C_TYPE_ATTRIBUTE), name)

    def type_link(self, name: str) -> GirLink | None:
        return self.members.get(name) or self.types.get(
            normalize_c_type(name)
        )

    def function_link(self, name: str) -> GirLink | None:
        return self.callables.get(name)

    def constant_link(self, name: str) -> GirLink | None:
        return self.members.get(name) or self.constants.get(name)

    def html_link(self, href: str) -> GirLink | None:
        filename = href.split("#", 1)[0].rsplit("/", 1)[-1]
        if not filename.endswith(".html"):
            return None
        name = filename[:-5]
        return (
            self.properties.get(name)
            or self.members.get(name)
            or self.callables.get(name)
            or self.types.get(name)
        )


class MarkupElement:
    """A small tree node used while translating documentation markup."""

    def __init__(self, tag: str, attributes: dict[str, str | None]) -> None:
        self.tag = tag
        self.attributes = attributes
        self.children: list[MarkupElement | str] = []


class ValadocMarkupParser(HTMLParser):
    """Parse the XML-like fragment stored inside a Valadoc GIR comment."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = MarkupElement("root", {})
        self.elements = [self.root]

    def handle_starttag(
        self,
        tag: str,
        attributes: list[tuple[str, str | None]],
    ) -> None:
        element = MarkupElement(tag, dict(attributes))
        self.elements[-1].children.append(element)
        if tag != "br":
            self.elements.append(element)

    def handle_startendtag(
        self,
        tag: str,
        attributes: list[tuple[str, str | None]],
    ) -> None:
        self.elements[-1].children.append(MarkupElement(tag, dict(attributes)))

    def handle_endtag(self, tag: str) -> None:
        open_tags = [element.tag for element in self.elements]
        if tag not in open_tags:
            raise ValueError(f"unbalanced Valadoc markup near </{tag}>")

        # Unresolved symbol links can leave an inline wrapper unclosed.
        while self.elements[-1].tag != tag:
            if self.elements[-1].tag not in {
                "constant",
                "emphasis",
                "function",
                "parameter",
                "type",
            }:
                raise ValueError(f"unbalanced Valadoc markup near </{tag}>")
            self.elements[-1].tag = "span"
            self.elements.pop()
        self.elements.pop()

    def handle_data(self, data: str) -> None:
        self.elements[-1].children.append(data)

    def finish(self) -> MarkupElement:
        self.close()
        if len(self.elements) != 1:
            raise ValueError(
                f"unclosed Valadoc markup element <{self.elements[-1].tag}>"
            )
        return self.root


class HtmlDescriptionParser(HTMLParser):
    """Extract a Valadoc page's description without changing the HTML."""

    VOID_ELEMENTS = {"br", "hr", "img", "input", "link", "meta"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root: MarkupElement | None = None
        self.elements: list[MarkupElement] = []
        self.capturing = False

    def handle_starttag(
        self,
        tag: str,
        attributes: list[tuple[str, str | None]],
    ) -> None:
        attrs = dict(attributes)
        if not self.capturing:
            if (
                self.root is None
                and tag == "div"
                and attrs.get("class") == "description"
            ):
                self.root = MarkupElement("root", {})
                self.elements = [self.root]
                self.capturing = True
            return

        element = MarkupElement(tag, attrs)
        self.elements[-1].children.append(element)
        if tag not in self.VOID_ELEMENTS:
            self.elements.append(element)

    def handle_startendtag(
        self,
        tag: str,
        attributes: list[tuple[str, str | None]],
    ) -> None:
        if self.capturing:
            self.elements[-1].children.append(
                MarkupElement(tag, dict(attributes))
            )

    def handle_endtag(self, tag: str) -> None:
        if not self.capturing:
            return
        if tag == "div" and len(self.elements) == 1:
            self.capturing = False
            self.elements = []
            return

        for index in range(len(self.elements) - 1, 0, -1):
            if self.elements[index].tag == tag:
                del self.elements[index:]
                return

    def handle_data(self, data: str) -> None:
        if self.capturing:
            self.elements[-1].children.append(data)

    def finish(self) -> MarkupElement | None:
        self.close()
        if self.capturing:
            raise ValueError("unclosed Valadoc HTML description")
        return self.root


def render_text(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def raw_text(element: MarkupElement) -> str:
    return "".join(
        child if isinstance(child, str) else raw_text(child)
        for child in element.children
    )


def code_span(content: str) -> str:
    return f"`{content}`"


class DocumentationRenderer:
    def __init__(self, symbols: SymbolIndex) -> None:
        self.symbols = symbols

    def gir_markup(self, markup: str, symbol_path: str) -> str:
        parser = ValadocMarkupParser()
        parser.feed(markup)
        return self._element(parser.finish(), symbol_path).strip()

    def html_description(self, filename: Path, symbol_path: str) -> str | None:
        parser = HtmlDescriptionParser()
        parser.feed(filename.read_text(encoding="utf-8"))
        root = parser.finish()
        if root is None:
            return None
        description = self._element(root, symbol_path).strip()
        return description or None

    def _children(self, element: MarkupElement, symbol_path: str) -> str:
        return "".join(
            render_text(child)
            if isinstance(child, str)
            else self._element(child, symbol_path)
            for child in element.children
        )

    def _block_children(self, element: MarkupElement, symbol_path: str) -> str:
        content = []
        for child in element.children:
            if isinstance(child, str):
                if child.strip():
                    content.append(render_text(child))
            else:
                content.append(self._element(child, symbol_path))
        return "".join(content)

    def _program_listing(self, element: MarkupElement) -> str:
        code = raw_text(element).strip()
        longest = max(
            (len(fence) for fence in re.findall(r"`+", code)),
            default=0,
        )
        fence = "`" * max(3, longest + 1)
        return f"\n\n{fence}\n{code}\n{fence}\n\n"

    def _list(
        self,
        element: MarkupElement,
        symbol_path: str,
        ordered: bool,
    ) -> str:
        items = []
        for child in element.children:
            if isinstance(child, str):
                if child.strip():
                    raise ValueError(f"unexpected text in list at {symbol_path}")
                continue
            if child.tag not in {"li", "listitem"}:
                raise ValueError(
                    f"unexpected <{child.tag}> in list at {symbol_path}"
                )
            content = self._children(child, symbol_path).strip()
            content = re.sub(r"\s*\n\s*", " ", content)
            items.append(f"{'1.' if ordered else '-'} {content}")
        content = "\n".join(items)
        return f"{content}\n\n"

    def _semantic_link(
        self,
        element: MarkupElement,
        symbol_path: str,
    ) -> str:
        content = self._children(element, symbol_path).strip()
        if element.tag == "type":
            link = self.symbols.type_link(content)
        elif element.tag == "function":
            link = self.symbols.function_link(content)
        elif element.tag == "constant":
            link = self.symbols.constant_link(content)
        else:
            link = None
        return link.render() if link else code_span(content)

    def _html_link(self, element: MarkupElement, symbol_path: str) -> str:
        href = element.attributes.get("href")
        content = self._children(element, symbol_path).strip()
        if not href:
            return content
        if href.startswith(("http://", "https://", "mailto:")):
            return f"[{content}]({href})"
        link = self.symbols.html_link(href)
        return link.render(raw_text(element).strip()) if link else code_span(content)

    def _element(self, element: MarkupElement, symbol_path: str) -> str:
        if element.tag in {"div", "example", "root"}:
            return self._block_children(element, symbol_path)
        if element.tag == "span":
            return self._children(element, symbol_path)
        if element.tag in {"p", "para"}:
            content = self._children(element, symbol_path).strip()
            return f"{content}\n\n" if content else ""
        if element.tag in {"constant", "function", "type"}:
            return self._semantic_link(element, symbol_path)
        if element.tag == "parameter":
            return code_span(self._children(element, symbol_path).strip())
        if element.tag == "a":
            return self._html_link(element, symbol_path)
        if element.tag == "ulink":
            url = element.attributes.get("url")
            if not url:
                raise ValueError(f"Valadoc link has no URL in {symbol_path}")
            return f"[{self._children(element, symbol_path).strip()}]({url})"
        if element.tag in {"b", "strong"}:
            return f"**{self._children(element, symbol_path).strip()}**"
        if element.tag in {"em", "i", "emphasis"}:
            marker = (
                "**"
                if element.attributes.get("role") == "bold"
                else "*"
            )
            return f"{marker}{self._children(element, symbol_path).strip()}{marker}"
        if element.tag in {"code", "kbd"}:
            return code_span(raw_text(element).strip())
        if element.tag in {"pre", "programlisting"}:
            return self._program_listing(element)
        if element.tag in {"itemizedlist", "ul"}:
            return self._list(element, symbol_path, ordered=False)
        if element.tag in {"ol", "orderedlist"}:
            return self._list(element, symbol_path, ordered=True)
        if element.tag in {"h1", "h2", "h3"}:
            content = self._children(element, symbol_path).strip()
            return f"\n\n**{content}**\n\n"
        if element.tag == "br":
            return "\n"
        raise ValueError(
            f"unsupported Valadoc markup <{element.tag}> in {symbol_path}"
        )


def element_label(element: ElementTree.Element) -> str:
    name = (
        element.get("name")
        or element.get(C_IDENTIFIER_ATTRIBUTE)
        or element.get(C_TYPE_ATTRIBUTE)
    )
    return local_name(element) if name is None else f"{local_name(element)}[{name}]"


def element_identity(element: ElementTree.Element) -> tuple[str, ...]:
    return (
        element.tag,
        element.get("name") or "",
        element.get(C_IDENTIFIER_ATTRIBUTE) or "",
        element.get(C_TYPE_ATTRIBUTE) or "",
    )


def api_children(element: ElementTree.Element) -> list[ElementTree.Element]:
    return [child for child in element if child.tag not in IGNORED_CHILD_TAGS]


def check_element_identity(
    compiler_element: ElementTree.Element,
    valadoc_element: ElementTree.Element,
    symbol_path: str,
) -> None:
    if compiler_element.tag != valadoc_element.tag:
        raise ValueError(
            f"GIR element differs at {symbol_path}: "
            f"{local_name(compiler_element)} != {local_name(valadoc_element)}"
        )
    for attribute in ("name", C_IDENTIFIER_ATTRIBUTE, C_TYPE_ATTRIBUTE):
        compiler_value = compiler_element.get(attribute)
        valadoc_value = valadoc_element.get(attribute)
        if compiler_value != valadoc_value:
            raise ValueError(
                f"GIR element differs at {symbol_path}: "
                f"{compiler_value!r} != {valadoc_value!r}"
            )


def insert_documentation(
    element: ElementTree.Element,
    documentation: ElementTree.Element,
) -> None:
    index = 0
    if documentation.tag == DEPRECATED_DOC_TAG:
        while index < len(element) and element[index].tag == DOC_TAG:
            index += 1
    element.insert(index, documentation)


def new_documentation(text: str) -> ElementTree.Element:
    documentation = ElementTree.Element(DOC_TAG)
    documentation.set("filename", "unknown")
    documentation.set("line", "0")
    documentation.set(XML_SPACE_ATTRIBUTE, "preserve")
    documentation.text = text
    return documentation


def documentation_text(element: ElementTree.Element | None) -> str | None:
    if element is None:
        return None
    documentation = element.find(DOC_TAG)
    return documentation.text if documentation is not None else None


def add_documentation(element: ElementTree.Element | None, text: str) -> bool:
    if element is None or not text or element.find(DOC_TAG) is not None:
        return False
    insert_documentation(element, new_documentation(text))
    return True


def copy_documentation(
    compiler_element: ElementTree.Element,
    valadoc_element: ElementTree.Element,
    symbol_path: str,
    renderer: DocumentationRenderer,
) -> int:
    """Copy missing comments while checking both writers emitted the same API."""

    check_element_identity(compiler_element, valadoc_element, symbol_path)
    copied = 0
    for valadoc_doc in valadoc_element:
        if (
            valadoc_doc.tag not in DOCUMENTATION_TAGS
            or compiler_element.find(valadoc_doc.tag) is not None
        ):
            continue

        compiler_doc = copy.deepcopy(valadoc_doc)
        compiler_doc.text = renderer.gir_markup(
            valadoc_doc.text or "",
            symbol_path,
        )
        if not compiler_doc.get("filename"):
            compiler_doc.set("filename", "unknown")
        if not compiler_doc.get("line"):
            compiler_doc.set("line", "0")
        compiler_doc.attrib.pop(XML_WHITESPACE_ATTRIBUTE, None)
        compiler_doc.set(XML_SPACE_ATTRIBUTE, "preserve")
        compiler_doc.tail = None
        insert_documentation(compiler_element, compiler_doc)
        copied += 1

    compiler_children = api_children(compiler_element)
    valadoc_children = api_children(valadoc_element)
    compiler_by_identity = {
        element_identity(child): child for child in compiler_children
    }
    valadoc_by_identity = {
        element_identity(child): child for child in valadoc_children
    }

    if len(compiler_by_identity) != len(compiler_children):
        raise ValueError(f"compiler GIR has duplicate children at {symbol_path}")
    if len(valadoc_by_identity) != len(valadoc_children):
        raise ValueError(f"Valadoc GIR has duplicate children at {symbol_path}")
    if set(compiler_by_identity) != set(valadoc_by_identity):
        missing = set(compiler_by_identity) - set(valadoc_by_identity)
        extra = set(valadoc_by_identity) - set(compiler_by_identity)
        raise ValueError(
            f"GIR children differ at {symbol_path}: "
            f"missing {len(missing)}, extra {len(extra)}"
        )

    for identity, compiler_child in compiler_by_identity.items():
        child_path = f"{symbol_path}/{element_label(compiler_child)}"
        copied += copy_documentation(
            compiler_child,
            valadoc_by_identity[identity],
            child_path,
            renderer,
        )
    return copied


def named_child(
    owner: ElementTree.Element,
    tag: str,
    name: str,
) -> ElementTree.Element | None:
    return next(
        (child for child in owner if child.tag == tag and child.get("name") == name),
        None,
    )


def accessor_result(method: ElementTree.Element) -> ElementTree.Element | None:
    return_value = method.find(RETURN_VALUE_TAG)
    if return_value is not None:
        value_type = return_value.find(TYPE_TAG)
        if value_type is None or value_type.get("name") != "none":
            return return_value

    parameters = method.find(PARAMETERS_TAG)
    if parameters is None:
        return None
    return next(
        (
            parameter
            for parameter in parameters
            if parameter.tag == PARAMETER_TAG
            and parameter.get("name") == "result"
            and parameter.get("direction") == "out"
        ),
        None,
    )


def setter_value(method: ElementTree.Element) -> ElementTree.Element | None:
    parameters = method.find(PARAMETERS_TAG)
    if parameters is None:
        return None
    return named_child(parameters, PARAMETER_TAG, "value")


def property_page(html_root: Path, symbol: str) -> Path | None:
    candidates = [html_root / f"{symbol}.html"]
    candidates.extend(html_root.glob(f"*/{symbol}.html"))
    matches = [candidate for candidate in candidates if candidate.is_file()]
    if len(matches) > 1:
        raise ValueError(f"multiple Valadoc pages found for {symbol}")
    return matches[0] if matches else None


def document_gobject_property(
    namespace_name: str,
    owner: ElementTree.Element,
    prop: ElementTree.Element,
) -> int:
    owner_name = owner.get("name") or ""
    property_name = prop.get("name") or ""
    source_name = property_name.replace("-", "_")
    getter = named_child(owner, METHOD_TAG, f"get_{source_name}")
    setter = named_child(owner, METHOD_TAG, f"set_{source_name}")
    field = named_child(owner, FIELD_TAG, f"_{source_name}")
    link = GirLink(
        "property",
        f"{namespace_name}.{owner_name}:{property_name}",
    ).render(source_name)

    added = 0
    description = documentation_text(prop)
    if getter is not None:
        prop.set("getter", getter.get("name") or "")
        getter.set(GLIB_GET_PROPERTY_ATTRIBUTE, property_name)
        added += add_documentation(getter, f"Gets the value of {link}.")
        result = accessor_result(getter)
        if result is None:
            raise ValueError(f"getter has no result: {owner_name}.get_{source_name}")
        added += add_documentation(result, f"The value of {link}.")
    if setter is not None:
        prop.set("setter", setter.get("name") or "")
        setter.set(GLIB_SET_PROPERTY_ATTRIBUTE, property_name)
        added += add_documentation(setter, f"Sets the value of {link}.")
        value = setter_value(setter)
        if value is None:
            raise ValueError(f"setter has no value: {owner_name}.set_{source_name}")
        added += add_documentation(value, f"The new value of {link}.")
    if description:
        added += add_documentation(field, description)
    return added


def document_source_property(
    namespace_name: str,
    owner: ElementTree.Element,
    source_name: str,
    html_root: Path,
    renderer: DocumentationRenderer,
) -> int:
    owner_name = owner.get("name") or ""
    symbol = f"{namespace_name}.{owner_name}.{source_name}"
    page = property_page(html_root, symbol)
    if page is None:
        return 0

    getter = named_child(owner, METHOD_TAG, f"get_{source_name}")
    setter = named_child(owner, METHOD_TAG, f"set_{source_name}")
    field = named_child(owner, FIELD_TAG, f"_{source_name}")
    description = renderer.html_description(page, symbol)
    description = description or documentation_text(field)
    member = code_span(source_name)

    added = 0
    if description:
        added += add_documentation(field, description)
    if getter is not None:
        summary = f"Gets the value of {member}."
        method_doc = f"{summary}\n\n{description}" if description else summary
        added += add_documentation(getter, method_doc)
        result = accessor_result(getter)
        if result is None:
            raise ValueError(f"getter has no result: {owner_name}.get_{source_name}")
        added += add_documentation(result, f"The value of {member}.")
    if setter is not None:
        summary = f"Sets the value of {member}."
        method_doc = f"{summary}\n\n{description}" if description else summary
        added += add_documentation(setter, method_doc)
        value = setter_value(setter)
        if value is None:
            raise ValueError(f"setter has no value: {owner_name}.set_{source_name}")
        added += add_documentation(value, f"The new value of {member}.")
    return added


def augment_properties(
    namespace: ElementTree.Element,
    html_root: Path,
    renderer: DocumentationRenderer,
) -> int:
    namespace_name = namespace.get("name") or ""
    added = 0
    for owner in namespace:
        if local_name(owner) not in API_TYPE_TAGS:
            continue

        gobject_properties = {
            prop.get("name", "").replace("-", "_")
            for prop in owner
            if prop.tag == PROPERTY_TAG
        }
        for prop in (child for child in owner if child.tag == PROPERTY_TAG):
            added += document_gobject_property(namespace_name, owner, prop)

        candidates: set[str] = set()
        for child in owner:
            name = child.get("name") or ""
            if child.tag == FIELD_TAG and name.startswith("_"):
                candidates.add(name[1:])
            elif child.tag == METHOD_TAG and name.startswith(("get_", "set_")):
                candidates.add(name[4:])

        for source_name in sorted(candidates - gobject_properties):
            added += document_source_property(
                namespace_name,
                owner,
                source_name,
                html_root,
                renderer,
            )
    return added


def find_namespace(
    tree: ElementTree.ElementTree,
    filename: Path,
) -> ElementTree.Element:
    namespace = tree.getroot().find(qualified_name(CORE_NAMESPACE, "namespace"))
    if namespace is None:
        raise ValueError(f"GIR has no namespace: {filename}")
    return namespace


def set_documentation_format(root: ElementTree.Element) -> None:
    format_element = root.find(DOC_FORMAT_TAG)
    if format_element is None:
        format_element = ElementTree.Element(DOC_FORMAT_TAG)
        namespace = root.find(qualified_name(CORE_NAMESPACE, "namespace"))
        index = list(root).index(namespace) if namespace is not None else 0
        root.insert(index, format_element)
    format_element.set("name", "gi-docgen")


def merge_girs(
    compiler_path: Path,
    valadoc_path: Path,
    html_root: Path,
    output_path: Path,
) -> None:
    compiler_tree = ElementTree.parse(compiler_path)
    valadoc_tree = ElementTree.parse(valadoc_path)
    compiler_namespace = find_namespace(compiler_tree, compiler_path)
    valadoc_namespace = find_namespace(valadoc_tree, valadoc_path)
    renderer = DocumentationRenderer(SymbolIndex(compiler_namespace))

    copied = copy_documentation(
        compiler_namespace,
        valadoc_namespace,
        element_label(compiler_namespace),
        renderer,
    )
    if copied == 0:
        raise ValueError(f"Valadoc GIR contains no documentation: {valadoc_path}")

    augment_properties(compiler_namespace, html_root, renderer)
    set_documentation_format(compiler_tree.getroot())
    ElementTree.indent(compiler_tree, space="  ")
    compiler_tree.write(output_path, encoding="utf-8", xml_declaration=True)


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print(
            "usage: merge_gir_docs.py "
            "COMPILER_GIR VALADOC_GIR VALADOC_HTML OUTPUT_GIR",
            file=sys.stderr,
        )
        return 2

    compiler_path, valadoc_path, html_root, output_path = map(Path, argv[1:])
    try:
        merge_girs(compiler_path, valadoc_path, html_root, output_path)
    except (ElementTree.ParseError, OSError, UnicodeError, ValueError) as error:
        print(f"merge_gir_docs.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
