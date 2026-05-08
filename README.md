# DreamHunter | Repository Management Guide

This document explains how to manage the product ecosystem (Game, Admin, Landing Page) without needing to run the Flutter or Backend code locally.

## 🚀 Quick Deployment Workflow

### 1. Building APKs
To update the mobile apps on the landing page, run these commands from the root:
```bash
# Build Game APK
cd frontend && flutter build apk --release && cd ..

# Build Admin APK
cd admin && flutter build apk --release && cd ..
```

### 2. Updating Downloads
After building, move the APKs to the `docs/` folder so they are accessible by the website:
```bash
# Copy to web directory
cp frontend/build/app/outputs/flutter-apk/app-release.apk docs/downloads/dreamhunter-release.apk
cp admin/build/app/outputs/flutter-apk/app-release.apk docs/downloads/admin-release.apk
```

### 3. Pushing Changes (Manual Only)
**DO NOT use auto-push scripts.** Always review your changes and push manually to maintain stability:
```bash
git add docs/index.html docs/downloads/*.apk
git commit -m "feat: release update v1.0.x"
git push origin main
```

---

## 🛠 Web Infrastructure (`docs/`)

The landing page is hosted via GitHub Pages from the `docs/` directory.

### Managing Downloads
*   **Main Game:** Linked via the "Android" card in `index.html`.
*   **Admin Dashboard:** Hidden trigger. Click the **"by ryme"** logo **3 times** within 1 second to download `admin-release.apk`.

### Version Labeling
If you update the APKs, remember to update the version text in `docs/index.html`:
```html
<span>v1.0.x • .APK</span>
```

---

## 📦 Creating GitHub Releases
To create a formal release with the APKs attached as binary assets:
1.  Tag the version: `git tag v1.0.x && git push origin v1.0.x`
2.  Create release via `gh` CLI:
    ```bash
    gh release create v1.0.x docs/downloads/dreamhunter-release.apk --title "Release v1.0.x" --notes "Release notes here"
    ```

---

## ⚠️ Safety Mandates
1.  **Redundant Files:** Keep the repo clean. Do not commit `.metadata`, `.directory`, or `package-lock.json` files.
2.  **Git State:** Always work on `development` branch for changes, then merge to `main` for releases.
3.  **Large Files:** If APKs exceed 100MB, you must use Git LFS (Large File Storage).
