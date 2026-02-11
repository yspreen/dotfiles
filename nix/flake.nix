{
  description = "spreen nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs = inputs@{
    self,
    nix-darwin,
    nixpkgs,
    # home-manager,
    mac-app-util,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    homebrew-bundle,
  }:
  let
    username = "user";
    configuration = { pkgs, ... }: let
      # Get the directory containing this flake
      flakeDir = builtins.dirOf __curPos.file;
    in {
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [
          pkgs.bun
          pkgs.ffmpeg
          pkgs.git
          pkgs.gnupg
          pkgs.postgresql_16
          pkgs.rustup
          pkgs.fnm
          pkgs.pnpm
          pkgs.stow
          pkgs.lazygit
          pkgs.zoom-us
          pkgs.cocoapods
          pkgs.fastlane
          pkgs.uv
          pkgs.go
          pkgs.fd
          pkgs.ripgrep
          pkgs.keka
        ];

      fonts.packages = [
        pkgs.fira-code
        pkgs.nerd-fonts.fira-code
        pkgs.inter
        pkgs.dm-sans
        pkgs.martian-mono
        pkgs.montserrat
        pkgs.geist-font
        pkgs.roboto-mono
        (pkgs.callPackage "${flakeDir}/font/figtree.nix" { }).out
      ];

      system.defaults = {
        dock.autohide = true;
        dock.orientation = "bottom";
        dock.persistent-apps = [];
        dock.autohide-time-modifier = 0.15;
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.NSWindowResizeTime = 0.001;
        NSGlobalDomain.AppleICUForce24HourTime = false;
        NSGlobalDomain.AppleTemperatureUnit = "Fahrenheit";
        NSGlobalDomain._HIHideMenuBar = false;
        NSGlobalDomain.AppleInterfaceStyleSwitchesAutomatically = true;
        NSGlobalDomain.AppleShowScrollBars = "Automatic";
        controlcenter.BatteryShowPercentage = false;
      };

      system.defaults.CustomUserPreferences = {
        # 1. Tell Siri to use the “SAE”-style custom hot-key
        "com.apple.Siri" = {
          CustomizedKeyboardShortcutSAE = {
            enabled = true;
            value = {
              parameters = [ 109 46 1966080 ];  # ascii 109 (‘m’), key-code 46, ⌃⌥⇧⌘ mask
              type       = "SAE1.0";
            };
          };
        };

        # Sets Downloads folder with fan view in Dock
        "com.apple.dock" = {
          persistent-others = [
            {
              "tile-data" = {
                "file-data" = {
                  "_CFURLString" = "/Users/${username}/Downloads";
                  "_CFURLStringType" = 0;
                };
                "arrangement" = 2;  # sorting order
                "displayas" = 1;    # 1 for fan display
                "showas" = 1;       # 1 for stack view
              };
              "tile-type" = "directory-tile";
            }
            {
              "tile-data" = {
                "file-data" = {
                  "_CFURLString" = "/Users/${username}/Desktop";
                  "_CFURLStringType" = 0;
                };
                "arrangement" = 2;  # sorting order
                "displayas" = 1;    # 1 for fan display
                "showas" = 1;       # 1 for stack view
              };
              "tile-type" = "directory-tile";
            }
          ];
        };

        "com.apple.QuickTimePlayerX" = {
          NSUserKeyEquivalents = {
            "New Audio Recording" = "@N";  # ⌘N
          };
        };

        NSGlobalDomain = {
          NSUserKeyEquivalents = {
            "Close Other Tabs" = "@~T";  # ⌘⌥T
          };
        };


        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # Disable 'Cmd + Space' for Spotlight Search
            "64" = {
              enabled = true;
            };
            # Disable 'Ctrl + Space'
            "60" = {
              enabled = false;
            };
            "65" = {
              enabled = true;
            };
            # DnD
            "175" = {
              enabled = true;
              value = {
                parameters = [
                  65535
                  79
                  8388608
                ];
                type = "standard";
              };
            };
            # siri
            "176" = {
              enabled = true;
              value = {
                type = "standard";
                parameters = [
                  109
                  46
                  1966080
                ];
              };
            };
          };
        };
      };

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      programs.zsh.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Set the primary user for user-specific options
      system.primaryUser = username;

      system.activationScripts.postActivation.text = ''
        sudo -u ${username} bash -c "cd /Users/${username}/dotfiles/scripts; ./post-activation.sh ${username}"
      '';

      homebrew = {
        enable = true;
        user = username;
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        onActivation.upgrade = true;
        brews = [
          "coreutils"
          "bat"
          "carthage"
          # "fontconfig"
          # "freetype"
          # "cmake"
          # "eksctl"
          "exiftool"
          "git-lfs"
          "imagemagick"
          # "go"
          "grep"
          "jq"
          # "helm"
          "mint"
          "mkcert"
          # "node"
          # "pandoc"
          "protobuf"
          "python"
          "redis"
          "sqlite"
          "wget"
          "cargo-lambda"
          "zig" # for cargo lambda
          "mas"
          "claude-code"
          "rudrankriyam/tap/asc"
          "openjdk@17"
        ];
        casks = [
          "hiddenbar"
          "orbstack"
          "aerospace"
          "hammerspoon"
          # "firefox"
          "iina"
          # "google-cloud-sdk"
          # "inkscape"
          # "macfuse"
          # "mitmproxy" # I don't know why I had this one twice. once in the brews and once in the casks
          "ngrok"
          # "openscad"
          "cloudflare-warp"
          "adguard"
          "visual-studio-code"
          "sf-symbols"
          "ukelele"
          "karabiner-elements"
          "fork"
          "raycast"
          "github-copilot-for-xcode"
          "zed"
          "slack"
          "spotify"
          "obs"
          "calendr"
          "codexbar"
          "ghostty"
        ];
        taps = [
          "nikitabobko/tap" # aerospace
          "cargo-lambda/cargo-lambda"
          "pakerwreah/calendr"
          "steipete/tap"
          "rudrankriyam/tap"
        ];

        # put casks in ~/Applications so updates don't prompt for admin
        caskArgs = { appdir = "~/Applications"; };

        masApps = {
          # AdGuardForSafari = 1440147259; # replaced by adguard brew package
          Amphetamine = 937984704;
          Tailscale = 1475387142;
          JsonPeep = 1458969831;
          WhatsApp = 310633997;
          VpnUnlimited = 694633015;
          TestFlight = 899247664;
          UnlimitedClipboardHistory = 6705136056;
          Telegram = 747648890;
          Unblocked = 6736508661;
        };
      };
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#spreen
    darwinConfigurations."spreen" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration


        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;

            # User owning the Homebrew prefix
            user = username;
          };
        }

        mac-app-util.darwinModules.default

        # # And if you also use home manager:
        # home-manager.darwinModules.home-manager
        # (
        #   { pkgs, config, inputs, ... }:
        #   {
        #     # To enable it for all users:
        #     home-manager.sharedModules = [
        #       mac-app-util.homeManagerModules.default
        #     ];

        #     # Or to enable it for a single user only:
        #     home-manager.users.foobar.imports = [
        #       #...
        #       mac-app-util.homeManagerModules.default
        #     ];
        #   }
        # )
      ];
    };
  };
}
