# HP 8904A Multifunction Synthesizer, DC - 600 kHz

## Problem Statement

HP 8904A Multifunction Synthesizer with firmware **08904-87007** (A2U12 EPROM) intermittently hangs the HP-IB bus when the instrument is acting as a talker. The hang can occur after a just a few successful GPIB commands or after over ten thousand successful commands (note that "HP-IB" and "GPIB" are interchangeably here; HP-IB was invented at HP and this was the name used by HP, but more generally it has been referred to as GPIB). When hung, the **talk LED stays on** and the **front panel remains responsive** — only GPIB becomes completely unresponsive. Power cycling is required to recover.

The problem is more frequent with fast HP-IB controllers. HP documented this in the service manual (page 7-2) and released firmware **08904-87010** as a fix (with no need to update the firmware in A2U13 EPROM). The 08904-87010 firmware is unobtainable from the manufacturer, and attempts to obtain it over a secondary market have failed.

## Guidelines

The directory listings `a2u12.asm` and `a2u13.asm` contain comments from prior work on trying to understand the code. Whenever you see an error in the comments, make a correction. Correctness is exteremely important in these files. As you gain understanding, add this to the comments as well. If you are not certain about something, make that clear in the comment. Do not write any assumptions as if they are fact. The comments in the directory listings should stand on their own, and not refer to documents such as this markdown file.

Make any corrections to overview.md (this file) if you find errors or learn more information that is helpful in debugging the HP-IB communication issue. As you update your understanding, modify this file to keep it up to date. You must similarly make your understanding clear here, as to whether a statement is fact you can verify, or just a working hypothesis. Mark any tentative statements as such.

When making updates based on new evidence or data, only state the facts as we now know them. We do not want to pollute our code comments or working documents (such as this one) with references to past thoughts or hypotheses that were proven wrong, just state what is now known. Stating what we got wrong before is not useful (no "old data was incomplete, so we replaced it with this new data..."). We can preserve the results of prior experiments, or the progression of experiments, as those results are always true and not bound to a particular timeline.

Many PDF documents are provided to you. Some of these documents are scans of varying quality. If you have any trouble reading them, don't guess, ask for help in interpreting them.

## Our task

We must first understand and document the root cause of the GPIB stall issue. This can be performed through code analysis in conjunction with experimental tests and measurements. Experimental ROM images may be built and loaded into A2U12 as part of these experiments.

Once the root cause is determined, we want to create a patch for A2U12 that fixes the bug.

**Status: the captured `*IDN?` stall family is identified as a lost-IRQ race at `$208D-$2094`, and the remaining `FRA?` stall seen with the latch-only ROM is still very likely tied to the ISR1-before-ISR2 read order at `$10DF`.** The permanent combined fixed ROM `a2u12_fix.bin` keeps the byte-only `$208D` update and changes `$10DF` to read ISR2 first, then ISR1. Hardware testing with that combined logic has so far shown no observed stalls in repeated `*IDN?` traffic or in repeated `WFA?` / `FRA...` / `FRA?` loops.

## Hardware

- **A2U11**: Motorola MC68B09P CPU (2 MHz)
- **A2U12**: AM27256 EPROM (256 Kbit, 32KB) — firmware under investigation
- **A2U13**: Intel D27513 paged EPROM (512 Kbit, 4 × 16KB pages) at `$4000–$7FFF`
- **A2U14**: Hitachi HM6264LP-15 battery-backed SRAM (8K × 8) — RAM
- **A2U15**: Motorola MC68B40P (MC6840 PTM) programmable timer at `$1000–$1007`
- **A2U16**: Intel P8291A GPIB Talker/Listener (at `$0400–$0407`)
- **Serial number prefix**: 2940A
- **GPIB transceiver (management lines)**: A2U17 = DS75161AN — handles EOI, DAV, NRFD, NDAC, IFC, SRQ, ATN, REN
- **GPIB transceiver (data lines)**: A2U18 = DS75160AN — handles DIO1–DIO8

Other hardware the CPU controls (exactly how they are connected is not clear, schematics are unavailable) include:

- 2 x 40 character LCD display
- Front-panel keypad
- Front-panel status LEDs
- DAC (data lines are not connected directly to the CPU, and include at least flip-flop buffers)

### Hardware connections

**P8291A INT (pin 11) connects directly to MC6809 IRQ (pin 3).** No connection to FIRQ (pin 4). The P8291A INT is configured **active-low** on this instrument (via Auxiliary Register B bit 3, set at `$1013`).

### P8291A Pin Reference

| Pin | Signal | Description |
|---|---|---|
| 1 | T/R1 | Talk Enable output → A2U17 pin 1 (TE) and A2U18 pin 1 (TE). Driven by P8291A hardware (HIGH in TACS). |
| 2 | T/R2 | → A2U18 pin 11 (PE, Pull-Up Enable) |
| 11 | INT | Interrupt output (active-low) → MC6809 IRQ (pin 3) |
| 28–35 | _DIO1–_DIO8 | GPIB data port (active-low); pin 28 = DIO1, pin 35 = DIO8 |
| 36 | _DAV | Data Valid handshake line (active-low) |
| 37 | _NRFD | Not Ready For Data handshake line (active-low) |
| 38 | _NDAC | Not Data Accepted handshake line (active-low) |
| 39 | _EOI | End Or Identify (active-low) |

## GPIB Bus Path

The P8291A connects to the physical GPIB bus through two transceiver ICs. See `GPIB_bus_path.md` for the complete pin-by-pin wiring.

### Transceiver Direction Control

- **TE (Talk Enable)**: P8291A pin 1 (T/R1) connects directly to A2U17 pin 1 AND A2U18 pin 1. TE is driven by the **P8291A hardware** (goes HIGH when P8291A is in TACS), **NOT by firmware**.
- **DC (Direction Control)**: A2U17 pin 11 is **hardwired to VCC** (always HIGH). This means ATN, REN, IFC are always receivers, and SRQ is always a transmitter.
- **PE (Pull-Up Enable)**: P8291A pin 2 (T/R2) connects to A2U18 pin 11.

### DS75161A Direction (with DC=HIGH, as wired)

| TE | ATN (driven by GPIB bus) | EOI | REN | IFC | SRQ | NRFD | NDAC | DAV |
|---|---|---|---|---|---|---|---|---|
| HIGH (talker) | HIGH | T | R | R | T | R | R | T |
| HIGH (talker) | LOW | R | R | R | T | R | R | T |
| LOW (idle/listener) | HIGH | R | R | R | T | T | T | R |
| LOW (idle/listener) | LOW | R | R | R | T | T | T | R |

T = Transmit (P8291A drives bus), R = Receive (bus drives P8291A)

When TE=LOW (not talker), the 8904A **transmits** NRFD, NDAC, SRQ and **receives** DAV, EOI.

## Observed Memory Map

The listed regions are directly supported by hardware inventory, pin tracing, and code accesses. What is still incomplete is the full decode of every address inside the broader `$0000–$0FFF` MMIO region.

| Address Range | Device |
|---|---|
| `$0000–$0FFF` | I/O space (system interrupt controller, GPIB, other peripherals) |
| `$0400–$0407` | Intel P8291A registers (8 registers, directly addressed) |
| `$0900` | Status/control port (shadow at `$2420`) — controls talk LED etc., NOT transceiver direction |
| `$1000–$1007` | MC6840 PTM (timer, 3 channels) |
| `$2000–$3FFF` | HM6264 SRAM (8KB, battery-backed) |
| `$4000–$7FFF` | A2U13 paged ROM (16KB window, 4 pages, page select at `$4000` write) |
| `$8000–$FFFF` | A2U12 ROM (32KB, this firmware) |

### P8291A Register Map (at `$0400`)

| Addr | Read | Write |
|---|---|---|
| `$0400` | Data In (DIR) | Data Out (DOR) |
| `$0401` | Interrupt Status 1 (ISR1) — **clear-on-read** | Interrupt Enable 1 (IE1) |
| `$0402` | Interrupt Status 2 (ISR2) — **clear-on-read** | Interrupt Enable 2 (IE2) |
| `$0403` | Serial Poll Status (SPSR) | Serial Poll Mode (SPMR) |
| `$0404` | Address Status (ADSR) | Address Mode (ADM) |
| `$0405` | Command Pass Through (CPTR) | Auxiliary Mode (AUX) |
| `$0406` | Address 0 (ADR0) — bit 7 = INT status duplicate | Address 0/1 (ADR0/1) |
| `$0407` | Address 1 (ADR1) | EOS register |

### P8291A ISR1 Bit Map

| Bit | Name | Description | Enabled in IE1? |
|---|---|---|---|
| 7 | CPT | Command Pass Through | Yes (`$AB` bit 7) |
| 6 | APT | Address Pass Through | No |
| 5 | GET | Group Execute Trigger | Yes |
| 4 | END | End/EOI received | No |
| 3 | DEC | Device Clear | Yes |
| 2 | ERR | Bus error (no listeners) | **No** |
| 1 | BO | Byte Out (output ready) | Yes |
| 0 | BI | Byte In (input ready) | Yes |

IE1 is initialized to `$AB` = `10101011` at `$1024`.

### P8291A ISR2 Bit Map

| Bit | Name | Description | Enabled in IE2? |
|---|---|---|---|
| 7 | INT | INT pin status (read-only, does not generate interrupt) | — |
| 6 | — | — | — |
| 5 | REM | Remote state (read-only status) | — |
| 4 | LLO | Local lockout state (read-only status) | — |
| 3 | SPC | Serial Poll Complete | Yes (`$0F` bit 3) |
| 2 | LLOC | Local lockout change | Yes |
| 1 | REMC | Remote/local change | Yes |
| 0 | ADSC | Address status change | Yes |

IE2 is initialized to `$0F` = `00001111` at `$1024` (written as part of `LDD #$AB0F; STD $0401`).

### P8291A ISR Behavior (from datasheet)

- Reading ISR1 or ISR2 **clears all latched bits** in that register
- "If an event occurs while one of the Interrupt Status Registers is being read, the event is held until after its register is cleared and then placed in the register"
- "The software must examine ALL relevant bits in the interrupt status registers before disregarding the value or an important interrupt may be missed"
- BO is set by the condition: `TACS * (SWNS + SGNS)` — talker active AND source handshake waiting/generating
- The recommended polling algorithm (datasheet page 18): read ADR0 for INT, then read ISR2, then read ISR1 — **ISR2 first, then ISR1**

### feoi (Force End-Or-Identify)

The `feoi` auxiliary command (`$06` written to `$0405` at `$1716`) tells the P8291A to assert EOI with the next data byte:

```
$1714: LDB  #$06
$1716: STB  $0405        ; feoi — assert EOI with next byte
$1719: STA  $0400        ; write the last data byte
```

## Interrupt Architecture

The IRQ versus FIRQ assignment below is directly established by board tracing and by the ROM handlers that service each line. The remaining uncertainty in this area is the exact external hardware source behind the `$0100` bit-7 FIRQ path.

| Vector | CPU Address | Line | Handler |
|---|---|---|---|
| FIRQ | `$DD0C` | Pin 4 | Saves registers, calls `$70A1` — polls `$0100` (system interrupt controller, **NOT P8291A**) |
| IRQ | `$DD14` | Pin 3 ← **P8291A INT** | Calls `$7154` — sets `$2204` bit 0, masks IRQ in saved CC |
| NMI | `$DC3D` | Pin 2 | Checks `$2202` bit 7: if set, dispatches through callback pointer at `$24D8`; otherwise services MC6840 PTM timer channels via shadow registers `$2421–$2423`, then calls `$705E` |

### IRQ Handler (`$5D14`)

```
$5D14: LBSR $7154        ; set $2204 bit 0 (flag), no other processing
$5D17: LDA  #$10         ; I bit mask
$5D19: ORA  ,S           ; set I bit in saved CC (mask IRQ on return)
$5D1B: STA  ,S
$5D1D: RTI               ; return with IRQ masked
```

The IRQ handler does minimal work: sets a flag and masks IRQ. All P8291A event processing is deferred to the main loop.

### FIRQ Handler (`$70A1`)

Reads `$0100` (system interrupt controller), processes bits 7 and 4. Contains an internal polling loop. **This handler has NOTHING to do with the P8291A** — the P8291A INT goes to IRQ, not FIRQ.

## Stack Frame Allocator (`$7D50`)

Nearly every function in A2U12 begins with `LDD $xxxx; LBSR $7D50`. This is **NOT a debug/trace call** — it is a stack frame allocator. The `LDD $xxxx` instruction (extended mode, opcode `$FC`) loads the 16-bit frame size from ROM address `$xxxx` into D. `$7D50` then uses D directly: it negates D, adjusts S by that amount (allocating local variable space on the stack), pushes a frame base pointer in X, and returns to the caller. The value in D on entry to `$7D50` **is** the frame size, not a pointer to it — the LDD instruction already performed the ROM read.

Frame size values are packed into small ROM data tables (e.g., at `$0932–$0938`, `$0F76–$0F7A`, `$5C34–$5C3C`). Multiple functions may share the same frame-size entry.

## Main Loop Architecture

The scheduler structure below is directly established from code flow. Some individual branch purposes inside that loop, such as the `$2203` bit-1 path through `$2398`, are still only partially decoded.

The main loop runs at `$04CA–$092B` and processes both front panel events and GPIB.

### GPIB Handler Call (`$0499–$04BD`)

```
$0499: LDD  $23C1        ; "GPIB active" flag
$04A4: LBEQ $04C0        ; if bit 0 not set → skip GPIB, go to front panel only
$04B3: LDX  $24E6        ; load current GPIB handler function pointer
$04B6: JSR  ,X           ; call handler
$04BA: CLR  $220A
$04BD: LBRA $04CA        ; continue to front panel processing
```

- `$23C1` bit 0: "GPIB active" flag. When 0, GPIB handler is skipped entirely but front panel still works.
- `$24E6`: dynamically-installed GPIB handler function pointer. `$0AEA` can load it from the 10-entry table at `$2224`; common values relevant to this bug are `$8D23` and `$A73E`.
- When `$24E6` = `$8D23` (idle handler): clears/restores HP-IB parser/display state and does **NOT** call `$10D3`
- When `$24E6` = `$A73E` (active handler): calls `$10D3` to poll the P8291A and then services several mailbox bits in `$2281`

### GPIB Processing Function (`$273E`)

When the instrument is actively communicating, `$24E6` points to `$A73E` (ROM `$273E`):

```
$2749: LBSR $1D4C        ; → $1B18 → $10D3: poll P8291A events
$274E: check $2203 bit 1 ; jumps through $2398 if set (normal use still unverified)
$2765: LBSR $5D00        ; ANDCC #$EF — re-enable IRQ
$276F: check `$2281` mailbox bits ; forwards queued work into `$2217`/`$0D60`
$2998: return
```

After `$273E` returns, the main loop at `$0807` checks `$2204` bit 2:

```
$0807: check $2204 bit 2 → if set, call $0D60 (request dispatch)
$0D60: loads $2217, dispatches through $0F13 switch/case
$0F13: jump table (types 1–34), dispatches to appropriate handler
```

For type `$000D` (buffer refill): dispatches to `$0E74` → calls `$2052` → fills buffer → `$9729` → sets `$2269 = 0` → output resumes.

### ADSC Handler and Status Control (`$1170`)

The ADSC (Address Status Change) handler is called by `$10D3` when ISR2 bit 0 is set. It reads ADSR (`$0404`) to determine the current address state and updates instrument status via `$0900` (talk LED, etc.):

```
$1170: LDX  #$9A62       ; default: listener teardown
$1173: LDA  $0404        ; read ADSR
$1176: BITA #$04         ; test LPAS (Listener Primary Address State)
$117D: JSR  ,X           ; call listener setup ($9A47) or teardown ($9A62)

$117F: LDX  #$9A66       ; default: talker teardown
$1182: LDA  $0404        ; read ADSR
$1185: BITA #$02         ; test TPAS (Talker Primary Address State)
$118C: JSR  ,X           ; call talker setup ($9A4B) or teardown ($9A66)
```

Status control functions modify `$0900` via shadow register `$2420` (controls talk/listen/remote-style front-panel status, NOT transceiver direction). The port is active-low (clearing a bit activates the corresponding indicator). Verified bit assignments from code analysis:

| Bit | Clear (activate) | Set (deactivate) | Function |
|-----|-------------------|-------------------|----------|
| 0 | `$9A4F` | `$9A6A` | Serial poll status related |
| 1 | `$9A4B` | `$9A66` | Talker indicator |
| 2 | `$9A47` | `$9A62` | Listener indicator |
| 3 | `$9A40` | `$9A5B` | Remote/LLO related indicator |
| 4 | `$9A53` | `$9A6E` | Not yet identified |
| 5 | `$9A57` | `$9A72` | Not yet identified |
| 6–7 | — | — | Not touched by these functions |

`$9A76` sets bits 0–5 (all indicators off); `$9A7D` clears bits 0–5 (all indicators on).

### All GPIB handlers are in A2U12

All subroutines called by `$10D3` (such as `$9170`, `$918F`, `$92A5`, `$930D`, `$96DA`, `$9C7E`, `$9C83`, `$9C88`) have CPU addresses in the range `$9000–$9FFF`, which maps to A2U12 ROM offsets `$1000–$1FFF`. These are **all in A2U12**, not in the paged A2U13 ROM.

## P8291A Event Handler (`$10D3`)

This is the core GPIB event processing function, called from the main loop (NOT from interrupts). **This is the ONLY function that reads P8291A ISR1 in the entire A2U12 ROM.**

```
$10D5: LDA  $0406        ; read ADR0 — bit 7 is INT status duplicate
$10D8: BMI  $10DF        ; if INT asserted → process events
$10DA: return             ; INT not asserted → return immediately (no events)

$10DF: LDD  $0401        ; read ISR1 (→A) and ISR2 (→B) — CLEARS BOTH
$10E2: STD  $2246        ; save to RAM

; Process from saved copy (ISR2 events first, then ISR1):
$10E5: ISR2 bit 0 (ADSC) → JSR $9170 (address status change → status update)
$10EF: ISR2 bit 1 (REMC) → JSR $918F (remote/local change)
$10F9: ISR2 bit 3 (SPC = Serial Poll Complete) → JSR $92A5
$1103: ISR1 bit 0 (BI)   → JSR $930D (byte in → reads $0400)
$110D: ISR1 bit 1 (BO)   → JSR $96DA = $16DA (byte out → writes $0400)
$1117: ISR1 bit 3 (DEC)  → inline: sets $2269=$80, calls $9C7E
$1135: ISR1 bit 5 (GET)  → JSR $9C83
$113F: ISR1 bit 7 (CPT)  → BSR $11B4 (command pass through)

; NOT checked: ISR1 bit 2 (ERR), ISR1 bit 4 (END), ISR1 bit 6 (APT)

$116B: return
```

**Key observations:**
- ISR1 is read at `$10DF` — the ONLY place in the entire A2U12 ROM that reads ISR1
- The firmware reads ISR1 FIRST, then ISR2 (via `LDD $0401`). The P8291A datasheet recommends ISR2 first, then ISR1.
- The saved copy at `$2246/$2247` is used by later handlers, but `$2247` bit 4 is later modified by software helpers, so not every later use of `$2247` is a pristine raw ISR2 snapshot
- ERR (bit 2) is never checked — if ERR fires, it's cleared by the read but not processed
- At the first ADSC test (`$10E5`), both outcomes occur in successful `*IDN?` traces

## Byte Output Function (`$16DA`)

Called when BO fires (P8291A ready for next byte):

```
$16DA: LDA  $2269        ; output state machine
       BMI  $16E7        ; $80 → message boundary
       BEQ  $16FA        ; $00 → ready to output
       ; else ($01) → waiting for buffer refill
$16E1: STA  $2264 = 1   ; set busy flag
$16E6: RTS              ; *** RETURN WITHOUT WRITING BYTE ***

; State $00: output next byte from buffer
$16FA: CLR  $2264        ; clear busy
$16FD: LDX  $2266        ; buffer pointer
$1700: LDA  ,X+          ; get byte
$1702: STX  $2266        ; advance
$1705: DEC  $2265        ; decrement count
$1708: BNE  $1719        ; if more bytes → write and return
       ; last byte:
$170C: STB  $2269 = $80  ; message boundary
$170F: TST  $2268        ; "more data" flag
$1712: BNE  $171D        ; if more data → skip EOI
$1714: LDB  #$06
$1716: STB  $0405        ; AUX feoi (Force End-Or-Identify)
$1719: STA  $0400        ; *** WRITE DATA BYTE TO P8291A ***
$171C: RTS

; State $80: message boundary → post refill request
$16E7: LDA  #$01
$16E9: STA  $2269        ; transition to $01 (waiting)
$16EC: JSR  $9C88        ; post request: sets $2281 bit 0, $2389 = $000D
$16F6: STA  $2264 = 1   ; set busy
$16F9: RTS
```

### Buffer Refill Chain

1. `$16DA` exhausts buffer → `$9C88` posts request (`$2281` bit 0, type `$000D`)
2. `$273E` handler: `$276F` checks `$2281` → `$0AD0` saves type `$000D` to `$2217`, sets `$2204` bit 2
3. Main loop: `$0807` checks `$2204` bit 2 → calls `$0D60`
4. `$0D60`: loads `$2217`, dispatches through `$0F13`
5. Type `$000D` → `$0E74` → calls `$2052` (buffer fill handler)
6. `$2052` → `$1BC4` → `$9729`: sets `$2269 = 0`, copies buffer params, optionally calls `$16DA`
7. Output resumes

**Note**: `$0D60` at `$0D75–$0D83` can override `$2217` with `$003C` when `$2202` bit 3 is set and the function at `$220D` returns non-zero. Type `$003C` exceeds the dispatch table range and goes to a fallback handler, not to `$2052`. This override is clearly used, but the exact UI state machine around it is still only partly decoded.

**Important trace facts**:

- In `traces_unique/`, failing `*IDN?` traces reach this refill/resume path and later hit `$1719` (`STA $0400`).
- In `traces_unique_9719/`, every failing trace is triggered on that first `$1719`, writes exactly one byte to `$0400`, and never reaches a second `$1719`.

### Buffer Fill Trigger (`$9729`)

```
$172E: CLR  $2269        ; *** RESET STATE TO 0 (ready) ***
$1731: PULU D            ; copy buffer params from U
$1733: STD  ,X++         ; to $2265/$2266 (count/pointer)
$1735: PULU D
$1737: STD  ,X           ; to $2267/$2268 (pointer low/flags)
$1739: TST  $2264        ; if busy flag set...
$173E: BSR  $16DA        ; ...call output directly (don't wait for BO event)
$1742: RTS
```

`$9729` is the ONLY function that sets `$2269 = 0`. It's called from ONE place: `$1BD6`.

## Key RAM Variables

The roles below are the verified uses seen in the HP-IB and foreground-loop paths analyzed here. Some of these bytes and bits have additional uses elsewhere in the firmware that are not yet fully decoded.

| Address | Name | Purpose |
|---|---|---|
| `$0900` | Status/control | Written by ADSC handler for talk/listen status (shadow at `$2420`). Does **NOT** control transceiver direction — TE comes from P8291A T/R1 directly. Controls the front-panel HP-IB/status indicators. |
| `$2202/$2203` | Flags | Various control flags. In the regions analyzed here, `$2202` bit 3 enables the `$220D` callback/override path in `$0D60`; `$2203` bit 1 is tested in `$273E`. |
| `$2204/$2205` | Flags | Low byte bit 0 = IRQ latched by `$7154`; low byte bit 2 = request dispatch pending; low byte bit 7 = idle-timeout active; high byte bit 1 = staged transmit descriptor ready. Many foreground paths update this word with read-modify-write sequences. |
| `$2217` | Request type | Saved by `$0AD0`, read by `$0D60` for dispatch |
| `$2246/$2247` | Saved ISR pair | ISR1 (high) / ISR2 (low) from last `$10D3` read. Note that `$2247` bit 4 is later modified by software, so it is not always a pristine ISR2 shadow. |
| `$2265` | Byte count | Bytes remaining in output buffer |
| `$2266/$2267` | Buffer pointer | Current position in output buffer |
| `$2268` | More data flag | Non-zero if more data segments follow |
| `$2269` | Output state | `$00`=ready, `$01`=waiting for refill, `$80`=message boundary |
| `$2281` | Request mailbox | Multi-bit HP-IB foreground work mailbox. Verified uses include bit 0 = request type already staged in `$2389`; bit 1/3/4/5 = additional HP-IB formatter or event-posting work classes; bit 6/7 = deferred callback / retry control. |
| `$2389` | Request target | Dispatch target (set by `$9Cxx` functions) |
| `$23C1` | GPIB active | Bit 0: GPIB handler enabled in main loop |
| `$24E6` | Handler pointer | Current GPIB handler function (changes dynamically) |

## Checksum Details

The power-on self-test routine at `$5CA9` verifies the ROM. Because `CMPX` in the checksum loop overwrites the carry flag each iteration, the algorithm reduces to:

```
(sum_of_all_32768_bytes + 32767) mod 256 == 0
```

Or equivalently: **the simple sum of all ROM bytes mod 256 must equal 1**.

`checksum.py` reproduces the exact 6809 algorithm and is useful when building experimental ROMs:

```
$ python3 checksum.py a2u12.asm
Current checksum result: $00 (PASS)
```

## Files

| File | Description |
|---|---|
| `a2u12.bin` | Binary dump of A2U12 firmware |
| `a2u12.asm` | Disassembly listing of firmware on A2U12 |
| `a2u12_fix_irq_latch.asm` | Intermediate A2U12 listing implementing only the checksum-neutral `$208D-$2096` IRQ-latch fix |
| `a2u12_fix_irq_latch.bin` | Built latch-only ROM image from `a2u12_fix_irq_latch.asm` |
| `a2u12_fix.asm` | Permanent combined A2U12 listing: `$208D` byte-only IRQ-latch fix plus `$10DF` ISR2-first poll helper |
| `a2u12_fix.bin` | Built permanent ROM image from `a2u12_fix.asm` |
| `a2u13.bin` | Binary dump of A2U13 paged ROM |
| `a2u13.asm` | Disassembly listing of A2U13 |
| `checksum.py` | Verifies ROM checksum using the exact self-test algorithm |
| `make_bin.py` | Extracts a 32KB binary from a disassembly listing |
| `GPIB_bus_path.md` | Traced GPIB bus path with pin-level wiring |
| `traces_stock_firmware_0406/` | 16 unique successful and 7 unique failed address traces derived from 27 successful and 29 failed captures, triggered on the first `$0406` after `*IDN?` |
| `traces_stock_firmware_9719/` | 12 unique successful and 6 unique failed address traces triggered on the first `$9719` (`$1719`) after `*IDN?` |
| `traces_with_irq_latch_fix_0406/` | Address traces captured while running `a2u12_fix_irq_latch.bin`; includes successful and failed mixed-command runs involving `WFA?`, `FRA...`, and `FRA?`, triggered on the first `$0406` after `FRA?` |
| `datasheets/Motorola MC6809 8-Bit Microprocessing Unit.pdf` | MC6809 CPU datasheet |
| `datasheets/AM27C256 256 Kilobit (32 k x 8-Bit) CMOS EPROM.pdf` | Datasheet for A2U12 EPROM |
| `datasheets/Intel 27513 Page-Addressed 512k (4 x 16k x 8) UV Erasable PROM.pdf` | Datasheet for A2U13 EPROM |
| `datasheets/HM6264 Series 8192-word x 8-bit High Speed CMOS Static RAM.pdf` | Datasheet for A2U14 battery-backed RAM |
| `datasheets/Intel P8291A GPIB Talker,Listener.pdf` | P8291A datasheet |
| `datasheets/DS75160A, DS75161A, DS75162A IEEE-488 GPIB Transceivers.pdf` | Bus transceiver datasheet |
| `datasheets/Motorola MC6840 Programmable Timer Module.pdf` | MC6840 programmable timer datasheet |

## Measurements During Stall

### GPIB Bus Lines

| Signal | Normal (after power-up) | During Stall | Driven By |
|---|---|---|---|
| EOI | High (idle) | High (idle) | — |
| DAV | High (idle) | High (idle) | — |
| NRFD | High (idle) | High (idle) | — |
| NDAC | High (idle) | **Low (asserted)** | **8904A** |
| IFC | High (idle) | High (idle) | — |
| SRQ | High (idle) | **Low (asserted)** | **8904A** |
| ATN | High (idle) | High (idle) | — |
| REN | Low (Prologix) | Low (Prologix) | Prologix |

### P8291A Pin Levels

| Pin | Signal | Level During Stall | Meaning |
|---|---|---|---|
| 1 | T/R1 (Talk Enable) | **Low** | P8291A is NOT in TACS — transceiver in receive mode |
| 2 | T/R2 | Low | — |
| 11 | INT | **Low (asserted)** | Pending events not being processed by firmware |
| 24 | _IFC | High | IFC not asserted |
| 25 | _REN | Low | REN asserted (from Prologix) |
| 26 | _ATN | High | ATN not asserted |
| 27 | _SRQ | **Low (asserted)** | P8291A is requesting service |
| 36 | _DAV | High | No data being presented |
| 37 | _NRFD | High | Ready for data (NRFD released) |
| 38 | _NDAC | **Low (asserted)** | Data not accepted — goes HIGH if Prologix unplugged |
| 39 | _EOI | High | EOI not asserted |

### MC6809 Pin Levels

| Pin | Signal | Level | Meaning |
|---|---|---|---|
| 2 | _NMI | High | NMI not asserted |
| 3 | _IRQ | **Low** | IRQ asserted (from P8291A INT) |
| 4 | _FIRQ | High | FIRQ not asserted |
| 5 | BS | Low | CPU running normally |
| 6 | BA | Low | CPU running normally (not halted) |

### What the Measurements Tell Us

1. **P8291A T/R1 = LOW**: At the stalled-state measurement point, the P8291A is not in talker mode.

2. **NDAC asserted by 8904A**: With TE=LOW, the DS75161A transmits NDAC from the P8291A to the bus. _NRFD=HIGH and _NDAC=LOW corresponds to IEEE 488 **ACRS** (Acceptor Ready State) — consistent with a non-talker or with a device that has already fallen back out of talker state.

3. **SRQ asserted by 8904A**: The P8291A is requesting service (`rsv` bit set) or is in a state that still causes SRQ to be asserted. The exact source remains to be identified.

4. **INT asserted (IRQ = 0V)**: The P8291A still has pending state for the firmware to service.

5. **Talk LED still on**: The front panel indication does not determine whether `$1170` ran. Stalled traces can reach `$0900/$2420` updates and can write a reply byte before hanging.

6. **Controller is idle**: ATN and IFC are both HIGH. The Prologix has stopped trying to communicate by the time this pin-level snapshot was taken.

### Measurement Interpretation

These measurements describe the stalled end state. They do not isolate the software transition that caused it.

## Address Sequences

A 16-bit logic analyzer was attached to the address lines of the MC68B09P and triggered on the falling edge of the P8291A chip select, which corresponds to the first `$0406` access after a `*IDN?` query is sent. The traces in `traces_unique/` contain:

- 27 successful captures collapsed to **16 unique successful traces**
- 29 failed captures collapsed to **7 unique failed traces**

The failed queries in the captured traces were preceded by as few as 1 successful query, or as many as over 12,000 successful queries, with no correlation to the particular path a trace followed.

### Verified Facts From `traces_unique/`

- Every unique trace is **33,555 lines** long.
- The first triggered `$0406` is always at **line 3,356**.
- **Lines 3,028 through 3,376 are identical across all 23 unique traces.**
- After that common window the traces branch repeatedly and later reconverge. After line 3,028 there are **20 distinct continuations** among the 23 unique traces, so the behavior after the trigger is diverse.

### First Branch After the Common Window

The first post-common branch occurs at the ADSC test in `$10D3`:

| Next address at line 3,377 | Meaning | Unique traces |
|---|---|---|
| `$90E9` | ADSC set → run `$1170` | 4 success, 0 fail |
| `$90EF` | ADSC clear → skip `$1170` | 12 success, 7 fail |

The first ADSC result does not determine success or failure. Successful traces exist on both paths.

### Later Branches

Inside the 19-trace `$90EF` branch, success and failure remain interleaved through several later decisions:

- At **line 4,122**, one subgroup takes the `$0839` path (idle-timeout active) and contains **4 success + 1 fail**, while another takes the `$0868` path and contains **8 success + 6 fail**.
- Later branches and reconvergences run through the main-loop housekeeping around `$06FC/$0760/$082A`.
- Other branches run through the serial-poll shadow helpers around `$11E2/$1237/$12A5`.
- One successful trace diverges because an IRQ arrives in the middle of the main loop where otherwise-similar traces do not.
- One failed trace shares the `$0839` path with four successful traces for another 1,555 lines before diverging.

No single later branch cleanly separates all remaining successful traces from all remaining failed traces.

### Failed Traces Reach Reply Transmission

Every failing trace in `traces_unique/` eventually reaches a later `STA $0400` at `$1719` through the refill/resume chain

```
$2052 -> $1BC4 -> $1729 -> $16DA -> $1719
```

In the captured failing runs, the firmware gets far enough to:

- parse incoming bytes,
- stage a reply buffer,
- install that buffer into `$2265-$2268`,
- and write at least one response byte to the P8291A DOR.

So the bug must be compatible with a failure that happens **after reply transmission has already started**.

## Post-First-Byte Address Sequences (`traces_unique_9719/`)

A 16-bit logic analyzer was triggered on CPU address `$9719`, which is the A2U12 ROM address for the first `STA $0400` after `*IDN?`. The traces in `traces_unique_9719/` contain **12 unique successful traces** and **6 unique failed traces**.

### Verified Facts From `traces_unique_9719/`

- Every trace is **33,554 lines** long.
- The first `9719` occurs at **line 3,356** in every trace.
- **Lines 3,356 through 3,376 are identical across all 18 traces.**
- After line 3,356 there are **6 distinct continuations** among the 18 traces.

### Early Branches After The First Byte

| Address at line 3,377 | Unique traces |
|---|---|
| `$9742` | 8 success, 0 fail |
| `$9743` | 4 success, 6 fail |

Inside the 10-trace `$9743` branch:

- At **line 3,382**, one subgroup shows `$9BD9` and contains **3 success, 0 fail**, while another shows `$9BDA` and contains **1 success, 6 fail**.
- At **line 3,387**, that mixed subgroup splits again: `$9BDB` contains **1 success, 0 fail**, while `$9BDC` contains **0 success, 6 fail**.

So unlike the earlier `$0406`-triggered captures, the post-first-byte traces separate **all observed failures from all observed successes within 31 lines of the first `$1719` write**.

### Failed Traces Stop Before The Second Byte

- Every failed trace contains exactly **one** post-trigger `9719` and exactly **one** post-trigger `$0400` access.
- Successful traces contain **29 or 30** post-trigger `9719` / `$0400` write pairs.
- Every failed trace takes **one** IRQ (`$DD14 -> $7154`) after that first byte, but no failed trace reaches `$07F3`, `$0802`, `$273E`, `$10D3`, `$1111`, or `$16DA` again.

This means the captured failure happens **after the first byte is written but before foreground code services the next BO event**. It is not a late-message or late-refill failure.

### Verified IRQ-Latch Loss Window

All 6 failing post-first-byte traces show the same timing around `$2052`'s cleanup path:

```
$208D: LDD  $2204       ; read both bytes of the flag word
$2090: ANDA #$FD        ; clear only high-byte bit 1
$2092: ANDB #$FF
$2094: STD  $2204       ; write both bytes back
```

In every failing trace:

- the first post-trigger fetch of `$208D` occurs at **line 3,393**,
- the IRQ vector `$DD14` occurs at **line 3,421**,
- execution later resumes at `$2094` and writes `$2204/$2205` at **lines 3,541-3,546**,
- the main loop later reaches `$07E4` at **line 3,766** and branches to `$0807` instead of `$07F3`.

No successful trace takes IRQ between the first `$208D` and the following `$2094`.

This is consistent with a concrete lost-IRQ race: `$7154` sets `$2204` bit 0 during the interrupt, then the resumed `STD $2204` at `$2094` writes the stale pre-IRQ low byte back and erases that latch. The main loop then sees bit 0 clear at `$07E4`, skips `$273E`, and never services the next BO interrupt.

### Intermediate Latch-Only Fix

Repeated hardware testing was first performed with a ROM that replaces the vulnerable 16-bit read-modify-write at `$208D-$2094` with a byte-only sequence:

```
LDA  $2204
ANDA #$FD
STA  $2204
```

With that logic installed, there were **no observed failures on `*IDN?` queries**.

Together with the captured post-first-byte traces, this identifies the observed `*IDN?` stall family as the `$208D-$2094` lost-IRQ window, but it did not fully fix all HP-IB traffic.

That intermediate image is retained as `a2u12_fix_irq_latch.bin`, built from `a2u12_fix_irq_latch.asm`.

It replaces the 10-byte sequence at ROM offset `$208D-$2096`:

```text
Original: FC 22 04 84 FD C4 FF FD 22 04
Patched : B6 22 04 84 FD B7 22 04 21 2E
```

Equivalent assembly:

```asm
LDA  $2204
ANDA #$FD
STA  $2204
BRN  $20C5
```

The first three instructions are the functional fix: they clear only the high byte of `$2204`, so a BO IRQ that sets low-byte bit 0 cannot be lost by a stale 16-bit write-back.

The final `BRN $20C5` is a harmless 2-byte filler that is executed but never branches. It preserves the original 10-byte footprint and keeps the ROM checksum correct without needing any separate compensation byte elsewhere in the image.

### Remaining Failures With The Latch-Only ROM

Long repeated loops of:

1. `WFA?`
2. `FRA100.0HZ` (with the numeric value changed each round)
3. `FRA?`

still stalled the bus while running `a2u12_fix_irq_latch.bin`. In the observed tests, the stall occurred on `FRA?`, not on `WFA?` or on long repeated `*IDN?` traffic.

The stalled line levels for that second failure family differ from the earlier `*IDN?` failure signature. During the latch-only post-fix stall, `T/R1` is LOW, `ATN` is HIGH, `DAV` is HIGH, `NRFD` is LOW, `NDAC` is LOW, `SRQ` is LOW, and the MC6809 `IRQ` pin is LOW. That is consistent with the P8291A sitting in a listener-side handshake state, not with the original post-first-byte `*IDN?` talker stall.

The trace set in `traces_with_irq_latch_fix/` does **not** reproduce the old `$208D-$2094` lost-IRQ signature. In the failure trace `address_sequence_failure_08.txt`, the last traced service window still reaches `$10DF`, tests `$110D`, executes the BO path through `$1111 -> $16DA`, writes another data byte at `$1719`, and then unwinds normally through `$2052/$2088/$208D`. That post-byte sequence matches successful traces from the same directory.

Those results point away from the old `$208D-$2094` race and toward a second bug. The strongest remaining candidate was the original ISR read ordering at `$10DF`: the firmware reads ISR1 first and ISR2 second via `LDD $0401`, while the P8291A datasheet recommends ISR2 first, then ISR1.

### Permanent Combined Fix

An additional ROM was then tested that keeps the `$208D` byte-only latch fix and changes `$10DF` to read ISR2 first, then ISR1, via a helper in unused padding ahead of the vector table. That ISR2-first experiment was then kept unchanged as the permanent fixed ROM.

Hardware testing with that combined logic has so far shown **no observed stalls** in repeated `*IDN?` traffic and in repeated `WFA?` / `FRA...` / `FRA?` loops.

The permanent fixed image is `a2u12_fix.bin`, built from `a2u12_fix.asm`. No separate ISR2-first experimental duplicate is retained, because the tested experiment and the permanent fix were the same ROM bytes.

The combined fix adds a second patch site:

```text
$10DF original: FC 04 01 FD 22 46
$10DF patched : BD FF CF 12 12 12

$7FCF helper  : F6 04 02 B6 04 01 FD 22 46 39
$7FD9 byte    : 45    ; checksum compensation in unused padding
```

Equivalent assembly for the new logic:

```asm
; at $10DF
JSR  $FFCF
NOP
NOP
NOP

; helper at $7FCF
LDB  $0402
LDA  $0401
STD  $2246
RTS
```

This preserves the later handler logic unchanged: it still expects `A = ISR1`, `B = ISR2`, and `$2246/$2247` as the saved ISR shadow pair. Only the read order changes.

## Current Conclusions

- `$10DF` is the only place that reads ISR1 in the original firmware, and it reads ISR1 before ISR2.
- The captured post-first-byte `*IDN?` failure family is caused by the `$208D-$2094` lost-IRQ race.
- The latch-only ROM `a2u12_fix_irq_latch.bin` eliminated the observed `*IDN?` failures but still left a second stall family on repeated `WFA?` / `FRA...` / `FRA?` loops.
- The traces for that second failure family do not match the old `$208D-$2094` lost-IRQ signature and are consistent with a listener-side handshake stall.
- Changing `$10DF` to read ISR2 first, then ISR1, together with the `$208D` latch fix, has eliminated the observed stalls in current hardware testing.
- The original ISR1-before-ISR2 ordering at `$10DF` is therefore very likely the remaining bug that the latch-only fix did not address.
- The permanent combined fix is `a2u12_fix.bin`, built from `a2u12_fix.asm`.

## Next Experiments

### 1. Broaden Hardware Validation Of `a2u12_fix.bin`

The first priority is now broad validation of the permanent fixed ROM:

- long repeated `*IDN?` runs on the fastest available controller,
- long repeated `WFA?` / `FRA...` / `FRA?` loops,
- mixed talk/listen command traffic,
- and any controller or timing combination that previously produced hangs most quickly.

### 2. Add Address-Visible Markers Only If A Residual Failure Appears

If any future failure still appears with `a2u12_fix.bin`, add marker writes around:

- `$208D`
- `$2094`
- `$7154`
- `$07E4`
- `$07F3`
- `$10DF`
- `$110D`
- `$130D`

Because the analyzer already records addresses, those markers would make any remaining lost-latch or post-IRQ path explicit.

### 3. Audit Other `$2204` Read-Modify-Write Sites Only If Needed

If a future failure starts matching another lost-latch signature, inspect every other site that writes the 16-bit `$2204/$2205` word even though it only intends to change one byte or one bit. Any such stale 16-bit write can erase low-byte bit 0 if IRQ lands in the window.
