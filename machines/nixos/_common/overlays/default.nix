{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          # Pillow 13 breaks this test's reference hash;
          # remove once nixos-26.05 contains https://github.com/NixOS/nixpkgs/pull/580486
          fpdf2 = pyprev.fpdf2.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [ "test_image_with_explicit_dimensions" ];
          });
          # Pillow 13 rejects imageio's 16-bit PNG mode;
          # remove once nixos-26.05 contains the backport of https://github.com/NixOS/nixpkgs/pull/580338
          imageio = pyprev.imageio.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_png_16bit"
              "test_png"
            ];
          });
        })
      ];
    })
  ];
}
