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
        })
      ];
    })
  ];
}
