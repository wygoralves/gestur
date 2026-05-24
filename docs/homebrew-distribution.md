# Homebrew Distribution

Gestur publishes its macOS Homebrew cask through the shared tap repository:

- Tap repo: `wygoralves/homebrew-tap`
- Published file: `Casks/gestur.rb`
- Source of truth for metadata: the GitHub Release created by the release workflow

## Required Setup

Before the `Publish Homebrew Cask` job can update the tap, ensure:

1. The `wygoralves/homebrew-tap` repository exists.
2. The repository has a `main` branch.
3. The Gestur repo has a `HOMEBREW_TAP_TOKEN` Actions secret with write access to the tap repository.

If the secret is absent, the Homebrew publish job is skipped and the app release still completes.

## Release Flow

The release workflow uploads the macOS release assets, then:

1. Checks out the released tag from the Gestur repo.
2. Checks out the tap repository into a sibling working directory.
3. Runs `node Scripts/generate-homebrew-cask.mjs <tag> --output homebrew-tap/Casks/gestur.rb`.
4. Commits and pushes the cask update to the tap repository if the rendered file changed.

The cask generator expects exactly one macOS `.dmg` asset in the release. If none or multiple DMGs are present, the job fails instead of publishing an ambiguous cask.

## Gatekeeper

Gestur is not currently Developer ID signed or notarized. The cask includes a best-effort `postflight` step that removes the quarantine attribute from the installed app:

```ruby
system_command "/usr/bin/xattr",
  args: ["-dr", "com.apple.quarantine", "#{appdir}/Gestur.app"]
```

This reduces Gatekeeper friction but does not replace notarization.
