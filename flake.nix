{
  description = "Opinionated shared nixos configurations";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixos-modules = {
      url = "github:NuschtOS/nixos-modules";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nixpkgs.url = "github:NuschtOS/nuschtpkgs/nixos-unstable";
    nvim = {
      url = "github:NuschtOS/nvim.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, flake-utils, nixos-modules, nixpkgs, nvim, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        # required for vscode-langservers-extracted which uses VSCodium as source
        nixpkgs.config.allowNonSource = true;
      };
      inherit (pkgs) lib;
    in {
      packages = {
        default = self.packages.${system}.shell;

        shell = pkgs.symlinkJoin {
          name = "nuschtos-shell";
          paths = [
            nixos-modules.packages.${system}.debugging
            (nvim.packages.${system}.nixvimWithOptions {
              inherit pkgs;
              options.enableMan = false;
            })

            (let
              tmuxConf = /* tmux */ ''
                set -g default-terminal "xterm-256color"
                set  -g base-index      1
                setw -g pane-base-index 1
                set -g focus-events on
                set -g mode-keys   emacs
                set -g mouse on
                set -g status-keys emacs

                setw -g aggressive-resize on
                setw -g clock-mode-style  24
                set  -s escape-time       100
                set  -g history-limit     50000

                # open new tab in PWD
                bind '"' split-window -c "#{pane_current_path}"
                bind % split-window -h -c "#{pane_current_path}"
                bind c new-window -c "#{pane_current_path}"

                # don't clear selection on copy
                bind-key -Tcopy-mode-vi MouseDragEnd1Pane send -X copy-selection-no-clear
                bind-key -Tcopy-mode-vi y send -X copy-selection-no-clear
              '';
            in pkgs.runCommand "tmux-with-config" {
              nativeBuildInputs = with pkgs; [ makeWrapper ];
            } ''
              mkdir -p $out/bin
              makeWrapper ${lib.getExe pkgs.tmux} $out/bin/tmux \
                --add-flags "-f ${pkgs.writeText "tmux.conf" tmuxConf}"
            '')

            pkgs.bashInteractive
          ];
          meta.mainProgram = "bash";
        };
      };
    });
}
