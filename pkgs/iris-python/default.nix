{
  python3,
  writeShellScriptBin,
}:

# A python3 interpreter carrying iris.py's deps (numpy + pillow), exposed as a
# distinct `iris-python` command so it doesn't collide with the system python3.
# apply_wallpaper_theme runs the out-of-store iris scripts through it.
let
  py = python3.withPackages (
    ps: with ps; [
      numpy
      pillow
    ]
  );
in
writeShellScriptBin "iris-python" ''
  exec ${py}/bin/python3 "$@"
''
