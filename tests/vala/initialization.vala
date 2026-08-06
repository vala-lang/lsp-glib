using Lsp;

/*
 * Initialization tests cover deeply nested server capabilities and the
 * lifecycle payloads exchanged before ordinary language feature requests.
 */

private Uri parse_uri (string value) {
    try {
        return Uri.parse (value, UriFlags.NONE);
    } catch (UriError e) {
        error ("failed to parse test URI: %s", e.message);
    }
}

private ServerCaps make_server_capabilities () {
    var completion = new CompletionOptions (true);
    completion.add_trigger (".");
    completion.add_trigger (":");
    completion.add_commit_trigger (";");
    completion.add_commit_trigger (")");

    var signature_help = new SignatureHelpOptions ();
    signature_help.add_trigger ("(");
    signature_help.add_trigger (",");
    signature_help.add_retrigger (")");

    var on_type_formatting = new DocumentOnTypeFormattingOptions ("}");
    on_type_formatting.add_trigger (";");
    on_type_formatting.add_trigger ("\n");

    return new ServerCaps () {
        text_document_sync = TextDocumentSyncKind.INCREMENTAL,
        completion = completion,
        hover = true,
        signature_help = signature_help,
        declaration = true,
        definition = true,
        type_definition = true,
        implementation = true,
        references = true,
        document_highlight = true,
        document_symbol = true,
        code_action = true,
        code_lens = CodeLensOptions (true),
        document_link = DocumentLinkOptions (true),
        document_formatting = true,
        document_range_formatting = true,
        document_on_type_formatting = on_type_formatting,
        rename = RenameOptions (true),
        call_hierarchy = CallHierarchyOptions (),
        inlay_hint = InlayHintOptions (true),
        workspace_symbol = true
    };
}

private void test_server_capabilities_round_trip () {
    try {
        var decoded = new ServerCaps.from_variant (
            make_server_capabilities ().to_variant ());

        assert (
            decoded.text_document_sync ==
            TextDocumentSyncKind.INCREMENTAL);
        assert (decoded.completion != null);
        assert (decoded.completion.supports_resolve);
        assert (decoded.completion.triggers.length == 2);
        assert (decoded.completion.triggers[0] == ".");
        assert (decoded.completion.commit_triggers.length == 2);
        assert (decoded.hover);
        assert (decoded.signature_help != null);
        assert (decoded.signature_help.triggers.length == 2);
        assert (decoded.signature_help.retriggers.length == 1);
        assert (decoded.declaration);
        assert (decoded.definition);
        assert (decoded.type_definition);
        assert (decoded.implementation);
        assert (decoded.references);
        assert (decoded.document_highlight);
        assert (decoded.document_symbol);
        assert (decoded.code_action);
        assert (decoded.code_lens.supported);
        assert (decoded.code_lens.supports_resolve);
        assert (decoded.document_link.supported);
        assert (decoded.document_link.supports_resolve);
        assert (decoded.document_formatting);
        assert (decoded.document_range_formatting);
        assert (decoded.document_on_type_formatting != null);
        assert (
            decoded.document_on_type_formatting.first_trigger == "}");
        assert (
            decoded.document_on_type_formatting.more_triggers.length == 2);
        assert (decoded.rename.supported);
        assert (decoded.rename.supports_prepare);
        assert (decoded.call_hierarchy.supported);
        assert (decoded.inlay_hint.supported);
        assert (decoded.inlay_hint.resolve_provider);
        assert (decoded.workspace_symbol);
    } catch (DeserializeError e) {
        error ("server capabilities round trip failed: %s", e.message);
    }
}

private void test_initialize_params_round_trip () {
    try {
        var original = new InitializeParams (1234) {
            client_info = new ClientInfo ("Test Editor", "1.2.3"),
            locale = "en-US",
            root_path = "/workspace",
            root_uri = parse_uri ("file:///workspace"),
            capabilities = new ClientCaps (),
            trace = TraceValue.MESSAGES,
            initialization_options = new Variant.string ("test-options")
        };
        original.add_workspace (new WorkspaceFolder (
            parse_uri ("file:///workspace"),
            "primary"));
        original.add_workspace (new WorkspaceFolder (
            parse_uri ("file:///dependencies"),
            "dependencies"));

        var decoded = new InitializeParams.from_variant (
            original.to_variant ());
        assert (decoded.process_id == 1234);
        assert (decoded.client_info != null);
        assert (decoded.client_info.name == "Test Editor");
        assert (decoded.client_info.version == "1.2.3");
        assert (decoded.locale == "en-US");
        assert (decoded.root_path == "/workspace");
        assert (decoded.root_uri != null);
        assert (decoded.root_uri.to_string () == "file:///workspace");
        assert (decoded.trace == TraceValue.MESSAGES);
        assert (decoded.workspaces != null);
        assert (decoded.workspaces.length == 2);
        assert (decoded.workspaces[0].name == "primary");
        assert (
            decoded.workspaces[1].uri.to_string () ==
            "file:///dependencies");
        assert (decoded.initialization_options != null);
        assert (
            decoded.initialization_options.is_of_type (
                VariantType.STRING));
        assert (
            (string) decoded.initialization_options ==
            "test-options");
    } catch (DeserializeError e) {
        error ("initialize params round trip failed: %s", e.message);
    }
}

private void test_initialize_result_round_trip () {
    try {
        var original = new InitializeResult (
            make_server_capabilities ()) {
            server_info = new ServerInfo ("VLS", "3.18.0")
        };
        var decoded = new InitializeResult.from_variant (
            original.to_variant ());

        assert (
            decoded.capabilities.text_document_sync ==
            TextDocumentSyncKind.INCREMENTAL);
        assert (decoded.server_info != null);
        assert (decoded.server_info.name == "VLS");
        assert (decoded.server_info.version == "3.18.0");
    } catch (DeserializeError e) {
        error ("initialize result round trip failed: %s", e.message);
    }
}

private void test_empty_server_capabilities () {
    try {
        var decoded = new ServerCaps.from_variant (
            new VariantDict ().end ());
        assert (
            decoded.text_document_sync ==
            TextDocumentSyncKind.NONE);
        assert (!decoded.hover);
        assert (decoded.completion == null);
        assert (!decoded.code_lens.supported);
        assert (!decoded.document_link.supported);
        assert (!decoded.rename.supported);
        assert (!decoded.call_hierarchy.supported);
        assert (!decoded.type_hierarchy.supported);
        assert (!decoded.inlay_hint.supported);
    } catch (DeserializeError e) {
        error ("empty server capabilities were rejected: %s", e.message);
    }
}

private void test_boolean_server_capabilities () {
    var dict = new VariantDict ();
    dict.insert_value ("renameProvider", true);
    dict.insert_value ("callHierarchyProvider", true);
    dict.insert_value ("typeHierarchyProvider", true);
    dict.insert_value ("inlayHintProvider", true);

    try {
        var decoded = new ServerCaps.from_variant (dict.end ());
        assert (decoded.rename.supported);
        assert (!decoded.rename.supports_prepare);
        assert (decoded.call_hierarchy.supported);
        assert (decoded.type_hierarchy.supported);
        assert (decoded.inlay_hint.supported);
        assert (!decoded.inlay_hint.resolve_provider);
    } catch (DeserializeError e) {
        error ("boolean server capabilities were rejected: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/initialization/server-capabilities",
        test_server_capabilities_round_trip);
    Test.add_func (
        "/serialization/initialization/params",
        test_initialize_params_round_trip);
    Test.add_func (
        "/serialization/initialization/result",
        test_initialize_result_round_trip);
    Test.add_func (
        "/deserialization/initialization/empty-capabilities",
        test_empty_server_capabilities);
    Test.add_func (
        "/deserialization/initialization/boolean-capabilities",
        test_boolean_server_capabilities);
    return Test.run ();
}
