# Stream Deck Auto-Recover

An experimental Windows recovery tool for a specific Stream Deck failure where the device briefly disconnects, reconnects almost instantly at the USB/Windows level, but remains **disconnected or unresponsive inside the Elgato Stream Deck software**.

Instead of requiring the Stream Deck to stay physically disconnected for several seconds, this project listens for **Elgato's own Stream Deck connection/disconnection events** and can automatically perform the same Windows device reset that normally has to be done manually through Device Manager.

> **Current version:** Fresh v1.1
> **Status:** Experimental / testing
> **Platform:** Windows
> **Requires:** Elgato Stream Deck software + Administrator permission

---

## The Problem

On some systems, a Stream Deck can experience a very short connection failure:

```text
Stream Deck disconnects
        ↓
USB reconnects almost instantly
        ↓
Windows sees the device again
        ↓
Elgato Stream Deck software does NOT recover correctly
        ↓
Stream Deck becomes unresponsive
```

The disconnect may only last a split second.

Because of that, a normal watchdog that checks:

```text
"Has the USB device been disconnected for 3 seconds?"
```

doesn't work.

By the time the watchdog checks, Windows already sees the Stream Deck again.

However, the **Elgato Stream Deck software may still consider the device disconnected**.

The manual fix is usually:

```text
Device Manager
    ↓
Disable Stream Deck device
    ↓
Enable Stream Deck device
    ↓
Stream Deck works again
```

This project attempts to automate that recovery.

---

# How It Works

Stream Deck Auto-Recover consists of two parts:

### 1. Elgato Stream Deck Sensor Plugin

A small Stream Deck plugin listens for Elgato's own:

```text
deviceDidDisconnect
```

and:

```text
deviceDidConnect
```

events.

This is important because the physical USB disconnect can happen too quickly for normal polling to reliably detect.

### 2. Windows Auto-Recovery Helper

The Windows helper monitors the connection information reported by the sensor.

The recovery logic is roughly:

```text
Elgato reports deviceDidDisconnect
                ↓
Remember that Stream Deck's device ID
                ↓
Wait briefly
                ↓
Did Elgato report deviceDidConnect
for the same Stream Deck?
        ↓                    ↓
       YES                  NO
        ↓                    ↓
   Do nothing        Force Windows reset
                            ↓
                     Disable device
                            ↓
                         Wait
                            ↓
                      Enable device
                            ↓
                     Rescan devices
```

A physical USB reconnect by itself does **not** necessarily cancel recovery.

The important question is whether **Elgato's software reports the Stream Deck as connected again**.

---

# Why Not Just Monitor USB?

Earlier versions of this project monitored whether the Stream Deck disappeared from the Windows Plug-and-Play device tree.

That works for longer disconnects.

It does **not** solve this specific problem.

The failure being targeted here can look like:

```text
Disconnect
Reconnect
```

within a tiny fraction of a second.

Windows may already report the device as present while the Stream Deck application is still stuck.

Therefore, newer versions use the **Stream Deck software's connection events as the trigger** instead.

---

# Installation

## 1. Download the Latest Release

Download the latest release and extract the entire folder somewhere permanent.

For example:

```text
C:\Programs\StreamDeckAutoRecover\
```

Do not run it directly from inside the ZIP.

---

## 2. Install the Stream Deck Sensor

Run:

```text
1 - Install Elgato Sensor.cmd
```

This installs the connection sensor into the Stream Deck plugin directory.

---

## 3. Restart Stream Deck

Completely quit the Elgato Stream Deck software.

Do not simply close its main window.

Exit it from the Windows system tray, then reopen Stream Deck.

This allows Stream Deck to load the newly installed sensor plugin.

---

## 4. Start Stream Deck Auto-Recover

Run:

```text
StreamDeckAutoRecover.exe
```

Windows will request Administrator permission.

Administrator access is required because Windows does not allow normal applications to disable and enable Plug-and-Play devices without elevation.

---

# Configuration

The application uses two separate device selections.

## Elgato Stream Deck Device

Select the Stream Deck reported by the **Elgato software**.

This determines which Stream Deck connection/disconnection events are monitored.

---

## Windows Device to Reset

Select the Windows Plug-and-Play device that should be disabled and re-enabled when recovery is necessary.

One physical Stream Deck may appear as multiple entries in Windows.

Because of this, use:

```text
Test Reset
```

before enabling automatic monitoring.

The correct entry should reproduce the same recovery that normally works when manually disabling/re-enabling the Stream Deck through Device Manager.

---

# Test Reset

Before enabling automatic recovery:

1. Select your Stream Deck.
2. Select the Windows device you believe represents the correct reset target.
3. Click **Test Reset**.
4. The Stream Deck should briefly disappear/reset.
5. It should reconnect and become functional again.

If nothing useful happens, try another Stream Deck-related Windows device entry.

---

# Automatic Recovery

After configuration, click:

```text
Start Monitoring
```

The application will then watch the selected Stream Deck.

When Elgato reports that device disconnected, the helper briefly waits to determine whether Elgato itself reports the device connected again.

If it does not, Auto-Recover performs the Windows reset automatically.

Typical recovery:

```text
Elgato: deviceDidDisconnect
            ↓
Short verification delay
            ↓
Still disconnected in Elgato
            ↓
Disable selected Windows PnP device
            ↓
Wait approximately 1 second
            ↓
Enable selected Windows PnP device
            ↓
Windows device rescan
            ↓
Stream Deck reconnects
```

---

# System Tray

Stream Deck Auto-Recover is designed to run in the background.

When monitoring is active, you can minimize the program and leave it running from the Windows notification area/system tray.

The goal is for Auto-Recover to remain available without needing another window open on your desktop while gaming, streaming, or recording.

---

# Serial Numbers

This project does **not rely on the Stream Deck serial number remaining readable during the failure**.

During the bug this application targets, the Stream Deck software may temporarily lose access to information such as the device serial number.

Instead, the sensor uses the Stream Deck connection information/events provided by the Elgato Stream Deck software.

---

# Multiple Stream Decks

The helper is designed around selecting a specific Stream Deck to monitor.

However, users with multiple **identical Stream Deck models** should test carefully.

Windows and USB devices can expose several interfaces, and selecting the correct reset target is important.

Always use **Test Reset** before enabling automatic recovery.

---

# Requirements

* Windows 10 or Windows 11
* Elgato Stream Deck software
* A supported Stream Deck device
* Administrator permission
* The included Stream Deck sensor plugin

No .NET SDK is required to use the compiled release.

---

# Safety

Auto-Recover only attempts to disable and enable the Windows device selected by the user.

It does not intentionally reset every USB device on the computer.

However, this software is still experimental.

**Test the recovery while you are not live or recording something important.**

Selecting the wrong Plug-and-Play entry could temporarily reset a different Elgato/USB interface.

---

# Troubleshooting

## The Sensor Was Installed but Nothing Happens

Completely restart the Stream Deck software after installing the sensor.

Exit Stream Deck from the Windows system tray and reopen it.

---

## Auto-Recover Opens but Doesn't Detect My Stream Deck

Confirm that:

* Stream Deck software is running.
* The sensor plugin was installed.
* Stream Deck was restarted after installation.
* The selected device is the correct Stream Deck.

---

## Test Reset Doesn't Fix the Stream Deck

Your physical Stream Deck may expose multiple Plug-and-Play entries.

Try another Stream Deck/Elgato-related entry in the Windows device dropdown and run **Test Reset** again.

You want the entry that reproduces the manual Device Manager reset that fixes your problem.

---

## Windows Reconnects the Stream Deck Immediately

That's expected for the bug this project is designed to handle.

The project is specifically designed so that an immediate Windows USB reconnection does **not automatically mean the problem has been fixed**.

The important state is what the **Elgato Stream Deck software** reports.

---

## Auto-Recover Says "Not Responding"

Use the newest release.

Fresh v1 contained a Windows UI threading bug in the helper.

Fresh **v1.1** pins the Win32 UI/message loop to a single Windows OS thread to prevent the application window from immediately becoming unresponsive.

---

# Current Limitations

This project is still under active testing.

Possible edge cases include:

* Different Stream Deck models exposing different Windows device interfaces.
* Multiple identical Stream Decks connected simultaneously.
* Stream Deck software changing how plugin connection events are delivered.
* Failures where Elgato itself never emits a disconnect event.
* Windows refusing to reset a particular device interface.
* Stream Deck software crashes that prevent plugins from running entirely.

Feedback and logs from additional hardware are useful.

---

# Why This Exists

This project started because manually doing:

```text
Device Manager
→ Disable Stream Deck
→ Enable Stream Deck
```

every time the Stream Deck software lost the device was annoying.

The goal is simple:

> **If Stream Deck loses the device and fails to recover properly, fix it automatically.**

No unplugging cables.

No opening Device Manager.

No manually disabling and enabling hardware in the middle of a stream.

---

# Reporting Bugs

When opening an issue, please include:

* Stream Deck model
* Windows version
* Stream Deck software version
* Whether **Test Reset** works
* Whether the sensor detected the disconnect
* Whether Windows immediately reconnected the device
* What the Stream Deck software displayed when the failure happened
* Any relevant Auto-Recover logs

Please **remove serial numbers or other unique hardware identifiers** before posting screenshots or logs publicly.

---

# Source Code

Source code for the Windows helper and Stream Deck sensor is included in this repository.

Contributions, testing, bug reports, and improvements are welcome.

---

# Disclaimer

This project is an independent community tool.

**It is not affiliated with, endorsed by, sponsored by, or supported by Elgato or Corsair.**

Stream Deck, Elgato, Corsair, Windows, and other product names belong to their respective owners.

This software interacts with Windows Plug-and-Play device controls and should be considered experimental.

Use at your own risk.

---

# MIT License
