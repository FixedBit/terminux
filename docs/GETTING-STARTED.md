# Getting started

terminux turns an Android phone into a Linux machine: a desktop you see in
the Termux:X11 app, VS Code, AI coding tools, and as many separate Linux
environments as you want. It runs inside Termux and doesn't need root.

## What you need

- An Android phone or tablet with a 64-bit ARM processor (almost every phone
  from the last five years), Android 8 or later.
- About 4 GB of free storage for a desktop, more for environments.
- **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) or
  [GitHub](https://github.com/termux/termux-app/releases). The Play Store
  version is outdated and won't work.

You don't need to install Termux:X11 or Termux:API yourself; the installer
does it.

## 1. Build your command

Open the [wizard](https://fixedbit.github.io/terminux/wizard.html) on any device, pick a preset or go through the options,
and copy the command it shows. Every option has a sensible default, so the
plain command works too:

```sh
curl -fsSL https://fixedbit.github.io/terminux/install.sh | bash
```

The wizard keeps your choices in the page address, so you can bookmark or
send that link to set up another phone the same way.

## 2. Run it in Termux

Open Termux, paste the command and press Enter. On a fresh Termux it:

1. Updates Termux and installs the basics.
2. Installs the **Termux:X11** app (Android asks you to allow installs from
   Termux; allow it, then tap Install) and points you to **Termux:API**.
3. Installs your desktop, apps, shell and extras.

It takes 20–40 minutes depending on your connection and what you chose. Keep
Termux open and the screen on; terminux holds a wake lock so Android doesn't
pause it.

If something optional fails, the rest still installs and the summary at the
end says what to retry.

## 3. Use it

Close Termux and open it again. You'll see the terminux banner with what's
running and the main commands.

```sh
terminux            # a menu with everything
terminux start      # start the desktop, then look in the Termux:X11 app
terminux stop
terminux add        # install more apps: AI tools, development, media, ...
terminux env        # your Linux environments
terminux doctor     # check for problems
terminux update     # get the latest terminux
```

## Phones that kill the desktop

Android 12 and later can kill Termux's background processes, which stops the
desktop with `signal 9`. If that happens, run `terminux fix phantom`. It
fixes this automatically when your phone has root or
[Shizuku](https://shizuku.rikka.app), and otherwise tells you the one setting
to change. Also set Termux and Termux:X11 to **Unrestricted** battery use.

## Already installed with an older script?

If you used linux-android or a similar script before, you don't need to start
over. Clone terminux and run `terminux fix`; it repairs the launchers you
already have. See [Troubleshooting](TROUBLESHOOTING.md).
