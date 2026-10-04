// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 melvincouwez-alt
/*
 * Reads a line such as « Dîner avec Léa vendredi 20 h » or « dentiste demain
 * 9h30 » into a title, a day and an optional time. French words only, kept
 * simple: a day word (aujourd'hui, demain, après-demain, a weekday, or 12/10),
 * a time (20h, 20 h, 20h30, 20:30, à 9h) and the rest is the title.
 */

public class Agenda.QuickAdd : Object {
    public string title { get; private set; default = ""; }
    public DateTime day { get; private set; }
    public bool has_time { get; private set; default = false; }
    public int hour { get; private set; default = 9; }
    public int minute { get; private set; default = 0; }

    private const string[] WEEKDAYS = { "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche" };

    public QuickAdd (string text, DateTime now) {
        var today = new DateTime.local (now.get_year (), now.get_month (), now.get_day_of_month (), 0, 0, 0);
        day = today;
        var rest = " " + text.strip () + " ";

        // Time: 20h, 20 h, 20h30, 20:30, optionally after « à ».
        MatchInfo info;
        try {
            var time = new Regex ("(?:\\s(?:à|a)\\s)?\\s(\\d{1,2})\\s?(?:h|:)\\s?(\\d{2})?(?=\\s)", RegexCompileFlags.CASELESS);
            if (time.match (rest, 0, out info)) {
                int h = int.parse (info.fetch (1));
                var m_text = info.fetch (2);
                int m = m_text != null && m_text != "" ? int.parse (m_text) : 0;
                if (h < 24 && m < 60) {
                    hour = h;
                    minute = m;
                    has_time = true;
                    int start, end;
                    info.fetch_pos (0, out start, out end);
                    rest = rest.splice (start, end, " ");
                }
            }
            // Day: relative words first, then weekdays, then a 12/10 date.
            string[,] relative = { { "après-demain", "2" }, { "apres-demain", "2" }, { "demain", "1" },
                                   { "aujourd'hui", "0" }, { "ce soir", "0" } };
            bool found = false;
            for (int i = 0; i < relative.length[0] && !found; i++) {
                var word = new Regex ("\\s" + Regex.escape_string (relative[i, 0]) + "(?=\\s)", RegexCompileFlags.CASELESS);
                if (word.match (rest, 0, out info)) {
                    day = today.add_days (int.parse (relative[i, 1]));
                    if (relative[i, 0] == "ce soir" && !has_time) {
                        hour = 20;
                        has_time = true;
                    }
                    rest = remove_match (rest, info, relative[i, 0] == "ce soir");
                    found = true;
                }
            }
            for (int i = 0; i < WEEKDAYS.length && !found; i++) {
                var word = new Regex ("\\s(?:ce\\s|prochain\\s)?" + WEEKDAYS[i] + "(?:\\sprochain)?(?=\\s)", RegexCompileFlags.CASELESS);
                if (word.match (rest, 0, out info)) {
                    int ahead = (i + 1 - today.get_day_of_week () + 7) % 7;
                    day = today.add_days (ahead == 0 ? 7 : ahead);
                    rest = remove_match (rest, info, false);
                    found = true;
                }
            }
            var date = new Regex ("\\s(?:le\\s)?(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?(?=\\s)");
            if (!found && date.match (rest, 0, out info)) {
                int d = int.parse (info.fetch (1)), mo = int.parse (info.fetch (2));
                var y_text = info.fetch (3);
                int y = y_text != null && y_text != "" ? int.parse (y_text) : today.get_year ();
                if (y < 100) {
                    y += 2000;
                }
                var candidate = new DateTime.local (y, mo, d, 0, 0, 0);
                if (candidate != null) {
                    if ((y_text == null || y_text == "") && candidate.compare (today) < 0) {
                        candidate = candidate.add_years (1);
                    }
                    day = candidate;
                    rest = remove_match (rest, info, false);
                }
            }
        } catch (RegexError e) {
            warning ("quick add: %s", e.message);
        }
        // Loose words left around the title.
        var cleaned = rest.strip ();
        foreach (var tail in new string[] { " le", " à", " a", " pour", " de" }) {
            if (cleaned.down ().has_suffix (tail)) {
                cleaned = cleaned.substring (0, cleaned.length - tail.length).strip ();
            }
        }
        title = cleaned != "" ? cleaned.substring (0, 1).up () + cleaned.substring (cleaned.index_of_nth_char (1)) : "";
    }

    private static string remove_match (string text, MatchInfo info, bool keep_space) {
        int start, end;
        info.fetch_pos (0, out start, out end);
        return text.splice (start, end, " ");
    }

    public DateTime start () {
        return day.add_hours (has_time ? hour : 0).add_minutes (has_time ? minute : 0);
    }
}
