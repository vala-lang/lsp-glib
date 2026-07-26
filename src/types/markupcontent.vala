/* markupcontent.vala
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
    public enum MarkupKind {
        PLAINTEXT,
        MARKDOWN;

        public unowned string to_string () {
            switch (this) {
                case PLAINTEXT:
                    return "plaintext";
                case MARKDOWN:
                    return "markdown";
            }

            assert_not_reached ();
        }

        public static MarkupKind parse_string (string value) throws DeserializeError {
            switch (value) {
                case "plaintext":
                    return PLAINTEXT;
                case "markdown":
                    return MARKDOWN;
            }

            throw new DeserializeError.INVALID_TYPE (
                "%s is not a %s",
                value,
                typeof (MarkupKind).name ());
        }
    }

    /**
     * A `MarkupContent` literal represents a string value which content is
     * interpreted based on its kind flag.
     *
     * Currently the protocol supports `plaintext` and `markdown` as markup kinds.
     *
     * If the kind is `markdown` then the value can contain fenced code blocks like
     * in GitHub issues.
     *
     * Here is an example how such a string can be constructed in Vala:
     * {{{
     * var markdown = new MarkupContent (
     *  MarkupKind.MARKDOWN,
     *  "# Header\n" + "Some text\n" + "```vala\n" + "someCode();\n" + "```"
     * );
     * }}}
     *
     * ''Please Note'' that clients might sanitize the return markdown. A client could
     * decide to remove HTML from the markdown to avoid script execution.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_markup_content_ref", unref_function = "lsp_markup_content_unref")]
    public class MarkupContent {
        private int ref_count = 1;

        public unowned MarkupContent ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The type of the markup
         */
        public MarkupKind kind { get; set; }

        /**
         * The content itself
         */
        public string value { get; set; }

        public MarkupContent (MarkupKind kind, string value) {
            this.kind = kind;
            this.value = value;
        }

        /**
         * Deserialize from a {@link GLib.Variant}. Accepts either a
         * plain string (treated as plaintext) or a dict with
         * {@link MarkupContent.kind} and {@link MarkupContent.value} properties.
         */
        public MarkupContent.from_variant (Variant variant) throws DeserializeError {
            var value_variant = unwrap_variant (variant);
            if (value_variant.is_of_type (VariantType.STRING)) {
                kind = MarkupKind.PLAINTEXT;
                value = (string) value_variant;
            } else if (value_variant.is_of_type (VariantType.VARDICT)) {
                kind = MarkupKind.parse_string (
                    (string) expect_property (
                        value_variant,
                        "kind",
                        VariantType.STRING,
                        "MarkupContent"));
                value = (string) expect_property (
                    value_variant,
                    "value",
                    VariantType.STRING,
                    "MarkupContent");
            } else {
                throw new DeserializeError.INVALID_TYPE (
                    "MarkupContent must be a string or a dict");
            }
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("kind", kind.to_string ());
            dict.insert_value ("value", value);
            return dict.end ();
        }
    }
}
