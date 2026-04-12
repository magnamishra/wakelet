// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE.apache for details.
// SPDX-License-Identifier: Apache-2.0
//
// Magna Mishra 



/*
 * Test the interrupt call and acknowledge between CROC and Wakelet
 */

#include <stdint.h>
#include <ipc.h>

int main(void) {
    // Trigger interrupt to CROC ? signal it to go to sleep
    wl_ipc_trigger();
    
    return 0;
}