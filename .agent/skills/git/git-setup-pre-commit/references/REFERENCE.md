# Per-Language Toolchain Reference

## Toolchain matrix

| Language | Manifest | Formatter | Linter | Typecheck | Test |
|---|---|---|---|---|---|
| JS/TS | `package.json` | Prettier | ESLint | `tsc --noEmit` | `jest` / `vitest run` |
| Python | `pyproject.toml`, `requirements.txt`, `Pipfile`, `setup.py`, `uv.lock` | `ruff format` (or Black) | `ruff check` | `mypy` / `pyright` | `pytest` |
| Java | `pom.xml`, `build.gradle(.kts)` | Spotless / google-java-format | Checkstyle | — | `mvn test` / `./gradlew test` |
| C/C++ | `CMakeLists.txt`, `Makefile`, `*.vcxproj` | `clang-format -i` | `clang-tidy` / `cppcheck` | — | `ctest` / `make test` |
| .NET | `*.sln`, `*.csproj`, `Directory.Build.props` | `dotnet format` | `dotnet format --verify-no-changes` | — | `dotnet test` |
| Rust | `Cargo.toml` | `cargo fmt` | `cargo clippy -- -D warnings` | `cargo check` | `cargo test` |

Always prefer the tool config already in the repo (`[tool.ruff]` in pyproject.toml, `.eslintrc`, `.clang-format`, `.editorconfig`, `*.editorconfig` for dotnet, `spotless {}` in Gradle, etc.) over generating new defaults.

## Runner: Husky (Node-only repos)

```bash
npm i -D husky lint-staged prettier eslint && npx husky init
```

`.husky/pre-commit` (no shebang needed, Husky v9+):

```bash
npx lint-staged
npm run typecheck
npm run test
```

Omit the `typecheck`/`test` lines if those scripts don't exist in package.json.

`.lintstagedrc`:

```json
{
  "*": "prettier --ignore-unknown --write",
  "*.{js,jsx,ts,tsx}": "eslint --fix"
}
```

`.prettierrc` (only if none exists):

```json
{
  "useTabs": false,
  "tabWidth": 2,
  "printWidth": 80,
  "singleQuote": false,
  "trailingComma": "es5",
  "semi": true,
  "arrowParens": "always"
}
```

## Runner: pre-commit framework (Python-only repos)

```bash
pipx install pre-commit     # or: uv tool install pre-commit
pre-commit install
```

`.pre-commit-config.yaml` (pin Ruff version to latest; adapt to repo's actual tooling):

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.11.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: local
    hooks:
      - id: mypy
        name: mypy
        entry: mypy
        language: system
        types: [python]
      - id: pytest
        name: pytest
        entry: pytest -q
        language: system
        pass_filenames: false
```

Drop the `mypy`/`pytest` blocks if the repo doesn't use them.

## Runner: lefthook (C/C++, Java, Rust, .NET, or polyglot)

Install options: `npm i -D lefthook`, `winget install lefthook`, `scoop install lefthook`, `brew install lefthook`, or download the binary from the GitHub releases. Then `lefthook install` (sets `core.hooksPath`).

`.lefthook.yml` — combine the `commands:` blocks for every detected language (parallel runs; remove unused):

```yaml
pre-commit:
  parallel: true
  commands:
    js-format:
      glob: "*.{js,jsx,ts,tsx}"
      run: npx prettier --write {staged_files}
    js-lint:
      glob: "*.{js,jsx,ts,tsx}"
      run: npx eslint {staged_files}
    js-typecheck:
      run: npx tsc --noEmit
    js-test:
      run: npx vitest run
    py-format:
      glob: "*.py"
      run: ruff format {staged_files}
    py-lint:
      glob: "*.py"
      run: ruff check --fix {staged_files}
    py-typecheck:
      glob: "*.py"
      run: mypy {staged_files}
    py-test:
      run: pytest -q
    java-format:
      run: mvn spotless:apply
    java-lint:
      run: mvn checkstyle:check
    java-test:
      run: mvn test
    dotnet-format:
      run: dotnet format --include {staged_files}
    dotnet-test:
      run: dotnet test
    cpp-format:
      glob: "*.{c,cc,cpp,h,hpp,cu}"
      run: clang-format -i {staged_files} && git add {staged_files}
    cpp-lint:
      glob: "*.{c,cc,cpp,h,hpp}"
      run: clang-tidy {staged_files}
    cpp-test:
      run: ctest --test-dir build
    rust-fmt:
      glob: "*.rs"
      run: cargo fmt --check
    rust-clippy:
      run: cargo clippy -- -D warnings
    rust-test:
      run: cargo test
```

Adapt to the repo's build system (Gradle instead of Maven, `make test` instead of `ctest`, uv/pip instead of npm).

## GitHub Actions CI templates

Single `.github/workflows/ci.yml`; keep only the jobs matching detected languages.

```yaml
name: CI
on:
  push:
  pull_request:

jobs:
  js-ts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npx prettier --check .
      - run: npx eslint .
      - run: npx tsc --noEmit
      - run: npx vitest run

  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install ruff mypy pytest
      - run: ruff format --check .
      - run: ruff check .
      - run: mypy .
      - run: pytest -q

  java:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
          cache: maven
      - run: mvn -B verify

  dotnet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0"
      - run: dotnet format --verify-no-changes
      - run: dotnet test

  cpp:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y clang-format clang-tidy cmake ninja-build
      - run: cmake -B build -G Ninja
      - run: cmake --build build
      - run: ctest --test-dir build

  rust:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - uses: Swatinem/rust-cache@v2
      - run: cargo fmt --check
      - run: cargo clippy -- -D warnings
      - run: cargo test
```

Adapt installs to the repo's real tooling (Gradle wrapper, uv/pip, build dir name) and trim any step without a matching local command.
