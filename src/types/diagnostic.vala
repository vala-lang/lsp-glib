/* diagnostic.vala
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
     * Structure to capture a description for an error code.
     *
     * @since 3.16.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_code_description_ref",
        unref_function = "lsp_code_description_unref")]
    public class CodeDescription {
        private int ref_count = 1;

        public unowned CodeDescription ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * An URI to open with more information about the diagnostic error.
         */
        public string href { get; set; }

        public CodeDescription (string href) {
            this.href = href;
        }

        public CodeDescription.from_variant (Variant variant) throws DeserializeError {
            href = (string) expect_property (
                variant,
                "href",
                VariantType.STRING,
                "CodeDescription");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("href", href);
            return dict.end ();
        }
    }

    /**
     * The diagnostic severity
     */
    public enum DiagnosticSeverity {
        UNSET       = 0,
        ERROR       = 1,
        WARNING     = 2,
        INFORMATION = 3,
        HINT        = 4
    }

    /**
     * The diagnostic tags
     *
     * @since 3.15.0
     */
    public enum DiagnosticTag {
        UNSET       = 0,

        /**
         * Unused or unnecessary code.
         *
         * Clients are allowed to render diagnostics with this tag faded out
         * instead of having an error squiggle.
         */
        UNNECESSARY = 1,

        /**
         * Deprecated or obsolete code.
         *
         * Clients are allowed to render diagnostics with this tag strike
         * through.
         */
        DEPRECATED  = 2;

        public static DiagnosticTag parse_int (int value) throws DeserializeError {
            if (value == UNNECESSARY || value == DEPRECATED)
                return value;
            throw new DeserializeError.INVALID_TYPE ("%d is not a %s", value,
                typeof (DiagnosticTag).name ());
        }
    }

    /**
     * A set of {@link DiagnosticTag} values.
     */
    [Flags]
    public enum DiagnosticTagFlags {
        NONE = 0,
        UNNECESSARY = 1,
        DEPRECATED = 2
    }

    /**
     * Represents a related message and source code location for a diagnostic.
     *
     * This should be used to point to code locations that cause or are related
     * to a diagnostics, e.g when duplicating a symbol in a scope.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_diagnostic_related_information_ref",
        unref_function = "lsp_diagnostic_related_information_unref")]
    public class DiagnosticRelatedInformation {
        private int ref_count = 1;

        public unowned DiagnosticRelatedInformation ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The location of this related diagnostic information.
         */
        public Location location { get; set; }

        /**
         * The message of this related diagnostic information.
         */
        public string message { get; set; }

        public DiagnosticRelatedInformation (Location location, string message) {
            this.location = location;
            this.message = message;
        }

        public DiagnosticRelatedInformation.from_variant (Variant variant) throws UriError,
        DeserializeError {
            location = Location.from_variant (expect_property (variant, "location",
                VariantType.VARDICT, typeof (DiagnosticRelatedInformation).name ()));
            message = (string) expect_property (variant, "message", VariantType.STRING,
                typeof (DiagnosticRelatedInformation).name ());
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("location", location.to_variant ());
            dict.insert_value ("message", message);
            return dict.end ();
        }
    }

    /**
     * Represents a diagnostic, such as a compiler error or warning.
     *
     * Diagnostic objects are only valid in the scope of a resource.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_diagnostic_ref", unref_function = "lsp_diagnostic_unref")]
    public class Diagnostic {
        private int ref_count = 1;

        public unowned Diagnostic ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The range at which the message applies.
         */
        public Range range { get; set; }

        /**
         * The diagnostic's severity. Can be omitted. If omitted it is up to
         * the client to interpret diagnostics as error, warning, info or hint.
         */
        public DiagnosticSeverity severity { get; set; default = UNSET; }

        /**
         * The diagnostic's code, which might appear in the user interface.
         */
        public string? code { get; set; }

        /**
         * An optional property to describe the error code.
         *
         * @since 3.16.0
         */
        public CodeDescription? code_description { get; owned set; }

        /**
         * A human-readable string describing the source of this diagnostic,
         * e.g. 'vala' or 'vala lint'.
         */
        public string? source { get; set; }

        /**
         * The diagnostic's message.
         */
        public string message { get; set; }

        /**
         * Additional metadata about the diagnostic.
         *
         * @since 3.15.0
         */
        public DiagnosticTagFlags tags { get; set; default = NONE; }

        /**
         * An array of related diagnostic information, e.g. when symbol-names
         * within a scope collide all definitions can be marked via this
         * property.
         */
        private DiagnosticRelatedInformation[]? _related_information;
        public DiagnosticRelatedInformation[]? related_information {
            get {
                return _related_information;
            }
            set {
                _related_information = value;
            }
        }

        /**
         * Appends related information to {@link related_information}.
         */
        public void add_related_information (DiagnosticRelatedInformation information) {
            _related_information += information;
        }

        /**
         * A data entry field that is preserved between a
         * `textDocument/publishDiagnostics` notification and
         * `textDocument/codeAction` request.
         *
         * @since 3.16.0
         */
        public Variant? data { get; set; }

        public Diagnostic (string message, Range range) {
            this.message = message;
            this.range = range;
        }

        public Diagnostic.from_variant (Variant variant) throws DeserializeError, UriError {
            Variant? prop = null;

            range = Range.from_variant (expect_property (variant, "range", VariantType.VARDICT,
                "LspDiagnostic"));

            if ((prop = lookup_property (variant, "severity", VariantType.INT64,
                "LspDiagnostic")) != null) {
                var value = (int64) prop;
                if (value < (int64) DiagnosticSeverity.ERROR ||
                    value > (int64) DiagnosticSeverity.HINT)
                    throw new DeserializeError.INVALID_TYPE ("invalid LspDiagnostic.severity");
                severity = (DiagnosticSeverity) value;
            }

            if ((prop = variant.lookup_value ("code", null)) != null) {
                if (prop.is_of_type (VariantType.INT64))
                    code = ((int64) prop).to_string ();
                else if (prop.is_of_type (VariantType.STRING))
                    code = (string) prop;
                else
                    throw new DeserializeError.INVALID_TYPE (
                        "LspDiagnostic.code must be an int64 or a string");
            }

            if ((prop = lookup_property (variant, "codeDescription", VariantType.VARDICT,
                "LspDiagnostic")) != null)
                code_description = new CodeDescription.from_variant (prop);

            if ((prop = lookup_property (variant, "source", VariantType.STRING,
                "LspDiagnostic")) != null)
                source = (string) prop;

            message = (string) expect_property (variant, "message", VariantType.STRING,
                "LspDiagnostic");

            if ((prop = lookup_property (variant, "tags", VariantType.ARRAY,
                "LspDiagnostic")) != null) {
                DiagnosticTagFlags diag_tags = DiagnosticTagFlags.NONE;
                foreach (var tag in prop) {
                    var tag_value = expect_array_element (
                        tag,
                        VariantType.INT64,
                        "Diagnostic.tags");
                    switch (DiagnosticTag.parse_int ((int) (int64) tag_value)) {
                        case DiagnosticTag.UNNECESSARY:
                            diag_tags |= DiagnosticTagFlags.UNNECESSARY;
                            break;
                        case DiagnosticTag.DEPRECATED:
                            diag_tags |= DiagnosticTagFlags.DEPRECATED;
                            break;
                        case DiagnosticTag.UNSET:
                            assert_not_reached ();
                    }
                }
                tags = diag_tags;
            }

            if ((prop = lookup_property (variant, "relatedInformation", VariantType.ARRAY,
                "LspDiagnostic")) != null) {
                DiagnosticRelatedInformation[] related_info = {};
                foreach (var related in prop) {
                    related_info += new DiagnosticRelatedInformation.from_variant (
                        expect_array_element (
                            related,
                            VariantType.VARDICT,
                            "Diagnostic.relatedInformation"));
                }
                related_information = related_info;
            }

            data = variant.lookup_value ("data", null);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("range", range.to_variant ());
            if (severity != DiagnosticSeverity.UNSET)
                dict.insert_value ("severity", new Variant.int64 ((int64) severity));
            if (code != null)
                dict.insert_value ("code", code);
            if (code_description != null)
                dict.insert_value ("codeDescription", code_description.to_variant ());
            if (source != null)
                dict.insert_value ("source", source);
            dict.insert_value ("message", message);
            if (tags != DiagnosticTagFlags.NONE) {
                Variant[] tags_list = {};
                if (DiagnosticTagFlags.UNNECESSARY in tags)
                    tags_list += new Variant.int64 (DiagnosticTag.UNNECESSARY);
                if (DiagnosticTagFlags.DEPRECATED in tags)
                    tags_list += new Variant.int64 (DiagnosticTag.DEPRECATED);
                dict.insert_value ("tags", new Variant.array (VariantType.INT64, tags_list));
            }
            if (related_information != null) {
                Variant[] related_information_list = {};
                foreach (unowned var related in related_information)
                    related_information_list += related.to_variant ();
                dict.insert_value (
                    "relatedInformation",
                    new Variant.array (VariantType.VARDICT, related_information_list));
            }
            if (data != null)
                dict.insert_value ("data", data);

            return dict.end ();
        }
    }
}
