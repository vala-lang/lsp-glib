import GLib from 'gi://GLib';
import Lsp from 'gi://Lsp?version=3.0';

const assertEqual = (actual, expected, message) => {
    if (actual !== expected)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
};

const assert = (condition, message) => {
    if (!condition)
        throw new Error(message);
};

const makeRange = (startLine, startCharacter, endLine, endCharacter) => {
    const start = new Lsp.Position();
    start.init(startLine, startCharacter);
    const end = new Lsp.Position();
    end.init(endLine, endCharacter);
    const range = new Lsp.Range();
    range.init(start, end);
    return range;
};

assertEqual(Lsp.language_id_to_string(Lsp.LanguageId.GENIE), 'genie',
    'Genie language identifier did not serialize');
assertEqual(Lsp.language_id_parse_string('genie'), Lsp.LanguageId.GENIE,
    'Genie language identifier did not parse');

const edit = new Lsp.TextEdit();
edit.init(makeRange(3, 4, 3, 9), 'print(${1:value})', null);

const item = Lsp.CompletionItem.new('print', Lsp.CompletionItemKind.FUNCTION);
item.set_label_details(Lsp.CompletionItemLabelDetails.new('(value)', 'GLib'));
item.set_documentation(Lsp.MarkupContent.new(
    Lsp.MarkupKind.MARKDOWN,
    '**Print** a value.',
));
item.set_deprecated(true);
item.set_commit_chars([';', '(']);
item.set_insert_text_format(Lsp.InsertTextFormat.SNIPPET);
item.set_text_edit(edit);
item.set_data(new GLib.Variant('s', 'completion-token'));

const completion = Lsp.CompletionList.from_variant(
    Lsp.CompletionList.new(true, [item]).to_variant(),
);
const [decodedItem] = completion.get_items();
assert(completion.get_is_incomplete(), 'completion list lost incomplete state');
assertEqual(decodedItem.get_label(), 'print', 'completion label did not round-trip');
assert(decodedItem.get_deprecated(), 'completion deprecated state did not round-trip');
assertEqual(decodedItem.get_insert_text_format(), Lsp.InsertTextFormat.SNIPPET,
    'insert text format did not round-trip');
assertEqual(decodedItem.get_text_edit().get_new_text(), 'print(${1:value})',
    'text edit did not round-trip');
assertEqual(decodedItem.get_data().deepUnpack(), 'completion-token',
    'completion data did not round-trip');

const highlight = new Lsp.DocumentHighlight();
highlight.init(makeRange(2, 3, 2, 9), Lsp.DocumentHighlightKind.WRITE);
const decodedHighlight = new Lsp.DocumentHighlight();
decodedHighlight.init_from_variant(highlight.to_variant());
assertEqual(decodedHighlight.get_kind(), Lsp.DocumentHighlightKind.WRITE,
    'document highlight kind did not round-trip');
assertEqual(decodedHighlight.get_range().start.character, 3,
    'document highlight range did not round-trip');

const referenceContext = new Lsp.ReferenceContext();
referenceContext.init(false);
const decodedReferenceContext = new Lsp.ReferenceContext();
decodedReferenceContext.init_from_variant(referenceContext.to_variant());
assert(!decodedReferenceContext.get_include_declaration(),
    'reference context did not round-trip');

const formattingOptions = new Lsp.FormattingOptions();
formattingOptions.init(4, true);
formattingOptions.set_flags(
    Lsp.FormattingOptionFlags.TRIM_TRAILING_WHITESPACE |
    Lsp.FormattingOptionFlags.INSERT_FINAL_NEWLINE |
    Lsp.FormattingOptionFlags.TRIM_FINAL_NEWLINES,
);
const decodedFormattingOptions = new Lsp.FormattingOptions();
decodedFormattingOptions.init_from_variant(formattingOptions.to_variant());
assertEqual(decodedFormattingOptions.get_tab_size(), 4,
    'formatting tab size did not round-trip');
assert(decodedFormattingOptions.get_insert_spaces(),
    'formatting insert-spaces setting did not round-trip');
assert(decodedFormattingOptions.get_flags() &
    Lsp.FormattingOptionFlags.TRIM_TRAILING_WHITESPACE,
'formatting whitespace flag did not round-trip');
assert(decodedFormattingOptions.get_flags() &
    Lsp.FormattingOptionFlags.INSERT_FINAL_NEWLINE,
'formatting final-newline flag did not round-trip');
assert(decodedFormattingOptions.get_flags() &
    Lsp.FormattingOptionFlags.TRIM_FINAL_NEWLINES,
'formatting final-newlines flag did not round-trip');

const rootUri = GLib.Uri.parse('file:///workspace', GLib.UriFlags.NONE);
const capabilities = Lsp.ServerCaps.new();
const codeLensOptions = new Lsp.CodeLensOptions();
codeLensOptions.init(true);
const documentLinkOptions = new Lsp.DocumentLinkOptions();
documentLinkOptions.init(true);
const renameOptions = new Lsp.RenameOptions();
renameOptions.init(true);
const callHierarchyOptions = new Lsp.CallHierarchyOptions();
callHierarchyOptions.init();
const typeHierarchyOptions = new Lsp.TypeHierarchyOptions();
typeHierarchyOptions.init();
const inlayHintOptions = new Lsp.InlayHintOptions();
inlayHintOptions.init(true);
capabilities.set_text_document_sync(Lsp.TextDocumentSyncKind.INCREMENTAL);
capabilities.set_completion(Lsp.CompletionOptions.new(true, ['.', ':']));
capabilities.set_hover(true);
capabilities.set_code_lens(codeLensOptions);
capabilities.set_document_link(documentLinkOptions);
capabilities.set_rename(renameOptions);
capabilities.set_call_hierarchy(callHierarchyOptions);
capabilities.set_type_hierarchy(typeHierarchyOptions);
capabilities.set_inlay_hint(inlayHintOptions);

const params = Lsp.InitializeParams.new(null);
params.set_client_info(Lsp.ClientInfo.new('GJS Test Editor', '1.0'));
params.set_locale('en-US');
params.set_root_uri(rootUri);
params.set_trace(Lsp.TraceValue.MESSAGES);
params.set_workspaces([Lsp.WorkspaceFolder.new(rootUri, 'workspace')]);

const decodedParams = Lsp.InitializeParams.from_variant(params.to_variant());
assertEqual(decodedParams.get_client_info().get_name(), 'GJS Test Editor',
    'client info did not round-trip');
assertEqual(decodedParams.get_locale(), 'en-US', 'locale did not round-trip');
assertEqual(decodedParams.get_trace(), Lsp.TraceValue.MESSAGES,
    'trace did not round-trip');
assertEqual(decodedParams.get_workspaces().length, 1,
    'workspace folders did not round-trip');

const result = Lsp.InitializeResult.new(capabilities);
result.set_server_info(Lsp.ServerInfo.new('GJS Test Server', '1.0'));
const decodedResult = Lsp.InitializeResult.from_variant(result.to_variant());
assertEqual(decodedResult.get_capabilities().get_text_document_sync(),
    Lsp.TextDocumentSyncKind.INCREMENTAL,
    'text document sync capability did not round-trip');
assert(decodedResult.get_capabilities().get_completion().get_supports_resolve(),
    'completion resolve capability did not round-trip');
assert(decodedResult.get_capabilities().get_hover(),
    'hover capability did not round-trip');
assert(decodedResult.get_capabilities().get_code_lens().get_supported(),
    'code lens capability did not round-trip');
assert(decodedResult.get_capabilities().get_code_lens().get_supports_resolve(),
    'code lens resolve capability did not round-trip');
assert(decodedResult.get_capabilities().get_document_link().get_supported(),
    'document link capability did not round-trip');
assert(decodedResult.get_capabilities().get_document_link().get_supports_resolve(),
    'document link resolve capability did not round-trip');
assert(decodedResult.get_capabilities().get_rename().get_supported(),
    'rename capability did not round-trip');
assert(decodedResult.get_capabilities().get_rename().get_supports_prepare(),
    'prepare rename capability did not round-trip');
assert(decodedResult.get_capabilities().get_call_hierarchy().get_supported(),
    'call hierarchy capability did not round-trip');
assert(decodedResult.get_capabilities().get_type_hierarchy().get_supported(),
    'type hierarchy capability did not round-trip');
assert(decodedResult.get_capabilities().get_inlay_hint().get_supported(),
    'inlay hint capability did not round-trip');
assert(decodedResult.get_capabilities().get_inlay_hint().get_resolve_provider(),
    'inlay hint resolve capability did not round-trip');

const uri = GLib.Uri.parse(
    'file:///workspace/generated.vala',
    GLib.UriFlags.NONE,
);
const create = Lsp.CreateFile.new();
create.set_uri(uri);
create.set_options(Lsp.CreateFileOptions.OVERWRITE);
create.set_annotation_id('create-file');

const workspaceEdit = Lsp.WorkspaceEdit.new();
workspaceEdit.add_document_change(create);
workspaceEdit.set_change_annotation(
    'create-file',
    Lsp.ChangeAnnotation.new(
        'Create generated source',
        true,
        'The file is generated by the compiler.',
    ),
);

const decodedWorkspaceEdit = Lsp.WorkspaceEdit.from_variant(
    workspaceEdit.to_variant(),
);
const [documentChange] = decodedWorkspaceEdit.get_document_changes();
assert(documentChange instanceof Lsp.CreateFile,
    'workspace edit lost its typed document change');
assertEqual(documentChange.get_uri().to_string(), uri.to_string(),
    'workspace edit URI did not round-trip');
assertEqual(decodedWorkspaceEdit.get_change_annotations()['create-file'].get_label(),
    'Create generated source',
    'change annotation did not round-trip');

const symbolRange = makeRange(0, 0, 5, 1);
const symbolSelection = makeRange(0, 6, 0, 13);
const documentSymbol = Lsp.DocumentSymbol.new(
    'Example',
    Lsp.SymbolKind.CLASS,
    symbolRange,
    symbolSelection,
    null,
    Lsp.SymbolTag.UNSET,
);
const hierarchicalSymbols = Lsp.DocumentSymbolResult.for_document_symbols([
    documentSymbol,
]);
const decodedHierarchical = Lsp.DocumentSymbolResult.from_variant(
    hierarchicalSymbols.to_variant(),
);
assertEqual(decodedHierarchical.get_document_symbols()[0].get_name(), 'Example',
    'hierarchical document symbols did not round-trip');
assertEqual(decodedHierarchical.get_symbol_information().length, 0,
    'hierarchical result populated its flat alternative');

const symbolLocation = new Lsp.Location();
symbolLocation.init(uri, symbolRange);
const flatSymbol = Lsp.SymbolInformation.new(
    'Example',
    Lsp.SymbolKind.CLASS,
    symbolLocation,
    null,
    Lsp.SymbolTag.UNSET,
);
const flatSymbols = Lsp.DocumentSymbolResult.for_symbol_information([flatSymbol]);
const decodedFlat = Lsp.DocumentSymbolResult.from_variant(flatSymbols.to_variant());
assertEqual(decodedFlat.get_document_symbols().length, 0,
    'flat result populated its hierarchical alternative');
assertEqual(decodedFlat.get_symbol_information()[0].get_name(), 'Example',
    'flat symbol information did not round-trip');

const preparedRename = new Lsp.PrepareRenameResult();
preparedRename.init_for_range(symbolRange, 'old_name');
const decodedPreparedRename = new Lsp.PrepareRenameResult();
decodedPreparedRename.init_from_variant(preparedRename.to_variant());
assert(decodedPreparedRename.has_range, 'prepare rename lost its range');
assertEqual(decodedPreparedRename.placeholder, 'old_name',
    'prepare rename lost its placeholder');

const defaultRename = new Lsp.PrepareRenameResult();
defaultRename.init_for_default_behavior(true);
const decodedDefaultRename = new Lsp.PrepareRenameResult();
decodedDefaultRename.init_from_variant(defaultRename.to_variant());
assert(!decodedDefaultRename.has_range,
    'default prepare rename unexpectedly has a range');
assert(decodedDefaultRename.default_behavior,
    'prepare rename lost default behavior');

const hierarchyItem = Lsp.TypeHierarchyItem.new(
    'Example',
    Lsp.SymbolKind.CLASS,
    uri,
    symbolRange,
    symbolSelection,
    'class Example',
    Lsp.SymbolTag.DEPRECATED,
);
hierarchyItem.set_data(new GLib.Variant('s', 'hierarchy-token'));
const decodedHierarchyItem = Lsp.TypeHierarchyItem.from_variant(
    hierarchyItem.to_variant(),
);
assertEqual(decodedHierarchyItem.get_name(), 'Example',
    'type hierarchy item name did not round-trip');
assertEqual(decodedHierarchyItem.get_kind(), Lsp.SymbolKind.CLASS,
    'type hierarchy item kind did not round-trip');
assertEqual(decodedHierarchyItem.get_data().deepUnpack(), 'hierarchy-token',
    'type hierarchy data did not round-trip');

const symbolCaps = new Lsp.DocumentSymbolClientCaps();
symbolCaps.init(
    Lsp.DocumentSymbolClientFlags.DYNAMIC_REGISTRATION |
    Lsp.DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS,
    Lsp.SymbolKindFlags.CLASS |
    Lsp.SymbolKindFlags.METHOD |
    Lsp.SymbolKindFlags.TYPE_PARAMETER,
    Lsp.SymbolTag.DEPRECATED,
);

const completionCaps = Lsp.CompletionClientCaps.new();
completionCaps.set_insert_text_modes(
    Lsp.InsertTextModeFlags.AS_IS |
    Lsp.InsertTextModeFlags.ADJUST_INDENTATION,
);
completionCaps.set_item_kinds(
    Lsp.CompletionItemKindFlags.TEXT |
    Lsp.CompletionItemKindFlags.FUNCTION |
    Lsp.CompletionItemKindFlags.TYPE_PARAMETER,
);

const workspaceEditCaps = new Lsp.WorkspaceEditClientCaps();
workspaceEditCaps.init(
    Lsp.WorkspaceEditClientFlags.DOCUMENT_CHANGES |
    Lsp.WorkspaceEditClientFlags.NORMALIZES_LINE_ENDINGS,
    Lsp.ResourceOperationKind.CREATE |
    Lsp.ResourceOperationKind.RENAME,
    Lsp.FailureHandlingKind.UNSET,
);
const workspaceCaps = new Lsp.WorkspaceClientCaps();
workspaceCaps.init_with_workspace_edit(
    workspaceEditCaps,
    Lsp.WorkspaceClientFlags.APPLY_EDIT,
);

const textCaps = Lsp.TextDocumentClientCaps.new();
textCaps.set_synchronization(
    Lsp.TextDocumentSyncClientCaps.WILL_SAVE |
    Lsp.TextDocumentSyncClientCaps.DID_SAVE,
);
textCaps.set_completion(completionCaps);
textCaps.set_document_symbol(symbolCaps);
textCaps.set_rename(
    Lsp.RenameClientCaps.SUPPORTED |
    Lsp.RenameClientCaps.PREPARE_SUPPORT,
);
textCaps.set_rename_prepare_support_default_behavior(
    Lsp.PrepareSupportDefaultBehavior.IDENTIFIER,
);
textCaps.set_type_hierarchy(
    Lsp.TypeHierarchyClientCaps.SUPPORTED |
    Lsp.TypeHierarchyClientCaps.DYNAMIC_REGISTRATION,
);
const clientCaps = Lsp.ClientCaps.new();
clientCaps.set_workspace(workspaceCaps);
clientCaps.set_text_document(textCaps);
const decodedClientCaps = Lsp.ClientCaps.from_variant(clientCaps.to_variant());
assert(decodedClientCaps.get_workspace().get_flags() &
    Lsp.WorkspaceClientFlags.APPLY_EDIT,
'workspace capability did not round-trip');
assert(decodedClientCaps.get_workspace().get_workspace_edit()
    .get_resource_ops() & Lsp.ResourceOperationKind.CREATE,
'workspace resource operation did not round-trip');
assert(decodedClientCaps.get_text_document().get_completion()
    .get_insert_text_modes() & Lsp.InsertTextModeFlags.ADJUST_INDENTATION,
'completion insert text modes did not round-trip');
assert(decodedClientCaps.get_text_document().get_completion()
    .get_item_kinds() & Lsp.CompletionItemKindFlags.TYPE_PARAMETER,
'completion item kinds did not round-trip');
assert(decodedClientCaps.get_text_document().get_document_symbol()
    .get_flags() & Lsp.DocumentSymbolClientFlags.HIERARCHICAL_DOCUMENT_SYMBOLS,
'hierarchical document symbol capability did not round-trip');
assert(decodedClientCaps.get_text_document().get_document_symbol()
    .get_symbol_kinds() & Lsp.SymbolKindFlags.TYPE_PARAMETER,
'document symbol kinds did not round-trip');
assert(decodedClientCaps.get_text_document().get_rename() &
    Lsp.RenameClientCaps.PREPARE_SUPPORT,
    'prepare rename capability did not round-trip');
assert(decodedClientCaps.get_text_document().get_type_hierarchy()
    & Lsp.TypeHierarchyClientCaps.DYNAMIC_REGISTRATION,
'type hierarchy capability did not round-trip');

const hierarchyServerCaps = Lsp.ServerCaps.new();
const hierarchyOptions = new Lsp.TypeHierarchyOptions();
hierarchyOptions.init();
hierarchyServerCaps.set_type_hierarchy(hierarchyOptions);
assert(Lsp.ServerCaps.from_variant(hierarchyServerCaps.to_variant())
    .get_type_hierarchy().get_supported(),
'type hierarchy server capability did not round-trip');

const protocolErrors = new Map([
    ['PARSE_ERROR', -32700],
    ['INVALID_REQUEST', -32600],
    ['METHOD_NOT_FOUND', -32601],
    ['INVALID_PARAMS', -32602],
    ['INTERNAL_ERROR', -32603],
    ['SERVER_NOT_INITIALIZED', -32002],
    ['UNKNOWN_ERROR_CODE', -32001],
    ['REQUEST_FAILED', -32803],
    ['SERVER_CANCELLED', -32802],
    ['CONTENT_MODIFIED', -32801],
    ['REQUEST_CANCELLED', -32800],
]);
for (const [name, value] of protocolErrors)
    assertEqual(Lsp.ProtocolError[name], value, `${name} has the wrong wire value`);
