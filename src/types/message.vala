/* message.vala
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
     * Used when showing a message in the editor.
     *
     * @see Lsp.Client.show_message_async
     * @see Lsp.Client.ask_message_async
     */
    public enum MessageType {
        /**
         * Unknown message type. (Non-standard)
         */
        UNKNOWN = 0,
        ERROR   = 1,
        WARNING = 2,
        INFO    = 3,
        LOG     = 4;

        public static MessageType parse_int (int value) {
            if (value == ERROR || value == WARNING || value == INFO || value == LOG)
                return (MessageType) value;
            return UNKNOWN;
        }
    }

    /**
     * Used to show an action in a prompt in the editor.
     *
     * @see Lsp.Client.ask_message_async
     */
    public struct MessageActionItem {
        /**
         * A short title like 'Retry', 'Open Log', etc.
         */
        public string title { get; set; }

        public MessageActionItem (string title) {
            this.title = title;
        }

        public MessageActionItem.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;

            if ((prop = dict.lookup_value ("title", VariantType.STRING)) != null)
                this.title = (string) prop;
            else
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `title` not found for MessageActionItem");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("title", title);
            return dict.end ();
        }
    }
}
