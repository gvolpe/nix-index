{ config, lib, pkgs, ... }:

let
  cfg = config.programs.nix-index-fork;
  useHomeManager = "export USE_HOME_MANAGER=true";
  useNixCommand =
    lib.optionalString cfg.enableNixCommand "export USE_NIX_COMMAND=true";

  wrapper = pkgs.callPackage ../wrapper.nix {
    nix-index = cfg.package;
    nix-index-database = cfg.database;
  };

  finalPackage = if cfg.database != null then wrapper else cfg.package;
in
{
  meta.maintainers = with lib.hm.maintainers; [ ambroisie gvolpe ];

  options.programs.nix-index-fork = with lib; {
    enable = mkEnableOption "nix-index, a file database for nixpkgs";

    package = mkOption {
      type = types.package;
      default = pkgs.nix-index;
      defaultText = literalExpression "pkgs.nix-index";
      description = "Package providing the {command}`nix-index` tool.";
    };

    enableBashIntegration = mkEnableOption "Bash integration" // {
      default = false;
    };

    enableZshIntegration = mkEnableOption "Zsh integration" // {
      default = false;
    };

    enableFishIntegration = mkEnableOption "Fish integration" // {
      default = false;
    };

    enableNixCommand = mkEnableOption "Enable Nix command suggestions (flakes)" // {
      default = false;
    };

    database = mkOption {
      type = types.package;
      defaultText = literalExpression "pkgs.nix-index-database";
      description = "The generated database, e.g. from nix-index-database";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      let
        checkOpt = name: {
          assertion = cfg.${name} -> !config.programs.command-not-found.enable;
          message = ''
            The 'programs.command-not-found.enable' option is mutually exclusive
            with the 'programs.nix-index.${name}' option.
          '';
        };
      in
      [ (checkOpt "enableBashIntegration") (checkOpt "enableZshIntegration") ];

    home.packages = [ finalPackage ];

    programs.bash.initExtra = lib.mkIf cfg.enableBashIntegration ''
      ${useHomeManager}
      ${useNixCommand}
      source ${finalPackage}/etc/profile.d/command-not-found.sh
    '';

    programs.zsh.initExtra = lib.mkIf cfg.enableZshIntegration ''
      ${useHomeManager}
      ${useNixCommand}
      source ${finalPackage}/etc/profile.d/command-not-found.sh
    '';

    # See https://github.com/bennofs/nix-index/issues/126
    programs.fish.interactiveShellInit =
      let
        wrapper = pkgs.writeScript "command-not-found" ''
          #!${pkgs.bash}/bin/bash
          ${useHomeManager}
          ${useNixCommand}
          source ${finalPackage}/etc/profile.d/command-not-found.sh
          command_not_found_handle "$@"
        '';
      in
      lib.mkIf cfg.enableFishIntegration ''
        function __fish_command_not_found_handler --on-event fish_command_not_found
            ${wrapper} $argv
        end
      '';
  };
}
