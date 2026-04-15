```ruby
██╗  ██╗███████╗██╗   ██╗██╗      ██████╗  ██████╗  ██████╗ ███████╗██████╗
██║ ██╔╝██╔════╝╚██╗ ██╔╝██║     ██╔═══██╗██╔════╝ ██╔════╝ ██╔════╝██╔══██╗
█████╔╝ █████╗   ╚████╔╝ ██║     ██║   ██║██║  ███╗██║  ███╗█████╗  ██████╔╝
██╔═██╗ ██╔══╝    ╚██╔╝  ██║     ██║   ██║██║   ██║██║   ██║██╔══╝  ██╔══██╗
██║  ██╗███████╗   ██║   ███████╗╚██████╔╝╚██████╔╝╚██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝
```

[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Educational](https://img.shields.io/badge/Purpose-Educational_Only-red?style=flat)](/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue?style=flat)](/)

> Educational keylogger for security research demonstrating input capture, window tracking, and C2 delivery techniques.

*This is a quick overview — security theory, architecture, and full walkthroughs are in the [learn modules](#learn).*

---

## ⚠️ Disclaimer

**This project is strictly for educational purposes and authorized security research only.**

Unauthorized use of keyloggers is **illegal** and may violate federal and state laws, including the Computer Fraud and Abuse Act (CFAA). Always obtain **explicit written consent** before monitoring any system you do not own. The author is not responsible for misuse of this software.

---

## What It Does

- Real-time keyboard event capture with microsecond-precision timestamps
- Active window tracking across Windows, macOS, and Linux
- Log rotation with configurable size limits (default 5MB)
- F9 toggle control to pause and resume capture at runtime
- Remote delivery simulation via webhooks for C2 research
- Thread-safe operations with proper resource locking and cleanup

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/deepmaha2006/KeyLogger.git
cd KeyLogger

# Install dependencies
pip install -r requirements.txt

# Run the keylogger
python keylogger.py
```

Press **F9** to toggle capture on/off. Press **Ctrl+C** to stop.

Logs are saved to `~/.keylogger_logs/` by default.

---

## Project Structure

```
KeyLogger/
├── keylogger.py          # Main implementation (~300 lines)
├── test_keylogger.py     # Pytest test suite
├── requirements.txt      # Python dependencies
├── .gitignore            # Git ignore rules
├── README.md             # This file
└── learn/                # Step-by-step learning modules
    ├── 00-OVERVIEW.md    # Prerequisites and quick start
    ├── 01-CONCEPTS.md    # Security theory and real-world breaches
    ├── 02-ARCHITECTURE.md # System design and data flow
    ├── 03-IMPLEMENTATION.md # Code walkthrough
    └── 04-CHALLENGES.md  # Extension ideas and exercises
```

---

## Configuration

You can customize the keylogger by modifying `KeyloggerConfig` in `keylogger.py`:

```python
config = KeyloggerConfig(
    log_dir=Path.home() / ".keylogger_logs",  # Where logs are saved
    max_log_size_mb=5.0,                       # Max log file size before rotation
    webhook_url=None,                          # Optional C2 webhook URL
    webhook_batch_size=50,                     # Events to batch before sending
    toggle_key=Key.f9,                         # Key to pause/resume logging
    enable_window_tracking=True,               # Track active window titles
    log_special_keys=True,                     # Log [ENTER], [BACKSPACE], etc.
)
```

---

## Running Tests

```bash
# Install dev dependencies
pip install pytest

# Run test suite
pytest test_keylogger.py -v
```

---

## Learn

This project includes step-by-step learning materials covering security theory, architecture, and implementation.

| Module | Topic |
|--------|-------|
| [00 - Overview](learn/00-OVERVIEW.md) | Prerequisites and quick start |
| [01 - Concepts](learn/01-CONCEPTS.md) | Security theory and real-world breaches |
| [02 - Architecture](learn/02-ARCHITECTURE.md) | System design and data flow |
| [03 - Implementation](learn/03-IMPLEMENTATION.md) | Code walkthrough |
| [04 - Challenges](learn/04-CHALLENGES.md) | Extension ideas and exercises |

---

## Key Components

| Class | Purpose |
|-------|---------|
| `Keylogger` | Main controller, coordinates all components |
| `KeyloggerConfig` | Runtime configuration dataclass |
| `KeyEvent` | Single keystroke record with metadata |
| `LogManager` | File writer with size-based rotation |
| `WebhookDelivery` | Batched HTTP exfiltration to remote endpoint |
| `WindowTracker` | Active window detection (cross-platform) |
| `KeyType` | Enum: CHAR, SPECIAL, UNKNOWN |

---

## Platform Support

| Platform | Keyboard Capture | Window Tracking |
|----------|-----------------|-----------------|
| Windows  | ✅ pynput       | ✅ win32gui + psutil |
| macOS    | ✅ pynput       | ✅ AppKit NSWorkspace |
| Linux    | ✅ pynput       | ✅ xdotool subprocess |

**Linux note:** Install xdotool for window tracking:
```bash
sudo apt-get install xdotool   # Debian/Ubuntu
sudo dnf install xdotool       # Fedora
```

---

## License

MIT License — See [LICENSE](LICENSE) for details.

---

*Built for cybersecurity education and research. Use responsibly.*
