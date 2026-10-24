# ライセンスの適用範囲

- `tools/`、CI設定、このプロジェクト独自の説明文は、ルートの `LICENSE` にあるMITライセンスです。
- 下記のHephaestusおよび追加MOD由来の翻訳を除く `resourcepack/assets/` と `client-overlay/` は、Create: Astral 2.1.5bの英語テキストに基づく非公式の日本語翻訳です。**この部分はMITライセンスの対象ではありません。** 原作に由来する権利は、原作者・各貢献者に帰属したままです。
- Create: Astral由来の翻訳データには、原作の `UPSTREAM-LICENSE.md` に記載された権利留保・条件が適用されます。独立した再許諾や、自由な再配布の許可をこのプロジェクトが与えるものではありません。
- 上流はパック本体を原則All Rights Reservedとし、翻訳などの本家へのPull Requestを歓迎しています。別用途での再利用・再配布の許諾が必要な場合は、同ファイルに示された原作者の窓口へ確認してください。

原作：<https://github.com/Laskyyy/Create-Astral/tree/v2.1.5b>

原作の条件：<https://github.com/Laskyyy/Create-Astral/blob/v2.1.5b/LICENSE.md>

## Hephaestusの説明書

v0.2.0以降で追加した `resourcepack/assets/tconstruct/book/*/ja_jp/` と、`book-index.json` の `languageEntries` に列挙する8個の言語キーは、Hephaestus **1.18.2-3.5.2.312**のリソースを元に翻訳しました。この追加分はMITで提供し、同MODに同梱されたMITライセンスと著作権表示を `HEPHAESTUS-LICENSE.txt` にそのまま収録しています。SlimeKnights、AlphaModeおよび各貢献者にクレジットします。

元のMOD：<https://github.com/Alpha-s-Stuff/TinkersConstruct>。対象JARのSHA-256と、各翻訳元の指紋を `book-index.json` に記録しています。パックに同梱するのは翻訳したJSON・言語データと権利表示のみで、MODのコードや表紙の画像は含めません。

このリポジトリには、MOD本体、ゲーム本体、テクスチャ、楽曲、レシピ、ワールドやプレイヤーデータを含めません。

## v0.3.0の追加MOD翻訳

`mod-language-index.json` に列挙した言語キーは、Hephaestus、Create、Create Crafts & Additions、REI、Tech Reborn由来のMITライセンスのデータです。各MODの権利表示を `third-party-licenses/` に保存し、ZIPにも同梱しています。元の英語と一致する公式日本語訳は、記録したリポジトリとコミットから取り込み、版の違う部分は個別に翻訳しました。既存のCreate: Astral由来のキーに対する権利条件は変更しません。

Hephaestusの追加5冊の日本語訳は、SlimeKnights/TinkersConstructのMITライセンスの翻訳を利用しています。元のコミットは `635f048cdd5a39aef27bddafb9489bff16ae3128` で、SlimeKnightsおよび日本語訳の各貢献者にクレジットします。JSONの機能・レシピ参照などは対象のHephaestusのものを保持しています。
