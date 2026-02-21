# chawan 設計ドキュメント

## 概要

tmux popupでsession/window/paneの新規作成・削除・検索・選択を統一的に行うプラグイン。
既存のtmux-fzfは「メニュー選択→操作選択→対象選択」の3段階で冗長、tmux-sessionxはsession管理のみという課題がある。
chawanは**1画面・モード切替方式**で全リソースを統一的に管理し、UI/UXの良さ・操作の統一感・軽量さで差別化する。

## 技術選定

| 項目 | 選定 | 理由 |
|------|------|------|
| 言語 | Bash | ポータビリティ最優先。既存plugin（tmux-fzf, tmux-sessionx）の主流 |
| fzf統合 | `fzf --tmux` | fzf 0.63+組み込み。`fzf-tmux`ラッパーより直感的で、tmux外では自動無視される安全性 |
| プラグイン管理 | TPM対応 | `set -g @plugin 'wasabi0522/chawan'` でインストール可能 |
| ライセンス | MIT | Bash製OSSプラグインの標準 |

### 要件

- tmux 3.3+
- fzf 0.63+（`--tmux` popup + `--footer` 対応）

## ディレクトリ構造

```
chawan/
├── chawan.tmux              # TPMエントリーポイント
├── scripts/
│   ├── helpers.sh           # 共通ユーティリティ
│   ├── chawan-main.sh       # fzf起動・全キーバインド定義（コア）
│   ├── chawan-list.sh       # session/window/pane リスト生成
│   ├── chawan-preview.sh    # プレビュー表示
│   ├── chawan-action.sh     # switch/delete アクションディスパッチャ
│   ├── chawan-create.sh     # 新規作成
│   └── chawan-rename.sh     # リネーム
├── tests/
│   ├── helpers.bats         # helpers.sh のテスト
│   ├── chawan-list.bats     # chawan-list.sh のテスト
│   ├── chawan-action.bats   # chawan-action.sh のテスト
│   └── test_helper.bash     # テスト用共通ヘルパー
├── docs/
│   └── design.md            # 本ドキュメント
├── Makefile                 # タスクランナー (make test, make lint, etc.)
├── README.md
├── LICENSE
└── .github/workflows/ci.yml # ShellCheck + shfmt + bats-core + kcov
```

### ファイル間依存関係

```
chawan.tmux
  └─> scripts/helpers.sh  (設定読み込み)

scripts/chawan-main.sh  (fzf起動)
  ├─> scripts/helpers.sh        (source)
  ├─> scripts/chawan-list.sh    (reload)
  ├─> scripts/chawan-preview.sh (--preview)
  ├─> scripts/chawan-action.sh  (become/reload-sync: switch/delete)
  ├─> scripts/chawan-create.sh  (execute/reload-sync: new)
  └─> scripts/chawan-rename.sh  (execute: rename)
```

## UIフロー

### 設計思想: 1画面・モード切替方式

tmux-fzfの3段階問題を解決するため、**1つのfzfインスタンス内でモード切替**を行う。
fzfの`reload()`アクションでリスト内容を動的に差し替える。

### 画面イメージ

```
[prefix + S] -> popup起動 (デフォルト: Sessionモード)

╭─────────────────────── chawan ─────────────────────────╮
│  Session   Window   Pane     Tab/S-Tab: switch mode   │  <- header
├──────────────────────────┬── Preview: my-project ─────┤
│  Session> _        3/3   │ $ vim src/main.rs          │
│ ▍* my-project    3w     │ ~                          │
│   dotfiles      1w      │ ~                          │
│   work/api      2w      │                            │
├──────────────────────────┴────────────────────────────┤
│  enter:switch  C-o:new  C-d:del  C-r:rename           │  <- footer
╰───────────────────────────────────────────────────────╯

※ "Session" は reverse属性 (\e[1;7m) で強調 — テーマ非依存
※ 選択行全体がハイライト (--highlight-line)
※ マッチ件数 "3/3" は右端表示 (--info right)
※ プレビューラベル "Preview: my-project" はフォーカス連動で動的変更
※ ヘッダー内のタブ名はマウスクリックでも切替可能 (click-header)
※ 起動時は現在セッションにカーソルが自動移動 (result:pos)

Tab -> Windowタブに切替:

╭─────────────────────── chawan ─────────────────────────╮
│   Session   Window   Pane     Tab/S-Tab: switch mode  │
├──────────────────────────┬── Preview: my-project:0 ───┤
│  Window> _         5/5   │ $ vim src/main.rs          │
│ ▍* my-project:0  vim    │ ~                          │
│   my-project:1  zsh     │ ~                          │
│   dotfiles:0    zsh     │                            │
├──────────────────────────┴────────────────────────────┤
│  enter:switch  C-o:new  C-d:del  C-r:rename           │
╰───────────────────────────────────────────────────────╯

※ アクティブタブが "Window" に切替わり、プレビューラベルも連動
```

アクティブタブはANSI reverse属性（`\e[1;7m` = bold + reverse）で強調表示する。
ターミナルのfg/bgを反転するため、ダークテーマ・ライトテーマを問わず正しく動作する。
fzfの`--header`にタブバーを描画し`change-header()`で切替時に更新、`--footer`にキーヒントを固定表示する。

### ユーザー操作フロー

1. **起動**: `prefix + S` を押す
2. **初期表示**: Sessionタブがアクティブ。全セッション一覧。現在のセッションに `*` マーカー
3. **fuzzy検索**: 入力でリアルタイムフィルタリング
4. **タブ切替**: `Tab`で次のタブ、`Shift-Tab`で前のタブへ（Session -> Window -> Pane -> Session ...）。リスト瞬時差替え（`reload()` + `change-header()` + `change-preview()`）。フッターは静的なため更新不要
5. **操作実行**: `Enter`でswitch、`Ctrl-O`で新規作成、`Ctrl-D`で削除、`Ctrl-R`でリネーム
6. **終了**: 操作完了後に自動closeまたは`Escape`でキャンセル

## キーバインド設計

### tmux側トリガー

| キー | 動作 | 設定オプション |
|------|------|---------------|
| `prefix + S` | chawan起動（Sessionモード） | `@chawan-key`（デフォルト: `S`） |

### popup内キーバインド（全モード共通）

| キー | 動作 | 説明 |
|------|------|------|
| `Tab` | 次のタブ | Session -> Window -> Pane -> Session ... |
| `Shift-Tab` | 前のタブ | 逆順でタブ切替 |
| `Enter` | switch/select | 選択した対象に切り替え |
| `Ctrl-O` | New（新規作成） | 現在のモードに応じた新規作成 |
| `Ctrl-D` | Delete（削除） | 選択項目を削除してリストをreload-sync |
| `Ctrl-R` | Rename（リネーム） | 選択項目のリネーム（execute経由で名前入力後リスト更新） |
| `Escape` | キャンセル | popupを閉じる |
| マウスクリック | タブ切替 | ヘッダー内のタブ名クリックでモード切替 |

## リスト表示フォーマット

各行は `{ID}\t{表示文字列}` の2フィールド構成。fzfに`--delimiter '\t'`と`--with-nth=2..`を指定し、ID列を非表示にする。
`{1}`でアクション時にIDを取得。

表示文字列は`printf`の固定幅フォーマット（`%-N.Ns`）でパディング+切り詰めした単一文字列とし、
セッション名やウィンドウ名の長さに依存しない整列された一覧表示を実現する。
`%-25.25s`は最小25文字にパディングし、最大25文字で切り詰める。
表示部分に内部タブは含まない。

各モードの出力先頭行にはカラムヘッダー行を含む。ヘッダー行は空のID + タブ + カラム名の形式で、
fzfの`--header-lines 1`により選択不可の固定ヘッダーとして表示される。

### 生成方式

tmuxの`-F`で構造化データをタブ区切り出力し、`awk`で固定幅に整形する:

```
tmux list-* -F '{id}\t{raw fields...}'  →  awk で printf 整形  →  '{id}\t{formatted display}'
```

### Sessionモード

```
内部形式:  {session_name}\t{表示文字列}
ヘッダー:  \t   NAME(25文字幅)  WIN
表示:      [marker]  name(25文字幅)  Nw  [attached]

例:
                \t   NAME                       WIN
prezto          \t   prezto                      3w
wasabi0522/dashi\t * wasabi0522/dashi             3w  (attached)
```

生成コマンド:
```bash
printf '\t   %-25.25s  %s\n' "NAME" "WIN"
tmux list-sessions -F '#{session_name}\t#{?session_attached,1,0}\t#{session_windows}' |
  awk -F'\t' '{
    m = ($2 == "1") ? "*" : " "
    att = ($2 == "1") ? "  (attached)" : ""
    printf "%s\t%s  %-25.25s  %sw%s\n", $1, m, $1, $3, att
  }'
```

### Windowモード

```
内部形式:  {session}:{window_index}\t{表示文字列}
ヘッダー:  \t   ID(25文字幅)  NAME(15文字幅)  PANE  PATH
表示:      [marker]  id(25文字幅)  window_name(15文字幅)  Np  path

例:
                  \t   ID                          NAME             PANE  PATH
prezto:0          \t   prezto:0                    zsh              1p  ~/dotfiles
wasabi0522/dashi:0\t * wasabi0522/dashi:0          vim              1p  ~/ghq/.../chawan
```

生成コマンド:
```bash
printf '\t   %-25.25s  %-15.15s  %-4s  %s\n' "ID" "NAME" "PANE" "PATH"
tmux list-windows -a -F "#{session_name}:#{window_index}\t#{?window_active,#{?session_attached,1,0},0}\t#{window_name}\t#{window_panes}\t#{s|$HOME|~|:pane_current_path}" |
  awk -F'\t' '{
    m = ($2 == "1") ? "*" : " "
    printf "%s\t%s  %-25.25s  %-15.15s  %sp  %s\n", $1, m, $1, $3, $4, $5
  }'
```

### Paneモード

```
内部形式:  {session}:{window}.{pane}\t{表示文字列}
ヘッダー:  \t   ID(25文字幅)  CMD(12文字幅)  SIZE(10文字幅)  PATH
表示:      [marker]  id(25文字幅)  command(12文字幅)  WxH(10文字幅)  path

例:
                    \t   ID                          CMD           SIZE        PATH
prezto:0.0          \t   prezto:0.0                  zsh           212x103     ~/dotfiles
wasabi0522/dashi:0.0\t * wasabi0522/dashi:0.0        claude        159x40      ~/ghq/.../chawan
```

生成コマンド:
```bash
printf '\t   %-25.25s  %-12.12s  %-10s  %s\n' "ID" "CMD" "SIZE" "PATH"
tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}\t#{?pane_active,#{?session_attached,1,0},0}\t#{pane_current_command}\t#{pane_width}x#{pane_height}\t#{s|$HOME|~|:pane_current_path}" |
  awk -F'\t' '{
    m = ($2 == "1") ? "*" : " "
    printf "%s\t%s  %-25.25s  %-12.12s  %-10s  %s\n", $1, m, $1, $3, $4, $5
  }'
```

### パス短縮

tmuxの`s/`フォーマット修飾子でパス短縮: `#{s|$HOME|~|:pane_current_path}`。
外部コマンド（`sed`）不要で、`tmux list-*`のフォーマット文字列内で直接処理する。
なお`s/`修飾子は`$HOME`のシェル変数展開が必要なため、フォーマット文字列はダブルクォートで囲む。

## 核心設計: タブ切替とモード状態管理

### fzf起動オプション

```bash
fzf --tmux "center,$popup_width,$popup_height" \
  --layout reverse --header-first \
  --border rounded --border-label ' chawan ' \
  --header "$initial_header" --header-border line \
  --footer "$footer" \
  --prompt '> ' \
  --ansi --highlight-line --info right \
  --pointer '▍' \
  --color 'header:bold,footer:dim,pointer:bold,prompt:bold' \
  --preview "$SCRIPTS_DIR/chawan-preview.sh {1}" \
  --preview-window "${preview_position},border-left" \
  --header-lines 1 \
  --with-nth '2..' --delimiter '\t' \
  --bind 'esc:abort' \
  --bind "result:pos($current_pos)" \
  ...
```

**注**: プレビュースクリプトはモード引数を受け取らず、ターゲットIDの形式（`:`+`.`含む→pane、`:`含む→window、それ以外→session）から自動検出する。プロンプトは全モード共通で `> ` を使用する。

### タブバーの描画

fzfの`--header`にタブバーを描画する。アクティブタブはANSI reverse属性（`\e[1;7m`）で強調表示する。
reverse属性はターミナルのfg/bgを反転するため、ダークテーマ・ライトテーマを問わず正しく動作する。

```bash
# helpers.sh 内のタブバー生成関数
make_tab_bar() {
  local active="$1"
  local hl=$'\e[1;7m' rs=$'\e[0m'
  local s=" Session " w=" Window " p=" Pane "
  [[ "$active" == "session" ]] && s="${hl}${s}${rs}"
  [[ "$active" == "window" ]] && w="${hl}${w}${rs}"
  [[ "$active" == "pane" ]] && p="${hl}${p}${rs}"
  printf ' %s  %s  %s' "$s" "$w" "$p"
}
```

chawan-main.shでヘッダー文字列に右寄せのTab/S-Tabヒントを付加し、3モード分のヘッダーを事前生成・export する。ヒント付加はターミナル幅とプレビュー幅から計算したパディングで行う。

chawan-main.shで3モード分のヘッダー文字列を事前生成し変数に保持する。
また、起動時に現在セッションの位置を算出し`result:pos()`で初期カーソルを合わせる:

```bash
HEADER_SESSION="$(make_tab_bar session)${padding}${hint}"
HEADER_WINDOW="$(make_tab_bar window)${padding}${hint}"
HEADER_PANE="$(make_tab_bar pane)${padding}${hint}"
export HEADER_SESSION HEADER_WINDOW HEADER_PANE

# 初期リスト生成・現在アイテムの行位置を算出
initial_list=$($SCRIPTS_DIR/chawan-list.sh "$default_mode")
current_pos=$(find_current_pos "$default_mode" "$initial_list")
```

### タブ切替・アクションの実装

タブ切替とアクション操作は `chawan-fzf-action.sh` に分離し、fzfの `transform` バインドから外部スクリプトとして呼び出す。

**モード判定**: `$FZF_PROMPT` ではなく、フォーカス中アイテムのID形式（`{1}`）から判定する。`mode_from_id` 関数（helpers.sh）が `:`+`.`含む→pane、`:`含む→window、それ以外→session と返す。これにより、全アクションで統一的にモードを判定でき、プロンプト文字列への依存を排除する。セッション名に`.`が含まれる場合（例: `my.dotfiles`）も正しくsessionと判定される。

**シェルインジェクション防止**: fzfアクション文字列にターゲットIDを埋め込む際、`printf '%q'` でシェルエスケープを行う。これにより、セッション名に空白やシェルメタ文字が含まれる場合でも安全に動作する。

**注**: `Tab`をモード切替に使用するため、fzfデフォルトの複数選択トグルは無効になる。chawanは単一選択UIとして設計しているため、この制約を許容する。

```bash
# chawan-main.sh 側のバインド定義
--bind "tab:transform:$SCRIPTS_DIR/chawan-fzf-action.sh tab {1}"
--bind "shift-tab:transform:$SCRIPTS_DIR/chawan-fzf-action.sh shift-tab {1}"
--bind "click-header:transform:$SCRIPTS_DIR/chawan-fzf-action.sh click-header \$FZF_CLICK_HEADER_WORD"
--bind "${bind_delete}:transform:$SCRIPTS_DIR/chawan-fzf-action.sh delete {1}"
--bind "${bind_new}:transform:$SCRIPTS_DIR/chawan-fzf-action.sh new {1}"
--bind "${bind_rename}:transform:$SCRIPTS_DIR/chawan-fzf-action.sh rename {1}"

# Enter: fzfの標準accept動作で選択行を出力。main()で受け取りmode_from_idで判定してswitch実行
```

chawan-fzf-action.sh は各アクションに応じたfzfアクション文字列を出力する:
- **tab/shift-tab**: `reload(chawan-list.sh $next_mode)+change-prompt(> )+change-header($HEADER_*)+first`
- **click-header**: クリックされた単語（Session/Window/Pane）に応じて上記と同様
- **delete**: `reload-sync(chawan-action.sh delete $mode $escaped_target; chawan-list.sh $mode)`
- **new (session)**: `execute(chawan-create.sh session)+abort`
- **new (window/pane)**: `reload-sync(chawan-create.sh $mode $escaped_target; chawan-list.sh $mode)`
- **rename**: `execute(chawan-rename.sh $mode $escaped_target)+reload(chawan-list.sh $mode)`

## プレビュー機能

`tmux capture-pane -ep -t {target}`で選択中リソースのペイン内容を表示。

| モード | プレビュー内容 | コマンド |
|--------|-------------|---------|
| Session | セッションのアクティブペイン | `tmux capture-pane -ep -t {name}:` |
| Window | ウィンドウのアクティブペイン | `tmux capture-pane -ep -t {sess}:{idx}` |
| Pane | 指定ペインの内容 | `tmux capture-pane -ep -t {sess}:{idx}.{pane}` |

### 動的プレビューラベル

`focus`イベントで`transform-preview-label`を使用し、フォーカス中アイテムの情報をプレビューウィンドウのボーダーラベルに表示する:

```bash
--preview-window 'right,50%,border-left'
--preview-label ''
--bind 'focus:transform-preview-label:echo " Preview: {2} "'
```

タブ切替時のプレビューラベルは、新リストの最初のアイテムにフォーカスが移った時点で`focus`イベントにより自動更新される。

## 操作一覧

### Session操作

| 操作 | キー | tmuxコマンド | 備考 |
|------|------|-------------|------|
| Switch | `Enter` | `tmux switch-client -t {name}` | |
| New | `Ctrl-O` | `tmux new-session -d -s {name} && tmux switch-client -t {name}` | execute経由で名前入力。作成+switch後にpopup終了 |
| Delete | `Ctrl-D` | `tmux kill-session -t {name}` | 現在セッション削除時は先に`switch-client`で別セッションに切り替え。最後のセッション削除時はtmuxサーバーが終了する |
| Rename | `Ctrl-R` | `tmux rename-session -t {name} {new}` | execute経由で名前入力後リスト更新 |

### Window操作

| 操作 | キー | tmuxコマンド | 備考 |
|------|------|-------------|------|
| Switch | `Enter` | `tmux switch-client -t {sess} && tmux select-window -t {target}` | |
| New | `Ctrl-O` | `tmux new-window -t {sess}:` | フォーカス中のアイテムのセッションに作成 |
| Delete | `Ctrl-D` | `tmux kill-window -t {target}` | |
| Rename | `Ctrl-R` | `tmux rename-window -t {target} {new}` | execute経由で名前入力後リスト更新 |

### Pane操作

| 操作 | キー | tmuxコマンド | 備考 |
|------|------|-------------|------|
| Switch | `Enter` | `tmux switch-client + select-window + select-pane` | |
| New | `Ctrl-O` | `tmux split-window -h -t {target}` | フォーカス中のペインと同じウィンドウに作成 |
| Delete | `Ctrl-D` | `tmux kill-pane -t {target}` | |
| Rename | `Ctrl-R` | `tmux select-pane -t {target} -T {title}` | execute経由でtitle入力後リスト更新 |

## 設定オプション

tmuxユーザーオプション（`@`prefix）経由で設定。

| オプション | デフォルト | 説明 |
|-----------|----------|------|
| `@chawan-key` | `S` | prefix後のトリガーキー |
| `@chawan-default-mode` | `session` | 起動時のデフォルトモード |
| `@chawan-popup-width` | `80%` | popup幅 |
| `@chawan-popup-height` | `70%` | popup高さ |
| `@chawan-preview` | `on` | プレビュー表示の有無 |
| `@chawan-preview-position` | `right,50%` | プレビュー位置とサイズ |
| `@chawan-bind-new` | `ctrl-o` | 新規作成キー |
| `@chawan-bind-delete` | `ctrl-d` | 削除キー |
| `@chawan-bind-rename` | `ctrl-r` | リネームキー |

tmux.confでの設定例:
```tmux
set -g @plugin 'wasabi0522/chawan'
set -g @chawan-key 'S'
set -g @chawan-default-mode 'session'
set -g @chawan-popup-width '80%'
set -g @chawan-popup-height '70%'
set -g @chawan-preview 'on'
```

## 各スクリプト詳細設計

### chawan.tmux（エントリーポイント）

TPMが`run-shell`で実行する。以下を行う:
1. `CURRENT_DIR`を算出（`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`）
2. fzf存在チェック（`command -v fzf`）
3. fzfバージョンチェック（0.63+必須。`fzf --version | grep -oE '[0-9]+\.[0-9]+'`でパース）
4. `@chawan-key`を読み込みキーバインド登録
5. `tmux bind-key "$key" run-shell -b "$CURRENT_DIR/scripts/chawan-main.sh"`

### scripts/helpers.sh

```bash
get_tmux_option()   # tmuxオプション値の取得（デフォルト値付き）
version_ge()        # バージョン比較 ($1 >= $2)。ドット区切りでメジャー・マイナーを数値比較
display_message()   # tmux display-messageでユーザーにメッセージ表示
mode_from_id()      # ターゲットID形式からモード判定（:+.→pane、:→window、それ以外→session）
make_tab_bar()      # 指定モードをANSI reverse属性で強調したタブバー文字列を生成
```

### scripts/chawan-main.sh（コア）

1. helpers.shをsource、全設定オプション読み込み
2. `SCRIPTS_DIR`を絶対パスで設定（`run-shell`実行時のカレントディレクトリが不定のため）
3. タブバー文字列（3モード分）を`make_tab_bar`で事前生成、初期プロンプト設定
4. 初期リストを`chawan-list.sh`で生成、現在セッションの行位置（`current_pos`）を算出
5. `fzf --tmux`を起動（オプション詳細は「fzf起動オプション」節参照）
6. 全`--bind`を設定:
   - `esc:abort` — Escapeで確実にpopup終了
   - `result:pos($current_pos)` — 起動時に現在アイテムにカーソルを自動移動
   - タブ切替/アクション: `transform` → `chawan-fzf-action.sh` 経由でfzfアクション文字列を生成
   - `click-header` — ヘッダー内のタブ名をマウスクリックでモード切替（`$FZF_CLICK_HEADER_WORD`で判定）
   - Enter: fzfの標準accept動作で選択行を出力し、`main()`側で`mode_from_id`によるモード判定＋switch実行
   - 削除操作は`reload-sync()`でイベントブロック、rename/createは`reload()`で継続

### scripts/chawan-list.sh

引数`$1`（session/window/pane）に応じて`tmux list-*`で構造化データを取得し、`awk`で固定幅に整形して出力。
パスはtmuxの`s/`フォーマット修飾子（`#{s|$HOME|~|:pane_current_path}`）で`~`に短縮。
各行は `{ID}\t{表示文字列}` の2フィールド構成。表示文字列は`printf`の`%-Ns`で固定幅パディングし、名前の長短に依存しないカラム揃えを実現する。

### scripts/chawan-fzf-action.sh

fzf bindの`transform`アクションから呼び出されるディスパッチャ。引数`$1`=action、`$2`=target IDを受け取り、fzfアクション文字列を標準出力に返す。ターゲットIDを`mode_from_id`でモード判定し、`printf '%q'`でシェルエスケープして安全にfzfアクション文字列に埋め込む。

### scripts/chawan-preview.sh

引数`$1`=targetで`tmux capture-pane -ep`を実行。ターゲットIDの形式からモードを自動検出する（セッション名にはコロンを含まないため、`:`なし→session、`:`あり→window/pane）。

### scripts/chawan-action.sh

引数`$1`=action（switch/delete）, `$2`=mode, `$3`=targetでディスパッチ。
switch時はモードに応じて`switch-client`→`select-window`→`select-pane`を連鎖。
delete時は安全ガードチェック後に`kill-*`を実行。

### scripts/chawan-create.sh

- Session: `execute()`内で`read -p`により名前入力→`new-session`→`switch-client`。fzfは`abort`で終了
- Window: フォーカス中のアイテムからセッション名を抽出し、そのセッションに即座に`new-window`。fzfは`reload`で継続
- Pane: フォーカス中のアイテムのターゲットに即座に`split-window -h`。fzfは`reload`で継続

### scripts/chawan-rename.sh

`execute()`内で`read -p`により新名称入力→`rename-session`/`rename-window`/`select-pane -T`。
完了後fzfに復帰し`reload()`でリスト更新。ユーザーが空入力でキャンセルした場合はリネームをスキップ。

## コーディング規約

既存tmux plugin（tmux-yank, tmux-pain-control, tmux-fzf）のコード調査に基づく。

### shebang・実行権限

- 全スクリプトに `#!/usr/bin/env bash` を記載
- `chawan.tmux` と `scripts/*.sh` は `chmod +x`（実行権限付与）が必要
  - `run-shell` で直接実行するため

### main()関数パターン

tmux-yank, tmux-pain-controlに倣い、エントリーポイントは`main()`関数で包む:

```bash
main() {
  # 処理
}
main
```

### ShellCheck ディレクティブ

`source`するスクリプトには`# shellcheck source=`ディレクティブを付与:

```bash
# shellcheck source=scripts/helpers.sh
source "$SCRIPTS_DIR/helpers.sh"
```

### .gitignore

```
coverage/
```

## 安全ガード

### 削除保護

- 現在接続中のセッションを削除する場合は、先に別セッションに切り替え（`switch-client -l`→`-n`フォールバック）てから`kill-session`を実行。他にセッションがない場合は切り替えに失敗するが、そのまま`kill-session`を実行しtmuxサーバーが終了する
- 最後のウィンドウ削除→セッション消滅、最後のペイン削除→ウィンドウ消滅の連鎖が発生するが、これは許容する
- `tmux kill-*`コマンドは`2>/dev/null`で存在しないターゲットのエラーを抑制

### 空リスト・空引数

- リスト生成が空を返した場合もfzfは正常動作する（空リストが表示される）
- 空リスト状態でアクションキーが押された場合、fzfの`{1}`は空文字列になる。全アクションスクリプトは第1引数が空の場合に即座に`return 0`する（`[[ -z "$target" ]] && return 0`）

### 特殊文字を含むターゲット名

- セッション名にスペース・シングルクォート・`$`・バッククォート等が含まれる場合に備え、tmuxコマンドへのターゲット引数は必ずダブルクォートで囲む: `tmux kill-session -t "$target"`
- `-t` オプションが次の引数をターゲット値として消費するため、`-` で始まるセッション名でもフラグとして誤解釈されない: `tmux kill-session -t "$target"`
- fzfアクション文字列にターゲットIDを埋め込む際は `printf '%q'` でシェルエスケープし、空白やメタ文字を含むセッション名でのシェルインジェクションを防止する

## 既知の検討事項

### execute()による対話入力

セッション新規作成とリネーム操作ではfzfの`execute()`アクションを使用してユーザー入力を受け付ける。
`execute()`はfzfを一時非表示にしてコマンドを実行し、完了後fzfに復帰する。
`fzf --tmux`のpopup内ではTTYが利用可能なため`read`による入力が動作する。

動作しない場合の代替案: `tmux command-prompt`を使用。

```bash
tmux command-prompt -p "New session name:" "new-session -d -s '%%' \; switch-client -t '%%'"
```

### セッション名のスラッシュ

`wasabi0522/dashi`のようにスラッシュを含むセッション名に対応。
タブ区切りの第1フィールドで取得するため、セッション名内のスラッシュに影響されない。

### リネーム・作成時の入力検証

`execute()`内の`read`で取得したユーザー入力に対して以下のバリデーションを行う:

- **空文字列**: リネーム/作成をスキップしてfzfに復帰（既存の設計通り）
- **既存名との重複**: `tmux has-session -t "$name" 2>/dev/null` で存在チェック。重複時はエラーメッセージを表示して再入力を促す
- **tmux禁止文字**: セッション名に `.`（ドット）、`:`（コロン）を含む場合はtmuxが拒否する。スクリプト側で事前チェックし、分かりやすいメッセージを表示する

### パス短縮の `s/` デリミタ

`#{s|$HOME|~|:pane_current_path}` でデリミタに `|` を使用している。
`$HOME` が `|` を含む場合（極めてまれ）パースが壊れる。
実運用上問題になる可能性は極めて低いが、万一の場合はデリミタを `#` 等に変更可能:
`#{s#$HOME#~#:pane_current_path}`。

### ターゲット消失（TOCTOU）

リスト表示後、ユーザーがアクションを実行するまでの間に、対象のセッション/ウィンドウ/ペインが別プロセスで削除される可能性がある。

- **delete**: `tmux kill-*` は存在しないターゲットに対してエラーを返すのみ（`2>/dev/null`で抑制済み）。`reload-sync` でリストが更新されるため、消失した項目は自然に消える
- **switch**: `tmux switch-client -t` が失敗した場合、`accept`でfzfは既に終了しているため、エラーメッセージがtmux status lineに一瞬表示されるが操作に影響しない。現在のセッション/ウィンドウには留まる
- **rename**: 対象が存在しない場合は `tmux rename-*` が失敗するのみ。`reload()` でリストが更新される

いずれもデータ損失やクラッシュのリスクはなく、許容可能な動作とする。

## テスト

### テストフレームワーク: bats-core

[bats-core](https://github.com/bats-core/bats-core)を使用。Bash用の最も普及したテストフレームワーク。

インストール:
```bash
brew install bats-core
```

### テスト対象と方針

| スクリプト | テスト方法 | 備考 |
|-----------|----------|------|
| `helpers.sh` | ユニットテスト | `get_tmux_option`, `version_ge`を純粋関数としてテスト |
| `chawan-list.sh` | ユニットテスト | `tmux`コマンドをモックしてリスト出力を検証 |
| `chawan-action.sh` | ユニットテスト | `tmux`コマンドをモックして呼び出し引数を検証 |
| `chawan-create.sh` | ユニットテスト | 同上 |
| `chawan-rename.sh` | ユニットテスト | 同上 |
| `chawan-preview.sh` | ユニットテスト | 同上 |
| `chawan-main.sh` | 手動テスト | fzfとの統合のため自動テスト困難。tmux内で実操作確認 |

### tmuxコマンドのモック方式

テスト用ヘルパー(`tests/test_helper.bash`)で`tmux`関数をモック化:

```bash
# tmuxコマンドの呼び出しを記録し、事前定義した出力を返す
tmux() {
  echo "$@" >> "$MOCK_TMUX_CALLS"
  case "$1 $2" in
    "list-sessions") cat "$MOCK_TMUX_OUTPUT" ;;
    "display-message") echo "$MOCK_DISPLAY_MESSAGE" ;;
    *) ;;
  esac
}
export -f tmux
```

### テスト実行・Lint・カバレッジ

Makefileで短いコマンドから実行する。

#### Makefile

```makefile
.PHONY: test lint fmt coverage

test:
	bats tests/

lint:
	shellcheck scripts/*.sh chawan.tmux
	shfmt -d -i 2 -ci scripts/*.sh chawan.tmux

fmt:
	shfmt -w -i 2 -ci scripts/*.sh chawan.tmux

coverage:
	ruby run_coverage.rb --bash-path "$$(command -v bash)" --root . -- bats tests/
```

#### コマンド一覧

| コマンド | 説明 |
|----------|------|
| `make test` | bats-coreで全テスト実行 |
| `make lint` | ShellCheck（静的解析）+ shfmt（フォーマットチェック） |
| `make fmt` | shfmtでフォーマット自動修正 |
| `make coverage` | bashcov（`run_coverage.rb`）でカバレッジ計測 |

#### ツール設定

| ツール | 役割 | 設定 |
|--------|------|------|
| ShellCheck | 静的解析（バグ・非推奨パターン検出） | デフォルト設定 |
| shfmt | フォーマット（インデント・スタイル統一） | `-i 2 -ci`（2スペースインデント、case文インデント） |
| [bashcov](https://github.com/infertux/bashcov) | カバレッジ計測 | `run_coverage.rb` でbats-core互換にパッチ適用。SimpleCov JSON出力 |

#### ローカル環境のセットアップ

```bash
brew install bats-core shellcheck shfmt
gem install bashcov
```

## CI

### GitHub Actions: `.github/workflows/ci.yml`

[sh-checker Action](https://github.com/luizm/action-sh-checker)でShellCheck + shfmtを統合実行し、bats-coreでテストを実行:

```yaml
name: CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: luizm/action-sh-checker@v2
        env:
          SHFMT_OPTS: "-i 2 -ci"
        with:
          sh_checker_shellcheck_disable: false
          sh_checker_shfmt_disable: false
          sh_checker_checkbashisms_enable: false
          sh_checker_scandir: "./scripts"
          sh_checker_additional_files: "chawan.tmux"
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      - name: Run tests
        run: bats tests/
```

## 実装順序（レイヤー構造）

依存関係に基づくレイヤー構造で開発する。同一レイヤー内のスクリプトは並列に開発可能。

```
Layer 0: Makefile, .gitignore, ディレクトリレイアウト
Layer 1: scripts/helpers.sh + テスト
Layer 2: chawan.tmux + テスト
Layer 3: chawan-list.sh, chawan-preview.sh, chawan-action.sh, chawan-create.sh, chawan-rename.sh + テスト（並列可）
Layer 4: chawan-main.sh（手動テスト。Layer 3 全スクリプトに依存）
Layer 5: .github/workflows/ci.yml, LICENSE, README.md
Layer 6: 結合テスト（tmux内で実操作確認）
```

## 検証方法

1. tmux内で `prefix + S` → popup起動確認
2. Sessionモード: fuzzy検索でフィルタ、Enter で switch 確認
3. `Tab` / `Shift-Tab` でタブ切替、タブバー表示更新・リスト差替え確認
4. `Ctrl-O` で新規作成、`Ctrl-D` で削除、`Ctrl-R` でリネーム確認
5. プレビューが正しくcapture-pane内容を表示するか確認
6. 現在セッションの削除が安全ガードされるか確認
7. TPM経由での `prefix + I` インストール確認
8. `bats tests/` で全テストパス確認
9. `shellcheck` + `shfmt -d` でlint/format警告なし確認
