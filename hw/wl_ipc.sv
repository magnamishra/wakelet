// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE.solderpad for details.
// SPDX-License-Identifier: SHL-0.51
//
// Magna Mishra

//
   /// REGISTER MAP
   /// -------------------------------------------
   ///  Offset | Index | Description
   /// --------|-------|--------------------------
   ///    0x00 |     0 | INT_TRIG
   ///    0x04 |     1 | reserved
   ///    0x08 |     2 | reserved
   ///    0x0C |     3 | reserved
///

module wl_ipc #(
  parameter int unsigned NumRegs = 1,
  parameter type req_t = logic,
  parameter type rsp_t = logic,
  // Hardcoded parameters, do not modify
  localparam int unsigned DataWidth = 32
) (
    input logic clk_i,
    input  logic rst_ni,
    input  req_t slv_req_i,
    output rsp_t slv_rsp_o,
    // Expose useful register to CROC
    inout logic int_io,
    input logic int_ack_i
    
);

localparam int unsigned IdxWidth = (NumRegs > 1) ? $clog2(NumRegs) : 1;
localparam int unsigned BytesOffset = $clog2(DataWidth / 8);

logic [NumRegs-1:0][DataWidth-1:0] regfile_d, regfile_q;
logic [IdxWidth-1:0] rf_idx;
assign rf_idx = slv_req_i.q.addr[IdxWidth+BytesOffset-1:BytesOffset];

logic int_pending_d, int_pending_q;
assign int_io = int_pending_q ? 1'b0 : 1'bz; //active low 

typedef enum logic {
    WAIT_REQ = 1'd0,
    WAIT_RETIRE = 1'd1
} state_t;

state_t curr_state, next_state;

typedef struct packed {
    logic [IdxWidth-1:0] idx;
    logic wen;
} req_buf_t;

req_buf_t req_buf_d, req_buf_q;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      curr_state <= WAIT_REQ;
      regfile_q <= '0;
      req_buf_q <= '0;
      int_pending_q <= '0; 
    end else begin
      curr_state <= next_state;
      regfile_q <= regfile_d;
      req_buf_q <= req_buf_d;
      int_pending_q <= int_pending_d; 
    end
end

always_comb begin
    next_state = curr_state;
    regfile_d = regfile_q;
    req_buf_d = req_buf_q;
    int_pending_d = int_pending_q; 

    // outputs
    slv_rsp_o.p.data = '0;
    slv_rsp_o.p.error = '0;
    slv_rsp_o.p_valid = 1'b0;
    slv_rsp_o.q_ready = 1'b1;

    case (curr_state)
      WAIT_REQ: begin
        // request arrived from master
        if (slv_req_i.q_valid) begin
          // serve INT (will take effect in next cycle)
          //if (slv_req_i.q.write && rf_idx == 0) begin
            //int_pending_d = 1'b1; 
          //end
          // buffer req metadata to give resp in next cycle
          req_buf_d.idx = rf_idx;
          req_buf_d.wen = slv_req_i.q.write;
          next_state = WAIT_RETIRE;
        end
      end
      WAIT_RETIRE: begin
        slv_rsp_o.q_ready = 1'b0;
        slv_rsp_o.p_valid = 1'b1;
        // write req is already served
        // if read, keep serving until retired
        if (!req_buf_q.wen) begin
          slv_rsp_o.p.data = regfile_q[req_buf_q.idx];
        end
        // when master is ready to retire, go back to wait
        if (slv_req_i.p_ready) begin
          next_state = WAIT_REQ;
        end
      end
      default: begin
        next_state = WAIT_REQ;
      end
    endcase
    // outside the case statement, always check ack
    if (int_ack_i) begin
      int_pending_d = 1'b0;
    end
    //if snitch has to signal CROC to immediately wake-up again
    if (slv_req_i.q_valid && slv_req_i.q.write && rf_idx == 0) begin
        int_pending_d = 1'b1;  // new interrupt wins
    end 
end

endmodule
