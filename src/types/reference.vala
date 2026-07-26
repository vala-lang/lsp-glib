/* reference.vala
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
     * Whether to include the declaration of the symbol in the
     * references request.
     */
    public class ReferenceContext {
        /**
         * Include the declaration of the symbol itself.
         */
        public bool include_declaration { get; set; }

        public ReferenceContext (bool include_declaration = true) {
            this.include_declaration = include_declaration;
        }

        public ReferenceContext.from_variant (Variant dict) throws DeserializeError {
            include_declaration = (bool) expect_property (dict, "includeDeclaration",
                VariantType.BOOLEAN, "ReferenceContext");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("includeDeclaration", new Variant.boolean (include_declaration));
            return dict.end ();
        }
    }
}
