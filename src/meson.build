# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 melvincouwez-alt
config_vala = configure_file(input: 'Config.vala.in', output: 'Config.vala', configuration: conf)

executable(app_id,
  config_vala,
  'Application.vala',
  'CalendarStore.vala',
  'Event.vala',
  'MainWindow.vala',
  'CalendarList.vala',
  'MonthView.vala',
  'DayPanel.vala',
  'WeekView.vala',
  'FeedView.vala',
  'QuickAdd.vala',
  'Settings.vala',
  'EventPopover.vala',
  'EventEditor.vala',
  'Importer.vala',
  'About.vala',
  dependencies: [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gtk4'),
    dependency('gee-0.8'),
    dependency('granite-7', version: '>= 7.7'),
    dependency('libedataserver-1.2'),
    dependency('libecal-2.0'),
    dependency('libical-glib'),
  ],
  install: true,
)
