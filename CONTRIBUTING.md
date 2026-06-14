# Contributing

SwiftUIInspector is research-first. Contributions should improve component-name
recovery or prove a limitation before adding inspector UI.

## Development Setup

Requirements:

- Current Xcode and Swift toolchain
- At least one iOS simulator

Run:

```bash
swift run SwiftUIInspectorResearch
swift test
xcodebuild test \
  -scheme SwiftUIInspector-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Project Structure

```text
Sources/SwiftUIInspector/          Package implementation
Sources/SwiftUIInspectorResearch/  Console root-value prototype
Tests/SwiftUIInspectorTests/       macOS and iOS simulator experiments
Docs/                        Architecture, research, troubleshooting
Research/                    Reproducible reverse-engineering notes
Scripts/                     SDK symbol inspection tools
Example/DemoApp/             Reserved for the post-gate demo app
```

## Research Workflow

1. State the runtime hypothesis.
2. Add the smallest reproducible experiment.
3. Test multiple OS versions when private API is involved.
4. Record successful and failed results in `Docs/Research.md`.
5. Keep private ABI calls isolated and dynamically resolved where possible.

## Pull Requests

- Keep changes scoped to the current milestone.
- Add tests for hierarchy filtering and OS compatibility.
- Do not claim support that has not been reproduced.
- Do not add overlay or inspector UI before live hierarchy reconstruction works.
