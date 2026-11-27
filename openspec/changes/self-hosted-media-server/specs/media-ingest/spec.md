## ADDED Requirements

### Requirement: Movies can be copied to the server from a desktop
The server SHALL expose the media directory as a network file share on the local network.

#### Scenario: Copying over the network share
- **WHEN** the operator connects to the share from a computer on the LAN and copies an MKV into it
- **THEN** the file SHALL appear in the media directory with ownership allowing the media server to read it
- **AND** the media server SHALL detect the new file and add it to the library

### Requirement: Movies can be uploaded from a browser
The server SHALL provide a web-based file manager for uploading media without mounting a share.

#### Scenario: Browser upload
- **WHEN** the operator opens the uploader on the LAN and uploads a file
- **THEN** the file SHALL be written into the media directory

### Requirement: New media is processed automatically
Newly added movies SHALL be picked up without operator action.

#### Scenario: Automatic processing after ingest
- **WHEN** a new movie file appears in the media directory
- **THEN** the subtitle extraction timer SHALL produce text sidecars for its embedded text subtitle tracks
- **AND** the library SHALL be refreshed so the movie becomes playable
