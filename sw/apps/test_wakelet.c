// -------------------------------------------------------------------
// Address map (Snitch internal view, BaseOffset stripped by bridge)
// -------------------------------------------------------------------
#define DMEM_BASE      0x00020000   // wl_pkg::DataMemBaseAddr
#define CSR_BASE       0x00040000   // wl_pkg::CsrBaseAddr
#define PMEM_BASE      0x00050000   // wl_pkg::HwpeWmemBaseAddr
 
// -------------------------------------------------------------------
// Register write helper
// -------------------------------------------------------------------
#define reg32(base, off) ((volatile unsigned int *)((unsigned int)(base) + (unsigned int)(off)))
 
// -------------------------------------------------------------------
// Data mover workload
// Copies N words from src buffer to dst buffer in DMEM
// Replace this function with any workload
// -------------------------------------------------------------------
#define N_WORDS  8
#define SRC_OFF  0x00
#define DST_OFF  0x40


static void workload(void) {
    volatile unsigned int *src = reg32(DMEM_BASE, SRC_OFF);
    volatile unsigned int *dst = reg32(DMEM_BASE, DST_OFF);
    int i;
    for (i = 0; i < N_WORDS; i++) {
        dst[i] = src[i];
    }
}
 
// -------------------------------------------------------------------
// Entry point - must be first in binary at 0x0001_0000
// Section attribute forces linker to place this before data_move
// -------------------------------------------------------------------
 int main(void) {
    //remove start attribute because snitch's ctr0.S will handle stack
    // Run the workload replace with any function
    workload();
 
    // Signal completion to CROC
    // Drives wakelet_done_o high CROC MEIP fires
    *reg32(CSR_BASE, 0x08) = 0x1;
 
    // Spin - Snitch has nothing left to do
    while (1) {}
}