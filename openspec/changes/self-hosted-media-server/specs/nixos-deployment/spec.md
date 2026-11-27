## ADDED Requirements

### Requirement: The whole server is described by a version-controlled flake
The entire machine configuration SHALL be expressed as a NixOS flake in a public git repository, such that a reinstall from scratch reproduces the same system.

#### Scenario: Fresh install from the installer
- **WHEN** the operator boots the NixOS installer and runs the documented install command against the repository
- **THEN** disks SHALL be partitioned and formatted declaratively
- **AND** the resulting system SHALL boot headless with all services enabled

#### Scenario: Configuration changes are reviewable
- **WHEN** any host-level setting changes (users, firewall, services, timers, storage)
- **THEN** that change SHALL be represented as a commit in the repository
- **AND** no host configuration SHALL exist only on the machine

### Requirement: Operator-tunable values live in one file
All values an operator is expected to change SHALL be collected in a single settings file, so routine changes do not require editing module internals.

#### Scenario: Changing a tunable value
- **WHEN** the operator changes the hostname, static IP, timezone, SSH public key, target disk, media path, or subtitle languages
- **THEN** that change SHALL require editing only the settings file

### Requirement: The server updates itself from git
The server SHALL periodically fetch the repository and rebuild itself without operator interaction.

#### Scenario: Scheduled update
- **WHEN** the scheduled upgrade timer fires
- **THEN** the system SHALL build the flake from the configured git URL and activate the result
- **AND** SHALL NOT reboot unless the operator has enabled that behaviour

#### Scenario: Manual update on demand
- **WHEN** the operator runs the documented update command over SSH
- **THEN** the system SHALL rebuild and switch immediately

#### Scenario: Recovering from a bad update
- **WHEN** an update produces a broken system
- **THEN** the previous generation SHALL remain selectable at boot
- **AND** the operator SHALL be able to roll back with a single documented command

### Requirement: The public repository contains no secrets
Because the repository is public, it SHALL NOT contain passwords, password hashes, private keys, or API tokens.

#### Scenario: Secret material is supplied out of band
- **WHEN** a service requires a credential
- **THEN** the configuration SHALL reference a path on the server outside the repository
- **AND** the checklist SHALL document how to create that file

### Requirement: Remote access is restricted to the local network
The server SHALL be reachable only from the local network, over SSH with public-key authentication.

#### Scenario: SSH hardening
- **WHEN** the system is running
- **THEN** SSH SHALL accept public-key authentication only
- **AND** password authentication and direct root login SHALL be disabled

#### Scenario: Firewall exposure
- **WHEN** the firewall is active
- **THEN** only SSH, the media server HTTP port, the uploader port, and Samba SHALL be open

### Requirement: Disk usage stays bounded
Since media and the operating system share one disk, the system SHALL limit the space consumed by system generations.

#### Scenario: Automatic garbage collection
- **WHEN** the garbage-collection timer runs
- **THEN** store paths older than the configured retention SHALL be deleted
- **AND** the number of boot entries SHALL be capped
