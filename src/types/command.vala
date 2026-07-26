/* command.vala
 *
 * Copyright 2021-2022 Princeton Ferro <princetonferro@gmail.com>
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
     * A generic action that can be performed, such as a command or a
     * refactoring. This is more generic than {@link Lsp.ResourceOperation}.
     */
    public abstract class Action {
        /**
         * Title of the command or action, like `save` or `organize imports`.
         */
        public string title { get; set; }

        protected Action (string title) {
            this.title = title;
        }

        /**
         * Deserializes either a {@link Command} or a {@link CodeAction}.
         */
        public static Action from_variant (
            Variant variant
        ) throws DeserializeError, UriError {
            var command = variant.lookup_value ("command", null);
            if (command != null &&
                unwrap_variant (command).is_of_type (VariantType.STRING))
                return new Command.from_variant (variant);
            return new CodeAction.from_variant (variant);
        }

        /**
         * Serialize this action to a {@link GLib.Variant}
         */
        public abstract Variant to_variant ();
    }

    /**
     * Represents a reference to a command.
     *
     * Provides a title which will be used to represent a command in the UI.
     * Commands are identified by a string identifier. The recommended way to
     * handle commands is to implement their execution on the server side if
     * the client and server provides the corresponding capabilities.
     * Alternatively the tool extension code could handle the command. The
     * protocol currently doesn’t specify a set of well-known commands.
     */
    public class Command : Action {
        /**
         * The identifier of the actual command handler.
         */
        public string command { get; set; }

        /**
         * Arguments that the command handler should be invoked with.
         */
        public Variant[]? arguments { get; set; }

        /**
         * Creates a new {@link Lsp.Command}
         *
         * {@inheritDoc}
         */
        public Command (string title, string command, Variant[]? arguments = null) {
            base (title);
            this.command = command;
            this.arguments = arguments;
        }

        public Command.from_variant (Variant variant) throws DeserializeError {
            base ((string) expect_property (variant, "title", VariantType.STRING, "LspCommand"));
            this.command = (string) expect_property (variant, "command", VariantType.STRING,
                "LspCommand");
            Variant? prop = lookup_property (variant, "arguments", VariantType.ARRAY, "LspCommand");
            if (prop != null) {
                Variant[] arguments = {};
                foreach (var varg in prop)
                    arguments += unwrap_variant (varg);
                if (arguments.length > 0)
                    this.arguments = arguments;
            }
        }

        public override Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("title", title);
            variant.insert_value ("command", command);
            if (arguments != null)
                variant.insert_value ("arguments", arguments);

            return variant.end ();
        }
    }
}
