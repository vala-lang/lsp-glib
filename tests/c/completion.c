#include "lsp-glib.h"

/*
 * Completion payloads cover nested objects, enum arrays, text edits,
 * commands, markup, and opaque LSPAny data in the native Variant API.
 */

static void
make_range (LspRange *range,
            guint64 line,
            guint64 start_character,
            guint64 end_character)
{
  LspPosition start = { 0 };
  LspPosition end = { 0 };

  lsp_position_init (&start, line, start_character);
  lsp_position_init (&end, line, end_character);
  lsp_range_init (range, &start, &end);
}

static void
test_completion_context_round_trip (void)
{
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspCompletionContext) original = NULL;
  g_autoptr (LspCompletionContext) decoded = NULL;

  original = lsp_completion_context_new (
      LSP_COMPLETION_TRIGGER_KIND_TRIGGER_CHARACTER,
      ".");
  wire =
      lsp_completion_context_to_variant (original);
  decoded = lsp_completion_context_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_cmpint (
      lsp_completion_context_get_trigger_kind (decoded),
      ==,
      LSP_COMPLETION_TRIGGER_KIND_TRIGGER_CHARACTER);
  g_assert_cmpstr (
      lsp_completion_context_get_trigger_character (decoded),
      ==,
      ".");
}

static void
test_completion_item_round_trip (void)
{
  LspRange primary_range = { 0 };
  LspRange additional_range = { 0 };
  LspTextEdit *primary_edit = g_new0 (LspTextEdit, 1);
  g_auto (LspTextEdit) additional_edit = { 0 };
  gint additional_count;
  gint commit_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspCompletionItem) original = NULL;
  g_autoptr (LspCompletionItem) decoded = NULL;
  g_autoptr (LspCompletionItemLabelDetails) label_details = NULL;
  g_autoptr (LspMarkupContent) documentation = NULL;
  g_autoptr (LspCommand) command = NULL;
  g_autoptr (GVariant) filename_argument = NULL;
  g_autoptr (GVariant) line_argument = NULL;
  LspTextEdit *decoded_edits;
  gchar **decoded_commit_chars;

  make_range (&primary_range, 3, 4, 7);
  make_range (&additional_range, 0, 0, 0);
  lsp_text_edit_init (
      primary_edit,
      &primary_range,
      "print(${1:value})",
      NULL);
  lsp_text_edit_init (
      &additional_edit,
      &additional_range,
      "using GLib;\n",
      NULL);

  filename_argument = g_variant_ref_sink (
      g_variant_new_string ("main.vala"));
  line_argument = g_variant_ref_sink (g_variant_new_int64 (3));
  label_details = lsp_completion_item_label_details_new (
      "(value)",
      "GLib");
  documentation = lsp_markup_content_new (
      LSP_MARKUP_KIND_MARKDOWN,
      "**Print** a value.");
  command = lsp_command_new (
      "Show documentation",
      "vala.showDocumentation",
      NULL,
      0);
  lsp_command_add_argument (command, filename_argument);
  lsp_command_add_argument (command, line_argument);

  original = lsp_completion_item_new (
      "print",
      LSP_COMPLETION_ITEM_KIND_FUNCTION);
  lsp_completion_item_set_label_details (original, label_details);
  lsp_completion_item_set_tags (
      original,
      LSP_COMPLETION_ITEM_TAG_DEPRECATED);
  lsp_completion_item_set_deprecated (original, TRUE);
  lsp_completion_item_set_detail (
      original,
      "void print (string value)");
  lsp_completion_item_set_documentation (original, documentation);
  lsp_completion_item_set_preselect (original, TRUE);
  lsp_completion_item_set_sort_text (original, "001");
  lsp_completion_item_set_filter_text (original, "print");
  lsp_completion_item_set_insert_text (original, "print");
  lsp_completion_item_set_insert_text_format (
      original,
      LSP_INSERT_TEXT_FORMAT_SNIPPET);
  lsp_completion_item_set_insert_text_mode (
      original,
      LSP_INSERT_TEXT_MODE_ADJUST_INDENTATION);
  /* The owned text_edit property takes this allocation. */
  lsp_completion_item_set_text_edit (original, primary_edit);
  lsp_completion_item_add_additional_text_edit (
      original,
      &additional_edit);
  lsp_completion_item_add_commit_char (original, ";");
  lsp_completion_item_add_commit_char (original, "(");
  lsp_completion_item_set_command (original, command);
  lsp_completion_item_set_data (
      original,
      g_variant_new_string ("completion-token"));

  wire =
      lsp_completion_item_to_variant (original);
  decoded = lsp_completion_item_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_cmpstr (lsp_completion_item_get_label (decoded), ==, "print");
  g_assert_cmpint (
      lsp_completion_item_get_kind (decoded),
      ==,
      LSP_COMPLETION_ITEM_KIND_FUNCTION);
  g_assert_true (
      LSP_COMPLETION_ITEM_TAG_DEPRECATED &
      lsp_completion_item_get_tags (decoded));
  g_assert_true (lsp_completion_item_get_deprecated (decoded));
  g_assert_cmpint (
      lsp_completion_item_get_insert_text_format (decoded),
      ==,
      LSP_INSERT_TEXT_FORMAT_SNIPPET);
  g_assert_cmpint (
      lsp_completion_item_get_insert_text_mode (decoded),
      ==,
      LSP_INSERT_TEXT_MODE_ADJUST_INDENTATION);
  g_assert_cmpstr (
      lsp_markup_content_get_value (
          lsp_completion_item_get_documentation (decoded)),
      ==,
      "**Print** a value.");
  g_assert_cmpstr (
      lsp_text_edit_get_new_text (
          lsp_completion_item_get_text_edit (decoded)),
      ==,
      "print(${1:value})");

  decoded_edits = lsp_completion_item_get_additional_text_edits (
      decoded,
      &additional_count);
  g_assert_cmpint (additional_count, ==, 1);
  g_assert_cmpstr (
      lsp_text_edit_get_new_text (&decoded_edits[0]),
      ==,
      "using GLib;\n");

  decoded_commit_chars = lsp_completion_item_get_commit_chars (
      decoded,
      &commit_count);
  g_assert_cmpint (commit_count, ==, 2);
  g_assert_cmpstr (decoded_commit_chars[1], ==, "(");
  g_assert_cmpstr (
      lsp_command_get_command (
          lsp_completion_item_get_command (decoded)),
      ==,
      "vala.showDocumentation");
  g_assert_cmpstr (
      g_variant_get_string (
          lsp_completion_item_get_data (decoded),
          NULL),
      ==,
      "completion-token");
}

static void
test_completion_list_round_trip (void)
{
  gint item_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspCompletionItem) item = NULL;
  g_autoptr (LspCompletionList) original = NULL;
  g_autoptr (LspCompletionList) decoded = NULL;
  LspCompletionItem **decoded_items;

  item = lsp_completion_item_new (
      "result",
      LSP_COMPLETION_ITEM_KIND_VARIABLE);
  original = lsp_completion_list_new (TRUE, NULL, 0);
  lsp_completion_list_add_item (original, item);
  wire =
      lsp_completion_list_to_variant (original);
  decoded = lsp_completion_list_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_true (lsp_completion_list_get_is_incomplete (decoded));
  decoded_items = lsp_completion_list_get_items (decoded, &item_count);
  g_assert_cmpint (item_count, ==, 1);
  g_assert_cmpstr (
      lsp_completion_item_get_label (decoded_items[0]),
      ==,
      "result");
}

int
main (int argc, char *argv[])
{
  g_test_init (&argc, &argv, NULL);
  g_test_add_func (
      "/c/serialization/completion/context",
      test_completion_context_round_trip);
  g_test_add_func (
      "/c/serialization/completion/item",
      test_completion_item_round_trip);
  g_test_add_func (
      "/c/serialization/completion/list",
      test_completion_list_round_trip);
  return g_test_run ();
}
