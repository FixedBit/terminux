# Device tweaks

Phones aren't Linux PCs: Android suspends apps, kills background processes
and changes audio and GPU stacks between vendors. These tweaks work around
that. Each one checks whether it applies and does nothing on phones where it
doesn't, so the wizard turns them all on (`--tweaks`). Untick any you don't
want, or pass `--tweaks none`.

| Tweak | id | What it does | Who needs it |
|-------|----|--------------|--------------|
| Keep Termux awake | `wakelock` | Holds a wake lock while the desktop runs, released by `terminux stop`. | Anyone; essential on Samsung, Xiaomi and other phones with aggressive battery savers, where switching to the Termux:X11 app otherwise freezes the desktop. |
| GPU self-check | `gpu-check` | At each start, asks Vulkan which GPU driver is active. If Mesa's Turnip driver doesn't support the GPU (common right after a new Snapdragon launches), it falls back to software rendering instead of letting apps crash. | Adreno phones, especially new ones. |
| Process killer | `phantom` | Android 12+ kills "phantom" child processes, which takes the desktop down with `signal 9`. terminux lifts the limit through root or [Shizuku](https://shizuku.rikka.app) when available; otherwise it tells you the one setting to change. Re-run any time with `terminux fix phantom`. | Android 12 and later. |
| One UI audio fix | `oneui-audio` | Starts PulseAudio with Samsung's `libskcodec` preloaded, without which it fails to start on One UI ([termux-packages #19623](https://github.com/termux/termux-packages/issues/19623)). | Samsung phones. Skipped automatically elsewhere. |
| Touch-friendly windows | `touch` | Uses XFCE's high-DPI window theme, whose borders are thick enough to grab with a finger. | XFCE on a touchscreen. |
| Automatic HiDPI | `hidpi` | When you haven't set `--dpi`, picks one: 180 on a Galaxy Z Fold's inner screen, otherwise 40% of Android's own screen density on high-density screens (density 480 → DPI 192). Ordinary screens keep 96. | High-resolution phones and foldables. |

## Where they live

The installer writes the choices to `~/.config/linux-gpu.sh` as
`TERMINUX_WAKELOCK`, `TERMINUX_GPU_CHECK`, `TERMINUX_ONEUI_AUDIO` and
`TERMINUX_TOUCH` (`1` on, `0` off), plus `LINUX_DPI`. Edit that file and
restart the desktop to change them without reinstalling.

## Doing it by hand

The process-killer limit, if terminux can't lift it:

- **Android 14 and later:** Developer options → **Disable child process
  restrictions** → on.
- **Android 12–13:** from a computer with `adb`, or on the phone with an app
  like LADB:

  ```sh
  adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
  adb shell "settings put global settings_enable_monitor_phantom_procs false"
  ```

Also exclude Termux and Termux:X11 from battery optimisation (Settings → Apps
→ Termux → Battery → Unrestricted).
