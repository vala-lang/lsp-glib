/* completion.vala
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
     * How whitespace and indentation is handled during completion item
     * insertion.
     *
     * @since 3.16.0
     */
    public enum InsertTextMode {
        UNSET               = 0,

        /**
         * The insertion or replacement string is taken as it is.
         *
         * If the value is multi line the lines below the cursor will be
         * inserted using the indentation defined in the string value.  The
         * client will not apply any kind of adjustments to the string.
         */
        AS_IS               = 1,

        /**
         * The editor adjusts leading whitespace of new lines so that
         * they match the indentation up to the cursor of the line for
         * which the item is accepted.
         *
         * Consider a line like this: <2tabs><cursor><3tabs>foo. Accepting a
         * multi line completion item is indented using 2 tabs and all
         * following lines inserted will be indented using 2 tabs as well.
         */
        ADJUST_INDENTATION  = 2
    }

    public enum InsertTextFormat {
        UNSET       = 0,

        /**
         * The primary text to be inserted is treated as a plain string.
         */
        PLAINTEXT   = 1,

        /**
         * The primary text to be inserted is treated as a snippet.
         *
         * A snippet can define tab stops and placeholders with `$1`, `$2`
         * and `${3:foo}`. `$0` defines the final tab stop, it defaults to
         * the end of the snippet. Placeholders with equal identifiers are linked,
         * that is typing in one will update others too.
         */
        SNIPPET     = 2
    }

    /**
     * The kind of a completion entry.
     */
    public enum CompletionItemKind {
        UNSET           = 0,
        TEXT            = 1,
        METHOD          = 2,
        FUNCTION        = 3,
        CONSTRUCTOR     = 4,
        FIELD           = 5,
        VARIABLE        = 6,
        CLASS           = 7,
        INTERFACE       = 8,
        MODULE          = 9,
        PROPERTY        = 10,
        UNIT            = 11,
        VALUE           = 12,
        ENUM            = 13,
        KEYWORD         = 14,
        SNIPPET         = 15,
        COLOR           = 16,
        FILE            = 17,
        REFERENCE       = 18,
        FOLDER          = 19,
        ENUM_MEMBER     = 20,
        CONSTANT        = 21,
        STRUCT          = 22,
        EVENT           = 23,
        OPERATOR        = 24,
        TYPE_PARAMETER  = 25
    }

    [Flags]
    public enum CompletionItemTag {
        NONE       = 0,
        DEPRECATED = 1
    }

    /**
     * How a completion was triggered.
     *
     * @since 3.2.0
     */
    public enum CompletionTriggerKind {
        /**
         * Completion was triggered by typing an identifier (automatic
         * code complete), manual invocation (e.g. Ctrl+Space) or via API.
         */
        INVOKED = 1,

        /**
         * Completion was triggered by a trigger character specified by
         * the `triggerCharacters` properties of the
         * `CompletionRegistrationOptions`.
         */
        TRIGGER_CHARACTER = 2,

        /**
         * Completion was re-triggered as the current completion list
         * is incomplete.
         *
         */
        TRIGGER_FOR_INCOMPLETE_COMPLETIONS = 3
    }

    /**
     * Contains additional information about the context in which a
     * completion request is triggered.
     *
     * @since 3.2.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_completion_context_ref",
        unref_function = "lsp_completion_context_unref")]
    public class CompletionContext {
        private int ref_count = 1;

        public unowned CompletionContext ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * How the completion was triggered.
         */
        public CompletionTriggerKind trigger_kind { get; set; }

        /**
         * The trigger character (a single character) that has triggered
         * code complete. Is null if
         * `trigger_kind !== CompletionTriggerKind.TRIGGER_CHARACTER`.
         */
        public string? trigger_character { get; set; }

        public CompletionContext (CompletionTriggerKind trigger_kind,
                                  string? trigger_character = null) {
            this.trigger_kind = trigger_kind;
            this.trigger_character = trigger_character;
        }

        public CompletionContext.from_variant (Variant dict) throws DeserializeError {
            var kind = expect_property (dict, "triggerKind", VariantType.INT64,
                "CompletionContext");
            trigger_kind = (CompletionTriggerKind) (int64) kind;
            var prop = lookup_property (dict, "triggerCharacter", VariantType.STRING,
                "CompletionContext");
            if (prop != null)
                trigger_character = (string) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("triggerKind", new Variant.int64 ((int64) trigger_kind));
            if (trigger_character != null)
                dict.insert_value ("triggerCharacter", trigger_character);
            return dict.end ();
        }
    }

    /**
     * Additional details for a completion item label.
     *
     * @since 3.17.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_completion_item_label_details_ref",
        unref_function = "lsp_completion_item_label_details_unref")]
    public class CompletionItemLabelDetails {
        private int ref_count = 1;

        public unowned CompletionItemLabelDetails ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * An optional string which is rendered less prominently directly
         * after detail, without any spacing.
         * Should be used for function signatures or type annotations.
         */
        public string? detail { get; set; }

        /**
         * An optional string which is rendered less prominently after
         * the detail string. Should be used for
         * fully qualified names or file paths.
         */
        public string? description { get; set; }

        public CompletionItemLabelDetails (string? detail = null, string? description = null) {
            this.detail = detail;
            this.description = description;
        }

        public CompletionItemLabelDetails.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;
            if ((prop = lookup_property (dict, "detail", VariantType.STRING,
                "CompletionItemLabelDetails")) != null)
                detail = (string) prop;
            if ((prop = lookup_property (dict, "description", VariantType.STRING,
                "CompletionItemLabelDetails")) != null)
                description = (string) prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            if (detail != null)
                dict.insert_value ("detail", detail);
            if (description != null)
                dict.insert_value ("description", description);
            return dict.end ();
        }
    }

    /**
     * Represents a collection of {@link CompletionItem} items to be
     * presented in the editor.
     *
     * @since 3.2.0
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_completion_list_ref", unref_function = "lsp_completion_list_unref")]
    public class CompletionList {
        private int ref_count = 1;

        public unowned CompletionList ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * This list is not complete. Further typing should result in
         * recomputing this list.
         *
         * Recomputed lists have all their items replaced (not appended)
         * in the incomplete completion sessions.
         */
        public bool is_incomplete { get; set; }

        /**
         * The completion items.
         */
        public CompletionItem[] items { get; set; default = {}; }

        public CompletionList (bool is_incomplete, (unowned CompletionItem)[] items) {
            this.is_incomplete = is_incomplete;
            this.items = items;
        }

        public CompletionList.from_variant (Variant dict) throws DeserializeError {
            is_incomplete = (bool) expect_property (dict, "isIncomplete", VariantType.BOOLEAN,
                "CompletionList");
            CompletionItem[] items = {};
            var items_v = expect_property (dict, "items", VariantType.ARRAY, "CompletionList");
            foreach (var item_v in items_v)
                items += new CompletionItem.from_variant (
                    expect_array_element (
                        item_v,
                        VariantType.VARDICT,
                        "CompletionList.items"));
            this.items = items;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();
            dict.insert_value ("isIncomplete", is_incomplete);
            Variant[] items_list = {};
            foreach (unowned var item in items)
                items_list += item.to_variant ();
            dict.insert_value ("items", new Variant.array (VariantType.VARDICT, items_list));
            return dict.end ();
        }
    }

    /**
     * A completion item is an option in a list of completions generated when
     * calling `textDocument/completion`.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_completion_item_ref", unref_function = "lsp_completion_item_unref")]
    public class CompletionItem {
        private int ref_count = 1;

        public unowned CompletionItem ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * The label of this completion item.
         *
         * The label property is also by default the text that is inserted
         * when selecting this completion.
         *
         * If label details are provided, the label itself should be an
         * unqualified name of the completion item.
         */
        public string label { get; set; }

        /**
         * Additional details for the label.
         *
         * @since 3.17.0
         */
        public CompletionItemLabelDetails? label_details { get; set; }

        /**
         * The kind of this completion item.
         */
        public CompletionItemKind kind { get; set; default = UNSET; }

        /**
         * Tags for this completion item.
         *
         * @since 3.15.0
         */
        public CompletionItemTag tags { get; set; default = NONE; }

        /**
         * A human-readable string with additional information about this
         * item, like type or symbol information.
         */
        public string? detail { get; set; }

        /**
         * A human-readable string that represents a doc-comment.
         */
        public MarkupContent? documentation { get; set; }

        /**
         * Select this item when showing.
         *
         * *Note* that only one completion item can be selected and that
         * the tool / client decides which item that is. The rule is that
         * the first item of those that match best is selected.
         */
        public bool preselect { get; set; }

        /**
         * A string that should be used when comparing this item with other
         * items. When omitted, the label is used as the sort text for this
         * item.
         */
        public string? sort_text { get; set; }

        /**
         * A string that should be used when filtering a set of completion
         * items. When omitted, the label is used as the filter text for
         * this item.
         */
        public string? filter_text { get; set; }

        /**
         * A string that should be inserted into a document when selecting
         * this completion. When `falsy` the label is used as the insert
         * text for this item.
         *
         * The `insertText` is subject to interpretation by the client side.  Some
         * tools might not take the string literally. For example VS Code when code
         * complete is requested in this example `con<cursor position>` and a
         * completion item with an `insertText` of `console` is provided it will
         * only insert `sole`. Therefore it is
         * recommended to use `textEdit` instead since it avoids additional client
         * side interpretation.
         */
        public string? insert_text { get; set; }

        /**
         * The format of the insert text. The format applies to both the
         * `insertText` property and the `newText` property of a provided
         * `textEdit`. If omitted defaults to `InsertTextFormat.PlainText`.
         */
        public InsertTextFormat insert_text_format {
            get;
            set;
            default = UNSET;
        }

        /**
         * How whitespace and indentation is handled during completion
         * item insertion. If not provided the client's default value depends on
         * the `textDocument.completion.insertTextMode` client capability.
         *
         * @since 3.16.0
         */
        public InsertTextMode insert_text_mode {
            get;
            set;
            default = UNSET;
        }

        /**
         * An edit which is applied to a document when selecting this completion.
         * When an edit is provided the value of `insertText` is ignored.
         *
         * *Note:* The range of the edit must be a single line range and it must
         * contain the position at which completion has been requested.
         *
         * Most editors support two different operations when accepting a completion
         * item. One is to insert a completion text and the other is to replace an
         * existing text with a completion text. Since this can usually not be
         * predetermined by a server it can report both ranges. Clients need to
         * signal support for `InsertReplaceEdit`s via the
         * `textDocument.completion.completionItem.insertReplaceSupport` client
         * capability property.
         *
         * *Note 1:* The text edit's range as well as both ranges from an insert
         * replace edit must be a [single line] and they must contain the position
         * at which completion has been requested.
         * *Note 2:* If an `InsertReplaceEdit` is returned the edit's insert range
         * must be a prefix of the edit's replace range, that means it must be
         * contained and starting at the same position.
         */
        public TextEdit? text_edit { get; owned set; }

        /**
         * An optional array of additional text edits that are applied when
         * selecting this completion. Edits must not overlap (including the same
         * insert position) with the main edit nor with themselves.
         *
         * Additional text edits should be used to change text unrelated to the
         * current cursor position (for example adding an import statement at the
         * top of the file if the completion item will insert an unqualified type).
         */
        public TextEdit[]? additional_text_edits { get; set; }

        /**
         * An optional set of characters that when pressed while this completion is
         * active will accept it first and then type that character. *Note* that all
         * commit characters should have `length=1` and that superfluous characters
         * will be ignored.
         */
        public string[]? commit_chars { get; set; }

        /**
         * An optional command that is executed *after* inserting this completion.
         * *Note* that additional modifications to the current document should be
         * described with the additionalTextEdits-property.
         */
        public Command? command { get; set; }

        /**
         * A data entry field that is preserved on a completion item between
         * a completion and a completion resolve request.
         */
        public Variant? data { get; set; }

        /**
         * Creates a new completion item with a label.
         *
         * @param label the string displayed for this completion item
         * @param kind  the type of completion item, or use {@link
         *              CompletionItemKind.UNSET} for a default
         */
        public CompletionItem (string label, CompletionItemKind kind = UNSET) {
            this.label = label;
            this.kind = kind;
        }

        public CompletionItem.from_variant (Variant dict) throws DeserializeError {
            Variant? prop = null;

            label = (string) expect_property (dict, "label", VariantType.STRING, "CompletionItem");

            if ((prop = lookup_property (dict, "labelDetails", VariantType.VARDICT,
                "CompletionItem")) != null)
                label_details = new CompletionItemLabelDetails.from_variant (prop);

            if ((prop = lookup_property (dict, "kind", VariantType.INT64,
                "CompletionItem")) != null)
                kind = (CompletionItemKind) (int64) prop;

            if ((prop = lookup_property (dict, "tags", VariantType.ARRAY,
                "CompletionItem")) != null) {
                CompletionItemTag parsed_tags = NONE;
                foreach (var tag_v in prop) {
                    var tag = expect_array_element (
                        tag_v,
                        VariantType.INT64,
                        "CompletionItem.tags");
                    if (tag.get_int64 () == (int64) CompletionItemTag.DEPRECATED)
                        parsed_tags |= CompletionItemTag.DEPRECATED;
                }
                tags = parsed_tags;
            }

            if ((prop = lookup_property (dict, "detail", VariantType.STRING,
                "CompletionItem")) != null)
                detail = (string) prop;

            if ((prop = lookup_property (dict, "documentation", VariantType.ANY,
                "CompletionItem")) != null)
                documentation = new MarkupContent.from_variant (
                    unwrap_variant (prop));

            if ((prop = lookup_property (dict, "preselect", VariantType.BOOLEAN,
                "CompletionItem")) != null)
                preselect = (bool) prop;

            if ((prop = lookup_property (dict, "sortText", VariantType.STRING,
                "CompletionItem")) != null)
                sort_text = (string) prop;

            if ((prop = lookup_property (dict, "filterText", VariantType.STRING,
                "CompletionItem")) != null)
                filter_text = (string) prop;

            if ((prop = lookup_property (dict, "insertText", VariantType.STRING,
                "CompletionItem")) != null)
                insert_text = (string) prop;

            if ((prop = lookup_property (dict, "insertTextFormat", VariantType.INT64,
                "CompletionItem")) != null)
                insert_text_format = (InsertTextFormat) (int64) prop;

            if ((prop = lookup_property (dict, "insertTextMode", VariantType.INT64,
                "CompletionItem")) != null)
                insert_text_mode = (InsertTextMode) (int64) prop;

            if ((prop = lookup_property (dict, "textEdit", VariantType.VARDICT,
                "CompletionItem")) != null) {
                if (prop.lookup_value ("range", null) != null)
                    text_edit = TextEdit.from_variant (prop);
            }

            if ((prop = lookup_property (dict, "additionalTextEdits", VariantType.ARRAY,
                "CompletionItem")) != null) {
                TextEdit[] edits = {};
                foreach (var edit_v in prop)
                    edits += TextEdit.from_variant (
                        expect_array_element (
                            edit_v,
                            VariantType.VARDICT,
                            "CompletionItem.additionalTextEdits"));
                if (edits.length > 0)
                    additional_text_edits = edits;
            }

            if ((prop = lookup_property (dict, "commitCharacters", VariantType.ARRAY,
                "CompletionItem")) != null)
                commit_chars = string_array_from_variant (
                    prop,
                    "CompletionItem.commitCharacters");

            if ((prop = lookup_property (dict, "command", VariantType.VARDICT,
                "CompletionItem")) != null)
                command = new Command.from_variant (prop);

            if ((prop = dict.lookup_value ("data", null)) != null)
                data = prop;
        }

        public Variant to_variant () {
            var dict = new VariantDict ();

            dict.insert_value ("label", label);

            if (label_details != null)
                dict.insert_value ("labelDetails", label_details.to_variant ());

            if (kind != UNSET)
                dict.insert_value ("kind", new Variant.int64 (kind));

            if (tags != NONE) {
                Variant[] tag_list = {};
                if (CompletionItemTag.DEPRECATED in tags)
                    tag_list += new Variant.int64 ((int64) CompletionItemTag.DEPRECATED);
                dict.insert_value ("tags", new Variant.array (VariantType.INT64, tag_list));
            }

            if (detail != null)
                dict.insert_value ("detail", detail);

            if (documentation != null)
                dict.insert_value (
                    "documentation",
                    documentation.to_variant ());

            if (preselect)
                dict.insert_value ("preselect", preselect);

            if (sort_text != null)
                dict.insert_value ("sortText", sort_text);

            if (filter_text != null)
                dict.insert_value ("filterText", filter_text);

            if (insert_text != null)
                dict.insert_value ("insertText", insert_text);

            if (insert_text_format != UNSET)
                dict.insert_value ("insertTextFormat", new Variant.int64 (insert_text_format));

            if (insert_text_mode != UNSET)
                dict.insert_value ("insertTextMode", new Variant.int64 (insert_text_mode));

            if (text_edit != null)
                dict.insert_value ("textEdit", text_edit.to_variant ());

            if (additional_text_edits != null) {
                Variant[] edits = {};
                foreach (unowned var edit in additional_text_edits)
                    edits += edit.to_variant ();
                dict.insert_value ("additionalTextEdits",
                    new Variant.array (VariantType.VARDICT, edits));
            }

            if (commit_chars != null)
                dict.insert_value ("commitCharacters", commit_chars);

            if (command != null)
                dict.insert_value ("command", command.to_variant ());

            if (data != null)
                dict.insert_value ("data", data);

            return dict.end ();
        }
    }
}
