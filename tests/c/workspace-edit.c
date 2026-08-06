#include "lsp-glib.h"

/*
 * Workspace edits exercise stack-allocated edits plus every typed resource
 * operation in the heterogeneous documentChanges protocol array.
 */

static GUri *
parse_uri (const gchar *value)
{
  GError *error = NULL;
  GUri *uri = g_uri_parse (value, G_URI_FLAGS_NONE, &error);

  g_assert_no_error (error);
  return uri;
}

static void
make_range (LspRange *range)
{
  LspPosition start = { 0 };
  LspPosition end = { 0 };

  lsp_position_init (&start, 1, 2);
  lsp_position_init (&end, 1, 5);
  lsp_range_init (range, &start, &end);
}

static void
test_text_edit_and_annotation (void)
{
  LspRange range = { 0 };
  LspTextEdit original_edit = { 0 };
  LspTextEdit decoded_edit = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspChangeAnnotation) annotation = NULL;
  g_autoptr (LspChangeAnnotation) decoded_annotation = NULL;

  make_range (&range);
  lsp_text_edit_init (
      &original_edit,
      &range,
      "value",
      "confirm");
  wire =
      lsp_text_edit_to_variant (&original_edit);
  lsp_text_edit_init_from_variant (&decoded_edit, wire, &error);

  g_assert_no_error (error);
  g_assert_cmpstr (
      lsp_text_edit_get_new_text (&decoded_edit),
      ==,
      "value");
  g_assert_cmpstr (
      lsp_text_edit_get_annotation_id (&decoded_edit),
      ==,
      "confirm");

  g_clear_pointer (&wire, g_variant_unref);
  annotation = lsp_change_annotation_new (
      "Confirm edit",
      TRUE,
      "Changes the selected value");
  wire =
      lsp_change_annotation_to_variant (annotation);
  decoded_annotation = lsp_change_annotation_new_from_variant (
      wire,
      &error);

  g_assert_no_error (error);
  g_assert_cmpstr (
      lsp_change_annotation_get_label (decoded_annotation),
      ==,
      "Confirm edit");
  g_assert_true (
      lsp_change_annotation_get_needs_confirmation (
          decoded_annotation));
}

static void
test_workspace_edit_round_trip (void)
{
  LspRange range = { 0 };
  LspTextEdit edits[1] = { 0 };
  LspTextDocumentIdentifier document = { 0 };
  gint change_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GUri) document_uri = parse_uri (
      "file:///workspace/main.vala");
  g_autoptr (GUri) create_uri = parse_uri (
      "file:///workspace/new.vala");
  g_autoptr (GUri) old_uri = parse_uri (
      "file:///workspace/old.vala");
  g_autoptr (GUri) renamed_uri = parse_uri (
      "file:///workspace/renamed.vala");
  g_autoptr (GUri) delete_uri = parse_uri (
      "file:///workspace/generated");
  g_autoptr (LspTextDocumentEdit) text_change = NULL;
  g_autoptr (LspCreateFile) create = NULL;
  g_autoptr (LspRenameFile) rename = NULL;
  g_autoptr (LspDeleteFile) delete = NULL;
  g_autoptr (LspChangeAnnotation) annotation = NULL;
  g_autoptr (LspWorkspaceEdit) original = NULL;
  g_autoptr (LspWorkspaceEdit) decoded = NULL;
  g_autoptr (GVariant) wire = NULL;
  LspResourceOperation **changes;
  GHashTable *annotations;

  make_range (&range);
  lsp_text_edit_init (&edits[0], &range, "value", "confirm");
  lsp_text_document_identifier_init (&document, document_uri, 9);
  text_change = lsp_text_document_edit_new (
      &document,
      NULL,
      0);
  lsp_text_document_edit_add_edit (text_change, &edits[0]);
  create = lsp_create_file_new_with_options (
      create_uri,
      LSP_CREATE_FILE_OPTIONS_OVERWRITE |
      LSP_CREATE_FILE_OPTIONS_IGNORE_IF_EXISTS,
      "confirm");
  rename = lsp_rename_file_new_with_options (
      old_uri,
      renamed_uri,
      LSP_RENAME_FILE_OPTIONS_OVERWRITE,
      NULL);
  delete = lsp_delete_file_new_with_options (
      delete_uri,
      LSP_DELETE_FILE_OPTIONS_RECURSIVE |
      LSP_DELETE_FILE_OPTIONS_IGNORE_IF_NOT_EXISTS,
      NULL);
  annotation = lsp_change_annotation_new (
      "Confirm edit",
      TRUE,
      NULL);

  original = lsp_workspace_edit_new ();
  lsp_workspace_edit_add_document_change (
      original,
      LSP_RESOURCE_OPERATION (text_change));
  lsp_workspace_edit_add_document_change (
      original,
      LSP_RESOURCE_OPERATION (create));
  lsp_workspace_edit_add_document_change (
      original,
      LSP_RESOURCE_OPERATION (rename));
  lsp_workspace_edit_add_document_change (
      original,
      LSP_RESOURCE_OPERATION (delete));
  lsp_workspace_edit_set_change_annotation (
      original,
      "confirm",
      annotation);

  wire =
      lsp_workspace_edit_to_variant (original);
  decoded = lsp_workspace_edit_new_from_variant (wire, &error);

  g_assert_no_error (error);
  changes = lsp_workspace_edit_get_document_changes (
      decoded,
      &change_count);
  g_assert_cmpint (change_count, ==, 4);
  g_assert_true (LSP_IS_TEXT_DOCUMENT_EDIT (changes[0]));
  g_assert_true (LSP_IS_CREATE_FILE (changes[1]));
  g_assert_true (LSP_IS_RENAME_FILE (changes[2]));
  g_assert_true (LSP_IS_DELETE_FILE (changes[3]));
  g_assert_true (
      LSP_CREATE_FILE_OPTIONS_OVERWRITE &
      lsp_create_file_get_options (LSP_CREATE_FILE (changes[1])));
  g_assert_true (
      LSP_DELETE_FILE_OPTIONS_IGNORE_IF_NOT_EXISTS &
      lsp_delete_file_get_options (LSP_DELETE_FILE (changes[3])));

  annotations = lsp_workspace_edit_get_change_annotations (decoded);
  g_assert_cmpuint (g_hash_table_size (annotations), ==, 1);
  g_assert_true (
      lsp_change_annotation_get_needs_confirmation (
          g_hash_table_lookup (annotations, "confirm")));
}

static void
test_apply_result_round_trip (void)
{
  guint64 failed_change = 2;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspApplyWorkspaceEditResult) original = NULL;
  g_autoptr (LspApplyWorkspaceEditResult) decoded = NULL;

  original = lsp_apply_workspace_edit_result_new (
      FALSE,
      "document changed");
  lsp_apply_workspace_edit_result_set_failed_change (
      original,
      &failed_change);
  wire =
      lsp_apply_workspace_edit_result_to_variant (original);
  decoded = lsp_apply_workspace_edit_result_new_from_variant (
      wire,
      &error);

  g_assert_no_error (error);
  g_assert_false (
      lsp_apply_workspace_edit_result_get_applied (decoded));
  g_assert_cmpstr (
      lsp_apply_workspace_edit_result_get_failure_reason (decoded),
      ==,
      "document changed");
  g_assert_cmpuint (
      *lsp_apply_workspace_edit_result_get_failed_change (decoded),
      ==,
      2);
}

int
main (int argc, char *argv[])
{
  g_test_init (&argc, &argv, NULL);
  g_test_add_func (
      "/c/serialization/workspace-edit/edit-and-annotation",
      test_text_edit_and_annotation);
  g_test_add_func (
      "/c/serialization/workspace-edit/mixed-operations",
      test_workspace_edit_round_trip);
  g_test_add_func (
      "/c/serialization/workspace-edit/apply-result",
      test_apply_result_round_trip);
  return g_test_run ();
}
