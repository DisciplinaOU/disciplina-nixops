{ nixops, openssh }:

nixops.overrideAttrs (super: {
  src = fetchGit {
    url = https://github.com/serokell/nixops;
    rev = "b2518d6b6656e36b4a571e41ee854ab325f4b86f";
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
