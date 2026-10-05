; =====================================================================
; boot.asm — SimpleOS Boot Entry (Multiboot 1 compatible)
; =====================================================================
; This file sets up the very first instructions run when GRUB (or any
; Multiboot-compliant bootloader) loads our kernel.
;
; What it does:
;   1. Declares a Multiboot header so GRUB recognizes us as a kernel.
;   2. Defines the entry point (_start) that GRUB jumps to.
;   3. Sets up a small stack (required before calling any C code).
;   4. Calls our C kernel entry point (kernel_main).
;   5. Halts the CPU if the kernel ever returns (it shouldn't).
; =====================================================================

; ------------------------------------------------------------------
; Multiboot 1 header constants
; ------------------------------------------------------------------
; GRUB searches for a magic number aligned on a 4 KB boundary. The
; header tells GRUB what we want: page-aligned modules and a memory
; info map. We compute a checksum so that (magic + flags + checksum)
; equals zero — this is how GRUB validates the header.
; ------------------------------------------------------------------
MBALIGN  equ  1 << 0            ; Align loaded modules on 4 KB pages
MEMINFO  equ  1 << 1            ; Provide us with a memory map
FLAGS    equ  MBALIGN | MEMINFO ; Multiboot flag bits
MAGIC    equ  0x1BADB002        ; GRUB's "magic" Multiboot signature
CHECKSUM equ -(MAGIC + FLAGS)   ; Make (magic + flags + checksum) = 0

; ------------------------------------------------------------------
; Multiboot header section
; ------------------------------------------------------------------
; We place this in its own section so the linker can put it at the
; very start of the binary — where GRUB expects to find it.
; ------------------------------------------------------------------
section .multiboot
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM

; ------------------------------------------------------------------
; Stack setup
; ------------------------------------------------------------------
; C code needs a stack to store return addresses, local variables,
; function arguments, etc. The x86 stack grows downward, so the
; stack pointer (esp) must be set to the *end* of the stack region.
; ------------------------------------------------------------------
section .bss
align 16
stack_bottom:
    resb 16384                  ; Reserve 16 KB for the kernel stack
stack_top:

; ------------------------------------------------------------------
; Kernel entry point
; ------------------------------------------------------------------
; GRUB jumps here after loading the kernel into memory. We are
; already in 32-bit protected mode thanks to GRUB.
; ------------------------------------------------------------------
section .text
global _start:function (_start.end - _start)
_start:
    ; 1. Load the stack pointer with the top of our stack.
    mov esp, stack_top

    ; 2. Call our C kernel. We pass two arguments:
    ;    - eax = Multiboot magic number (should be 0x2BADB002)
    ;    - ebx = Physical address of the Multiboot info structure
    push ebx
    push eax
    extern kernel_main          ; kernel_main is defined in kernel.c
    call kernel_main

    ; 3. If kernel_main ever returns (it shouldn't), halt forever.
    ;    Disable interrupts first so an NMI can't wake us up.
    cli
.hang:
    hlt                         ; Halt the CPU until an interrupt
    jmp .hang                   ; Parachute loop in case we wake up
.end:
