# Interfaces

## URL scheme (V1.1-ready stub)

- Scheme: `quicktype://capture`
- Query params:
  - `text` (optional): prefill capture text
  - `target` (optional): UUID of note target

Example:

```text
quicktype://capture?text=Follow%20up%20with%20design&target=9E44F2F0-2FC9-4609-AF31-25C7457698C2
```

## CLI helper (spec only, not shipped)

```bash
quicktype capture --target <uuid> --text "message"
```

Current repo includes URL parser plumbing but does not ship a standalone CLI binary.
