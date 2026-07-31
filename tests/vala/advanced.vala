using Lsp;

/*
 * Advanced payloads contain protocol unions and deeply nested arrays. These
 * tests exercise signature offset labels, structured inlay labels, and the
 * Command|CodeAction union through the public typed API.
 */

private Uri parse_uri (string value) {
    try {
        return Uri.parse (value, UriFlags.NONE);
    } catch (UriError e) {
        error ("failed to parse test URI: %s", e.message);
    }
}

private Range make_range (
    uint64 start_line,
    uint64 start_character,
    uint64 end_line,
    uint64 end_character
) {
    return Range (
        Position (start_line, start_character),
        Position (end_line, end_character));
}

private void test_signature_help () {
    try {
        var named_parameter = new ParameterInformation ("value") {
            documentation = new MarkupContent (
                MarkupKind.PLAINTEXT,
                "The value to print")
        };
        var offset_parameter = new ParameterInformation.with_offsets (13, 19) {
            documentation = new MarkupContent (
                MarkupKind.MARKDOWN,
                "`format` string")
        };
        var signature = new SignatureInformation (
            "print_value(value, format)") {
            documentation = new MarkupContent (
                MarkupKind.MARKDOWN,
                "Prints a **value**."),
            parameters = { named_parameter, offset_parameter },
            active_parameter = 1
        };
        SignatureInformation[] signatures = { signature };
        var help = new SignatureHelp (signatures, 0, 1);

        var decoded = new SignatureHelp.from_variant (
            help.to_variant ());
        assert (decoded.signatures.length == 1);
        assert (decoded.active_signature == 0);
        assert (decoded.active_parameter == 1);
        var decoded_signature = decoded.signatures[0];
        assert (decoded_signature.documentation != null);
        assert (
            decoded_signature.documentation.kind ==
            MarkupKind.MARKDOWN);
        assert (decoded_signature.parameters != null);
        assert (decoded_signature.parameters.length == 2);
        assert (decoded_signature.parameters[0].label == "value");
        assert (
            decoded_signature.parameters[0].documentation.value ==
            "The value to print");
        assert (decoded_signature.parameters[1].has_label_offsets);
        assert (decoded_signature.parameters[1].label_start == 13);
        assert (decoded_signature.parameters[1].label_end == 19);
        assert (decoded_signature.active_parameter == 1);
    } catch (Error e) {
        error ("signature help round trip failed: %s", e.message);
    }
}

private void test_inlay_hint () {
    try {
        var location = Location (
            parse_uri ("file:///workspace/main.vala"),
            make_range (2, 4, 2, 9));
        var part = new InlayHintLabelPart (": string") {
            tooltip = new MarkupContent (
                MarkupKind.MARKDOWN,
                "Inferred **type**"),
            location = location,
            command = new Command ("Open type", "vala.openType")
        };
        InlayHintLabelPart[] parts = { part };
        var hint = new InlayHint.with_label_parts (
            Position (2, 9),
            parts,
            InlayHintKind.TYPE) {
            text_edits = {
                TextEdit (
                    make_range (2, 9, 2, 9),
                    ": string")
            },
            tooltip = new MarkupContent (
                MarkupKind.PLAINTEXT,
                "Inferred type"),
            padding = InlayHintPadding.LEFT |
                InlayHintPadding.RIGHT,
            data = new Variant.string ("hint-token")
        };

        var decoded = new InlayHint.from_variant (
            hint.to_variant ());
        assert (decoded.position.line == 2);
        assert (decoded.kind == InlayHintKind.TYPE);
        assert (decoded.label == null);
        var decoded_parts = decoded.label_parts;
        assert (decoded_parts != null);
        assert (decoded_parts.length == 1);
        assert (decoded_parts[0].value == ": string");
        assert (decoded_parts[0].tooltip != null);
        assert (
            decoded_parts[0].tooltip.kind ==
            MarkupKind.MARKDOWN);
        assert (decoded_parts[0].location != null);
        assert (
            decoded_parts[0].location.uri.to_string () ==
            "file:///workspace/main.vala");
        assert (decoded_parts[0].command != null);
        assert (decoded_parts[0].command.command == "vala.openType");
        assert (decoded.text_edits != null);
        assert (decoded.text_edits.length == 1);
        assert (decoded.text_edits[0].new_text == ": string");
        assert (InlayHintPadding.LEFT in decoded.padding);
        assert (InlayHintPadding.RIGHT in decoded.padding);
        assert (decoded.data != null);
        assert ((string) decoded.data == "hint-token");

        var text_hint = new InlayHint (
            Position (4, 2),
            "parameter:",
            InlayHintKind.PARAMETER);
        var decoded_text = new InlayHint.from_variant (
            text_hint.to_variant ());
        assert (decoded_text.label == "parameter:");
        assert (decoded_text.label_parts == null);
        assert (decoded_text.kind == InlayHintKind.PARAMETER);

        var params = new InlayHintParams (
            TextDocumentIdentifier.unversioned (
                parse_uri ("file:///workspace/main.vala")),
            make_range (0, 0, 10, 0));
        var decoded_params = new InlayHintParams.from_variant (
            params.to_variant ());
        assert (decoded_params.range.end.line == 10);

        var options = InlayHintOptions (true);
        var decoded_options = InlayHintOptions.from_variant (
            options.to_variant ());
        assert (decoded_options.resolve_provider);
    } catch (Error e) {
        error ("inlay hint round trip failed: %s", e.message);
    }
}

private Diagnostic make_diagnostic () {
    return new Diagnostic (
        "replace deprecated call",
        make_range (3, 2, 3, 8)) {
        severity = DiagnosticSeverity.WARNING,
        code = "deprecated-call"
    };
}

private void test_code_action_context () {
    try {
        var context = new CodeActionContext () {
            diagnostics = { make_diagnostic () },
            only = {
                CodeActionKind.QUICK_FIX,
                CodeActionKind.REFACTOR_REWRITE
            },
            trigger = CodeActionTriggerKind.AUTOMATIC
        };
        var decoded = new CodeActionContext.from_variant (
            context.to_variant ());
        assert (decoded.diagnostics.length == 1);
        assert (
            decoded.diagnostics[0].message ==
            "replace deprecated call");
        assert (decoded.only != null);
        assert (decoded.only.length == 2);
        assert (decoded.only[0] == CodeActionKind.QUICK_FIX);
        assert (
            decoded.only[1] ==
            CodeActionKind.REFACTOR_REWRITE);
        assert (
            decoded.trigger ==
            CodeActionTriggerKind.AUTOMATIC);
    } catch (Error e) {
        error ("code action context round trip failed: %s", e.message);
    }
}

private void test_code_action_union () {
    try {
        var edit = new WorkspaceEdit ();
        edit.add_document_change (
            new CreateFile.with_options (
                parse_uri ("file:///workspace/generated.vala"),
                CreateFile.Options.OVERWRITE,
                "confirm"));
        edit.set_change_annotation (
            "confirm",
            new ChangeAnnotation ("Create generated file", true));

        var original = new CodeAction ("Replace deprecated call") {
            kind = CodeActionKind.QUICK_FIX,
            preferred = true,
            disabled_reason = "project is read-only",
            diagnostics = { make_diagnostic () },
            edit = edit,
            command = new Command (
                "Refresh",
                "vala.refresh"),
            data = new Variant.string ("action-token")
        };
        var encoded = original.to_variant ();
        assert (
            encoded.lookup_value (
                "isPreferred",
                VariantType.BOOLEAN) != null);
        assert (
            encoded.lookup_value (
                "preferred",
                VariantType.BOOLEAN) == null);
        assert (
            encoded.lookup_value (
                "disabled",
                VariantType.VARDICT) != null);

        var decoded_action = Lsp.Action.from_variant (
            encoded);
        assert (decoded_action is CodeAction);
        var decoded = (CodeAction) decoded_action;
        assert (decoded.title == "Replace deprecated call");
        assert (decoded.kind == CodeActionKind.QUICK_FIX);
        assert (decoded.preferred);
        assert (decoded.disabled_reason == "project is read-only");
        assert (decoded.diagnostics != null);
        assert (decoded.diagnostics.length == 1);
        assert (decoded.edit != null);
        assert (decoded.edit.document_changes.length == 1);
        assert (decoded.edit.document_changes[0] is CreateFile);
        assert (decoded.edit.change_annotations != null);
        assert (
            decoded.edit.change_annotations["confirm"].needs_confirmation);
        assert (decoded.command != null);
        assert (decoded.command.command == "vala.refresh");
        assert (decoded.data != null);
        assert ((string) decoded.data == "action-token");

        // A CodeAction may omit kind; an object-valued command still
        // distinguishes it from the Command branch of the protocol union.
        var minimal = new CodeAction ("Refresh") {
            command = new Command ("Refresh", "vala.refresh")
        };
        assert (
            Lsp.Action.from_variant (minimal.to_variant ())
            is CodeAction);
    } catch (Error e) {
        error ("code action union round trip failed: %s", e.message);
    }
}

private void test_document_symbol_result () {
    try {
        var range = make_range (0, 0, 4, 1);
        var selection = make_range (0, 6, 0, 13);
        DocumentSymbol[] hierarchical = {
            new DocumentSymbol (
                "Example",
                SymbolKind.CLASS,
                range,
                selection)
        };
        var decoded_hierarchical = new DocumentSymbolResult.from_variant (
            new DocumentSymbolResult.for_document_symbols (
                hierarchical).to_variant ());
        assert (decoded_hierarchical.document_symbols != null);
        assert (decoded_hierarchical.document_symbols.length == 1);
        assert (decoded_hierarchical.document_symbols[0].name == "Example");
        assert (decoded_hierarchical.symbol_information == null);

        SymbolInformation[] flat = {
            new SymbolInformation (
                "Example",
                SymbolKind.CLASS,
                Location (
                    parse_uri ("file:///workspace/main.vala"),
                    range))
        };
        var decoded_flat = new DocumentSymbolResult.from_variant (
            new DocumentSymbolResult.for_symbol_information (
                flat).to_variant ());
        assert (decoded_flat.document_symbols == null);
        assert (decoded_flat.symbol_information != null);
        assert (decoded_flat.symbol_information.length == 1);
        assert (decoded_flat.symbol_information[0].name == "Example");

        var decoded_empty = new DocumentSymbolResult.from_variant (
            new Variant.array (VariantType.VARDICT, {}));
        assert (decoded_empty.document_symbols != null);
        assert (decoded_empty.document_symbols.length == 0);
        assert (decoded_empty.symbol_information == null);

        try {
            new DocumentSymbolResult.from_variant (
                new Variant.array (
                    VariantType.VARDICT,
            {
                hierarchical[0].to_variant (),
                flat[0].to_variant ()
            }));
            assert_not_reached ();
        } catch (DeserializeError e) {
            assert (e.code == DeserializeError.UNEXPECTED_ELEMENT);
        }
    } catch (Error e) {
        error ("document symbol result round trip failed: %s", e.message);
    }
}

private void test_prepare_rename_result () {
    try {
        var range = make_range (3, 4, 3, 11);
        var plain = PrepareRenameResult.for_range (range);
        var decoded_plain = PrepareRenameResult.from_variant (
            plain.to_variant ());
        assert (decoded_plain.has_range);
        assert (decoded_plain.range.start.character == 4);
        assert (decoded_plain.placeholder == null);

        var placeholder = PrepareRenameResult.for_range (
            range,
            "old_name");
        var decoded_placeholder = PrepareRenameResult.from_variant (
            placeholder.to_variant ());
        assert (decoded_placeholder.has_range);
        assert (decoded_placeholder.placeholder == "old_name");

        var use_default = PrepareRenameResult.for_default_behavior ();
        var decoded_default = PrepareRenameResult.from_variant (
            use_default.to_variant ());
        assert (!decoded_default.has_range);
        assert (decoded_default.default_behavior);

        var invalid = new VariantDict ();
        invalid.insert_value ("defaultBehavior", true);
        invalid.insert_value ("range", range.to_variant ());
        try {
            PrepareRenameResult.from_variant (invalid.end ());
            assert_not_reached ();
        } catch (DeserializeError e) {
            assert (e.code == DeserializeError.UNEXPECTED_ELEMENT);
        }
    } catch (Error e) {
        error ("prepare rename result round trip failed: %s", e.message);
    }
}

private void test_type_hierarchy_and_capabilities () {
    try {
        var range = make_range (0, 0, 5, 1);
        var selection = make_range (0, 6, 0, 13);
        var item = new TypeHierarchyItem (
            "Example",
            SymbolKind.CLASS,
            parse_uri ("file:///workspace/main.vala"),
            range,
            selection,
            "class Example",
            SymbolTag.DEPRECATED) {
            data = new Variant.string ("hierarchy-token")
        };
        var decoded_item = new TypeHierarchyItem.from_variant (
            item.to_variant ());
        assert (decoded_item.name == "Example");
        assert (decoded_item.kind == SymbolKind.CLASS);
        assert (SymbolTag.DEPRECATED in decoded_item.tags);
        assert (decoded_item.selection_range.end.character == 13);
        assert (decoded_item.data != null);
        assert ((string) decoded_item.data == "hierarchy-token");

        var document_symbol = DocumentSymbolClientCaps (
            DocumentSymbolClientFlags.DYNAMIC_REGISTRATION |
            DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS |
            DocumentSymbolClientFlags.LABEL,
            SymbolKindFlags.CLASS | SymbolKindFlags.METHOD |
            SymbolKindFlags.TYPE_PARAMETER,
            SymbolTag.DEPRECATED);
        var text_document = new TextDocumentClientCaps ();
        text_document.synchronization = TextDocumentSyncClientCaps.WILL_SAVE |
            TextDocumentSyncClientCaps.DID_SAVE;
        text_document.document_symbol = document_symbol;
        text_document.rename = RenameClientCaps.SUPPORTED |
            RenameClientCaps.PREPARE_SUPPORT |
            RenameClientCaps.HONORS_CHANGE_ANNOTATIONS;
        text_document.rename_prepare_support_default_behavior =
            PrepareSupportDefaultBehavior.IDENTIFIER;
        text_document.type_hierarchy = TypeHierarchyClientCaps.SUPPORTED |
            TypeHierarchyClientCaps.DYNAMIC_REGISTRATION;
        var client = new ClientCaps ();
        client.text_document = text_document;
        var decoded_client = new ClientCaps.from_variant (client.to_variant ());
        assert (decoded_client.text_document != null);
        var decoded_text_document = (!) decoded_client.text_document;
        assert (TextDocumentSyncClientCaps.WILL_SAVE in
            decoded_text_document.synchronization);
        assert (TextDocumentSyncClientCaps.DID_SAVE in
            decoded_text_document.synchronization);
        var decoded_document_symbol = decoded_text_document.document_symbol;
        assert (DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS in
            decoded_document_symbol.flags);
        assert (SymbolKindFlags.CLASS in decoded_document_symbol.symbol_kinds);
        assert (SymbolKindFlags.METHOD in decoded_document_symbol.symbol_kinds);
        assert (SymbolKindFlags.TYPE_PARAMETER in
            decoded_document_symbol.symbol_kinds);
        assert (RenameClientCaps.PREPARE_SUPPORT in
            decoded_text_document.rename);
        assert (decoded_text_document.rename_prepare_support_default_behavior ==
            PrepareSupportDefaultBehavior.IDENTIFIER);
        assert (TypeHierarchyClientCaps.DYNAMIC_REGISTRATION in
            decoded_text_document.type_hierarchy);

        var decoded_server = new ServerCaps.from_variant (
            new ServerCaps () {
            type_hierarchy = TypeHierarchyOptions ()
        }.to_variant ());
        assert (decoded_server.type_hierarchy.supported);
    } catch (Error e) {
        error ("type hierarchy round trip failed: %s", e.message);
    }
}

private void test_protocol_error_values () {
    assert ((int) ProtocolError.PARSE_ERROR == -32700);
    assert ((int) ProtocolError.INVALID_REQUEST == -32600);
    assert ((int) ProtocolError.METHOD_NOT_FOUND == -32601);
    assert ((int) ProtocolError.INVALID_PARAMS == -32602);
    assert ((int) ProtocolError.INTERNAL_ERROR == -32603);
    assert ((int) ProtocolError.SERVER_NOT_INITIALIZED == -32002);
    assert ((int) ProtocolError.UNKNOWN_ERROR_CODE == -32001);
    assert ((int) ProtocolError.REQUEST_FAILED == -32803);
    assert ((int) ProtocolError.SERVER_CANCELLED == -32802);
    assert ((int) ProtocolError.CONTENT_MODIFIED == -32801);
    assert ((int) ProtocolError.REQUEST_CANCELLED == -32800);
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/advanced/signature-help",
        test_signature_help);
    Test.add_func (
        "/serialization/advanced/inlay-hint",
        test_inlay_hint);
    Test.add_func (
        "/serialization/advanced/code-action-context",
        test_code_action_context);
    Test.add_func (
        "/serialization/advanced/code-action-union",
        test_code_action_union);
    Test.add_func (
        "/serialization/advanced/document-symbol-result",
        test_document_symbol_result);
    Test.add_func (
        "/serialization/advanced/prepare-rename-result",
        test_prepare_rename_result);
    Test.add_func (
        "/serialization/advanced/type-hierarchy-and-capabilities",
        test_type_hierarchy_and_capabilities);
    Test.add_func (
        "/protocol/error-values",
        test_protocol_error_values);
    return Test.run ();
}
