{
  lib,
  stdenvNoCC,
  makeWrapper,
  sway,
  foot,
  swayidle,
  swaylock,
  mako,
  wl-clipboard,
  cliphist,
  wofi,
  grim,
  slurp,
  jq,
  libnotify,
  dex,
  wireplumber,
  brightnessctl,
  playerctl,
  dbus,
  polkit_gnome,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
  gnutar,
  procps,
  socat,
}:

# The session's own tools go after the user's PATH (--suffix), so a sway or
# foot the system provides (programs.sway's wrapped sway, say) wins. Quark
# and Firefox are not bundled: the NixOS module and the user supply them.
let
  runtimeDeps = [
    sway
    foot
    swayidle
    swaylock
    mako
    wl-clipboard
    cliphist
    wofi
    grim
    slurp
    jq
    libnotify
    dex
    wireplumber
    brightnessctl
    playerctl
    dbus
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    gnutar
    procps
    socat
  ];
in
stdenvNoCC.mkDerivation {
  pname = "quark-de";
  version = "0-unstable";

  src = lib.cleanSource ../..;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    make install PREFIX=$out WAYLAND_SESSIONS=$out/share/wayland-sessions
    runHook postInstall
  '';

  # sway runs the quark-de-* helpers by name, so $out/bin leads PATH.
  # quark-de-polkit looks the agent up on PATH; polkit-gnome keeps it in libexec.
  postFixup = ''
    for bin in $out/bin/quark-de $out/bin/quark-de-*; do
      wrapProgram "$bin" \
        --prefix PATH : $out/bin \
        --suffix PATH : ${lib.makeBinPath runtimeDeps}:${polkit_gnome}/libexec
    done
  '';

  passthru.providedSessions = [ "quark-de" ];

  meta = {
    description = "Wayland desktop session where the Quark app is the desktop";
    homepage = "https://github.com/autobutler-org/quark-de";
    license = lib.licenses.mit0;
    mainProgram = "quark-de";
    platforms = lib.platforms.linux;
  };
}
