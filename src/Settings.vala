// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * The few choices Agenda keeps between launches, in ~/.config/agenda/agenda.conf
 * (no GSettings schema to install for so little).
 */

namespace Agenda.Settings {
    private string path () {
        return Path.build_filename (Environment.get_user_config_dir (), "agenda", "agenda.conf");
    }

    private KeyFile load () {
        var file = new KeyFile ();
        try {
            file.load_from_file (path (), KeyFileFlags.NONE);
        } catch (Error e) {
            // first launch: defaults
        }
        return file;
    }

    /* "mois", "semaine" or "fil". */
    public string layout () {
        try {
            return load ().get_string ("window", "layout");
        } catch (Error e) {
            return "mois";
        }
    }

    public void set_layout (string layout) {
        var file = load ();
        file.set_string ("window", "layout", layout);
        try {
            DirUtils.create_with_parents (Path.get_dirname (path ()), 0700);
            file.save_to_file (path ());
        } catch (Error e) {
            warning ("saving the layout: %s", e.message);
        }
    }
}
