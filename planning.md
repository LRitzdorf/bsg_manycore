## Architecture Planning

Architecture:
- Fetch unit must pass on two instructions at once, instead of just one
- New high-level decoder, instantiating two `cl_decode` instances
  - Can issue non-overlapping FP+INT instructions in parallel
  - Just `OR` together control bits for INT and FP structs
- Block interrupts when in the middle of a sequence of two single-issues
- Provide feedback signal to icache when we're single-issuing, causing it to "freeze" its outputs for an additional clock cycle

When to *NOT* dual-issue instructions:
- Two instructions of same type (INT/FP)
- Register dependence:
  - Write-before-read
  - Write-before-write, if to same address
    - To check for register dependence:
      - Does first instruction's RD match second instruction's RS1 or RS2?
      - NOTE: Decoder also provides `write_rd`, `read_rs[12]` bits that we can use. e.g. if first instruction doesn't write RD, there can be no dependence
- Conditional branch as first instruction

FP register file:
 - Add second port
 - Second port gets write priority, if two writes occur to the same address (should™ never happen, but safest to create well-defined behavior anyway)

icache branch prediction:
- Dual-issue: predict second instruction's jump target
- Single-issue:
  - First cycle: predict first instruction's jump target
  - Second cycle: predict second instruction's jump target


## Report Notes

- Icache stall signal is a long combinational path; this would limit max clock speed in real hardware
