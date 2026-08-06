conf = configuration_data()
conf.set('prefix', get_option('prefix'))
conf.set('libdir', get_option ('libdir'))
conf.set('PROJECT_NAME', 'lsp-glib')
conf.set('PROJECT_VERSION', meson.project_version())
conf.set('API_VERSION', API_VERSION)

sources = [version_file] + files([
  'types/boxed-types.c',
  'io/jsonrpc-reply.c',
  'io/client.vala',
  'io/editor.vala',
  'io/server.vala',
  'types/callhierarchy.vala',
  'types/clientcapabilities.vala',
  'types/codelens.vala',
  'types/codeaction.vala',
  'types/command.vala',
  'types/completion.vala',
  'types/diagnostic.vala',
  'types/error.vala',
  'types/formatting.vala',
  'types/highlight.vala',
  'types/inlayhint.vala',
  'types/hover.vala',
  'types/initialization.vala',
  'types/location.vala',
  'types/markupcontent.vala',
  'types/message.vala',
  'types/reference.vala',
  'types/rename.vala',
  'types/serialization.vala',
  'types/servercapabilities.vala',
  'types/signaturehelp.vala',
  'types/symbol.vala',
  'types/textdocument.vala',
  'types/textedit.vala',
  'types/trace.vala',
  'types/typehierarchy.vala',
  'types/workspace.vala',
  'types/workspaceedit.vala',
  'library.vala'
])

liblsp_glib = library('lsp-glib-' + API_VERSION,
  sources,
  vala_header: 'lsp-glib.h',
  vala_vapi: 'lsp-glib-' + API_VERSION + '.vapi',
  vala_gir: 'Lsp-' + API_VERSION + '.gir',
  dependencies : vala_dependencies,
  vala_args: [
    '--abi-stability'
    ],
  install: true,
  install_dir: [
    true,
    get_option('includedir') / 'lsp-glib-' + API_VERSION,
    vapidir,
    false
  ]
)

subdir('gir')

install_data(
  'lsp-glib.deps',
  install_dir: vapidir,
  rename: 'lsp-glib-' + API_VERSION + '.deps',
)

if g_ir_compiler.found() and get_option('default_library') != 'static'
  lsp_glib_typelib = custom_target('liblsp-glib-typelib',
    command: [
      g_ir_compiler,
      '--shared-library', 'liblsp-glib-@0@.so'.format (API_VERSION),
      '--output', '@OUTPUT@',
      lsp_glib_gir
    ],
    output: 'Lsp-' + API_VERSION + '.typelib',
    depends: liblsp_glib,
    install: true,
    install_dir: join_paths(get_option('libdir'), 'girepository-1.0'))
endif

pkgconfig.generate(liblsp_glib,
  subdirs: 'lsp-glib-' + API_VERSION,
  version: meson.project_version(),
  name: 'lsp-glib',
  filebase: 'lsp-glib-' + API_VERSION,
  requires: PKGCONFIG_DEPS,
  description: 'LSP library built on GLib')

lsp_glib_dep = declare_dependency(
  link_with: liblsp_glib,
  dependencies: dependencies,
  include_directories: [include_directories('.')],
  version: meson.project_version(),
)

# Generated VAPIs are source dependencies in Meson and make C-only targets look
# like Vala targets. Keep them in a Vala-specific dependency for subprojects.
lsp_glib_vala_dep = declare_dependency(
  link_with: liblsp_glib,
  dependencies: vala_dependencies,
  include_directories: [include_directories('.')],
  version: meson.project_version(),
)

meson.override_dependency('lsp-glib-' + API_VERSION, lsp_glib_dep)
