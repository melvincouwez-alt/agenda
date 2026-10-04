// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * New or edited event: title, calendar, all day, start and end, place, notes.
 * Editing a repeated event changes the whole series; its repetition rule is
 * kept as it is. Moving an event to another calendar copies it there and
 * removes it from the first.
 */

public class Agenda.EventEditor : Granite.Dialog {
    private CalendarStore store;
    private Occurrence? occurrence = null;
    private ICal.Component? existing = null;
    private Gee.List<Calendar> calendars;

    private Gtk.Entry title_entry;
    private Gtk.DropDown calendar_choice;
    private Gtk.Switch all_day;
    private DateTimeField start_field;
    private DateTimeField end_field;
    private Gtk.Entry location;
    private Gtk.TextView notes;
    private Gtk.Widget save_button;
    private Gtk.Label error_label;

    public EventEditor.for_new (Gtk.Window parent, CalendarStore store, Date day, DateTime? at = null,
                                string title = "", bool whole_day = false) {
        Object (transient_for: parent, modal: true, title: _("Nouvel évènement"));
        this.store = store;
        var now = new DateTime.now_local ();
        var start = at ?? new DateTime.local (day.get_year (), day.get_month (), day.get_day (), now.get_hour (), 0, 0)
                               .add_hours (1);
        build (start, whole_day ? start : start.add_hours (1), whole_day);
        title_entry.text = title;
    }

    public EventEditor.for_existing (Gtk.Window parent, CalendarStore store, Occurrence occurrence,
                                     ICal.Component comp) {
        Object (transient_for: parent, modal: true, title: _("Modifier l'évènement"));
        this.store = store;
        this.occurrence = occurrence;
        this.existing = comp;
        var start = CalendarStore.to_local (comp.get_dtstart ()) ?? occurrence.start;
        var end = CalendarStore.to_local (comp.get_dtend ()) ?? start.add_hours (1);
        bool whole_days = comp.get_dtstart ().is_date ();
        if (whole_days) {
            end = end.add_days (-1); // shown as the last day, stored as the day after
        }
        build (start, end, whole_days);
        title_entry.text = comp.get_summary () ?? "";
        location.text = comp.get_location () ?? "";
        notes.buffer.text = comp.get_description () ?? "";
        for (uint i = 0; i < calendars.size; i++) {
            if (calendars[(int) i] == occurrence.calendar) {
                calendar_choice.selected = i;
            }
        }
    }

    private void build (DateTime start, DateTime end, bool whole_days) {
        calendars = store.writable ();
        default_width = 460;

        title_entry = new Gtk.Entry () { placeholder_text = _("Titre de l'évènement"), activates_default = true };
        var names = new Gtk.StringList (null);
        foreach (var calendar in calendars) {
            names.append ("%s (%s)".printf (calendar.name, calendar.account));
        }
        calendar_choice = new Gtk.DropDown (names, null);
        all_day = new Gtk.Switch () { active = whole_days, valign = Gtk.Align.CENTER, halign = Gtk.Align.START };
        start_field = new DateTimeField (start);
        end_field = new DateTimeField (end);
        start_field.show_time = end_field.show_time = !whole_days;
        all_day.notify["active"].connect (() => {
            start_field.show_time = end_field.show_time = !all_day.active;
            validate ();
        });
        // Moving the start keeps the length, as calendars usually do.
        start_field.changed.connect ((before) => {
            var length = end_field.value.difference (before);
            end_field.value = start_field.value.add (length);
            validate ();
        });
        end_field.changed.connect (() => validate ());
        location = new Gtk.Entry () { placeholder_text = _("Lieu"), primary_icon_name = "mark-location-symbolic" };
        notes = new Gtk.TextView () { wrap_mode = Gtk.WrapMode.WORD_CHAR, top_margin = 6, bottom_margin = 6,
                                      left_margin = 6, right_margin = 6 };
        var notes_frame = new Gtk.ScrolledWindow () { child = notes, height_request = 90 };
        notes_frame.add_css_class (Granite.CssClass.CARD);
        error_label = new Gtk.Label ("") { xalign = 0, visible = false };
        error_label.add_css_class (Granite.CssClass.ERROR);

        var form = new Gtk.Grid () { column_spacing = 12, row_spacing = 9, margin_start = 12, margin_end = 12 };
        int row = 0;
        form.attach (title_entry, 0, row++, 2);
        form.attach (label (_("Agenda")), 0, row);
        form.attach (calendar_choice, 1, row++);
        form.attach (label (_("Toute la journée")), 0, row);
        form.attach (all_day, 1, row++);
        form.attach (label (_("Début")), 0, row);
        form.attach (start_field, 1, row++);
        form.attach (label (_("Fin")), 0, row);
        form.attach (end_field, 1, row++);
        form.attach (location, 0, row++, 2);
        var notes_label = label (_("Notes"));
        notes_label.xalign = 0;
        form.attach (notes_label, 0, row++, 2);
        form.attach (notes_frame, 0, row++, 2);
        form.attach (error_label, 0, row++, 2);
        get_content_area ().append (form);

        add_button (_("Annuler"), Gtk.ResponseType.CANCEL);
        save_button = add_button (occurrence == null ? _("Ajouter") : _("Enregistrer"), Gtk.ResponseType.ACCEPT);
        save_button.add_css_class (Granite.CssClass.SUGGESTED);
        set_default_response (Gtk.ResponseType.ACCEPT);
        response.connect ((id) => {
            if (id == Gtk.ResponseType.ACCEPT) {
                save.begin ();
            } else {
                destroy ();
            }
        });
        title_entry.grab_focus ();
        validate ();
    }

    private static Gtk.Label label (string text) {
        var result = new Gtk.Label (text) { xalign = 1 };
        result.add_css_class (Granite.CssClass.DIM);
        return result;
    }

    private DateTime start_value () {
        return all_day.active ? start_field.day_start () : start_field.value;
    }

    /* For all-day events the stored end is the day after the last day shown. */
    private DateTime end_value () {
        return all_day.active ? end_field.day_start ().add_days (1) : end_field.value;
    }

    private bool validate () {
        bool ok = end_value ().compare (start_value ()) > 0
                  || (!all_day.active && end_value ().equal (start_value ()));
        error_label.label = _("La fin est avant le début.");
        error_label.visible = !ok;
        save_button.sensitive = ok && calendars.size > 0;
        return ok;
    }

    private async void save () {
        if (!validate ()) {
            return;
        }
        save_button.sensitive = false;
        var calendar = calendars[(int) calendar_choice.selected];
        var event = existing != null ? existing.clone () : new ICal.Component.vevent ();
        if (existing == null) {
            event.set_uid (Uuid.string_random ());
            var stamp = new ICal.Time.current_with_zone (ICal.Timezone.get_utc_timezone ());
            event.set_dtstamp (stamp);
        }
        event.set_summary (title_entry.text.strip () != "" ? title_entry.text.strip () : _("Nouvel évènement"));
        event.set_dtstart (CalendarStore.to_ical (start_value (), all_day.active));
        event.set_dtend (CalendarStore.to_ical (end_value (), all_day.active));
        set_text (event, ICal.PropertyKind.LOCATION_PROPERTY, location.text.strip ());
        set_text (event, ICal.PropertyKind.DESCRIPTION_PROPERTY, notes.buffer.text.strip ());
        try {
            if (occurrence != null && calendar != occurrence.calendar) {
                yield store.save (calendar, event, true);
                yield store.remove (occurrence, true);
            } else {
                yield store.save (calendar, event, existing == null);
            }
            destroy ();
        } catch (Error e) {
            error_label.label = _("Enregistrement impossible : %s").printf (e.message);
            error_label.visible = true;
            save_button.sensitive = true;
        }
    }

    /* Set or drop a text property: an empty field removes it. */
    private static void set_text (ICal.Component event, ICal.PropertyKind kind, string text) {
        ICal.Property? property;
        while ((property = event.get_first_property (kind)) != null) {
            event.remove_property (property);
        }
        if (text == "") {
            return;
        }
        if (kind == ICal.PropertyKind.LOCATION_PROPERTY) {
            event.set_location (text);
        } else {
            event.set_description (text);
        }
    }
}

/* A date button with a calendar popover, followed by hour and minute fields. */
public class Agenda.DateTimeField : Gtk.Box {
    /* Emitted with the previous value when the user changes it. */
    public signal void changed (DateTime before);

    private DateTime current;
    private Gtk.MenuButton date_button;
    private Gtk.Label date_label;
    private Gtk.Calendar calendar;
    private Gtk.SpinButton hours;
    private Gtk.SpinButton minutes;
    private Gtk.Box time_box;
    private bool updating = false;

    public bool show_time {
        get { return time_box.visible; }
        set { time_box.visible = value; }
    }

    public DateTime value {
        get { return current; }
        set {
            current = value;
            sync ();
        }
    }

    public DateTimeField (DateTime initial) {
        Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
        current = initial;
        calendar = new Gtk.Calendar ();
        date_label = new Gtk.Label ("");
        var date_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        date_content.append (new Gtk.Image.from_icon_name ("office-calendar-symbolic"));
        date_content.append (date_label);
        date_button = new Gtk.MenuButton () { child = date_content, popover = new Gtk.Popover () { child = calendar } };
        calendar.day_selected.connect (() => {
            if (updating) {
                return;
            }
            var day = calendar.get_date ();
            apply_value (new DateTime.local (day.get_year (), day.get_month (), day.get_day_of_month (),
                                           current.get_hour (), current.get_minute (), 0));
            date_button.popover.popdown ();
        });
        hours = new Gtk.SpinButton.with_range (0, 23, 1) { orientation = Gtk.Orientation.HORIZONTAL, wrap = true };
        minutes = new Gtk.SpinButton.with_range (0, 55, 5) { orientation = Gtk.Orientation.HORIZONTAL, wrap = true };
        minutes.output.connect (() => {
            minutes.text = "%02d".printf ((int) minutes.value);
            return true;
        });
        hours.value_changed.connect (on_time);
        minutes.value_changed.connect (on_time);
        time_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        time_box.append (hours);
        time_box.append (new Gtk.Label (":"));
        time_box.append (minutes);
        append (date_button);
        append (time_box);
        sync ();
    }

    public DateTime day_start () {
        return new DateTime.local (current.get_year (), current.get_month (), current.get_day_of_month (), 0, 0, 0);
    }

    private void on_time () {
        if (updating) {
            return;
        }
        apply_value (new DateTime.local (current.get_year (), current.get_month (), current.get_day_of_month (),
                                       (int) hours.value, (int) minutes.value, 0));
    }

    private void apply_value (DateTime next) {
        var before = current;
        current = next;
        sync ();
        changed (before);
    }

    private void sync () {
        updating = true;
        date_label.label = current.format ("%e %b %Y").strip ();
        calendar.select_day (current);
        hours.value = current.get_hour ();
        minutes.value = current.get_minute () - current.get_minute () % 5;
        updating = false;
    }
}
