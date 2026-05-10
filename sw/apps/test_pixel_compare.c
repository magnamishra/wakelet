// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE.apache for details.
// SPDX-License-Identifier: Apache-2.0
/*
 * Test the HWPE Datamover after adapting it for pixel comparison.
 */

#include <stdint.h>
#include <stddef.h>
#include <addr_map.h>
#include <registers.h>
#include <hwpe_datamover.h>

#define reg32(base, off) ((volatile unsigned int *)((unsigned int)(base) + (unsigned int)(off)))

#define FRAME_WIDTH        64
#define FRAME_HEIGHT       64
#define FRAME_SIZE_BYTES   (FRAME_WIDTH * FRAME_HEIGHT)    // 4096 bytes
#define FRAME_SIZE_WORDS   (FRAME_SIZE_BYTES / DATAMOVER_BW_BYTE) // 128 words

#define BUF_A              (ACT_MEM_BASE) // for data mover 
#define BUF_B              (ACT_MEM_BASE + FRAME_SIZE_BYTES) // for sensor 
#define OUT_ADDR           (DATA_MEM_BASE) // Use this as scratch area 

#define REGISTER_WAKELET_DONE  (CSR_BASE + 0x08)
#define PIXEL_THRESHOLD        100
#define MXI_BIT                20

// Trap vector over-ride 
// Why do this - in Ctr0.S, trap vector resets Snitch's PC by default. 
// When MXIP fires, Snitch pauses
// After the pause, Snitch should not reconfigure datamover or start PC from scratch. 
void __attribute__((interrupt)) trap_vector(void) {
    *reg32(CSR_BASE, 0x08) = 0x1;
}

// Main starts here 

int main(void) {

    // Soft clear datamover state
    DATAMOVER_WRITE_CMD(DATAMOVER_SOFT_CLEAR, DATAMOVER_SOFT_CLEAR_ALL);
    asm volatile("nop");
    asm volatile("nop");
    
    // Unmask 
    asm volatile("csrs mie, %0" :: "r"(1 << MXI_BIT));

    // Write pixel difference threshold to generic_params[0]
    DATAMOVER_WRITE_GENERIC_PARAM(DATAMOVER_REG_GENERIC_PARAMS_0, PIXEL_THRESHOLD);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_PTR,        BUF_A);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_PTR,       OUT_ADDR);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_TOT_LEN,       FRAME_SIZE_WORDS);
    // Input: 2D addressing for 64x64 frame
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D0_LEN,     FRAME_WIDTH  / (DATAMOVER_BW_BYTE));  // 2 words per row
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D0_STRIDE,  DATAMOVER_BW_BYTE);                   // 32 bytes
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D1_LEN,     FRAME_HEIGHT);                        // 64 rows
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D1_STRIDE,  FRAME_WIDTH);                         // 64 bytes
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D2_STRIDE,  0);                                   // 1x channel 
    // Output   
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D0_LEN,    FRAME_WIDTH  / (DATAMOVER_BW_BYTE));  // 2 words per row
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D0_STRIDE, DATAMOVER_BW_BYTE);                   // 32 bytes
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D1_LEN,    FRAME_HEIGHT);                        // 64 rows
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D1_STRIDE, FRAME_WIDTH);                         // 64 bytes
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D2_STRIDE, 0);                                   // 1x channel  
    
    // Acquire a context slot
    // Taken from hwpe_ctrl_slave 
    DATAMOVER_WRITE_CMD(DATAMOVER_ACQUIRE, 0);
    asm volatile("nop");
    asm volatile("nop");
    // Trigger DM 
    DATAMOVER_WRITE_CMD(DATAMOVER_COMMIT_AND_TRIGGER, DATAMOVER_TRIGGER_CMD);
    
    asm volatile("wfi");

    return 0;
} 
