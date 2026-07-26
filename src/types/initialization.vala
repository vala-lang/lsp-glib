/* initialization.vala
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
     * Information about the client/editor.
     *
     * @since 3.15.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_client_info_ref", unref_function = "lsp_client_info_unref")]
    public class ClientInfo {
        private int ref_count = 1;

        public unowned ClientInfo ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public string name { get; set; }
        public string? version { get; set; }

        public ClientInfo (string name, string? version = null) {
            this.name = name;
            this.version = version;
        }

        public ClientInfo.from_variant (Variant dict) throws DeserializeError {
            name = (string) expect_property (
                dict,
                "name",
                VariantType.STRING,
                "ClientInfo");

            var version_value = lookup_property (
                dict,
                "version",
                VariantType.STRING,
                "ClientInfo");
            if (version_value != null)
                version = (string) version_value;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("name", name);
            if (version != null)
                dict.insert_value ("version", version);
            return dict.end ();
        }
    }

    /**
     * Sent from the client / editor to the server.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_initialize_params_ref",
        unref_function = "lsp_initialize_params_unref")]
    public class InitializeParams {
        private int ref_count = 1;

        public unowned InitializeParams ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The process Id of the parent process that started the server.
         * Is `null` if the process has not been started by another process.
         * If the parent process is not alive, then the server should exit
         * its process.
         */
        public int64? process_id { get; set; }

        /**
         * Information about the client
         *
         * @since 3.15.0
         */
        public ClientInfo? client_info { get; set; }

        /**
         * The locale the client is currently showing the user interface
         * in. This must not necessarily be the locale of the operating
         * system.
         *
         * @since 3.16.0
         */
        public string? locale { get; set; }

        /**
         * (Kept for backwards compatibility)
         *
         * The rootPath of the workspace. Is null if no folder is open.
         *
         * @deprecated in favor of `rootUri`.
         */
        public string? root_path { get; set; }

        /**
         * (Kept for backwards compatibility)
         *
         * The rootUri of the workspace. Is null if no folder is open. If both
         * `rootPath` and `rootUri` are set `rootUri` wins.
         *
         * @deprecated in favor of `workspaceFolders`
         */
        public Uri? root_uri { get; set; }

        /**
         * The capabilities of the client / editor.
         */
        public ClientCaps? capabilities { get; set; }

        /**
         * The initial trace setting. If omitted, trace is disabled ('off').
         */
        public TraceValue trace { get; set; default = OFF; }

        /**
         * The workspace folders configured in the client when the server starts.
         * This property is only available if the client supports workspace folders.
         * It can be `null` if the client supports workspace folders but none are
         * configured.
         *
         * @since 3.6.0
         */
        public WorkspaceFolder[]? workspaces { get; set; }

        /**
         * User provided initialization options.
         */
        public Variant? initialization_options { get; set; }

        public InitializeParams (int64? process_id = null) {
            this.process_id = process_id;
        }

        /**
         * Creates initialization parameters with workspace folders.
         *
         * @param primary_workspace   the primary workspace folder
         * @param secondary_workspaces additional workspace folders
         */
        public InitializeParams.with_workspace_folders (WorkspaceFolder primary_workspace,
            (unowned WorkspaceFolder)[]? secondary_workspaces = null) throws ConvertError {
            this ();
            WorkspaceFolder[] temp_workspaces = {};

            root_uri = primary_workspace.uri;

            string root_uri_string = primary_workspace.uri.to_string ();

            root_path = Filename.from_uri (root_uri_string, null);

            temp_workspaces += primary_workspace;
            foreach (unowned var secondary_workspace in secondary_workspaces)
                temp_workspaces += secondary_workspace;
            workspaces = temp_workspaces;
        }

        public InitializeParams.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;

            if ((prop = dict.lookup_value ("processId", VariantType.INT64)) != null)
                process_id = (int64) prop;

            if ((prop = dict.lookup_value ("clientInfo", VariantType.VARDICT)) != null)
                client_info = new ClientInfo.from_variant (prop);

            if ((prop = dict.lookup_value ("locale", VariantType.STRING)) != null)
                locale = (string) prop;

            if ((prop = dict.lookup_value ("rootPath", VariantType.STRING)) != null)
                root_path = (string) prop;

            if ((prop = dict.lookup_value ("rootUri", VariantType.STRING)) != null) {
                try {
                    root_uri = Uri.parse ((string) prop, UriFlags.NONE);
                } catch (UriError e) {
                    throw new DeserializeError.INVALID_TYPE (
                        "invalid rootUri in InitializeParams: %s", e.message);
                }
            }

            if ((prop = dict.lookup_value ("capabilities", VariantType.VARDICT)) != null)
                capabilities = new ClientCaps.from_variant (prop);

            if ((prop = dict.lookup_value ("trace", VariantType.STRING)) != null)
                trace = TraceValue.parse_string ((string) prop);

            if ((prop = dict.lookup_value ("workspaceFolders", VariantType.ARRAY)) != null) {
                WorkspaceFolder[] folders = {};
                foreach (var folder_v in prop) {
                    try {
                        folders += new WorkspaceFolder.from_variant (
                            unwrap_variant (folder_v));
                    } catch (UriError e) {
                        throw new DeserializeError.INVALID_TYPE (
                            "invalid uri in workspaceFolders: %s",
                            e.message);
                    }
                }
                workspaces = folders;
            }

            if ((prop = dict.lookup_value ("initializationOptions", null)) != null)
                initialization_options = prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            if (process_id != null)
                dict.insert_value ("processId", (int64) process_id);
            if (client_info != null)
                dict.insert_value ("clientInfo", client_info.to_variant ());
            if (locale != null)
                dict.insert_value ("locale", locale);
            if (root_path != null)
                dict.insert_value ("rootPath", root_path);
            if (root_uri != null)
                dict.insert_value ("rootUri", root_uri.to_string ());
            if (capabilities != null)
                dict.insert_value ("capabilities", capabilities.to_variant ());
            if (trace != OFF)
                dict.insert_value ("trace", trace.to_string ());
            if (workspaces != null) {
                Variant[] workspaces_list = {};
                foreach (unowned var workspace in workspaces)
                    workspaces_list += workspace.to_variant ();
                dict.insert_value ("workspaceFolders",
                    new Variant.array (VariantType.VARDICT, workspaces_list));
            }
            if (initialization_options != null)
                dict.insert_value ("initializationOptions", initialization_options);

            return dict.end ();
        }
    }

    /**
     * Information about the server.
     *
     * @since 3.15.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_server_info_ref", unref_function = "lsp_server_info_unref")]
    public class ServerInfo {
        private int ref_count = 1;

        public unowned ServerInfo ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        public string name { get; set; }
        public string? version { get; set; }

        public ServerInfo (string name, string? version = null) {
            this.name = name;
            this.version = version;
        }

        public ServerInfo.from_variant (Variant dict) throws DeserializeError {
            Variant? prop;

            if ((prop = dict.lookup_value ("name", VariantType.STRING)) != null)
                name = (string) prop;
            if ((prop = dict.lookup_value ("version", VariantType.STRING)) != null)
                version = (string) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("name", name);
            if (version != null)
                dict.insert_value ("version", version);

            return dict.end ();
        }
    }

    /**
     * Sent from the language server to the client / editor after
     * initialization.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_initialize_result_ref",
        unref_function = "lsp_initialize_result_unref")]
    public class InitializeResult {
        private int ref_count = 1;

        public unowned InitializeResult ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The capabilities the language server provides.
         */
        public ServerCaps capabilities { get; set; }

        /**
         * Information about the server.
         *
         * @since 3.15.0
         */
        public ServerInfo? server_info { get; set; }

        public InitializeResult (ServerCaps capabilities) {
            this.capabilities = capabilities;
        }

        public InitializeResult.from_variant (Variant variant) throws DeserializeError {
            capabilities = new ServerCaps.from_variant (
                expect_property (variant, "capabilities", VariantType.VARDICT,
                    typeof (InitializeResult).name ()));

            Variant? prop;
            if ((prop = variant.lookup_value ("serverInfo", VariantType.VARDICT)) != null)
                server_info = new ServerInfo.from_variant (prop);
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("capabilities", capabilities.to_variant ());
            if (server_info != null)
                dict.insert_value ("serverInfo", server_info.to_variant ());

            return dict.end ();
        }
    }
}
