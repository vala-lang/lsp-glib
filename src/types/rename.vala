/* rename.vala
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
     * The parameters of a {@link textDocument/rename} request.
     */
    public class RenameParams {
        /**
         * The document to rename a symbol in.
         */
        public TextDocumentIdentifier text_document { get; set; }

        /**
         * The position at which the symbol to rename is located.
         */
        public Position position { get; set; }

        /**
         * The new name of the symbol.
         */
        public string new_name { get; set; }

        public RenameParams (TextDocumentIdentifier text_document, Position position,
                             string new_name) {
            this.text_document = text_document;
            this.position = position;
            this.new_name = new_name;
        }

        public RenameParams.from_variant (Variant dict) throws DeserializeError, UriError {
            text_document = TextDocumentIdentifier.from_variant (expect_property (dict,
                "textDocument", VariantType.VARDICT, "RenameParams"));
            position = Position.from_variant (expect_property (dict, "position",
                VariantType.VARDICT, "RenameParams"));
            new_name = (string) expect_property (dict, "newName", VariantType.STRING,
                "RenameParams");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("textDocument", text_document.to_variant ());
            dict.insert_value ("position", position.to_variant ());
            dict.insert_value ("newName", new_name);
            return dict.end ();
        }
    }

    /**
     * The parameters of a {@link textDocument/prepareRename} request.
     */
    public class PrepareRenameParams {
        /**
         * The document to prepare a rename in.
         */
        public TextDocumentIdentifier text_document { get; set; }

        /**
         * The position at which the symbol to rename is located.
         */
        public Position position { get; set; }

        public PrepareRenameParams (TextDocumentIdentifier text_document, Position position) {
            this.text_document = text_document;
            this.position = position;
        }

        public PrepareRenameParams.from_variant (Variant dict) throws DeserializeError, UriError {
            text_document = TextDocumentIdentifier.from_variant (expect_property (dict,
                "textDocument", VariantType.VARDICT, "PrepareRenameParams"));
            position = Position.from_variant (expect_property (dict, "position",
                VariantType.VARDICT, "PrepareRenameParams"));
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("textDocument", text_document.to_variant ());
            dict.insert_value ("position", position.to_variant ());
            return dict.end ();
        }
    }

    /**
     * The result of checking whether a symbol can be renamed.
     *
     * When {@link has_range} is false, this represents the protocol's
     * `defaultBehavior` result. Keeping the range inline avoids allocating it
     * solely to represent the alternative result shape.
     */
    public struct PrepareRenameResult {
        public Range range;
        public bool has_range;
        public string? placeholder;
        public bool default_behavior;

        public PrepareRenameResult.for_range (Range range, string? placeholder = null) {
            this.range = range;
            this.has_range = true;
            this.placeholder = placeholder;
            this.default_behavior = false;
        }

        public PrepareRenameResult.for_default_behavior (bool default_behavior = true) {
            this.has_range = false;
            this.placeholder = null;
            this.default_behavior = default_behavior;
        }

        public PrepareRenameResult.from_variant (Variant dict) throws DeserializeError {
            if (!dict.is_of_type (VariantType.VARDICT))
                throw new DeserializeError.INVALID_TYPE (
                    "prepare rename result must be a dictionary");

            var default_value = dict.lookup_value ("defaultBehavior", VariantType.BOOLEAN);
            var nested_range = dict.lookup_value ("range", VariantType.VARDICT);

            if (default_value != null) {
                if (nested_range != null || dict.lookup_value ("start", null) != null)
                    throw new DeserializeError.UNEXPECTED_ELEMENT (
                        "prepare rename result alternatives cannot be mixed");
                has_range = false;
                placeholder = null;
                default_behavior = (bool) default_value;
            } else if (nested_range != null) {
                range = Range.from_variant (nested_range);
                has_range = true;
                default_behavior = false;
                var placeholder = dict.lookup_value ("placeholder", VariantType.STRING);
                this.placeholder = placeholder != null ? (string) placeholder : null;
            } else {
                range = Range.from_variant (dict);
                has_range = true;
                placeholder = null;
                default_behavior = false;
            }
        }

        public Variant to_variant () {
            if (!has_range) {
                var dict = new VariantDict ();
                dict.insert_value ("defaultBehavior", default_behavior);
                return dict.end ();
            }

            if (placeholder == null)
                return range.to_variant ();

            var dict = new VariantDict ();
            dict.insert_value ("range", range.to_variant ());
            dict.insert_value ("placeholder", placeholder);
            return dict.end ();
        }
    }
}
