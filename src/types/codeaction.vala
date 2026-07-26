namespace Lsp {
    public enum CodeActionKind {
        /**
         * Empty kind.
         */
        EMPTY,

        /**
         * Base kind for quickfix actions: 'quickfix'.
         */
        QUICK_FIX,

        /**
         * Base kind for refactoring actions: 'refactor'.
         */
        REFACTOR,

        /**
         * Base kind for refactoring extraction actions: 'refactor.extract'.
         *
         * Example extract actions:
         *
         * - Extract method
         * - Extract function
         * - Extract variable
         * - Extract interface from class
         * - ...
         */
        REFACTOR_EXTRACT,

        /**
         * Base kind for refactoring inline actions: 'refactor.inline'.
         *
         * Example inline actions:
         *
         * - Inline function
         * - Inline variable
         * - Inline constant
         * - ...
         */
        REFACTOR_INLINE,

        /**
         * Base kind for refactoring rewrite actions: 'refactor.rewrite'.
         *
         * Example rewrite actions:
         *
         * - Convert JavaScript function to class
         * - Add or remove parameter
         * - Encapsulate field
         * - Make method static
         * - Move method to base class
         * - ...
         */
        REFACTOR_REWRITE,

        /**
         * Base kind for source actions: `source`.
         *
         * Source code actions apply to the entire file.
         */
        SOURCE,

        /**
         * Base kind for an organize imports source action:
         * `source.organizeImports`.
         */
        SOURCE_ORGANIZE_IMPORTS,

        /**
         * Base kind for a 'fix all' source action: `source.fixAll`.
         *
         * 'Fix all' actions automatically fix errors that have a clear fix that
         * do not require user input. They should not suppress errors or perform
         * unsafe fixes such as generating new types or classes.
         *
         * @since 3.17.0
         */
        SOURCE_FIX_ALL;

        public unowned string to_string () {
            switch (this) {
                case EMPTY:
                    return "";
                case QUICK_FIX:
                    return "quickfix";
                case REFACTOR:
                    return "refactor";
                case REFACTOR_EXTRACT:
                    return "refactor.extract";
                case REFACTOR_INLINE:
                    return "refactor.inline";
                case REFACTOR_REWRITE:
                    return "refactor.rewrite";
                case SOURCE:
                    return "source";
                case SOURCE_ORGANIZE_IMPORTS:
                    return "source.organizeImports";
                case SOURCE_FIX_ALL:
                    return "source.fixAll";
            }

            assert_not_reached ();
        }

        public static CodeActionKind parse_variant (Variant variant) throws DeserializeError {
            if (!variant.is_of_type (VariantType.STRING))
                throw new DeserializeError.INVALID_TYPE ("expected string for CodeActionKind");

            switch ((string) variant) {
                case "quickfix":
                    return QUICK_FIX;
                case "refactor":
                    return REFACTOR;
                case "refactor.extract":
                    return REFACTOR_EXTRACT;
                case "refactor.inline":
                    return REFACTOR_INLINE;
                case "refactor.rewrite":
                    return REFACTOR_REWRITE;
                case "source":
                    return SOURCE;
                case "source.organizeImports":
                    return SOURCE_ORGANIZE_IMPORTS;
                case "source.fixAll":
                    return SOURCE_FIX_ALL;
                default:
                    return EMPTY;
            }
        }
    }

    /**
     * The reason why code actions were requested.
     *
     * @since 3.17.0
     */
    public enum CodeActionTriggerKind {
        /**
         * No trigger or unknown.
         */
        UNSET     = 0,

        /**
         * Code actions were explicitly requested by the user or by an extension.
         */
        INVOKED   = 1,

        /**
         * Code actions were requested automatically.
         *
         * This typically happens when current selection in a file changes, but can
         * also be triggered when file content changes.
         */
        AUTOMATIC = 2;

        public static CodeActionTriggerKind parse_variant (
            Variant variant) throws DeserializeError {
            if (!variant.is_of_type (VariantType.INT64))
                throw new DeserializeError.INVALID_TYPE (
                    "expected int64 for CodeActionTriggerKind");
            switch ((int64) variant) {
                case INVOKED:
                case AUTOMATIC:
                    return (CodeActionTriggerKind) (int64) variant;
                default:
                    throw new DeserializeError.INVALID_TYPE ("expected CodeActionTriggerKind");
            }
        }
    }

    /**
     * Contains additional diagnostic information about the context in which
     * a code action is run.
     */
    [Compact (opaque = true)]
    [CCode (ref_function = "lsp_code_action_context_ref",
        unref_function = "lsp_code_action_context_unref")]
    public class CodeActionContext {
        private int ref_count = 1;

        public unowned CodeActionContext ref () {
            AtomicInt.add (ref this.ref_count, 1);
            return this;
        }

        public void unref () {
            if (AtomicInt.dec_and_test (ref this.ref_count))
                this.free ();
        }

        private extern void free ();

        /**
         * An array of diagnostics known on the client side overlapping the range
         * provided to the `textDocument/codeAction` request. They are provided so
         * that the server knows which errors are currently presented to the user
         * for the given range. There is no guarantee that these accurately reflect
         * the error state of the resource. The primary parameter
         * to compute code actions is the provided range.
         */
        public Diagnostic[] diagnostics { get; set; default = {}; }

        /**
         * Requested kind of actions to return.
         *
         * Actions not of this kind are filtered out by the client before being
         * shown. So servers can omit computing them.
         */
        public CodeActionKind[]? only { get; set; }

        /**
         * The reason why code actions were requested.
         *
         * @since 3.17.0
         */
        public CodeActionTriggerKind trigger { get; set; default = UNSET; }

        /**
         * Deserializes a code action context from a {@link GLib.Variant}
         */
        public CodeActionContext.from_variant (Variant variant) throws Error {
            Diagnostic[] diagnostics = {};
            foreach (var diag in expect_property (variant, "diagnostics", VariantType.ARRAY,
                "CodeActionContext")) {
                diagnostics += new Diagnostic.from_variant (
                    expect_array_element (
                        diag,
                        VariantType.VARDICT,
                        "CodeActionContext.diagnostics"));
            }
            this.diagnostics = diagnostics;

            Variant? only_variant = lookup_property (variant, "only", VariantType.ARRAY,
                "CodeActionContext");
            if (only_variant != null) {
                CodeActionKind[] only = {};
                foreach (var kind in only_variant)
                    only += CodeActionKind.parse_variant (
                        expect_array_element (
                            kind,
                            VariantType.STRING,
                            "CodeActionContext.only"));
                this.only = only;
            }

            Variant? trigger_variant = lookup_property (variant, "triggerKind", VariantType.INT64,
                "CodeActionContext");
            if (trigger_variant != null)
                trigger = CodeActionTriggerKind.parse_variant (trigger_variant);
        }

        /**
         * Serializes this {@link Lsp.CodeActionContext} to a {@link GLib.Variant}
         */
        public Variant to_variant () {
            var variant = new VariantDict ();

            Variant[] diagnostics_list = {};
            foreach (var diag in diagnostics)
                diagnostics_list += diag.to_variant ();
            variant.insert_value ("diagnostics", diagnostics_list);

            if (only != null) {
                Variant[] only_list = {};
                foreach (var kind in only)
                    only_list += kind.to_string ();
                variant.insert_value ("only", only_list);
            }

            if (trigger != CodeActionTriggerKind.UNSET)
                variant.insert_value (
                    "triggerKind",
                    new Variant.int64 (trigger));

            return variant.end ();
        }
    }

    /**
     * A code action represents a change that can be performed in code, e.g. to fix
     * a problem or to refactor code.
     *
     * A CodeAction must set either `edit` and/or a `command`. If both are supplied,
     * the `edit` is applied first, then the `command` is executed.
     */
    public class CodeAction : Action {
        /**
         * The kind of the code action.
         *
         * Used to filter code actions.
         */
        public CodeActionKind kind { get; set; }

        /**
         * Marks this as a preferred action. Preferred actions are used by the
         * `auto fix` command and can be targeted by keybindings.
         *
         * A quick fix should be marked preferred if it properly addresses the
         * underlying error. A refactoring should be marked preferred if it is the
         * most reasonable choice of actions to take.
         *
         * @since 3.15.0
         */
        public bool preferred { get; set; }

        /**
         * Human readable description of why the code action is currently
         * disabled, if it is disabled.
         *
         * This is displayed in the code actions UI. When non-null, this
         * indicates that the code action cannot currently be applied.
         *
         * Clients should follow the following guidelines regarding disabled code
         * actions:
         *
         *  * Disabled code actions are not shown in automatic lightbulbs code
         *    action menus.
         *
         *  * Disabled actions are shown as faded out in the code action menu when
         *    the user request a more specific type of code action, such as
         *    refactorings.
         *
         *  * If the user has a keybinding that auto applies a code action and only
         *    a disabled code actions are returned, the client should show the user
         *    an error message with `reason` in the editor.
         *
         *
         * @since 3.16.0
         */
        public string? disabled_reason { get; set; }

        /**
         * The diagnostics that this code action resolves.
         */
        public Diagnostic[]? diagnostics { get; set; }

        /**
         * The workspace edit this code action performs.
         */
        public WorkspaceEdit? edit { get; set; }

        /**
         * A command this code action executes. If a code action
         * provides an edit and a command, first the edit is
         * executed and then the command.
         */
        public Command? command { get; set; }

        /**
         * A data entry field that is preserved on a code action between
         * a `textDocument/codeAction` and a `codeAction/resolve` request.
         *
         * @since 3.16.0
         */
        public Variant? data { get; set; }

        /**
         * Creates a new {@link Lsp.CodeAction}
         */
        public CodeAction (string title) {
            base (title);
        }

        public CodeAction.from_variant (Variant variant) throws DeserializeError, UriError {
            base ((string) expect_property (variant, "title", VariantType.STRING, "LspCodeAction"));

            Variant? prop = lookup_property (
                variant,
                "kind",
                VariantType.STRING,
                "LspCodeAction");
            if (prop != null)
                kind = CodeActionKind.parse_variant (prop);

            prop = lookup_property (
                variant,
                "isPreferred",
                VariantType.BOOLEAN,
                "LspCodeAction");
            if (prop == null)
                prop = lookup_property (
                    variant,
                    "preferred",
                    VariantType.BOOLEAN,
                    "LspCodeAction");
            if (prop != null)
                preferred = (bool) prop;

            var disabled = lookup_property (
                variant,
                "disabled",
                VariantType.VARDICT,
                "LspCodeAction");
            if (disabled != null)
                disabled_reason = (string) expect_property (
                    disabled,
                    "reason",
                    VariantType.STRING,
                    "CodeAction.disabled");

            Diagnostic[] diagnostics = {};
            prop = lookup_property (
                variant,
                "diagnostics",
                VariantType.ARRAY,
                "LspCodeAction");
            if (prop != null) {
                foreach (var vdiag in prop)
                    diagnostics += new Diagnostic.from_variant (
                        expect_array_element (
                            vdiag,
                            VariantType.VARDICT,
                            "CodeAction.diagnostics"));
                this.diagnostics = diagnostics;
            }

            if ((prop = lookup_property (variant, "edit", VariantType.VARDICT,
                "LspCodeAction")) != null)
                edit = new WorkspaceEdit.from_variant (prop);

            if ((prop = lookup_property (variant, "command", VariantType.VARDICT,
                "LspCodeAction")) != null)
                command = new Command.from_variant (prop);

            data = variant.lookup_value ("data", null);
        }

        public override Variant to_variant () {
            var variant = new VariantDict ();

            variant.insert_value ("title", title);
            if (kind != CodeActionKind.EMPTY)
                variant.insert_value ("kind", kind.to_string ());
            if (preferred)
                variant.insert_value ("isPreferred", preferred);
            if (disabled_reason != null) {
                var disabled_dict = new VariantDict ();
                disabled_dict.insert_value ("reason", disabled_reason);
                variant.insert_value ("disabled", disabled_dict.end ());
            }
            if (diagnostics != null) {
                Variant[] diagnostics_list = {};
                foreach (var diag in diagnostics)
                    diagnostics_list += diag.to_variant ();
                variant.insert_value ("diagnostics", diagnostics_list);
            }
            if (edit != null)
                variant.insert_value ("edit", edit.to_variant ());
            if (command != null)
                variant.insert_value ("command", command.to_variant ());
            if (data != null)
                variant.insert_value ("data", data);

            return variant.end ();
        }
    }
}
