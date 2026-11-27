## ADDED Requirements

### Requirement: Text subtitles reach the browser as DOM text
The web player SHALL render selected text subtitle tracks into a regular DOM element containing plain text, not into a `<canvas>` and not exclusively via browser-native `<track>` rendering in shadow DOM.

#### Scenario: SRT subtitle renders into the DOM
- **WHEN** a movie with a text subtitle track is played in a Chromium browser with subtitle styling set to `Custom`
- **THEN** an element matching `.videoSubtitles .videoSubtitlesInner` exists in the document
- **AND** its `textContent` equals the active subtitle line
- **AND** `document.body.innerHTML` contains that line

#### Scenario: Default styling in Chromium is documented as unsupported
- **WHEN** subtitle styling is left at the default `Auto` in a Chromium browser
- **THEN** subtitles are rendered natively and are NOT present in the DOM
- **AND** the operator checklist SHALL instruct the user to set subtitle styling to `Custom` once per browser profile

### Requirement: The subtitle element is rewritten only when the cue changes
The web player SHALL NOT rewrite the subtitle element's contents while the active cue is unchanged, so that DOM nodes injected by a browser extension survive for the lifetime of the cue.

#### Scenario: Redundant rewrites are suppressed
- **WHEN** a movie plays for 15 seconds during which the active cue changes N times
- **THEN** the number of childList mutations on the subtitle element SHALL equal N
- **AND** SHALL NOT scale with the `timeupdate` event rate

#### Scenario: Injected word spans survive a cue
- **WHEN** an extension replaces the subtitle text node with per-word `<span>` elements
- **AND** the same cue remains active for several seconds
- **THEN** those spans SHALL still be present in the document for the whole cue
- **AND** SHALL be replaced only when the cue changes

#### Scenario: Cue transitions still update correctly
- **WHEN** the active cue changes to a different cue
- **THEN** the subtitle element SHALL display the new cue's text
- **WHEN** no cue is active
- **THEN** the subtitle element SHALL be hidden

### Requirement: Image and styled subtitle formats are converted, not rendered
Formats that the web player draws to a canvas (`ass`, `ssa`) SHALL be made available as plain-text sidecar subtitles so a DOM-readable alternative always exists.

#### Scenario: ASS track gets a text sidecar
- **WHEN** a movie file contains an embedded `ass` or `ssa` subtitle track
- **THEN** the system SHALL produce a `.srt` sidecar file beside the movie for that track's language
- **AND** the sidecar SHALL be offered by the media server as a selectable external subtitle

#### Scenario: Bitmap subtitles are out of scope
- **WHEN** a movie's only subtitle track is a bitmap format such as PGS
- **THEN** the system SHALL NOT attempt OCR
- **AND** SHALL rely on subtitle acquisition to obtain a text subtitle instead
