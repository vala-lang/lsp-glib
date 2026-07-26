using Lsp;

/*
 * Editor test double for server-to-client protocol methods. Signals cover
 * notifications; async overrides cover requests that require a response.
 */
private class TestEditor : Lsp.Editor {
    private string[] events = {};

    public MessageType shown_type;
    public string? shown_message;
    public MessageType logged_type;
    public string? logged_message;
    public string? trace_message;
    public string? trace_verbose;

    public string? diagnostic_uri;
    public int64? diagnostic_version;
    public int diagnostic_count;
    public string? diagnostic_message;

    public MessageType prompt_type;
    public string? prompt_message;
    public int prompt_action_count;
    public string? prompt_first_action;

    public string? shown_document_uri;
    public bool shown_document_external;
    public bool shown_document_take_focus;
    public Range? shown_document_selection;

    public string? applied_edit_label;

    public TestEditor () {
        show_message.connect ((type, message) => {
            shown_type = type;
            shown_message = message;
            record ("show-message");
        });
        log_message.connect ((type, message) => {
            logged_type = type;
            logged_message = message;
            record ("log-message");
        });
        log_trace.connect ((message, verbose) => {
            trace_message = message;
            trace_verbose = verbose;
            record ("log-trace");
        });
        publish_diagnostics.connect ((uri, version, diagnostics) => {
            diagnostic_uri = uri.to_string ();
            diagnostic_version = version;
            diagnostic_count = diagnostics.length;
            if (diagnostics.length > 0)
                diagnostic_message = diagnostics[0].message;
            record ("publish-diagnostics");
        });
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
        debug ("recorded Editor protocol test event: %s", event);
    }

    protected override async MessageActionItem? show_message_request_async (
        MessageType type,
        string message,
        (unowned MessageActionItem)[] actions
    ) throws Error {
        prompt_type = type;
        prompt_message = message;
        prompt_action_count = actions.length;
        if (actions.length > 0)
            prompt_first_action = actions[0].title;
        record ("show-message-request");

        if (actions.length == 0)
            return null;
        return actions[0];
    }

    protected override async bool show_document_async (
        Uri uri,
        bool external,
        bool take_focus,
        Range? selection
    ) throws Error {
        shown_document_uri = uri.to_string ();
        shown_document_external = external;
        shown_document_take_focus = take_focus;
        shown_document_selection = selection;
        record ("show-document");
        return true;
    }

    protected override async ApplyWorkspaceEditResult
    apply_workspace_edit_async (
        WorkspaceEdit edit,
        string? label = null
    ) throws Error {
        applied_edit_label = label;
        record ("apply-edit");
        return new ApplyWorkspaceEditResult (true);
    }
}
