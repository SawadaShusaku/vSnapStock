# vSnapStock 多言語対応セットアップガイド

このドキュメントでは、vSnapStockアプリの多言語対応（日本語・英語・スペイン語）のセットアップ手順を説明します。

## 📋 実装済みの内容

### ✅ 翻訳ファイル
1. **Localizable.xcstrings** - UI文字列の翻訳（約110文字列）
2. **InfoPlist.xcstrings** - 権限説明の翻訳（カメラ・フォトライブラリ）

### ✅ 多言語対応済みファイル
以下のSwiftファイルは全て多言語対応済みです：
- HomeView.swift
- PhotoCaptureSheet.swift
- CardEditSheet.swift
- ArchiveView.swift
- TrashView.swift
- ColorSettingsView.swift
- OCRSettingsView.swift

## 🔧 Xcodeでのセットアップ手順

### ステップ1: プロジェクトに言語を追加

1. **Xcodeでプロジェクトを開く**
   - `vSnapStock.xcodeproj` を開きます

2. **プロジェクト設定を開く**
   - 左側のナビゲーターでプロジェクトアイコン（最上部の青いアイコン）をクリック
   - 中央のエディタエリアで「vSnapStock」プロジェクトが選択されていることを確認

3. **Infoタブを選択**
   - 上部のタブから「Info」をクリック

4. **言語を追加**
   - 「Localizations」セクションを見つけます
   - 現在は「Japanese - Development Language」のみが表示されているはずです
   - 「+」ボタンをクリックして以下の言語を追加：
     - **English**
     - **Spanish (es)**
     - **German (de)**
     - **French (fr)**

5. **ファイルを選択**
   - 言語を追加すると、ダイアログが表示されます
   - 以下のファイルにチェックが入っていることを確認：
     - ✅ Localizable.xcstrings
     - ✅ InfoPlist.xcstrings
   - 「Finish」をクリック

### ステップ2: String Catalogの確認

1. **Localizable.xcstringsを開く**
   - 左側のナビゲーターで `vSnapStock/Localizable.xcstrings` をクリック

2. **翻訳を確認**
   - 右側のエディタで、各キー（例: "app.name", "button.cancel"など）の翻訳が表示されます
   - 言語ごとに翻訳状態を確認できます：
     - 🟢 Translated（翻訳済み）
     - 🔴 Not Translated（未翻訳）

3. **InfoPlist.xcstringsを開く**
   - 同様に `vSnapStock/InfoPlist.xcstrings` を開いて確認

### ステップ3: ビルドとテスト

1. **クリーンビルド**
   ```
   Product > Clean Build Folder (⇧⌘K)
   ```

2. **ビルド実行**
   ```
   Product > Build (⌘B)
   ```

3. **エラーがないことを確認**
   - ビルドが成功することを確認します

### ステップ4: 言語切り替えのテスト

#### シミュレータでテスト

1. **シミュレータを起動**
   - アプリを実行します（⌘R）

2. **言語を変更**
   - **iOS設定アプリ** を開く
   - **General** > **Language & Region**
   - **iPhone Language** をタップ
   - テストしたい言語を選択（例：English）
   - 「Change to English」を確認

3. **アプリを再起動**
   - アプリを終了して再度起動
   - UIが選択した言語で表示されることを確認

#### 実機でテスト

1. **実機を接続**
   - iPhoneをMacに接続

2. **言語設定を変更**
   - **設定** > **一般** > **言語と地域**
   - **iPhoneの使用言語** で言語を変更

3. **アプリを実行**
   - Xcodeから実機にアプリをインストールして実行
   - UIが選択した言語で表示されることを確認

## 🌐 対応言語

| 言語 | ロケールコード | 状態 |
|------|---------------|------|
| 日本語 | ja | ✅ 完了 |
| 英語 | en | ✅ 完了 |
| スペイン語 | es | ✅ 完了 |
| ドイツ語 | de | ✅ 完了 |
| フランス語 | fr | ✅ 完了 |

## 📝 翻訳のカスタマイズ

翻訳を修正したい場合：

1. **Localizable.xcstringsを開く**
2. 修正したいキーを選択
3. 右側のエディタで該当言語の翻訳を編集
4. 保存（⌘S）
5. クリーンビルドして再実行

## 🔍 トラブルシューティング

### 問題: 翻訳が反映されない

**解決策:**
1. クリーンビルドを実行（⇧⌘K）
2. シミュレータをリセット：Device > Erase All Content and Settings...
3. アプリを削除して再インストール

### 問題: 一部の文字列が翻訳されない

**解決策:**
1. Localizable.xcstringsで該当キーが存在するか確認
2. コード内で正しいキー名を使用しているか確認
3. `String(localized: "キー名")` の形式になっているか確認

### 問題: ビルドエラーが発生

**解決策:**
1. Localizable.xcstringsとInfoPlist.xcstringsがプロジェクトに正しく追加されているか確認
2. ファイルのTarget Membershipが「vSnapStock」になっているか確認
   - ファイルを選択 > 右側のインスペクタ > Target Membership

## 📱 スクリーンショットの確認項目

各言語で以下の画面をテストしてください：

- ✅ ホーム画面（カード一覧）
- ✅ カード編集画面
- ✅ 写真撮影画面
- ✅ アーカイブ画面
- ✅ ゴミ箱画面
- ✅ カラー設定画面
- ✅ OCR設定画面
- ✅ 権限リクエストダイアログ

## 🎯 今後の拡張

新しい言語を追加する場合：

1. Xcodeのプロジェクト設定で言語を追加
2. Localizable.xcstringsとInfoPlist.xcstringsに自動的に新しい言語の欄が追加されます
3. 各キーに対して新しい言語の翻訳を入力
4. ビルドしてテスト

## 📚 参考資料

- [Apple Developer - Localization](https://developer.apple.com/localization/)
- [String Catalogs - WWDC](https://developer.apple.com/videos/play/wwdc2023/10155/)

---

**実装完了日**: 2026年1月3日
**対応言語数**: 5言語（日本語、英語、スペイン語、ドイツ語、フランス語）
**翻訳文字列数**: 約110文字列
