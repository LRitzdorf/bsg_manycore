//-----------------------------------------------------------------------------
// File Name: dual_cl_decode.sv
// Author: Keith Phou, Lucas Ritzdorf
// Date: 12/9/24
// Description: Higher level decoder making use of two cldecoder instances to dual issue instructions 
//-----------------------------------------------------------------------------

`include "bsg_vanilla_defines.svh"

// Module Declaration
module dual_cl_decode 
import bsg_vanilla_pkg::*;
import bsg_manycore_pkg::*;
(
    input clk_i
  , input reset_i
  , input instruction_s instruction_i [0:1]
  , output decode_s decode_o
  , output fp_decode_s fp_decode_o
  , output do_single_issue
  , output is_int
);

    decode_s decode_intermediate [0:1];
    fp_decode_s fp_decode_intermediate [0:1];

    cl_decode cl_decode_inst1 (
        .instruction_i(instruction_i[0]), 
        .decode_o(decode_intermediate[0]), 
        .fp_decode_o(fp_decode_intermediate[0]) 
    );    

    cl_decode cl_decode_inst2 (
        .instruction_i(instruction_i[1]), 
        .decode_o(decode_intermediate[1]),
        .fp_decode_o(fp_decode_intermediate[1])
    );

    // Determine if there is a dependency
    // check if the second address uses rs1
    logic write_read_dependency = 
        decode_intermediate[0].write_rd & 
        (decode_intermediate[0].rd == decode_intermediate[1].rs1 | 
         decode_intermediate[0].rd == decode_intermediate[1].rs2) & 
        decode_intermediate[1].read_rs2;

    logic write_write_dependency = 
        decode_intermediate[0].write_rd & 
        decode_intermediate[1].write_rd & 
        (decode_intermediate[0].rd == decode_intermediate[1].rd);

    logic has_dependency = write_read_dependency | write_write_dependency;    

    // single issue any op codes that mess with program counter
    // When to *NOT* dual-issue instructions:
    // - First instruction is a special operation:
    //   - Fence
    //   - Send/recv barrier
    //   - CSR
    //   - MRET
    //   - Conditional branch
    //   - jal and jalr (jumping)
    //   - auipc
    // - Two instructions of same type (INT/FP)

    logic single_issue_same_type, single_issue_special;

    // Treat FP load operations as INT ops so they can dual issue with FP ops
    logic is_fp_load_0, is_fp_load_1;
    assign is_fp_load_0 = decode_intermediate[0].is_load_op && decode_intermediate[0].is_fp_op;
    assign is_fp_load_1 = decode_intermediate[1].is_load_op && decode_intermediate[1].is_fp_op;

    // Determine if both instructions are of the same type (INT/FP), consider FP loads as INT
    assign single_issue_same_type =
        ((decode_intermediate[0].is_fp_op && !is_fp_load_0) &&
         (decode_intermediate[1].is_fp_op && !is_fp_load_1)) || // Both are true FP ops
        ((!decode_intermediate[0].is_fp_op || is_fp_load_0) &&
         (!decode_intermediate[1].is_fp_op || is_fp_load_1)) || // Both are INT/FP load ops
        (is_fp_load_0 && is_fp_load_1); // Prevent two FP loads from dual-issuing

    // single issue any special instructons, check first instruction
    // included jump instructs in case of jumping, they assume PC+4 
    assign  single_issue_special = 
        decode_intermediate[0].is_fence_op ||
        decode_intermediate[0].is_barsend_op ||
        decode_intermediate[0].is_barrecv_op ||
        decode_intermediate[0].is_csr_op ||
        decode_intermediate[0].is_mret_op ||
        decode_intermediate[0].is_branch_op || 
        decode_intermediate[0].is_jal_op || // Jump and link
        decode_intermediate[0].is_jalr_op || // Jump and link reg
        decode_intermediate[0].is_auipc_op;

    assign do_single_issue = has_dependency  || single_issue_same_type || single_issue_special;

    // Indicate if instruction 0 or 1 are true INT op (excluding FP laod)
    always_comb begin
        if (!decode_intermediate[0].is_fp_op) begin
            is_int = 0;
        end else if (!decode_intermediate[1].is_fp_op) begin
            is_int = 1;
        end else begin
            is_int = 'x; // Neither instruction is INT (both are FP)
        end
    end

    // State to track single-issue progress
    logic single_issue_state; // 0: Issue first instruction, 1: Issue second instruction

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            single_issue_state <= 1'b0;
        end else if (do_single_issue) begin
            single_issue_state <= ~single_issue_state; // Toggle state during single-issue mode
        end else begin
            single_issue_state <= 1'b0; // Reset state during dual-issue
        end
    end

    // OR both lower level decoders if its dual; instructions 
    // if single issue only execute first instruction
    always_comb begin
        if (do_single_issue) begin
            if (single_issue_state) begin
                decode_o = decode_intermediate[1]; // Second instruction in single-issue mode
                fp_decode_o = fp_decode_intermediate[1];
            end else begin
                decode_o = decode_intermediate[0]; // First instruction in single-issue mode
                fp_decode_o = fp_decode_intermediate[0];
            end
        end else begin
            decode_o = decode_intermediate[0] | decode_intermediate[1]; // Dual-issue
            fp_decode_o = fp_decode_intermediate[0] | fp_decode_intermediate[1];
        end
    end

endmodule
