/* =====================================================================
   kernel.c — SimpleOS Kernel (32-bit Protected Mode)
   =====================================================================
   This is the heart of SimpleOS. It runs after GRUB has:
     1. Loaded us from disk into memory
     2. Switched the CPU into 32-bit protected mode
     3. Disabled interrupts (we leave them disabled)
     4. Set up a basic stack for us in boot.asm

   What we implement here — nothing fancy, just the bare minimum to
   prove we are alive and can talk to the screen:

     - VGA text-mode driver (80 x 25 characters, color)
         * terminal_clear()  — blank the entire screen
         * terminal_putchar() — write a single colored char
         * terminal_write()  — write a string
     - kernel_main() — the C entry point called from boot.asm

   ===================================================================== */

#include <stdint.h>
#include <stddef.h>

/* =====================================================================
   VGA Text Mode Constants
   =====================================================================
   The classic IBM VGA text buffer lives at physical address 0xB8000.
   Each on-screen character takes 2 bytes:
     Byte 0 — ASCII character code
     Byte 1 — Attribute byte:
       Bits 7..4 = background color (0..15)
       Bits 3..0 = foreground color (0..15)
   Screen resolution is fixed at 80 columns × 25 rows.
   ===================================================================== */
#define VGA_BUFFER    0xB8000
#define VGA_WIDTH     80
#define VGA_HEIGHT    25

/* --- 16 standard VGA color codes ---------------------------------- */
enum vga_color {
    VGA_COLOR_BLACK         = 0,
    VGA_COLOR_BLUE          = 1,
    VGA_COLOR_GREEN         = 2,
    VGA_COLOR_CYAN          = 3,
    VGA_COLOR_RED           = 4,
    VGA_COLOR_MAGENTA       = 5,
    VGA_COLOR_BROWN         = 6,
    VGA_COLOR_LIGHT_GREY    = 7,
    VGA_COLOR_DARK_GREY     = 8,
    VGA_COLOR_LIGHT_BLUE    = 9,
    VGA_COLOR_LIGHT_GREEN   = 10,
    VGA_COLOR_LIGHT_CYAN    = 11,
    VGA_COLOR_LIGHT_RED     = 12,
    VGA_COLOR_LIGHT_MAGENTA = 13,
    VGA_COLOR_LIGHT_BROWN   = 14,
    VGA_COLOR_YELLOW        = 14,
    VGA_COLOR_WHITE         = 15,
};

/* =====================================================================
   Global "terminal" state
   =====================================================================
   We remember where the cursor *should* be (row / column) and the
   default foreground / background colors we want to paint with.
   The actual VGA cursor hardware is NOT updated by this simple
   driver — we just keep a software position.
   ===================================================================== */
static size_t       terminal_row;
static size_t       terminal_column;
static uint8_t      terminal_color;
static uint16_t*    terminal_buffer;

/* =====================================================================
   vga_entry_color(fg, bg) — pack two 4-bit colors into 1 attribute byte
   ===================================================================== */
static inline uint8_t vga_entry_color(enum vga_color fg, enum vga_color bg)
{
    return fg | (bg << 4);
}

/* =====================================================================
   vga_entry(c, color) — pack a char + attribute into one 16-bit word
   ===================================================================== */
static inline uint16_t vga_entry(unsigned char c, uint8_t color)
{
    return (uint16_t) c | ((uint16_t) color << 8);
}

/* =====================================================================
   terminal_initialize() — reset our state and clear the screen
   ===================================================================== */
void terminal_initialize(void)
{
    terminal_row = 0;
    terminal_column = 0;

    /* Default style: light grey text on a black background */
    terminal_color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);

    /* Cast the magic physical address into a pointer we can write to */
    terminal_buffer = (uint16_t*) VGA_BUFFER;

    /* Blank every cell */
    for (size_t y = 0; y < VGA_HEIGHT; y++) {
        for (size_t x = 0; x < VGA_WIDTH; x++) {
            const size_t index = y * VGA_WIDTH + x;
            terminal_buffer[index] = vga_entry(' ', terminal_color);
        }
    }
}

/* =====================================================================
   terminal_setcolor(color) — change the default pen color
   ===================================================================== */
void terminal_setcolor(uint8_t color)
{
    terminal_color = color;
}

/* =====================================================================
   terminal_putentryat(c, color, x, y) — draw one char at (x, y)
   ===================================================================== */
void terminal_putentryat(char c, uint8_t color, size_t x, size_t y)
{
    const size_t index = y * VGA_WIDTH + x;
    terminal_buffer[index] = vga_entry(c, color);
}

/* =====================================================================
   terminal_scroll() — shift everything up one line, blank the last line
   ===================================================================== */
static void terminal_scroll(void)
{
    /* Move rows 1..24 into rows 0..23 */
    for (size_t y = 0; y < VGA_HEIGHT - 1; y++) {
        for (size_t x = 0; x < VGA_WIDTH; x++) {
            terminal_buffer[y * VGA_WIDTH + x] =
                terminal_buffer[(y + 1) * VGA_WIDTH + x];
        }
    }
    /* Blank the newly empty last line */
    for (size_t x = 0; x < VGA_WIDTH; x++) {
        terminal_buffer[(VGA_HEIGHT - 1) * VGA_WIDTH + x] =
            vga_entry(' ', terminal_color);
    }
    terminal_row = VGA_HEIGHT - 1;
}

/* =====================================================================
   terminal_newline() — advance to the start of the next line
   ===================================================================== */
static void terminal_newline(void)
{
    terminal_column = 0;
    if (++terminal_row == VGA_HEIGHT) {
        terminal_scroll();
    }
}

/* =====================================================================
   terminal_putchar(c) — write a single character at the cursor
   ===================================================================== */
void terminal_putchar(char c)
{
    unsigned char uc = (unsigned char) c;

    /* Handle special control characters */
    if (uc == '\n') {
        terminal_newline();
        return;
    }
    if (uc == '\r') {
        terminal_column = 0;
        return;
    }
    if (uc == '\t') {
        /* Tab: advance to next multiple of 8 */
        terminal_column = (terminal_column + 8) & ~7;
        if (terminal_column >= VGA_WIDTH) terminal_newline();
        return;
    }
    if (uc == '\b') {
        /* Backspace: move back one cell (don't erase) */
        if (terminal_column > 0) terminal_column--;
        return;
    }

    /* Wrap to next line if we've hit the right edge */
    if (terminal_column == VGA_WIDTH) {
        terminal_newline();
    }

    /* Normal printable character */
    terminal_putentryat(uc, terminal_color, terminal_column, terminal_row);
    terminal_column++;
}

/* =====================================================================
   terminal_write(data, size) — write a raw buffer of size bytes
   ===================================================================== */
void terminal_write(const char* data, size_t size)
{
    for (size_t i = 0; i < size; i++) {
        terminal_putchar(data[i]);
    }
}

/* =====================================================================
   terminal_writestring(str) — write a null-terminated string
   ===================================================================== */
void terminal_writestring(const char* str)
{
    /* Walk until we find the null terminator */
    size_t i = 0;
    while (str[i] != '\0') {
        i++;
    }
    terminal_write(str, i);
}

/* =====================================================================
   kernel_main(magic, mb_info) — THE kernel entry point
   =====================================================================
   Called from boot.asm. GRUB passes us:
     magic   — should always be 0x2BADB002 if GRUB loaded us correctly
     mb_info — pointer to the Multiboot info structure (we ignore it)
   ===================================================================== */
void kernel_main(uint32_t magic, void* mb_info)
{
    (void) magic;   /* Unused in this minimal kernel */
    (void) mb_info; /* Unused in this minimal kernel */

    /* --- 1. Start with a clean slate on screen ------------------ */
    terminal_initialize();

    /* --- 2. Build some pretty colors for our welcome banner ---- */
    uint8_t color_banner  = vga_entry_color(VGA_COLOR_CYAN,    VGA_COLOR_BLACK);
    uint8_t color_title   = vga_entry_color(VGA_COLOR_YELLOW,  VGA_COLOR_BLACK);
    uint8_t color_body    = vga_entry_color(VGA_COLOR_WHITE,   VGA_COLOR_BLACK);
    uint8_t color_ok      = vga_entry_color(VGA_COLOR_GREEN,   VGA_COLOR_BLACK);

    /* --- 3. Print a little decorative header ------------------- */
    terminal_setcolor(color_banner);
    terminal_writestring("================================================\n");

    terminal_setcolor(color_title);
    terminal_writestring("  SimpleOS Kernel v0.1\n");

    terminal_setcolor(color_banner);
    terminal_writestring("================================================\n\n");

    /* --- 4. Informational messages ----------------------------- */
    terminal_setcolor(color_body);
    terminal_writestring("Booted successfully using Multiboot protocol.\n");
    terminal_writestring("CPU is running in 32-bit protected mode.\n");
    terminal_writestring("VGA text mode driver initialized.\n\n");

    terminal_setcolor(color_ok);
    terminal_writestring("[ OK ] System ready. CPU will now halt.\n");
    terminal_writestring("[ OK ] You can safely close QEMU.\n");

    /* --- 5. More banner fluff ---------------------------------- */
    terminal_setcolor(color_banner);
    terminal_writestring("\n================================================\n");

    /* --- 6. Infinite halt loop --------------------------------- */
    /* We have nothing more to do. Disable interrupts and halt the
       CPU forever. `hlt` wakes up if an interrupt fires, so we
       immediately loop back and re-halt just in case. */
    for (;;) {
        __asm__ volatile ("cli; hlt");
    }

    /* Never reached — keeps compiler happy */
    __builtin_unreachable();
}
