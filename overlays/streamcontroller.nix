_final: prev: {
  # StreamController's page auto-switching has no niri backend upstream.
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
    '';
  });
}
