# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 melvincouwez-alt
project('io.github.melvincouwez.Agenda', 'vala', 'c',
  version: '0.1.3',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 1.0',
)

app_id = meson.project_name()
prefix = get_option('prefix')
datadir = prefix / get_option('datadir')

conf = configuration_data()
conf.set('APP_ID', app_id)
conf.set('VERSION', meson.project_version())
conf.set('BINDIR', prefix / get_option('bindir'))

# Interface texts are written in French, like Boomerang's.
add_project_arguments('-DGETTEXT_PACKAGE="agenda"', '-DLIBICAL_GLIB_UNSTABLE_API=1', language: 'c')

subdir('src')
subdir('data')

gnome = import('gnome')
gnome.post_install(gtk_update_icon_cache: true, update_desktop_database: true)
