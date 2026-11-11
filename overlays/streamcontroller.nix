_final: prev: {
  # StreamController's page auto-switching has no niri backend upstream.
  # It also re-creates its autostart entry when autostart is disabled.
  streamcontroller = prev.streamcontroller.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cp ${./streamcontroller-niri.py} src/backend/WindowGrabber/Integrations/Niri.py
      substituteInPlace src/backend/WindowGrabber/WindowGrabber.py \
        --replace-fail \
          'from src.backend.WindowGrabber.Integrations.KDE import KDE' \
          'from src.backend.WindowGrabber.Integrations.KDE import KDE
      from src.backend.WindowGrabber.Integrations.Niri import Niri' \
        --replace-fail '"x11", "kde"]' '"x11", "kde", "niri"]' \
        --replace-fail \
          'self.integration = KDE(self)' \
          'self.integration = KDE(self)
              elif self.environment == "niri":
                  self.integration = Niri(self)'

      # Disabling autostart outside Flatpak still asks the Flatpak portal,
      # whose failure path re-creates the XDG autostart entry. The
      # streamcontroller home-manager module starts it as a user service.
      substituteInPlace autostart.py \
        --replace-fail \
          'setup_autostart_flatpak(False)' \
          'if is_flatpak(): setup_autostart_flatpak(False)'
    '';
  });
}
