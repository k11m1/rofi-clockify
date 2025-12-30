{
  description = "Rofi-based Clockify TUI using clockify-cli";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nur }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nur.overlays.default ];
      };
      
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

          # Desktop entry for application with actions (Start, Stop)
          mkdir -p $out/share/applications
          cat > $out/share/applications/rofi-clockify.desktop <<EOF
[Desktop Entry]
Name=Rofi Clockify
GenericName=Time Tracker
Comment=Track Clockify entries via Rofi
Exec=$out/bin/rofi-clockify start-dmenu
TryExec=$out/bin/rofi-clockify
Icon=clock
Terminal=false
Type=Application
Categories=Office;Utility;
Actions=Start;Stop;

[Desktop Action Start]
Name=Start via dmenu
Exec=$out/bin/rofi-clockify start-dmenu

[Desktop Action Stop]
Name=Stop current entry
Exec=$out/bin/rofi-clockify stop
EOF

	chmod +x $out/share/applications/rofi-clockify.desktop


          wrapProgram $out/bin/rofi-clockify \
            --prefix PATH : ${pkgs.lib.makeBinPath [ 
              pkgs.nur.repos.lucassabreu.clockify-cli
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
          pkgs.nur.repos.lucassabreu.clockify-cli
        ] ++ perlPackages;

        shellHook = ''
          echo "🕐 Rofi-Clockify development environment"
          echo "Run './main.pl init' to initialize the database"
          echo "Run './main.pl start' to start time tracking"
        '';
      };
    };
}
