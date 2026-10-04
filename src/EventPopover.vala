// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * An event's details, with Modifier and Supprimer when its calendar can be
 * written. Deleting one occurrence of a series asks which one is meant.
 */

public class Agenda.EventPopover : Gtk.Popover {
    public signal void edit ();

    private CalendarStore store;
    private Occurrence occurrence;

    public EventPopover (CalendarStore store, Occurrence occurrence) {
        this.store = store;
        this.occurrence = occurrence;

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_top = 12, margin_bottom = 12, margin_start = 12, margin_end = 12, width_request = 280
        };
        var title = new Gtk.Label (occurrence.summary != "" ? occurrence.summary : _("(Sans titre)")) {
            xalign = 0, wrap = true, selectable = true
        };
        title.add_css_class (Granite.HeaderLabel.Size.H3.to_string ());
        box.append (title);

        var when = new Gtk.Label (when_text ()) { xalign = 0, wrap = true };
        box.append (when);
        if (occurrence.recurring) {
            var repeats = new Gtk.Label (_("Évènement répété")) { xalign = 0 };
            repeats.add_css_class (Granite.CssClass.DIM);
            box.append (repeats);
        }

        var calendar_line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { valign = Gtk.Align.CENTER };
        dot.add_css_class ("event-dot");
        dot.add_css_class (Palette.class_for (occurrence.calendar));
        calendar_line.append (dot);
        var calendar_name = new Gtk.Label ("%s · %s".printf (occurrence.calendar.name, occurrence.calendar.account));
        calendar_name.add_css_class (Granite.CssClass.DIM);
        calendar_line.append (calendar_name);
        box.append (calendar_line);

        if (occurrence.location != "") {
            var place = new Gtk.Label (occurrence.location) { xalign = 0, wrap = true, selectable = true };
            box.append (with_icon ("mark-location-symbolic", place));
        }
        if (occurrence.description != "") {
            var notes = new Gtk.Label (occurrence.description) {
                xalign = 0, wrap = true, selectable = true, lines = 8, ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 40
            };
            notes.add_css_class (Granite.CssClass.SMALL);
            box.append (notes);
        }

        if (occurrence.calendar.writable) {
            var remove = new Gtk.Button.with_label (_("Supprimer"));
            remove.add_css_class (Granite.CssClass.DESTRUCTIVE);
            remove.clicked.connect (confirm_removal);
            var modify = new Gtk.Button.with_label (_("Modifier"));
            modify.clicked.connect (() => {
                popdown ();
                edit ();
            });
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) { halign = Gtk.Align.END, margin_top = 6 };
            actions.append (remove);
            actions.append (modify);
            box.append (actions);
        }
        child = box;
    }

    private static Gtk.Widget with_icon (string icon, Gtk.Widget widget) {
        var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        line.append (new Gtk.Image.from_icon_name (icon) { valign = Gtk.Align.START });
        line.append (widget);
        return line;
    }

    private string when_text () {
        var start = occurrence.start;
        var date = start.format ("%A %e %B %Y").replace ("  ", " ");
        date = date.substring (0, 1).up () + date.substring (date.index_of_nth_char (1));
        if (occurrence.all_day) {
            var last = occurrence.end.add_days (-1);
            if (last.compare (start) > 0) {
                return _("Du %s au %s").printf (start.format ("%e %B").strip (), last.format ("%e %B %Y").strip ());
            }
            return "%s\n%s".printf (date, _("Toute la journée"));
        }
        return "%s\n%s".printf (date, occurrence.time_label ());
    }

    private void confirm_removal () {
        var window = get_root () as Gtk.Window;
        popdown ();
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Supprimer « %s » ?").printf (occurrence.summary),
            occurrence.recurring
                ? _("Cet évènement se répète. Il disparaîtra aussi de l'iPhone et d'iCloud.")
                : _("Il disparaîtra aussi de l'iPhone et d'iCloud."),
            "edit-delete", Gtk.ButtonsType.CANCEL) {
            transient_for = window,
            modal = true
        };
        if (occurrence.recurring) {
            dialog.add_button (_("Toute la série"), 2).add_css_class (Granite.CssClass.DESTRUCTIVE);
            dialog.add_button (_("Cette occurrence"), 1).add_css_class (Granite.CssClass.DESTRUCTIVE);
        } else {
            dialog.add_button (_("Supprimer"), 1).add_css_class (Granite.CssClass.DESTRUCTIVE);
        }
        dialog.response.connect ((response) => {
            if (response == 1 || response == 2) {
                store.remove.begin (occurrence, response == 2, (obj, res) => {
                    try {
                        store.remove.end (res);
                    } catch (Error e) {
                        warning ("removing %s: %s", occurrence.uid, e.message);
                    }
                });
            }
            dialog.destroy ();
        });
        dialog.present ();
    }
}
