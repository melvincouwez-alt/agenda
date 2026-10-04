// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * The calendars, grouped by account, each with a check in its own colour that
 * shows or hides it; shown in the header bar's calendars menu. The choice is the
 * calendar's own "selected" flag, so elementary's Calendar and Agenda agree on it.
 */

public class Agenda.CalendarList : Gtk.Box {
    private CalendarStore store;
    private Gtk.Box list;
    private Gtk.CssProvider colors = new Gtk.CssProvider ();

    public CalendarList (CalendarStore store) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, width_request: 240);
        this.store = store;

        list = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        append (new Gtk.ScrolledWindow () {
            child = list,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            propagate_natural_height = true,
            max_content_height = 480
        });
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), colors,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
        store.calendars_changed.connect (rebuild);
        rebuild ();
    }

    private void rebuild () {
        Gtk.Widget? child;
        while ((child = list.get_first_child ()) != null) {
            list.remove (child);
        }
        var css = new StringBuilder ();
        string? account = null;
        foreach (var calendar in store.list ()) {
            if (calendar.account != account) {
                account = calendar.account;
                list.append (new Granite.HeaderLabel (account) { margin_top = list.get_first_child () == null ? 0 : 12 });
            }
            var css_name = "cal-" + Checksum.compute_for_string (ChecksumType.MD5, calendar.uid).substring (0, 12);
            var check = new Gtk.CheckButton.with_label (calendar.name) {
                active = calendar.visible,
                tooltip_text = calendar.writable ? null : _("Lecture seule")
            };
            check.add_css_class ("calendar-check");
            check.add_css_class (css_name);
            check.toggled.connect (() => calendar.visible = check.active);
            list.append (check);
            css.append ("checkbutton.%s check { border-color: %s; }\n".printf (css_name, calendar.color));
            css.append ("checkbutton.%s check:checked { background-color: %s; background-image: none; }\n"
                        .printf (css_name, calendar.color));
        }
        if (list.get_first_child () == null) {
            var empty = new Gtk.Label (_("Aucun agenda. Connectez iCloud dans Boomerang, onglet Services Apple.")) {
                wrap = true,
                xalign = 0
            };
            empty.add_css_class (Granite.CssClass.DIM);
            list.append (empty);
        }
        colors.load_from_string (css.str);
    }
}
