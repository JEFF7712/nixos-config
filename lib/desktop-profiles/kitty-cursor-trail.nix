# Kitty cursor_trail presets, named like niri-animations.nix (snappy / glide / soft).
# Smaller decay = shorter smear. delayMs is how long the cursor must sit still
# before a jump counts; startThreshold is the minimum cell distance.
{
  default = {
    delayMs = 3;
    decayMin = 0.1;
    decayMax = 0.4;
    startThreshold = 2;
  };

  snappy = {
    delayMs = 1;
    decayMin = 0.04;
    decayMax = 0.12;
    startThreshold = 1;
  };

  glide = {
    delayMs = 3;
    decayMin = 0.08;
    decayMax = 0.28;
    startThreshold = 2;
  };

  soft = {
    delayMs = 5;
    decayMin = 0.16;
    decayMax = 0.55;
    startThreshold = 2;
  };
}
