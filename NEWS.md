# NEWS

## Development version

### Performance

* Validation of large files (≈400 KB, ≈8500 lines) completes in approximately half the time required by the legacy DOS Proofer.

### Interface

* Added bilingual validation messages (English/Spanish).
* Added colour-coded status messages:

  * green when no issues are detected;
  * red when issues are present.
* Hidden the issues table and diagnostic preview when validation succeeds.
* Added an `About` tab with credits, acknowledgements, links and project philosophy.
* Added a progress bar during validation to provide feedback when processing large files.

### Technical checks

* Added detection of Unicode combining diacritics to discourage manually composed characters and favour precomposed Unicode forms.
* Added support for pilcrow characters (`¶`, `¶2`, `¶3`) as Unicode equivalents of the traditional HSMS symbols (`%`, `%2`, `%3`).
* Added support for inserted pilcrow forms (`[¶]`, `[^¶]`, `[¶2]`, `[^¶2]`, `[¶3]`, `[^¶3]`).
* Obsoleted `check_para_spacing()`, whose functionality has been absorbed into `check_percent_spacing()`.

### Structural checks

* Added validation of crosshatch markers (`#`) in non-original hands and reconstructions.
* Added validation of backslashes used for old foliation.
* Extended backslash validation to allow `\` inside `{HD. ...}`, `{HD1. ...}` and `{HD2. ...}`.
* Added validation of the position of the backslash within heading mnemonics.
* Added validation of calderon spacing based on complete tokens rather than isolated `%` symbols.
* Added validation of combined deletion–insertion structures `(x)[y]`.

### RMK

* Relaxed punctuation rules inside `{RMK: ... .}` to allow common abbreviations such as `s.l.` and `s.n.` and identification remarks of the form `HSMS-xxxx-yyyy: ...`.
* Improved handling of initial RMK blocks before the first folio.

### Project

* Created GitHub repository.
* Added MIT license.
* Added project documentation and acknowledgements.
* Adopted the motto:

  *Proofer points; the editor decides.*

  *Proofer señala; el editor decide.*
