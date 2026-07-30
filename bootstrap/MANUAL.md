# bootstrap 操作マニュアル

この `~/.config` を Ubuntu マシン上で再現し、pin されたバージョンを維持するための手引き。
設計の背景と「なぜそうしたか」は [README.md](README.md)（英語）にある。こちらは操作の手引き。

---

## 1. 覚えるコマンドは 3 つ

```sh
~/.config/bootstrap/bs.sh          # 環境を再現・修復する（冪等。何度でも実行して良い）
~/.config/bootstrap/bs.sh update   # 全バージョンを最新にする → git diff を見て commit
~/.config/bootstrap/bs.sh doctor   # 今のマシンが manifest とどこで違うかを表で出す
```

補助として `bs.sh list`（ステップ一覧）がある。

**原則**: `bs.sh` は **commit された manifest に書いてあるものしか入れない**。
バージョンが動くのは `bs.sh update` を実行したときだけ。勝手に上がらない。

---

## 2. 新規マシンのセットアップ

```sh
# 1. 最小の足場（これだけは手で入れる）
sudo apt update && sudo apt install -y git zsh

# 2. ~/.config をこの repo にする
cd "$HOME/.config"
git init
git remote add origin git@github.com:mbyamaguchi/dotconfig-stc.git
git fetch
git checkout main

# 3. あとはこれ 1 つ
./bootstrap/bs.sh

# 4. 新しいシェルへ
exec zsh
```

`bs.sh` は途中で 1 度だけ sudo のパスワードを聞き、以降は無人で走る（バックグラウンドで
sudo のタイムスタンプを維持している）。所要時間は回線次第で 10〜20 分。
neovim のプラグイン復元とパーサーのビルドが大半を占める。

終わったら `bs.sh doctor` で確認する。

### sudo が使えない環境で

```sh
./bootstrap/bs.sh --no-sudo
```

root が必要な 7 ステップ（`apt:base` `apt:cpp` `apt:media` `gh` `locale` `zdotdir` `shell`）は
飛ばされ、それ以外はすべて実行される。最後に「後で流すコマンド」が表示される。

**`sudo ./bootstrap/bs.sh` としてはいけない。** `/root/.local` に入ってしまうため、
スクリプトが検知して拒否する。個々のコマンドが自分で昇格する設計。

---

## 3. 日常操作

### バージョンを上げる

```sh
bs.sh update          # manifest を書き換える
git diff              # 何が上がるかを確認
git commit -am 'Bump pins'
bs.sh                 # 適用
```

一部だけ上げたいとき:

```sh
bs.sh update --check          # 書き換えず「何が古いか」だけ表示（古いものがあれば exit 1）
bs.sh update starship         # 1 つだけ
bs.sh update starship uv      # 複数
```

`update` が参照する上流は 5 系統（GitHub Releases / nodejs.org / npm registry / go.dev /
`git ls-remote`）。並行取得するので全体で数秒。

**上げないもの**（意図的）:
- `rust` — `stable` 追従。repo は rustc のバージョンに依存しない
- `yt-dlp` — `latest` 固定。古い yt-dlp はサイト変更で動かなくなるので、ここでは追従が正解

### 点検する

```sh
bs.sh doctor          # 差分があれば exit 1
bs.sh doctor --json   # 機械可読（将来 systemd timer で回す用）
```

`STATUS` の意味:

| | |
|---|---|
| `OK` | manifest どおり |
| `WARN` | 違っている。`bs.sh` で直る可能性が高い |
| `FAIL` | 壊れている。放置すると使えない（locale・ZDOTDIR・git の identity など） |
| `INFO` | 参考情報。exit code には影響しない |

### 一部だけ入れ直す

```sh
bs.sh --only tool:              # tools.tsv の全ツール
bs.sh --only tool:fzf           # 1 つだけ
bs.sh --only nvim,nvim:plugins  # neovim 関連だけ
bs.sh --skip nvim:plugins       # 遅いものを飛ばす
bs.sh --dry-run                 # 何が起きるか表示するだけ。何も変更しない
```

ID は前方一致。存在しない ID を指定した場合は「何も実行しなかった」ことを
明示して exit 2 で終わる（タイプミスが成功に見えないようにしている）。

---

## 4. ツールを追加する

GitHub Releases のバイナリなら **`tools.tsv` に 1 行足すだけ**。
ステップの登録・`--only` の ID・`doctor` の行・`update` 対応はすべてそこから生成される。

```
name	ref	min	repo	asset	install
```

| 列 | 意味 |
|---|---|
| `name` | コマンド名。ステップ ID は `tool:<name>` になる |
| `ref` | **上流のリリースタグをそのまま**。`v` の有無は上流に合わせる（sheldon と uv は `v` なし）。`latest` で毎回最新 |
| `min` | 設定が要求する下限。`ref=latest` のときのガード。不要なら `-` |
| `repo` | `owner/name` |
| `asset` | リリースのファイル名。プレースホルダは `tools.tsv` の冒頭に一覧がある |
| `install` | `bin:名前,名前` または `font` |

追加したら確認:

```sh
bs.sh --dry-run --only tool:<name>   # 生成される URL が実際のアセット名と一致するか
bs.sh --only tool:<name>
cd bootstrap/tool && go test ./...   # manifest の形式チェックが走る
```

「ダウンロードして展開する」以上のことが必要なものは `steps/` にファイルを足す。
関数 1 つと `register` 1 行が最小構成 — 一番小さい例は `steps/30-zdotdir.sh`。

---

## 5. どのファイルが何を持っているか

```
bootstrap/
├── bs.sh          エントリポイント。引数解析・ステップ実行・install
├── lib.sh         共有ヘルパー（ログ・バージョン・ダウンロード・PATH）
├── tools.tsv      ★ GitHub Releases のバイナリの pin
├── apt.tsv        apt パッケージ（グループ別。版は pin しない）
├── runtimes.tsv   ★ nvim / node / pnpm / go / rust
├── steps/         1 ファイル 1 関心事。ファイル名の番号順に実行
├── tool/          doctor と update（Go・依存ゼロ）
├── cleanup.sh     読まれていないファイルの退避（--yes 必須。削除ではなく移動）
└── test/          lint.sh と container.sh
```

repo 側で pin されているものは他に 2 つ:

| | |
|---|---|
| `nvim/lazy-lock.json` | neovim プラグイン 34 個の commit。**この repo で最も価値の高い pin** |
| `sheldon/plugins.toml` の `rev` | zsh プラグイン 5 個の commit |

### バージョンを pin していないもの（意図的）

- **apt パッケージ** — Ubuntu の archive は古い版を削除するので、`ripgrep=14.1.1-1` のような
  pin は noble-updates がパッケージを差し替えた瞬間に壊れる。pin はむしろ再現性を下げる。
  `apt.tsv` が固定しているのは**集合**であってバージョンではない。
- **rust** と **yt-dlp** — 上記「上げないもの」参照。

---

## 6. 手作業が必要なこと

### WSL: Cica フォントを Windows 側にも入れる

Windows のターミナルは Linux 側のフォントを読まない。`bs.sh` の実行後に表示される
パス（`~/.local/share/fonts` と Windows の Downloads フォルダ）を使って、
TTF をコピーしてダブルクリックでインストールし、ターミナルのフォントに指定する。

`reg.exe` 経由のレジストリ操作は自動化していない。

### `~/.gitconfig`（このマシンでは整理済み）

`~/.gitconfig` は `~/.config/git/config` より**後に読まれて勝つ**。かつてそこにしか
無かった `user.signingkey` / `commit.gpgsign` / credential helper は
`git/config.local` へ移し、`~/.gitconfig` 自体は
`~/.local/share/dotconfig-legacy/<日時>/` へ退避した。コミットアドレスは
`github@mbmsky.dev` のまま変わっていない（両方に同じ値が入っていた）。

新しいマシンで同じ状態にするには、`bs.sh` が作る `config.local` に signingkey と
`commit.gpgsign`、それに credential helper を書く。**`gh auth setup-git` は使わない**:
`~/.gitconfig` が無いと git のグローバル設定は `~/.config/git/config`
——つまり**追跡されているファイル**——になり、そこへ書き込まれてしまう。

```sh
git config --file ~/.config/git/config.local user.signingkey <KEYID>
git config --file ~/.config/git/config.local commit.gpgsign true
git config --file ~/.config/git/config.local --add \
  credential.https://github.com.helper '!/usr/bin/gh auth git-credential'
```

確認は `git config --show-origin --get user.email` で `config.local` が出ること、
署名は捨てリポジトリで `git commit --allow-empty` して
`git log --show-signature -1` が `Good signature` を出すこと。
`bs.sh doctor` の `git:home` 行がこの状態を見張っている。

### 読まれていないファイルの掃除

```sh
bootstrap/cleanup.sh          # 何が対象かを表示するだけ
bootstrap/cleanup.sh --yes    # 実行
```

削除ではなく `~/.local/share/dotconfig-legacy/<日時>/` へ移動するので、戻せる。
対象は `~/.zshrc`（`ZDOTDIR` があるので**読まれていない**）、`~/.zprofile`、
`~/.config/nvim.bak/`、空ディレクトリ、壊れた nix の symlink、未使用の `mise` など。

`~/.gitconfig` `~/dotfiles/` `~/bootstrap/` は判断が必要なので対象外にしてある。

---

## 7. トラブルシューティング

| 症状 | 原因と対処 |
|---|---|
| `doctor` が `shim:fd` / `shim:bat` を WARN | apt ステップが未実行。`bs.sh --only apt:base`（sudo 必要） |
| `doctor` が `tool:X` を「`/usr/bin` から来ている」と言う | apt 版が pin 版を覆っている。`bs.sh --only tool:X` で `~/.local/bin` に入れ直す |
| `doctor` が `node` の alias 不一致を WARN | `.zshenv` は `$NVM_DIR/alias/default` を glob するので、**新しいシェルが別の node を掴む**。`bs.sh --only node` |
| `doctor` が `nvim:parsers` を WARN | `tree-sitter` CLI が無いとパーサーは 1 つもビルドされない。`bs.sh --only pnpm` で入れた後、`bs.sh --only nvim:plugins` |
| `doctor` が `node:tree-sitter` を「PATH にあるが動かない」と WARN | npm の `tree-sitter-cli` は JS ラッパーだけで、実体は postinstall が落としてくる。pnpm 10 以降は未承認パッケージの build script を実行しないため、**動かないラッパーだけが PATH に残る**（症状は毎回 Node の `ENOENT`）。`bs.sh --only pnpm` が `--allow-build` 付きで入れ直す |
| `doctor` / `update` が「Go が必要」と言う | この 2 つは Go 製。`bs.sh --only go` を先に実行する |
| `locale` が FAIL | すべてのサブプロセスが `LC_CTYPE` の警告を出す状態。`bs.sh --only locale`（sudo 必要）。root が無い場合は `$XDG_DATA_HOME/locale` に自前生成し、`.zshenv` が `LOCPATH` 経由で拾う |
| `zdotdir` が FAIL | zsh がこの repo を読んでいない。`bs.sh --only zdotdir`（sudo 必要） |
| プロンプトが崩れた / 補完が壊れた | zsh プラグインの revision がずれている可能性。`bs.sh doctor` の `zsh:plugins` を見て `sheldon lock` |
| neovim のプラグインが変わってしまった | `bs.sh --only nvim:plugins` が lockfile の revision へ**戻す**（`Lazy! restore`） |
| `bs.sh` の実行が途中で失敗した | 1 ステップの失敗で全体は止まらない。最後のサマリに失敗したステップ名と再実行コマンドが出る |

### 変更を一切したくない確認

```sh
bs.sh --dry-run                    # 変更コマンドを表示するだけ
bs.sh --dry-run --arch aarch64     # 別アーキテクチャでの挙動
bs.sh update --check               # 上流との差分だけ
```

---

## 8. 既知の限界

- **Mason が入れる LSP サーバーはバージョン固定されていない。** `mason.nvim` に lockfile が
  無いため、`lua/config/plugins/lsp.lua` の `ensure_installed` はその日のレジストリの版を入れる。
  固定するなら `"lua_ls@3.7.4"` 形式か `mason-lock.nvim` の導入が必要。
  Treesitter のパーサーは `lazy-lock.json` の `nvim-treesitter` の commit からビルドされるので、
  実質的には固定されている。
- **`run` と `check` が別言語にある。** ステップのインストールは `steps/*.sh`、その検証は
  `tool/doctor.go`。`tools.tsv` 由来の行は両方が manifest から生成されるので影響しないが、
  個別ステップ 8 個は直す場所が 2 ファイルになる。
- **x86_64 と aarch64 以外では、ビルド済みバイナリを要するステップが SKIP される。**
  404 で落ちるのではなく理由を表示してスキップし、全体は成功扱いになる。

---

## 9. テスト

```sh
bootstrap/test/lint.sh         # bash -n / shellcheck / gofmt / go vet / go test
bootstrap/test/container.sh    # クリーンな ubuntu:24.04 でフル実走（--fast で高速化）
```

`container.sh` は `git archive HEAD` をコンテナに流し込む（**追跡ファイルだけ**なので
gh のトークンや履歴はコンテナに入らない）。sudo 可能な非 root ユーザーで実行するので
root 必須ステップも本当に走る。検証内容:

- `--dry-run` が何も変更しないこと
- 未対応アーキテクチャが SKIP して成功すること
- Go が無い状態の `doctor` が「先に Go を入れろ」と言うこと
- フルインストールが失敗ゼロで通ること
- **2 回目の実行でダウンロードが 0 件**であること（冪等性）
- **追跡ファイルが 1 つも変更されないこと**
- zsh が無出力で起動すること
- `fzf --zsh` / starship / zoxide / eza / stylua / nvim が解決すること
- `doctor` が通ること

`lint.sh` は shellcheck が未インストールならコンテナ版にフォールバックする（未整備の
マシンでこそ使いたいので）。Go ツールが **Ubuntu 24.04 の Go 1.22 でビルドできること**も
確認する — 新規マシンが持っているのはそれだから。
