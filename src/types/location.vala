/* location.vala
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
     * Position in a text document expressed as zero-based line and zero-based
     * character offset.
     *
     * A position is between two characters like an ‘insert’ cursor in a
     * editor. Special values like for example `-1` to denote the end of a line
     * are not supported.
     */
    public struct Position {
        /**
         * Line position in a document (zero-based).
         */
        public uint64 line;

        /**
         * Character offset on a line in a document (zero-based). Assuming that
         * the line is represented as a string, the `character` value
         * represents the gap between the `character` and `character + 1`.
         *
         * If the character value is greater than the line length it defaults
         * back to the line length.
         */
        public uint64 character;

        public Position (uint64 line, uint64 character) {
            this.line = line;
            this.character = character;
        }

        public Position.from_variant (Variant variant) throws DeserializeError {
            if (!variant.is_of_type (VariantType.VARDICT))
                throw new DeserializeError.INVALID_TYPE ("expected dictionary for Position");

            var prop = variant.lookup_value ("line", null);
            if (prop == null)
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `line` not found for Position");
            line = parse_uinteger ((!) prop, "line", "Position");

            prop = variant.lookup_value ("character", null);
            if (prop == null)
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `character` not found for Position");
            character = parse_uinteger (
                (!) prop,
                "character",
                "Position");
        }

        public Variant to_variant () {
            var variant = new VariantDict ();
            variant.insert_value ("line", line);
            variant.insert_value ("character", character);
            return variant.end ();
        }
    }

    /**
     * A range in a text document expressed as (zero-based) start and end
     * positions.
     *
     * A range is comparable to a selection in an editor. Therefore the end
     * position is exclusive. If you want to specify a range that contains a
     * line including the line ending character(s) then use an end position
     * denoting the start of the next line.
     */
    public struct Range {
        /**
         * The range's start position.
         */
        public Position start;

        /**
         * The range's end position.
         */
        public Position end;

        public Range (Position start, Position end) {
            this.start = start;
            this.end = end;
        }

        public Range.from_variant (Variant variant) throws DeserializeError {
            var start = variant.lookup_value ("start", VariantType.VARDICT);
            if (start != null)
                this.start = Position.from_variant ((!) start);
            else
                throw new DeserializeError.MISSING_PROPERTY (
                    "property `start` not found for Range");
            var end = variant.lookup_value ("end", VariantType.VARDICT);
            if (end != null)
                this.end = Position.from_variant ((!) end);
            else
                throw new DeserializeError.MISSING_PROPERTY ("property `end` not found for Range");
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("start", start.to_variant ());
            dict.insert_value ("end", end.to_variant ());
            return dict.end ();
        }
    }

    /**
     * Represents a location inside a resource, such as a line inside a text
     * file.
     */
    public struct Location {
        public Range range;
        public Uri uri { get; set; }

        public Location (Uri uri, Range range) {
            this.uri = uri;
            this.range = range;
        }

        public Location.from_variant (Variant variant) throws UriError, DeserializeError {
            var uri = (string) expect_property (
                variant,
                "uri",
                VariantType.STRING,
                "Location");
            this.uri = Uri.parse (uri, UriFlags.NONE);
            range = Range.from_variant (expect_property (
                variant,
                "range",
                VariantType.VARDICT,
                "Location"));
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("uri", uri.to_string ());
            dict.insert_value ("range", range.to_variant ());
            return dict.end ();
        }
    }
}
