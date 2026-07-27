{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  gnutar,
  gzip,
  bubblewrap,
  codex-upstream,
}:

let
  inherit (codex-upstream) version;

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "codex-cli: unsupported system ${stdenvNoCC.hostPlatform.system}");

  # Upstream codex-cli-nix only installs the main `codex` binary from the
  # release tarball. Since 0.144, command execution also requires
  # `codex-code-mode-host` beside that binary (or CODEX_CODE_MODE_HOST_PATH).
  codeModeHostHashes = {
    "0.144.0" = {
      "x86_64-unknown-linux-musl" = "0gcr30mf1mgfwqfpiqhmvjb0qyq23vwgfgjii7s2nz4lb9fcdn96";
      "aarch64-unknown-linux-musl" = "0sniqrhxcff3rghai6nsx59fm5zil4i56hk7wiqkmhhsysamdcia";
      "x86_64-apple-darwin" = "07rdypzbqvmq9z6mx6q61jf00n4f6xyp3nj7s2f0vy9pjwfv5lkg";
      "aarch64-apple-darwin" = "0im248hb4vb7wd0k4fkg87chszsac022ijy7d49m9zmy60j2iybc";
    };
    "0.144.1" = {
      "x86_64-unknown-linux-musl" = "0pyj7lw3i0amgmfacngn0m7gcxbnsah7h74k82alda0npvqdv6hq";
      "aarch64-unknown-linux-musl" = "1rsqq0scrkc9dsfbxlffyhvisykfqkiryhb3finc6idaz56n24h6";
    };
    "0.145.0" = {
      "x86_64-unknown-linux-musl" = "0bl5j3a489n2vjagnmfvh1kvgdav1zc7phl0y7ww2363arwif8xc";
      "aarch64-unknown-linux-musl" = "0ffxyfy62yxsm52033x6x0d3i7hnnjsblba0b57r9g06f8n8dd92";
      "x86_64-apple-darwin" = "0fd9andn5lyscslwf42v1ykk753dzdjdk8lkcq908dziby9afa16";
      "aarch64-apple-darwin" = "0326d13gap30ir5xdm9cm7jl353b3wpzf7zrq6si72da6il31ybm";
    };
  };

  versionHashes =
    codeModeHostHashes.${version}
      or (throw "codex-cli: add code-mode-host hashes for version ${version}");

  hostSha256 =
    versionHashes.${platform}
      or (throw "codex-cli: missing code-mode-host hash for ${platform} @ ${version}");

  codeModeHostTarball = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${platform}.tar.gz";
    sha256 = hostSha256;
  };

  linuxRuntimePath = lib.makeBinPath (lib.optionals stdenvNoCC.isLinux [ bubblewrap ]);
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [
    gnutar
    gzip
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    # Keep the upstream binary; re-wrap so both live in this output.
    cp ${codex-upstream}/bin/codex-raw $out/bin/codex-raw
    chmod u+w,+x $out/bin/codex-raw

    tar -xzf ${codeModeHostTarball} -C $out/bin
    mv $out/bin/codex-code-mode-host-${platform} $out/bin/codex-code-mode-host
    chmod +x $out/bin/codex-code-mode-host

    makeWrapper "$out/bin/codex-raw" "$out/bin/codex" \
      --set DISABLE_AUTOUPDATER 1 \
      ${lib.optionalString stdenvNoCC.isLinux ''--prefix PATH : "${linuxRuntimePath}"''}

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI with code-mode-host companion binary";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
