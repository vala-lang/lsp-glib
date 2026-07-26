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
}
