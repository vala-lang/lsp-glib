/* textedit.vala
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
    /**
     * A textual edit applicable to a text document.
     */
    public struct TextEdit {
        /**
         * The range of the text document to be manipulated. To insert text
         * into a document create a range where start === end.
         */
        public Range range { get; set; }

        /**
         * The string to be inserted. For delete operations use an empty
         * string.
         */
        public string new_text { get; set; }

        /**
         * An identifier referring to a change annotation managed by a workspace
         * edit.
         *
         * Usually clients provide options to group the changes along the
         * annotations they are associated with. To support this in the protocol an
         * edit or resource operation refers to a change annotation using an
         * identifier and not the change annotation literal directly. This allows
         * servers to use the identical annotation across multiple edits or
         * resource operations which then allows clients to group the operations
         * under that change annotation. The actual change annotations together
         * with their identifers are managed by the workspace edit via the new
         * property changeAnnotations.
         *
         * Support for this is guarded by the client capability
         * `workspace.workspaceEdit.changeAnnotationSupport`. If a client doesn’t
         * signal the capability, servers shouldn’t send this back to the client
         * and should leave this set to `null`.
         *
         * @since 3.16.0
         */
        public string? annotation_id { get; set; }

        /**
         * Creates a new {@link Lsp.TextEdit}
         */
        public TextEdit (Range range, string new_text, string? annotation_id = null) {
            this.range = range;
            this.new_text = new_text;
            this.annotation_id = annotation_id;
        }

        /**
         * Deserialize this from a {@link GLib.Variant}
         */
        public TextEdit.from_variant (Variant variant) throws DeserializeError {
            range = Range.from_variant (expect_property (variant, "range", VariantType.VARDICT,
                "LspTextEdit"));
            new_text = (string) expect_property (variant, "newText", VariantType.STRING,
                "LspTextEdit");
            var prop = lookup_property (variant, "annotationId", VariantType.STRING, "LspTextEdit");
            if (prop != null)
                annotation_id = (string) prop;
        }

        /**
         * Serialize this to a {@link GLib.Variant}
         */
        public Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("range", range.to_variant ());
            variant.insert_value ("newText", new_text);
            if (annotation_id != null)
                variant.insert_value ("annotationId", annotation_id);

            return variant.end ();
        }
    }

    /**
     * Additional information that describes document changes.
     *
     * @since 3.16.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_change_annotation_ref",
        unref_function = "lsp_change_annotation_unref")]
    public class ChangeAnnotation {
        private int ref_count = 1;

        public unowned ChangeAnnotation ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * A human-readable string describing the actual change. The string is
         * rendered prominent in the user interface.
         */
        public string label { get; set; }

        /**
         * A flag which indicates that user confirmation is needed before
         * applying the change.
         */
        public bool needs_confirmation { get; set; }

        /**
         * A human-readable string which is rendered less prominent in the user
         * interface.
         */
        public string? description { get; set; }

        /**
         * Creates a new {@link Lsp.ChangeAnnotation}
         *
         * {@inheritDoc}
         */
        public ChangeAnnotation (string label, bool needs_confirmation = false,
                                 string? description = null) {
            this.label = label;
            this.needs_confirmation = needs_confirmation;
            this.description = description;
        }

        /**
         * Deserialize this from a {@link GLib.Variant}
         */
        public ChangeAnnotation.from_variant (Variant variant) throws DeserializeError {
            label = (string) expect_property (variant, "label", VariantType.STRING,
                "ChangeAnnotation");
            var prop = lookup_property (variant, "needsConfirmation", VariantType.BOOLEAN,
                "ChangeAnnotation");
            if (prop != null)
                needs_confirmation = (bool) prop;
            prop = lookup_property (variant, "description", VariantType.STRING, "ChangeAnnotation");
            if (prop != null)
                description = (string) prop;
        }

        /**
         * Serializes this to a {@link GLib.Variant}
         */
        public Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("label", label);
            if (needs_confirmation)
                variant.insert_value ("needsConfirmation", needs_confirmation);
            if (description != null)
                variant.insert_value ("description", description);

            return variant.end ();
        }
    }

    /**
     * Describes textual changes on a single text document.
     *
     * The text document may be referred to as a {@link TextDocumentIdentifier}
     * to allow clients to check the text document version before an edit is
     * applied. A {@link TextDocumentEdit} describes all changes on a version
     * Si and after they are applied move the document to version Si+1. So the
     * creator of a {@link TextDocumentEdit} doesn’t need to sort the array of
     * edits or do any kind of ordering. However the edits must be non
     * overlapping.
     */
    public class TextDocumentEdit : ResourceOperation {
        public override unowned string kind {
            get {
                return "textDocumentEdit";
            }
        }

        /**
         * The text document to change. This may be a versioned {@link TextDocumentIdentifier}
         */
        public TextDocumentIdentifier text_document { get; set; }

        /**
         * The edits to be applied.
         *
         * Support for annotated text edits is guarded by the client capability
         * `workspace.workspaceEdit.changeAnnotationSupport`
         */
        public TextEdit[] edits { get; set; }

        public TextDocumentEdit (TextDocumentIdentifier text_document, TextEdit[] edits) {
            this.text_document = text_document;
            this.edits = edits;
        }

        public TextDocumentEdit.from_variant (Variant variant) throws DeserializeError, UriError {
            text_document = TextDocumentIdentifier.from_variant (expect_property (variant,
                "textDocument", VariantType.VARDICT, "LspTextDocumentEdit"));
            TextEdit[] edits = {};
            foreach (var vedit in expect_property (variant, "edits", VariantType.ARRAY,
                "LspTextDocumentEdit"))
                edits += TextEdit.from_variant (
                    expect_array_element (
                        vedit,
                        VariantType.VARDICT,
                        "TextDocumentEdit.edits"));
            this.edits = edits;
        }

        public override Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("textDocument", text_document.to_variant ());
            Variant[] edits_list = {};
            foreach (var edit in edits)
                edits_list += edit.to_variant ();
            variant.insert_value (
                "edits",
                new Variant.array (VariantType.VARDICT, edits_list));

            return variant.end ();
        }
    }
}
