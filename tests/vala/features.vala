using Lsp;

/*
 * These tests cover the smaller feature payloads that are easy to overlook:
 * commands, hovers, highlights, formatting, rename, and code lenses. Every
 * object is serialized to and deserialized from the native Variant API.
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

private TextDocumentIdentifier make_document () {
    return TextDocumentIdentifier (
        parse_uri ("file:///workspace/main.vala"),
        4);
}

private void test_foundation_types () {
    try {
        var location = Location (
            parse_uri ("file:///workspace/main.vala"),
            make_range (2, 3, 4, 5));
        var decoded_location = Location.from_variant (
            location.to_variant ());
        assert (
            decoded_location.uri.to_string () ==
            "file:///workspace/main.vala");
        assert (decoded_location.range.start.line == 2);
        assert (decoded_location.range.end.character == 5);

        var folder = new WorkspaceFolder (
            parse_uri ("file:///workspace"),
            "workspace");
        var decoded_folder = new WorkspaceFolder.from_variant (
            folder.to_variant ());
        assert (decoded_folder.uri.to_string () == "file:///workspace");
        assert (decoded_folder.name == "workspace");

        var action = MessageActionItem ("Retry");
        var decoded_action = MessageActionItem.from_variant (
            action.to_variant ());
        assert (decoded_action.title == "Retry");
    } catch (Error e) {
        error ("foundation type round trip failed: %s", e.message);
    }
}

private void test_command_highlight_and_hover () {
    try {
        Variant[] arguments = {
            new Variant.string ("main.vala"),
            new Variant.int64 (9),
            new Variant.boolean (true)
        };
        var command = new Command (
            "Run test",
            "vala.runTest",
            arguments);
        var decoded_action = Lsp.Action.from_variant (
            command.to_variant ());
        assert (decoded_action is Command);
        var decoded_command = (Command) decoded_action;
        assert (decoded_command.title == "Run test");
        assert (decoded_command.command == "vala.runTest");
        assert (decoded_command.arguments != null);
        assert (decoded_command.arguments.length == 3);
        assert ((string) decoded_command.arguments[0] == "main.vala");
        assert ((int64) decoded_command.arguments[1] == 9);
        assert ((bool) decoded_command.arguments[2]);

        var highlight = DocumentHighlight (
            make_range (1, 1, 1, 6),
            DocumentHighlightKind.WRITE);
        var decoded_highlight = DocumentHighlight.from_variant (
            highlight.to_variant ());
        assert (decoded_highlight.kind == DocumentHighlightKind.WRITE);
        assert (decoded_highlight.range.end.character == 6);

        var hover = new Hover (
            new MarkupContent (
                MarkupKind.MARKDOWN,
                "**symbol** documentation"),
            make_range (3, 2, 3, 8));
        var decoded_hover = new Hover.from_variant (
            hover.to_variant ());
        assert (decoded_hover.contents.kind == MarkupKind.MARKDOWN);
        assert (
            decoded_hover.contents.value ==
            "**symbol** documentation");
        assert (decoded_hover.range != null);
        assert (decoded_hover.range.start.line == 3);
    } catch (Error e) {
        error ("command, highlight, or hover round trip failed: %s", e.message);
    }
}

private void test_formatting_and_rename_params () {
    try {
        var options = FormattingOptions (4, true);
        options.flags =
            FormattingOptionFlags.TRIM_TRAILING_WHITESPACE |
            FormattingOptionFlags.INSERT_FINAL_NEWLINE |
            FormattingOptionFlags.TRIM_FINAL_NEWLINES;
        var formatting = new DocumentFormattingParams (
            make_document (),
            options);
        var decoded_formatting =
            new DocumentFormattingParams.from_variant (
                formatting.to_variant ());
        assert (decoded_formatting.text_document.version == 4);
        assert (decoded_formatting.options.tab_size == 4);
        assert (decoded_formatting.options.insert_spaces);
        assert (
            FormattingOptionFlags.TRIM_TRAILING_WHITESPACE in
            decoded_formatting.options.flags);
        assert (
            FormattingOptionFlags.INSERT_FINAL_NEWLINE in
            decoded_formatting.options.flags);
        assert (
            FormattingOptionFlags.TRIM_FINAL_NEWLINES in
            decoded_formatting.options.flags);

        var range_formatting = new DocumentRangeFormattingParams (
            make_document (),
            make_range (5, 0, 8, 0),
            options);
        var decoded_range_formatting =
            new DocumentRangeFormattingParams.from_variant (
                range_formatting.to_variant ());
        assert (decoded_range_formatting.range.start.line == 5);
        assert (decoded_range_formatting.range.end.line == 8);

        var rename = new RenameParams (
            make_document (),
            Position (6, 7),
            "renamed_value");
        var decoded_rename = new RenameParams.from_variant (
            rename.to_variant ());
        assert (decoded_rename.position.line == 6);
        assert (decoded_rename.position.character == 7);
        assert (decoded_rename.new_name == "renamed_value");

        var prepare = new PrepareRenameParams (
            make_document (),
            Position (9, 10));
        var decoded_prepare = new PrepareRenameParams.from_variant (
            prepare.to_variant ());
        assert (decoded_prepare.position.line == 9);
        assert (decoded_prepare.position.character == 10);

        var references = ReferenceContext (false);
        var decoded_references = ReferenceContext.from_variant (
            references.to_variant ());
        assert (!decoded_references.include_declaration);
    } catch (Error e) {
        error ("request parameter round trip failed: %s", e.message);
    }
}

private void test_code_lens () {
    try {
        var lens = new CodeLens (
            make_range (10, 0, 10, 12),
            new Command ("Run", "vala.run"),
            new Variant.string ("lens-token"));
        var decoded = new CodeLens.from_variant (
            lens.to_variant ());
        assert (decoded.range.start.line == 10);
        assert (decoded.command != null);
        assert (decoded.command.command == "vala.run");
        assert (decoded.data != null);
        assert ((string) decoded.data == "lens-token");

        var params = new CodeLensParams (make_document ());
        var decoded_params = new CodeLensParams.from_variant (
            params.to_variant ());
        assert (
            decoded_params.text_document.uri.to_string () ==
            "file:///workspace/main.vala");
        assert (decoded_params.text_document.version == 4);
    } catch (Error e) {
        error ("code lens round trip failed: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/features/foundation",
        test_foundation_types);
    Test.add_func (
        "/serialization/features/command-highlight-hover",
        test_command_highlight_and_hover);
    Test.add_func (
        "/serialization/features/formatting-rename",
        test_formatting_and_rename_params);
    Test.add_func (
        "/serialization/features/code-lens",
        test_code_lens);
    return Test.run ();
}
