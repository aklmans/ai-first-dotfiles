# Vendored TOML reader

`tomli/` contains the pure-Python source of Tomli 2.4.1 (MIT), copied unchanged
from pip's vendored distribution. Upstream: https://github.com/hukkin/tomli
The upstream license is retained in `tomli/LICENSE`.

This supplies offline TOML parsing on the macOS Python 3.9 runtime; rendering
must not silently skip validation when `tomllib` is unavailable. This checks
TOML syntax plus our own workspace/route invariants, not every AeroSpace
version's command grammar. Activation still performs AeroSpace's own dry-run.
