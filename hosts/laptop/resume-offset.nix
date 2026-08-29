# Generated after install: physical offset of /.swap/swapfile within
# /dev/mapper/cryptroot. Regenerate if the swapfile is ever recreated.
{
  boot.resumeDevice = "/dev/mapper/cryptroot";
  boot.kernelParams = [ "resume_offset=533760" ];
}
