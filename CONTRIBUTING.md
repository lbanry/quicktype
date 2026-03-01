# Contributing

## Development

- Use Swift 6.2+
- Run `swift build` and `swift test` before opening PRs
- Keep app local-first and privacy-preserving

## Pull requests

- Include problem statement and implementation summary
- Add/update tests for behavior changes
- Avoid adding outbound telemetry by default

## Release process (GitHub)

- Create and push a semantic tag (`vX.Y.Z`)
- GitHub Actions `release.yml` publishes release artifacts automatically
