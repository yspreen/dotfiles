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
    username = let val = builtins.getEnv "USER"; in if val == "" then "user" else val;
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
          pkgs.zed-editor
          pkgs.spotify
        ];

      fonts.packages = [
        pkgs.fira-code
        pkgs.nerd-fonts.fira-code
        pkgs.inter
        pkgs.dm-sans
        pkgs.martian-mono
        pkgs.montserrat
        pkgs.geist-font
        (pkgs.callPackage "/Users/${username}/dotfiles/nix/font/figtree.nix" { }).out
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
        controlcenter.BatteryShowPercentage = true;
      };

      system.defaults.CustomUserPreferences = {
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

        NSGlobalDomain = {
          NSUserKeyEquivalents = {
            "Close Other Tabs" = "@~T";  # ⌘⌥T
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

      environment.launchAgents = {
        sketchybar = {
          enable = true;
          target = "homebrew.mxcl.sketchybar.plist";
          text = ''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
		<key>LANG</key>
		<string>en_US.UTF-8</string>
		<key>PATH</key>
		<string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin</string>
	</dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>homebrew.mxcl.sketchybar</string>
	<key>LimitLoadToSessionType</key>
	<array>
		<string>Aqua</string>
		<string>Background</string>
		<string>LoginWindow</string>
		<string>StandardIO</string>
		<string>System</string>
	</array>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>ProgramArguments</key>
	<array>
		<string>/opt/homebrew/opt/sketchybar/bin/sketchybar</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>/opt/homebrew/var/log/sketchybar/sketchybar.err.log</string>
	<key>StandardOutPath</key>
	<string>/opt/homebrew/var/log/sketchybar/sketchybar.out.log</string>
</dict>
</plist>
          '';
        };
      };



      system.activationScripts.postActivation.text = ''
        # Load the service
        sudo -u ${username} /bin/launchctl load -w /Library/LaunchAgents/homebrew.mxcl.sketchybar.plist 2>/dev/null;
        sudo -u ${username} bash -c "cd /Users/${username}/dotfiles; stow --adopt ."
      '';

      homebrew = {
        enable = true;
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        onActivation.upgrade = true;
        brews = [
          "bat"
          "awscli"
          "carthage"
          # "fontconfig"
          # "freetype"
          "doppler"
          # "cmake"
          # "eksctl"
          "exiftool"
          "fastlane"
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
          "sketchybar"
          "sqlite"
          "wget"
        ];
        casks = [
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
          "xcodes"
          "ukelele"
          "karabiner-elements"
        ];
        taps = [
          "dopplerhq/cli"
          "nikitabobko/tap" # aerospace
        ];
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
