# v0.4.0の対応範囲

Create: Astral 2.1.5bの実環境にある175個のトップレベルMOD JARを調べ、144個から言語・説明書・権利表示を抽出しました。内蔵ライブラリJARの全テキスト、画像の文字、プログラムに直接書かれた英語は網羅していません。

今回は**アイテム名を新規追加せず、効果・操作・設定の説明を優先**しました。既存版に収録した名前の翻訳はそのまま残します。

| 配布物 | 今回追加 | 合計 |
| --- | ---: | ---: |
| 通常版・メニュー | 678 | 6,806 |
| 追加説明書（クライアント用） | 215 | 215 |
| 全配布物 | 893 | 7,021 |

通常版の追加対象は26 MODです。YIGDの設定説明110項目、Yttrの説明106項目、Ad Astraの説明・画面112項目、AE2の説明76項目、Sodiumの設定説明33項目などを含みます。既存の日本語訳がある表示は併用します。[対象版・出典・権利表示](description-sources.json)を公開しています。

## 本の対応

| 対象 | 翻訳範囲 | 導入方法 |
| --- | --- | --- |
| Hephaestus全6冊 | 416ファイル・1,127項目、関連名8項目 | 通常版。サーバー配信可能 |
| Astrodux | 25ファイル・116項目 | Books版。各クライアントへ導入 |
| Extended Drawers | 15ファイル・43項目 | Books版。各クライアントへ導入 |
| Phonos | 12ファイル・56項目 | Books版。各クライアントへ導入 |

HephaestusはMaterials and You、Puny Smelting、Mighty Smelting、Fantastic Foundry、Tinker's Gadgetry、Encyclopedia of Tinkeringに対応します。元のHephaestus 1.18.2-3.5.2.312の構造を保持し、同じ英語原文の公式日本語訳を利用、版で異なる箇所は個別に翻訳しました。

追加3冊は、この版のPatchouliが `data/.../patchouli_books/...` をMOD自身のJARから直接読む仕様です。通常のリソースパックでは本文を差し替えられません。Books版は原本のバックアップを作り、日本語JSONだけを追加します。[導入・復元手順](legacy-books/BOOKS-README.md)と[Patchouli公式の移行仕様](https://vazkiimods.github.io/Patchouli/docs/upgrading/upgrade-guide-117/)を確認してください。

## 残っているもの

| 対象 | 状況 |
| --- | --- |
| Vineryの説明書 | リソースの権利留保があるため未収録 |
| Minecraft Dungeons Weapons | 対象JARの同梱ライセンスが再配布を認めないため未収録 |
| Naturalist等の権利留保があるリソース | 今回の追加から除外 |
| Chippedなどの大量のアイテム名 | 今回の優先対象外 |
| 表紙など画像に描かれた英字 | 画像は差し替えていない |
| クエスト定義に直接固定された英語 | 少数の見出し・確認ボタンが残る。進行データは変更しない |
| MOD名、キー名、単位、ローマ数字、コマンド識別子 | 必要に応じ原表記を保持 |

すべてのMODの全説明を翻訳済みという意味ではありません。Vineryは[原作者の条件](https://www.curseforge.com/minecraft/mc-mods/lets-do-vinery/license)、Chippedは[対象系列の条件](https://github.com/terrarium-earth/Chipped/blob/1.18.2/LICENSE)を確認し、一律にMIT扱いしません。

## 検証

JSON・UTF-8・収録範囲、差し込み文字、装飾コード、URL、Patchouliのマクロ、本の翻訳以外の構造を検査します。原文の指紋と出典は `mod-language-index.json`、`book-index.json`、`legacy-books/legacy-book-index.json` に記録しています。元のレシピ・アイテムID・NBT・参照画像・数値は保持します。

Books版は対象の実JARのコピーで導入・再導入・原本復元を確認し、Windowsの自動テストで不正なペイロード、未知の更新済みJAR、パス逸脱の拒否も確認しています。

**追加画面・本の実ゲーム表示は未検証です。** 日本語の見切れやリソースの優先順位は実プレイでの確認が必要です。説明書は元MODの仕様のため、パック独自のレシピ変更やネザー無効化などとは異なる記述が残ります。実際のレシピはREIとクエストを優先してください。
