// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * The window, with three layouts to choose from in the header bar: Mois (the
 * month and a panel for the selected day, as elementary's Calendar), Semaine (a
 * timeline of the week) and Fil (the day as a feed with a quick-add field). The
 * choice is kept for the next launch.
 */

public class Agenda.MainWindow : Gtk.ApplicationWindow {
    private CalendarStore store;
    private MonthView month_view;
    private DayPanel day_panel;
    private WeekView week_view;
    private FeedView feed_view;
    private Gtk.Stack stack;
    private Gtk.Label title_label;
    private Gtk.Button refresh_button;
    private DateTime shown_month;

    public MainWindow (Application application) {
        Object (application: application, title: _("Agenda"), icon_name: Config.APP_ID,
                default_width: 1180, default_height: 780);
        store = application.store;

        var now = new DateTime.now_local ();
        shown_month = new DateTime.local (now.get_year (), now.get_month (), 1, 0, 0, 0);

        // Start: previous / today / next, then the month and year, as in Calendar.
        var previous = new Gtk.Button.from_icon_name ("go-previous-symbolic") {
            action_name = "win.previous",
            tooltip_markup = Granite.markup_accel_tooltip ({ "<Control>Page_Up" }, _("Mois précédent"))
        };
        var today = new Gtk.Button.with_label (_("Aujourd'hui")) {
            action_name = "win.today",
            tooltip_markup = Granite.markup_accel_tooltip ({ "<Control>t" }, _("Revenir à aujourd'hui"))
        };
        var next = new Gtk.Button.from_icon_name ("go-next-symbolic") {
            action_name = "win.next",
            tooltip_markup = Granite.markup_accel_tooltip ({ "<Control>Page_Down" }, _("Mois suivant"))
        };
        var navigation = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { valign = Gtk.Align.CENTER };
        navigation.add_css_class ("linked");
        navigation.append (previous);
        navigation.append (today);
        navigation.append (next);

        title_label = new Gtk.Label ("") { margin_start = 6 };
        title_label.add_css_class (Granite.HeaderLabel.Size.H3.to_string ());

        // End: the calendars menu, sync, and the new event button.
        var calendars = new Gtk.MenuButton () {
            icon_name = "office-calendar-symbolic",
            tooltip_text = _("Agendas affichés"),
            popover = new Gtk.Popover () { child = new CalendarList (store) },
            valign = Gtk.Align.CENTER
        };
        refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
            action_name = "win.refresh",
            valign = Gtk.Align.CENTER,
            tooltip_markup = Granite.markup_accel_tooltip ({ "F5" }, _("Synchroniser avec iCloud"))
        };
        var add = new Gtk.Button.from_icon_name ("appointment-new") {
            action_name = "app.new-event",
            valign = Gtk.Align.CENTER,
            tooltip_markup = Granite.markup_accel_tooltip ({ "<Control>n" }, _("Nouvel évènement"))
        };

        // The three layouts, as a segmented control in the middle.
        var layouts = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { valign = Gtk.Align.CENTER };
        layouts.add_css_class ("linked");
        layouts.add_css_class ("layout-switch");
        Gtk.ToggleButton? group = null;
        var toggles = new Gee.HashMap<string, Gtk.ToggleButton> ();
        string[,] names = { { "mois", _("Mois") }, { "semaine", _("Semaine") }, { "fil", _("Fil") } };
        for (int i = 0; i < names.length[0]; i++) {
            var toggle = new Gtk.ToggleButton.with_label (names[i, 1]) { group = group };
            group = group ?? toggle;
            var id = names[i, 0];
            toggle.toggled.connect (() => {
                if (toggle.active) {
                    stack.visible_child_name = id;
                }
            });
            toggles[id] = toggle;
            layouts.append (toggle);
        }

        var app_menu = new GLib.Menu ();
        app_menu.append (_("À propos d'Agenda"), "app.about");
        app_menu.append (_("Quitter"), "app.quit");
        var menu = new Gtk.MenuButton () {
            icon_name = "open-menu",
            menu_model = app_menu,
            tooltip_text = _("Menu"),
            valign = Gtk.Align.CENTER
        };

        var header = new Gtk.HeaderBar () { title_widget = layouts };
        header.add_css_class (Granite.STYLE_CLASS_FLAT);
        header.pack_start (navigation);
        header.pack_start (title_label);
        header.pack_end (menu);
        header.pack_end (add);
        header.pack_end (refresh_button);
        header.pack_end (calendars);
        set_titlebar (header);

        month_view = new MonthView (store);
        day_panel = new DayPanel (store);
        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            start_child = month_view,
            end_child = day_panel,
            resize_end_child = false,
            shrink_end_child = false,
            shrink_start_child = false
        };
        map.connect (() => paned.position = get_width () - 320);
        week_view = new WeekView (store);
        feed_view = new FeedView (store);
        stack = new Gtk.Stack () { transition_type = Gtk.StackTransitionType.CROSSFADE };
        stack.add_named (paned, "mois");
        stack.add_named (week_view, "semaine");
        stack.add_named (feed_view, "fil");
        child = stack;
        var layout = Environment.get_variable ("AGENDA_DEV_LAYOUT") ?? Settings.layout ();
        stack.visible_child_name = layout;
        toggles[toggles.has_key (layout) ? layout : "mois"].active = true;
        stack.notify["visible-child-name"].connect (() => {
            if (Environment.get_variable ("AGENDA_DEV_LAYOUT") == null) {
                Settings.set_layout (stack.visible_child_name);
            }
            update_title ();
        });

        add_action_simple ("previous", () => move (-1));
        add_action_simple ("next", () => move (1));
        add_action_simple ("today", () => {
            var n = new DateTime.now_local ();
            shown_month = new DateTime.local (n.get_year (), n.get_month (), 1, 0, 0, 0);
            show_month ();
            month_view.select (Days.today ());
            week_view.show_week (n);
            feed_view.go_to (n);
            update_title ();
        });
        add_action_simple ("refresh", () => refresh.begin ());

        month_view.event_activated.connect (show_event);
        day_panel.event_activated.connect (show_event);
        week_view.event_activated.connect (show_event);
        feed_view.event_activated.connect (show_event);
        week_view.slot_activated.connect ((start) => {
            var editor = new EventEditor.for_new (this, store, Days.from (start), start);
            editor.present ();
        });
        feed_view.quick_added.connect ((request) => {
            if (store.writable ().size == 0) {
                new_event (null);
                return;
            }
            var editor = new EventEditor.for_new (this, store, Days.from (request.day),
                                                  request.has_time ? request.start () : null, request.title,
                                                  !request.has_time);
            editor.present ();
        });
        month_view.day_activated.connect ((day) => new_event (day));
        month_view.day_selected.connect ((day) => day_panel.show_day (day));
        day_panel.add_requested.connect ((day) => new_event (day));
        store.events_changed.connect (reload);
        store.calendars_changed.connect (reload);

        // Scrolling over the month turns the pages, as in elementary's Calendar.
        var scroll = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.VERTICAL
                                                    | Gtk.EventControllerScrollFlags.DISCRETE);
        scroll.scroll.connect ((dx, dy) => {
            if (dy != 0 && stack.visible_child_name == "mois") {
                move (dy > 0 ? 1 : -1);
                return true;
            }
            return false;
        });
        month_view.add_controller (scroll);

        show_month ();

        // Development aids: AGENDA_DEV_VIEW=editor opens the new event dialog at
        // start; AGENDA_DEV_CAPTURE=file.png renders the window to that file after 6s.
        var capture = Environment.get_variable ("AGENDA_DEV_CAPTURE");
        if (capture != null) {
            Timeout.add_seconds (6, () => {
                capture_to (capture);
                return Source.REMOVE;
            });
        }
        if (Environment.get_variable ("AGENDA_DEV_VIEW") == "editor") {
            Timeout.add_seconds (2, () => {
                new_event (null);
                return Source.REMOVE;
            });
        }
    }

    private void capture_to (string path) {
        var paintable = new Gtk.WidgetPaintable (this);
        var snapshot = new Gtk.Snapshot ();
        paintable.snapshot (snapshot, get_width (), get_height ());
        var node = snapshot.to_node ();
        if (node == null) {
            return;
        }
        var texture = get_native ().get_renderer ().render_texture (node, null);
        texture.save_to_png (path);
        foreach (var toplevel in Gtk.Window.list_toplevels ()) {
            var dialog = toplevel as Gtk.Window;
            if (dialog != null && dialog != this && dialog.visible) {
                var p = new Gtk.WidgetPaintable (dialog);
                var s = new Gtk.Snapshot ();
                p.snapshot (s, dialog.get_width (), dialog.get_height ());
                var n = s.to_node ();
                if (n != null) {
                    dialog.get_native ().get_renderer ().render_texture (n, null).save_to_png (path.replace (".png", "-dialog.png"));
                }
            }
        }
    }

    private void add_action_simple (string name, owned SimpleActionActivateCallback callback) {
        var action = new SimpleAction (name, null);
        action.activate.connect ((a, p) => callback (a, p));
        add_action (action);
    }

    /* The arrows move by a month, a week or a day, as the layout shows. */
    private void move (int steps) {
        switch (stack.visible_child_name) {
            case "semaine":
                week_view.move (steps);
                break;
            case "fil":
                feed_view.move (steps);
                break;
            default:
                shown_month = shown_month.add_months (steps);
                show_month ();
                return;
        }
        update_title ();
    }

    private void show_month () {
        month_view.show_month (shown_month);
        update_title ();
    }

    private void update_title () {
        string text;
        switch (stack.visible_child_name) {
            case "semaine":
                var monday = week_view.week_start ();
                var sunday = monday.add_days (6);
                text = monday.get_month () == sunday.get_month ()
                    ? "%d – %d %s".printf (monday.get_day_of_month (), sunday.get_day_of_month (), sunday.format ("%B %Y"))
                    : "%d %s – %d %s".printf (monday.get_day_of_month (), monday.format ("%b"),
                                              sunday.get_day_of_month (), sunday.format ("%b %Y"));
                break;
            case "fil":
                text = feed_view.shown_day ().format ("%B %Y");
                break;
            default:
                text = shown_month.format ("%B %Y");
                break;
        }
        title_label.label = text.substring (0, 1).up () + text.substring (text.index_of_nth_char (1));
    }

    private void reload () {
        month_view.reload ();
        day_panel.reload ();
        week_view.reload ();
        feed_view.reload ();
    }

    private async void refresh () {
        refresh_button.sensitive = false;
        yield store.refresh ();
        refresh_button.sensitive = true;
    }

    private void show_event (Occurrence occurrence, Gtk.Widget relative_to) {
        var popover = new EventPopover (store, occurrence);
        popover.edit.connect (() => edit_event.begin (occurrence));
        popover.set_parent (relative_to);
        popover.closed.connect (() => {
            Idle.add (() => {
                popover.unparent ();
                return Source.REMOVE;
            });
        });
        popover.popup ();
    }

    public void new_event (Date? day) {
        if (store.writable ().size == 0) {
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Aucun agenda modifiable"),
                _("Connectez votre compte iCloud dans Boomerang (Services Apple) ou attendez que vos agendas "
                  + "aient fini de se charger."),
                "dialog-information", Gtk.ButtonsType.CLOSE) {
                transient_for = this,
                modal = true
            };
            dialog.response.connect (() => dialog.destroy ());
            dialog.present ();
            return;
        }
        var editor = new EventEditor.for_new (this, store, day ?? month_view.selected_day ());
        editor.present ();
    }

    private async void edit_event (Occurrence occurrence) {
        try {
            var comp = yield store.get_event (occurrence);
            var editor = new EventEditor.for_existing (this, store, occurrence, comp);
            editor.present ();
        } catch (Error e) {
            warning ("opening %s: %s", occurrence.uid, e.message);
        }
    }
}
