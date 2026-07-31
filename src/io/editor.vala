/* client.vala
 *
 * Copyright 2021-2022 Princeton Ferro <princetonferro@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

/**
 * A JSON-RPC server implementing the client side of the Language Server
 * Protocol.
 *
 * This API is intended for GUIs, which is why incoming LSP notifications have
 * synchronous event handlers rather than virtual async methods.
 */
public class Lsp.Editor : Jsonrpc.Server {
    Jsonrpc.Client? client;

    /**
     * Whether we've exited the server.
     */
    public bool exited { get; private set; }

    /**
     * Whether a successful shutdown request has been sent.
     */
    public bool is_shutting_down { get; private set; }

    /**
     * The trace configuration, synchronized with the language server.
     */
    public TraceValue trace_value { get; private set; default = OFF; }

    public Cancellable cancellable { get; private set; }

    /**
     * The initialization info we got from the language server.
     */
    public InitializeResult? init_result { get; private set; }

    public HashTable<Uri, TextDocumentItem> text_documents { get; private set; }

    construct {
        this.cancellable = new Cancellable ();
        this.text_documents = new HashTable<Uri, TextDocumentItem> (uri_hash, uri_equal);
        this.handle_call.connect ((client, method, id, parameters) => {
            handle_call_async.begin (client, method, id, parameters);
            return !exited;
        });
    }

    public Editor () {
    }

    protected override void notification (Jsonrpc.Client client, string method,
        Variant parameters) {
        if (exited || init_result == null)
            return;

        try {
            switch (method) {
                case "window/logMessage":
                    var sm_type = expect_property (parameters, "type", VariantType.INT64,
                        "LogMessageParams");
                    string message = (string) expect_property (parameters, "message",
                        VariantType.STRING, "LogMessageParams");
                    log_message (MessageType.parse_int ((int) (int64) sm_type), message);
                    break;

                case "window/showMessage":
                    var sm_type = expect_property (parameters, "type", VariantType.INT64,
                        "ShowMessageParams");
                    string message = (string) expect_property (parameters, "message",
                        VariantType.STRING, "ShowMessageParams");
                    show_message (MessageType.parse_int ((int) (int64) sm_type), message);
                    break;

                case "textDocument/publishDiagnostics":
                    var pd_uri = expect_property (parameters, "uri", VariantType.STRING,
                        "PublishDiagnosticsParams");
                    var pd_version = lookup_property (parameters, "version", VariantType.INT64,
                        "PublishDiagnosticsParams");
                    int64? version = pd_version != null ? (int64?) pd_version.get_int64 () : null;
                    Diagnostic[] diags = {};
                    foreach (var diag in expect_property (parameters, "diagnostics",
                        VariantType.ARRAY, "PublishDiagnosticsParams"))
                        diags += new Diagnostic.from_variant (
                            unwrap_variant (diag));
                    publish_diagnostics (Uri.parse ((string) pd_uri, UriFlags.NONE), version,
                        diags);
                    break;

                case "$/logTrace":
                    var message = (string) expect_property (parameters, "message",
                        VariantType.STRING, "LogTraceParams");
                    var lt_verbose = lookup_property (parameters, "verbose", VariantType.STRING,
                        "LogTraceParams");
                    string? verbose = lt_verbose != null ? (string?) lt_verbose : null;
                    log_trace (message, verbose);
                    break;
            }
        } catch (Error e) {
            warning ("handling notification failed - %s", e.message);
        }
    }

    private async void handle_call_async (Jsonrpc.Client client, string method, Variant id,
        Variant parameters) {
        if (exited) {
            try {
                yield client.reply_error_async (id, ProtocolError.INVALID_REQUEST,
                    "editor is shutting down", cancellable);
            } catch (Error e) {
                // ignore
            }
            return;
        }

        try {
            switch (method) {
                default: {
                    yield client.reply_error_async (id, ProtocolError.METHOD_NOT_FOUND, null,
                        cancellable);
                    break;
                }

                case "workspace/applyEdit":
                    var edit = new WorkspaceEdit.from_variant (expect_property (parameters, "edit",
                        VariantType.VARDICT, "ApplyWorkspaceEditParams"));
                    var label_prop = lookup_property (parameters, "label", VariantType.STRING,
                        "ApplyWorkspaceEditParams");
                    var result = yield apply_workspace_edit_async (edit, (string?) label_prop);
                    yield client.reply_async (id, result.to_variant (), cancellable);
                    break;

                case "window/showMessageRequest":
                    var message_type = expect_property (
                        parameters,
                        "type",
                        VariantType.INT64,
                        "ShowMessageRequestParams");
                    var message = (string) expect_property (
                        parameters,
                        "message",
                        VariantType.STRING,
                        "ShowMessageRequestParams");
                    MessageActionItem[] actions = {};
                    var actions_value = lookup_property (
                        parameters,
                        "actions",
                        VariantType.ARRAY,
                        "ShowMessageRequestParams");
                    if (actions_value != null) {
                        foreach (var action in actions_value)
                            actions += MessageActionItem.from_variant (
                                unwrap_variant (action));
                    }
                    var selected_action = yield show_message_request_async (
                        MessageType.parse_int ((int) (int64) message_type),
                        message,
                        actions);
                    if (selected_action == null)
                        yield reply_null_async (
                            client,
                            id,
                            cancellable);
                    else
                        yield client.reply_async (
                            id,
                            ((MessageActionItem) selected_action).to_variant (),
                            cancellable);
                    break;

                case "window/showDocument":
                    var uri = Uri.parse (
                        (string) expect_property (
                            parameters,
                            "uri",
                            VariantType.STRING,
                            "ShowDocumentParams"),
                        UriFlags.NONE);
                    var external_value = lookup_property (
                        parameters,
                        "external",
                        VariantType.BOOLEAN,
                        "ShowDocumentParams");
                    var focus_value = lookup_property (
                        parameters,
                        "takeFocus",
                        VariantType.BOOLEAN,
                        "ShowDocumentParams");
                    var selection_value = lookup_property (
                        parameters,
                        "selection",
                        VariantType.VARDICT,
                        "ShowDocumentParams");
                    Range? selection = null;
                    if (selection_value != null)
                        selection = Range.from_variant (selection_value);
                    var success = yield show_document_async (
                        uri,
                        external_value != null && (bool) external_value,
                        focus_value != null && (bool) focus_value,
                        selection);
                    var show_result = new VariantDict ();
                    show_result.insert_value ("success", success);
                    yield client.reply_async (
                        id,
                        show_result.end (),
                        cancellable);
                    break;
            }
        } catch (ProtocolError e) {
            warning ("handling call failed - %s", e.message);
            try {
                yield client.reply_error_async (id, e.code, e.message,
                    cancellable);
            } catch (Error e2) {
                // ignore
            }
        } catch (Error e) {
            warning ("handling call failed - %s", e.message);
            try {
                yield client.reply_error_async (id, ProtocolError.INTERNAL_ERROR, e.message,
                    cancellable);
            } catch (Error e2) {
                // ignore
            }
        }
    }

    /**
     * The workspace/applyEdit request is sent from the server to the
     * client to apply a workspace edit.
     *
     * @param edit  the workspace edit to apply
     * @param label an optional label describing the edit
     *
     * @return the result indicating whether the edit was applied
     */
    protected virtual async ApplyWorkspaceEditResult apply_workspace_edit_async (WorkspaceEdit edit,
        string? label = null) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND ("workspace/applyEdit is not implemented");
    }

    /**
     * Asks the user to select an action for a server-provided message.
     *
     * @return the selected action, or `null` if no action was selected
     */
    protected virtual async MessageActionItem? show_message_request_async (
        MessageType type,
        string message,
        (unowned MessageActionItem)[] actions
    ) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "window/showMessageRequest is not implemented");
    }

    /**
     * Shows a server-provided resource in the editor.
     *
     * @return whether the resource was shown
     */
    protected virtual async bool show_document_async (
        Uri uri,
        bool external,
        bool take_focus,
        Range? selection
    ) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "window/showDocument is not implemented");
    }

    protected override void client_accepted (Jsonrpc.Client client) {
        if (this.client != client) {
            init_result = null;         // reset init_result with a new client
            is_shutting_down = false;
            exited = false;
        }
        this.client = client;
    }

    protected override void client_closed (Jsonrpc.Client client) {
        this.init_result = null;
        this.client = null;
        this.is_shutting_down = false;
    }

    /**
     * Emitted when we receive a `window/showMessage` notification
     *
     * @param type    the message type
     * @param message the actual message
     */
    public virtual signal void show_message (MessageType type, string message);

    /**
     * Emitted when we receive a `textDocument/publishDiagnostics` notification
     *
     * @param uri         the URI for which diagnostic information is reported
     * @param version     (optional, since 3.15.0) the version number of the
     *                    document the diagnostics are published for
     * @param diagnostics an array of diagnostic information items
     */
    public virtual signal void publish_diagnostics (Uri uri, int64? version,
        Diagnostic[] diagnostics);

    /**
     * Emitted when we receive a `$/logTrace` notification
     *
     * @param message the message to be logged
     * @param verbose additional information that can be computed if the trace
     *                configuration is set to `verbose`
     */
    public virtual signal void log_trace (string message, string? verbose);

    /**
     * Emitted when we receive a `window/logMessage` notification
     *
     * @param type    the message type
     * @param message the actual message
     */
    public virtual signal void log_message (MessageType type, string message);

    /**
     * Initializes the server, if we're connected to one.
     *
     * @see Lsp.Server.initialize_async
     */
    public async void initialize_async (WorkspaceFolder primary_workspace,
        (unowned WorkspaceFolder)[]? secondary_workspaces = null) throws Error {
        var init_params = new InitializeParams.with_workspace_folders (
            primary_workspace,
            secondary_workspaces);
        yield initialize_with_params_async (init_params);
    }

    /**
     * Initializes the server with caller-provided protocol parameters.
     *
     * Use this form when the editor needs to advertise client capabilities,
     * client information, locale, or initialization options.
     */
    public async void initialize_with_params_async (
        InitializeParams init_params
    ) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");

        Variant? return_value;
        yield client.call_async ("initialize", init_params.to_variant (), cancellable,
            out return_value);

        if (return_value == null)
            throw new DeserializeError.INVALID_TYPE (
                "expected non-null return value from `initialize`");

        init_result = new InitializeResult.from_variant (return_value);
    }

    /**
     * Notifies the server that initialization has completed.
     *
     * This must be sent after {@link initialize_async} and before any other
     * request or notification.
     */
    public async void initialized_async () throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        yield client.send_notification_async (
            "initialized",
            new VariantDict ().end (),
            cancellable);
    }

    /**
     * Opens a file, sending the `textDocument/didOpen` message to the language
     * server. If the file is already open, this does nothing.
     *
     * @param text  if non-null, this means that `uri` is associated with an
     *              in-memory buffer `text`
     */
    public async void open_text_document_async (Uri uri, LanguageId language_id,
        string? text = null) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        if (text_documents.contains (uri))
            return;     // the document is already open

        bool in_memory = true;
        if (text == null) {
            var file = File.new_for_uri (uri.to_string ());
            var bytes = yield file.load_bytes_async (cancellable, null);
            text = (string?) bytes.get_data ();  // null means the file was empty
            in_memory = false;
        }

        var text_document = new TextDocumentItem (uri, language_id, 1, text ?? "");
        text_document.state =
            in_memory ? TextDocumentItem.State.IN_MEMORY : TextDocumentItem.State.UNMODIFIED;

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument", text_document.to_variant ());

        yield client.send_notification_async ("textDocument/didOpen", parameters.end (),
            cancellable);

        text_documents[uri] = text_document;
    }

    /**
     * The document change notification is sent from the client to the server
     * to signal changes to a text document. Before a client can change a text
     * document it must claim ownership of its content using the
     * `textDocument/didOpen` notification (see {@link
     * open_text_document_async}). In 2.0 the shape of the params has changed
     * to include proper version numbers.
     *
     * @param uri             the URI of the document that has been modified
     * @param version         the version numebr points to the version after all
     *                        provided content changes have been applied
     * @param content_changes the actual content changes. The content changes describe single state
     *                        changes to the document. So if there are two content changes c1 (at
     *                        array index 0) and c2 (at array index 1) for a document in state S then
     *                        c1 moves the document from S to S2 and c2 from S2 to S3. So c1 is
     *                        computed on the state S and c2 is computed on the state S2.
     *                        To mirror the content of a document using change events use the following
     *                        approach:
     *                        * start with the same initial content
     *                        * apply the 'textDocument/didChange' notifications in the order you
     *                          receive them.
     *                        * apply the `TextDocumentContentChangeEvent`s in a single notification
     *                          in the order you receive them.
     */
    public async void edit_text_document_async (Uri uri, int64 version,
        (unowned TextDocumentContentChangeEvent)[] content_changes) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        if (!text_documents.contains (uri))
            return;     // the document is not open

        var text_document = text_documents[uri];
        if (version <= text_document.version)
            return;     // discard stale changes

        var parameters = new VariantDict ();
        Variant[] content_changes_list = {};
        foreach (var content_change in content_changes) {
            content_changes_list += content_change.to_variant ();
        }
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier (text_document.uri, version).to_variant ());
        parameters.insert_value ("contentChanges", content_changes_list);

        yield client.send_notification_async ("textDocument/didChange", parameters.end (),
            cancellable);

        if (version > text_document.version)
            text_document.version = version;
    }

    /**
     * Notifies the server that an open document was saved.
     *
     * @param text optional saved content when requested by the server
     */
    public async void save_text_document_async (
        Uri uri,
        string? text = null
    ) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        if (!text_documents.contains (uri))
            return;

        var parameters = new VariantDict ();
        parameters.insert_value (
            "textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        if (text != null)
            parameters.insert_value ("text", text);

        yield client.send_notification_async (
            "textDocument/didSave",
            parameters.end (),
            cancellable);
    }

    /**
     * Closes a file, sending the `textDocument/didClose` message to the
     * language server. If the file is not open, this does nothing.
     */
    public async void close_text_document_async (Uri uri) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        if (!text_documents.contains (uri))
            return;     // the document is not open

        var text_document = text_documents[uri];
        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier (text_document.uri, text_document.version).to_variant ());

        yield client.send_notification_async ("textDocument/didClose", parameters.end (),
            cancellable);

        text_documents.remove (uri);
    }

    /**
     * A notification that should be used by the client to modify the trace
     * setting of the server.
     */
    public async void set_trace_async (TraceValue trace_value) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("value", trace_value.to_string ());

        yield client.send_notification_async ("$/setTrace", parameters.end (), cancellable);
        this.trace_value = trace_value;         // synchronize on success
    }

    /**
     * Requests an orderly server shutdown without terminating it.
     */
    public async void shutdown_async () throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        Variant? return_value;
        yield client.call_async (
            "shutdown",
            null,
            cancellable,
            out return_value);
        is_shutting_down = true;
    }

    /**
     * Notifies the server to exit after shutdown.
     */
    public async void exit_async () throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");

        yield client.send_notification_async (
            "exit",
            null,
            cancellable);
        exited = true;
    }

    /**
     * The completion request is sent from the client to the server to
     * compute completion items at a given cursor position.
     *
     * @param uri      the URI of the document for which completions are
     *                 requested
     * @param position the position at which completions are requested
     * @param context  additional context about the completion trigger,
     *                 or null if not provided by the server
     *
     * @return a list of completion items, or null if there are none
     */
    public async CompletionItem[]? completion_async (Uri uri, Position position,
        CompletionContext? context = null) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());
        if (context != null)
            parameters.insert_value ("context", context.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/completion", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        CompletionItem[] items = {};
        foreach (var item in return_value) {
            items += new CompletionItem.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/completion result"));
        }
        return items.length > 0 ? items : null;
    }

    /**
     * The document highlight request is sent from the client to the
     * server to resolve document highlights for a given text document
     * position.
     *
     * @param uri      the URI of the document to find highlights in
     * @param position the position inside the document
     *
     * @return a list of document highlights, or null if there are none
     */
    public async DocumentHighlight[]? document_highlight_async (Uri uri,
        Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/documentHighlight", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        DocumentHighlight[] items = {};
        foreach (var item in return_value)
            items += DocumentHighlight.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/documentHighlight result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The hover request is sent from the client to the server to request
     * hover information at a given text document position.
     *
     * @param uri      the URI of the document to hover over
     * @param position the position inside the document
     *
     * @return the hover information, or null if none
     */
    public async Hover? hover_async (Uri uri, Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/hover", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        return new Hover.from_variant (return_value);
    }

    /**
     * The signature help request is sent from the client to the server
     * to request signature information at a given cursor position.
     *
     * @param uri      the URI of the document containing the call
     * @param position the position inside the document
     *
     * @return signature help information, or null if none
     */
    public async SignatureHelp? signature_help_async (Uri uri, Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/signatureHelp", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        return new SignatureHelp.from_variant (return_value);
    }

    /**
     * The go-to-declaration request is sent from the client to the server
     * to resolve the declaration location for a symbol at a given text
     * document position.
     *
     * @param uri      the URI of the document containing the symbol
     * @param position the position inside the document
     *
     * @return a list of locations where the symbol is declared, or null
     */
    public async Location[]? declaration_async (Uri uri, Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/declaration", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        Location[] items = {};
        foreach (var item in return_value)
            items += Location.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/declaration result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The go-to-definition request is sent from the client to the server
     * to resolve the definition location for a symbol at a given text
     * document position.
     *
     * @param uri      the URI of the document containing the symbol
     * @param position the position inside the document
     *
     * @return a list of locations where the symbol is defined, or null
     */
    public async Location[]? definition_async (Uri uri, Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/definition", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        Location[] items = {};
        foreach (var item in return_value)
            items += Location.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/definition result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The go-to-implementation request is sent from the client to the
     * server to resolve the implementation location for a symbol at a
     * given text document position.
     *
     * @param uri      the URI of the document containing the symbol
     * @param position the position inside the document
     *
     * @return a list of locations where the symbol is implemented,
     *         or null
     */
    public async Location[]? implementation_async (Uri uri, Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/implementation", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        Location[] items = {};
        foreach (var item in return_value)
            items += Location.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/implementation result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The references request is sent from the client to the server to
     * resolve project-wide references for the symbol denoted by the
     * given text document position.
     *
     * @param uri      the URI of the document containing the symbol
     * @param position the position inside the document
     * @param context  additional information
     *
     * @return a list of locations for the references, or null
     */
    public async Location[]? references_async (Uri uri, Position position,
        ReferenceContext context) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());
        parameters.insert_value ("context", context.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/references", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        Location[] items = {};
        foreach (var item in return_value)
            items += Location.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/references result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The document symbol request is sent from the client to the server
     * to return all symbols found in a given text document.
     *
     * @param uri the URI of the document to list symbols from
     *
     * @return hierarchical document symbols or flat symbol information
     */
    public async DocumentSymbolResult? document_symbol_async (Uri uri) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/documentSymbol", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        return new DocumentSymbolResult.from_variant (return_value);
    }

    /**
     * The rename request is sent from the client to the server to
     * rename a symbol.
     *
     * @param uri       the URI of the document containing the symbol
     * @param position  the position of the symbol
     * @param new_name  the new name for the symbol
     *
     * @return a workspace edit describing the rename, or null
     */
    public async WorkspaceEdit? rename_async (Uri uri, Position position,
        string new_name) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new RenameParams (TextDocumentIdentifier.unversioned (uri), position,
            new_name);

        Variant? return_value;
        yield client.call_async ("textDocument/rename", parameters.to_variant (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        return new WorkspaceEdit.from_variant (return_value);
    }

    /**
     * The prepare rename request is sent from the client to the server
     * to check whether a rename is valid at the given position.
     *
     * @param uri       the URI of the document containing the symbol
     * @param position  the position of the symbol
     *
     * @return the prepared rename range or default behavior, or null
     */
    public async PrepareRenameResult? prepare_rename_async (Uri uri,
        Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/prepareRename", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;
        return PrepareRenameResult.from_variant (return_value);
    }

    /**
     * The prepare call hierarchy request is sent from the client to the
     * server to prepare a call hierarchy for a symbol at a given text
     * document position.
     *
     * @param uri      the URI of the document containing the symbol
     * @param position the position inside the document
     *
     * @return a list of call hierarchy items, or null
     */
    public async CallHierarchyItem[]? prepare_call_hierarchy_async (Uri uri,
        Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/prepareCallHierarchy", parameters.end (),
            cancellable, out return_value);

        if (return_value == null)
            return null;

        CallHierarchyItem[] items = {};
        foreach (var item in return_value)
            items += new CallHierarchyItem.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/prepareCallHierarchy result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The incoming calls request is sent from the client to the server
     * to resolve incoming calls for a given call hierarchy item.
     *
     * @param item the call hierarchy item
     *
     * @return a list of incoming calls, or null
     */
    public async CallHierarchyIncomingCall[]?
    incoming_calls_async (CallHierarchyItem item) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("item", item.to_variant ());
        Variant? return_value;
        yield client.call_async (
            "callHierarchy/incomingCalls",
            parameters.end (),
            cancellable,
            out return_value);

        if (return_value == null)
            return null;

        CallHierarchyIncomingCall[] items = {};
        foreach (var call in return_value)
            items += new CallHierarchyIncomingCall.from_variant (
                expect_array_element (
                    call,
                    VariantType.VARDICT,
                    "callHierarchy/incomingCalls result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The outgoing calls request is sent from the client to the server
     * to resolve outgoing calls for a given call hierarchy item.
     *
     * @param item the call hierarchy item
     *
     * @return a list of outgoing calls, or null
     */
    public async CallHierarchyOutgoingCall[]?
    outgoing_calls_async (CallHierarchyItem item) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("item", item.to_variant ());
        Variant? return_value;
        yield client.call_async (
            "callHierarchy/outgoingCalls",
            parameters.end (),
            cancellable,
            out return_value);

        if (return_value == null)
            return null;

        CallHierarchyOutgoingCall[] items = {};
        foreach (var call in return_value)
            items += new CallHierarchyOutgoingCall.from_variant (
                expect_array_element (
                    call,
                    VariantType.VARDICT,
                    "callHierarchy/outgoingCalls result"));
        return items.length > 0 ? items : null;
    }

    /**
     * Prepares a type hierarchy at a document position.
     *
     * @since 3.17.0
     */
    public async TypeHierarchyItem[]? prepare_type_hierarchy_async (Uri uri,
        Position position) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("position", position.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/prepareTypeHierarchy", parameters.end (),
            cancellable, out return_value);
        return type_hierarchy_items_from_variant (
            return_value, "textDocument/prepareTypeHierarchy result");
    }

    /**
     * Resolves direct supertypes for a type hierarchy item.
     *
     * @since 3.17.0
     */
    public async TypeHierarchyItem[]? type_hierarchy_supertypes_async (
        TypeHierarchyItem item
    ) throws Error {
        return yield type_hierarchy_items_async ("typeHierarchy/supertypes", item);
    }

    /**
     * Resolves direct subtypes for a type hierarchy item.
     *
     * @since 3.17.0
     */
    public async TypeHierarchyItem[]? type_hierarchy_subtypes_async (
        TypeHierarchyItem item
    ) throws Error {
        return yield type_hierarchy_items_async ("typeHierarchy/subtypes", item);
    }

    private async TypeHierarchyItem[]? type_hierarchy_items_async (string method,
        TypeHierarchyItem item) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("item", item.to_variant ());
        Variant? return_value;
        yield client.call_async (method, parameters.end (), cancellable, out return_value);
        return type_hierarchy_items_from_variant (return_value, @"$method result");
    }

    private static TypeHierarchyItem[]? type_hierarchy_items_from_variant (
        Variant? return_value,
        string result_name
    ) throws DeserializeError, UriError {
        if (return_value == null)
            return null;

        TypeHierarchyItem[] items = {};
        foreach (var value in return_value)
            items += new TypeHierarchyItem.from_variant (
                expect_array_element (value, VariantType.VARDICT, result_name));
        return items.length > 0 ? items : null;
    }

    /**
     * The inlay hint request is sent from the client to the server to
     * resolve inlay hints for a given text document range.
     *
     * @param uri   the URI of the document
     * @param range the range to fetch hints for
     *
     * @return a list of inlay hints, or null
     */
    public async InlayHint[]? inlay_hint_async (Uri uri, Range range) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new InlayHintParams (TextDocumentIdentifier.unversioned (uri), range);

        Variant? return_value;
        yield client.call_async ("textDocument/inlayHint", parameters.to_variant (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        InlayHint[] items = {};
        foreach (var item in return_value)
            items += new InlayHint.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/inlayHint result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The inlay hint resolve request is sent from the client to the
     * server to resolve additional information for a given inlay hint.
     *
     * @param hint the inlay hint to resolve
     *
     * @return the resolved inlay hint
     */
    public async InlayHint? inlay_hint_resolve_async (InlayHint hint) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        Variant? return_value;
        yield client.call_async ("inlayHint/resolve", hint.to_variant (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        return new InlayHint.from_variant (return_value);
    }

    /**
     * The code action request is sent from the client to the server to compute
     * commands for a given text document and range. These commands are typically code
     * fixes to either fix problems or to beautify/refactor code. The result of a
     * textDocument/codeAction request is an array of Command literals which are
     * typically presented in the user interface. To ensure that a server is useful in
     * many clients the commands specified in a code actions should be handled by the
     * server and not by the client (see workspace/executeCommand and
     * ServerCapabilities.executeCommandProvider). If the client supports providing
     * edits with a code action then that mode should be used.
     *
     * Since version 3.16.0: a client can offer a server to delay the computation of
     * code action properties during a ‘textDocument/codeAction’ request:
     *
     * This is useful for cases where it is expensive to compute the value of a
     * property (for example the edit property). Clients signal this through the
     * codeAction.resolveSupport capability which lists all properties a client can
     * resolve lazily. The server capability codeActionProvider.resolveProvider
     * signals that a server will offer a codeAction/resolve route. To help servers to
     * uniquely identify a code action in the resolve request, a code action literal
     * can optional carry a data property. This is also guarded by an additional
     * client capability codeAction.dataSupport. In general, a client should offer
     * data support if it offers resolve support. It should also be noted that servers
     * shouldn’t alter existing attributes of a code action in a codeAction/resolve
     * request.
     *
     * Since version 3.8.0: support for CodeAction literals to enable the
     * following scenarios:
     *
     *  * the ability to directly return a workspace edit from the code action
     *    request. This avoids having another server roundtrip to execute an actual
     *    code action. However server providers should be aware that if the code
     *    action is expensive to compute or the edits are huge it might still be
     *    beneficial if the result is simply a command and the actual edit is only
     *    computed when needed.
     *  * the ability to group code actions using a kind.
     *    Clients are allowed to ignore that information. However it allows them to
     *    better group code action for example into corresponding menus (e.g. all
     *    refactor code actions into a refactor menu).
     *
     * Clients need to announce their support for code action literals (e.g. literals
     * of type CodeAction) and code action kinds via the corresponding client
     * capability codeAction.codeActionLiteralSupport.
     *
     * @param uri     the URI of the document in which the command was invoked
     * @param range   the range for which the command was invoked
     * @param trigger the reason why this code action request happened, or
     *                {@link CodeActionTriggerKind.UNSET} for no reason
     * @param only    if non-null, limit results to these kinds only
     *
     * @return a list of code actions and commands available at the current
     *         range in the document, or null if there are none
     */
    public async Action[]? code_action_async (Uri uri, Range range,
        CodeActionTriggerKind trigger = CodeActionTriggerKind.UNSET,
        CodeActionKind[]? only = null) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("textDocument",
            TextDocumentIdentifier.unversioned (uri).to_variant ());
        parameters.insert_value ("range", range.to_variant ());
        parameters.insert_value ("context", new CodeActionContext () {
            trigger = trigger,
            only = only
        }.to_variant ());

        Variant? return_value;
        yield client.call_async ("textDocument/codeAction", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        Action[] actions = {};
        foreach (var item in return_value) {
            var action = expect_array_element (
                item,
                VariantType.VARDICT,
                "textDocument/codeAction result");
            actions += Action.from_variant (action);
        }
        return actions.length > 0 ? actions : null;
    }

    /**
     * The code lens request is sent from the client to the server to
     * compute code lenses for a given text document.
     *
     * @param uri the URI of the document to compute code lenses for
     *
     * @return a list of code lenses, or null if there are none
     */
    public async CodeLens[]? code_lens_async (Uri uri) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new CodeLensParams (TextDocumentIdentifier.unversioned (uri));

        Variant? return_value;
        yield client.call_async ("textDocument/codeLens", parameters.to_variant (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        CodeLens[] items = {};
        foreach (var item in return_value)
            items += new CodeLens.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/codeLens result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The document formatting request is sent from the client to the
     * server to format a whole document.
     *
     * @param uri      the URI of the document to format
     * @param options  the formatting options
     *
     * @return a list of text edits, or null if no formatting is needed
     */
    public async TextEdit[]? formatting_async (Uri uri, FormattingOptions options) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new DocumentFormattingParams (TextDocumentIdentifier.unversioned (uri),
            options);

        Variant? return_value;
        yield client.call_async ("textDocument/formatting", parameters.to_variant (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        TextEdit[] items = {};
        foreach (var item in return_value)
            items += TextEdit.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/formatting result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The document range formatting request is sent from the client to
     * the server to format a given range in a document.
     *
     * @param uri      the URI of the document to format
     * @param range    the range to format
     * @param options  the formatting options
     *
     * @return a list of text edits, or null if no formatting is needed
     */
    public async TextEdit[]? range_formatting_async (Uri uri, Range range,
        FormattingOptions options) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters =
            new DocumentRangeFormattingParams (TextDocumentIdentifier.unversioned (uri), range,
                options);

        Variant? return_value;
        yield client.call_async ("textDocument/rangeFormatting", parameters.to_variant (),
            cancellable, out return_value);

        if (return_value == null)
            return null;

        TextEdit[] items = {};
        foreach (var item in return_value)
            items += TextEdit.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "textDocument/rangeFormatting result"));
        return items.length > 0 ? items : null;
    }

    /**
     * The workspace symbol request is sent from the client to the server
     * to list project-wide symbols matching a given query string.
     *
     * @param query a non-empty query string
     *
     * @return a list of symbol informations matching the query, or null
     *         if there are none
     */
    public async SymbolInformation[]? workspace_symbol_async (string query) throws Error {
        if (client == null)
            throw new Lsp.ProtocolError.REQUEST_FAILED ("not connected to a client");
        if (init_result == null)
            throw new Lsp.ProtocolError.SERVER_NOT_INITIALIZED ("client not initialized");

        var parameters = new VariantDict ();
        parameters.insert_value ("query", new Variant.string (query));

        Variant? return_value;
        yield client.call_async ("workspace/symbol", parameters.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        SymbolInformation[] items = {};
        foreach (var item in return_value)
            items += new SymbolInformation.from_variant (
                expect_array_element (
                    item,
                    VariantType.VARDICT,
                    "workspace/symbol result"));
        return items.length > 0 ? items : null;
    }
}
