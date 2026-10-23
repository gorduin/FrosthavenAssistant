# X-haven mentés-végpont

A tévés app (gorduin.xhaven) ide küldi az állás biztonsági mentését.

Telepítés a tárhelyre: a mappa tartalma egy webről elérhető könyvtárba kerül
(pl. `public_html/xhaven-backup/`), mellé egy `config.php` a kulccsal
(minta: `config.sample.php`). A `data/` könyvtárat a `.htaccess` lezárja.

Az app a buildkor kapja a címet és a kulcsot:
`--dart-define-from-file=~/claude/keys/xhaven-backup.json`
