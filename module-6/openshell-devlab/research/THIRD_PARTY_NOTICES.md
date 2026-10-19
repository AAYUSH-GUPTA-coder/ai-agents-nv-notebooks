# Third-party notices

This notice covers `orjson` in the research sandbox and `certifi` in both the
outer Jupyter runtime and research sandbox. It is not a complete license
inventory of the Devlab image.

## orjson 3.12.0

The research sandbox uses the unmodified upstream `orjson` package.
Its license expression is `MPL-2.0 AND (Apache-2.0 OR MIT)`: the MPL-covered
source remains under MPL-2.0; other code is available under Apache-2.0 or MIT.

- Corresponding source: [orjson-3.12.0.tar.gz](https://files.pythonhosted.org/packages/0f/f3/742fb1f62b825f2c010697eaf4e828004bc2a81e7e806666989c132c7c42/orjson-3.12.0.tar.gz).
- Source SHA-256: `d14203fb1aae2ad9b3d52f8a0e82aeb10197ef1c9bc61da7f358bd70b00123d5`.
- MPL-2.0 terms: <https://www.mozilla.org/en-US/MPL/2.0/>.

The source archive contains the upstream source, copyright notices and license
texts. The installed package also retains `LICENSE-MPL-2.0`, `LICENSE-APACHE`
and `LICENSE-MIT` in
`/sandbox/.venv/lib/python3.12/site-packages/orjson-3.12.0.dist-info/licenses/`.

## certifi 2026.7.22

The outer Jupyter runtime and research sandbox use the unmodified upstream
`certifi` package, licensed under MPL-2.0.

- Corresponding source: [certifi-2026.7.22.tar.gz](https://files.pythonhosted.org/packages/a3/c2/24167ea9858356b47a87a50d39908bfdb72ceeefe0041586e704e5376b3a/certifi-2026.7.22.tar.gz).
- Source SHA-256: `741e2c3b351ddf169a738da9f2c048608ff7f2c5cc02f1ebc6b118bb090d5d55`.
- MPL-2.0 terms: <https://www.mozilla.org/en-US/MPL/2.0/>.

The installed package includes its Python source and certificate bundle.
It retains the upstream license text at
`/usr/local/lib/python3.12/site-packages/certifi-2026.7.22.dist-info/licenses/LICENSE`
in the outer runtime, and at
`/sandbox/.venv/lib/python3.12/site-packages/certifi-2026.7.22.dist-info/licenses/LICENSE`
in the research sandbox. The source archive above also includes the upstream
source, copyright notices and license text.
