using Lsp;

/*
 * Client capability tests cover the full nested hierarchy sent in
 * InitializeParams: workspace edits, text synchronization, and completion.
 * Array-valued fields are populated so both their element encodings and the
 * containing capability objects are exercised.
 */

private void test_client_capabilities_round_trip () {
    try {
        var workspace_edit = WorkspaceEditClientCaps ();
        workspace_edit.flags = WorkspaceEditClientFlags.DOCUMENT_CHANGES |
            WorkspaceEditClientFlags.NORMALIZES_LINE_ENDINGS |
            WorkspaceEditClientFlags.CHANGE_ANNOTATIONS |
            WorkspaceEditClientFlags.CHANGE_ANNOTATIONS_GROUP_ON_LABEL;
        workspace_edit.resource_ops = ResourceOperationKind.CREATE |
            ResourceOperationKind.RENAME |
            ResourceOperationKind.DELETE;
        workspace_edit.failure_handling = FailureHandlingKind.TRANSACTIONAL;
        var completion = new CompletionClientCaps () {
            flags = CompletionClientFlags.SNIPPETS |
                CompletionClientFlags.COMMIT_CHARACTERS |
                CompletionClientFlags.DEPRECATED_PROPERTY |
                CompletionClientFlags.PRESELECT_PROPERTY |
                CompletionClientFlags.INSERT_REPLACE |
                CompletionClientFlags.CONTEXT |
                CompletionClientFlags.LABEL_DETAILS,
            documentation_formats = {
                MarkupKind.MARKDOWN,
                MarkupKind.PLAINTEXT
            },
            supported_tags = CompletionItemTag.DEPRECATED,
            resolve_properties = { "documentation", "detail" },
            insert_text_modes = InsertTextModeFlags.AS_IS |
                InsertTextModeFlags.ADJUST_INDENTATION,
            item_kinds = CompletionItemKindFlags.TEXT |
                CompletionItemKindFlags.FUNCTION |
                CompletionItemKindFlags.TYPE_PARAMETER
        };
        var workspace = WorkspaceClientCaps ();
        workspace.flags = WorkspaceClientFlags.APPLY_EDIT;
        workspace.workspace_edit = workspace_edit;
        var text_document = new TextDocumentClientCaps ();
        text_document.synchronization =
            TextDocumentSyncClientCaps.WILL_SAVE |
            TextDocumentSyncClientCaps.WILL_SAVE_WAIT_UNTIL |
            TextDocumentSyncClientCaps.DID_SAVE;
        text_document.completion = completion;
        var original = new ClientCaps ();
        original.workspace = workspace;
        original.text_document = text_document;

        var decoded = new ClientCaps.from_variant (
            original.to_variant ());
        assert (WorkspaceClientFlags.APPLY_EDIT in decoded.workspace.flags);
        var decoded_edit = decoded.workspace.workspace_edit;
        assert (WorkspaceEditClientFlags.DOCUMENT_CHANGES in decoded_edit.flags);
        assert (ResourceOperationKind.CREATE in decoded_edit.resource_ops);
        assert (ResourceOperationKind.RENAME in decoded_edit.resource_ops);
        assert (ResourceOperationKind.DELETE in decoded_edit.resource_ops);
        assert (
            decoded_edit.failure_handling ==
            FailureHandlingKind.TRANSACTIONAL);
        assert (WorkspaceEditClientFlags.NORMALIZES_LINE_ENDINGS in decoded_edit.flags);
        assert (WorkspaceEditClientFlags.CHANGE_ANNOTATIONS in decoded_edit.flags);
        assert (WorkspaceEditClientFlags.CHANGE_ANNOTATIONS_GROUP_ON_LABEL in
            decoded_edit.flags);

        assert (decoded.text_document != null);
        var decoded_text_document = (!) decoded.text_document;
        assert (TextDocumentSyncClientCaps.WILL_SAVE in
            decoded_text_document.synchronization);
        assert (
            TextDocumentSyncClientCaps.WILL_SAVE_WAIT_UNTIL in
            decoded_text_document.synchronization);
        assert (
            TextDocumentSyncClientCaps.DID_SAVE in
            decoded_text_document.synchronization);
        assert (decoded_text_document.completion != null);
        var decoded_completion = (!) decoded_text_document.completion;
        assert (CompletionClientFlags.SNIPPETS in decoded_completion.flags);
        assert (CompletionClientFlags.COMMIT_CHARACTERS in decoded_completion.flags);
        assert (decoded_completion.documentation_formats != null);
        assert (decoded_completion.documentation_formats.length == 2);
        assert (
            decoded_completion.documentation_formats[0] ==
            MarkupKind.MARKDOWN);
        assert (CompletionClientFlags.DEPRECATED_PROPERTY in decoded_completion.flags);
        assert (CompletionClientFlags.PRESELECT_PROPERTY in decoded_completion.flags);
        assert (
            CompletionItemTag.DEPRECATED in
            decoded_completion.supported_tags);
        assert (CompletionClientFlags.INSERT_REPLACE in decoded_completion.flags);
        assert (decoded_completion.resolve_properties != null);
        assert (decoded_completion.resolve_properties.length == 2);
        assert (InsertTextModeFlags.AS_IS in decoded_completion.insert_text_modes);
        assert (InsertTextModeFlags.ADJUST_INDENTATION in
            decoded_completion.insert_text_modes);
        assert (CompletionItemKindFlags.TEXT in decoded_completion.item_kinds);
        assert (CompletionItemKindFlags.FUNCTION in decoded_completion.item_kinds);
        assert (CompletionItemKindFlags.TYPE_PARAMETER in
            decoded_completion.item_kinds);
        assert (CompletionClientFlags.CONTEXT in decoded_completion.flags);
        assert (CompletionClientFlags.LABEL_DETAILS in decoded_completion.flags);
    } catch (DeserializeError e) {
        error ("client capabilities round trip failed: %s", e.message);
    }
}

private void test_failure_handling_default () {
    try {
        var unset = WorkspaceEditClientCaps ();
        assert (
            unset.to_variant ().lookup_value (
                "failureHandling",
                VariantType.STRING) == null);

        var abort = WorkspaceEditClientCaps ();
        abort.failure_handling = FailureHandlingKind.ABORT;
        var encoded = abort.to_variant ();
        var value = encoded.lookup_value (
            "failureHandling",
            VariantType.STRING);
        assert (value != null);
        assert ((string) value == "abort");

        var decoded = WorkspaceEditClientCaps.from_variant (encoded);
        assert (decoded.failure_handling == FailureHandlingKind.ABORT);
    } catch (DeserializeError e) {
        error ("failure handling round trip failed: %s", e.message);
    }
}

private void test_flag_only_capability_presence () {
    try {
        var without_symbols = new TextDocumentClientCaps ();
        without_symbols.rename = RenameClientCaps.SUPPORTED;
        var without_symbols_client = new ClientCaps ();
        without_symbols_client.text_document = without_symbols;
        var text_without_symbols = without_symbols_client.to_variant ().lookup_value (
            "textDocument",
            VariantType.VARDICT);
        assert (text_without_symbols != null);
        assert (text_without_symbols.lookup_value (
            "documentSymbol",
            VariantType.VARDICT) == null);

        var text_caps = new TextDocumentClientCaps ();
        text_caps.document_symbol = DocumentSymbolClientCaps ();
        text_caps.rename = RenameClientCaps.SUPPORTED;
        text_caps.type_hierarchy = TypeHierarchyClientCaps.SUPPORTED;
        var original = new ClientCaps ();
        original.text_document = text_caps;
        var encoded = original.to_variant ();
        var text_document = encoded.lookup_value ("textDocument", VariantType.VARDICT);
        assert (text_document != null);
        assert (text_document.lookup_value ("documentSymbol", VariantType.VARDICT) != null);
        assert (text_document.lookup_value ("rename", VariantType.VARDICT) != null);
        assert (text_document.lookup_value ("typeHierarchy", VariantType.VARDICT) != null);

        var decoded = new ClientCaps.from_variant (encoded);
        assert (decoded.text_document != null);
        var decoded_text = (!) decoded.text_document;
        assert (DocumentSymbolClientFlags.SUPPORTED in
            decoded_text.document_symbol.flags);
        assert (RenameClientCaps.SUPPORTED in decoded_text.rename);
        assert (TypeHierarchyClientCaps.SUPPORTED in decoded_text.type_hierarchy);
    } catch (DeserializeError e) {
        error ("flag-only capability round trip failed: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/client-capabilities/full",
        test_client_capabilities_round_trip);
    Test.add_func (
        "/serialization/client-capabilities/failure-handling-default",
        test_failure_handling_default);
    Test.add_func (
        "/serialization/client-capabilities/flag-only-presence",
        test_flag_only_capability_presence);
    return Test.run ();
}
