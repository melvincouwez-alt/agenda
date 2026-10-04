// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * Six weeks from the Monday before the 1st. Each day shows its events: all-day
 * ones as a bar in the calendar's colour, timed ones as a dot, the time and the
 * title. Click a day to select it, double-click to add an event on it.
 */

namespace Agenda.Palette {
    private Gtk.CssProvider? provider = null;
    private Gee.HashSet<string>? known = null;

    /* A style class that paints in the calendar's colour, created on first use. */
    public string class_for (Calendar calendar) {
        if (provider == null) {
            provider = new Gtk.CssProvider ();
            known = new Gee.HashSet<string> ();
            Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 2);
        }
        var color = calendar.color;
        var name = "color-" + color.replace ("#", "").down ();
        if (!known.contains (name)) {
            known.add (name);
            var css = new StringBuilder ();
            foreach (var n in known) {
                var hex = "#" + n.substring (6);
                css.append (".event-chip.%s.all-day { background-color: %s; color: white; }\n".printf (n, hex));
                css.append (".event-dot.%s, .event-bar.%s { background-color: %s; }\n".printf (n, n, hex));
                css.append (".event-block.%s { background-color: alpha(%s, 0.18); box-shadow: inset 3px 0 0 %s; }\n"
                            .printf (n, hex, hex));
            }
            provider.load_from_string (css.str);
        }
        return name;
    }
}

public class Agenda.MonthView : Gtk.Box {
    public signal void event_activated (Occurrence occurrence, Gtk.Widget relative_to);
    public signal void day_activated (Date day);
    public signal void day_selected (Date day);

    private const int SHOWN_EVENTS = 3;

    private CalendarStore store;
    private Gtk.Grid grid;
    private DateTime month = new DateTime.now_local ();
    private Date first_day;
    private Date selected;
    private DayCell[] cells = new DayCell[42];
    private uint generation = 0;

    public MonthView (CalendarStore store) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        this.store = store;
        selected = Days.today ();

        var names = new Gtk.Grid () { column_homogeneous = true };
        var monday = new DateTime.local (2024, 1, 1, 0, 0, 0); // a Monday
        for (int i = 0; i < 7; i++) {
            var label = new Gtk.Label (monday.add_days (i).format ("%a").up ());
            label.add_css_class ("weekday");
            names.attach (label, i, 0);
        }
        append (names);

        grid = new Gtk.Grid () {
            column_homogeneous = true,
            row_homogeneous = true,
            vexpand = true,
            hexpand = true
        };
        for (int i = 0; i < 42; i++) {
            var cell = new DayCell (this);
            cells[i] = cell;
            grid.attach (cell, i % 7, i / 7);
        }
        append (grid);
    }

    public Date selected_day () {
        return selected;
    }

    public void select (Date day) {
        selected = day;
        foreach (var cell in cells) {
            cell.set_selected (cell.day.compare (selected) == 0);
        }
        day_selected (day);
    }

    public void show_month (DateTime first_of_month) {
        month = first_of_month;
        var first = Days.from (first_of_month);
        int back = ((int) first.get_weekday () - 1); // Monday = 1
        first_day = first;
        first_day.subtract_days (back);
        var today = Days.today ();
        for (int i = 0; i < 42; i++) {
            var day = first_day;
            day.add_days (i);
            cells[i].set_day (day, day.get_month () == first.get_month (), day.compare (today) == 0);
            cells[i].set_selected (day.compare (selected) == 0);
        }
        reload ();
    }

    public void reload () {
        var from = new DateTime.local (first_day.get_year (), first_day.get_month (), first_day.get_day (), 0, 0, 0);
        var to = from.add_days (42);
        uint mine = ++generation;
        store.occurrences.begin (from, to, (obj, res) => {
            var occurrences = store.occurrences.end (res);
            if (mine != generation) {
                return; // a later month or reload won
            }
            foreach (var cell in cells) {
                var day_events = new Gee.ArrayList<Occurrence> ();
                foreach (var occurrence in occurrences) {
                    if (occurrence.touches (cell.day)) {
                        day_events.add (occurrence);
                    }
                }
                cell.set_events (day_events);
            }
        });
    }

    private class DayCell : Gtk.Box {
        public Date day;
        private unowned MonthView view;
        private Gtk.Label number;
        private Gtk.Box events;

        public DayCell (MonthView view) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 2);
            this.view = view;
            add_css_class ("day-cell");
            overflow = Gtk.Overflow.HIDDEN;
            number = new Gtk.Label ("") { halign = Gtk.Align.END };
            number.add_css_class ("day-number");
            events = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
            append (number);
            append (events);

            var click = new Gtk.GestureClick ();
            click.pressed.connect ((n_press, x, y) => {
                view.select (day);
                if (n_press == 2) {
                    view.day_activated (day);
                }
            });
            add_controller (click);
        }

        public void set_day (Date day, bool in_month, bool is_today) {
            this.day = day;
            number.label = day.get_day ().to_string ();
            if (in_month) {
                remove_css_class ("other-month");
            } else {
                add_css_class ("other-month");
            }
            if (is_today) {
                add_css_class ("today");
            } else {
                remove_css_class ("today");
            }
        }

        public void set_selected (bool selected) {
            if (selected) {
                add_css_class ("selected");
            } else {
                remove_css_class ("selected");
            }
        }

        public void set_events (Gee.List<Occurrence> list) {
            Gtk.Widget? child;
            while ((child = events.get_first_child ()) != null) {
                events.remove (child);
            }
            int shown = 0;
            foreach (var occurrence in list) {
                if (shown == SHOWN_EVENTS && list.size > SHOWN_EVENTS + 1) {
                    break;
                }
                events.append (chip (occurrence));
                shown++;
            }
            int rest = list.size - shown;
            if (rest > 0) {
                var more = new Gtk.MenuButton () {
                    label = ngettext ("%d autre", "%d autres", rest).printf (rest),
                    halign = Gtk.Align.START
                };
                more.add_css_class ("flat");
                more.add_css_class ("more-label");
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                    margin_top = 6, margin_bottom = 6, margin_start = 6, margin_end = 6
                };
                foreach (var occurrence in list) {
                    box.append (chip (occurrence));
                }
                more.popover = new Gtk.Popover () { child = box };
                events.append (more);
            }
        }

        private Gtk.Widget chip (Occurrence occurrence) {
            var color_class = Palette.class_for (occurrence.calendar);
            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            var title = occurrence.summary != "" ? occurrence.summary : _("(Sans titre)");
            if (occurrence.all_day) {
                content.append (new Gtk.Label (title) { ellipsize = Pango.EllipsizeMode.END, xalign = 0 });
            } else {
                var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { valign = Gtk.Align.CENTER };
                dot.add_css_class ("event-dot");
                dot.add_css_class (color_class);
                var time = new Gtk.Label (occurrence.start.format ("%H:%M"));
                time.add_css_class (Granite.CssClass.DIM);
                content.append (dot);
                content.append (time);
                content.append (new Gtk.Label (title) { ellipsize = Pango.EllipsizeMode.END, xalign = 0 });
            }
            var button = new Gtk.Button () { child = content, tooltip_text = title };
            button.add_css_class ("event-chip");
            button.add_css_class (color_class);
            button.add_css_class (occurrence.all_day ? "all-day" : "timed");
            if (!occurrence.all_day) {
                button.add_css_class ("flat");
            }
            button.clicked.connect (() => view.event_activated (occurrence, button));
            return button;
        }
    }
}
