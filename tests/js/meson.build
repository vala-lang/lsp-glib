gjs = find_program('gjs', required: false)

if gjs.found() and is_variable('lsp_glib_typelib')
  js_test_env = environment()
  js_test_env.prepend(
    'GI_TYPELIB_PATH',
    meson.project_build_root() / 'src',
  )
  js_test_env.prepend(
    'PATH',
    meson.project_build_root() / 'src',
  )

  if host_machine.system() == 'darwin'
    js_test_env.prepend(
      'DYLD_LIBRARY_PATH',
      meson.project_build_root() / 'src',
    )
  elif host_machine.system() != 'windows'
    js_test_env.prepend(
      'LD_LIBRARY_PATH',
      meson.project_build_root() / 'src',
    )
  endif

  test(
    'GJS position serialization',
    gjs,
    args: ['-m', files('position.js')],
    depends: lsp_glib_typelib,
    env: js_test_env,
    suite: 'js',
  )
  test(
    'GJS diagnostic serialization',
    gjs,
    args: ['-m', files('diagnostic.js')],
    depends: lsp_glib_typelib,
    env: js_test_env,
    suite: 'js',
  )
  test(
    'GJS typed serialization',
    gjs,
    args: ['-m', files('types.js')],
    depends: lsp_glib_typelib,
    env: js_test_env,
    suite: 'js',
  )

  if is_variable('gi_test_support_gir')
    js_server_test_env = js_test_env
    js_server_test_env.prepend(
      'GI_TYPELIB_PATH',
      meson.project_build_root() / 'tests' / 'support',
    )

    if host_machine.system() == 'darwin'
      js_server_test_env.prepend(
        'DYLD_LIBRARY_PATH',
        meson.project_build_root() / 'tests' / 'support',
      )
    elif host_machine.system() != 'windows'
      js_server_test_env.prepend(
        'LD_LIBRARY_PATH',
        meson.project_build_root() / 'tests' / 'support',
      )
    endif

    test(
      'GJS Editor JSON-RPC dispatch',
      gjs,
      args: ['-m', files('server.js')],
      depends: [
        lsp_glib_typelib,
        gi_test_support_gir,
      ],
      env: js_server_test_env,
      suite: 'js',
    )
  endif
endif
