# Releasing QuickType

## Preconditions

- `main` is green in GitHub Actions
- Version is decided (SemVer)
- Release notes are reviewed

## Steps

1. Update docs/changelog as needed
2. Commit and push to `main`
3. Create and push a tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

4. Wait for `.github/workflows/release.yml` to finish
5. Verify release assets:
- `quicktype-vX.Y.Z-macos-arm64.tar.gz`
- `quicktype-vX.Y.Z-macos-arm64.tar.gz.sha256`

## Verification

- Download artifact from GitHub Release
- Verify checksum:

```bash
shasum -a 256 -c quicktype-vX.Y.Z-macos-arm64.tar.gz.sha256
```

## Rollback

- If artifact is bad, delete the GitHub Release and tag:

```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
```

- Fix issue and publish a new tag (e.g., `vX.Y.(Z+1)`).
