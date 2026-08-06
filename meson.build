project('lsp-glib', 'vala', 'c',
  version: '3.18.0-alpha.1',
  license: 'LGPL-2.1-or-later')

jsonrpc_glib_dep = dependency(
  'jsonrpc-glib-1.0',
  version: '>= 3.44',
  required: false,
  default_options: [
    'enable_tests=false',
    'with_introspection=true',
    'with_vapi=true',
  ],
)
jsonrpc_glib_vala_dep = []
if not jsonrpc_glib_dep.found()
  jsonrpc_glib_project = subproject(
    'jsonrpc-glib',
    default_options: [
      'enable_tests=false',
      'with_introspection=true',
      'with_vapi=true',
    ],
  )
  jsonrpc_glib_dep = jsonrpc_glib_project.get_variable(
    'libjsonrpc_glib_dep',
  )
  jsonrpc_glib_vala_dep = jsonrpc_glib_project.get_variable(
    'libjsonrpc_glib_vapi',
  )
elif jsonrpc_glib_dep.type_name() == 'internal'
  # The wrap provider may have already loaded the fallback for dependency().
  # Its C dependency does not carry the generated VAPI transitively.
  jsonrpc_glib_project = subproject('jsonrpc-glib')
  jsonrpc_glib_vala_dep = jsonrpc_glib_project.get_variable(
    'libjsonrpc_glib_vapi',
  )
endif

dependencies = [
  dependency('glib-2.0', version: '>= 2.66'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  jsonrpc_glib_dep,
]
vala_dependencies = dependencies + jsonrpc_glib_vala_dep

pkgconfig = import('pkgconfig')

PKGCONFIG_DEPS = ['glib-2.0', 'gobject-2.0', 'gio-2.0', 'jsonrpc-glib-1.0']
# API_VERSION names ABI-facing artifacts; project() versions library releases.
API_VERSION = '3.0'
vapidir = get_option('datadir') / 'vala' / 'vapi'

add_project_arguments(['--enable-experimental', '--fatal-warnings'], language: 'vala')

g_ir_compiler = find_program('g-ir-compiler', required: false)

version_file = vcs_tag(input: 'version.vala.in',
                       output: 'version.vala',
                       command: ['git', 'describe', '--tags', '--dirty'])

subdir('src')
subdir('tests')
subdir('doc')
