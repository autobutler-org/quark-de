# NixOS module: services.quark-de.enable registers the "Quark" Wayland
# session; services.quark-de.autologin.user also logs that user straight in
# through greetd.
self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.quark-de;
  tuigreet = pkgs.tuigreet or pkgs.greetd.tuigreet;
in
{
  options.services.quark-de = {
    enable = lib.mkEnableOption "the Quark DE Wayland session";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quark-de;
      defaultText = lib.literalExpression "quark-de.packages.\${system}.quark-de";
      description = "The quark-de package to use.";
    };

    autologin.user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "kiosk";
      description = ''
        Log this user into the Quark session at boot through greetd.
        After they log out, greetd shows tuigreet. Null leaves the display
        manager to you.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.sway.enable = true;
        programs.firefox.enable = lib.mkDefault true;

        environment.systemPackages = [ cfg.package ];
        services.displayManager.sessionPackages = [ cfg.package ];

        xdg.portal = {
          enable = true;
          wlr.enable = true;
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
          configPackages = [ cfg.package ];
        };
      }

      (lib.mkIf (cfg.autologin.user != null) {
        services.greetd = {
          enable = true;
          settings = {
            initial_session = {
              command = lib.getExe cfg.package;
              user = cfg.autologin.user;
            };
            default_session.command = "${lib.getExe tuigreet} --time --cmd ${lib.getExe cfg.package}";
          };
        };
      })
    ]
  );
}
