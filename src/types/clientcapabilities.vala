/* clientcapabilities.vala
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

namespace Lsp {
    /**
     * The kind of resource operations supported by the client.
     */
    public enum ResourceOperationKind {
        /**
         * Supports creating new files and folders
         */
        CREATE,

        /**
         * Supports renaming existing files and folders.
         */
        RENAME,

        /**
         * Supports deleting existing files and folders.
         */
        DELETE;

        public unowned string to_string () {
            switch (this) {
                case CREATE:
                    return "create";
                case RENAME:
                    return "rename";
                case DELETE:
                    return "delete";
            }

            assert_not_reached ();
        }
    }

    public enum FailureHandlingKind {
        UNSET,
        ABORT,
        TRANSACTIONAL,
        TEXT_ONLY_TRANSACTIONAL,
        UNDO;

        public unowned string to_string () {
            switch (this) {
                case UNSET:
                    assert_not_reached ();
                case ABORT:
                    return "abort";
                case TRANSACTIONAL:
                    return "transactional";
                case TEXT_ONLY_TRANSACTIONAL:
                    return "textOnlyTransactional";
                case UNDO:
                    return "undo";
            }

            assert_not_reached ();
        }

        public bool try_parse (string str, out FailureHandlingKind kind) {
            switch (str) {
                case "abort":
                    kind = ABORT;
                    return true;
                case "transactional":
                    kind = TRANSACTIONAL;
                    return true;
                case "textOnlyTransactional":
                    kind = TEXT_ONLY_TRANSACTIONAL;
                    return true;
                case "undo":
                    kind = UNDO;
                    return true;
                default:
                    kind = UNSET;
                    return false;
            }
        }
    }

    /**
     * Defines what workspace resource operations the client supports.
     *
     * @see WorkspaceEditClientCaps.resource_ops
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_workspace_edit_client_caps_ref",
        unref_function = "lsp_workspace_edit_client_caps_unref")]
    public class WorkspaceEditClientCaps {
        private int ref_count = 1;

        public unowned WorkspaceEditClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The client supports versioned document changes in {@link WorkspaceEdit}s
         */
        public bool document_changes { get; set; }

        /**
         * The resource operations the client supports. Clients should at least
         * support 'create' ({@link ResourceOperationKind.CREATE}), 'rename'
         * ({@link ResourceOperationKind.RENAME}) and 'delete'
         * ({@link ResourceOperationKind.DELETE}) files and folders.
         *
         * @see ResourceOperationKind
         * @since 3.13.0
         */
        public string[]? resource_ops { get; set; }

        /**
         * The failure handling strategy of a client if applying the workspace
         * edit fails.
         *
         * @since 3.13.0
         */
        public FailureHandlingKind failure_handling { get; set; }

        /**
         * Whether the client normalizes line endings to the client specific
         * setting.
         *
         * If set to `true` the client will normalize line ending characters in
         * a workspace edit to the client specific new line character(s).
         *
         * @since 3.16.0
         */
        public bool normalizes_line_endings { get; set; }

        /**
         * Whether the client supports change annotations.
         *
         * @since 3.16.0
         */
        public bool change_annotations { get; set; }

        /**
         * Whether the client groups edits with equal labels into tree nodes,
         * for instance all edits labelled with "Changes in Strings" would be a
         * tree node.
         */
        public bool change_annotations_group_on_label { get; set; }

        public WorkspaceEditClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;

            if ((prop = dict.lookup_value ("documentChanges", VariantType.BOOLEAN)) != null)
                document_changes = (bool) prop;

            if ((prop = dict.lookup_value ("resourceOperations", VariantType.ARRAY)) != null) {
                resource_ops = string_array_from_variant (
                    prop,
                    "WorkspaceEditClientCaps.resourceOperations");
            }

            if ((prop = dict.lookup_value ("failureHandling", VariantType.STRING)) != null) {
                FailureHandlingKind fh;
                if (FailureHandlingKind.UNSET.try_parse ((string) prop, out fh))
                    failure_handling = fh;
            }

            if ((prop = dict.lookup_value ("normalizesLineEndings", VariantType.BOOLEAN)) != null)
                normalizes_line_endings = (bool) prop;

            if ((prop = dict.lookup_value ("changeAnnotationSupport",
                VariantType.VARDICT)) != null) {
                change_annotations = true;
                Variant? ca_prop;
                if ((ca_prop = prop.lookup_value ("groupsOnLabel", VariantType.BOOLEAN)) != null)
                    change_annotations_group_on_label = (bool) ca_prop;
            }
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (document_changes)
                dict.insert_value ("documentChanges", true);
            if (resource_ops != null) {
                Variant[] ops = {};
                foreach (unowned var op in resource_ops)
                    ops += op;
                dict.insert_value ("resourceOperations",
                    new Variant.array (VariantType.STRING, ops));
            }
            if (failure_handling != FailureHandlingKind.UNSET)
                dict.insert_value ("failureHandling", failure_handling.to_string ());
            if (normalizes_line_endings)
                dict.insert_value ("normalizesLineEndings", true);
            if (change_annotations) {
                var ca_dict = new VariantDict ();
                if (change_annotations_group_on_label)
                    ca_dict.insert_value ("groupsOnLabel", true);
                dict.insert_value ("changeAnnotationSupport", ca_dict.end ());
            }

            return dict.end ();
        }
    }

    /**
     * Workspace-specific client capabilities.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_workspace_client_caps_ref",
        unref_function = "lsp_workspace_client_caps_unref")]
    public class WorkspaceClientCaps {
        private int ref_count = 1;

        public unowned WorkspaceClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The client supports applying batch edits to the workspace by
         * supporting the request 'workspace/applyEdit'
         */
        public bool apply_edit { get; set; }

        /**
         * Capabilities specific to {@link WorkspaceEdit}s.
         *
         * @since 3.13.0
         */
        public WorkspaceEditClientCaps? workspace_edit { get; set; }

        public WorkspaceClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;

            if ((prop = dict.lookup_value ("applyEdit", VariantType.BOOLEAN)) != null)
                apply_edit = (bool) prop;

            if ((prop = dict.lookup_value ("workspaceEdit", VariantType.VARDICT)) != null)
                workspace_edit = new WorkspaceEditClientCaps.from_variant (prop);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (apply_edit)
                dict.insert_value ("applyEdit", true);
            if (workspace_edit != null)
                dict.insert_value ("workspaceEdit", workspace_edit.to_variant ());

            return dict.end ();
        }
    }

    /**
     * Completion-specific client capabilities
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_completion_client_caps_ref",
        unref_function = "lsp_completion_client_caps_unref")]
    public class CompletionClientCaps {
        private int ref_count = 1;

        public unowned CompletionClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Client supports snippets as insert text.
         *
         * A snippet can define tab stops and placeholders with `$1`, `$2` and
         * `${3:foo}`. `$0` defines the final tab stop, it defaults to the end
         * of the snippet. Placeholders with equal identifiers are linked, that
         * is typing in one will update others too.
         */
        public bool snippets { get; set; }

        /**
         * Client supports commit characters on a completion item.
         */
        public bool commit_chars { get; set; }

        /**
         * Client supports the following content formats for the documentation
         * property. The order describes the preferred format of the client.
         */
        public MarkupKind[]? documentation_formats { get; set; }

        /**
         * Client supports the deprecated property on a completion item.
         */
        public bool deprecated_property { get; set; }

        /**
         * Client supports the preselect property on a completion item.
         */
        public bool preselect_property { get; set; }

        /**
         * Client supports the tag property on a completion item. Clients
         * supporting tags have to handle unknown tags gracefully. Clients
         * especially need to preserve unknown tags when sending a completion
         * item back to the server in a resolve call.
         *
         * @since 3.15.0
         */
        public CompletionItemTag supported_tags {
            get;
            set;
            default = NONE;
        }

        /**
         * Client supports insert replace edit to control different behavior if
         * a completion item is inserted in the text or should replace text.
         *
         * @since 3.16.0
         */
        public bool insert_replace { get; set; }

        /**
         * Indicates which properties a client can resolve lazily on a
         * completion item. Before version 3.16.0 only the predefined
         * properties `documentation` and `detail` could be resolved lazily.
         *
         * @since 3.16.0
         */
        public string[]? resolve_properties { get; set; }

        /**
         * The client supports the `insertTextMode` property on a completion
         * item to override the whitespace handling mode as defined by the
         * client (see `insertTextMode`).
         *
         * @since 3.16.0
         */
        public InsertTextMode[]? insert_text_modes { get; set; }

        /**
         * The completion item kind values the client supports. When this
         * property exists the client also guarantees that it will handle
         * values outside its set gracefully and falls back to a default value
         * when unknown.
         *
         * If this property is not present the client only supports the
         * completion items kinds from `Text` to `Reference` as defined in the
         * initial version of the protocol.
         */
        public CompletionItemKind[]? item_kinds { get; set; }

        /**
         * The client supports to send additional context information for a
         * `textDocument/completion` request.
         */
        public bool context { get; set; }

        /**
         * The client supports completion item label details.
         *
         * @since 3.17.0
         */
        public bool label_details { get; set; }

        public CompletionClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;
            Variant item_caps = dict;

            if ((prop = dict.lookup_value ("completionItem", VariantType.VARDICT)) != null)
                item_caps = prop;

            if ((prop = item_caps.lookup_value ("snippetSupport", VariantType.BOOLEAN)) != null)
                snippets = (bool) prop;
            else if ((prop = item_caps.lookup_value ("snippet", VariantType.BOOLEAN)) != null)
                snippets = (bool) prop;

            if ((prop = item_caps.lookup_value ("commitCharactersSupport",
                VariantType.BOOLEAN)) != null)
                commit_chars = (bool) prop;

            if ((prop = item_caps.lookup_value ("deprecatedSupport", VariantType.BOOLEAN)) != null)
                deprecated_property = (bool) prop;

            if ((prop = item_caps.lookup_value ("preselectSupport", VariantType.BOOLEAN)) != null)
                preselect_property = (bool) prop;

            if ((prop = item_caps.lookup_value ("insertReplaceSupport",
                VariantType.BOOLEAN)) != null)
                insert_replace = (bool) prop;

            if ((prop = dict.lookup_value ("contextSupport", VariantType.BOOLEAN)) != null)
                context = (bool) prop;

            if ((prop = item_caps.lookup_value ("labelDetailsSupport",
                VariantType.BOOLEAN)) != null)
                label_details = (bool) prop;

            if ((prop = item_caps.lookup_value ("resolveSupport", VariantType.VARDICT)) != null) {
                Variant? rp;
                if ((rp = prop.lookup_value ("properties", VariantType.ARRAY)) != null) {
                    resolve_properties = string_array_from_variant (
                        rp,
                        "CompletionClientCaps.resolveSupport.properties");
                }
            }

            if ((prop = item_caps.lookup_value ("documentationFormat",
                VariantType.ARRAY)) != null) {
                MarkupKind[] formats = {};
                foreach (var f in prop) {
                    var format = unwrap_variant (f);
                    if (format.is_of_type (VariantType.STRING)) {
                        switch ((string) format) {
                            case "plaintext":
                                formats += MarkupKind.PLAINTEXT;
                                break;
                            case "markdown":
                                formats += MarkupKind.MARKDOWN;
                                break;
                        }
                    } else if (format.is_of_type (VariantType.INT64))
                        formats += (MarkupKind) (int64) format;
                }
                documentation_formats = formats;
            }

            if ((prop = item_caps.lookup_value ("tagSupport", VariantType.VARDICT)) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    CompletionItemTag tags = CompletionItemTag.NONE;
                    foreach (var value in values) {
                        var tag = expect_array_element (
                            value,
                            VariantType.INT64,
                            "CompletionClientCaps.tagSupport.valueSet");
                        if ((int64) tag == CompletionItemTag.DEPRECATED)
                            tags |= CompletionItemTag.DEPRECATED;
                    }
                    supported_tags = tags;
                }
            }

            if ((prop = item_caps.lookup_value ("insertTextModeSupport",
                VariantType.VARDICT)) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    InsertTextMode[] modes = {};
                    foreach (var value in values)
                        modes += (InsertTextMode) (int64) expect_array_element (
                            value,
                            VariantType.INT64,
                            "CompletionClientCaps.insertTextModeSupport.valueSet");
                    insert_text_modes = modes;
                }
            }

            if ((prop = dict.lookup_value ("completionItemKind", VariantType.VARDICT)) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    CompletionItemKind[] kinds = {};
                    foreach (var value in values)
                        kinds += (CompletionItemKind) (int64) expect_array_element (
                            value,
                            VariantType.INT64,
                            "CompletionClientCaps.completionItemKind.valueSet");
                    item_kinds = kinds;
                }
            }
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            var item = new VariantDict ();
            bool has_item_caps = false;

            if (snippets) {
                item.insert_value ("snippetSupport", true);
                has_item_caps = true;
            }
            if (commit_chars) {
                item.insert_value ("commitCharactersSupport", true);
                has_item_caps = true;
            }
            if (deprecated_property) {
                item.insert_value ("deprecatedSupport", true);
                has_item_caps = true;
            }
            if (preselect_property) {
                item.insert_value ("preselectSupport", true);
                has_item_caps = true;
            }
            if (insert_replace) {
                item.insert_value ("insertReplaceSupport", true);
                has_item_caps = true;
            }
            if (label_details) {
                item.insert_value ("labelDetailsSupport", true);
                has_item_caps = true;
            }
            if (context)
                dict.insert_value ("contextSupport", true);
            if (resolve_properties != null) {
                var rp_dict = new VariantDict ();
                Variant[] props = {};
                foreach (unowned var p in resolve_properties)
                    props += p;
                rp_dict.insert_value ("properties", new Variant.array (VariantType.STRING, props));
                item.insert_value ("resolveSupport", rp_dict.end ());
                has_item_caps = true;
            }
            if (documentation_formats != null) {
                Variant[] formats = {};
                foreach (unowned var f in documentation_formats)
                    formats += f.to_string ();
                item.insert_value (
                    "documentationFormat",
                    new Variant.array (VariantType.STRING, formats));
                has_item_caps = true;
            }
            if (supported_tags != CompletionItemTag.NONE) {
                var tag_support = new VariantDict ();
                Variant[] tags = {};
                if (CompletionItemTag.DEPRECATED in supported_tags)
                    tags += new Variant.int64 (
                        CompletionItemTag.DEPRECATED);
                tag_support.insert_value ("valueSet", tags);
                item.insert_value ("tagSupport", tag_support.end ());
                has_item_caps = true;
            }
            if (insert_text_modes != null) {
                var mode_support = new VariantDict ();
                Variant[] modes = {};
                foreach (var mode in insert_text_modes)
                    modes += new Variant.int64 (mode);
                mode_support.insert_value ("valueSet", modes);
                item.insert_value (
                    "insertTextModeSupport",
                    mode_support.end ());
                has_item_caps = true;
            }
            if (has_item_caps)
                dict.insert_value ("completionItem", item.end ());

            if (item_kinds != null) {
                var kind_support = new VariantDict ();
                Variant[] kinds = {};
                foreach (var kind in item_kinds)
                    kinds += new Variant.int64 (kind);
                kind_support.insert_value ("valueSet", kinds);
                dict.insert_value (
                    "completionItemKind",
                    kind_support.end ());
            }

            return dict.end ();
        }
    }

    /**
     * Client capabilities for document symbols.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_document_symbol_client_caps_ref",
        unref_function = "lsp_document_symbol_client_caps_unref")]
    public class DocumentSymbolClientCaps {
        private int ref_count = 1;

        public unowned DocumentSymbolClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public bool dynamic_registration { get; set; }
        public SymbolKind[]? symbol_kinds { get; set; }
        public bool hierarchical_document_symbol_support { get; set; }
        public SymbolTag supported_tags { get; set; default = UNSET; }
        public bool label_support { get; set; }

        public DocumentSymbolClientCaps () {
        }

        public DocumentSymbolClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;

            if ((prop = lookup_property (dict, "dynamicRegistration", VariantType.BOOLEAN,
                "DocumentSymbolClientCaps")) != null)
                dynamic_registration = (bool) prop;

            if ((prop = lookup_property (dict, "symbolKind", VariantType.VARDICT,
                "DocumentSymbolClientCaps")) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    SymbolKind[] kinds = {};
                    foreach (var value in values)
                        kinds += (SymbolKind) (int64) expect_array_element (
                            value,
                            VariantType.INT64,
                            "DocumentSymbolClientCaps.symbolKind.valueSet");
                    symbol_kinds = kinds;
                }
            }

            if ((prop = lookup_property (dict, "hierarchicalDocumentSymbolSupport",
                VariantType.BOOLEAN, "DocumentSymbolClientCaps")) != null)
                hierarchical_document_symbol_support = (bool) prop;

            if ((prop = lookup_property (dict, "tagSupport", VariantType.VARDICT,
                "DocumentSymbolClientCaps")) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    SymbolTag tags = SymbolTag.UNSET;
                    foreach (var value in values) {
                        var tag = expect_array_element (
                            value,
                            VariantType.INT64,
                            "DocumentSymbolClientCaps.tagSupport.valueSet");
                        tags |= (SymbolTag) (int) tag.get_int64 ();
                    }
                    supported_tags = tags;
                }
            }

            if ((prop = lookup_property (dict, "labelSupport", VariantType.BOOLEAN,
                "DocumentSymbolClientCaps")) != null)
                label_support = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (dynamic_registration)
                dict.insert_value ("dynamicRegistration", true);
            if (symbol_kinds != null) {
                Variant[] values = {};
                foreach (var kind in symbol_kinds)
                    values += new Variant.int64 (kind);
                var symbol_kind = new VariantDict ();
                symbol_kind.insert_value ("valueSet", values);
                dict.insert_value ("symbolKind", symbol_kind.end ());
            }
            if (hierarchical_document_symbol_support)
                dict.insert_value ("hierarchicalDocumentSymbolSupport", true);
            if (supported_tags != SymbolTag.UNSET) {
                Variant[] values = {};
                if (SymbolTag.DEPRECATED in supported_tags)
                    values += new Variant.int64 (SymbolTag.DEPRECATED);
                var tag_support = new VariantDict ();
                tag_support.insert_value ("valueSet", values);
                dict.insert_value ("tagSupport", tag_support.end ());
            }
            if (label_support)
                dict.insert_value ("labelSupport", true);
            return dict.end ();
        }
    }

    /**
     * Default behavior advertised for prepare rename.
     */
    public enum PrepareSupportDefaultBehavior {
        UNSET = 0,
        IDENTIFIER = 1
    }

    /**
     * Client capabilities for renaming symbols.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_rename_client_caps_ref",
        unref_function = "lsp_rename_client_caps_unref")]
    public class RenameClientCaps {
        private int ref_count = 1;

        public unowned RenameClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public bool dynamic_registration { get; set; }
        public bool prepare_support { get; set; }
        public PrepareSupportDefaultBehavior prepare_support_default_behavior {
            get;
            set;
            default = UNSET;
        }
        public bool honors_change_annotations { get; set; }

        public RenameClientCaps () {
        }

        public RenameClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;
            if ((prop = lookup_property (dict, "dynamicRegistration", VariantType.BOOLEAN,
                "RenameClientCaps")) != null)
                dynamic_registration = (bool) prop;
            if ((prop = lookup_property (dict, "prepareSupport", VariantType.BOOLEAN,
                "RenameClientCaps")) != null)
                prepare_support = (bool) prop;
            if ((prop = lookup_property (dict, "prepareSupportDefaultBehavior",
                VariantType.INT64, "RenameClientCaps")) != null)
                prepare_support_default_behavior = (PrepareSupportDefaultBehavior) (int64) prop;
            if ((prop = lookup_property (dict, "honorsChangeAnnotations", VariantType.BOOLEAN,
                "RenameClientCaps")) != null)
                honors_change_annotations = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (dynamic_registration)
                dict.insert_value ("dynamicRegistration", true);
            if (prepare_support)
                dict.insert_value ("prepareSupport", true);
            if (prepare_support_default_behavior != PrepareSupportDefaultBehavior.UNSET)
                dict.insert_value ("prepareSupportDefaultBehavior",
                    new Variant.int64 (prepare_support_default_behavior));
            if (honors_change_annotations)
                dict.insert_value ("honorsChangeAnnotations", true);
            return dict.end ();
        }
    }

    /**
     * Client capabilities for type hierarchy requests.
     */
    [Compact (opaque = true)]
    [CCode (lower_case_cprefix = "lsp_type_hierarchy_client_caps_",
        ref_function = "lsp_type_hierarchy_client_caps_ref",
        unref_function = "lsp_type_hierarchy_client_caps_unref")]
    public class TypeHierarchyClientCaps {
        private int ref_count = 1;

        public unowned TypeHierarchyClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public bool dynamic_registration { get; set; }

        public TypeHierarchyClientCaps () {
        }

        public TypeHierarchyClientCaps.from_variant (Variant dict) throws DeserializeError {
            var prop = lookup_property (dict, "dynamicRegistration", VariantType.BOOLEAN,
                "TypeHierarchyClientCaps");
            if (prop != null)
                dynamic_registration = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (dynamic_registration)
                dict.insert_value ("dynamicRegistration", true);
            return dict.end ();
        }
    }

    [Flags]
    public enum TextDocumentSyncClientCaps {
        NONE = 0,

        /**
         * The client supports sending 'will save' notifications.
         */
        WILL_SAVE = 1 << 0,

        /**
         * The client supports sending a 'will save' request and waits for
         * a response providing text edits which will be applied to the
         * document before it is saved.
         */
        WILL_SAVE_WAIT_UNTIL = 1 << 1,

        /**
         * The client supports 'did save' notifications.
         */
        DID_SAVE = 1 << 2
    }

    /**
     * Text document-specific client capabilities.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_text_document_client_caps_ref",
        unref_function = "lsp_text_document_client_caps_unref")]
    public class TextDocumentClientCaps {
        private int ref_count = 1;

        public unowned TextDocumentClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public TextDocumentSyncClientCaps synchronization {
            get;
            set;
            default = NONE;
        }

        public CompletionClientCaps? completion { get; set; }
        public DocumentSymbolClientCaps? document_symbol { get; set; }
        public RenameClientCaps? rename { get; set; }
        public TypeHierarchyClientCaps? type_hierarchy { get; set; }

        public TextDocumentClientCaps () {
        }

        public TextDocumentClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;

            if ((prop = dict.lookup_value ("synchronization", VariantType.VARDICT)) != null) {
                var sync_flags = TextDocumentSyncClientCaps.NONE;
                Variant? sync_prop;
                if ((sync_prop = prop.lookup_value ("willSave",
                    VariantType.BOOLEAN)) != null && (bool) sync_prop)
                    sync_flags |= TextDocumentSyncClientCaps.WILL_SAVE;
                if ((sync_prop = prop.lookup_value ("willSaveWaitUntil",
                    VariantType.BOOLEAN)) != null && (bool) sync_prop)
                    sync_flags |= TextDocumentSyncClientCaps.WILL_SAVE_WAIT_UNTIL;
                if ((sync_prop = prop.lookup_value ("didSave",
                    VariantType.BOOLEAN)) != null && (bool) sync_prop)
                    sync_flags |= TextDocumentSyncClientCaps.DID_SAVE;
                synchronization = sync_flags;
            }

            if ((prop = dict.lookup_value ("completion", VariantType.VARDICT)) != null)
                completion = new CompletionClientCaps.from_variant (prop);
            if ((prop = dict.lookup_value ("documentSymbol", VariantType.VARDICT)) != null)
                document_symbol = new DocumentSymbolClientCaps.from_variant (prop);
            if ((prop = dict.lookup_value ("rename", VariantType.VARDICT)) != null)
                rename = new RenameClientCaps.from_variant (prop);
            if ((prop = dict.lookup_value ("typeHierarchy", VariantType.VARDICT)) != null)
                type_hierarchy = new TypeHierarchyClientCaps.from_variant (prop);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (synchronization != TextDocumentSyncClientCaps.NONE) {
                var sync_dict = new VariantDict ();
                if (TextDocumentSyncClientCaps.WILL_SAVE in synchronization)
                    sync_dict.insert_value ("willSave", true);
                if (TextDocumentSyncClientCaps.WILL_SAVE_WAIT_UNTIL in synchronization)
                    sync_dict.insert_value ("willSaveWaitUntil", true);
                if (TextDocumentSyncClientCaps.DID_SAVE in synchronization)
                    sync_dict.insert_value ("didSave", true);
                dict.insert_value ("synchronization", sync_dict.end ());
            }

            if (completion != null)
                dict.insert_value ("completion", completion.to_variant ());
            if (document_symbol != null)
                dict.insert_value ("documentSymbol", document_symbol.to_variant ());
            if (rename != null)
                dict.insert_value ("rename", rename.to_variant ());
            if (type_hierarchy != null)
                dict.insert_value ("typeHierarchy", type_hierarchy.to_variant ());

            return dict.end ();
        }
    }

    /**
     * Capabilities of the client / editor.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_client_caps_ref", unref_function = "lsp_client_caps_unref")]
    public class ClientCaps {
        private int ref_count = 1;

        public unowned ClientCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Workspace-specific client capabilities.
         */
        public WorkspaceClientCaps? workspace { get; set; }

        /**
         * Text document-specific client capabilities.
         */
        public TextDocumentClientCaps? text_document { get; set; }

        public ClientCaps () {
        }

        public ClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;

            if ((prop = dict.lookup_value ("workspace", VariantType.VARDICT)) != null)
                workspace = new WorkspaceClientCaps.from_variant (prop);

            if ((prop = dict.lookup_value ("textDocument", VariantType.VARDICT)) != null)
                text_document = new TextDocumentClientCaps.from_variant (prop);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (workspace != null)
                dict.insert_value ("workspace", workspace.to_variant ());
            if (text_document != null)
                dict.insert_value ("textDocument", text_document.to_variant ());

            return dict.end ();
        }
    }
}
