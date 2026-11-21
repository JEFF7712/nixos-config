{
  python3,
  writeShellScriptBin,
}:

# python3 + icalendar/recurring-ical-events as `calendar-python` for next-events.
let
  py = python3.withPackages (
    ps: with ps; [
      icalendar
      recurring-ical-events
    ]
  );
in
writeShellScriptBin "calendar-python" ''
  exec ${py}/bin/python3 "$@"
''
