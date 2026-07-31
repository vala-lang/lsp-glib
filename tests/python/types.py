"""Exercise larger typed payloads through the generated PyGObject API.

These tests use the same GVariant serialization boundary exposed by lsp-glib.
The Editor/Server suites separately cover JSON-RPC framing and dispatch.
"""

# PyGObject namespaces are generated at runtime and do not provide .pyi files.
# pyright: reportMissingImports=false

import unittest
from typing import Any

import gi

gi.require_version("Lsp", "3.0")

from gi.repository import GLib, Lsp  # pyright: ignore[reportAttributeAccessIssue]


def make_range(
    start_line: int,
    start_character: int,
    end_line: int,
    end_character: int,
) -> Any:
    start = Lsp.Position()
    start.init(start_line, start_character)
    end = Lsp.Position()
    end.init(end_line, end_character)
    result = Lsp.Range()
    result.init(start, end)
    return result


class TypedSerializationTest(unittest.TestCase):
    def test_completion_list(self) -> None:
        edit = Lsp.TextEdit()
        edit.init(make_range(3, 4, 3, 9), "print(${1:value})", None)

        item = Lsp.CompletionItem.new(
            "print",
            Lsp.CompletionItemKind.FUNCTION,
        )
        label_details = Lsp.CompletionItemLabelDetails.new(
            "(value)",
            "GLib",
        )
        documentation = Lsp.MarkupContent.new(
            Lsp.MarkupKind.MARKDOWN,
            "**Print** a value.",
        )
        item.set_label_details(label_details)
        item.set_tags(Lsp.CompletionItemTag.DEPRECATED)
        item.set_documentation(documentation)
        item.set_commit_chars([";", "("])
        item.set_insert_text_format(Lsp.InsertTextFormat.SNIPPET)
        item.set_text_edit(edit)
        item.set_data(GLib.Variant("s", "completion-token"))

        decoded = Lsp.CompletionList.from_variant(
            Lsp.CompletionList.new(True, [item]).to_variant()
        )

        self.assertTrue(decoded.get_is_incomplete())
        decoded_items = decoded.get_items()
        self.assertEqual(len(decoded_items), 1)
        self.assertEqual(decoded_items[0].get_label(), "print")
        self.assertEqual(
            decoded_items[0].get_insert_text_format(),
            Lsp.InsertTextFormat.SNIPPET,
        )
        self.assertEqual(
            decoded_items[0].get_text_edit().get_new_text(),
            "print(${1:value})",
        )
        self.assertEqual(decoded_items[0].get_data().unpack(), "completion-token")

    def test_flat_protocol_records(self) -> None:
        highlight = Lsp.DocumentHighlight()
        highlight.init(
            make_range(2, 3, 2, 9),
            Lsp.DocumentHighlightKind.WRITE,
        )
        decoded_highlight = Lsp.DocumentHighlight()
        decoded_highlight.init_from_variant(highlight.to_variant())
        self.assertEqual(
            decoded_highlight.get_kind(),
            Lsp.DocumentHighlightKind.WRITE,
        )
        self.assertEqual(decoded_highlight.get_range().start.character, 3)

        context = Lsp.ReferenceContext()
        context.init(False)
        decoded_context = Lsp.ReferenceContext()
        decoded_context.init_from_variant(context.to_variant())
        self.assertFalse(decoded_context.get_include_declaration())

        options = Lsp.FormattingOptions()
        options.init(4, True)
        options.set_flags(
            Lsp.FormattingOptionFlags.TRIM_TRAILING_WHITESPACE
            | Lsp.FormattingOptionFlags.INSERT_FINAL_NEWLINE
            | Lsp.FormattingOptionFlags.TRIM_FINAL_NEWLINES
        )
        decoded_options = Lsp.FormattingOptions()
        decoded_options.init_from_variant(options.to_variant())
        self.assertEqual(decoded_options.get_tab_size(), 4)
        self.assertTrue(decoded_options.get_insert_spaces())
        self.assertTrue(
            decoded_options.get_flags()
            & Lsp.FormattingOptionFlags.TRIM_TRAILING_WHITESPACE
        )
        self.assertTrue(
            decoded_options.get_flags()
            & Lsp.FormattingOptionFlags.INSERT_FINAL_NEWLINE
        )
        self.assertTrue(
            decoded_options.get_flags()
            & Lsp.FormattingOptionFlags.TRIM_FINAL_NEWLINES
        )

    def test_initialization(self) -> None:
        root_uri = GLib.Uri.parse(
            "file:///workspace",
            GLib.UriFlags.NONE,
        )
        capabilities = Lsp.ServerCaps.new()
        completion = Lsp.CompletionOptions.new(True, [".", ":"])
        code_lens = Lsp.CodeLensOptions()
        code_lens.init(True)
        document_link = Lsp.DocumentLinkOptions()
        document_link.init(True)
        rename = Lsp.RenameOptions()
        rename.init(True)
        call_hierarchy = Lsp.CallHierarchyOptions()
        call_hierarchy.init()
        type_hierarchy = Lsp.TypeHierarchyOptions()
        type_hierarchy.init()
        inlay_hint = Lsp.InlayHintOptions()
        inlay_hint.init(True)
        capabilities.set_text_document_sync(
            Lsp.TextDocumentSyncKind.INCREMENTAL
        )
        capabilities.set_completion(completion)
        capabilities.set_hover(True)
        capabilities.set_code_lens(code_lens)
        capabilities.set_document_link(document_link)
        capabilities.set_rename(rename)
        capabilities.set_call_hierarchy(call_hierarchy)
        capabilities.set_type_hierarchy(type_hierarchy)
        capabilities.set_inlay_hint(inlay_hint)

        # Nullable integer properties are exposed as pointers by GI, so
        # PyGObject cannot safely marshal a non-null processId here.
        params = Lsp.InitializeParams.new()
        client_info = Lsp.ClientInfo.new("Test Editor", "1.2.3")
        workspace = Lsp.WorkspaceFolder.new(root_uri, "workspace")
        params.set_client_info(client_info)
        params.set_locale("en-US")
        params.set_root_uri(root_uri)
        params.set_trace(Lsp.TraceValue.MESSAGES)
        params.set_workspaces([workspace])
        params.set_initialization_options(
            GLib.Variant("s", "initialization-token")
        )

        decoded_params = Lsp.InitializeParams.from_variant(params.to_variant())
        self.assertEqual(decoded_params.get_client_info().get_name(), "Test Editor")
        self.assertEqual(decoded_params.get_locale(), "en-US")
        self.assertEqual(decoded_params.get_trace(), Lsp.TraceValue.MESSAGES)
        self.assertEqual(len(decoded_params.get_workspaces()), 1)
        self.assertEqual(
            decoded_params.get_initialization_options().unpack(),
            "initialization-token",
        )

        result = Lsp.InitializeResult.new(capabilities)
        server_info = Lsp.ServerInfo.new("VLS", "3.18.0")
        result.set_server_info(server_info)
        decoded_result = Lsp.InitializeResult.from_variant(result.to_variant())
        decoded_caps = decoded_result.get_capabilities()
        self.assertEqual(
            decoded_caps.get_text_document_sync(),
            Lsp.TextDocumentSyncKind.INCREMENTAL,
        )
        self.assertTrue(decoded_caps.get_completion().get_supports_resolve())
        self.assertTrue(decoded_caps.get_hover())
        self.assertTrue(decoded_caps.get_code_lens().get_supported())
        self.assertTrue(decoded_caps.get_code_lens().get_supports_resolve())
        self.assertTrue(decoded_caps.get_document_link().get_supported())
        self.assertTrue(
            decoded_caps.get_document_link().get_supports_resolve()
        )
        self.assertTrue(decoded_caps.get_rename().get_supported())
        self.assertTrue(decoded_caps.get_rename().get_supports_prepare())
        self.assertTrue(decoded_caps.get_call_hierarchy().get_supported())
        self.assertTrue(decoded_caps.get_type_hierarchy().get_supported())
        self.assertTrue(decoded_caps.get_inlay_hint().get_supported())
        self.assertTrue(decoded_caps.get_inlay_hint().get_resolve_provider())

    def test_workspace_edit(self) -> None:
        uri = GLib.Uri.parse(
            "file:///workspace/generated.vala",
            GLib.UriFlags.NONE,
        )
        create = Lsp.CreateFile.new()
        create.set_uri(uri)
        create.set_options(Lsp.CreateFileOptions.OVERWRITE)
        create.set_annotation_id("create-file")

        edit = Lsp.WorkspaceEdit.new()
        edit.add_document_change(create)
        annotation = Lsp.ChangeAnnotation.new(
            "Create generated source",
            True,
            "The file is generated by the compiler.",
        )
        edit.set_change_annotation(
            "create-file",
            annotation,
        )

        decoded = Lsp.WorkspaceEdit.from_variant(edit.to_variant())
        changes = decoded.get_document_changes()
        self.assertEqual(len(changes), 1)
        self.assertIsInstance(changes[0], Lsp.CreateFile)
        self.assertEqual(changes[0].get_uri().to_string(), uri.to_string())
        self.assertEqual(
            changes[0].get_options(),
            Lsp.CreateFileOptions.OVERWRITE,
        )
        annotations = decoded.get_change_annotations()
        self.assertEqual(
            annotations["create-file"].get_label(),
            "Create generated source",
        )
        self.assertTrue(
            annotations["create-file"].get_needs_confirmation()
        )

    def test_typed_protocol_unions(self) -> None:
        position = Lsp.Position()
        position.init(2, 9)
        part = Lsp.InlayHintLabelPart.new(": string")
        tooltip = Lsp.MarkupContent.new(
            Lsp.MarkupKind.MARKDOWN,
            "Inferred **type**",
        )
        part.set_tooltip(tooltip)

        hint = Lsp.InlayHint.new(
            position,
            "temporary",
            Lsp.InlayHintKind.TYPE,
        )
        hint.set_label_parts([part])
        hint.set_padding(
            Lsp.InlayHintPadding.LEFT | Lsp.InlayHintPadding.RIGHT
        )

        decoded_hint = Lsp.InlayHint.from_variant(hint.to_variant())
        self.assertIsNone(decoded_hint.get_label())
        self.assertEqual(decoded_hint.get_label_parts()[0].get_value(), ": string")

        uri = GLib.Uri.parse(
            "file:///workspace/main.vala",
            GLib.UriFlags.NONE,
        )
        symbol = Lsp.WorkspaceSymbol.new(
            "Example",
            Lsp.SymbolKind.CLASS,
            uri,
            make_range(0, 0, 6, 1),
            "demo",
            Lsp.SymbolTag.DEPRECATED,
        )
        decoded_symbol = Lsp.WorkspaceSymbol.from_variant(symbol.to_variant())
        self.assertEqual(decoded_symbol.get_uri().to_string(), uri.to_string())
        self.assertEqual(decoded_symbol.get_range().end.line, 6)
        self.assertEqual(decoded_symbol.get_tags(), Lsp.SymbolTag.DEPRECATED)

    def test_vls_protocol_results(self) -> None:
        uri = GLib.Uri.parse(
            "file:///workspace/main.vala",
            GLib.UriFlags.NONE,
        )
        range_ = make_range(0, 0, 5, 1)
        selection = make_range(0, 6, 0, 13)
        document_symbol = Lsp.DocumentSymbol.new(
            "Example",
            Lsp.SymbolKind.CLASS,
            range_,
            selection,
            None,
            Lsp.SymbolTag.UNSET,
        )
        hierarchical = Lsp.DocumentSymbolResult.for_document_symbols(
            [document_symbol]
        )
        decoded_hierarchical = Lsp.DocumentSymbolResult.from_variant(
            hierarchical.to_variant()
        )
        self.assertEqual(
            decoded_hierarchical.get_document_symbols()[0].get_name(),
            "Example",
        )
        self.assertEqual(
            len(decoded_hierarchical.get_symbol_information()),
            0,
        )

        location = Lsp.Location()
        location.init(uri, range_)
        flat_symbol = Lsp.SymbolInformation.new(
            "Example",
            Lsp.SymbolKind.CLASS,
            location,
            None,
            Lsp.SymbolTag.UNSET,
        )
        flat = Lsp.DocumentSymbolResult.for_symbol_information([flat_symbol])
        decoded_flat = Lsp.DocumentSymbolResult.from_variant(flat.to_variant())
        self.assertEqual(len(decoded_flat.get_document_symbols()), 0)
        self.assertEqual(
            decoded_flat.get_symbol_information()[0].get_name(),
            "Example",
        )

        prepared = Lsp.PrepareRenameResult()
        prepared.init_for_range(range_, "old_name")
        decoded_prepared = Lsp.PrepareRenameResult()
        decoded_prepared.init_from_variant(prepared.to_variant())
        self.assertTrue(decoded_prepared.has_range)
        self.assertEqual(decoded_prepared.placeholder, "old_name")
        self.assertEqual(decoded_prepared.range.start.character, 0)

        use_default = Lsp.PrepareRenameResult()
        use_default.init_for_default_behavior(True)
        decoded_default = Lsp.PrepareRenameResult()
        decoded_default.init_from_variant(use_default.to_variant())
        self.assertFalse(decoded_default.has_range)
        self.assertTrue(decoded_default.default_behavior)

        hierarchy_item = Lsp.TypeHierarchyItem.new(
            "Example",
            Lsp.SymbolKind.CLASS,
            uri,
            range_,
            selection,
            "class Example",
            Lsp.SymbolTag.DEPRECATED,
        )
        hierarchy_item.set_data(GLib.Variant("s", "hierarchy-token"))
        decoded_item = Lsp.TypeHierarchyItem.from_variant(
            hierarchy_item.to_variant()
        )
        self.assertEqual(decoded_item.get_name(), "Example")
        self.assertEqual(decoded_item.get_kind(), Lsp.SymbolKind.CLASS)
        self.assertEqual(decoded_item.get_tags(), Lsp.SymbolTag.DEPRECATED)
        self.assertEqual(decoded_item.get_data().unpack(), "hierarchy-token")

    def test_vls_capabilities_and_error_codes(self) -> None:
        symbol_caps = Lsp.DocumentSymbolClientCaps()
        symbol_caps.init(
            Lsp.DocumentSymbolClientFlags.DYNAMIC_REGISTRATION
            | Lsp.DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS
            | Lsp.DocumentSymbolClientFlags.LABEL,
            Lsp.SymbolKindFlags.CLASS
            | Lsp.SymbolKindFlags.METHOD
            | Lsp.SymbolKindFlags.TYPE_PARAMETER,
            Lsp.SymbolTag.DEPRECATED,
        )

        completion_caps = Lsp.CompletionClientCaps.new()
        completion_caps.set_insert_text_modes(
            Lsp.InsertTextModeFlags.AS_IS
            | Lsp.InsertTextModeFlags.ADJUST_INDENTATION
        )
        completion_caps.set_item_kinds(
            Lsp.CompletionItemKindFlags.TEXT
            | Lsp.CompletionItemKindFlags.FUNCTION
            | Lsp.CompletionItemKindFlags.TYPE_PARAMETER
        )

        workspace_edit = Lsp.WorkspaceEditClientCaps()
        workspace_edit.init(
            Lsp.WorkspaceEditClientFlags.DOCUMENT_CHANGES
            | Lsp.WorkspaceEditClientFlags.NORMALIZES_LINE_ENDINGS,
            Lsp.ResourceOperationKind.CREATE
            | Lsp.ResourceOperationKind.RENAME,
            Lsp.FailureHandlingKind.UNSET,
        )
        workspace_caps = Lsp.WorkspaceClientCaps()
        workspace_caps.init_with_workspace_edit(
            workspace_edit,
            Lsp.WorkspaceClientFlags.APPLY_EDIT,
        )

        text_caps = Lsp.TextDocumentClientCaps.new()
        text_caps.set_synchronization(
            Lsp.TextDocumentSyncClientCaps.WILL_SAVE
            | Lsp.TextDocumentSyncClientCaps.DID_SAVE,
        )
        text_caps.set_completion(completion_caps)
        text_caps.set_document_symbol(symbol_caps)
        text_caps.set_rename(
            Lsp.RenameClientCaps.SUPPORTED
            | Lsp.RenameClientCaps.PREPARE_SUPPORT
            | Lsp.RenameClientCaps.HONORS_CHANGE_ANNOTATIONS,
        )
        text_caps.set_rename_prepare_support_default_behavior(
            Lsp.PrepareSupportDefaultBehavior.IDENTIFIER,
        )
        text_caps.set_type_hierarchy(
            Lsp.TypeHierarchyClientCaps.SUPPORTED
            | Lsp.TypeHierarchyClientCaps.DYNAMIC_REGISTRATION,
        )
        client_caps = Lsp.ClientCaps.new()
        client_caps.set_workspace(workspace_caps)
        client_caps.set_text_document(text_caps)

        decoded_client = Lsp.ClientCaps.from_variant(client_caps.to_variant())
        decoded_workspace = decoded_client.get_workspace()
        self.assertTrue(
            decoded_workspace.get_flags()
            & Lsp.WorkspaceClientFlags.APPLY_EDIT
        )
        self.assertTrue(
            decoded_workspace.get_workspace_edit().get_resource_ops()
            & Lsp.ResourceOperationKind.CREATE
        )
        decoded_text = decoded_client.get_text_document()
        self.assertTrue(
            decoded_text.get_synchronization()
            & Lsp.TextDocumentSyncClientCaps.WILL_SAVE
        )
        self.assertTrue(
            decoded_text.get_completion().get_insert_text_modes()
            & Lsp.InsertTextModeFlags.ADJUST_INDENTATION
        )
        self.assertTrue(
            decoded_text.get_completion().get_item_kinds()
            & Lsp.CompletionItemKindFlags.TYPE_PARAMETER
        )
        self.assertTrue(
            decoded_text.get_document_symbol().get_flags()
            & Lsp.DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS
        )
        self.assertTrue(
            decoded_text.get_document_symbol().get_symbol_kinds()
            & Lsp.SymbolKindFlags.TYPE_PARAMETER
        )
        self.assertTrue(
            decoded_text.get_rename()
            & Lsp.RenameClientCaps.PREPARE_SUPPORT
        )
        self.assertEqual(
            decoded_text.get_rename_prepare_support_default_behavior(),
            Lsp.PrepareSupportDefaultBehavior.IDENTIFIER,
        )
        self.assertTrue(
            decoded_text.get_type_hierarchy()
            & Lsp.TypeHierarchyClientCaps.DYNAMIC_REGISTRATION
        )

        server_caps = Lsp.ServerCaps.new()
        type_hierarchy = Lsp.TypeHierarchyOptions()
        type_hierarchy.init()
        server_caps.set_type_hierarchy(type_hierarchy)
        decoded_server = Lsp.ServerCaps.from_variant(server_caps.to_variant())
        self.assertTrue(decoded_server.get_type_hierarchy().get_supported())

        expected_errors = {
            "PARSE_ERROR": -32700,
            "INVALID_REQUEST": -32600,
            "METHOD_NOT_FOUND": -32601,
            "INVALID_PARAMS": -32602,
            "INTERNAL_ERROR": -32603,
            "SERVER_NOT_INITIALIZED": -32002,
            "UNKNOWN_ERROR_CODE": -32001,
            "REQUEST_FAILED": -32803,
            "SERVER_CANCELLED": -32802,
            "CONTENT_MODIFIED": -32801,
            "REQUEST_CANCELLED": -32800,
        }
        for name, value in expected_errors.items():
            self.assertEqual(int(getattr(Lsp.ProtocolError, name)), value)


if __name__ == "__main__":
    unittest.main()
