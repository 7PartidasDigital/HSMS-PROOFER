# NEWS

## Development version

### Performance

* Preliminary tests suggest that HSMS Proofer processes large transcriptions efficiently when compared with the legacy DOS Proofer.

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
* Deprecated `check_para_spacing()`, whose functionality has been absorbed into `check_percent_spacing()`.
* Stopped reporting LF/CRLF/CR line endings as validation issues, since line endings depend on the user’s operating system.
* Allowed both `.` and `:` as delimiters for `{DIAG}` mnemonics, since `{DIAG: ...}` is used for descriptive comments such as `Numeric table follows.`, `scribally deleted.` or `editorially deleted.`.
* Allowed internal punctuation in `{RMK: ...}` remarks placed in the first six lines of the file, since initial remarks may contain bibliographical descriptions, shelfmarks, abbreviations and institutional names.
* Added a warning for consecutive calderon markers (`¶¶`, internally equivalent to `%%`), since they may represent either an intentional printed feature or an accidental duplication requiring editorial review.
* Standardized structural validation outputs before combining them, preventing report-generation crashes when different structural checks return issue tables with slightly different column sets.

### Structural checks

* Added validation of crosshatch markers (`#`) in non-original hands and reconstructions.
* Added validation of backslashes used for old foliation.
* Extended backslash validation to allow `\` inside `{HD. ...}`, `{HD1. ...}` and `{HD2. ...}`.
* Added validation of the position of the backslash within heading mnemonics.
* Added validation of calderon spacing based on complete tokens rather than isolated `%` symbols.
* Added validation of combined deletion–insertion structures `(x)[y]`.
* Allowed non-structural mnemonics inside scribal insertions within `{GL.}` and `{AD.}` containers.
* Kept structural mnemonics such as `{CB.}`, `{HD.}`, `{CW.}` and `{SG.}` prohibited inside such insertions.
* Added `≺` and `≻` as the current markers for real parentheses.
* Marked legacy `((` and `))` as obsolete real-parenthesis markers.
* Stopped validating spacing for legacy `((...))`, which is now kept only as a historical fossil.
* Clarified the handling of `{GL.}` and `{AD.}` insertions in container-crossing checks, avoiding false reports when non-structural internal mnemonics such as `{RMK: ...}` occur inside scribal insertions.

### RMK

* Relaxed punctuation rules inside `{RMK: ... .}` to allow common abbreviations such as `s.l.` and `s.n.` and identification remarks of the form `HSMS-xxxx-yyyy: ...`.
* Improved handling of initial RMK blocks before the first folio.
* Fixed RMK validation so that `{RMK: ...}` may be followed by another mnemonic or text on the same line, provided that the RMK token itself is properly closed and ends with a period.

### Project

* Created GitHub repository.
* Added MIT license.
* Added project documentation and acknowledgements.
* Adopted the motto:

  *Proofer points; the editor decides.*

  *Proofer señala; el editor decide.*
