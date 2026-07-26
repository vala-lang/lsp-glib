#include "test-server.h"

/*
 * TestServer records the arguments delivered to each LSP vfunc. Its tasks
 * complete from idle callbacks so the tests cross a real async boundary.
 */

G_DEFINE_TYPE (TestServer, test_server, LSP_TYPE_SERVER)

static void
record_event (TestServer *self,
              const gchar *event)
{
  g_assert_cmpuint (self->n_events, <, G_N_ELEMENTS (self->events));
  self->events[self->n_events++] = event;
}

static gboolean
complete_boolean_task (gpointer data)
{
  GTask *task = data;

  g_task_return_boolean (task, TRUE);
  g_object_unref (task);
  return G_SOURCE_REMOVE;
}

static gboolean
complete_initialize_task (gpointer data)
{
  GTask *task = data;
  LspInitializeResult *result = g_task_get_task_data (task);

  g_task_return_pointer (
      task,
      lsp_initialize_result_ref (result),
      (GDestroyNotify) lsp_initialize_result_unref);
  g_object_unref (task);
  return G_SOURCE_REMOVE;
}

static void
start_boolean_task (LspServer *self,
                    GAsyncReadyCallback callback,
                    gpointer user_data)
{
  GTask *task = g_task_new (self, NULL, callback, user_data);

  g_idle_add (complete_boolean_task, task);
}

static void
test_server_initialize_async (LspServer *server,
                              LspClient *client,
                              LspInitializeParams *params,
                              GAsyncReadyCallback callback,
                              gpointer user_data)
{
  TestServer *self = (TestServer *) server;
  gint workspaces_length;
  g_autoptr (LspServerCaps) capabilities = lsp_server_caps_new ();
  GTask *task;

  g_assert_true (LSP_IS_CLIENT (client));
  g_set_object (&self->peer_client, client);
  g_free (self->initialize_locale);
  self->initialize_locale = g_strdup (
      lsp_initialize_params_get_locale (params));

  if (lsp_initialize_params_get_root_uri (params) != NULL)
    {
      g_free (self->initialize_root_uri);
      self->initialize_root_uri = g_uri_to_string (
          lsp_initialize_params_get_root_uri (params));
    }

  (void) lsp_initialize_params_get_workspaces (
      params,
      &workspaces_length);
  self->initialize_workspace_count = workspaces_length;
  record_event (self, "initialize");

  task = g_task_new (server, NULL, callback, user_data);
  g_task_set_task_data (
      task,
      lsp_initialize_result_new (capabilities),
      (GDestroyNotify) lsp_initialize_result_unref);
  g_idle_add (complete_initialize_task, task);
}

static LspInitializeResult *
test_server_initialize_finish (LspServer *server,
                               GAsyncResult *result,
                               GError **error)
{
  record_event ((TestServer *) server, "initialize-finish");
  return g_task_propagate_pointer (G_TASK (result), error);
}

static void
test_server_initialized_async (LspServer *server,
                               LspClient *client,
                               GAsyncReadyCallback callback,
                               gpointer user_data)
{
  TestServer *self = (TestServer *) server;

  g_assert_true (LSP_IS_CLIENT (client));
  g_set_object (&self->peer_client, client);
  record_event (self, "initialized");
  start_boolean_task (server, callback, user_data);
}

static void
test_server_initialized_finish (LspServer *server,
                                GAsyncResult *result,
                                GError **error)
{
  record_event ((TestServer *) server, "initialized-finish");
  g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_server_did_open_async (LspServer *server,
                            LspClient *client,
                            LspTextDocumentItem *document,
                            GAsyncReadyCallback callback,
                            gpointer user_data)
{
  TestServer *self = (TestServer *) server;

  g_assert_true (LSP_IS_CLIENT (client));
  g_free (self->opened_uri);
  g_free (self->opened_text);
  self->opened_uri = g_uri_to_string (
      lsp_text_document_item_get_uri (document));
  self->opened_language_id =
      lsp_text_document_item_get_language_id (document);
  self->opened_version =
      lsp_text_document_item_get_version (document);
  self->opened_text = g_strdup (
      lsp_text_document_item_get_text (document));
  record_event (self, "did-open");
  start_boolean_task (server, callback, user_data);
}

static void
test_server_did_open_finish (LspServer *server,
                             GAsyncResult *result,
                             GError **error)
{
  record_event ((TestServer *) server, "did-open-finish");
  g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_server_did_change_async (
    LspServer *server,
    LspClient *client,
    LspTextDocumentIdentifier *document,
    LspTextDocumentContentChangeEvent *content_changes,
    gint content_changes_length,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TestServer *self = (TestServer *) server;
  gint64 *version =
      lsp_text_document_identifier_get_version (document);

  g_assert_true (LSP_IS_CLIENT (client));
  g_free (self->changed_uri);
  g_free (self->changed_text);
  self->changed_uri = g_uri_to_string (
      lsp_text_document_identifier_get_uri (document));
  self->changed_version = version != NULL ? *version : -1;
  self->changed_content_count = content_changes_length;
  if (content_changes_length > 0)
    self->changed_text = g_strdup (
        lsp_text_document_content_change_event_get_text (
            &content_changes[0]));
  record_event (self, "did-change");
  start_boolean_task (server, callback, user_data);
}

static void
test_server_did_change_finish (LspServer *server,
                               GAsyncResult *result,
                               GError **error)
{
  record_event ((TestServer *) server, "did-change-finish");
  g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_server_did_save_async (LspServer *server,
                            LspClient *client,
                            LspTextDocumentIdentifier *document,
                            const gchar *text,
                            GAsyncReadyCallback callback,
                            gpointer user_data)
{
  TestServer *self = (TestServer *) server;

  g_assert_true (LSP_IS_CLIENT (client));
  g_free (self->saved_uri);
  g_free (self->saved_text);
  self->saved_uri = g_uri_to_string (
      lsp_text_document_identifier_get_uri (document));
  self->saved_text = g_strdup (text);
  record_event (self, "did-save");
  start_boolean_task (server, callback, user_data);
}

static void
test_server_did_save_finish (LspServer *server,
                             GAsyncResult *result,
                             GError **error)
{
  record_event ((TestServer *) server, "did-save-finish");
  g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_server_did_close_async (LspServer *server,
                             LspClient *client,
                             LspTextDocumentIdentifier *document,
                             GAsyncReadyCallback callback,
                             gpointer user_data)
{
  TestServer *self = (TestServer *) server;

  g_assert_true (LSP_IS_CLIENT (client));
  g_free (self->closed_uri);
  self->closed_uri = g_uri_to_string (
      lsp_text_document_identifier_get_uri (document));
  record_event (self, "did-close");
  start_boolean_task (server, callback, user_data);
}

static void
test_server_did_close_finish (LspServer *server,
                              GAsyncResult *result,
                              GError **error)
{
  record_event ((TestServer *) server, "did-close-finish");
  g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_server_shutdown_async (LspServer *server,
                            LspClient *client,
                            GAsyncReadyCallback callback,
                            gpointer user_data)
{
  g_assert_true (LSP_IS_CLIENT (client));
  record_event ((TestServer *) server, "shutdown");
  start_boolean_task (server, callback, user_data);
}

static void
test_server_shutdown_finish (LspServer *server,
                             GAsyncResult *result,
                             GError **error)
{
  record_event ((TestServer *) server, "shutdown-finish");
  g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_server_exit (LspServer *server)
{
  record_event ((TestServer *) server, "exit");
}

static void
test_server_finalize (GObject *object)
{
  TestServer *self = (TestServer *) object;

  g_clear_object (&self->peer_client);
  g_free (self->initialize_locale);
  g_free (self->initialize_root_uri);
  g_free (self->opened_uri);
  g_free (self->opened_text);
  g_free (self->changed_uri);
  g_free (self->changed_text);
  g_free (self->saved_uri);
  g_free (self->saved_text);
  g_free (self->closed_uri);

  G_OBJECT_CLASS (test_server_parent_class)->finalize (object);
}

static void
test_server_class_init (TestServerClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  LspServerClass *server_class = LSP_SERVER_CLASS (klass);

  object_class->finalize = test_server_finalize;
  server_class->initialize_async = test_server_initialize_async;
  server_class->initialize_finish = test_server_initialize_finish;
  server_class->initialized_async = test_server_initialized_async;
  server_class->initialized_finish = test_server_initialized_finish;
  server_class->text_document_did_open_async =
      test_server_did_open_async;
  server_class->text_document_did_open_finish =
      test_server_did_open_finish;
  server_class->text_document_did_change_async =
      test_server_did_change_async;
  server_class->text_document_did_change_finish =
      test_server_did_change_finish;
  server_class->text_document_did_save_async =
      test_server_did_save_async;
  server_class->text_document_did_save_finish =
      test_server_did_save_finish;
  server_class->text_document_did_close_async =
      test_server_did_close_async;
  server_class->text_document_did_close_finish =
      test_server_did_close_finish;
  server_class->shutdown_async = test_server_shutdown_async;
  server_class->shutdown_finish = test_server_shutdown_finish;
  server_class->exit = test_server_exit;
}

static void
test_server_init (TestServer *self)
{
  (void) self;
}

TestServer *
test_server_new (GMainLoop *loop)
{
  return (TestServer *) lsp_server_construct (
      test_server_get_type (),
      loop);
}
