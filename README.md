# DotConfig feat. Santa Claus

## Usage

### Installation

Add below to the `/etc/zsh/zshenv`, as well as installing zsh (run `sudo apt install zsh` or something).

```zshenv
ZDOTDIR=$HOME/.config/zsh
```

Then run `cd $HOME/.config` on your shell to move to the working dir.

After the setup of ssh for github, run some commands below.

Do not forget to save backups just in case.

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

### Additional Installation

Fully to use the settings, install below all.

- bat
- eza
- sheldon
- neovim>=0.12
- starship
- Source Han Code JP

