// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE.apache for details.
// SPDX-License-Identifier: Apache-2.0
/*
 * Test the HWPE Datamover after adapting it for pixel comparison.
 * Update MXI_BIT to 20 
 * Ideally MXI interrupt should be used at bit 19 
 * We are using MCI to align with original Snitch cluster used for Wakelet
 * This simplies the code Snitch bootrom already sets MCI 
 * Snitch doesn't trigger the datamover, initial code has this bug 
 * Just trigger one operation for now and see if the wakeup works 
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
#define BUF_A              (ACT_MEM_BASE)
#define BUF_B              (ACT_MEM_BASE + FRAME_SIZE_BYTES)
#define OUT_ADDR           (DATA_MEM_BASE)
#define REGISTER_WAKELET_DONE  (CSR_BASE + 0x08)
#define PIXEL_THRESHOLD        100

void __attribute__((interrupt)) trap_vector(void) {
    *reg32(CSR_BASE, 0x08) = 0x1;
    //no mret -> loop or wfi
    while(1) asm volatile("wfi");
}

int main(void) {

    // Enable global interrupts (set MIE in mstatus)
    asm volatile("csrsi mstatus, 8");
    asm volatile("csrs mie, %0" :: "r"(1 << 19));

    // Soft clear datamover state
    DATAMOVER_WRITE_CMD(DATAMOVER_SOFT_CLEAR, DATAMOVER_SOFT_CLEAR_ALL);
    asm volatile("nop");
    asm volatile("nop");

    // Write threshold to generic_params[0]
    DATAMOVER_WRITE_GENERIC_PARAM(DATAMOVER_REG_GENERIC_PARAMS_0, PIXEL_THRESHOLD);

    // Job 1: FILL from BUF_A
    DATAMOVER_WRITE_CMD(DATAMOVER_ACQUIRE, 0);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_PTR,        BUF_A);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_PTR,       OUT_ADDR);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_TOT_LEN,       FRAME_SIZE_WORDS);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D0_LEN,     FRAME_WIDTH / DATAMOVER_BW_BYTE);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D0_STRIDE,  DATAMOVER_BW_BYTE);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D1_LEN,     FRAME_HEIGHT);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D1_STRIDE,  FRAME_WIDTH);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_IN_D2_STRIDE,  0);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D0_LEN,    FRAME_WIDTH / DATAMOVER_BW_BYTE);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D0_STRIDE, DATAMOVER_BW_BYTE);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D1_LEN,    FRAME_HEIGHT);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D1_STRIDE, FRAME_WIDTH);
    DATAMOVER_WRITE_REG(DATAMOVER_REG_OUT_D2_STRIDE, 0);
    DATAMOVER_WRITE_CMD(DATAMOVER_COMMIT_AND_TRIGGER, DATAMOVER_TRIGGER_CMD);

    // Sleep  wait for pixel_wakeup via mcip
    asm volatile("wfi");
    return 0;
}
