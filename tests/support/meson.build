g_ir_scanner = find_program('g-ir-scanner', required: false)

if is_variable('lsp_glib_typelib') and g_ir_scanner.found()
  gnome = import('gnome')
  gi_test_support = shared_library(
    'lsp-test-support',
    [
      'test-stream-support.c',
      '../c/test-server.c',
      '../c/test-stream.c',
    ],
    dependencies: lsp_glib_dep,
    install: false,
  )
  gi_test_support_gir = gnome.generate_gir(
    gi_test_support,
    sources: files('test-stream-support.h'),
    namespace: 'LspTest',
    nsversion: '1.0',
    identifier_prefix: 'LspTest',
    symbol_prefix: 'lsp_test',
    includes: ['Gio-2.0'],
    env: {'GI_SCANNER_DISABLE_CACHE': '1'},
    install: false,
  )
endif
