# Setup

## R

Install R from [CRAN](https://cran.r-project.org). Tested with R 4.6.

R packages this project needs (`tidyverse`, `gt`, `ragg`, etc.) do not need a manual install
step on any platform — this happens automatically the first time `NSSK.R` runs. What the
platform sections below cover is R itself and, on Linux, the underlying OS/system libraries
those R packages need in order to compile from source, which still require a manual
`apt`/`brew` step, most notably on Linux.

### Mac

Install R from CRAN or via Homebrew:

```bash
brew install --cask r
```

Some packages (notably `ragg`) require system libraries. If installation fails, install the dependencies via Homebrew:

```bash
brew install libpng freetype harfbuzz fribidi
```

### Unix / Linux

Install R via your distribution's package manager. On Debian/Ubuntu:

```bash
sudo apt-get install r-base r-base-dev
```

Installing this project's R packages compiles some of them from source on Linux, which needs
a few system libraries beyond `r-base-dev` itself. On Debian/Ubuntu:

```bash
sudo apt-get install build-essential gfortran pkg-config libcurl4-openssl-dev libssl-dev \
  libxml2-dev libpng-dev libjpeg-dev libtiff5-dev libfreetype6-dev libfontconfig1-dev \
  libharfbuzz-dev libfribidi-dev zlib1g-dev libicu-dev libbz2-dev liblzma-dev libpcre2-dev \
  libuv1-dev libv8-dev
```

Install Helvetica-compatible fonts via apt:

```bash
sudo apt-get install fonts-texgyre fonts-urw-base35 fonts-liberation
```

- `fonts-texgyre` — TeX Gyre Heros (primary; purpose-built Helvetica clone, refined from Nimbus Sans)
- `fonts-urw-base35` — Nimbus Sans (secondary fallback; direct Helvetica clone from URW, precursor to TeX Gyre Heros)
- `fonts-liberation` — Liberation Sans (tertiary fallback; Arial-metric compatible, not Helvetica letterforms)

#### Debian 13 — build R 4.6.1 from source

The build dependencies below cover both R itself and the system libraries required by R packages including `ragg`.

```bash
sudo apt-get install -y \
  build-essential gfortran pkg-config libreadline-dev libx11-dev libxt-dev \
  libcairo2-dev libpng-dev libjpeg-dev libtiff-dev libicu-dev \
  libbz2-dev liblzma-dev libcurl4-openssl-dev libpcre2-dev zlib1g-dev \
  texinfo libuv1-dev libprotobuf-dev protobuf-compiler libudunits2-dev \
  libnode-dev libv8-dev libsecret-1-dev libmagick++-dev

sudo apt-get install -y texlive-fonts-extra texlive-latex-extra
```

Download the R 4.6.1 source from [CRAN](https://cran.r-project.org/src/base/), extract, and build:

```bash
./configure \
  --prefix="/home/user/r-lang" \
  --enable-R-shlib \
  --enable-memory-profiling \
  --with-cairo \
  --with-libpng \
  --with-libtiff \
  --with-jpeglib \
  --with-lapack \
  --with-blas \
  --with-tcltk
make -j"$(nproc)"
make install
```

R is installed to `/home/user/r-lang/bin/R`. Add that directory to your `PATH` or invoke `Rscript` via its full path.

### Windows

1. Download the installer from CRAN: https://cran.r-project.org/bin/windows/base/.
2. Run the downloaded `.exe` and accept the defaults. This installs R to `C:\Program Files\R\R-<version>`.
3. Add R's `bin` directory to the PATH so `Rscript` resolves from any shell:
   - Settings → System → About → Advanced system settings → Environment Variables
   - Under "System variables", select `Path` → Edit → New
   - Add your R installation's `bin` directory depending on your version (ex `C:\Program Files\R\R-4.6.1\bin`)
   - Open a new terminal (the change doesn't apply to already-open ones) and confirm installation succeeded by running:
     ```
     Rscript --version
     ```

Pre-compiled binaries are available for all required packages — no additional build tools are needed for a standard installation.
