# Architecture — Keylogger

This document breaks down how the system is designed and why certain architectural decisions were made.

---

## System Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Operating System                       │
│                  (Keyboard Event Stream)                  │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  pynput Listener     │
              │  (Event Callbacks)   │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │     Keylogger        │
              │   (Main Controller)  │
              └─────┬────────┬───────┘
                    │        │
        ┌───────────┘        └──────────┐
        ▼                               ▼
┌───────────────┐              ┌────────────────┐
│ WindowTracker │              │  LogManager    │
│  (Platform-   │              │ (File Writing) │
│   Specific)   │              └────────┬───────┘
└───────────────┘                       │
                                        ▼
                              ┌──────────────────┐
                              │ WebhookDelivery  │
                              │  (Exfiltration)  │
                              └──────────────────┘
```

---

## Components

### Keylogger (Main Controller)
- **Purpose**: Orchestrates all components and handles the event processing pipeline
- **Responsibilities**: Receives keyboard events from pynput, processes keys, coordinates window tracking, delegates to logging and webhook delivery
- **Interfaces**: Exposes `start()` and `stop()` methods for lifecycle management

### LogManager
- **Purpose**: Manages persistent storage of keystroke events with automatic file rotation
- **Responsibilities**: Creates timestamped log files, writes events to disk, monitors file size and rotates when limit reached, provides thread-safe access via locks
- **Interfaces**: `write_event(event)`, `get_current_log_content()`, `close()`

### WebhookDelivery
- **Purpose**: Handles remote exfiltration of captured keystrokes via HTTP webhooks
- **Responsibilities**: Buffers events to reduce network traffic, batches events before sending, delivers JSON payloads to configured endpoint
- **Interfaces**: `add_event(event)`, `flush()`

### WindowTracker
- **Purpose**: Determines which application has focus when keystrokes occur
- **Responsibilities**: Platform detection (Windows/macOS/Linux), calls platform-specific APIs to get active window title
- **Interfaces**: Static method `get_active_window()` returns current window title or None

### KeyEvent (Data Model)
- **Purpose**: Immutable representation of a single keystroke with metadata
- **Fields**: timestamp, key string, window title, key type classification
- **Interfaces**: `to_dict()` for JSON serialization, `to_log_string()` for human-readable formatting

---

## Data Flow

### Primary Use Case: Keystroke Capture and Logging

```
1. OS Keyboard Event → pynput Listener
   User presses 'a' key, OS delivers event to all registered listeners

2. Listener → Keylogger._on_press()
   Callback receives Key or KeyCode object
   Checks if it's the toggle key → pause/resume if so
   Checks if logging is active → early return if paused

3. Keylogger → WindowTracker.get_active_window()
   Calls platform-specific code to get active window
   Caches result for 0.5 seconds to avoid excessive API calls

4. Keylogger → _process_key()
   Converts Key/KeyCode to string representation
   Looks up special keys ("Enter"→"[ENTER]", "Space"→"[SPACE]")
   Classifies key type (CHAR, SPECIAL, UNKNOWN)

5. Keylogger → Creates KeyEvent
   Bundles timestamp, key string, window title, and key type

6. Keylogger → LogManager.write_event()
   Acquires lock for thread safety
   Writes to current log file
   Checks file size and rotates if needed

7. Keylogger → WebhookDelivery.add_event()
   Adds event to buffer array under lock
   Checks if buffer reached batch size (default 50)
   If full, delivers the batch via HTTP POST
```

---

## Design Patterns

### Observer Pattern (Event-Driven Architecture)
pynput's `keyboard.Listener` implements the Observer pattern:

```python
self.listener = keyboard.Listener(on_press=self._on_press)
self.listener.start()
```

Our `_on_press` method is the observer callback. When the OS delivers a keyboard event, pynput notifies us by calling this function.

### Thread Safety with Locks
Multiple threads accessing shared data requires synchronization:

```python
def write_event(self, event: KeyEvent) -> None:
    with self._lock:
        self._file.write(event.to_log_string() + '\n')
        self._file.flush()
        self._check_rotation()
```

WebhookDelivery uses a buffer swap pattern — delivering outside the lock:

```python
def add_event(self, event: KeyEvent) -> None:
    batch = None
    with self.buffer_lock:
        self.event_buffer.append(event)
        if len(self.event_buffer) >= self.config.webhook_batch_size:
            batch = self.event_buffer  # Swap buffer
            self.event_buffer = []
    if batch:
        self._deliver_batch(batch)  # Deliver outside lock
```

### Immutable Data with Dataclasses
KeyEvent represents a keystroke as an immutable dataclass:

```python
@dataclass
class KeyEvent:
    timestamp: datetime
    key: str
    window_title: str = None
    key_type: KeyType = KeyType.CHAR
```

---

## Layered Architecture

```
┌─────────────────────────────────────────────────┐
│           Application Layer                     │
│  - Keylogger main class                         │
│  - Lifecycle management (start/stop)            │
│  - Event processing pipeline                    │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────┴───────────────────────────────┐
│           Service Layer                         │
│  - LogManager (persistence)                     │
│  - WebhookDelivery (exfiltration)               │
│  - WindowTracker (context gathering)            │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────┴───────────────────────────────┐
│           Data Layer                            │
│  - KeyEvent (event representation)              │
│  - KeyloggerConfig (configuration)              │
│  - KeyType (enum classification)                │
└─────────────────────────────────────────────────┘
```

---

## Performance Optimizations

- **Window title caching**: Only update every `window_check_interval` seconds (default 0.5) instead of every keystroke. Reduces API calls by 99%+ for typical typing speeds.
- **Batched webhook delivery**: Sending 50 events in one request instead of 50 individual requests reduces network overhead dramatically.
- **Buffer swap pattern**: WebhookDelivery swaps the event buffer under the lock and delivers outside the lock. The lock is only held for the brief list swap, not during the slow HTTP POST.

---

## Error Handling

1. **Import failures** - pynput import failure raises `ImportError` immediately with a clear message. Platform-specific imports (win32gui, NSWorkspace) are caught and set to None, allowing graceful degradation.
2. **Webhook delivery failures** - Caught and logged, doesn't crash the keylogger.
3. **File I/O errors during rotation** - `_check_rotation()` handles `FileNotFoundError` by immediately rotating to a new file.
4. **Non-OK webhook responses** - Logged as warning but doesn't crash.

---

## Next Steps

Now that you understand the architecture:
1. Read [03-IMPLEMENTATION.md](./03-IMPLEMENTATION.md) for detailed code walkthrough
2. Try modifying `window_check_interval` and observe the performance impact
3. Experiment with changing `webhook_batch_size` and monitor network traffic
