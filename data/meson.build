# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 melvincouwez-alt
configure_file(input: 'agenda.desktop.in', output: app_id + '.desktop', configuration: conf,
               install: true, install_dir: datadir / 'applications')
install_data('metainfo.xml', rename: app_id + '.metainfo.xml', install_dir: datadir / 'metainfo')

# The 128px design scales up; 16 to 48 are drawn on their own pixel grid, as
# elementary's icons are, and installed for 1x and 2x.
install_data('icons' / '128.svg', rename: app_id + '.svg', install_dir: datadir / 'icons' / 'hicolor' / 'scalable' / 'apps')
foreach size : ['16', '24', '32', '48']
  foreach dir : [size + 'x' + size, size + 'x' + size + '@2']
    install_data('icons' / size + '.svg', rename: app_id + '.svg',
                 install_dir: datadir / 'icons' / 'hicolor' / dir / 'apps')
  endforeach
endforeach
