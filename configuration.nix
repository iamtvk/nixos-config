{ config, libs, pkgs, ... }:
  let restartTrackpadScript = pkgs.writeShellScript "restart-i2c" ''
	#!/bin/sh
	  echo "[TrackpadFix] Running restart script..." >> /var/log/trackpad.log
	  /run/current-system/sw/bin/rmmod i2c_hid_acpi
	  /run/current-system/sw/bin/modprobe i2c_hid_acpi
	  '';
  in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./vm.nix
    ];

  systemd.services.restart-trackpad = {
	  description = "Reset i2c_hid_acpi after resume from sleep/hibernate";
	  wantedBy = [ "sleep.target" ];
	  after = [ "sleep.target" ];
	  serviceConfig = {
		  Type = "oneshot";
		  ExecStart = restartTrackpadScript;
	  };
  };
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # VanishCam: virtual webcam Teams can use (loaded on boot)
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="VanishCam" exclusive_caps=1
  '';

  boot.kernel.sysctl = {
  	"net.ipv4.ip_unprivileged_port_start" = 80;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "stacia"; # Define your hostname.
  # networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.
  networking.extraHosts = ''
  	192.168.1.69 snapperoffice50
	127.0.0.1 local.zimble.io
	127.0.0.1 local.mst.com
	127.0.0.1 admin.mst.com
 
 '';

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable Docker
  virtualisation.docker = {
	  enable = true;
	  daemon.settings = {
	      dns = [ "127.0.0.53" ];
	  };

	  rootless = {
		  enable = true;
		  setSocketVariable = true;
	  };
  };

  systemd.services.docker.environment = {
	  DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER = "builtin";
  };
  systemd.services."systemd-suspend".enable = false;
  systemd.services."systemd-hybrid-sleep".enable = false;


  # Enable networking.
  networking.networkmanager = {
  	enable = true;
	plugins = with pkgs; [
		networkmanager-openvpn
	];
  };

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IN";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable thermald
  services.thermald.enable = true;

  # restart trackpad service
  # systemd.services.restart-trackpad = {
  #  description = "Reset i2c_hid_acpi after resume from hibernate";
  #  wantedBy = [ "sleep.target" "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
  #  after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
  #  serviceConfig = {
  #    Type = "oneshot";
  #    ExecStart = "/run/current-system/sw/bin/sh -c 'rmmod i2c_hid_acpi && modprobe i2c_hid_acpi'";
#  };
# };

system.autoUpgrade = {
  enable = true;
  # Fetch from GitHub — works for root's anonymous fetch, avoids the
  # local-repo ownership error that broke upgrades since July.
  flake = "github:iamtvk/nixos-config#stacia";
  # --update-input refreshes the nixpkgs lock on each run
  # (deprecated alias, but required to keep the lock moving).
  flags = [ "--update-input" "nixpkgs" "-L" ];
  dates = "19:00";
  randomizedDelaySec = "45min";
  allowReboot = false;
# Add this line so missed updates run when the laptop wakes up
  persistent = true;
};

  nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
  };

# Configure keymap in X11
  services.xserver = {
	  layout = "us";
	  xkbVariant = "";
  };

  services.keyd = {
    enable = true;
    };

  # services.logind = {
  #   lidSwitch = "ignore";
  #   };
  # services.logind.extraConfig = '' HandlePowerKey=ignore '';

  services.logind.settings = {
   Login = {
    HandlePowerKey = "ignore";
    IdleAction = "suspend";
    lidSwitch = "ignore";
    # add other options here
   };
  };


  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable blueman bluetooth manager
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;

  hardware.opengl = {
	  enable = true;
  };

# # Ensure proper graphics drivers for Intel
#   hardware.opengl.extraPackages = with pkgs; [
# 	  intel-media-driver  # For newer Intel GPUs (recommended for 12th gen)
# 		  vaapiIntel         # Alternative/fallback
# 		  intel-compute-runtime  # For OpenCL
#   ];
#
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [
    intel-media-driver      # Best for 6th gen and newer (your 12th gen)
    intel-vaapi-driver      # Legacy fallback (replaces old vaapiIntel)
    libvdpau-va-gl          # Optional: VDPAU support
  ];
};

# Recommended for modern Intel GPUs
environment.sessionVariables = {
  LIBVA_DRIVER_NAME = "iHD";   # Use the modern driver
};

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
   services.pipewire = {
     enable = true;
     alsa.enable = true;
     alsa.support32Bit = true;
     pulse.enable = true;
     # If you want to use JACK applications, uncomment this
     jack.enable = true;

  #   # use the example session manager (no others are packaged yet so this is enabled by default,
  #   # no need to redefine it in your config for now)
  #   #media-session.enable = true;
   };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.childe = {
    isNormalUser = true;
    description = "childe";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      firefox
    # thunderbird
    ];
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  



  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
# Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
	  cmake
	  meson
	  ninja
	  cpio
	  pkg-config
	  openvpn3
	  strongswanNM
	  mesa
	  libGL
  wayland-protocols
  wayland-scanner
  libGLU
  udis86
    wayland
    libxkbcommon
    wget
    home-manager
    git
    lm_sensors
    gccgo13
    gh
    hyprlock
    hyprland
    alacritty
    cloudflare-warp
    kitty
    libreoffice-fresh
    clipman
    bat
    ripgrep-all
    htop
    swayimg
    bottom
    jq
    wlogout
    pavucontrol
    pamixer
    networkmanagerapplet
    dunst
    zathura
    tmux
    starship
    libnotify
    waybar
    dejavu_fonts
    yazi
    swaybg
    killall
    hyprpicker
    wofi
    wlr-randr
    vimPlugins.meson
    keyd
    mpv
    brave
    courier-prime
    google-chrome
    swayidle
    grim
    slurp
    man-pages
    man-pages-posix
    linux-manual
    brightnessctl
    udiskie
    wl-clipboard
    fzf
    hyprpaper

  ];

  programs.neovim = {
  	enable = true;
	defaultEditor = true;
  };
  
  documentation = {
  	dev.enable = true;

  };

  programs.openvpn3.enable = true;


  #enable hyprland 
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal.enable = true;


  
  # configuration.nix



  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.power-profiles-daemon.enable = true;
 #  services.auto-cpufreq.enable = true;
 #  services.auto-cpufreq.settings = {
	# battery = {
	# 	governer = "powersave";
	# 	turbo = "auto";
	# };
	# charger = {
	# 	governer = "powersave";
	# 	turbo = "auto";
	# };
 #  };
 

#  systemd.user.services.pause-media = {
#  description = "pauses the source when sinks unplugged ";
#   serviceConfig = {
#        ExecStart = "${pkgs.playerctl}/bin/playerctl --all-players pause";
#   };
# };
#
# systemd.services.pause-media-bridge = {
#   description = "Bridge USB audio removal to user media pause";
#
#
#   serviceConfig = {
#     Type = "oneshot";
#     User = "childe";
#
#     # systemd needs to know where the user bus lives
#     Environment = "XDG_RUNTIME_DIR=/run/user/1000";
#
#     ExecStart = "/run/current-system/sw/bin/systemctl --user start pause-media.service";
#   };
# };
#
#
#   SUBSYSTEM=="usb", \
#   DEVTYPE=="usb_device", \
#   ENV{ID_USB_INTERFACES}=="*:01*", \
#   TAG+="systemd", \
#   ENV{SYSTEMD_WANTS}="pause-media-bridge.service"
# '';





  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true; # opens port 22
    settings = {
      PermitRootLogin = "no";
      AllowUsers = [ "childe" ];
      # Key-only login.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Allowed client keys live in ~/.ssh/authorized_keys (not in this public repo).

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.enable = true;


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}

