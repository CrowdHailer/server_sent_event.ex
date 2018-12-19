# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.4.7](https://github.com/CrowdHailer/server_sent_event.ex/tree/0.4.7) - 2018-12-19

### Fixed

- Slow event parsing on inputs containing many new line characters

## [0.4.6](https://github.com/CrowdHailer/server_sent_event.ex/tree/0.4.6) - 2018-11-09

### Fixed

- Response heads split over multiple packets are handled correcly by `ServerSentEvent.Client`

## [0.4.5](https://github.com/CrowdHailer/server_sent_event.ex/tree/0.4.5) - 2018-11-02

### Added

- Support for [Raxx 0.17.x](https://hex.pm/packages/raxx/0.17.0)

## [0.4.4](https://github.com/CrowdHailer/server_sent_event.ex/tree/0.4.4) - 2018-10-21

### Fixed

- Call to `set_active/1` failing no longer crashes client.

## [0.4.3](https://github.com/CrowdHailer/server_sent_event.ex/tree/0.4.3) - 2018-10-12

### Fixed

- `ServerSentEvent.Client` now processes events that are received as part of first received packet.
- `ServerSentEvent.Client` clears buffers in response to a disconnect.
