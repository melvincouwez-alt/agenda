// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * Agenda: Boomerang's calendar. Your iCloud calendars and the ones on this PC,
 * through Evolution Data Server, in an elementary window. Opens .ics files too.
 */

public class Agenda.Application : Gtk.Application {
    public CalendarStore store { get; private set; }

    private const string STYLE = """
        .day-cell {
            padding: 4px;
            border-right: 1px solid alpha(@fg_color, 0.08);
            border-bottom: 1px solid alpha(@fg_color, 0.08);
            background-color: @base_color;
        }
        .day-cell.other-month {
            background-color: alpha(@fg_color, 0.03);
        }
        .day-cell.other-month .day-number {
            opacity: 0.4;
        }
        .day-cell.selected {
            background-color: alpha(@accent_color, 0.08);
        }
        .day-number {
            font-weight: 600;
            padding: 1px 6px;
            border-radius: 9999px;
        }
        .day-cell.today .day-number {
            background-color: @accent_color;
            color: @selected_fg_color;
        }
        .weekday {
            font-size: 0.85em;
            font-weight: 700;
            opacity: 0.6;
            padding: 6px 0;
        }
        .event-chip {
            font-size: 0.9em;
            padding: 1px 6px;
            border-radius: 4px;
            min-height: 0;
        }
        .event-chip.timed {
            background: none;
            box-shadow: none;
            border: none;
        }
        .event-dot {
            min-width: 8px;
            min-height: 8px;
            border-radius: 9999px;
        }
        .more-label {
            font-size: 0.85em;
            opacity: 0.7;
            padding: 0 6px;
        }
        .calendar-check check {
            border-radius: 4px;
        }
        .day-panel {
            background-color: @bg_color;
            border-left: 1px solid alpha(black, 0.1);
        }
        .day-panel-weekday {
            color: @accent_color;
            font-weight: 700;
        }
        .upcoming-day {
            font-size: 0.9em;
            font-weight: 600;
            opacity: 0.75;
        }
        .event-bar {
            border-radius: 9999px;
        }
        .layout-switch button {
            padding: 2px 14px;
        }
        .week-sidebar {
            background-color: @bg_color;
            border-right: 1px solid alpha(black, 0.1);
        }
        .week-main {
            background-color: @base_color;
        }
        .week-number {
            font-weight: 700;
        }
        .week-number.today {
            background-color: @accent_color;
            color: @selected_fg_color;
            border-radius: 9999px;
            padding: 0 7px;
        }
        .week-all-day {
            border-bottom: 1px solid alpha(@fg_color, 0.08);
            padding-bottom: 4px;
        }
        .hour-label {
            font-size: 0.8em;
            opacity: 0.55;
        }
        .week-column.today {
            background-color: alpha(@accent_color, 0.04);
        }
        .event-block {
            padding: 3px 6px;
            border-radius: 6px;
            min-height: 0;
            box-shadow: none;
            background-image: none;
        }
        .block-title {
            font-weight: 600;
            font-size: 0.9em;
        }
        .block-time {
            font-size: 0.8em;
            opacity: 0.8;
        }
        .strip-day {
            padding: 6px 0;
            border-radius: 10px;
        }
        .strip-day.selected {
            background-color: @accent_color;
            color: @selected_fg_color;
        }
        .strip-day.weekend .strip-name {
            opacity: 0.5;
        }
        .strip-name {
            font-size: 0.75em;
            font-weight: 700;
            opacity: 0.75;
        }
        .strip-number {
            font-size: 1.3em;
            font-weight: 700;
        }
        .strip-dots {
            border-radius: 9999px;
            background-color: @accent_color;
            opacity: 0.8;
        }
        .strip-day.selected .strip-dots {
            background-color: @selected_fg_color;
        }
        .feed-time {
            font-weight: 600;
            opacity: 0.6;
        }
        .feed-dot {
            min-width: 12px;
            min-height: 12px;
            border-radius: 9999px;
        }
        .feed-dot.free {
            border: 2px solid alpha(@fg_color, 0.2);
            background-color: @bg_color;
        }
        .feed-rail {
            background-color: alpha(@fg_color, 0.1);
            min-width: 2px;
        }
        .feed-card {
            padding: 8px 12px;
            border-radius: 10px;
        }
        .feed-title {
            font-weight: 600;
        }
        .feed-free {
            padding: 8px 12px;
            border-radius: 10px;
            border: 1px dashed alpha(@fg_color, 0.15);
            opacity: 0.7;
        }
        .week-card {
            padding: 10px 12px;
        }
    """;

    public Application () {
        // A development capture runs beside the real app, never through it.
        var flags = ApplicationFlags.HANDLES_OPEN;
        if (Environment.get_variable ("AGENDA_DEV_CAPTURE") != null) {
            flags |= ApplicationFlags.NON_UNIQUE;
        }
        Object (application_id: Config.APP_ID, flags: flags);
    }

    protected override void startup () {
        base.startup ();
        Granite.init ();
        Intl.setlocale (LocaleCategory.ALL, "");

        // Follow the system's dark style, as every elementary app does.
        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();
        gtk_settings.gtk_application_prefer_dark_theme =
            granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme =
                granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        var provider = new Gtk.CssProvider ();
        provider.load_from_string (STYLE);
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        store = new CalendarStore ();
        store.load.begin ((obj, res) => {
            try {
                store.load.end (res);
            } catch (Error e) {
                warning ("Evolution Data Server unavailable: %s", e.message);
            }
        });

        var new_event = new SimpleAction ("new-event", null);
        new_event.activate.connect (() => main_window ().new_event (null));
        add_action (new_event);
        set_accels_for_action ("app.new-event", { "<Control>n" });
        var about = new SimpleAction ("about", null);
        about.activate.connect (() => show_about (active_window));
        add_action (about);
        var quit = new SimpleAction ("quit", null);
        quit.activate.connect (() => this.quit ());
        add_action (quit);
        set_accels_for_action ("app.quit", { "<Control>q" });
        set_accels_for_action ("win.today", { "<Control>t" });
        set_accels_for_action ("win.previous", { "<Control>Page_Up" });
        set_accels_for_action ("win.next", { "<Control>Page_Down" });
        set_accels_for_action ("win.refresh", { "F5", "<Control>r" });
    }

    private MainWindow main_window () {
        var window = active_window as MainWindow;
        if (window == null) {
            window = new MainWindow (this);
        }
        return window;
    }

    protected override void activate () {
        main_window ().present ();
    }

    /* .ics files: offer to add their events to a calendar. */
    protected override void open (File[] files, string hint) {
        var window = main_window ();
        window.present ();
        foreach (var file in files) {
            Importer.run (window, store, file);
        }
    }

    public static int main (string[] args) {
        return new Agenda.Application ().run (args);
    }
}
