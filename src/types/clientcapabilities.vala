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
    [Flags]
    public enum ResourceOperationKind {
        NONE = 0,

        /**
         * Supports creating new files and folders
         */
        CREATE = 1,

        /**
         * Supports renaming existing files and folders.
         */
        RENAME = 2,

        /**
         * Supports deleting existing files and folders.
         */
        DELETE = 4;

        public unowned string to_string () {
            switch (this) {
                case NONE:
                    assert_not_reached ();
                case CREATE:
                    return "create";
                case RENAME:
                    return "rename";
                case DELETE:
                    return "delete";
            }

            assert_not_reached ();
        }

        public bool try_parse (string str, out ResourceOperationKind kind) {
            switch (str) {
                case "create":
                    kind = CREATE;
                    return true;
                case "rename":
                    kind = RENAME;
                    return true;
                case "delete":
                    kind = DELETE;
                    return true;
                default:
                    kind = NONE;
                    return false;
            }
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
     * Boolean workspace edit capabilities.
     */
    [Flags]
    public enum WorkspaceEditClientFlags {
        NONE = 0,
        DOCUMENT_CHANGES = 1,
        NORMALIZES_LINE_ENDINGS = 2,
        CHANGE_ANNOTATIONS = 4,
        CHANGE_ANNOTATIONS_GROUP_ON_LABEL = 8
    }

    /**
     * Defines what workspace resource operations the client supports.
     *
     * This is a value type because all of its capabilities fit in flags and
     * enums. It can therefore be embedded in {@link WorkspaceClientCaps}
     * without another allocation.
     */
    public struct WorkspaceEditClientCaps {

        /**
         * The client supports versioned document changes in {@link WorkspaceEdit}s
         */
        public WorkspaceEditClientFlags flags { get; set; }

        /**
         * The resource operations the client supports. Clients should at least
         * support 'create' ({@link ResourceOperationKind.CREATE}), 'rename'
         * ({@link ResourceOperationKind.RENAME}) and 'delete'
         * ({@link ResourceOperationKind.DELETE}) files and folders.
         *
         * @see ResourceOperationKind
         * @since 3.13.0
         */
        public ResourceOperationKind resource_ops { get; set; }

        /**
         * The failure handling strategy of a client if applying the workspace
         * edit fails.
         *
         * @since 3.13.0
         */
        public FailureHandlingKind failure_handling { get; set; }

        public WorkspaceEditClientCaps (
            WorkspaceEditClientFlags flags = WorkspaceEditClientFlags.NONE,
            ResourceOperationKind resource_ops = ResourceOperationKind.NONE,
            FailureHandlingKind failure_handling = FailureHandlingKind.UNSET
        ) {
            this.flags = flags;
            this.resource_ops = resource_ops;
            this.failure_handling = failure_handling;
        }

        public WorkspaceEditClientCaps.from_variant (Variant dict) throws DeserializeError {
            this ();
            Variant? prop;

            if ((prop = dict.lookup_value ("documentChanges",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= WorkspaceEditClientFlags.DOCUMENT_CHANGES;

            if ((prop = dict.lookup_value ("resourceOperations", VariantType.ARRAY)) != null) {
                foreach (var operation_value in prop) {
                    var operation = expect_array_element (
                        operation_value,
                        VariantType.STRING,
                        "WorkspaceEditClientCaps.resourceOperations");
                    ResourceOperationKind kind;
                    if (ResourceOperationKind.NONE.try_parse ((string) operation, out kind))
                        resource_ops |= kind;
                }
            }

            if ((prop = dict.lookup_value ("failureHandling", VariantType.STRING)) != null) {
                FailureHandlingKind fh;
                if (FailureHandlingKind.UNSET.try_parse ((string) prop, out fh))
                    failure_handling = fh;
            }

            if ((prop = dict.lookup_value ("normalizesLineEndings",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= WorkspaceEditClientFlags.NORMALIZES_LINE_ENDINGS;

            if ((prop = dict.lookup_value ("changeAnnotationSupport",
                VariantType.VARDICT)) != null) {
                flags |= WorkspaceEditClientFlags.CHANGE_ANNOTATIONS;
                Variant? ca_prop;
                if ((ca_prop = prop.lookup_value ("groupsOnLabel",
                    VariantType.BOOLEAN)) != null && (bool) ca_prop)
                    flags |= WorkspaceEditClientFlags.CHANGE_ANNOTATIONS_GROUP_ON_LABEL;
            }
        }

        internal bool is_empty () {
            return flags == WorkspaceEditClientFlags.NONE &&
                   resource_ops == ResourceOperationKind.NONE &&
                   failure_handling == FailureHandlingKind.UNSET;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (WorkspaceEditClientFlags.DOCUMENT_CHANGES in flags)
                dict.insert_value ("documentChanges", true);
            if (resource_ops != ResourceOperationKind.NONE) {
                Variant[] ops = {};
                if (ResourceOperationKind.CREATE in resource_ops)
                    ops += ResourceOperationKind.CREATE.to_string ();
                if (ResourceOperationKind.RENAME in resource_ops)
                    ops += ResourceOperationKind.RENAME.to_string ();
                if (ResourceOperationKind.DELETE in resource_ops)
                    ops += ResourceOperationKind.DELETE.to_string ();
                dict.insert_value ("resourceOperations",
                    new Variant.array (VariantType.STRING, ops));
            }
            if (failure_handling != FailureHandlingKind.UNSET)
                dict.insert_value ("failureHandling", failure_handling.to_string ());
            if (WorkspaceEditClientFlags.NORMALIZES_LINE_ENDINGS in flags)
                dict.insert_value ("normalizesLineEndings", true);
            if (WorkspaceEditClientFlags.CHANGE_ANNOTATIONS in flags ||
                WorkspaceEditClientFlags.CHANGE_ANNOTATIONS_GROUP_ON_LABEL in flags) {
                var ca_dict = new VariantDict ();
                if (WorkspaceEditClientFlags.CHANGE_ANNOTATIONS_GROUP_ON_LABEL in flags)
                    ca_dict.insert_value ("groupsOnLabel", true);
                dict.insert_value ("changeAnnotationSupport", ca_dict.end ());
            }

            return dict.end ();
        }
    }

    [Flags]
    public enum WorkspaceClientFlags {
        NONE = 0,
        APPLY_EDIT = 1
    }

    /**
     * Workspace-specific client capabilities.
     */
    public struct WorkspaceClientCaps {

        /**
         * The client supports applying batch edits to the workspace by
         * supporting the request 'workspace/applyEdit'
         */
        public WorkspaceClientFlags flags { get; set; }

        /**
         * Capabilities specific to {@link WorkspaceEdit}s.
         *
         * @since 3.13.0
         */
        public WorkspaceEditClientCaps workspace_edit { get; set; }

        public WorkspaceClientCaps (
            WorkspaceClientFlags flags = WorkspaceClientFlags.NONE
        ) {
            this.flags = flags;
            workspace_edit = WorkspaceEditClientCaps ();
        }

        public WorkspaceClientCaps.with_workspace_edit (
            WorkspaceEditClientCaps workspace_edit,
            WorkspaceClientFlags flags = WorkspaceClientFlags.NONE
        ) {
            this.flags = flags;
            this.workspace_edit = workspace_edit;
        }

        public WorkspaceClientCaps.from_variant (Variant dict) throws DeserializeError {
            this ();
            Variant? prop;

            if ((prop = dict.lookup_value ("applyEdit",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= WorkspaceClientFlags.APPLY_EDIT;

            if ((prop = dict.lookup_value ("workspaceEdit", VariantType.VARDICT)) != null)
                workspace_edit = WorkspaceEditClientCaps.from_variant (prop);
        }

        internal bool is_empty () {
            return flags == WorkspaceClientFlags.NONE && workspace_edit.is_empty ();
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (WorkspaceClientFlags.APPLY_EDIT in flags)
                dict.insert_value ("applyEdit", true);
            if (!workspace_edit.is_empty ())
                dict.insert_value ("workspaceEdit", workspace_edit.to_variant ());

            return dict.end ();
        }
    }

    /**
     * Boolean completion capabilities.
     */
    [Flags]
    public enum CompletionClientFlags {
        NONE = 0,
        SNIPPETS = 1,
        COMMIT_CHARACTERS = 2,
        DEPRECATED_PROPERTY = 4,
        PRESELECT_PROPERTY = 8,
        INSERT_REPLACE = 16,
        CONTEXT = 32,
        LABEL_DETAILS = 64
    }

    /**
     * Completion-specific client capabilities.
     *
     * This remains ref-counted because documentation formats are ordered by
     * preference and resolve property names are extensible protocol strings.
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
         * Boolean completion capabilities supported by the client.
         */
        public CompletionClientFlags flags { get; set; default = NONE; }

        /**
         * Client supports the following content formats for the documentation
         * property. The order describes the preferred format of the client.
         */
        private MarkupKind[]? _documentation_formats;
        public MarkupKind[]? documentation_formats {
            get {
                return _documentation_formats;
            }
            set {
                _documentation_formats = value;
            }
        }

        /**
         * Appends a content format to {@link documentation_formats}.
         */
        public void add_documentation_format (MarkupKind format) {
            _documentation_formats += format;
        }

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
         * Indicates which properties a client can resolve lazily on a
         * completion item. Before version 3.16.0 only the predefined
         * properties `documentation` and `detail` could be resolved lazily.
         *
         * @since 3.16.0
         */
        private string[]? _resolve_properties;
        public string[]? resolve_properties {
            get {
                return _resolve_properties;
            }
            set {
                _resolve_properties = value;
            }
        }

        /**
         * Appends a property name to {@link resolve_properties}.
         */
        public void add_resolve_property (string property) {
            _resolve_properties += property;
        }

        /**
         * The client supports the `insertTextMode` property on a completion
         * item to override the whitespace handling mode as defined by the
         * client (see `insertTextMode`).
         *
         * @since 3.16.0
         */
        public InsertTextModeFlags insert_text_modes { get; set; default = NONE; }

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
        public CompletionItemKindFlags item_kinds { get; set; default = NONE; }

        public CompletionClientCaps.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;
            Variant item_caps = dict;

            if ((prop = dict.lookup_value ("completionItem", VariantType.VARDICT)) != null)
                item_caps = prop;

            if ((prop = item_caps.lookup_value ("snippetSupport", VariantType.BOOLEAN)) != null)
                flags |= (bool) prop ? CompletionClientFlags.SNIPPETS : CompletionClientFlags.NONE;
            else if ((prop = item_caps.lookup_value ("snippet", VariantType.BOOLEAN)) != null)
                flags |= (bool) prop ? CompletionClientFlags.SNIPPETS : CompletionClientFlags.NONE;

            if ((prop = item_caps.lookup_value ("commitCharactersSupport",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= CompletionClientFlags.COMMIT_CHARACTERS;

            if ((prop = item_caps.lookup_value ("deprecatedSupport",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= CompletionClientFlags.DEPRECATED_PROPERTY;

            if ((prop = item_caps.lookup_value ("preselectSupport",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= CompletionClientFlags.PRESELECT_PROPERTY;

            if ((prop = item_caps.lookup_value ("insertReplaceSupport",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= CompletionClientFlags.INSERT_REPLACE;

            if ((prop = dict.lookup_value ("contextSupport",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= CompletionClientFlags.CONTEXT;

            if ((prop = item_caps.lookup_value ("labelDetailsSupport",
                VariantType.BOOLEAN)) != null && (bool) prop)
                flags |= CompletionClientFlags.LABEL_DETAILS;

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
                    InsertTextModeFlags modes = InsertTextModeFlags.NONE;
                    foreach (var value in values) {
                        var mode = (int) (int64) expect_array_element (
                            value,
                            VariantType.INT64,
                            "CompletionClientCaps.insertTextModeSupport.valueSet");
                        if (mode >= InsertTextMode.AS_IS &&
                            mode <= InsertTextMode.ADJUST_INDENTATION)
                            modes |= (InsertTextModeFlags) (1 << (mode - 1));
                    }
                    insert_text_modes = modes;
                }
            }

            if ((prop = dict.lookup_value ("completionItemKind", VariantType.VARDICT)) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    CompletionItemKindFlags kinds = CompletionItemKindFlags.NONE;
                    foreach (var value in values) {
                        var kind = (int) (int64) expect_array_element (
                            value,
                            VariantType.INT64,
                            "CompletionClientCaps.completionItemKind.valueSet");
                        if (kind >= CompletionItemKind.TEXT &&
                            kind <= CompletionItemKind.TYPE_PARAMETER)
                            kinds |= (CompletionItemKindFlags) (1 << (kind - 1));
                    }
                    item_kinds = kinds;
                }
            }
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            var item = new VariantDict ();
            bool has_item_caps = false;

            if (CompletionClientFlags.SNIPPETS in flags) {
                item.insert_value ("snippetSupport", true);
                has_item_caps = true;
            }
            if (CompletionClientFlags.COMMIT_CHARACTERS in flags) {
                item.insert_value ("commitCharactersSupport", true);
                has_item_caps = true;
            }
            if (CompletionClientFlags.DEPRECATED_PROPERTY in flags) {
                item.insert_value ("deprecatedSupport", true);
                has_item_caps = true;
            }
            if (CompletionClientFlags.PRESELECT_PROPERTY in flags) {
                item.insert_value ("preselectSupport", true);
                has_item_caps = true;
            }
            if (CompletionClientFlags.INSERT_REPLACE in flags) {
                item.insert_value ("insertReplaceSupport", true);
                has_item_caps = true;
            }
            if (CompletionClientFlags.LABEL_DETAILS in flags) {
                item.insert_value ("labelDetailsSupport", true);
                has_item_caps = true;
            }
            if (CompletionClientFlags.CONTEXT in flags)
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
            if (insert_text_modes != InsertTextModeFlags.NONE) {
                var mode_support = new VariantDict ();
                Variant[] modes = {};
                if (InsertTextModeFlags.AS_IS in insert_text_modes)
                    modes += new Variant.int64 (InsertTextMode.AS_IS);
                if (InsertTextModeFlags.ADJUST_INDENTATION in insert_text_modes)
                    modes += new Variant.int64 (InsertTextMode.ADJUST_INDENTATION);
                mode_support.insert_value ("valueSet", modes);
                item.insert_value (
                    "insertTextModeSupport",
                    mode_support.end ());
                has_item_caps = true;
            }
            if (has_item_caps)
                dict.insert_value ("completionItem", item.end ());

            if (item_kinds != CompletionItemKindFlags.NONE) {
                var kind_support = new VariantDict ();
                Variant[] kinds = {};
                for (int kind = CompletionItemKind.TEXT;
                     kind <= CompletionItemKind.TYPE_PARAMETER;
                     kind++) {
                    var flag = (CompletionItemKindFlags) (1 << (kind - 1));
                    if (flag in item_kinds)
                        kinds += new Variant.int64 (kind);
                }
                kind_support.insert_value ("valueSet", kinds);
                dict.insert_value (
                    "completionItemKind",
                    kind_support.end ());
            }

            return dict.end ();
        }
    }

    /**
     * Boolean document symbol capabilities.
     */
    [Flags]
    public enum DocumentSymbolClientFlags {
        NONE = 0,
        DYNAMIC_REGISTRATION = 1,
        HIERARCHICAL_DOCUMENT_SYMBOLS = 2,
        LABEL = 4,

        /**
         * Records the presence of the protocol capability object. Struct
         * constructors set this automatically; an all-zero embedded value is
         * absent.
         */
        SUPPORTED = 8
    }

    /**
     * Client capabilities for document symbols.
     *
     * Kind support is stored as a bitfield, so this value can be embedded in
     * {@link TextDocumentClientCaps} without an allocation.
     */
    public struct DocumentSymbolClientCaps {
        public DocumentSymbolClientFlags flags { get; set; }
        public SymbolKindFlags symbol_kinds { get; set; }
        public SymbolTag supported_tags { get; set; }

        public DocumentSymbolClientCaps (
            DocumentSymbolClientFlags flags = DocumentSymbolClientFlags.NONE,
            SymbolKindFlags symbol_kinds = SymbolKindFlags.NONE,
            SymbolTag supported_tags = SymbolTag.UNSET
        ) {
            this.flags = flags | DocumentSymbolClientFlags.SUPPORTED;
            this.symbol_kinds = symbol_kinds;
            this.supported_tags = supported_tags;
        }

        public DocumentSymbolClientCaps.from_variant (Variant dict) throws DeserializeError {
            this ();
            Variant? prop;

            if ((prop = lookup_property (dict, "dynamicRegistration", VariantType.BOOLEAN,
                "DocumentSymbolClientCaps")) != null && (bool) prop)
                flags |= DocumentSymbolClientFlags.DYNAMIC_REGISTRATION;

            if ((prop = lookup_property (dict, "symbolKind", VariantType.VARDICT,
                "DocumentSymbolClientCaps")) != null) {
                var values = prop.lookup_value ("valueSet", VariantType.ARRAY);
                if (values != null) {
                    SymbolKindFlags kinds = SymbolKindFlags.NONE;
                    foreach (var value in values) {
                        var kind = (int) (int64) expect_array_element (
                            value,
                            VariantType.INT64,
                            "DocumentSymbolClientCaps.symbolKind.valueSet");
                        if (kind >= SymbolKind.FILE && kind <= SymbolKind.TYPE_PARAMETER)
                            kinds |= (SymbolKindFlags) (1 << (kind - 1));
                    }
                    symbol_kinds = kinds;
                }
            }

            if ((prop = lookup_property (dict, "hierarchicalDocumentSymbolSupport",
                VariantType.BOOLEAN, "DocumentSymbolClientCaps")) != null && (bool) prop)
                flags |= DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS;

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
                "DocumentSymbolClientCaps")) != null && (bool) prop)
                flags |= DocumentSymbolClientFlags.LABEL;
        }

        internal bool is_empty () {
            return flags == DocumentSymbolClientFlags.NONE &&
                   symbol_kinds == SymbolKindFlags.NONE &&
                   supported_tags == SymbolTag.UNSET;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (DocumentSymbolClientFlags.DYNAMIC_REGISTRATION in flags)
                dict.insert_value ("dynamicRegistration", true);
            if (symbol_kinds != SymbolKindFlags.NONE) {
                Variant[] values = {};
                for (int kind = SymbolKind.FILE; kind <= SymbolKind.TYPE_PARAMETER; kind++) {
                    var flag = (SymbolKindFlags) (1 << (kind - 1));
                    if (flag in symbol_kinds)
                        values += new Variant.int64 (kind);
                }
                var symbol_kind = new VariantDict ();
                symbol_kind.insert_value ("valueSet", values);
                dict.insert_value ("symbolKind", symbol_kind.end ());
            }
            if (DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS in flags)
                dict.insert_value ("hierarchicalDocumentSymbolSupport", true);
            if (supported_tags != SymbolTag.UNSET) {
                Variant[] values = {};
                if (SymbolTag.DEPRECATED in supported_tags)
                    values += new Variant.int64 (SymbolTag.DEPRECATED);
                var tag_support = new VariantDict ();
                tag_support.insert_value ("valueSet", values);
                dict.insert_value ("tagSupport", tag_support.end ());
            }
            if (DocumentSymbolClientFlags.LABEL in flags)
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
     *
     * `SUPPORTED` records the presence of the protocol capability object, so
     * an empty object remains distinguishable from an unsupported feature.
     */
    [Flags]
    public enum RenameClientCaps {
        NONE = 0,
        SUPPORTED = 1,
        DYNAMIC_REGISTRATION = 2,
        PREPARE_SUPPORT = 4,
        HONORS_CHANGE_ANNOTATIONS = 8
    }

    /**
     * Client capabilities for type hierarchy requests.
     *
     * `SUPPORTED` records the presence of the protocol capability object.
     */
    [Flags]
    public enum TypeHierarchyClientCaps {
        NONE = 0,
        SUPPORTED = 1,
        DYNAMIC_REGISTRATION = 2
    }

    [Flags]
    public enum TextDocumentSyncClientCaps {
        NONE = 0,

        /**
         * The client supports sending 'will save' notifications.
         */
        WILL_SAVE = 1,

        /**
         * The client supports sending a 'will save' request and waits for
         * a response providing text edits which will be applied to the
         * document before it is saved.
         */
        WILL_SAVE_WAIT_UNTIL = 2,

        /**
         * The client supports 'did save' notifications.
         */
        DID_SAVE = 4
    }

    /**
     * Text document-specific client capabilities.
     *
     * This remains ref-counted because completion capabilities contain owned
     * arrays.
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
        public DocumentSymbolClientCaps document_symbol { get; set; }
        public RenameClientCaps rename { get; set; default = NONE; }
        public PrepareSupportDefaultBehavior rename_prepare_support_default_behavior {
            get;
            set;
            default = UNSET;
        }
        public TypeHierarchyClientCaps type_hierarchy { get; set; default = NONE; }

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
                document_symbol = DocumentSymbolClientCaps.from_variant (prop);
            if ((prop = dict.lookup_value ("rename", VariantType.VARDICT)) != null) {
                rename = RenameClientCaps.SUPPORTED;
                Variant? rename_prop;
                if ((rename_prop = lookup_property (prop, "dynamicRegistration",
                    VariantType.BOOLEAN, "RenameClientCaps")) != null && (bool) rename_prop)
                    rename |= RenameClientCaps.DYNAMIC_REGISTRATION;
                if ((rename_prop = lookup_property (prop, "prepareSupport",
                    VariantType.BOOLEAN, "RenameClientCaps")) != null && (bool) rename_prop)
                    rename |= RenameClientCaps.PREPARE_SUPPORT;
                if ((rename_prop = lookup_property (prop, "prepareSupportDefaultBehavior",
                    VariantType.INT64, "RenameClientCaps")) != null)
                    rename_prepare_support_default_behavior =
                        (PrepareSupportDefaultBehavior) (int64) rename_prop;
                if ((rename_prop = lookup_property (prop, "honorsChangeAnnotations",
                    VariantType.BOOLEAN, "RenameClientCaps")) != null && (bool) rename_prop)
                    rename |= RenameClientCaps.HONORS_CHANGE_ANNOTATIONS;
            }
            if ((prop = dict.lookup_value ("typeHierarchy", VariantType.VARDICT)) != null) {
                type_hierarchy = TypeHierarchyClientCaps.SUPPORTED;
                var hierarchy_prop = lookup_property (prop, "dynamicRegistration",
                    VariantType.BOOLEAN, "TypeHierarchyClientCaps");
                if (hierarchy_prop != null && (bool) hierarchy_prop)
                    type_hierarchy |= TypeHierarchyClientCaps.DYNAMIC_REGISTRATION;
            }
        }

        internal bool is_empty () {
            return synchronization == TextDocumentSyncClientCaps.NONE &&
                   completion == null &&
                   document_symbol.is_empty () &&
                   rename == RenameClientCaps.NONE &&
                   rename_prepare_support_default_behavior ==
                   PrepareSupportDefaultBehavior.UNSET &&
                   type_hierarchy == TypeHierarchyClientCaps.NONE;
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
            if (!document_symbol.is_empty ())
                dict.insert_value ("documentSymbol", document_symbol.to_variant ());
            if (rename != RenameClientCaps.NONE ||
                rename_prepare_support_default_behavior !=
                PrepareSupportDefaultBehavior.UNSET) {
                var rename_dict = new VariantDict ();
                if (RenameClientCaps.DYNAMIC_REGISTRATION in rename)
                    rename_dict.insert_value ("dynamicRegistration", true);
                if (RenameClientCaps.PREPARE_SUPPORT in rename)
                    rename_dict.insert_value ("prepareSupport", true);
                if (rename_prepare_support_default_behavior !=
                    PrepareSupportDefaultBehavior.UNSET)
                    rename_dict.insert_value ("prepareSupportDefaultBehavior",
                        new Variant.int64 (rename_prepare_support_default_behavior));
                if (RenameClientCaps.HONORS_CHANGE_ANNOTATIONS in rename)
                    rename_dict.insert_value ("honorsChangeAnnotations", true);
                dict.insert_value ("rename", rename_dict.end ());
            }
            if (type_hierarchy != TypeHierarchyClientCaps.NONE) {
                var hierarchy_dict = new VariantDict ();
                if (TypeHierarchyClientCaps.DYNAMIC_REGISTRATION in type_hierarchy)
                    hierarchy_dict.insert_value ("dynamicRegistration", true);
                dict.insert_value ("typeHierarchy", hierarchy_dict.end ());
            }

            return dict.end ();
        }
    }

    /**
     * Capabilities of the client / editor.
     *
     * This remains ref-counted because it owns optional text document
     * capabilities.
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
        public WorkspaceClientCaps workspace { get; set; }

        /**
         * Text document-specific client capabilities.
         */
        public TextDocumentClientCaps? text_document { get; set; }

        public ClientCaps () {
            workspace = WorkspaceClientCaps ();
        }

        public ClientCaps.from_variant (Variant dict) throws DeserializeError {
            workspace = WorkspaceClientCaps ();
            Variant? prop;

            if ((prop = dict.lookup_value ("workspace", VariantType.VARDICT)) != null)
                workspace = WorkspaceClientCaps.from_variant (prop);

            if ((prop = dict.lookup_value ("textDocument", VariantType.VARDICT)) != null)
                text_document = new TextDocumentClientCaps.from_variant (prop);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (!workspace.is_empty ())
                dict.insert_value ("workspace", workspace.to_variant ());
            if (text_document != null && !text_document.is_empty ())
                dict.insert_value ("textDocument", text_document.to_variant ());

            return dict.end ();
        }
    }
}
