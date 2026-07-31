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

    protected override async DocumentSymbolResult? document_symbol_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document
    ) throws Error {
        var range = Range (Position (0, 0), Position (4, 1));
        var selection = Range (Position (0, 6), Position (0, 13));
        DocumentSymbol[] symbols = {
            new DocumentSymbol (
                "Example",
                SymbolKind.CLASS,
                range,
                selection)
        };
        return new DocumentSymbolResult.for_document_symbols (symbols);
    }

    protected override async PrepareRenameResult? prepare_rename_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document,
        Position position
    ) throws Error {
        return PrepareRenameResult.for_range (
            Range (Position (position.line, 2), Position (position.line, 9)),
            "example");
    }

    private TypeHierarchyItem hierarchy_item (
        string name,
        TextDocumentIdentifier text_document
    ) {
        var range = Range (Position (0, 0), Position (4, 1));
        return new TypeHierarchyItem (
            name,
            SymbolKind.CLASS,
            text_document.uri,
            range,
            Range (Position (0, 6), Position (0, 13)));
    }

    protected override async TypeHierarchyItem[]?
    prepare_type_hierarchy_async (
        Lsp.Client client,
        TextDocumentIdentifier text_document,
        Position position
    ) throws Error {
        return { hierarchy_item ("Example", text_document) };
    }

    protected override async TypeHierarchyItem[]?
    type_hierarchy_supertypes_async (
        Lsp.Client client,
        TypeHierarchyItem item
    ) throws Error {
        return {
                   new TypeHierarchyItem (
                       "Base",
                       SymbolKind.CLASS,
                       item.uri,
                       item.range,
                       item.selection_range)
        };
    }

    protected override async TypeHierarchyItem[]?
    type_hierarchy_subtypes_async (
        Lsp.Client client,
        TypeHierarchyItem item
    ) throws Error {
        return {
                   new TypeHierarchyItem (
                       "Derived",
                       SymbolKind.CLASS,
                       item.uri,
                       item.range,
                       item.selection_range)
        };
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
