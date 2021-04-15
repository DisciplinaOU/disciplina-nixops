{ nixops, openssh, fetchFromGitHub }:

nixops.overrideAttrs (super: {
  src = fetchFromGitHub {
    owner = "serokell";
    repo = "nixops";
    rev = "4f9e4d2d574a832b4e81a7c95d9c9cb1c7b0dffb";
    sha256 = "0gnb4y9jaaxz9jyrvn3m5ns4av7i7wgy01jg2kbrgp1vsn88mw8y";
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
