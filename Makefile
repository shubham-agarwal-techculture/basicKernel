# =====================================================================
# Makefile — SimpleOS v0.1
# =====================================================================
# Builds a bootable kernel image and ISO for x86_32 (i686-elf).
#
# Required tools:
#   nasm                — assemble boot.asm
#   i686-elf-gcc        — freestanding C compiler (or plain gcc -m32)
#   i686-elf-ld         — linker (or plain ld -m elf_i386)
#   grub-mkrescue       — create bootable ISO (needs xorriso / mtools)
#   qemu-system-i386    — run the kernel
#
# On Windows: use WSL (Ubuntu), then `apt install gcc nasm make
# grub-common xorriso mtools qemu-system-x86` plus the i686-elf
# cross-compiler (or use -m32 with host gcc on a multiarch install).
# =====================================================================

# ----- Toolchain -----------------------------------------------------
# Try i686-elf-* cross-compiler first; fall back to host gcc/ld -m32.
# Either works for this tiny freestanding kernel.
AS      ?= nasm
CC      ?= $(shell which i686-elf-gcc 2>/dev/null || echo gcc)
LD      ?= $(shell which i686-elf-ld  2>/dev/null || echo ld)

# ----- Flags ---------------------------------------------------------
# `-ffreestanding`  = no standard library, no OS assumptions
# `-m32`            = emit 32-bit x86 code (host-gcc fallback)
# `-nostdlib`       = don't link libc / crt0 (we have our own entry)
CFLAGS   = -ffreestanding -m32 -O2 -Wall -Wextra -std=c99 -pedantic
ASFLAGS  = -f elf32
LDFLAGS  = -m elf_i386 -nostdlib

# ----- Files ---------------------------------------------------------
BOOT_SRC  = boot.asm
KERNEL_SRC= kernel.c
LINKER    = linker.ld

BOOT_OBJ  = boot.o
KERNEL_OBJ= kernel.o
KERNEL_BIN= kernel.bin
ISO_DIR   = isodir
ISO_FILE  = simpleos.iso

# =====================================================================
# Default target: build the bootable ISO
# =====================================================================
all: $(ISO_FILE)

# ----- Assemble boot.asm → boot.o ------------------------------------
$(BOOT_OBJ): $(BOOT_SRC)
	$(AS) $(ASFLAGS) $(BOOT_SRC) -o $(BOOT_OBJ)

# ----- Compile kernel.c → kernel.o -----------------------------------
$(KERNEL_OBJ): $(KERNEL_SRC)
	$(CC) $(CFLAGS) -c $(KERNEL_SRC) -o $(KERNEL_OBJ)

# ----- Link everything → kernel.bin ----------------------------------
$(KERNEL_BIN): $(BOOT_OBJ) $(KERNEL_OBJ) $(LINKER)
	$(LD) $(LDFLAGS) -T $(LINKER) -o $(KERNEL_BIN) $(BOOT_OBJ) $(KERNEL_OBJ)

# ----- Build the bootable ISO structure -----------------------------
$(ISO_DIR)/boot/grub/grub.cfg:
	mkdir -p $(ISO_DIR)/boot/grub
	printf 'menuentry "SimpleOS v0.1" {\n    multiboot /boot/%s\n}\n' \
	    $(KERNEL_BIN) > $(ISO_DIR)/boot/grub/grub.cfg

$(ISO_DIR)/boot/$(KERNEL_BIN): $(KERNEL_BIN) $(ISO_DIR)/boot/grub/grub.cfg
	mkdir -p $(ISO_DIR)/boot
	cp $(KERNEL_BIN) $(ISO_DIR)/boot/$(KERNEL_BIN)

# ----- Generate the ISO image ---------------------------------------
$(ISO_FILE): $(ISO_DIR)/boot/$(KERNEL_BIN)
	grub-mkrescue -o $(ISO_FILE) $(ISO_DIR) 2>/dev/null

# =====================================================================
# Run the kernel in QEMU
# =====================================================================
run: $(ISO_FILE)
	qemu-system-i386 -cdrom $(ISO_FILE) -boot d -m 32

# Run just the raw kernel binary (skips GRUB, uses QEMU's -kernel)
run-kernel: $(KERNEL_BIN)
	qemu-system-i386 -kernel $(KERNEL_BIN) -m 32

# =====================================================================
# Housekeeping
# =====================================================================
clean:
	rm -f $(BOOT_OBJ) $(KERNEL_OBJ) $(KERNEL_BIN) $(ISO_FILE)
	rm -rf $(ISO_DIR)

.PHONY: all run run-kernel clean
