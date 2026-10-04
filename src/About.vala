// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * About Agenda: version, licence, credits, independence from Apple and trademarks.
 */

namespace Agenda {
    public void show_about (Gtk.Window? parent) {
        var about = new Gtk.AboutDialog () {
            transient_for = parent,
            modal = true,
            program_name = "Agenda",
            logo_icon_name = Config.APP_ID,
            version = Config.VERSION,
            comments = _("L'agenda de Boomerang : vos agendas iCloud et ceux de ce PC.\n"
                       + "Projet libre, non affilié à Apple Inc."),
            copyright = _("© 2026 melvincouwez-alt"),
            authors = { "melvincouwez-alt" },
            website = "https://github.com/melvincouwez-alt/agenda",
            website_label = _("Code source")
        };
        about.license = _("Agenda est un logiciel libre et indépendant. Il n'est ni affilié à Apple Inc., "
                          + "ni approuvé par Apple Inc., ni par elementary, Inc.\n\n"
                          + "Apple, iPhone et iCloud sont des marques d'Apple Inc., déposées aux États-Unis "
                          + "et dans d'autres pays. elementary est une marque d'elementary, Inc. Ces noms "
                          + "ne sont employés que pour décrire la compatibilité.\n\n"
                          + "Ce programme est distribué sans aucune garantie.\n\n"
                          + "Agenda est distribué sous licence GNU GPL, version 3 ou ultérieure : "
                          + "https://www.gnu.org/licenses/gpl-3.0.html");
        about.wrap_license = true;
        about.add_credit_section (_("Projets utilisés"), {
            "Evolution Data Server (LGPL-2.1-or-later) https://gitlab.gnome.org/GNOME/evolution-data-server",
            "libical (LGPL-2.1-or-later / MPL-2.0) https://github.com/libical/libical",
            "GTK (LGPL-2.1-or-later) https://gitlab.gnome.org/GNOME/gtk",
            "Granite (LGPL-3.0-or-later) https://github.com/elementary/granite",
            "libgee (LGPL-2.1-or-later) https://gitlab.gnome.org/GNOME/libgee",
            "Vala (LGPL-2.1-or-later) https://gitlab.gnome.org/GNOME/vala",
            _("Police Inter, Rasmus Andersson (SIL OFL 1.1), texte de l'icône https://github.com/rsms/inter")
        });
        about.present ();
    }
}
