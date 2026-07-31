vala_test_stream_sources = [
  'test-stream.vala',
  '../c/test-stream.c',
]

vala_test_stream_includes = include_directories('../c')
position_test = executable(
  'position-test',
  [
    'position.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'position serialization',
  position_test,
  suite: 'vala',
)

diagnostic_test = executable(
  'diagnostic-test',
  [
    'diagnostic.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'diagnostic serialization',
  diagnostic_test,
  suite: 'vala',
)

text_document_test = executable(
  'text-document-test',
  [
    'text-document.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'text document serialization',
  text_document_test,
  suite: 'vala',
)

workspace_edit_test = executable(
  'workspace-edit-test',
  [
    'workspace-edit.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'workspace edit serialization',
  workspace_edit_test,
  suite: 'vala',
)

completion_test = executable(
  'completion-test',
  [
    'completion.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'completion serialization',
  completion_test,
  suite: 'vala',
)

initialization_test = executable(
  'initialization-test',
  [
    'initialization.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'initialization serialization',
  initialization_test,
  suite: 'vala',
)

client_capabilities_test = executable(
  'client-capabilities-test',
  [
    'client-capabilities.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'client capabilities serialization',
  client_capabilities_test,
  suite: 'vala',
)

features_test = executable(
  'features-test',
  [
    'features.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'feature serialization',
  features_test,
  suite: 'vala',
)

symbols_test = executable(
  'symbols-test',
  [
    'symbols.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'symbol serialization',
  symbols_test,
  suite: 'vala',
)

advanced_test = executable(
  'advanced-test',
  [
    'advanced.vala',
  ],
  dependencies: lsp_glib_vala_dep,
)

test(
  'advanced serialization',
  advanced_test,
  suite: 'vala',
)

vala_server_test = executable(
  'vala-server-test',
  [
    'server.vala',
    'test-server.vala',
    vala_test_stream_sources,
  ],
  dependencies: lsp_glib_vala_dep,
  include_directories: vala_test_stream_includes,
)

test(
  'Vala server JSON-RPC dispatch',
  vala_server_test,
  suite: 'vala',
)

vala_editor_test = executable(
  'vala-editor-test',
  [
    'editor.vala',
    'test-editor.vala',
    'test-server.vala',
    vala_test_stream_sources,
  ],
  dependencies: lsp_glib_vala_dep,
  include_directories: vala_test_stream_includes,
)

test(
  'Vala Editor and Server document sync',
  vala_editor_test,
  suite: 'vala',
)

server_cancellation_test = executable(
  'server-cancellation-test',
  [
    'server-cancellation.vala',
    vala_test_stream_sources,
  ],
  dependencies: lsp_glib_vala_dep,
  include_directories: vala_test_stream_includes,
)

test(
  'server cancellation',
  server_cancellation_test,
  suite: 'vala',
)
