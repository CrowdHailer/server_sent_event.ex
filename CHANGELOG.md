# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## 0.4.3](https://github.com/CrowdHailer/server_sent_event.ex/tree/0.4.3) - 2018-10-12

### Fixed

- `ServerSentEvent.Client` now processes events that are received as part of first received packet.
- `ServerSentEvent.Client` clears buffers in response to a disconnect.
