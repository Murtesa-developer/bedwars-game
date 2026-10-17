# Building BedWars for the Microsoft Store (APPX, x86, Windows 10 + 11)

1. Install the **standard** Godot 4.x editor (not the .NET build) and its export templates.
2. Install the Windows 10/11 SDK (for `makeappx.exe`).
3. Open `appx/AppxManifest.xml` and replace the two `CHANGE-ME` values (Identity Name and Publisher) with the ones from
   Partner Center > Product management > Product identity. PublisherDisplayName is already set to "murtesa developer".
4. Run in PowerShell (inside the project folder):  `.\build_appx.ps1`  (it looks for Godot itself; or give the path: `.\build_appx.ps1 -Godot "C:\path\to\Godot.exe"`)
   -> `build\BedWars_x86.appx`  (add `-SelfSign` to test-install it on your own PC first)
5. Upload `BedWars_x86.appx` in Partner Center > Packages. Store signs it for you.

Notes
- The package is 32-bit x86 and runs on 32-bit and 64-bit Windows 10 (1809+) and Windows 11.
- Keep `Version` in the manifest rising for every upload (last number must stay 0 for Store).
- Run the Windows App Certification Kit (WACK) on the .appx before submitting.
- Store listing needs its own screenshots (1366x768+) - use the in-game lobby and a match.

## Privacy policy (required by the Store)
- The full policy is shown inside the game (lobby > Privacy Policy).
- Partner Center also asks for a public URL: host `legal/privacy.html` (GitHub Pages, your site) and paste the link in Properties > Privacy policy URL.
