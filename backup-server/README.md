# X-haven mentés-végpont

A tévés app (gorduin.xhaven) ide küldi az állás biztonsági mentését.

Telepítés a tárhelyre: a mappa tartalma egy webről elérhető könyvtárba kerül
(pl. `public_html/xhaven-backup/`), mellé egy `config.php` a kulccsal
(minta: `config.sample.php`). A `data/` könyvtárat a `.htaccess` lezárja.

Az app a buildkor kapja a címet és a kulcsot:
`--dart-define-from-file=~/claude/keys/xhaven-backup.json`

## Éles telepítés

- Cím: https://techtanacs.hu/xhaven-backup/ (tárhely.eu, `public_html/xhaven-backup/`)
- Feltöltés SFTP-vel (parancssor nincs a fiókon): kulcs `~/.ssh/techtana_xhaven`,
  `sftp -i ~/.ssh/techtana_xhaven techtana@185.51.188.51`
- Jogosultságok: `config.php` 600, `data/` 700
- App build: `flutter build apk --release --target-platform android-arm --dart-define-from-file=/Users/hunorracz/claude/keys/xhaven-backup.json`
