python = import('python').find_installation('python3')

if meson.version().version_compare('>=1.10.0')
  lsp_glib_orig_gir = liblsp_glib.vala_gir()
else
  lsp_glib_orig_gir = meson.current_build_dir() / '..' / 'Lsp-' + API_VERSION + '.gir'
endif

lsp_glib_gir = custom_target(
  'liblsp-glib-gir',
  output: 'Lsp-' + API_VERSION + '.gir',
  command: [
    python,
    files('../types/patch-boxed-gir.py'),
    lsp_glib_orig_gir,
    '@OUTPUT@',
    files('../types/boxed-types.def'),
  ],
  depends: liblsp_glib,
  install: true,
  install_dir: get_option('datadir') / 'gir-1.0',
)
