#include "lsp-glib.h"

/*
 * These payloads contain the most important structured protocol unions:
 * recursive symbols, signature offset labels, typed inlay labels, and
 * Command|CodeAction dispatch.
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
make_range (LspRange *range,
            guint64 start_line,
            guint64 start_character,
            guint64 end_line,
            guint64 end_character)
{
  LspPosition start = { 0 };
  LspPosition end = { 0 };

  lsp_position_init (&start, start_line, start_character);
  lsp_position_init (&end, end_line, end_character);
  lsp_range_init (range, &start, &end);
}

static void
test_signature_help_round_trip (void)
{
  guint active_parameter = 1;
  LspParameterInformation *parameters[2];
  LspSignatureInformation *signatures[1];
  gint signature_count;
  gint parameter_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspMarkupContent) plain_documentation = NULL;
  g_autoptr (LspMarkupContent) markdown_documentation = NULL;
  g_autoptr (LspParameterInformation) named_parameter = NULL;
  g_autoptr (LspParameterInformation) offset_parameter = NULL;
  g_autoptr (LspSignatureInformation) signature = NULL;
  g_autoptr (LspSignatureHelp) original = NULL;
  g_autoptr (LspSignatureHelp) decoded = NULL;
  LspSignatureInformation **decoded_signatures;
  LspParameterInformation **decoded_parameters;

  plain_documentation = lsp_markup_content_new (
      LSP_MARKUP_KIND_PLAINTEXT,
      "The value to print");
  markdown_documentation = lsp_markup_content_new (
      LSP_MARKUP_KIND_MARKDOWN,
      "`format` string");
  named_parameter = lsp_parameter_information_new ("value");
  lsp_parameter_information_set_documentation (
      named_parameter,
      plain_documentation);
  offset_parameter = lsp_parameter_information_new_with_offsets (13, 19);
  lsp_parameter_information_set_documentation (
      offset_parameter,
      markdown_documentation);
  parameters[0] = named_parameter;
  parameters[1] = offset_parameter;

  signature = lsp_signature_information_new (
      "print_value(value, format)");
  lsp_signature_information_set_parameters (
      signature,
      parameters,
      G_N_ELEMENTS (parameters));
  lsp_signature_information_set_active_parameter (
      signature,
      &active_parameter);
  signatures[0] = signature;
  original = lsp_signature_help_new (
      signatures,
      G_N_ELEMENTS (signatures),
      0,
      1);

  wire =
      lsp_signature_help_to_variant (original);
  decoded = lsp_signature_help_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_cmpuint (
      lsp_signature_help_get_active_parameter (decoded),
      ==,
      1);
  decoded_signatures = lsp_signature_help_get_signatures (
      decoded,
      &signature_count);
  g_assert_cmpint (signature_count, ==, 1);
  decoded_parameters = lsp_signature_information_get_parameters (
      decoded_signatures[0],
      &parameter_count);
  g_assert_cmpint (parameter_count, ==, 2);
  g_assert_cmpstr (
      lsp_parameter_information_get_label (decoded_parameters[0]),
      ==,
      "value");
  g_assert_true (
      lsp_parameter_information_get_has_label_offsets (
          decoded_parameters[1]));
  g_assert_cmpuint (
      lsp_parameter_information_get_label_start (
          decoded_parameters[1]),
      ==,
      13);
  g_assert_cmpuint (
      lsp_parameter_information_get_label_end (
          decoded_parameters[1]),
      ==,
      19);
}

static void
test_symbols_round_trip (void)
{
  LspRange parent_range = { 0 };
  LspRange parent_selection = { 0 };
  LspRange child_range = { 0 };
  LspRange child_selection = { 0 };
  LspDocumentSymbol *children[1];
  gint child_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (GUri) uri = parse_uri (
      "file:///workspace/main.vala");
  g_autoptr (LspDocumentSymbol) child = NULL;
  g_autoptr (LspDocumentSymbol) parent = NULL;
  g_autoptr (LspDocumentSymbol) decoded = NULL;
  g_autoptr (LspWorkspaceSymbol) workspace = NULL;
  g_autoptr (LspWorkspaceSymbol) decoded_workspace = NULL;
  g_autofree gchar *decoded_uri = NULL;
  LspDocumentSymbol **decoded_children;

  make_range (&parent_range, 0, 0, 6, 1);
  make_range (&parent_selection, 0, 6, 0, 13);
  make_range (&child_range, 2, 4, 4, 5);
  make_range (&child_selection, 2, 9, 2, 15);

  child = lsp_document_symbol_new (
      "method",
      LSP_SYMBOL_KIND_METHOD,
      &child_range,
      &child_selection,
      "void method ()",
      LSP_SYMBOL_TAG_DEPRECATED);
  parent = lsp_document_symbol_new (
      "Example",
      LSP_SYMBOL_KIND_CLASS,
      &parent_range,
      &parent_selection,
      "class Example",
      LSP_SYMBOL_TAG_UNSET);
  children[0] = child;
  lsp_document_symbol_set_children (
      parent,
      children,
      G_N_ELEMENTS (children));

  wire =
      lsp_document_symbol_to_variant (parent);
  decoded = lsp_document_symbol_new_from_variant (wire, &error);

  g_assert_no_error (error);
  decoded_children = lsp_document_symbol_get_children (
      decoded,
      &child_count);
  g_assert_cmpint (child_count, ==, 1);
  g_assert_cmpstr (
      lsp_document_symbol_get_name (decoded_children[0]),
      ==,
      "method");
  g_assert_true (
      LSP_SYMBOL_TAG_DEPRECATED &
      lsp_document_symbol_get_tags (decoded_children[0]));

  g_clear_pointer (&wire, g_variant_unref);
  workspace = lsp_workspace_symbol_new (
      "Example",
      LSP_SYMBOL_KIND_CLASS,
      uri,
      &parent_range,
      "demo",
      LSP_SYMBOL_TAG_DEPRECATED);
  wire =
      lsp_workspace_symbol_to_variant (workspace);
  decoded_workspace = lsp_workspace_symbol_new_from_variant (
      wire,
      &error);

  g_assert_no_error (error);
  decoded_uri = g_uri_to_string (
      lsp_workspace_symbol_get_uri (decoded_workspace));
  g_assert_cmpstr (
      decoded_uri,
      ==,
      "file:///workspace/main.vala");
  g_assert_nonnull (
      lsp_workspace_symbol_get_range (decoded_workspace));
  g_assert_cmpuint (
      lsp_workspace_symbol_get_range (decoded_workspace)->start.line,
      ==,
      0);
}

static void
test_inlay_hint_round_trip (void)
{
  LspPosition position = { 0 };
  LspRange location_range = { 0 };
  LspLocation location = { 0 };
  LspInlayHintLabelPart *parts[1];
  gint part_count;
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (GUri) uri = parse_uri (
      "file:///workspace/main.vala");
  g_autoptr (LspMarkupContent) tooltip = NULL;
  g_autoptr (LspCommand) command = NULL;
  g_autoptr (LspInlayHintLabelPart) part = NULL;
  g_autoptr (LspInlayHint) original = NULL;
  g_autoptr (LspInlayHint) decoded = NULL;
  g_autoptr (LspInlayHint) text_hint = NULL;
  g_autoptr (LspInlayHint) decoded_text = NULL;
  LspInlayHintLabelPart **decoded_parts;

  lsp_position_init (&position, 2, 9);
  make_range (&location_range, 2, 4, 2, 9);
  lsp_location_init (&location, uri, &location_range);
  tooltip = lsp_markup_content_new (
      LSP_MARKUP_KIND_MARKDOWN,
      "Inferred **type**");
  command = lsp_command_new ("Open type", "vala.openType", NULL, 0);
  part = lsp_inlay_hint_label_part_new (": string");
  lsp_inlay_hint_label_part_set_tooltip (part, tooltip);
  lsp_inlay_hint_label_part_set_location (part, &location);
  lsp_inlay_hint_label_part_set_command (part, command);
  parts[0] = part;
  original = lsp_inlay_hint_new_with_label_parts (
      &position,
      parts,
      G_N_ELEMENTS (parts),
      LSP_INLAY_HINT_KIND_TYPE);
  lsp_inlay_hint_set_padding (
      original,
      LSP_INLAY_HINT_PADDING_LEFT |
      LSP_INLAY_HINT_PADDING_RIGHT);
  lsp_inlay_hint_set_data (
      original,
      g_variant_new_string ("hint-token"));

  wire =
      lsp_inlay_hint_to_variant (original);
  decoded = lsp_inlay_hint_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_null (lsp_inlay_hint_get_label (decoded));
  decoded_parts = lsp_inlay_hint_get_label_parts (
      decoded,
      &part_count);
  g_assert_cmpint (part_count, ==, 1);
  g_assert_cmpstr (
      lsp_inlay_hint_label_part_get_value (decoded_parts[0]),
      ==,
      ": string");
  g_assert_cmpstr (
      lsp_command_get_command (
          lsp_inlay_hint_label_part_get_command (
              decoded_parts[0])),
      ==,
      "vala.openType");
  g_assert_true (
      LSP_INLAY_HINT_PADDING_LEFT &
      lsp_inlay_hint_get_padding (decoded));
  g_assert_true (
      LSP_INLAY_HINT_PADDING_RIGHT &
      lsp_inlay_hint_get_padding (decoded));

  g_clear_pointer (&wire, g_variant_unref);
  text_hint = lsp_inlay_hint_new (
      &position,
      "parameter:",
      LSP_INLAY_HINT_KIND_PARAMETER);
  wire =
      lsp_inlay_hint_to_variant (text_hint);
  decoded_text = lsp_inlay_hint_new_from_variant (wire, &error);
  g_assert_no_error (error);
  g_assert_cmpstr (
      lsp_inlay_hint_get_label (decoded_text),
      ==,
      "parameter:");
  g_assert_null (
      lsp_inlay_hint_get_label_parts (decoded_text, NULL));
}

static void
test_code_action_union_round_trip (void)
{
  LspRange diagnostic_range = { 0 };
  LspDiagnostic *diagnostics[1];
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspDiagnostic) diagnostic = NULL;
  g_autoptr (LspCommand) command = NULL;
  g_autoptr (LspCodeAction) original = NULL;
  g_autoptr (LspAction) decoded = NULL;

  make_range (&diagnostic_range, 3, 2, 3, 8);
  diagnostic = lsp_diagnostic_new (
      "replace deprecated call",
      &diagnostic_range);
  lsp_diagnostic_set_severity (
      diagnostic,
      LSP_DIAGNOSTIC_SEVERITY_WARNING);
  diagnostics[0] = diagnostic;
  command = lsp_command_new ("Refresh", "vala.refresh", NULL, 0);
  original = lsp_code_action_new ("Replace deprecated call");
  lsp_code_action_set_kind (
      original,
      LSP_CODE_ACTION_KIND_QUICK_FIX);
  lsp_code_action_set_preferred (original, TRUE);
  lsp_code_action_set_disabled_reason (
      original,
      "project is read-only");
  lsp_code_action_set_diagnostics (
      original,
      diagnostics,
      G_N_ELEMENTS (diagnostics));
  lsp_code_action_set_command (original, command);
  lsp_code_action_set_data (
      original,
      g_variant_new_string ("action-token"));

  wire =
      lsp_action_to_variant (LSP_ACTION (original));
  decoded = lsp_action_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_true (LSP_IS_CODE_ACTION (decoded));
  g_assert_cmpint (
      lsp_code_action_get_kind (LSP_CODE_ACTION (decoded)),
      ==,
      LSP_CODE_ACTION_KIND_QUICK_FIX);
  g_assert_true (
      lsp_code_action_get_preferred (LSP_CODE_ACTION (decoded)));
  g_assert_cmpstr (
      lsp_code_action_get_disabled_reason (
          LSP_CODE_ACTION (decoded)),
      ==,
      "project is read-only");
  g_assert_cmpstr (
      lsp_command_get_command (
          lsp_code_action_get_command (
              LSP_CODE_ACTION (decoded))),
      ==,
      "vala.refresh");
}

static void
test_document_symbol_result_round_trip (void)
{
  LspRange range = { 0 };
  LspRange selection = { 0 };
  LspDocumentSymbol *document_symbols[1];
  LspSymbolInformation *symbol_information[1];
  gint result_length;
  g_auto (LspLocation) location = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GUri) uri = parse_uri (
      "file:///workspace/main.vala");
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspDocumentSymbol) document_symbol = NULL;
  g_autoptr (LspSymbolInformation) flat_symbol = NULL;
  g_autoptr (LspDocumentSymbolResult) original = NULL;
  g_autoptr (LspDocumentSymbolResult) decoded = NULL;
  LspDocumentSymbol **decoded_document_symbols;
  LspSymbolInformation **decoded_symbol_information;

  make_range (&range, 0, 0, 4, 1);
  make_range (&selection, 0, 6, 0, 13);
  document_symbol = lsp_document_symbol_new (
      "Example",
      LSP_SYMBOL_KIND_CLASS,
      &range,
      &selection,
      NULL,
      LSP_SYMBOL_TAG_UNSET);
  document_symbols[0] = document_symbol;
  original = lsp_document_symbol_result_new_for_document_symbols (
      document_symbols,
      G_N_ELEMENTS (document_symbols));
  wire = lsp_document_symbol_result_to_variant (original);
  decoded = lsp_document_symbol_result_new_from_variant (wire, &error);

  g_assert_no_error (error);
  decoded_document_symbols = lsp_document_symbol_result_get_document_symbols (
      decoded,
      &result_length);
  g_assert_cmpint (result_length, ==, 1);
  g_assert_cmpstr (
      lsp_document_symbol_get_name (decoded_document_symbols[0]),
      ==,
      "Example");
  g_assert_null (
      lsp_document_symbol_result_get_symbol_information (
          decoded,
          NULL));

  g_clear_pointer (&wire, g_variant_unref);
  g_clear_pointer (&original, lsp_document_symbol_result_unref);
  g_clear_pointer (&decoded, lsp_document_symbol_result_unref);
  lsp_location_init (&location, uri, &range);
  flat_symbol = lsp_symbol_information_new (
      "Example",
      LSP_SYMBOL_KIND_CLASS,
      &location,
      NULL,
      LSP_SYMBOL_TAG_UNSET);
  symbol_information[0] = flat_symbol;
  original = lsp_document_symbol_result_new_for_symbol_information (
      symbol_information,
      G_N_ELEMENTS (symbol_information));
  wire = lsp_document_symbol_result_to_variant (original);
  decoded = lsp_document_symbol_result_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_null (
      lsp_document_symbol_result_get_document_symbols (
          decoded,
          NULL));
  decoded_symbol_information = lsp_document_symbol_result_get_symbol_information (
      decoded,
      &result_length);
  g_assert_cmpint (result_length, ==, 1);
  g_assert_cmpstr (
      lsp_symbol_information_get_name (decoded_symbol_information[0]),
      ==,
      "Example");
}

static void
test_prepare_rename_result_round_trip (void)
{
  LspRange range = { 0 };
  g_auto (LspPrepareRenameResult) original = { 0 };
  g_auto (LspPrepareRenameResult) decoded = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GVariant) wire = NULL;

  make_range (&range, 3, 4, 3, 11);
  lsp_prepare_rename_result_init_for_range (
      &original,
      &range,
      "old_name");
  wire = lsp_prepare_rename_result_to_variant (&original);
  lsp_prepare_rename_result_init_from_variant (
      &decoded,
      wire,
      &error);

  g_assert_no_error (error);
  g_assert_true (decoded.has_range);
  g_assert_cmpstr (decoded.placeholder, ==, "old_name");
  g_assert_cmpuint (decoded.range.start.character, ==, 4);

  g_clear_pointer (&wire, g_variant_unref);
  lsp_prepare_rename_result_destroy (&original);
  original = (LspPrepareRenameResult) { 0 };
  lsp_prepare_rename_result_destroy (&decoded);
  decoded = (LspPrepareRenameResult) { 0 };
  lsp_prepare_rename_result_init_for_default_behavior (
      &original,
      TRUE);
  wire = lsp_prepare_rename_result_to_variant (&original);
  lsp_prepare_rename_result_init_from_variant (
      &decoded,
      wire,
      &error);

  g_assert_no_error (error);
  g_assert_false (decoded.has_range);
  g_assert_true (decoded.default_behavior);
}

static void
test_type_hierarchy_and_capabilities_round_trip (void)
{
  LspRange range = { 0 };
  LspRange selection = { 0 };
  LspSymbolKind symbol_kinds[] = {
    LSP_SYMBOL_KIND_CLASS,
    LSP_SYMBOL_KIND_METHOD,
  };
  g_autoptr (GError) error = NULL;
  g_autoptr (GUri) uri = parse_uri (
      "file:///workspace/main.vala");
  g_autoptr (GVariant) wire = NULL;
  g_autoptr (LspTypeHierarchyItem) item = NULL;
  g_autoptr (LspTypeHierarchyItem) decoded_item = NULL;
  g_autoptr (LspDocumentSymbolClientCaps) symbol_caps = NULL;
  g_autoptr (LspRenameClientCaps) rename_caps = NULL;
  g_autoptr (LspTypeHierarchyClientCaps) hierarchy_caps = NULL;
  g_autoptr (LspTextDocumentClientCaps) text_caps = NULL;
  g_autoptr (LspClientCaps) client_caps = NULL;
  g_autoptr (LspClientCaps) decoded_client = NULL;
  g_autoptr (LspTypeHierarchyOptions) hierarchy_options = NULL;
  g_autoptr (LspServerCaps) server_caps = NULL;
  g_autoptr (LspServerCaps) decoded_server = NULL;

  make_range (&range, 0, 0, 5, 1);
  make_range (&selection, 0, 6, 0, 13);
  item = lsp_type_hierarchy_item_new (
      "Example",
      LSP_SYMBOL_KIND_CLASS,
      uri,
      &range,
      &selection,
      "class Example",
      LSP_SYMBOL_TAG_DEPRECATED);
  lsp_type_hierarchy_item_set_data (
      item,
      g_variant_new_string ("hierarchy-token"));
  wire = lsp_type_hierarchy_item_to_variant (item);
  decoded_item = lsp_type_hierarchy_item_new_from_variant (
      wire,
      &error);

  g_assert_no_error (error);
  g_assert_cmpstr (
      lsp_type_hierarchy_item_get_name (decoded_item),
      ==,
      "Example");
  g_assert_cmpint (
      lsp_type_hierarchy_item_get_kind (decoded_item),
      ==,
      LSP_SYMBOL_KIND_CLASS);
  g_assert_true (
      LSP_SYMBOL_TAG_DEPRECATED &
      lsp_type_hierarchy_item_get_tags (decoded_item));
  g_assert_cmpstr (
      g_variant_get_string (
          lsp_type_hierarchy_item_get_data (decoded_item),
          NULL),
      ==,
      "hierarchy-token");

  symbol_caps = lsp_document_symbol_client_caps_new ();
  lsp_document_symbol_client_caps_set_symbol_kinds (
      symbol_caps,
      symbol_kinds,
      G_N_ELEMENTS (symbol_kinds));
  lsp_document_symbol_client_caps_set_hierarchical_document_symbol_support (
      symbol_caps,
      TRUE);
  lsp_document_symbol_client_caps_set_supported_tags (
      symbol_caps,
      LSP_SYMBOL_TAG_DEPRECATED);
  rename_caps = lsp_rename_client_caps_new ();
  lsp_rename_client_caps_set_prepare_support (rename_caps, TRUE);
  lsp_rename_client_caps_set_prepare_support_default_behavior (
      rename_caps,
      LSP_PREPARE_SUPPORT_DEFAULT_BEHAVIOR_IDENTIFIER);
  hierarchy_caps = lsp_type_hierarchy_client_caps_new ();
  lsp_type_hierarchy_client_caps_set_dynamic_registration (
      hierarchy_caps,
      TRUE);
  text_caps = lsp_text_document_client_caps_new ();
  lsp_text_document_client_caps_set_synchronization (
      text_caps,
      LSP_TEXT_DOCUMENT_SYNC_CLIENT_CAPS_WILL_SAVE |
      LSP_TEXT_DOCUMENT_SYNC_CLIENT_CAPS_DID_SAVE);
  lsp_text_document_client_caps_set_document_symbol (
      text_caps,
      symbol_caps);
  lsp_text_document_client_caps_set_rename (text_caps, rename_caps);
  lsp_text_document_client_caps_set_type_hierarchy (
      text_caps,
      hierarchy_caps);
  client_caps = lsp_client_caps_new ();
  lsp_client_caps_set_text_document (client_caps, text_caps);
  g_clear_pointer (&wire, g_variant_unref);
  wire = lsp_client_caps_to_variant (client_caps);
  decoded_client = lsp_client_caps_new_from_variant (wire, &error);

  g_assert_no_error (error);
  g_assert_true (
      LSP_TEXT_DOCUMENT_SYNC_CLIENT_CAPS_WILL_SAVE &
      lsp_text_document_client_caps_get_synchronization (
          lsp_client_caps_get_text_document (decoded_client)));
  g_assert_true (
      lsp_document_symbol_client_caps_get_hierarchical_document_symbol_support (
          lsp_text_document_client_caps_get_document_symbol (
              lsp_client_caps_get_text_document (decoded_client))));
  g_assert_true (
      lsp_rename_client_caps_get_prepare_support (
          lsp_text_document_client_caps_get_rename (
              lsp_client_caps_get_text_document (decoded_client))));
  g_assert_true (
      lsp_type_hierarchy_client_caps_get_dynamic_registration (
          lsp_text_document_client_caps_get_type_hierarchy (
              lsp_client_caps_get_text_document (decoded_client))));

  hierarchy_options = lsp_type_hierarchy_options_new ();
  server_caps = lsp_server_caps_new ();
  lsp_server_caps_set_type_hierarchy (
      server_caps,
      hierarchy_options);
  g_clear_pointer (&wire, g_variant_unref);
  wire = lsp_server_caps_to_variant (server_caps);
  decoded_server = lsp_server_caps_new_from_variant (wire, &error);
  g_assert_no_error (error);
  g_assert_nonnull (
      lsp_server_caps_get_type_hierarchy (decoded_server));
}

static void
test_protocol_error_values (void)
{
  g_assert_cmpint (LSP_PROTOCOL_ERROR_PARSE_ERROR, ==, -32700);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_INVALID_REQUEST, ==, -32600);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_METHOD_NOT_FOUND, ==, -32601);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_INVALID_PARAMS, ==, -32602);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_INTERNAL_ERROR, ==, -32603);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_SERVER_NOT_INITIALIZED, ==, -32002);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_UNKNOWN_ERROR_CODE, ==, -32001);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_REQUEST_FAILED, ==, -32803);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_SERVER_CANCELLED, ==, -32802);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_CONTENT_MODIFIED, ==, -32801);
  g_assert_cmpint (LSP_PROTOCOL_ERROR_REQUEST_CANCELLED, ==, -32800);
}

int
main (int argc, char *argv[])
{
  g_test_init (&argc, &argv, NULL);
  g_test_add_func (
      "/c/serialization/advanced/signature-help",
      test_signature_help_round_trip);
  g_test_add_func (
      "/c/serialization/advanced/symbols",
      test_symbols_round_trip);
  g_test_add_func (
      "/c/serialization/advanced/inlay-hint",
      test_inlay_hint_round_trip);
  g_test_add_func (
      "/c/serialization/advanced/code-action-union",
      test_code_action_union_round_trip);
  g_test_add_func (
      "/c/serialization/advanced/document-symbol-result",
      test_document_symbol_result_round_trip);
  g_test_add_func (
      "/c/serialization/advanced/prepare-rename-result",
      test_prepare_rename_result_round_trip);
  g_test_add_func (
      "/c/serialization/advanced/type-hierarchy-and-capabilities",
      test_type_hierarchy_and_capabilities_round_trip);
  g_test_add_func (
      "/c/protocol/error-values",
      test_protocol_error_values);
  return g_test_run ();
}
