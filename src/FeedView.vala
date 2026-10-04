// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * Idea C: the day as a feed. A field to add an event by typing it, a strip of
 * the next two weeks, the chosen day as a timeline with its free gaps, and the
 * rest of the week on the right.
 */

public class Agenda.FeedView : Gtk.Box {
    public signal void event_activated (Occurrence occurrence, Gtk.Widget relative_to);
    public signal void quick_added (QuickAdd request);

    private const int STRIP_DAYS = 14;

    private CalendarStore store;
    private Gtk.Box strip;
    private Gtk.Box timeline;
    private Gtk.Box week;
    private Gtk.Label day_title;
    private Gtk.Label month_label;
    private DateTime first;
    private DateTime selected;
    private uint generation = 0;

    public FeedView (CalendarStore store) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        this.store = store;
        var now = new DateTime.now_local ();
        first = new DateTime.local (now.get_year (), now.get_month (), now.get_day_of_month (), 0, 0, 0);
        selected = first;

        // Quick add
        var entry = new Gtk.Entry () {
            placeholder_text = _("Ajouter : « Dîner avec Léa vendredi 20 h »"),
            primary_icon_name = "list-add-symbolic",
            hexpand = true,
            max_width_chars = 60
        };
        entry.activate.connect (() => {
            var text = entry.text.strip ();
            if (text != "") {
                quick_added (new QuickAdd (text, new DateTime.now_local ()));
                entry.text = "";
            }
        });
        var entry_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.CENTER, margin_top = 12, margin_bottom = 6, width_request = 480
        };
        entry_box.append (entry);
        append (entry_box);

        // Strip of days
        month_label = new Gtk.Label ("") { width_chars = 10, xalign = 0 };
        month_label.add_css_class (Granite.HeaderLabel.Size.H2.to_string ());
        strip = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        var strip_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 6, margin_bottom = 12, margin_start = 18, margin_end = 18
        };
        strip_row.append (month_label);
        strip_row.append (new Gtk.ScrolledWindow () {
            child = strip, hexpand = true, vscrollbar_policy = Gtk.PolicyType.NEVER
        });
        strip_row.add_css_class ("feed-strip");
        append (strip_row);
        append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

        // Timeline and the week
        day_title = new Gtk.Label ("") { xalign = 0, margin_bottom = 12 };
        day_title.add_css_class (Granite.HeaderLabel.Size.H1.to_string ());
        timeline = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            halign = Gtk.Align.CENTER, width_request = 560, margin_top = 18, margin_bottom = 24
        };
        column.append (day_title);
        column.append (timeline);
        var center = new Gtk.ScrolledWindow () { child = column, hexpand = true, vexpand = true, hscrollbar_policy = Gtk.PolicyType.NEVER };

        week = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) { margin_top = 18, margin_start = 16, margin_end = 16 };
        var side = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { width_request = 280 };
        side.add_css_class ("day-panel");
        side.append (new Granite.HeaderLabel (_("Cette semaine")) { margin_top = 18, margin_start = 16 });
        side.append (new Gtk.ScrolledWindow () { child = week, vexpand = true, hscrollbar_policy = Gtk.PolicyType.NEVER });

        var body = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { vexpand = true };
        body.append (center);
        body.append (side);
        append (body);
        reload ();
    }

    public void go_to (DateTime day) {
        selected = new DateTime.local (day.get_year (), day.get_month (), day.get_day_of_month (), 0, 0, 0);
        if (selected.compare (first) < 0 || selected.compare (first.add_days (STRIP_DAYS)) >= 0) {
            first = selected;
        }
        reload ();
    }

    public void move (int days) {
        go_to (selected.add_days (days));
    }

    public DateTime shown_day () {
        return selected;
    }

    public void reload () {
        uint mine = ++generation;
        store.occurrences.begin (first, first.add_days (STRIP_DAYS), (obj, res) => {
            var occurrences = store.occurrences.end (res);
            if (mine == generation) {
                fill (occurrences);
            }
        });
    }

    private static string capitalised (string text) {
        return text.substring (0, 1).up () + text.substring (text.index_of_nth_char (1));
    }

    private void fill (Gee.List<Occurrence> occurrences) {
        month_label.label = capitalised (selected.format ("%B"));
        Gtk.Widget? child;
        while ((child = strip.get_first_child ()) != null) {
            strip.remove (child);
        }
        var today = new DateTime.now_local ();
        for (int i = 0; i < STRIP_DAYS; i++) {
            var day = first.add_days (i);
            int count = 0;
            foreach (var occurrence in occurrences) {
                if (occurrence.touches (Days.from (day))) {
                    count++;
                }
            }
            var name = new Gtk.Label (day.format ("%a").up ().replace (".", ""));
            name.add_css_class ("strip-name");
            var number = new Gtk.Label (day.get_day_of_month ().to_string ());
            number.add_css_class ("strip-number");
            var dots = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                halign = Gtk.Align.CENTER, width_request = count > 0 ? 6 + int.min (count, 4) * 5 : 0, height_request = 4
            };
            dots.add_css_class ("strip-dots");
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            box.append (name);
            box.append (number);
            box.append (dots);
            var button = new Gtk.Button () { child = box, width_request = 56 };
            button.add_css_class ("strip-day");
            button.add_css_class ("flat");
            if (day.equal (selected)) {
                button.add_css_class ("selected");
            }
            if (day.get_day_of_week () >= 6) {
                button.add_css_class ("weekend");
            }
            var target = day;
            button.clicked.connect (() => go_to (target));
            strip.append (button);
        }

        // The chosen day, with the gaps of an hour or more between events.
        bool is_today = selected.get_year () == today.get_year () && selected.get_day_of_year () == today.get_day_of_year ();
        day_title.label = is_today ? _("Aujourd'hui") + ", " + selected.format ("%e %B").strip ()
                                   : capitalised ("%s %d %s".printf (selected.format ("%A"), selected.get_day_of_month (),
                                                                      selected.format ("%B")));
        while ((child = timeline.get_first_child ()) != null) {
            timeline.remove (child);
        }
        var day_events = new Gee.ArrayList<Occurrence> ();
        foreach (var occurrence in occurrences) {
            if (occurrence.touches (Days.from (selected))) {
                day_events.add (occurrence);
            }
        }
        if (day_events.size == 0) {
            timeline.append (new Granite.Placeholder (_("Journée libre")) {
                description = _("Tapez un évènement dans le champ du haut pour l'ajouter."),
                icon = new ThemedIcon ("office-calendar")
            });
        }
        DateTime? cursor = null;
        foreach (var occurrence in day_events) {
            if (!occurrence.all_day && cursor != null && occurrence.start.difference (cursor) >= TimeSpan.HOUR) {
                timeline.append (feed_row (cursor.format ("%H:%M"), _("Libre"),
                                           duration (occurrence.start.difference (cursor)), null, null));
            }
            var detail = occurrence.location != "" ? occurrence.location : "";
            if (!occurrence.all_day) {
                var length = duration (occurrence.end.difference (occurrence.start));
                detail = detail != "" ? "%s · %s".printf (detail, length) : length;
            }
            timeline.append (feed_row (occurrence.all_day ? _("Journée") : occurrence.start.format ("%H:%M"),
                                       occurrence.summary != "" ? occurrence.summary : _("(Sans titre)"),
                                       detail, occurrence, Palette.class_for (occurrence.calendar)));
            if (!occurrence.all_day && (cursor == null || occurrence.end.compare (cursor) > 0)) {
                cursor = occurrence.end;
            }
        }

        // The rest of the week, one card per day.
        while ((child = week.get_first_child ()) != null) {
            week.remove (child);
        }
        for (int i = 1; i <= 7; i++) {
            var day = selected.add_days (i);
            var lines = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            foreach (var occurrence in occurrences) {
                if (occurrence.touches (Days.from (day))) {
                    var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { valign = Gtk.Align.CENTER };
                    dot.add_css_class ("event-dot");
                    dot.add_css_class (Palette.class_for (occurrence.calendar));
                    var text = new Gtk.Label ("%s  %s".printf (occurrence.all_day ? "" : occurrence.start.format ("%H:%M"),
                                                              occurrence.summary)) {
                        xalign = 0, ellipsize = Pango.EllipsizeMode.END
                    };
                    var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                    line.append (dot);
                    line.append (text);
                    lines.append (line);
                }
            }
            if (lines.get_first_child () == null) {
                continue;
            }
            var heading = new Gtk.Label (i == 1 ? _("Demain") : capitalised (day.format ("%A"))) { xalign = 0 };
            heading.add_css_class ("upcoming-day");
            var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            card.add_css_class (Granite.CssClass.CARD);
            card.add_css_class ("week-card");
            card.append (heading);
            card.append (lines);
            week.append (card);
        }
    }

    private static string duration (TimeSpan span) {
        int minutes = (int) (span / TimeSpan.MINUTE);
        if (minutes < 60) {
            return _("%d min").printf (minutes);
        }
        int hours = minutes / 60, rest = minutes % 60;
        return rest == 0 ? _("%d h").printf (hours) : _("%d h %02d").printf (hours, rest);
    }

    private Gtk.Widget feed_row (string time, string title, string detail, Occurrence? occurrence, string? color) {
        var time_label = new Gtk.Label (time) { width_chars = 6, xalign = 1, valign = Gtk.Align.START, margin_top = 12 };
        time_label.add_css_class ("feed-time");
        var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { halign = Gtk.Align.CENTER, margin_top = 15 };
        dot.add_css_class ("feed-dot");
        if (color != null) {
            dot.add_css_class ("event-dot");
            dot.add_css_class (color);
        } else {
            dot.add_css_class ("free");
        }
        var rail = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { halign = Gtk.Align.CENTER, vexpand = true, width_request = 2 };
        rail.add_css_class ("feed-rail");
        var marker = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { width_request = 14 };
        marker.append (dot);
        marker.append (rail);
        var title_label = new Gtk.Label (title) { xalign = 0, wrap = true };
        title_label.add_css_class ("feed-title");
        var texts = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        texts.append (title_label);
        if (detail != "") {
            var detail_label = new Gtk.Label (detail) { xalign = 0 };
            detail_label.add_css_class (Granite.CssClass.DIM);
            texts.append (detail_label);
        }
        Gtk.Widget card;
        if (occurrence != null) {
            var button = new Gtk.Button () { child = texts, hexpand = true, margin_bottom = 10 };
            button.add_css_class ("feed-card");
            var o = occurrence;
            button.clicked.connect (() => event_activated (o, button));
            card = button;
        } else {
            texts.hexpand = true;
            texts.margin_bottom = 10;
            texts.add_css_class ("feed-free");
            card = texts;
        }
        // The rail stretches to the row's height; the row itself must not grow.
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 14) { vexpand = false };
        card.valign = Gtk.Align.START;
        row.append (time_label);
        row.append (marker);
        row.append (card);
        return row;
    }
}
