{ nixops, openssh }:

nixops.overrideAttrs (super: {
  src = fetchGit {
    url = https://github.com/serokell/nixops;
    rev = "4f9e4d2d574a832b4e81a7c95d9c9cb1c7b0dffb";
  };

  postPatch = ''
    for f in scripts/nixops setup.py; do
      substituteInPlace $f --subst-var-by version ${super.version}
    done

    rm -r doc/manual
  '';

  postInstall = ''
    mkdir -p $out/share/nix
    cp -r nix $out/share/nix/nixops

    wrapProgram $out/bin/nixops --prefix PATH : ${openssh}/bin
  '';
})
