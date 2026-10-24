# Create: Astral 2.1.5b 日本語化パッチ

Minecraft Java 1.18.2 / Create: Astral **2.1.5b**向けの非公式日本語化です。原作の翻訳用テキスト3,874項目（リソース3,828項目・メニュー46項目）を翻訳し、原作にないクエスト表示キー1件も補っています。

クエストの説明、独自アイテム名、ツールチップ、思案の説明、加工カテゴリを収録しています。MOD本体・レシピ・クエストの条件や報酬・ワールドには変更を加えません。各MOD自身が提供する日本語訳は、そのまま併用します。

**v0.3.0では、Hephaestusの全6冊と、Create・REI・Tech Rebornなどの残っていた表示を追加しました。** 2,103項目増え、全体は6,128項目です。表紙の英字は画像なので残ります。[対応範囲と残り](COVERAGE.md)を公開しています。

## ダウンロード

[v0.3.0 リリース](https://github.com/g-kari/create-astral-ja/releases/tag/v0.3.0)

| ファイル | 用途 |
| --- | --- |
| `Create-Astral-2.1.5b-Japanese-v0.3.0.zip` | クエスト・Hephaestusの本6冊・追加のMOD表示。サーバーから配信可能 |
| `Create-Astral-2.1.5b-Japanese-Menu-v0.3.0.zip` | タイトルメニューの日本語化。クライアント用 |
| `server-resource-pack.properties` | サーバー配信用のURL・SHA-1設定例 |
| `*.sha1` / `*.sha256` | 配布ZIPのハッシュ |

## クライアントに入れる

1. 2.1.5bのインスタンスの `resourcepacks` フォルダーへ、通常版ZIPを**展開せず**に置きます。
2. 「設定 → リソースパック」で有効化し、一覧の上側へ移します。
3. 「設定 → 言語」で「日本語」を選択します。

旧版から更新する場合は旧ZIPを無効化して、新ZIPを有効化してください。本を閉じてから入れ替え、リソースの再読み込みが終わってから開き直します。

メニューも日本語化する場合は、ゲームを終了してからMenu版ZIPを展開し、中の `config` をそのインスタンスのフォルダーへコピーします。追加するのは `ja_jp.local` だけです。既存のワールドや設定一式を置き換える必要はありません。戻す場合は追加したファイルだけを削除します。

## サーバーから配信する

**通常版は、参加時のサーバーリソースパックとして配信できます。** 参加者はダウンロードを許可し、言語設定を日本語にするだけです。ZIPを手動で入れる必要はありません。表示処理自体はクライアントで行います。

リリースにある `server-resource-pack.properties` の各項目を、サーバーの `server.properties` に反映し、都合のよいときに再起動してください。この設定例を `server.properties` 全体に上書きしないでください。

```properties
resource-pack=https://github.com/g-kari/create-astral-ja/releases/download/v0.3.0/Create-Astral-2.1.5b-Japanese-v0.3.0.zip
resource-pack-sha1=配布したZIPのSHA-1
require-resource-pack=false
```

実際のハッシュはリリースの設定例に記入済みです。拒否した人も参加できる初期設定です。パックを必須にする場合は `require-resource-pack=true` にします。その場合、拒否した参加者は接続を続けられません。[Minecraft公式の説明](https://www.minecraft.net/ja-jp/article/minecraft-snapshot-20w45a-20w46a-jp)

すでに別のサーバーリソースパックを配信している場合、1.18.2のこの設定欄は1本です。既存のパックに言語ファイルを統合し、統合後のZIPのハッシュを使ってください。タイトルメニューはサーバー参加前に表示されるため、Menu版はこの方法で配信できません。

Hephaestusの本6冊の翻訳も通常版ZIPに含まれ、同じ配信で受け取れます。サーバーパックは接続・退出時に適用状態が切り替わるため、リソースの読み直しが発生します。待ち時間を避けたい人は、通常版ZIPをローカルで常時有効化し、そのサーバーの編集画面で「サーバーリソースパック」を無効化してください。この方法は、サーバー側がパックを必須にしていない場合に使えます。他の参加者への配信には影響しません。

このプロジェクトが稼働中のサーバー設定を書き換えたり、再起動したりすることはありません。

## 検証と確認範囲

- JSON・メニューのUTF-8構文、全項目の収録、重複キー、`%s`などの差し込み、色・装飾コード、URL、タグや検索用の参照を検査します。
- 上流の英語テキストは、公開インデックスに保存したSHA-256と照合できます。英語コーパス全体は同梱しません。
- クエスト定義の2,662種類の翻訳参照を調べ、英語ファイルにも欠けていた燃料タスクの表示キーを補いました。
- Hephaestusの全6冊・416ファイルで、翻訳以外の構造・レシピ参照・アイテムID・NBT・図の参照・数値を保持しているか検査します。Mantle 1.9.156が選択言語の本をリソースマネージャーから読むことも確認しました。
- **v0.3.0の追加画面・説明書のゲーム内表示は未検証です。** 日本語が長くなることによる見切れや、MOD間のリソース優先順位は、実プレイで確認が必要です。
- 原作のクエスト定義に英語で直接固定されている少数の見出し・確認ボタン（例：`Got it!`、`Wow thanks!`）は、言語ファイルだけでは変更できません。クエスト定義の上書きや進行データの変更は行っていません。
- パック独自の言語ファイルに加え、5 MODの未翻訳表示とHephaestusの本に対応します。すべてのMODの全UI・全アイテムを翻訳するものではありません。[残りの一覧](COVERAGE.md)を確認してください。

表記上、原文の引き出し容量の括弧内にあった計算不整合は省き、記載された個数を保持しています。架空の装置・物質・効果や、作者からのメッセージは原作の内容です。

## 自分でビルドする

Node.js 20以上が必要です。外部npmパッケージは使いません。

```sh
node tools/validate.mjs
node tools/build.mjs
```

生成物は `dist/` に出ます。上流2.1.5bクライアントZIPを展開した `overrides` との照合：

```sh
node tools/validate.mjs /path/to/overrides
```

本の翻訳元も照合する場合は、対象のHephaestus JARから取り出した `assets/` の親ディレクトリを第2引数に渡します。

```sh
node tools/validate.mjs /path/to/overrides /path/to/hephaestus-extracted
```

追加MODの原文も照合する場合は、`mod-language-index.json` の `sourceFile` と同じ相対配置で展開したJAR群の親ディレクトリを第3引数に渡します。

```sh
node tools/validate.mjs /path/to/overrides /path/to/hephaestus-extracted /path/to/extracted-mods
```

## ライセンス・クレジット

[自作ツールはMIT](LICENSE)。Create: Astral由来の翻訳データには原作の権利留保・条件を保持し、**MITは適用しません**。Hephaestusの本と関連する8個の言語キー、および `mod-language-index.json` の追加言語キーは、それぞれのMODのMITに従い、権利表示を同梱します。[追加分の権利表示](third-party-licenses/)も確認してください。[詳しい適用範囲](LICENSING.md)、[原作ライセンス](UPSTREAM-LICENSE.md)、[Hephaestusの権利表示](HEPHAESTUS-LICENSE.txt)を確認してください。

原作はLaskyyyおよびCreate: Astralの各貢献者によるものです。公式配布：<https://github.com/Laskyyy/Create-Astral/releases/tag/v2.1.5b>。本プロジェクトは非公式で、原作者からの公認を表すものではありません。
