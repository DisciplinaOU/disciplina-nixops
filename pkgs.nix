(import (fetchGit {
  url = https://github.com/serokell/serokell-closure;
  rev = "5ab82488518d978858a380f5d938cd520d9d50ac";
  ref = "nix-npm-buildpackage";
})).extend (import ./pkgs)
