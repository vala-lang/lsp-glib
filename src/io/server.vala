/* server.vala
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
 * A JSON-RPC server implementing the server's side of the Language Server
 * Protocol using {@link GLib.MainLoop}.
 */
public abstract class Lsp.Server : Jsonrpc.Server {
    MainLoop? loop;
    HashTable<Jsonrpc.Client, HashTable<Variant, Cancellable>> active_requests;

    /**
     * Whether we've received a shutdown request.
     */
    bool is_shutting_down;

    /**
     * Whether we've exited the server.
     */
    bool exited;

    /**
     * How we should log trace messages to the client.
     */
    public TraceValue trace_value { get; private set; default = OFF; }

    public Cancellable cancellable { get; private set; default = new Cancellable (); }

    construct {
        active_requests = new HashTable<Jsonrpc.Client, HashTable<Variant, Cancellable>> (
            direct_hash,
            direct_equal);
        notification.connect (notification_async);
        handle_call.connect ((client, method, id, parameters) => {
            handle_call_async.begin (client, method, id, parameters);
            return !exited;
        });
        client_closed.connect (cancel_client_requests);
    }

    /**
     * Creates a new server.
     *
     * @param loop  The main loop
     */
    protected Server (MainLoop loop) {
        this.loop = loop;
    }

    private async void notification_async (Jsonrpc.Client client, string method,
        Variant parameters) {
        if (exited)
            return;

        debug ("got notification - %s", method);
        if (is_shutting_down && method != "exit" && method != "$/cancelRequest")
            return;

        var lsp_client = new Client (client, cancellable);
        try {
            switch (method) {
                case "exit":
                    cancel_all_requests ();
                    exit ();
                    exited = true;
                    break;

                case "$/cancelRequest":
                    cancel_request (client, parameters);
                    break;

                case "initialized":
                    yield initialized_async (lsp_client);
                    break;

                case "textDocument/didChange":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DidChangeTextDocumentParams");
                    var cc_variant = expect_property (parameters, "contentChanges",
                        VariantType.ARRAY, "DidChangeTextDocumentParams");
                    var content_changes = new TextDocumentContentChangeEvent[] {};
                    foreach (var cc in cc_variant) {
                        if (cc == null)
                            throw new DeserializeError.INVALID_TYPE (
                                "expected non-null content changes for DidChangeTextDocumentParams");
                        content_changes += TextDocumentContentChangeEvent.from_variant (
                            unwrap_variant (cc));
                    }
                    yield text_document_did_change_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant), content_changes);
                    break;

                case "textDocument/didClose":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DidCloseTextDocumentParams");
                    yield text_document_did_close_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant));
                    break;

                case "textDocument/didOpen":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DidOpenTextDocumentParams");
                    yield text_document_did_open_async (lsp_client,
                        new TextDocumentItem.from_variant (tdi_variant));
                    break;

                case "textDocument/didSave":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DidSaveTextDocumentParams");
                    var text_variant = lookup_property (parameters, "text", VariantType.STRING,
                        "DidSaveTextDocumentParams");
                    string? text = text_variant != null ? (string) text_variant : null;
                    yield text_document_did_save_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant), text);
                    break;

                case "$/setTrace":
                    var st_value = (string) expect_property (parameters, "value",
                        VariantType.STRING, "SetTraceParams");
                    trace_value = TraceValue.parse_string (st_value);
                    break;

                default:
                    warning ("notification not supported: %s", method);
                    break;
            }
        } catch (Error e) {
            warning ("notification failed - %s", e.message);
        }
    }

    private async void handle_call_async (Jsonrpc.Client client, string method, Variant id,
        Variant parameters) {
        if (exited)
            return;

        var request_cancellable = register_request (client, id);
        debug ("got call - %s", method);
        try {
            if (is_shutting_down && method != "exit") {
                debug ("rejected because we're already shutting down");
                yield reply_error_async (client, id, ProtocolError.INVALID_REQUEST,
                    "server is shutting down");
                return;
            }

            var lsp_client = new Client (client, request_cancellable);
            switch (method) {
                default: {
                    yield reply_error_async (client, id, ProtocolError.METHOD_NOT_FOUND);
                    break;
                }

                case "initialize":
                    var init_params = new InitializeParams.from_variant (parameters);
                    var init_result = yield initialize_async (lsp_client, init_params);
                    yield reply_result_async (client, id, init_result.to_variant (),
                        request_cancellable);
                    break;

                case "shutdown":
                    is_shutting_down = true;
                    yield shutdown_async (lsp_client);
                    yield reply_result_async (client, id, null, request_cancellable);
                    break;

                case "textDocument/completion":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "CompletionParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "CompletionParams");
                    var ctx_variant = lookup_property (parameters, "context", VariantType.VARDICT,
                        "CompletionParams");
                    CompletionContext? context = null;
                    if (ctx_variant != null)
                        context = new CompletionContext.from_variant (ctx_variant);
                    CompletionItem[]? items = yield completion_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant), context);
                    if (items == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] item_variants = {};
                        foreach (unowned var item in items)
                            item_variants += item.to_variant ();
                        yield reply_result_async (client, id, item_variants, request_cancellable);
                    }
                    break;

                case "textDocument/documentHighlight":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DocumentHighlightParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "DocumentHighlightParams");
                    DocumentHighlight[]? highlights = yield document_highlight_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (highlights == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] hl_variants = {};
                        foreach (unowned var hl in highlights)
                            hl_variants += hl.to_variant ();
                        yield reply_result_async (client, id, hl_variants, request_cancellable);
                    }
                    break;

                case "textDocument/hover":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "HoverParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "HoverParams");
                    Hover? hover_result = yield hover_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (hover_result == null)
                        yield reply_result_async (client, id, null, request_cancellable);
                    else
                        yield reply_result_async (client, id, hover_result.to_variant (),
                            request_cancellable);
                    break;

                case "textDocument/signatureHelp":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "SignatureHelpParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "SignatureHelpParams");
                    SignatureHelp? sig_result = yield signature_help_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (sig_result == null)
                        yield reply_result_async (client, id, null, request_cancellable);
                    else
                        yield reply_result_async (client, id, sig_result.to_variant (),
                            request_cancellable);
                    break;

                case "textDocument/formatting":
                    var params = new DocumentFormattingParams.from_variant (parameters);
                    TextEdit[]? fmt_result = yield formatting_async (lsp_client,
                        params.text_document,
                        params.options);
                    if (fmt_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] edit_variants = {};
                        foreach (var edit in fmt_result)
                            edit_variants += edit.to_variant ();
                        yield reply_result_async (client, id, edit_variants, request_cancellable);
                    }
                    break;

                case "textDocument/rangeFormatting":
                    var rng_params = new DocumentRangeFormattingParams.from_variant (parameters);
                    TextEdit[]? rng_result = yield range_formatting_async (lsp_client,
                        rng_params.text_document,
                        rng_params.range,
                        rng_params.options);
                    if (rng_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] edit_variants = {};
                        foreach (var edit in rng_result)
                            edit_variants += edit.to_variant ();
                        yield reply_result_async (client, id, edit_variants, request_cancellable);
                    }
                    break;

                case "textDocument/declaration":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DeclarationParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "DeclarationParams");
                    Location[]? decl_result = yield declaration_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (decl_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] loc_variants = {};
                        foreach (unowned var loc in decl_result)
                            loc_variants += loc.to_variant ();
                        yield reply_result_async (client, id, loc_variants, request_cancellable);
                    }
                    break;

                case "textDocument/definition":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DefinitionParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "DefinitionParams");
                    Location[]? def_result = yield definition_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (def_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] loc_variants = {};
                        foreach (unowned var loc in def_result)
                            loc_variants += loc.to_variant ();
                        yield reply_result_async (client, id, loc_variants, request_cancellable);
                    }
                    break;

                case "textDocument/implementation":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "ImplementationParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "ImplementationParams");
                    Location[]? impl_result = yield implementation_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (impl_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] loc_variants = {};
                        foreach (unowned var loc in impl_result)
                            loc_variants += loc.to_variant ();
                        yield reply_result_async (client, id, loc_variants, request_cancellable);
                    }
                    break;

                case "textDocument/references":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "ReferenceParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "ReferenceParams");
                    var ctx_variant = expect_property (parameters, "context", VariantType.VARDICT,
                        "ReferenceParams");
                    Location[]? refs = yield references_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant),
                        ReferenceContext.from_variant (ctx_variant));
                    if (refs == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] ref_variants = {};
                        foreach (unowned var loc in refs)
                            ref_variants += loc.to_variant ();
                        yield reply_result_async (client, id, ref_variants, request_cancellable);
                    }
                    break;

                case "textDocument/documentSymbol":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "DocumentSymbolParams");
                    DocumentSymbolResult? sym_result = yield document_symbol_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant));
                    if (sym_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        yield reply_result_async (
                            client, id, sym_result.to_variant (), request_cancellable);
                    }
                    break;

                case "textDocument/rename":
                    var rename_params = new RenameParams.from_variant (parameters);
                    WorkspaceEdit? rename_result = yield rename_async (lsp_client,
                        rename_params.text_document,
                        rename_params.position,
                        rename_params.new_name);
                    if (rename_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        yield reply_result_async (client, id, rename_result.to_variant (),
                            request_cancellable);
                    }
                    break;

                case "textDocument/prepareRename":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "PrepareRenameParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "PrepareRenameParams");
                    PrepareRenameResult? prepare_result = yield prepare_rename_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (prepare_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        yield reply_result_async (
                            client, id, prepare_result.to_variant (), request_cancellable);
                    }
                    break;

                case "textDocument/inlayHint":
                    var ih_params = new InlayHintParams.from_variant (parameters);
                    InlayHint[]? ih_result = yield inlay_hint_async (lsp_client,
                        ih_params.text_document,
                        ih_params.range);
                    if (ih_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] ih_variants = {};
                        foreach (unowned var hint in ih_result)
                            ih_variants += hint.to_variant ();
                        yield reply_result_async (client, id, ih_variants, request_cancellable);
                    }
                    break;

                case "inlayHint/resolve":
                    var hint = new InlayHint.from_variant (parameters);
                    InlayHint? resolved = yield inlay_hint_resolve_async (lsp_client, hint);
                    if (resolved == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        yield reply_result_async (client, id, resolved.to_variant (),
                            request_cancellable);
                    }
                    break;

                case "textDocument/prepareCallHierarchy":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "CallHierarchyPrepareParams");
                    var pos_variant = expect_property (parameters, "position", VariantType.VARDICT,
                        "CallHierarchyPrepareParams");
                    CallHierarchyItem[]? ch_result = yield prepare_call_hierarchy_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant),
                        Position.from_variant (pos_variant));
                    if (ch_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] ch_variants = {};
                        foreach (unowned var item in ch_result)
                            ch_variants += item.to_variant ();
                        yield reply_result_async (client, id, ch_variants, request_cancellable);
                    }
                    break;

                case "callHierarchy/incomingCalls":
                    var item = new CallHierarchyItem.from_variant (
                        expect_property (parameters, "item", VariantType.VARDICT,
                            "CallHierarchyIncomingCallsParams"));
                    CallHierarchyIncomingCall[]? in_result = yield incoming_calls_async (lsp_client,
                        item);
                    if (in_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] in_variants = {};
                        foreach (unowned var call in in_result)
                            in_variants += call.to_variant ();
                        yield reply_result_async (client, id, in_variants, request_cancellable);
                    }
                    break;

                case "callHierarchy/outgoingCalls":
                    var out_item = new CallHierarchyItem.from_variant (
                        expect_property (parameters, "item", VariantType.VARDICT,
                            "CallHierarchyOutgoingCallsParams"));
                    CallHierarchyOutgoingCall[]? out_result =
                        yield outgoing_calls_async (lsp_client, out_item);
                    if (out_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] out_variants = {};
                        foreach (unowned var call in out_result)
                            out_variants += call.to_variant ();
                        yield reply_result_async (client, id, out_variants, request_cancellable);
                    }
                    break;

                case "textDocument/prepareTypeHierarchy":
                    var th_tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "TypeHierarchyPrepareParams");
                    var th_pos_variant = expect_property (parameters, "position",
                        VariantType.VARDICT, "TypeHierarchyPrepareParams");
                    TypeHierarchyItem[]? th_result = yield prepare_type_hierarchy_async (
                        lsp_client,
                        TextDocumentIdentifier.from_variant (th_tdi_variant),
                        Position.from_variant (th_pos_variant));
                    if (th_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] th_variants = {};
                        foreach (unowned var hierarchy_item in th_result)
                            th_variants += hierarchy_item.to_variant ();
                        yield reply_result_async (
                            client, id, th_variants, request_cancellable);
                    }
                    break;

                case "typeHierarchy/supertypes":
                case "typeHierarchy/subtypes":
                    var th_item_variant = expect_property (parameters, "item",
                        VariantType.VARDICT, "TypeHierarchyParams");
                    var th_item = new TypeHierarchyItem.from_variant (th_item_variant);
                    TypeHierarchyItem[]? th_items;
                    if (method == "typeHierarchy/supertypes")
                        th_items = yield type_hierarchy_supertypes_async (lsp_client, th_item);
                    else
                        th_items = yield type_hierarchy_subtypes_async (lsp_client, th_item);
                    if (th_items == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] th_variants = {};
                        foreach (unowned var hierarchy_item in th_items)
                            th_variants += hierarchy_item.to_variant ();
                        yield reply_result_async (
                            client, id, th_variants, request_cancellable);
                    }
                    break;

                case "textDocument/codeLens":
                    var tdi_variant = expect_property (parameters, "textDocument",
                        VariantType.VARDICT, "CodeLensParams");
                    CodeLens[]? lenses = yield code_lens_async (lsp_client,
                        TextDocumentIdentifier.from_variant (tdi_variant));
                    if (lenses == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] lens_variants = {};
                        foreach (unowned var lens in lenses)
                            lens_variants += lens.to_variant ();
                        yield reply_result_async (client, id, lens_variants, request_cancellable);
                    }
                    break;

                case "workspace/symbol":
                    var query = (string) expect_property (parameters, "query", VariantType.STRING,
                        "WorkspaceSymbolParams");
                    SymbolInformation[]? sym_result = yield workspace_symbol_async (lsp_client,
                        query);
                    if (sym_result == null) {
                        yield reply_result_async (client, id, null, request_cancellable);
                    } else {
                        Variant[] sym_variants = {};
                        foreach (unowned var sym in sym_result)
                            sym_variants += sym.to_variant ();
                        yield reply_result_async (client, id, sym_variants, request_cancellable);
                    }
                    break;

                case "textDocument/codeAction":
                    var text_document =
                        TextDocumentIdentifier.from_variant (expect_property (parameters,
                            "textDocument", VariantType.VARDICT, "CodeActionParams"));
                    var range = Range.from_variant (expect_property (parameters, "range",
                        VariantType.VARDICT, "CodeActionParams"));
                    var context = new CodeActionContext.from_variant (expect_property (parameters,
                        "context", VariantType.VARDICT, "CodeActionParams"));
                    var action_result = yield code_action_async (
                        lsp_client,
                        text_document,
                        range,
                        context);
                    if (action_result == null) {
                        yield reply_result_async (
                            client, id, null, request_cancellable);
                    } else {
                        Variant[] actions = {};
                        foreach (var action in action_result)
                            actions += action.to_variant ();
                        yield reply_result_async (client, id, actions, request_cancellable);
                    }
                    break;
            }
        } catch (IOError.CANCELLED e) {
            if (request_cancellable.is_cancelled ())
                yield reply_error_async (client, id, ProtocolError.REQUEST_CANCELLED, e.message);
            else
                yield reply_error_async (client, id, ProtocolError.SERVER_CANCELLED, e.message);
        } catch (DeserializeError e) {
            warning ("request failed - deserialize params failed - %s", e.message);
            yield reply_error_async (client, id, ProtocolError.INVALID_PARAMS, e.message);
        } catch (ProtocolError e) {
            yield reply_error_async (client, id, e.code, e.message);
        } catch (Error e) {
            yield reply_error_async (client, id, ProtocolError.INTERNAL_ERROR, e.message);
        } finally {
            unregister_request (client, id);
        }
    }

    private async void reply_result_async (Jsonrpc.Client client, Variant id, Variant? result,
        Cancellable request_cancellable) throws Error {
        request_cancellable.set_error_if_cancelled ();
        if (result == null)
            yield Lsp.reply_null_async (client, id, cancellable);
        else
            yield client.reply_async (id, result, cancellable);
    }

    private async void reply_error_async (Jsonrpc.Client client, Variant id, int error_code,
        string? message = null) {
        try {
            yield client.reply_error_async (id, error_code, message, cancellable);
        } catch (Error e) {
            warning ("failed to reply with error to client - %s", e.message);
        }
    }

    private static uint request_id_hash (Variant id) {
        return id.hash ();
    }

    private static bool request_id_equal (Variant a, Variant b) {
        return a.equal (b);
    }

    private Cancellable register_request (Jsonrpc.Client client, Variant id) {
        HashTable<Variant, Cancellable>? requests = active_requests[client];
        if (requests == null) {
            requests = new HashTable<Variant, Cancellable> (
                request_id_hash,
                request_id_equal);
            active_requests[client] = requests;
        }

        var request_cancellable = new Cancellable ();
        requests[id] = request_cancellable;
        return request_cancellable;
    }

    private void unregister_request (Jsonrpc.Client client, Variant id) {
        HashTable<Variant, Cancellable>? requests = active_requests[client];
        if (requests == null)
            return;

        requests.remove (id);
        if (requests.length == 0)
            active_requests.remove (client);
    }

    private void cancel_request (Jsonrpc.Client client,
        Variant parameters) throws DeserializeError {
        if (!parameters.is_of_type (VariantType.VARDICT))
            throw new DeserializeError.INVALID_TYPE ("expected dictionary for CancelParams");

        var id = parameters.lookup_value ("id", null);
        if (id == null)
            throw new DeserializeError.MISSING_PROPERTY ("missing property `id` for CancelParams");
        if (!id.is_of_type (VariantType.INT64) && !id.is_of_type (VariantType.STRING))
            throw new DeserializeError.INVALID_TYPE (
                "expected integer or string property `id` for CancelParams");

        HashTable<Variant, Cancellable>? requests = active_requests[client];
        Cancellable? request_cancellable = requests != null ? requests[id] : null;
        if (request_cancellable != null)
            request_cancellable.cancel ();
    }

    private void cancel_client_requests (Jsonrpc.Client client) {
        HashTable<Variant, Cancellable>? requests = active_requests[client];
        if (requests == null)
            return;

        foreach (unowned var request_cancellable in requests.get_values ())
            request_cancellable.cancel ();
        active_requests.remove (client);
    }

    private void cancel_all_requests () {
        foreach (unowned var requests in active_requests.get_values ()) {
            foreach (unowned var request_cancellable in requests.get_values ())
                request_cancellable.cancel ();
        }
        active_requests.remove_all ();
    }

    /**
     * The initialize request is sent as the first request from the client
     * to the server.
     * If the server receives a request or notification before the
     * initialize request it should act as follows:
     *
     * For a request the response should be an error with code: `-32002`. The
     * message can be picked by the server.  Notifications should be
     * dropped, except for the exit notification. This will allow the exit
     * of a server without an initialize request.
     *
     * Until the server has responded to the initialize request with an
     * InitializeResult, the client must not send any additional requests
     * or notifications to the server. In addition the server is not
     * allowed to send any requests or notifications to the client until it
     * has responded with an InitializeResult, with the exception that
     * during the initialize request the server is allowed to send the
     * notifications `window/showMessage`, `window/logMessage` and
     * telemetry/event as well as the window/showMessageRequest request to
     * the client. In case the client sets up a progress token in the
     * initialize params (e.g. property workDoneToken) the server is also
     * allowed to use that token (and only that token) using the $/progress
     * notification sent from the server to the client.
     *
     * The initialize request may only be sent once.
     */
    protected abstract async InitializeResult initialize_async (Client client,
        InitializeParams init_params) throws Error;

    /**
     * The initialized notification is sent from the client to the server after
     * the client received the result of the initialize request but before the
     * client is sending any other request or notification to the server.
     *
     * The server can use the initialized notification for example to
     * dynamically register capabilities. The initialized notification may only
     * be sent once.
     */
    protected virtual async void initialized_async (Client client) throws Error {
        // do nothing
    }

    /**
     * The document open notification is sent from the client to the server to
     * signal newly opened text documents.
     *
     * The document’s content is now managed by the client and the server must
     * not try to read the document’s content using the document’s Uri. Open in
     * this sense means it is managed by the client. It doesn’t necessarily mean
     * that its content is presented in an editor. An open notification must not
     * be sent more than once without a corresponding close notification send
     * before. This means open and close notification must be balanced and the
     * max open count for a particular textDocument is one. Note that a server’s
     * ability to fulfill requests is independent of whether a text document is
     * open or closed.
     */
    protected abstract async void text_document_did_open_async (Client client,
        TextDocumentItem text_document) throws Error;

    /**
     * The document change notification is sent from the client to the server to
     * signal changes to a text document. Before a client can change a text
     * document it must claim ownership of its content using the
     * textDocument/didOpen notification (see {@link text_document_did_open_async}).
     *
     * @param text_document     The text document with a version number set.
     * @param content_changes   The actual content changes. The content changes describe single state
     *                          changes to the document. So if there are two content changes c1 (at
     *                          array index 0) and c2 (at array index 1) for a document in state S then
     *                          c1 moves the document from S to S2 and c2 from S2 to S3. So c1 is
     *                          computed on the state S and c2 is computed on the state S2.
     *                          To mirror the content of a document using change events use the following
     *                          approach:
     *                          - start with the same initial content
     *                          - apply the 'textDocument/didChange' notifications in the order you
     *                            receive them.
     *                          - apply the `TextDocumentContentChangeEvent`s in a single notification
     *                            in the order you receive them.
     */
    protected abstract async void text_document_did_change_async (Client client,
        TextDocumentIdentifier text_document,
        (unowned TextDocumentContentChangeEvent)[] content_changes) throws Error;

    /**
     * The document save notification is sent from the client to the server when
     * the document was saved in the client.
     *
     * @param text_document     The document that was saved.
     * @param text              The content when saved. Depends on whether the
     *                          server has opted to receive this.
     */
    protected virtual async void text_document_did_save_async (Client client,
        TextDocumentIdentifier text_document,
        string? text) throws Error {
        // do nothing
    }

    /**
     * The document close notification is sent from the client to the server
     * when the document got closed in the client.
     *
     * The document’s master now exists where the document’s URI points to (e.g.
     * if the document’s URI is a file URI the master now exists on disk). As
     * with the open notification the close notification is about managing the
     * document’s content.  Receiving a close notification doesn’t mean that the
     * document was open in an editor before. A close notification requires a
     * previous open notification to be sent. Note that a server’s ability to
     * fulfill requests is independent of whether a text document is open or
     * closed.
     *
     * @param text_document     The document that was closed.
     */
    protected abstract async void text_document_did_close_async (Client client,
        TextDocumentIdentifier text_document) throws Error;

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
     * @param text_document the document in which the command was invoked
     * @param range         the range for which the command was invoked
     * @param context       context carrying additional information
     *
     * @return a list of code actions and commands available at the current
     *         range in the document
     */
    protected virtual async Action[]? code_action_async (Client client,
        TextDocumentIdentifier text_document, Range range, CodeActionContext context) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/codeAction is not implemented");
    }

    /**
     * The completion request is sent from the client to the server to
     * compute completion items at a given cursor position.
     *
     * Completion items are presented in the IntelliSense user interface.
     * If computing full completion items is expensive, servers can additionally
     * provide a handler for the completion item resolve request
     * ('completionItem/resolve').
     *
     * @param text_document the document to provide completions for
     * @param position      the position inside the document for which
     *                      completions are requested
     * @param context       additional context about how the completion was
     *                      triggered
     *
     * @return a list of completion items, or null if there are none
     */
    protected virtual async CompletionItem[]? completion_async (Client client,
        TextDocumentIdentifier text_document, Position position,
        CompletionContext? context) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/completion is not implemented");
    }

    /**
     * The hover request is sent from the client to the server to request
     * hover information at a given text document position.
     *
     * @param text_document the document to hover over
     * @param position      the position inside the document
     *
     * @return the hover information, or null if none
     */
    protected virtual async Hover? hover_async (Client client, TextDocumentIdentifier text_document,
        Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND ("textDocument/hover is not implemented");
    }

    /**
     * The signature help request is sent from the client to the server
     * to request signature information at a given cursor position.
     *
     * @param text_document the document containing the call
     * @param position      the position inside the document
     *
     * @return signature help information, or null if none
     */
    protected virtual async SignatureHelp? signature_help_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/signatureHelp is not implemented");
    }

    /**
     * The go-to-declaration request is sent from the client to the server
     * to resolve the declaration location for a symbol at a given text
     * document position.
     *
     * @param text_document the document containing the symbol
     * @param position      the position inside the document
     *
     * @return a list of locations where the symbol is declared, or null
     */
    protected virtual async Location[]? declaration_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/declaration is not implemented");
    }

    /**
     * The go-to-definition request is sent from the client to the server
     * to resolve the definition location for a symbol at a given text
     * document position.
     *
     * @param text_document the document containing the symbol
     * @param position      the position inside the document
     *
     * @return a list of locations where the symbol is defined, or null
     */
    protected virtual async Location[]? definition_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/definition is not implemented");
    }

    /**
     * The document highlight request is sent from the client to the
     * server to resolve document highlights for a given text document
     * position.
     *
     * For programming languages, this usually highlights all references
     * to the symbol scoped to this file.
     *
     * @param text_document the document to find highlights in
     * @param position      the position inside the document
     *
     * @return a list of document highlights, or null if there are none
     */
    protected virtual async DocumentHighlight[]? document_highlight_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/documentHighlight is not implemented");
    }

    /**
     * The document symbol request is sent from the client to the server
     * to return all symbols found in a given text document.
     *
     * @param text_document the document to list symbols from
     *
     * @return a list of document symbols, or null if there are none
     */
    protected virtual async DocumentSymbolResult? document_symbol_async (Client client,
        TextDocumentIdentifier text_document) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/documentSymbol is not implemented");
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
    protected virtual async SymbolInformation[]? workspace_symbol_async (Client client,
        string query) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND ("workspace/symbol is not implemented");
    }

    /**
     * The references request is sent from the client to the server to
     * resolve project-wide references for the symbol denoted by the
     * given text document position.
     *
     * @param text_document the document containing the symbol
     * @param position      the position inside the document
     * @param context       additional information
     *
     * @return a list of locations for the references, or null
     */
    protected virtual async Location[]? references_async (Client client,
        TextDocumentIdentifier text_document, Position position,
        ReferenceContext context) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/references is not implemented");
    }

    /**
     * The go-to-implementation request is sent from the client to the
     * server to resolve the implementation location for a symbol at a
     * given text document position.
     *
     * @param text_document the document containing the symbol
     * @param position      the position inside the document
     *
     * @return a list of locations where the symbol is implemented,
     *         or null
     */
    protected virtual async Location[]? implementation_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/implementation is not implemented");
    }

    /**
     * The rename request is sent from the client to the server to
     * rename a symbol.
     *
     * @param text_document the document containing the symbol
     * @param position      the position of the symbol
     * @param new_name      the new name for the symbol
     *
     * @return a workspace edit describing the rename, or null
     */
    protected virtual async WorkspaceEdit? rename_async (Client client,
        TextDocumentIdentifier text_document, Position position, string new_name) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND ("textDocument/rename is not implemented");
    }

    /**
     * The prepare rename request is sent from the client to the server
     * to check whether a rename is valid at the given position.
     *
     * @param text_document the document containing the symbol
     * @param position      the position of the symbol
     *
     * @return the prepared rename range or default behavior, or null
     */
    protected virtual async PrepareRenameResult? prepare_rename_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/prepareRename is not implemented");
    }

    /**
     * The code lens request is sent from the client to the server to
     * compute code lenses for a given text document.
     *
     * @param text_document the document to compute code lenses for
     *
     * @return a list of code lenses, or null if there are none
     */
    protected virtual async CodeLens[]? code_lens_async (Client client,
        TextDocumentIdentifier text_document) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND ("textDocument/codeLens is not implemented");
    }

    /**
     * The document formatting request is sent from the client to the
     * server to format a whole document.
     *
     * @param text_document the document to format
     * @param options       the formatting options
     *
     * @return a list of text edits, or null if no formatting is needed
     */
    protected virtual async TextEdit[]? formatting_async (Client client,
        TextDocumentIdentifier text_document, FormattingOptions options) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/formatting is not implemented");
    }

    /**
     * The document range formatting request is sent from the client to
     * the server to format a given range in a document.
     *
     * @param text_document the document to format
     * @param range         the range to format
     * @param options       the formatting options
     *
     * @return a list of text edits, or null if no formatting is needed
     */
    protected virtual async TextEdit[]? range_formatting_async (Client client,
        TextDocumentIdentifier text_document, Range range, FormattingOptions options) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/rangeFormatting is not implemented");
    }

    /**
     * The prepare call hierarchy request is sent from the client to the
     * server to prepare a call hierarchy for a symbol at a given text
     * document position.
     *
     * @param text_document the document containing the symbol
     * @param position      the position inside the document
     *
     * @return a list of call hierarchy items, or null
     */
    protected virtual async CallHierarchyItem[]? prepare_call_hierarchy_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/prepareCallHierarchy is not implemented");
    }

    /**
     * The incoming calls request is sent from the client to the server
     * to resolve incoming calls for a given call hierarchy item.
     *
     * @param item the call hierarchy item
     *
     * @return a list of incoming calls, or null
     */
    protected virtual async CallHierarchyIncomingCall[]? incoming_calls_async (Client client,
        CallHierarchyItem item) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "callHierarchy/incomingCalls is not implemented");
    }

    /**
     * The outgoing calls request is sent from the client to the server
     * to resolve outgoing calls for a given call hierarchy item.
     *
     * @param item the call hierarchy item
     *
     * @return a list of outgoing calls, or null
     */
    protected virtual async CallHierarchyOutgoingCall[]? outgoing_calls_async (Client client,
        CallHierarchyItem item) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "callHierarchy/outgoingCalls is not implemented");
    }

    /**
     * Prepares a type hierarchy for a symbol at a document position.
     *
     * @since 3.17.0
     */
    protected virtual async TypeHierarchyItem[]? prepare_type_hierarchy_async (Client client,
        TextDocumentIdentifier text_document, Position position) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/prepareTypeHierarchy is not implemented");
    }

    /**
     * Resolves the direct supertypes of a type hierarchy item.
     *
     * @since 3.17.0
     */
    protected virtual async TypeHierarchyItem[]? type_hierarchy_supertypes_async (Client client,
        TypeHierarchyItem item) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "typeHierarchy/supertypes is not implemented");
    }

    /**
     * Resolves the direct subtypes of a type hierarchy item.
     *
     * @since 3.17.0
     */
    protected virtual async TypeHierarchyItem[]? type_hierarchy_subtypes_async (Client client,
        TypeHierarchyItem item) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "typeHierarchy/subtypes is not implemented");
    }

    /**
     * The inlay hint request is sent from the client to the server to
     * resolve inlay hints for a given text document range.
     *
     * @param text_document the document to fetch hints for
     * @param range         the range to fetch hints for
     *
     * @return a list of inlay hints, or null
     */
    protected virtual async InlayHint[]? inlay_hint_async (Client client,
        TextDocumentIdentifier text_document, Range range) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND (
            "textDocument/inlayHint is not implemented");
    }

    /**
     * The inlay hint resolve request is sent from the client to the
     * server to resolve additional information for a given inlay hint.
     *
     * @param hint the inlay hint to resolve
     *
     * @return the resolved inlay hint, or null
     */
    protected virtual async InlayHint? inlay_hint_resolve_async (Client client,
        InlayHint hint) throws Error {
        throw new ProtocolError.METHOD_NOT_FOUND ("inlayHint/resolve is not implemented");
    }

    /**
     * The shutdown request is sent from the client to the server. It asks
     * the server to shut down, but to not exit (otherwise the response
     * might not be delivered correctly to the client).
     *
     * There is a separate exit notification that asks the server to exit.
     * Clients must not send any notifications other than exit or requests
     * to a server to which they have sent a shutdown request. Clients
     * should also wait with sending the exit notification until they have
     * received a response from the shutdown request.
     *
     * The server will error with {@link Lsp.ProtocolError.INVALID_REQUEST} if
     * it receives any requests after a shutdown request.
     */
    protected abstract async void shutdown_async (Client client) throws Error;

    public virtual void exit () {
        if (loop != null)
            loop.quit ();
    }
}
