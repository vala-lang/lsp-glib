/* callhierarchy.vala
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
     * Represents an item in a call hierarchy.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_call_hierarchy_item_ref",
        unref_function = "lsp_call_hierarchy_item_unref")]
    public class CallHierarchyItem {
        private int ref_count = 1;

        public unowned CallHierarchyItem ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The name of this item.
         */
        public string name { get; set; }

        /**
         * The kind of this item.
         */
        public SymbolKind kind { get; set; }

        /**
         * Tags for this item.
         */
        public SymbolTag tags { get; set; default = UNSET; }

        /**
         * More detail for this item, e.g. the signature of a function.
         */
        public string? detail { get; set; }

        /**
         * The resource identifier of this item.
         */
        public Uri uri { get; set; }

        /**
         * The range enclosing this symbol not including leading/trailing
         * whitespace but everything else like comments.
         */
        public Range range { get; set; }

        /**
         * The range that should be selected and revealed when this symbol
         * is being picked, e.g. the name of a function.
         */
        public Range selection_range { get; set; }

        /**
         * A data entry field that is preserved between call hierarchy
         * requests.
         */
        public Variant? data { get; set; }

        public CallHierarchyItem (string name, SymbolKind kind, Uri uri, Range range,
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

        public CallHierarchyItem.from_variant (Variant dict) throws DeserializeError, UriError {
            Variant? prop = null;

            name = (string) expect_property (dict, "name", VariantType.STRING, "CallHierarchyItem");
            kind = (SymbolKind) (int64) expect_property (dict, "kind", VariantType.INT64,
                "CallHierarchyItem");

            if ((prop = lookup_property (dict, "tags", VariantType.ARRAY,
                "CallHierarchyItem")) != null) {
                SymbolTag parsed_tags = SymbolTag.UNSET;
                foreach (var tag_v in prop) {
                    var tag = expect_array_element (
                        tag_v,
                        VariantType.INT64,
                        "CallHierarchyItem.tags");
                    parsed_tags |= (SymbolTag) (int) tag.get_int64 ();
                }
                tags = parsed_tags;
            }

            if ((prop = lookup_property (dict, "detail", VariantType.STRING,
                "CallHierarchyItem")) != null)
                detail = (string) prop;

            uri = Uri.parse ((string) expect_property (dict, "uri", VariantType.STRING,
                "CallHierarchyItem"), UriFlags.NONE);
            range = Range.from_variant (expect_property (dict, "range", VariantType.VARDICT,
                "CallHierarchyItem"));
            selection_range = Range.from_variant (expect_property (dict, "selectionRange",
                VariantType.VARDICT, "CallHierarchyItem"));

            if ((prop = dict.lookup_value ("data", null)) != null)
                data = prop;
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
            if (detail != null)
                dict.insert_value ("detail", new Variant.string (detail));
            dict.insert_value ("uri", uri.to_string ());
            dict.insert_value ("range", range.to_variant ());
            dict.insert_value ("selectionRange", selection_range.to_variant ());
            if (data != null)
                dict.insert_value ("data", data);
            return dict.end ();
        }
    }

    /**
     * Represents an incoming call from a call hierarchy.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_call_hierarchy_incoming_call_ref",
        unref_function = "lsp_call_hierarchy_incoming_call_unref")]
    public class CallHierarchyIncomingCall {
        private int ref_count = 1;

        public unowned CallHierarchyIncomingCall ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The item that makes the call.
         */
        public CallHierarchyItem from { get; set; }

        /**
         * The ranges at which the calls appear.
         */
        public Range[] from_ranges { get; set; }

        public CallHierarchyIncomingCall (CallHierarchyItem from, Range[] from_ranges) {
            this.from = from;
            this.from_ranges = from_ranges;
        }

        public CallHierarchyIncomingCall.from_variant (Variant dict) throws DeserializeError,
        UriError {
            from = new CallHierarchyItem.from_variant (expect_property (dict, "from",
                VariantType.VARDICT, "CallHierarchyIncomingCall"));
            Range[] ranges = {};
            foreach (var rng in expect_property (dict, "fromRanges", VariantType.ARRAY,
                "CallHierarchyIncomingCall"))
                ranges += Range.from_variant (expect_array_element (
                    rng,
                    VariantType.VARDICT,
                    "CallHierarchyIncomingCall.fromRanges"));
            from_ranges = ranges;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("from", from.to_variant ());
            Variant[] rng_list = {};
            foreach (var rng in from_ranges)
                rng_list += rng.to_variant ();
            dict.insert_value ("fromRanges", rng_list);
            return dict.end ();
        }
    }

    /**
     * Represents an outgoing call from a call hierarchy.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_call_hierarchy_outgoing_call_ref",
        unref_function = "lsp_call_hierarchy_outgoing_call_unref")]
    public class CallHierarchyOutgoingCall {
        private int ref_count = 1;

        public unowned CallHierarchyOutgoingCall ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The item that is called.
         */
        public CallHierarchyItem to { get; set; }

        /**
         * The ranges at which the calls appear.
         */
        public Range[] from_ranges { get; set; }

        public CallHierarchyOutgoingCall (CallHierarchyItem to, Range[] from_ranges) {
            this.to = to;
            this.from_ranges = from_ranges;
        }

        public CallHierarchyOutgoingCall.from_variant (Variant dict) throws DeserializeError,
        UriError {
            to = new CallHierarchyItem.from_variant (expect_property (dict, "to",
                VariantType.VARDICT, "CallHierarchyOutgoingCall"));
            Range[] ranges = {};
            foreach (var rng in expect_property (dict, "fromRanges", VariantType.ARRAY,
                "CallHierarchyOutgoingCall"))
                ranges += Range.from_variant (expect_array_element (
                    rng,
                    VariantType.VARDICT,
                    "CallHierarchyOutgoingCall.fromRanges"));
            from_ranges = ranges;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("to", to.to_variant ());
            Variant[] rng_list = {};
            foreach (var rng in from_ranges)
                rng_list += rng.to_variant ();
            dict.insert_value ("fromRanges", rng_list);
            return dict.end ();
        }
    }

    /**
     * Options for call hierarchy support.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_call_hierarchy_options_ref",
        unref_function = "lsp_call_hierarchy_options_unref")]
    public class CallHierarchyOptions {
        private int ref_count = 1;

        public unowned CallHierarchyOptions ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public CallHierarchyOptions () {
        }

        public CallHierarchyOptions.from_variant (Variant variant) throws DeserializeError {
        }

        public Variant to_variant () {
            return new VariantDict ().end ();
        }
    }
}
