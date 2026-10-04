// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * One occurrence of an event, as the views draw it. A recurring event gives one
 * Occurrence per instance; uid and rid find it again in its calendar.
 */

public class Agenda.Occurrence : Object {
    public Calendar calendar { get; construct; }
    public string uid { get; construct; }
    /* Recurrence id of this instance, or "" for a single event. */
    public string rid { get; construct; }
    public bool recurring { get; construct; }
    public string summary { get; construct; }
    public string location { get; construct; }
    public string description { get; construct; }
    public bool all_day { get; construct; }
    /* Local time. For an all-day event, end is the day after the last day. */
    public DateTime start { get; construct; }
    public DateTime end { get; construct; }

    public Occurrence (Calendar calendar, string uid, string rid, bool recurring, string summary,
                       string location, string description, bool all_day, DateTime start, DateTime end) {
        Object (calendar: calendar, uid: uid, rid: rid, recurring: recurring, summary: summary,
                location: location, description: description, all_day: all_day, start: start, end: end);
    }

    /* True when the occurrence covers some part of the given local day. */
    public bool touches (Date day) {
        var day_start = new DateTime.local (day.get_year (), day.get_month (), day.get_day (), 0, 0, 0);
        var day_end = day_start.add_days (1);
        return start.compare (day_end) < 0 && end.compare (day_start) > 0
               || (start.equal (end) && start.compare (day_start) >= 0 && start.compare (day_end) < 0);
    }

    public string time_label () {
        if (all_day) {
            return _("Toute la journée");
        }
        return "%s – %s".printf (start.format ("%H:%M"), end.format ("%H:%M"));
    }

    /* Sort: all-day first, then by start time, then by title. */
    public static int compare (Occurrence a, Occurrence b) {
        if (a.all_day != b.all_day) {
            return a.all_day ? -1 : 1;
        }
        int by_start = a.start.compare (b.start);
        return by_start != 0 ? by_start : strcmp (a.summary, b.summary);
    }
}

namespace Agenda.Days {
    public Date today () {
        return from (new DateTime.now_local ());
    }

    public Date from (DateTime time) {
        var day = Date ();
        day.set_dmy ((DateDay) time.get_day_of_month (), time.get_month (), (DateYear) time.get_year ());
        return day;
    }
}
