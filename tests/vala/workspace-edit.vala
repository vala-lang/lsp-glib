using Lsp;

/*
 * Workspace edit tests exercise annotated text edits and every resource
 * operation in a heterogeneous documentChanges array.
 */

private Uri parse_uri (string value) {
    try {
        return Uri.parse (value, UriFlags.NONE);
    } catch (UriError e) {
        error ("failed to parse test URI: %s", e.message);
    }
}

private TextEdit make_text_edit () {
    return TextEdit (
        Range (Position (1, 2), Position (1, 5)),
        "value",
        "confirm");
}

private void test_text_edit_round_trip () {
    try {
        var decoded = TextEdit.from_variant (
            make_text_edit ().to_variant ());

        assert (decoded.range.start.line == 1);
        assert (decoded.range.start.character == 2);
        assert (decoded.range.end.character == 5);
        assert (decoded.new_text == "value");
        assert (decoded.annotation_id == "confirm");
    } catch (DeserializeError e) {
        error ("text edit round trip failed: %s", e.message);
    }
}

private void test_change_annotation_round_trip () {
    try {
        var original = new ChangeAnnotation (
            "Confirm edit",
            true,
            "Changes the selected value");
        var decoded = new ChangeAnnotation.from_variant (
            original.to_variant ());

        assert (decoded.label == "Confirm edit");
        assert (decoded.needs_confirmation);
        assert (decoded.description == "Changes the selected value");
    } catch (DeserializeError e) {
        error ("change annotation round trip failed: %s", e.message);
    }
}

private void test_text_document_edit_round_trip () {
    try {
        var original = new TextDocumentEdit (
            TextDocumentIdentifier (
                parse_uri ("file:///workspace/main.vala"),
                9),
            {});
        original.add_edit (make_text_edit ());
        var encoded = original.to_variant ();

        assert (encoded.lookup_value ("kind", null) == null);

        var decoded = new TextDocumentEdit.from_variant (
            encoded);
        assert (
            decoded.text_document.uri.to_string () ==
            "file:///workspace/main.vala");
        assert (decoded.text_document.version == 9);
        assert (decoded.edits.length == 1);
        assert (decoded.edits[0].new_text == "value");
        assert (decoded.edits[0].annotation_id == "confirm");
    } catch (Error e) {
        error ("text document edit round trip failed: %s", e.message);
    }
}

private void test_resource_operations_round_trip () {
    try {
        var create = new CreateFile () {
            uri = parse_uri ("file:///workspace/new.vala"),
            options = CreateFile.Options.OVERWRITE |
                CreateFile.Options.IGNORE_IF_EXISTS,
            annotation_id = "confirm"
        };
        var decoded_create = new CreateFile.from_variant (
            create.to_variant ());
        assert (decoded_create.uri.to_string () == "file:///workspace/new.vala");
        assert (CreateFile.Options.OVERWRITE in decoded_create.options);
        assert (
            CreateFile.Options.IGNORE_IF_EXISTS in
            decoded_create.options);
        assert (decoded_create.annotation_id == "confirm");

        var rename = new RenameFile () {
            old_uri = parse_uri ("file:///workspace/old.vala"),
            new_uri = parse_uri ("file:///workspace/new.vala"),
            options = RenameFile.Options.OVERWRITE,
            annotation_id = "confirm"
        };
        var decoded_rename = new RenameFile.from_variant (
            rename.to_variant ());
        assert (
            decoded_rename.old_uri.to_string () ==
            "file:///workspace/old.vala");
        assert (
            decoded_rename.new_uri.to_string () ==
            "file:///workspace/new.vala");
        assert (RenameFile.Options.OVERWRITE in decoded_rename.options);

        var delete = new DeleteFile () {
            uri = parse_uri ("file:///workspace/generated"),
            options = DeleteFile.Options.RECURSIVE |
                DeleteFile.Options.IGNORE_IF_NOT_EXISTS,
            annotation_id = "confirm"
        };
        var decoded_delete = new DeleteFile.from_variant (
            delete.to_variant ());
        assert (
            decoded_delete.uri.to_string () ==
            "file:///workspace/generated");
        assert (DeleteFile.Options.RECURSIVE in decoded_delete.options);
        assert (
            DeleteFile.Options.IGNORE_IF_NOT_EXISTS in
            decoded_delete.options);
    } catch (Error e) {
        error ("resource operation round trip failed: %s", e.message);
    }
}

private void test_workspace_edit_round_trip () {
    try {
        var text_document_edit = new TextDocumentEdit (
            TextDocumentIdentifier (
                parse_uri ("file:///workspace/main.vala"),
                9),
            {});
        text_document_edit.add_edit (make_text_edit ());
        var create = new CreateFile () {
            uri = parse_uri ("file:///workspace/new.vala"),
            options = CreateFile.Options.OVERWRITE,
            annotation_id = "confirm"
        };
        var rename = new RenameFile () {
            old_uri = parse_uri ("file:///workspace/old.vala"),
            new_uri = parse_uri ("file:///workspace/renamed.vala")
        };
        var delete = new DeleteFile () {
            uri = parse_uri ("file:///workspace/generated"),
            options = DeleteFile.Options.RECURSIVE
        };

        var original = new WorkspaceEdit ();
        original.add_document_change (text_document_edit);
        original.add_document_change (create);
        original.add_document_change (rename);
        original.add_document_change (delete);
        original.set_change_annotation (
            "confirm",
            new ChangeAnnotation ("Confirm edit", true));
        var decoded = new WorkspaceEdit.from_variant (
            original.to_variant ());
        assert (decoded.document_changes.length == 4);
        assert (decoded.document_changes[0] is TextDocumentEdit);
        assert (decoded.document_changes[1] is CreateFile);
        assert (decoded.document_changes[2] is RenameFile);
        assert (decoded.document_changes[3] is DeleteFile);

        var decoded_annotations = decoded.change_annotations;
        assert (decoded_annotations != null);
        assert (decoded_annotations.length == 1);
        assert (decoded_annotations["confirm"].label == "Confirm edit");
        assert (decoded_annotations["confirm"].needs_confirmation);

        var round_tripped = new WorkspaceEdit.from_variant (
            decoded.to_variant ());
        assert (round_tripped.document_changes.length == 4);
        assert (round_tripped.document_changes[0] is TextDocumentEdit);
        assert (round_tripped.change_annotations != null);
        assert (round_tripped.change_annotations.length == 1);
    } catch (Error e) {
        error ("workspace edit round trip failed: %s", e.message);
    }
}

private void test_apply_result_round_trip () {
    try {
        var original = new ApplyWorkspaceEditResult (
            false,
            "document changed") {
            failed_change = 2
        };
        var decoded = new ApplyWorkspaceEditResult.from_variant (
            original.to_variant ());

        assert (!decoded.applied);
        assert (decoded.failure_reason == "document changed");
        assert (decoded.failed_change == 2);
    } catch (DeserializeError e) {
        error ("apply workspace edit result round trip failed: %s", e.message);
    }
}

private int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/serialization/workspace-edit/text-edit",
        test_text_edit_round_trip);
    Test.add_func (
        "/serialization/workspace-edit/change-annotation",
        test_change_annotation_round_trip);
    Test.add_func (
        "/serialization/workspace-edit/text-document-edit",
        test_text_document_edit_round_trip);
    Test.add_func (
        "/serialization/workspace-edit/resource-operations",
        test_resource_operations_round_trip);
    Test.add_func (
        "/serialization/workspace-edit/mixed-operations",
        test_workspace_edit_round_trip);
    Test.add_func (
        "/serialization/workspace-edit/apply-result",
        test_apply_result_round_trip);
    return Test.run ();
}
