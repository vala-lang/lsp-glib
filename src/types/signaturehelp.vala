/* signaturehelp.vala
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
     * Represents a parameter of a callable-signature. A parameter can
     * have a label and a doc-comment.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_parameter_information_ref",
        unref_function = "lsp_parameter_information_unref")]
    public class ParameterInformation {
        private int ref_count = 1;

        public unowned ParameterInformation ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The label of this parameter information.
         *
         * Either a string of an informative substring of the signature
         * label (e.g. the parameter name), or a tuple of two numbers
         * that are the start and end offset within the signature label.
         */
        public string label { get; set; }

        /**
         * Whether the label is represented by offsets into the signature.
         */
        public bool has_label_offsets { get; private set; }

        /**
         * The inclusive start offset when {@link has_label_offsets} is true.
         */
        public uint64 label_start { get; private set; }

        /**
         * The exclusive end offset when {@link has_label_offsets} is true.
         */
        public uint64 label_end { get; private set; }

        /**
         * The human-readable doc-comment of this parameter.
         *
         * Will be shown in the UI.
         */
        public MarkupContent? documentation { get; set; }

        public ParameterInformation (string label) {
            this.label = label;
        }

        public ParameterInformation.with_offsets (
            uint64 label_start,
            uint64 label_end
        ) {
            this.label = "";
            this.label_start = label_start;
            this.label_end = label_end;
            this.has_label_offsets = true;
        }

        public ParameterInformation.from_variant (Variant dict) throws DeserializeError {
            var prop = unwrap_variant (expect_property (
                dict,
                "label",
                VariantType.ANY,
                "ParameterInformation"));
            if (prop.is_of_type (VariantType.STRING))
                label = (string) prop;
            else if (prop.is_of_type (VariantType.ARRAY)) {
                if (prop.n_children () != 2)
                    throw new DeserializeError.INVALID_TYPE (
                        "ParameterInformation.label offsets must contain two elements");
                label_start = parse_uinteger (
                    prop.get_child_value (0),
                    "label[0]",
                    "ParameterInformation");
                label_end = parse_uinteger (
                    prop.get_child_value (1),
                    "label[1]",
                    "ParameterInformation");
                label = "";
                has_label_offsets = true;
            } else
                throw new DeserializeError.INVALID_TYPE (
                    "expected string or [uint, uint] for ParameterInformation.label");

            var doc_prop = lookup_property (dict, "documentation", VariantType.ANY,
                "ParameterInformation");
            if (doc_prop != null)
                documentation = new MarkupContent.from_variant (doc_prop);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (has_label_offsets) {
                Variant[] offsets = {
                    new Variant.uint64 (label_start),
                    new Variant.uint64 (label_end)
                };
                dict.insert_value ("label", offsets);
            } else
                dict.insert_value ("label", label);
            if (documentation != null)
                dict.insert_value (
                    "documentation",
                    documentation.to_variant ());
            return dict.end ();
        }
    }

    /**
     * Represents the signature of something callable. A signature
     * can have a label, a doc-comment, and a set of parameters.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_signature_information_ref",
        unref_function = "lsp_signature_information_unref")]
    public class SignatureInformation {
        private int ref_count = 1;

        public unowned SignatureInformation ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The label of this signature. Will be shown in the UI.
         */
        public string label { get; set; }

        /**
         * The human-readable doc-comment of this signature.
         *
         * Will be shown in the UI.
         */
        public MarkupContent? documentation { get; set; }

        /**
         * The parameters of this signature.
         */
        public ParameterInformation[]? parameters { get; set; }

        /**
         * The index of the active parameter.
         *
         * If provided, this is used in place of
         * {@link SignatureHelp.active_parameter}.
         *
         * @since 3.16.0
         */
        public uint? active_parameter { get; set; }

        public SignatureInformation (string label) {
            this.label = label;
        }

        public SignatureInformation.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;

            label = (string) expect_property (dict, "label", VariantType.STRING,
                "SignatureInformation");

            if ((prop = lookup_property (dict, "documentation", VariantType.ANY,
                "SignatureInformation")) != null)
                documentation = new MarkupContent.from_variant (
                    unwrap_variant (prop));

            if ((prop = lookup_property (dict, "parameters", VariantType.ARRAY,
                "SignatureInformation")) != null) {
                ParameterInformation[] params = {};
                foreach (var param_v in prop)
                    params += new ParameterInformation.from_variant (
                        expect_array_element (
                            param_v,
                            VariantType.VARDICT,
                            "SignatureInformation.parameters"));
                if (params.length > 0)
                    parameters = params;
            }

            if ((prop = dict.lookup_value ("activeParameter", null)) != null)
                active_parameter = (uint) parse_uinteger (
                    prop,
                    "activeParameter",
                    "SignatureInformation");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("label", label);

            if (documentation != null)
                dict.insert_value (
                    "documentation",
                    documentation.to_variant ());

            if (parameters != null) {
                Variant[] param_list = {};
                foreach (unowned var param in parameters)
                    param_list += param.to_variant ();
                dict.insert_value ("parameters",
                    new Variant.array (VariantType.VARDICT, param_list));
            }

            if (active_parameter != null)
                dict.insert_value ("activeParameter",
                    new Variant.uint64 ((uint64) active_parameter));

            return dict.end ();
        }
    }

    /**
     * Signature help represents the signature of something callable.
     * There can be multiple signature helps but only one active.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_signature_help_ref", unref_function = "lsp_signature_help_unref")]
    public class SignatureHelp {
        private int ref_count = 1;

        public unowned SignatureHelp ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * One or more signatures.
         */
        public SignatureInformation[] signatures { get; set; default = {}; }

        /**
         * The active signature. If omitted or the value lies outside
         * the range of `signatures`, the value defaults to zero or
         * is ignored if `signatures.length == 0`.
         */
        public uint active_signature { get; set; }

        /**
         * The active parameter of the active signature. If omitted or
         * the value lies outside the range of
         * `signatures[activeSignature].parameters`, it defaults to 0.
         */
        public uint active_parameter { get; set; }

        public SignatureHelp ((unowned SignatureInformation)[] signatures,
                              uint active_signature = 0, uint active_parameter = 0) {
            this.signatures = signatures;
            this.active_signature = active_signature;
            this.active_parameter = active_parameter;
        }

        public SignatureHelp.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;

            SignatureInformation[] sigs = {};
            foreach (var sig_v in expect_property (dict, "signatures", VariantType.ARRAY,
                "SignatureHelp"))
                sigs += new SignatureInformation.from_variant (
                    expect_array_element (
                        sig_v,
                        VariantType.VARDICT,
                        "SignatureHelp.signatures"));
            signatures = sigs;

            if ((prop = dict.lookup_value ("activeSignature", null)) != null)
                active_signature = (uint) parse_uinteger (
                    prop,
                    "activeSignature",
                    "SignatureHelp");

            if ((prop = dict.lookup_value ("activeParameter", null)) != null)
                active_parameter = (uint) parse_uinteger (
                    prop,
                    "activeParameter",
                    "SignatureHelp");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            Variant[] sig_list = {};
            foreach (unowned var sig in signatures)
                sig_list += sig.to_variant ();
            dict.insert_value ("signatures", new Variant.array (VariantType.VARDICT, sig_list));
            dict.insert_value ("activeSignature", new Variant.uint64 (active_signature));
            dict.insert_value ("activeParameter", new Variant.uint64 (active_parameter));
            return dict.end ();
        }
    }
}
