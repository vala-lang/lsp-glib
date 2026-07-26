/* symbol.vala
 *
 * Copyright 2022 Princeton Ferro <princetonferro@gmail.com>
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
     * A symbol kind.
     */
    public enum SymbolKind {
        FILE = 1,
        MODULE = 2,
        NAMESPACE = 3,
        PACKAGE = 4,
        CLASS = 5,
        METHOD = 6,
        PROPERTY = 7,
        FIELD = 8,
        CONSTRUCTOR = 9,
        ENUM = 10,
        INTERFACE = 11,
        FUNCTION = 12,
        VARIABLE = 13,
        CONSTANT = 14,
        STRING = 15,
        NUMBER = 16,
        BOOLEAN = 17,
        ARRAY = 18,
        OBJECT = 19,
        KEY = 20,
        NULL = 21,
        ENUM_MEMBER = 22,
        STRUCT = 23,
        EVENT = 24,
        OPERATOR = 25,
        TYPE_PARAMETER = 26;
    }

    /**
     * Symbol tags are extra annotations that tweak the rendering of a
     * symbol.
     */
    [Flags]
    public enum SymbolTag {
        UNSET = 0,
        DEPRECATED = 1
    }

    /**
     * Represents programming constructs like variables, classes,
     * interfaces, etc. that appear in a document. Document symbols can be
     * hierarchical.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_document_symbol_ref", unref_function = "lsp_document_symbol_unref")]
    public class DocumentSymbol {
        private int ref_count = 1;

        public unowned DocumentSymbol ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The name of this symbol.
         */
        public string name { get; set; }

        /**
         * More detail for this symbol, e.g. the signature of a function.
         */
        public string? detail { get; set; }

        /**
         * The kind of this symbol.
         */
        public SymbolKind kind { get; set; }

        /**
         * Tags for this symbol.
         */
        public SymbolTag tags { get; set; default = UNSET; }

        /**
         * The range enclosing this symbol not including leading/trailing
         * whitespace but everything else like comments. This information is
         * typically used to determine if the user's cursor is inside the
         * symbol to reveal in the symbol sidebar or breadcrumb.
         */
        public Range range { get; set; }

        /**
         * The range that should be selected and revealed when this symbol
         * is being picked, e.g. the name of a function. Must be contained
         * by the {@link range}.
         */
        public Range selection_range { get; set; }

        /**
         * Children of this symbol, e.g. properties of a class.
         */
        public DocumentSymbol[] children { get; set; }

        public DocumentSymbol (string name, SymbolKind kind, Range range, Range selection_range,
                               string? detail = null, SymbolTag tags = SymbolTag.UNSET) {
            this.name = name;
            this.kind = kind;
            this.range = range;
            this.selection_range = selection_range;
            this.detail = detail;
            this.tags = tags;
        }

        public DocumentSymbol.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;
            Variant? child_list;

            name = (string) expect_property (dict, "name", VariantType.STRING, "DocumentSymbol");
            kind = (SymbolKind) (int64) expect_property (dict, "kind", VariantType.INT64,
                "DocumentSymbol");

            if ((prop = lookup_property (dict, "detail", VariantType.STRING,
                "DocumentSymbol")) != null)
                detail = (string) prop;

            range = Range.from_variant (expect_property (dict, "range", VariantType.VARDICT,
                "DocumentSymbol"));
            selection_range = Range.from_variant (expect_property (dict, "selectionRange",
                VariantType.VARDICT, "DocumentSymbol"));

            if ((prop = lookup_property (dict, "tags", VariantType.ARRAY,
                "DocumentSymbol")) != null) {
                SymbolTag parsed_tags = SymbolTag.UNSET;
                foreach (var tag_v in prop) {
                    var tag = expect_array_element (
                        tag_v,
                        VariantType.INT64,
                        "DocumentSymbol.tags");
                    parsed_tags |= (SymbolTag) (int) tag.get_int64 ();
                }
                tags = parsed_tags;
            }

            child_list = lookup_property (
                dict,
                "children",
                VariantType.ARRAY,
                "DocumentSymbol");
            if (child_list != null) {
                DocumentSymbol[] children = {};
                foreach (var child in child_list)
                    children += new DocumentSymbol.from_variant (
                        expect_array_element (
                            child,
                            VariantType.VARDICT,
                            "DocumentSymbol.children"));
                this.children = children;
            } else {
                this.children = {};
            }
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("name", new Variant.string (name));
            dict.insert_value ("kind", new Variant.int64 (kind));
            if (detail != null)
                dict.insert_value ("detail", new Variant.string (detail));
            if (tags != SymbolTag.UNSET) {
                Variant[] tag_list = {};
                if (SymbolTag.DEPRECATED in tags)
                    tag_list += new Variant.int64 ((int64) SymbolTag.DEPRECATED);
                dict.insert_value ("tags", new Variant.array (VariantType.INT64, tag_list));
            }
            dict.insert_value ("range", range.to_variant ());
            dict.insert_value ("selectionRange", selection_range.to_variant ());
            if (children.length > 0) {
                Variant[] child_variants = {};
                foreach (unowned var child in children)
                    child_variants += child.to_variant ();
                dict.insert_value ("children", child_variants);
            }
            return dict.end ();
        }
    }

    /**
     * Represents information about programming constructs like variables,
     * classes, interfaces, etc.
     *
     * @deprecated This type is still used in workspace/symbol, but
     *   {@link DocumentSymbol} is preferred for document/symbol.
     */
    public class SymbolInformation {
        /**
         * Whether this symbol is deprecated.
         *
         * This is a convenience property that delegates to {@link tags}.
         */
        public bool deprecated {
            get {
                return SymbolTag.DEPRECATED in tags;
            }
            set {
                if (value)
                    tags |= SymbolTag.DEPRECATED;
                else
                    tags &= ~SymbolTag.DEPRECATED;
            }
        }

        /**
         * The name of this symbol.
         */
        public string name { get; set; }

        /**
         * The kind of this symbol.
         */
        public SymbolKind kind { get; set; }

        /**
         * Tags for this symbol.
         */
        public SymbolTag tags { get; set; default = UNSET; }

        /**
         * The name of the symbol containing this symbol.
         */
        public string? container_name { get; set; }

        /**
         * The location of this symbol.
         */
        public Location location { get; set; }

        public SymbolInformation (string name, SymbolKind kind, Location location,
                                  string? container_name = null, SymbolTag tags = SymbolTag.UNSET) {
            this.name = name;
            this.kind = kind;
            this.tags = tags;
            this.location = location;
            this.container_name = container_name;
        }

        public SymbolInformation.from_variant (Variant dict) throws DeserializeError, UriError {
            Variant? prop = null;

            name = (string) expect_property (dict, "name", VariantType.STRING, "SymbolInformation");
            kind = (SymbolKind) (int64) expect_property (dict, "kind", VariantType.INT64,
                "SymbolInformation");
            location = Location.from_variant (expect_property (dict, "location",
                VariantType.VARDICT, "SymbolInformation"));

            if ((prop = lookup_property (dict, "tags", VariantType.ARRAY,
                "SymbolInformation")) != null) {
                SymbolTag parsed_tags = SymbolTag.UNSET;
                foreach (var tag_v in prop) {
                    var tag = expect_array_element (
                        tag_v,
                        VariantType.INT64,
                        "SymbolInformation.tags");
                    parsed_tags |= (SymbolTag) (int) tag.get_int64 ();
                }
                tags = parsed_tags;
            }

            if ((prop = lookup_property (dict, "deprecated", VariantType.BOOLEAN,
                "SymbolInformation")) != null && (bool) prop)
                tags |= SymbolTag.DEPRECATED;

            if ((prop = lookup_property (dict, "containerName", VariantType.STRING,
                "SymbolInformation")) != null)
                container_name = (string) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("name", new Variant.string (name));
            if (deprecated)
                dict.insert_value ("deprecated", new Variant.boolean (true));
            dict.insert_value ("kind", new Variant.int64 (kind));
            if (tags != SymbolTag.UNSET) {
                Variant[] tag_list = {};
                if (SymbolTag.DEPRECATED in tags)
                    tag_list += new Variant.int64 ((int64) SymbolTag.DEPRECATED);
                dict.insert_value ("tags", new Variant.array (VariantType.INT64, tag_list));
            }
            if (container_name != null)
                dict.insert_value ("containerName", new Variant.string (container_name));
            dict.insert_value ("location", location.to_variant ());
            return dict.end ();
        }
    }

    /**
     * A workspace symbol is a symbol that can be returned from the
     * workspace/symbol request. It is similar to {@link SymbolInformation}
     * but with an extended {@link location} that can also be a
     * {@link Uri} + {@link Range} literal.
     *
     * @since 3.17.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_workspace_symbol_ref",
        unref_function = "lsp_workspace_symbol_unref")]
    public class WorkspaceSymbol {
        private int ref_count = 1;

        public unowned WorkspaceSymbol ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The name of this symbol.
         */
        public string name { get; set; }

        /**
         * The kind of this symbol.
         */
        public SymbolKind kind { get; set; }

        /**
         * Tags for this symbol.
         */
        public SymbolTag tags { get; set; default = UNSET; }

        /**
         * The name of the symbol containing this symbol.
         */
        public string? container_name { get; set; }

        /**
         * The URI containing this symbol.
         */
        public Uri uri { get; set; }

        /**
         * The symbol range, or null when the server has not resolved it.
         */
        public Range? range { get; set; }

        public WorkspaceSymbol (
            string name,
            SymbolKind kind,
            Uri uri,
            Range? range = null,
            string? container_name = null,
            SymbolTag tags = SymbolTag.UNSET
        ) {
            this.name = name;
            this.kind = kind;
            this.tags = tags;
            this.uri = uri;
            this.range = range;
            this.container_name = container_name;
        }

        public WorkspaceSymbol.from_variant (
            Variant dict
        ) throws DeserializeError, UriError {
            Variant? prop = null;

            name = (string) expect_property (dict, "name", VariantType.STRING, "WorkspaceSymbol");
            kind = (SymbolKind) (int64) expect_property (dict, "kind", VariantType.INT64,
                "WorkspaceSymbol");
            var location = expect_property (
                dict,
                "location",
                VariantType.VARDICT,
                "WorkspaceSymbol");
            uri = Uri.parse (
                (string) expect_property (
                    location,
                    "uri",
                    VariantType.STRING,
                    "WorkspaceSymbol.location"),
                UriFlags.NONE);
            if ((prop = lookup_property (
                location,
                "range",
                VariantType.VARDICT,
                "WorkspaceSymbol.location")) != null)
                range = Range.from_variant (prop);

            if ((prop = lookup_property (dict, "tags", VariantType.ARRAY,
                "WorkspaceSymbol")) != null) {
                SymbolTag parsed_tags = SymbolTag.UNSET;
                foreach (var tag_v in prop) {
                    var tag = expect_array_element (
                        tag_v,
                        VariantType.INT64,
                        "WorkspaceSymbol.tags");
                    parsed_tags |= (SymbolTag) (int) tag.get_int64 ();
                }
                tags = parsed_tags;
            }

            if ((prop = lookup_property (dict, "containerName", VariantType.STRING,
                "WorkspaceSymbol")) != null)
                container_name = (string) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("name", new Variant.string (name));
            dict.insert_value ("kind", new Variant.int64 (kind));
            if (tags != SymbolTag.UNSET) {
                Variant[] tag_list = {};
                if (SymbolTag.DEPRECATED in tags)
                    tag_list += new Variant.int64 ((int64) SymbolTag.DEPRECATED);
                dict.insert_value ("tags", new Variant.array (VariantType.INT64, tag_list));
            }
            if (container_name != null)
                dict.insert_value ("containerName", new Variant.string (container_name));
            var location = new VariantDict ();
            location.insert_value ("uri", uri.to_string ());
            if (range != null)
                location.insert_value ("range", range.to_variant ());
            dict.insert_value ("location", location.end ());
            return dict.end ();
        }
    }
}
