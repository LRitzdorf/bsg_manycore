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
  input instruction_s instruction_i [0:1]
  , output decode_s decode_o
  , output fp_decode_s fp_decode_o
  , output do_single_issue // name?
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
    logic write_read_dependency = cl_decode_inst1.write_rd & (cl_decode_inst1.rd == cl_decode_inst2.rs1 | cl_decode_inst1.rd == cl_decode_inst2.rs2) & cl_decode_inst2.read_rs2;
    logic write_write_dependency = cl_decode_inst1.write_rd & cl_decode_inst2.write_rd & (cl_decode_inst1.rd == cl_decode_inst2.rd);

    logic has_dependency = write_read_dependency | write_write_dependency;    

    // single issue any op codes that mess with program counter
    // single issue any op codes that mess with program counter
    // When to *NOT* dual-issue instructions:
    // - First instruction is a special operation:
    //   - Fence
    //   - Send/recv barrier
    //   - CSR
    //   - MRET
    //   - Conditional branch
    // - Two instructions of same type (INT/FP)

    logic single_issue_pc_op, single_issue_same_type, single_issue_special;

    //assign single_issue_pc_op

    // Should we consider no op intructions for single issue as well?
    localparam instruction_t NO_OP = 32'h00000013; // Standard no-op RISC V

    assign single_issue_same_type = 
        (decode_intermediate[0].is_fp_op && decode_intermediate[1].is_fp_op) || // both FP
        (!decode_intermediate[0].is_fp_op && !decode_intermediate[1].is_fp_op); // both INT/regular instruction, this check might have false positives?

    // single issue any special instructons
    assign  single_issue_special = 

    //assign do_single_issue = has_dependency || any single issue cond 


    // OR both lower level decoders
    assign decode_o = decode_intermediate[0] | decode_intermediate[1]; 
    assign fp_decode_o = fp_decode_intermediate[0] | fp_decode_intermediate[1]; 


endmodule
