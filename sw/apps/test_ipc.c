// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE.apache for details.
// SPDX-License-Identifier: Apache-2.0
//
// Magna Mishra 



/*
 * Test the interrupt call and acknowledge between CROC and Wakelet
 */

#include <stdint.h>
#include <addr_map.h>

int main(void) {
    *(volatile uint32_t *)(CSR_BASE + 0x04) = 0x1;
    *(volatile uint32_t *)(CSR_BASE + 0x08) = 0x1;
    return 0;
}