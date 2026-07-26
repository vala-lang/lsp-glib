#include "lsp-glib.h"
#include "test-editor.h"
#include "test-server.h"
#include "test-stream.h"

/*
 * Exercise both directions of one JSON-RPC connection. The Editor first sends
 * document lifecycle messages to TestServer; the server's captured LspClient
 * then sends UI notifications and requests back to TestEditor.
 */

typedef enum
{
  EDITOR_OPERATION_INITIALIZE,
  EDITOR_OPERATION_INITIALIZED,
  EDITOR_OPERATION_OPEN,
  EDITOR_OPERATION_EDIT,
  EDITOR_OPERATION_CLOSE,
} EditorOperationKind;

typedef struct
{
  EditorOperationKind kind;
  gboolean completed;
  GError *error;
} EditorOperation;

typedef enum
{
  CLIENT_OPERATION_SHOW_MESSAGE,
  CLIENT_OPERATION_LOG_MESSAGE,
  CLIENT_OPERATION_LOG_TRACE,
  CLIENT_OPERATION_PUBLISH_DIAGNOSTICS,
  CLIENT_OPERATION_ASK_MESSAGE,
  CLIENT_OPERATION_SHOW_DOCUMENT,
  CLIENT_OPERATION_APPLY_EDIT,
} ClientOperationKind;

typedef struct
{
  ClientOperationKind kind;
  gboolean completed;
  GError *error;
  LspMessageActionItem *selected_action;
  gboolean shown;
  LspApplyWorkspaceEditResult *apply_result;
} ClientOperation;

static void
editor_operation_ready (GObject *source,
                        GAsyncResult *result,
                        gpointer user_data)
{
  LspEditor *editor = LSP_EDITOR (source);
  EditorOperation *operation = user_data;

  switch (operation->kind)
    {
    case EDITOR_OPERATION_INITIALIZE:
      lsp_editor_initialize_finish (
          editor,
          result,
          &operation->error);
      break;

    case EDITOR_OPERATION_INITIALIZED:
      lsp_editor_initialized_finish (
          editor,
          result,
          &operation->error);
      break;

    case EDITOR_OPERATION_OPEN:
      lsp_editor_open_text_document_finish (
          editor,
          result,
          &operation->error);
      break;

    case EDITOR_OPERATION_EDIT:
      lsp_editor_edit_text_document_finish (
          editor,
          result,
          &operation->error);
      break;

    case EDITOR_OPERATION_CLOSE:
      lsp_editor_close_text_document_finish (
          editor,
          result,
          &operation->error);
      break;

    default:
      g_assert_not_reached ();
    }

  operation->completed = TRUE;
}

static void
client_operation_ready (GObject *source,
                        GAsyncResult *result,
                        gpointer user_data)
{
  LspClient *client = LSP_CLIENT (source);
  ClientOperation *operation = user_data;

  switch (operation->kind)
    {
    case CLIENT_OPERATION_SHOW_MESSAGE:
      lsp_client_show_message_finish (
          client,
          result,
          &operation->error);
      break;

    case CLIENT_OPERATION_LOG_MESSAGE:
      lsp_client_log_message_finish (
          client,
          result,
          &operation->error);
      break;

    case CLIENT_OPERATION_LOG_TRACE:
      lsp_client_log_trace_finish (
          client,
          result,
          &operation->error);
      break;

    case CLIENT_OPERATION_PUBLISH_DIAGNOSTICS:
      lsp_client_publish_diagnostics_finish (
          client,
          result,
          &operation->error);
      break;

    case CLIENT_OPERATION_ASK_MESSAGE:
      operation->selected_action = lsp_client_ask_message_finish (
          client,
          result,
          &operation->error);
      break;

    case CLIENT_OPERATION_SHOW_DOCUMENT:
      operation->shown = lsp_client_show_document_finish (
          client,
          result,
          &operation->error);
      break;

    case CLIENT_OPERATION_APPLY_EDIT:
      operation->apply_result = lsp_client_apply_edit_finish (
          client,
          result,
          &operation->error);
      break;

    default:
      g_assert_not_reached ();
    }

  operation->completed = TRUE;
}

static void
wait_for_completion (gboolean *completed,
                     GError **error)
{
  gint64 deadline = g_get_monotonic_time () + (2 * G_TIME_SPAN_SECOND);

  while (!*completed &&
         g_get_monotonic_time () < deadline)
    {
      while (g_main_context_pending (NULL))
        g_main_context_iteration (NULL, FALSE);
      g_usleep (1000);
    }

  g_assert_true (*completed);
  g_assert_no_error (*error);
}

static void
wait_for_server_events (TestServer *server,
                        guint expected_count)
{
  gint64 deadline = g_get_monotonic_time () + (2 * G_TIME_SPAN_SECOND);

  while (server->n_events < expected_count &&
         g_get_monotonic_time () < deadline)
    {
      while (g_main_context_pending (NULL))
        g_main_context_iteration (NULL, FALSE);
      g_usleep (1000);
    }

  g_assert_cmpuint (server->n_events, ==, expected_count);
}

static void
wait_for_editor_events (TestEditor *editor,
                        guint expected_count)
{
  gint64 deadline = g_get_monotonic_time () + (2 * G_TIME_SPAN_SECOND);

  while (editor->n_events < expected_count &&
         g_get_monotonic_time () < deadline)
    {
      while (g_main_context_pending (NULL))
        g_main_context_iteration (NULL, FALSE);
      g_usleep (1000);
    }

  g_assert_cmpuint (editor->n_events, ==, expected_count);
}

static void
test_server_and_editor (void)
{
  static const gchar *expected_server_events[] = {
    "initialize",
    "initialize-finish",
    "initialized",
    "initialized-finish",
    "did-open",
    "did-open-finish",
    "did-change",
    "did-change-finish",
    "did-close",
    "did-close-finish",
  };
  static const gchar *expected_editor_events[] = {
    "show-message",
    "log-message",
    "log-trace",
    "publish-diagnostics",
    "show-message-request",
    "show-document",
    "apply-edit",
  };
  g_auto (LspTextDocumentContentChangeEvent) change = { 0 };
  LspMessageActionItem actions[2] = {{ 0 }};
  LspPosition start = { 0 };
  LspPosition end = { 0 };
  LspRange range = { 0 };
  gint64 diagnostic_version = 2;
  g_autoptr (GError) error = NULL;
  g_autoptr (GMainLoop) loop = g_main_loop_new (NULL, FALSE);
  g_autoptr (TestServer) server = test_server_new (loop);
  g_autoptr (TestEditor) editor = test_editor_new ();
  g_autoptr (GIOStream) server_stream = NULL;
  g_autoptr (GIOStream) editor_stream = NULL;
  g_autoptr (GUri) workspace_uri = g_uri_parse (
      "file:///workspace",
      G_URI_FLAGS_NONE,
      &error);
  g_autoptr (GUri) document_uri = g_uri_parse (
      "file:///server-test.vala",
      G_URI_FLAGS_NONE,
      &error);
  g_autoptr (LspWorkspaceFolder) workspace = NULL;
  g_autoptr (LspDiagnostic) diagnostic = NULL;
  LspDiagnostic *diagnostics[1];
  g_autoptr (LspWorkspaceEdit) edit = NULL;
  EditorOperation editor_operation = {
    .kind = EDITOR_OPERATION_INITIALIZE,
  };

  g_assert_no_error (error);
  workspace = lsp_workspace_folder_new (
      workspace_uri,
      "workspace");

  /* Both peers can issue requests over the same duplex stream pair. */
  create_test_stream_pair (&server_stream, &editor_stream);
  jsonrpc_server_accept_io_stream (
      JSONRPC_SERVER (server),
      server_stream);
  jsonrpc_server_accept_io_stream (
      JSONRPC_SERVER (editor),
      editor_stream);

  lsp_editor_initialize_async (
      LSP_EDITOR (editor),
      workspace,
      NULL,
      0,
      editor_operation_ready,
      &editor_operation);
  wait_for_completion (
      &editor_operation.completed,
      &editor_operation.error);
  wait_for_server_events (server, 2);

  editor_operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_INITIALIZED,
  };
  lsp_editor_initialized_async (
      LSP_EDITOR (editor),
      editor_operation_ready,
      &editor_operation);
  wait_for_completion (
      &editor_operation.completed,
      &editor_operation.error);
  wait_for_server_events (server, 4);

  editor_operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_OPEN,
  };
  lsp_editor_open_text_document_async (
      LSP_EDITOR (editor),
      document_uri,
      LSP_LANGUAGE_ID_VALA,
      "class Before {}",
      editor_operation_ready,
      &editor_operation);
  wait_for_completion (
      &editor_operation.completed,
      &editor_operation.error);
  wait_for_server_events (server, 6);
  g_assert_true (g_hash_table_contains (
      lsp_editor_get_text_documents (LSP_EDITOR (editor)),
      document_uri));

  lsp_text_document_content_change_event_init (
      &change,
      NULL,
      "class After {}");
  editor_operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_EDIT,
  };
  lsp_editor_edit_text_document_async (
      LSP_EDITOR (editor),
      document_uri,
      2,
      &change,
      1,
      editor_operation_ready,
      &editor_operation);
  wait_for_completion (
      &editor_operation.completed,
      &editor_operation.error);
  wait_for_server_events (server, 8);

  editor_operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_CLOSE,
  };
  lsp_editor_close_text_document_async (
      LSP_EDITOR (editor),
      document_uri,
      editor_operation_ready,
      &editor_operation);
  wait_for_completion (
      &editor_operation.completed,
      &editor_operation.error);
  wait_for_server_events (server, 10);
  g_assert_false (g_hash_table_contains (
      lsp_editor_get_text_documents (LSP_EDITOR (editor)),
      document_uri));

  /* Initialization exposes the reverse-facing client used by the server. */
  g_assert_nonnull (server->peer_client);

  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_SHOW_MESSAGE,
    };

    lsp_client_show_message_async (
        server->peer_client,
        LSP_MESSAGE_TYPE_INFO,
        "Build completed",
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    wait_for_editor_events (editor, 1);
  }
  g_assert_cmpint (editor->shown_type, ==, LSP_MESSAGE_TYPE_INFO);
  g_assert_cmpstr (editor->shown_message, ==, "Build completed");

  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_LOG_MESSAGE,
    };

    lsp_client_log_message_async (
        server->peer_client,
        LSP_MESSAGE_TYPE_LOG,
        "Index refreshed",
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    wait_for_editor_events (editor, 2);
  }
  g_assert_cmpint (editor->logged_type, ==, LSP_MESSAGE_TYPE_LOG);
  g_assert_cmpstr (editor->logged_message, ==, "Index refreshed");

  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_LOG_TRACE,
    };

    lsp_client_log_trace_async (
        server->peer_client,
        "request complete",
        "elapsed=2ms",
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    wait_for_editor_events (editor, 3);
  }
  g_assert_cmpstr (editor->trace_message, ==, "request complete");
  g_assert_cmpstr (editor->trace_verbose, ==, "elapsed=2ms");

  lsp_position_init (&start, 1, 2);
  lsp_position_init (&end, 1, 7);
  lsp_range_init (&range, &start, &end);
  diagnostic = lsp_diagnostic_new ("unused value", &range);
  lsp_diagnostic_set_severity (
      diagnostic,
      LSP_DIAGNOSTIC_SEVERITY_WARNING);
  diagnostics[0] = diagnostic;
  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_PUBLISH_DIAGNOSTICS,
    };

    lsp_client_publish_diagnostics_async (
        server->peer_client,
        document_uri,
        diagnostics,
        1,
        &diagnostic_version,
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    wait_for_editor_events (editor, 4);
  }
  g_assert_cmpstr (
      editor->diagnostic_uri,
      ==,
      "file:///server-test.vala");
  g_assert_true (editor->has_diagnostic_version);
  g_assert_cmpint (editor->diagnostic_version, ==, 2);
  g_assert_cmpuint (editor->diagnostic_count, ==, 1);
  g_assert_cmpstr (editor->diagnostic_message, ==, "unused value");

  lsp_message_action_item_init (&actions[0], "Apply");
  lsp_message_action_item_init (&actions[1], "Cancel");
  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_ASK_MESSAGE,
    };

    lsp_client_ask_message_async (
        server->peer_client,
        LSP_MESSAGE_TYPE_WARNING,
        "Apply suggested edit?",
        actions,
        2,
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    g_assert_nonnull (operation.selected_action);
    g_assert_cmpstr (
        lsp_message_action_item_get_title (operation.selected_action),
        ==,
        "Apply");
    lsp_message_action_item_free (operation.selected_action);
  }
  g_assert_cmpint (editor->prompt_type, ==, LSP_MESSAGE_TYPE_WARNING);
  g_assert_cmpstr (
      editor->prompt_message,
      ==,
      "Apply suggested edit?");
  g_assert_cmpuint (editor->prompt_action_count, ==, 2);
  g_assert_cmpstr (editor->prompt_first_action, ==, "Apply");

  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_SHOW_DOCUMENT,
    };

    lsp_client_show_document_async (
        server->peer_client,
        document_uri,
        TRUE,
        TRUE,
        &range,
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    g_assert_true (operation.shown);
  }
  g_assert_cmpstr (
      editor->shown_document_uri,
      ==,
      "file:///server-test.vala");
  g_assert_true (editor->shown_document_external);
  g_assert_true (editor->shown_document_take_focus);
  g_assert_true (editor->has_shown_document_selection);
  g_assert_cmpuint (
      editor->shown_document_selection.start.line,
      ==,
      1);
  g_assert_cmpuint (
      editor->shown_document_selection.end.character,
      ==,
      7);

  edit = lsp_workspace_edit_new ();
  {
    ClientOperation operation = {
      .kind = CLIENT_OPERATION_APPLY_EDIT,
    };

    lsp_client_apply_edit_async (
        server->peer_client,
        edit,
        "Apply generated edit",
        client_operation_ready,
        &operation);
    wait_for_completion (&operation.completed, &operation.error);
    g_assert_nonnull (operation.apply_result);
    g_assert_true (lsp_apply_workspace_edit_result_get_applied (
        operation.apply_result));
    lsp_apply_workspace_edit_result_unref (operation.apply_result);
  }
  g_assert_cmpstr (
      editor->applied_edit_label,
      ==,
      "Apply generated edit");

  /* Event order also catches handlers that finish late or are skipped. */
  g_assert_cmpuint (
      server->n_events,
      ==,
      G_N_ELEMENTS (expected_server_events));
  for (guint i = 0; i < G_N_ELEMENTS (expected_server_events); i++)
    g_assert_cmpstr (
        server->events[i],
        ==,
        expected_server_events[i]);

  g_assert_cmpuint (
      editor->n_events,
      ==,
      G_N_ELEMENTS (expected_editor_events));
  for (guint i = 0; i < G_N_ELEMENTS (expected_editor_events); i++)
    g_assert_cmpstr (
        editor->events[i],
        ==,
        expected_editor_events[i]);

  lsp_message_action_item_destroy (&actions[0]);
  lsp_message_action_item_destroy (&actions[1]);
}

int
main (int argc, char *argv[])
{
  g_test_init (&argc, &argv, NULL);
  g_test_add_func (
      "/c/editor/server-peer",
      test_server_and_editor);
  return g_test_run ();
}
