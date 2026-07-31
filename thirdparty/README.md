# Third Party Dependencies

This folder contains third-party binaries bundled with Project Indie.

## OmniSave

**Source**: https://github.com/abduznik/OmniSave
**License**: MIT

OmniSave is a lightweight portable game save synchronization tool. It handles the Sync-Launch-Sync lifecycle:
1. Copies saves from portable drive to local system path
2. Launches the game
3. Waits for game exit
4. Copies saves back to portable drive

### Usage
- `OmniSave.exe` is copied to each game's `.indie/` directory at launch
- Configuration is generated as `OmniSave.ini` next to the executable
- The launcher manages all OmniSave interactions automatically

### Build from Source
```bash
git clone https://github.com/abduznik/OmniSave
cd OmniSave
make clean && make
```
