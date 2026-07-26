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
      "/c/deserialization/markup-content",
      test_markup_content_deserialization);
  return g_test_run ();
}
