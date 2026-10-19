# Elavo

Elavo is a desktop Linux image based on `ghcr.io/ublue-os/base-main`. Published builds are `ghcr.io/elavo-io/elavo`.

Verify a published image with the public key in this repository:

```bash
cosign verify --key cosign.pub ghcr.io/elavo-io/elavo
```

## What is in this image

The system name is Elavo. `build.sh` rewrites `/usr/lib/os-release` so `NAME` is Elavo and `VERSION` and `PRETTY_NAME` are Elavo `0.1.6`. GRUB's menu title is `PRETTY_NAME`, so a new deployment is `Elavo 0.1.6 (ostree:N)`. About reads `VERSION` for the line under the title, and shows `VERSION_ID` as Fedora Version. `VERSION_ID`, `CPE_NAME`, and `OSTREE_VERSION` stay as the base image shipped them. `ID` stays `fedora` so the ISO build and the signed `EFI/fedora` bootloader keep working. Which build is installed is `bootc status`.

The image boots to `greetd` and `gtkgreet`, then a labwc session with Folio, the Elavo desktop: the top panel, the dock, Lens, and the app switcher, from [elavo-folio](https://github.com/elavo-io/elavo-folio). The Containerfile's `folio` stage builds `elavo-folio` at the tag in `ELAVO_FOLIO_REF` and installs the binaries and their systemd user units. The units are enabled globally and are wanted by `graphical-session.target`. This image does not include the control center, the Applications folder, or NVIDIA drivers.

System Settings comes from [elavo-system-settings](https://github.com/elavo-io/elavo-system-settings), built in the Containerfile's `system-settings` stage at `ELAVO_SYSTEM_SETTINGS_REF`. The panel's System Settings… item opens it, and the dock's Dock Settings… opens its Desktop & Dock pane. It relies on these user services the image enables:

- `elavo-idle.service` runs `/usr/libexec/elavo-idle`, which starts `swayidle` with the lock and display-off times from `~/.config/elavo/idle.conf` (5 and 10 minutes until the Lock Screen pane changes them). It also handles `loginctl lock-session` and locks before sleep.
- `elavo-polkit-agent.service` is the administrator password prompt (`mate-polkit`) for software updates, users, the date and time, and the computer's name.
- `kanshi.service` reapplies the display arrangement the Displays pane saves. A drop-in keeps it stopped until the first one is saved.
- `elavo-power-button.service` reads the laptop power button. A press while the screen is on and the session is unlocked runs the panel's Shut Down action. A press while the screen is off, the session is locked, or the machine has just woken turns the screen on. Holding the button for several seconds is the laptop's own power-off.

Software updates and the lid setting run as root through `/usr/libexec/elavo-system-settings-helper` and `pkexec`. `rc.xml` sets natural scrolling, tap to click, and ignoring the trackpad while typing for every pointer; the Mouse and Trackpad panes override them per kind of device in `~/.config/labwc/rc.xml`.

The greeter runs in `cage` because the Fedora `gtkgreet` package requires cage, sway, wayfire, or river. The logged-in session is labwc, started from `/usr/share/wayland-sessions/elavo.desktop` via `/usr/libexec/elavo-session`. labwc's autostart starts `elavo-session.target` after the Wayland socket exists. That target binds to `graphical-session.target`, which refuses a direct start, so the portals, the panel, the dock, and Lens come up. The wrapper stops `elavo-session.target` when labwc exits, which stops all of them. Fedora 44's labwc package does not ship that session file or `labwc-menu-generator`, so the image ships the session file and a short root menu: Terminal, Files, and Log Out. The panel's sun opens the Elavo menu (About, Sleep, Restart, Shut Down, Lock Screen, Log Out). Window buttons are on the left. Super+Space toggles Lens (`elavo-lens --toggle`), which searches applications, does arithmetic and unit conversion, and lists every application. Super+1 through Super+9 activate that dock slot (`elavo-dock --activate N`). Super+Return opens `foot`. Super+Ctrl+Q locks the screen, and Super+Shift+Q asks whether to log out. Both call the panel, as the power button's Shut Down question does.

The Elavo icon theme comes from `elavo-visuals` `themes/elavo-icons`, at the same pinned commit as the GTK theme, and is installed at `/usr/share/icons/Elavo`. It is the default icon theme (`settings.ini` and dconf). It holds the panel's sun (`elavo-sun-symbolic`), the panel's search glass, and Elavo's application icons. Every other icon comes from Adwaita, which it inherits.

`gnome-keyring` is the login keyring. `greetd`'s PAM stack unlocks it with the account password. The session attaches that daemon to the session bus. This is where applications store sign-in tokens. It is not disk encryption.

Flathub is enabled from `/etc/flatpak/remotes.d`. Firefox (`org.mozilla.firefox`) is declared in `/usr/share/flatpak/preinstall.d`. `elavo-flatpak-preinstall.service` installs it after the network is up. A system Flatpak installed during the image build would land in `/var`, which bootc does not ship, so the browser is not on the image until that first online boot.

The Plymouth theme is fetched during the image build from `elavo-visuals` `main`, path `bootscreen/elavo-new/elavo-boot/`. It is installed at `/usr/share/plymouth/themes/elavo-boot`, set with `plymouth-set-default-theme elavo-boot`, and built into the initramfs with dracut. The frames are not stored in this repository. The first boot should show that splash before the greeter.

Package names were checked against Fedora 44, the release `base-main` tracks. Fedora has no `qt6-wayland` package; Qt applications get `qt6-qtwayland`. The UI font is Roboto (`google-roboto-fonts`), the face the GTK theme names, and the terminal font is JetBrains Mono. Inter (`rsms-inter-fonts`) is still installed but no longer the default. The cursor theme is Adwaita.

The Elavo theme is fetched from `elavo-visuals` at the commit in `visuals_theme_rev` in `build_files/build.sh`, and installed at `/usr/share/themes/Elavo`. It is the default GTK theme (`settings.ini` and dconf), and `rc.xml` selects it for labwc's title bars. Some of it has to live in each account, so `elavo-user-theme.service` runs `/usr/libexec/elavo-user-theme` at every login, before the panel starts. That script:

- Keeps a copy of the theme in `~/.local/share/themes`, refreshed when the image's copy changes, because Flatpak apps cannot read `/usr/share/themes`. A symlink there, or a copy without the image's stamp, is left alone.
- Adds the libadwaita import and the accent file to `~/.config/gtk-4.0/gtk.css`, keeping anything already in it.
- Sets the user Flatpak override that lets apps read the theme copy and the GTK settings, read-only.
- Adds the Elavo window buttons to Firefox profiles.
- Sets Chrome, Brave, and Chromium profiles that never chose a theme to GTK, while the browser is closed. On Classic they draw their own buttons.

The theme names Roboto, and the image installs it and sets it in dconf.

# image-template

This repository is meant to be a template for building your own custom [bootc](https://github.com/bootc-dev/bootc) image. This template is the recommended way to make customizations to any image published by the Universal Blue Project.

# Community

If you have questions about this template after following the instructions, try the following spaces:
- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc discussion forums](https://github.com/bootc-dev/bootc/discussions) - This is not an Universal Blue managed space, but is an excellent resource if you run into issues with building bootc images.

# How to Use

To get started on your first bootc image, simply read and follow the steps in the next few headings.
If you prefer instructions in video form, TesterTech created an excellent tutorial, embedded below.

[![Video Tutorial](https://img.youtube.com/vi/IxBl11Zmq5w/0.jpg)](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

## Step 0: Prerequisites

These steps assume you have the following:
- A Github Account
- A machine running a bootc image (e.g. Bazzite, Bluefin, Aurora, or Fedora Atomic)
- Experience installing and using CLI programs

## Step 1: Preparing the Template

### Step 1a: Copying the Template

Select `Use this Template` on this page. You can set the name and description of your repository to whatever you would like, but all other settings should be left untouched.

Once you have finished copying the template, you need to enable the Github Actions workflows for your new repository.
To enable the workflows, go to the `Actions` tab of the new repository and click the button to enable workflows.

### Step 1b: Cloning the New Repository

Here I will defer to the much superior GitHub documentation on the matter. You can use whichever method is easiest.
[GitHub Documentation](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)

Once you have the repository on your local drive, proceed to the next step.

## Step 2: Initial Setup

### Step 2a: Creating a Cosign Key

Container signing is important for end-user security and is enabled on all Universal Blue images. By default the image builds *will fail* if you don't.

First, install the [cosign CLI tool](https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/#installing-cosign-with-the-cosign-binary)
With the cosign tool installed, run inside your repo folder:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
```

The signing key will be used in GitHub Actions and will not work if it is password protected.

> [!WARNING]
> Be careful to *never* accidentally commit `cosign.key` into your git repo. If this key goes out to the public, the security of your repository is compromised.

Next, you need to add the key to GitHub. This makes use of GitHub's secret signing system.

<details>
    <summary>Using the Github Web Interface (preferred)</summary>

Go to your repository settings, under `Secrets and Variables` -> `Actions`
![image](https://user-images.githubusercontent.com/1264109/216735595-0ecf1b66-b9ee-439e-87d7-c8cc43c2110a.png)
Add a new secret and name it `SIGNING_SECRET`, then paste the contents of `cosign.key` into the secret and save it. Make sure it's the .key file and not the .pub file. Once done, it should look like this:
![image](https://user-images.githubusercontent.com/1264109/216735690-2d19271f-cee2-45ac-a039-23e6a4c16b34.png)
</details>
<details>
<summary>Using the Github CLI</summary>

If you have the `github-cli` installed, run:

```bash
gh secret set SIGNING_SECRET < cosign.key
```
</details>

### Step 2b: Choosing Your Base Image

To choose a base image, simply modify the line in the container file starting with `FROM`. This will be the image your image derives from, and is your starting point for modifications.
For a base image, you can choose any of the Universal Blue images or start from a Fedora Atomic system. Below this paragraph is a dropdown with a non-exhaustive list of potential base images.

<details>
    <summary>Base Images</summary>

- Bazzite: `ghcr.io/ublue-os/bazzite:stable`
- Aurora: `ghcr.io/ublue-os/aurora:stable`
- Bluefin: `ghcr.io/ublue-os/bluefin:stable`
- Universal Blue Base: `ghcr.io/ublue-os/base-main:latest`
- Fedora: `quay.io/fedora/fedora-bootc:44`

You can find more Universal Blue images on the [packages page](https://github.com/orgs/ublue-os/packages).
</details>

If you don't know which image to pick, choosing the one your system is currently on is the best bet for a smooth transition. To find out what image your system currently uses, run the following command:
```bash
sudo bootc status
```
This will show you all the info you need to know about your current image. The image you are currently on is displayed after `Booted image:`. Paste that information after the `FROM` statement in the Containerfile to set it as your base image.

### Step 2c: Changing Names

Change the `IMAGE_NAME` and `REPO_ORGANIZATION` variable inside the `image-template.env`

To commit and push all the files changed and added in step 2 into your Github repository:
```bash
git add Containerfile image-template.env cosign.pub
git commit -m "Initial Setup"
git push
```
Once pushed, go look at the Actions tab on your Github repository's page.  The green checkmark should be showing on the top commit, which means your new image is ready!

## Step 3: Switch to Your Image

From your bootc system, run the following command substituting in your Github username and image name where noted.
```bash
sudo bootc switch ghcr.io/<username>/<image_name>
```
This should queue your image for the next reboot, which you can do immediately after the command finishes. You have officially set up your custom image! See the following section for an explanation of the important parts of the template for customization.

# Repository Contents

## Containerfile

The [Containerfile](./Containerfile) defines the operations used to customize the selected image.This file is the entrypoint for your image build, and works exactly like a regular podman Containerfile. For reference, please see the [Podman Documentation](https://docs.podman.io/en/latest/Introduction.html).

## build.sh

The [build.sh](./build_files/build.sh) file is called from your Containerfile. It is the best place to install new packages or make any other customization to your system. There are customization examples contained within it for your perusal.

## build.yml

The [build.yml](./.github/workflows/build.yml) Github Actions workflow creates your custom OCI image and publishes it to the Github Container Registry (GHCR). By default, the image name will match the Github repository name.

# Building Disk Images

This template provides an out of the box workflow for creating disk images (ISO, qcow, raw) for your custom OCI image which can be used to directly install onto your machines.

This template provides a way to upload the disk images that is generated from the workflow to a S3 bucket. The disk images will also be available as an artifact from the job, if you wish to use an alternate provider. To upload to S3 we use [rclone](https://rclone.org/) which is able to use [many S3 providers](https://rclone.org/s3/).

## Setting Up ISO Builds

The [build-disk.yml](./.github/workflows/build-disk.yml) Github Actions workflow creates a disk image from your OCI image by utilizing the [bootc-image-builder](https://osbuild.org/docs/bootc/). In order to use this workflow you must complete the following steps:

1. Modify `disk_config/iso.toml` to point to your custom container image before generating an ISO image.
2. If you changed your image name from the default in `build.yml` then in the `build-disk.yml` file edit the `IMAGE_REGISTRY`, `IMAGE_NAME` and `DEFAULT_TAG` environment variables with the correct values. If you did not make changes, skip this step.
3. Finally, if you want to upload your disk images to S3 then you will need to add your S3 configuration to the repository's Action secrets. This can be found by going to your repository settings, under `Secrets and Variables` -> `Actions`. You will need to add the following
  - `S3_PROVIDER` - Must match one of the values from the [supported list](https://rclone.org/s3/)
  - `S3_BUCKET_NAME` - Your unique bucket name
  - `S3_ACCESS_KEY_ID` - It is recommended that you make a separate key just for this workflow
  - `S3_SECRET_ACCESS_KEY` - See above.
  - `S3_REGION` - The region your bucket lives in. If you do not know then set this value to `auto`.
  - `S3_ENDPOINT` - This value will be specific to the bucket as well.

Once the workflow is done, you'll find the disk images either in your S3 bucket or as part of the summary under `Artifacts` after the workflow is completed.

# Artifacthub

This template comes with the necessary tooling to index your image on [artifacthub.io](https://artifacthub.io). Use the `artifacthub-repo.yml` file at the root to verify yourself as the publisher. This is important to you for a few reasons:

- The value of artifacthub is it's one place for people to index their custom images, and since we depend on each other to learn, it helps grow the community. 
- You get to see your pet project listed with the other cool projects in Cloud Native.
- Since the site puts your README front and center, it's a good way to learn how to write a good README, learn some marketing, finding your audience, etc. 

[Discussion Thread](https://universal-blue.discourse.group/t/listing-your-custom-image-on-artifacthub/6446)

# Justfile Documentation

The `Justfile` contains various commands and configurations for building and managing container images and virtual machine images using Podman and other utilities. It is also used inside Github Actions.

## Required Utilities

Container build:
- [just](https://just.systems/man/en/introduction.html)
- [podman](https://docs.podman.io/en/latest)
- [jq](https://jqlang.org)

These are usually preinstalled on Universal Blue's Bootc Images.

Linting:
- shfmt
- shellcheck

## Environment Variables

These are all sourced from the `image-template.env` file.

- `image_name`: The name of the image (default: "image-template").
- `default_tag`: The default tag for the image (default: "latest").
- `bib_image`: The Bootc Image Builder (BIB) image (default: "quay.io/centos-bootc/bootc-image-builder:latest").

## Building The Image

All these recipes will work (with default values) without supplying any arguments to them, e.g. `just build`

### `just build`

Builds a container image using Podman.

```bash
just build $target_image $tag
```

Arguments:
- `$target_image`: The tag you want to apply to the image (default: `$image_name`).
- `$tag`: The tag for the image (default: `$default_tag`).

### Rechunking
We can flatten the layers of container images to make sure there isn't a single huge layer when your image gets published.
This does not make your image faster to download, just provides better resumability.

#### `just ostree-rechunk`
Rechunks the existing Image with [rpm-ostree](https://coreos.github.io/rpm-ostree/build-chunked-oci/)

```bash
just ostree-rechunk $target_image $tag
```

#### `just rechunk`
Rechunks the existing Image with [chunkah](https://github.com/coreos/chunkah), this is probably gonna be the default here at some point, try it out, it's cool.

```bash
just rechunk $target_image $tag
```

### Switching to the locally built image for testing

The image has to be in the containers-storage owned by root, to be able to rebase to it, see the `_rootful_load_image` recipe.

`sudo just build` and `sudo just ostree-rechunk` builds directly as root and allows you to skip the transfer to the root containers-storage.

You can rebase to all the images that are in your containers-storage:

```
sudo podman image list --filter=label=containers.bootc=1
```

See [man bootc switch](https://bootc.dev/bootc/man/bootc-switch.8.html) for more info.

```
sudo bootc switch --transport containers-storage localhost/myimage:latest
```

and reboot your system!

## Building and Running Virtual Machines and ISOs

The below commands all build QCOW2 images. To produce or use a different type of image, substitute in the command with that type in the place of `qcow2`. The available types are `qcow2`, `iso`, and `raw`.

### `just build-qcow2`

Builds a QCOW2 virtual machine image.

```bash
just build-qcow2 $target_image $tag
```

### `just rebuild-qcow2`

Rebuilds a QCOW2 virtual machine image.

```bash
just rebuild-vm $target_image $tag
```

### `just run-vm-qcow2`

Runs a virtual machine from a QCOW2 image.

```bash
just run-vm-qcow2 $target_image $tag
```

### `just spawn-vm`

Runs a virtual machine using systemd-vmspawn.

```bash
just spawn-vm rebuild="0" type="qcow2" ram="6G"
```

## File Management

### `just check`

Checks the syntax of all `.just` files and the `Justfile`.

### `just fix`

Fixes the syntax of all `.just` files and the `Justfile`.

### `just clean`

Cleans the repository by removing build artifacts.

### `just lint`

Runs shell check on all Bash scripts.

### `just format`

Runs shfmt on all Bash scripts.

## Additional resources

For additional driver support, ublue maintains a set of scripts and container images available at [ublue-akmod](https://github.com/ublue-os/akmods). These images include the necessary scripts to install multiple kernel drivers within the container (Nvidia, OpenRazer, Framework...). The documentation provides guidance on how to properly integrate these drivers into your container image.

## Community Examples

These are images derived from this template (or similar enough to this template). Reference them when building your image!

- [m2Giles' OS](https://github.com/m2giles/m2os)
- [bOS](https://github.com/bsherman/bos)
- [Homer](https://github.com/bketelsen/homer/)
- [Amy OS](https://github.com/astrovm/amyos)
- [VeneOS](https://github.com/Venefilyn/veneos)
