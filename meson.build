project('vala app', 'vala', 'c')

vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gtk4'),
    dependency('cairo'),
    dependency('pango'),
    dependency('msgpack'),
]

sources = files('main.vala', 'msgpack-rpc.vala', 'renderer.vala')

executable('nvv', sources, dependencies: dependencies)
