using Lsp;

/*
 * Symbol tests cover recursive arrays, deprecated tags, opaque workspace
 * locations, and both directions of the call hierarchy.
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

private void test_document_symbol () {
    try {
        var child = new DocumentSymbol (
            "method",
            SymbolKind.METHOD,
            make_range (2, 4, 4, 5),
            make_range (2, 9, 2, 15),
            "void method ()",
            SymbolTag.DEPRECATED);
        var parent = new DocumentSymbol (
            "Example",
            SymbolKind.CLASS,
            make_range (0, 0, 6, 1),
            make_range (0, 6, 0, 13),
            "class Example");
        parent.add_child (child);

        var decoded = new DocumentSymbol.from_variant (
            parent.to_variant ());
        assert (decoded.name == "Example");
        assert (decoded.kind == SymbolKind.CLASS);
        assert (decoded.detail == "class Example");
        assert (decoded.children.length == 1);
        assert (decoded.children[0].name == "method");
        assert (decoded.children[0].kind == SymbolKind.METHOD);
        assert (SymbolTag.DEPRECATED in decoded.children[0].tags);
        assert (decoded.children[0].selection_range.end.character == 15);
    } catch (Error e) {
        error ("document symbol round trip failed: %s", e.message);
    }
}

private void test_flat_and_workspace_symbols () {
    try {
        var location = Location (
            parse_uri ("file:///workspace/main.vala"),
            make_range (7, 2, 7, 8));
        var flat = new SymbolInformation (
            "result",
            SymbolKind.VARIABLE,
            location,
            "main",
            SymbolTag.DEPRECATED);
        var decoded_flat = new SymbolInformation.from_variant (
            flat.to_variant ());
        assert (decoded_flat.name == "result");
        assert (decoded_flat.kind == SymbolKind.VARIABLE);
        assert (decoded_flat.deprecated);
        assert (decoded_flat.container_name == "main");
        assert (
            decoded_flat.location.uri.to_string () ==
            "file:///workspace/main.vala");

        var workspace = new WorkspaceSymbol (
            "Example",
            SymbolKind.CLASS,
            location.uri,
            location.range,
            "demo",
            SymbolTag.DEPRECATED);
        var decoded_workspace = new WorkspaceSymbol.from_variant (
            workspace.to_variant ());
        assert (decoded_workspace.name == "Example");
        assert (decoded_workspace.kind == SymbolKind.CLASS);
        assert (SymbolTag.DEPRECATED in decoded_workspace.tags);
        assert (decoded_workspace.container_name == "demo");
        assert (
            decoded_workspace.uri.to_string () ==
            "file:///workspace/main.vala");
        assert (decoded_workspace.range != null);
        assert (decoded_workspace.range.start.line == 7);
    } catch (Error e) {
        error ("flat symbol round trip failed: %s", e.message);
    }
}

private CallHierarchyItem make_call_item (
    string name,
    uint64 line
) {
    return new CallHierarchyItem (
        name,
        SymbolKind.FUNCTION,
        parse_uri ("file:///workspace/main.vala"),
        make_range (line, 0, line + 2, 1),
        make_range (line, 5, line, 5 + name.length),
        "void %s ()".printf (name),
        SymbolTag.DEPRECATED) {
        data = new Variant.string ("%s-token".printf (name))
    };
}

private void test_call_hierarchy () {
    try {
        var caller = make_call_item ("caller", 1);
        var callee = make_call_item ("callee", 8);
        var incoming = new CallHierarchyIncomingCall (
            caller,
            {});
        incoming.add_from_range (make_range (3, 4, 3, 10));
        incoming.add_from_range (make_range (5, 4, 5, 10));
        var decoded_incoming =
            new CallHierarchyIncomingCall.from_variant (
                incoming.to_variant ());
        assert (decoded_incoming.from.name == "caller");
        assert (SymbolTag.DEPRECATED in decoded_incoming.from.tags);
        assert (decoded_incoming.from.data != null);
        assert ((string) decoded_incoming.from.data == "caller-token");
        assert (decoded_incoming.from_ranges.length == 2);
        assert (decoded_incoming.from_ranges[1].start.line == 5);

        var outgoing = new CallHierarchyOutgoingCall (
            callee,
            {});
        outgoing.add_from_range (make_range (3, 4, 3, 10));
        outgoing.add_from_range (make_range (5, 4, 5, 10));
        var decoded_outgoing =
            new CallHierarchyOutgoingCall.from_variant (
                outgoing.to_variant ());
        assert (decoded_outgoing.to.name == "callee");
        assert (decoded_outgoing.to.selection_range.start.line == 8);
        assert (decoded_outgoing.from_ranges.length == 2);

        var options = CallHierarchyOptions ();
        var decoded_options = CallHierarchyOptions.from_variant (
            options.to_variant ());
        assert (
            decoded_options.to_variant ().is_of_type (
                VariantType.VARDICT));
    } catch (Error e) {
        error ("call hierarchy round trip failed: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/symbols/document",
        test_document_symbol);
    Test.add_func (
        "/serialization/symbols/flat-and-workspace",
        test_flat_and_workspace_symbols);
    Test.add_func (
        "/serialization/symbols/call-hierarchy",
        test_call_hierarchy);
    return Test.run ();
}
