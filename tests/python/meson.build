python = import('python').find_installation(
  'python3',
  modules: ['gi'],
  required: false,
)

if python.found() and is_variable('lsp_glib_typelib')
  python_test_env = environment()
  python_test_env.prepend(
    'GI_TYPELIB_PATH',
    meson.project_build_root() / 'tests' / 'support',
  )
  python_test_env.prepend(
    'GI_TYPELIB_PATH',
    meson.project_build_root() / 'src',
  )
  python_test_env.prepend(
    'PATH',
    meson.project_build_root() / 'tests' / 'support',
  )
  python_test_env.prepend(
    'PATH',
    meson.project_build_root() / 'src',
  )

  if host_machine.system() == 'darwin'
    python_test_env.prepend(
      'DYLD_LIBRARY_PATH',
      meson.project_build_root() / 'tests' / 'support',
    )
    python_test_env.prepend(
      'DYLD_LIBRARY_PATH',
      meson.project_build_root() / 'src',
    )
  elif host_machine.system() != 'windows'
    python_test_env.prepend(
      'LD_LIBRARY_PATH',
      meson.project_build_root() / 'tests' / 'support',
    )
    python_test_env.prepend(
      'LD_LIBRARY_PATH',
      meson.project_build_root() / 'src',
    )
  endif

  test(
    'Python position serialization',
    python,
    args: files('position.py'),
    depends: lsp_glib_typelib,
    env: python_test_env,
    suite: 'python',
  )
  test(
    'Python diagnostic serialization',
    python,
    args: files('diagnostic.py'),
    depends: lsp_glib_typelib,
    env: python_test_env,
    suite: 'python',
  )
  test(
    'Python typed serialization',
    python,
    args: files('types.py'),
    depends: lsp_glib_typelib,
    env: python_test_env,
    suite: 'python',
  )
  if is_variable('gi_test_support_gir')
    test(
      'Python server JSON-RPC dispatch',
      python,
      args: files('server.py'),
      depends: [
        lsp_glib_typelib,
        gi_test_support_gir,
      ],
      env: python_test_env,
      suite: 'python',
    )
  endif
endif
