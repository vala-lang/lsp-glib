/* textdocument.vala
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
     * Text documents have a language identifier to identify a document on the
     * server side when it handles more than one language to avoid
     * re-interpreting the file extension. If a document refers to one of the
     * programming languages listed below it is recommended that clients use
     * those ids.
     *
     * @see LanguageId.to_string
     */
    public enum LanguageId {
        UNKNOWN,
        ABAP,
        BASH,
        BAT,
        BIBTEXT,
        CLOJURE,
        COFFEESCRIPT,
        C,
        CPP,
        CSHARP,
        CSS,
        DIFF,
        DART,
        DOCKERFILE,
        ELIXIR,
        ERLANG,
        FSHARP,
        GIT_COMMIT,
        GIT_REBASE,
        GO,
        GROOVY,
        HANDLEBARS,
        HTML,
        INI,
        JAVA,
        JAVASCRIPT,
        JAVASCRIPT_REACT,
        JSON,
        LATEX,
        LESS,
        LUA,
        MAKEFILE,
        MARKDOWN,
        OBJECTIVE_C,
        OBJECTIVE_CPP,
        PERL,
        PERL6,
        PHP,
        POWERSHELL,
        PUG,
        PYTHON,
        R,
        RAZOR,
        RUBY,
        RUST,
        SASS,
        SCSS,
        SCALA,
        SHADERLAB,
        SQL,
        SWIFT,
        TYPESCRIPT,
        TYPESCRIPT_REACT,
        TEX,
        VALA,
        XML,
        XSL,
        YAML;

        public unowned string to_string () {
            switch (this) {
                case UNKNOWN:
                    return "plain";
                case ABAP:
                    return "abap";
                case BASH:
                    return "shellscript";
                case BAT:
                    return "bat";
                case BIBTEXT:
                    return "bibtex";
                case CLOJURE:
                    return "clojure";
                case COFFEESCRIPT:
                    return "coffeescript";
                case C:
                    return "c";
                case CPP:
                    return "cpp";
                case CSHARP:
                    return "csharp";
                case CSS:
                    return "css";
                case DIFF:
                    return "diff";
                case DART:
                    return "dart";
                case DOCKERFILE:
                    return "dockerfile";
                case ELIXIR:
                    return "elixir";
                case ERLANG:
                    return "erlang";
                case FSHARP:
                    return "fsharp";
                case GIT_COMMIT:
                    return "git-commit";
                case GIT_REBASE:
                    return "git-rebase";
                case GO:
                    return "go";
                case GROOVY:
                    return "groovy";
                case HANDLEBARS:
                    return "handlebars";
                case HTML:
                    return "html";
                case INI:
                    return "ini";
                case JAVA:
                    return "java";
                case JAVASCRIPT:
                    return "javascript";
                case JAVASCRIPT_REACT:
                    return "javascriptreact";
                case JSON:
                    return "json";
                case LATEX:
                    return "latex";
                case LESS:
                    return "less";
                case LUA:
                    return "lua";
                case MAKEFILE:
                    return "makefile";
                case MARKDOWN:
                    return "markdown";
                case OBJECTIVE_C:
                    return "objective-c";
                case OBJECTIVE_CPP:
                    return "objective-cpp";
                case PERL:
                    return "perl";
                case PERL6:
                    return "perl6";
                case PHP:
                    return "php";
                case POWERSHELL:
                    return "powershell";
                case PUG:
                    return "jade";
                case PYTHON:
                    return "python";
                case R:
                    return "r";
                case RAZOR:
                    return "razor";
                case RUBY:
                    return "ruby";
                case RUST:
                    return "rust";
                case SASS:
                    return "sass";
                case SCSS:
                    return "scss";
                case SCALA:
                    return "scala";
                case SHADERLAB:
                    return "shaderlab";
                case SQL:
                    return "sql";
                case SWIFT:
                    return "swift";
                case TYPESCRIPT:
                    return "typescript";
                case TYPESCRIPT_REACT:
                    return "typescriptreact";
                case TEX:
                    return "tex";
                case VALA:
                    return "vala";
                case XML:
                    return "xml";
                case XSL:
                    return "xsl";
                case YAML:
                    return "yaml";
            }

            assert_not_reached ();
        }

        public static LanguageId parse_string (string value) {
            for (int id = (int) UNKNOWN; id <= (int) YAML; id++) {
                var language_id = (LanguageId) id;
                if (language_id.to_string () == value)
                    return language_id;
            }

            return UNKNOWN;
        }
    }

    /**
     * Contains a text document's URI and the version (optionally).
     */
    public struct TextDocumentIdentifier {
        /**
         * The text document's URI.
         *
         * Text documents are identified using a URI. On the protocol level,
         * URIs are passed as strings.
         */
        public Uri uri { get; set; }

        /**
         * The version number of this document.
         *
         * The version number of a document will increase after each change,
         * including undo/redo. The number doesn't need to be consecutive.
         */
        public int64? version { get; set; }

        public TextDocumentIdentifier (Uri uri, int64 version) {
            this.uri = uri;
            this.version = version;
        }

        public TextDocumentIdentifier.unversioned (Uri uri) {
            this.uri = uri;
        }

        public TextDocumentIdentifier.from_variant (Variant dict) throws DeserializeError,
        UriError {
            var uri = (string) expect_property (dict, "uri", VariantType.STRING,
                typeof (TextDocumentIdentifier).name ());
            this.uri = Uri.parse (uri, UriFlags.NONE);
            Variant? prop = null;
            if ((prop = lookup_property (dict, "version", VariantType.INT64,
                typeof (TextDocumentIdentifier).name ())) != null) {
                this.version = (int64) prop;
            } else if ((prop = lookup_property (dict, "version", VariantType.MAYBE,
                typeof (TextDocumentIdentifier).name ())) != null) {
                if ((prop = prop.get_maybe ()) != null) {
                    if (prop.is_of_type (VariantType.INT64))
                        this.version = (int64) prop;
                    else
                        throw new DeserializeError.INVALID_TYPE (
                            "invalid type for property `version` on TextDocumentIdentifier");
                }
            }
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("uri", uri.to_string ());
            if (version != null) {
                int64 new_version = version;
                dict.insert_value ("version", new_version);
            }

            return dict.end ();
        }
    }

    /**
     * An item to transfer a text document from the client to the server.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_text_document_item_ref",
        unref_function = "lsp_text_document_item_unref")]
    public class TextDocumentItem {
        private int ref_count = 1;

        public unowned TextDocumentItem ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The text document's URI
         */
        public Uri uri { get; set; }

        /**
         * The text document's language identifier
         */
        public LanguageId language_id { get; set; }

        internal enum State {
            /**
             * The file is not associated with a file on the system.
             */
            IN_MEMORY,

            /**
             * The file is associated with a file on the system and it is up-to-date.
             */
            UNMODIFIED,

            /**
             * The file is associated with a file on the system and it is stale.
             */
            MODIFIED
        }

        /**
         * (Non-standard) the state of the file.
         *
         * @see Lsp.Editor
         */
        internal State state { get; set; default = IN_MEMORY; }

        /**
         * The version number of this document (it will increase after each
         * change, including undo/redo).
         */
        public int64 version { get; set; }

        /**
         * The content of the opened text document.
         */
        public string text { get; set; }

        public TextDocumentItem (Uri uri, LanguageId language_id, int version, string text) {
            this.uri = uri;
            this.language_id = language_id;
            this.version = version;
            this.text = text;
        }

        public TextDocumentItem.from_variant (Variant dict) throws DeserializeError, UriError {
            Variant? prop = null;

            if ((prop = dict.lookup_value ("uri", VariantType.STRING)) != null)
                this.uri = Uri.parse ((string) prop, UriFlags.NONE);
            else
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `uri` not found for TextDocumentItem");

            this.language_id = LanguageId.parse_string (
                (string) expect_property (
                    dict,
                    "languageId",
                    VariantType.STRING,
                    "TextDocumentItem"));

            if ((prop = dict.lookup_value ("version", VariantType.INT64)) != null)
                this.version = (int64) prop;
            else
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `version` not found for TextDocumentItem");

            if ((prop = dict.lookup_value ("text", VariantType.STRING)) != null)
                this.text = (string) prop;
            else
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `text` not found for TextDocumentItem");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("uri", uri.to_string ());
            dict.insert_value ("languageId", language_id.to_string ());
            dict.insert_value ("version", version);
            dict.insert_value ("text", text);

            return dict.end ();
        }
    }

    /**
     * A parameter literal used in requests to pass a text document and a
     * position inside that document.
     *
     * It is up to the client to decide how a selection is converted into a
     * position when issuing a request for a text document. The client can for
     * example honor or ignore the selection direction to make LSP request
     * consistent with features implemented internally.
     */
    public class TextDocumentPositionParams {
        /**
         * The position inside the text document.
         */
        public Position position { get; set; }

        /**
         * The text document.
         */
        public TextDocumentIdentifier text_document { get; set; }

        public TextDocumentPositionParams (TextDocumentIdentifier text_document,
                                           Position position) {
            this.text_document = text_document;
            this.position = position;
        }

        public TextDocumentPositionParams.from_variant (Variant dict) throws DeserializeError,
        UriError {
            text_document = TextDocumentIdentifier.from_variant (
                expect_property (
                    dict,
                    "textDocument",
                    VariantType.VARDICT,
                    "TextDocumentPositionParams"));
            position = Position.from_variant (
                expect_property (
                    dict,
                    "position",
                    VariantType.VARDICT,
                    "TextDocumentPositionParams"));
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value (
                "textDocument",
                text_document.to_variant ());
            dict.insert_value ("position", position.to_variant ());
            return dict.end ();
        }
    }

    /**
     * Describes how the host (editor) should sync document changes to the
     * language server.
     */
    public enum TextDocumentSyncKind {
        /**
         * Documents should not be synced at all.
         */
        NONE = 0,

        /**
         * Documents are synced by always sending the full content of the
         * document.
         */
        FULL = 1,

        /**
         * Documents are synced by sending the full content on open. After that
         * only incremental updates to the document are sent.
         */
        INCREMENTAL = 2
    }

    /**
     * An event describing a change to a text document. If {@link range} is
     * omitted the new text is considered to be the full content of the
     * document.
     */
    public struct TextDocumentContentChangeEvent {
        /**
         * The range of the document that changed.
         */
        public Range? range { get; set; }

        /**
         * The new text for the provided range. If {@link range} is omitted,
         * this is the new text for the entire document.
         */
        public string text { get; set; }

        public TextDocumentContentChangeEvent (Range? range, string text) {
            this.range = range;
            this.text = text;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (range != null)
                dict.insert_value ("range", range.to_variant ());
            dict.insert_value ("text", text);
            return dict.end ();
        }

        public TextDocumentContentChangeEvent.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;
            if ((prop = lookup_property (dict, "range", VariantType.VARDICT,
                typeof (TextDocumentContentChangeEvent).name ())) != null)
                range = Range.from_variant (prop);
            text = (string) expect_property (dict, "text", VariantType.STRING,
                typeof (TextDocumentContentChangeEvent).name ());
        }
    }
}
