// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * An .ics file (an invitation, a ticket, a timetable): shows how many events it
 * holds and adds them to the chosen calendar. An event already there, same UID,
 * is updated rather than duplicated.
 */

namespace Agenda.Importer {
    public void run (Gtk.Window parent, CalendarStore store, File file) {
        string text;
        try {
            uint8[] bytes;
            file.load_contents (null, out bytes, null);
            text = (string) bytes;
        } catch (Error e) {
            show_error (parent, _("Lecture de « %s » impossible").printf (file.get_basename ()), e.message);
            return;
        }
        var root = new ICal.Component.from_string (text);
        var events = new Gee.ArrayList<ICal.Component> ();
        var zones = new Gee.ArrayList<ICal.Timezone> ();
        if (root != null) {
            if (root.isa () == ICal.ComponentKind.VEVENT_COMPONENT) {
                events.add (root);
            }
            for (var c = root.get_first_component (ICal.ComponentKind.VEVENT_COMPONENT); c != null;
                 c = root.get_next_component (ICal.ComponentKind.VEVENT_COMPONENT)) {
                events.add (c.clone ());
            }
            for (var c = root.get_first_component (ICal.ComponentKind.VTIMEZONE_COMPONENT); c != null;
                 c = root.get_next_component (ICal.ComponentKind.VTIMEZONE_COMPONENT)) {
                var zone = new ICal.Timezone ();
                if (zone.set_component (c.clone ()) != 0) {
                    zones.add (zone);
                }
            }
        }
        var calendars = store.writable ();
        if (events.size == 0) {
            show_error (parent, _("Aucun évènement"), _("« %s » ne contient pas d'évènement.").printf (file.get_basename ()));
            return;
        }
        if (calendars.size == 0) {
            show_error (parent, _("Aucun agenda modifiable"),
                        _("Connectez votre compte iCloud dans Covalence (Services Apple)."));
            return;
        }

        var first = events[0];
        var summary = events.size == 1
            ? _("Ajouter « %s » à l'agenda :").printf (first.get_summary () ?? _("(Sans titre)"))
            : ngettext ("Ajouter %d évènement à l'agenda :", "Ajouter %d évènements à l'agenda :", events.size)
              .printf (events.size);
        var names = new Gtk.StringList (null);
        foreach (var calendar in calendars) {
            names.append ("%s (%s)".printf (calendar.name, calendar.account));
        }
        var choice = new Gtk.DropDown (names, null);
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            file.get_basename (), summary, "office-calendar", Gtk.ButtonsType.CANCEL) {
            transient_for = parent,
            modal = true
        };
        dialog.custom_bin.append (choice);
        dialog.add_button (_("Ajouter"), Gtk.ResponseType.ACCEPT).add_css_class (Granite.CssClass.SUGGESTED);
        dialog.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                import.begin (parent, calendars[(int) choice.selected], events, zones);
            }
            dialog.destroy ();
        });
        dialog.present ();
    }

    private async void import (Gtk.Window parent, Calendar calendar, Gee.List<ICal.Component> events,
                               Gee.List<ICal.Timezone> zones) {
        foreach (var zone in zones) {
            try {
                yield calendar.client.add_timezone (zone, null);
            } catch (Error e) {
                warning ("timezone: %s", e.message);
            }
        }
        int failed = 0;
        string last_error = "";
        foreach (var event in events) {
            try {
                string uid;
                yield calendar.client.create_object (event, ECal.OperationFlags.NONE, null, out uid);
            } catch (Error e) {
                try {
                    yield calendar.client.modify_object (event, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, null);
                } catch (Error e2) {
                    failed++;
                    last_error = e2.message;
                }
            }
        }
        if (failed > 0) {
            show_error (parent, ngettext ("%d évènement n'a pas pu être ajouté", "%d évènements n'ont pas pu être ajoutés",
                                          failed).printf (failed), last_error);
        }
    }

    private void show_error (Gtk.Window parent, string title, string detail) {
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (title, detail, "dialog-warning",
                                                                          Gtk.ButtonsType.CLOSE) {
            transient_for = parent,
            modal = true
        };
        dialog.response.connect (() => dialog.destroy ());
        dialog.present ();
    }
}
