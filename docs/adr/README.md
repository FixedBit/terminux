# Architecture decision records

Short records of decisions that shape terminux: the context, what was
decided, and what it costs. Add a new numbered file instead of rewriting an
old one; if a decision is reversed, mark the old record **Superseded** and
link the new one.

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-native-termux-with-optional-proot.md) | Native Termux desktop, Debian proot only for glibc apps | Accepted |
| [0002](0002-build-on-upstream-projects.md) | Build on upstream projects; reuse code only under compatible licences | Accepted |
| [0003](0003-secrets-at-runtime.md) | Secrets are supplied at install time, never committed | Accepted |
| [0004](0004-netbird-netstack.md) | NetBird runs rootless in netstack mode | Accepted |
| [0005](0005-options-schema.md) | One options schema drives the wizard, the installer and the tests | Accepted |
| [0006](0006-test-first.md) | Features are built test-first with bats | Accepted |
| [0007](0007-apache-2-licence.md) | Licence terminux under Apache-2.0 | Accepted |
