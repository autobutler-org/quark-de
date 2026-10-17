{
  self,
  pkgs,
  nixpkgs,
}:

let
  inherit (pkgs) lib;
  quark-de = self.packages.${pkgs.stdenv.hostPlatform.system}.quark-de;

  # Evaluate a whole system with the module on; drvPath forces every option
  # and assertion without building the system.
  system = nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.quark-de
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
        services.quark-de = {
          enable = true;
          autologin.user = "kiosk";
        };
        users.users.kiosk.isNormalUser = true;
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/null";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      }
    ];
  };
  inherit (system) config;
in
{
  inherit quark-de;

  # The wrapped launcher finds sway and its tools with nothing else on PATH;
  # only Quark and Firefox come from outside the package.
  launcher = pkgs.runCommand "quark-de-launcher-check" { } ''
    PATH= ${quark-de}/bin/quark-de --check >check.log 2>&1 || :
    cat check.log
    for want in sway foot swayidle swaylock mako wpctl wl-copy grim polkit-agent; do
      ${pkgs.gnugrep}/bin/grep -Eq "^ok +$want( |$)" check.log || { echo "quark-de --check did not find $want"; exit 1; }
    done
    if ${pkgs.gnugrep}/bin/grep -q 'share/quark-de/sway/config' check.log; then
      echo "quark-de --check did not find its installed config"; exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -qx 'Exec=${quark-de}/bin/quark-de' ${quark-de}/share/wayland-sessions/quark-de.desktop ||
      { echo "quark-de.desktop does not point at the packaged launcher"; exit 1; }
    touch $out
  '';

  module =
    assert lib.elem quark-de config.services.displayManager.sessionPackages;
    assert config.programs.sway.enable;
    assert config.services.greetd.settings.initial_session.user == "kiosk";
    assert config.services.greetd.settings.initial_session.command == lib.getExe quark-de;
    pkgs.writeText "quark-de-module-check" (
      builtins.unsafeDiscardStringContext config.system.build.toplevel.drvPath
    );
}
