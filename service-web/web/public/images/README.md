# 画像置き場（静的ファイル）

このフォルダに画像を置くと、Next.js がそのまま配信します。

## 例

- `public/images/logo.png` を置く
  - ブラウザで: `/images/logo.png`
  - React/Nextで: `<img src="/images/logo.png" alt="logo" />`

※ `public/` 配下はビルド時にもそのまま利用されます（アップロード保存先ではなく、静的ファイル置き場です）。

