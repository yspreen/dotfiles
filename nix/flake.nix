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
    configuration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [
          pkgs.vim
          pkgs.bun
          pkgs.ffmpeg
          pkgs.git
          pkgs.gnupg
          pkgs.postgresql_16
          pkgs.rustup
          pkgs.fnm
          pkgs.pnpm
        ];

      fonts.packages = [
        # pkgs.fira-code
        pkgs.nerd-fonts.fira-code
      ];

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

      homebrew = {
        enable = true;
        onActivation.cleanup = "zap";
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
          "flyctl"
          "git-lfs"
          "imagemagick"
          # "go"
          "grep"
          "jq"
          # "helm"
          "mint"
          "mkcert"
          # "mosh"
          "neofetch"
          # "nginx"
          # "node"
          # "pandoc"
          "protobuf"
          "python"
          "redis"
          "rsync"
          "sketchybar"
          "sqlite"
          "telnet"
          "terraform"
          "wget"
          "mas"
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
        ];
        taps = [
          "dopplerhq/cli"
          "nikitabobko/tap"
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
            user = "user";

            # Automatically migrate existing Homebrew installations
            autoMigrate = true;
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
