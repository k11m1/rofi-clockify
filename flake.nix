{
  description = "Rofi-based Clockify TUI using clockify-cli";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    clockify-cli-flake = {
      url = "github:k11m1/clockify-cli-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, clockify-cli-flake }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      # Perl dependencies
      perlPackages = with pkgs.perlPackages; [
        DBI
        DBDSQLite
        JSON
        GetoptLong
      ];

      rofi-clockify = pkgs.stdenv.mkDerivation {
        pname = "rofi-clockify";
        version = "0.1.0";

        src = ./.;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        buildInputs = [ pkgs.perl ] ++ perlPackages;

        installPhase = ''
          mkdir -p $out/bin
          cp main.pl $out/bin/rofi-clockify
          chmod +x $out/bin/rofi-clockify

          wrapProgram $out/bin/rofi-clockify \
            --prefix PATH : ${pkgs.lib.makeBinPath [ 
              clockify-cli-flake.packages.${system}.default
              pkgs.rofi
              pkgs.libnotify
            ]} \
            --prefix PERL5LIB : "${pkgs.perlPackages.makePerlPath perlPackages}"
        '';

        meta = with pkgs.lib; {
          description = "Access Clockify via Rofi using clockify-cli";
          homepage = "https://github.com/k11m1/rofi-clockify";
          license = licenses.mit;
          platforms = platforms.linux;
        };
      };

    in {
      packages.${system} = {
        default = rofi-clockify;
        rofi-clockify = rofi-clockify;
      };

      defaultPackage.${system} = rofi-clockify;

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.perl
          pkgs.rofi
          clockify-cli-flake.packages.${system}.default
        ] ++ perlPackages;

        shellHook = ''
          echo "🕐 Rofi-Clockify development environment"
          echo "Run './main.pl init' to initialize the database"
          echo "Run './main.pl start' to start time tracking"
        '';
      };
    };
}
