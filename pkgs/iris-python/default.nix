{
  python3,
  writeShellScriptBin,
}:

# python3 + numpy/pillow as `iris-python` (does not collide with system python3).
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
