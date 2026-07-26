/* servercapabilities.vala
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
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_completion_options_ref",
        unref_function = "lsp_completion_options_unref")]
    public class CompletionOptions {
        private int ref_count = 1;

        public unowned CompletionOptions ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Most tools trigger completion request automatically without
         * explicitly requesting it using a keyboard shortcut (e.g.
         * Ctrl+Space). Typically they do so when the user starts to type an
         * identifier. For example if the user types `c` in a JavaScript file
         * code complete will automatically pop up present `console` besides
         * others as a completion item. Characters that make up identifiers
         * don't need to be listed here.
         *
         * If code complete should automatically be trigger on characters not being
         * valid inside an identifier (for example `.` in JavaScript) list them in
         * `triggerCharacters`.
         */
        public string[]? triggers { get; set; }

        /**
         * The list of all possible characters that commit a completion. This field
         * can be used if clients don't support individual commit characters per
         * completion item. See client capability
         * `completion.completionItem.commitCharactersSupport`.
         *
         * If a server provides both `allCommitCharacters` and commit characters on
         * an individual completion item the ones on the completion item win.
         *
         * @since 3.2.0
         */
        public string[]? commit_triggers { get; set; }

        /**
         * The server provides support to resolve additional information for a
         * completion item.
         */
        public bool supports_resolve { get; set; }

        public CompletionOptions (bool supports_resolve, string[]? triggers = null) {
            this.supports_resolve = supports_resolve;
            this.triggers = triggers;
        }

        public CompletionOptions.from_variant (Variant variant) throws DeserializeError {
            Variant? prop = null;

            if ((prop = lookup_property (variant, "triggerCharacters", VariantType.ARRAY,
                "CompletionOptions")) != null)
                triggers = string_array_from_variant (
                    prop,
                    "CompletionOptions.triggerCharacters");

            if ((prop = lookup_property (variant, "allCommitCharacters", VariantType.ARRAY,
                "CompletionOptions")) != null)
                commit_triggers = string_array_from_variant (
                    prop,
                    "CompletionOptions.allCommitCharacters");

            if ((prop = lookup_property (variant, "resolveProvider", VariantType.BOOLEAN,
                "CompletionOptions")) != null)
                supports_resolve = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (triggers != null)
                dict.insert_value ("triggerCharacters", triggers);
            if (commit_triggers != null)
                dict.insert_value ("allCommitCharacters", commit_triggers);
            dict.insert_value ("resolveProvider", supports_resolve);

            return dict.end ();
        }
    }

    public class SignatureHelpOptions {
        /**
         * The characters that trigger signature help automatically.
         */
        public string[]? triggers { get; set; }

        /**
         * List of characters that re-trigger signature help.
         *
         * These trigger characters are only active when signature help is already
         * showing. All trigger characters are also counted as re-trigger
         * characters.
         *
         * @since 3.15.0
         */
        public string[]? retriggers { get; set; }

        public SignatureHelpOptions (string[]? triggers = null) {
            this.triggers = triggers;
        }

        public SignatureHelpOptions.from_variant (Variant variant) throws DeserializeError {
            Variant? prop = null;

            if ((prop = lookup_property (variant, "triggerCharacters", VariantType.ARRAY,
                "SignatureHelpOptions")) != null)
                triggers = string_array_from_variant (
                    prop,
                    "SignatureHelpOptions.triggerCharacters");

            if ((prop = lookup_property (variant, "retriggerCharacters", VariantType.ARRAY,
                "SignatureHelpOptions")) != null)
                retriggers = string_array_from_variant (
                    prop,
                    "SignatureHelpOptions.retriggerCharacters");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (triggers != null)
                dict.insert_value ("triggerCharacters", triggers);
            if (retriggers != null)
                dict.insert_value ("retriggerCharacters", retriggers);

            return dict.end ();
        }
    }

    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_code_lens_options_ref",
        unref_function = "lsp_code_lens_options_unref")]
    public class CodeLensOptions {
        private int ref_count = 1;

        public unowned CodeLensOptions ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Code lens has a resolve provider as well.
         */
        public bool supports_resolve { get; set; }

        public CodeLensOptions (bool supports_resolve) {
            this.supports_resolve = supports_resolve;
        }

        public CodeLensOptions.from_variant (Variant variant) throws DeserializeError {
            Variant? prop = null;

            if ((prop = lookup_property (variant, "resolveProvider", VariantType.BOOLEAN,
                "CodeLensOptions")) != null)
                supports_resolve = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("resolveProvider", supports_resolve);

            return dict.end ();
        }
    }

    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_document_link_options_ref",
        unref_function = "lsp_document_link_options_unref")]
    public class DocumentLinkOptions {
        private int ref_count = 1;

        public unowned DocumentLinkOptions ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Document links have a resolve provider as well.
         */
        public bool supports_resolve { get; set; }

        public DocumentLinkOptions (bool supports_resolve) {
            this.supports_resolve = supports_resolve;
        }

        public DocumentLinkOptions.from_variant (Variant variant) throws DeserializeError {
            Variant? prop = null;

            if ((prop = lookup_property (variant, "resolveProvider", VariantType.BOOLEAN,
                "DocumentLinkOptions")) != null)
                supports_resolve = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("resolveProvider", supports_resolve);

            return dict.end ();
        }
    }

    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_document_on_type_formatting_options_ref",
        unref_function = "lsp_document_on_type_formatting_options_unref")]
    public class DocumentOnTypeFormattingOptions {
        private int ref_count = 1;

        public unowned DocumentOnTypeFormattingOptions ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The character on which formatting should be triggered, like `}`.
         */
        public string first_trigger { get; set; }

        /**
         * More trigger characters.
         */
        public string[]? more_triggers { get; set; }

        public DocumentOnTypeFormattingOptions (string first_trigger,
                                                string[]? more_triggers = null) {
            this.first_trigger = first_trigger;
            this.more_triggers = more_triggers;
        }

        public DocumentOnTypeFormattingOptions.from_variant (
            Variant variant) throws DeserializeError {
            first_trigger = (string) expect_property (
                variant,
                "firstTriggerCharacter",
                VariantType.STRING,
                "DocumentOnTypeFormattingOptions");

            var prop = lookup_property (
                variant,
                "moreTriggerCharacters",
                VariantType.ARRAY,
                "DocumentOnTypeFormattingOptions");
            if (prop != null)
                more_triggers = string_array_from_variant (
                    prop,
                    "DocumentOnTypeFormattingOptions.moreTriggerCharacters");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("firstTriggerCharacter", first_trigger);
            if (more_triggers != null)
                dict.insert_value ("moreTriggerCharacters", more_triggers);

            return dict.end ();
        }
    }

    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_rename_options_ref", unref_function = "lsp_rename_options_unref")]
    public class RenameOptions {
        private int ref_count = 1;

        public unowned RenameOptions ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The server supports renames being checked and tested before being
         * executed.
         */
        public bool supports_prepare { get; set; }

        public RenameOptions (bool supports_prepare) {
            this.supports_prepare = supports_prepare;
        }

        public RenameOptions.from_variant (Variant variant) throws DeserializeError {
            Variant? prop = null;

            if ((prop = lookup_property (variant, "prepareProvider", VariantType.BOOLEAN,
                "RenameOptions")) != null)
                supports_prepare = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("prepareProvider", supports_prepare);

            return dict.end ();
        }
    }

    /**
     * The capabilities of the language server.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_server_caps_ref", unref_function = "lsp_server_caps_unref")]
    public class ServerCaps {
        private int ref_count = 1;

        public unowned ServerCaps ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Defines how text documents are synced.
         */
        public TextDocumentSyncKind text_document_sync {
            get;
            set;
            default = NONE;
        }

        /**
         * The server provides completion support.
         */
        public CompletionOptions? completion { get; set; }

        /**
         * The server provides hover support.
         */
        public bool hover { get; set; }

        /**
         * The server provides signature help support.
         */
        public SignatureHelpOptions? signature_help { get; set; }

        /**
         * The server provides goto-declaration support.
         */
        public bool declaration { get; set; }

        /**
         * The server provides goto-definition support.
         */
        public bool definition { get; set; }

        /**
         * The server provides goto-type-definition support.
         */
        public bool type_definition { get; set; }

        /**
         * The server provides goto-implementation support.
         */
        public bool implementation { get; set; }

        /**
         * The server provides find references support.
         */
        public bool references { get; set; }

        /**
         * The server provides document highlight support.
         */
        public bool document_highlight { get; set; }

        /**
         * The server provides document symbol support.
         */
        public bool document_symbol { get; set; }

        /**
         * The server provides code actions.
         */
        public bool code_action { get; set; }

        /**
         * The server provides code lens.
         */
        public CodeLensOptions? code_lens { get; set; }

        /**
         * The server provides document links.
         */
        public DocumentLinkOptions? document_link { get; set; }

        /**
         * The server provides document formatting.
         */
        public bool document_formatting { get; set; }

        /**
         * The server provides document range formatting.
         */
        public bool document_range_formatting { get; set; }

        /**
         * The server provides document formatting on typing.
         */
        public DocumentOnTypeFormattingOptions? document_on_type_formatting { get; set; }

        /**
         * The server provides rename support.
         */
        public RenameOptions? rename { get; set; }

        /**
         * Whether the server provides call hierarchy support.
         */
        public CallHierarchyOptions? call_hierarchy { get; set; }

        /**
         * Whether the server provides inlay hint support.
         *
         * @since 3.17.0
         */
        public InlayHintOptions? inlay_hint { get; set; }

        /**
         * The server provides workspace symbol support.
         */
        public bool workspace_symbol { get; set; }

        public ServerCaps.from_variant (Variant variant) throws DeserializeError {
            Variant? prop = null;

            if ((prop = lookup_property (
                variant,
                "textDocumentSync",
                VariantType.INT64,
                "ServerCaps")) != null)
                text_document_sync = (TextDocumentSyncKind) (int64) prop;

            if ((prop = lookup_property (variant, "completionProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                completion = new CompletionOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "hoverProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    hover = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    hover = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.hoverProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "signatureHelpProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                signature_help = new SignatureHelpOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "declarationProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    declaration = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    declaration = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.declarationProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "definitionProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    definition = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    definition = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.definitionProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "typeDefinitionProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    type_definition = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    type_definition = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.typeDefinitionProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "implementationProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    implementation = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    implementation = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.implementationProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "referencesProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    references = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    references = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.referencesProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "documentHighlightProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    document_highlight = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    document_highlight = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.documentHighlightProvider must be a boolean or an object",
                        "ServerCaps");
            }

            if ((prop = lookup_property (variant, "documentSymbolProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    document_symbol = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    document_symbol = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.documentSymbolProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "codeActionProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    code_action = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    code_action = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.codeActionProvider must be a boolean or an object", "ServerCaps");
            }

            if ((prop = lookup_property (variant, "codeLensProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                code_lens = new CodeLensOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "documentLinkProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                document_link = new DocumentLinkOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "documentFormattingProvider", VariantType.ANY,
                "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    document_formatting = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    document_formatting = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.documentFormattingProvider must be a boolean or an object",
                        "ServerCaps");
            }

            if ((prop = lookup_property (variant, "documentRangeFormattingProvider",
                VariantType.ANY, "ServerCaps")) != null) {
                if (prop.is_of_type (VariantType.BOOLEAN))
                    document_range_formatting = (bool) prop;
                else if (prop.is_of_type (VariantType.VARDICT))
                    document_range_formatting = true;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "%s.documentRangeFormattingProvider must be a boolean or an object",
                        "ServerCaps");
            }

            if ((prop = lookup_property (variant, "documentOnTypeFormattingProvider",
                VariantType.VARDICT, "ServerCaps")) != null)
                document_on_type_formatting =
                    new DocumentOnTypeFormattingOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "renameProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                rename = new RenameOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "callHierarchyProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                call_hierarchy = new CallHierarchyOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "inlayHintProvider", VariantType.VARDICT,
                "ServerCaps")) != null)
                inlay_hint = new InlayHintOptions.from_variant (prop);

            if ((prop = lookup_property (variant, "workspaceSymbolProvider", VariantType.BOOLEAN,
                "ServerCaps")) != null)
                workspace_symbol = (bool) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("textDocumentSync", new Variant.int64 (text_document_sync));
            if (completion != null)
                dict.insert_value ("completionProvider", completion.to_variant ());
            dict.insert_value ("hoverProvider", hover);
            if (signature_help != null)
                dict.insert_value ("signatureHelpProvider", signature_help.to_variant ());
            dict.insert_value ("declarationProvider", declaration);
            dict.insert_value ("definitionProvider", definition);
            dict.insert_value ("typeDefinitionProvider", type_definition);
            dict.insert_value ("implementationProvider", implementation);
            dict.insert_value ("referencesProvider", references);
            dict.insert_value ("documentHighlightProvider", document_highlight);
            dict.insert_value ("documentSymbolProvider", document_symbol);
            dict.insert_value ("codeActionProvider", code_action);
            if (code_lens != null)
                dict.insert_value ("codeLensProvider", code_lens.to_variant ());
            if (document_link != null)
                dict.insert_value ("documentLinkProvider", document_link.to_variant ());
            dict.insert_value ("documentFormattingProvider", document_formatting);
            dict.insert_value ("documentRangeFormattingProvider", document_range_formatting);
            if (document_on_type_formatting != null)
                dict.insert_value ("documentOnTypeFormattingProvider",
                    document_on_type_formatting.to_variant ());
            if (rename != null)
                dict.insert_value ("renameProvider", rename.to_variant ());
            if (call_hierarchy != null)
                dict.insert_value ("callHierarchyProvider", call_hierarchy.to_variant ());
            if (inlay_hint != null)
                dict.insert_value ("inlayHintProvider", inlay_hint.to_variant ());
            dict.insert_value ("workspaceSymbolProvider", workspace_symbol);

            return dict.end ();
        }
    }
}
