{ nixops, openssh }:

nixops.overrideAttrs (super: {
  src = fetchGit {
    url = https://github.com/serokell/nixops;
    rev = "0636c7ecc844edf06f9ef553d9c3a39288264bf3";
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
