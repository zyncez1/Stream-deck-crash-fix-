# Stream Deck Auto-Recover

An experimental Windows recovery utility for a specific Elgato Stream Deck failure where the device briefly disconnects, reconnects almost instantly at the Windows/USB level, but remains disconnected or unresponsive inside the Elgato Stream Deck software.

Instead of relying on the Stream Deck to remain physically disconnected for several seconds, this project uses a Stream Deck sensor plugin to watch Elgato's own device connection events and can automatically perform the same Windows disable/re-enable reset that would normally be done manually through Device Manager.

> **Current version:** Fresh v1.1  
> **Status:** Experimental / testing  
> **Platform:** Windows 10 / Windows 11  
> **Requires:** Elgato Stream Deck software and Administrator permission

---

## What Problem Does This Fix?

The failure this project targets can look like this:

```text
Stream Deck disconnects for a split second
        ↓
Windows/USB reconnects it almost immediately
        ↓
Windows sees the device again
        ↓
Elgato Stream Deck software does not recover correctly
        ↓
The Stream Deck becomes disconnected or unresponsive in the software
```

Because the physical disconnect can be extremely short, a normal watchdog that checks whether the USB device has been gone for several seconds may completely miss it.

The manual fix is often:

```text
Device Manager
    ↓
Disable the Stream Deck device
    ↓
Enable the Stream Deck device
    ↓
Stream Deck starts working again
```

**Stream Deck Auto-Recover attempts to automate that recovery.**

---

## How It Works

The project has two main pieces.

### 1. Elgato Stream Deck Sensor

The included sensor plugin listens for Stream Deck connection events reported by the Elgato Stream Deck software.

The important events are:

```text
deviceDidDisconnect
deviceDidConnect
```

This allows the project to react to Elgato's own view of the device instead of trying to poll Windows fast enough to catch a split-millisecond USB interruption.

### 2. Windows Auto-Recovery Helper

The Windows helper receives the connection state from the sensor and performs the recovery when necessary.

The intended logic is:

```text
Elgato reports deviceDidDisconnect
                ↓
Remember that Stream Deck device
                ↓
Wait briefly for Elgato to recover
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

An immediate Windows USB reconnect by itself does **not** necessarily mean the problem has been fixed.

The important state is whether the **Elgato Stream Deck software** considers that Stream Deck connected again.

---

## Installation

### 1. Download the Repository / Release

Download the project and extract the files to a permanent folder.

For example:

```text
C:\Programs\StreamDeckAutoRecover\
```

Do not run the program directly from inside a ZIP archive.

### 2. Install the Elgato Sensor

Run:

```text
1 - Install Elgato Sensor.cmd
```

### 3. Fully Restart Stream Deck

After installing the sensor:

1. Completely exit the Elgato Stream Deck software from the Windows system tray.
2. Reopen Stream Deck.

Simply closing the main Stream Deck window may not fully restart the software.

### 4. Run Auto-Recover

Run:

```text
StreamDeckAutoRecover.exe
```

Windows may ask for Administrator permission.

Administrator permission is required because the helper may need to disable and re-enable a Windows Plug-and-Play device.

---

## Configuration

The helper uses two device selections.

### Elgato Stream Deck Device

Select the Stream Deck reported by the Elgato software.

This is the device whose Elgato connection state will be monitored.

### Windows Device to Reset

Select the Windows Plug-and-Play device that should be disabled and re-enabled during recovery.

One physical Stream Deck may appear as multiple Windows device entries, so choosing the correct reset target is important.

---

## Test Reset First

Before enabling automatic monitoring, use the included **Test Reset** function.

The correct Windows device entry should reproduce the same recovery that normally works when you manually disable and re-enable the Stream Deck in Device Manager.

Recommended test:

1. Select your Stream Deck.
2. Select a Stream Deck-related Windows device.
3. Click **Test Reset**.
4. Confirm the Stream Deck briefly resets.
5. Confirm it reconnects and works again.
6. If nothing useful happens, try another Stream Deck-related Windows device entry.

**Do this while you are not live or recording anything important.**

---

## Automatic Recovery

After configuration, click:

```text
Start Monitoring
```

When the sensor reports a Stream Deck disconnect, Auto-Recover briefly waits to see whether Elgato reports the same device connected again.

If Elgato does not recover properly, the helper can perform:

```text
Disable selected Windows device
        ↓
Wait
        ↓
Enable selected Windows device
        ↓
Rescan Windows devices
        ↓
Stream Deck reconnects
```

---

## Why Not Just Monitor USB?

Earlier versions of this project attempted to monitor whether the Stream Deck remained absent from the Windows Plug-and-Play device tree.

That does not reliably detect the problem this version is intended to fix.

The failure may look like:

```text
disconnect
reconnect
```

within a tiny fraction of a second.

By the time a normal polling loop checks Windows, the device may already be present again even though the Elgato software is still stuck.

That is why the newer approach uses the Stream Deck software connection events as the trigger.

---

## Serial Number Behavior

During this particular failure, the Elgato Stream Deck software may temporarily be unable to read the Stream Deck serial number.

Auto-Recover is designed so that recovery does not depend on the serial number remaining readable during the fault.

---

## System Tray

Stream Deck Auto-Recover is intended to run quietly in the background.

When supported by the current build, the helper can remain available through the Windows system tray while monitoring is active.

---

## Requirements

- Windows 10 or Windows 11
- Elgato Stream Deck software
- Elgato Stream Deck hardware
- Administrator permission for hardware reset operations
- Included Stream Deck sensor plugin

The compiled release does not require you to install the .NET SDK.

---

## Safety Warning

This software can disable and re-enable a Windows Plug-and-Play device.

It is experimental.

Before relying on automatic recovery:

- Test the reset manually using **Test Reset**.
- Make sure the selected Windows device is actually your Stream Deck.
- Do not test for the first time during an important livestream or recording.
- Be aware that selecting the wrong device entry could temporarily reset another USB/Elgato interface.

Use this software at your own risk.

---

## Troubleshooting

### The Sensor Installed but Nothing Happens

Completely exit the Elgato Stream Deck software from the system tray and reopen it after installing the sensor.

### Auto-Recover Does Not Detect My Stream Deck

Confirm:

- Elgato Stream Deck software is running.
- The sensor plugin was installed.
- Stream Deck was completely restarted after installation.
- The correct Stream Deck is selected.

### Test Reset Does Not Fix the Device

One physical Stream Deck can expose multiple Windows Plug-and-Play entries.

Try another Stream Deck/Elgato-related entry and run **Test Reset** again.

You want the entry that reproduces the manual Device Manager reset that fixes your Stream Deck.

### Windows Reconnects the Stream Deck Immediately

That is expected for the failure this project targets.

A fast Windows USB reconnect does not necessarily mean the Elgato software successfully recovered.

### Auto-Recover Says "Not Responding"

Use the latest build.

Fresh v1 had a Windows UI threading issue. Fresh v1.1 changed the helper so its Win32 UI/message loop remains on the correct Windows OS thread.

### Sensor Logs

Use:

```text
Open Sensor Logs.cmd
```

when troubleshooting sensor behavior.

---

## Current Limitations

This project is still experimental and has not been tested across every Stream Deck model or Windows configuration.

Possible edge cases include:

- Different Stream Deck models exposing different Windows device interfaces.
- Multiple identical Stream Decks connected at the same time.
- Elgato changing how Stream Deck plugin connection events are delivered.
- Failures where Elgato never emits a disconnect event.
- Windows refusing to reset a particular device interface.
- Stream Deck software itself crashing badly enough that plugins cannot run.

Testing and bug reports are welcome.

---

## Reporting a Bug

When opening an issue, please include:

- Stream Deck model
- Windows version
- Elgato Stream Deck software version
- Whether **Test Reset** works
- Whether the sensor detected the disconnect
- Whether Windows reconnected the device immediately
- What the Elgato Stream Deck software showed during the failure
- Relevant Auto-Recover or sensor logs

**Please remove serial numbers and other unique hardware identifiers before posting screenshots or logs publicly.**

---

## Uninstalling the Sensor

Run:

```text
Uninstall Elgato Sensor.cmd
```

Then completely restart the Elgato Stream Deck software.

---

## Project Status

This project began as a personal workaround for a Stream Deck that would briefly disconnect during use and then become unresponsive inside the Elgato software.

The goal is simple:

> If Stream Deck loses the device and fails to recover correctly, automatically perform the reset instead of opening Device Manager every time.

This repository currently contains the compiled Windows helper and related installation/support files.

---

## Disclaimer

Stream Deck Auto-Recover is an independent community project.

It is **not affiliated with, endorsed by, sponsored by, or supported by Elgato or Corsair**.

Elgato, Stream Deck, Corsair, Windows, and other product names and trademarks belong to their respective owners.

This software interacts with Windows hardware/device controls and is experimental.

**Use at your own risk.**

---

## License

This project is licensed under the **MIT License**.

See the [`LICENSE`](LICENSE) file for details.
