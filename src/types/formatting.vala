/* formatting.vala
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
     * Flags for formatting options.
     *
     * @since 3.15.0
     */
    [Flags]
    public enum FormattingOptionFlags {
        NONE = 0,
        TRIM_TRAILING_WHITESPACE = 1,
        INSERT_FINAL_NEWLINE = 2,
        TRIM_FINAL_NEWLINES = 4
    }

    /**
     * Formatting options for a `textDocument/formatting` request.
     */
    public struct FormattingOptions {
        /**
         * Size of a tab in spaces.
         */
        public int tab_size { get; set; }

        /**
         * Whether to use spaces instead of tabs.
         */
        public bool insert_spaces { get; set; }

        /**
         * Formatting option flags.
         *
         * @since 3.15.0
         */
        public FormattingOptionFlags flags { get; set; }

        public FormattingOptions (int tab_size, bool insert_spaces) {
            this.tab_size = tab_size;
            this.insert_spaces = insert_spaces;
            flags = FormattingOptionFlags.NONE;
        }

        public FormattingOptions.from_variant (Variant dict) throws DeserializeError {
            tab_size = (int) (int64) expect_property (dict, "tabSize", VariantType.INT64,
                "FormattingOptions");
            insert_spaces = (bool) expect_property (dict, "insertSpaces", VariantType.BOOLEAN,
                "FormattingOptions");
            Variant? prop;
            if ((prop = lookup_property (dict, "trimTrailingWhitespace", VariantType.BOOLEAN,
                "FormattingOptions")) != null && (bool) prop)
                flags |= FormattingOptionFlags.TRIM_TRAILING_WHITESPACE;
            if ((prop = lookup_property (dict, "insertFinalNewline", VariantType.BOOLEAN,
                "FormattingOptions")) != null && (bool) prop)
                flags |= FormattingOptionFlags.INSERT_FINAL_NEWLINE;
            if ((prop = lookup_property (dict, "trimFinalNewlines", VariantType.BOOLEAN,
                "FormattingOptions")) != null && (bool) prop)
                flags |= FormattingOptionFlags.TRIM_FINAL_NEWLINES;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("tabSize", new Variant.int64 (tab_size));
            dict.insert_value ("insertSpaces", new Variant.boolean (insert_spaces));
            if (FormattingOptionFlags.TRIM_TRAILING_WHITESPACE in flags)
                dict.insert_value ("trimTrailingWhitespace", new Variant.boolean (true));
            if (FormattingOptionFlags.INSERT_FINAL_NEWLINE in flags)
                dict.insert_value ("insertFinalNewline", new Variant.boolean (true));
            if (FormattingOptionFlags.TRIM_FINAL_NEWLINES in flags)
                dict.insert_value ("trimFinalNewlines", new Variant.boolean (true));
            return dict.end ();
        }
    }

    /**
     * The parameters of a `textDocument/formatting` request.
     */
    public class DocumentFormattingParams {
        /**
         * The document to format.
         */
        public TextDocumentIdentifier text_document { get; set; }

        /**
         * The formatting options.
         */
        public FormattingOptions options { get; set; }

        public DocumentFormattingParams (TextDocumentIdentifier text_document,
                                         FormattingOptions options) {
            this.text_document = text_document;
            this.options = options;
        }

        public DocumentFormattingParams.from_variant (Variant dict) throws DeserializeError,
        UriError {
            text_document = TextDocumentIdentifier.from_variant (expect_property (dict,
                "textDocument", VariantType.VARDICT, "DocumentFormattingParams"));
            options = FormattingOptions.from_variant (expect_property (dict, "options",
                VariantType.VARDICT, "DocumentFormattingParams"));
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("textDocument", text_document.to_variant ());
            dict.insert_value ("options", options.to_variant ());
            return dict.end ();
        }
    }

    /**
     * The parameters of a `textDocument/rangeFormatting` request.
     */
    public class DocumentRangeFormattingParams {
        /**
         * The document to format.
         */
        public TextDocumentIdentifier text_document { get; set; }

        /**
         * The range to format.
         */
        public Range range { get; set; }

        /**
         * The formatting options.
         */
        public FormattingOptions options { get; set; }

        public DocumentRangeFormattingParams (TextDocumentIdentifier text_document, Range range,
                                              FormattingOptions options) {
            this.text_document = text_document;
            this.range = range;
            this.options = options;
        }

        public DocumentRangeFormattingParams.from_variant (Variant dict) throws DeserializeError,
        UriError {
            text_document = TextDocumentIdentifier.from_variant (expect_property (dict,
                "textDocument", VariantType.VARDICT, "DocumentRangeFormattingParams"));
            range = Range.from_variant (expect_property (dict, "range", VariantType.VARDICT,
                "DocumentRangeFormattingParams"));
            options = FormattingOptions.from_variant (expect_property (dict, "options",
                VariantType.VARDICT, "DocumentRangeFormattingParams"));
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("textDocument", text_document.to_variant ());
            dict.insert_value ("range", range.to_variant ());
            dict.insert_value ("options", options.to_variant ());
            return dict.end ();
        }
    }
}
