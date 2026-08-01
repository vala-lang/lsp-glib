/* codelens.vala
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
     * A code lens represents a command that should be shown along with
     * source text, like the number of references, a way to run tests, etc.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_code_lens_ref", unref_function = "lsp_code_lens_unref")]
    public class CodeLens {
        private int ref_count = 1;

        public unowned CodeLens ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The range in which this code lens is valid.
         */
        public Range range { get; set; }

        /**
         * The command this code lens represents.
         */
        public Command? command { get; set; }

        /**
         * A data entry field that is preserved on the code lens item
         * between a code lens and a code lens resolve request.
         */
        public Variant? data { get; set; }

        public CodeLens (Range range, Command? command = null, Variant? data = null) {
            this.range = range;
            this.command = command;
            this.data = data;
        }

        public CodeLens.from_variant (Variant dict) throws DeserializeError {
            range = Range.from_variant (expect_property (dict, "range", VariantType.VARDICT,
                "CodeLens"));
            var prop = lookup_property (dict, "command", VariantType.VARDICT, "CodeLens");
            if (prop != null)
                command = new Command.from_variant (prop);
            prop = dict.lookup_value ("data", null);
            if (prop != null)
                data = prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("range", range.to_variant ());
            if (command != null)
                dict.insert_value ("command", command.to_variant ());
            if (data != null)
                dict.insert_value ("data", data);
            return dict.end ();
        }
    }

    /**
     * The parameters of a `textDocument/codeLens` request.
     */
    public class CodeLensParams {
        /**
         * The document to request code lens for.
         */
        public TextDocumentIdentifier text_document { get; set; }

        public CodeLensParams (TextDocumentIdentifier text_document) {
            this.text_document = text_document;
        }

        public CodeLensParams.from_variant (Variant dict) throws DeserializeError, UriError {
            text_document = TextDocumentIdentifier.from_variant (expect_property (dict,
                "textDocument", VariantType.VARDICT, "CodeLensParams"));
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("textDocument", text_document.to_variant ());
            return dict.end ();
        }
    }
}
