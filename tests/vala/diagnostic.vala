using Lsp;

/*
 * Diagnostic exercises nested dictionaries, arrays, optional fields, URIs,
 * and opaque data. The full round trip guards both serializers together;
 * focused deserialization cases cover the integer|string code union and
 * required properties.
 */

private void test_round_trip () {
    try {
        var range = Range (Position (1, 2), Position (3, 4));
        var related_range = Range (Position (5, 6), Position (7, 8));
        var related = new DiagnosticRelatedInformation (
            Location (
                Uri.parse ("file:///related.vala", UriFlags.NONE),
                related_range),
            "related message");

        var original = new Diagnostic ("diagnostic message", range) {
            severity = DiagnosticSeverity.WARNING,
            code = "V123",
            code_description = new CodeDescription ("https://example.com/V123"),
            source = "vala",
            tags = DiagnosticTagFlags.UNNECESSARY |
                DiagnosticTagFlags.DEPRECATED,
            data = new Variant.string ("opaque payload")
        };
        original.add_related_information (related);

        var decoded = new Diagnostic.from_variant (
            original.to_variant ());
        assert (decoded.range.start.line == 1);
        assert (decoded.range.start.character == 2);
        assert (decoded.range.end.line == 3);
        assert (decoded.range.end.character == 4);
        assert (decoded.severity == DiagnosticSeverity.WARNING);
        assert (decoded.code == "V123");
        assert (decoded.code_description != null);
        assert (decoded.code_description.href == "https://example.com/V123");
        assert (decoded.source == "vala");
        assert (decoded.message == "diagnostic message");

        assert (DiagnosticTagFlags.UNNECESSARY in decoded.tags);
        assert (DiagnosticTagFlags.DEPRECATED in decoded.tags);

        assert (decoded.related_information != null);
        assert (decoded.related_information.length == 1);
        var decoded_related = decoded.related_information[0];
        assert (decoded_related.message == "related message");
        assert (decoded_related.location.uri.to_string () == "file:///related.vala");
        assert (decoded_related.location.range.start.line == 5);
        assert (decoded_related.location.range.end.character == 8);

        assert (decoded.data != null);
        assert (decoded.data.is_of_type (VariantType.STRING));
        assert ((string) decoded.data == "opaque payload");
    } catch (Error e) {
        error ("diagnostic round trip failed: %s", e.message);
    }
}

private void test_numeric_code () {
    var dict = new VariantDict ();
    dict.insert_value (
        "range",
        Range (Position (0, 0), Position (0, 1)).to_variant ());
    dict.insert_value ("message", new Variant.string ("numeric code"));
    dict.insert_value ("code", new Variant.int64 (42));

    try {
        var decoded = new Diagnostic.from_variant (dict.end ());
        assert (decoded.code == "42");
    } catch (Error e) {
        error ("numeric diagnostic code was not deserialized: %s", e.message);
    }
}

private void test_missing_message () {
    var dict = new VariantDict ();
    dict.insert_value (
        "range",
        Range (Position (0, 0), Position (0, 1)).to_variant ());

    bool caught = false;
    try {
        new Diagnostic.from_variant (dict.end ());
    } catch (DeserializeError.MISSING_PROPERTY e) {
        caught = true;
    } catch (Error e) {
        assert_not_reached ();
    }
    assert (caught);
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/serialization/diagnostic/round-trip", test_round_trip);
    Test.add_func ("/deserialization/diagnostic/numeric-code", test_numeric_code);
    Test.add_func ("/deserialization/diagnostic/missing-message", test_missing_message);
    return Test.run ();
}
