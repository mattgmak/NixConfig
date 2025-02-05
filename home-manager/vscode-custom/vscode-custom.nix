{ ... }:
let
in {
  home.file = {
    ".vscode-custom/vscode.js".source = ./vscode.js;
    ".vscode-custom/vscode.css".source = ./vscode.css;
  };
}
