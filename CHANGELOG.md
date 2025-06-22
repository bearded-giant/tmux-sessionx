# Changelog

## [Unreleased]

### Fixed
- Fixed session selection not working due to incorrect fzf binding and variable scope issues
- Fixed session deletion (ctrl-k) not executing due to complex command escaping
- Fixed UI not refreshing after session deletion
- Fixed session name parsing with new timestamp delimiter format

### Added
- Helper scripts for cleaner command execution:
  - `scripts/kill-session.sh` - Handles session deletion with proper debugging
  - `scripts/reload-sessions.sh` - Refreshes session list after operations
- Comprehensive test suite for session deletion and UI refresh
- Debug mode now logs key binding creation and execution

### Changed
- Simplified complex shell command escaping by using helper scripts
- Improved whitespace handling in session name extraction
- Updated default scroll down binding from ctrl-d to ctrl-f to avoid conflicts