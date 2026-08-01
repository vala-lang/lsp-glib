if get_option('enable_valadoc')
  valadoc = find_program('valadoc')
  lsp_glib_docs = custom_target('valadoc-api-docs',
    input: sources,
    install: true,
    # FIXME: Installing to tmp, so the target will be built
    #        the problem is we cannot access a subfolder of the
    #        buildtarget via the output parameter.
    #        Find a nicer solution
    install_dir: get_option('datadir') / 'devhelp' / 'books',
    command: [
      valadoc,
      '-o', meson.current_build_dir() / 'valadoc',
      '--doclet',
      'devhelp',
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
    output: 'Lsp-' + API_VERSION)

  install_subdir(meson.current_build_dir() / 'Lsp-' + API_VERSION / 'lsp-glib-' + API_VERSION,
    install_dir: get_option('datadir') / 'devhelp' / 'books')
endif

if get_option('gi-docgen')
  gidocgen_dep = dependency('gi-docgen', version: '>= 2021.6',
                            fallback: ['gi-docgen', 'dummy_dep'],
                            required: true)

  gidocgen = find_program('gi-docgen', required: true)

  toml_conf = configuration_data()
  toml_conf.set('VERSION', API_VERSION)

  lsp_glib_toml = configure_file(input: 'lsp-glib.toml.in',
                                 output: 'lsp-glib.toml',
                                 configuration: toml_conf)

  lsp_glib_gi_docs = custom_target('gi-docgen-api-docs',
    input: [lsp_glib_toml],
    output: 'gi-docgen',
    command: [
      gidocgen,
      'generate',
      #'--quiet',
      '--no-namespace-dir',
      #'--fatal-warnings',
      '--config=@INPUT0@',
      '--output-dir=@OUTPUT@',
      '--content-dir=@0@'.format(meson.current_source_dir()),
      lsp_glib_gir,
    ],
    build_by_default: true,
    depends: liblsp_glib,
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
      meson.current_build_dir() / 'valadoc' / 'lsp-glib-' + API_VERSION,
      '@OUTPUT@',
    ],
    depends: [lsp_glib_docs, lsp_glib_gi_docs],
    build_always_stale: true,
  )
endif
