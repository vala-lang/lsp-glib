#include "test-stream.h"

/*
 * A small in-memory duplex transport for the Server and Editor tests. Each end
 * reads what the other writes, while the condition variable preserves normal
 * blocking and cancellation behavior without platform-specific socket APIs.
 */

typedef struct
{
  GObject parent_instance;
  GMutex mutex;
  GCond data_available;
  GByteArray *pending;
  gboolean closed;
} TestPipe;

typedef GObjectClass TestPipeClass;

G_DEFINE_TYPE (TestPipe, test_pipe, G_TYPE_OBJECT)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (TestPipe, g_object_unref)

static void
test_pipe_finalize (GObject *object)
{
  TestPipe *self = (TestPipe *) object;

  g_byte_array_unref (self->pending);
  g_cond_clear (&self->data_available);
  g_mutex_clear (&self->mutex);

  G_OBJECT_CLASS (test_pipe_parent_class)->finalize (object);
}

static void
test_pipe_class_init (TestPipeClass *klass)
{
  G_OBJECT_CLASS (klass)->finalize = test_pipe_finalize;
}

static void
test_pipe_init (TestPipe *self)
{
  g_mutex_init (&self->mutex);
  g_cond_init (&self->data_available);
  self->pending = g_byte_array_new ();
}

static TestPipe *
test_pipe_new (void)
{
  return g_object_new (test_pipe_get_type (), NULL);
}

static void
wake_cancelled_read (GCancellable *cancellable,
                     gpointer data)
{
  TestPipe *self = data;

  (void) cancellable;
  g_mutex_lock (&self->mutex);
  g_cond_broadcast (&self->data_available);
  g_mutex_unlock (&self->mutex);
}

static gssize
test_pipe_read (TestPipe *self,
                void *buffer,
                gsize count,
                GCancellable *cancellable,
                GError **error)
{
  gulong cancelled_id = 0;
  gsize bytes_read;

  if (cancellable != NULL)
    cancelled_id = g_cancellable_connect (
        cancellable,
        G_CALLBACK (wake_cancelled_read),
        self,
        NULL);

  g_mutex_lock (&self->mutex);
  while (self->pending->len == 0 &&
         !self->closed &&
         (cancellable == NULL ||
          !g_cancellable_is_cancelled (cancellable)))
    g_cond_wait (&self->data_available, &self->mutex);

  if (cancellable != NULL &&
      g_cancellable_is_cancelled (cancellable))
    {
      g_mutex_unlock (&self->mutex);
      g_cancellable_disconnect (cancellable, cancelled_id);
      g_cancellable_set_error_if_cancelled (cancellable, error);
      return -1;
    }

  bytes_read = MIN (self->pending->len, count);
  if (bytes_read > 0)
    {
      memcpy (buffer, self->pending->data, bytes_read);
      g_byte_array_remove_range (self->pending, 0, bytes_read);
    }
  g_mutex_unlock (&self->mutex);

  if (cancelled_id != 0)
    g_cancellable_disconnect (cancellable, cancelled_id);

  return bytes_read;
}

static gssize
test_pipe_write (TestPipe *self,
                 const void *buffer,
                 gsize count,
                 GCancellable *cancellable,
                 GError **error)
{
  if (cancellable != NULL &&
      g_cancellable_set_error_if_cancelled (cancellable, error))
    return -1;

  g_mutex_lock (&self->mutex);
  if (self->closed)
    {
      g_mutex_unlock (&self->mutex);
      g_set_error_literal (
          error,
          G_IO_ERROR,
          G_IO_ERROR_CLOSED,
          "test pipe is closed");
      return -1;
    }

  g_byte_array_append (self->pending, buffer, count);
  g_cond_signal (&self->data_available);
  g_mutex_unlock (&self->mutex);

  return count;
}

static void
test_pipe_close (TestPipe *self)
{
  g_mutex_lock (&self->mutex);
  self->closed = TRUE;
  g_cond_broadcast (&self->data_available);
  g_mutex_unlock (&self->mutex);
}

typedef struct
{
  GInputStream parent_instance;
  TestPipe *pipe;
} TestPipeInputStream;

typedef GInputStreamClass TestPipeInputStreamClass;

G_DEFINE_TYPE (
    TestPipeInputStream,
    test_pipe_input_stream,
    G_TYPE_INPUT_STREAM)

static gssize
test_pipe_input_stream_read (
    GInputStream *stream,
    void *buffer,
    gsize count,
    GCancellable *cancellable,
    GError **error)
{
  TestPipeInputStream *self = (TestPipeInputStream *) stream;

  return test_pipe_read (
      self->pipe,
      buffer,
      count,
      cancellable,
      error);
}

static gboolean
test_pipe_input_stream_close (
    GInputStream *stream,
    GCancellable *cancellable,
    GError **error)
{
  TestPipeInputStream *self = (TestPipeInputStream *) stream;

  (void) cancellable;
  (void) error;
  test_pipe_close (self->pipe);
  return TRUE;
}

static void
test_pipe_input_stream_finalize (GObject *object)
{
  TestPipeInputStream *self = (TestPipeInputStream *) object;

  g_clear_object (&self->pipe);
  G_OBJECT_CLASS (test_pipe_input_stream_parent_class)->finalize (object);
}

static void
test_pipe_input_stream_class_init (TestPipeInputStreamClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  GInputStreamClass *stream_class = G_INPUT_STREAM_CLASS (klass);

  object_class->finalize = test_pipe_input_stream_finalize;
  stream_class->read_fn = test_pipe_input_stream_read;
  stream_class->close_fn = test_pipe_input_stream_close;
}

static void
test_pipe_input_stream_init (TestPipeInputStream *self)
{
  (void) self;
}

static GInputStream *
test_pipe_input_stream_new (TestPipe *pipe)
{
  TestPipeInputStream *self = g_object_new (
      test_pipe_input_stream_get_type (),
      NULL);

  self->pipe = g_object_ref (pipe);
  return G_INPUT_STREAM (self);
}

typedef struct
{
  GOutputStream parent_instance;
  TestPipe *pipe;
} TestPipeOutputStream;

typedef GOutputStreamClass TestPipeOutputStreamClass;

G_DEFINE_TYPE (
    TestPipeOutputStream,
    test_pipe_output_stream,
    G_TYPE_OUTPUT_STREAM)

static gssize
test_pipe_output_stream_write (
    GOutputStream *stream,
    const void *buffer,
    gsize count,
    GCancellable *cancellable,
    GError **error)
{
  TestPipeOutputStream *self = (TestPipeOutputStream *) stream;

  return test_pipe_write (
      self->pipe,
      buffer,
      count,
      cancellable,
      error);
}

static gboolean
test_pipe_output_stream_close (
    GOutputStream *stream,
    GCancellable *cancellable,
    GError **error)
{
  TestPipeOutputStream *self = (TestPipeOutputStream *) stream;

  (void) cancellable;
  (void) error;
  test_pipe_close (self->pipe);
  return TRUE;
}

static void
test_pipe_output_stream_finalize (GObject *object)
{
  TestPipeOutputStream *self = (TestPipeOutputStream *) object;

  g_clear_object (&self->pipe);
  G_OBJECT_CLASS (test_pipe_output_stream_parent_class)->finalize (object);
}

static void
test_pipe_output_stream_class_init (TestPipeOutputStreamClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  GOutputStreamClass *stream_class = G_OUTPUT_STREAM_CLASS (klass);

  object_class->finalize = test_pipe_output_stream_finalize;
  stream_class->write_fn = test_pipe_output_stream_write;
  stream_class->close_fn = test_pipe_output_stream_close;
}

static void
test_pipe_output_stream_init (TestPipeOutputStream *self)
{
  (void) self;
}

static GOutputStream *
test_pipe_output_stream_new (TestPipe *pipe)
{
  TestPipeOutputStream *self = g_object_new (
      test_pipe_output_stream_get_type (),
      NULL);

  self->pipe = g_object_ref (pipe);
  return G_OUTPUT_STREAM (self);
}

static GIOStream *
create_test_io_stream (TestPipe *input_pipe,
                       TestPipe *output_pipe)
{
  g_autoptr (GInputStream) input =
      test_pipe_input_stream_new (input_pipe);
  g_autoptr (GOutputStream) output =
      test_pipe_output_stream_new (output_pipe);

  return g_simple_io_stream_new (input, output);
}

void
create_test_stream_pair (GIOStream **server_stream,
                         GIOStream **client_stream)
{
  g_autoptr (TestPipe) client_to_server = test_pipe_new ();
  g_autoptr (TestPipe) server_to_client = test_pipe_new ();

  g_return_if_fail (server_stream != NULL);
  g_return_if_fail (client_stream != NULL);

  *server_stream = create_test_io_stream (
      client_to_server,
      server_to_client);
  *client_stream = create_test_io_stream (
      server_to_client,
      client_to_server);
}
