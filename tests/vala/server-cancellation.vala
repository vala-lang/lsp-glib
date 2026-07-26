using Lsp;

/*
 * Exercise both points where a server implementation can cooperatively
 * observe cancellation: while waiting for its context to settle, and while
 * executing the request handler. A fresh Jsonrpc.Client is used for each case,
 * so the request being cancelled has the initial JSON-RPC id of 1.
 */

private class CancellationServer : Lsp.Server {
    public signal void request_waiting ();

    bool wait_in_context_hook;
    Cancellable? context_cancellable;

    public bool handler_called { get; private set; }

    public CancellationServer (MainLoop loop, bool wait_in_context_hook) {
        base (loop);
        this.wait_in_context_hook = wait_in_context_hook;
    }

    private async void wait_until_cancelled (Cancellable cancellable) {
        if (cancellable.is_cancelled ())
            return;

        ulong handler_id = cancellable.cancelled.connect (() => {
            Idle.add (wait_until_cancelled.callback);
        });
        yield;
        cancellable.disconnect (handler_id);
    }

    protected override async void wait_for_context_update_async (
        Cancellable cancellable
    ) throws Error {
        context_cancellable = cancellable;
        if (!wait_in_context_hook)
            return;

        request_waiting ();
        yield wait_until_cancelled (cancellable);
        cancellable.set_error_if_cancelled ();
    }

    protected override async InitializeResult initialize_async (
        Lsp.Client client,
        InitializeParams init_params
    ) throws Error {
        return new InitializeResult (new ServerCaps ());
    }

    protected override async void text_document_did_open_async (
        Lsp.Client client,
        TextDocumentItem text_document
    ) throws Error {
    }

    protected override async void text_document_did_change_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document,
        (unowned TextDocumentContentChangeEvent)[] content_changes
    ) throws Error {
    }

    protected override async void text_document_did_close_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document
    ) throws Error {
    }

    protected override async SymbolInformation[]? workspace_symbol_async (
        Lsp.Client client,
        string query
    ) throws Error {
        handler_called = true;
        assert (client.cancellable == context_cancellable);

        request_waiting ();
        yield wait_until_cancelled (client.cancellable);
        client.cancellable.set_error_if_cancelled ();
        return null;
    }

    protected override async void shutdown_async (Lsp.Client client) throws Error {
    }
}

private Variant workspace_symbol_params () {
    var parameters = new VariantDict ();
    parameters.insert_value ("query", new Variant.string ("cancel me"));
    return parameters.end ();
}

private async void run_request (Jsonrpc.Client client, MainLoop loop) {
    try {
        Variant? result;
        yield client.call_async ("workspace/symbol", workspace_symbol_params (), null, out result);
        assert_not_reached ();
    } catch (Error e) {
        assert (e.domain == Jsonrpc.Client.error_quark ());
        assert (e.code == ErrorCode.REQUEST_CANCELLED);
    }

    try {
        yield client.close_async (null);
    } catch (Error e) {
        error ("failed to close JSON-RPC client: %s", e.message);
    }
    loop.quit ();
}

private void run_cancellation_case (bool wait_in_context_hook) {
    IOStream server_connection;
    IOStream client_connection;
    create_test_stream_pair (out server_connection, out client_connection);

    var loop = new MainLoop ();
    var server = new CancellationServer (loop, wait_in_context_hook);
    var client = new Jsonrpc.Client (client_connection);

    server.accept_io_stream (server_connection);
    server.request_waiting.connect (() => {
        var parameters = new VariantDict ();
        parameters.insert_value ("id", new Variant.int64 (1));
        AsyncReadyCallback on_cancelled = (object, result) => {
            try {
                client.send_notification_async.end (result);
            } catch (Error e) {
                error ("failed to cancel request: %s", e.message);
            }
        };
        client.send_notification_async.begin (
            "$/cancelRequest",
            parameters.end (),
            null,
            on_cancelled);
    });

    run_request.begin (client, loop);

    bool timed_out = false;
    uint timeout_id = Timeout.add_seconds (5, () => {
        timed_out = true;
        loop.quit ();
        return Source.REMOVE;
    });

    loop.run ();
    if (!timed_out)
        Source.remove (timeout_id);

    assert (!timed_out);
    assert (server.handler_called != wait_in_context_hook);
}

private int main (string[] args) {
    run_cancellation_case (true);
    run_cancellation_case (false);
    return 0;
}
