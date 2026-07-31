#include "lsp-glib.h"

/*
 * These small round trips cover both stack-allocated structs and ref-counted
 * protocol objects. The markup test builds its wire value by hand so decoding
 * is tested independently of the matching encoder.
 */

static void
test_position_and_range_round_trip (void)
{
  LspPosition start = { 0 };
  LspPosition end = { 0 };
  LspRange original = { 0 };
  LspRange decoded = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) encoded = NULL;

  lsp_position_init (&start, 3, 4);
  lsp_position_init (&end, 5, 6);
  lsp_range_init (&original, &start, &end);

  encoded = lsp_range_to_variant (&original);
  lsp_range_init_from_variant (&decoded, encoded, &error);

  g_assert_no_error (error);
  g_assert_cmpuint (decoded.start.line, ==, 3);
  g_assert_cmpuint (decoded.start.character, ==, 4);
  g_assert_cmpuint (decoded.end.line, ==, 5);
  g_assert_cmpuint (decoded.end.character, ==, 6);
}

static void
test_text_document_item_round_trip (void)
{
  g_autoptr (GError) error = NULL;
  g_autoptr (GUri) uri = NULL;
  g_autoptr (GVariant) encoded = NULL;
  g_autoptr (GVariant) language_id = NULL;
  g_autoptr (LspTextDocumentItem) original = NULL;
  g_autoptr (LspTextDocumentItem) decoded = NULL;

  uri = g_uri_parse ("file:///workspace/main.vala", G_URI_FLAGS_NONE, &error);
  g_assert_no_error (error);

  original = lsp_text_document_item_new (
      uri,
      LSP_LANGUAGE_ID_VALA,
      7,
      "void main () {}\n");
  encoded = lsp_text_document_item_to_variant (original);
  language_id = g_variant_lookup_value (
      encoded,
      "languageId",
      G_VARIANT_TYPE_STRING);

  g_assert_nonnull (language_id);
  g_assert_cmpstr (g_variant_get_string (language_id, NULL), ==, "vala");

  decoded = lsp_text_document_item_new_from_variant (encoded, &error);
  g_assert_no_error (error);
  g_assert_nonnull (decoded);
  g_assert_cmpint (
      lsp_text_document_item_get_language_id (decoded),
      ==,
      LSP_LANGUAGE_ID_VALA);
  g_assert_cmpint (lsp_text_document_item_get_version (decoded), ==, 7);
  g_assert_cmpstr (
      lsp_text_document_item_get_text (decoded),
      ==,
      "void main () {}\n");
}

static void
test_genie_language_id (void)
{
  g_assert_cmpstr (
      lsp_language_id_to_string (LSP_LANGUAGE_ID_GENIE),
      ==,
      "genie");
  g_assert_cmpint (
      lsp_language_id_parse_string ("genie"),
      ==,
      LSP_LANGUAGE_ID_GENIE);
}

static void
test_markup_content_deserialization (void)
{
  GVariantBuilder builder;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) encoded = NULL;
  g_autoptr (LspMarkupContent) content = NULL;

  /* Deliberately bypass lsp_markup_content_to_variant() in this test. */
  g_variant_builder_init (&builder, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add (
      &builder,
      "{sv}",
      "kind",
      g_variant_new_string ("markdown"));
  g_variant_builder_add (
      &builder,
      "{sv}",
      "value",
      g_variant_new_string ("**bold**"));
  encoded = g_variant_ref_sink (g_variant_builder_end (&builder));

  content = lsp_markup_content_new_from_variant (encoded, &error);

  g_assert_no_error (error);
  g_assert_nonnull (content);
  g_assert_cmpint (
      lsp_markup_content_get_kind (content),
      ==,
      LSP_MARKUP_KIND_MARKDOWN);
  g_assert_cmpstr (lsp_markup_content_get_value (content), ==, "**bold**");
}

static void
test_flat_protocol_records_round_trip (void)
{
  LspPosition start = { 0 };
  LspPosition end = { 0 };
  LspRange range = { 0 };
  LspRange decoded_range = { 0 };
  LspDocumentHighlight highlight = { 0 };
  LspDocumentHighlight decoded_highlight = { 0 };
  LspReferenceContext context = { 0 };
  LspReferenceContext decoded_context = { 0 };
  LspFormattingOptions options = { 0 };
  LspFormattingOptions decoded_options = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) highlight_wire = NULL;
  g_autoptr (GVariant) context_wire = NULL;
  g_autoptr (GVariant) options_wire = NULL;

  lsp_position_init (&start, 2, 3);
  lsp_position_init (&end, 2, 9);
  lsp_range_init (&range, &start, &end);

  lsp_document_highlight_init (
      &highlight,
      &range,
      LSP_DOCUMENT_HIGHLIGHT_KIND_WRITE);
  highlight_wire = lsp_document_highlight_to_variant (&highlight);
  lsp_document_highlight_init_from_variant (
      &decoded_highlight,
      highlight_wire,
      &error);

  g_assert_no_error (error);
  g_assert_cmpint (
      lsp_document_highlight_get_kind (&decoded_highlight),
      ==,
      LSP_DOCUMENT_HIGHLIGHT_KIND_WRITE);
  lsp_document_highlight_get_range (&decoded_highlight, &decoded_range);
  g_assert_cmpuint (decoded_range.start.character, ==, 3);
  g_assert_cmpuint (decoded_range.end.character, ==, 9);

  lsp_reference_context_init (&context, FALSE);
  context_wire = lsp_reference_context_to_variant (&context);
  lsp_reference_context_init_from_variant (
      &decoded_context,
      context_wire,
      &error);

  g_assert_no_error (error);
  g_assert_false (
      lsp_reference_context_get_include_declaration (&decoded_context));

  lsp_formatting_options_init (&options, 4, TRUE);
  lsp_formatting_options_set_flags (
      &options,
      LSP_FORMATTING_OPTION_FLAGS_TRIM_TRAILING_WHITESPACE |
      LSP_FORMATTING_OPTION_FLAGS_INSERT_FINAL_NEWLINE |
      LSP_FORMATTING_OPTION_FLAGS_TRIM_FINAL_NEWLINES);
  options_wire = lsp_formatting_options_to_variant (&options);
  lsp_formatting_options_init_from_variant (
      &decoded_options,
      options_wire,
      &error);

  g_assert_no_error (error);
  g_assert_cmpint (lsp_formatting_options_get_tab_size (&decoded_options), ==, 4);
  g_assert_true (lsp_formatting_options_get_insert_spaces (&decoded_options));
  g_assert_true (
      lsp_formatting_options_get_flags (&decoded_options) &
      LSP_FORMATTING_OPTION_FLAGS_TRIM_TRAILING_WHITESPACE);
  g_assert_true (
      lsp_formatting_options_get_flags (&decoded_options) &
      LSP_FORMATTING_OPTION_FLAGS_INSERT_FINAL_NEWLINE);
  g_assert_true (
      lsp_formatting_options_get_flags (&decoded_options) &
      LSP_FORMATTING_OPTION_FLAGS_TRIM_FINAL_NEWLINES);
}

static void
test_server_option_records_round_trip (void)
{
  LspCodeLensOptions code_lens = { 0 };
  LspCodeLensOptions decoded_code_lens = { 0 };
  LspDocumentLinkOptions document_link = { 0 };
  LspDocumentLinkOptions decoded_document_link = { 0 };
  LspRenameOptions rename = { 0 };
  LspRenameOptions decoded_rename = { 0 };
  LspCallHierarchyOptions call_hierarchy = { 0 };
  LspCallHierarchyOptions decoded_call_hierarchy = { 0 };
  LspTypeHierarchyOptions type_hierarchy = { 0 };
  LspTypeHierarchyOptions decoded_type_hierarchy = { 0 };
  LspInlayHintOptions inlay_hint = { 0 };
  LspInlayHintOptions decoded_inlay_hint = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspServerCaps) original = NULL;
  g_autoptr (LspServerCaps) decoded = NULL;

  lsp_code_lens_options_init (&code_lens, TRUE);
  lsp_document_link_options_init (&document_link, TRUE);
  lsp_rename_options_init (&rename, TRUE);
  lsp_call_hierarchy_options_init (&call_hierarchy);
  lsp_type_hierarchy_options_init (&type_hierarchy);
  lsp_inlay_hint_options_init (&inlay_hint, TRUE);

  original = lsp_server_caps_new ();
  lsp_server_caps_set_code_lens (original, &code_lens);
  lsp_server_caps_set_document_link (original, &document_link);
  lsp_server_caps_set_rename (original, &rename);
  lsp_server_caps_set_call_hierarchy (original, &call_hierarchy);
  lsp_server_caps_set_type_hierarchy (original, &type_hierarchy);
  lsp_server_caps_set_inlay_hint (original, &inlay_hint);

  wire = lsp_server_caps_to_variant (original);
  decoded = lsp_server_caps_new_from_variant (wire, &error);

  g_assert_no_error (error);
  lsp_server_caps_get_code_lens (decoded, &decoded_code_lens);
  lsp_server_caps_get_document_link (decoded, &decoded_document_link);
  lsp_server_caps_get_rename (decoded, &decoded_rename);
  lsp_server_caps_get_call_hierarchy (decoded, &decoded_call_hierarchy);
  lsp_server_caps_get_type_hierarchy (decoded, &decoded_type_hierarchy);
  lsp_server_caps_get_inlay_hint (decoded, &decoded_inlay_hint);

  g_assert_true (lsp_code_lens_options_get_supported (&decoded_code_lens));
  g_assert_true (
      lsp_code_lens_options_get_supports_resolve (&decoded_code_lens));
  g_assert_true (
      lsp_document_link_options_get_supported (&decoded_document_link));
  g_assert_true (
      lsp_document_link_options_get_supports_resolve (&decoded_document_link));
  g_assert_true (lsp_rename_options_get_supported (&decoded_rename));
  g_assert_true (lsp_rename_options_get_supports_prepare (&decoded_rename));
  g_assert_true (
      lsp_call_hierarchy_options_get_supported (&decoded_call_hierarchy));
  g_assert_true (
      lsp_type_hierarchy_options_get_supported (&decoded_type_hierarchy));
  g_assert_true (lsp_inlay_hint_options_get_supported (&decoded_inlay_hint));
  g_assert_true (
      lsp_inlay_hint_options_get_resolve_provider (&decoded_inlay_hint));
}

static void
test_diagnostic_tags_and_related_information (void)
{
  LspPosition start = { 0 };
  LspPosition end = { 0 };
  LspRange range = { 0 };
  g_auto (LspLocation) location = { 0 };
  g_auto (LspLocation) decoded_location = { 0 };
  LspDiagnosticRelatedInformation *related_list[1];
  LspDiagnosticRelatedInformation **decoded_related;
  gint decoded_related_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GUri) uri = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (GVariant) tags = NULL;
  g_autoptr (GVariant) first_tag = NULL;
  g_autoptr (GVariant) second_tag = NULL;
  g_autoptr (LspDiagnosticRelatedInformation) related = NULL;
  g_autoptr (LspDiagnostic) original = NULL;
  g_autoptr (LspDiagnostic) decoded = NULL;
  g_autofree gchar *decoded_uri = NULL;

  uri = g_uri_parse ("file:///workspace/main.vala", G_URI_FLAGS_NONE, &error);
  g_assert_no_error (error);

  lsp_position_init (&start, 6, 2);
  lsp_position_init (&end, 6, 10);
  lsp_range_init (&range, &start, &end);
  lsp_location_init (&location, uri, &range);

  related = lsp_diagnostic_related_information_new (
      &location,
      "related declaration");
  related_list[0] = related;
  original = lsp_diagnostic_new ("unused declaration", &range);
  lsp_diagnostic_set_tags (
      original,
      LSP_DIAGNOSTIC_TAG_FLAGS_UNNECESSARY |
      LSP_DIAGNOSTIC_TAG_FLAGS_DEPRECATED);
  lsp_diagnostic_set_related_information (
      original,
      related_list,
      G_N_ELEMENTS (related_list));

  wire = lsp_diagnostic_to_variant (original);
  tags = g_variant_lookup_value (wire, "tags", G_VARIANT_TYPE_ARRAY);
  g_assert_nonnull (tags);
  g_assert_cmpuint (g_variant_n_children (tags), ==, 2);
  first_tag = g_variant_get_child_value (tags, 0);
  second_tag = g_variant_get_child_value (tags, 1);
  g_assert_cmpint (g_variant_get_int64 (first_tag), ==, 1);
  g_assert_cmpint (g_variant_get_int64 (second_tag), ==, 2);

  decoded = lsp_diagnostic_new_from_variant (wire, &error);
  g_assert_no_error (error);
  g_assert_true (
      lsp_diagnostic_get_tags (decoded) &
      LSP_DIAGNOSTIC_TAG_FLAGS_UNNECESSARY);
  g_assert_true (
      lsp_diagnostic_get_tags (decoded) &
      LSP_DIAGNOSTIC_TAG_FLAGS_DEPRECATED);

  decoded_related = lsp_diagnostic_get_related_information (
      decoded,
      &decoded_related_count);
  g_assert_cmpint (decoded_related_count, ==, 1);
  g_assert_cmpstr (
      lsp_diagnostic_related_information_get_message (decoded_related[0]),
      ==,
      "related declaration");
  lsp_diagnostic_related_information_get_location (
      decoded_related[0],
      &decoded_location);
  decoded_uri = g_uri_to_string (lsp_location_get_uri (&decoded_location));
  g_assert_cmpstr (decoded_uri, ==, "file:///workspace/main.vala");
}

int
main (int argc, char *argv[])
{
  g_test_init (&argc, &argv, NULL);
  g_test_add_func (
      "/c/serialization/position-and-range",
      test_position_and_range_round_trip);
  g_test_add_func (
      "/c/serialization/text-document-item",
      test_text_document_item_round_trip);
  g_test_add_func (
      "/c/serialization/genie-language-id",
      test_genie_language_id);
  g_test_add_func (
      "/c/deserialization/markup-content",
      test_markup_content_deserialization);
  g_test_add_func (
      "/c/serialization/flat-protocol-records",
      test_flat_protocol_records_round_trip);
  g_test_add_func (
      "/c/serialization/server-option-records",
      test_server_option_records_round_trip);
  g_test_add_func (
      "/c/serialization/diagnostic-tags-and-related-information",
      test_diagnostic_tags_and_related_information);
  return g_test_run ();
}
