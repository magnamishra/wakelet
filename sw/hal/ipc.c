// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE.solderpad for details.
// SPDX-License-Identifier: SHL-0.51
//
// Magna Mishra

//Snitch calls this to put CROC to sleep 

#include <ipc.h>
#include <stdint.h>
#include <addr_map.h>

void wl_ipc_trigger() {
    *(volatile uint32_t *)(IPC_INT_TRIG) = 0x1;
}