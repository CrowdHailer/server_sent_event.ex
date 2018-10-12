# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## client-tests

### Fixed

- `ServerSentEvent.Client` now processes events that are received as part of first received packet.
- `ServerSentEvent.Client` clears buffers in response to a disconnect.
