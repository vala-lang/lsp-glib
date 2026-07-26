#include "test-editor.h"

/*
 * TestEditor records client-facing notifications and provides predictable
 * replies to requests. Idle completion keeps the mock behavior asynchronous.
 */

G_DEFINE_TYPE (TestEditor, test_editor, LSP_TYPE_EDITOR)

typedef struct
{
  GTask *task;
  gpointer result;
  GDestroyNotify destroy;
} PointerCompletion;

static void
record_event (TestEditor *self,
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
complete_pointer_task (gpointer data)
{
  PointerCompletion *completion = data;

  g_task_return_pointer (
      completion->task,
      completion->result,
      completion->destroy);
  g_object_unref (completion->task);
  g_free (completion);
  return G_SOURCE_REMOVE;
}

static void
start_boolean_task (TestEditor *self,
                    GAsyncReadyCallback callback,
                    gpointer user_data)
{
  GTask *task = g_task_new (self, NULL, callback, user_data);

  g_idle_add (complete_boolean_task, task);
}

static void
start_pointer_task (TestEditor *self,
                    gpointer result,
                    GDestroyNotify destroy,
                    GAsyncReadyCallback callback,
                    gpointer user_data)
{
  PointerCompletion *completion = g_new0 (PointerCompletion, 1);

  completion->task = g_task_new (self, NULL, callback, user_data);
  completion->result = result;
  completion->destroy = destroy;
  g_idle_add (complete_pointer_task, completion);
}

static void
test_editor_show_message_request_async (
    LspEditor *editor,
    LspMessageType type,
    const gchar *message,
    LspMessageActionItem *actions,
    gint actions_length,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;
  LspMessageActionItem *selected = NULL;

  self->prompt_type = type;
  g_free (self->prompt_message);
  g_free (self->prompt_first_action);
  self->prompt_message = g_strdup (message);
  self->prompt_action_count = actions_length;
  self->prompt_first_action = actions_length > 0
      ? g_strdup (lsp_message_action_item_get_title (&actions[0]))
      : NULL;
  if (actions_length > 0)
    selected = lsp_message_action_item_dup (&actions[0]);
  record_event (self, "show-message-request");

  start_pointer_task (
      self,
      selected,
      (GDestroyNotify) lsp_message_action_item_free,
      callback,
      user_data);
}

static LspMessageActionItem *
test_editor_show_message_request_finish (
    LspEditor *editor,
    GAsyncResult *result,
    GError **error)
{
  (void) editor;
  return g_task_propagate_pointer (G_TASK (result), error);
}

static void
test_editor_show_document_async (
    LspEditor *editor,
    GUri *uri,
    gboolean external,
    gboolean take_focus,
    LspRange *selection,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;

  g_free (self->shown_document_uri);
  self->shown_document_uri = g_uri_to_string (uri);
  self->shown_document_external = external;
  self->shown_document_take_focus = take_focus;
  self->has_shown_document_selection = selection != NULL;
  if (selection != NULL)
    self->shown_document_selection = *selection;
  record_event (self, "show-document");
  start_boolean_task (self, callback, user_data);
}

static gboolean
test_editor_show_document_finish (LspEditor *editor,
                                  GAsyncResult *result,
                                  GError **error)
{
  (void) editor;
  return g_task_propagate_boolean (G_TASK (result), error);
}

static void
test_editor_apply_workspace_edit_async (
    LspEditor *editor,
    LspWorkspaceEdit *edit,
    const gchar *label,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;

  g_assert_nonnull (edit);
  g_free (self->applied_edit_label);
  self->applied_edit_label = g_strdup (label);
  record_event (self, "apply-edit");
  start_pointer_task (
      self,
      lsp_apply_workspace_edit_result_new (TRUE, NULL),
      (GDestroyNotify) lsp_apply_workspace_edit_result_unref,
      callback,
      user_data);
}

static LspApplyWorkspaceEditResult *
test_editor_apply_workspace_edit_finish (
    LspEditor *editor,
    GAsyncResult *result,
    GError **error)
{
  (void) editor;
  return g_task_propagate_pointer (G_TASK (result), error);
}

static void
show_message_cb (LspEditor *editor,
                 LspMessageType type,
                 const gchar *message,
                 gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;

  (void) user_data;
  self->shown_type = type;
  g_free (self->shown_message);
  self->shown_message = g_strdup (message);
  record_event (self, "show-message");
}

static void
log_message_cb (LspEditor *editor,
                LspMessageType type,
                const gchar *message,
                gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;

  (void) user_data;
  self->logged_type = type;
  g_free (self->logged_message);
  self->logged_message = g_strdup (message);
  record_event (self, "log-message");
}

static void
log_trace_cb (LspEditor *editor,
              const gchar *message,
              const gchar *verbose,
              gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;

  (void) user_data;
  g_free (self->trace_message);
  g_free (self->trace_verbose);
  self->trace_message = g_strdup (message);
  self->trace_verbose = g_strdup (verbose);
  record_event (self, "log-trace");
}

static void
publish_diagnostics_cb (LspEditor *editor,
                        GUri *uri,
                        gint64 *version,
                        LspDiagnostic **diagnostics,
                        gint diagnostics_length,
                        gpointer user_data)
{
  TestEditor *self = (TestEditor *) editor;

  (void) user_data;
  g_free (self->diagnostic_uri);
  g_free (self->diagnostic_message);
  self->diagnostic_uri = g_uri_to_string (uri);
  self->has_diagnostic_version = version != NULL;
  self->diagnostic_version = version != NULL ? *version : -1;
  self->diagnostic_count = diagnostics_length;
  self->diagnostic_message = diagnostics_length > 0
      ? g_strdup (lsp_diagnostic_get_message (diagnostics[0]))
      : NULL;
  record_event (self, "publish-diagnostics");
}

static void
test_editor_finalize (GObject *object)
{
  TestEditor *self = (TestEditor *) object;

  g_free (self->shown_message);
  g_free (self->logged_message);
  g_free (self->trace_message);
  g_free (self->trace_verbose);
  g_free (self->diagnostic_uri);
  g_free (self->diagnostic_message);
  g_free (self->prompt_message);
  g_free (self->prompt_first_action);
  g_free (self->shown_document_uri);
  g_free (self->applied_edit_label);

  G_OBJECT_CLASS (test_editor_parent_class)->finalize (object);
}

static void
test_editor_class_init (TestEditorClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  LspEditorClass *editor_class = LSP_EDITOR_CLASS (klass);

  object_class->finalize = test_editor_finalize;
  editor_class->show_message_request_async =
      test_editor_show_message_request_async;
  editor_class->show_message_request_finish =
      test_editor_show_message_request_finish;
  editor_class->show_document_async =
      test_editor_show_document_async;
  editor_class->show_document_finish =
      test_editor_show_document_finish;
  editor_class->apply_workspace_edit_async =
      test_editor_apply_workspace_edit_async;
  editor_class->apply_workspace_edit_finish =
      test_editor_apply_workspace_edit_finish;
}

static void
test_editor_init (TestEditor *self)
{
  g_signal_connect (
      self,
      "show-message",
      G_CALLBACK (show_message_cb),
      NULL);
  g_signal_connect (
      self,
      "log-message",
      G_CALLBACK (log_message_cb),
      NULL);
  g_signal_connect (
      self,
      "log-trace",
      G_CALLBACK (log_trace_cb),
      NULL);
  g_signal_connect (
      self,
      "publish-diagnostics",
      G_CALLBACK (publish_diagnostics_cb),
      NULL);
}

TestEditor *
test_editor_new (void)
{
  return (TestEditor *) lsp_editor_construct (TEST_TYPE_EDITOR);
}
