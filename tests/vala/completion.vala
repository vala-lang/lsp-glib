using Lsp;

/*
 * Completion items combine most variant shapes used by LSP data types:
 * optional objects, enums, arrays, text edits, commands, markup, and opaque
 * data. Markup tests also verify the protocol's string-valued kind field.
 */

private void test_markup_content_deserialization () {
    try {
        var plaintext = new MarkupContent.from_variant (
            new Variant.string ("plain text"));
        assert (plaintext.kind == MarkupKind.PLAINTEXT);
        assert (plaintext.value == "plain text");

        var encoded = new VariantDict ();
        encoded.insert_value ("kind", new Variant.string ("markdown"));
        encoded.insert_value ("value", new Variant.string ("**bold**"));
        var markdown = new MarkupContent.from_variant (encoded.end ());
        assert (markdown.kind == MarkupKind.MARKDOWN);
        assert (markdown.value == "**bold**");

        var round_tripped = new MarkupContent.from_variant (
            new MarkupContent (
                MarkupKind.MARKDOWN,
                "serialized").to_variant ());
        assert (round_tripped.kind == MarkupKind.MARKDOWN);
        assert (round_tripped.value == "serialized");
    } catch (DeserializeError e) {
        error ("markup content deserialization failed: %s", e.message);
    }
}

private void test_completion_context_round_trip () {
    try {
        var original = new CompletionContext (
            CompletionTriggerKind.TRIGGER_CHARACTER,
            ".");
        var decoded = new CompletionContext.from_variant (
            original.to_variant ());

        assert (
            decoded.trigger_kind ==
            CompletionTriggerKind.TRIGGER_CHARACTER);
        assert (decoded.trigger_character == ".");
    } catch (DeserializeError e) {
        error ("completion context round trip failed: %s", e.message);
    }
}

private void test_completion_item_round_trip () {
    try {
        var primary_edit = TextEdit (
            Range (Position (3, 4), Position (3, 7)),
            "print(${1:value})");
        var command = new Command (
            "Show documentation",
            "vala.showDocumentation");
        command.add_argument (new Variant.string ("main.vala"));
        command.add_argument (new Variant.int64 (3));

        var original = new CompletionItem (
            "print",
            CompletionItemKind.FUNCTION) {
            label_details = new CompletionItemLabelDetails (
                "(value)",
                "GLib"),
            tags = CompletionItemTag.DEPRECATED,
            deprecated = true,
            detail = "void print (string value)",
            documentation = new MarkupContent (
                MarkupKind.MARKDOWN,
                "**Print** a value."),
            preselect = true,
            sort_text = "001",
            filter_text = "print",
            insert_text = "print",
            insert_text_format = InsertTextFormat.SNIPPET,
            insert_text_mode = InsertTextMode.ADJUST_INDENTATION,
            text_edit = primary_edit,
            command = command,
            data = new Variant.string ("completion-token")
        };
        original.add_additional_text_edit (TextEdit (
            Range (Position (0, 0), Position (0, 0)),
            "using GLib;\n"));
        original.add_commit_char (";");
        original.add_commit_char ("(");

        var encoded = original.to_variant ();
        var documentation = encoded.lookup_value (
            "documentation",
            VariantType.VARDICT);
        assert (documentation != null);
        var markup_kind = documentation.lookup_value (
            "kind",
            VariantType.STRING);
        assert (markup_kind != null);
        assert ((string) markup_kind == "markdown");

        var decoded = new CompletionItem.from_variant (
            encoded);
        assert (decoded.label == "print");
        assert (decoded.kind == CompletionItemKind.FUNCTION);
        assert (decoded.label_details != null);
        assert (decoded.label_details.detail == "(value)");
        assert (decoded.label_details.description == "GLib");
        assert (CompletionItemTag.DEPRECATED in decoded.tags);
        assert (decoded.deprecated);
        assert (decoded.detail == "void print (string value)");
        assert (decoded.documentation != null);
        assert (decoded.documentation.kind == MarkupKind.MARKDOWN);
        assert (decoded.documentation.value == "**Print** a value.");
        assert (decoded.preselect);
        assert (decoded.sort_text == "001");
        assert (decoded.filter_text == "print");
        assert (decoded.insert_text == "print");
        assert (decoded.insert_text_format == InsertTextFormat.SNIPPET);
        assert (
            decoded.insert_text_mode ==
            InsertTextMode.ADJUST_INDENTATION);

        assert (decoded.text_edit != null);
        assert (decoded.text_edit.new_text == "print(${1:value})");
        assert (decoded.additional_text_edits != null);
        assert (decoded.additional_text_edits.length == 1);
        assert (
            decoded.additional_text_edits[0].new_text ==
            "using GLib;\n");
        assert (decoded.commit_chars != null);
        assert (decoded.commit_chars.length == 2);
        assert (decoded.commit_chars[0] == ";");
        assert (decoded.commit_chars[1] == "(");

        assert (decoded.command != null);
        assert (decoded.command.title == "Show documentation");
        assert (decoded.command.command == "vala.showDocumentation");
        assert (decoded.command.arguments != null);
        assert (decoded.command.arguments.length == 2);
        assert ((string) decoded.command.arguments[0] == "main.vala");
        assert ((int64) decoded.command.arguments[1] == 3);

        assert (decoded.data != null);
        assert (decoded.data.is_of_type (VariantType.STRING));
        assert ((string) decoded.data == "completion-token");
    } catch (DeserializeError e) {
        error ("completion item round trip failed: %s", e.message);
    }
}

private void test_completion_list_round_trip () {
    try {
        var item = new CompletionItem (
            "result",
            CompletionItemKind.VARIABLE);
        var original = new CompletionList (true, {});
        original.add_item (item);
        var decoded = new CompletionList.from_variant (
            original.to_variant ());

        assert (decoded.is_incomplete);
        assert (decoded.items.length == 1);
        assert (decoded.items[0].label == "result");
        assert (decoded.items[0].kind == CompletionItemKind.VARIABLE);
    } catch (DeserializeError e) {
        error ("completion list round trip failed: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/deserialization/markup-content/string-and-object",
        test_markup_content_deserialization);
    Test.add_func (
        "/serialization/completion/context",
        test_completion_context_round_trip);
    Test.add_func (
        "/serialization/completion/item",
        test_completion_item_round_trip);
    Test.add_func (
        "/serialization/completion/list",
        test_completion_list_round_trip);
    return Test.run ();
}
