// Copyright 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE.apache for details.
// SPDX-License-Identifier: Apache-2.0
//
// Magna Mishra < added for interrupt >

#include <addr_map.h>
#ifndef __IPC_H__
#define __IPC_H__

/*
 * REGISTER MAP
 * -------------------------------------------
 *  Offset | Description
 * --------|----------------------------------
 *  0x0000 | INT_TRIG - write to assert interrupt to CROC
 *  0x0004 | reserved
 *  0x0008 | reserved
 *  0x000C | reserved
 */

#define IPC_INT_TRIG (IPC_BASE + 0x00000000)

void wl_ipc_trigger(void);

#endif // __IPC_H__