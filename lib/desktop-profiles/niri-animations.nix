rec {
  default = {
    "workspace-switch" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1000;
        epsilon = 0.0001;
      };
    };
    "window-open" = {
      durationMs = 150;
      curve = "ease-out-expo";
    };
    "window-close" = {
      durationMs = 150;
      curve = "ease-out-quad";
    };
    "horizontal-view-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 800;
        epsilon = 0.0001;
      };
    };
    "window-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 800;
        epsilon = 0.0001;
      };
    };
    "window-resize" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 800;
        epsilon = 0.0001;
      };
    };
    "config-notification-open-close" = {
      spring = {
        dampingRatio = 0.6;
        stiffness = 1000;
        epsilon = 0.001;
      };
    };
    "exit-confirmation-open-close" = {
      spring = {
        dampingRatio = 0.6;
        stiffness = 500;
        epsilon = 0.01;
      };
    };
    "screenshot-ui-open" = {
      durationMs = 200;
      curve = "ease-out-quad";
    };
    "overview-open-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 800;
        epsilon = 0.0001;
      };
    };
    "recent-windows-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 800;
        epsilon = 0.001;
      };
    };
  };

  snappy = default // {
    "workspace-switch" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1300;
        epsilon = 0.0001;
      };
    };
    "window-open" = {
      durationMs = 110;
      curve = "ease-out-expo";
    };
    "window-close" = {
      durationMs = 100;
      curve = "ease-out-quad";
    };
    "horizontal-view-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1100;
        epsilon = 0.0001;
      };
    };
    "window-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1100;
        epsilon = 0.0001;
      };
    };
  };

  glide = default // {
    "workspace-switch" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 780;
        epsilon = 0.0001;
      };
    };
    "window-open" = {
      durationMs = 170;
      curve = "ease-out-expo";
    };
    "window-close" = {
      durationMs = 125;
      curve = "ease-out-quad";
    };
    "horizontal-view-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 720;
        epsilon = 0.0001;
      };
    };
    "window-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 760;
        epsilon = 0.0001;
      };
    };
  };

  soft = default // {
    "workspace-switch" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 650;
        epsilon = 0.0001;
      };
    };
    "window-open" = {
      durationMs = 210;
      curve = "ease-out-expo";
    };
    "window-close" = {
      durationMs = 140;
      curve = "ease-out-quad";
    };
    "horizontal-view-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 600;
        epsilon = 0.0001;
      };
    };
    "window-movement" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 650;
        epsilon = 0.0001;
      };
    };
  };
}
