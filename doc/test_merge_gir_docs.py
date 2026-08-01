#!/usr/bin/env python3

# Copyright 2026 Princeton Ferro <princetonferro@gmail.com>
# SPDX-License-Identifier: LGPL-2.1-or-later

"""Tests for the temporary Valadoc-to-GIR documentation bridge."""

import argparse
import tempfile
import unittest
import xml.etree.ElementTree as ElementTree
from pathlib import Path

import merge_gir_docs as merger


INTEGRATION_GIR: Path | None = None
VALADOC_HTML: Path | None = None
GI_DOCS: Path | None = None


def element(tag: str, name: str | None = None) -> ElementTree.Element:
    node = ElementTree.Element(merger.qualified_name(merger.CORE_NAMESPACE, tag))
    if name is not None:
        node.set("name", name)
    return node


def add_type(
    parent: ElementTree.Element,
    name: str,
    c_type: str,
) -> ElementTree.Element:
    node = ElementTree.SubElement(parent, merger.TYPE_TAG)
    node.set("name", name)
    node.set(merger.C_TYPE_ATTRIBUTE, c_type)
    return node


def add_doc(parent: ElementTree.Element, text: str) -> None:
    parent.insert(0, merger.new_documentation(text))


def add_method(
    owner: ElementTree.Element,
    name: str,
    return_type: tuple[str, str] = ("none", "void"),
    *,
    result_type: tuple[str, str] | None = None,
    value_type: tuple[str, str] | None = None,
) -> ElementTree.Element:
    method = ElementTree.SubElement(owner, merger.METHOD_TAG)
    method.set("name", name)
    method.set(merger.C_IDENTIFIER_ATTRIBUTE, f"lsp_test_{name}")

    return_value = ElementTree.SubElement(method, merger.RETURN_VALUE_TAG)
    add_type(return_value, *return_type)
    parameters = ElementTree.SubElement(method, merger.PARAMETERS_TAG)
    if result_type:
        result = ElementTree.SubElement(parameters, merger.PARAMETER_TAG)
        result.set("name", "result")
        result.set("direction", "out")
        add_type(result, *result_type)
    if value_type:
        value = ElementTree.SubElement(parameters, merger.PARAMETER_TAG)
        value.set("name", "value")
        add_type(value, *value_type)
    return method


def make_namespace() -> ElementTree.Element:
    namespace = element("namespace", "Lsp")
    range_type = element("record", "Range")
    range_type.set(merger.C_TYPE_ATTRIBUTE, "LspRange")
    namespace.append(range_type)
    return namespace


def find_named(
    parent: ElementTree.Element,
    tag: str,
    name: str,
) -> ElementTree.Element:
    result = merger.named_child(parent, tag, name)
    assert result is not None
    return result


class PropertyDocumentationTests(unittest.TestCase):
    def test_gobject_accessors_link_to_property(self) -> None:
        namespace = make_namespace()
        owner = element("class", "Widget")
        namespace.append(owner)

        prop = element("property", "title")
        add_doc(prop, "The complete property description.")
        owner.append(prop)
        getter = add_method(owner, "get_title", ("utf8", "gchar*"))
        setter = add_method(
            owner,
            "set_title",
            value_type=("utf8", "gchar*"),
        )

        merger.document_gobject_property("Lsp", owner, prop)

        self.assertEqual(prop.get("getter"), "get_title")
        self.assertEqual(prop.get("setter"), "set_title")
        self.assertEqual(
            getter.get(merger.GLIB_GET_PROPERTY_ATTRIBUTE),
            "title",
        )
        self.assertEqual(
            setter.get(merger.GLIB_SET_PROPERTY_ATTRIBUTE),
            "title",
        )
        getter_doc = merger.documentation_text(getter) or ""
        self.assertIn("[property@Lsp.Widget:title]", getter_doc)
        self.assertNotIn("complete property description", getter_doc)
        self.assertIn(
            "[property@Lsp.Widget:title]",
            merger.documentation_text(getter.find(merger.RETURN_VALUE_TAG)) or "",
        )

    def test_record_property_documents_field_and_accessors(self) -> None:
        namespace = make_namespace()
        owner = element("record", "Highlight")
        namespace.append(owner)
        field = element("field", "_range")
        add_type(field, "Lsp.Range", "LspRange")
        owner.append(field)
        getter = add_method(
            owner,
            "get_range",
            result_type=("Lsp.Range", "LspRange*"),
        )
        setter = add_method(
            owner,
            "set_range",
            value_type=("Lsp.Range", "LspRange*"),
        )

        with tempfile.TemporaryDirectory() as directory:
            html_root = Path(directory)
            (html_root / "Lsp.Highlight.range.html").write_text(
                '<html><div class="description">'
                '<p>The associated <a href="Lsp.Range.html">range</a>.</p>'
                "</div></html>",
                encoding="utf-8",
            )
            renderer = merger.DocumentationRenderer(merger.SymbolIndex(namespace))
            merger.document_source_property(
                "Lsp",
                owner,
                "range",
                html_root,
                renderer,
            )

        field_doc = merger.documentation_text(field) or ""
        self.assertIn("[type@Lsp.Range]", field_doc)
        self.assertIn("The associated", merger.documentation_text(getter) or "")
        result = find_named(
            getter.find(merger.PARAMETERS_TAG),
            merger.PARAMETER_TAG,
            "result",
        )
        self.assertEqual(merger.documentation_text(result), "The value of `range`.")
        value = find_named(
            setter.find(merger.PARAMETERS_TAG),
            merger.PARAMETER_TAG,
            "value",
        )
        self.assertEqual(
            merger.documentation_text(value),
            "The new value of `range`.",
        )

    def test_explicit_docs_win_and_unrelated_getter_is_ignored(self) -> None:
        namespace = make_namespace()
        owner = element("record", "Example")
        namespace.append(owner)
        field = element("field", "_value")
        add_doc(field, "Field documentation.")
        owner.append(field)
        getter = add_method(owner, "get_value", ("gint", "gint"))
        add_doc(getter, "Custom getter documentation.")
        unrelated = add_method(owner, "get_noise", ("gint", "gint"))

        with tempfile.TemporaryDirectory() as directory:
            html_root = Path(directory)
            (html_root / "Lsp.Example.value.html").write_text(
                '<div class="description"></div>',
                encoding="utf-8",
            )
            renderer = merger.DocumentationRenderer(merger.SymbolIndex(namespace))
            merger.augment_properties(namespace, html_root, renderer)

        self.assertEqual(
            merger.documentation_text(getter),
            "Custom getter documentation.",
        )
        self.assertIsNone(merger.documentation_text(unrelated))


class MarkupTests(unittest.TestCase):
    def test_semantic_links_resolve_from_gir(self) -> None:
        namespace = make_namespace()
        enum = element("enumeration", "Mode")
        enum.set(merger.C_TYPE_ATTRIBUTE, "LspMode")
        member = element("member", "unset")
        member.set(merger.C_IDENTIFIER_ATTRIBUTE, "LSP_MODE_UNSET")
        enum.append(member)
        namespace.append(enum)
        function = element("function", "run")
        function.set(merger.C_IDENTIFIER_ATTRIBUTE, "lsp_run")
        namespace.append(function)

        renderer = merger.DocumentationRenderer(merger.SymbolIndex(namespace))
        result = renderer.gir_markup(
            "<para>Use <type>LspRange</type>, "
            "<type>LSP_MODE_UNSET</type>, and <function>lsp_run</function>. "
            "Keep <type>UnknownType</type> readable.</para>",
            "test",
        )
        self.assertIn("[type@Lsp.Range]", result)
        self.assertIn("[enum@Lsp.Mode.UNSET]", result)
        self.assertIn("[id@lsp_run]", result)
        self.assertIn("`UnknownType`", result)

    def test_copying_does_not_replace_existing_docs(self) -> None:
        compiler = element("record", "Example")
        valadoc = element("record", "Example")
        add_doc(compiler, "Compiler documentation.")
        add_doc(valadoc, "Valadoc documentation.")
        namespace = make_namespace()
        renderer = merger.DocumentationRenderer(merger.SymbolIndex(namespace))

        copied = merger.copy_documentation(
            compiler,
            valadoc,
            "Example",
            renderer,
        )
        self.assertEqual(copied, 0)
        self.assertEqual(
            merger.documentation_text(compiler),
            "Compiler documentation.",
        )


class GeneratedDocumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if INTEGRATION_GIR is None:
            raise unittest.SkipTest("generated documentation not provided")
        tree = ElementTree.parse(INTEGRATION_GIR)
        cls.namespace = merger.find_namespace(tree, INTEGRATION_GIR)

    def owner(self, kind: str, name: str) -> ElementTree.Element:
        tag = merger.qualified_name(merger.CORE_NAMESPACE, kind)
        return find_named(self.namespace, tag, name)

    def test_client_property_and_record_field(self) -> None:
        client = self.owner("class", "Client")
        prop = find_named(client, merger.PROPERTY_TAG, "cancellable")
        getter = find_named(client, merger.METHOD_TAG, "get_cancellable")
        self.assertEqual(prop.get("getter"), "get_cancellable")
        self.assertIn(
            "[property@Lsp.Client:cancellable]",
            merger.documentation_text(getter) or "",
        )
        self.assertNotIn("For requests", merger.documentation_text(getter) or "")

        highlight = self.owner("record", "DocumentHighlight")
        field = find_named(highlight, merger.FIELD_TAG, "_range")
        self.assertIn("range this highlight", merger.documentation_text(field) or "")
        result = merger.accessor_result(
            find_named(highlight, merger.METHOD_TAG, "get_range")
        )
        self.assertEqual(merger.documentation_text(result), "The value of `range`.")

    def test_html_outputs_and_external_links(self) -> None:
        assert VALADOC_HTML is not None
        assert GI_DOCS is not None
        self.assertTrue((VALADOC_HTML / "index.html").is_file())
        self.assertFalse(any(VALADOC_HTML.rglob("*.devhelp*")))
        self.assertTrue((GI_DOCS / "index.html").is_file())
        self.assertIn(
            "property.Client.cancellable.html",
            (GI_DOCS / "method.Client.get_cancellable.html").read_text(
                encoding="utf-8"
            ),
        )
        self.assertIn(
            'data-namespace="Jsonrpc"',
            (GI_DOCS / "class.Client.html").read_text(encoding="utf-8"),
        )
        self.assertIn(
            'data-namespace="GLib"',
            (GI_DOCS / "class.Server.html").read_text(encoding="utf-8"),
        )
        urlmap = (GI_DOCS / "urlmap.js").read_text(encoding="utf-8")
        self.assertIn("https://docs.gtk.org/glib/", urlmap)
        self.assertIn("jsonrpc-glib/jsonrpc-glib/", urlmap)


def main() -> None:
    global INTEGRATION_GIR, VALADOC_HTML, GI_DOCS

    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--gir", type=Path)
    parser.add_argument("--valadoc-html", type=Path)
    parser.add_argument("--gi-docs", type=Path)
    args, unittest_args = parser.parse_known_args()
    INTEGRATION_GIR = args.gir
    VALADOC_HTML = args.valadoc_html
    GI_DOCS = args.gi_docs
    unittest.main(argv=[__file__, *unittest_args])


if __name__ == "__main__":
    main()
