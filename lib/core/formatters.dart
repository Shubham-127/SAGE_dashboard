/// Small helper that turns a time into text like "14:05:09".
/// padLeft(2, '0') makes sure 5 becomes "05".
String fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
