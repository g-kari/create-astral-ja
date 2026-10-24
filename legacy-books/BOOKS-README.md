# 追加の説明書を日本語化する

Create: Astral **2.1.5b / Minecraft 1.18.2**用です。通常版リソースパックと併用してください。このZIP自体はリソースパックではありません。

| 説明書 | 対象MOD | 翻訳項目 |
| --- | --- | ---: |
| Astrodux | Ad Astra 1.0.9 | 116 |
| 引き出しの説明書 | Extended Drawers 1.3.7+mc.1.18.2 | 43 |
| 音響装置の説明書 | Phonos 0.3+1.18.2 | 56 |

この版の3冊はMOD自身のJARから本文を読みます。サーバーのリソースパックだけでは本文を差し替えられないため、**読む人のクライアントに一度導入する必要があります**。Hephaestusの6冊や通常のツールチップは通常版で配信できます。Astroduxの導入文の翻訳にも通常版が必要です。

## 導入

1. Minecraftを終了します。
2. Books版ZIPを専用フォルダーに展開します。
3. そのフォルダーをPowerShellで開き、インスタンスの場所を指定して確認します。指定先は `mods` フォルダーの1つ上です。

```powershell
.\Install-Japanese-Books.ps1 -InstancePath 'C:\Minecraft\CreateAstral' -CheckOnly
```

4. `CHECK OK` を確認して実行します。

```powershell
.\Install-Japanese-Books.ps1 -InstancePath 'C:\Minecraft\CreateAstral'
```

5. Minecraftを起動し、言語を日本語にして、本を開き直します。

必要な本だけなら `-Book ad_astra`、`-Book extended_drawers`、`-Book phonos` を追加できます。存在しない対象MODはスキップします。異なる版・変更済みの不明なJARはハッシュ検査で拒否し、上書きしません。

## 元に戻す

Minecraftを終了して、同じインスタンスに対して実行します。

```powershell
.\Install-Japanese-Books.ps1 -InstancePath 'C:\Minecraft\CreateAstral' -Restore
```

原本はインスタンス内の `.create-astral-ja-books-backups` に保存します。復元まで削除しないでください。導入後にランチャー等がMODを更新した場合、不明な変更を上書きしないよう復元を拒否します。バックアップと対象版を確認してください。

## 変更内容と確認範囲

3個のJARに日本語JSONを計52ファイル追加します。元からある各ファイルの内容を照合し、MODのコード・レシピ・ワールドは変更しません。JARのZIPコンテナーは組み直されるため、JAR全体のハッシュは変わります。再実行は同じ内容なら変更せず、復元時は原本のバイト列に戻します。

対象の実JARのコピーとWindowsのテストで、追加・再実行・復元を確認しています。**ゲーム内のページ表示や日本語の見切れは未検証です。** 原作の説明書がパック独自のレシピと違う場合は、REIとクエストを優先してください。

スクリプトはMIT、翻訳データは各MODのMITまたはApache-2.0です。`LICENSING.md` と同梱の権利表示を確認してください。
