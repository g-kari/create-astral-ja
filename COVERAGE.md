# v0.3.0の対応範囲

実環境の175個のトップレベルMOD JARを調べ、144個から言語・説明書・権利表示を抽出しました。通常の `assets/*/lang/en_us.json` と `ja_jp.json`、本のJSON・章名データが対象です。内蔵ライブラリJARの全テキスト、画像の文字、プログラムに直接書かれた英語は網羅していません。

v0.2.0から**2,103項目**追加し、パッチ全体は**6,128項目**です。

| 対象 | 今回追加した項目 |
| --- | ---: |
| Hephaestusの残り5冊の本文・章名 | 985 |
| Hephaestusの素材・改造・道具の説明など | 821 |
| Createの加工カテゴリ・タグ名など | 85 |
| Create Crafts & Additionsの説明など | 62 |
| REIの画面・設定説明 | 85 |
| Tech Rebornの機械状態・装備名・説明など | 65 |

## 本の対応

Hephaestusの**全6冊**の英語JSON・章名ファイルに対応します。合計416ファイル・1,127項目の本データと、v0.2.0で追加した8個の本・装備名を含みます。

- Materials and You
- Puny Smelting
- Mighty Smelting
- Fantastic Foundry
- Tinker's Gadgetry
- Encyclopedia of Tinkering

公式Tinkers' Constructにある同一の英語原文の日本語訳を利用し、この版で内容が異なる箇所は個別に翻訳しました。レシピ参照、アイテムID、NBT、画像の参照などは**Hephaestus 1.18.2-3.5.2.312の構造を保持**します。新版の本の丸ごと移植ではありません。

## 残っているもの

Create・Hephaestus・REI・Tech Rebornで今回の照合後に残った英語候補は、MOD名、キー名、RPMなどの単位、ローマ数字、コマンドの識別子、入力方式の製品名、非表示のコメントです。

以下は今回の通常版ZIPに未収録です。

| 対象 | 調査結果 |
| --- | --- |
| Ad AstraのAstrodux | 英語の説明書データ25ファイル |
| Extended Drawersの説明書 | 英語の説明書データ15ファイル |
| Phonosの説明書 | 英語の説明書データ12ファイル |
| Vineryの説明書 | 英語の説明書データ15ファイル |
| Chippedなど、今回の5 MOD以外の全アイテム名・設定 | 未対応の候補あり |
| 表紙などの画像に描かれた英字 | 画像は差し替えない |
| クエスト定義に直接固定された英語 | 少数の見出し・確認ボタンは残る。進行データは変更しない |

上記4種の本は、この版では `data/.../patchouli_books/...` に格納されています。Mantleの本と同じ処理には混ぜません。Patchouliは `use_resource_pack` などの設定で読み込み方が変わるため、実クライアントで対応方法を確認する必要があります。[Patchouli公式仕様](https://vazkiimods.github.io/Patchouli/docs/reference/book-json/)

翻訳データの条件もMODごとに異なります。例えばChippedの1.18.2のライセンスでは、定義されたCodeがMIT、それ以外はAll Rights Reservedです。すべてのMODの翻訳を一律にMIT扱いしません。[Chippedのライセンス](https://github.com/terrarium-earth/Chipped/blob/1.18.2/LICENSE)

## 検証

JSON・UTF-8・収録範囲、差し込み文字、装飾コード、参照文字列、本の翻訳以外の構造を検査しました。追加MODの原文の指紋と出典は `mod-language-index.json`、本の指紋は `book-index.json` に記録しています。利用した公式訳のリポジトリとコミットも固定しています。

**追加画面・本の実ゲーム表示は未検証です。** 長い日本語の見切れや表示の優先順位は実プレイでの確認が必要です。

説明書は元MODの仕様のため、パック独自のレシピ変更やネザー無効化などとは異なる記述が残ります。実際のレシピはREIとクエストを優先してください。
