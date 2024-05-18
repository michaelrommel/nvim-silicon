# WSL2 and the Windows Clipboard

## Motivation

When working inside the WSL2 it is sometimes preferable to get a code snapshot directly in the Windows clipboard to paste it in Teams or Mail or share it in another way. The `silicon` tool itself can directly copy a generated image to the clipboard on all platforms (linux, windows, mac) but it can only do so when run on that platform itself, not in a subsystem like the WSL.

Based on your feedback and my own desire to come up with a solution, I researched several ways to achieve this and here I outline my solution and the reasons behind several decisions. It may help others when facing similar problems.

## Navigating the solution space

### No-Go: direct copy to the Windows Clipboard

Since WSL runs linux, the `silicon` version on that platform tries to finde the `xclip` tool in order to copy the generated image to the X Clipboard. Which means running an X server on the Windows side and exposing that to the WSL. Which is pretty bloated and cumbersome to set up and probably not something a vi user wants to have. So I have pretty much decided that this is not the direction I would like to take.

### Second choice: External 3rd Party Programs

There are numerous tools available including Windows' own `clip.exe` or `wslclip` programs that can put text onto the clipboard, but very few, that can actually handle images.

In my search, I found two tools:

1. [NirCmd](http://www.nirsoft.net/utils/nircmd.html)
2. [image-clipboard](https://github.com/bamontelucas/image-clipboard)

Both tools work as intended and can take an image file as input and put it onto the Windows clipboard.

However that requires the user to download and install a binary program on their systems, which is always coming with an inherent risk, it is another step to perform and may be outright forbidden in your place of work.

### Preferred: Powershell Script

Since powershell provides a lot of commandlets and libraries as standard, there are native ways to put an image file on the Windows clipboard. The hurdles to overcome here are mainly two:

1. the Script ExecutionPolicy that might be set
2. the path semantics on Windows and linux

The first issue arises, if the script that is called from neovim is part of the lua package installation and resides on the linux side. Then - depending on the policy - loading a WSL-path script into the Windows powershell.exe, the WSL is seen as "remote" and might be blocked if the Policy is set to "RemoteSigned". It can be tackled by calling the `powershell.exe` interpreter with a script path that is local to the Windows side, but this is also then another step to copy/move that powershell script to Windows and adapt a linux script with the new path to the installation. It for sure can be done, but to have to do it on every machine, where you sync your dotfiles to is a hassle, that I'd like to avoid.

The second issue is, that the generated image file from `silicon` most likely resides on the linux side and the `powershell.exe` interpreter needs to see it from windows. Since the Windows perceived path contains the name of the distribution/installation of the WSL instance, it should not be a fixed value.

## Solution

The solution I finally arrived at does also come with inconveniences, albeit hopefully some, that most users can live with, because they might already be fulfilled as part of a minimal installation.

### Prerequisites

You need to have the `wslpath` tool available and in your path. It is by default a symlink from `/usr/bin/wslpath` to `/init` in a WSL2 installation, there should not be a need for any installation.

Also the `powershell.exe` interpreter should be in your path, which is typically taken over from the Windows System Environment Variables setting of your Windows installation (or you would need to adapt the helper script accordingly, see below).

### How it works

The idea is to provide a new configuration option `wslclipboard` that steers, how `nvim-silicon` should interact with the clipboard if the clipboard has been selected as destination.

Several values are available:

- `never`: never try to make special provisions to copy to the Windows clipboard. This essentially means, that the usual linux way used by `silicon` (via `xclip`) is always used. `nil` is regarded as `never`.
- `always``: unconditionally use the provided mechanism to first create a file based screenshot on linux and then push this image onto the Windows clipboard
- `auto`: detect that nvim is running under WSL by looking for the string "WSL" in the output of the `uname -r` command, e.g. "5.15.146.1-microsoft-standard-WSL2". If WSL is detected, then use the provided mechanism, otherwise keep the `silicon` standard.

Since we cannot access the Windows clipboard directly, we have to construct an imagefile first. This will be put in the location specified by the `output` opts key. If this is `nil` because you always only wanted the images to be placed on the clipboard or you called the new `.clip()` function, a temporary file will be created in `/tmp/<YYY-MM-DDTHH-MM-SS>_code.png`.

There is a second option `wslclipboardcopy` that defines, whether to keep these temporary files or not, the values are `keep` or `delete`. `nil` is regarded as `keep`.

Whenever the Windows clipboard shall be used, first this (temporary) file is created in the usual manner. Then a script `wslclipimg` is called that resides in the `helper` directory of the plugin installation with the filename of that image file as parameter. This linux bash script contains the powershell code needed to read that file and put the contents on the Windows clipboard. The original idea of usine an EncodedCommand was misleading, because of a [bug in Powershell](https://github.com/PowerShell/PowerShell/issues/5912). Now the helper script passes the script as text, explicitly setting the ExecutionPolicy to Bypass. The path to the helper script is determined automatically based on the installation path of the plugin. If that breaks, please turn on `debug` in your config and let me know the output, so that it can be improved.

```bash
#! /bin/bash

# we need to get the path to the WSL located file as it would be accessed
# by the windows side. wslpath should be a symlink to /init on a standaed WSL2
# installation
IMG=$(wslpath -w "$1")

SCRIPT=$(cat << EOF
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
[Windows.Forms.Clipboard]::SetImage(\$([System.Drawing.Image]::Fromfile(\$(Get-Item "${IMG}"))));
EOF
)

# powershell.exe should be on your path, otherwise specify the complete path to the
# interpreter, like /mnt/c/Windows/system32/WindowsPowerShell/v1.0/powershell.exe
echo "${SCRIPT}" | powershell.exe -NoProfile -NoLogo -InputFormat text -OutputFormat text -NonInteractive -ExecutionPolicy Bypass -Command -
```

If you have suggestions, how this could be even more simplified, please let me know.

