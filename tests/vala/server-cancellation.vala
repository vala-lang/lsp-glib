using Lsp;

/*
 * Verify that cancelling a request while its handler is suspended produces a
 * RequestCancelled response. The handler deliberately returns normally after
 * cancellation so Lsp.Server's final reply check also remains covered.
 */

private class CancellationServer : Lsp.Server {
    public signal void request_waiting ();

    public bool handler_called { get; private set; }

    public CancellationServer (MainLoop loop) {
        base (loop);
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
        request_waiting ();
        yield wait_until_cancelled (client.cancellable);
        // Returning normally after cancellation must not let a stale success
        // response escape. Lsp.Server checks again before replying.
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
        assert (e.code == ProtocolError.REQUEST_CANCELLED);
    }

    try {
        yield client.close_async (null);
    } catch (Error e) {
        error ("failed to close JSON-RPC client: %s", e.message);
    }
    loop.quit ();
}

private void run_cancellation_case () {
    IOStream server_connection;
    IOStream client_connection;
    create_test_stream_pair (out server_connection, out client_connection);

    var loop = new MainLoop ();
    var server = new CancellationServer (loop);
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
    assert (server.handler_called);
}

private int main (string[] args) {
    run_cancellation_case ();
    return 0;
}
