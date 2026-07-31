using Lsp;

/*
 * Text document tests cover versioned and unversioned identifiers, the
 * protocol string representation of language identifiers, and both forms of
 * content change event.
 */

private Uri parse_uri (string value) {
    try {
        return Uri.parse (value, UriFlags.NONE);
    } catch (UriError e) {
        error ("failed to parse test URI: %s", e.message);
    }
}

private void test_identifier_round_trip () {
    try {
        var original = TextDocumentIdentifier (
            parse_uri ("file:///workspace/main.vala"),
            42);
        var encoded = original.to_variant ();

        var uri = encoded.lookup_value ("uri", VariantType.STRING);
        var version = encoded.lookup_value ("version", VariantType.INT64);
        assert (uri != null);
        assert ((string) uri == "file:///workspace/main.vala");
        assert (version != null);
        assert ((int64) version == 42);

        var decoded = TextDocumentIdentifier.from_variant (
            encoded);
        assert (decoded.uri.to_string () == "file:///workspace/main.vala");
        assert (decoded.version == 42);
    } catch (Error e) {
        error ("versioned identifier round trip failed: %s", e.message);
    }
}

private void test_unversioned_identifier_round_trip () {
    try {
        var original = TextDocumentIdentifier.unversioned (
            parse_uri ("untitled:buffer"));
        var encoded = original.to_variant ();

        assert (encoded.lookup_value ("version", null) == null);

        var decoded = TextDocumentIdentifier.from_variant (
            encoded);
        assert (decoded.uri.to_string () == "untitled:buffer");
        assert (decoded.version == null);
    } catch (Error e) {
        error ("unversioned identifier round trip failed: %s", e.message);
    }
}

private void test_document_item_round_trip () {
    try {
        var original = new TextDocumentItem (
            parse_uri ("file:///workspace/main.vala"),
            LanguageId.VALA,
            7,
            "void main () {}\n");
        var encoded = original.to_variant ();

        var language_id = encoded.lookup_value (
            "languageId",
            VariantType.STRING);
        assert (language_id != null);
        assert ((string) language_id == "vala");

        var decoded = new TextDocumentItem.from_variant (
            encoded);
        assert (decoded.uri.to_string () == "file:///workspace/main.vala");
        assert (decoded.language_id == LanguageId.VALA);
        assert (decoded.version == 7);
        assert (decoded.text == "void main () {}\n");
    } catch (Error e) {
        error ("text document item round trip failed: %s", e.message);
    }
}

private void test_genie_language_id () {
    assert (LanguageId.GENIE.to_string () == "genie");
    assert (LanguageId.parse_string ("genie") == LanguageId.GENIE);
}

private void test_content_change_round_trip () {
    try {
        var changed_range = Range (
            Position (2, 3),
            Position (2, 8));
        var ranged = TextDocumentContentChangeEvent (
            changed_range,
            "replacement");
        var decoded_ranged =
            TextDocumentContentChangeEvent.from_variant (
                ranged.to_variant ());

        assert (decoded_ranged.range != null);
        assert (decoded_ranged.range.start.line == 2);
        assert (decoded_ranged.range.start.character == 3);
        assert (decoded_ranged.range.end.character == 8);
        assert (decoded_ranged.text == "replacement");

        var full = TextDocumentContentChangeEvent (null, "new contents");
        var decoded_full =
            TextDocumentContentChangeEvent.from_variant (
                full.to_variant ());
        assert (decoded_full.range == null);
        assert (decoded_full.text == "new contents");
    } catch (DeserializeError e) {
        error ("content change round trip failed: %s", e.message);
    }
}

private void test_position_params_round_trip () {
    try {
        var original = new TextDocumentPositionParams (
            TextDocumentIdentifier.unversioned (
                parse_uri ("file:///workspace/main.vala")),
            Position (8, 13));
        var decoded = new TextDocumentPositionParams.from_variant (
            original.to_variant ());

        assert (
            decoded.text_document.uri.to_string () ==
            "file:///workspace/main.vala");
        assert (decoded.text_document.version == null);
        assert (decoded.position.line == 8);
        assert (decoded.position.character == 13);
    } catch (Error e) {
        error ("text document position params round trip failed: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/text-document/identifier",
        test_identifier_round_trip);
    Test.add_func (
        "/serialization/text-document/unversioned-identifier",
        test_unversioned_identifier_round_trip);
    Test.add_func (
        "/serialization/text-document/item",
        test_document_item_round_trip);
    Test.add_func (
        "/serialization/text-document/genie-language-id",
        test_genie_language_id);
    Test.add_func (
        "/serialization/text-document/content-change",
        test_content_change_round_trip);
    Test.add_func (
        "/serialization/text-document/position-params",
        test_position_params_round_trip);
    return Test.run ();
}
