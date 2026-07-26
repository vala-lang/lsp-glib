#include "lsp-glib.h"
#include "test-server.h"
#include "test-stream.h"

/*
 * Connect a real LspEditor to TestServer over framed JSON-RPC, then run the
 * normal server lifecycle. Assertions inspect values recorded by the vfuncs,
 * proving that requests were decoded before reaching the implementation.
 */

typedef enum
{
  EDITOR_OPERATION_INITIALIZE,
  EDITOR_OPERATION_INITIALIZED,
  EDITOR_OPERATION_OPEN,
  EDITOR_OPERATION_EDIT,
  EDITOR_OPERATION_SAVE,
  EDITOR_OPERATION_CLOSE,
  EDITOR_OPERATION_SHUTDOWN,
  EDITOR_OPERATION_EXIT,
} EditorOperationKind;

typedef struct
{
  EditorOperationKind kind;
  gboolean completed;
  GError *error;
} EditorOperation;

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
      lsp_editor_initialize_with_params_finish (
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

    case EDITOR_OPERATION_SAVE:
      lsp_editor_save_text_document_finish (
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

    case EDITOR_OPERATION_SHUTDOWN:
      lsp_editor_shutdown_finish (
          editor,
          result,
          &operation->error);
      break;

    case EDITOR_OPERATION_EXIT:
      lsp_editor_exit_finish (
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
wait_for_operation (EditorOperation *operation)
{
  gint64 deadline = g_get_monotonic_time () + (2 * G_TIME_SPAN_SECOND);

  while (!operation->completed &&
         g_get_monotonic_time () < deadline)
    {
      while (g_main_context_pending (NULL))
        g_main_context_iteration (NULL, FALSE);
      g_usleep (1000);
    }

  g_assert_true (operation->completed);
  g_assert_no_error (operation->error);
}

static void
wait_for_events (TestServer *server,
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
test_editor_drives_server (void)
{
  static const gchar *expected_events[] = {
    "initialize",
    "initialize-finish",
    "initialized",
    "initialized-finish",
    "did-open",
    "did-open-finish",
    "did-change",
    "did-change-finish",
    "did-save",
    "did-save-finish",
    "did-close",
    "did-close-finish",
    "shutdown",
    "shutdown-finish",
    "exit",
  };
  g_auto (LspTextDocumentContentChangeEvent) change = { 0 };
  g_autoptr (GError) error = NULL;
  g_autoptr (GMainLoop) loop = g_main_loop_new (NULL, FALSE);
  g_autoptr (TestServer) server = test_server_new (loop);
  g_autoptr (LspEditor) editor = lsp_editor_new ();
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
  g_autoptr (LspInitializeParams) init_params = NULL;
  EditorOperation operation = {
    .kind = EDITOR_OPERATION_INITIALIZE,
  };

  g_assert_no_error (error);
  workspace = lsp_workspace_folder_new (
      workspace_uri,
      "workspace");
  init_params = lsp_initialize_params_new_with_workspace_folders (
      workspace,
      NULL,
      0,
      &error);
  g_assert_no_error (error);
  lsp_initialize_params_set_locale (init_params, "en-US");

  /* Every call below crosses this in-memory JSON-RPC connection. */
  create_test_stream_pair (&server_stream, &editor_stream);
  jsonrpc_server_accept_io_stream (
      JSONRPC_SERVER (server),
      server_stream);
  jsonrpc_server_accept_io_stream (
      JSONRPC_SERVER (editor),
      editor_stream);

  lsp_editor_initialize_with_params_async (
      editor,
      init_params,
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 2);

  g_assert_nonnull (lsp_editor_get_init_result (editor));
  g_assert_cmpstr (server->initialize_locale, ==, "en-US");
  g_assert_cmpstr (
      server->initialize_root_uri,
      ==,
      "file:///workspace");
  g_assert_cmpuint (server->initialize_workspace_count, ==, 1);

  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_INITIALIZED,
  };
  lsp_editor_initialized_async (
      editor,
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 4);

  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_OPEN,
  };
  lsp_editor_open_text_document_async (
      editor,
      document_uri,
      LSP_LANGUAGE_ID_VALA,
      "class Before {}",
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 6);

  lsp_text_document_content_change_event_init (
      &change,
      NULL,
      "class After {}");
  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_EDIT,
  };
  lsp_editor_edit_text_document_async (
      editor,
      document_uri,
      2,
      &change,
      1,
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 8);

  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_SAVE,
  };
  lsp_editor_save_text_document_async (
      editor,
      document_uri,
      "class Saved {}",
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 10);

  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_CLOSE,
  };
  lsp_editor_close_text_document_async (
      editor,
      document_uri,
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 12);

  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_SHUTDOWN,
  };
  lsp_editor_shutdown_async (
      editor,
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 14);
  g_assert_true (lsp_editor_get_is_shutting_down (editor));

  operation = (EditorOperation) {
    .kind = EDITOR_OPERATION_EXIT,
  };
  lsp_editor_exit_async (
      editor,
      editor_operation_ready,
      &operation);
  wait_for_operation (&operation);
  wait_for_events (server, 15);
  g_assert_true (lsp_editor_get_exited (editor));

  /* Check the decoded payloads in addition to the lifecycle event order. */
  g_assert_cmpstr (
      server->opened_uri,
      ==,
      "file:///server-test.vala");
  g_assert_cmpint (
      server->opened_language_id,
      ==,
      LSP_LANGUAGE_ID_VALA);
  g_assert_cmpint (server->opened_version, ==, 1);
  g_assert_cmpstr (server->opened_text, ==, "class Before {}");
  g_assert_cmpstr (
      server->changed_uri,
      ==,
      "file:///server-test.vala");
  g_assert_cmpint (server->changed_version, ==, 2);
  g_assert_cmpuint (server->changed_content_count, ==, 1);
  g_assert_cmpstr (server->changed_text, ==, "class After {}");
  g_assert_cmpstr (
      server->saved_uri,
      ==,
      "file:///server-test.vala");
  g_assert_cmpstr (server->saved_text, ==, "class Saved {}");
  g_assert_cmpstr (
      server->closed_uri,
      ==,
      "file:///server-test.vala");

  g_assert_cmpuint (
      server->n_events,
      ==,
      G_N_ELEMENTS (expected_events));
  for (guint i = 0; i < G_N_ELEMENTS (expected_events); i++)
    g_assert_cmpstr (server->events[i], ==, expected_events[i]);
}

int
main (int argc, char *argv[])
{
  g_test_init (&argc, &argv, NULL);
  g_test_add_func (
      "/c/server/editor-peer",
      test_editor_drives_server);
  return g_test_run ();
}
