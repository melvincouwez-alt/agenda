// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * Idea B: the week as a timeline. A sidebar with a small month and the week
 * picked in it; seven columns of hours, events as tinted blocks, all-day ones
 * in a strip above, and a red line at the current time.
 */

public class Agenda.WeekView : Gtk.Box {
    public signal void event_activated (Occurrence occurrence, Gtk.Widget relative_to);
    public signal void slot_activated (DateTime start);

    public const int HOUR_HEIGHT = 48;

    private CalendarStore store;
    private Gtk.Calendar mini;
    private Gtk.Box names;
    private Gtk.Box all_day;
    private DayColumn[] columns = new DayColumn[7];
    private Gtk.ScrolledWindow scroller;
    private DateTime monday;
    private uint generation = 0;

    public WeekView (CalendarStore store) {
        Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        this.store = store;

        // Sidebar: a small month; picking a day shows its week.
        mini = new Gtk.Calendar () { margin_top = 12, margin_start = 12, margin_end = 12, show_heading = true };
        mini.day_selected.connect (() => show_week (mini.get_date ()));
        var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { width_request = 250 };
        sidebar.add_css_class ("week-sidebar");
        sidebar.append (mini);
        append (sidebar);

        var main = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { hexpand = true };
        main.add_css_class ("week-main");
        names = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { homogeneous = true, margin_start = 52 };
        all_day = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { homogeneous = true, margin_start = 52 };
        all_day.add_css_class ("week-all-day");
        main.append (names);
        main.append (all_day);

        var hours = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { width_request = 52 };
        for (int h = 0; h < 24; h++) {
            var label = new Gtk.Label (h == 0 ? "" : "%d:00".printf (h)) {
                height_request = HOUR_HEIGHT, xalign = 1, yalign = 0, margin_end = 8
            };
            label.add_css_class ("hour-label");
            hours.append (label);
        }
        var grid = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { homogeneous = true, hexpand = true };
        for (int i = 0; i < 7; i++) {
            columns[i] = new DayColumn (this);
            grid.append (columns[i]);
        }
        var body = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        body.append (hours);
        body.append (grid);
        scroller = new Gtk.ScrolledWindow () { child = body, vexpand = true, hscrollbar_policy = Gtk.PolicyType.NEVER };
        main.append (scroller);
        append (main);

        show_week (new DateTime.now_local ());
        // Open on the working day, from 7:30.
        map.connect (() => Idle.add (() => {
            scroller.vadjustment.value = HOUR_HEIGHT * 7.5;
            return Source.REMOVE;
        }));
    }

    public DateTime week_start () {
        return monday;
    }

    public void show_week (DateTime any_day) {
        var day = new DateTime.local (any_day.get_year (), any_day.get_month (), any_day.get_day_of_month (), 0, 0, 0);
        monday = day.add_days (1 - day.get_day_of_week ());
        Gtk.Widget? child;
        while ((child = names.get_first_child ()) != null) {
            names.remove (child);
        }
        var today = new DateTime.now_local ();
        for (int i = 0; i < 7; i++) {
            var d = monday.add_days (i);
            bool is_today = d.get_year () == today.get_year () && d.get_day_of_year () == today.get_day_of_year ();
            var name = new Gtk.Label (d.format ("%a").up ());
            name.add_css_class ("weekday");
            var number = new Gtk.Label (d.get_day_of_month ().to_string ());
            number.add_css_class ("week-number");
            if (is_today) {
                number.add_css_class ("today");
            }
            var head = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) { margin_top = 6, margin_bottom = 6, margin_start = 8 };
            head.append (name);
            head.append (number);
            names.append (head);
            columns[i].set_day (d, is_today);
        }
        reload ();
    }

    public void move (int weeks) {
        show_week (monday.add_weeks (weeks));
    }

    public void reload () {
        uint mine = ++generation;
        store.occurrences.begin (monday, monday.add_days (7), (obj, res) => {
            var occurrences = store.occurrences.end (res);
            if (mine != generation) {
                return;
            }
            Gtk.Widget? child;
            while ((child = all_day.get_first_child ()) != null) {
                all_day.remove (child);
            }
            for (int i = 0; i < 7; i++) {
                var day = Days.from (monday.add_days (i));
                var timed = new Gee.ArrayList<Occurrence> ();
                var whole = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) { margin_start = 2, margin_end = 2 };
                foreach (var occurrence in occurrences) {
                    if (!occurrence.touches (day)) {
                        continue;
                    }
                    if (occurrence.all_day) {
                        whole.append (chip (occurrence));
                    } else {
                        timed.add (occurrence);
                    }
                }
                all_day.append (whole);
                columns[i].set_events (timed);
            }
        });
    }

    private Gtk.Widget chip (Occurrence occurrence) {
        var button = new Gtk.Button.with_label (occurrence.summary != "" ? occurrence.summary : _("(Sans titre)"));
        button.add_css_class ("event-chip");
        button.add_css_class ("all-day");
        button.add_css_class (Palette.class_for (occurrence.calendar));
        ((Gtk.Label) button.child).ellipsize = Pango.EllipsizeMode.END;
        button.clicked.connect (() => event_activated (occurrence, button));
        return button;
    }

    /* One day of the timeline: hour lines, events placed by their times. */
    private class DayColumn : Gtk.Widget {
        private unowned WeekView view;
        private DateTime day;
        private bool is_today;
        private Gee.ArrayList<Gtk.Widget> blocks = new Gee.ArrayList<Gtk.Widget> ();
        private Gee.HashMap<Gtk.Widget, Occurrence> placed = new Gee.HashMap<Gtk.Widget, Occurrence> ();
        private Gee.HashMap<Gtk.Widget, int> lanes = new Gee.HashMap<Gtk.Widget, int> ();
        private int lane_count = 1;

        public DayColumn (WeekView view) {
            this.view = view;
            add_css_class ("week-column");
            hexpand = true;
            var click = new Gtk.GestureClick ();
            click.pressed.connect ((n, x, y) => {
                if (n == 2) {
                    int minutes = ((int) (y / HOUR_HEIGHT * 60) / 30) * 30;
                    view.slot_activated (day.add_minutes (minutes));
                }
            });
            add_controller (click);
        }

        public void set_day (DateTime day, bool is_today) {
            this.day = day;
            this.is_today = is_today;
            if (is_today) {
                add_css_class ("today");
            } else {
                remove_css_class ("today");
            }
            queue_draw ();
        }

        public void set_events (Gee.List<Occurrence> events) {
            foreach (var block in blocks) {
                block.unparent ();
            }
            blocks.clear ();
            placed.clear ();
            lanes.clear ();
            // Overlapping events share the width, each in its own lane.
            var ends = new Gee.ArrayList<DateTime> ();
            foreach (var occurrence in events) {
                int lane = 0;
                while (lane < ends.size && ends[lane].compare (occurrence.start) > 0) {
                    lane++;
                }
                if (lane == ends.size) {
                    ends.add (occurrence.end);
                } else {
                    ends[lane] = occurrence.end;
                }
                var block = block_for (occurrence);
                block.set_parent (this);
                blocks.add (block);
                placed[block] = occurrence;
                lanes[block] = lane;
            }
            lane_count = int.max (1, ends.size);
            queue_allocate ();
        }

        private Gtk.Widget block_for (Occurrence occurrence) {
            var title = new Gtk.Label (occurrence.summary != "" ? occurrence.summary : _("(Sans titre)")) {
                xalign = 0, ellipsize = Pango.EllipsizeMode.END
            };
            title.add_css_class ("block-title");
            var time = new Gtk.Label (occurrence.time_label ()) { xalign = 0, ellipsize = Pango.EllipsizeMode.END };
            time.add_css_class ("block-time");
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (title);
            box.append (time);
            var button = new Gtk.Button () { child = box, overflow = Gtk.Overflow.HIDDEN };
            button.add_css_class ("event-block");
            button.add_css_class (Palette.class_for (occurrence.calendar));
            button.clicked.connect (() => view.event_activated (occurrence, button));
            return button;
        }

        protected override void measure (Gtk.Orientation orientation, int for_size, out int minimum, out int natural,
                                         out int minimum_baseline, out int natural_baseline) {
            minimum = natural = orientation == Gtk.Orientation.VERTICAL ? HOUR_HEIGHT * 24 : 40;
            minimum_baseline = natural_baseline = -1;
        }

        protected override void size_allocate (int width, int height, int baseline) {
            int lane_width = (width - 6) / lane_count;
            foreach (var block in blocks) {
                var occurrence = placed[block];
                var midnight = new DateTime.local (day.get_year (), day.get_month (), day.get_day_of_month (), 0, 0, 0);
                double from = double.max (0, occurrence.start.difference (midnight) / (double) TimeSpan.MINUTE);
                double to = double.min (24 * 60, occurrence.end.difference (midnight) / (double) TimeSpan.MINUTE);
                int y = (int) (from / 60 * HOUR_HEIGHT);
                int h = int.max (22, (int) ((to - from) / 60 * HOUR_HEIGHT) - 2);
                int min_w, nat_w, min_h, nat_h;
                block.measure (Gtk.Orientation.HORIZONTAL, -1, out min_w, out nat_w, null, null);
                block.measure (Gtk.Orientation.VERTICAL, -1, out min_h, out nat_h, null, null);
                var at = new Gsk.Transform ().translate (Graphene.Point () { x = 3 + lanes[block] * lane_width, y = y });
                block.allocate (int.max (min_w, lane_width - 2), int.max (min_h, h), -1, at);
            }
        }

        protected override void snapshot (Gtk.Snapshot snapshot) {
            int width = get_width ();
            var line = Gdk.RGBA ();
            line.parse ("rgba(0,0,0,0.07)");
            for (int h = 1; h < 24; h++) {
                snapshot.append_color (line, Graphene.Rect ().init (0, h * HOUR_HEIGHT, width, 1));
            }
            snapshot.append_color (line, Graphene.Rect ().init (width - 1, 0, 1, HOUR_HEIGHT * 24));
            base.snapshot (snapshot);
            if (is_today) {
                var now = new DateTime.now_local ();
                float y = (float) ((now.get_hour () * 60 + now.get_minute ()) / 60.0 * HOUR_HEIGHT);
                var red = Gdk.RGBA ();
                red.parse ("#c6262e");
                snapshot.append_color (red, Graphene.Rect ().init (0, y - 1, width, 2));
            }
        }

        protected override void dispose () {
            foreach (var block in blocks) {
                block.unparent ();
            }
            blocks.clear ();
            base.dispose ();
        }
    }
}
