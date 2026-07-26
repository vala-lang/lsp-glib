/* highlight.vala
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
     * A document highlight kind.
     */
    public enum DocumentHighlightKind {
        /**
         * A textual occurrence.
         */
        TEXT = 1,

        /**
         * Read-access of a symbol, like reading a variable.
         */
        READ = 2,

        /**
         * Write-access of a symbol, like writing to a variable.
         */
        WRITE = 3
    }

    /**
     * A document highlight is a range inside a text document which
     * deserves special attention. Usually a document highlight is
     * visualized by changing the background color of its range.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_document_highlight_ref",
        unref_function = "lsp_document_highlight_unref")]
    public class DocumentHighlight {
        private int ref_count = 1;

        public unowned DocumentHighlight ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The range this highlight applies to.
         */
        public Range range { get; set; }

        /**
         * The highlight kind, default is {@link DocumentHighlightKind.TEXT}.
         */
        public DocumentHighlightKind kind { get; set; default = TEXT; }

        public DocumentHighlight (Range range, DocumentHighlightKind kind = TEXT) {
            this.range = range;
            this.kind = kind;
        }

        public DocumentHighlight.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;

            range = Range.from_variant (expect_property (dict, "range", VariantType.VARDICT,
                "DocumentHighlight"));

            if ((prop = lookup_property (dict, "kind", VariantType.INT64,
                "DocumentHighlight")) != null)
                kind = (DocumentHighlightKind) (int64) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("range", range.to_variant ());
            if (kind != TEXT)
                dict.insert_value ("kind", new Variant.int64 (kind));
            return dict.end ();
        }
    }
}
