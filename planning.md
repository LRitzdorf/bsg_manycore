Architecture:
- Fetch unit must pass on two instructions at once, instead of just one
- New high-level decoder, instantiating two `cl_decode` instances
  - Can issue non-overlapping FP+INT instructions in parallel
  - Just `OR` together control bits for INT and FP structs
- Block interrupts when in the middle of a sequence of two single-issues?

When to *NOT* dual-issue instructions:
- Two instructions of same type (INT/FP)
- Register dependence:
  - Write-before-read
  - Write-before-write, if to same address
- Conditional branch as first instruction

FP register file:
 - Add second port
 - Second port gets write priority, if two writes occur to the same address (should™ never happen, but safest to create well-defined behavior anyway)
