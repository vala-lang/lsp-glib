/* workspace.vala
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
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_workspace_folder_ref",
        unref_function = "lsp_workspace_folder_unref")]
    public class WorkspaceFolder {
        private int ref_count = 1;

        public unowned WorkspaceFolder ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The URI associated with the root of this workspace folder.
         */
        public Uri uri { get; set; }

        /**
         * The name of this workspace folder. Used to refer to this workspace
         * folder in the user interface.
         */
        public string name { get; set; }

        public WorkspaceFolder (Uri uri, string name) {
            this.uri = uri;
            this.name = name;
        }

        public WorkspaceFolder.from_variant (Variant dict) throws DeserializeError, UriError {
            uri = Uri.parse (
                (string) expect_property (
                    dict,
                    "uri",
                    VariantType.STRING,
                    "WorkspaceFolder"),
                UriFlags.NONE);
            name = (string) expect_property (
                dict,
                "name",
                VariantType.STRING,
                "WorkspaceFolder");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("uri", uri.to_string ());
            dict.insert_value ("name", name);
            return dict.end ();
        }
    }
}
