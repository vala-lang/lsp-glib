build_valadoc_docs = get_option('enable_valadoc') or get_option('gi-docgen')

if build_valadoc_docs
  valadoc = find_program('valadoc')
  valadoc_output = 'vala'
  lsp_glib_docs = custom_target('valadoc-api-docs',
    input: sources,
    output: [valadoc_output, 'Lsp-' + API_VERSION + '.gir'],
    command: [
      valadoc,
      '-o', '@OUTPUT0@',
      '--doclet',
      'html',
      # valac does not include Vala comments in generated GIRs yet. Use Valadoc
      # until https://gitlab.gnome.org/GNOME/vala/-/merge_requests/240 is resolved.
      '--gir=@OUTPUT1@',
      '@INPUT@',
      '--pkg', 'glib-2.0',
      '--pkg', 'gobject-2.0',
      '--pkg', 'gio-2.0',
      '--pkg', 'jsonrpc-glib-1.0',
      '--force',
      '--use-svg-images',
      '--package-name', 'lsp-glib-' + API_VERSION,
      '--package-version', API_VERSION
    ],
    build_by_default: get_option('enable_valadoc'),
    install: get_option('enable_valadoc'),
    install_dir: [
      get_option('datadir') / 'doc' / 'lsp-glib-' + API_VERSION,
      false,
    ],
  )
endif

if get_option('gi-docgen')
  gidocgen_dep = dependency('gi-docgen', version: '>= 2021.6',
                            fallback: ['gi-docgen', 'dummy_dep'],
                            required: true)

  gidocgen = find_program('gi-docgen', required: true)
  doc_python = import('python').find_installation('python3')

  toml_conf = configuration_data()
  toml_conf.set('VERSION', API_VERSION)

  lsp_glib_toml = configure_file(input: 'lsp-glib.toml.in',
                                 output: 'lsp-glib.toml',
                                 configuration: toml_conf)
  lsp_glib_urlmap = configure_file(input: 'urlmap.js',
                                   output: 'urlmap.js',
                                   copy: true)

  lsp_glib_doc_gir = custom_target('gi-docgen-gir',
    input: [lsp_glib_gir, lsp_glib_docs[1], lsp_glib_docs[0]],
    output: 'Lsp-' + API_VERSION + '-docs.gir',
    command: [
      doc_python,
      files('merge_gir_docs.py'),
      '@INPUT0@',
      '@INPUT1@',
      '@INPUT2@',
      '@OUTPUT@',
    ],
  )

  lsp_glib_gi_docs = custom_target('gi-docgen-api-docs',
    input: [lsp_glib_toml, lsp_glib_doc_gir, lsp_glib_urlmap],
    output: 'gi-docgen',
    command: [
      gidocgen,
      'generate',
      #'--quiet',
      '--no-namespace-dir',
      '--fatal-warnings',
      '--config=@INPUT0@',
      '--output-dir=@OUTPUT@',
      '--content-dir=@0@'.format(meson.current_source_dir()),
      '@INPUT1@',
    ],
    build_by_default: true,
  )

  test('gir-documentation', doc_python,
    args: [
      files('test_merge_gir_docs.py'),
      '--gir', lsp_glib_doc_gir,
      '--valadoc-html', lsp_glib_docs[0],
      '--gi-docs', lsp_glib_gi_docs,
    ],
    depends: [lsp_glib_doc_gir, lsp_glib_gi_docs],
    env: {'PYTHONDONTWRITEBYTECODE': '1'},
    suite: 'docs',
  )
endif

if get_option('enable_valadoc') and get_option('gi-docgen')
  pages_python = import('python').find_installation('python3')
  pages_script = files('prepare-pages.py')
  pages_assets = files(
    'pages/index.html',
    'pages/style.css',
  )

  custom_target('pages',
    input: pages_assets,
    output: 'pages',
    command: [
      pages_python,
      pages_script,
      meson.current_source_dir() / 'pages',
      meson.current_build_dir() / 'gi-docgen',
      meson.current_build_dir() / valadoc_output,
      '@OUTPUT@',
    ],
    depends: [lsp_glib_docs, lsp_glib_gi_docs],
    build_always_stale: true,
  )
endif
