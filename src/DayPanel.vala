// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * The panel on the right, as in elementary's Calendar: the selected day in
 * large type, its events, then what comes in the following two weeks.
 */

public class Agenda.DayPanel : Gtk.Box {
    public signal void event_activated (Occurrence occurrence, Gtk.Widget relative_to);
    public signal void add_requested (Date day);

    private const int AHEAD_DAYS = 14;

    private CalendarStore store;
    private Date day;
    private Gtk.Label weekday;
    private Gtk.Label date;
    private Gtk.Box content;
    private uint generation = 0;

    public DayPanel (CalendarStore store) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, width_request: 300);
        this.store = store;
        add_css_class ("day-panel");

        weekday = new Gtk.Label ("") { xalign = 0 };
        weekday.add_css_class ("day-panel-weekday");
        date = new Gtk.Label ("") { xalign = 0 };
        date.add_css_class (Granite.HeaderLabel.Size.H1.to_string ());
        var add = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            valign = Gtk.Align.CENTER,
            tooltip_text = _("Ajouter un évènement ce jour-là")
        };
        add.add_css_class ("circular");
        add.clicked.connect (() => add_requested (day));
        var titles = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { hexpand = true };
        titles.append (weekday);
        titles.append (date);
        var heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 18, margin_bottom = 12, margin_start = 18, margin_end = 18
        };
        heading.append (titles);
        heading.append (add);
        append (heading);
        append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

        content = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_top = 12, margin_bottom = 18, margin_start = 12, margin_end = 12
        };
        append (new Gtk.ScrolledWindow () {
            child = content,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        });
        show_day (Days.today ());
    }

    public void show_day (Date day) {
        this.day = day;
        var start = new DateTime.local (day.get_year (), day.get_month (), day.get_day (), 0, 0, 0);
        var today = Days.today ();
        if (day.compare (today) == 0) {
            weekday.label = _("Aujourd'hui");
        } else {
            weekday.label = capitalised (start.format ("%A"));
        }
        date.label = start.format ("%e %B").strip ();
        reload ();
    }

    public void reload () {
        var start = new DateTime.local (day.get_year (), day.get_month (), day.get_day (), 0, 0, 0);
        uint mine = ++generation;
        store.occurrences.begin (start, start.add_days (AHEAD_DAYS + 1), (obj, res) => {
            var occurrences = store.occurrences.end (res);
            if (mine == generation) {
                fill (start, occurrences);
            }
        });
    }

    private void fill (DateTime start, Gee.List<Occurrence> occurrences) {
        Gtk.Widget? child;
        while ((child = content.get_first_child ()) != null) {
            content.remove (child);
        }
        // The day itself
        var today_list = list_for (Days.from (start), occurrences);
        if (today_list != null) {
            content.append (today_list);
        } else {
            var nothing = new Gtk.Label (_("Rien de prévu")) { margin_top = 12, margin_bottom = 12 };
            nothing.add_css_class (Granite.CssClass.DIM);
            content.append (nothing);
        }
        // The next two weeks
        bool heading_shown = false;
        for (int i = 1; i <= AHEAD_DAYS; i++) {
            var when = start.add_days (i);
            var list = list_for (Days.from (when), occurrences, true);
            if (list == null) {
                continue;
            }
            if (!heading_shown) {
                content.append (new Granite.HeaderLabel (_("À venir")) { margin_top = 12 });
                heading_shown = true;
            }
            var label = new Gtk.Label (day_label (when)) { xalign = 0, margin_top = 6 };
            label.add_css_class ("upcoming-day");
            content.append (label);
            content.append (list);
        }
    }

    private static string capitalised (string text) {
        return text.substring (0, 1).up () + text.substring (text.index_of_nth_char (1));
    }

    private static string day_label (DateTime when) {
        var today = new DateTime.now_local ();
        var tomorrow = today.add_days (1);
        if (when.get_year () == tomorrow.get_year () && when.get_day_of_year () == tomorrow.get_day_of_year ()) {
            return _("Demain");
        }
        return capitalised ("%s %d %s".printf (when.format ("%A"), when.get_day_of_month (), when.format ("%B")));
    }

    /* The day's events as a card, or null when there are none. */
    private Gtk.Widget? list_for (Date day, Gee.List<Occurrence> occurrences, bool compact = false) {
        var rows = new Gtk.ListBox () { selection_mode = Gtk.SelectionMode.NONE };
        rows.add_css_class (Granite.CssClass.CARD);
        foreach (var occurrence in occurrences) {
            if (occurrence.touches (day)) {
                rows.append (row (occurrence, compact));
            }
        }
        return rows.get_first_child () != null ? rows : null;
    }

    private Gtk.Widget row (Occurrence occurrence, bool compact) {
        var bar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { width_request = 4 };
        bar.add_css_class ("event-bar");
        bar.add_css_class (Palette.class_for (occurrence.calendar));
        var title = new Gtk.Label (occurrence.summary != "" ? occurrence.summary : _("(Sans titre)")) {
            xalign = 0, ellipsize = Pango.EllipsizeMode.END, wrap = !compact, lines = 2
        };
        var time = new Gtk.Label (occurrence.time_label ()) { xalign = 0 };
        time.add_css_class (Granite.CssClass.DIM);
        time.add_css_class (Granite.CssClass.SMALL);
        var texts = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) { hexpand = true };
        texts.append (title);
        texts.append (time);
        if (!compact && occurrence.location != "") {
            var place = new Gtk.Label (occurrence.location) { xalign = 0, ellipsize = Pango.EllipsizeMode.END };
            place.add_css_class (Granite.CssClass.DIM);
            place.add_css_class (Granite.CssClass.SMALL);
            texts.append (place);
        }
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
            margin_top = 8, margin_bottom = 8, margin_start = 8, margin_end = 10
        };
        box.append (bar);
        box.append (texts);
        var row = new Gtk.ListBoxRow () { child = box, activatable = true };
        var click = new Gtk.GestureClick ();
        click.released.connect (() => event_activated (occurrence, row));
        row.add_controller (click);
        return row;
    }
}
