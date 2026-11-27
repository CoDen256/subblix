## ADDED Requirements

### Requirement: Missing subtitles are fetched automatically
For movies lacking a usable text subtitle in the configured languages, the system SHALL attempt to download one.

#### Scenario: Scheduled fetch
- **WHEN** the subtitle fetch timer runs
- **THEN** the system SHALL search for subtitles in each configured language for movies that have none
- **AND** SHALL save any result as a `.srt` sidecar beside the movie

#### Scenario: Language preference
- **WHEN** subtitles are fetched
- **THEN** the configured languages SHALL be requested, defaulting to Norwegian, German, and English

#### Scenario: Existing subtitles are not overwritten
- **WHEN** a sidecar subtitle for a language already exists
- **THEN** the fetcher SHALL leave it untouched

### Requirement: Subtitle acquisition is declarative
Subtitle fetching SHALL be configured in the repository rather than through media-server plugin state.

#### Scenario: Configuration lives in git
- **WHEN** the operator changes subtitle languages or the fetch schedule
- **THEN** the change SHALL be a repository edit
- **AND** SHALL NOT require configuring a plugin through a web UI
