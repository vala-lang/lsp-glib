using Lsp;

/*
 * Shared protocol-test server. The async overrides record the values decoded
 * by Lsp.Server after each request or notification crosses JSON-RPC.
 */

private class TestServer : Lsp.Server {
    private string[] events = {};

    public Lsp.Client? peer_client { get; private set; }

    public string? initialize_locale { get; private set; }
    public string? initialize_root_uri { get; private set; }
    public uint initialize_workspace_count { get; private set; }

    public string? opened_uri { get; private set; }
    public LanguageId opened_language_id { get; private set; }
    public int64 opened_version { get; private set; }
    public string? opened_text { get; private set; }

    public string? changed_uri { get; private set; }
    public int64? changed_version;
    public uint changed_content_count { get; private set; }
    public string? changed_text { get; private set; }

    public string? saved_uri { get; private set; }
    public string? saved_text { get; private set; }

    public string? closed_uri { get; private set; }

    public TestServer (MainLoop loop) {
        base (loop);
    }

    public int event_count {
        get {
            return events.length;
        }
    }

    public unowned string event_at (int index) {
        return events[index];
    }

    private void record (string event) {
        events += event;
        debug ("recorded protocol test event: %s", event);
    }

    protected override async InitializeResult initialize_async (
        Lsp.Client client,
        InitializeParams init_params
    ) throws Error {
        peer_client = client;
        initialize_locale = init_params.locale;
        initialize_root_uri = init_params.root_uri?.to_string ();
        initialize_workspace_count =
            init_params.workspaces != null
                ? (uint) init_params.workspaces.length
                : 0;
        record ("initialize");
        record ("initialize-finish");
        return new InitializeResult (new ServerCaps ());
    }

    protected override async void initialized_async (
        Lsp.Client client
    ) throws Error {
        peer_client = client;
        record ("initialized");
        record ("initialized-finish");
    }

    protected override async void text_document_did_open_async (
        Lsp.Client client,
        TextDocumentItem text_document
    ) throws Error {
        opened_uri = text_document.uri.to_string ();
        opened_language_id = text_document.language_id;
        opened_version = text_document.version;
        opened_text = text_document.text;
        record ("did-open");
        record ("did-open-finish");
    }

    protected override async void text_document_did_change_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document,
        (unowned TextDocumentContentChangeEvent)[] content_changes
    ) throws Error {
        changed_uri = text_document.uri.to_string ();
        changed_version = text_document.version;
        changed_content_count = content_changes.length;
        if (content_changes.length > 0)
            changed_text = content_changes[0].text;
        record ("did-change");
        record ("did-change-finish");
    }

    protected override async void text_document_did_save_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document,
        string? text
    ) throws Error {
        saved_uri = text_document.uri.to_string ();
        saved_text = text;
        record ("did-save");
        record ("did-save-finish");
    }

    protected override async void text_document_did_close_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document
    ) throws Error {
        closed_uri = text_document.uri.to_string ();
        record ("did-close");
        record ("did-close-finish");
    }

    protected override async void shutdown_async (
        Lsp.Client client
    ) throws Error {
        record ("shutdown");
        record ("shutdown-finish");
    }

    public override void exit () {
        record ("exit");
    }
}
