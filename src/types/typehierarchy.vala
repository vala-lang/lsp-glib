/* typehierarchy.vala
 *
 * Copyright 2026 Princeton Ferro
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

namespace Lsp {
    /**
     * Represents an item in a type hierarchy.
     *
     * @since 3.17.0
     */
    [Compact (opaque = true)]
    [CCode (lower_case_cprefix = "lsp_type_hierarchy_item_",
        ref_function = "lsp_type_hierarchy_item_ref",
        unref_function = "lsp_type_hierarchy_item_unref")]
    public class TypeHierarchyItem {
        private int ref_count = 1;

        public unowned TypeHierarchyItem ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public string name { get; set; }
        public SymbolKind kind { get; set; default = UNSET; }
        public SymbolTag tags { get; set; default = UNSET; }
        public string? detail { get; set; }
        public Uri uri { get; set; }
        public Range range { get; set; }
        public Range selection_range { get; set; }

        /**
         * Opaque protocol data preserved between type hierarchy requests.
         */
        public Variant? data { get; set; }

        public TypeHierarchyItem (string name, SymbolKind kind, Uri uri, Range range,
                                  Range selection_range, string? detail = null,
                                  SymbolTag tags = SymbolTag.UNSET) {
            this.name = name;
            this.kind = kind;
            this.uri = uri;
            this.range = range;
            this.selection_range = selection_range;
            this.detail = detail;
            this.tags = tags;
        }

        public TypeHierarchyItem.from_variant (Variant dict) throws DeserializeError, UriError {
            name = (string) expect_property (
                dict, "name", VariantType.STRING, "TypeHierarchyItem");
            kind = (SymbolKind) (int64) expect_property (
                dict, "kind", VariantType.INT64, "TypeHierarchyItem");
            uri = Uri.parse ((string) expect_property (
                dict, "uri", VariantType.STRING, "TypeHierarchyItem"), UriFlags.NONE);
            range = Range.from_variant (expect_property (
                dict, "range", VariantType.VARDICT, "TypeHierarchyItem"));
            selection_range = Range.from_variant (expect_property (
                dict, "selectionRange", VariantType.VARDICT, "TypeHierarchyItem"));

            Variant? prop;
            if ((prop = lookup_property (
                dict, "detail", VariantType.STRING, "TypeHierarchyItem")) != null)
                detail = (string) prop;

            if ((prop = lookup_property (
                dict, "tags", VariantType.ARRAY, "TypeHierarchyItem")) != null) {
                SymbolTag parsed_tags = SymbolTag.UNSET;
                foreach (var tag_value in prop) {
                    var tag = expect_array_element (
                        tag_value,
                        VariantType.INT64,
                        "TypeHierarchyItem.tags");
                    parsed_tags |= (SymbolTag) (int) tag.get_int64 ();
                }
                tags = parsed_tags;
            }

            data = dict.lookup_value ("data", null);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("name", name);
            dict.insert_value ("kind", new Variant.int64 (kind));
            if (tags != SymbolTag.UNSET) {
                Variant[] tag_values = {};
                if (SymbolTag.DEPRECATED in tags)
                    tag_values += new Variant.int64 (SymbolTag.DEPRECATED);
                dict.insert_value ("tags", new Variant.array (
                    VariantType.INT64, tag_values));
            }
            if (detail != null)
                dict.insert_value ("detail", detail);
            dict.insert_value ("uri", uri.to_string ());
            dict.insert_value ("range", range.to_variant ());
            dict.insert_value ("selectionRange", selection_range.to_variant ());
            if (data != null)
                dict.insert_value ("data", data);
            return dict.end ();
        }
    }

    /**
     * Options for type hierarchy support.
     *
     * @since 3.17.0
     */
    public struct TypeHierarchyOptions {
        /** Whether the capability object is present. */
        public bool supported { get; private set; }

        public TypeHierarchyOptions () {
            supported = true;
        }

        public TypeHierarchyOptions.from_variant (Variant variant) throws DeserializeError {
            this ();
            if (!variant.is_of_type (VariantType.VARDICT))
                throw new DeserializeError.INVALID_TYPE (
                    "TypeHierarchyOptions must be a dictionary");
        }

        internal bool is_empty () {
            return !supported;
        }

        public Variant to_variant () {
            return new VariantDict ().end ();
        }
    }
}
