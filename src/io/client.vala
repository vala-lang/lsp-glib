/* editor.vala
 *
 * Copyright 2021 Princeton Ferro <princetonferro@gmail.com>
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
 * The JSON-RPC client. Exposes methods and notifications that should be called
 * from server code. If you want to ''implement'' a LSP editor, use {@link
 * Lsp.Editor}.
 *
 * This is a wrapper over {@link Jsonrpc.Client} that supports LSP-specific
 * operations, and is created internally by {@link Lsp.Server}.
 */
public class Lsp.Client : Object {
    Jsonrpc.Client client;
    TraceValue trace_value;

    /**
     * Cancels work associated with the message currently being handled.
     *
     * For requests, this is cancelled when the remote client sends a
     * `$/cancelRequest` notification. For notifications, this has the same
     * lifetime as the server. Implementations should observe this cancellable
     * and must not cancel it themselves.
     */
    public Cancellable cancellable { get; private set; }

    internal Client (Jsonrpc.Client client, Cancellable cancellable, TraceValue trace_value) {
        this.client = client;
        this.cancellable = cancellable;
        this.trace_value = trace_value;
    }

    /**
     * The show message notification is sent from a server to a client to ask
     * the client to display a particular message in the user interface.
     */
    public async void show_message_async (MessageType type, string message) throws Error {
        var dict = new VariantDict ();
        dict.insert_value ("type", type);
        dict.insert_value ("message", message);
        yield client.send_notification_async ("window/showMessage", dict.end (), cancellable);
    }

    /**
     * The show message request allows to pass actions and to wait for an answer
     * from the client.
     *
     * @param actions   The list of actions the user can select, like 'Ok',
     *                  'Cancel', 'Build', etc. Can be `null` if you just want to wait for a
     *                  response from the editor after showing a message.
     * @return          The action selected in the editor or `null` if no actions were provided.
     */
    public async MessageActionItem? ask_message_async (MessageType type, string message,
        (unowned MessageActionItem)[]? actions = null) throws Error {
        var dict = new VariantDict ();
        dict.insert_value ("type", type);
        dict.insert_value ("message", message);
        Variant[] actions_list = {};
        if (actions != null) {
            foreach (var action in actions)
                actions_list += action.to_variant ();
        }
        dict.insert_value ("actions", new Variant.array (VariantType.VARDICT, actions_list));

        Variant? return_value;
        yield client.call_async ("window/showMessageRequest", dict.end (), cancellable,
            out return_value);

        if (return_value == null)
            return null;

        return MessageActionItem.from_variant (return_value);
    }

    /**
     * The show document request is sent from a server to a client to ask the
     * client to display a particular document in the user interface.
     *
     * @param uri           The document URI to show.
     * @param external      Indicates to show the resource in an external program.
     *                      To show for example [[https://vala-project.org]] in the
     *                      default web browser set this to `true`.
     * @param take_focus    Indicates whether the editor showing the document should
     *                      take focus or not. Clients might ignore this property if
     *                      an external program is started.
     * @param selection     An optional selection range if the document is a text
     *                      document. Clients might ignore the property if an external
     *                      program is started or the file is not a text file.
     * @return              `true` if the show was successful, `false` otherwise
     *
     * @since 3.16.0
     */
    public async bool show_document_async (Uri uri, bool external = false,
        bool take_focus = false, Range? selection = null) throws Error {
        var dict = new VariantDict ();
        dict.insert_value ("uri", uri.to_string ());
        dict.insert_value ("external", external);
        dict.insert_value ("takeFocus", take_focus);
        if (selection != null) {
            dict.insert_value ("selection", selection.to_variant ());
        }

        Variant? return_value;
        yield client.call_async ("window/showDocument", dict.end (), cancellable, out return_value);

        if (return_value == null)
            throw new DeserializeError.INVALID_TYPE ("expected result from window/showDocument");

        return (bool) expect_property (
            return_value,
            "success",
            VariantType.BOOLEAN,
            "ShowDocumentResult");
    }

    /**
     * Diagnostics notifications are sent from the server to the client to signal
     * results of validation runs.
     *
     * Diagnostics are “owned” by the server so it is the server’s responsibility
     * to clear them if necessary. The following rule is used for VS Code servers
     * that generate diagnostics:
     *
     *  * if a language is single file only (for example HTML) then diagnostics
     *    are cleared by the server when the file is closed. Please note that open
     *    / close events don’t necessarily reflect what the user sees in the user
     *    interface. These events are ownership events. So with the current version
     *    of the specification it is possible that problems are not cleared
     *    although the file is not visible in the user interface since the client
     *    has not closed the file yet.
     *
     *  * if a language has a project system (for example C#) diagnostics are not
     *    cleared when a file closes. When a project is opened all diagnostics for
     *    all files are recomputed (or read from a cache).
     *
     * When a file changes it is the server’s responsibility to re-compute
     * diagnostics and push them to the client. If the computed set is empty it
     * has to push the empty array to clear former diagnostics. Newly pushed
     * diagnostics always replace previously pushed diagnostics. There is no
     * merging that happens on the client side.
     *
     * @param uri           The URI for which diagnostic information is reported.
     * @param diagnostics   An array of diagnostic information. Pass in `null`
     *                      to clear diagnostics.
     * @param version       The version number of the document the diagnostics
     *                      are published for.
     */
    public async void publish_diagnostics_async (Uri uri, (unowned Diagnostic)[]? diagnostics,
        int64? version = null) throws Error {
        var dict = new VariantDict ();
        dict.insert_value ("uri", uri.to_string ());
        if (version != null)
            dict.insert_value ("version", (int64) version);
        Variant[] diagnostics_list = {};
        if (diagnostics != null) {
            foreach (var diagnostic in diagnostics)
                diagnostics_list += diagnostic.to_variant ();
        }
        dict.insert_value ("diagnostics",
            new Variant.array (VariantType.VARDICT, diagnostics_list));

        yield client.send_notification_async ("textDocument/publishDiagnostics", dict.end (),
            cancellable);
    }

    /**
     * A notification to log the trace of the server’s execution. The amount and
     * content of these notifications depends on the current `trace` configuration. If
     * `trace` is 'off', the server should not send any logTrace notification. If `trace`
     * is 'messages', the server should not add the 'verbose' field in the
     * `LogTraceParams`.

     * `$/logTrace` should be used for systematic trace reporting. For single debugging
     * messages, the server should send `window/logMessage` notifications.
     *
     * @param message the message to be logged
     * @param verbose additional information that can be computed if the
     *                `trace` configuration is set to `verbose`
     */
    public async void log_trace_async (string message, string? verbose = null) throws Error {
        if (trace_value == TraceValue.OFF)
            return;
        var dict = new VariantDict ();
        dict.insert_value ("message", message);
        if (trace_value == TraceValue.VERBOSE && verbose != null)
            dict.insert_value ("verbose", verbose);

        yield client.send_notification_async ("$/logTrace", dict.end (), cancellable);
    }

    /**
     * The log message notification is sent from the server to the client to
     * ask the client to log a particular message.
     *
     * @param type    the message type
     * @param message the actual message
     */
    public async void log_message_async (MessageType type, string message) throws Error {
        var dict = new VariantDict ();
        dict.insert_value ("type", type);
        dict.insert_value ("message", message);
        yield client.send_notification_async ("window/logMessage", dict.end (), cancellable);
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
    public async ApplyWorkspaceEditResult apply_edit_async (WorkspaceEdit edit,
        string? label = null) throws Error {
        var dict = new VariantDict ();
        dict.insert_value ("edit", edit.to_variant ());
        if (label != null)
            dict.insert_value ("label", label);

        Variant? return_value;
        yield client.call_async ("workspace/applyEdit", dict.end (), cancellable, out return_value);

        if (return_value == null)
            throw new DeserializeError.INVALID_TYPE ("expected result from workspace/applyEdit");

        return new ApplyWorkspaceEditResult.from_variant (return_value);
    }
}
