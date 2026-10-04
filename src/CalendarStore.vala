// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * Calendars and events, through Evolution Data Server. EDS already carries the
 * iCloud calendars Covalence sets up (CalDAV) and the ones on this PC, and keeps
 * them in sync; Agenda reads and writes through it like elementary's Calendar,
 * so an event added here shows up in Calendar, on the iPhone and on iCloud.com.
 */

public class Agenda.Calendar : Object {
    public E.Source source { get; construct; }
    public string account { get; construct; }
    public ECal.Client? client { get; set; default = null; }

    public Calendar (E.Source source, string account) {
        Object (source: source, account: account);
    }

    public string uid {
        get { return source.uid; }
    }

    public string name {
        owned get { return source.display_name; }
    }

    private E.SourceSelectable extension {
        get { return (E.SourceSelectable) source.get_extension (E.SOURCE_EXTENSION_CALENDAR); }
    }

    /* Shown in the views: the calendar's "selected" flag, shared with Calendar. */
    public bool visible {
        get { return extension.selected; }
        set {
            extension.selected = value;
            source.write.begin (null);
        }
    }

    public string color {
        owned get {
            var value = extension.color;
            return value != null && value != "" ? value : "#3689e6";
        }
    }

    public bool writable {
        get { return client != null && !client.readonly; }
    }
}

public class Agenda.CalendarStore : Object {
    /* Calendars or their visibility changed: rebuild the sidebar and redraw. */
    public signal void calendars_changed ();
    /* Events changed in some calendar: reload the shown range. */
    public signal void events_changed ();

    private E.SourceRegistry? registry = null;
    private Gee.HashMap<string, Calendar> calendars = new Gee.HashMap<string, Calendar> ();
    private Gee.HashMap<string, ECal.ClientView> views = new Gee.HashMap<string, ECal.ClientView> ();
    private uint changed_timeout = 0;

    public async void load () throws Error {
        registry = yield new E.SourceRegistry (null);
        registry.source_added.connect ((source) => add_source.begin (source));
        registry.source_removed.connect (remove_source);
        registry.source_changed.connect ((source) => {
            if (calendars.has_key (source.uid)) {
                calendars_changed ();
                events_changed ();
            }
        });
        // Connect them all at once: a slow CalDAV account must not hold up the rest.
        foreach (var source in registry.list_sources (E.SOURCE_EXTENSION_CALENDAR)) {
            add_source.begin (source);
        }
    }

    private async void add_source (E.Source source) {
        if (!source.has_extension (E.SOURCE_EXTENSION_CALENDAR) || !source.enabled
            || calendars.has_key (source.uid)) {
            return;
        }
        var calendar = new Calendar (source, account_name (source));
        calendars[source.uid] = calendar;
        calendars_changed ();
        try {
            calendar.client = (ECal.Client) yield ECal.Client.connect (source, ECal.ClientSourceType.EVENTS,
                                                                      30, null);
            watch (calendar);
        } catch (Error e) {
            warning ("calendar %s: %s", source.display_name, e.message);
        }
        calendars_changed ();
        events_changed ();
    }

    private void remove_source (E.Source source) {
        if (calendars.unset (source.uid)) {
            views.unset (source.uid);
            calendars_changed ();
            events_changed ();
        }
    }

    /* A live view on the whole calendar: any change there reloads the shown range. */
    private void watch (Calendar calendar) {
        calendar.client.get_view.begin ("#t", null, (obj, res) => {
            try {
                ECal.ClientView view;
                calendar.client.get_view.end (res, out view);
                view.objects_added.connect (() => queue_changed ());
                view.objects_modified.connect (() => queue_changed ());
                view.objects_removed.connect (() => queue_changed ());
                view.start ();
                views[calendar.uid] = view;
            } catch (Error e) {
                warning ("watching %s: %s", calendar.name, e.message);
            }
        });
    }

    /* Coalesce bursts (a sync brings many objects at once) into one reload. */
    private void queue_changed () {
        if (changed_timeout != 0) {
            Source.remove (changed_timeout);
        }
        changed_timeout = Timeout.add (250, () => {
            changed_timeout = 0;
            events_changed ();
            return Source.REMOVE;
        });
    }

    private string account_name (E.Source source) {
        var parent = source.parent != null ? registry.ref_source (source.parent) : null;
        if (parent == null) {
            return _("Autres");
        }
        var name = parent.display_name;
        if (name == "Sur cet ordinateur" || parent.uid == "local-stub") {
            return _("Sur ce PC");
        }
        return name;
    }

    /* Calendars grouped by account, iCloud first, then this PC, then the rest. */
    public Gee.List<Calendar> list () {
        var result = new Gee.ArrayList<Calendar> ();
        result.add_all (calendars.values);
        result.sort ((a, b) => {
            int rank_a = rank (a.account), rank_b = rank (b.account);
            if (rank_a != rank_b) {
                return rank_a - rank_b;
            }
            int by_account = strcmp (a.account, b.account);
            return by_account != 0 ? by_account : a.name.collate (b.name);
        });
        return result;
    }

    private static int rank (string account) {
        if (account == "iCloud") {
            return 0;
        }
        return account == _("Sur ce PC") ? 1 : 2;
    }

    public Gee.List<Calendar> writable () {
        var result = new Gee.ArrayList<Calendar> ();
        foreach (var calendar in list ()) {
            if (calendar.writable) {
                result.add (calendar);
            }
        }
        return result;
    }

    public Calendar? find (string uid) {
        return calendars[uid];
    }

    /*
     * Every occurrence between from and to (local times) in the visible calendars,
     * recurring events expanded. EDS runs the expansion; it is quick from its
     * cache, so this runs in a worker thread only to keep large ranges smooth.
     */
    public async Gee.List<Occurrence> occurrences (DateTime from, DateTime to) {
        var result = new Gee.ArrayList<Occurrence> ();
        var wanted = new Gee.ArrayList<Calendar> ();
        foreach (var calendar in calendars.values) {
            if (calendar.visible && calendar.client != null) {
                wanted.add (calendar);
            }
        }
        SourceFunc callback = occurrences.callback;
        new Thread<void> ("agenda-occurrences", () => {
            foreach (var calendar in wanted) {
                collect (calendar, (time_t) from.to_unix (), (time_t) to.to_unix (), result);
            }
            Idle.add ((owned) callback);
        });
        yield;
        result.sort (Occurrence.compare);
        return result;
    }

    private static Mutex collect_mutex;

    private static void collect (Calendar calendar, time_t from, time_t to, Gee.List<Occurrence> into) {
        var found = new Gee.ArrayList<Occurrence> ();
        calendar.client.generate_instances_sync (from, to, null, (comp, instance_start, instance_end) => {
            var occurrence = occurrence_from (calendar, comp, instance_start, instance_end);
            if (occurrence != null) {
                found.add (occurrence);
            }
            return true;
        });
        collect_mutex.lock ();
        into.add_all (found);
        collect_mutex.unlock ();
    }

    private static Occurrence? occurrence_from (Calendar calendar, ICal.Component comp,
                                                ICal.Time start, ICal.Time end) {
        var begins = to_local (start);
        if (begins == null) {
            return null;
        }
        var ends = to_local (end) ?? begins;
        bool all_day = start.is_date ();
        if (all_day && ends.compare (begins) <= 0) {
            ends = begins.add_days (1);
        }
        var rid_time = comp.get_recurrenceid ();
        string rid = rid_time != null && !rid_time.is_null_time () ? rid_time.as_ical_string () : "";
        bool recurring = rid != "" || comp.get_first_property (ICal.PropertyKind.RRULE_PROPERTY) != null;
        if (recurring && rid == "") {
            rid = start.as_ical_string ();
        }
        return new Occurrence (calendar, comp.get_uid () ?? "", rid, recurring, comp.get_summary () ?? "",
                               comp.get_location () ?? "", comp.get_description () ?? "", all_day, begins, ends);
    }

    /* An iCal time as local time; a date stays at local midnight. */
    public static DateTime? to_local (ICal.Time time) {
        if (time.is_null_time ()) {
            return null;
        }
        if (time.is_date ()) {
            return new DateTime.local (time.get_year (), time.get_month (), time.get_day (), 0, 0, 0);
        }
        var zone = time.get_timezone () ?? (time.is_utc () ? ICal.Timezone.get_utc_timezone () : null);
        var seconds = time.as_timet_with_zone (zone);
        return new DateTime.from_unix_local ((int64) seconds);
    }

    public static ICal.Timezone local_zone () {
        var id = new TimeZone.local ().get_identifier ();
        return ICal.Timezone.get_builtin_timezone (id) ?? ICal.Timezone.get_utc_timezone ();
    }

    public static ICal.Time to_ical (DateTime time, bool all_day) {
        if (all_day) {
            var date = new ICal.Time.null_date ();
            date.set_date (time.get_year (), time.get_month (), time.get_day_of_month ());
            return date;
        }
        var zone = local_zone ();
        return new ICal.Time.from_timet_with_zone ((time_t) time.to_unix (), 0, zone);
    }

    /* Store a new event or save an edited one (the whole series for a recurring event). */
    public async void save (Calendar calendar, ICal.Component event, bool is_new) throws Error {
        if (is_new) {
            string uid;
            yield calendar.client.create_object (event, ECal.OperationFlags.NONE, null, out uid);
        } else {
            yield calendar.client.modify_object (event, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, null);
        }
    }

    /* The stored event behind an occurrence: the master of a series. */
    public async ICal.Component get_event (Occurrence occurrence) throws Error {
        ICal.Component comp;
        yield occurrence.calendar.client.get_object (occurrence.uid, null, null, out comp);
        return comp;
    }

    public async void remove (Occurrence occurrence, bool whole_series) throws Error {
        var mod = whole_series || !occurrence.recurring ? ECal.ObjModType.ALL : ECal.ObjModType.THIS;
        string? rid = occurrence.recurring && !whole_series ? occurrence.rid : null;
        yield occurrence.calendar.client.remove_object (occurrence.uid, rid, mod, ECal.OperationFlags.NONE, null);
    }

    /* Ask every calendar's backend to fetch changes now (CalDAV sync). */
    public async void refresh () {
        foreach (var calendar in calendars.values) {
            if (calendar.client != null && calendar.client.check_refresh_supported ()) {
                try {
                    yield calendar.client.refresh (null);
                } catch (Error e) {
                    warning ("refreshing %s: %s", calendar.name, e.message);
                }
            }
        }
    }
}
