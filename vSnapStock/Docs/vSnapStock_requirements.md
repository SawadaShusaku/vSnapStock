# vSnapStock 要件定義書

## 1. アプリ概要

### 1.1 アプリ名
- **日本語名**: vSnapStock（ブイスナップストック）
- **英語名**: vSnapStock
- **AppStore表示名**: vSnapStock - Visual Inventory

### 1.2 コンセプト
カメラで撮影した物品を自動認識し、視覚的に在庫管理ができるiOS向けリマインダーアプリ。Vision FrameworkとLiquid AIのLEAP SDKを活用し、物体検知と詳細説明の自動生成を実現。

### 1.3 ターゲットユーザー
- 家庭の在庫管理をしたい一般ユーザー
- 小規模ビジネスオーナー
- コレクション管理をしたい趣味人

## 2. システム要件

### 2.1 対応環境
| 項目 | 要件 |
|------|------|
| 対象OS | iOS 18.0以上 |
| 対応デバイス | iPhone, iPad |
| 最小RAM | 4GB以上（AI処理のため） |
| ストレージ | 500MB以上の空き容量 |
| ネットワーク | オフライン動作可能（初回モデルDL時のみ必要） |

### 2.2 言語サポート
- 日本語（ja）
- 英語（en）

## 3. 機能要件

### 3.1 コア機能

#### 3.1.1 画像認識・データ作成機能
- **物体検知**
  - Vision Frameworkによる物体検知
  - 検知された物体の個数カウント
  - バウンディングボックスの表示

- **AI詳細説明生成**
  - LEAP SDK（LFM2-VLモデル）による物体の詳細説明自動生成
  - オンデバイス処理（プライバシー保護）
  - 各物体に対して個別の説明文生成

- **データ管理**
  - 検知物体ごとにJSON形式のデータテーブル作成
  - ユーザーによる認識結果の編集機能
  - カスタムタグ・メモの追加

#### 3.1.2 UI/UX機能
- **TabView（iOS26 Liquid Glass）**
  - ホーム（カメラ・一覧）
  - 検索
  - カテゴリー
  - 設定

- **表示モード**
  - カード形式表示
  - リスト形式表示
  - 表示切り替えボタン

- **検索・フィルター**
  - リアルタイム検索（名前、説明、タグ）
  - カテゴリーフィルター
  - 日付範囲フィルター
  - タグフィルター

#### 3.1.3 設定機能
- **テーマカスタマイズ**
  - RGBスライダーによる詳細な色指定
  - プリセットテーマ（5種類）
  - ライト/ダークモード切り替え
  - システム設定連動オプション

- **アプリ情報**
  - 利用規約
  - プライバシーポリシー
  - 使用ライセンス（LEAP SDK、その他OSS）
  - バージョン情報

- **その他**
  - App Storeレビュー誘導（StoreKit）
  - 通知設定
  - データ同期設定

#### 3.1.4 データ管理機能
- **エクスポート/共有**
  - JSON形式エクスポート
  - CSV形式エクスポート
  - 画像付きPDF生成
  - AirDrop対応
  - 共有シート対応

- **データ同期**
  - CloudKit同期（複数デバイス対応）
  - 自動バックアップ
  - 手動バックアップ/復元

## 4. 技術仕様

### 4.1 技術スタック
| カテゴリー | 技術 |
|------------|------|
| UI Framework | SwiftUI (iOS26 Liquid Glass対応) |
| 画像処理 | Vision Framework |
| AI処理 | LEAP SDK (LFM2-VL-1.6Bモデル) |
| データ永続化 | Core Data |
| クラウド同期 | CloudKit |
| ローカリゼーション | String Catalogs |
| 依存管理 | Swift Package Manager |

### 4.2 データモデル

#### ItemRecord（Core Data Entity）
```json
{
  "id": "UUID",
  "capturedAt": "ISO8601 Timestamp",
  "updatedAt": "ISO8601 Timestamp",
  "imageData": "Binary Data",
  "location": "String（保存場所）",
  "category": "String",
  "objects": [
    {
      "objectId": "UUID",
      "type": "String（検知された物体タイプ）",
      "description": "String（AI生成の説明）",
      "quantity": "Integer",
      "confidence": "Float（0.0-1.0）",
      "tags": ["String"],
      "customNotes": "String",
      "isUserEdited": "Boolean"
    }
  ]
}
```

### 4.3 LEAP SDK統合仕様

#### モデル設定
- **使用モデル**: LFM2-VL-1.6B
- **モデルサイズ**: 約1.6GB
- **ダウンロード方式**: 初回起動時にオンデマンド
- **推論設定**:
  - Temperature: 0.7
  - Max tokens: 150
  - 言語: 日本語/英語（ユーザー設定に応じて）

#### 処理フロー
1. カメラ撮影/画像選択
2. Vision Frameworkで物体検知
3. 検知された各領域を切り出し
4. LEAP SDKで各物体の説明生成
5. 結果をCore Dataに保存
6. UIを更新

## 5. UI設計

### 5.1 画面構成

#### メインTabView（iOS26 Liquid Glass）
1. **ホームタブ**
   - カメラボタン（フローティング）
   - 保存済みアイテム一覧
   - 表示切替ボタン

2. **検索タブ**（role: .search）
   - 検索フィールド
   - 検索結果表示
   - フィルターオプション

3. **カテゴリータブ**
   - カテゴリー一覧
   - カテゴリー別アイテム表示

4. **設定タブ**
   - 各種設定項目
   - アプリ情報

### 5.2 カラースキーム
- Primary Color: ユーザーカスタマイズ可能
- Secondary Color: システム定義
- Background: ライト/ダークモード対応
- Accent: RGB指定可能

## 6. 非機能要件

### 6.1 パフォーマンス
- 画像認識処理: 3秒以内
- AI説明生成: 5秒以内/物体
- アプリ起動時間: 2秒以内
- 検索レスポンス: 即時（< 100ms）

### 6.2 セキュリティ・プライバシー
- すべての処理はオンデバイスで実行
- 画像データの外部送信なし
- CloudKit使用時はApple IDによる認証
- App Tracking Transparencyに準拠

### 6.3 ユーザビリティ
- VoiceOver対応
- Dynamic Type対応
- 横画面対応（iPad）
- キーボードショートカット対応（iPad）

## 7. 開発スケジュール（概要）

### Phase 1: 基礎実装（4週間）
- プロジェクトセットアップ
- Core Data設計
- 基本UI実装（TabView）
- Vision Framework統合

### Phase 2: AI機能実装（3週間）
- LEAP SDK統合
- モデルダウンロード機能
- 物体説明生成機能
- 編集機能

### Phase 3: 拡張機能（3週間）
- CloudKit同期
- エクスポート機能
- テーマカスタマイズ
- 多言語対応

### Phase 4: 品質向上（2週間）
- バグ修正
- パフォーマンス最適化
- UI/UXブラッシュアップ
- App Store準備

## 8. 今後の拡張予定

### Version 2.0
- Apple Watch連携
- ウィジェット対応
- Shortcuts対応
- バーコード/QRコード読み取り

### Version 3.0
- 複数ユーザー共有機能
- 期限管理・通知機能
- 統計・分析機能
- AIによる在庫予測

## 9. ライセンス・法的事項

### 使用ライブラリのライセンス
- LEAP SDK: LFM1.0 License（Apache 2.0ベース）
- その他OSSライブラリ: 各ライセンスに準拠

### App Store審査対応
- 年齢制限: 9+
- カテゴリー: 仕事効率化
- 必要な権限: カメラ、写真ライブラリ

## 10. 備考

- 本要件定義書は開発開始時点のものであり、開発過程で変更される可能性があります
- LEAP SDKの最新バージョンに応じて、AI機能の詳細仕様は調整される場合があります
- iOS26の正式リリース後、Liquid Glass UIの仕様に合わせて調整を行います

---
*Document Version: 1.0*  
*Last Updated: 2025-11-15*  
*Author: Development Team*
