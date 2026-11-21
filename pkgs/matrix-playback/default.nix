{ writers, python3Packages }:

writers.writePython3Bin "matrix-playback" {
  libraries = [ python3Packages.websockets ];
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./matrix-playback.py)
