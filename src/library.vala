/* library.vala
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
    /*
     * jsonrpc-glib accepts a null reply result, but its async GIR parameter
     * is missing the nullable annotation. Keep the workaround internal.
     */
    [CCode (
        cname = "lsp_jsonrpc_client_reply_null_async",
        cheader_filename = "io/jsonrpc-reply.h",
        finish_name = "lsp_jsonrpc_client_reply_null_finish"
     )]
    extern async bool reply_null_async (
        Jsonrpc.Client client,
        Variant id,
        Cancellable? cancellable
    ) throws Error;

    public uint uri_hash (Uri uri) {
        return uri.to_string ().hash ();
    }

    public bool uri_equal (Uri a, Uri b) {
        return a.get_auth_params () == b.get_auth_params () &&
               a.get_fragment () == b.get_fragment () &&
               a.get_query () == b.get_query () &&
               a.get_path () == b.get_path () &&
               a.get_port () == b.get_port () &&
               a.get_host () == b.get_host () &&
               a.get_scheme () == b.get_scheme () &&
               a.get_userinfo () == b.get_userinfo ();
    }

    /**
     * Expect a property on a variant.
     */
    Variant expect_property (Variant dict, string property_name,
        VariantType expected_type,
        string parent_type_name) throws DeserializeError {
        if (!dict.is_of_type (VariantType.VARDICT))
            throw new DeserializeError.INVALID_TYPE ("expected dictionary for %s",
                parent_type_name);
        var prop = dict.lookup_value (property_name, expected_type);
        if (prop == null)
            throw new DeserializeError.MISSING_PROPERTY ("missing property `%s` for %s",
                property_name, parent_type_name);
        return prop;
    }

    Variant? lookup_property (Variant dict, string property_name,
        VariantType expected_type,
        string parent_type_name) throws DeserializeError {
        if (!dict.is_of_type (VariantType.VARDICT))
            throw new DeserializeError.INVALID_TYPE ("expected dictionary for %s",
                parent_type_name);
        return dict.lookup_value (property_name, expected_type);
    }

    Variant unwrap_variant (Variant variant) {
        Variant current = variant;
        while (current.is_of_type (VariantType.VARIANT))
            current = current.get_variant ();
        return current;
    }

    Variant expect_array_element (
        Variant element,
        VariantType expected_type,
        string parent_type_name
    ) throws DeserializeError {
        var value = unwrap_variant (element);
        if (!value.is_of_type (expected_type))
            throw new DeserializeError.INVALID_TYPE (
                "unexpected array element type in %s",
                parent_type_name);
        return value;
    }

    string[] string_array_from_variant (
        Variant array,
        string parent_type_name
    ) throws DeserializeError {
        string[] values = {};
        foreach (var element in array)
            values += (string) expect_array_element (
                element,
                VariantType.STRING,
                parent_type_name);
        return values;
    }

    uint64 parse_uinteger (
        Variant value,
        string property_name,
        string parent_type_name
    ) throws DeserializeError {
        var unwrapped = unwrap_variant (value);
        if (unwrapped.is_of_type (VariantType.UINT64))
            return (uint64) unwrapped;
        if (unwrapped.is_of_type (VariantType.INT64) &&
            (int64) unwrapped >= 0)
            return (uint64) (int64) unwrapped;
        throw new DeserializeError.INVALID_TYPE (
            "property `%s` on %s must be a non-negative integer",
            property_name,
            parent_type_name);
    }
}
