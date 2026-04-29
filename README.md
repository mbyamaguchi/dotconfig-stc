# DotConfig feat. STC

## Usage

### Installation

Firstly, install zsh (run `sudo apt install zsh` or something else) and change your default shell to the zsh (consider to run `chsh -s /bin/zsh`).

Next add below to the bottom of `/etc/zsh/zshenv`
```zshenv
ZDOTDIR=$HOME/.config/zsh
```

Then run `cd $HOME/.config` on your shell to move to the working dir.

After setting up ssh for your github account, run some commands below.

Do not forget to save backups like what you want.

```sh
git init
git remote add origin git@github.com:mbyamaguchi/dotconfig-stc.git
git fetch
git checkout main
```

Finally, run:

```sh
exec $SHELL
```

to apply the changes.

### Additional Installation

Fully to use the settings, install below all.

- bat
- eza
- sheldon
- neovim>=0.12
- starship
- Source Han Code JP
- dropbox : see the website `dropbox.com/ja/install-linux`
- pixi (package manager for python)
- uv 
