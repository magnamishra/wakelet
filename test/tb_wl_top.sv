// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE.solderpad for details.
// SPDX-License-Identifier: SHL-0.51
//
// Sergio Mazzola <smazzola@iis.ee.ethz.ch>
// Magna Mishra   < Adapt test bench for pixel streaming >

// Changes 
// - Remove std::randomize for incoming data 
// - Add temporary check for wakelet_done 
// - Add wakelet_done to snitch monitoring 
// - Add timeout
// - Fix AXI burst width (8192 bytes) to 4096 bytes
// - Fix xbar address map to include HWPE config space
// - Simplified test: Snitch triggers both jobs
// - Updated test bench to include continuous streaming
// - Fix sensor loop: use join_none to avoid fork driver conflict
// - Fix sensor loop: send AW and W simultaneously to avoid deadlock
// - Change onject assignment between BUF_A and B, test for reduced frames

`include "axi/assign.svh"
module tb_wl_top
  import wl_pkg::*;
#()();

  //////////////////////
  // Testbench config //
  //////////////////////

  localparam time ClkPeriod = 10ns;
  localparam time TbTA = 2ns;
  localparam time TbTT = 8ns;

  localparam int ActMemNumBytesInit = 8192; // 2 buffers * 4096 bytes

  ////////////////////////////
  // Clock/reset generation //
  ////////////////////////////

  logic s_clk;
  logic s_rst_n;
  logic s_wakelet_done;

  clk_rst_gen #(
      .ClkPeriod ( ClkPeriod ),
      .RstClkCycles ( 5 )
  ) i_clk_gen (
      .clk_o ( s_clk ),
      .rst_no( s_rst_n )
  );

  ////////////////////////
  // AXI Lite Tb driver //
  ////////////////////////

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) axi_lite_drv2xbar ();

  AXI_LITE_DV #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) axi_lite_drv2xbar_dv (s_clk);

  `AXI_LITE_ASSIGN(axi_lite_drv2xbar, axi_lite_drv2xbar_dv)

  axi_test::axi_lite_driver #(
    .AW( AxiAddrWidth ),
    .DW( AxiDataWidth ),
    .TA ( TbTA ),
    .TT ( TbTT )
  ) axi_lite_tb_driver = new(axi_lite_drv2xbar_dv);

  task axi_lite_send_aw_w (
    input axi_test::axi_lite_driver #(
      .AW ( AxiAddrWidth ),
      .DW ( AxiDataWidth ),
      .TA ( TbTA ),
      .TT ( TbTT )
    ) axi_drv,
    input logic [AxiAddrWidth-1:0] addr,
    input axi_pkg::prot_t          prot,
    input logic [AxiDataWidth-1:0]   data,
    input logic [AxiDataWidth/8-1:0] strb
  );
    axi_drv.axi.aw_addr  <= #axi_drv.TA addr;
    axi_drv.axi.aw_prot  <= #axi_drv.TA prot;
    axi_drv.axi.aw_valid <= #axi_drv.TA 1;
    axi_drv.axi.w_data  <= #axi_drv.TA data;
    axi_drv.axi.w_strb  <= #axi_drv.TA strb;
    axi_drv.axi.w_valid <= #axi_drv.TA 1;
    axi_drv.cycle_start();
    while (axi_drv.axi.w_ready != 1) begin axi_drv.cycle_end(); axi_drv.cycle_start(); end
    axi_drv.cycle_end();
    axi_drv.axi.aw_addr  <= #axi_drv.TA '0;
    axi_drv.axi.aw_prot  <= #axi_drv.TA '0;
    axi_drv.axi.aw_valid <= #axi_drv.TA 0;
    axi_drv.axi.w_data  <= #axi_drv.TA '0;
    axi_drv.axi.w_strb  <= #axi_drv.TA '0;
    axi_drv.axi.w_valid <= #axi_drv.TA 0;
  endtask

  ////////////////////////
  // DUT AXI Lite buses //
  ////////////////////////

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) axi_lite_dut2tb ();

  axi_lite_req_t axi_lite_dut2tb_req;
  axi_lite_resp_t axi_lite_dut2tb_rsp;

  `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_dut2tb, axi_lite_dut2tb_req)
  `AXI_LITE_ASSIGN_TO_RESP(axi_lite_dut2tb_rsp, axi_lite_dut2tb)

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) axi_lite_tb2dut ();

  axi_lite_req_t axi_lite_tb2dut_req;
  axi_lite_resp_t axi_lite_tb2dut_rsp;

  `AXI_LITE_ASSIGN_TO_REQ(axi_lite_tb2dut_req, axi_lite_tb2dut)
  `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_tb2dut, axi_lite_tb2dut_rsp)

  ////////////////////
  // AXI Sim memory //
  ////////////////////

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) axi_lite_xbar2mem ();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH ( 32'd1 ),
    .AXI_USER_WIDTH ( 32'd1 )
  ) axi_xbar2mem ();

  axi_lite_to_axi_intf #(
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) i_sim_mem_axilite_to_axi (
    .in ( axi_lite_xbar2mem ),
    .slv_aw_cache_i ( '0 ),
    .slv_ar_cache_i ( '0 ),
    .out ( axi_xbar2mem )
  );

  axi_sim_mem_intf #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH ( 32'd1 ),
    .AXI_USER_WIDTH ( 32'd1 ),
    .APPL_DELAY ( TbTA ),
    .ACQ_DELAY ( TbTT )
  ) i_tb_sim_mem (
    .clk_i ( s_clk ),
    .rst_ni ( s_rst_n ),
    .axi_slv ( axi_xbar2mem ),
    .mon_w_valid_o ( /* Unconnected */ ),
    .mon_w_addr_o ( /* Unconnected */ ),
    .mon_w_data_o ( /* Unconnected */ ),
    .mon_w_id_o ( /* Unconnected */ ),
    .mon_w_user_o ( /* Unconnected */ ),
    .mon_w_beat_count_o ( /* Unconnected */ ),
    .mon_w_last_o ( /* Unconnected */ ),
    .mon_r_valid_o ( /* Unconnected */ ),
    .mon_r_addr_o ( /* Unconnected */ ),
    .mon_r_data_o ( /* Unconnected */ ),
    .mon_r_id_o ( /* Unconnected */ ),
    .mon_r_user_o ( /* Unconnected */ ),
    .mon_r_beat_count_o ( /* Unconnected */ ),
    .mon_r_last_o ( /* Unconnected */ )
  );

  //////////
  // Xbar //
  //////////

  localparam int unsigned TbXbarNumMasters = 2;
  localparam int unsigned TbXbarNumSlaves = 2;
  localparam int unsigned TbXbarNumRules = TbXbarNumSlaves + 1;
  typedef axi_pkg::xbar_rule_32_t tb_xbar_rule_t;

  localparam tb_xbar_rule_t [TbXbarNumRules-1:0] TbXbarAddrMap = '{
    '{ // Tb sim memory (everything above DUT memory)
        idx: 32'd0,
        start_addr: wl_pkg::DataMemBaseAddr + wl_pkg::DataMemOffset,
        end_addr: 32'hFFFF_FFFF
    },
    '{ // DUT memory range
        idx: 32'd1,
        start_addr: wl_pkg::InstrMemBaseAddr,
        end_addr: wl_pkg::DataMemBaseAddr + wl_pkg::DataMemOffset
    },
    '{ // Tb sim memory (everything below DUT memory)
        idx: 32'd0,
        start_addr: 32'h0000_0000,
        end_addr: wl_pkg::InstrMemBaseAddr
    }
  };

  localparam axi_pkg::xbar_cfg_t TbXbarCfg = '{
    NoSlvPorts:     TbXbarNumMasters,
    NoMstPorts:     TbXbarNumSlaves,
    MaxMstTrans:    32'd5,
    MaxSlvTrans:    32'd2,
    FallThrough:    1'b0,
    LatencyMode:    axi_pkg::CUT_SLV_PORTS,
    PipelineStages: 32'd0,
    AxiAddrWidth:   AxiAddrWidth,
    AxiDataWidth:   AxiDataWidth,
    NoAddrRules:    TbXbarNumRules,
    default:        '0
  };

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) tb_xbar_in [TbXbarNumMasters-1:0] ();
  `AXI_LITE_ASSIGN(tb_xbar_in[0], axi_lite_drv2xbar)
  `AXI_LITE_ASSIGN(tb_xbar_in[1], axi_lite_dut2tb)

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth )
  ) tb_xbar_out [TbXbarNumSlaves-1:0] ();
  `AXI_LITE_ASSIGN(axi_lite_xbar2mem, tb_xbar_out[0])
  `AXI_LITE_ASSIGN(axi_lite_tb2dut, tb_xbar_out[1])

  axi_lite_xbar_intf #(
    .Cfg ( TbXbarCfg ),
    .rule_t ( tb_xbar_rule_t )
  ) i_tbxbar (
    .clk_i ( s_clk ),
    .rst_ni ( s_rst_n ),
    .test_i ( 1'b0 ),
    .slv_ports ( tb_xbar_in ),
    .mst_ports ( tb_xbar_out ),
    .addr_map_i ( TbXbarAddrMap ),
    .en_default_mst_port_i ( '0 ),
    .default_mst_port_i ( '0 )
  );

  /////////////////////////////////
  // Wide AXI Tb driver (sensor) //
  /////////////////////////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH   ( AxiSlvIdWidth ),
    .AXI_USER_WIDTH ( AxiUserWidth )
  ) axi_wide_tb2dut ();

  axi_req_t axi_wide_tb2dut_req;
  axi_resp_t axi_wide_tb2dut_rsp;

  `AXI_ASSIGN_TO_REQ(axi_wide_tb2dut_req, axi_wide_tb2dut)
  `AXI_ASSIGN_FROM_RESP(axi_wide_tb2dut, axi_wide_tb2dut_rsp)

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH   ( AxiSlvIdWidth ),
    .AXI_USER_WIDTH ( AxiUserWidth )
  ) axi_wide_tb2dut_dv (s_clk);

  `AXI_ASSIGN(axi_wide_tb2dut, axi_wide_tb2dut_dv)

  axi_test::axi_driver #(
    .AW ( AxiAddrWidth ),
    .DW ( AxiDataWidth ),
    .IW ( AxiSlvIdWidth ),
    .UW ( AxiUserWidth ),
    .TA ( TbTA ),
    .TT ( TbTT )
  ) axi_wide_driver = new(axi_wide_tb2dut_dv);

  typedef axi_test::axi_ax_beat #(.AW(AxiAddrWidth), .IW(AxiSlvIdWidth), .UW(AxiUserWidth)) aw_beat_t;
  typedef axi_test::axi_w_beat #(.DW(AxiDataWidth), .UW(AxiUserWidth)) w_beat_t;
  typedef axi_test::axi_b_beat #(.IW(AxiSlvIdWidth), .UW(AxiUserWidth)) b_beat_t;

  // -------------------------------------------------------------------
  // Task: send one AXI burst to initialise a buffer.
  // A fresh beat object is allocated on every call so the driver never
  // aliases between transactions (fixes BUF_B always-zero bug).
  // -------------------------------------------------------------------
  task automatic send_axi_buffer (
    input logic [AxiAddrWidth-1:0]  base_addr,
    input logic [AxiDataWidth-1:0]  fill_data [],
    input int unsigned               num_bytes
  );
    automatic aw_beat_t aw = new();
    automatic w_beat_t  w  = new();
    automatic b_beat_t  b  = new();
    automatic int unsigned num_beats = num_bytes / (AxiDataWidth/8);

    aw.ax_id    = '0;
    aw.ax_addr  = base_addr;
    aw.ax_len   = num_beats - 1;
    aw.ax_size  = $clog2(AxiDataWidth/8);
    aw.ax_burst = 2'b01;
    axi_wide_driver.send_aw(aw);

    for (int i = 0; i < num_beats; i++) begin
      w.w_data = fill_data[i];
      w.w_strb = '1;
      w.w_last = (i == num_beats - 1);
      w.w_user = '0;
      axi_wide_driver.send_w(w);
    end

    axi_wide_driver.recv_b(b);
    @(posedge s_clk); // drain before next transaction
  endtask

  /////////
  // DUT //
  /////////

  logic s_irq;
  logic [DataWidth-1:0] s_eoc;

  `ifdef TARGET_ASIC wl_top_wrap `else wl_top `endif
    #() dut (
      .clk_i ( s_clk ),
      .rst_ni ( s_rst_n ),
      .axi_lite_slv_req_i ( axi_lite_tb2dut_req ),
      .axi_lite_slv_rsp_o ( axi_lite_tb2dut_rsp ),
      .axi_lite_mst_req_o ( axi_lite_dut2tb_req ),
      .axi_lite_mst_rsp_i ( axi_lite_dut2tb_rsp ),
      .irq_i ( s_irq ),
      .eoc_o ( s_eoc ),
      .int_trig_o ( /* unconnected */ ),
      .wakelet_done_o ( s_wakelet_done ),
      .axi_slv_req_i ( axi_wide_tb2dut_req ),
      .axi_slv_rsp_o ( axi_wide_tb2dut_rsp )
    );


  // Monitor activation memory writes
  generate
  for (genvar b = 0; b < 16; b++) begin : gen_mem_monitor
    always @(posedge s_clk) begin
      if (dut.i_hwpe_subsystem.hci_mem[b].req && 
          !dut.i_hwpe_subsystem.hci_mem[b].wen) begin
        $display("[MEM] t=%0t bank=%0d addr=0x%03x data=0x%08x be=0x%01x",
                 $time, b,
                 dut.i_hwpe_subsystem.hci_mem[b].add,
                 dut.i_hwpe_subsystem.hci_mem[b].data,
                 dut.i_hwpe_subsystem.hci_mem[b].be);
      end
    end
  end
  endgenerate

  // Monitor activation memory reads
  generate
  for (genvar b = 0; b < 16; b++) begin : gen_mem_read_monitor
    always @(posedge s_clk) begin
      if (dut.i_hwpe_subsystem.hci_mem[b].req && 
          dut.i_hwpe_subsystem.hci_mem[b].wen) begin
        $display("[MEM READ] t=%0t bank=%0d addr=0x%03x r_data=0x%08x",
                 $time, b,
                 dut.i_hwpe_subsystem.hci_mem[b].add,
                 dut.i_hwpe_subsystem.hci_mem[b].r_data);
      end
    end
  end
  endgenerate
  //////////
  // Test //
  //////////

  initial begin
    int file, ret;
    int w_num;
    string app_base, instr_mem_bin, data_mem_bin;
    logic [DataWidth-1:0] data;
    logic [AddrWidth-1:0] address;
    automatic axi_pkg::resp_t resp;

    /* Reset */
    axi_lite_tb_driver.reset_master();
    s_irq = 1'b0;
    axi_wide_driver.reset_master();

    @(posedge s_rst_n);

    fork
      // ------------------------------------------------------------------
      // Thread 1: flash instruction + data memories over AXI Lite
      // ------------------------------------------------------------------
      begin
        if (!$value$plusargs("bin=%s", app_base)) begin
          $fatal(1, "[TB] ERROR: No +bin=... argument specified");
        end
        instr_mem_bin = {app_base, ".instr_mem.bin"};
        data_mem_bin  = {app_base, ".data_mem.bin"};

        /* Preload instruction memory */
        $display("[TB] Flashing instruction memory from: %s", instr_mem_bin);
        file = $fopen(instr_mem_bin, "rb");
        if (!file) $fatal(1, "[TB] ERROR: Failed to open %s", instr_mem_bin);

        w_num = 0;
        address = InstrMemBaseAddr;
        while (!$feof(file)) begin
          ret = $fread(data, file);
          if (ret == 0) continue;
          else if (ret != 4) $fatal("[TB] ERROR: Partial read (%0d bytes), aborting", ret);
          data = {data[7:0], data[15:8], data[23:16], data[31:24]};
          axi_lite_send_aw_w(axi_lite_tb_driver, address, axi_pkg::prot_t'('0), data, '1);
          axi_lite_tb_driver.recv_b(resp);
          w_num++;
          address += 4;
        end
        $fclose(file);
        $info("[TB] Application flash complete. %0d words loaded in instruction memory.", w_num);

        /* Preload data memory */
        $display("[TB] Flashing data memory from: %s", data_mem_bin);
        file = $fopen(data_mem_bin, "rb");
        if (!file) $fatal(1, "[TB] ERROR: Failed to open %s", data_mem_bin);

        w_num = 0;
        address = DataMemBaseAddr;
        while (!$feof(file)) begin
          ret = $fread(data, file);
          if (ret == 0) continue;
          else if (ret != 4) $fatal("[TB] ERROR: Partial read (%0d bytes), aborting", ret);
          data = {data[7:0], data[15:8], data[23:16], data[31:24]};
          axi_lite_send_aw_w(axi_lite_tb_driver, address, axi_pkg::prot_t'('0), data, '1);
          axi_lite_tb_driver.recv_b(resp);
          w_num++;
          address += 4;
        end
        $fclose(file);
        $info("[TB] Data flash complete. %0d words loaded in SPM.", w_num);

        axi_lite_tb_driver.reset_master();
        @(posedge s_clk);
      end

      // ------------------------------------------------------------------
      // Thread 2: initialise activation memory (double-buffered BUF_A/B)
      //
      // Only 2 physical buffers exist; frames alternate between them:
      //   Frame 0 -> BUF_A (0x0000_0000)
      //   Frame 1 -> BUF_B (0x0000_1000)
      //   Frame 2 -> BUF_A (reused)
      //   Frame 3 -> BUF_B (reused)  ...
      //
      // Fresh beat objects are allocated inside send_axi_buffer() on every
      // call, preventing the driver from aliasing between transactions.
      // ------------------------------------------------------------------
      begin
        automatic logic [AxiDataWidth-1:0] zeros     [];
        automatic logic [AxiDataWidth-1:0] buf_b_data[];
        automatic int unsigned beats = 4096 / (AxiDataWidth/8);

        zeros      = new[beats];
        buf_b_data = new[beats];

        foreach (zeros[i])      zeros[i]      = '0;
        foreach (buf_b_data[i]) buf_b_data[i] = (i <= 5) ? '1 : '0; // beats 0-5: 0xFF (192 B), rest: 0x00

        $display("[TB] Initialising activation memory (double buffering, 2 physical buffers).");

        send_axi_buffer(32'h0000_0000, zeros,      4096);  // BUF_A: all zeros
        send_axi_buffer(32'h0000_1000, buf_b_data, 4096);  // BUF_B: 192B of 0xFF, rest zeros

        $info("[TB] Activation memory initialised. %0d bytes loaded.", ActMemNumBytesInit);
        axi_wide_driver.reset_master();
        @(posedge s_clk);
      end
    join

    /* Start program execution */
    `ifndef TARGET_ASIC
      if (!dut.i_core_subsystem.i_snitch.wfi_q) begin
        $display("[TB] Waiting for bootrom to complete...");
        @(posedge dut.i_core_subsystem.i_snitch.wfi_q);
      end
    `endif
    repeat(5) @(posedge s_clk);

    // Wake Snitch to configure and trigger datamover
    s_irq = #TbTA 1'b1;
    @(posedge s_clk);
    s_irq = #TbTA 1'b0;

    // Give Snitch time to configure datamover and reach wfi
    repeat(50000) @(posedge s_clk);
    $display("[TB] Starting sensor loop at %t", $time);

    // Wait for wakelet or timeout
    fork
      begin : wait_wakelet
        @(posedge s_wakelet_done);
        $display("[TB] Wakelet signaled CROC at %t - motion detected!", $time);
        $finish(0);
      end
      begin : timeout
        repeat(1500000) @(posedge s_clk);
        $error("[TB] ERROR: Timeout waiting for wakelet_done_o!");
        $finish(1);
      end
    join_any
    disable fork;

  end

endmodule