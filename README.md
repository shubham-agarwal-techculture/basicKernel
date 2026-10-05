# SimpleOS v0.1 — Minimal Educational x86 Kernel

A tiny, readable 32-bit protected-mode kernel written in C and NASM
assembly. It boots via GRUB (Multiboot 1), initializes a VGA text-mode
driver, prints a friendly welcome banner, then halts the CPU.

This project is intentionally **as simple as possible** — no paging,
no interrupts, no memory allocator, no multitasking. It exists purely
to teach the boot → C entry → screen I/O pipeline.

---

## What's in the box?

| File | Purpose |
|---|---|
| [boot.asm](boot.asm) | NASM entry point. Declares the Multiboot header so GRUB recognizes us, sets up a 16 KB stack, then calls `kernel_main()`. |
| [kernel.c](kernel.c) | C kernel. VGA text-mode driver (`putchar`, `write`, `clear`, `scroll`) + `kernel_main()` which prints the banner and halts. |
| [linker.ld](linker.ld) | GNU linker script. Packs `.multiboot` first (required), then `.text`/`.rodata`/`.data`/`.bss`, loading everything at 0x00100000 (1 MB). |
| [Makefile](Makefile) | Builds `kernel.bin`, wraps it in a bootable ISO with `grub-mkrescue`, and launches QEMU. |

---

## Build & Run — Quick Start (one command after setup)

```
make run
```

That's it. It compiles, creates `simpleos.iso`, and boots it in QEMU.

### Expected output in the QEMU window

```
================================================
  SimpleOS Kernel v0.1
================================================

Booted successfully using Multiboot protocol.
CPU is running in 32-bit protected mode.
VGA text mode driver initialized.

[ OK ] System ready. CPU will now halt.
[ OK ] You can safely close QEMU.

================================================
```

---

## Prerequisites (install once)

### Recommended: Windows + WSL (Ubuntu 22.04 or 24.04)

All of these commands run **inside your WSL shell**:

```bash
# 1. Install the host toolchain (gcc -m32 works great for such a tiny kernel)
sudo apt update
sudo apt install -y gcc-multilib nasm make grub-common xorriso mtools

# 2. Install QEMU for i386
sudo apt install -y qemu-system-x86

# 3. Verify tools exist
nasm -v && gcc --version && grub-mkrescue --version && qemu-system-i386 --version
```

Then just navigate to the project folder and run:
```bash
cd /mnt/d/path/to/basicKernel
make run
```

### Option B: Native Linux (Debian / Ubuntu)

Same package list as WSL above, minus the `/mnt/...` path.

### Option C: macOS

```bash
brew install nasm qemu
brew install grub               # note: x86_64-elf-gcc + xorriso still needed
```

You'll also need an `i686-elf-gcc` cross-compiler (homebrew's `gcc`
targets x86_64 by default). The Makefile auto-detects `i686-elf-gcc`
if it's on PATH.

---

## Other useful `make` targets

| Target | What it does |
|---|---|
| `make` / `make all` | Build the bootable ISO `simpleos.iso` |
| `make run` | Build and boot the ISO in QEMU (GRUB menu included) |
| `make run-kernel` | Skip GRUB, use QEMU's `-kernel` to load `kernel.bin` directly (faster) |
| `make clean` | Remove all object files, the kernel binary, ISO, and staging dir |

---

## Learning Tour — suggested reading order

1. **[boot.asm](boot.asm)** — the very first CPU instructions.
   Walks through the Multiboot header, stack setup, and the
   single `call kernel_main` bridge from asm into C.

2. **[linker.ld](linker.ld)** — why the Multiboot section must
   live inside the first 8 KB, why we load at 1 MB, what `.bss`
   actually is.

3. **[kernel.c](kernel.c)** — start at `kernel_main()` (bottom of
   file) and work upwards: VGA memory layout (0xB8000), the
   char/attribute 2-byte cell format, scrolling, newline/tab/backspace
   handling, and the final `cli; hlt` infinite loop.

---

## Why no interrupts, paging, GDT reprogramming, etc.?

Because GRUB already does the **bare minimum** for us:

- CPU is in 32-bit protected mode ✓
- A flat GDT covering 0..4 GB is loaded ✓
- A20 gate is enabled ✓
- Interrupts are **disabled** ✓

So we can jump straight to printing strings without 400 lines of
bootloader boilerplate. Perfect for teaching the essentials first.

---

## Troubleshooting

- **`grub-mkrescue: not found`** → `sudo apt install grub-common xorriso mtools`
- **`gcc: error: unrecognized command-line option '-m32'`** → install `gcc-multilib` (Debian/Ubuntu)
- **`kernel_main is defined but never used` warning** → ignore it, it's called from asm
- **QEMU shows "No bootable device"** → ensure `grub-mkrescue` completed without errors
- **QEMU window is empty / hangs** → try `make run-kernel` (skips GRUB menu) to confirm the kernel itself boots

---

## License

Public domain / CC0 — do whatever you want with this code, it's
intended as a teaching base.
