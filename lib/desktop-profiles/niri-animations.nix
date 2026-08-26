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
    "window-resize" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1200;
        epsilon = 0.0001;
      };
    };
    "config-notification-open-close" = {
      spring = {
        dampingRatio = 0.7;
        stiffness = 1300;
        epsilon = 0.001;
      };
    };
    "exit-confirmation-open-close" = {
      spring = {
        dampingRatio = 0.75;
        stiffness = 900;
        epsilon = 0.01;
      };
    };
    "screenshot-ui-open" = {
      durationMs = 110;
      curve = "ease-out-quad";
    };
    "overview-open-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1250;
        epsilon = 0.0001;
      };
    };
    "recent-windows-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 1200;
        epsilon = 0.001;
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
    "window-resize" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 740;
        epsilon = 0.0001;
      };
    };
    "config-notification-open-close" = {
      spring = {
        dampingRatio = 0.6;
        stiffness = 900;
        epsilon = 0.001;
      };
    };
    "exit-confirmation-open-close" = {
      spring = {
        dampingRatio = 0.6;
        stiffness = 480;
        epsilon = 0.01;
      };
    };
    "screenshot-ui-open" = {
      durationMs = 180;
      curve = "ease-out-quad";
    };
    "overview-open-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 760;
        epsilon = 0.0001;
      };
    };
    "recent-windows-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 760;
        epsilon = 0.001;
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
    "window-resize" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 580;
        epsilon = 0.0001;
      };
    };
    "config-notification-open-close" = {
      spring = {
        dampingRatio = 0.55;
        stiffness = 750;
        epsilon = 0.001;
      };
    };
    "exit-confirmation-open-close" = {
      spring = {
        dampingRatio = 0.55;
        stiffness = 400;
        epsilon = 0.01;
      };
    };
    "screenshot-ui-open" = {
      durationMs = 240;
      curve = "ease-out-quad";
    };
    "overview-open-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 600;
        epsilon = 0.0001;
      };
    };
    "recent-windows-close" = {
      spring = {
        dampingRatio = 1.0;
        stiffness = 600;
        epsilon = 0.001;
      };
    };
  };
}
