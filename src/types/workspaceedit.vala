/* workspaceedit.vala
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
     * An operation to edit a workspace.
     *
     * @see WorkspaceEdit.document_changes
     */
    public abstract class ResourceOperation {
        public abstract unowned string kind { get; }

        public abstract Variant to_variant ();
    }

    /**
     * Create file operation
     */
    public class CreateFile : ResourceOperation {
        public override unowned string kind {
            get {
                return ResourceOperationKind.CREATE.to_string ();
            }
        }

        /**
         * The resource to create.
         */
        public Uri uri { get; set; }

        [Flags]
        public enum Options {
            NONE = 0,
            OVERWRITE,
            IGNORE_IF_EXISTS;

            public static Options from_variant (Variant variant) throws DeserializeError {
                var options = NONE;
                Variant? prop = null;
                if ((prop = lookup_property (variant, "overwrite", VariantType.BOOLEAN,
                    "LspCreateFileOptions")) != null && (bool) prop)
                    options |= OVERWRITE;
                if ((prop = lookup_property (variant, "ignoreIfExists", VariantType.BOOLEAN,
                    "LspCreateFileOptions")) != null && (bool) prop)
                    options |= IGNORE_IF_EXISTS;
                return options;
            }
        }

        public Options options { get; set; default = NONE; }

        public string? annotation_id { get; set; }

        public CreateFile () {
        }

        public CreateFile.with_options (
            Uri uri,
            Options options = Options.NONE,
            string? annotation_id = null
        ) {
            this.uri = uri;
            this.options = options;
            this.annotation_id = annotation_id;
        }

        public CreateFile.from_variant (Variant variant) throws DeserializeError, UriError {
            uri = Uri.parse ((string) expect_property (variant, "uri", VariantType.STRING,
                "LspCreateFile"), UriFlags.NONE);
            Variant? prop = null;
            if ((prop = lookup_property (variant, "options", VariantType.VARDICT,
                "LspCreateFileOptions")) != null)
                options = Options.from_variant (prop);
            if ((prop = lookup_property (variant, "annotationId", VariantType.STRING,
                "LspCreateFile")) != null)
                annotation_id = (string) prop;
        }

        public override Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("kind", kind);
            variant.insert_value ("uri", uri.to_string ());
            if (options != NONE) {
                var opts = new VariantDict ();
                if (Options.OVERWRITE in options)
                    opts.insert_value ("overwrite", new Variant.boolean (true));
                if (Options.IGNORE_IF_EXISTS in options)
                    opts.insert_value ("ignoreIfExists", new Variant.boolean (true));
                variant.insert_value ("options", opts.end ());
            }
            if (annotation_id != null)
                variant.insert_value ("annotationId", annotation_id);

            return variant.end ();
        }
    }

    /**
     * Rename file operation
     */
    public class RenameFile : ResourceOperation {
        public override unowned string kind {
            get {
                return ResourceOperationKind.RENAME.to_string ();
            }
        }

        public Uri old_uri { get; set; }

        public Uri new_uri { get; set; }

        [Flags]
        public enum Options {
            NONE = 0,
            OVERWRITE,
            IGNORE_IF_EXISTS;

            public static Options from_variant (Variant variant) throws DeserializeError {
                var options = NONE;
                Variant? prop = null;
                if ((prop = lookup_property (variant, "overwrite", VariantType.BOOLEAN,
                    "LspRenameFileOptions")) != null && (bool) prop)
                    options |= OVERWRITE;
                if ((prop = lookup_property (variant, "ignoreIfExists", VariantType.BOOLEAN,
                    "LspRenameFileOptions")) != null && (bool) prop)
                    options |= IGNORE_IF_EXISTS;
                return options;
            }
        }

        public Options options { get; set; default = NONE; }

        public string? annotation_id { get; set; }

        public RenameFile () {
        }

        public RenameFile.with_options (
            Uri old_uri,
            Uri new_uri,
            Options options = Options.NONE,
            string? annotation_id = null
        ) {
            this.old_uri = old_uri;
            this.new_uri = new_uri;
            this.options = options;
            this.annotation_id = annotation_id;
        }

        public RenameFile.from_variant (Variant variant) throws DeserializeError, UriError {
            old_uri = Uri.parse ((string) expect_property (variant, "oldUri", VariantType.STRING,
                "LspRenameFile"), UriFlags.NONE);
            new_uri = Uri.parse ((string) expect_property (variant, "newUri", VariantType.STRING,
                "LspRenameFile"), UriFlags.NONE);
            Variant? prop = null;
            if ((prop = lookup_property (variant, "options", VariantType.VARDICT,
                "LspRenameFileOptions")) != null)
                options = Options.from_variant (prop);
            if ((prop = lookup_property (variant, "annotationId", VariantType.STRING,
                "LspRenameFile")) != null)
                annotation_id = (string) prop;
        }

        public override Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("kind", kind);
            variant.insert_value ("oldUri", old_uri.to_string ());
            variant.insert_value ("newUri", new_uri.to_string ());
            if (options != NONE) {
                var opts = new VariantDict ();
                if (Options.OVERWRITE in options)
                    opts.insert_value ("overwrite", new Variant.boolean (true));
                if (Options.IGNORE_IF_EXISTS in options)
                    opts.insert_value ("ignoreIfExists", new Variant.boolean (true));
                variant.insert_value ("options", opts.end ());
            }
            if (annotation_id != null)
                variant.insert_value ("annotationId", annotation_id);

            return variant.end ();
        }
    }

    /**
     * Delete file operation
     */
    public class DeleteFile : ResourceOperation {
        public override unowned string kind {
            get {
                return ResourceOperationKind.DELETE.to_string ();
            }
        }

        public Uri uri { get; set; }

        [Flags]
        public enum Options {
            NONE = 0,
            RECURSIVE,
            IGNORE_IF_NOT_EXISTS;

            public static Options from_variant (Variant variant) throws DeserializeError {
                var options = NONE;
                Variant? prop = null;
                if ((prop = lookup_property (variant, "recursive", VariantType.BOOLEAN,
                    "LspDeleteFileOptions")) != null && (bool) prop)
                    options |= RECURSIVE;
                if ((prop = lookup_property (variant, "ignoreIfNotExists", VariantType.BOOLEAN,
                    "LspDeleteFileOptions")) != null && (bool) prop)
                    options |= IGNORE_IF_NOT_EXISTS;
                return options;
            }
        }

        public Options options { get; set; default = NONE; }

        public string? annotation_id { get; set; }

        public DeleteFile () {
        }

        public DeleteFile.with_options (
            Uri uri,
            Options options = Options.NONE,
            string? annotation_id = null
        ) {
            this.uri = uri;
            this.options = options;
            this.annotation_id = annotation_id;
        }

        public DeleteFile.from_variant (Variant variant) throws DeserializeError, UriError {
            uri = Uri.parse ((string) expect_property (variant, "uri", VariantType.STRING,
                "LspDeleteFile"), UriFlags.NONE);
            Variant? prop = null;
            if ((prop = lookup_property (variant, "options", VariantType.VARDICT,
                "LspDeleteFileOptions")) != null)
                options = Options.from_variant (prop);
            if ((prop = lookup_property (variant, "annotationId", VariantType.STRING,
                "LspDeleteFile")) != null)
                annotation_id = (string) prop;
        }

        public override Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("kind", kind);
            variant.insert_value ("uri", uri.to_string ());
            if (options != NONE) {
                var opts = new VariantDict ();
                if (Options.RECURSIVE in options)
                    opts.insert_value ("recursive", new Variant.boolean (true));
                if (Options.IGNORE_IF_NOT_EXISTS in options)
                    opts.insert_value ("ignoreIfNotExists", new Variant.boolean (true));
                variant.insert_value ("options", opts.end ());
            }
            if (annotation_id != null)
                variant.insert_value ("annotationId", annotation_id);

            return variant.end ();
        }
    }

    /**
     * A workspace edit represents changes to many resources managed in the
     * workspace.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_workspace_edit_ref", unref_function = "lsp_workspace_edit_unref")]
    public class WorkspaceEdit {
        private int ref_count = 1;

        public unowned WorkspaceEdit ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * Holds changes to existing resources.
         *
         * This corresponds to the `documentChanges` property in the protocol.
         */
        public ResourceOperation[] document_changes { get; private set; default = {}; }

        /**
         * A map of change annotations that can be referenced in
         * annotated {@link TextEdit}s or create, rename and delete file / folder
         * operations.
         *
         * Each key is the change annotation identifier.
         *
         * Whether clients honor this property depends on the client capability
         * `workspace.changeAnnotationSupport`.
         *
         * @since 3.16.0
         */
        public HashTable<string, ChangeAnnotation>? change_annotations { get; private set; }

        public WorkspaceEdit () {
        }

        public WorkspaceEdit.with_document_changes (
            (unowned ResourceOperation)[]? document_changes = null,
            HashTable<string, ChangeAnnotation>? change_annotations = null
        ) {
            if (document_changes != null)
                this.document_changes = document_changes;
            this.change_annotations = change_annotations;
        }

        /**
         * Appends a typed document or resource change.
         */
        public void add_document_change (ResourceOperation change) {
            ResourceOperation[] changes = {};
            foreach (unowned var existing_change in document_changes)
                changes += existing_change;
            changes += change;
            document_changes = changes;
        }

        /**
         * Adds or replaces a change annotation.
         */
        public void set_change_annotation (
            string identifier,
            ChangeAnnotation annotation
        ) {
            if (change_annotations == null)
                change_annotations = new HashTable<string, ChangeAnnotation> (
                    str_hash,
                    str_equal);
            change_annotations[identifier] = annotation;
        }

        /**
         * Deserialize this from a {@link GLib.Variant}
         */
        public WorkspaceEdit.from_variant (Variant variant) throws DeserializeError, UriError {
            Variant? doc_changes = lookup_property (variant, "documentChanges", VariantType.ARRAY,
                "LspWorkspaceEdit");
            if (doc_changes != null) {
                ResourceOperation[] items = {};
                foreach (var vchange in doc_changes) {
                    var change = expect_array_element (
                        vchange,
                        VariantType.VARDICT,
                        "WorkspaceEdit.documentChanges");
                    var kind_variant = lookup_property (
                        change,
                        "kind",
                        VariantType.STRING,
                        "LspWorkspaceEdit");
                    if (kind_variant == null) {
                        items += new TextDocumentEdit.from_variant (change);
                        continue;
                    }

                    var kind = (string) kind_variant;
                    if (kind == "create")
                        items += new CreateFile.from_variant (change);
                    else if (kind == "delete")
                        items += new DeleteFile.from_variant (change);
                    else if (kind == "rename")
                        items += new RenameFile.from_variant (change);
                    else
                        throw new DeserializeError.UNEXPECTED_ELEMENT (
                            "unexpected element in documentChanges array");
                }
                document_changes = items;
            }

            Variant? annotations = lookup_property (variant, "changeAnnotations",
                VariantType.VARDICT, "LspWorkspaceEdit");
            if (annotations != null) {
                var map = new HashTable<string, ChangeAnnotation> (str_hash, str_equal);
                VariantIter iter = annotations.iterator ();
                string key;
                Variant val;
                while (iter.next ("{sv}", out key, out val))
                    map[key] = new ChangeAnnotation.from_variant (
                        unwrap_variant (val));
                change_annotations = map;
            }
        }

        /**
         * Serialize this to a {@link GLib.Variant}
         */
        public Variant to_variant () {
            var variant = new VariantDict ();

            if (document_changes.length > 0) {
                Variant[] list = {};
                foreach (var change in document_changes)
                    list += change.to_variant ();
                variant.insert_value (
                    "documentChanges",
                    new Variant.array (VariantType.VARDICT, list));
            }
            if (change_annotations != null) {
                var annotations_dict = new VariantDict ();
                foreach (unowned var key in change_annotations.get_keys ())
                    annotations_dict.insert_value (key, change_annotations[key].to_variant ());
                variant.insert_value ("changeAnnotations", annotations_dict.end ());
            }

            return variant.end ();
        }
    }

    /**
     * The result returned from the {@link workspace/applyEdit} request.
     */
    public class ApplyWorkspaceEditResult {
        /**
         * Indicates whether the edit was applied or not.
         */
        public bool applied { get; set; }

        /**
         * An optional textual description for why the edit was not applied.
         */
        public string? failure_reason { get; set; }

        /**
         * Depending on the client's failure handling strategy, the client
         * might return the actual edits it applied, so that the server can
         * reconcile with its state.
         */
        public uint64? failed_change { get; set; }

        public ApplyWorkspaceEditResult (bool applied = true, string? failure_reason = null) {
            this.applied = applied;
            this.failure_reason = failure_reason;
        }

        public ApplyWorkspaceEditResult.from_variant (Variant variant) throws DeserializeError {
            applied = (bool) expect_property (variant, "applied", VariantType.BOOLEAN,
                "ApplyWorkspaceEditResult");
            var prop = lookup_property (variant, "failureReason", VariantType.STRING,
                "ApplyWorkspaceEditResult");
            if (prop != null)
                failure_reason = (string) prop;
            prop = variant.lookup_value ("failedChange", null);
            if (prop != null)
                failed_change = parse_uinteger (
                    prop,
                    "failedChange",
                    "ApplyWorkspaceEditResult");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("applied", new Variant.boolean (applied));
            if (failure_reason != null)
                dict.insert_value ("failureReason", failure_reason);
            if (failed_change != null)
                dict.insert_value (
                    "failedChange",
                    new Variant.uint64 ((uint64) failed_change));
            return dict.end ();
        }
    }
}
