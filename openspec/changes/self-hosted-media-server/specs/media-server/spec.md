## ADDED Requirements

### Requirement: The media server streams the personal movie library over the LAN
A media server SHALL serve the local movie library over HTTP to browsers, mobile apps, and the projector's Android TV client.

#### Scenario: Library is browsable
- **WHEN** a client connects to the media server on the local network
- **THEN** movies found under the configured media path SHALL be listed with metadata

#### Scenario: Casting to the projector
- **WHEN** the operator plays a movie from a phone and casts it
- **THEN** the projector SHALL play the movie
- **AND** the operator checklist SHALL note that subtitles rendered on the projector are NOT visible to the browser extension

### Requirement: Playback prefers direct play over transcoding
Given the server CPU cannot hardware-decode HEVC, the system SHALL be configured so that playback avoids server-side transcoding wherever the client can decode the file itself.

#### Scenario: Compatible file plays directly
- **WHEN** a client capable of decoding the movie's codecs requests playback
- **THEN** the session's play method SHALL be direct play
- **AND** no transcoding process SHALL start

#### Scenario: Subtitles are not burned in
- **WHEN** a text subtitle track is selected
- **THEN** the subtitle SHALL be delivered as a separate text stream
- **AND** SHALL NOT be burned into the video, since burn-in forces a full transcode

#### Scenario: Hardware acceleration is available as a fallback
- **WHEN** transcoding is genuinely required
- **THEN** VAAPI hardware acceleration SHALL be enabled for the formats the hardware supports
- **AND** the service user SHALL have access to the render device

### Requirement: First run is provisioned without manual clicking
A reinstall SHALL produce a usable server without the operator stepping through the setup wizard by hand.

#### Scenario: Automated provisioning
- **WHEN** the media server starts for the first time and the provisioning script runs
- **THEN** the startup wizard SHALL be completed
- **AND** an administrator account SHALL exist
- **AND** the movie library SHALL be created pointing at the configured media path
- **AND** hardware acceleration SHALL be configured

#### Scenario: Provisioning is idempotent
- **WHEN** the provisioning script runs again on an already-configured server
- **THEN** it SHALL make no changes and SHALL NOT fail

### Requirement: Client-side display settings are documented, not automated
Settings stored in the browser rather than on the server SHALL be listed in the operator checklist.

#### Scenario: Per-browser setting
- **WHEN** the operator opens the web player on a new computer or browser profile
- **THEN** the checklist SHALL instruct setting subtitle styling to `Custom`
- **AND** the system SHALL NOT attempt to set it server-side, because it is stored in browser local storage
