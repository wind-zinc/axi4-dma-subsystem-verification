# AXI-Lite DECERR Handshake Fix

## Reason

The crossbar could return `DECERR/BVALID` for an unmapped write before the matching W-channel handshake.

## Changes

- Added an error-only W-credit counter; local `DECERR BVALID` is asserted only after the matching W handshake.
- Gated source-side `WREADY` and W state updates with a valid write command.
- Reset `w_select_reg`, `w_drop_reg`, and `w_select_valid_reg` together.
- Suppressed all downstream `BREADY` signals while a local `DECERR` is at the response head.
- Added simulation-only checks for credit bounds and invalid error-routing state.

## Result

An unmapped write now returns DECERR only after its W beat is accepted. The counter also preserves correctness for multiple outstanding writes.
