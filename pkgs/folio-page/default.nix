{ writers, python3Packages }:

writers.writePython3Bin "folio-page" {
  libraries = with python3Packages; [
    numpy
    pillow
  ];
  flakeIgnore = [
    "E203"
    "E501"
  ];
} (builtins.readFile ./page.py)
