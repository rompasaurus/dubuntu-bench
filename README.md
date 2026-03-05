# dubuntu-bench

A comprehensive CLI system benchmarking and info tool for Linux. Interactive TUI with single-keypress navigation, automatic tool installation, and result logging.

## Quick Start

```bash
git clone https://github.com/dubuntu/dubuntu-bench.git
cd dubuntu-bench
chmod +x bench.sh
./bench.sh
```

## Features

- **Interactive TUI** — polished menus with single-keypress navigation and color-coded output
- **System Info** — CPU, GPU, RAM, storage, motherboard/BIOS, temperatures, OS/kernel
- **Benchmark Suite** — CPU, GPU, memory, and storage benchmarks with one-click install
- **Result Logging** — timestamped logs in `results/` with a summary file
- **CLI Mode** — run benchmarks non-interactively via command-line flags

## Main Menu

```
[1] System Information     [6] Phoronix Test Suite
[2] CPU Benchmarks         [7] Temperature Monitor
[3] GPU Benchmarks         [8] Install All Dependencies
[4] Memory Benchmarks      [9] View Past Results
[5] Storage Benchmarks     [0] Exit
```

## Benchmarks

| Category | Tool | Description |
|----------|------|-------------|
| CPU | stress-ng | Multi-core stress test with configurable duration |
| CPU | sysbench | Prime number calculation (single + multi-threaded) |
| CPU | Geekbench 6 | Industry-standard CPU benchmark |
| GPU | glmark2 | OpenGL 2.0 benchmark |
| GPU | vkmark | Vulkan benchmark |
| GPU | Unigine Heaven/Valley/Superposition | GPU stress tests |
| Memory | sysbench memory | Memory bandwidth (read + write) |
| Memory | mbw | Memory bandwidth (MEMCPY, DUMB, MCBLOCK) |
| Storage | fio | Sequential read/write + random 4K IOPS |
| Storage | hdparm | Cached + buffered disk read speed |
| Suite | Phoronix Test Suite | Comprehensive benchmark framework |

## Usage

### Interactive Mode

```bash
./bench.sh
```

### CLI Mode

```bash
# Print system info
./bench.sh --info

# Run a specific benchmark
./bench.sh --run sysbench-cpu
./bench.sh --run fio

# Install all dependencies
./bench.sh --install all

# Check tool install status
./bench.sh --status

# View past results
./bench.sh --results

# Show help
./bench.sh --help
```

### Available Test Names

`stress-ng` `sysbench-cpu` `geekbench6` `glmark2` `vkmark` `unigine-heaven` `unigine-valley` `sysbench-memory` `mbw` `fio` `hdparm`

## Results

Benchmark results are saved to `results/` with timestamped filenames:

```
results/
├── summary.log                          # One-line summary of every run
├── sysbench-cpu_2026-03-05_14-30-00.log
├── fio_2026-03-05_14-35-00.log
└── glmark2_2026-03-05_14-40-00.log
```

## Dependencies

Most tools are installable via the built-in installer (`[8] Install All Dependencies`).

**APT packages:** stress-ng, sysbench, glmark2, vkmark, fio, hdparm, mbw, lm-sensors, s-tui, radeontop

**Custom installs:** Geekbench 6 (downloaded to `~/.local/share/`), Phoronix Test Suite (.deb), Unigine benchmarks (manual download)

## System Requirements

- Linux (Ubuntu/Debian-based recommended)
- Bash 4.0+
- `lspci` (from `pciutils`) for GPU detection
- Root/sudo for: RAM speed detection, hdparm, package installation

## License

MIT
