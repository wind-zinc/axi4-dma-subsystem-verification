# AXI-Lite DECERR Handshake Fix

## Reason

The crossbar could return `DECERR/BVALID` for an unmapped write before the matching W-channel handshake.

## Changes

- Added a per-input W-response credit counter.
- Incremented it on `WVALID && WREADY` and decremented it when a B response leaves the response FIFO.
- Gated only the synthetic DECERR `BVALID` with an available W credit.
- Kept the original vendor expression as a comment; mapped OKAY/SLVERR paths are unchanged.

## Result

An unmapped write now returns DECERR only after its W beat is accepted. The counter also preserves correctness for multiple outstanding writes.
