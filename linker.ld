/* =====================================================================
   linker.ld — SimpleOS Linker Script
   =====================================================================
   The linker script tells the GNU linker (ld) exactly how to arrange
   our compiled pieces into the final kernel binary. The most important
   rule for Multiboot 1 is: the magic Multiboot header (from boot.asm's
   .multiboot section) must appear within the FIRST 8192 BYTES of the
   executable, aligned on a 4-byte boundary.

   We also specify that the kernel should be loaded at the classic
   1 MB (0x00100000) mark — standard for x86 hobby OS kernels.
   ===================================================================== */

/* ------------------------------------------------------------------
   ENTRY — where execution begins (symbol in boot.asm)
   ------------------------------------------------------------------ */
ENTRY(_start)

/* ------------------------------------------------------------------
   SECTIONS — lay out the binary image in memory at 0x00100000 (1 MB)
   ------------------------------------------------------------------ */
SECTIONS
{
    /* Start the kernel at 1 MB */
    . = 0x00100000;

    /* ----------------------------------------------------------------
       .text — executable code. Put .multiboot FIRST so the header is
       within the first 8 KB of the file (required by GRUB).
       ---------------------------------------------------------------- */
    .text ALIGN(4K) :
    {
        /* Boot.asm's Multiboot magic header goes RIGHT HERE first */
        KEEP(*(.multiboot))

        /* All .text sections (our actual machine code) */
        *(.text)
        *(.text.*)
    }

    /* ----------------------------------------------------------------
       .rodata — read-only data (string literals, const globals, etc.)
       ---------------------------------------------------------------- */
    .rodata ALIGN(4K) :
    {
        *(.rodata)
        *(.rodata.*)
    }

    /* ----------------------------------------------------------------
       .data — initialized read/write global variables
       ---------------------------------------------------------------- */
    .data ALIGN(4K) :
    {
        *(.data)
        *(.data.*)
    }

    /* ----------------------------------------------------------------
       .bss — uninitialized global variables (zeroed by convention).
       The bootloader zeroes .bss for us. The symbol `_bss_end` marks
       where it finishes, and `_bss_start` where it begins.
       ---------------------------------------------------------------- */
    .bss ALIGN(4K) :
    {
        _bss_start = .;
        *(COMMON)
        *(.bss)
        *(.bss.*)
        _bss_end = .;
    }

    /* ----------------------------------------------------------------
       Handy end marker — if we ever need the total size of the kernel
       image we can subtract start address from `_end`.
       ---------------------------------------------------------------- */
    _end = .;

    /* Drop debug / comment sections so the binary stays small */
    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame)
        *(.note.*)
    }
}
