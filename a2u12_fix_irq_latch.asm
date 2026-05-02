; HP 8904A A2U12 firmware disassembly (ROM at CPU $8000-$FFFF, file offsets $0000-$7FFF).
; Intermediate latch-only variant based on the original A2U12 image:
; - implements only the $208D byte-only IRQ-latch fix
; - intentionally leaves the original P8291A poller at $10DF reading ISR1 before ISR2
; Hardware testing with this ROM eliminated the observed *IDN? stalls but still showed
; occasional stalls on repeated WFA? / FRA... / FRA? loops.
;
; Verified high-level structure:
; - $7D5F is the reset entry reached from the reset vector at file offset $7FFE.
; - $03A0 performs cold-start sequencing and falls into the foreground loop at $0499/$04CA.
; - $0F9F-$1728 is the local HP-IB / GPIB driver in this ROM.
; - $10D3 polls the Intel P8291A by foreground software; the IRQ handler only latches a flag.
; - $0D60 dispatches queued request types, and $24E6 selects the current foreground GPIB handler.
; - $1A40-$1A88 are the status shadow / LED control entry points for $0900.
; - $1C7E-$1CE2 are the request-posting entry points that stage types into $2389/$2281.
; - $5CA9 is the ROM checksum self-test (ADCB loop with CMPX carry injection).
; - $5D0C/$5D14 are the FIRQ/IRQ wrappers; $5C3D is the NMI handler.
;
; Address convention:
; - The offsets on the left are ROM offsets within this EPROM.
; - Absolute JSR/JMP targets in the disassembly are CPU addresses, so subtract $8000 to find the
;   corresponding offset in this file. Example: JSR $9170 lands at file offset $1170.
; - Comments in this file use file offsets when referring to locations within this ROM.
;
; Stack frame allocator convention:
; - Nearly every function begins with LDD $xxxx; LBSR $7D50.
; - The LDD loads a 16-bit frame size from the ROM address into D (extended mode, opcode $FC).
; - $7D50 negates D, adjusts S (allocating that many bytes), pushes the frame base in X, and
;   returns. D is the frame size itself, NOT a pointer to it — LDD already performed the read.
; - Frame-size values are packed into small ROM data tables (e.g., $0932-$0938, $0F76-$0F7A).
;
; Known RAM / I/O state used heavily in the commented regions:
; - $0100: system interrupt controller (read by FIRQ handler and main loop; NOT the P8291A)
; - $0400-$0407: Intel P8291A GPIB controller registers
; - $0900 (shadow $2420): front-panel/status control port (active-low LEDs: bit 1=talk,
;   bit 2=listen, bit 3=remote/LLO related, bits 0/4/5=other indicators)
; - $1000-$1007: MC6840 PTM (programmable timer, serviced by NMI handler)
; - $2202/$2203: control flags ($2202 bit 15 enables NMI callback dispatch via $24D8;
;   $2202 bit 9 enables FIRQ measurement callback dispatch via $24DA;
;   $2202 bit 3 enables $0D60 request-type override via callback at $220D)
; - $2204/$2205: foreground/interrupt flags (bit 0 = IRQ latched, bit 1 = FIRQ result,
;   bit 2 = request dispatch pending, bit 4/5 = display refresh gates)
; - $2217: queued request type for $0D60 dispatcher
; - $2246/$2247: saved copy of P8291A ISR1 ($2246) / ISR2 ($2247) from last $10D3 poll
; - $2265/$2266: HP-IB transmit buffer byte count / pointer
; - $2268: "more data" flag (nonzero if additional segments follow current buffer)
; - $2269: HP-IB output state machine ($00=ready, $01=waiting for refill, $80=boundary)
; - $2264: HP-IB transmit busy flag
; - $2281: request-posting mailbox (multi-bit; bit 0=type staged in $2389, bits 1-7=other classes)
; - $2389: staged request type number (set by $1C7E-$1CE2 family)
; - $23C1 bit 0: HP-IB foreground handling enabled in main loop
; - $24D8: NMI callback pointer (dispatched via JMP [$24D8] when $2202 bit 15 is set)
; - $24DA: FIRQ measurement callback pointer (dispatched via JSR ,X when $2202 bit 9 is set)
; - $24E6: current foreground HP-IB handler pointer (changes dynamically)
;
; Note: several regions in this raw listing are ROM data tables that the disassembler renders as
; instructions. Known data regions include:
; - $0932-$0938: frame-size table entries
; - $0F2A-$0F6D: request jump table (target addresses for types 1-$22)
; - $0F76-$0F7A: frame-size table entries
; - $129D-$12A4: bit-mask table (8 entries, used by $11E2/$1237/$175E)
; - $1777-$19FF (approx): parser token tables and numeric formatting data
; - $5C34-$5C3C: frame-size table entries (and data preceding NMI handler)
; - $5D73-$5D9B: lookup table for $5D3B key/parameter mapping
; - $7FF0-$7FFF: MC6809 interrupt/reset vector table
;
; =====================================================================================
; Display/menu buffer initialization ($0000).
; Frame size: 4 bytes (from ROM $8932).
; Copies ROM templates into RAM work areas at $2285 (line 1, 40 chars) and $22AD (line 2, 35 chars)
; using the block-copy helper at $4285. Conditionally patches portions of the $2285 buffer based
; on option/install bytes at $247B, $3FFC, $3FFD, and the runtime channel count in $23B2.
; When $23B2 < current index, the loop body at $00A4 overwrites 3-byte groups with the ROM
; template at $ED11, effectively blanking option indicators for absent channels.
; The exact meaning of the option/install bytes is not fully decoded yet.
; =====================================================================================
0000: fc 89 32        LDD    $8932
0003: 17 7d 4a        LBSR   $7D50
0006: f6 24 7b        LDB    $247B
0009: e7 64           STB    $4,S
000b: f6 3f fc        LDB    $3FFC
000e: e7 65           STB    $5,S
0010: ce 22 cd        LDU    #$22CD
0013: 10 8e 3f fd     LDY    #$3FFD
0017: 8e 00 04        LDX    #$0004
001a: 34 70           PSHS   U,Y,X
001c: 17 4a 70        LBSR   $4A8F
001f: 32 66           LEAS   $6,S
0021: 5f              CLRB
0022: 1d              SEX
0023: 1f 03           TFR    D,U
0025: 10 8e 00 02     LDY    #$0002
0029: 34 60           PSHS   U,Y
002b: 17 5a b2        LBSR   $5AE0
002e: 32 64           LEAS   $4,S
0030: ce 22 85        LDU    #$2285
0033: 10 8e 40 27     LDY    #$4027
0037: c6 28           LDB    #$28
0039: 1d              SEX
003a: 1f 01           TFR    D,X
003c: cc 00 06        LDD    #$0006
003f: 34 76           PSHS   U,Y,X,D
0041: 17 42 41        LBSR   $4285
0044: 32 68           LEAS   $8,S
0046: e6 64           LDB    $4,S
0048: 4f              CLRA
0049: 1f 03           TFR    D,U
004b: 10 8e 00 02     LDY    #$0002
004f: 34 60           PSHS   U,Y
0051: 17 5a 8c        LBSR   $5AE0
0054: 32 64           LEAS   $4,S
0056: ce 22 ad        LDU    #$22AD
0059: 10 8e ea 99     LDY    #$EA99
005d: c6 23           LDB    #$23
005f: 1d              SEX
0060: 1f 01           TFR    D,X
0062: cc 00 06        LDD    #$0006
0065: 34 76           PSHS   U,Y,X,D
0067: 17 42 1b        LBSR   $4285
006a: 32 68           LEAS   $8,S
006c: f6 23 b2        LDB    $23B2
006f: c1 01           CMPB   #$01
0071: 17 7e 4a        LBSR   $7EBE
0074: c1 00           CMPB   #$00
0076: 10 26 00 0f     LBNE   $0089
007a: c6 20           LDB    #$20
007c: f7 22 93        STB    $2293
007f: c6 20           LDB    #$20
0081: f7 22 94        STB    $2294
0084: c6 20           LDB    #$20
0086: f7 22 95        STB    $2295
0089: 6f 62           CLR    $2,S
008b: c6 10           LDB    #$10
008d: e7 63           STB    $3,S
008f: e6 62           LDB    $2,S
0091: c1 08           CMPB   #$08
0093: 10 24 00 38     LBCC   $00CF
0097: e6 65           LDB    $5,S
0099: c4 01           ANDB   #$01
009b: 4f              CLRA
009c: 10 83 00 00     CMPD   #$0000
00a0: 10 26 00 1b     LBNE   $00BF
00a4: 8e 22 85        LDX    #$2285
00a7: e6 63           LDB    $3,S
00a9: 3a              ABX
00aa: 1f 13           TFR    X,U
00ac: 10 8e ed 11     LDY    #$ED11
00b0: c6 03           LDB    #$03
00b2: 1d              SEX
00b3: 1f 01           TFR    D,X
00b5: cc 00 06        LDD    #$0006
00b8: 34 76           PSHS   U,Y,X,D
00ba: 17 41 c8        LBSR   $4285
00bd: 32 68           LEAS   $8,S
00bf: e6 62           LDB    $2,S
00c1: cb 01           ADDB   #$01
00c3: e7 62           STB    $2,S
00c5: 64 65           LSR    $5,S
00c7: e6 63           LDB    $3,S
00c9: cb 03           ADDB   #$03
00cb: e7 63           STB    $3,S
00cd: 20 c0           BRA    $008F
00cf: 32 66           LEAS   $6,S
00d1: 39              RTS
; =====================================================================================
; Thin wrapper: re-run $0000, then refresh display from $2285 via $5989. ($00D2)
; Frame size: 0 bytes (from ROM $8934).
; =====================================================================================
00d2: fc 89 34        LDD    $8934
00d5: 17 7c 78        LBSR   $7D50
00d8: ce 00 00        LDU    #$0000
00db: 34 40           PSHS   U
00dd: 17 ff 20        LBSR   $0000
00e0: 32 62           LEAS   $2,S
00e2: ce 22 85        LDU    #$2285
00e5: 10 8e 00 02     LDY    #$0002
00e9: 34 60           PSHS   U,Y
00eb: 17 58 9b        LBSR   $5989
00ee: 32 64           LEAS   $4,S
00f0: 32 62           LEAS   $2,S
00f2: 39              RTS
; =====================================================================================
; Reinitialize front-panel / per-channel state ($00F3).
; Frame size: 2 bytes (from ROM $8935, shared with $01AD).
; Clears several $2202/$2203 bits, calls $46EA, then iterates channels 0-3. For each channel:
;   - $35EF: sets parameter mode/type (arg $000F)
;   - $36EF: sets a per-channel flag based on $23B2 threshold
;   - $379C: additional per-channel state reset
;   - $7713: sets another per-channel parameter (arg $0000)
;   - $7770: sets per-channel parameter (arg $0003)
; Finishes with a call to $3646.
; =====================================================================================
00f3: fc 89 35        LDD    $8935
00f6: 17 7c 57        LBSR   $7D50
00f9: fc 22 02        LDD    $2202
00fc: 84 7d           ANDA   #$7D
00fe: c4 f1           ANDB   #$F1
0100: fd 22 02        STD    $2202
0103: ce 00 00        LDU    #$0000
0106: 34 40           PSHS   U
0108: 17 45 df        LBSR   $46EA
010b: 32 62           LEAS   $2,S
010d: 5f              CLRB
010e: 1d              SEX
010f: 1f 03           TFR    D,U
0111: 10 8e 00 02     LDY    #$0002
0115: 34 60           PSHS   U,Y
0117: 17 59 c6        LBSR   $5AE0
011a: 32 64           LEAS   $4,S
011c: 6f 62           CLR    $2,S
011e: c6 01           LDB    #$01
0120: e7 63           STB    $3,S
0122: e6 62           LDB    $2,S
0124: c1 04           CMPB   #$04
0126: 10 24 00 76     LBCC   $01A0
012a: e6 62           LDB    $2,S
012c: f1 23 b2        CMPB   $23B2
012f: 10 25 00 02     LBCS   $0135
0133: 6f 63           CLR    $3,S
0135: c6 0f           LDB    #$0F
0137: 1d              SEX
0138: 1f 03           TFR    D,U
013a: e6 62           LDB    $2,S
013c: 4f              CLRA
013d: 1f 02           TFR    D,Y
013f: 8e 00 04        LDX    #$0004
0142: 34 70           PSHS   U,Y,X
0144: 17 34 a8        LBSR   $35EF
0147: 32 66           LEAS   $6,S
0149: e6 63           LDB    $3,S
014b: 4f              CLRA
014c: 1f 03           TFR    D,U
014e: e6 62           LDB    $2,S
0150: 4f              CLRA
0151: 1f 02           TFR    D,Y
0153: 8e 00 04        LDX    #$0004
0156: 34 70           PSHS   U,Y,X
0158: 17 35 94        LBSR   $36EF
015b: 32 66           LEAS   $6,S
015d: e6 63           LDB    $3,S
015f: 4f              CLRA
0160: 1f 03           TFR    D,U
0162: e6 62           LDB    $2,S
0164: 4f              CLRA
0165: 1f 02           TFR    D,Y
0167: 8e 00 04        LDX    #$0004
016a: 34 70           PSHS   U,Y,X
016c: 17 36 2d        LBSR   $379C
016f: 32 66           LEAS   $6,S
0171: 5f              CLRB
0172: 1d              SEX
0173: 1f 03           TFR    D,U
0175: e6 62           LDB    $2,S
0177: 4f              CLRA
0178: 1f 02           TFR    D,Y
017a: 8e 00 04        LDX    #$0004
017d: 34 70           PSHS   U,Y,X
017f: 17 75 91        LBSR   $7713
0182: 32 66           LEAS   $6,S
0184: c6 03           LDB    #$03
0186: 1d              SEX
0187: 1f 03           TFR    D,U
0189: e6 62           LDB    $2,S
018b: 4f              CLRA
018c: 1f 02           TFR    D,Y
018e: 8e 00 04        LDX    #$0004
0191: 34 70           PSHS   U,Y,X
0193: 17 75 da        LBSR   $7770
0196: 32 66           LEAS   $6,S
0198: e6 62           LDB    $2,S
019a: cb 01           ADDB   #$01
019c: e7 62           STB    $2,S
019e: 20 82           BRA    $0122
01a0: ce 00 00        LDU    #$0000
01a3: 34 40           PSHS   U
01a5: 17 34 9e        LBSR   $3646
01a8: 32 62           LEAS   $2,S
01aa: 32 64           LEAS   $4,S
01ac: 39              RTS
; =====================================================================================
; Master runtime initialization ($01AD).
; Frame size: 2 bytes (from ROM $8935, shared with $00F3).
; Called during boot and when returning to idle baseline. Operations:
; 1. Calls $436E (broad state clear)
; 2. Initializes $2200=$23, $2201=$0F (shadow registers for some control port)
; 3. Disables IRQ ($5D06) and FIRQ ($5D09)
; 4. Clears $2202 and $2204 (all flags)
; 5. If $23C1 bit 0 (HP-IB active): restores HP-IB state from $24F0-$24F3 → $2206-$2209,
;    sets $220A=1. If HP-IB not active: clears $220A.
; 6. Calls ~10 subsystem initializers ($5524, $5596, $56C8, $5AE0, $3852, $381E, ...)
; 7. Conditionally enters HP-IB handler enumeration if GPIB is active
; =====================================================================================
01ad: fc 89 35        LDD    $8935
01b0: 17 7b 9d        LBSR   $7D50
01b3: ce 00 00        LDU    #$0000
01b6: 34 40           PSHS   U
01b8: 17 41 b3        LBSR   $436E            ; → $436E: broad state clear
01bb: 32 62           LEAS   $2,S
01bd: c6 23           LDB    #$23
01bf: f7 22 00        STB    $2200            ; init control shadow: $2200 = $23
01c2: c6 0f           LDB    #$0F
01c4: f7 22 01        STB    $2201            ; init control shadow: $2201 = $0F
01c7: ce 00 00        LDU    #$0000
01ca: 34 40           PSHS   U
01cc: 17 5b 37        LBSR   $5D06            ; disable IRQ
01cf: 32 62           LEAS   $2,S
01d1: ce 00 00        LDU    #$0000
01d4: 34 40           PSHS   U
01d6: 17 5b 30        LBSR   $5D09            ; disable FIRQ
01d9: 32 62           LEAS   $2,S
01db: 5f              CLRB
01dc: 4f              CLRA
01dd: fd 22 02        STD    $2202            ; clear all control flags
01e0: 5f              CLRB
01e1: 4f              CLRA
01e2: fd 22 04        STD    $2204            ; clear all foreground/interrupt flags
01e5: fc 23 c1        LDD    $23C1
01e8: 84 00           ANDA   #$00
01ea: c4 01           ANDB   #$01             ; $23C1 bit 0: HP-IB active?
01ec: 10 83 00 00     CMPD   #$0000
01f0: 10 27 00 29     LBEQ   $021D            ; not active → skip HP-IB restore
01f4: f6 22 0a        LDB    $220A
01f7: c1 00           CMPB   #$00             ; $220A already set?
01f9: 10 26 00 1d     LBNE   $021A            ; yes → skip restore, just flag it
; Restore HP-IB state from saved block $24F0-$24F3 into $2206-$2209
01fd: f6 24 f0        LDB    $24F0
0200: f7 22 06        STB    $2206
0203: f6 24 f1        LDB    $24F1
0206: f7 22 07        STB    $2207
0209: f6 24 f2        LDB    $24F2
020c: f7 22 08        STB    $2208
020f: f6 24 f3        LDB    $24F3
0212: f7 22 09        STB    $2209
0215: c6 01           LDB    #$01
0217: f7 22 0a        STB    $220A            ; mark HP-IB state as restored
021a: 16 00 03        LBRA   $0220
021d: 7f 22 0a        CLR    $220A            ; HP-IB not active: clear flag
; Subsystem initialization chain
0220: ce 00 00        LDU    #$0000
0223: 34 40           PSHS   U
0225: 17 52 fc        LBSR   $5524            ; → $5524: init subsystem 1
0228: 32 62           LEAS   $2,S
022a: ce 00 00        LDU    #$0000
022d: 34 40           PSHS   U
022f: 17 53 64        LBSR   $5596            ; → $5596: init subsystem 2
0232: 32 62           LEAS   $2,S
0234: ce 00 00        LDU    #$0000
0237: 34 40           PSHS   U
0239: 17 54 8c        LBSR   $56C8            ; → $56C8: init subsystem 3
023c: 32 62           LEAS   $2,S
023e: 5f              CLRB
023f: 1d              SEX
0240: 1f 03           TFR    D,U
0242: 10 8e 00 02     LDY    #$0002
0246: 34 60           PSHS   U,Y
0248: 17 58 95        LBSR   $5AE0            ; → $5AE0: page/state reset (arg=0)
024b: 32 64           LEAS   $4,S
024d: ce 00 00        LDU    #$0000
0250: 34 40           PSHS   U
0252: 17 35 fd        LBSR   $3852            ; → $3852: init subsystem 5
0255: 32 62           LEAS   $2,S
0257: ce 00 00        LDU    #$0000
025a: 34 40           PSHS   U
025c: 17 35 bf        LBSR   $381E            ; → $381E: init subsystem 6
025f: 32 62           LEAS   $2,S
0261: ce 00 00        LDU    #$0000
0264: 34 40           PSHS   U
0266: 17 18 14        LBSR   $1A7D            ; → $1A7D: P8291A / GPIB init
0269: 32 62           LEAS   $2,S
026b: ce 00 00        LDU    #$0000
026e: 34 40           PSHS   U
0270: 17 57 73        LBSR   $59E6            ; → $59E6: display init
0273: 32 62           LEAS   $2,S
0275: ce 00 00        LDU    #$0000
0278: 34 40           PSHS   U
027a: 17 58 df        LBSR   $5B5C            ; → $5B5C: init loop state
027d: 32 62           LEAS   $2,S
027f: ce 00 00        LDU    #$0000
0282: 34 40           PSHS   U
0284: 17 59 f4        LBSR   $5C7B            ; → $5C7B: self-test (RAM + ROM checksum)
0287: 32 62           LEAS   $2,S
0289: ce 01 2c        LDU    #$012C           ; delay $012C (300) via $5670
028c: 10 8e 00 02     LDY    #$0002
0290: 34 60           PSHS   U,Y
0292: 17 53 db        LBSR   $5670            ; → $5670: delay loop
0295: 32 64           LEAS   $4,S
0297: ce 00 00        LDU    #$0000
029a: 34 40           PSHS   U
029c: 17 17 d7        LBSR   $1A76            ; → $1A76: P8291A enable (post-selftest)
029f: 32 62           LEAS   $2,S
02a1: 7f 24 13        CLR    $2413            ; clear formatter state
; Conditional early GPIB reconfiguration if $23DD (prior session state) is nonzero
02a4: f6 23 dd        LDB    $23DD
02a7: c1 00           CMPB   #$00
02a9: 10 27 00 0d     LBEQ   $02BA            ; zero → skip
02ad: ce 00 00        LDU    #$0000
02b0: 34 40           PSHS   U
02b2: 17 40 0f        LBSR   $42C4            ; → $42C4: reconfigure from saved state
02b5: 32 62           LEAS   $2,S
02b7: 7f 22 0a        CLR    $220A            ; clear restored flag after reconfig
; If HP-IB active: enumerate and initialize all 4 output channels
02ba: fc 23 c1        LDD    $23C1
02bd: 84 00           ANDA   #$00
02bf: c4 01           ANDB   #$01             ; $23C1 bit 0: HP-IB active?
02c1: 10 83 00 00     CMPD   #$0000
02c5: 10 27 00 5b     LBEQ   $0324            ; no → skip channel init
02c9: ce 00 00        LDU    #$0000
02cc: 34 40           PSHS   U
02ce: 17 44 19        LBSR   $46EA            ; → $46EA: HP-IB subsystem pre-init
02d1: 32 62           LEAS   $2,S
; Loop: init channels 0-3 from $2206[$2,S] via $5BA1 (output port access)
02d3: 6f 62           CLR    $2,S             ; channel index = 0
02d5: e6 62           LDB    $2,S
02d7: c1 04           CMPB   #$04             ; all 4 channels done?
02d9: 10 24 00 3a     LBCC   $0317            ; yes → finalize
02dd: 8e 22 06        LDX    #$2206           ; X → channel state array base
02e0: e6 62           LDB    $2,S
02e2: 3a              ABX                     ; X → $2206[channel]
02e3: e6 84           LDB    ,X               ; B = channel state byte
02e5: e7 63           STB    $3,S
02e7: e6 63           LDB    $3,S
02e9: 4f              CLRA
02ea: 1f 03           TFR    D,U              ; U = state byte (arg 1)
02ec: 10 8e 00 ff     LDY    #$00FF           ; Y = $FF (arg 2: all outputs enabled)
02f0: e6 62           LDB    $2,S
02f2: 4f              CLRA
02f3: 1f 01           TFR    D,X              ; X = channel index (arg 3)
02f5: cc 00 06        LDD    #$0006
02f8: 34 76           PSHS   U,Y,X,D
02fa: 17 58 a4        LBSR   $5BA1            ; → $5BA1: configure output port
02fd: 32 68           LEAS   $8,S
02ff: e6 62           LDB    $2,S
0301: 4f              CLRA
0302: 1f 03           TFR    D,U              ; U = channel index
0304: 10 8e 00 02     LDY    #$0002
0308: 34 60           PSHS   U,Y
030a: 17 34 22        LBSR   $372F            ; → $372F: per-channel init
030d: 32 64           LEAS   $4,S
030f: e6 62           LDB    $2,S
0311: cb 01           ADDB   #$01             ; channel++
0313: e7 62           STB    $2,S
0315: 20 be           BRA    $02D5            ; → loop
; Channel init done: reset all output ports to idle
0317: ce 00 00        LDU    #$0000
031a: 34 40           PSHS   U
031c: 17 33 27        LBSR   $3646            ; → $3646: reset all output ports
031f: 32 62           LEAS   $2,S
0321: 16 00 14        LBRA   $0338            ; → post-init delay
; HP-IB not active path: clear and init front panel only
0324: ce 00 00        LDU    #$0000
0327: 34 40           PSHS   U
0329: 17 fd c7        LBSR   $00F3            ; → $00F3: front-panel state reset
032c: 32 62           LEAS   $2,S
032e: ce 00 00        LDU    #$0000
0331: 34 40           PSHS   U
0333: 17 43 8d        LBSR   $46C3            ; → $46C3: standalone front-panel init
0336: 32 62           LEAS   $2,S
; Post-init delay: $00FA (250) iterations via $5670
0338: ce 00 fa        LDU    #$00FA
033b: 10 8e 00 02     LDY    #$0002
033f: 34 60           PSHS   U,Y
0341: 17 53 2c        LBSR   $5670
0344: 32 64           LEAS   $4,S
; Conditional first-run display: if $23B2 == 0, call $43FE($0A) for initial display
0346: f6 23 b2        LDB    $23B2
0349: c1 00           CMPB   #$00
034b: 10 26 00 13     LBNE   $0362            ; nonzero → skip, clear $23DE instead
034f: c6 0a           LDB    #$0A
0351: 1d              SEX
0352: 1f 03           TFR    D,U              ; arg = $0A (initial display mode)
0354: 10 8e 00 02     LDY    #$0002
0358: 34 60           PSHS   U,Y
035a: 17 40 a1        LBSR   $43FE            ; → $43FE: display setup
035d: 32 64           LEAS   $4,S
035f: 16 00 03        LBRA   $0365
0362: 7f 23 de        CLR    $23DE            ; returning from prior state: clear flag
; Install default HP-IB hooks and enable interrupts
0365: cc c2 39        LDD    #$C239
0368: fd 22 13        STD    $2213            ; $2213 = $C239 (pre-dispatch hook = stub RTS)
036b: ce 00 00        LDU    #$0000
036e: 34 40           PSHS   U
0370: 17 19 c1        LBSR   $1D34            ; → $1D34: init HP-IB event hooks
0373: 32 62           LEAS   $2,S
0375: ce 00 00        LDU    #$0000
0378: 34 40           PSHS   U
037a: 17 51 c8        LBSR   $5545            ; → $5545: finalize subsystem setup
037d: 32 62           LEAS   $2,S
037f: ce 00 00        LDU    #$0000
0382: 34 40           PSHS   U
0384: 17 59 79        LBSR   $5D00            ; enable IRQ
0387: 32 62           LEAS   $2,S
0389: ce 00 00        LDU    #$0000
038c: 34 40           PSHS   U
038e: 17 59 72        LBSR   $5D03            ; enable FIRQ
0391: 32 62           LEAS   $2,S
0393: ce 00 00        LDU    #$0000
0396: 34 40           PSHS   U
0398: 17 53 2d        LBSR   $56C8            ; → $56C8: reinit subsystem 3
039b: 32 62           LEAS   $2,S
039d: 32 64           LEAS   $4,S
039f: 39              RTS
; =====================================================================================
; Cold-start sequencing entered from reset ($03A0).
; Frame size: 18 bytes (from ROM $8937 = $0012).
; 1. Calls master init $01AD.
; 2. Derives a mode/index from $2202 bits 6/5/4: bit 6 adds 4, bit 5 adds 2, bit 4 adds 1.
;    These correspond to self-test error flags: bit 6 = $2202 bit 6 (RAM error detected by
;    $5C82), bit 5 = $2202 bit 5 (A2U12 ROM checksum fail), bit 4 = $2202 bit 4 (A2U13
;    paged ROM checksum fail). If any are set, X > 0 and the cold-start shows a diagnostic
;    display before entering the main loop.
; 3. If X = 0 (no errors): skips display init, jumps directly to $048D.
; 4. If X > 0: copies ROM templates ($EA71, $EE1F) into display buffers, calls $4912 with
;    the error index, then calls $58EA to render the display.
; 5. Spins at $0467 waiting for $2204 bit 1 or bit 2 to be set (interrupt/status activity).
; 6. Calls $0939, clears local state, and falls into the HP-IB entry point at $0499.
; =====================================================================================
03a0: fc 89 37        LDD    $8937
03a3: 17 79 aa        LBSR   $7D50
03a6: ce 00 00        LDU    #$0000
03a9: 34 40           PSHS   U
03ab: 17 fd ff        LBSR   $01AD            ; → master runtime initialization
03ae: 32 62           LEAS   $2,S
03b0: 6f 63           CLR    $3,S             ; clear watchdog secondary counter
03b2: 6f 66           CLR    $6,S             ; clear key repeat armed flag
03b4: 6f 67           CLR    $7,S             ; clear key idle counter
; Decode self-test error index from $2202 bits 6/5/4
03b6: 5f              CLRB
03b7: 4f              CLRA
03b8: ed 68           STD    $8,S             ; error index = 0
03ba: fc 22 02        LDD    $2202
03bd: 84 40           ANDA   #$40             ; bit 6: RAM test fail?
03bf: c4 00           ANDB   #$00
03c1: 10 83 00 00     CMPD   #$0000
03c5: 10 27 00 07     LBEQ   $03D0            ; no → check bit 5
03c9: ec 68           LDD    $8,S
03cb: c3 00 04        ADDD   #$0004           ; +4 (RAM error)
03ce: ed 68           STD    $8,S
03d0: fc 22 02        LDD    $2202
03d3: 84 20           ANDA   #$20             ; bit 5: A2U12 ROM checksum fail?
03d5: c4 00           ANDB   #$00
03d7: 10 83 00 00     CMPD   #$0000
03db: 10 27 00 07     LBEQ   $03E6            ; no → check bit 4
03df: ec 68           LDD    $8,S
03e1: c3 00 02        ADDD   #$0002           ; +2 (A2U12 ROM error)
03e4: ed 68           STD    $8,S
03e6: fc 22 02        LDD    $2202
03e9: 84 10           ANDA   #$10             ; bit 4: A2U13 ROM checksum fail?
03eb: c4 00           ANDB   #$00
03ed: 10 83 00 00     CMPD   #$0000
03f1: 10 27 00 07     LBEQ   $03FC            ; no → done decoding
03f5: ec 68           LDD    $8,S
03f7: c3 00 01        ADDD   #$0001           ; +1 (A2U13 ROM error)
03fa: ed 68           STD    $8,S
; If error index == 0 (all tests passed), skip diagnostic display
03fc: ae 68           LDX    $8,S             ; X = error index
03fe: 8c 00 00        CMPX   #$0000
0401: 10 27 00 88     LBEQ   $048D            ; no errors → jump to normal init
; Display diagnostic: call $43FE($0B) then render error template
0405: c6 0b           LDB    #$0B             ; display mode $0B (diagnostic)
0407: 1d              SEX
0408: 1f 03           TFR    D,U
040a: 10 8e 00 02     LDY    #$0002
040e: 34 60           PSHS   U,Y
0410: 17 3f eb        LBSR   $43FE
0413: 32 64           LEAS   $4,S
; Copy error template $EA71 (40 chars) into LCD line 1 buffer
0415: ce ea 71        LDU    #$EA71
0418: c6 28           LDB    #$28
041a: 1d              SEX
041b: 1f 02           TFR    D,Y
041d: 5f              CLRB
041e: 1d              SEX
041f: 1f 01           TFR    D,X
0421: cc 00 06        LDD    #$0006
0424: 34 76           PSHS   U,Y,X,D
0426: 17 54 c1        LBSR   $58EA
0429: 32 68           LEAS   $8,S
; Copy blank template $EE1F (40 chars) into LCD line 2 buffer
042b: ce ee 1f        LDU    #$EE1F
042e: c6 28           LDB    #$28
0430: 1d              SEX
0431: 1f 02           TFR    D,Y
0433: c6 40           LDB    #$40
0435: 1d              SEX
0436: 1f 01           TFR    D,X
0438: cc 00 06        LDD    #$0006
043b: 34 76           PSHS   U,Y,X,D
043d: 17 54 aa        LBSR   $58EA
0440: 32 68           LEAS   $8,S
; Call $4912 with error index to format the specific error message
0442: 33 6c           LEAU   $C,S             ; U → output buffer on stack
0444: 10 ae 68        LDY    $8,S             ; Y = error index
0447: 8e 00 04        LDX    #$0004
044a: 34 70           PSHS   U,Y,X
044c: 17 44 c3        LBSR   $4912            ; → $4912: format error string
044f: 32 66           LEAS   $6,S
0451: 33 6f           LEAU   $F,S
0453: c6 02           LDB    #$02
0455: 1d              SEX
0456: 1f 02           TFR    D,Y
0458: c6 10           LDB    #$10
045a: 1d              SEX
045b: 1f 01           TFR    D,X
045d: cc 00 06        LDD    #$0006
0460: 34 76           PSHS   U,Y,X,D
0462: 17 54 85        LBSR   $58EA
0465: 32 68           LEAS   $8,S
0467: fc 22 04        LDD    $2204
046a: 84 00           ANDA   #$00
046c: c4 02           ANDB   #$02
046e: 10 83 00 00     CMPD   #$0000
0472: 10 26 00 12     LBNE   $0488
0476: fc 22 04        LDD    $2204
0479: 84 00           ANDA   #$00
047b: c4 01           ANDB   #$01
047d: 10 83 00 00     CMPD   #$0000
0481: 10 26 00 03     LBNE   $0488
0485: 16 00 03        LBRA   $048B
0488: 16 00 02        LBRA   $048D
048b: 20 da           BRA    $0467
048d: ce 00 00        LDU    #$0000
0490: 34 40           PSHS   U
0492: 17 04 a4        LBSR   $0939
0495: 32 62           LEAS   $2,S
0497: 6f 62           CLR    $2,S
; =====================================================================================
; Foreground HP-IB entry point ($0499).
; If $23C1 bit 0 (HP-IB active): pushes arg $0002 and calls the handler at [$24E6].
;   The handler is dynamically installed: $8D23 (idle) or $A73E (active GPIB session).
;   After the handler returns, clears $220A and falls into the main loop at $04CA.
; If $23C1 bit 0 is clear: calls $0D23 to reset the handler to the idle/default path.
; =====================================================================================
0499: fc 23 c1        LDD    $23C1
049c: 84 00           ANDA   #$00
049e: c4 01           ANDB   #$01
04a0: 10 83 00 00     CMPD   #$0000
04a4: 10 27 00 18     LBEQ   $04C0
04a8: c6 02           LDB    #$02
04aa: 1d              SEX
04ab: 1f 03           TFR    D,U
04ad: 10 8e 00 02     LDY    #$0002
04b1: 34 60           PSHS   U,Y
04b3: be 24 e6        LDX    $24E6
04b6: ad 84           JSR    ,X
04b8: 32 64           LEAS   $4,S
04ba: 7f 22 0a        CLR    $220A
04bd: 16 00 0a        LBRA   $04CA
04c0: ce 00 00        LDU    #$0000
04c3: 34 40           PSHS   U
04c5: 17 08 5b        LBSR   $0D23
04c8: 32 62           LEAS   $2,S
; =====================================================================================
; Main foreground loop ($04CA).
; Reads the system interrupt/status latch at $0100 (NOT the P8291A — that's $0400). XORs with
; $0F to invert the low 4 bits. The XOR result is saved in $5,S for repeated bit testing.
;
; Key bit handling:
; - Bit 5 of the XOR result gates a display refresh cycle: if set and $2204 bit 5 is clear,
;   enters the display refresh path (sets $2204 bits 4 and 5, calls $1DD3 and display helpers).
;   When $2204 bit 5 is already set but $0100 bit 5 clears, it exits the refresh state.
; - Low 4 bits (after XOR) drive front-panel key scanning. The loop decodes which key column
;   is active and calls $1DD3 with the key code.
; - After key processing: checks $2204 bit 0 (IRQ latched). If set, re-enables IRQ via $5D00,
;   then checks $2204 bit 2 (request dispatch pending). If set, calls $0D60 to dispatch.
;
; The loop branches back to $04CA from $092B, making this the central non-interrupt scheduler.
; =====================================================================================
; --- Top of main loop ---
04ca: f6 01 00        LDB    $0100       ; read system interrupt/status latch
04cd: c8 0f           EORB   #$0F        ; invert low 4 bits (active-low key inputs)
04cf: e7 65           STB    $5,S        ; save XOR result for bit tests below
; Check bit 5: display refresh trigger
04d1: e6 65           LDB    $5,S
04d3: c4 20           ANDB   #$20        ; test bit 5
04d5: 10 27 00 12     LBEQ   $04EB       ; bit 5 clear → skip display entry
04d9: fc 22 04        LDD    $2204
04dc: 84 00           ANDA   #$00
04de: c4 20           ANDB   #$20        ; test $2204 bit 5 (refresh state already active?)
04e0: 10 83 00 00     CMPD   #$0000
04e4: 10 26 00 03     LBNE   $04EB       ; already active → skip
04e8: 16 00 03        LBRA   $04EE       ; → enter display refresh path
04eb: 16 00 82        LBRA   $0570       ; → skip to display-exit / key scan
; --- Display refresh entry: set active flags, render LCD lines ---
04ee: fc 22 04        LDD    $2204
04f1: 8a 00           ORA    #$00
04f3: ca 20           ORB    #$20             ; set $2204 bit 5 (display refresh active)
04f5: fd 22 04        STD    $2204
04f8: fc 22 04        LDD    $2204
04fb: 8a 00           ORA    #$00
04fd: ca 10           ORB    #$10             ; set $2204 bit 4
04ff: fd 22 04        STD    $2204
0502: fc 22 04        LDD    $2204
0505: 84 00           ANDA   #$00
0507: c4 08           ANDB   #$08             ; if $2204 bit 3: post status event $0C
0509: 10 83 00 00     CMPD   #$0000
050d: 10 27 00 14     LBEQ   $0525
0511: c6 0c           LDB    #$0C
0513: 1d              SEX
0514: 1f 03           TFR    D,U
0516: c6 01           LDB    #$01
0518: 1d              SEX
0519: 1f 02           TFR    D,Y
051b: 8e 00 04        LDX    #$0004
051e: 34 70           PSHS   U,Y,X
0520: 17 18 b0        LBSR   $1DD3
0523: 32 66           LEAS   $6,S
; Render LCD line 1 from $EDCF (40 chars, offset 0) via $58A5
0525: ce ed cf        LDU    #$EDCF
0528: c6 28           LDB    #$28
052a: 1d              SEX
052b: 1f 02           TFR    D,Y
052d: 5f              CLRB
052e: 1d              SEX
052f: 1f 01           TFR    D,X
0531: cc 00 06        LDD    #$0006
0534: 34 76           PSHS   U,Y,X,D
0536: 17 53 6c        LBSR   $58A5
0539: 32 68           LEAS   $8,S
; Render LCD line 2 from $ED11 (40 chars, offset $40) via $58A5
053b: ce ed 11        LDU    #$ED11
053e: c6 28           LDB    #$28
0540: 1d              SEX
0541: 1f 02           TFR    D,Y
0543: c6 40           LDB    #$40
0545: 1d              SEX
0546: 1f 01           TFR    D,X
0548: cc 00 06        LDD    #$0006
054b: 34 76           PSHS   U,Y,X,D
054d: 17 53 55        LBSR   $58A5
0550: 32 68           LEAS   $8,S
; Call $43FE($0C, 2) — update LCD hardware with rendered content
0552: c6 0c           LDB    #$0C
0554: 1d              SEX
0555: 1f 03           TFR    D,U
0557: 10 8e 00 02     LDY    #$0002
055b: 34 60           PSHS   U,Y
055d: 17 3e 9e        LBSR   $43FE
0560: 32 64           LEAS   $4,S
; Delay $02EE (750 decimal) via $5670 — LCD settle time
0562: ce 02 ee        LDU    #$02EE
0565: 10 8e 00 02     LDY    #$0002
0569: 34 60           PSHS   U,Y
056b: 17 51 02        LBSR   $5670
056e: 32 64           LEAS   $4,S
; --- Display exit check: if bit 5 was active but $0100 bit 5 now clear, finalize ---
0570: fc 22 04        LDD    $2204
0573: 84 00           ANDA   #$00
0575: c4 20           ANDB   #$20             ; $2204 bit 5 still set?
0577: 10 83 00 00     CMPD   #$0000
057b: 10 27 00 10     LBEQ   $058F            ; not set → skip to keys
057f: e6 65           LDB    $5,S
0581: c4 20           ANDB   #$20             ; $0100 bit 5 still active?
0583: 4f              CLRA
0584: 10 83 00 00     CMPD   #$0000
0588: 10 26 00 03     LBNE   $058F            ; yes → display still needed, skip
058c: 16 00 03        LBRA   $0592            ; no → finalize display refresh
058f: 16 00 42        LBRA   $05D4            ; → key column scan
; Clear $2204 bit 5, call $1DB7(1) — finalize display refresh
0592: fc 22 04        LDD    $2204
0595: 84 ff           ANDA   #$FF
0597: c4 df           ANDB   #$DF             ; clear bit 5 (refresh no longer active)
0599: fd 22 04        STD    $2204
059c: c6 01           LDB    #$01
059e: 1d              SEX
059f: 1f 03           TFR    D,U
05a1: 10 8e 00 02     LDY    #$0002
05a5: 34 60           PSHS   U,Y
05a7: 17 18 0d        LBSR   $1DB7
05aa: 32 64           LEAS   $4,S
05ac: fc 22 04        LDD    $2204
05af: 84 00           ANDA   #$00
05b1: c4 40           ANDB   #$40             ; $2204 bit 6 (key processing active?)
05b3: 10 83 00 00     CMPD   #$0000
05b7: 10 26 00 0d     LBNE   $05C8            ; set → clear it instead
05bb: ce 00 00        LDU    #$0000
05be: 34 40           PSHS   U
05c0: 17 54 03        LBSR   $59C6            ; bit 6 clear → call $59C6 (soft-key refresh)
05c3: 32 62           LEAS   $2,S
05c5: 16 00 0c        LBRA   $05D4
05c8: fc 22 04        LDD    $2204
05cb: 84 ff           ANDA   #$FF
05cd: c4 bf           ANDB   #$BF             ; clear $2204 bit 6
05cf: fd 22 04        STD    $2204
05d2: 6f 62           CLR    $2,S
; Key column scan: isolate low 4 bits of XOR result (inverted active-low key inputs)
05d4: e6 65           LDB    $5,S
05d6: c4 0f           ANDB   #$0F        ; mask to key columns 0-3
05d8: 10 27 01 20     LBEQ   $06FC       ; no keys active → skip key processing
05dc: fc 22 04        LDD    $2204
05df: 84 00           ANDA   #$00
05e1: c4 40           ANDB   #$40             ; $2204 bit 6 already set?
05e3: 10 83 00 00     CMPD   #$0000
05e7: 10 26 00 37     LBNE   $0622            ; already processing → skip setup
; First key press: set $2204 bits 6 and 4
05eb: fc 22 04        LDD    $2204
05ee: 8a 00           ORA    #$00
05f0: ca 40           ORB    #$40             ; set bit 6 (key processing active)
05f2: fd 22 04        STD    $2204
05f5: fc 22 04        LDD    $2204
05f8: 8a 00           ORA    #$00
05fa: ca 10           ORB    #$10             ; set bit 4
05fc: fd 22 04        STD    $2204
05ff: fc 22 04        LDD    $2204
0602: 84 00           ANDA   #$00
0604: c4 08           ANDB   #$08             ; if bit 3 set: post status event $0D
0606: 10 83 00 00     CMPD   #$0000
060a: 10 27 00 14     LBEQ   $0622
060e: c6 0d           LDB    #$0D
0610: 1d              SEX
0611: 1f 03           TFR    D,U
0613: c6 04           LDB    #$04
0615: 1d              SEX
0616: 1f 02           TFR    D,Y
0618: 8e 00 04        LDX    #$0004
061b: 34 70           PSHS   U,Y,X
061d: 17 17 b3        LBSR   $1DD3
0620: 32 66           LEAS   $6,S
0622: e6 65           LDB    $5,S
0624: c4 0f           ANDB   #$0F
0626: 4f              CLRA
0627: ed e8 12        STD    $12,S
062a: e6 62           LDB    $2,S
062c: 4f              CLRA
062d: 10 a3 e8 12     CMPD   $12,S
0631: 10 27 00 c7     LBEQ   $06FC
; Decode active key column. Each column maps to a priority value ($4,S) and ASCII char ($11,S).
; Priority: bit 3 > bit 2 > bit 1 > bit 0 (last match wins due to fall-through).
0635: e6 65           LDB    $5,S
0637: c4 08           ANDB   #$08        ; column 3 (bit 3)?
0639: 10 27 00 09     LBEQ   $0646
063d: c6 04           LDB    #$04        ; priority 4
063f: e7 64           STB    $4,S
0641: c6 34           LDB    #$34        ; ASCII '4'
0643: e7 e8 11        STB    $11,S
0646: e6 65           LDB    $5,S
0648: c4 04           ANDB   #$04        ; column 2 (bit 2)?
064a: 10 27 00 09     LBEQ   $0657
064e: c6 03           LDB    #$03        ; priority 3
0650: e7 64           STB    $4,S
0652: c6 33           LDB    #$33        ; ASCII '3'
0654: e7 e8 11        STB    $11,S
0657: e6 65           LDB    $5,S
0659: c4 02           ANDB   #$02        ; column 1 (bit 1)?
065b: 10 27 00 09     LBEQ   $0668
065f: c6 02           LDB    #$02        ; priority 2
0661: e7 64           STB    $4,S
0663: c6 32           LDB    #$32        ; ASCII '2'
0665: e7 e8 11        STB    $11,S
0668: e6 65           LDB    $5,S
066a: c4 01           ANDB   #$01        ; column 0 (bit 0)?
066c: 10 27 00 09     LBEQ   $0679
0670: c6 01           LDB    #$01        ; priority 1
0672: e7 64           STB    $4,S
0674: c6 31           LDB    #$31        ; ASCII '1'
0676: e7 e8 11        STB    $11,S
; Render key-press feedback on LCD line 1: $EDF7 (40 chars, offset 0)
0679: ce ed f7        LDU    #$EDF7
067c: c6 28           LDB    #$28
067e: 1d              SEX
067f: 1f 02           TFR    D,Y
0681: 5f              CLRB
0682: 1d              SEX
0683: 1f 01           TFR    D,X
0685: cc 00 06        LDD    #$0006
0688: 34 76           PSHS   U,Y,X,D
068a: 17 52 18        LBSR   $58A5
068d: 32 68           LEAS   $8,S
; Write key ASCII char from $11,S into LCD buffer at column $26 (38), 1 char
068f: 33 e8 11        LEAU   $11,S            ; U → key ASCII char on stack
0692: c6 01           LDB    #$01
0694: 1d              SEX
0695: 1f 02           TFR    D,Y              ; Y = 1 (char count)
0697: c6 26           LDB    #$26
0699: 1d              SEX
069a: 1f 01           TFR    D,X              ; X = $26 (column offset 38)
069c: cc 00 06        LDD    #$0006
069f: 34 76           PSHS   U,Y,X,D
06a1: 17 52 01        LBSR   $58A5
06a4: 32 68           LEAS   $8,S
; Select LCD line 2 source based on $2204 bit 3 (status event gate)
06a6: fc 22 04        LDD    $2204
06a9: 84 00           ANDA   #$00
06ab: c4 08           ANDB   #$08             ; test bit 3
06ad: 10 83 00 00     CMPD   #$0000
06b1: 10 26 00 1a     LBNE   $06CF            ; bit 3 set → use $ED11 (active status line)
; Bit 3 clear: render LCD line 2 from $EE1F (40 chars, offset $40)
06b5: ce ee 1f        LDU    #$EE1F
06b8: c6 28           LDB    #$28
06ba: 1d              SEX
06bb: 1f 02           TFR    D,Y
06bd: c6 40           LDB    #$40
06bf: 1d              SEX
06c0: 1f 01           TFR    D,X
06c2: cc 00 06        LDD    #$0006
06c5: 34 76           PSHS   U,Y,X,D
06c7: 17 51 db        LBSR   $58A5
06ca: 32 68           LEAS   $8,S
06cc: 16 00 17        LBRA   $06E6
; Bit 3 set: render LCD line 2 from $ED11 (40 chars, offset $40)
06cf: ce ed 11        LDU    #$ED11
06d2: c6 28           LDB    #$28
06d4: 1d              SEX
06d5: 1f 02           TFR    D,Y
06d7: c6 40           LDB    #$40
06d9: 1d              SEX
06da: 1f 01           TFR    D,X
06dc: cc 00 06        LDD    #$0006
06df: 34 76           PSHS   U,Y,X,D
06e1: 17 51 c1        LBSR   $58A5
06e4: 32 68           LEAS   $8,S
; Save current column state, then update LCD hardware via $43FE($0D, 2)
06e6: e6 65           LDB    $5,S
06e8: c4 0f           ANDB   #$0F             ; mask key columns
06ea: e7 62           STB    $2,S             ; save current column state
06ec: c6 0d           LDB    #$0D
06ee: 1d              SEX
06ef: 1f 03           TFR    D,U              ; arg = $0D (key-press LCD update)
06f1: 10 8e 00 02     LDY    #$0002
06f5: 34 60           PSHS   U,Y
06f7: 17 3d 04        LBSR   $43FE            ; → $43FE: update LCD hardware
06fa: 32 64           LEAS   $4,S
; --- Key-release detection ($06FC) ---
; If bit 6 is set (key was being processed) but column bits are now all zero (key released),
; clears bit 6, calls $1DB7(4) to finalize key event, and refreshes soft-keys via $59C6.
06fc: fc 22 04        LDD    $2204
06ff: 84 00           ANDA   #$00
0701: c4 40           ANDB   #$40             ; test $2204 bit 6 (key processing active)
0703: 10 83 00 00     CMPD   #$0000
0707: 10 27 00 10     LBEQ   $071B            ; not active → skip
070b: e6 65           LDB    $5,S             ; check $0100 column bits
070d: c4 0f           ANDB   #$0F             ; mask low 4 bits (XOR'd key columns)
070f: 4f              CLRA
0710: 10 83 00 00     CMPD   #$0000
0714: 10 26 00 03     LBNE   $071B            ; columns still active → key held, skip
0718: 16 00 03        LBRA   $071E            ; all columns zero → key released
071b: 16 00 42        LBRA   $0760            ; → key-event state refresh
; Key released: clear processing flag, call $1DB7(4) to finalize
071e: fc 22 04        LDD    $2204
0721: 84 ff           ANDA   #$FF
0723: c4 bf           ANDB   #$BF             ; clear bit 6 (key processing done)
0725: fd 22 04        STD    $2204
0728: c6 04           LDB    #$04
072a: 1d              SEX
072b: 1f 03           TFR    D,U
072d: 10 8e 00 02     LDY    #$0002
0731: 34 60           PSHS   U,Y
0733: 17 16 81        LBSR   $1DB7            ; → $1DB7: finalize key event (arg=4)
0736: 32 64           LEAS   $4,S
0738: 6f 62           CLR    $2,S             ; clear saved key row
073a: fc 22 04        LDD    $2204
073d: 84 00           ANDA   #$00
073f: c4 20           ANDB   #$20             ; test bit 5 (display refresh active)
0741: 10 83 00 00     CMPD   #$0000
0745: 10 26 00 0d     LBNE   $0756            ; display active → clear bit 5 instead
0749: ce 00 00        LDU    #$0000
074c: 34 40           PSHS   U
074e: 17 52 75        LBSR   $59C6            ; → $59C6: soft-key label refresh
0751: 32 62           LEAS   $2,S
0753: 16 00 0a        LBRA   $0760            ; → key-event state refresh
; Display was still active during key release — clear bit 5 (end display refresh)
0756: fc 22 04        LDD    $2204
0759: 84 ff           ANDA   #$FF
075b: c4 df           ANDB   #$DF             ; clear bit 5
075d: fd 22 04        STD    $2204
; --- Key-event state refresh ($0760) ---
; Gated by $2204 bit 1 (set by FIRQ handler at $7102 when a key is detected).
; Clears bit 1, enters idle-timeout state if not already active ($5B5C), reinitializes
; watchdog counters, conditionally refreshes display ($33C2), and posts request $08 if
; key processing is active (bit 6) with no pending status event (bit 3 clear).
0760: fc 22 04        LDD    $2204
0763: 84 00           ANDA   #$00
0765: c4 02           ANDB   #$02             ; test $2204 bit 1
0767: 10 83 00 00     CMPD   #$0000
076b: 10 27 00 75     LBEQ   $07E4            ; not set → skip to IRQ latch check
076f: fc 22 04        LDD    $2204
0772: 84 ff           ANDA   #$FF
0774: c4 fd           ANDB   #$FD             ; clear bit 1
0776: fd 22 04        STD    $2204
0779: fc 22 04        LDD    $2204
077c: 84 00           ANDA   #$00
077e: c4 80           ANDB   #$80             ; test bit 7 (idle-timeout active)
0780: 10 83 00 00     CMPD   #$0000
0784: 10 26 00 0a     LBNE   $0792            ; already active → skip $5B5C
0788: ce 00 00        LDU    #$0000
078b: 34 40           PSHS   U
078d: 17 53 cc        LBSR   $5B5C            ; → $5B5C: enter idle-timeout state (set bit 7, LED off)
0790: 32 62           LEAS   $2,S
0792: cc 0f dd        LDD    #$0FDD           ; init primary watchdog counter = $0FDD (4061)
0795: ed 6a           STD    $A,S
0797: 6f 63           CLR    $3,S             ; reset secondary counter
0799: fc 22 04        LDD    $2204
079c: 84 00           ANDA   #$00
079e: c4 20           ANDB   #$20             ; test bit 5 (display refresh active)
07a0: 10 83 00 00     CMPD   #$0000
07a4: 10 26 00 0a     LBNE   $07B2            ; active → skip refresh call
07a8: ce 00 00        LDU    #$0000
07ab: 34 40           PSHS   U
07ad: 17 2c 12        LBSR   $33C2            ; → $33C2: display refresh
07b0: 32 62           LEAS   $2,S
07b2: fc 22 04        LDD    $2204
07b5: 84 00           ANDA   #$00
07b7: c4 40           ANDB   #$40             ; test bit 6 (key processing active)
07b9: 10 83 00 00     CMPD   #$0000
07bd: 10 27 00 12     LBEQ   $07D3            ; not active → skip
07c1: fc 22 04        LDD    $2204
07c4: 84 00           ANDA   #$00
07c6: c4 08           ANDB   #$08             ; test bit 3 (status event gate)
07c8: 10 83 00 00     CMPD   #$0000
07cc: 10 26 00 03     LBNE   $07D3            ; gate set → skip (event pending)
07d0: 16 00 03        LBRA   $07D6            ; key active + gate clear → post request
07d3: 16 00 0e        LBRA   $07E4            ; → IRQ latch check
; Key active with no event pending: post request type $08 (port idle reset)
07d6: ce 00 08        LDU    #$0008
07d9: 10 8e 00 02     LDY    #$0002
07dd: 34 60           PSHS   U,Y
07df: 17 02 ee        LBSR   $0AD0
07e2: 32 64           LEAS   $4,S
; Check $2204 bit 0: IRQ latched (set by $7154 in IRQ wrapper).
; In the captured post-first-byte *IDN? stall family, BO IRQ is accepted by hardware and $7154
; runs, but a stale
; 16-bit $2204 write at $208D-$2094 later erases bit 0 before this test executes. When that
; happens, this branch falls through to $0807 and the P8291A is not serviced.
07e4: fc 22 04        LDD    $2204
07e7: 84 00           ANDA   #$00
07e9: c4 01           ANDB   #$01        ; test bit 0
07eb: 10 83 00 00     CMPD   #$0000
07ef: 10 27 00 14     LBEQ   $0807       ; not set → skip HP-IB service
; Clear IRQ latch and service the P8291A in foreground context
07f3: fc 22 04        LDD    $2204
07f6: 84 ff           ANDA   #$FF
07f8: c4 fe           ANDB   #$FE        ; clear bit 0
07fa: fd 22 04        STD    $2204
; Deferred HP-IB foreground work latched by the real IRQ path.
; Run the active-bus handler once outside interrupt context so P8291A service, mailbox forwarding,
; and formatter/event follow-up happen in the normal foreground scheduler.
07fd: ce 00 00        LDU    #$0000
0800: 34 40           PSHS   U
0802: 17 1f 39        LBSR   $273E       ; → $273E: foreground HP-IB active-bus handler
0805: 32 62           LEAS   $2,S
; Check $2204 bit 2: request dispatch pending
0807: fc 22 04        LDD    $2204
080a: 84 00           ANDA   #$00
080c: c4 04           ANDB   #$04        ; test bit 2
080e: 10 83 00 00     CMPD   #$0000
0812: 10 27 00 14     LBEQ   $082A       ; not set → skip dispatch
; Clear bit 2 and run central dispatcher
0816: fc 22 04        LDD    $2204
0819: 84 ff           ANDA   #$FF
081b: c4 fb           ANDB   #$FB        ; clear bit 2
081d: fd 22 04        STD    $2204
; Main request-dispatch gate.
; $0AD0 and several HP-IB helpers raise $2204 bit 2 after writing $2217, so this block is where
; queued HP-IB/UI requests actually enter the central dispatcher at $0D60.
0820: ce 00 00        LDU    #$0000
0823: 34 40           PSHS   U
0825: 17 05 38        LBSR   $0D60       ; → $0D60: central request dispatcher
0828: 32 62           LEAS   $2,S
; Idle-timeout watchdog ($2204 bit 7 = "idle-timeout active" flag, set by $5B5C).
; While bit 7 is set, increments a 16-bit counter at $A,S each loop iteration.
; On overflow (wrap to 0), resets counter to $0D60 and increments secondary counter at $3,S.
; When secondary counter reaches $12 (18 overflows): calls $5B7D to exit idle-timeout
; (clears bit 7, turns LED back on), reactivating the instrument.
082a: fc 22 04        LDD    $2204
082d: 84 00           ANDA   #$00
082f: c4 80           ANDB   #$80        ; test bit 7 (idle-timeout active?)
0831: 10 83 00 00     CMPD   #$0000
0835: 10 27 00 2f     LBEQ   $0868       ; not in idle-timeout → skip
0839: ec 6a           LDD    $A,S        ; load primary counter
083b: c3 00 01        ADDD   #$0001      ; increment
083e: ed 6a           STD    $A,S
0840: ae 6a           LDX    $A,S
0842: 8c 00 00        CMPX   #$0000      ; overflow?
0845: 10 26 00 0b     LBNE   $0854       ; no → skip
0849: cc 0d 60        LDD    #$0D60      ; reset primary counter to $0D60
084c: ed 6a           STD    $A,S
084e: e6 63           LDB    $3,S        ; secondary counter
0850: cb 01           ADDB   #$01        ; increment
0852: e7 63           STB    $3,S
0854: e6 63           LDB    $3,S
0856: c1 12           CMPB   #$12        ; reached 18?
0858: 10 26 00 0c     LBNE   $0868       ; no → continue
085c: 6f 63           CLR    $3,S        ; reset secondary counter
085e: ce 00 00        LDU    #$0000
0861: 34 40           PSHS   U
0863: 17 53 17        LBSR   $5B7D       ; → $5B7D: exit idle-timeout (clear bit 7, LED on)
0866: 32 62           LEAS   $2,S
; Periodic timer/status check. Gated by $2204 bit 2 (high byte) — a software timer flag.
; Decrements a 16-bit counter at $220B each time; when it reaches zero, reloads $026C (620)
; and calls $2B7A to check system status. The return value selects further action:
;   $0013 → post request $0020     $0019 → post request $001F
;   other → clear $2204 bit 2 high byte (disarm the timer gate)
0868: fc 22 04        LDD    $2204
086b: 84 04           ANDA   #$04             ; test bit 2 of high byte (timer gate)
086d: c4 00           ANDB   #$00
086f: 10 83 00 00     CMPD   #$0000
0873: 10 27 00 63     LBEQ   $08DA            ; not set → skip to key-release section
0877: fc 22 0b        LDD    $220B            ; load countdown timer
087a: 83 00 01        SUBD   #$0001           ; decrement
087d: fd 22 0b        STD    $220B
0880: be 22 0b        LDX    $220B
0883: 8c 00 00        CMPX   #$0000           ; reached zero?
0886: 10 26 00 50     LBNE   $08DA            ; no → continue waiting
088a: cc 02 6c        LDD    #$026C           ; reload: 620 loop iterations
088d: fd 22 0b        STD    $220B
0890: ce 00 00        LDU    #$0000
0893: 34 40           PSHS   U
0895: 17 22 e2        LBSR   $2B7A            ; → status/condition check
0898: 32 62           LEAS   $2,S
089a: 1f 01           TFR    D,X              ; X = result code
089c: 16 00 2f        LBRA   $08CE            ; → dispatch on result code
; Status result handler: $0019 → post request type $1F
089f: ce 00 1f        LDU    #$001F
08a2: 10 8e 00 02     LDY    #$0002
08a6: 34 60           PSHS   U,Y
08a8: 17 02 25        LBSR   $0AD0
08ab: 32 64           LEAS   $4,S
08ad: 16 00 2a        LBRA   $08DA
; Status result handler: $0013 → post request type $20
08b0: ce 00 20        LDU    #$0020
08b3: 10 8e 00 02     LDY    #$0002
08b7: 34 60           PSHS   U,Y
08b9: 17 02 14        LBSR   $0AD0
08bc: 32 64           LEAS   $4,S
08be: 16 00 19        LBRA   $08DA
; Status result: default → disarm timer gate (clear $2204 high-byte bit 2)
08c1: fc 22 04        LDD    $2204
08c4: 84 fb           ANDA   #$FB             ; clear bit 2 of high byte
08c6: c4 ff           ANDB   #$FF
08c8: fd 22 04        STD    $2204
08cb: 16 00 0c        LBRA   $08DA
; Status result dispatch: branch on $2B7A return value in X
08ce: 8c 00 13        CMPX   #$0013           ; result $0013?
08d1: 27 dd           BEQ    $08B0            ; → post request $20
08d3: 8c 00 19        CMPX   #$0019           ; result $0019?
08d6: 27 c7           BEQ    $089F            ; → post request $1F
08d8: 20 e7           BRA    $08C1            ; default → disarm timer
; --- Key-release idle detection ($08DA) ---
; Gated by $2204 high-byte bit 6. When set, monitors $0100 bit 6 (key physically down)
; and manages a release-idle counter at $7,S. After 200 iterations with no key pressed,
; arms $6,S. On the next key-down with $6,S armed, posts request type $2E and resets.
08da: fc 22 04        LDD    $2204
08dd: 84 40           ANDA   #$40             ; test $2204 high-byte bit 6 (key monitor gate)
08df: c4 00           ANDB   #$00
08e1: 10 83 00 00     CMPD   #$0000
08e5: 10 27 00 42     LBEQ   $092B            ; gate not set → skip to loop-back
08e9: e6 65           LDB    $5,S             ; $0100 status latch (saved at $04CF)
08eb: c4 40           ANDB   #$40             ; test bit 6: key physically down?
08ed: 10 27 00 1d     LBEQ   $090E            ; not down → key-released path
; Key-down path: if repeat armed ($6,S != 0), fire request $2E and reset
08f1: e6 66           LDB    $6,S             ; repeat-armed flag
08f3: c1 00           CMPB   #$00
08f5: 10 27 00 10     LBEQ   $0909            ; not armed → just reset counter
08f9: ce 00 2e        LDU    #$002E           ; post request type $2E (key-repeat event)
08fc: 10 8e 00 02     LDY    #$0002
0900: 34 60           PSHS   U,Y
0902: 17 01 cb        LBSR   $0AD0
0905: 32 64           LEAS   $4,S
0907: 6f 66           CLR    $6,S             ; clear armed flag after firing
0909: 6f 67           CLR    $7,S             ; reset idle counter
090b: 16 00 1d        LBRA   $092B
; Key-released path: count idle iterations, arm repeat flag after 200
090e: e6 66           LDB    $6,S             ; already armed?
0910: c1 00           CMPB   #$00
0912: 10 26 00 15     LBNE   $092B            ; yes → nothing to do, loop
0916: e6 67           LDB    $7,S             ; idle counter
0918: cb 01           ADDB   #$01             ; increment
091a: e7 67           STB    $7,S
091c: e6 67           LDB    $7,S
091e: 4f              CLRA
091f: 10 83 00 c8     CMPD   #$00C8           ; reached 200?
0923: 10 23 00 04     LBLS   $092B            ; no → keep counting
0927: c6 01           LDB    #$01             ; yes → arm repeat flag
0929: e7 66           STB    $6,S
092b: 16 fb 9c        LBRA   $04CA       ; loop back to top of main foreground loop
092e: 32 e8 14        LEAS   $14,S       ; (reached only on cold-start exit, not from main loop)
0931: 39              RTS
; ROM data: frame-size table entries (NOT executable code).
; $8932 → $0004 (used by $0000)
; $8934 → $0000 (used by $00D2)
; $8935 → $0002 (used by $00F3, $01AD — note: overlapping byte with $8934)
; $8937 → $0012 (used by $03A0)
0932: 00 04           NEG    <$04
0934: 00 00           NEG    <$00
0936: 02 00           XNC    <$00
0938: 12              NOP
; =====================================================================================
; Early system setup ($0939).
; Frame size: 4 bytes (from ROM $8F76).
; Reads option byte $3FFC bit 0 to conditionally load $4003 into $2223 (paged ROM config).
; Copies data from $4004-$4007 into $2224-$2227. Appears to load configuration from paged ROM
; (A2U13 page 0) into working RAM for the front-panel and HP-IB subsystems.
; =====================================================================================
0939: fc 8f 76        LDD    $8F76
093c: 17 74 11        LBSR   $7D50
093f: f6 3f fc        LDB    $3FFC            ; option byte at $3FFC (page 0 ROM)
0942: c4 01           ANDB   #$01             ; bit 0: paged config present?
0944: 10 27 00 09     LBEQ   $0951            ; no → clear $2223
0948: f6 40 03        LDB    $4003            ; load channel count from page 0
094b: f7 22 23        STB    $2223
094e: 16 00 03        LBRA   $0954
0951: 7f 22 23        CLR    $2223            ; no config → 0 channels
; Copy first two handler pointers from page 0 ($4004-$4007) into $2224-$2227
0954: fc 40 04        LDD    $4004
0957: fd 22 24        STD    $2224
095a: fc 40 06        LDD    $4006
095d: fd 22 26        STD    $2226
; Loop: fill handler pointer table $2224[2..9] from page 0 ROM at $4000+offset
; $2,S = table index (starts at 2), $3,S = ROM offset (starts at 8), limit = 10 entries
0960: c6 02           LDB    #$02
0962: e7 62           STB    $2,S             ; table index = 2
0964: c6 08           LDB    #$08
0966: e7 63           STB    $3,S             ; ROM offset = 8
0968: e6 62           LDB    $2,S
096a: c1 0a           CMPB   #$0A             ; index >= 10?
096c: 10 24 00 37     LBCC   $09A7            ; yes → done
0970: f6 3f fc        LDB    $3FFC
0973: c4 01           ANDB   #$01             ; config present?
0975: 10 27 00 0d     LBEQ   $0986            ; no → use $C239 sentinel
0979: 8e 40 00        LDX    #$4000           ; read pointer from page 0 ROM
097c: e6 63           LDB    $3,S
097e: 3a              ABX                     ; X = $4000 + ROM offset
097f: ae 84           LDX    ,X               ; X = pointer value from ROM
0981: af 64           STX    $4,S
0983: 16 00 05        LBRA   $098B
0986: cc c2 39        LDD    #$C239           ; no config → null sentinel
0989: ed 64           STD    $4,S
; Store pointer into $2224 table at [index * 2]
098b: e6 62           LDB    $2,S
098d: 4f              CLRA
098e: 58              ASLB
098f: 49              ROLA                     ; D = index * 2
0990: 8e 22 24        LDX    #$2224
0993: 30 8b           LEAX   D,X              ; X → $2224 + index*2
0995: ec 64           LDD    $4,S
0997: ed 84           STD    ,X               ; store handler pointer
0999: e6 62           LDB    $2,S
099b: cb 01           ADDB   #$01             ; index++
099d: e7 62           STB    $2,S
099f: e6 63           LDB    $3,S
09a1: cb 02           ADDB   #$02             ; ROM offset += 2
09a3: e7 63           STB    $3,S
09a5: 20 c1           BRA    $0968            ; → loop
09a7: 32 66           LEAS   $6,S
09a9: 39              RTS
; Soft-key page display refresh — $09AA.
; Loads the display descriptor for the currently selected page ($268E) from the table at
; [$2240]. Each entry is a 5-word (10-byte) record: word 0 is a display string pointer
; (pushed to $5989), words 1-4 are callback function pointers stored into $2238-$223E.
09aa: fc 8f 78        LDD    $8F78
09ad: 17 73 a0        LBSR   $7D50
09b0: f6 26 8e        LDB    $268E
09b3: 86 05           LDA    #$05
09b5: 3d              MUL
09b6: 58              ASLB
09b7: 49              ROLA
09b8: be 22 40        LDX    $2240
09bb: 30 8b           LEAX   D,X
09bd: af 62           STX    $2,S
09bf: ee f8 02        LDU    [$02,S]
09c2: 10 8e 00 02     LDY    #$0002
09c6: 34 60           PSHS   U,Y
09c8: 17 4f be        LBSR   $5989
09cb: 32 64           LEAS   $4,S
09cd: c6 01           LDB    #$01
09cf: 1d              SEX
09d0: 58              ASLB
09d1: 49              ROLA
09d2: ae 62           LDX    $2,S
09d4: 30 8b           LEAX   D,X
09d6: ae 84           LDX    ,X
09d8: bf 22 38        STX    $2238
09db: c6 02           LDB    #$02
09dd: 1d              SEX
09de: 58              ASLB
09df: 49              ROLA
09e0: ae 62           LDX    $2,S
09e2: 30 8b           LEAX   D,X
09e4: ae 84           LDX    ,X
09e6: bf 22 3a        STX    $223A
09e9: c6 03           LDB    #$03
09eb: 1d              SEX
09ec: 58              ASLB
09ed: 49              ROLA
09ee: ae 62           LDX    $2,S
09f0: 30 8b           LEAX   D,X
09f2: ae 84           LDX    ,X
09f4: bf 22 3c        STX    $223C
09f7: c6 04           LDB    #$04
09f9: 1d              SEX
09fa: 58              ASLB
09fb: 49              ROLA
09fc: ae 62           LDX    $2,S
09fe: 30 8b           LEAX   D,X
0a00: ae 84           LDX    ,X
0a02: bf 22 3e        STX    $223E
0a05: 32 64           LEAS   $4,S
0a07: 39              RTS
; Install soft-key page descriptor table — $0A08.
; Sets $2240 to the table base pointer (arg), reads the entry count from the byte just
; before the table into $2242, resets the current page index ($268E) to 0, then calls
; $09AA to display page 0.
0a08: fc 8f 7a        LDD    $8F7A
0a0b: 17 73 42        LBSR   $7D50
0a0e: ec e9 00 06     LDD    $0006,S
0a12: fd 22 40        STD    $2240
0a15: ae e9 00 06     LDX    $0006,S
0a19: 30 1f           LEAX   -$1,X
0a1b: e6 84           LDB    ,X
0a1d: f7 22 42        STB    $2242
0a20: 7f 26 8e        CLR    $268E
0a23: ce 00 00        LDU    #$0000
0a26: 34 40           PSHS   U
0a28: 8d 80           BSR    $09AA
0a2a: 32 62           LEAS   $2,S
0a2c: 32 62           LEAS   $2,S
0a2e: 39              RTS
; Soft-key page navigation dispatcher — $0A2F.
; Dispatches request types $13-$18 via a jump table at $0AC1:
; - Calls indirect through function pointers in $2238-$223E (soft-key callbacks)
; - Increments/decrements the page index $268E with wraparound via $2242
; - Refreshes the display via $09AA after page changes
0a2f: fc 8f 7a        LDD    $8F7A
0a32: 17 73 1b        LBSR   $7D50
0a35: be 22 17        LDX    $2217
0a38: 16 00 6f        LBRA   $0AAA
0a3b: be 22 38        LDX    $2238         ; type $13: soft-key 1 callback
0a3e: ad 84           JSR    ,X
0a40: 16 00 8a        LBRA   $0ACD
0a43: be 22 3a        LDX    $223A         ; type $14: soft-key 2 callback
0a46: ad 84           JSR    ,X
0a48: 16 00 82        LBRA   $0ACD
0a4b: be 22 3c        LDX    $223C         ; type $15: soft-key 3 callback
0a4e: ad 84           JSR    ,X
0a50: 16 00 7a        LBRA   $0ACD
0a53: be 22 3e        LDX    $223E         ; type $16: soft-key 4 callback
0a56: ad 84           JSR    ,X
0a58: 16 00 72        LBRA   $0ACD
; Type $17: page forward with wraparound
0a5b: f6 26 8e        LDB    $268E            ; current page index
0a5e: f1 22 42        CMPB   $2242            ; at last page?
0a61: 10 26 00 06     LBNE   $0A6B            ; no → increment
0a65: 7f 26 8e        CLR    $268E            ; wrap to page 0
0a68: 16 00 08        LBRA   $0A73
0a6b: f6 26 8e        LDB    $268E
0a6e: cb 01           ADDB   #$01             ; page++
0a70: f7 26 8e        STB    $268E
0a73: ce 00 00        LDU    #$0000
0a76: 34 40           PSHS   U
0a78: 17 ff 2f        LBSR   $09AA            ; refresh display for new page
0a7b: 32 62           LEAS   $2,S
0a7d: 16 00 4d        LBRA   $0ACD
; Type $18: page backward with wraparound
0a80: f6 26 8e        LDB    $268E            ; current page index
0a83: c1 00           CMPB   #$00             ; at page 0?
0a85: 10 26 00 09     LBNE   $0A92            ; no → decrement
0a89: f6 22 42        LDB    $2242            ; wrap to last page
0a8c: f7 26 8e        STB    $268E
0a8f: 16 00 08        LBRA   $0A9A
0a92: f6 26 8e        LDB    $268E
0a95: c0 01           SUBB   #$01             ; page--
0a97: f7 26 8e        STB    $268E
0a9a: ce 00 00        LDU    #$0000
0a9d: 34 40           PSHS   U
0a9f: 17 ff 08        LBSR   $09AA            ; refresh display for new page
0aa2: 32 62           LEAS   $2,S
0aa4: 16 00 26        LBRA   $0ACD
0aa7: 16 00 23        LBRA   $0ACD            ; default: NOP → return
0aaa: 8c 00 18        CMPX   #$0018           ; type > $18?
0aad: 10 2e 00 1c     LBGT   $0ACD            ; yes → out of range
0ab1: 1f 10           TFR    X,D
0ab3: 83 00 13        SUBD   #$0013           ; D = type - $13 (0-based index)
0ab6: 10 2d 00 13     LBLT   $0ACD            ; type < $13 → out of range
0aba: 8e 8a c1        LDX    #$8AC1           ; jump table base (6 entries)
0abd: 58              ASLB
0abe: 49              ROLA                     ; D *= 2 (word offset)
0abf: 6e 9b           JMP    [D,X]            ; indirect jump to handler
; ROM data: jump table for request types $13-$18 (6 entries, 16-bit CPU addresses).
; $13→$8A3B(sk1) $14→$8A43(sk2) $15→$8A4B(sk3) $16→$8A53(sk4) $17→$8A5B(pg+) $18→$8A80(pg-)
0ac1: 8a 3b           ORA    #$3B
0ac3: 8a 43           ORA    #$43
0ac5: 8a 4b           ORA    #$4B
0ac7: 8a 53           ORA    #$53
0ac9: 8a 5b           ORA    #$5B
0acb: 8a 80           ORA    #$80
0acd: 32 62           LEAS   $2,S
0acf: 39              RTS
; Queue a request type for the main dispatcher by storing it in $2217 and setting $2204 bit 2.
; This is the common helper used by the active HP-IB handler and other foreground code.
0ad0: fc 8f 7a        LDD    $8F7A
0ad3: 17 72 7a        LBSR   $7D50
0ad6: ec e9 00 06     LDD    $0006,S          ; D = request type arg
0ada: fd 22 17        STD    $2217            ; store in request mailbox
0add: fc 22 04        LDD    $2204
0ae0: 8a 00           ORA    #$00
0ae2: ca 04           ORB    #$04             ; set $2204 bit 2 (dispatch pending)
0ae4: fd 22 04        STD    $2204
0ae7: 32 62           LEAS   $2,S
0ae9: 39              RTS
; Install one of up to ten HP-IB foreground handler entry points from the pointer table at $2224.
; If the selected pointer is the default sentinel $C239, this returns without changing $24E6.
0aea: fc 8f 78        LDD    $8F78
0aed: 17 72 60        LBSR   $7D50
0af0: ae e9 00 08     LDX    $0008,S          ; X = handler index arg
0af4: 8c 00 0a        CMPX   #$000A           ; valid range 0-9
0af7: 10 25 00 03     LBCS   $0AFE
0afb: 16 00 4b        LBRA   $0B49            ; out of range → exit
0afe: ec e9 00 08     LDD    $0008,S
0b02: 58              ASLB                     ; D = index * 2 (word offset)
0b03: 49              ROLA
0b04: 8e 22 24        LDX    #$2224           ; $2224 = 10-entry handler pointer table
0b07: 30 8b           LEAX   D,X
0b09: ae 84           LDX    ,X               ; X = handler address from table
0b0b: af 62           STX    $2,S
0b0d: cc c2 39        LDD    #$C239           ; $C239 = null sentinel
0b10: 10 a3 62        CMPD   $2,S
0b13: 10 26 00 03     LBNE   $0B1A            ; non-null → install it
0b17: 16 00 2f        LBRA   $0B49            ; null → exit (no handler for this index)
0b1a: be 22 13        LDX    $2213            ; call current pre-dispatch hook
0b1d: ad 84           JSR    ,X
0b1f: ec 62           LDD    $2,S             ; install new handler as foreground
0b21: fd 24 e6        STD    $24E6
0b24: cc c2 39        LDD    #$C239           ; clear the pre-dispatch hook
0b27: fd 22 13        STD    $2213
0b2a: 5f              CLRB                     ; call $5AE0(0) — reset subsystem state
0b2b: 1d              SEX
0b2c: 1f 03           TFR    D,U
0b2e: 10 8e 00 02     LDY    #$0002
0b32: 34 60           PSHS   U,Y
0b34: 17 4f a9        LBSR   $5AE0
0b37: 32 64           LEAS   $4,S
0b39: 5f              CLRB                     ; call the new handler's entry point
0b3a: 1d              SEX
0b3b: 1f 03           TFR    D,U
0b3d: 10 8e 00 02     LDY    #$0002
0b41: 34 60           PSHS   U,Y
0b43: ae 66           LDX    $6,S             ; X = handler address (from stack frame)
0b45: ad 84           JSR    ,X
0b47: 32 64           LEAS   $4,S
0b49: 32 64           LEAS   $4,S
0b4b: 39              RTS
; Post request type $000B — $0B4C.
; Queues request type $0B through the common dispatcher at $0AD0.
0b4c: fc 8f 7a        LDD    $8F7A
0b4f: 17 71 fe        LBSR   $7D50
0b52: ce 00 0b        LDU    #$000B
0b55: 10 8e 00 02     LDY    #$0002
0b59: 34 60           PSHS   U,Y
0b5b: 17 ff 72        LBSR   $0AD0
0b5e: 32 64           LEAS   $4,S
0b60: 32 62           LEAS   $2,S
0b62: 39              RTS
; Refresh a 2-line display template selected by $2245.
; $2245 chooses one of five descriptor pointers at $4018-$4020. The selected pointer is copied to
; $2,S, paired selector values are written to $2243/$2244, then $58EA copies a fixed line-1
; template ($EABC) and the selected line-2 template into the LCD work buffer.
; The exact user-facing meaning of the five entries is still uncertain.
0b63: fc 8f 78        LDD    $8F78
0b66: 17 71 e7        LBSR   $7D50
0b69: f6 22 45        LDB    $2245
0b6c: 16 00 58        LBRA   $0BC7
0b6f: fc 40 18        LDD    $4018
0b72: ed 62           STD    $2,S
0b74: 7f 22 43        CLR    $2243
0b77: c6 01           LDB    #$01
0b79: f7 22 44        STB    $2244
0b7c: 16 00 66        LBRA   $0BE5
0b7f: fc 40 1a        LDD    $401A
0b82: ed 62           STD    $2,S
0b84: c6 02           LDB    #$02
0b86: f7 22 43        STB    $2243
0b89: c6 03           LDB    #$03
0b8b: f7 22 44        STB    $2244
0b8e: 16 00 54        LBRA   $0BE5
0b91: fc 40 1c        LDD    $401C
0b94: ed 62           STD    $2,S
0b96: c6 04           LDB    #$04
0b98: f7 22 43        STB    $2243
0b9b: c6 05           LDB    #$05
0b9d: f7 22 44        STB    $2244
0ba0: 16 00 42        LBRA   $0BE5
0ba3: fc 40 1e        LDD    $401E
0ba6: ed 62           STD    $2,S
0ba8: c6 06           LDB    #$06
0baa: f7 22 43        STB    $2243
0bad: c6 07           LDB    #$07
0baf: f7 22 44        STB    $2244
0bb2: 16 00 30        LBRA   $0BE5
0bb5: fc 40 20        LDD    $4020
0bb8: ed 62           STD    $2,S
0bba: c6 08           LDB    #$08
0bbc: f7 22 43        STB    $2243
0bbf: c6 09           LDB    #$09
0bc1: f7 22 44        STB    $2244
0bc4: 16 00 1e        LBRA   $0BE5
0bc7: c1 00           CMPB   #$00             ; $2245 range check: 0-4
0bc9: 10 25 00 18     LBCS   $0BE5
0bcd: c1 04           CMPB   #$04
0bcf: 10 22 00 12     LBHI   $0BE5
0bd3: 8e 8b db        LDX    #$8BDB           ; 5-entry jump table by $2245
0bd6: 4f              CLRA
0bd7: 58              ASLB
0bd8: 49              ROLA
0bd9: 6e 9b           JMP    [D,X]
; Jump table (ROM data): 0→$0B6F 1→$0B7F 2→$0B91 3→$0BA3 4→$0BB5
; Each entry loads descriptor from $4018+N*2, sets $2243/$2244 pair.
0bdb: 8b 6f           ADDA   #$6F
0bdd: 8b 7f           ADDA   #$7F
0bdf: 8b 91           ADDA   #$91
0be1: 8b a3           ADDA   #$A3
0be3: 8b b5           ADDA   #$B5
; Common display rendering: copy $EABC (40 chars) to LCD line 1 buffer (offset 0)
0be5: ce ea bc        LDU    #$EABC
0be8: c6 28           LDB    #$28
0bea: 1d              SEX
0beb: 1f 02           TFR    D,Y              ; Y = 40 (char count)
0bed: 5f              CLRB
0bee: 1d              SEX
0bef: 1f 01           TFR    D,X              ; X = 0 (LCD offset)
0bf1: cc 00 06        LDD    #$0006
0bf4: 34 76           PSHS   U,Y,X,D
0bf6: 17 4c f1        LBSR   $58EA            ; → $58EA: block copy to LCD buffer
0bf9: 32 68           LEAS   $8,S
; Copy descriptor source ($2,S) (40 chars) to LCD line 2 buffer (offset $40)
0bfb: ee 62           LDU    $2,S             ; source ptr from jump table handler
0bfd: c6 28           LDB    #$28
0bff: 1d              SEX
0c00: 1f 02           TFR    D,Y              ; Y = 40
0c02: c6 40           LDB    #$40
0c04: 1d              SEX
0c05: 1f 01           TFR    D,X              ; X = $40 (line 2 offset)
0c07: cc 00 06        LDD    #$0006
0c0a: 34 76           PSHS   U,Y,X,D
0c0c: 17 4c db        LBSR   $58EA
0c0f: 32 68           LEAS   $8,S
0c11: 32 64           LEAS   $4,S
0c13: 39              RTS
; Small dispatcher used for a narrow group of request types already queued in $2217.
; This mainly handles a few local UI / stepping requests and falls back to a generic update path.
0c14: fc 8f 7a        LDD    $8F7A
0c17: 17 71 36        LBSR   $7D50
0c1a: be 22 17        LDX    $2217            ; X = request type from mailbox
0c1d: 16 00 bf        LBRA   $0CDF            ; → dispatch table at $0CDF
; Type $10 handler: call $4418 (UI param display setup)
0c20: ce 00 00        LDU    #$0000
0c23: 34 40           PSHS   U
0c25: 17 37 f0        LBSR   $4418
0c28: 32 62           LEAS   $2,S
0c2a: 16 00 f3        LBRA   $0D20            ; → common return
; Type $13 handler: copy $2243→$2219, re-post as type $0A
0c2d: f6 22 43        LDB    $2243
0c30: f7 22 19        STB    $2219
0c33: ce 00 0a        LDU    #$000A
0c36: 10 8e 00 02     LDY    #$0002
0c3a: 34 60           PSHS   U,Y
0c3c: 17 fe 91        LBSR   $0AD0
0c3f: 32 64           LEAS   $4,S
0c41: 16 00 dc        LBRA   $0D20            ; → common return
; Types $01, $14, $16, $3C: generic update (NOP — just return)
0c44: 16 00 d9        LBRA   $0D20
; Type $15 handler: copy $2244→$2219, re-post as type $0A
0c47: f6 22 44        LDB    $2244
0c4a: f7 22 19        STB    $2219
0c4d: ce 00 0a        LDU    #$000A
0c50: 10 8e 00 02     LDY    #$0002
0c54: 34 60           PSHS   U,Y
0c56: 17 fe 77        LBSR   $0AD0
0c59: 32 64           LEAS   $4,S
0c5b: 16 00 c2        LBRA   $0D20
; Type $17 handler: step $2245 forward (wraparound at $2223), refresh display via $0B63
0c5e: f6 22 45        LDB    $2245            ; current channel/display index
0c61: f1 22 23        CMPB   $2223            ; at limit?
0c64: 10 26 00 06     LBNE   $0C6E            ; no → increment
0c68: 7f 22 45        CLR    $2245            ; wrap to 0
0c6b: 16 00 08        LBRA   $0C76
0c6e: f6 22 45        LDB    $2245
0c71: cb 01           ADDB   #$01             ; index++
0c73: f7 22 45        STB    $2245
0c76: ce 00 00        LDU    #$0000
0c79: 34 40           PSHS   U
0c7b: 17 fe e5        LBSR   $0B63            ; refresh display for new index
0c7e: 32 62           LEAS   $2,S
0c80: 16 00 9d        LBRA   $0D20
; Type $18 handler: step $2245 backward (wraparound to $2223), refresh display via $0B63
0c83: f6 22 45        LDB    $2245
0c86: c1 00           CMPB   #$00             ; at 0?
0c88: 10 26 00 09     LBNE   $0C95            ; no → decrement
0c8c: f6 22 23        LDB    $2223            ; wrap to max
0c8f: f7 22 45        STB    $2245
0c92: 16 00 08        LBRA   $0C9D
0c95: f6 22 45        LDB    $2245
0c98: c0 01           SUBB   #$01             ; index--
0c9a: f7 22 45        STB    $2245
0c9d: ce 00 00        LDU    #$0000
0ca0: 34 40           PSHS   U
0ca2: 17 fe be        LBSR   $0B63
0ca5: 32 62           LEAS   $2,S
0ca7: 16 00 76        LBRA   $0D20
; If the temporary callback/override gate is still armed here, mirror that condition into HP-IB
; event/request slot $0F before falling back to the generic local refresh below.
; Default handler: if $2204 bit 3 (status event gate), post event $0F via $1DD3
0caa: fc 22 04        LDD    $2204
0cad: 84 00           ANDA   #$00
0caf: c4 08           ANDB   #$08             ; test bit 3
0cb1: 10 83 00 00     CMPD   #$0000
0cb5: 10 27 00 13     LBEQ   $0CCC            ; not set → skip event post
0cb9: c6 0f           LDB    #$0F             ; event $0F, sub-type $00, mode $04
0cbb: 1d              SEX
0cbc: 1f 03           TFR    D,U
0cbe: 5f              CLRB
0cbf: 1d              SEX
0cc0: 1f 02           TFR    D,Y
0cc2: 8e 00 04        LDX    #$0004
0cc5: 34 70           PSHS   U,Y,X
0cc7: 17 11 09        LBSR   $1DD3
0cca: 32 66           LEAS   $6,S
; Call $43FE($0F, 2) — generic display update for unhandled types
0ccc: c6 0f           LDB    #$0F
0cce: 1d              SEX
0ccf: 1f 03           TFR    D,U
0cd1: 10 8e 00 02     LDY    #$0002
0cd5: 34 60           PSHS   U,Y
0cd7: 17 37 24        LBSR   $43FE
0cda: 32 64           LEAS   $4,S
0cdc: 16 00 41        LBRA   $0D20
; Request type dispatch table:
0cdf: 8c 00 01        CMPX   #$0001      ; type $01: generic update
0ce2: 10 27 ff 5e     LBEQ   $0C44
0ce6: 8c 00 10        CMPX   #$0010      ; type $10: re-run $4418 (UI param display setup)
0ce9: 10 27 ff 33     LBEQ   $0C20
0ced: 8c 00 13        CMPX   #$0013      ; type $13: copy $2243→$2219, re-post as type $0A
0cf0: 10 27 ff 39     LBEQ   $0C2D
0cf4: 8c 00 14        CMPX   #$0014      ; type $14: generic update (same as $01)
0cf7: 10 27 ff 49     LBEQ   $0C44
0cfb: 8c 00 15        CMPX   #$0015      ; type $15: copy $2244→$2219, re-post as type $0A
0cfe: 10 27 ff 45     LBEQ   $0C47
0d02: 8c 00 16        CMPX   #$0016      ; type $16: generic update (same as $01)
0d05: 10 27 ff 3b     LBEQ   $0C44
0d09: 8c 00 17        CMPX   #$0017      ; type $17: step channel index $2245 forward
0d0c: 10 27 ff 4e     LBEQ   $0C5E
0d10: 8c 00 18        CMPX   #$0018      ; type $18: step channel index $2245 backward
0d13: 10 27 ff 6c     LBEQ   $0C83
0d17: 8c 00 3c        CMPX   #$003C      ; type $3C: generic update (fallback override)
0d1a: 10 27 ff 26     LBEQ   $0C44
0d1e: 20 8a           BRA    $0CAA       ; default: post event $0F if gate armed, then $43FE
0d20: 32 62           LEAS   $2,S
0d22: 39              RTS
; =====================================================================================
; Default/idle HP-IB foreground handler ($0D23).
; Frame size: 0 bytes (from ROM $8F7A).
; Clears parser/display state, restores default function pointers:
;   $2213 = $C239 (pre-dispatch hook — a stub RTS in A2U13)
;   $2211 = $C239 (another hook)
;   $220F = $8C14 (some state reference, used by $0EDB comparison)
;   $24E6 = $8D23 (reinstalls THIS function as the foreground HP-IB handler)
; Unlike the active handler at $273E, this does NOT poll the P8291A for bus events.
; =====================================================================================
0d23: fc 8f 7a        LDD    $8F7A
0d26: 17 70 27        LBSR   $7D50
0d29: 5f              CLRB
0d2a: 1d              SEX
0d2b: 1f 03           TFR    D,U
0d2d: 10 8e 00 02     LDY    #$0002
0d31: 34 60           PSHS   U,Y
0d33: 17 4d aa        LBSR   $5AE0
0d36: 32 64           LEAS   $4,S
0d38: 7f 22 45        CLR    $2245
0d3b: ce 00 00        LDU    #$0000
0d3e: 34 40           PSHS   U
0d40: 17 fe 20        LBSR   $0B63
0d43: 32 62           LEAS   $2,S
0d45: cc c2 39        LDD    #$C239
0d48: fd 22 13        STD    $2213
0d4b: cc c2 39        LDD    #$C239
0d4e: fd 22 11        STD    $2211
0d51: cc 8c 14        LDD    #$8C14
0d54: fd 22 0f        STD    $220F
0d57: cc 8d 23        LDD    #$8D23
0d5a: fd 24 e6        STD    $24E6
0d5d: 32 62           LEAS   $2,S
0d5f: 39              RTS
; =====================================================================================
; Main request dispatcher ($0D60).
; Frame size: 0 bytes (from ROM $8F7A).
; Reads request type from $2217 and dispatches through the jump table at $0F13.
; Override mechanism: if $2202 bit 3 is set, calls the callback at [$220D]. If that callback
; returns B != 0, overrides $2217 with $003C (which exceeds the $0F13 table range, causing
; the fallback path at $0F6E to be taken instead of a normal dispatch).
; =====================================================================================
0d60: fc 8f 7a        LDD    $8F7A
0d63: 17 6f ea        LBSR   $7D50
0d66: fc 22 02        LDD    $2202            ; check override gate: $2202 bit 3
0d69: 84 00           ANDA   #$00
0d6b: c4 08           ANDB   #$08
0d6d: 10 83 00 00     CMPD   #$0000
0d71: 10 27 00 11     LBEQ   $0D86            ; not set → normal dispatch
0d75: be 22 0d        LDX    $220D            ; call override callback at [$220D]
0d78: ad 84           JSR    ,X
0d7a: c1 00           CMPB   #$00
0d7c: 10 27 00 06     LBEQ   $0D86            ; callback returned 0 → proceed normally
0d80: cc 00 3c        LDD    #$003C           ; callback returned non-0 → force type $3C
0d83: fd 22 17        STD    $2217            ; ($3C > $22, so $0F13 table falls through)
0d86: be 22 17        LDX    $2217            ; X = request type
0d89: 16 01 87        LBRA   $0F13            ; → jump table dispatcher
; One request path that explicitly tears HP-IB back down to the idle/default handler after running
; the current pre-dispatch hook in $2213 and clearing the broader front-panel/runtime state.
0d8c: be 22 13        LDX    $2213
0d8f: ad 84           JSR    ,X
0d91: ce 00 00        LDU    #$0000
0d94: 34 40           PSHS   U
0d96: 17 f3 5a        LBSR   $00F3
0d99: 32 62           LEAS   $2,S
0d9b: 5f              CLRB
0d9c: 4f              CLRA
0d9d: fd 23 c1        STD    $23C1
0da0: ce 00 00        LDU    #$0000
0da3: 34 40           PSHS   U
0da5: 17 ff 7b        LBSR   $0D23
0da8: 32 62           LEAS   $2,S
0daa: 16 01 c6        LBRA   $0F73
; Similar teardown path, but with the extra $00D2 reset and a $0BB8 delay before restoring the
; idle HP-IB handler. The exact user-visible reason for this slower exit is still uncertain.
0dad: be 22 13        LDX    $2213
0db0: ad 84           JSR    ,X
0db2: ce 00 00        LDU    #$0000
0db5: 34 40           PSHS   U
0db7: 17 f3 39        LBSR   $00F3
0dba: 32 62           LEAS   $2,S
0dbc: 5f              CLRB
0dbd: 4f              CLRA
0dbe: fd 23 c1        STD    $23C1
0dc1: ce 00 00        LDU    #$0000
0dc4: 34 40           PSHS   U
0dc6: 17 f3 09        LBSR   $00D2
0dc9: 32 62           LEAS   $2,S
0dcb: ce 0b b8        LDU    #$0BB8
0dce: 10 8e 00 02     LDY    #$0002
0dd2: 34 60           PSHS   U,Y
0dd4: 17 48 99        LBSR   $5670
0dd7: 32 64           LEAS   $4,S
0dd9: ce 00 00        LDU    #$0000
0ddc: 34 40           PSHS   U
0dde: 17 ff 42        LBSR   $0D23
0de1: 32 62           LEAS   $2,S
0de3: 16 01 8d        LBRA   $0F73
; Request path that asks the HP-IB helper layer whether the current command/handshake state has
; gone idle yet. $1E22 also clears the deferred-callback gate on success.
0de6: ce 00 00        LDU    #$0000
0de9: 34 40           PSHS   U
0deb: 17 10 34        LBSR   $1E22
0dee: 32 62           LEAS   $2,S
0df0: 16 01 7b        LBRA   $0F6E
; Request type 17 entry: calls $5E7F (display/state sync helper).
0df3: ce 00 00        LDU    #$0000
0df6: 34 40           PSHS   U
0df8: 17 50 84        LBSR   $5E7F
0dfb: 32 62           LEAS   $2,S
0dfd: 16 01 73        LBRA   $0F73
; Request type 3 entry: installs $0D23 (idle handler) as foreground handler at $24E6,
; runs the current pre-dispatch hook [$2213], resets via $5AE0, then calls [$4022] (A2U13).
0e00: cc 8d 23        LDD    #$8D23
0e03: fd 24 e6        STD    $24E6
0e06: be 22 13        LDX    $2213
0e09: ad 84           JSR    ,X
0e0b: 5f              CLRB
0e0c: 1d              SEX
0e0d: 1f 03           TFR    D,U
0e0f: 10 8e 00 02     LDY    #$0002
0e13: 34 60           PSHS   U,Y
0e15: 17 4c c8        LBSR   $5AE0
0e18: 32 64           LEAS   $4,S
0e1a: be 40 22        LDX    $4022
0e1d: ad 84           JSR    ,X
0e1f: 16 01 51        LBRA   $0F73
; Another explicit return-to-idle path after first calling the current request-specific hook in
; $2213. This is distinct from the broader reset at $0D8C only in what it does beforehand.
0e22: be 22 13        LDX    $2213
0e25: ad 84           JSR    ,X
0e27: ce 00 00        LDU    #$0000
0e2a: 34 40           PSHS   U
0e2c: 17 fe f4        LBSR   $0D23
0e2f: 32 62           LEAS   $2,S
0e31: 16 01 3f        LBRA   $0F73
; Request type 8 entry: resets all four output ports to idle via $3646.
0e34: ce 00 00        LDU    #$0000
0e37: 34 40           PSHS   U
0e39: 17 28 0a        LBSR   $3646
0e3c: 32 62           LEAS   $2,S
0e3e: 16 01 32        LBRA   $0F73
; Clear the serial-poll/status-byte shadow state through the HP-IB helper at $1E0F.
0e41: ce 00 00        LDU    #$0000
0e44: 34 40           PSHS   U
0e46: 17 0f c6        LBSR   $1E0F
0e49: 32 62           LEAS   $2,S
0e4b: 16 01 25        LBRA   $0F73
; Request type 10 entry: dispatches $2219 (sub-type) through the event callback at $0AEA.
0e4e: f6 22 19        LDB    $2219
0e51: 4f              CLRA
0e52: 1f 03           TFR    D,U
0e54: 10 8e 00 02     LDY    #$0002
0e58: 34 60           PSHS   U,Y
0e5a: 17 fc 8d        LBSR   $0AEA
0e5d: 32 64           LEAS   $4,S
0e5f: 16 01 11        LBRA   $0F73
; Variant that runs the current request hook and then forces HP-IB back to the idle/default state.
0e62: be 22 13        LDX    $2213
0e65: ad 84           JSR    ,X
0e67: ce 00 00        LDU    #$0000
0e6a: 34 40           PSHS   U
0e6c: 17 fe b4        LBSR   $0D23
0e6f: 32 62           LEAS   $2,S
0e71: 16 00 ff        LBRA   $0F73
; Request type 0x0D entry: commit any descriptor staged by $1FFE into the live HP-IB transmit
; engine, or synthesize the default "? No Data ?" reply if nothing is ready yet.
0e74: ce 00 00        LDU    #$0000
0e77: 34 40           PSHS   U
0e79: 17 11 d6        LBSR   $2052
0e7c: 32 62           LEAS   $2,S
0e7e: 16 00 f2        LBRA   $0F73
; Request type 14 entry: calls $22E4 (HP-IB command execution helper).
0e81: ce 00 00        LDU    #$0000
0e84: 34 40           PSHS   U
0e86: 17 14 5b        LBSR   $22E4
0e89: 32 62           LEAS   $2,S
0e8b: 16 00 e5        LBRA   $0F73
; Enter the front-panel HP-IB address edit flow. $21A4 installs $20D4 as the temporary callback
; that validates/commits the entered address before normal dispatch continues.
0e8e: ce 00 00        LDU    #$0000
0e91: 34 40           PSHS   U
0e93: 17 13 0e        LBSR   $21A4
0e96: 32 62           LEAS   $2,S
0e98: 16 00 d8        LBRA   $0F73
; Request type 34 entry: calls $7331 with arg $0022 (numeric port/channel selector).
0e9b: ce 00 22        LDU    #$0022
0e9e: 10 8e 00 02     LDY    #$0002
0ea2: 34 60           PSHS   U,Y
0ea4: 17 64 8a        LBSR   $7331
0ea7: 32 64           LEAS   $4,S
0ea9: 16 00 c7        LBRA   $0F73
; Request type 15 entry: calls $75A0 with arg $000F (port enable/direction setup).
0eac: ce 00 0f        LDU    #$000F
0eaf: 10 8e 00 02     LDY    #$0002
0eb3: 34 60           PSHS   U,Y
0eb5: 17 66 e8        LBSR   $75A0
0eb8: 32 64           LEAS   $4,S
0eba: 16 00 b6        LBRA   $0F73
; Request type 18 entry: calls $75A0 with arg $0012 (port enable/direction — variant).
0ebd: ce 00 12        LDU    #$0012
0ec0: 10 8e 00 02     LDY    #$0002
0ec4: 34 60           PSHS   U,Y
0ec6: 17 66 d7        LBSR   $75A0
0ec9: 32 64           LEAS   $4,S
0ecb: 16 00 a5        LBRA   $0F73
; Request type 12 entry: calls $7C39 (I/O port configuration UI setup).
0ece: ce 00 00        LDU    #$0000
0ed1: 34 40           PSHS   U
0ed3: 17 6d 63        LBSR   $7C39
0ed6: 32 62           LEAS   $2,S
0ed8: 16 00 98        LBRA   $0F73
; Request type 5 entry: if $220F != $8C14 ($0C14 handler), runs $43FE with type $10.
; If $220F == $8C14, resets via $5AE0 and calls [$4024] (A2U13 paged callback).
0edb: cc 8c 14        LDD    #$8C14
0ede: 10 b3 22 0f     CMPD   $220F
0ee2: 10 27 00 13     LBEQ   $0EF9
0ee6: c6 10           LDB    #$10
0ee8: 1d              SEX
0ee9: 1f 03           TFR    D,U
0eeb: 10 8e 00 02     LDY    #$0002
0eef: 34 60           PSHS   U,Y
0ef1: 17 35 0a        LBSR   $43FE
0ef4: 32 64           LEAS   $4,S
0ef6: 16 00 7a        LBRA   $0F73
0ef9: 5f              CLRB
0efa: 1d              SEX
0efb: 1f 03           TFR    D,U
0efd: 10 8e 00 02     LDY    #$0002
0f01: 34 60           PSHS   U,Y
0f03: 17 4b da        LBSR   $5AE0
0f06: 32 64           LEAS   $4,S
0f08: be 40 24        LDX    $4024
0f0b: ad 84           JSR    ,X
0f0d: 16 00 63        LBRA   $0F73
0f10: 16 00 5b        LBRA   $0F6E
; =====================================================================================
; Jump-table dispatcher for request types 1..$22 ($0F13).
; X = request type on entry. If X < 1 or X > $22, falls through to $0F6E.
; The bytes at $0F2A-$0F6D are a 34-entry table of 16-bit CPU addresses (NOT instructions).
; Decoded table (type → file offset → purpose where known):
;   1→$0DE6  check idle     7→$0D8C  teardown     13→$0E74  buffer refill
;   2→$0E8E  addr edit      8→$0E34               14→$0E81
;   3→$0E00                 9→$0E41  clear SPoll   15→$0EAC
;   4→$0E22  hook+idle     10→$0E4E               16→$0F6E  (fallback)
;   5→$0EDB                11→$0E62  hook+idle    17→$0DF3
;   6→$0DAD  slow teardown 12→$0ECE               18→$0EBD
;   Types 19-33 → $0F6E (fallback/no-op); type 34 → $0E9B.
; Fallback at $0F6E: calls [$220F] then returns.
; Common return at $0F73: LEAS $2,S; RTS (shared by most handlers above).
; =====================================================================================
0f13: 8c 00 22        CMPX   #$0022           ; max valid type = $22 (34 decimal)
0f16: 10 2e 00 54     LBGT   $0F6E            ; out of range → fallback
0f1a: 1f 10           TFR    X,D
0f1c: 83 00 01        SUBD   #$0001           ; D = type - 1 (0-based index)
0f1f: 10 2d 00 4b     LBLT   $0F6E            ; type 0 → fallback
0f23: 8e 8f 2a        LDX    #$8F2A           ; base of 34-entry pointer table
0f26: 58              ASLB                     ; D *= 2 (word offset)
0f27: 49              ROLA
0f28: 6e 9b           JMP    [D,X]            ; indirect jump to handler
0f2a: 8d e6           BSR    $0F12
0f2c: 8e 8e 8e        LDX    #$8E8E
0f2f: 00 8e           NEG    <$8E
0f31: 22 8e           BHI    $0EC1
0f33: db 8d           ADDB   <$8D
0f35: ad 8d 8c 8e     JSR    $9BC7,PCR
0f39: 34 8e           PSHS   PC,DP,D
0f3b: 41              NEGA
0f3c: 8e 4e 8e        LDX    #$4E8E
0f3f: 62 8e           XNC    W,X
0f41: ce 8e 74        LDU    #$8E74
0f44: 8e 81 8e        LDX    #$818E
0f47: ac 8f           CMPX   ,W
0f49: 6e 8d f3 8e     JMP    $02DB,PCR
0f4d: bd 8f 6e        JSR    $8F6E
0f50: 8f 6e 8f        XSTX   #$6E8F
0f53: 6e 8f           JMP    ,W
0f55: 6e 8f           JMP    ,W
0f57: 6e 8f           JMP    ,W
0f59: 6e 8f           JMP    ,W
0f5b: 6e 8f           JMP    ,W
0f5d: 6e 8f           JMP    ,W
0f5f: 6e 8f           JMP    ,W
0f61: 6e 8f           JMP    ,W
0f63: 6e 8f           JMP    ,W
0f65: 6e 8f           JMP    ,W
0f67: 6e 8f           JMP    ,W
0f69: 6e 8f           JMP    ,W
0f6b: 6e 8e           JMP    W,X
0f6d: 9b be           ADDA   <$BE
; Fallback ($0F6E): call indirect through [$220F], then return.
; Disassembler is misaligned here — actual code: LDX $220F / JSR ,X / LEAS $2,S / RTS.
0f6f: 22 0f           BHI    $0F80
0f71: ad 84           JSR    ,X
; Common return point ($0F73): all handlers above LBRA here to deallocate and return.
0f73: 32 62           LEAS   $2,S
0f75: 39              RTS
; ROM data used immediately above:
; - $0F76/$0F78/$0F7A are small frame-size words referenced by the stack allocator helper
; - $0F7C onward is an embedded banner string:
;   "HP-IB DRIVER VER 1.4 MWM 10/19/83"
0f76: 00 04           NEG    <$04
0f78: 00 02           NEG    <$02
0f7a: 00 00           NEG    <$00
0f7c: 20 48           BRA    $0FC6
0f7e: 50              NEGB
0f7f: 2d 49           BLT    $0FCA
0f81: 42              XNCA
0f82: 20 44           BRA    $0FC8
0f84: 52              XNCB
0f85: 49              ROLA
0f86: 56              RORB
0f87: 45              LSRA
0f88: 52              XNCB
0f89: 20 56           BRA    $0FE1
0f8b: 45              LSRA
0f8c: 52              XNCB
0f8d: 20 31           BRA    $0FC0
0f8f: 2e 34           BGT    $0FC5
0f91: 20 4d           BRA    $0FE0
0f93: 57              ASRB
0f94: 4d              TSTA
0f95: 20 31           BRA    $0FC8
0f97: 30 2f           LEAX   $F,Y
0f99: 31 39           LEAY   -$7,Y
0f9b: 2f 38           BLE    $0FD5
0f9d: 33 20           LEAU   $0,Y
; P8291A initialization/configuration from a descriptor block pointed to by U.
; Descriptor layout used by this ROM:
; - byte 0: control. bit 0 enters the full register-programming path; bit 7 additionally emits a
;   trailing AUX $00 after that setup. If neither bit is set, only AUX $00 is issued.
; - byte 1: mode/config byte. Bits 5:4 select the Address Mode path, the low nibble is treated as
;   a 1..8 internal-counter preset (default 8), and bits 7/6 feed Auxiliary Register B setup.
; - bytes 2-3: copied to $2248/$2249 as the event/SRQ-trigger mask pair (bit 6 forced clear).
; - byte 4: primary HP-IB address used when the normal addressed-mode path is selected.
; Verified effects:
; - Clears the driver's local shadow state at $2246 and up
; - Programs P8291A address-mode / Address 0/1 / internal-counter / auxiliary registers
; - Enables interrupts with IE1=$AB and IE2=$0F
; - Clears talk/listen-related front-panel shadow bits via $9A5B/$9A66/$9A62
; - Initializes HP-IB transmit state to $2269=$80 (message boundary / refill-needed state)
0f9f: 34 3f           PSHS   Y,X,DP,D,CC
0fa1: a6 c4           LDA    ,U          ; descriptor byte 0: mode flags
0fa3: c6 01           LDB    #$01
0fa5: 84 81           ANDA   #$81        ; check bits 7 and 0
0fa7: 10 27 00 8f     LBEQ   $103A       ; neither set → skip most init, just write $0405
; Full initialization path
0fab: 86 02           LDA    #$02
0fad: b7 04 05        STA    $0405       ; AUX command $02: chip reset
0fb0: c6 2e           LDB    #$2E        ; 46 bytes
0fb2: 4f              CLRA
0fb3: 8e 22 46        LDX    #$2246      ; start of driver shadow state
0fb6: a7 80           STA    ,X+         ; }
0fb8: 5a              DECB               ; } zero $2246..$2273
0fb9: 26 fb           BNE    $0FB6       ; }
; Configure addressing mode from descriptor byte 1 bits 5:4
0fbb: e6 41           LDB    $1,U        ; descriptor byte 1
0fbd: c4 30           ANDB   #$30        ; isolate bits 5:4 (address mode)
0fbf: 27 1b           BEQ    $0FDC       ; %00 → normal addressed mode
0fc1: c1 30           CMPB   #$30
0fc3: 27 17           BEQ    $0FDC       ; %11 → also normal addressed mode
; Listen-only or talk-only mode (%01 or %10)
0fc5: 86 40           LDA    #$40        ; base: listen-only ($40)
0fc7: c5 10           BITB   #$10        ; bit 4 set → talk-only
0fc9: 27 02           BEQ    $0FCD
0fcb: 88 c0           EORA   #$C0        ; flip to talk-only ($80)
0fcd: b7 04 04        STA    $0404       ; write Address Mode register ($40=lon, $80=ton)
0fd0: 86 60           LDA    #$60        ; first Address 0/1 programming byte for lon/ton path
0fd2: b7 04 06        STA    $0406       ; write Address 0/1 register
0fd5: 8a 80           ORA    #$80        ; second Address 0/1 programming byte for lon/ton path
0fd7: b7 04 06        STA    $0406
0fda: 20 15           BRA    $0FF1       ; → internal-counter / auxiliary-register setup
; Normal addressed mode: program address from descriptor
0fdc: 4c              INCA               ; A was 0 from clear loop; now A=1 → Address Mode 1
0fdd: b7 04 04        STA    $0404       ; write Address Mode register (Mode 1)
0fe0: a6 44           LDA    $4,U        ; descriptor byte 4: HP-IB address
0fe2: 84 1f           ANDA   #$1F        ; mask to 5-bit address (0-30)
0fe4: 81 1f           CMPA   #$1F        ; address 31 is reserved
0fe6: 26 01           BNE    $0FE9
0fe8: 4a              DECA               ; clamp 31 → 30
0fe9: b7 04 06        STA    $0406       ; write primary address to Address 0 register
0fec: 86 e0           LDA    #$E0        ; disable the secondary address entry in Address 1
0fee: b7 04 06        STA    $0406       ; write Address 0/1 register again
; Internal-counter / auxiliary-register setup
0ff1: a6 41           LDA    $1,U        ; descriptor byte 1
0ff3: 84 0f           ANDA   #$0F        ; low nibble = internal-counter preset candidate
0ff5: 27 04           BEQ    $0FFB       ; zero → use default
0ff7: 81 09           CMPA   #$09        ; must be < 9
0ff9: 25 02           BCS    $0FFD       ; valid → use it
0ffb: 86 08           LDA    #$08        ; default internal-counter preset = 8
0ffd: 8a 20           ORA    #$20        ; AUX $20+N: preset internal counter with N
0fff: b7 04 05        STA    $0405       ; write to AUX register
1002: 86 80           LDA    #$80
1004: b7 04 05        STA    $0405       ; AUX $80: write 0 to Auxiliary Register A
; Program Auxiliary Register B from descriptor byte 1 bits 7/6
1007: 86 a3           LDA    #$A3        ; base Aux-B value: CPT enabled + EOI in SPAS enabled
1009: e6 41           LDB    $1,U        ; descriptor byte 1 again
100b: 2a 02           BPL    $100F
100d: 8a 04           ORA    #$04        ; set Aux-B bit 2 if descriptor bit 7 is set
100f: c5 40           BITB   #$40        ; byte 1 bit 6
1011: 26 02           BNE    $1015       ; set → leave Aux-B bit 3 clear
1013: 8a 08           ORA    #$08        ; set Aux-B bit 3 (active-low INT) if bit 6 clear
1015: b7 04 05        STA    $0405       ; write Auxiliary Register B
1018: 4f              CLRA
1019: b7 04 03        STA    $0403       ; clear Serial Poll Mode register
101c: b7 04 07        STA    $0407       ; clear EOS register
101f: 86 70           LDA    #$70
1021: b7 04 05        STA    $0405       ; AUX $70: disable parallel poll
1024: cc ab 0f        LDD    #$AB0F      ; A=$AB (IMR1 final), B=$0F (IMR2: ADSC+REMC+LLOC+SPC)
1027: fd 04 01        STD    $0401       ; write IMR1→$0401, IMR2→$0402
; Load event enable mask from descriptor bytes 2-3
102a: ec 42           LDD    $2,U        ; descriptor bytes 2-3
102c: 84 bf           ANDA   #$BF        ; clear bit 6 in each (bit 6 reserved for poll-in-progress)
102e: c4 bf           ANDB   #$BF
1030: fd 22 48        STD    $2248       ; store as event enable mask pair ($2248/$2249)
; Conditional AUX write based on descriptor byte 0 bit 7
1033: c6 05           LDB    #$05        ; descriptor is 5 bytes long
1035: a6 c4           LDA    ,U          ; re-read descriptor byte 0
1037: 2a 04           BPL    $103D       ; bit 7 clear → skip final AUX write
1039: 4f              CLRA              ; A=0 (falls through from LBEQ $103A entry)
103a: b7 04 05        STA    $0405       ; AUX $00: Immediate Execute pon
; Initialize driver state
103d: 33 c5           LEAU   B,U         ; advance U past descriptor (U += 5)
103f: 86 01           LDA    #$01
1041: b7 22 4c        STA    $224C       ; set parser mode = 1 (initial/ready)
1044: bd 9a 5b        JSR    $9A5B       ; → $1A5B: update LED/status for remote state
1047: bd 9a 6a        JSR    $9A6A       ; → $1A6A: update serial-poll LED
104a: bd 9a 66        JSR    $9A66       ; → $1A66: set talk LED off
104d: bd 9a 62        JSR    $9A62       ; → $1A62: set listen LED off
1050: 86 80           LDA    #$80
1052: b7 22 69        STA    $2269       ; output state = $80 (message boundary / refill-needed)
1055: 35 3f           PULS   CC,D,DP,X,Y
1057: 39              RTS
; Write-only helper for the SRQ-trigger mask at $2249. Preserves bit 6 (poll-in-progress) clear.
1058: 34 03           PSHS   A,CC
105a: 84 bf           ANDA   #$BF        ; force bit 6 clear before storing
105c: b7 22 49        STA    $2249
105f: 35 03           PULS   CC,A
1061: 39              RTS
; Read accessor for $2249 (SRQ-trigger mask).
1062: 34 01           PSHS   CC
1064: b6 22 49        LDA    $2249
1067: 35 01           PULS   CC
1069: 39              RTS
; Read accessor for $224A (primary serial-poll status byte shadow).
106a: 34 01           PSHS   CC
106c: b6 22 4a        LDA    $224A
106f: 35 01           PULS   CC
1071: 39              RTS
; =====================================================================================
; Full serial-poll status reset — $1072.
; Clears all three local shadow tiers ($224A primary, $224B pending, $224E/$224F deferred,
; $226A/$226B accumulated/deferred-flag), issues AUX $01, then writes $00 to $0403.
; Datasheet note: AUX $01 is "clear local ist" (parallel-poll flag); the firmware uses it here as
; part of its serial-poll cleanup sequence. Finishes with LED update via $9A6A.
; =====================================================================================
1072: 34 3f           PSHS   Y,X,DP,D,CC
1074: 4f              CLRA
1075: b7 22 4a        STA    $224A       ; clear primary status
1078: b7 22 4b        STA    $224B       ; clear pending status
107b: b7 22 4e        STA    $224E       ; clear deferred-high
107e: b7 22 4f        STA    $224F       ; clear deferred-low
1081: b7 22 6a        STA    $226A       ; clear accumulated mask
1084: b7 22 6b        STA    $226B       ; clear deferred SPoll flag
1087: c6 01           LDB    #$01
1089: f7 04 05        STB    $0405       ; AUX $01 (datasheet: clear local "ist")
108c: b7 04 03        STA    $0403       ; write $00 to Serial Poll Mode register
108f: bd 9a 6a        JSR    $9A6A       ; → $1A6A: update serial-poll LED
1092: 35 3f           PULS   CC,D,DP,X,Y
1094: 39              RTS
; =====================================================================================
; Software-shadow bit-4 helper — $1095 / $10BD.
; Two entry points:
;   $1095: primary entry — checks software shadow byte $2247. This byte begins as the ISR2
;          snapshot from $10D3, but this routine later clears bit 4 in the shadow, so bit 4 is
;          not a pristine raw ISR2 copy after the first pass.
;          If bit 5 is set, skips action.
;          If bit 5 clear but bit 4 set: issues AUX $0D then AUX $05, clears bit 4 in $2247,
;          and calls $9A5B. Datasheet names AUX $0D/$05 "set rtl" / "clear rtl".
;   $10BD: alternate entry — skips the bit 5/4 test, just reloads $2247 for the tail test.
; Returns with Z flag reflecting $2247 bit 4 state (Z=1 → shadow bit 4 clear).
; The raw ISR2 bits are documented as REM/LLO status, but this code clearly repurposes the saved
; bit-4 shadow as software state after the first pass.
; =====================================================================================
1095: 34 03           PSHS   A,CC
1097: b6 22 47        LDA    $2247       ; ISR2 shadow
109a: 85 20           BITA   #$20        ; shadow bit 5 set?
109c: 26 24           BNE    $10C2       ; set → nothing to release
109e: 85 10           BITA   #$10        ; shadow bit 4 set?
10a0: 27 20           BEQ    $10C2       ; clear → nothing pending
; Shadow bit 4 set: toggle AUX $0D/$05, then clear the software shadow
10a2: 34 3c           PSHS   Y,X,DP,B
10a4: 86 0d           LDA    #$0D
10a6: b7 04 05        STA    $0405       ; AUX $0D: set rtl
10a9: 86 05           LDA    #$05
10ab: b7 04 05        STA    $0405       ; AUX $05: clear rtl
10ae: b6 22 47        LDA    $2247
10b1: 84 ef           ANDA   #$EF        ; clear bit 4 (handled)
10b3: b7 22 47        STA    $2247
10b6: bd 9a 5b        JSR    $9A5B       ; → $1A5B: update remote/LLO LED state
10b9: 35 3c           PULS   B,DP,X,Y
10bb: 20 02           BRA    $10BF
; Alternate entry: just check current $2247 state
10bd: 34 03           PSHS   A,CC
10bf: b6 22 47        LDA    $2247
10c2: 35 01           PULS   CC          ; restore CC (preserves A for bit test below)
10c4: 85 10           BITA   #$10        ; set Z based on bit 4
10c6: 35 02           PULS   A
10c8: 39              RTS
; Emit P8291A auxiliary command $04 (Trigger).
10c9: 34 03           PSHS   A,CC
10cb: 86 04           LDA    #$04
10cd: b7 04 05        STA    $0405       ; AUX $04 → P8291A
10d0: 35 03           PULS   CC,A
10d2: 39              RTS
; Foreground poll/service routine for the Intel P8291A HP-IB controller.
; Return convention:
; - If no interrupt is pending (ADR0 bit 7 clear), returns with Z set (ORCC #$04).
; - If any event was processed, returns with Z clear (ANDCC #$FB).
;
; Verified behavior:
; - Reads ADR0 at $0406 first; bit 7 mirrors the INT pin. Exits immediately if clear.
; - Reads ISR1/ISR2 together via LDD $0401, saving ISR1→$2246, ISR2→$2247.
;   NOTE: on the MC6809, LDD reads the high byte (ISR1 at $0401) before the low byte
;   (ISR2 at $0402). Both reads clear their respective latched bits. The P8291A datasheet
;   recommends ISR2-first, ISR1-second.
;   This intermediate image intentionally leaves that original ISR1-first ordering unchanged.
;   Successful *IDN? traces exist both with and without the first ADSC path at $10E9.
; - Services events from the saved copy in this order:
;   ISR2 bit 0 → $1170  ADSC  (address status change)
;   ISR2 bit 1 → $118F  REMC  (remote/local change)
;   ISR2 bit 3 → $12A5  SPC   (serial poll complete)
;   ISR1 bit 0 → $130D  BI    (byte in — reads data from $0400)
;   ISR1 bit 1 → $16DA  BO    (byte out — writes data to $0400)
;   ISR1 bit 3 → inline  DEC   (device clear: resets parser state, sets $2269=$80,
;                                calls $1C7E to post request type $0007)
;   ISR1 bit 5 → $1C83  GET   (group execute trigger: posts request type $0024)
;   ISR1 bit 7 → $11B4  CPT   (command pass-through)
;   NOT checked: ISR1 bit 2 (ERR — bus error, silently cleared), bit 4 (END), bit 6 (APT).
; - If $226B is nonzero after all events: issues AUX $09, then writes the deferred serial-poll
;   byte from $224B to $0403. If the write-back verify fails (CMPA $0403), sets $226B=1 and
;   AUX $01 for retry. If successful, clears $226B and calls $1A4F.
; - Trace fact: stalled *IDN? runs can later reach $1719 (STA $0400) after this routine returns,
;   so the failure is not confined to the initial address-recognition step.
10d3: 34 3f           PSHS   Y,X,DP,D,CC
10d5: b6 04 06        LDA    $0406       ; read ADR0 — bit 7 mirrors INT pin
10d8: 2b 05           BMI    $10DF       ; INT asserted (bit 7 set) → process events
10da: 35 3f           PULS   CC,D,DP,X,Y ; no events pending
10dc: 1a 04           ORCC   #$04        ; set Z (caller convention: Z=1 means "nothing happened")
10de: 39              RTS
10df: fc 04 01        LDD    $0401       ; original order: read ISR1→A ($0401), then ISR2→B ($0402); CLEARS BOTH
10e2: fd 22 46        STD    $2246       ; save ISR1→$2246, ISR2→$2247
10e5: c5 01           BITB   #$01        ; ISR2 bit 0: ADSC?
10e7: 27 06           BEQ    $10EF
10e9: bd 91 70        JSR    $9170       ; → $1170: address status change handler
10ec: fc 22 46        LDD    $2246       ; reload saved ISR pair
10ef: c5 02           BITB   #$02        ; ISR2 bit 1: REMC?
10f1: 27 06           BEQ    $10F9
10f3: bd 91 8f        JSR    $918F       ; → $118F: remote/local change handler
10f6: fc 22 46        LDD    $2246       ; reload
10f9: c5 08           BITB   #$08        ; ISR2 bit 3: SPC?
10fb: 27 06           BEQ    $1103
10fd: bd 92 a5        JSR    $92A5       ; → $12A5: serial poll complete handler
1100: b6 22 46        LDA    $2246       ; reload ISR1 only (ISR2 processing done)
1103: 85 01           BITA   #$01        ; ISR1 bit 0: BI?
1105: 27 06           BEQ    $110D
1107: bd 93 0d        JSR    $930D       ; → $130D: byte-in handler
110a: b6 22 46        LDA    $2246       ; reload ISR1
110d: 85 02           BITA   #$02        ; ISR1 bit 1: BO?
110f: 27 06           BEQ    $1117
1111: bd 96 da        JSR    $96DA       ; → $16DA: byte-out handler
1114: b6 22 46        LDA    $2246       ; reload ISR1
1117: 85 08           BITA   #$08        ; ISR1 bit 3: DEC (device clear)?
1119: 27 1a           BEQ    $1135
; DEC inline handler: reset parser state, set output to message-boundary, post request $0007
111b: 4f              CLRA
111c: b7 22 50        STA    $2250       ; clear parser depth
111f: b7 22 53        STA    $2253       ; clear mnemonic parse state
1122: 86 01           LDA    #$01
1124: b7 22 4c        STA    $224C       ; set parser mode = 1 (initial)
1127: 7f 22 64        CLR    $2264       ; clear transmit busy flag
112a: 86 80           LDA    #$80
112c: b7 22 69        STA    $2269       ; set output state = $80 (message boundary)
112f: bd 9c 7e        JSR    $9C7E       ; → $1C7E: post request type $0007 (device clear)
1132: b6 22 46        LDA    $2246       ; reload ISR1
1135: 85 20           BITA   #$20        ; ISR1 bit 5: GET?
1137: 27 06           BEQ    $113F
1139: bd 9c 83        JSR    $9C83       ; → $1C83: post request type $0024 (GET)
113c: b6 22 46        LDA    $2246       ; reload ISR1
113f: 4d              TSTA               ; ISR1 bit 7: CPT? (TSTA checks sign bit)
1140: 2a 04           BPL    $1146       ; bit 7 clear → skip CPT
1142: 8d 70           BSR    $11B4       ; → $11B4: command pass-through handler
1144: 20 03           BRA    $1149
1146: 7f 22 4d        CLR    $224D       ; no CPT: clear deferred command byte
; Deferred serial-poll status update (runs after all event handlers)
1149: b6 22 6b        LDA    $226B       ; deferred SPoll pending?
114c: 27 1d           BEQ    $116B       ; no → return
114e: 86 09           LDA    #$09
1150: b7 04 05        STA    $0405       ; AUX $09 (datasheet: set local "ist")
1153: b6 22 4b        LDA    $224B       ; load pending status byte
1156: b7 04 03        STA    $0403       ; write deferred serial-poll byte to $0403
1159: b1 04 03        CMPA   $0403       ; verify write-back (read $0403 status view and compare)
115c: 26 08           BNE    $1166       ; mismatch → retry later
115e: 7f 22 6b        CLR    $226B       ; success: clear deferred flag
1161: bd 9a 4f        JSR    $9A4F       ; → $1A4F: clear status bit 0 in $0900
1164: 20 05           BRA    $116B
1166: 86 01           LDA    #$01
1168: b7 04 05        STA    $0405       ; AUX $01 (datasheet: clear local "ist")
116b: 35 3f           PULS   CC,D,DP,X,Y
116d: 1c fb           ANDCC  #$FB        ; clear Z (caller convention: Z=0 means "events processed")
116f: 39              RTS
; =====================================================================================
; Address-status-change handler — ISR2 bit 0 / ADSC ($1170).
; Reads ADSR ($0404) to determine current talker/listener state and updates the front-panel
; status port at $0900 via shadow register $2420.
; - LPAS (ADSR bit 2): listener primary address state
;   Set → call $1A47 (clear bit 2 of $0900, listener LED on)
;   Clear → call $1A62 (set bit 2 of $0900, listener LED off)
; - TPAS (ADSR bit 1): talker primary address state
;   Set → call $1A4B (clear bit 1 of $0900, talk LED on)
;   Clear → call $1A66 (set bit 1 of $0900, talk LED off)
; Note: ADSR is read twice (once per test). This is harmless since ADSR is not clear-on-read.
; Trace fact: successful *IDN? traces can either run this handler on the first post-trigger poll
; or skip directly to $10EF.
; =====================================================================================
1170: 8e 9a 62        LDX    #$9A62
1173: b6 04 04        LDA    $0404
1176: 85 04           BITA   #$04
1178: 27 03           BEQ    $117D
117a: 8e 9a 47        LDX    #$9A47
117d: ad 84           JSR    ,X
117f: 8e 9a 66        LDX    #$9A66
1182: b6 04 04        LDA    $0404
1185: 85 02           BITA   #$02
1187: 27 03           BEQ    $118C
1189: 8e 9a 4b        LDX    #$9A4B
118c: ad 84           JSR    ,X
118e: 39              RTS
; =====================================================================================
; Remote/local-change handler — ISR2 bit 1 / REMC ($118F).
; Checks ISR2 snapshot ($2247) bit 4 = LLO (Local Lockout status, read-only in ISR2):
; - If LLO active (bit 4 set): uses $9A40 (calls $9EB9, clears bit 3 of $0900).
;   Skips the parser reset.
; - If LLO not active (bit 4 clear): uses $9A5B (calls $9F45, sets bit 3 of $0900).
;   Additionally reads ADSR ($0404) to check LPAS (bit 2):
;   if the instrument is currently a listener, resets the incoming-command parser
;   ($2250=0, $2253=0, $224C=1) to prevent partial commands from being misinterpreted.
; =====================================================================================
118f: 8e 9a 5b        LDX    #$9A5B      ; default: non-lockout handler
1192: b6 22 47        LDA    $2247       ; ISR2 snapshot
1195: 85 10           BITA   #$10        ; test bit 4 = LLO status
1197: 27 05           BEQ    $119E       ; LLO not active → check listener state
1199: 8e 9a 40        LDX    #$9A40      ; LLO active → use lockout handler
119c: 20 13           BRA    $11B1       ; skip parser reset
119e: b6 04 04        LDA    $0404       ; read ADSR (live, not snapshot)
11a1: 85 04           BITA   #$04        ; test LPAS (listener primary address state)
11a3: 27 0c           BEQ    $11B1       ; not listener → skip parser reset
; Listener + remote/local change + no lockout: reset incoming-command parser
11a5: 4f              CLRA
11a6: b7 22 50        STA    $2250       ; clear parser depth
11a9: b7 22 53        STA    $2253       ; clear mnemonic parse state
11ac: 86 01           LDA    #$01
11ae: b7 22 4c        STA    $224C       ; set parser mode = 1 (initial)
11b1: ad 84           JSR    ,X          ; call chosen status handler
11b3: 39              RTS
; =====================================================================================
; Command-pass-through handler — ISR1 bit 7 / CPT ($11B4).
; Reads the P8291A command pass-through register ($0405 on read) and decides what to relay.
; Uses $224D as a "deferred secondary command" flag:
;   - $05 (PPC / Parallel Poll Configure) sets $224D=$05, suppresses relay.
;   - If $224D is set and cmd >= $60 (secondary address group), relays cmd to $0405.
;     This is the PPE/PPD secondary that follows PPC.
;   - If cmd < $60 and not $05: clears $224D. If cmd == $15 (OSA / Other Secondary Address),
;     writes AUX $70, which the datasheet names "disable parallel poll".
; Always ends by writing AUX $0F (valid command accepted) to $0405.
; =====================================================================================
11b4: b6 04 05        LDA    $0405       ; read CPT register (command byte)
11b7: 84 7f           ANDA   #$7F        ; strip bit 7 (parity or reserved)
11b9: 81 05           CMPA   #$05        ; PPC (Parallel Poll Configure)?
11bb: 26 05           BNE    $11C2
11bd: b7 22 4d        STA    $224D       ; save $05 → expect PPE/PPD secondary next
11c0: 20 1a           BRA    $11DC       ; → finish with AUX $0F
11c2: 81 60           CMPA   #$60        ; >= $60 → secondary address group?
11c4: 25 0a           BCS    $11D0       ; no → check for OSA
11c6: 7d 22 4d        TST    $224D       ; secondary: was PPC pending?
11c9: 27 11           BEQ    $11DC       ; no deferred PPC → ignore
11cb: b7 04 05        STA    $0405       ; relay PPE/PPD secondary to P8291A
11ce: 20 0c           BRA    $11DC       ; → finish
11d0: 7f 22 4d        CLR    $224D       ; non-secondary, non-PPC: clear deferred state
11d3: 81 15           CMPA   #$15        ; OSA (Other Secondary Address)?
11d5: 26 05           BNE    $11DC       ; no → nothing special
11d7: 86 70           LDA    #$70        ; AUX $70: disable parallel poll
11d9: b7 04 05        STA    $0405       ; write to AUX register
11dc: 86 0f           LDA    #$0F        ; AUX $0F: "valid command accepted"
11de: b7 04 05        STA    $0405       ; acknowledge CPT processing to P8291A
11e1: 39              RTS
; =====================================================================================
; Set one event/status bit — $11E2.
; Entry: A = event index (0..7). Mask from table at $929D.
; Updates the three-tier serial-poll status shadow system:
;   $224A (primary $0403 shadow), $224B (pending), $224E/$224F (deferred), $226A (accumulated).
; If a serial poll is in progress ($224A bit 6 set), the bit goes into $224B (pending) instead
; of writing to $0403 immediately.
; If the new bit matches the SRQ-trigger mask in $2249, raises SRQ (AUX $09, bit 6 in $224A).
; Always clears the corresponding deferred and accumulated bits so they won't re-fire.
; =====================================================================================
11e2: 8e 92 9d        LDX    #$929D      ; base of bit-mask table
11e5: 30 86           LEAX   A,X         ; X → mask byte for event A
11e7: f6 22 4a        LDB    $224A       ; load primary status byte
11ea: c5 40           BITB   #$40        ; serial poll in progress?
11ec: 27 0e           BEQ    $11FC       ; no → set bit directly in $0403 shadow
; Poll in progress: defer the new bit into $224B
11ee: e5 84           BITB   ,X          ; already set in primary?
11f0: 26 2a           BNE    $121C       ; yes → nothing to do, skip to deferred cleanup
11f2: b6 22 4b        LDA    $224B       ; load pending byte
11f5: aa 84           ORA    ,X          ; merge new bit
11f7: b7 22 4b        STA    $224B       ; save back
11fa: 20 20           BRA    $121C       ; → deferred cleanup
; No poll in progress: update $0403 shadow directly
11fc: ea 84           ORB    ,X          ; merge new bit into primary
11fe: b6 22 49        LDA    $2249       ; load SRQ-trigger mask
1201: a5 84           BITA   ,X          ; does this event trigger SRQ?
1203: 27 11           BEQ    $1216       ; no → just write $0403
; SRQ trigger: set bit 6 and issue AUX $09
1205: 34 14           PSHS   X,B         ; save mask ptr and new status
1207: bd 9a 4f        JSR    $9A4F       ; → $1A4F: clear serial-poll LED ($0900 bit 0)
120a: 7f 22 6a        CLR    $226A       ; reset accumulated mask
120d: 35 14           PULS   B,X
120f: ca 40           ORB    #$40        ; set bit 6 (SRQ pending) in new status
1211: 86 09           LDA    #$09
1213: b7 04 05        STA    $0405       ; AUX $09 (datasheet: set local "ist")
1216: f7 04 03        STB    $0403       ; write new serial-poll byte to $0403
1219: f7 22 4a        STB    $224A       ; update primary shadow
; Clear the corresponding deferred and accumulated bits
121c: a6 84           LDA    ,X          ; load mask
121e: 43              COMA               ; invert → clear mask
121f: 1f 89           TFR    A,B
1221: b4 22 4e        ANDA   $224E       ; clear bit in deferred-high
1224: f4 22 4f        ANDB   $224F       ; clear bit in deferred-low
1227: b7 22 4e        STA    $224E
122a: f7 22 4f        STB    $224F
122d: a6 84           LDA    ,X          ; reload mask
122f: 43              COMA
1230: b4 22 6a        ANDA   $226A       ; clear bit in accumulated
1233: b7 22 6a        STA    $226A
1236: 39              RTS
; =====================================================================================
; Clear one event/status bit — $1237.
; Entry: A = event index (0..7). Mask from table at $929D.
; This is the inverse of $11E2. The clearing logic checks the tier hierarchy:
;   No poll in progress ($224A bit 6 clear):
;     - If $2248 (enable mask) has the bit → clear it from $224A and $0403 directly.
;     - Else if $226A (accumulated) has the bit → clear from both $224A/$0403 and $226A.
;     - Else → set the bit in $224E (deferred) so it will be applied after the next poll.
;   Poll in progress ($224A bit 6 set):
;     - If bit is NOT in primary $224A → check $224B (pending), and either defer or clear there.
;     - If bit IS in primary → defer into $224E.
; =====================================================================================
1237: 8e 92 9d        LDX    #$929D      ; base of bit-mask table
123a: 30 86           LEAX   A,X         ; X → mask byte for event A
123c: f6 22 4a        LDB    $224A       ; load primary status byte
123f: c5 40           BITB   #$40        ; serial poll in progress?
1241: 26 15           BNE    $1258       ; yes → poll-active path
; No poll in progress:
1243: b6 22 48        LDA    $2248       ; load enable mask
1246: a5 84           BITA   ,X          ; is this event enabled?
1248: 27 2f           BEQ    $1279       ; no → check accumulated
; Enabled event: clear bit directly from $0403 shadow
124a: a6 84           LDA    ,X
124c: 43              COMA               ; invert → clear mask
124d: b4 22 4a        ANDA   $224A       ; clear from primary shadow
1250: b7 22 4a        STA    $224A
1253: b7 04 03        STA    $0403       ; write updated serial-poll byte to $0403
1256: 20 44           BRA    $129C       ; done
; Poll in progress:
1258: e5 84           BITB   ,X          ; bit present in primary?
125a: 26 38           BNE    $1294       ; yes → can't clear during poll, defer
; Bit not in primary — check pending ($224B)
125c: a6 84           LDA    ,X          ; load mask
125e: b5 22 4b        BITA   $224B       ; in pending?
1261: 27 39           BEQ    $129C       ; no → nothing to do
1263: b5 22 48        BITA   $2248       ; is this event enabled?
1266: 26 08           BNE    $1270       ; yes → clear from pending
; Not enabled: save into deferred-low
1268: ba 22 4f        ORA    $224F       ; merge into deferred-low
126b: b7 22 4f        STB    $224F
126e: 20 2c           BRA    $129C
; Enabled: clear from pending
1270: 43              COMA
1271: b4 22 4b        ANDA   $224B       ; clear bit from pending
1274: b7 22 4b        STA    $224B
1277: 20 23           BRA    $129C
; Not enabled, no poll: check accumulated ($226A)
1279: a6 84           LDA    ,X          ; load mask
127b: b5 22 6a        BITA   $226A       ; in accumulated?
127e: 27 14           BEQ    $1294       ; no → defer
; Accumulated: clear from both primary and accumulated
1280: 43              COMA
1281: 1f 89           TFR    A,B
1283: b4 22 4a        ANDA   $224A       ; clear from primary
1286: b7 22 4a        STA    $224A
1289: b7 04 03        STA    $0403       ; write updated serial-poll byte to $0403
128c: f4 22 6a        ANDB   $226A       ; clear from accumulated
128f: f7 22 6a        STB    $226A
1292: 20 08           BRA    $129C
; Defer: set bit in $224E so it will be applied after next SPC
1294: b6 22 4e        LDA    $224E
1297: aa 84           ORA    ,X          ; merge into deferred
1299: b7 22 4e        STA    $224E
129c: 39              RTS
; Bit-mask table used by $11E2/$1237/$175E.
; Entries are masks for event indices 0..7; entry 6 is deliberately zero in this table.
129d: 01 02           NEG    <$02
129f: 04 08           LSR    <$08
12a1: 10 20 00 80     XLBRA  $1325
; =====================================================================================
; Serial poll complete handler — ISR2 bit 3 / SPC ($12A5).
; Manages a three-tier status byte shadow system:
;   $224A: primary serial-poll byte shadow (written to $0403)
;   $224B: pending/conditional status bits (merged after poll completes)
;   $224E/$224F: deferred event bits (activated under certain conditions)
;   $226A: accumulated event mask
; On SPC: writes AUX $01, clears bit 6 of $224A (service-request / poll-in-progress flag),
; reconstructs the normal serial-poll byte from the shadow tiers, and rewrites $0403. If the
; $0403 write-back verify fails, sets $226B=1 so $10D3's tail code will retry the update later.
; =====================================================================================
12a5: 86 01           LDA    #$01
12a7: b7 04 05        STA    $0405       ; AUX $01 (datasheet: clear local "ist")
12aa: b6 22 4a        LDA    $224A       ; load primary status byte
12ad: 84 bf           ANDA   #$BF        ; clear bit 6 (serial-poll-in-progress)
12af: b7 22 4a        STA    $224A
12b2: b7 04 03        STA    $0403       ; write cleared serial-poll byte to $0403
12b5: bd 9a 6a        JSR    $9A6A       ; → $1A6A: set serial-poll LED on ($0900 bit 0)
; Merge deferred events into accumulated
12b8: b6 22 4e        LDA    $224E       ; load deferred-high
12bb: 43              COMA               ; invert → bits NOT deferred
12bc: b4 22 4a        ANDA   $224A       ; primary AND NOT-deferred = accumulated base
12bf: b7 22 6a        STA    $226A       ; store as accumulated
12c2: f6 22 48        LDB    $2248       ; load enable mask
12c5: 53              COMB               ; invert → disabled bits
12c6: f4 22 6a        ANDB   $226A       ; remove disabled from accumulated
12c9: f7 22 6a        STB    $226A
; Reconstruct new primary from old primary + pending
12cc: ba 22 4b        ORA    $224B       ; A = primary | pending
12cf: f6 22 4f        LDB    $224F       ; promote deferred-low → deferred-high
12d2: f7 22 4e        STB    $224E
; Check if pending bits trigger SRQ
12d5: f6 22 4b        LDB    $224B
12d8: f5 22 49        BITB   $2249       ; any pending bits in SRQ-trigger mask?
12db: 27 0a           BEQ    $12E7       ; no → write without SRQ
12dd: 8a 40           ORA    #$40        ; set bit 6 (SRQ pending)
12df: c6 09           LDB    #$09
12e1: f7 04 05        STB    $0405       ; AUX $09 (datasheet: set local "ist")
12e4: 7f 22 6a        CLR    $226A       ; reset accumulated
; Write reconstructed serial-poll byte to $0403 and verify
12e7: b7 22 4a        STA    $224A       ; update primary shadow
12ea: b7 04 03        STA    $0403       ; write reconstructed byte to $0403
12ed: b1 04 03        CMPA   $0403       ; verify: read $0403 status view back and compare
12f0: 27 0a           BEQ    $12FC       ; match → success
; $0403 write-back verify failed: defer retry to $10D3 tail
12f2: 86 01           LDA    #$01
12f4: b7 22 6b        STA    $226B       ; set deferred-SPoll retry flag
12f7: b7 04 05        STA    $0405       ; AUX $01 (datasheet: clear local "ist")
12fa: 20 07           BRA    $1303       ; → cleanup
; Success: if SRQ still pending, clear serial-poll LED
12fc: 85 40           BITA   #$40        ; SRQ pending?
12fe: 27 03           BEQ    $1303       ; no → cleanup
1300: bd 9a 4f        JSR    $9A4F       ; → $1A4F: clear bit 0 of $0900 (serial-poll LED on)
1303: 7f 22 4b        CLR    $224B       ; clear pending
1306: 7f 22 4f        CLR    $224F       ; clear deferred-low
1309: bd 9a 89        JSR    $9A89       ; → $1A89: set $2281 bit 0 (request dispatch)
130c: 39              RTS
; =====================================================================================
; Incoming-byte handler — ISR1 bit 0 / BI ($130D).
; Reads a data byte from P8291A DIR ($0400) and feeds it into the HP-IB command parser.
; First checks shadow bit 4 in $2247. $2247 starts as the ISR2 snapshot, but $1095/$10BD may
; later clear bit 4 in software, so this gate should NOT be described as a raw ISR2/LLO test.
; If shadow bit 4 is clear, reads DIR to clear BI but discards the byte.
; Otherwise, reads ADSR ($0404) bit 5 to determine EOI status (saved in B: 0=no EOI, 1=EOI).
; Character dispatch:
;   '+' ($2B), '-' ($2D), '.' ($2E), '0'-'9' ($30-$39) → numeric parser at $1465
;   'a'-'z' → uppercased to 'A'-'Z' first, then through mnemonic lookup
;   'A'-'Z' → mnemonic table search starting at $977B/$9780, with sub-table descent via $2251
; Parser state: $224C = parser mode (0=idle, 1=active), $2250 = parse depth, $2253 = parse flags.
; If $224C=0 on entry, $1A9B is called first to check whether command-input is enabled.
; =====================================================================================
130d: b6 22 47        LDA    $2247       ; software shadow derived from ISR2
1310: 85 10           BITA   #$10        ; shadow bit 4 set?
1312: 26 04           BNE    $1318       ; yes → process the byte
1314: b6 04 00        LDA    $0400       ; no → read DIR to clear BI, discard byte
1317: 39              RTS
1318: b6 04 04        LDA    $0404       ; read ADSR
131b: 5f              CLRB               ; B = 0 (no EOI)
131c: 85 20           BITA   #$20        ; ADSR bit 5: EOI?
131e: 27 01           BEQ    $1321
1320: 5c              INCB               ; B = 1 (EOI present)
1321: b6 04 00        LDA    $0400       ; read data byte from DIR
1324: 7d 22 4c        TST    $224C       ; parser already active?
1327: 26 12           BNE    $133B       ; yes → skip activation check
; Parser idle: ask whether we should begin accepting input
1329: 5d              TSTB               ; (preserve EOI status across call)
132a: 34 06           PSHS   D           ; save data byte + EOI flag
132c: bd 9a 9b        JSR    $9A9B       ; → $1A9B: check command-input enable
132f: 26 03           BNE    $1334       ; enabled → activate parser
1331: 32 62           LEAS   $2,S        ; not enabled → discard
1333: 39              RTS
1334: 86 01           LDA    #$01
1336: b7 22 4c        STA    $224C       ; set parser mode = active
1339: 35 06           PULS   D           ; restore A=data, B=EOI
; Classify the incoming character
133b: 84 7f           ANDA   #$7F        ; strip parity/MSB
133d: 81 2b           CMPA   #$2B        ; '+'?
133f: 27 10           BEQ    $1351       ; → numeric parser
1341: 81 2d           CMPA   #$2D        ; '-'?
1343: 27 0c           BEQ    $1351
1345: 81 2e           CMPA   #$2E        ; '.'?
1347: 27 08           BEQ    $1351
1349: 81 30           CMPA   #$30        ; < '0'?
134b: 25 10           BCS    $135D       ; yes → try mnemonic
134d: 81 3a           CMPA   #$3A        ; > '9'?
134f: 24 0c           BCC    $135D       ; yes → try mnemonic
; Numeric character: dispatch to numeric parser
1351: 34 04           PSHS   B           ; save EOI flag on stack
1353: bd 94 65        JSR    $9465       ; → $1465: numeric input state machine
1356: 6d e0           TST    ,S+         ; pop EOI: was this the last byte?
1358: 10 26 00 e7     LBNE   $1443       ; yes → finalize token
135c: 39              RTS
; Mnemonic / alpha character path
135d: 81 61           CMPA   #$61        ; >= 'a'?
135f: 25 06           BCS    $1367       ; no → proceed with uppercase check
1361: 81 7b           CMPA   #$7B        ; <= 'z'?
1363: 24 02           BCC    $1367       ; no → already uppercase or non-alpha
1365: 84 5f           ANDA   #$5F        ; convert lowercase → uppercase
; Check if we're in the middle of a numeric parse sequence
1367: 7d 22 53        TST    $2253       ; numeric parse in progress?
136a: 27 32           BEQ    $139E       ; no → go directly to mnemonic lookup
; Numeric parse was active: handle transition to alpha
136c: 34 06           PSHS   D           ; save char + EOI
136e: 2a 02           BPL    $1372       ; A >= 0 (bit 7 clear) → check for 'E' exponent
1370: 20 07           BRA    $1379       ; bit 7 set → finalize numeric then re-parse
1372: 7d 22 54        TST    $2254       ; exponent state active?
1375: 27 09           BEQ    $1380       ; no → check if this is the 'E' start
1377: 2b 18           BMI    $1391       ; $2254 < 0 (= $80: awaiting exponent digits) → finalize
1379: bd 94 43        JSR    $9443       ; → $1443: finalize current numeric token
137c: 35 06           PULS   D           ; restore and fall through to mnemonic lookup
137e: 20 1e           BRA    $139E
; Check for 'E' as exponent introducer
1380: 81 45           CMPA   #$45        ; 'E'?
1382: 26 f5           BNE    $1379       ; no → finalize numeric, reparse as mnemonic
1384: 86 80           LDA    #$80
1386: b7 22 54        STA    $2254       ; $80 = "awaiting exponent digits"
1389: 35 06           PULS   D           ; restore char
138b: 5d              TSTB               ; EOI?
138c: 10 26 00 b3     LBNE   $1443       ; yes → finalize (exponent with no digits)
1390: 39              RTS                ; no → wait for exponent digits
; Exponent was pending but got another alpha: finalize exponent-less, re-feed 'E' as mnemonic
1391: 7f 22 54        CLR    $2254       ; clear exponent state
1394: bd 94 43        JSR    $9443       ; finalize what we had before 'E'
1397: 86 45           LDA    #$45        ; re-inject 'E' as a mnemonic character
1399: 5f              CLRB               ; no EOI
139a: 8d 02           BSR    $139E       ; → parse 'E' through mnemonic tables
139c: 20 de           BRA    $137C       ; then handle the current char again
139e: 34 04           PSHS   B           ; save EOI flag
13a0: 7d 22 50        TST    $2250       ; multi-char parse in progress?
13a3: 26 36           BNE    $13DB       ; yes → continue in sub-table
; =====================================================================================
; Inner mnemonic parser — first character.
; Searches the 5-entry special-character table at $977B. If not found and A is a letter,
; looks up through the 26-entry dispatch table at $9780 (indexed by A-'A', 2 bytes each → pointer).
; Sub-tables are 5-byte entries: [char, type, handler-hi, handler-lo, aux].
;   type=0: descend (handler is a pointer to the next sub-table, saved in $2251)
;   type=1: call handler directly, reset parser
;   type>=5: same as type=1
;   type=2..4: arm numeric follow-up (handler→$2255, aux→$2257, type→$2258, $2253=$80)
; If no match at any level → $1439 resets parser and calls $1A92 (error/unrecognized).
; =====================================================================================
13a5: c6 05           LDB    #$05        ; 5 entries in special-char table
13a7: 8e 97 7b        LDX    #$977B      ; → special-character mnemonic table
13aa: a1 80           CMPA   ,X+         ; compare A with table entry
13ac: 27 23           BEQ    $13D1       ; match → handle it
13ae: 5a              DECB
13af: 26 f9           BNE    $13AA       ; loop through all 5 entries
; No match in special table; try alpha dispatch
13b1: 7c 22 50        INC    $2250       ; set parse depth = 1 (multi-char mode)
13b4: 81 41           CMPA   #$41        ; < 'A'?
13b6: 25 1e           BCS    $13D6       ; yes → try fallback table at $9A22
13b8: 81 5b           CMPA   #$5B
13ba: 24 1a           BCC    $13D6
; Alpha lookup via the 26-letter dispatch table
13bc: 8e 97 80        LDX    #$9780      ; → letter dispatch table (26 × 2-byte pointers)
13bf: 80 41           SUBA   #$41        ; A = letter index (0='A', 25='Z')
13c1: 48              ASLA               ; × 2 (each entry is a 2-byte pointer)
13c2: ae 86           LDX    A,X         ; X = sub-table pointer for this letter
13c4: 35 04           PULS   B           ; restore EOI flag
13c6: 6d 84           TST    ,X          ; sub-table exists?
13c8: 27 6f           BEQ    $1439       ; null → unrecognized, reset parser
13ca: bf 22 51        STX    $2251       ; save sub-table pointer for multi-char continuation
13cd: 5d              TSTB               ; EOI?
13ce: 26 69           BNE    $1439       ; EOI after single letter → reset (incomplete mnemonic)
13d0: 39              RTS                ; wait for more characters
; Special-char match: finalize token immediately
13d1: 8d 70           BSR    $1443       ; → $1443: finalize current token
13d3: 32 61           LEAS   $1,S        ; drop saved EOI byte
13d5: 39              RTS
; Fallback table search (for non-alpha printable chars)
13d6: 8e 9a 22        LDX    #$9A22      ; → fallback mnemonic table
13d9: 20 13           BRA    $13EE       ; → enter sub-table search loop
; Multi-char continuation: resume from saved sub-table
13db: be 22 51        LDX    $2251       ; reload current sub-table pointer
13de: 81 5f           CMPA   #$5F        ; '_' (underscore)?
13e0: 27 0c           BEQ    $13EE       ; yes → allow as valid mnemonic char
13e2: 81 41           CMPA   #$41        ; < 'A'?
13e4: 25 04           BCS    $13EA       ; yes → not a valid continuation
13e6: 81 5b           CMPA   #$5B        ; > 'Z'?
13e8: 25 04           BCS    $13EE       ; no → valid uppercase letter, search sub-table
; Invalid continuation character: reset parser
13ea: 32 61           LEAS   $1,S        ; drop saved EOI
13ec: 20 4b           BRA    $1439       ; → reset
; Sub-table search loop (5 bytes per entry: [char, type, ptr-hi, ptr-lo, aux])
13ee: 6d 84           TST    ,X          ; end of sub-table? (null terminator)
13f0: 27 f8           BEQ    $13EA       ; yes → no match, reset
13f2: a1 84           CMPA   ,X          ; compare char with entry[0]
13f4: 26 39           BNE    $142F       ; no match → advance to next entry
; Match found: dispatch based on entry type (entry[1])
13f6: a6 04           LDA    $4,X        ; A = entry[4] (aux byte)
13f8: 10 ae 02        LDY    $2,X        ; Y = entry[2..3] (handler pointer or sub-table)
13fb: e6 01           LDB    $1,X        ; B = entry[1] (type)
13fd: 26 09           BNE    $1408       ; type != 0 → terminal entry
; Type 0: descend into next sub-table
13ff: 10 bf 22 51     STY    $2251       ; save new sub-table pointer
1403: e6 e0           LDB    ,S+         ; pop EOI flag
1405: 26 32           BNE    $1439       ; EOI → incomplete mnemonic, reset
1407: 39              RTS                ; wait for next character
; Type 1 or >= 5: call handler directly
1408: c1 01           CMPB   #$01
140a: 26 0b           BNE    $1417
140c: 32 61           LEAS   $1,S        ; drop EOI flag
140e: ad a4           JSR    ,Y          ; call handler
1410: 7f 22 50        CLR    $2250       ; reset parse depth
1413: 7f 22 53        CLR    $2253       ; reset parse flags
1416: 39              RTS
; Type 2..4: arm numeric follow-up parse
1417: c1 05           CMPB   #$05
1419: 24 f1           BCC    $140C       ; type >= 5 → treat as direct call (same as type 1)
141b: 10 bf 22 55     STY    $2255       ; save handler pointer for numeric completion
141f: b7 22 57        STA    $2257       ; save aux byte
1422: f7 22 58        STB    $2258       ; save type (2/3/4 selects numeric format)
1425: 86 80           LDA    #$80
1427: b7 22 53        STA    $2253       ; set parse flags = $80 (numeric follow-up armed)
142a: a6 e0           LDA    ,S+         ; pop EOI flag
142c: 26 0b           BNE    $1439       ; EOI → no digits follow, reset
142e: 39              RTS                ; wait for numeric digits
; Advance to next sub-table entry
142f: 30 04           LEAX   $4,X        ; skip to entry[4]
1431: 6d 1d           TST    -$3,X       ; check entry[1] (type) of current
1433: 27 b9           BEQ    $13EE       ; type=0 → entries are 4 bytes, already at next
1435: 30 01           LEAX   $1,X        ; type!=0 → entries are 5 bytes, skip aux
1437: 20 b5           BRA    $13EE       ; → try next entry
; Parser reset: unrecognized or incomplete token
1439: 7f 22 50        CLR    $2250       ; clear parse depth
143c: 7f 22 53        CLR    $2253       ; clear parse flags
143f: bd 9a 92        JSR    $9A92       ; → $1A92: set $2281 bit 5 (error/unrecognized)
1442: 39              RTS
; =====================================================================================
; Token finalization — $1443.
; Called on EOI or when a new command character arrives after a parsed token.
; Two paths:
;   $2250 != 0 (multi-char mnemonic in progress):
;     If $2253 bit 7 set AND bit 0 set → numeric follow-up complete: call $1692 to format
;     and dispatch through handler at $2255. Otherwise → incomplete, reset.
;   $2250 == 0 (no mnemonic):
;     If $2253 != 0 → standalone numeric value complete: call $15E0 to format for display.
; Always resets $2250 and $2253 on exit.
; =====================================================================================
1443: 7d 22 50        TST    $2250       ; mnemonic parse in progress?
1446: 27 0e           BEQ    $1456       ; no → check standalone numeric
; Mnemonic in progress: was a numeric follow-up armed and populated?
1448: b6 22 53        LDA    $2253
144b: 2a ec           BPL    $1439       ; bit 7 clear → no follow-up armed, reset
144d: 85 01           BITA   #$01        ; bit 0: at least one digit entered?
144f: 27 e8           BEQ    $1439       ; no digits → incomplete, reset
1451: bd 96 92        JSR    $9692       ; → $1692: format value and dispatch to handler
1454: 20 08           BRA    $145E       ; → cleanup
; No mnemonic: check for standalone numeric token
1456: 7d 22 53        TST    $2253       ; any numeric parse state?
1459: 27 03           BEQ    $145E       ; no → nothing to finalize
145b: bd 95 e0        JSR    $95E0       ; → $15E0: format standalone numeric for display
; Cleanup
145e: 7f 22 50        CLR    $2250       ; reset parse depth
1461: 7f 22 53        CLR    $2253       ; reset parse flags
1464: 39              RTS
; =====================================================================================
; Numeric input state machine — $1465.
; Called for each digit/sign/decimal character during HP-IB command parsing.
; State variables:
;   $2253: parse flags. Bit 7 = numeric follow-up armed (from mnemonic parser).
;          Bit 0 = initialization done (at least one digit processed).
;   $225F: packed BCD accumulator for incoming digits (shifted left 4 per new digit).
;   $2261: digit countdown. When it reaches 0, all expected digits have arrived → dispatch.
;   $2258: numeric format type (set by mnemonic parser): type 2 expects 1 digit ($2261=1),
;          other types expect 2 digits ($2261=2).
;   $2254: exponent state (0=none, $80=awaiting exponent, >0=exponent value entered).
; If sign (+/-) or decimal point arrives after digits have been entered, finalizes the current
; number first via $1692 then re-enters to start a new parse.
; =====================================================================================
1465: f6 22 53        LDB    $2253       ; load parse flags
1468: 2a 51           BPL    $14BB       ; bit 7 clear → standalone numeric path (below)
; Mnemonic follow-up numeric path (bit 7 set)
146a: c5 01           BITB   #$01        ; already initialized?
146c: 27 15           BEQ    $1483       ; no → first character, initialize
; Already in progress: check if this is a sign/point (new value) vs digit (continuation)
146e: 81 2b           CMPA   #$2B        ; '+'?
1470: 27 08           BEQ    $147A       ; → finalize current, restart
1472: 81 2d           CMPA   #$2D        ; '-'?
1474: 27 04           BEQ    $147A
1476: 81 2e           CMPA   #$2E        ; '.'?
1478: 26 23           BNE    $149D       ; no → it's a digit, accumulate
; Sign or decimal after digits: finalize current number, re-enter with new char
147a: 34 02           PSHS   A           ; save current character
147c: bd 96 92        JSR    $9692       ; → $1692: format and dispatch accumulated value
147f: 35 02           PULS   A           ; restore character
1481: 20 e2           BRA    $1465       ; re-enter state machine
; First character: initialize accumulator and digit counter
1483: ca 01           ORB    #$01        ; set bit 0 (initialized)
1485: f7 22 53        STB    $2253
1488: 7f 22 5f        CLR    $225F       ; clear BCD accumulator
148b: 7f 22 54        CLR    $2254       ; clear exponent state
148e: c6 01           LDB    #$01
1490: f7 22 61        STB    $2261       ; digit count = 1 (base)
1493: f6 22 58        LDB    $2258       ; load format type
1496: c1 02           CMPB   #$02        ; type 2?
1498: 27 03           BEQ    $149D       ; yes → expect 1 digit only
149a: 7c 22 61        INC    $2261       ; other types → expect 2 digits
; Accumulate digit into packed BCD
149d: 80 30           SUBA   #$30        ; convert ASCII to digit value
149f: 25 98           BCS    $1439       ; < 0 → invalid char, reset parser
14a1: 78 22 5f        ASL    $225F       ; shift accumulator left 4 bits
14a4: 78 22 5f        ASL    $225F       ;   (making room for new digit in low nibble)
14a7: 78 22 5f        ASL    $225F
14aa: 78 22 5f        ASL    $225F
14ad: bb 22 5f        ADDA   $225F       ; merge new digit into low nibble
14b0: b7 22 5f        STA    $225F       ; store updated accumulator
14b3: 7a 22 61        DEC    $2261       ; decrement digit countdown
14b6: 10 27 01 d8     LBEQ   $1692       ; all digits received → format and dispatch
14ba: 39              RTS                ; wait for more digits
; Standalone numeric input path ($2253 bit 7 clear, entered from main parser).
; State in $2259-$2263:
;   $2259: sign/mode flags (bit 0 = negative, bit 1 = negative exponent)
;   $225A-$225E: BCD digit storage (5 bytes = 10 nibbles, right-justified)
;   $225F: packed BCD accumulator for mnemonic-follow-up path
;   $2260: working BCD digit pair
;   $2261: digit counter (counts down from 11 = max digits)
;   $2262: format flags (bit 7 = sign seen, bit 6 = decimal point seen, bit 2 = digit seen,
;          bit 1 = overflow, bit 0 = initialized)
;   $2263: exponent accumulator (signed)
;   $2254: exponent state (0=mantissa, $80=awaiting exponent sign/digits, >0=in exponent)
; Calls $15E0 when the current number needs to be finalized before a new one starts.
14bb: 26 15           BNE    $14D2       ; $2253 != 0 → already initialized, skip init
; First character of standalone numeric: clear $2259-$2263
14bd: 8e 22 59        LDX    #$2259
14c0: c6 0b           LDB    #$0B        ; 11 bytes to clear
14c2: 6f 80           CLR    ,X+
14c4: 5a              DECB
14c5: 26 fb           BNE    $14C2
14c7: 7c 22 53        INC    $2253       ; set $2253 = 1 (standalone numeric active)
14ca: 7f 22 54        CLR    $2254       ; exponent state = none
14cd: c6 0b           LDB    #$0B        ; max 11 digits
14cf: f7 22 61        STB    $2261       ; digit counter
; Character dispatch
14d2: 81 30           CMPA   #$30        ; >= '0'?
14d4: 24 5b           BCC    $1531       ; yes → digit path
14d6: 81 2e           CMPA   #$2E        ; '.'?
14d8: 27 40           BEQ    $151A       ; → decimal point path
; Sign character (+/-) or exponent sign
14da: f6 22 54        LDB    $2254       ; exponent state
14dd: 2a 18           BPL    $14F7       ; >= 0 → not awaiting exponent start
; Exponent state $80 → sign/sign-of-exponent
14df: c6 01           LDB    #$01
14e1: f7 22 54        STB    $2254       ; mark exponent as "digits expected"
14e4: f6 22 62        LDB    $2262
14e7: ca 40           ORB    #$40        ; set "decimal point seen" (locks out further '.')
14e9: c4 7e           ANDB   #$7E        ; clear bit 0 and bit 7
14eb: f7 22 62        STB    $2262
14ee: c5 04           BITB   #$04        ; any digit seen yet?
14f0: 26 05           BNE    $14F7       ; yes → just record sign
; No digits before exponent sign → finalize current and restart
14f2: 17 00 eb        LBSR   $15E0       ; → $15E0: format for display
14f5: 20 c6           BRA    $14BD       ; → reinitialize
; General sign handling
14f7: f6 22 62        LDB    $2262
14fa: 2a 05           BPL    $1501       ; bit 7 clear → first sign character
; Sign already seen → finalize current number, restart
14fc: 17 00 e1        LBSR   $15E0
14ff: 20 bc           BRA    $14BD
; First sign: record it
1501: ca 80           ORB    #$80        ; set bit 7 (sign seen)
1503: f7 22 62        STB    $2262
1506: c6 02           LDB    #$02        ; B = 2 (negative mantissa flag)
1508: 81 2b           CMPA   #$2B        ; '+'?
150a: 27 0d           BEQ    $1519       ; yes → don't set negative bit
150c: 7d 22 54        TST    $2254       ; in exponent?
150f: 27 02           BEQ    $1513       ; no → use mantissa negative flag
1511: c6 01           LDB    #$01        ; yes → use exponent negative flag (bit 0)
1513: fa 22 59        ORB    $2259       ; merge into sign byte
1516: f7 22 59        STB    $2259
1519: 39              RTS
; Decimal point handling
151a: f6 22 54        LDB    $2254       ; in exponent?
151d: 26 07           BNE    $1526       ; yes → '.' invalid in exponent, finalize and restart
151f: f6 22 62        LDB    $2262
1522: c5 40           BITB   #$40        ; decimal already seen?
1524: 27 05           BEQ    $152B       ; no → record it
; Duplicate decimal or decimal in exponent: finalize, restart
1526: 17 00 b7        LBSR   $15E0
1529: 20 92           BRA    $14BD
; Record decimal point
152b: ca c0           ORB    #$C0        ; set bits 7+6 (sign seen + decimal seen)
152d: f7 22 62        STB    $2262
1530: 39              RTS
; Digit path (A >= '0', i.e., '0'-'9')
1531: f6 22 62        LDB    $2262
1534: ca 81           ORB    #$81        ; set bits 7+0 (sign seen + initialized)
1536: 7d 22 54        TST    $2254       ; in exponent?
1539: 26 69           BNE    $15A4       ; yes → exponent digit path
; Mantissa digit
153b: ca 04           ORB    #$04        ; set bit 2 (digit seen)
153d: f7 22 62        STB    $2262
1540: f6 22 61        LDB    $2261       ; digit counter
1543: 80 30           SUBA   #$30        ; convert ASCII → digit value
1545: 26 1c           BNE    $1563       ; non-zero digit → store it
; Zero digit: special handling (leading zero suppression vs exponent adjust)
1547: c1 0b           CMPB   #$0B        ; still at max count (first digit)?
1549: 26 18           BNE    $1563
154b: b6 22 62        LDA    $2262
154e: 85 40           BITA   #$40
1550: 27 10           BEQ    $1562
1552: f6 22 63        LDB    $2263
1555: c0 01           SUBB   #$01
1557: 28 06           BVC    $155F
1559: 5f              CLRB
155a: 8a 02           ORA    #$02
155c: b7 22 62        STA    $2262
155f: f7 22 63        STB    $2263
1562: 39              RTS
1563: 5d              TSTB
1564: 2b 1a           BMI    $1580
1566: 8e 22 5a        LDX    #$225A
1569: 57              ASRB
156a: 50              NEGB
156b: cb 05           ADDB   #$05
156d: 3a              ABX
156e: f6 22 61        LDB    $2261
1571: c5 01           BITB   #$01
1573: 27 04           BEQ    $1579
1575: 48              ASLA
1576: 48              ASLA
1577: 48              ASLA
1578: 48              ASLA
1579: ab 84           ADDA   ,X
157b: a7 84           STA    ,X
157d: 7a 22 61        DEC    $2261
1580: f6 22 61        LDB    $2261
1583: b6 22 62        LDA    $2262
1586: 85 40           BITA   #$40
1588: 26 15           BNE    $159F
158a: c1 0a           CMPB   #$0A
158c: 27 10           BEQ    $159E
158e: f6 22 63        LDB    $2263
1591: cb 01           ADDB   #$01
1593: 28 06           BVC    $159B
1595: 5f              CLRB
1596: 8a 02           ORA    #$02
1598: b7 22 62        STA    $2262
159b: f7 22 63        STB    $2263
159e: 39              RTS
159f: c1 0a           CMPB   #$0A
15a1: 27 af           BEQ    $1552
15a3: 39              RTS
15a4: c5 04           BITB   #$04
15a6: 26 0a           BNE    $15B2
15a8: c4 fe           ANDB   #$FE
15aa: f7 22 62        STB    $2262
15ad: 8d 31           BSR    $15E0
15af: 16 ff 0b        LBRA   $14BD
15b2: ca 40           ORB    #$40
15b4: f7 22 62        STB    $2262
15b7: c6 01           LDB    #$01
15b9: f7 22 54        STB    $2254
15bc: c6 f0           LDB    #$F0
15be: f5 22 60        BITB   $2260
15c1: 27 08           BEQ    $15CB
15c3: f6 22 62        LDB    $2262
15c6: ca 02           ORB    #$02
15c8: f7 22 62        STB    $2262
15cb: 84 0f           ANDA   #$0F
15cd: 78 22 60        ASL    $2260
15d0: 78 22 60        ASL    $2260
15d3: 78 22 60        ASL    $2260
15d6: 78 22 60        ASL    $2260
15d9: bb 22 60        ADDA   $2260
15dc: b7 22 60        STA    $2260
15df: 39              RTS
; =====================================================================================
; Standalone numeric display formatter — $15E0.
; Converts the accumulated numeric state ($2259-$2263) into an 8-byte display buffer pushed
; onto U, then calls $9AB9 to transfer it to the display system.
; Process:
;   1. Validates $2262 bit 0 (initialized) and $2254 (not awaiting exponent). If either
;      check fails, takes the zero-fill path at $167C.
;   2. Converts the 2-nibble exponent in $2260 to a signed binary value via BCD→binary
;      conversion (high nibble × 10 + low nibble), applies sign from $2259 bit 0, and adds
;      the mantissa exponent offset in $2263. Clamps to ±99.
;   3. Converts the clamped exponent back to BCD (using DAA and a table at $9777), builds
;      the sign byte in $2259, and pushes 8 bytes through U: [sign/flags, digits...].
;   4. Leading-zero suppression: digits pushed from $225A-$2260 are checked, and if all are
;      zero up to the decimal point, the leading zeros are suppressed.
;   5. Finally calls $9AB9 (display update) and clears $2253/$2254.
; Zero-fill path ($167C): pushes 8 zero bytes through U, clears Z flag.
; =====================================================================================
15e0: 34 02           PSHS   A
15e2: f6 22 62        LDB    $2262       ; format flags
15e5: c5 01           BITB   #$01        ; initialized?
15e7: 10 27 00 91     LBEQ   $167C       ; no → zero-fill
15eb: b6 22 54        LDA    $2254       ; exponent state
15ee: 10 2b 00 8a     LBMI   $167C       ; $80 (awaiting) → zero-fill
; Convert 2-nibble BCD exponent in $2260 to binary
15f2: b6 22 60        LDA    $2260       ; packed BCD exponent
15f5: 1f 89           TFR    A,B
15f7: 84 f0           ANDA   #$F0        ; high nibble
15f9: c4 0f           ANDB   #$0F        ; low nibble
15fb: 34 04           PSHS   B           ; save low nibble
15fd: c6 a0           LDB    #$A0        ; $A0 = 160
15ff: 3d              MUL               ; A(high nibble) × $A0; result in D (high byte = tens digit × 10)
1600: ab e0           ADDA   ,S+         ; add low nibble to get binary exponent
; Apply exponent sign and add mantissa offset
1602: f6 22 59        LDB    $2259       ; sign flags
1605: c5 01           BITB   #$01        ; bit 0 = negative mantissa?
1607: 27 01           BEQ    $160A       ; no → keep positive
1609: 40              NEGA               ; negate exponent
160a: bb 22 63        ADDA   $2263       ; add mantissa exponent offset
160d: 28 08           BVC    $1617
160f: f6 22 62        LDB    $2262
1612: ca 02           ORB    #$02
1614: f7 22 62        STB    $2262
1617: b7 22 63        STA    $2263
161a: 2a 01           BPL    $161D
161c: 40              NEGA
161d: 81 64           CMPA   #$64
161f: 25 03           BCS    $1624
1621: 4f              CLRA
1622: 20 eb           BRA    $160F
1624: 1f 89           TFR    A,B
1626: 84 07           ANDA   #$07
1628: 34 02           PSHS   A
162a: c4 78           ANDB   #$78
162c: 58              ASLB
162d: 8e 97 77        LDX    #$9777
1630: 4f              CLRA
1631: 5d              TSTB
1632: 27 0a           BEQ    $163E
1634: 58              ASLB
1635: 24 03           BCC    $163A
1637: ab 84           ADDA   ,X
1639: 19              DAA
163a: 30 01           LEAX   $1,X
163c: 20 f3           BRA    $1631
163e: ab e0           ADDA   ,S+
1640: 19              DAA
1641: b7 22 60        STA    $2260
1644: b6 22 59        LDA    $2259
1647: 84 02           ANDA   #$02
1649: 7d 22 63        TST    $2263
164c: 2a 02           BPL    $1650
164e: 8a 01           ORA    #$01
1650: b7 22 59        STA    $2259
1653: 8e 22 61        LDX    #$2261
1656: c6 07           LDB    #$07
1658: 34 04           PSHS   B
165a: a6 82           LDA    ,-X
165c: 36 02           PSHU   A
165e: 27 06           BEQ    $1666
1660: c1 07           CMPB   #$07
1662: 27 02           BEQ    $1666
1664: 6f e4           CLR    ,S
1666: 5a              DECB
1667: 26 f1           BNE    $165A
1669: a6 1f           LDA    -$1,X
166b: 6d e0           TST    ,S+
166d: 27 04           BEQ    $1673
166f: 84 fd           ANDA   #$FD
1671: 6f 46           CLR    $6,U
1673: 36 02           PSHU   A
1675: b6 22 62        LDA    $2262
1678: 85 02           BITA   #$02
167a: 20 0a           BRA    $1686
167c: c6 08           LDB    #$08
167e: 4f              CLRA
167f: 36 02           PSHU   A
1681: 5a              DECB
1682: 26 fb           BNE    $167F
1684: 1c fb           ANDCC  #$FB
1686: bd 9a b9        JSR    $9AB9
1689: 7f 22 53        CLR    $2253
168c: 7f 22 54        CLR    $2254
168f: 35 02           PULS   A
1691: 39              RTS
; =====================================================================================
; Mnemonic-follow-up numeric dispatch — $1692.
; After a mnemonic armed a numeric follow-up (type in $2258, handler in $2255), this function
; formats the accumulated BCD digit(s) in $225F and dispatches to the handler.
; If type == 4: converts the packed BCD pair in $225F to a single byte using the same
; high-nibble×10+low-nibble conversion, placing the result in B.
; Otherwise: B = raw $225F value.
; Then loads A = $2257 (aux byte), Y = $2255 (handler pointer), and JMPs to $940E which is
; the common dispatch entry that calls the handler.
; =====================================================================================
1692: f6 22 5f        LDB    $225F       ; packed BCD digit(s) from accumulator
1695: b6 22 58        LDA    $2258       ; format type (set by mnemonic parser)
1698: 81 04           CMPA   #$04        ; type 4?
169a: 26 0f           BNE    $16AB       ; no → use raw $225F
; Type 4: BCD pair → binary conversion
169c: 1f 98           TFR    B,A
169e: 84 f0           ANDA   #$F0        ; high nibble
16a0: c4 0f           ANDB   #$0F        ; low nibble
16a2: 34 04           PSHS   B
16a4: c6 a0           LDB    #$A0        ; high nibble × $A0 → tens digit × 10
16a6: 3d              MUL
16a7: ab e0           ADDA   ,S+         ; + low nibble = binary value
16a9: 1f 89           TFR    A,B         ; result in B
; Common path: dispatch to saved handler
16ab: b6 22 57        LDA    $2257       ; aux byte
16ae: 10 be 22 55     LDY    $2255       ; handler pointer
16b2: 7e 94 0e        JMP    $940E       ; → common dispatch (calls handler at Y)
; =====================================================================================
; Parser idle/complete query — $16B5.
; Entry: A = mode (0 = query-and-reset, nonzero = force parser to active).
; If A == 0:
;   Clears $224C (parser mode → idle). Checks $2250 | $2253:
;   - If nonzero (parse was in progress): clears both, returns Z=0 (was busy).
;   - If zero (already idle): returns Z=1 (idle).
; If A != 0: sets $224C = 1 (force parser to active), returns Z=1.
; Preserves A and CC flags on entry (except Z, which is the return value).
; =====================================================================================
16b5: 34 03           PSHS   A,CC        ; save original A and flags
16b7: 4d              TSTA               ; mode 0?
16b8: 26 16           BNE    $16D0       ; nonzero → force active
; Mode 0: query and reset
16ba: b7 22 4c        STA    $224C       ; clear parser mode (A=0)
16bd: b6 22 50        LDA    $2250       ; parse depth
16c0: ba 22 53        ORA    $2253       ; | parse flags
16c3: 27 10           BEQ    $16D5       ; both zero → parser was idle
; Parser was busy: clear state, return Z=0
16c5: 7f 22 50        CLR    $2250
16c8: 7f 22 53        CLR    $2253
16cb: 35 03           PULS   CC,A        ; restore original flags
16cd: 1c fb           ANDCC  #$FB        ; clear Z → "was busy"
16cf: 39              RTS
; Force parser to active
16d0: 86 01           LDA    #$01
16d2: b7 22 4c        STA    $224C       ; parser mode = active
; Return Z=1 (idle / no work pending)
16d5: 35 03           PULS   CC,A        ; restore original flags
16d7: 1a 04           ORCC   #$04        ; set Z → "idle"
16d9: 39              RTS
; =====================================================================================
; HP-IB transmit state machine — ISR1 bit 1 / BO ($16DA).
; State machine in $2269:
;   $80 → message boundary: transition to $01, post refill request via $1C88 (type $000D),
;          set busy flag $2264=1, return without writing data.
;   $01 → waiting for refill: set busy flag $2264=1, return without writing data.
;          (Only $1729 can reset $2269 to $00 when new buffer params are installed.)
;   $00 → ready: clear busy flag, read next byte from [$2266], advance pointer, decrement
;          $2265. If more bytes remain → write byte to $0400 and return.
;          If last byte of segment: set $2269=$80.
;            If $2268=0 (no continuation): issue FEOI (AUX $06 to $0405) before writing.
;            If $2268!=0 (more segments follow): write byte, then immediately transition to
;            $01 and post another refill request via $1C88.
; Key invariant: FEOI is written to AUX ($0405) BEFORE the last data byte goes to DOR ($0400).
; =====================================================================================
16da: b6 22 69        LDA    $2269
16dd: 2b 08           BMI    $16E7       ; $80 (boundary) → post refill
16df: 27 19           BEQ    $16FA       ; $00 (ready) → output next byte
; State $01 (waiting for refill):
16e1: 86 01           LDA    #$01
16e3: b7 22 64        STA    $2264       ; set busy flag
16e6: 39              RTS                ; return WITHOUT writing any byte
; State $80 (message boundary):
16e7: 86 01           LDA    #$01
16e9: b7 22 69        STA    $2269       ; transition to $01 (waiting)
16ec: bd 9c 88        JSR    $9C88       ; → $1C88: post refill request (type $000D)
16ef: b6 22 69        LDA    $2269       ; check if $1C88 (or its chain) already refilled
16f2: 27 06           BEQ    $16FA       ; if $2269 was reset to $00, output immediately
16f4: 86 01           LDA    #$01
16f6: b7 22 64        STA    $2264       ; still waiting: set busy flag
16f9: 39              RTS
; State $00 (ready to output):
16fa: 7f 22 64        CLR    $2264       ; clear busy flag
16fd: be 22 66        LDX    $2266       ; load buffer pointer
1700: a6 80           LDA    ,X+         ; get next byte, advance pointer
1702: bf 22 66        STX    $2266       ; save updated pointer
1705: 7a 22 65        DEC    $2265       ; decrement remaining count
1708: 26 0f           BNE    $1719       ; more bytes → write and return
; Last byte of this segment:
170a: c6 80           LDB    #$80
170c: f7 22 69        STB    $2269       ; transition to $80 (boundary)
170f: 7d 22 68        TST    $2268       ; more segments follow?
1712: 26 09           BNE    $171D       ; yes → write byte, then request next segment
; Final byte of entire message:
1714: c6 06           LDB    #$06
1716: f7 04 05        STB    $0405       ; AUX feoi — assert EOI with next byte
1719: b7 04 00        STA    $0400       ; *** WRITE DATA BYTE TO P8291A DOR ***
171c: 39              RTS
; Continuation segment path: write current byte, then immediately request next segment
171d: b7 04 00        STA    $0400       ; write data byte (no EOI)
1720: 86 01           LDA    #$01
1722: b7 22 69        STA    $2269       ; transition to $01 (waiting)
1725: bd 9c 88        JSR    $9C88       ; → $1C88: post refill request for next segment
1728: 39              RTS
; =====================================================================================
; Install transmit-buffer descriptor — $1729.
; Copies 4 bytes from the U-based descriptor into the transmit state at $2265-$2268:
;   $2265 = byte count, $2266-$2267 = buffer pointer, $2268 = continuation flag.
; Resets $2269 to $00 (ready state). If the transmitter was stalled ($2264 = busy flag set),
; immediately calls $16DA to resume output.
; Entry: U points to a 4-byte descriptor [count, ptr-hi, ptr-lo, continuation].
; =====================================================================================
1729: 34 17           PSHS   X,D,CC      ; save registers
172b: 8e 22 65        LDX    #$2265      ; X → transmit descriptor
172e: 7f 22 69        CLR    $2269       ; output state = $00 (ready)
1731: 37 06           PULU   D           ; pull first 2 bytes (count + ptr-hi)
1733: ed 81           STD    ,X++        ; store at $2265-$2266
1735: 37 06           PULU   D           ; pull next 2 bytes (ptr-lo + continuation)
1737: ed 84           STD    ,X          ; store at $2267-$2268
1739: 7d 22 64        TST    $2264       ; transmitter stalled (busy flag)?
173c: 27 02           BEQ    $1740       ; no → done
173e: 8d 9a           BSR    $16DA       ; yes → immediately resume output
1740: 35 17           PULS   CC,D,X
1742: 39              RTS
; =====================================================================================
; Set parser/event slot — $1743.
; Entry: A = slot index (masked to 0..7), B = optional associated value.
; If B != 0: stores B at $226C+A, then calls $11E2 to set the corresponding event bit.
; If B == 0: calls $1237 to clear the corresponding event bit.
; Index 6 is special: skips the event-bit set/clear entirely (slot 6 has no bit in the mask table).
; =====================================================================================
1743: 34 3f           PSHS   Y,X,DP,D,CC
1745: 84 07           ANDA   #$07        ; mask to 0..7
1747: 81 06           CMPA   #$06        ; special slot 6?
1749: 27 10           BEQ    $175B       ; yes → skip event-bit operations
174b: 5d              TSTB               ; associated value provided?
174c: 27 0a           BEQ    $1758       ; no → clear the event bit
; Set: store value and set event bit
174e: 8e 22 6c        LDX    #$226C      ; per-slot value table
1751: e7 86           STB    A,X         ; store B at $226C+A
1753: bd 91 e2        JSR    $91E2       ; → $11E2: set event bit A
1756: 20 03           BRA    $175B
; Clear event bit
1758: bd 92 37        JSR    $9237       ; → $1237: clear event bit A
175b: 35 3f           PULS   CC,D,DP,X,Y
175d: 39              RTS
; =====================================================================================
; Read parser/event slot — $175E.
; Entry: A = slot index (masked to 0..7).
; Returns: B = value from $226C+A if the corresponding event bit in $224A is set, else B = 0.
; =====================================================================================
175e: 34 13           PSHS   X,A,CC
1760: 84 07           ANDA   #$07        ; mask to 0..7
1762: 8e 92 9d        LDX    #$929D      ; bit-mask table
1765: f6 22 4a        LDB    $224A       ; primary status byte
1768: e5 86           BITB   A,X         ; event bit set?
176a: 27 07           BEQ    $1773       ; no → return 0
176c: 8e 22 6c        LDX    #$226C      ; per-slot value table
176f: e6 86           LDB    A,X         ; B = stored value
1771: 20 01           BRA    $1774
1773: 5f              CLRB               ; event not set → B = 0
1774: 35 13           PULS   CC,A,X
1776: 39              RTS
; ROM data tables used by the parser and numeric-formatting code.
; This region is not executable code even though the raw disassembly renders it as instructions.
; Known users include $13A5 (mnemonic parsing) and $1465/$162D (numeric formatting helpers).
1777: 64 32           LSR    -$E,Y
1779: 16 08 0a        LBRA   $1F86
177c: 0d 20           TST    <$20
177e: 2c 3b           BGE    $17BB
1780: 97 b5           STA    <$B5
1782: 97 e8           STA    <$E8
1784: 97 b4           STA    <$B4
1786: 98 0c           EORA   <$0C
1788: 98 58           EORA   <$58
178a: 98 68           EORA   <$68
178c: 98 a0           EORA   <$A0
178e: 98 a6           EORA   <$A6
1790: 98 bb           EORA   <$BB
1792: 97 b4           STA    <$B4
1794: 98 c6           EORA   <$C6
1796: 98 cc           EORA   <$CC
1798: 98 d2           EORA   <$D2
179a: 98 dd           EORA   <$DD
179c: 98 e3           EORA   <$E3
179e: 98 f8           EORA   <$F8
17a0: 99 35           ADCA   <$35
17a2: 99 40           ADCA   <$40
17a4: 99 7d           ADCA   <$7D
17a6: 99 e7           ADCA   <$E7
17a8: 99 ed           ADCA   <$ED
17aa: 99 f8           ADCA   <$F8
17ac: 99 fe           ADCA   <$FE
17ae: 97 b4           STA    <$B4
17b0: 97 b4           STA    <$B4
17b2: 97 b4           STA    <$B4
17b4: 00 50           NEG    <$50
17b6: 00 97           NEG    <$97
17b8: ce 4d 01        LDU    #$4D01
17bb: 9c e3           CMPX   <$E3
17bd: 07 55           ASR    <$55
17bf: 01 9c           NEG    <$9C
17c1: e3 14           ADDD   -$C,X
17c3: 48              ASLA
17c4: 00 97           NEG    <$97
17c6: c8 00           EORB   #$00
17c8: 52              XNCB
17c9: 01 9c           NEG    <$9C
17cb: 8d 02           BSR    $17CF
17cd: 00 41           NEG    <$41
17cf: 01 9b           NEG    <$9B
17d1: f0 00 42        SUBB   >$0042
17d4: 01 9b           NEG    <$9B
17d6: f0 01 43        SUBB   $0143
17d9: 01 9b           NEG    <$9B
17db: f0 02 44        SUBB   $0244
17de: 01 9b           NEG    <$9B
17e0: f0 03 48        SUBB   $0348
17e3: 01 9b           NEG    <$9B
17e5: e1 00           CMPB   $0,X
17e7: 00 50           NEG    <$50
17e9: 01 9d           NEG    <$9D
17eb: 1c 00           ANDCC  #$00
17ed: 4f              CLRA
17ee: 01 9d           NEG    <$9D
17f0: 20 00           BRA    $17F2
17f2: 46              RORA
17f3: 01 9d           NEG    <$9D
17f5: 24 00           BCC    $17F7
17f7: 53              COMB
17f8: 00 97           NEG    <$97
17fa: fc 00 42        LDD    >$0042
17fd: 01 9c           NEG    <$9C
17ff: 16 00 4f        LBRA   $1851
1802: 01 9c           NEG    <$9C
1804: 1c 00           ANDCC  #$00
1806: 48              ASLA
1807: 01 9c           NEG    <$9C
1809: 22 00           BHI    $180B
180b: 00 4e           NEG    <$4E
180d: 01 9c           NEG    <$9C
180f: bd 00 47        JSR    >$0047
1812: 01 9d           NEG    <$9D
1814: 01 03           NEG    <$03
1816: 43              COMA
1817: 01 9c           NEG    <$9C
1819: e3 04           ADDD   $4,X
181b: 53              COMB
181c: 01 9c           NEG    <$9C
181e: e3 0a           ADDD   $A,X
1820: 45              LSRA
1821: 00 98           NEG    <$98
1823: 43              COMA
1824: 50              NEGB
1825: 00 98           NEG    <$98
1827: 3d              MUL
1828: 41              NEGA
1829: 00 98           NEG    <$98
182b: 2d 00           BLT    $182D
182d: 50              NEGB
182e: 00 98           NEG    <$98
1830: 32 00           LEAS   $0,X
1832: 48              ASLA
1833: 01 9b           NEG    <$9B
1835: f0 00 4c        SUBB   >$004C
1838: 01 9b           NEG    <$9B
183a: f0 01 00        SUBB   $0100
183d: 45              LSRA
183e: 01 9c           NEG    <$9C
1840: 8d 00           BSR    $1842
1842: 00 41           NEG    <$41
1844: 01 9b           NEG    <$9B
1846: ff 00 42        STU    >$0042
1849: 01 9b           NEG    <$9B
184b: ff 01 43        STU    $0143
184e: 01 9b           NEG    <$9B
1850: ff 02 44        STU    $0244
1853: 01 9b           NEG    <$9B
1855: ff 03 00        STU    $0300
1858: 4d              TSTA
1859: 01 9c           NEG    <$9C
185b: b3 00 4f        SUBD   >$004F
185e: 01 9d           NEG    <$9D
1860: 14              XHCF
1861: 00 54           NEG    <$54
1863: 01 9d           NEG    <$9D
1865: 01 08           NEG    <$08
1867: 00 43           NEG    <$43
1869: 02 9c           XNC    <$9C
186b: a4 00           ANDA   $0,X
186d: 53              COMB
186e: 02 9c           XNC    <$9C
1870: ae 00           LDX    $0,X
1872: 52              XNCB
1873: 00 98           NEG    <$98
1875: 86 4d           LDA    #$4D
1877: 01 9c           NEG    <$9C
1879: e3 08           ADDD   $8,X
187b: 48              ASLA
187c: 00 98           NEG    <$98
187e: 80 00           SUBA   #$00
1880: 52              XNCB
1881: 01 9c           NEG    <$9C
1883: 8d 01           BSR    $1886
1885: 00 41           NEG    <$41
1887: 01 9b           NEG    <$9B
1889: eb 00           ADDB   $0,X
188b: 42              XNCA
188c: 01 9b           NEG    <$9B
188e: eb 01           ADDB   $1,X
1890: 43              COMA
1891: 01 9b           NEG    <$9B
1893: eb 02           ADDB   $2,X
1895: 44              LSRA
1896: 01 9b           NEG    <$9B
1898: eb 03           ADDB   $3,X
189a: 48              ASLA
189b: 01 9b           NEG    <$9B
189d: dc 00           LDD    <$00
189f: 00 4d           NEG    <$4D
18a1: 02 9c           XNC    <$9C
18a3: 9f 00           STX    <$00
18a5: 00 50           NEG    <$50
18a7: 01 9d           NEG    <$9D
18a9: 18              X18
18aa: 00 5a           NEG    <$5A
18ac: 01 9d           NEG    <$9D
18ae: 01 02           NEG    <$02
18b0: 52              XNCB
18b1: 00 98           NEG    <$98
18b3: b5 00 41        BITA   >$0041
18b6: 01 9c           NEG    <$9C
18b8: 34 00           PSHS   
18ba: 00 44           NEG    <$44
18bc: 01 9d           NEG    <$9D
18be: 2c 00           BGE    $18C0
18c0: 53              COMB
18c1: 01 9c           NEG    <$9C
18c3: b8 00 00        EORA   >$0000
18c6: 5a              DECB
18c7: 01 9d           NEG    <$9D
18c9: 01 01           NEG    <$01
18cb: 00 4f           NEG    <$4F
18cd: 01 9c           NEG    <$9C
18cf: e3 13           ADDD   -$D,X
18d1: 00 56           NEG    <$56
18d3: 01 9d           NEG    <$9D
18d5: 01 06           NEG    <$06
18d7: 53              COMB
18d8: 01 9d           NEG    <$9D
18da: 01 0a           NEG    <$0A
18dc: 00 53           NEG    <$53
18de: 01 9c           NEG    <$9C
18e0: e3 05           ADDD   $5,X
18e2: 00 4f           NEG    <$4F
18e4: 02 9c           XNC    <$9C
18e6: a9 00           ADCA   $0,X
18e8: 46              RORA
18e9: 01 9c           NEG    <$9C
18eb: e3 10           ADDD   -$10,X
18ed: 4e              XCLRA
18ee: 01 9c           NEG    <$9C
18f0: e3 11           ADDD   -$F,X
18f2: 43              COMA
18f3: 02 9c           XNC    <$9C
18f5: e3 0c           ADDD   $C,X
18f7: 00 52           NEG    <$52
18f9: 01 9c           NEG    <$9C
18fb: cc 00 53        LDD    #$0053
18fe: 01 9c           NEG    <$9C
1900: 7e 00 48        JMP    >$0048
1903: 00 99           NEG    <$99
1905: 16 43 01        LBRA   $5C09
1908: 9d 01           JSR    <$01
190a: 0b 4d           XDEC   <$4D
190c: 01 9c           NEG    <$9C
190e: e3 09           ADDD   $9,X
1910: 55              LSRB
1911: 01 9c           NEG    <$9C
1913: e3 0b           ADDD   $B,X
1915: 00 41           NEG    <$41
1917: 01 9b           NEG    <$9B
1919: fa 00 42        ORB    >$0042
191c: 01 9b           NEG    <$9B
191e: fa 01 43        ORB    $0143
1921: 01 9b           NEG    <$9B
1923: fa 02 44        ORB    $0244
1926: 01 9b           NEG    <$9B
1928: fa 03 48        ORB    $0348
192b: 01 9b           NEG    <$9B
192d: e6 00           LDB    $0,X
192f: 52              XNCB
1930: 01 9c           NEG    <$9C
1932: 8d 03           BSR    $1937
1934: 00 52           NEG    <$52
1936: 00 99           NEG    <$99
1938: 3a              ABX
1939: 00 45           NEG    <$45
193b: 01 9c           NEG    <$9C
193d: 6a 00           DEC    $0,X
193f: 00 53           NEG    <$53
1941: 00 99           NEG    <$99
1943: 77 4d 01        ASR    $4D01
1946: 9d 28           JSR    <$28
1948: 00 50           NEG    <$50
194a: 01 9c           NEG    <$9C
194c: 74 00 43        LSR    >$0043
194f: 01 9c           NEG    <$9C
1951: d1 00           CMPB   <$00
1953: 44              LSRA
1954: 01 9d           NEG    <$9D
1956: 01 04           NEG    <$04
1958: 41              NEGA
1959: 01 9c           NEG    <$9C
195b: e3 02           ADDD   $2,X
195d: 55              LSRB
195e: 00 99           NEG    <$99
1960: 62 00           XNC    $0,X
1962: 4e              XCLRA
1963: 00 99           NEG    <$99
1965: 67 00           ASR    $0,X
1967: 43              COMA
1968: 01 9c           NEG    <$9C
196a: 3a              ABX
196b: 00 4d           NEG    <$4D
196d: 01 9c           NEG    <$9C
196f: 46              RORA
1970: 00 53           NEG    <$53
1972: 01 9c           NEG    <$9C
1974: 40              NEGA
1975: 00 00           NEG    <$00
1977: 46              RORA
1978: 01 9d           NEG    <$9D
197a: 10 00 00        NEG    <$00
197d: 46              RORA
197e: 01 9c           NEG    <$9C
1980: 9a 00           ORA    <$00
1982: 4d              TSTA
1983: 01 9c           NEG    <$9C
1985: 79 00 56        ROL    >$0056
1988: 01 9c           NEG    <$9C
198a: c7 00           XSTB   #$00
198c: 43              COMA
198d: 01 9d           NEG    <$9D
198f: 01 09           NEG    <$09
1991: 49              ROLA
1992: 01 9c           NEG    <$9C
1994: e3 01           ADDD   $1,X
1996: 51              NEGB
1997: 01 9c           NEG    <$9C
1999: e3 06           ADDD   $6,X
199b: 48              ASLA
199c: 01 9c           NEG    <$9C
199e: e3 12           ADDD   -$E,X
19a0: 54              LSRB
19a1: 00 99           NEG    <$99
19a3: c3 42 00        ADDD   #$4200
19a6: 99 bd           ADCA   <$BD
19a8: 45              LSRA
19a9: 00 99           NEG    <$99
19ab: ad 00           JSR    $0,X
19ad: 51              NEGB
19ae: 00 99           NEG    <$99
19b0: b2 00 50        SBCA   >$0050
19b3: 01 9c           NEG    <$9C
19b5: 5e              XCLRB
19b6: 00 45           NEG    <$45
19b8: 01 9c           NEG    <$9C
19ba: 64 00           LSR    $0,X
19bc: 00 50           NEG    <$50
19be: 01 9c           NEG    <$9C
19c0: 52              XNCB
19c1: 00 00           NEG    <$00
19c3: 4f              CLRA
19c4: 00 99           NEG    <$99
19c6: d7 5f           STB    <$5F
19c8: 00 99           NEG    <$99
19ca: cc 00 49        LDD    #$0049
19cd: 00 99           NEG    <$99
19cf: d1 00           CMPB   <$00
19d1: 44              LSRA
19d2: 01 9d           NEG    <$9D
19d4: 30 00           LEAX   $0,X
19d6: 00 50           NEG    <$50
19d8: 01 9c           NEG    <$9C
19da: 4c              INCA
19db: 00 4e           NEG    <$4E
19dd: 01 9c           NEG    <$9C
19df: 52              XNCB
19e0: 00 46           NEG    <$46
19e2: 01 9c           NEG    <$9C
19e4: 58              ASLB
19e5: 00 00           NEG    <$00
19e7: 52              XNCB
19e8: 01 9c           NEG    <$9C
19ea: e3 03           ADDD   $3,X
19ec: 00 50           NEG    <$50
19ee: 01 9c           NEG    <$9C
19f0: c2 00           SBCB   #$00
19f2: 56              RORB
19f3: 01 9d           NEG    <$9D
19f5: 01 07           NEG    <$07
19f7: 00 4c           NEG    <$4C
19f9: 01 9d           NEG    <$9D
19fb: 01 05           NEG    <$05
19fd: 00 46           NEG    <$46
19ff: 00 9a           NEG    <$9A
1a01: 0d 53           TST    <$53
1a03: 00 9a           NEG    <$9A
1a05: 07 00           ASR    <$00
1a07: 51              NEGB
1a08: 01 9c           NEG    <$9C
1a0a: 95 00           BITA   <$00
1a0c: 00 41           NEG    <$41
1a0e: 01 9b           NEG    <$9B
1a10: f5 00 42        BITB   >$0042
1a13: 01 9b           NEG    <$9B
1a15: f5 01 43        BITB   $0143
1a18: 01 9b           NEG    <$9B
1a1a: f5 02 44        BITB   $0244
1a1d: 01 9b           NEG    <$9B
1a1f: f5 03 00        BITB   $0300
1a22: 3e              XRES
1a23: 01 9c           NEG    <$9C
1a25: 28 00           BVC    $1A27
1a27: 3c 01           CWAI   #$01
1a29: 9c 2e           CMPX   <$2E
1a2b: 00 25           NEG    <$25
1a2d: 01 9d           NEG    <$9D
1a2f: 01 0b           NEG    <$0B
1a31: 3f              SWI
1a32: 01 9c           NEG    <$9C
1a34: 6f 00           CLR    $0,X
1a36: 00 86           NEG    <$86
1a38: 3f              SWI
1a39: b7 09 00        STA    $0900
1a3c: b7 24 20        STA    $2420
1a3f: 39              RTS
; =====================================================================================
; Front-panel status-port LED helpers — $1A36-$1A88.
; Port $0900 is active-low: clear a bit = LED on, set a bit = LED off.
; Shadow register at $2420 keeps the software-side copy.
; Two groups of entry points:
;   "Clear" entries ($1A40-$1A57) → AND mask with $2420 → turn LED(s) ON.
;   "Set" entries ($1A5B-$1A76) → OR mask with $2420 → turn LED(s) OFF.
; Bit assignments (active-low, accent on the CLEAR/ON side):
;   Bit 0: serial poll status LED            clear=$1A4F  set=$1A6A
;   Bit 1: talk LED                          clear=$1A4B  set=$1A66
;   Bit 2: listen LED                        clear=$1A47  set=$1A62
;   Bit 3: remote/LLO LED                    clear=$1A40  set=$1A5B
;   Bit 4: unidentified LED 4                clear=$1A53  set=$1A6E
;   Bit 5: unidentified LED 5                clear=$1A57  set=$1A72
; $1A76 ($3F): turns LEDs 0-5 all OFF at once.
; $1A7D ($C0): turns LEDs 0-5 all ON (clears bits 0-5).
; $1A40 and $1A5B also call secondary helpers ($1EB9 and $1F45 respectively) before the update.
; =====================================================================================
1a40: bd 9e b9        JSR    $9EB9       ; → $1EB9: additional remote-state processing
1a43: 86 f7           LDA    #$F7        ; clear bit 3 (remote LED on)
1a45: 20 38           BRA    $1A7F
1a47: 86 fb           LDA    #$FB        ; clear bit 2 (listen LED on)
1a49: 20 34           BRA    $1A7F
1a4b: 86 fd           LDA    #$FD        ; clear bit 1 (talk LED on)
1a4d: 20 30           BRA    $1A7F
1a4f: 86 fe           LDA    #$FE        ; clear bit 0 (serial poll LED on)
1a51: 20 2c           BRA    $1A7F
1a53: 86 ef           LDA    #$EF        ; clear bit 4 (LED 4 on)
1a55: 20 28           BRA    $1A7F
1a57: 86 df           LDA    #$DF        ; clear bit 5 (LED 5 on)
1a59: 20 24           BRA    $1A7F
1a5b: bd 9f 45        JSR    $9F45       ; → $1F45: additional remote-state reset
1a5e: 86 08           LDA    #$08        ; set bit 3 (remote LED off)
1a60: 20 16           BRA    $1A78
1a62: 86 04           LDA    #$04        ; set bit 2 (listen LED off)
1a64: 20 12           BRA    $1A78
1a66: 86 02           LDA    #$02        ; set bit 1 (talk LED off)
1a68: 20 0e           BRA    $1A78
1a6a: 86 01           LDA    #$01        ; set bit 0 (serial poll LED off)
1a6c: 20 0a           BRA    $1A78
1a6e: 86 10           LDA    #$10        ; set bit 4 (LED 4 off)
1a70: 20 06           BRA    $1A78
1a72: 86 20           LDA    #$20        ; set bit 5 (LED 5 off)
1a74: 20 02           BRA    $1A78
1a76: 86 3f           LDA    #$3F        ; set bits 0-5 (all status LEDs off)
; "Set" common path: OR with shadow → bits high = LEDs off
1a78: ba 24 20        ORA    $2420       ; merge with shadow
1a7b: 20 05           BRA    $1A82       ; → write to port
; "Clear" all bits 0-5: turns all status LEDs ON
1a7d: 86 c0           LDA    #$C0        ; keep bits 6-7, clear 0-5
; "Clear" common path: AND with shadow → bits low = LEDs on
1a7f: b4 24 20        ANDA   $2420       ; merge with shadow
; Write to hardware and update shadow
1a82: b7 24 20        STA    $2420       ; update shadow register
1a85: b7 09 00        STA    $0900       ; write to status port hardware
1a88: 39              RTS
; Small request-flag helpers used by foreground state machines.
; $1A89: set $2281 bit 8 (high byte bit 0) → "dispatch pending request"
1a89: fc 22 81        LDD    $2281
1a8c: 8a 01           ORA    #$01        ; set bit 0 of high byte ($2281)
1a8e: fd 22 81        STD    $2281
1a91: 39              RTS
; $1A92: set $2281 bit 5 (low byte bit 5) → "unrecognized command / error"
1a92: fc 22 81        LDD    $2281
1a95: ca 20           ORB    #$20        ; set bit 5 of low byte ($2282)
1a97: fd 22 81        STD    $2281
1a9a: 39              RTS
; =====================================================================================
; Deferred HP-IB callback post — $1A9B.
; Entry: A = callback identifier byte.
; If A != 0: also sets $2281 bit 7 (forced single-shot mode).
; Stores A in $2280, then calls $1F9D to run the deferred-callback engine once.
; Returns Z=0 if the engine completed (B=0), Z=1 if it needs retry (B!=0).
; =====================================================================================
1a9b: 34 02           PSHS   A
1a9d: 27 08           BEQ    $1AA7       ; A == 0 → skip forced mode
1a9f: fc 22 81        LDD    $2281
1aa2: ca 80           ORB    #$80        ; set bit 7 (forced single-shot)
1aa4: fd 22 81        STD    $2281
1aa7: 35 02           PULS   A
1aa9: b7 22 80        STA    $2280       ; store callback identifier
1aac: 17 04 ee        LBSR   $1F9D       ; → $1F9D: run deferred-callback engine
1aaf: 5d              TSTB               ; result in B
1ab0: 26 04           BNE    $1AB6       ; nonzero → needs retry
1ab2: 1c fb           ANDCC  #$FB        ; Z=0 (success)
1ab4: 20 02           BRA    $1AB8
1ab6: 1a 04           ORCC   #$04        ; Z=1 (needs retry)
1ab8: 39              RTS
; =====================================================================================
; Install 4 handler-pointer pairs from U into the $2390-$2397 table — $1AB9.
; Entry: incoming Z flag controls whether to also set $2281 bit 2. Z=1 leaves bit 2 clear;
; Z=0 sets it.
; Copies 4 × 2-byte values from U to $2390..$2397, then sets $2281 bit 1 unconditionally
; and bit 2 if the incoming Z was clear.
; =====================================================================================
1ab9: 27 04           BEQ    $1ABF       ; Z=1 → B=$00
1abb: c6 ff           LDB    #$FF        ; Z=0 → B=$FF (flag for bit 2)
1abd: 20 02           BRA    $1AC1
1abf: c6 00           LDB    #$00
1ac1: 8e 23 90        LDX    #$2390      ; destination: handler-pointer table
1ac4: 86 04           LDA    #$04        ; 4 entries
1ac6: 37 20           PULU   Y           ; pull 2-byte pointer from U
1ac8: 10 af 81        STY    ,X++        ; store into table, advance X
1acb: 4a              DECA
1acc: 26 f8           BNE    $1AC6       ; loop 4 times
1ace: 5d              TSTB               ; should we set bit 2?
1acf: 27 08           BEQ    $1AD9       ; no → skip
1ad1: fc 22 81        LDD    $2281
1ad4: ca 04           ORB    #$04        ; set bit 2
1ad6: fd 22 81        STD    $2281
1ad9: fc 22 81        LDD    $2281
1adc: ca 02           ORB    #$02        ; set bit 1 (handler table updated)
1ade: fd 22 81        STD    $2281
1ae1: 39              RTS
; =====================================================================================
; P8291A init wrappers — $1AE2/$1AE6/$1B08.
; These build a descriptor and call $0F9F (P8291A register write sequence).
; $1AE2 (control=$80) and $1AE6 (control=$01):
;   Build a 5-byte descriptor on the stack: [control, $81, $BF, $227E, $227F].
;   In $0F9F, control bit 0 selects the full register-programming path; control bit 7 additionally
;   emits a trailing AUX $00 (Immediate Execute pon) after that setup.
;   $81 is descriptor byte 1 (normal addressed mode, low nibble 1, and the Aux-B feature pattern
;   derived from descriptor bits 7/6 inside $0F9F).
;   $BF and $227E become the event/SRQ-trigger mask pair copied into $2248/$2249.
;   $227F is the saved primary HP-IB address loaded into Address 0 during the normal path.
; $1B08: minimal 1-byte descriptor [00]; this takes the short path in $0F9F and only issues AUX $00.
; =====================================================================================
1ae2: c6 80           LDB    #$80        ; control bit 7 set: full setup + trailing AUX $00
1ae4: 20 02           BRA    $1AE8
1ae6: c6 01           LDB    #$01        ; control bit 0 set: full setup, no trailing AUX $00
1ae8: 34 40           PSHS   U           ; save caller's U
1aea: b6 22 7f        LDA    $227F       ; saved primary HP-IB address
1aed: 34 02           PSHS   A
1aef: b6 22 7e        LDA    $227E       ; saved SRQ-trigger mask byte
1af2: 34 02           PSHS   A
1af4: 86 bf           LDA    #$BF        ; event-mask high byte copied to $2248
1af6: 34 02           PSHS   A
1af8: 86 81           LDA    #$81        ; descriptor byte 1 used by $0F9F
1afa: 34 02           PSHS   A
1afc: 34 04           PSHS   B           ; control byte at top of descriptor
1afe: 33 e4           LEAU   ,S          ; U → descriptor
1b00: 17 f4 9c        LBSR   $0F9F       ; → $0F9F: P8291A register write sequence
1b03: 32 65           LEAS   $5,S        ; discard 5-byte descriptor
1b05: 35 40           PULS   U           ; restore U
1b07: 39              RTS
; Minimal P8291A reset wrapper
1b08: 34 40           PSHS   U
1b0a: 86 00           LDA    #$00        ; control = $00
1b0c: 34 02           PSHS   A
1b0e: 33 e4           LEAU   ,S          ; U → 1-byte descriptor
1b10: 17 f4 8c        LBSR   $0F9F       ; → $0F9F: P8291A register write sequence
1b13: 32 61           LEAS   $1,S        ; discard descriptor
1b15: 35 40           PULS   U
1b17: 39              RTS
; API-style wrappers around the local HP-IB driver.
; Called from other modules (including paged ROM) to poll, read/write shadow state,
; manipulate parser/event bits, and install transmit buffers without knowing local details.
; Each allocates a minimal stack frame via $7D50, delegates to one internal helper,
; and returns the result in B (0 or 1 for boolean queries).
;
;   $1B18 — poll P8291A once via $10D3; returns B=1 if no HP-IB event was pending
;   $1B31 — write $227E byte into SRQ-trigger mask $2249 via $1058
;   $1B40 — read SRQ-trigger mask $2249 via $1062; returns value in B
;   $1B50 — read primary serial-poll status $224A via $106A; returns value in B
;   $1B60 — set parser-event slot: A=slot, B=value → $1743
;   $1B70 — read parser-event slot: A=slot → $175E; returns value in B
;   $1B80 — run $1095 and return B=1 if it leaves shadow bit 4 clear
;   $1B96 — check software shadow bit 4 in $2247 via $10BD; returns B=1 if clear
;   $1BAC — parser mode control via $16B5: A=0 queries/resets, A!=0 forces active;
;           returns B=1 if parser was idle (or forced active)
1b18: cc 00 01        LDD    #$0001
1b1b: 17 62 32        LBSR   $7D50
1b1e: ce 22 7e        LDU    #$227E
1b21: 17 f5 af        LBSR   $10D3
1b24: 26 04           BNE    $1B2A
1b26: c6 01           LDB    #$01
1b28: 20 02           BRA    $1B2C
1b2a: c6 00           LDB    #$00
1b2c: e7 62           STB    $2,S
1b2e: 32 63           LEAS   $3,S
1b30: 39              RTS
; $1B31: write SRQ-trigger mask via $1058
1b31: cc 00 00        LDD    #$0000
1b34: 17 62 19        LBSR   $7D50
1b37: b6 22 7e        LDA    $227E
1b3a: 17 f5 1b        LBSR   $1058
1b3d: 32 62           LEAS   $2,S
1b3f: 39              RTS
; $1B40: read SRQ-trigger mask $2249 via $1062
1b40: cc 00 01        LDD    #$0001
1b43: 17 62 0a        LBSR   $7D50
1b46: 17 f5 19        LBSR   $1062
1b49: 1f 89           TFR    A,B
1b4b: e7 62           STB    $2,S
1b4d: 32 63           LEAS   $3,S
1b4f: 39              RTS
; $1B50: read primary serial-poll status $224A via $106A
1b50: cc 00 01        LDD    #$0001
1b53: 17 61 fa        LBSR   $7D50
1b56: 17 f5 11        LBSR   $106A
1b59: 1f 89           TFR    A,B
1b5b: e7 62           STB    $2,S
1b5d: 32 63           LEAS   $3,S
1b5f: 39              RTS
; $1B60: set parser-event slot (A=slot, B=value) via $1743
1b60: cc 00 00        LDD    #$0000
1b63: 17 61 ea        LBSR   $7D50
1b66: a6 67           LDA    $7,S
1b68: e6 69           LDB    $9,S
1b6a: 17 fb d6        LBSR   $1743
1b6d: 32 62           LEAS   $2,S
1b6f: 39              RTS
; $1B70: read parser-event slot (A=slot) via $175E
1b70: cc 00 01        LDD    #$0001
1b73: 17 61 da        LBSR   $7D50
1b76: a6 68           LDA    $8,S
1b78: 17 fb e3        LBSR   $175E
1b7b: e7 62           STB    $2,S
1b7d: 32 63           LEAS   $3,S
1b7f: 39              RTS
; $1B80: run $1095 and report whether shadow bit 4 ended clear
1b80: cc 00 01        LDD    #$0001
1b83: 17 61 ca        LBSR   $7D50
1b86: 17 f5 0c        LBSR   $1095
1b89: 27 04           BEQ    $1B8F
1b8b: c6 00           LDB    #$00
1b8d: 20 02           BRA    $1B91
1b8f: c6 01           LDB    #$01
1b91: e7 62           STB    $2,S
1b93: 32 63           LEAS   $3,S
1b95: 39              RTS
; $1B96: check software shadow bit 4 in $2247 via $10BD
1b96: cc 00 01        LDD    #$0001
1b99: 17 61 b4        LBSR   $7D50
1b9c: 17 f5 1e        LBSR   $10BD
1b9f: 27 04           BEQ    $1BA5
1ba1: c6 00           LDB    #$00
1ba3: 20 02           BRA    $1BA7
1ba5: c6 01           LDB    #$01
1ba7: e7 62           STB    $2,S
1ba9: 32 63           LEAS   $3,S
1bab: 39              RTS
; $1BAC: parser mode control via $16B5 (A=0 query/reset, A!=0 force active)
1bac: cc 00 01        LDD    #$0001
1baf: 17 61 9e        LBSR   $7D50
1bb2: a6 68           LDA    $8,S
1bb4: 17 fa fe        LBSR   $16B5
1bb7: 27 04           BEQ    $1BBD
1bb9: c6 00           LDB    #$00
1bbb: 20 02           BRA    $1BBF
1bbd: c6 01           LDB    #$01
1bbf: e7 62           STB    $2,S
1bc1: 32 63           LEAS   $3,S
1bc3: 39              RTS
; Commit a freshly prepared transmit buffer into the HP-IB driver.
; This pushes a 4-byte descriptor into $227E... and then enters the common buffer-install path.
; Trace fact: captured failing *IDN? runs reach the chained
; $1BC4 -> $1729 -> $16DA -> $1719 path, proving that some failures occur AFTER a reply buffer
; has been committed and AFTER at least one byte has been written to DOR.
1bc4: cc 00 00        LDD    #$0000
1bc7: 17 61 86        LBSR   $7D50
1bca: ce 22 7e        LDU    #$227E
1bcd: 4f              CLRA
1bce: 36 02           PSHU   A
1bd0: ae 66           LDX    $6,S
1bd2: a6 69           LDA    $9,S
1bd4: 36 12           PSHU   X,A
1bd6: 17 fb 50        LBSR   $1729
1bd9: 32 62           LEAS   $2,S
1bdb: 39              RTS
; =====================================================================================
; Request-posting stubs — $1BDC-$1CE2.
; Each entry loads a fixed request code into $2389 (and sometimes stores an auxiliary byte in
; $2219 or $23BE), then sets $2281 bit 0 so the active HP-IB foreground handler will forward the
; request to $0AD0 / $0D60.
; "Group A" stubs ($1BDC-$1C15): also store A in $23BE and call $421A before posting.
; "Group B" stubs ($1C16-$1CE2): post directly (some also store B in $2219).
; =====================================================================================
; Group A stubs (store $23BE, call $421A):
1bdc: 8e 00 28        LDX    #$0028      ; request type $0028
1bdf: 20 23           BRA    $1C04
1be1: 8e 00 29        LDX    #$0029      ; request type $0029
1be4: 20 1e           BRA    $1C04
1be6: 8e 00 2a        LDX    #$002A      ; request type $002A
1be9: 20 19           BRA    $1C04
1beb: 8e 00 19        LDX    #$0019      ; request type $0019
1bee: 20 14           BRA    $1C04
1bf0: 8e 00 1a        LDX    #$001A      ; request type $001A
1bf3: 20 0f           BRA    $1C04
1bf5: 8e 00 1b        LDX    #$001B      ; request type $001B
1bf8: 20 0a           BRA    $1C04
1bfa: 8e 00 1c        LDX    #$001C      ; request type $001C
1bfd: 20 05           BRA    $1C04
1bff: 8e 00 1d        LDX    #$001D      ; request type $001D
1c02: 20 00           BRA    $1C04
; Group A common: store aux byte, call helper, post request
1c04: b7 23 be        STA    $23BE       ; store auxiliary byte from A
1c07: bf 23 89        STX    $2389       ; store request type
1c0a: 17 26 0d        LBSR   $421A       ; → $421A: pre-dispatch helper
1c0d: fc 22 81        LDD    $2281
1c10: ca 01           ORB    #$01        ; set bit 0 → dispatch pending
1c12: fd 22 81        STD    $2281
1c15: 39              RTS
; Group B stubs (direct post, no $23BE / $421A):
1c16: 8e 00 39        LDX    #$0039      ; request type $0039
1c19: 16 00 bb        LBRA   $1CD7
1c1c: 8e 00 3a        LDX    #$003A
1c1f: 16 00 b5        LBRA   $1CD7
1c22: 8e 00 3b        LDX    #$003B
1c25: 16 00 af        LBRA   $1CD7
1c28: 8e 00 17        LDX    #$0017
1c2b: 16 00 a9        LBRA   $1CD7
1c2e: 8e 00 18        LDX    #$0018
1c31: 16 00 a3        LBRA   $1CD7
1c34: 8e 00 27        LDX    #$0027
1c37: 16 00 9d        LBRA   $1CD7
1c3a: 8e 00 2d        LDX    #$002D
1c3d: 16 00 97        LBRA   $1CD7
1c40: 8e 00 2e        LDX    #$002E
1c43: 16 00 91        LBRA   $1CD7
1c46: 8e 00 2f        LDX    #$002F
1c49: 16 00 8b        LBRA   $1CD7
1c4c: 8e 00 30        LDX    #$0030
1c4f: 16 00 85        LBRA   $1CD7
1c52: 8e 00 31        LDX    #$0031
1c55: 16 00 7f        LBRA   $1CD7
1c58: 8e 00 32        LDX    #$0032
1c5b: 16 00 79        LBRA   $1CD7
1c5e: 8e 00 33        LDX    #$0033
1c61: 16 00 73        LBRA   $1CD7
1c64: 8e 00 34        LDX    #$0034
1c67: 16 00 6d        LBRA   $1CD7
1c6a: 8e 00 36        LDX    #$0036
1c6d: 20 68           BRA    $1CD7
1c6f: 8e 00 25        LDX    #$0025
1c72: 20 63           BRA    $1CD7
1c74: 8e 00 08        LDX    #$0008
1c77: 20 5e           BRA    $1CD7
1c79: 8e 00 0e        LDX    #$000E
1c7c: 20 59           BRA    $1CD7
; Post request type $0007. Used by the ISR1 bit 3 path in $10D3 (device-clear-related handling).
1c7e: 8e 00 07        LDX    #$0007
1c81: 20 54           BRA    $1CD7
; Post request type $0024. Used by the ISR1 bit 5 path in $10D3 (GET-related handling).
1c83: 8e 00 24        LDX    #$0024
1c86: 20 4f           BRA    $1CD7
; Post request type $000D. Used by the transmit state machine at $16DA to request buffer refill.
1c88: 8e 00 0d        LDX    #$000D
1c8b: 20 4a           BRA    $1CD7
; Stubs with auxiliary byte in A → $2219:
1c8d: 8e 00 2b        LDX    #$002B      ; request type $002B
1c90: b7 22 19        STA    $2219       ; store A as auxiliary
1c93: 20 42           BRA    $1CD7
1c95: 8e 00 2c        LDX    #$002C
1c98: 20 3d           BRA    $1CD7
1c9a: 8e 00 05        LDX    #$0005
1c9d: 20 38           BRA    $1CD7
; Stubs with auxiliary byte in B → $2219 (via $1CD4):
1c9f: 8e 00 0a        LDX    #$000A
1ca2: 20 30           BRA    $1CD4
1ca4: 8e 00 12        LDX    #$0012
1ca7: 20 2b           BRA    $1CD4
1ca9: 8e 00 0f        LDX    #$000F
1cac: 20 26           BRA    $1CD4
1cae: 8e 00 0c        LDX    #$000C
1cb1: 20 21           BRA    $1CD4
; More direct-post stubs:
1cb3: 8e 00 0b        LDX    #$000B
1cb6: 20 1f           BRA    $1CD7
1cb8: 8e 00 1e        LDX    #$001E
1cbb: 20 1a           BRA    $1CD7
1cbd: 8e 00 1f        LDX    #$001F
1cc0: 20 15           BRA    $1CD7
1cc2: 8e 00 20        LDX    #$0020
1cc5: 20 10           BRA    $1CD7
1cc7: 8e 00 21        LDX    #$0021
1cca: 20 0b           BRA    $1CD7
1ccc: 8e 00 11        LDX    #$0011
1ccf: 20 06           BRA    $1CD7
1cd1: 8e 00 22        LDX    #$0022
; Common entry: store B in $2219 auxiliary, then fall through to post
1cd4: f7 22 19        STB    $2219       ; store B as auxiliary byte
; Group B common: post request
1cd7: bf 23 89        STX    $2389       ; store request type
1cda: fc 22 81        LDD    $2281
1cdd: ca 01           ORB    #$01        ; set bit 0 → dispatch pending
1cdf: fd 22 81        STD    $2281
1ce2: 39              RTS
; Post "class 0x10" work into the active HP-IB foreground handler:
; - $221F receives a small selector value derived from A/B
; - $2281 bit 4 is set so $273E will service it later
1ce3: 81 0c           CMPA   #$0C
1ce5: 26 0b           BNE    $1CF2
1ce7: 4f              CLRA
1ce8: 5a              DECB
1ce9: c1 03           CMPB   #$03
1ceb: 22 05           BHI    $1CF2
1ced: c3 00 0c        ADDD   #$000C
1cf0: 20 03           BRA    $1CF5
1cf2: 1f 89           TFR    A,B
1cf4: 4f              CLRA
1cf5: fd 22 1f        STD    $221F
1cf8: fc 22 81        LDD    $2281
1cfb: ca 10           ORB    #$10
1cfd: fd 22 81        STD    $2281
1d00: 39              RTS
; Post "class 0x08" work into the active HP-IB foreground handler:
; - $2221 receives the selector value
; - $2281 bit 3 is set so $273E will service it later
1d01: 1f 89           TFR    A,B
1d03: 4f              CLRA
1d04: fd 22 21        STD    $2221
1d07: fc 22 81        LDD    $2281
1d0a: ca 08           ORB    #$08
1d0c: fd 22 81        STD    $2281
1d0f: 39              RTS
; Thin entry-point trampolines called from paged ROM or other modules.
; Each simply forwards to one internal function and returns.
1d10: 17 06 60        LBSR   $2373       ; → $2373: numeric entry state query
1d13: 39              RTS
1d14: 17 06 26        LBSR   $233D       ; → $233D: numeric entry buffer readback
1d17: 39              RTS
1d18: 17 05 f3        LBSR   $230E       ; → $230E: numeric entry mode query
1d1b: 39              RTS
1d1c: 17 39 a9        LBSR   $56C8       ; → $56C8: display/UI state snapshot
1d1f: 39              RTS
1d20: 17 3e 39        LBSR   $5B5C       ; → $5B5C: enter idle watchdog timeout
1d23: 39              RTS
1d24: 17 3e 56        LBSR   $5B7D       ; → $5B7D: exit idle watchdog timeout
1d27: 39              RTS
1d28: 17 03 6f        LBSR   $209A       ; → $209A: status-byte reply formatter
1d2b: 39              RTS
1d2c: 17 06 71        LBSR   $23A0       ; → $23A0: numeric entry commit helper
1d2f: 39              RTS
1d30: 17 06 93        LBSR   $23C6       ; → $23C6: reset paged-data pointer
1d33: 39              RTS
; Clear the HP-IB request mailbox and reinitialize the P8291A from the default descriptor path.
1d34: fc a4 0c        LDD    $A40C
1d37: 17 60 16        LBSR   $7D50
1d3a: 5f              CLRB
1d3b: 4f              CLRA
1d3c: fd 22 81        STD    $2281
1d3f: ce 00 00        LDU    #$0000
1d42: 34 40           PSHS   U
1d44: 17 fd 9b        LBSR   $1AE2
1d47: 32 62           LEAS   $2,S
1d49: 32 62           LEAS   $2,S
1d4b: 39              RTS
; Poll wrapper around $10D3 that normalizes the return value into B=1 (no pending HP-IB event)
; or B=0 (one or more events were serviced).
1d4c: fc a4 0d        LDD    $A40D
1d4f: 17 5f fe        LBSR   $7D50
1d52: ce 00 00        LDU    #$0000
1d55: 34 40           PSHS   U
1d57: 17 fd be        LBSR   $1B18
1d5a: 32 62           LEAS   $2,S
1d5c: c1 00           CMPB   #$00
1d5e: 10 27 00 08     LBEQ   $1D6A
1d62: 6f 62           CLR    $2,S
1d64: 16 00 07        LBRA   $1D6E
1d67: 16 00 04        LBRA   $1D6E
1d6a: c6 01           LDB    #$01
1d6c: e7 62           STB    $2,S
1d6e: e6 62           LDB    $2,S
1d70: 32 63           LEAS   $3,S
1d72: 39              RTS
; Set SRQ-trigger mask from stack argument — $1D73.
; Stores the caller's byte argument into $227E, then calls $1B31 to write it to $2249
; (the SRQ-trigger mask) via $1058.
1d73: fc a4 0c        LDD    $A40C
1d76: 17 5f d7        LBSR   $7D50
1d79: e6 e9 00 07     LDB    $0007,S
1d7d: f7 22 7e        STB    $227E
1d80: ce 00 00        LDU    #$0000
1d83: 34 40           PSHS   U
1d85: 17 fd a9        LBSR   $1B31
1d88: 32 62           LEAS   $2,S
1d8a: 32 62           LEAS   $2,S
1d8c: 39              RTS
; Read SRQ-trigger mask — $1D8D.
; Returns the current value of $2249 in B via $1B40/$1062.
1d8d: fc a4 0d        LDD    $A40D
1d90: 17 5f bd        LBSR   $7D50
1d93: ce 00 00        LDU    #$0000
1d96: 34 40           PSHS   U
1d98: 17 fd a5        LBSR   $1B40
1d9b: 32 62           LEAS   $2,S
1d9d: e7 62           STB    $2,S
1d9f: 32 63           LEAS   $3,S
1da1: 39              RTS
; Read primary serial-poll status byte — $1DA2.
; Returns the current value of $224A in B via $1B50/$106A.
1da2: fc a4 0d        LDD    $A40D
1da5: 17 5f a8        LBSR   $7D50
1da8: ce 00 00        LDU    #$0000
1dab: 34 40           PSHS   U
1dad: 17 fd a0        LBSR   $1B50
1db0: 32 62           LEAS   $2,S
1db2: e7 62           STB    $2,S
1db4: 32 63           LEAS   $3,S
1db6: 39              RTS
; Wrapper around $1743: set one parsed HP-IB event/slot with an optional associated value.
1db7: fc a4 0c        LDD    $A40C
1dba: 17 5f 93        LBSR   $7D50
1dbd: 5f              CLRB
1dbe: 1d              SEX
1dbf: 1f 03           TFR    D,U
1dc1: 10 ae e9 00 06  LDY    $0006,S
1dc6: 8e 00 04        LDX    #$0004
1dc9: 34 70           PSHS   U,Y,X
1dcb: 17 fd 92        LBSR   $1B60
1dce: 32 66           LEAS   $6,S
1dd0: 32 62           LEAS   $2,S
1dd2: 39              RTS
; Wrapper around $1743 plus immediate readback via $175E.
; If X != $00FF it also updates $23DE with the caller's auxiliary selector byte before the set/read.
1dd3: fc a4 0c        LDD    $A40C
1dd6: 17 5f 77        LBSR   $7D50
1dd9: ae e9 00 08     LDX    $0008,S
1ddd: 8c 00 ff        CMPX   #$00FF
1de0: 10 27 00 07     LBEQ   $1DEB
1de4: e6 e9 00 09     LDB    $0009,S
1de8: f7 23 de        STB    $23DE
1deb: ee e9 00 08     LDU    $0008,S
1def: 10 ae e9 00 06  LDY    $0006,S
1df4: 8e 00 04        LDX    #$0004
1df7: 34 70           PSHS   U,Y,X
1df9: 17 fd 64        LBSR   $1B60
1dfc: 32 66           LEAS   $6,S
1dfe: ee e9 00 06     LDU    $0006,S
1e02: 10 8e 00 02     LDY    #$0002
1e06: 34 60           PSHS   U,Y
1e08: 8d ad           BSR    $1DB7
1e0a: 32 64           LEAS   $4,S
1e0c: 32 62           LEAS   $2,S
1e0e: 39              RTS
; Clear serial-poll/status shadow state through $1072.
1e0f: fc a4 0c        LDD    $A40C
1e12: 17 5f 3b        LBSR   $7D50
1e15: ce 00 00        LDU    #$0000
1e18: 34 40           PSHS   U
1e1a: 17 f2 55        LBSR   $1072
1e1d: 32 62           LEAS   $2,S
1e1f: 32 62           LEAS   $2,S
1e21: 39              RTS
; Query whether the helper behind $1095 reports that the current HP-IB command/handshake state is idle.
; On success this also clears $2281 bit 6, which is the deferred-callback gate used by $1F9D.
1e22: fc a4 0d        LDD    $A40D
1e25: 17 5f 28        LBSR   $7D50
1e28: ce 00 00        LDU    #$0000
1e2b: 34 40           PSHS   U
1e2d: 17 fd 50        LBSR   $1B80
1e30: 32 62           LEAS   $2,S
1e32: c1 00           CMPB   #$00
1e34: 10 27 00 12     LBEQ   $1E4A
1e38: fc 22 81        LDD    $2281
1e3b: 84 ff           ANDA   #$FF
1e3d: c4 bf           ANDB   #$BF
1e3f: fd 22 81        STD    $2281
1e42: 6f 62           CLR    $2,S
1e44: 16 00 07        LBRA   $1E4E
1e47: 16 00 04        LBRA   $1E4E
1e4a: c6 01           LDB    #$01
1e4c: e7 62           STB    $2,S
1e4e: e6 62           LDB    $2,S
1e50: 32 63           LEAS   $3,S
1e52: 39              RTS
; Query whether auxiliary-command $04 handling ($10C9) is complete/idle.
1e53: fc a4 0d        LDD    $A40D
1e56: 17 5e f7        LBSR   $7D50
1e59: ce 00 00        LDU    #$0000
1e5c: 34 40           PSHS   U
1e5e: 17 fd 35        LBSR   $1B96
1e61: 32 62           LEAS   $2,S
1e63: c1 00           CMPB   #$00
1e65: 10 27 00 08     LBEQ   $1E71
1e69: 6f 62           CLR    $2,S
1e6b: 16 00 07        LBRA   $1E75
1e6e: 16 00 04        LBRA   $1E75
1e71: c6 01           LDB    #$01
1e73: e7 62           STB    $2,S
1e75: e6 62           LDB    $2,S
1e77: 32 63           LEAS   $3,S
1e79: 39              RTS
; Issue P8291A AUX command $04 (Trigger) — $1E7A.
; Calls $10C9 to write AUX command $04 to the P8291A.
1e7a: fc a4 0c        LDD    $A40C
1e7d: 17 5e d0        LBSR   $7D50
1e80: ce 00 00        LDU    #$0000
1e83: 34 40           PSHS   U
1e85: 17 f2 41        LBSR   $10C9
1e88: 32 62           LEAS   $2,S
1e8a: 32 62           LEAS   $2,S
1e8c: 39              RTS
; Wrapper around $1BAC: query whether the parser/command-input state is complete.
1e8d: fc a4 0d        LDD    $A40D
1e90: 17 5e bd        LBSR   $7D50
1e93: ee e9 00 07     LDU    $0007,S
1e97: 10 8e 00 02     LDY    #$0002
1e9b: 34 60           PSHS   U,Y
1e9d: 17 fd 0c        LBSR   $1BAC
1ea0: 32 64           LEAS   $4,S
1ea2: c1 00           CMPB   #$00
1ea4: 10 27 00 08     LBEQ   $1EB0
1ea8: 6f 62           CLR    $2,S
1eaa: 16 00 07        LBRA   $1EB4
1ead: 16 00 04        LBRA   $1EB4
1eb0: c6 01           LDB    #$01
1eb2: e7 62           STB    $2,S
1eb4: e6 62           LDB    $2,S
1eb6: 32 63           LEAS   $3,S
1eb8: 39              RTS
; Foreground HP-IB housekeeping entry.
; This raises $2204 bit 3, conditionally posts status events 0x0C/0x0D, runs $338B, and then
; clears $2202 bit 3. If $2204 bit 4 is set afterwards it also calls $59C6.
1eb9: fc a4 0c        LDD    $A40C
1ebc: 17 5e 91        LBSR   $7D50
1ebf: fc 22 04        LDD    $2204
1ec2: 8a 00           ORA    #$00
1ec4: ca 08           ORB    #$08
1ec6: fd 22 04        STD    $2204
1ec9: fc 22 04        LDD    $2204
1ecc: 84 00           ANDA   #$00
1ece: c4 20           ANDB   #$20
1ed0: 10 83 00 00     CMPD   #$0000
1ed4: 10 27 00 14     LBEQ   $1EEC
1ed8: c6 0c           LDB    #$0C
1eda: 1d              SEX
1edb: 1f 03           TFR    D,U
1edd: c6 01           LDB    #$01
1edf: 1d              SEX
1ee0: 1f 02           TFR    D,Y
1ee2: 8e 00 04        LDX    #$0004
1ee5: 34 70           PSHS   U,Y,X
1ee7: 17 fe e9        LBSR   $1DD3
1eea: 32 66           LEAS   $6,S
1eec: fc 22 04        LDD    $2204
1eef: 84 00           ANDA   #$00
1ef1: c4 40           ANDB   #$40
1ef3: 10 83 00 00     CMPD   #$0000
1ef7: 10 27 00 14     LBEQ   $1F0F
1efb: c6 0d           LDB    #$0D
1efd: 1d              SEX
1efe: 1f 03           TFR    D,U
1f00: c6 04           LDB    #$04
1f02: 1d              SEX
1f03: 1f 02           TFR    D,Y
1f05: 8e 00 04        LDX    #$0004
1f08: 34 70           PSHS   U,Y,X
1f0a: 17 fe c6        LBSR   $1DD3
1f0d: 32 66           LEAS   $6,S
1f0f: c6 01           LDB    #$01
1f11: 1d              SEX
1f12: 1f 03           TFR    D,U
1f14: 10 8e 00 02     LDY    #$0002
1f18: 34 60           PSHS   U,Y
1f1a: 17 14 6e        LBSR   $338B
1f1d: 32 64           LEAS   $4,S
1f1f: fc 22 02        LDD    $2202
1f22: 84 ff           ANDA   #$FF
1f24: c4 f7           ANDB   #$F7
1f26: fd 22 02        STD    $2202
1f29: fc 22 04        LDD    $2204
1f2c: 84 00           ANDA   #$00
1f2e: c4 10           ANDB   #$10
1f30: 10 83 00 00     CMPD   #$0000
1f34: 10 27 00 0a     LBEQ   $1F42
1f38: ce 00 00        LDU    #$0000
1f3b: 34 40           PSHS   U
1f3d: 17 3a 86        LBSR   $59C6
1f40: 32 62           LEAS   $2,S
1f42: 32 62           LEAS   $2,S
1f44: 39              RTS
; Reset a subset of HP-IB foreground state:
; - clear $2204 bit 3
; - clear serial-poll/status shadow state
; - clear the numeric-response formatter busy flag ($238F)
; - clear $2202 bit 3
; - if $2204 bit 4 is set, call $59C6
; Finally queues request type 1.
1f45: fc a4 0c        LDD    $A40C
1f48: 17 5e 05        LBSR   $7D50
1f4b: fc 22 04        LDD    $2204
1f4e: 84 ff           ANDA   #$FF
1f50: c4 f7           ANDB   #$F7
1f52: fd 22 04        STD    $2204
1f55: ce 00 00        LDU    #$0000
1f58: 34 40           PSHS   U
1f5a: 17 fe b2        LBSR   $1E0F
1f5d: 32 62           LEAS   $2,S
1f5f: ce 00 00        LDU    #$0000
1f62: 34 40           PSHS   U
1f64: 17 05 0b        LBSR   $2472
1f67: 32 62           LEAS   $2,S
1f69: fc 22 02        LDD    $2202
1f6c: 84 ff           ANDA   #$FF
1f6e: c4 f7           ANDB   #$F7
1f70: fd 22 02        STD    $2202
1f73: fc 22 04        LDD    $2204
1f76: 84 00           ANDA   #$00
1f78: c4 10           ANDB   #$10
1f7a: 10 83 00 00     CMPD   #$0000
1f7e: 10 27 00 0a     LBEQ   $1F8C
1f82: ce 00 00        LDU    #$0000
1f85: 34 40           PSHS   U
1f87: 17 3a 3c        LBSR   $59C6
1f8a: 32 62           LEAS   $2,S
1f8c: ce 00 01        LDU    #$0001
1f8f: 10 8e 00 02     LDY    #$0002
1f93: 34 60           PSHS   U,Y
1f95: 17 eb 38        LBSR   $0AD0
1f98: 32 64           LEAS   $4,S
1f9a: 32 62           LEAS   $2,S
1f9c: 39              RTS
; =====================================================================================
; Deferred HP-IB callback engine — $1F9D.
; If $2281 bit 6 is set, executes the callback function pointer at $2283 with $2280 as argument.
; The callback returns success (B=0) or failure (B!=0).
;   Success: clears bits 6 and 7 of $2281 (callback complete, no retry).
;   Failure with bit 7 clear: leaves $2281 unchanged → retry on next call.
;   Failure with bit 7 set (forced single-shot): still clears bits 6+7 → no retry.
; Returns B from the stack frame (0 = success, nonzero = needs retry).
; =====================================================================================
1f9d: fc a4 0f        LDD    $A40F       ; frame size from ROM
1fa0: 17 5d ad        LBSR   $7D50       ; allocate stack frame
1fa3: 6f 62           CLR    $2,S        ; local result = 0
; Check if callback is armed
1fa5: fc 22 81        LDD    $2281
1fa8: 84 00           ANDA   #$00
1faa: c4 40           ANDB   #$40        ; isolate bit 6
1fac: 10 83 00 00     CMPD   #$0000
1fb0: 10 27 00 43     LBEQ   $1FF7       ; not armed → return 0
; Armed: call the callback at [$2283] with $2280 as argument
1fb4: f6 22 80        LDB    $2280       ; callback argument
1fb7: 4f              CLRA
1fb8: 1f 03           TFR    D,U
1fba: 10 8e 00 02     LDY    #$0002
1fbe: 34 60           PSHS   U,Y
1fc0: be 22 83        LDX    $2283       ; load callback function pointer
1fc3: ad 84           JSR    ,X          ; call it
1fc5: 32 64           LEAS   $4,S
1fc7: e7 62           STB    $2,S        ; save result
; Check result
1fc9: e6 62           LDB    $2,S
1fcb: c1 00           CMPB   #$00
1fcd: 10 27 00 12     LBEQ   $1FE3       ; success → clear armed bits
; Failure: check forced single-shot mode
1fd1: fc 22 81        LDD    $2281
1fd4: 84 00           ANDA   #$00
1fd6: c4 80           ANDB   #$80        ; isolate bit 7 (forced mode)
1fd8: 10 83 00 00     CMPD   #$0000
1fdc: 10 26 00 03     LBNE   $1FE3       ; forced → clear anyway
1fe0: 16 00 14        LBRA   $1FF7       ; not forced → leave armed for retry
; Clear callback-armed bits
1fe3: fc 22 81        LDD    $2281
1fe6: 84 ff           ANDA   #$FF
1fe8: c4 7f           ANDB   #$7F        ; clear bit 7 (forced mode)
1fea: fd 22 81        STD    $2281
1fed: fc 22 81        LDD    $2281
1ff0: 84 ff           ANDA   #$FF
1ff2: c4 bf           ANDB   #$BF        ; clear bit 6 (callback armed)
1ff4: fd 22 81        STD    $2281
; Return
1ff7: e6 62           LDB    $2,S        ; load result
1ff9: e7 63           STB    $3,S        ; store into return position
1ffb: 32 64           LEAS   $4,S        ; deallocate frame
1ffd: 39              RTS
; Stage an HP-IB transmit-buffer descriptor in $2385/$2387.
; Inputs are passed on the stack as:
; - pointer -> stored in $2385
; - length  -> stored in $2387
; Special case: if the buffer pointer is $2285 (the common scratch response buffer), append the
; two bytes at $EAEF/$EAF0, which appear to be CR/LF terminators for generated ASCII replies.
; This helper also sets $2204 bit 1 to mark "buffer descriptor ready".
1ffe: fc a4 0c        LDD    $A40C
2001: 17 5d 4c        LBSR   $7D50
2004: ec e9 00 06     LDD    $0006,S     ; arg 1: buffer pointer
2008: fd 23 85        STD    $2385       ; store in staged descriptor
200b: e6 e9 00 09     LDB    $0009,S     ; arg 2: byte count
200f: f7 23 87        STB    $2387       ; store in staged descriptor
; If buffer is the common scratch area at $2285, append CR/LF from ROM
2012: ae e9 00 06     LDX    $0006,S
2016: 8c 22 85        CMPX   #$2285      ; is this the scratch response buffer?
2019: 10 26 00 28     LBNE   $2045       ; no → skip line ending
; Append first terminator byte ($EAEF → probably CR)
201d: f6 23 87        LDB    $2387       ; current count (also index for next byte)
2020: b6 23 87        LDA    $2387
2023: 8b 01           ADDA   #$01        ; increment count
2025: b7 23 87        STA    $2387
2028: 8e 22 85        LDX    #$2285
202b: 3a              ABX               ; X = $2285 + old count
202c: f6 ea ef        LDB    $EAEF       ; ROM byte (CR)
202f: e7 84           STB    ,X          ; append to buffer
; Append second terminator byte ($EAF0 → probably LF)
2031: f6 23 87        LDB    $2387
2034: b6 23 87        LDA    $2387
2037: 8b 01           ADDA   #$01        ; increment count again
2039: b7 23 87        STA    $2387
203c: 8e 22 85        LDX    #$2285
203f: 3a              ABX               ; X = $2285 + new count - 1
2040: f6 ea f0        LDB    $EAF0       ; ROM byte (LF)
2043: e7 84           STB    ,X          ; append to buffer
; Mark descriptor as ready
2045: fc 22 04        LDD    $2204
2048: 8a 02           ORA    #$02        ; set $2204 bit 1 (high byte): buffer descriptor ready
204a: ca 00           ORB    #$00
204c: fd 22 04        STD    $2204
204f: 32 62           LEAS   $2,S
2051: 39              RTS
; Request type 0x0D handler: install the currently staged HP-IB transmit buffer into the live
; transmitter state at $2265-$2268. If nothing has staged a descriptor yet, seed it with the ROM
; string at $EAE4 ("? No Data ?" followed by the usual line ending).
2052: fc a4 0c        LDD    $A40C
2055: 17 5c f8        LBSR   $7D50
; Check if a buffer descriptor has been staged ($2204 bit 1 high-byte)
2058: fc 22 04        LDD    $2204
205b: 84 02           ANDA   #$02        ; test bit 1 of high byte
205d: c4 00           ANDB   #$00
205f: 10 83 00 00     CMPD   #$0000
2063: 10 26 00 12     LBNE   $2079       ; staged → use it
; No staged buffer: seed with ROM error string "? No Data ?" at $EAE4
2067: c6 0d           LDB    #$0D        ; length = 13
2069: 1d              SEX
206a: 1f 03           TFR    D,U
206c: 10 8e ea e4     LDY    #$EAE4      ; ROM string pointer
2070: 8e 00 04        LDX    #$0004
2073: 34 70           PSHS   U,Y,X
2075: 8d 87           BSR    $1FFE       ; stage this default buffer
2077: 32 66           LEAS   $6,S
; Install staged descriptor into live transmitter state via $1BC4
2079: f6 23 87        LDB    $2387       ; byte count from descriptor
207c: 4f              CLRA
207d: 1f 03           TFR    D,U
207f: 10 be 23 85     LDY    $2385       ; pointer from descriptor
2083: 8e 00 04        LDX    #$0004
2086: 34 70           PSHS   U,Y,X
2088: 17 fb 39        LBSR   $1BC4       ; → $1BC4: install into $2265-$2268 live tx state
208b: 32 66           LEAS   $6,S
; Fixed ROM patch: replace the vulnerable 16-bit read-modify-write with a byte-only high-byte
; update so BO IRQ cannot be lost by a stale low-byte write-back.
208d: b6 22 04        LDA    $2204       ; load only high byte
2090: 84 fd           ANDA   #$FD        ; clear bit 1 of high byte
2092: b7 22 04        STA    $2204       ; store only high byte
2095: 21 2e           BRN    $20C5       ; filler only; never branches, chosen to keep checksum unchanged
2097: 32 62           LEAS   $2,S
2099: 39              RTS
; Read the $2249 HP-IB status/shadow byte through the wrapper at $1D8D, format it into ASCII in
; the common scratch buffer at $2285, then stage a 3-character HP-IB reply via $1FFE.
; =====================================================================================
; HP-IB status-byte reply formatter — $209A.
; Reads the current status/shadow byte from $1D8D, formats it as a 3-character ASCII
; decimal string into the scratch buffer at $2285 using $49D1 (binary-to-ASCII helper),
; then stages the 3-byte reply via $1FFE for HP-IB transmission.
; =====================================================================================
209a: fc a4 0d        LDD    $A40D
209d: 17 5c b0        LBSR   $7D50
20a0: ce 00 00        LDU    #$0000
20a3: 34 40           PSHS   U
20a5: 17 fc e5        LBSR   $1D8D       ; → read $2249 status/shadow byte
20a8: 32 62           LEAS   $2,S
20aa: e7 62           STB    $2,S        ; save result in local
; Format the byte as ASCII decimal into $2285
20ac: ce 22 85        LDU    #$2285      ; destination: scratch buffer
20af: e6 62           LDB    $2,S        ; value to format
20b1: 4f              CLRA
20b2: 1f 02           TFR    D,Y         ; Y = value (as 16-bit)
20b4: 8e 00 04        LDX    #$0004
20b7: 34 70           PSHS   U,Y,X
20b9: 17 29 15        LBSR   $49D1       ; → $49D1: binary to ASCII decimal conversion
20bc: 32 66           LEAS   $6,S
; Stage the 3-character string as an HP-IB transmit reply
20be: c6 03           LDB    #$03        ; 3 characters
20c0: 1d              SEX
20c1: 1f 03           TFR    D,U
20c3: 10 8e 22 85     LDY    #$2285      ; buffer pointer
20c7: 8e 00 04        LDX    #$0004
20ca: 34 70           PSHS   U,Y,X
20cc: 17 ff 2f        LBSR   $1FFE       ; → $1FFE: stage transmit buffer descriptor
20cf: 32 66           LEAS   $6,S
20d1: 32 63           LEAS   $3,S
20d3: 39              RTS
; Likely commit a newly-entered HP-IB address from the numeric-entry buffer at $239A.
; Verified behavior:
; - Only takes the special path when the current request type is $0023
; - Parses the ASCII digits, accepts only values in the range 0..30
; - On success stores the address in $227F and calls $1D34 to reinitialize HP-IB state
; - On failure posts a UI/message path instead of committing
; The UI strings loaded by $21A4 make the "HP-IB address" interpretation very likely.
20d4: fc a4 11        LDD    $A411
20d7: 17 5c 76        LBSR   $7D50
20da: 6f 63           CLR    $3,S
20dc: be 22 17        LDX    $2217
20df: 8c 00 23        CMPX   #$0023
20e2: 10 26 00 a1     LBNE   $2187
20e6: c6 01           LDB    #$01
20e8: e7 63           STB    $3,S
20ea: c6 03           LDB    #$03
20ec: 1d              SEX
20ed: 1f 03           TFR    D,U
20ef: 10 8e 00 02     LDY    #$0002
20f3: 34 60           PSHS   U,Y
20f5: 17 11 2b        LBSR   $3223
20f8: 32 64           LEAS   $4,S
20fa: c1 00           CMPB   #$00
20fc: 10 27 00 87     LBEQ   $2187
2100: ce 23 9a        LDU    #$239A
2103: 10 8e 00 02     LDY    #$0002
2107: 34 60           PSHS   U,Y
2109: 17 29 2a        LBSR   $4A36
210c: 32 64           LEAS   $4,S
210e: e7 62           STB    $2,S
2110: e6 62           LDB    $2,S
2112: c1 00           CMPB   #$00
2114: 10 2d 00 0b     LBLT   $2123
2118: e6 62           LDB    $2,S
211a: c1 1e           CMPB   #$1E
211c: 10 2e 00 03     LBGT   $2123
2120: 16 00 03        LBRA   $2126
2123: 16 00 12        LBRA   $2138
2126: e6 62           LDB    $2,S
2128: f7 22 7f        STB    $227F
212b: ce 00 00        LDU    #$0000
212e: 34 40           PSHS   U
2130: 17 fc 01        LBSR   $1D34
2133: 32 62           LEAS   $2,S
2135: 16 00 4f        LBRA   $2187
2138: c6 03           LDB    #$03
213a: 1d              SEX
213b: 1f 03           TFR    D,U
213d: 10 8e 00 02     LDY    #$0002
2141: 34 60           PSHS   U,Y
2143: 17 22 b8        LBSR   $43FE
2146: 32 64           LEAS   $4,S
2148: ce ed 11        LDU    #$ED11
214b: c6 02           LDB    #$02
214d: 1d              SEX
214e: 1f 02           TFR    D,Y
2150: c6 10           LDB    #$10
2152: 1d              SEX
2153: 1f 01           TFR    D,X
2155: cc 00 06        LDD    #$0006
2158: 34 76           PSHS   U,Y,X,D
215a: 17 37 48        LBSR   $58A5
215d: 32 68           LEAS   $8,S
215f: c6 10           LDB    #$10
2161: 1d              SEX
2162: 1f 03           TFR    D,U
2164: 10 8e 00 02     LDY    #$0002
2168: c6 10           LDB    #$10
216a: 1d              SEX
216b: 1f 01           TFR    D,X
216d: c6 02           LDB    #$02
216f: 1d              SEX
2170: 34 76           PSHS   U,Y,X,D
2172: ce 00 00        LDU    #$0000
2175: 10 8e 00 0a     LDY    #$000A
2179: 34 60           PSHS   U,Y
217b: 17 0a b7        LBSR   $2C35
217e: 32 6c           LEAS   $C,S
2180: c6 01           LDB    #$01
2182: e7 64           STB    $4,S
2184: 16 00 18        LBRA   $219F
2187: fc 22 02        LDD    $2202
218a: 84 ff           ANDA   #$FF
218c: c4 f7           ANDB   #$F7
218e: fd 22 02        STD    $2202
2191: ce 00 00        LDU    #$0000
2194: 34 40           PSHS   U
2196: 17 38 2d        LBSR   $59C6
2199: 32 62           LEAS   $2,S
219b: e6 63           LDB    $3,S
219d: e7 64           STB    $4,S
219f: e6 64           LDB    $4,S
21a1: 32 65           LEAS   $5,S
21a3: 39              RTS
; Set up the front-panel/UI state for editing the HP-IB address.
; This builds display text from the ROM strings at $EAF1 and $EB19, inserts the current address
; value from $227F into the editable field, then installs $20D4 as the state-specific callback in
; $220D and sets $2202 bit 3 so $0D60 will consult that callback before dispatch.
21a4: fc a4 0c        LDD    $A40C
21a7: 17 5b a6        LBSR   $7D50
21aa: fc 22 04        LDD    $2204
21ad: 8a 00           ORA    #$00
21af: ca 10           ORB    #$10
21b1: fd 22 04        STD    $2204
21b4: ce ea f1        LDU    #$EAF1
21b7: c6 28           LDB    #$28
21b9: 1d              SEX
21ba: 1f 02           TFR    D,Y
21bc: 5f              CLRB
21bd: 1d              SEX
21be: 1f 01           TFR    D,X
21c0: cc 00 06        LDD    #$0006
21c3: 34 76           PSHS   U,Y,X,D
21c5: 17 36 dd        LBSR   $58A5
21c8: 32 68           LEAS   $8,S
21ca: ce eb 19        LDU    #$EB19
21cd: c6 28           LDB    #$28
21cf: 1d              SEX
21d0: 1f 02           TFR    D,Y
21d2: c6 40           LDB    #$40
21d4: 1d              SEX
21d5: 1f 01           TFR    D,X
21d7: cc 00 06        LDD    #$0006
21da: 34 76           PSHS   U,Y,X,D
21dc: 17 36 c6        LBSR   $58A5
21df: 32 68           LEAS   $8,S
21e1: ce 24 14        LDU    #$2414
21e4: f6 22 7f        LDB    $227F
21e7: 4f              CLRA
21e8: 1f 02           TFR    D,Y
21ea: 8e 00 04        LDX    #$0004
21ed: 34 70           PSHS   U,Y,X
21ef: 17 27 df        LBSR   $49D1
21f2: 32 66           LEAS   $6,S
21f4: ce 24 15        LDU    #$2415
21f7: c6 02           LDB    #$02
21f9: 1d              SEX
21fa: 1f 02           TFR    D,Y
21fc: c6 10           LDB    #$10
21fe: 1d              SEX
21ff: 1f 01           TFR    D,X
2201: cc 00 06        LDD    #$0006
2204: 34 76           PSHS   U,Y,X,D
2206: 17 36 9c        LBSR   $58A5
2209: 32 68           LEAS   $8,S
220b: c6 10           LDB    #$10
220d: 1d              SEX
220e: 1f 03           TFR    D,U
2210: 10 8e 00 02     LDY    #$0002
2214: c6 10           LDB    #$10
2216: 1d              SEX
2217: 1f 01           TFR    D,X
2219: c6 02           LDB    #$02
221b: 1d              SEX
221c: 34 76           PSHS   U,Y,X,D
221e: ce 00 00        LDU    #$0000
2221: 10 8e 00 0a     LDY    #$000A
2225: 34 60           PSHS   U,Y
2227: 17 0a 0b        LBSR   $2C35
222a: 32 6c           LEAS   $C,S
222c: cc a0 d4        LDD    #$A0D4
222f: fd 22 0d        STD    $220D
2232: fc 22 02        LDD    $2202
2235: 8a 00           ORA    #$00
2237: ca 08           ORB    #$08
2239: fd 22 02        STD    $2202
223c: 32 62           LEAS   $2,S
223e: 39              RTS
; Another state-specific callback entry selected through $220D.
; This validates numeric input for a special request-$0023 path and either posts event 0x13 on
; success or event 0x0F on failure, then clears $2202 bit 3. Exact UI ownership is still uncertain.
223f: fc a4 13        LDD    $A413
2242: 17 5b 0b        LBSR   $7D50
2245: be 22 17        LDX    $2217
2248: 8c 00 23        CMPX   #$0023
224b: 10 26 00 1c     LBNE   $226B
224f: c6 06           LDB    #$06
2251: 1d              SEX
2252: 1f 03           TFR    D,U
2254: 10 8e 00 00     LDY    #$0000
2258: 8e 00 04        LDX    #$0004
225b: 34 70           PSHS   U,Y,X
225d: 17 2b 81        LBSR   $4DE1
2260: 32 66           LEAS   $6,S
2262: c1 04           CMPB   #$04
2264: 10 2c 00 03     LBGE   $226B
2268: 16 00 03        LBRA   $226E
226b: 16 00 51        LBRA   $22BF
226e: ce 24 14        LDU    #$2414
2271: 10 8e 00 02     LDY    #$0002
2275: 34 60           PSHS   U,Y
2277: 17 26 f9        LBSR   $4973
227a: 32 64           LEAS   $4,S
227c: ed 62           STD    $2,S
227e: ae 62           LDX    $2,S
2280: 8c 00 00        CMPX   #$0000
2283: 10 25 00 0c     LBCS   $2293
2287: ae 62           LDX    $2,S
2289: 8c 00 ff        CMPX   #$00FF
228c: 10 22 00 03     LBHI   $2293
2290: 16 00 03        LBRA   $2296
2293: 16 00 13        LBRA   $22A9
2296: e6 63           LDB    $3,S
2298: 4f              CLRA
2299: 1f 03           TFR    D,U
229b: 10 8e 00 02     LDY    #$0002
229f: 34 60           PSHS   U,Y
22a1: 17 fa cf        LBSR   $1D73
22a4: 32 64           LEAS   $4,S
22a6: 16 00 13        LBRA   $22BC
22a9: c6 13           LDB    #$13
22ab: 1d              SEX
22ac: 1f 03           TFR    D,U
22ae: 5f              CLRB
22af: 1d              SEX
22b0: 1f 02           TFR    D,Y
22b2: 8e 00 04        LDX    #$0004
22b5: 34 70           PSHS   U,Y,X
22b7: 17 fb 19        LBSR   $1DD3
22ba: 32 66           LEAS   $6,S
22bc: 16 00 13        LBRA   $22D2
22bf: c6 0f           LDB    #$0F
22c1: 1d              SEX
22c2: 1f 03           TFR    D,U
22c4: 5f              CLRB
22c5: 1d              SEX
22c6: 1f 02           TFR    D,Y
22c8: 8e 00 04        LDX    #$0004
22cb: 34 70           PSHS   U,Y,X
22cd: 17 fb 03        LBSR   $1DD3
22d0: 32 66           LEAS   $6,S
22d2: fc 22 02        LDD    $2202
22d5: 84 ff           ANDA   #$FF
22d7: c4 f7           ANDB   #$F7
22d9: fd 22 02        STD    $2202
22dc: cc 00 01        LDD    #$0001
22df: ed 64           STD    $4,S
22e1: 32 66           LEAS   $6,S
22e3: 39              RTS
; Generic numeric-entry UI setup — $22E4.
; Initializes the numeric-response formatter via $2415 with mode=0 and selector=0 (no sign prefix,
; basic validation). Installs $223F as the state-specific callback at $220D and sets $2202 bit 3
; so $0D60 will route through that callback before dispatch.
; Compare $21A4 which is the HP-IB-address-specific version of the same pattern.
22e4: fc a4 0c        LDD    $A40C
22e7: 17 5a 66        LBSR   $7D50
22ea: ce 00 00        LDU    #$0000       ; formatter mode = 0
22ed: 10 8e 00 00     LDY    #$0000       ; validation selector = 0
22f1: 8e 00 04        LDX    #$0004
22f4: 34 70           PSHS   U,Y,X
22f6: 17 01 1c        LBSR   $2415        ; init formatter state ($238D/$238B/buffer)
22f9: 32 66           LEAS   $6,S
22fb: cc a2 3f        LDD    #$A23F       ; callback = $223F (generic numeric validator)
22fe: fd 22 0d        STD    $220D        ; install as state callback
2301: fc 22 02        LDD    $2202
2304: 8a 00           ORA    #$00
2306: ca 08           ORB    #$08         ; set bit 3: route dispatch through $220D callback
2308: fd 22 02        STD    $2202
230b: 32 62           LEAS   $2,S
230d: 39              RTS
; Format the auxiliary HP-IB byte saved in $23DE into the scratch reply buffer and stage a
; 3-character response through $1FFE.
230e: fc a4 0c        LDD    $A40C
2311: 17 5a 3c        LBSR   $7D50
2314: ce 22 85        LDU    #$2285
2317: f6 23 de        LDB    $23DE
231a: 4f              CLRA
231b: 1f 02           TFR    D,Y
231d: 8e 00 04        LDX    #$0004
2320: 34 70           PSHS   U,Y,X
2322: 17 26 ac        LBSR   $49D1
2325: 32 66           LEAS   $6,S
2327: c6 03           LDB    #$03
2329: 1d              SEX
232a: 1f 03           TFR    D,U
232c: 10 8e 22 85     LDY    #$2285
2330: 8e 00 04        LDX    #$0004
2333: 34 70           PSHS   U,Y,X
2335: 17 fc c6        LBSR   $1FFE
2338: 32 66           LEAS   $6,S
233a: 32 62           LEAS   $2,S
233c: 39              RTS
; Fetch one runtime value through $5C14, format it into the scratch reply buffer at $2285, then
; stage that 3-character reply for HP-IB transmission.
233d: fc a4 0c        LDD    $A40C
2340: 17 5a 0d        LBSR   $7D50
2343: ce 00 00        LDU    #$0000
2346: 34 40           PSHS   U
2348: 17 38 c9        LBSR   $5C14
234b: 32 62           LEAS   $2,S
234d: ce 22 85        LDU    #$2285
2350: 4f              CLRA
2351: 1f 02           TFR    D,Y
2353: 8e 00 04        LDX    #$0004
2356: 34 70           PSHS   U,Y,X
2358: 17 26 76        LBSR   $49D1
235b: 32 66           LEAS   $6,S
235d: c6 03           LDB    #$03
235f: 1d              SEX
2360: 1f 03           TFR    D,U
2362: 10 8e 22 85     LDY    #$2285
2366: 8e 00 04        LDX    #$0004
2369: 34 70           PSHS   U,Y,X
236b: 17 fc 90        LBSR   $1FFE
236e: 32 66           LEAS   $6,S
2370: 32 62           LEAS   $2,S
2372: 39              RTS
; Format the 16-bit value at $23C1 into the scratch reply buffer and stage a 5-character HP-IB
; response through $1FFE.
2373: fc a4 0c        LDD    $A40C
2376: 17 59 d7        LBSR   $7D50
2379: ce 22 85        LDU    #$2285
237c: 10 be 23 c1     LDY    $23C1
2380: 8e 00 04        LDX    #$0004
2383: 34 70           PSHS   U,Y,X
2385: 17 25 8a        LBSR   $4912
2388: 32 66           LEAS   $6,S
238a: c6 05           LDB    #$05
238c: 1d              SEX
238d: 1f 03           TFR    D,U
238f: 10 8e 22 85     LDY    #$2285
2393: 8e 00 04        LDX    #$0004
2396: 34 70           PSHS   U,Y,X
2398: 17 fc 63        LBSR   $1FFE
239b: 32 66           LEAS   $6,S
239d: 32 62           LEAS   $2,S
239f: 39              RTS
; Rebuild the standard scratch buffer via $0000 and stage its first $50 bytes as an HP-IB reply.
; This looks like a bulk status/banner dump rather than a short numeric response.
23a0: fc a4 0c        LDD    $A40C
23a3: 17 59 aa        LBSR   $7D50
23a6: ce 00 00        LDU    #$0000
23a9: 34 40           PSHS   U
23ab: 17 dc 52        LBSR   $0000
23ae: 32 62           LEAS   $2,S
23b0: c6 50           LDB    #$50
23b2: 1d              SEX
23b3: 1f 03           TFR    D,U
23b5: 10 8e 22 85     LDY    #$2285
23b9: 8e 00 04        LDX    #$0004
23bc: 34 70           PSHS   U,Y,X
23be: 17 fc 3d        LBSR   $1FFE
23c1: 32 66           LEAS   $6,S
23c3: 32 62           LEAS   $2,S
23c5: 39              RTS
; Reset paged-data pointer and flag — $23C6.
; Stores $3FFD into the word at $221C via the helper at $537D, then clears $3FFC.
; $221C is used by the input dispatch chain; $3FFC appears to be a related busy/pending flag.
; The specific meaning of value $3FFD is not yet determined (tentative: page-base address or
; jump-table anchor within the paged ROM region).
23c6: fc a4 0c        LDD    $A40C
23c9: 17 59 84        LBSR   $7D50
23cc: ce 22 1c        LDU    #$221C       ; destination address
23cf: 10 8e 3f fd     LDY    #$3FFD       ; value to store
23d3: 8e 00 04        LDX    #$0004
23d6: 34 70           PSHS   U,Y,X
23d8: 17 2f a2        LBSR   $537D        ; store word Y at address U
23db: 32 66           LEAS   $6,S
23dd: 7f 3f fc        CLR    $3FFC        ; clear associated flag
23e0: 32 62           LEAS   $2,S
23e2: 39              RTS
; Install a deferred HP-IB callback:
; - callback function pointer -> $2283
; - set $2281 bit 6 so $1F9D will run it
; The callback itself is expected to accept one byte in $2280 as an argument.
23e3: fc a4 0c        LDD    $A40C
23e6: 17 59 67        LBSR   $7D50
23e9: ec e9 00 06     LDD    $0006,S
23ed: fd 22 83        STD    $2283
23f0: 5f              CLRB
23f1: 1d              SEX
23f2: 1f 03           TFR    D,U
23f4: 10 8e 00 02     LDY    #$0002
23f8: 34 60           PSHS   U,Y
23fa: 17 fa 90        LBSR   $1E8D
23fd: 32 64           LEAS   $4,S
23ff: fc 22 81        LDD    $2281
2402: 8a 00           ORA    #$00
2404: ca 40           ORB    #$40
2406: fd 22 81        STD    $2281
2409: 32 62           LEAS   $2,S
240b: 39              RTS
240c: 00 00           NEG    <$00
240e: 01 00           NEG    <$00
2410: 02 00           XNC    <$00
2412: 03 00           COM    <$00
2414: 04 fc           LSR    <$FC
; Actual entry is $2418; the bytes at $2414-$2417 are frame/metadata, not code.
;
; Initialize the signed numeric-response formatter state used by the active HP-IB foreground handler.
; Verified state variables:
; - $238D: formatting mode selector
; - $238B: validation/routing selector
; - $239A..$23A3: ASCII output buffer, cleared to spaces here
; - $23A4: current character count/prefix length
; - $238F: formatter busy flag (set here, cleared by $2472)
; If $238D == 2 the formatter seeds the buffer with a leading '+' and sets the length to 1.
2416: a9 9b           ADCA   [D,X]
2418: 17 59 35        LBSR   $7D50
241b: ec e9 00 07     LDD    $0007,S
241f: fd 23 8d        STD    $238D
2422: ec e9 00 09     LDD    $0009,S
2426: fd 23 8b        STD    $238B
2429: 6f 62           CLR    $2,S
242b: e6 62           LDB    $2,S
242d: c1 0a           CMPB   #$0A
242f: 10 24 00 12     LBCC   $2445
2433: 8e 23 9a        LDX    #$239A
2436: e6 62           LDB    $2,S
2438: 3a              ABX
2439: c6 20           LDB    #$20
243b: e7 84           STB    ,X
243d: e6 62           LDB    $2,S
243f: cb 01           ADDB   #$01
2441: e7 62           STB    $2,S
2443: 20 e6           BRA    $242B
2445: be 23 8d        LDX    $238D
2448: 16 00 13        LBRA   $245E
244b: c6 2b           LDB    #$2B
244d: f7 23 9a        STB    $239A
2450: c6 01           LDB    #$01
2452: f7 23 a4        STB    $23A4
2455: 16 00 0d        LBRA   $2465
2458: 7f 23 a4        CLR    $23A4
245b: 16 00 07        LBRA   $2465
245e: 8c 00 02        CMPX   #$0002
2461: 27 e8           BEQ    $244B
2463: 20 f3           BRA    $2458
2465: 5f              CLRB
2466: 4f              CLRA
2467: fd 22 81        STD    $2281
246a: c6 01           LDB    #$01
246c: f7 23 8f        STB    $238F
246f: 32 63           LEAS   $3,S
2471: 39              RTS
; Clear the numeric-response formatter busy flag ($238F).
2472: fc a9 9d        LDD    $A99D
2475: 17 58 d8        LBSR   $7D50
2478: 7f 23 8f        CLR    $238F
247b: 32 62           LEAS   $2,S
247d: 39              RTS
; Convert internal numeric state at $2390/$2397 into ASCII text in $239A...
; The exact physical quantity is not yet proven, but this routine is clearly a formatter:
; - extracts magnitude/sign information from $2397 and option bits in $2390
; - emits '+' or '-' when required
; - converts a small integer value to ASCII digits in $239A...
; - leaves the resulting character count in $23A4
; - returns B=1 on success, B=0 on range/format failure
247e: fc a9 9e        LDD    $A99E
2481: 17 58 cc        LBSR   $7D50
2484: f6 23 97        LDB    $2397
2487: c4 0f           ANDB   #$0F
2489: 4f              CLRA
248a: f7 23 88        STB    $2388
248d: f6 23 90        LDB    $2390
2490: c4 01           ANDB   #$01
2492: 10 27 00 06     LBEQ   $249C
2496: 73 23 88        COM    $2388
2499: 7c 23 88        INC    $2388
249c: f6 23 97        LDB    $2397
249f: 4f              CLRA
24a0: 84 00           ANDA   #$00
24a2: c4 f0           ANDB   #$F0
24a4: 10 83 00 00     CMPD   #$0000
24a8: 10 26 00 18     LBNE   $24C4
24ac: f6 23 88        LDB    $2388
24af: c1 05           CMPB   #$05
24b1: 10 2e 00 0f     LBGT   $24C4
24b5: f6 23 88        LDB    $2388
24b8: 1d              SEX
24b9: 10 83 ff fa     CMPD   #$FFFA
24bd: 10 2d 00 03     LBLT   $24C4
24c1: 16 00 05        LBRA   $24C9
24c4: 6f 6d           CLR    $D,S
24c6: 16 00 f2        LBRA   $25BB
24c9: be 23 8d        LDX    $238D
24cc: 16 00 45        LBRA   $2514
24cf: 7f 23 a4        CLR    $23A4
24d2: f6 23 90        LDB    $2390
24d5: c4 02           ANDB   #$02
24d7: 10 27 00 05     LBEQ   $24E0
24db: 6f 6d           CLR    $D,S
24dd: 16 00 db        LBRA   $25BB
24e0: c6 08           LDB    #$08
24e2: e7 64           STB    $4,S
24e4: 16 00 3e        LBRA   $2525
24e7: f6 23 90        LDB    $2390
24ea: c4 02           ANDB   #$02
24ec: 10 27 00 08     LBEQ   $24F8
24f0: c6 2d           LDB    #$2D
24f2: f7 23 9a        STB    $239A
24f5: 16 00 05        LBRA   $24FD
24f8: c6 2b           LDB    #$2B
24fa: f7 23 9a        STB    $239A
24fd: c6 01           LDB    #$01
24ff: f7 23 a4        STB    $23A4
2502: c6 07           LDB    #$07
2504: e7 64           STB    $4,S
2506: 7c 23 88        INC    $2388
2509: 16 00 19        LBRA   $2525
250c: 6f 6d           CLR    $D,S
250e: 16 00 aa        LBRA   $25BB
2511: 16 00 11        LBRA   $2525
2514: 8c 00 00        CMPX   #$0000
2517: 27 b6           BEQ    $24CF
2519: 8c 00 02        CMPX   #$0002
251c: 27 c9           BEQ    $24E7
251e: 8c 00 03        CMPX   #$0003
2521: 27 ac           BEQ    $24CF
2523: 20 e7           BRA    $250C
2525: c6 01           LDB    #$01
2527: e7 62           STB    $2,S
2529: 6f 63           CLR    $3,S
252b: e6 62           LDB    $2,S
252d: c1 05           CMPB   #$05
252f: 10 24 00 52     LBCC   $2585
2533: e6 63           LDB    $3,S
2535: a6 63           LDA    $3,S
2537: 8b 01           ADDA   #$01
2539: a7 63           STA    $3,S
253b: 30 65           LEAX   $5,S
253d: 3a              ABX
253e: ce 23 90        LDU    #$2390
2541: e6 62           LDB    $2,S
2543: 4f              CLRA
2544: 33 cb           LEAU   D,U
2546: e6 c4           LDB    ,U
2548: af 6e           STX    $E,S
254a: 1f 01           TFR    D,X
254c: c6 fc           LDB    #$FC
254e: 17 5a 53        LBSR   $7FA4
2551: 8a 00           ORA    #$00
2553: ca 30           ORB    #$30
2555: e7 f8 0e        STB    [$0E,S]
2558: e6 63           LDB    $3,S
255a: e7 e8 10        STB    $10,S
255d: e6 63           LDB    $3,S
255f: cb 01           ADDB   #$01
2561: e7 63           STB    $3,S
2563: 33 65           LEAU   $5,S
2565: e6 e8 10        LDB    $10,S
2568: 4f              CLRA
2569: 33 cb           LEAU   D,U
256b: 10 8e 23 90     LDY    #$2390
256f: e6 62           LDB    $2,S
2571: 31 ab           LEAY   D,Y
2573: e6 a4           LDB    ,Y
2575: c4 0f           ANDB   #$0F
2577: 8a 00           ORA    #$00
2579: ca 30           ORB    #$30
257b: e7 c4           STB    ,U
257d: e6 62           LDB    $2,S
257f: cb 01           ADDB   #$01
2581: e7 62           STB    $2,S
2583: 20 a6           BRA    $252B
2585: 6f 62           CLR    $2,S
2587: f6 23 a4        LDB    $23A4
258a: c1 08           CMPB   #$08
258c: 10 24 00 22     LBCC   $25B2
2590: 8e 23 9a        LDX    #$239A
2593: f6 23 a4        LDB    $23A4
2596: 3a              ABX
2597: 33 65           LEAU   $5,S
2599: e6 62           LDB    $2,S
259b: 4f              CLRA
259c: 33 cb           LEAU   D,U
259e: e6 c4           LDB    ,U
25a0: e7 84           STB    ,X
25a2: f6 23 a4        LDB    $23A4
25a5: cb 01           ADDB   #$01
25a7: f7 23 a4        STB    $23A4
25aa: e6 62           LDB    $2,S
25ac: cb 01           ADDB   #$01
25ae: e7 62           STB    $2,S
25b0: 20 d5           BRA    $2587
25b2: e6 64           LDB    $4,S
25b4: f7 23 a4        STB    $23A4
25b7: c6 01           LDB    #$01
25b9: e7 6d           STB    $D,S
25bb: e6 6d           LDB    $D,S
25bd: 32 e8 11        LEAS   $11,S
25c0: 39              RTS
; Validate/translate selector $238B into a small mode value in $2221.
; Current decoding shows only two accepted cases:
; - $238B == 0 -> $2221 = $0010
; - $238B == 1 -> $2221 = $000C
; Other values fail and return B=0.
25c1: fc a9 9b        LDD    $A99B
25c4: 17 57 89        LBSR   $7D50
25c7: be 23 8b        LDX    $238B
25ca: 16 00 22        LBRA   $25EF
25cd: cc 00 0c        LDD    #$000C
25d0: fd 22 21        STD    $2221
25d3: c6 01           LDB    #$01
25d5: e7 62           STB    $2,S
25d7: 16 00 21        LBRA   $25FB
25da: cc 00 10        LDD    #$0010
25dd: fd 22 21        STD    $2221
25e0: c6 01           LDB    #$01
25e2: e7 62           STB    $2,S
25e4: 16 00 14        LBRA   $25FB
25e7: 6f 62           CLR    $2,S
25e9: 16 00 0f        LBRA   $25FB
25ec: 16 00 0c        LBRA   $25FB
25ef: 8c 00 00        CMPX   #$0000
25f2: 27 e6           BEQ    $25DA
25f4: 8c 00 01        CMPX   #$0001
25f7: 27 d4           BEQ    $25CD
25f9: 20 ec           BRA    $25E7
25fb: e6 62           LDB    $2,S
25fd: 32 63           LEAS   $3,S
25ff: 39              RTS
; Apply a mask test derived from:
; - a bit-position selector in $2220
; - a formatting mode in $238D
; - a lookup table at $F014
; Returns B=1 if the selected condition passes, else B=0.
; Exact user-facing meaning of this gate is still uncertain.
2600: fc a9 a0        LDD    $A9A0
2603: 17 57 4a        LBSR   $7D50
2606: c6 10           LDB    #$10
2608: e7 63           STB    $3,S
260a: cc f0 14        LDD    #$F014
260d: ed 64           STD    $4,S
260f: f6 22 20        LDB    $2220
2612: ae 64           LDX    $4,S
2614: 3a              ABX
2615: e6 84           LDB    ,X
2617: e7 62           STB    $2,S
2619: be 23 8d        LDX    $238D
261c: 16 00 0b        LBRA   $262A
261f: 64 63           LSR    $3,S
2621: 64 63           LSR    $3,S
2623: 64 63           LSR    $3,S
2625: 64 63           LSR    $3,S
2627: 16 00 17        LBRA   $2641
262a: 8c 00 04        CMPX   #$0004
262d: 27 f4           BEQ    $2623
262f: 8c 00 05        CMPX   #$0005
2632: 27 f1           BEQ    $2625
2634: 8c 00 06        CMPX   #$0006
2637: 27 e6           BEQ    $261F
2639: 8c 00 07        CMPX   #$0007
263c: 27 e3           BEQ    $2621
263e: 16 00 00        LBRA   $2641
2641: e6 63           LDB    $3,S
2643: e4 62           ANDB   $2,S
2645: 10 27 00 0a     LBEQ   $2653
2649: c6 01           LDB    #$01
264b: e7 66           STB    $6,S
264d: 16 00 05        LBRA   $2655
2650: 16 00 02        LBRA   $2655
2653: 6f 66           CLR    $6,S
2655: e6 66           LDB    $6,S
2657: 32 67           LEAS   $7,S
2659: 39              RTS
; Secondary validator for the same numeric-response path.
; This checks the mode value in $2221 against a small set that depends on $238B and returns
; B=1 when the combination is accepted, B=0 otherwise.
265a: fc a9 9b        LDD    $A99B
265d: 17 56 f0        LBSR   $7D50
2660: be 23 8b        LDX    $238B
2663: 16 00 b4        LBRA   $271A
2666: c6 01           LDB    #$01
2668: e7 62           STB    $2,S
266a: 16 00 cc        LBRA   $2739
266d: be 22 21        LDX    $2221
2670: 16 00 0f        LBRA   $2682
2673: c6 01           LDB    #$01
2675: e7 62           STB    $2,S
2677: 16 00 bf        LBRA   $2739
267a: 6f 62           CLR    $2,S
267c: 16 00 ba        LBRA   $2739
267f: 16 00 0c        LBRA   $268E
2682: 8c 00 03        CMPX   #$0003
2685: 27 ec           BEQ    $2673
2687: 8c 00 04        CMPX   #$0004
268a: 27 e7           BEQ    $2673
268c: 20 ec           BRA    $267A
268e: be 22 21        LDX    $2221
2691: 16 00 0f        LBRA   $26A3
2694: c6 01           LDB    #$01
2696: e7 62           STB    $2,S
2698: 16 00 9e        LBRA   $2739
269b: 6f 62           CLR    $2,S
269d: 16 00 99        LBRA   $2739
26a0: 16 00 11        LBRA   $26B4
26a3: 8c 00 05        CMPX   #$0005
26a6: 27 ec           BEQ    $2694
26a8: 8c 00 06        CMPX   #$0006
26ab: 27 e7           BEQ    $2694
26ad: 8c 00 07        CMPX   #$0007
26b0: 27 e2           BEQ    $2694
26b2: 20 e7           BRA    $269B
26b4: be 22 21        LDX    $2221
26b7: 16 00 0f        LBRA   $26C9
26ba: c6 01           LDB    #$01
26bc: e7 62           STB    $2,S
26be: 16 00 78        LBRA   $2739
26c1: 6f 62           CLR    $2,S
26c3: 16 00 73        LBRA   $2739
26c6: 16 00 0c        LBRA   $26D5
26c9: 8c 00 09        CMPX   #$0009
26cc: 27 ec           BEQ    $26BA
26ce: 8c 00 0a        CMPX   #$000A
26d1: 27 e7           BEQ    $26BA
26d3: 20 ec           BRA    $26C1
26d5: be 22 21        LDX    $2221
26d8: 16 00 0f        LBRA   $26EA
26db: c6 01           LDB    #$01
26dd: e7 62           STB    $2,S
26df: 16 00 57        LBRA   $2739
26e2: 6f 62           CLR    $2,S
26e4: 16 00 52        LBRA   $2739
26e7: 16 00 0c        LBRA   $26F6
26ea: 8c 00 01        CMPX   #$0001
26ed: 27 ec           BEQ    $26DB
26ef: 8c 00 02        CMPX   #$0002
26f2: 27 e7           BEQ    $26DB
26f4: 20 ec           BRA    $26E2
26f6: be 22 21        LDX    $2221
26f9: 16 00 0f        LBRA   $270B
26fc: c6 01           LDB    #$01
26fe: e7 62           STB    $2,S
2700: 16 00 36        LBRA   $2739
2703: 6f 62           CLR    $2,S
2705: 16 00 31        LBRA   $2739
2708: 16 00 07        LBRA   $2712
270b: 8c 00 0b        CMPX   #$000B
270e: 27 ec           BEQ    $26FC
2710: 20 f1           BRA    $2703
2712: 6f 62           CLR    $2,S
2714: 16 00 22        LBRA   $2739
2717: 16 00 1f        LBRA   $2739
271a: 8c 00 07        CMPX   #$0007
271d: 2e f3           BGT    $2712
271f: 1f 10           TFR    X,D
2721: 83 00 02        SUBD   #$0002
2724: 2d ec           BLT    $2712
2726: 8e a7 2d        LDX    #$A72D
2729: 58              ASLB
272a: 49              ROLA
272b: 6e 9b           JMP    [D,X]
272d: a6 66           LDA    $6,S
272f: a6 6d           LDA    $D,S
2731: a6 8e           LDA    W,X
2733: a6 b4           LDA    [,Y]
2735: a6 d5           LDA    [B,U]
2737: a6 f6           LDA    [A,S]
2739: e6 62           LDB    $2,S
273b: 32 63           LEAS   $3,S
273d: 39              RTS
; Active HP-IB foreground handler selected by $24E6 while bus activity is enabled.
; Verified responsibilities:
; - Calls $1D4C -> $1B18 -> $10D3 to poll and service the P8291A
; - Re-enables IRQs in foreground with $5D00 after deferred processing
; - Forwards request bits from $2281 into queued request types via $0AD0
; - Runs several additional request-specific service paths for codes posted in $2281
; Some of the secondary request meanings are still being decoded, but this is clearly the
; "bus active" counterpart to the idle handler at $0D23.
273e: fc a9 9d        LDD    $A99D
2741: 17 56 0c        LBSR   $7D50
2744: ce 00 00        LDU    #$0000
2747: 34 40           PSHS   U
2749: 17 f6 00        LBSR   $1D4C
274c: 32 62           LEAS   $2,S
274e: fc 22 02        LDD    $2202
2751: 84 00           ANDA   #$00
2753: c4 02           ANDB   #$02
2755: 10 83 00 00     CMPD   #$0000
2759: 10 27 00 08     LBEQ   $2765
275d: be 23 98        LDX    $2398
2760: ad 84           JSR    ,X
2762: 16 02 33        LBRA   $2998
2765: ce 00 00        LDU    #$0000
2768: 34 40           PSHS   U
276a: 17 35 93        LBSR   $5D00
276d: 32 62           LEAS   $2,S
; $2281 bit 0: a ready-to-dispatch request type is already sitting in $2389.
276f: fc 22 81        LDD    $2281
2772: 84 00           ANDA   #$00
2774: c4 01           ANDB   #$01
2776: 10 83 00 00     CMPD   #$0000
277a: 10 27 00 18     LBEQ   $2796
277e: fc 22 81        LDD    $2281
2781: 84 ff           ANDA   #$FF
2783: c4 fe           ANDB   #$FE
2785: fd 22 81        STD    $2281
2788: fe 23 89        LDU    $2389
278b: 10 8e 00 02     LDY    #$0002
278f: 34 60           PSHS   U,Y
2791: 17 e3 3c        LBSR   $0AD0
2794: 32 64           LEAS   $4,S
; $2281 bit 2: clear bits 2 and 1, reset the numeric-response formatter busy flag, then post
; event/request slot $29 through $1DD3.
2796: fc 22 81        LDD    $2281
2799: 84 00           ANDA   #$00
279b: c4 04           ANDB   #$04
279d: 10 83 00 00     CMPD   #$0000
27a1: 10 27 00 31     LBEQ   $27D6
27a5: fc 22 81        LDD    $2281
27a8: 84 ff           ANDA   #$FF
27aa: c4 fb           ANDB   #$FB
27ac: fd 22 81        STD    $2281
27af: fc 22 81        LDD    $2281
27b2: 84 ff           ANDA   #$FF
27b4: c4 fd           ANDB   #$FD
27b6: fd 22 81        STD    $2281
27b9: ce 00 00        LDU    #$0000
27bc: 34 40           PSHS   U
27be: 17 fc b1        LBSR   $2472
27c1: 32 62           LEAS   $2,S
27c3: c6 29           LDB    #$29
27c5: 1d              SEX
27c6: 1f 03           TFR    D,U
27c8: 5f              CLRB
27c9: 1d              SEX
27ca: 1f 02           TFR    D,Y
27cc: 8e 00 04        LDX    #$0004
27cf: 34 70           PSHS   U,Y,X
27d1: 17 f5 ff        LBSR   $1DD3
27d4: 32 66           LEAS   $6,S
; $2281 bit 1: first numeric-response/validation work class.
; If $238F says formatter state exists, try:
;   $247E -> format ASCII into $239A...
;   $25C1 -> validate/translate selector state
; Success posts request $23 to the main dispatcher; failure posts event $2A or $2B via $1DD3.
; If $238F is clear, the failure path goes straight to $2B.
27d6: fc 22 81        LDD    $2281
27d9: 84 00           ANDA   #$00
27db: c4 02           ANDB   #$02
27dd: 10 83 00 00     CMPD   #$0000
27e1: 10 27 00 81     LBEQ   $2866
27e5: fc 22 81        LDD    $2281
27e8: 84 ff           ANDA   #$FF
27ea: c4 fd           ANDB   #$FD
27ec: fd 22 81        STD    $2281
27ef: f6 23 8f        LDB    $238F
27f2: c1 00           CMPB   #$00
27f4: 10 27 00 5b     LBEQ   $2853
27f8: ce 00 00        LDU    #$0000
27fb: 34 40           PSHS   U
27fd: 17 fc 7e        LBSR   $247E
2800: 32 62           LEAS   $2,S
2802: c1 00           CMPB   #$00
2804: 10 27 00 2b     LBEQ   $2833
2808: ce 00 00        LDU    #$0000
280b: 34 40           PSHS   U
280d: 17 fd b1        LBSR   $25C1
2810: 32 62           LEAS   $2,S
2812: c1 00           CMPB   #$00
2814: 10 27 00 18     LBEQ   $2830
2818: ce 00 00        LDU    #$0000
281b: 34 40           PSHS   U
281d: 17 fc 52        LBSR   $2472
2820: 32 62           LEAS   $2,S
2822: ce 00 23        LDU    #$0023
2825: 10 8e 00 02     LDY    #$0002
2829: 34 60           PSHS   U,Y
282b: 17 e2 a2        LBSR   $0AD0
282e: 32 64           LEAS   $4,S
2830: 16 00 1d        LBRA   $2850
2833: ce 00 00        LDU    #$0000
2836: 34 40           PSHS   U
2838: 17 fc 37        LBSR   $2472
283b: 32 62           LEAS   $2,S
283d: c6 2a           LDB    #$2A
283f: 1d              SEX
2840: 1f 03           TFR    D,U
2842: 5f              CLRB
2843: 1d              SEX
2844: 1f 02           TFR    D,Y
2846: 8e 00 04        LDX    #$0004
2849: 34 70           PSHS   U,Y,X
284b: 17 f5 85        LBSR   $1DD3
284e: 32 66           LEAS   $6,S
2850: 16 00 13        LBRA   $2866
2853: c6 2b           LDB    #$2B
2855: 1d              SEX
2856: 1f 03           TFR    D,U
2858: 5f              CLRB
2859: 1d              SEX
285a: 1f 02           TFR    D,Y
285c: 8e 00 04        LDX    #$0004
285f: 34 70           PSHS   U,Y,X
2861: 17 f5 6f        LBSR   $1DD3
2864: 32 66           LEAS   $6,S
; $2281 bit 4: second numeric-response/validation work class.
; Uses $2600 and then $25C1 before either queueing request $23 or posting event $2C/$2D.
2866: fc 22 81        LDD    $2281
2869: 84 00           ANDA   #$00
286b: c4 10           ANDB   #$10
286d: 10 83 00 00     CMPD   #$0000
2871: 10 27 00 77     LBEQ   $28EC
2875: fc 22 81        LDD    $2281
2878: 84 ff           ANDA   #$FF
287a: c4 ef           ANDB   #$EF
287c: fd 22 81        STD    $2281
287f: f6 23 8f        LDB    $238F
2882: c1 00           CMPB   #$00
2884: 10 27 00 51     LBEQ   $28D9
2888: ce 00 00        LDU    #$0000
288b: 34 40           PSHS   U
288d: 17 fd 70        LBSR   $2600
2890: 32 62           LEAS   $2,S
2892: c1 00           CMPB   #$00
2894: 10 27 00 2b     LBEQ   $28C3
2898: ce 00 00        LDU    #$0000
289b: 34 40           PSHS   U
289d: 17 fd 21        LBSR   $25C1
28a0: 32 62           LEAS   $2,S
28a2: c1 00           CMPB   #$00
28a4: 10 27 00 18     LBEQ   $28C0
28a8: ce 00 00        LDU    #$0000
28ab: 34 40           PSHS   U
28ad: 17 fb c2        LBSR   $2472
28b0: 32 62           LEAS   $2,S
28b2: ce 00 23        LDU    #$0023
28b5: 10 8e 00 02     LDY    #$0002
28b9: 34 60           PSHS   U,Y
28bb: 17 e2 12        LBSR   $0AD0
28be: 32 64           LEAS   $4,S
28c0: 16 00 13        LBRA   $28D6
28c3: c6 2c           LDB    #$2C
28c5: 1d              SEX
28c6: 1f 03           TFR    D,U
28c8: 5f              CLRB
28c9: 1d              SEX
28ca: 1f 02           TFR    D,Y
28cc: 8e 00 04        LDX    #$0004
28cf: 34 70           PSHS   U,Y,X
28d1: 17 f4 ff        LBSR   $1DD3
28d4: 32 66           LEAS   $6,S
28d6: 16 00 13        LBRA   $28EC
28d9: c6 2d           LDB    #$2D
28db: 1d              SEX
28dc: 1f 03           TFR    D,U
28de: 5f              CLRB
28df: 1d              SEX
28e0: 1f 02           TFR    D,Y
28e2: 8e 00 04        LDX    #$0004
28e5: 34 70           PSHS   U,Y,X
28e7: 17 f4 e9        LBSR   $1DD3
28ea: 32 66           LEAS   $6,S
; $2281 bit 3: third numeric-response/validation work class.
; Uses $265A before either queueing request $23 or posting event $2E/$2F.
28ec: fc 22 81        LDD    $2281
28ef: 84 00           ANDA   #$00
28f1: c4 08           ANDB   #$08
28f3: 10 83 00 00     CMPD   #$0000
28f7: 10 27 00 67     LBEQ   $2962
28fb: fc 22 81        LDD    $2281
28fe: 84 ff           ANDA   #$FF
2900: c4 f7           ANDB   #$F7
2902: fd 22 81        STD    $2281
2905: f6 23 8f        LDB    $238F
2908: c1 00           CMPB   #$00
290a: 10 27 00 41     LBEQ   $294F
290e: ce 00 00        LDU    #$0000
2911: 34 40           PSHS   U
2913: 17 fd 44        LBSR   $265A
2916: 32 62           LEAS   $2,S
2918: c1 00           CMPB   #$00
291a: 10 27 00 1b     LBEQ   $2939
291e: ce 00 00        LDU    #$0000
2921: 34 40           PSHS   U
2923: 17 fb 4c        LBSR   $2472
2926: 32 62           LEAS   $2,S
2928: ce 00 23        LDU    #$0023
292b: 10 8e 00 02     LDY    #$0002
292f: 34 60           PSHS   U,Y
2931: 17 e1 9c        LBSR   $0AD0
2934: 32 64           LEAS   $4,S
2936: 16 00 13        LBRA   $294C
2939: c6 2e           LDB    #$2E
293b: 1d              SEX
293c: 1f 03           TFR    D,U
293e: 5f              CLRB
293f: 1d              SEX
2940: 1f 02           TFR    D,Y
2942: 8e 00 04        LDX    #$0004
2945: 34 70           PSHS   U,Y,X
2947: 17 f4 89        LBSR   $1DD3
294a: 32 66           LEAS   $6,S
294c: 16 00 13        LBRA   $2962
294f: c6 2f           LDB    #$2F
2951: 1d              SEX
2952: 1f 03           TFR    D,U
2954: 5f              CLRB
2955: 1d              SEX
2956: 1f 02           TFR    D,Y
2958: 8e 00 04        LDX    #$0004
295b: 34 70           PSHS   U,Y,X
295d: 17 f4 73        LBSR   $1DD3
2960: 32 66           LEAS   $6,S
; $2281 bit 5: post event/request slot $30 after clearing the numeric-response formatter busy flag.
2962: fc 22 81        LDD    $2281
2965: 84 00           ANDA   #$00
2967: c4 20           ANDB   #$20
2969: 10 83 00 00     CMPD   #$0000
296d: 10 27 00 27     LBEQ   $2998
2971: fc 22 81        LDD    $2281
2974: 84 ff           ANDA   #$FF
2976: c4 df           ANDB   #$DF
2978: fd 22 81        STD    $2281
297b: ce 00 00        LDU    #$0000
297e: 34 40           PSHS   U
2980: 17 fa ef        LBSR   $2472
2983: 32 62           LEAS   $2,S
2985: c6 30           LDB    #$30
2987: 1d              SEX
2988: 1f 03           TFR    D,U
298a: 5f              CLRB
298b: 1d              SEX
298c: 1f 02           TFR    D,Y
298e: 8e 00 04        LDX    #$0004
2991: 34 70           PSHS   U,Y,X
2993: 17 f4 3d        LBSR   $1DD3
2996: 32 66           LEAS   $6,S
2998: 32 62           LEAS   $2,S
299a: 39              RTS
; Frame-size descriptor bytes for surrounding functions (not code).
299b: 00 01           NEG    <$01
299d: 00 00           NEG    <$00
299f: 0f 00           CLR    <$00
29a1: 05 fc           LSR    <$FC
; =====================================================================================
; Front-panel 6x6 matrix keypad scanner — $29A2.
; Hardware interface:
;   Input port $0000: bit 7 = any-key-pressed flag (active high)
;                     bits 5:0 = row sense lines (active low, one-hot when key pressed)
;   Output port $0A00: bits 5:0 = column drive lines (active low)
;   Shadow register $241F: mirrors last value written to $0A00; bit 7 preserved
;
; Algorithm:
; 1. Read $0000; if bit 7 is clear, no key is pressed → return 0
; 2. Mask bits 5:0 and decode the active-low one-hot row value:
;      $3E→row 0, $3D→1, $3B→2, $37→3, $2F→4, $1F→5 (else row 6 → catch-all)
; 3. Scan columns 0-5 by driving one column low at a time through $0A00:
;    - Create mask with bit N clear, bits 5:0 otherwise set
;    - If $0000 bits 5:0 read back as all-ones ($3F), the key is not in this column
;    - If not all-ones, the key IS in this column → stop scanning
; 4. If all 6 columns scanned without a hit → return $40 (no valid key)
; 5. Otherwise: return (row * 6) + column + 1, yielding key codes 1..36
; =====================================================================================
29a3: ab a1           ADDA   ,Y++
29a5: 17 53 a8        LBSR   $7D50       ; allocate 8-byte stack frame
29a8: 6f 66           CLR    $6,S        ; result = 0 (default: no key)
29aa: f6 00 00        LDB    >$0000      ; read keypad input port
29ad: e7 63           STB    $3,S        ; save raw input
; --- Phase 1: check any-key-pressed flag (bit 7) ---
29af: e6 63           LDB    $3,S
29b1: 4f              CLRA
29b2: 84 00           ANDA   #$00
29b4: c4 80           ANDB   #$80        ; isolate bit 7 (any-key-pressed)
29b6: 10 83 00 00     CMPD   #$0000
29ba: 10 26 00 07     LBNE   $29C5       ; key pressed → decode it
29be: e6 66           LDB    $6,S        ; no key → return 0
29c0: e7 67           STB    $7,S
29c2: 16 00 fa        LBRA   $2ABF       ; → exit
; --- Phase 2: decode active-low row from bits 5:0 ---
29c5: e6 63           LDB    $3,S
29c7: c4 3f           ANDB   #$3F        ; mask to row sense bits
29c9: e7 63           STB    $3,S
29cb: e6 63           LDB    $3,S
29cd: 16 00 2f        LBRA   $29FF       ; → row decode switch
; Row decode targets: each stores row number into $2,S then jumps to column scan
29d0: 6f 62           CLR    $2,S        ; $3E → row 0 (bit 0 low)
29d2: 16 00 44        LBRA   $2A19
29d5: c6 01           LDB    #$01        ; $3D → row 1 (bit 1 low)
29d7: e7 62           STB    $2,S
29d9: 16 00 3d        LBRA   $2A19
29dc: c6 02           LDB    #$02        ; $3B → row 2 (bit 2 low)
29de: e7 62           STB    $2,S
29e0: 16 00 36        LBRA   $2A19
29e3: c6 03           LDB    #$03        ; $37 → row 3 (bit 3 low)
29e5: e7 62           STB    $2,S
29e7: 16 00 2f        LBRA   $2A19
29ea: c6 04           LDB    #$04        ; $2F → row 4 (bit 4 low)
29ec: e7 62           STB    $2,S
29ee: 16 00 28        LBRA   $2A19
29f1: c6 05           LDB    #$05        ; $1F → row 5 (bit 5 low)
29f3: e7 62           STB    $2,S
29f5: 16 00 21        LBRA   $2A19
29f8: c6 06           LDB    #$06        ; catch-all → row 6 (invalid/multi-key)
29fa: e7 62           STB    $2,S
29fc: 16 00 1a        LBRA   $2A19
; Row decode switch: compare active-low one-hot patterns
29ff: c1 1f           CMPB   #$1F        ; bit 5 low → row 5
2a01: 27 ee           BEQ    $29F1
2a03: c1 2f           CMPB   #$2F        ; bit 4 low → row 4
2a05: 27 e3           BEQ    $29EA
2a07: c1 37           CMPB   #$37        ; bit 3 low → row 3
2a09: 27 d8           BEQ    $29E3
2a0b: c1 3b           CMPB   #$3B        ; bit 2 low → row 2
2a0d: 27 cd           BEQ    $29DC
2a0f: c1 3d           CMPB   #$3D        ; bit 1 low → row 1
2a11: 27 c2           BEQ    $29D5
2a13: c1 3e           CMPB   #$3E        ; bit 0 low → row 0
2a15: 27 b9           BEQ    $29D0
2a17: 20 df           BRA    $29F8       ; no valid one-hot → row 6 catch-all
; --- Phase 3: scan columns via output port $0A00 ---
2a19: 6f 65           CLR    $5,S        ; column counter = 0
; Preserve bit 7 of $241F shadow, clear column drive bits
2a1b: f6 24 1f        LDB    $241F
2a1e: 4f              CLRA
2a1f: 84 00           ANDA   #$00
2a21: c4 80           ANDB   #$80        ; keep bit 7 only
2a23: f7 24 1f        STB    $241F       ; update shadow
2a26: f6 24 1f        LDB    $241F
2a29: f7 0a 00        STB    $0A00       ; drive all columns high (inactive)
; Column scan loop: for column 0..5
2a2c: e6 65           LDB    $5,S
2a2e: c1 06           CMPB   #$06        ; scanned all 6 columns?
2a30: 10 24 00 47     LBCC   $2A7B       ; yes → exit scan
; Build active-low mask: one bit clear at position $5,S
2a34: c6 01           LDB    #$01        ; start with bit 0
2a36: e7 64           STB    $4,S
2a38: a6 64           LDA    $4,S
2a3a: e6 65           LDB    $5,S        ; shift count = column number
2a3c: 17 53 5f        LBSR   $7D9E       ; arithmetic shift left → 1<<column
2a3f: e7 64           STB    $4,S
2a41: 63 64           COM    $4,S        ; complement → all 1s except column bit
2a43: e6 64           LDB    $4,S
2a45: c4 3f           ANDB   #$3F        ; mask to 6 column bits
2a47: e7 64           STB    $4,S
; Merge with shadow and drive output port
2a49: f6 24 1f        LDB    $241F
2a4c: 4f              CLRA
2a4d: 84 00           ANDA   #$00
2a4f: c4 c0           ANDB   #$C0        ; preserve bits 7:6 of shadow
2a51: f7 24 1f        STB    $241F
2a54: f6 24 1f        LDB    $241F
2a57: ea 64           ORB    $4,S        ; merge column drive mask
2a59: f7 24 1f        STB    $241F       ; update shadow
2a5c: f6 24 1f        LDB    $241F
2a5f: f7 0a 00        STB    $0A00       ; write to column output port
; Read back row sense lines
2a62: f6 00 00        LDB    >$0000      ; read keypad input
2a65: c4 3f           ANDB   #$3F        ; isolate row sense bits
2a67: 4f              CLRA
2a68: 10 83 00 3f     CMPD   #$003F      ; all rows high? (no key in this column)
2a6c: 10 27 00 03     LBEQ   $2A73       ; yes → next column
2a70: 16 00 08        LBRA   $2A7B       ; no → key found in this column, exit scan
2a73: e6 65           LDB    $5,S
2a75: cb 01           ADDB   #$01        ; column++
2a77: e7 65           STB    $5,S
2a79: 20 b1           BRA    $2A2C       ; → loop
; --- Phase 4: compute key code ---
2a7b: e6 65           LDB    $5,S
2a7d: c1 06           CMPB   #$06        ; did we scan all 6 without finding the key?
2a7f: 10 26 00 07     LBNE   $2A8A       ; no → compute code
2a83: c6 40           LDB    #$40        ; yes → return $40 (no valid key)
2a85: e7 66           STB    $6,S
2a87: 16 00 13        LBRA   $2A9D
; key_code = row * 6 + column + 1
2a8a: e6 62           LDB    $2,S        ; B = row number
2a8c: 86 06           LDA    #$06
2a8e: 3d              MUL              ; D = row * 6 (result in B since row<6)
2a8f: e7 62           STB    $2,S
2a91: a6 62           LDA    $2,S        ; A = row * 6
2a93: e6 65           LDB    $5,S        ; B = column number
2a95: 17 52 e8        LBSR   $7D80       ; D = (row * 6) + column (unsigned byte add)
2a98: c3 00 01        ADDD   #$0001      ; +1 → key codes are 1-based
2a9b: e7 66           STB    $6,S        ; store result
; --- Restore column output port to idle state ---
2a9d: f6 24 1f        LDB    $241F
2aa0: 4f              CLRA
2aa1: 84 00           ANDA   #$00
2aa3: c4 80           ANDB   #$80        ; preserve bit 7
2aa5: f7 24 1f        STB    $241F
2aa8: f6 24 1f        LDB    $241F
2aab: ca 40           ORB    #$40        ; set bit 6 (idle pattern with bit 6 high)
2aad: f7 24 1f        STB    $241F
2ab0: f6 24 1f        LDB    $241F
2ab3: f7 0a 00        STB    $0A00       ; write idle pattern to column output port
2ab6: f6 00 00        LDB    >$0000      ; final read-back (settle/debounce)
2ab9: e7 63           STB    $3,S
2abb: e6 66           LDB    $6,S        ; load result
2abd: e7 67           STB    $7,S        ; store in return slot
; --- Exit ---
2abf: e6 67           LDB    $7,S        ; return key code (0=none, 1-36=valid, $40=scan-fail)
2ac1: 32 68           LEAS   $8,S        ; deallocate frame
2ac3: 39              RTS
; Conditional key scan wrapper — $2AC4.
; Reads $0100 bit 4 (system latch key-detect flag). If set, calls the matrix scanner at $29A2
; and returns its result. If clear, returns 0 (no key).
2ac4: fc ab a3        LDD    $ABA3
2ac7: 17 52 86        LBSR   $7D50       ; allocate frame
2aca: 6f 62           CLR    $2,S        ; default result = 0
2acc: f6 01 00        LDB    $0100       ; read system latch
2acf: c4 10           ANDB   #$10        ; isolate bit 4 (key-detect)
2ad1: 10 27 00 0c     LBEQ   $2AE1       ; not set → return 0
2ad5: ce 00 00        LDU    #$0000
2ad8: 34 40           PSHS   U
2ada: 17 fe c5        LBSR   $29A2       ; → 6×6 matrix scan
2add: 32 62           LEAS   $2,S
2adf: e7 62           STB    $2,S        ; save scan result
2ae1: e6 62           LDB    $2,S
2ae3: e7 63           STB    $3,S        ; store in return slot
2ae5: 32 64           LEAS   $4,S
2ae7: 39              RTS
; =====================================================================================
; Key-code translator — $2AE8.
; Maps a raw matrix key code (from $29A2) to an action code using the ROM lookup table at $EF4A.
; Input: 16-bit key code on the stack ($000D,S)
; Output: 16-bit action code in D
;
; Special handling:
;   $0040 → action $0035 (no-key sentinel)
;   > $0024 (36) → action $0036 (out-of-range sentinel)
;   otherwise: index = key_code * 2 + hp_ib_offset
;     hp_ib_offset comes from $2202 bit 0 (1 if HP-IB activity is pending, else 0)
;     action = byte at $EF4A[index]
;   If action == $07, sets $2202 bit 0 (marks HP-IB activity pending for next scan)
; =====================================================================================
2ae8: fc ab a5        LDD    $ABA5
2aeb: 17 52 62        LBSR   $7D50       ; allocate 9-byte frame
2aee: ae e9 00 0d     LDX    $000D,S     ; load raw key code
2af2: 8c 00 40        CMPX   #$0040      ; $40 = no-key from scanner
2af5: 10 26 00 08     LBNE   $2B01
2af9: cc 00 35        LDD    #$0035      ; → return action $35 (no-key sentinel)
2afc: ed 67           STD    $7,S
2afe: 16 00 74        LBRA   $2B75
2b01: ae e9 00 0d     LDX    $000D,S
2b05: 8c 00 24        CMPX   #$0024      ; $24 = 36 (max valid matrix code)
2b08: 10 23 00 08     LBLS   $2B14       ; ≤ 36 → valid
2b0c: cc 00 36        LDD    #$0036      ; → return action $36 (out-of-range sentinel)
2b0f: ed 67           STD    $7,S
2b11: 16 00 61        LBRA   $2B75
; Check $2202 bit 0 for HP-IB activity offset
2b14: fc 22 02        LDD    $2202
2b17: 84 00           ANDA   #$00
2b19: c4 01           ANDB   #$01        ; isolate bit 0
2b1b: 10 83 00 00     CMPD   #$0000
2b1f: 10 27 00 11     LBEQ   $2B34       ; not set → offset = 0
2b23: c6 01           LDB    #$01        ; set → offset = 1
2b25: e7 62           STB    $2,S
2b27: fc 22 02        LDD    $2202       ; clear bit 0 (consumed)
2b2a: 84 ff           ANDA   #$FF
2b2c: c4 fe           ANDB   #$FE
2b2e: fd 22 02        STD    $2202
2b31: 16 00 02        LBRA   $2B36
2b34: 6f 62           CLR    $2,S        ; offset = 0
; Compute table index: key_code * 2 + offset, then look up in $EF4A
2b36: cc ef 4a        LDD    #$EF4A      ; ROM lookup table base
2b39: ed 63           STD    $3,S        ; save table pointer
2b3b: 68 e9 00 0e     ASL    $000E,S     ; key_code <<= 1 (low byte)
2b3f: 69 e9 00 0d     ROL    $000D,S     ; (high byte)
2b43: e6 62           LDB    $2,S        ; B = HP-IB offset (0 or 1)
2b45: 4f              CLRA
2b46: e3 e9 00 0d     ADDD   $000D,S     ; D = key_code * 2 + offset
2b4a: ed e9 00 0d     STD    $000D,S
2b4e: ae 63           LDX    $3,S        ; X = $EF4A
2b50: ec e9 00 0d     LDD    $000D,S     ; D = table index
2b54: 30 8b           LEAX   D,X         ; X = &table[index]
2b56: af 63           STX    $3,S
2b58: e6 f8 03        LDB    [$03,S]     ; B = table[index] (the action code)
2b5b: 4f              CLRA
2b5c: ed 65           STD    $5,S        ; save action code
; If action == 7, set $2202 bit 0 for next scan cycle
2b5e: ae 65           LDX    $5,S
2b60: 8c 00 07        CMPX   #$0007      ; action $07 = HP-IB activity trigger
2b63: 10 26 00 0a     LBNE   $2B71       ; no → skip
2b67: fc 22 02        LDD    $2202
2b6a: 8a 00           ORA    #$00
2b6c: ca 01           ORB    #$01        ; set bit 0 (HP-IB offset for next key)
2b6e: fd 22 02        STD    $2202
2b71: ec 65           LDD    $5,S        ; return action code in D
2b73: ed 67           STD    $7,S
2b75: ec 67           LDD    $7,S
2b77: 32 69           LEAS   $9,S        ; deallocate frame
2b79: 39              RTS
; Combined scan-and-translate — $2B7A.
; Calls $29A2 (matrix scan) then $2AE8 (translate) in one step. Returns the final action code.
2b7a: fc ab a7        LDD    $ABA7
2b7d: 17 51 d0        LBSR   $7D50       ; allocate frame
2b80: ce 00 00        LDU    #$0000
2b83: 34 40           PSHS   U
2b85: 17 fe 1a        LBSR   $29A2       ; → 6×6 matrix scan → raw key code in B
2b88: 32 62           LEAS   $2,S
2b8a: e7 62           STB    $2,S        ; save raw code
2b8c: e6 62           LDB    $2,S
2b8e: 4f              CLRA
2b8f: 1f 03           TFR    D,U         ; pass raw code to translator
2b91: 10 8e 00 02     LDY    #$0002
2b95: 34 60           PSHS   U,Y
2b97: 17 ff 4e        LBSR   $2AE8       ; → translate via $EF4A table
2b9a: 32 64           LEAS   $4,S
2b9c: ed 63           STD    $3,S        ; return translated action code
2b9e: 32 65           LEAS   $5,S
2ba0: 39              RTS
; Frame-size descriptor bytes (not code).
2ba1: 00 06           NEG    <$06
2ba3: 00 02           NEG    <$02
2ba5: 00 07           NEG    <$07
2ba7: 00 03           NEG    <$03
; Display string loader (table A) — $2BA9.
; Looks up a display string by index (0..19) from the ROM pointer table at $EE62.
; Clamps index > 19 to 0. Each table entry is a 2-byte pointer to a Pascal-style string
; (first byte = length, followed by character data). Calls $58EA to copy the string to display RAM.
; Input: index on stack at $000A,S; display target parameters at $0008,S.
2ba9: fc b5 e3        LDD    $B5E3
2bac: 17 51 a1        LBSR   $7D50       ; allocate frame
2baf: ae e9 00 0a     LDX    $000A,S     ; load string index
2bb3: 8c 00 13        CMPX   #$0013      ; max valid = 19 ($13)
2bb6: 10 23 00 06     LBLS   $2BC0       ; in range → proceed
2bba: 5f              CLRB              ; out of range → clamp to 0
2bbb: 4f              CLRA
2bbc: ed e9 00 0a     STD    $000A,S
2bc0: ec e9 00 0a     LDD    $000A,S     ; D = index
2bc4: 58              ASLB              ; D *= 2 (pointer table has 2-byte entries)
2bc5: 49              ROLA
2bc6: 8e ee 62        LDX    #$EE62      ; ROM pointer table base
2bc9: 30 8b           LEAX   D,X         ; X = &table[index]
2bcb: af 62           STX    $2,S
2bcd: ec f8 02        LDD    [$02,S]     ; D = string pointer from table
2bd0: ed 62           STD    $2,S        ; save string pointer
2bd2: ae 62           LDX    $2,S
2bd4: 30 01           LEAX   $1,X        ; X = string data (skip length byte)
2bd6: 1f 13           TFR    X,U         ; U = source data pointer
2bd8: e6 f8 02        LDB    [$02,S]     ; B = length byte (first byte of string)
2bdb: 4f              CLRA
2bdc: 1f 02           TFR    D,Y         ; Y = length
2bde: ae e9 00 08     LDX    $0008,S     ; X = display target from caller
2be2: cc 00 06        LDD    #$0006
2be5: 34 76           PSHS   U,Y,X,D
2be7: 17 2d 00        LBSR   $58EA       ; → copy string to display RAM
2bea: 32 68           LEAS   $8,S
2bec: 32 64           LEAS   $4,S
2bee: 39              RTS
; Display string loader (table B) — $2BEF.
; Same structure as $2BA9 but uses ROM pointer table at $EEEE with max index 15 ($0F).
; Each entry is a 2-byte pointer to a Pascal-style string (length + data).
2bef: fc b5 e3        LDD    $B5E3
2bf2: 17 51 5b        LBSR   $7D50       ; allocate frame
2bf5: ae e9 00 0a     LDX    $000A,S     ; load string index
2bf9: 8c 00 0f        CMPX   #$000F      ; max valid = 15
2bfc: 10 23 00 06     LBLS   $2C06       ; in range → proceed
2c00: 5f              CLRB              ; out of range → clamp to 0
2c01: 4f              CLRA
2c02: ed e9 00 0a     STD    $000A,S
2c06: ec e9 00 0a     LDD    $000A,S     ; D = index
2c0a: 58              ASLB              ; D *= 2
2c0b: 49              ROLA
2c0c: 8e ee ee        LDX    #$EEEE      ; ROM pointer table base
2c0f: 30 8b           LEAX   D,X         ; X = &table[index]
2c11: af 62           STX    $2,S
2c13: ec f8 02        LDD    [$02,S]     ; D = string pointer
2c16: ed 62           STD    $2,S
2c18: ae 62           LDX    $2,S
2c1a: 30 01           LEAX   $1,X        ; skip length byte → data start
2c1c: 1f 13           TFR    X,U         ; U = source data
2c1e: e6 f8 02        LDB    [$02,S]     ; B = length
2c21: 4f              CLRA
2c22: 1f 02           TFR    D,Y         ; Y = length
2c24: ae e9 00 08     LDX    $0008,S     ; X = display target
2c28: cc 00 06        LDD    #$0006
2c2b: 34 76           PSHS   U,Y,X,D
2c2d: 17 2c ba        LBSR   $58EA       ; → copy string to display RAM
2c30: 32 68           LEAS   $8,S
2c32: 32 64           LEAS   $4,S
2c34: 39              RTS
; =====================================================================================
; Numeric entry field setup — $2C35.
; Initializes the front-panel numeric entry UI for user input. Stores caller-supplied parameters
; into the entry state block:
;   $23A9 ← formatting mode (from stack $0007,S)
;   $23AB ← validation selector (from stack $000D,S)
;   $23AD ← field width / digit count (from stack $000C,S)
;   $23AF ← additional flags (from stack $0010,S)
;   $221F ← cleared to 0 (current digit position reset)
; If $2204 bit 3 is already set (callback active), redirects to $2415 to reinitialize the
; formatter within the existing callback context. Otherwise performs full initialization:
; clears editing state ($23A6/$23A7/$23A8), sets up display via $57A0/$57BE, fills the ASCII
; buffer at $239A with spaces, and optionally seeds a sign prefix.
; =====================================================================================
2c35: fc b5 e5        LDD    $B5E5
2c38: 17 51 15        LBSR   $7D50       ; allocate frame
2c3b: ec e9 00 07     LDD    $0007,S
2c3f: fd 23 a9        STD    $23A9       ; formatting mode
2c42: ec e9 00 0d     LDD    $000D,S
2c46: fd 23 ab        STD    $23AB       ; validation selector
2c49: 5f              CLRB
2c4a: 4f              CLRA
2c4b: fd 22 1f        STD    $221F       ; reset current digit position
2c4e: e6 e9 00 0c     LDB    $000C,S
2c52: f7 23 ad        STB    $23AD       ; field width
2c55: e6 e9 00 10     LDB    $0010,S
2c59: f7 23 af        STB    $23AF       ; additional flags
; If callback already active, redirect to formatter reinit
2c5c: fc 22 04        LDD    $2204
2c5f: 84 00           ANDA   #$00
2c61: c4 08           ANDB   #$08        ; test bit 3 (callback active)
2c63: 10 83 00 00     CMPD   #$0000
2c67: 10 27 00 16     LBEQ   $2C81       ; not active → full init
; Callback is active: reinitialize formatter only
2c6b: ee e9 00 0d     LDU    $000D,S     ; validation selector
2c6f: 10 ae e9 00 07  LDY    $0007,S     ; formatting mode
2c74: 8e 00 04        LDX    #$0004
2c77: 34 70           PSHS   U,Y,X
2c79: 17 f7 99        LBSR   $2415       ; → reinit formatter state
2c7c: 32 66           LEAS   $6,S
2c7e: 16 00 c9        LBRA   $2D4A       ; → exit
; Full initialization: clear editing state
2c81: 7f 23 a6        CLR    $23A6       ; clear accumulated digits
2c84: 7f 23 a7        CLR    $23A7       ; clear edit flag
2c87: c6 01           LDB    #$01
2c89: f7 23 a8        STB    $23A8       ; set initial entry state to 1
; Set up display field via display helpers
2c8c: f6 23 ad        LDB    $23AD       ; field width
2c8f: 4f              CLRA
2c90: 1f 03           TFR    D,U
2c92: 10 8e 00 02     LDY    #$0002
2c96: 34 60           PSHS   U,Y
2c98: 17 2b 05        LBSR   $57A0       ; → display field setup (width in U)
2c9b: 32 64           LEAS   $4,S
2c9d: ce 00 00        LDU    #$0000
2ca0: 10 8e 00 02     LDY    #$0002
2ca4: 34 60           PSHS   U,Y
2ca6: 17 2b 15        LBSR   $57BE       ; → display cursor init
2ca9: 32 64           LEAS   $4,S
; Set max digit count ($23A5), clamped to 10
2cab: ae e9 00 09     LDX    $0009,S     ; caller-supplied max digits
2caf: 8c 00 0a        CMPX   #$000A      ; > 10?
2cb2: 10 22 00 0a     LBHI   $2CC0       ; yes → clamp
2cb6: e6 e9 00 0a     LDB    $000A,S     ; no → use as-is
2cba: f7 23 a5        STB    $23A5
2cbd: 16 00 05        LBRA   $2CC5
2cc0: c6 0a           LDB    #$0A        ; clamp to 10 digits max
2cc2: f7 23 a5        STB    $23A5
; Clear ASCII buffer ($239A..) to spaces
2cc5: 6f 62           CLR    $2,S        ; loop index = 0
2cc7: e6 62           LDB    $2,S
2cc9: f1 23 a5        CMPB   $23A5       ; < max digits?
2ccc: 10 24 00 12     LBCC   $2CE2       ; no → done filling
2cd0: 8e 23 9a        LDX    #$239A      ; ASCII buffer base
2cd3: e6 62           LDB    $2,S
2cd5: 3a              ABX               ; X = &buffer[i]
2cd6: c6 20           LDB    #$20        ; space character
2cd8: e7 84           STB    ,X          ; buffer[i] = ' '
2cda: e6 62           LDB    $2,S
2cdc: cb 01           ADDB   #$01        ; i++
2cde: e7 62           STB    $2,S
2ce0: 20 e5           BRA    $2CC7       ; → loop
; Mode switch: seed buffer based on formatting mode ($23A9)
2ce2: be 23 a9        LDX    $23A9       ; load formatting mode
2ce5: 16 00 13        LBRA   $2CFB       ; → switch
; Mode 2: seed leading '+' sign
2ce8: c6 2b           LDB    #$2B        ; '+' character
2cea: f7 23 9a        STB    $239A       ; store at buffer[0]
2ced: c6 01           LDB    #$01
2cef: f7 23 a4        STB    $23A4       ; prefix length = 1
2cf2: 16 00 0d        LBRA   $2D02
; Other modes: no prefix
2cf5: 7f 23 a4        CLR    $23A4       ; prefix length = 0
2cf8: 16 00 07        LBRA   $2D02
; Mode switch target
2cfb: 8c 00 02        CMPX   #$0002      ; mode 2 → sign prefix
2cfe: 27 e8           BEQ    $2CE8
2d00: 20 f3           BRA    $2CF5       ; all others → no prefix
; Validation selector switch: sets $23AE (decimal-point position) based on selector value
2d02: ae e9 00 0d     LDX    $000D,S     ; load validation selector
2d06: 16 00 1e        LBRA   $2D27       ; → switch
2d09: c6 03           LDB    #$03        ; selector → decimal position 3
2d0b: f7 23 ae        STB    $23AE
2d0e: 16 00 39        LBRA   $2D4A
2d11: c6 02           LDB    #$02        ; selector → decimal position 2
2d13: f7 23 ae        STB    $23AE
2d16: 16 00 31        LBRA   $2D4A
2d19: c6 01           LDB    #$01        ; selector → decimal position 1
2d1b: f7 23 ae        STB    $23AE
2d1e: 16 00 29        LBRA   $2D4A
2d21: 7f 23 ae        CLR    $23AE       ; out of range → no decimal point
2d24: 16 00 23        LBRA   $2D4A
; Selector range check: valid range 0..7, indexed through jump table at $AD3A
2d27: 8c 00 00        CMPX   #$0000
2d2a: 2d f5           BLT    $2D21       ; < 0 → no decimal
2d2c: 8c 00 07        CMPX   #$0007
2d2f: 2e f0           BGT    $2D21       ; > 7 → no decimal
2d31: 1f 10           TFR    X,D
2d33: 8e ad 3a        LDX    #$AD3A      ; jump table base
2d36: 58              ASLB              ; index *= 2
2d37: 49              ROLA
2d38: 6e 9b           JMP    [D,X]       ; indirect jump through table
; Jump table entries (8 targets for selectors 0..7)
2d3a: ad 21           JSR    $1,Y
2d3c: ad 21           JSR    $1,Y
2d3e: ad 21           JSR    $1,Y
2d40: ad 09           JSR    $9,X
2d42: ad 11           JSR    -$F,X
2d44: ad 11           JSR    -$F,X
2d46: ad 09           JSR    $9,X
2d48: ad 19           JSR    -$7,X
2d4a: 32 63           LEAS   $3,S        ; deallocate frame
2d4c: 39              RTS
; =====================================================================================
; Key action dispatcher (primary) — $2D4D.
; Translates a key action code (1..52, from $2AE8) into a request type and posts it via $0AD0.
; Uses a 52-entry jump table at $AE3D (bytes at $2E3D in file offset). Each entry maps to a
; code block that loads the corresponding request code into $2,S, then falls through to the
; common post at $2EA5. Action codes outside 1..52 return B=0 (unhandled).
; =====================================================================================
2d4d: fc b5 e7        LDD    $B5E7
2d50: 17 4f fd        LBSR   $7D50       ; allocate frame
2d53: ae e9 00 09     LDX    $0009,S     ; load action code
2d57: 16 00 d0        LBRA   $2E2A       ; → range check and dispatch
2d5a: cc 00 11        LDD    #$0011
2d5d: ed 62           STD    $2,S
2d5f: 16 01 43        LBRA   $2EA5
2d62: cc 00 03        LDD    #$0003
2d65: ed 62           STD    $2,S
2d67: 16 01 3b        LBRA   $2EA5
2d6a: cc 00 05        LDD    #$0005
2d6d: ed 62           STD    $2,S
2d6f: 16 01 33        LBRA   $2EA5
2d72: cc 00 01        LDD    #$0001
2d75: ed 62           STD    $2,S
2d77: 16 01 2b        LBRA   $2EA5
2d7a: cc 00 02        LDD    #$0002
2d7d: ed 62           STD    $2,S
2d7f: 16 01 23        LBRA   $2EA5
2d82: cc 00 06        LDD    #$0006
2d85: ed 62           STD    $2,S
2d87: 16 01 1b        LBRA   $2EA5
2d8a: cc 00 13        LDD    #$0013
2d8d: ed 62           STD    $2,S
2d8f: 16 01 13        LBRA   $2EA5
2d92: cc 00 37        LDD    #$0037
2d95: ed 62           STD    $2,S
2d97: 16 01 0b        LBRA   $2EA5
2d9a: cc 00 14        LDD    #$0014
2d9d: ed 62           STD    $2,S
2d9f: 16 01 03        LBRA   $2EA5
2da2: cc 00 15        LDD    #$0015
2da5: ed 62           STD    $2,S
2da7: 16 00 fb        LBRA   $2EA5
2daa: cc 00 38        LDD    #$0038
2dad: ed 62           STD    $2,S
2daf: 16 00 f3        LBRA   $2EA5
2db2: cc 00 16        LDD    #$0016
2db5: ed 62           STD    $2,S
2db7: 16 00 eb        LBRA   $2EA5
2dba: cc 00 17        LDD    #$0017
2dbd: ed 62           STD    $2,S
2dbf: 16 00 e3        LBRA   $2EA5
2dc2: cc 00 18        LDD    #$0018
2dc5: ed 62           STD    $2,S
2dc7: 16 00 db        LBRA   $2EA5
2dca: cc 00 04        LDD    #$0004
2dcd: ed 62           STD    $2,S
2dcf: 16 00 d3        LBRA   $2EA5
2dd2: cc 00 20        LDD    #$0020
2dd5: ed 62           STD    $2,S
2dd7: 16 00 cb        LBRA   $2EA5
2dda: cc 00 1f        LDD    #$001F
2ddd: ed 62           STD    $2,S
2ddf: 16 00 c3        LBRA   $2EA5
2de2: cc 00 1e        LDD    #$001E
2de5: ed 62           STD    $2,S
2de7: 16 00 bb        LBRA   $2EA5
2dea: cc 00 21        LDD    #$0021
2ded: ed 62           STD    $2,S
2def: 16 00 b3        LBRA   $2EA5
2df2: cc 00 22        LDD    #$0022
2df5: ed 62           STD    $2,S
2df7: 16 00 ab        LBRA   $2EA5
2dfa: cc 00 0c        LDD    #$000C
2dfd: ed 62           STD    $2,S
2dff: 16 00 a3        LBRA   $2EA5
2e02: cc 00 12        LDD    #$0012
2e05: ed 62           STD    $2,S
2e07: 16 00 9b        LBRA   $2EA5
2e0a: cc 00 0f        LDD    #$000F
2e0d: ed 62           STD    $2,S
2e0f: 16 00 93        LBRA   $2EA5
2e12: cc 00 10        LDD    #$0010
2e15: ed 62           STD    $2,S
2e17: 16 00 8b        LBRA   $2EA5
2e1a: cc 00 26        LDD    #$0026
2e1d: ed 62           STD    $2,S
2e1f: 16 00 83        LBRA   $2EA5
2e22: 6f 64           CLR    $4,S        ; out-of-range → return 0 (unhandled)
2e24: 16 00 8f        LBRA   $2EB6
2e27: 16 00 7b        LBRA   $2EA5
; Range check: valid action codes are 1..52 ($01..$34)
2e2a: 8c 00 34        CMPX   #$0034      ; > 52?
2e2d: 2e f3           BGT    $2E22       ; yes → unhandled
2e2f: 1f 10           TFR    X,D
2e31: 83 00 01        SUBD   #$0001      ; make 0-based
2e34: 2d ec           BLT    $2E22       ; < 1 → unhandled
2e36: 8e ae 3d        LDX    #$AE3D      ; jump table (52 two-byte entries)
2e39: 58              ASLB              ; index *= 2
2e3a: 49              ROLA
2e3b: 6e 9b           JMP    [D,X]       ; dispatch through table
2e3d: ad 72           JSR    -$E,S
2e3f: ad 8a           JSR    F,X
2e41: ae 22           LDX    $2,Y
2e43: ae 22           LDX    $2,Y
2e45: ae 22           LDX    $2,Y
2e47: ae 22           LDX    $2,Y
2e49: ae 22           LDX    $2,Y
2e4b: ad 9a           JSR    [F,X]
2e4d: ae 22           LDX    $2,Y
2e4f: ae 22           LDX    $2,Y
2e51: ae 22           LDX    $2,Y
2e53: ae 22           LDX    $2,Y
2e55: ad e2           JSR    ,-S
2e57: ad c2           JSR    ,-U
2e59: ae 22           LDX    $2,Y
2e5b: ae 22           LDX    $2,Y
2e5d: ae 22           LDX    $2,Y
2e5f: ae 22           LDX    $2,Y
2e61: ad d2           JSR    Illegal Postbyte
2e63: ad ba           JSR    [F,Y]
2e65: ae 22           LDX    $2,Y
2e67: ae 22           LDX    $2,Y
2e69: ae 22           LDX    $2,Y
2e6b: ae 22           LDX    $2,Y
2e6d: ad da           JSR    [F,U]
2e6f: ad a2           JSR    ,-Y
2e71: ae 22           LDX    $2,Y
2e73: ae 22           LDX    $2,Y
2e75: ae 22           LDX    $2,Y
2e77: ae 22           LDX    $2,Y
2e79: ae 22           LDX    $2,Y
2e7b: ad b2           JSR    Illegal Postbyte
2e7d: ae 22           LDX    $2,Y
2e7f: ae 22           LDX    $2,Y
2e81: ae 22           LDX    $2,Y
2e83: ae 22           LDX    $2,Y
2e85: ae 02           LDX    $2,X
2e87: ae 0a           LDX    $A,X
2e89: ad 7a           JSR    -$6,S
2e8b: ad fa           JSR    [F,S]
2e8d: ad 62           JSR    $2,S
2e8f: ae 22           LDX    $2,Y
2e91: ae 12           LDX    -$E,X
2e93: ad ca           JSR    F,U
2e95: ad ea           JSR    F,S
2e97: ad 6a           JSR    $A,S
2e99: ad f2           JSR    Illegal Postbyte
2e9b: ad 82           JSR    ,-X
2e9d: ad 5a           JSR    -$6,U
2e9f: ad 92           JSR    Illegal Postbyte
2ea1: ad aa           JSR    F,Y
2ea3: ae 1a           LDX    -$6,X
; Common exit: post request code and return success
2ea5: ee 62           LDU    $2,S        ; U = request type from case block
2ea7: 10 8e 00 02     LDY    #$0002
2eab: 34 60           PSHS   U,Y
2ead: 17 dc 20        LBSR   $0AD0       ; → post request to main dispatcher
2eb0: 32 64           LEAS   $4,S
2eb2: c6 01           LDB    #$01        ; return 1 (handled)
2eb4: e7 64           STB    $4,S
2eb6: e6 64           LDB    $4,S        ; load return value
2eb8: 32 65           LEAS   $5,S        ; deallocate frame
2eba: 39              RTS
; Key action dispatcher (secondary) — $2EBB.
; Handles a subset of action codes (3, 4, 5, 6, 42) that map to request types $19..$1D.
; All other codes return B=0 (unhandled). Posts via $0AD0, same pattern as $2D4D.
2ebb: fc b5 e7        LDD    $B5E7
2ebe: 17 4e 8f        LBSR   $7D50       ; allocate frame
2ec1: ae e9 00 09     LDX    $0009,S     ; load action code
2ec5: 16 00 30        LBRA   $2EF8       ; → switch
2ec8: cc 00 19        LDD    #$0019
2ecb: ed 62           STD    $2,S
2ecd: 16 00 43        LBRA   $2F13
2ed0: cc 00 1a        LDD    #$001A
2ed3: ed 62           STD    $2,S
2ed5: 16 00 3b        LBRA   $2F13
2ed8: cc 00 1b        LDD    #$001B
2edb: ed 62           STD    $2,S
2edd: 16 00 33        LBRA   $2F13
2ee0: cc 00 1c        LDD    #$001C
2ee3: ed 62           STD    $2,S
2ee5: 16 00 2b        LBRA   $2F13
2ee8: cc 00 1d        LDD    #$001D
2eeb: ed 62           STD    $2,S
2eed: 16 00 23        LBRA   $2F13
2ef0: 6f 64           CLR    $4,S
2ef2: 16 00 2f        LBRA   $2F24
2ef5: 16 00 1b        LBRA   $2F13
2ef8: 8c 00 03        CMPX   #$0003
2efb: 27 e3           BEQ    $2EE0
2efd: 8c 00 04        CMPX   #$0004
2f00: 27 d6           BEQ    $2ED8
2f02: 8c 00 05        CMPX   #$0005
2f05: 27 c9           BEQ    $2ED0
2f07: 8c 00 06        CMPX   #$0006
2f0a: 27 bc           BEQ    $2EC8
2f0c: 8c 00 2a        CMPX   #$002A
2f0f: 27 d7           BEQ    $2EE8
2f11: 20 dd           BRA    $2EF0
2f13: ee 62           LDU    $2,S
2f15: 10 8e 00 02     LDY    #$0002
2f19: 34 60           PSHS   U,Y
2f1b: 17 db b2        LBSR   $0AD0
2f1e: 32 64           LEAS   $4,S
2f20: c6 01           LDB    #$01
2f22: e7 64           STB    $4,S
2f24: e6 64           LDB    $4,S
2f26: 32 65           LEAS   $5,S
2f28: 39              RTS
; =====================================================================================
; Numeric digit entry handler — $2F29.
; Processes a single key press during numeric entry mode. Uses $23A9 (formatting mode) to
; determine how many digit positions to expect (1-7, via jump table at $AF81), then searches
; the 8-byte-per-entry key-to-character table at $EF94 (up to 16 entries) for a match against
; the action code at $000C,S.
; Handles special characters: '.' (decimal point — only allowed once, tracked by $23A6),
; '-' (sign — stored at buffer[0]). Appends ordinary digits to $239A buffer up to $23A5 limit.
; Returns B=1 if the key was accepted, B=0 if rejected.
; =====================================================================================
2f29: fc b5 e9        LDD    $B5E9
2f2c: 17 4e 21        LBSR   $7D50       ; allocate 8-byte frame
2f2f: be 23 a9        LDX    $23A9       ; load formatting mode
2f32: 16 00 39        LBRA   $2F6E       ; → mode switch
2f35: c6 01           LDB    #$01
2f37: e7 66           STB    $6,S
2f39: 16 00 53        LBRA   $2F8F
2f3c: c6 02           LDB    #$02
2f3e: e7 66           STB    $6,S
2f40: 16 00 4c        LBRA   $2F8F
2f43: c6 03           LDB    #$03
2f45: e7 66           STB    $6,S
2f47: 16 00 45        LBRA   $2F8F
2f4a: c6 04           LDB    #$04
2f4c: e7 66           STB    $6,S
2f4e: 16 00 3e        LBRA   $2F8F
2f51: c6 05           LDB    #$05
2f53: e7 66           STB    $6,S
2f55: 16 00 37        LBRA   $2F8F
2f58: c6 06           LDB    #$06
2f5a: e7 66           STB    $6,S
2f5c: 16 00 30        LBRA   $2F8F
2f5f: c6 07           LDB    #$07
2f61: e7 66           STB    $6,S
2f63: 16 00 29        LBRA   $2F8F
2f66: 6f 67           CLR    $7,S
2f68: 16 01 00        LBRA   $306B
2f6b: 16 00 21        LBRA   $2F8F
2f6e: 8c 00 00        CMPX   #$0000
2f71: 2d f3           BLT    $2F66
2f73: 8c 00 06        CMPX   #$0006
2f76: 2e ee           BGT    $2F66
2f78: 1f 10           TFR    X,D
2f7a: 8e af 81        LDX    #$AF81
2f7d: 58              ASLB
2f7e: 49              ROLA
2f7f: 6e 9b           JMP    [D,X]
2f81: af 4a           STX    $A,U
2f83: af 51           STX    -$F,U
2f85: af 58           STX    -$8,U
2f87: af 5f           STX    -$1,U
2f89: af 3c           STX    -$4,Y
2f8b: af 43           STX    $3,U
2f8d: af 35           STX    -$B,Y
2f8f: cc ef 94        LDD    #$EF94
2f92: ed 63           STD    $3,S
2f94: 6f 65           CLR    $5,S
2f96: e6 65           LDB    $5,S
2f98: c1 10           CMPB   #$10
2f9a: 10 24 00 1e     LBCC   $2FBC
2f9e: e6 f8 03        LDB    [$03,S]
2fa1: 4f              CLRA
2fa2: 10 a3 e9 00 0c  CMPD   $000C,S
2fa7: 10 26 00 03     LBNE   $2FAE
2fab: 16 00 0e        LBRA   $2FBC
2fae: ae 63           LDX    $3,S
2fb0: 30 08           LEAX   $8,X
2fb2: af 63           STX    $3,S
2fb4: e6 65           LDB    $5,S
2fb6: cb 01           ADDB   #$01
2fb8: e7 65           STB    $5,S
2fba: 20 da           BRA    $2F96
2fbc: e6 65           LDB    $5,S
2fbe: c1 10           CMPB   #$10
2fc0: 10 26 00 05     LBNE   $2FC9
2fc4: 6f 67           CLR    $7,S
2fc6: 16 00 a2        LBRA   $306B
2fc9: ae 63           LDX    $3,S
2fcb: e6 66           LDB    $6,S
2fcd: 3a              ABX
2fce: af 63           STX    $3,S
2fd0: e6 f8 03        LDB    [$03,S]
2fd3: e7 62           STB    $2,S
2fd5: e6 62           LDB    $2,S
2fd7: c1 58           CMPB   #$58
2fd9: 10 26 00 05     LBNE   $2FE2
2fdd: 6f 67           CLR    $7,S
2fdf: 16 00 89        LBRA   $306B
2fe2: be 23 a9        LDX    $23A9
2fe5: 8c 00 06        CMPX   #$0006
2fe8: 10 27 00 17     LBEQ   $3003
2fec: be 23 a9        LDX    $23A9
2fef: 8c 00 04        CMPX   #$0004
2ff2: 10 27 00 0d     LBEQ   $3003
2ff6: be 23 a9        LDX    $23A9
2ff9: 8c 00 05        CMPX   #$0005
2ffc: 10 27 00 03     LBEQ   $3003
3000: 16 00 0d        LBRA   $3010
3003: e6 62           LDB    $2,S
3005: 4f              CLRA
3006: fd 22 1f        STD    $221F
3009: c6 01           LDB    #$01
300b: e7 67           STB    $7,S
300d: 16 00 5b        LBRA   $306B
3010: e6 62           LDB    $2,S
3012: c1 2e           CMPB   #$2E
3014: 10 26 00 16     LBNE   $302E
3018: f6 23 a6        LDB    $23A6
301b: c1 00           CMPB   #$00
301d: 10 27 00 08     LBEQ   $3029
3021: 6f 67           CLR    $7,S
3023: 16 00 45        LBRA   $306B
3026: 16 00 05        LBRA   $302E
3029: c6 01           LDB    #$01
302b: f7 23 a6        STB    $23A6
302e: e6 62           LDB    $2,S
3030: c1 2d           CMPB   #$2D
3032: 10 26 00 0c     LBNE   $3042
3036: e6 62           LDB    $2,S
3038: f7 23 9a        STB    $239A
303b: c6 01           LDB    #$01
303d: e7 67           STB    $7,S
303f: 16 00 29        LBRA   $306B
3042: f6 23 a4        LDB    $23A4
3045: f1 23 a5        CMPB   $23A5
3048: 10 24 00 1d     LBCC   $3069
304c: 8e 23 9a        LDX    #$239A
304f: f6 23 a4        LDB    $23A4
3052: 3a              ABX
3053: e6 62           LDB    $2,S
3055: e7 84           STB    ,X
3057: f6 23 a4        LDB    $23A4
305a: cb 01           ADDB   #$01
305c: f7 23 a4        STB    $23A4
305f: c6 01           LDB    #$01
3061: e7 67           STB    $7,S
3063: 16 00 05        LBRA   $306B
3066: 16 00 02        LBRA   $306B
3069: 6f 67           CLR    $7,S
306b: e6 67           LDB    $7,S
306d: 32 68           LEAS   $8,S
306f: 39              RTS
; Numeric entry commit/validate — $3070.
; Validates the completed numeric entry based on $23AB (validation selector) and $23A4/$23A5
; (digit count vs limit). On success, stores $2221 and returns B=1; on failure returns B=0.
3070: fc b5 e5        LDD    $B5E5
3073: 17 4c da        LBSR   $7D50       ; allocate frame
3076: be 23 ab        LDX    $23AB       ; load validation selector
3079: 16 00 34        LBRA   $30B0       ; → switch
307c: cc 00 10        LDD    #$0010
307f: fd 22 21        STD    $2221
3082: c6 01           LDB    #$01
3084: e7 62           STB    $2,S
3086: 16 00 33        LBRA   $30BC
3089: f6 23 a4        LDB    $23A4
308c: f1 23 a5        CMPB   $23A5
308f: 10 26 00 10     LBNE   $30A3
3093: cc 00 0c        LDD    #$000C
3096: fd 22 21        STD    $2221
3099: c6 01           LDB    #$01
309b: e7 62           STB    $2,S
309d: 16 00 1c        LBRA   $30BC
30a0: 16 00 05        LBRA   $30A8
30a3: 6f 62           CLR    $2,S
30a5: 16 00 14        LBRA   $30BC
30a8: 6f 62           CLR    $2,S
30aa: 16 00 0f        LBRA   $30BC
30ad: 16 00 0c        LBRA   $30BC
30b0: 8c 00 00        CMPX   #$0000
30b3: 27 c7           BEQ    $307C
30b5: 8c 00 01        CMPX   #$0001
30b8: 27 cf           BEQ    $3089
30ba: 20 ec           BRA    $30A8
30bc: e6 62           LDB    $2,S
30be: 32 63           LEAS   $3,S
30c0: 39              RTS
; Numeric entry soft-key commit handler — $30C1.
; Validates completed numeric entry based on $23AB (validation selector) and the action
; code passed as argument. Each validation mode maps specific action codes to $2221 values:
;   selector 0: action $1B → mode $08
;   selector 1: actions $1B/$1C → modes $03/$04
;   selector 2: actions $1C/$1D/$1E → modes $05/$06/$07
;   selector 3: actions $1D/$1E → modes $09/$0A
;   selector 4: actions $1D/$1E → modes $01/$02
;   selector 5: action $1C → mode $0B
; Returns B=1 on accepted action, B=0 otherwise.
30c1: fc b5 e5        LDD    $B5E5
30c4: 17 4c 89        LBSR   $7D50
30c7: be 23 ab        LDX    $23AB
30ca: 16 01 32        LBRA   $31FF
30cd: ae e9 00 07     LDX    $0007,S
30d1: 16 00 11        LBRA   $30E5
30d4: cc 00 08        LDD    #$0008
30d7: fd 22 21        STD    $2221
30da: 16 00 0f        LBRA   $30EC
30dd: 6f 62           CLR    $2,S
30df: 16 01 3c        LBRA   $321E
30e2: 16 00 07        LBRA   $30EC
30e5: 8c 00 1b        CMPX   #$001B
30e8: 27 ea           BEQ    $30D4
30ea: 20 f1           BRA    $30DD
30ec: c6 01           LDB    #$01
30ee: e7 62           STB    $2,S
30f0: 16 01 2b        LBRA   $321E
30f3: ae e9 00 07     LDX    $0007,S
30f7: 16 00 1a        LBRA   $3114
30fa: cc 00 03        LDD    #$0003
30fd: fd 22 21        STD    $2221
3100: 16 00 1d        LBRA   $3120
3103: cc 00 04        LDD    #$0004
3106: fd 22 21        STD    $2221
3109: 16 00 14        LBRA   $3120
310c: 6f 62           CLR    $2,S
310e: 16 01 0d        LBRA   $321E
3111: 16 00 0c        LBRA   $3120
3114: 8c 00 1b        CMPX   #$001B
3117: 27 ea           BEQ    $3103
3119: 8c 00 1c        CMPX   #$001C
311c: 27 dc           BEQ    $30FA
311e: 20 ec           BRA    $310C
3120: c6 01           LDB    #$01
3122: e7 62           STB    $2,S
3124: 16 00 f7        LBRA   $321E
3127: ae e9 00 07     LDX    $0007,S
312b: 16 00 23        LBRA   $3151
312e: cc 00 05        LDD    #$0005
3131: fd 22 21        STD    $2221
3134: 16 00 2b        LBRA   $3162
3137: cc 00 06        LDD    #$0006
313a: fd 22 21        STD    $2221
313d: 16 00 22        LBRA   $3162
3140: cc 00 07        LDD    #$0007
3143: fd 22 21        STD    $2221
3146: 16 00 19        LBRA   $3162
3149: 6f 62           CLR    $2,S
314b: 16 00 d0        LBRA   $321E
314e: 16 00 11        LBRA   $3162
3151: 8c 00 1c        CMPX   #$001C
3154: 27 ea           BEQ    $3140
3156: 8c 00 1d        CMPX   #$001D
3159: 27 dc           BEQ    $3137
315b: 8c 00 1e        CMPX   #$001E
315e: 27 ce           BEQ    $312E
3160: 20 e7           BRA    $3149
3162: c6 01           LDB    #$01
3164: e7 62           STB    $2,S
3166: 16 00 b5        LBRA   $321E
3169: ae e9 00 07     LDX    $0007,S
316d: 16 00 1a        LBRA   $318A
3170: cc 00 09        LDD    #$0009
3173: fd 22 21        STD    $2221
3176: 16 00 1d        LBRA   $3196
3179: cc 00 0a        LDD    #$000A
317c: fd 22 21        STD    $2221
317f: 16 00 14        LBRA   $3196
3182: 6f 62           CLR    $2,S
3184: 16 00 97        LBRA   $321E
3187: 16 00 0c        LBRA   $3196
318a: 8c 00 1d        CMPX   #$001D
318d: 27 ea           BEQ    $3179
318f: 8c 00 1e        CMPX   #$001E
3192: 27 dc           BEQ    $3170
3194: 20 ec           BRA    $3182
3196: c6 01           LDB    #$01
3198: e7 62           STB    $2,S
319a: 16 00 81        LBRA   $321E
319d: ae e9 00 07     LDX    $0007,S
31a1: 16 00 1a        LBRA   $31BE
31a4: cc 00 01        LDD    #$0001
31a7: fd 22 21        STD    $2221
31aa: 16 00 1d        LBRA   $31CA
31ad: cc 00 02        LDD    #$0002
31b0: fd 22 21        STD    $2221
31b3: 16 00 14        LBRA   $31CA
31b6: 6f 62           CLR    $2,S
31b8: 16 00 63        LBRA   $321E
31bb: 16 00 0c        LBRA   $31CA
31be: 8c 00 1d        CMPX   #$001D
31c1: 27 ea           BEQ    $31AD
31c3: 8c 00 1e        CMPX   #$001E
31c6: 27 dc           BEQ    $31A4
31c8: 20 ec           BRA    $31B6
31ca: c6 01           LDB    #$01
31cc: e7 62           STB    $2,S
31ce: 16 00 4d        LBRA   $321E
31d1: ae e9 00 07     LDX    $0007,S
31d5: 16 00 11        LBRA   $31E9
31d8: cc 00 0b        LDD    #$000B
31db: fd 22 21        STD    $2221
31de: 16 00 0f        LBRA   $31F0
31e1: 6f 62           CLR    $2,S
31e3: 16 00 38        LBRA   $321E
31e6: 16 00 07        LBRA   $31F0
31e9: 8c 00 1c        CMPX   #$001C
31ec: 27 ea           BEQ    $31D8
31ee: 20 f1           BRA    $31E1
31f0: c6 01           LDB    #$01
31f2: e7 62           STB    $2,S
31f4: 16 00 27        LBRA   $321E
31f7: 6f 62           CLR    $2,S
31f9: 16 00 22        LBRA   $321E
31fc: 16 00 1f        LBRA   $321E
31ff: 8c 00 07        CMPX   #$0007
3202: 2e f3           BGT    $31F7
3204: 1f 10           TFR    X,D
3206: 83 00 02        SUBD   #$0002
3209: 2d ec           BLT    $31F7
320b: 8e b2 12        LDX    #$B212
320e: 58              ASLB
320f: 49              ROLA
3210: 6e 9b           JMP    [D,X]
3212: b0 cd b0        SUBA   $CDB0
3215: f3 b1 27        ADDD   $B127
3218: b1 69 b1        CMPA   $69B1
321b: 9d b1           JSR    <$B1
321d: d1 e6           CMPB   <$E6
321f: 62 32           XNC    -$E,Y
3221: 63 39           COM    -$7,Y
; Numeric entry digit-shift/format helper — $3223.
; Prepares the display format for a numeric entry field. Computes the fill character and
; starting position based on the formatting mode ($23A9). Mode 2 uses leading '0' padding
; from position 1; other modes use space ($20) padding from position 0.
; Shifts existing characters rightward in the $239A buffer to make room for new digits.
; Returns B = adjusted cursor position in the display field.
3223: fc b5 eb        LDD    $B5EB
3226: 17 4b 27        LBSR   $7D50
3229: f6 23 a4        LDB    $23A4
322c: 4f              CLRA
322d: ed 68           STD    $8,S
322f: ec e9 00 0f     LDD    $000F,S
3233: a3 68           SUBD   $8,S
3235: e7 63           STB    $3,S
3237: be 23 a9        LDX    $23A9
323a: 16 00 23        LBRA   $3260
323d: b6 23 a4        LDA    $23A4
3240: c6 01           LDB    #$01
3242: 17 4b 4a        LBSR   $7D8F
3245: e7 64           STB    $4,S
3247: c6 30           LDB    #$30
3249: e7 67           STB    $7,S
324b: c6 01           LDB    #$01
324d: e7 65           STB    $5,S
324f: 16 00 24        LBRA   $3276
3252: f6 23 a4        LDB    $23A4
3255: e7 64           STB    $4,S
3257: c6 30           LDB    #$30
3259: e7 67           STB    $7,S
325b: 6f 65           CLR    $5,S
325d: 16 00 16        LBRA   $3276
3260: 8c 00 00        CMPX   #$0000
3263: 27 ed           BEQ    $3252
3265: 8c 00 01        CMPX   #$0001
3268: 27 e8           BEQ    $3252
326a: 8c 00 02        CMPX   #$0002
326d: 27 ce           BEQ    $323D
326f: 8c 00 03        CMPX   #$0003
3272: 27 de           BEQ    $3252
3274: 20 dc           BRA    $3252
3276: e6 64           LDB    $4,S
3278: e7 66           STB    $6,S
327a: e6 63           LDB    $3,S
327c: c1 00           CMPB   #$00
327e: 10 27 00 44     LBEQ   $32C6
3282: ec e9 00 0f     LDD    $000F,S
3286: 83 00 01        SUBD   #$0001
3289: e7 62           STB    $2,S
328b: e6 62           LDB    $2,S
328d: e1 65           CMPB   $5,S
328f: 10 2d 00 33     LBLT   $32C6
3293: e6 64           LDB    $4,S
3295: c1 00           CMPB   #$00
3297: 10 2f 00 1a     LBLE   $32B5
329b: 8e 23 9a        LDX    #$239A
329e: e6 62           LDB    $2,S
32a0: 30 85           LEAX   B,X
32a2: a6 62           LDA    $2,S
32a4: e6 63           LDB    $3,S
32a6: 17 4a c7        LBSR   $7D70
32a9: ce 23 9a        LDU    #$239A
32ac: 33 cb           LEAU   D,U
32ae: e6 c4           LDB    ,U
32b0: e7 84           STB    ,X
32b2: 16 00 0b        LBRA   $32C0
32b5: 8e 23 9a        LDX    #$239A
32b8: e6 62           LDB    $2,S
32ba: 30 85           LEAX   B,X
32bc: e6 67           LDB    $7,S
32be: e7 84           STB    ,X
32c0: 6a 62           DEC    $2,S
32c2: 6a 64           DEC    $4,S
32c4: 20 c5           BRA    $328B
32c6: e6 66           LDB    $6,S
32c8: e7 6a           STB    $A,S
32ca: 32 6b           LEAS   $B,S
32cc: 39              RTS
; Numeric entry backspace handler — $32CD.
; Handles action code $1F (backspace key). Decrements the character count ($23A4), clears the
; deleted character position to a space, and resets $23A6 (decimal point flag) if the deleted
; character was '.'. For signed modes (mode 2), will not delete past the sign prefix at position 0.
; Returns B=1 if backspace was performed, B=0 if the action code wasn't $1F.
32cd: fc b5 e5        LDD    $B5E5
32d0: 17 4a 7d        LBSR   $7D50       ; allocate frame
32d3: ae e9 00 07     LDX    $0007,S     ; load action code
32d7: 8c 00 1f        CMPX   #$001F      ; is it backspace ($1F)?
32da: 10 27 00 05     LBEQ   $32E3       ; yes → handle
32de: 6f 62           CLR    $2,S        ; no → return 0
32e0: 16 00 a3        LBRA   $3386
32e3: be 23 a9        LDX    $23A9
32e6: 16 00 7d        LBRA   $3366
32e9: f6 23 a4        LDB    $23A4
32ec: c1 00           CMPB   #$00
32ee: 10 23 00 0b     LBLS   $32FD
32f2: f6 23 a4        LDB    $23A4
32f5: c0 01           SUBB   #$01
32f7: f7 23 a4        STB    $23A4
32fa: 16 00 03        LBRA   $3300
32fd: 7f 23 a4        CLR    $23A4
3300: 8e 23 9a        LDX    #$239A
3303: f6 23 a4        LDB    $23A4
3306: 3a              ABX
3307: e6 84           LDB    ,X
3309: c1 2e           CMPB   #$2E
330b: 10 26 00 03     LBNE   $3312
330f: 7f 23 a6        CLR    $23A6
3312: 8e 23 9a        LDX    #$239A
3315: f6 23 a4        LDB    $23A4
3318: 3a              ABX
3319: c6 20           LDB    #$20
331b: e7 84           STB    ,X
331d: 16 00 62        LBRA   $3382
3320: f6 23 a4        LDB    $23A4
3323: c1 01           CMPB   #$01
3325: 10 23 00 28     LBLS   $3351
3329: f6 23 a4        LDB    $23A4
332c: c0 01           SUBB   #$01
332e: f7 23 a4        STB    $23A4
3331: 8e 23 9a        LDX    #$239A
3334: f6 23 a4        LDB    $23A4
3337: 3a              ABX
3338: e6 84           LDB    ,X
333a: c1 2e           CMPB   #$2E
333c: 10 26 00 03     LBNE   $3343
3340: 7f 23 a6        CLR    $23A6
3343: 8e 23 9a        LDX    #$239A
3346: f6 23 a4        LDB    $23A4
3349: 3a              ABX
334a: c6 20           LDB    #$20
334c: e7 84           STB    ,X
334e: 16 00 0a        LBRA   $335B
3351: c6 2b           LDB    #$2B
3353: f7 23 9a        STB    $239A
3356: c6 01           LDB    #$01
3358: f7 23 a4        STB    $23A4
335b: 16 00 24        LBRA   $3382
335e: 6f 62           CLR    $2,S
3360: 16 00 23        LBRA   $3386
3363: 16 00 1c        LBRA   $3382
3366: 8c 00 00        CMPX   #$0000
3369: 10 27 ff 7c     LBEQ   $32E9
336d: 8c 00 01        CMPX   #$0001
3370: 10 27 ff 75     LBEQ   $32E9
3374: 8c 00 02        CMPX   #$0002
3377: 27 a7           BEQ    $3320
3379: 8c 00 03        CMPX   #$0003
337c: 10 27 ff 69     LBEQ   $32E9
3380: 20 dc           BRA    $335E
3382: c6 01           LDB    #$01
3384: e7 62           STB    $2,S
3386: e6 62           LDB    $2,S
3388: 32 63           LEAS   $3,S
338a: 39              RTS
; Post-entry display refresh — $338B.
; Clears $23A7-$23A8 (entry tracking flags). If the caller's argument is nonzero,
; refreshes the display via $59C6 and calls the indirect function at [$2211] before
; enabling the cursor at $57BE.
338b: fc b5 ed        LDD    $B5ED
338e: 17 49 bf        LBSR   $7D50
3391: 7f 23 a7        CLR    $23A7
3394: 7f 23 a8        CLR    $23A8
3397: ae e9 00 06     LDX    $0006,S
339b: 8c 00 00        CMPX   #$0000
339e: 10 27 00 0f     LBEQ   $33B1
33a2: ce 00 00        LDU    #$0000
33a5: 34 40           PSHS   U
33a7: 17 26 1c        LBSR   $59C6
33aa: 32 62           LEAS   $2,S
33ac: be 22 11        LDX    $2211
33af: ad 84           JSR    ,X
33b1: ce 00 01        LDU    #$0001
33b4: 10 8e 00 02     LDY    #$0002
33b8: 34 60           PSHS   U,Y
33ba: 17 24 01        LBSR   $57BE
33bd: 32 64           LEAS   $4,S
33bf: 32 62           LEAS   $2,S
33c1: 39              RTS
; Numeric entry key handler — $33C2.
; Main dispatcher for key actions during an active numeric entry field. Processes the
; translated action code in $24DC through multiple stages:
; 1. If $2202 bit 2 set, calls active callback at [$23B0] (HP-IB command override)
; 2. Tests for null/special codes ($00, $07, $35, $36) → ignored
; 3. Tries $2D4D (primary key action dispatcher, codes 1-52)
; 4. Tries $2EBB (secondary dispatcher, codes 3-6/42)
; 5. Tries $32CD (backspace handler, action $1F)
; 6. Tries $2F29 (digit entry handler, numeric keys)
; 7. Tries $30C1 (commit handler, soft-key confirmation)
; On successful digit entry with passing validation ($3070), posts request $0023.
33c2: fc b5 ed        LDD    $B5ED
33c5: 17 49 88        LBSR   $7D50       ; allocate frame
; --- Stage 1: HP-IB command override check ---
33c8: fc 22 02        LDD    $2202
33cb: 84 00           ANDA   #$00
33cd: c4 04           ANDB   #$04        ; test $2202 bit 2 (HP-IB override active)
33cf: 10 83 00 00     CMPD   #$0000
33d3: 10 27 00 08     LBEQ   $33DF       ; not active → normal key processing
33d7: be 23 b0        LDX    $23B0       ; active callback pointer
33da: ad 84           JSR    ,X          ; → dispatch to HP-IB command handler
33dc: 16 02 01        LBRA   $35E0       ; → exit
; --- Stage 2: filter null/special key codes ---
33df: fc 22 04        LDD    $2204
33e2: 84 00           ANDA   #$00
33e4: c4 08           ANDB   #$08        ; test $2204 bit 3 (status event gate)
33e6: 10 83 00 00     CMPD   #$0000
33ea: 10 27 00 12     LBEQ   $3400       ; gate not set → skip filter
33ee: be 24 dc        LDX    $24DC       ; X = decoded key code
33f1: 8c 00 01        CMPX   #$0001      ; key code <= $01?
33f4: 17 49 bf        LBSR   $7DB6       ; → unsigned LE compare helper (B=1 if <=)
33f7: c1 00           CMPB   #$00
33f9: 10 26 00 03     LBNE   $3400       ; no (code > $01) → proceed
33fd: 16 00 03        LBRA   $3403       ; yes (code $00 or $01) → ignore, exit
3400: 16 00 03        LBRA   $3406       ; → special code filter
3403: 16 01 da        LBRA   $35E0       ; → exit (null/trivial key ignored)
; Filter out special key codes that are ignored during numeric entry
3406: be 24 dc        LDX    $24DC       ; X = decoded key code
3409: 8c 00 07        CMPX   #$0007      ; $07 (bell/alert)?
340c: 10 27 00 21     LBEQ   $3431       ; → ignore
3410: be 24 dc        LDX    $24DC
3413: 8c 00 00        CMPX   #$0000      ; $00 (null)?
3416: 10 27 00 17     LBEQ   $3431       ; → ignore
341a: be 24 dc        LDX    $24DC
341d: 8c 00 36        CMPX   #$0036      ; $36 (shift key)?
3420: 10 27 00 0d     LBEQ   $3431       ; → ignore
3424: be 24 dc        LDX    $24DC
3427: 8c 00 35        CMPX   #$0035      ; $35 (modifier key)?
342a: 10 27 00 03     LBEQ   $3431       ; → ignore
342e: 16 00 03        LBRA   $3434       ; not filtered → try dispatchers
3431: 16 01 ac        LBRA   $35E0       ; → exit (special key ignored)
; --- Stage 3: primary key action dispatcher ($2D4D) ---
3434: fe 24 dc        LDU    $24DC       ; U = key code
3437: 10 8e 00 02     LDY    #$0002
343b: 34 60           PSHS   U,Y
343d: 17 f9 0d        LBSR   $2D4D       ; → primary dispatcher (action codes 1-52)
3440: 32 64           LEAS   $4,S
3442: c1 00           CMPB   #$00        ; handled?
3444: 10 27 00 1c     LBEQ   $3464       ; no → try secondary
3448: f6 23 a8        LDB    $23A8       ; entry state ($01 = active)
344b: c1 00           CMPB   #$00
344d: 10 27 00 10     LBEQ   $3461       ; state 0 → skip display update
3451: c6 01           LDB    #$01
3453: 1d              SEX
3454: 1f 03           TFR    D,U         ; arg = 1
3456: 10 8e 00 02     LDY    #$0002
345a: 34 60           PSHS   U,Y
345c: 17 ff 2c        LBSR   $338B       ; → $338B: refresh entry field display
345f: 32 64           LEAS   $4,S
3461: 16 01 7c        LBRA   $35E0       ; → exit (handled by primary)
; --- Stage 4: secondary key action dispatcher ($2EBB) ---
3464: fe 24 dc        LDU    $24DC       ; U = key code
3467: 10 8e 00 02     LDY    #$0002
346b: 34 60           PSHS   U,Y
346d: 17 fa 4b        LBSR   $2EBB       ; → secondary dispatcher (codes 3-6/42)
3470: 32 64           LEAS   $4,S
3472: c1 00           CMPB   #$00        ; handled?
3474: 10 27 00 1c     LBEQ   $3494       ; no → try backspace
3478: f6 23 a8        LDB    $23A8       ; entry state
347b: c1 00           CMPB   #$00
347d: 10 27 00 10     LBEQ   $3491       ; state 0 → skip display update
3481: c6 01           LDB    #$01
3483: 1d              SEX
3484: 1f 03           TFR    D,U         ; arg = 1
3486: 10 8e 00 02     LDY    #$0002
348a: 34 60           PSHS   U,Y
348c: 17 fe fc        LBSR   $338B       ; → refresh entry field display
348f: 32 64           LEAS   $4,S
3491: 16 01 4c        LBRA   $35E0       ; → exit (handled by secondary)
; --- Stage 5: backspace handler ($32CD) ---
; If entry state is 0 (no active entry), fall through to $43FE and exit
3494: f6 23 a8        LDB    $23A8       ; entry state
3497: c1 00           CMPB   #$00
3499: 10 26 00 13     LBNE   $34B0       ; state != 0 → try backspace
349d: c6 01           LDB    #$01
349f: 1d              SEX
34a0: 1f 03           TFR    D,U         ; arg = 1
34a2: 10 8e 00 02     LDY    #$0002
34a6: 34 60           PSHS   U,Y
34a8: 17 0f 53        LBSR   $43FE       ; → $43FE: save UI state + param
34ab: 32 64           LEAS   $4,S
34ad: 16 01 30        LBRA   $35E0       ; → exit
34b0: fe 24 dc        LDU    $24DC       ; U = key code
34b3: 10 8e 00 02     LDY    #$0002
34b7: 34 60           PSHS   U,Y
34b9: 17 fe 11        LBSR   $32CD       ; → backspace handler (action $1F)
34bc: 32 64           LEAS   $4,S
34be: c1 00           CMPB   #$00        ; handled?
34c0: 10 27 00 3e     LBEQ   $3502       ; no → try digit entry
34c4: f6 23 a7        LDB    $23A7       ; edit flag (nonzero = digits entered)
34c7: c1 00           CMPB   #$00
34c9: 10 26 00 03     LBNE   $34D0       ; digits entered → update display
34cd: 16 01 10        LBRA   $35E0       ; no digits → exit
; Backspace handled with digits present: refresh the displayed entry field
34d0: ce 23 9a        LDU    #$239A      ; U = ASCII buffer base
34d3: f6 23 a5        LDB    $23A5       ; B = max digit count
34d6: 4f              CLRA
34d7: 1f 02           TFR    D,Y         ; Y = char count
34d9: f6 23 ad        LDB    $23AD       ; B = field width offset
34dc: 4f              CLRA
34dd: 1f 01           TFR    D,X         ; X = display column
34df: cc 00 06        LDD    #$0006
34e2: 34 76           PSHS   U,Y,X,D
34e4: 17 23 be        LBSR   $58A5       ; → copy ASCII buffer to display RAM
34e7: 32 68           LEAS   $8,S
34e9: b6 23 ad        LDA    $23AD       ; A = field width
34ec: f6 23 a4        LDB    $23A4       ; B = current digit count
34ef: 17 48 8e        LBSR   $7D80       ; → unsigned subtract: D = A - B
34f2: 1f 03           TFR    D,U         ; U = cursor position (width - digits)
34f4: 10 8e 00 02     LDY    #$0002
34f8: 34 60           PSHS   U,Y
34fa: 17 22 a3        LBSR   $57A0       ; → update cursor position display
34fd: 32 64           LEAS   $4,S
34ff: 16 00 de        LBRA   $35E0       ; → exit
; --- Stage 6: digit entry handler ($2F29) ---
3502: fe 24 dc        LDU    $24DC       ; U = key code
3505: 10 8e 00 02     LDY    #$0002
3509: 34 60           PSHS   U,Y
350b: 17 fa 1b        LBSR   $2F29       ; → digit entry handler (numeric keys)
350e: 32 64           LEAS   $4,S
3510: c1 00           CMPB   #$00        ; handled?
3512: 10 27 00 86     LBEQ   $359C       ; no → try commit
; Digit accepted: set up display if first digit
3516: f6 23 a7        LDB    $23A7       ; edit flag
3519: c1 00           CMPB   #$00
351b: 10 26 00 1e     LBNE   $353D       ; already editing → skip first-digit init
351f: c6 01           LDB    #$01
3521: f7 23 a7        STB    $23A7       ; set edit flag (first digit entered)
; First digit: load secondary display line from $ED11
3524: ce ed 11        LDU    #$ED11      ; U = ROM string source
3527: f6 23 ae        LDB    $23AE       ; B = display row parameter
352a: 4f              CLRA
352b: 1f 02           TFR    D,Y         ; Y = char count
352d: f6 23 af        LDB    $23AF       ; B = display column parameter
3530: 4f              CLRA
3531: 1f 01           TFR    D,X         ; X = column offset
3533: cc 00 06        LDD    #$0006
3536: 34 76           PSHS   U,Y,X,D
3538: 17 23 6a        LBSR   $58A5       ; → copy string to display RAM
353b: 32 68           LEAS   $8,S
; Refresh digit display after entry
353d: ce 23 9a        LDU    #$239A      ; U = ASCII buffer base
3540: f6 23 a5        LDB    $23A5       ; B = max digit count
3543: 4f              CLRA
3544: 1f 02           TFR    D,Y         ; Y = char count
3546: f6 23 ad        LDB    $23AD       ; B = field width offset
3549: 4f              CLRA
354a: 1f 01           TFR    D,X         ; X = display column
354c: cc 00 06        LDD    #$0006
354f: 34 76           PSHS   U,Y,X,D
3551: 17 23 51        LBSR   $58A5       ; → copy ASCII buffer to display RAM
3554: 32 68           LEAS   $8,S
3556: b6 23 ad        LDA    $23AD       ; A = field width
3559: f6 23 a4        LDB    $23A4       ; B = digit count
355c: 17 48 21        LBSR   $7D80       ; → D = A - B (cursor offset)
355f: 1f 03           TFR    D,U         ; U = cursor position
3561: 10 8e 00 02     LDY    #$0002
3565: 34 60           PSHS   U,Y
3567: 17 22 36        LBSR   $57A0       ; → update cursor position
356a: 32 64           LEAS   $4,S
; Validate the partial entry via $3070
356c: ce 00 00        LDU    #$0000      ; validation mode 0
356f: 34 40           PSHS   U
3571: 17 fa fc        LBSR   $3070       ; → numeric entry validate
3574: 32 62           LEAS   $2,S
3576: c1 00           CMPB   #$00        ; valid?
3578: 10 27 00 1d     LBEQ   $3599       ; no → skip post
; Validation passed: refresh display and post request $23
357c: 5f              CLRB
357d: 1d              SEX
357e: 1f 03           TFR    D,U         ; arg = 0
3580: 10 8e 00 02     LDY    #$0002
3584: 34 60           PSHS   U,Y
3586: 17 fe 02        LBSR   $338B       ; → refresh entry field display
3589: 32 64           LEAS   $4,S
358b: ce 00 23        LDU    #$0023      ; request type $23 (numeric entry complete)
358e: 10 8e 00 02     LDY    #$0002
3592: 34 60           PSHS   U,Y
3594: 17 d5 39        LBSR   $0AD0       ; → post request $23
3597: 32 64           LEAS   $4,S
3599: 16 00 44        LBRA   $35E0       ; → exit
; --- Stage 7: commit handler ($30C1) ---
359c: fe 24 dc        LDU    $24DC       ; U = key code
359f: 10 8e 00 02     LDY    #$0002
35a3: 34 60           PSHS   U,Y
35a5: 17 fb 19        LBSR   $30C1       ; → commit handler (soft-key confirm)
35a8: 32 64           LEAS   $4,S
35aa: c1 00           CMPB   #$00        ; handled?
35ac: 10 27 00 20     LBEQ   $35D0       ; no → unhandled key fallthrough
; Commit handled: refresh display and post request $23
35b0: 5f              CLRB
35b1: 1d              SEX
35b2: 1f 03           TFR    D,U         ; arg = 0
35b4: 10 8e 00 02     LDY    #$0002
35b8: 34 60           PSHS   U,Y
35ba: 17 fd ce        LBSR   $338B       ; → refresh entry field display
35bd: 32 64           LEAS   $4,S
35bf: ce 00 23        LDU    #$0023      ; request type $23
35c2: 10 8e 00 02     LDY    #$0002
35c6: 34 60           PSHS   U,Y
35c8: 17 d5 05        LBSR   $0AD0       ; → post request $23
35cb: 32 64           LEAS   $4,S
35cd: 16 00 10        LBRA   $35E0       ; → exit
; No dispatcher handled the key: save UI state with arg=2
35d0: c6 02           LDB    #$02
35d2: 1d              SEX
35d3: 1f 03           TFR    D,U         ; arg = 2 (unhandled key)
35d5: 10 8e 00 02     LDY    #$0002
35d9: 34 60           PSHS   U,Y
35db: 17 0e 20        LBSR   $43FE       ; → $43FE: save UI state + param
35de: 32 64           LEAS   $4,S
35e0: 32 62           LEAS   $2,S        ; deallocate frame
35e2: 39              RTS
35e3: 00 02           NEG    <$02
35e5: 00 01           NEG    <$01
35e7: 00 03           NEG    <$03
35e9: 00 06           NEG    <$06
35eb: 00 09           NEG    <$09
35ed: 00 00           NEG    <$00
; I/O port bit-field write with complement and shift — $35EF.
; Clamps the field index (arg 2) to 0-15, complements it, shifts left by 3, then calls
; $5BA1 to write the result along with a $78 mask to the I/O port selected by arg 1.
; Finishes with a 6-iteration calibrated delay via $5670.
35ef: fc c1 c6        LDD    $C1C6
35f2: 17 47 5b        LBSR   $7D50       ; allocate frame
35f5: ae e9 00 09     LDX    $0009,S     ; X = field index arg
35f9: 8c 00 0f        CMPX   #$000F     ; > 15?
35fc: 10 23 00 07     LBLS   $3607       ; no → proceed
3600: cc 00 0f        LDD    #$000F
3603: ed e9 00 09     STD    $0009,S     ; clamp to 15
3607: 63 e9 00 09     COM    $0009,S     ; complement (16-bit)
360b: 63 e9 00 0a     COM    $000A,S
360f: ec e9 00 09     LDD    $0009,S     ; D = ~index
3613: 58              ASLB                ; shift left 3 (multiply by 8)
3614: 49              ROLA
3615: 58              ASLB
3616: 49              ROLA
3617: 58              ASLB
3618: 49              ROLA
3619: e7 62           STB    $2,S        ; save shifted value
361b: e6 62           LDB    $2,S
361d: 4f              CLRA
361e: 1f 03           TFR    D,U         ; U = value (complemented + shifted)
3620: c6 78           LDB    #$78        ; mask $78 (bits 6-3)
3622: 1d              SEX
3623: 1f 02           TFR    D,Y         ; Y = mask
3625: ae e9 00 07     LDX    $0007,S     ; X = port index arg
3629: cc 00 06        LDD    #$0006
362c: 34 76           PSHS   U,Y,X,D
362e: 17 25 70        LBSR   $5BA1       ; → $5BA1: write port
3631: 32 68           LEAS   $8,S
3633: c6 06           LDB    #$06
3635: 1d              SEX
3636: 1f 03           TFR    D,U         ; U = 6 (delay iterations)
3638: 10 8e 00 02     LDY    #$0002
363c: 34 60           PSHS   U,Y
363e: 17 20 2f        LBSR   $5670       ; → calibration delay
3641: 32 64           LEAS   $4,S
3643: 32 63           LEAS   $3,S        ; deallocate frame
3645: 39              RTS
; Reset all four output ports to idle — $3646.
; Iterates ports 0-3, writing value=$00/mask=$80 to each via $5BA1, then clears
; the $0800 strobe port.
3646: fc c1 c6        LDD    $C1C6
3649: 17 47 04        LBSR   $7D50       ; allocate frame
364c: 6f 62           CLR    $2,S        ; port index = 0
364e: e6 62           LDB    $2,S        ; loop: load port index
3650: c1 04           CMPB   #$04        ; all 4 ports done?
3652: 10 24 00 1f     LBCC   $3675       ; yes → clear strobe
3656: 5f              CLRB
3657: 1d              SEX
3658: 1f 03           TFR    D,U         ; U = value $00 (idle)
365a: 10 8e 00 80     LDY    #$0080      ; Y = mask $80 (enable bit)
365e: e6 62           LDB    $2,S
3660: 4f              CLRA
3661: 1f 01           TFR    D,X         ; X = port index
3663: cc 00 06        LDD    #$0006
3666: 34 76           PSHS   U,Y,X,D
3668: 17 25 36        LBSR   $5BA1       ; → $5BA1: write port (value=$00, mask=$80)
366b: 32 68           LEAS   $8,S
366d: e6 62           LDB    $2,S
366f: cb 01           ADDB   #$01        ; port index++
3671: e7 62           STB    $2,S
3673: 20 d9           BRA    $364E       ; → loop
3675: 7f 08 00        CLR    $0800       ; clear strobe port
3678: 32 63           LEAS   $3,S        ; deallocate frame
367a: 39              RTS
; Conditional I/O port bit-field write — $367B.
; If port index (arg 1) > 3, returns immediately. When enable (arg 2) is nonzero, checks
; the enable flag at $23B3+port; if already set, writes value=$00/mask=$04 via $5BA1.
; When enable is zero and $23C1 bit 4 is clear, writes value=$04/mask=$04 instead.
367b: fc c1 c8        LDD    $C1C8
367e: 17 46 cf        LBSR   $7D50       ; allocate frame
3681: ae e9 00 06     LDX    $0006,S     ; X = port index
3685: 8c 00 03        CMPX   #$0003      ; valid port (0-3)?
3688: 10 23 00 03     LBLS   $368F       ; yes → proceed
368c: 16 00 5d        LBRA   $36EC       ; no → exit
368f: ae e9 00 08     LDX    $0008,S     ; X = enable arg
3693: 8c 00 00        CMPX   #$0000      ; enable == 0?
3696: 10 27 00 2b     LBEQ   $36C5       ; yes → disable path
; Enable path: check per-port enable flag at $23B3+port
369a: 8e 23 b3        LDX    #$23B3      ; per-port enable flags base
369d: ec e9 00 06     LDD    $0006,S     ; D = port index
36a1: 30 8b           LEAX   D,X         ; X = &$23B3[port]
36a3: e6 84           LDB    ,X          ; B = enable flag for this port
36a5: c1 00           CMPB   #$00
36a7: 10 27 00 17     LBEQ   $36C2       ; flag clear → skip write
36ab: 5f              CLRB
36ac: 1d              SEX
36ad: 1f 03           TFR    D,U         ; U = value $00 (clear bit)
36af: c6 04           LDB    #$04
36b1: 1d              SEX
36b2: 1f 02           TFR    D,Y         ; Y = mask $04 (bit 2)
36b4: ae e9 00 06     LDX    $0006,S     ; X = port index
36b8: cc 00 06        LDD    #$0006
36bb: 34 76           PSHS   U,Y,X,D
36bd: 17 24 e1        LBSR   $5BA1       ; → write port: clear bit 2
36c0: 32 68           LEAS   $8,S
36c2: 16 00 27        LBRA   $36EC       ; → exit
; Disable path: only write if $23C1 bit 4 is clear
36c5: fc 23 c1        LDD    $23C1
36c8: 84 00           ANDA   #$00
36ca: c4 10           ANDB   #$10        ; test $23C1 bit 4
36cc: 10 83 00 00     CMPD   #$0000
36d0: 10 26 00 18     LBNE   $36EC       ; bit 4 set → skip write, exit
36d4: c6 04           LDB    #$04
36d6: 1d              SEX
36d7: 1f 03           TFR    D,U         ; U = value $04 (set bit)
36d9: c6 04           LDB    #$04
36db: 1d              SEX
36dc: 1f 02           TFR    D,Y         ; Y = mask $04 (bit 2)
36de: ae e9 00 06     LDX    $0006,S     ; X = port index
36e2: cc 00 06        LDD    #$0006
36e5: 34 76           PSHS   U,Y,X,D
36e7: 17 24 b7        LBSR   $5BA1       ; → write port: set bit 2
36ea: 32 68           LEAS   $8,S
36ec: 32 62           LEAS   $2,S        ; deallocate frame
36ee: 39              RTS
; I/O port read with conditional enable — $36EF.
; If port index (arg 1) > 3, returns default result ($02). If enable (arg 2) is nonzero,
; clears the local result. Writes value/mask to port via $5BA1 with mask=$02.
36ef: fc c1 c6        LDD    $C1C6
36f2: 17 46 5b        LBSR   $7D50       ; allocate frame
36f5: c6 02           LDB    #$02
36f7: e7 62           STB    $2,S        ; default value = $02
36f9: ae e9 00 07     LDX    $0007,S     ; X = port index
36fd: 8c 00 03        CMPX   #$0003      ; valid port (0-3)?
3700: 10 23 00 03     LBLS   $3707       ; yes → proceed
3704: 16 00 25        LBRA   $372C       ; no → exit with default
3707: ae e9 00 09     LDX    $0009,S     ; X = enable arg
370b: 8c 00 00        CMPX   #$0000      ; enable == 0?
370e: 10 27 00 02     LBEQ   $3714       ; yes → keep default $02
3712: 6f 62           CLR    $2,S        ; enable nonzero → value = $00
3714: e6 62           LDB    $2,S
3716: 4f              CLRA
3717: 1f 03           TFR    D,U         ; U = value ($00 or $02)
3719: c6 02           LDB    #$02
371b: 1d              SEX
371c: 1f 02           TFR    D,Y         ; Y = mask $02 (bit 1)
371e: ae e9 00 07     LDX    $0007,S     ; X = port index
3722: cc 00 06        LDD    #$0006
3725: 34 76           PSHS   U,Y,X,D
3727: 17 24 77        LBSR   $5BA1       ; → $5BA1: write port
372a: 32 68           LEAS   $8,S
372c: 32 63           LEAS   $3,S        ; deallocate frame
372e: 39              RTS
; Channel output enable/disable — $372F.
; Handles channel index 0 or 1. For channel 0: if $23B3 is nonzero calls $1A53 (enable
; output), else calls $1A6E (disable). For channel 1: uses $23B4 and $1A57/$1A72.
372f: fc c1 c8        LDD    $C1C8
3732: 17 46 1b        LBSR   $7D50       ; allocate frame
3735: ae e9 00 06     LDX    $0006,S     ; X = channel index
3739: 8c 00 01        CMPX   #$0001      ; valid (0 or 1)?
373c: 10 23 00 03     LBLS   $3743       ; yes → proceed
3740: 16 00 56        LBRA   $3799       ; no → exit
; --- Channel 0 ---
3743: ae e9 00 06     LDX    $0006,S     ; X = channel index
3747: 8c 00 00        CMPX   #$0000      ; channel 0?
374a: 10 26 00 20     LBNE   $376E       ; no → check channel 1
374e: f6 23 b3        LDB    $23B3       ; channel 0 enable flag
3751: c1 00           CMPB   #$00
3753: 10 27 00 0d     LBEQ   $3764       ; flag clear → disable
3757: ce 00 00        LDU    #$0000
375a: 34 40           PSHS   U
375c: 17 e2 f4        LBSR   $1A53       ; → enable channel 0 output
375f: 32 62           LEAS   $2,S
3761: 16 00 0a        LBRA   $376E       ; → check channel 1
3764: ce 00 00        LDU    #$0000
3767: 34 40           PSHS   U
3769: 17 e3 02        LBSR   $1A6E       ; → disable channel 0 output
376c: 32 62           LEAS   $2,S
; --- Channel 1 ---
376e: ae e9 00 06     LDX    $0006,S     ; X = channel index
3772: 8c 00 01        CMPX   #$0001      ; channel 1?
3775: 10 26 00 20     LBNE   $3799       ; no → exit
3779: f6 23 b4        LDB    $23B4       ; channel 1 enable flag
377c: c1 00           CMPB   #$00
377e: 10 27 00 0d     LBEQ   $378F       ; flag clear → disable
3782: ce 00 00        LDU    #$0000
3785: 34 40           PSHS   U
3787: 17 e2 cd        LBSR   $1A57       ; → enable channel 1 output
378a: 32 62           LEAS   $2,S
378c: 16 00 0a        LBRA   $3799       ; → exit
378f: ce 00 00        LDU    #$0000
3792: 34 40           PSHS   U
3794: 17 e2 db        LBSR   $1A72       ; → disable channel 1 output
3797: 32 62           LEAS   $2,S
3799: 32 62           LEAS   $2,S        ; deallocate frame
379b: 39              RTS
; Channel output enable with state store — $379C.
; If port index (arg 1) > 3, returns. If enable (arg 2) is nonzero: sets $23B3+port
; to $FF and writes $00/$04 to port via $5BA1. If zero: clears $23B3+port, writes
; $04/$04. Then calls $372F with the port's value byte.
379c: fc c1 c6        LDD    $C1C6
379f: 17 45 ae        LBSR   $7D50       ; allocate frame
37a2: ae e9 00 07     LDX    $0007,S     ; X = port index
37a6: 8c 00 03        CMPX   #$0003      ; valid (0-3)?
37a9: 10 23 00 03     LBLS   $37B0       ; yes → proceed
37ad: 16 00 6b        LBRA   $381B       ; no → exit
37b0: ae e9 00 09     LDX    $0009,S     ; X = enable arg
37b4: 8c 00 00        CMPX   #$0000      ; enable == 0?
37b7: 10 27 00 27     LBEQ   $37E2       ; yes → disable path
; Enable: set $23B3[port] = $FF, write $00/$04 (clear bit 2)
37bb: 8e 23 b3        LDX    #$23B3      ; per-port enable flags
37be: ec e9 00 07     LDD    $0007,S     ; D = port index
37c2: 30 8b           LEAX   D,X         ; X = &$23B3[port]
37c4: c6 ff           LDB    #$FF
37c6: e7 84           STB    ,X          ; mark enabled
37c8: 5f              CLRB
37c9: 1d              SEX
37ca: 1f 03           TFR    D,U         ; U = value $00
37cc: c6 04           LDB    #$04
37ce: 1d              SEX
37cf: 1f 02           TFR    D,Y         ; Y = mask $04
37d1: ae e9 00 07     LDX    $0007,S     ; X = port index
37d5: cc 00 06        LDD    #$0006
37d8: 34 76           PSHS   U,Y,X,D
37da: 17 23 c4        LBSR   $5BA1       ; → write port: clear bit 2
37dd: 32 68           LEAS   $8,S
37df: 16 00 23        LBRA   $3805       ; → call $372F
; Disable: clear $23B3[port], write $04/$04 (set bit 2)
37e2: 8e 23 b3        LDX    #$23B3
37e5: ec e9 00 07     LDD    $0007,S     ; D = port index
37e9: 30 8b           LEAX   D,X
37eb: 6f 84           CLR    ,X          ; mark disabled
37ed: c6 04           LDB    #$04
37ef: 1d              SEX
37f0: 1f 03           TFR    D,U         ; U = value $04
37f2: c6 04           LDB    #$04
37f4: 1d              SEX
37f5: 1f 02           TFR    D,Y         ; Y = mask $04
37f7: ae e9 00 07     LDX    $0007,S     ; X = port index
37fb: cc 00 06        LDD    #$0006
37fe: 34 76           PSHS   U,Y,X,D
3800: 17 23 9e        LBSR   $5BA1       ; → write port: set bit 2
3803: 32 68           LEAS   $8,S
; Apply output enable/disable via $372F
3805: e6 e9 00 08     LDB    $0008,S     ; B = port index (low byte)
3809: e7 62           STB    $2,S
380b: e6 62           LDB    $2,S
380d: 4f              CLRA
380e: 1f 03           TFR    D,U         ; U = port index
3810: 10 8e 00 02     LDY    #$0002
3814: 34 60           PSHS   U,Y
3816: 17 ff 16        LBSR   $372F       ; → channel output enable/disable
3819: 32 64           LEAS   $4,S
381b: 32 63           LEAS   $3,S        ; deallocate frame
381d: 39              RTS
; Reset all I/O ports with full mask — $381E.
; Iterates ports 0-3, writing value=$84/mask=$FF to each via $5BA1, then clears $0800.
381e: fc c1 c6        LDD    $C1C6
3821: 17 45 2c        LBSR   $7D50       ; allocate frame
3824: 6f 62           CLR    $2,S        ; port index = 0
3826: e6 62           LDB    $2,S        ; loop: load port index
3828: c1 04           CMPB   #$04        ; all 4 ports done?
382a: 10 24 00 1e     LBCC   $384C       ; yes → clear strobe
382e: ce 00 84        LDU    #$0084      ; U = value $84 (output enable + bit 2)
3831: 10 8e 00 ff     LDY    #$00FF      ; Y = mask $FF (all bits)
3835: e6 62           LDB    $2,S
3837: 4f              CLRA
3838: 1f 01           TFR    D,X         ; X = port index
383a: cc 00 06        LDD    #$0006
383d: 34 76           PSHS   U,Y,X,D
383f: 17 23 5f        LBSR   $5BA1       ; → write port: full reset to $84
3842: 32 68           LEAS   $8,S
3844: e6 62           LDB    $2,S
3846: cb 01           ADDB   #$01        ; port index++
3848: e7 62           STB    $2,S
384a: 20 da           BRA    $3826       ; → loop
384c: 7f 08 00        CLR    $0800       ; clear strobe port
384f: 32 63           LEAS   $3,S        ; deallocate frame
3851: 39              RTS
; Hardware channel scan — $3852.
; Clears $23B2 (detected channel count). For each of ports 0-3, writes $80/$80 via $5BA1,
; clears $0800, then tests $0100 AND a shifted mask. If present, increments $23B2 and
; shifts the detection mask. After scanning all ports, calls $3646 to reset.
3852: fc c1 c9        LDD    $C1C9
3855: 17 44 f8        LBSR   $7D50       ; allocate frame
3858: 7f 23 b2        CLR    $23B2       ; detected channel count = 0
385b: 6f 62           CLR    $2,S        ; port index = 0
385d: c6 01           LDB    #$01
385f: e7 63           STB    $3,S        ; detection mask = $01 (shifts left per port)
3861: e6 62           LDB    $2,S        ; loop: load port index
3863: c1 04           CMPB   #$04        ; all 4 ports scanned?
3865: 10 24 00 37     LBCC   $38A0       ; yes → reset and exit
; Activate port: write $80/$80 (set enable bit)
3869: ce 00 80        LDU    #$0080      ; U = value $80
386c: 10 8e 00 80     LDY    #$0080      ; Y = mask $80
3870: e6 62           LDB    $2,S
3872: 4f              CLRA
3873: 1f 01           TFR    D,X         ; X = port index
3875: cc 00 06        LDD    #$0006
3878: 34 76           PSHS   U,Y,X,D
387a: 17 23 24        LBSR   $5BA1       ; → activate port output
387d: 32 68           LEAS   $8,S
387f: 7f 08 00        CLR    $0800       ; clear strobe
; Test if hardware responded: AND mask with $0100 status
3882: e6 63           LDB    $3,S        ; B = detection mask
3884: f4 01 00        ANDB   $0100       ; AND with status latch
3887: 10 27 00 03     LBEQ   $388E       ; zero → channel present (active-low)
388b: 16 00 12        LBRA   $38A0       ; nonzero → no channel, stop scan
; Channel detected
388e: f6 23 b2        LDB    $23B2
3891: cb 01           ADDB   #$01        ; channel count++
3893: f7 23 b2        STB    $23B2
3896: 68 63           ASL    $3,S        ; shift detection mask left
3898: e6 62           LDB    $2,S
389a: cb 01           ADDB   #$01        ; port index++
389c: e7 62           STB    $2,S
389e: 20 c1           BRA    $3861       ; → scan next port
; Scan complete: reset all ports
38a0: ce 00 00        LDU    #$0000
38a3: 34 40           PSHS   U
38a5: 17 fd 9e        LBSR   $3646       ; → reset all output ports
38a8: 32 62           LEAS   $2,S
38aa: 32 64           LEAS   $4,S        ; deallocate frame
38ac: 39              RTS
; Packed parameter comparison — $38AD.
; Compares a caller-provided value against the packed data at [$23B7] via $53C6.
; Returns the comparison result in B.
38ad: fc c1 cb        LDD    $C1CB
38b0: 17 44 9d        LBSR   $7D50
38b3: 33 62           LEAU   $2,S
38b5: 10 ae e9 00 0a  LDY    $000A,S
38ba: be 23 b7        LDX    $23B7
38bd: cc 00 06        LDD    #$0006
38c0: 34 76           PSHS   U,Y,X,D
38c2: 17 1b 01        LBSR   $53C6
38c5: 32 68           LEAS   $8,S
38c7: e7 65           STB    $5,S
38c9: 32 66           LEAS   $6,S
38cb: 39              RTS
; Channel parameter validation and storage — $38CC.
; Looks up channel parameters via $7CEA (array indexer) into the $24F5 channel data
; structure at $C1CD. Validates against expected mode values and stores results into
; working buffers via $537D/$534B. Uses math routines $7D8F/$7E59/$7FA4 for scaling.
38cc: fc c1 d3        LDD    $C1D3
38cf: 17 44 7e        LBSR   $7D50
38d2: ce 24 f5        LDU    #$24F5
38d5: 10 ae e9 00 13  LDY    $0013,S
38da: 34 60           PSHS   U,Y
38dc: 86 01           LDA    #$01
38de: 8e c1 cd        LDX    #$C1CD
38e1: 17 44 06        LBSR   $7CEA
38e4: 30 88 21        LEAX   $21,X
38e7: ae 84           LDX    ,X
38e9: af 65           STX    $5,S
38eb: ae 65           LDX    $5,S
38ed: 8c 00 10        CMPX   #$0010
38f0: 10 26 00 05     LBNE   $38F9
38f4: 6f 6c           CLR    $C,S
38f6: 16 01 2e        LBRA   $3A27
38f9: fc 25 16        LDD    $2516
38fc: ed 67           STD    $7,S
38fe: ee e9 00 15     LDU    $0015,S
3902: 31 62           LEAY   $2,S
3904: 8e 00 04        LDX    #$0004
3907: 34 70           PSHS   U,Y,X
3909: 17 1a 71        LBSR   $537D
390c: 32 66           LEAS   $6,S
390e: ae 65           LDX    $5,S
3910: 8c 00 09        CMPX   #$0009
3913: 10 26 00 11     LBNE   $3928
3917: 33 62           LEAU   $2,S
3919: 10 8e 00 02     LDY    #$0002
391d: 34 60           PSHS   U,Y
391f: 8d 8c           BSR    $38AD
3921: 32 64           LEAS   $4,S
3923: e7 6c           STB    $C,S
3925: 16 00 ff        LBRA   $3A27
3928: 6f 6b           CLR    $B,S
392a: e6 6b           LDB    $B,S
392c: c1 04           CMPB   #$04
392e: 10 24 00 e6     LBCC   $3A18
3932: e6 6b           LDB    $B,S
3934: 4f              CLRA
3935: 10 a3 e9 00 13  CMPD   $0013,S
393a: 10 26 00 03     LBNE   $3941
393e: 16 00 ce        LBRA   $3A0F
3941: ce 24 f5        LDU    #$24F5
3944: e6 6b           LDB    $B,S
3946: 4f              CLRA
3947: 1f 02           TFR    D,Y
3949: 34 60           PSHS   U,Y
394b: 86 01           LDA    #$01
394d: 8e c1 cd        LDX    #$C1CD
3950: 17 43 97        LBSR   $7CEA
3953: 30 88 21        LEAX   $21,X
3956: ae 84           LDX    ,X
3958: af 69           STX    $9,S
395a: ae 69           LDX    $9,S
395c: ac 65           CMPX   $5,S
395e: 10 27 00 2b     LBEQ   $398D
3962: ae 69           LDX    $9,S
3964: 8c 00 0a        CMPX   #$000A
3967: 10 26 00 0b     LBNE   $3976
396b: ae 65           LDX    $5,S
396d: ac 67           CMPX   $7,S
396f: 10 26 00 03     LBNE   $3976
3973: 16 00 17        LBRA   $398D
3976: ae 69           LDX    $9,S
3978: ac 67           CMPX   $7,S
397a: 10 26 00 0c     LBNE   $398A
397e: ae 65           LDX    $5,S
3980: 8c 00 0a        CMPX   #$000A
3983: 10 26 00 03     LBNE   $398A
3987: 16 00 03        LBRA   $398D
398a: 16 00 82        LBRA   $3A0F
398d: e6 6b           LDB    $B,S
398f: c1 00           CMPB   #$00
3991: 10 26 00 12     LBNE   $39A7
3995: fc 22 02        LDD    $2202
3998: 84 00           ANDA   #$00
399a: c4 40           ANDB   #$40
399c: 10 83 00 00     CMPD   #$0000
39a0: 10 27 00 03     LBEQ   $39A7
39a4: 16 00 03        LBRA   $39AA
39a7: 16 00 32        LBRA   $39DC
39aa: ce 00 04        LDU    #$0004
39ad: 10 8e 00 02     LDY    #$0002
39b1: 34 60           PSHS   U,Y
39b3: 17 2f ac        LBSR   $6962
39b6: 32 64           LEAS   $4,S
39b8: 1f 01           TFR    D,X
39ba: af 6d           STX    $D,S
39bc: 33 62           LEAU   $2,S
39be: 31 62           LEAY   $2,S
39c0: ae 6d           LDX    $D,S
39c2: cc 00 06        LDD    #$0006
39c5: 34 76           PSHS   U,Y,X,D
39c7: 17 19 c8        LBSR   $5392
39ca: 32 68           LEAS   $8,S
39cc: c1 00           CMPB   #$00
39ce: 10 27 00 07     LBEQ   $39D9
39d2: c6 01           LDB    #$01
39d4: e7 6c           STB    $C,S
39d6: 16 00 4e        LBRA   $3A27
39d9: 16 00 33        LBRA   $3A0F
39dc: ce 24 f5        LDU    #$24F5
39df: e6 6b           LDB    $B,S
39e1: 4f              CLRA
39e2: 1f 02           TFR    D,Y
39e4: 34 60           PSHS   U,Y
39e6: 86 01           LDA    #$01
39e8: 8e c1 cd        LDX    #$C1CD
39eb: 17 42 fc        LBSR   $7CEA
39ee: 30 0a           LEAX   $A,X
39f0: af 6d           STX    $D,S
39f2: 33 62           LEAU   $2,S
39f4: 31 62           LEAY   $2,S
39f6: ae 6d           LDX    $D,S
39f8: cc 00 06        LDD    #$0006
39fb: 34 76           PSHS   U,Y,X,D
39fd: 17 19 92        LBSR   $5392
3a00: 32 68           LEAS   $8,S
3a02: c1 00           CMPB   #$00
3a04: 10 27 00 07     LBEQ   $3A0F
3a08: c6 01           LDB    #$01
3a0a: e7 6c           STB    $C,S
3a0c: 16 00 18        LBRA   $3A27
3a0f: e6 6b           LDB    $B,S
3a11: cb 01           ADDB   #$01
3a13: e7 6b           STB    $B,S
3a15: 16 ff 12        LBRA   $392A
3a18: 33 62           LEAU   $2,S
3a1a: 10 8e 00 02     LDY    #$0002
3a1e: 34 60           PSHS   U,Y
3a20: 17 fe 8a        LBSR   $38AD
3a23: 32 64           LEAS   $4,S
3a25: e7 6c           STB    $C,S
3a27: e6 6c           LDB    $C,S
3a29: 32 6f           LEAS   $F,S
3a2b: 39              RTS
; Channel parameter update for all matching channels — $3A2C.
; Copies ROM defaults from $EA58 into $23B9, then iterates channels 0-3. For each,
; looks up channel data via $7CEA at $C1CD, compares the mode field (offset $21) against
; the caller's argument. If channel 0 matches and $2202 bit 6 is set, calls $6962.
; Otherwise copies channel data (offset $0A) into $23B9 via $5392.
3a2c: fc c1 c6        LDD    $C1C6
3a2f: 17 43 1e        LBSR   $7D50
3a32: ce ea 58        LDU    #$EA58
3a35: 10 8e 23 b9     LDY    #$23B9
3a39: 8e 00 04        LDX    #$0004
3a3c: 34 70           PSHS   U,Y,X
3a3e: 17 19 3c        LBSR   $537D
3a41: 32 66           LEAS   $6,S
3a43: 6f 62           CLR    $2,S
3a45: e6 62           LDB    $2,S
3a47: c1 04           CMPB   #$04
3a49: 10 24 00 93     LBCC   $3AE0
3a4d: ce 24 f5        LDU    #$24F5
3a50: e6 62           LDB    $2,S
3a52: 4f              CLRA
3a53: 1f 02           TFR    D,Y
3a55: 34 60           PSHS   U,Y
3a57: 86 01           LDA    #$01
3a59: 8e c1 cd        LDX    #$C1CD
3a5c: 17 42 8b        LBSR   $7CEA
3a5f: 30 88 21        LEAX   $21,X
3a62: ae 84           LDX    ,X
3a64: ac e9 00 07     CMPX   $0007,S
3a68: 10 27 00 03     LBEQ   $3A6F
3a6c: 16 00 68        LBRA   $3AD7
3a6f: e6 62           LDB    $2,S
3a71: c1 00           CMPB   #$00
3a73: 10 26 00 12     LBNE   $3A89
3a77: fc 22 02        LDD    $2202
3a7a: 84 00           ANDA   #$00
3a7c: c4 40           ANDB   #$40
3a7e: 10 83 00 00     CMPD   #$0000
3a82: 10 27 00 03     LBEQ   $3A89
3a86: 16 00 03        LBRA   $3A8C
3a89: 16 00 25        LBRA   $3AB1
3a8c: ce 00 04        LDU    #$0004
3a8f: 10 8e 00 02     LDY    #$0002
3a93: 34 60           PSHS   U,Y
3a95: 17 2e ca        LBSR   $6962
3a98: 32 64           LEAS   $4,S
3a9a: 1f 01           TFR    D,X
3a9c: ce 23 b9        LDU    #$23B9
3a9f: 1f 12           TFR    X,Y
3aa1: 8e 23 b9        LDX    #$23B9
3aa4: cc 00 06        LDD    #$0006
3aa7: 34 76           PSHS   U,Y,X,D
3aa9: 17 18 e6        LBSR   $5392
3aac: 32 68           LEAS   $8,S
3aae: 16 00 26        LBRA   $3AD7
3ab1: ce 24 f5        LDU    #$24F5
3ab4: e6 62           LDB    $2,S
3ab6: 4f              CLRA
3ab7: 1f 02           TFR    D,Y
3ab9: 34 60           PSHS   U,Y
3abb: 86 01           LDA    #$01
3abd: 8e c1 cd        LDX    #$C1CD
3ac0: 17 42 27        LBSR   $7CEA
3ac3: 30 0a           LEAX   $A,X
3ac5: ce 23 b9        LDU    #$23B9
3ac8: 1f 12           TFR    X,Y
3aca: 8e 23 b9        LDX    #$23B9
3acd: cc 00 06        LDD    #$0006
3ad0: 34 76           PSHS   U,Y,X,D
3ad2: 17 18 bd        LBSR   $5392
3ad5: 32 68           LEAS   $8,S
3ad7: e6 62           LDB    $2,S
3ad9: cb 01           ADDB   #$01
3adb: e7 62           STB    $2,S
3add: 16 ff 65        LBRA   $3A45
3ae0: 32 63           LEAS   $3,S
3ae2: 39              RTS
; Channel parameter read with scaling — $3AE3.
; Calls $3A2C with mode=$08, copies result from $23B9 via $534B, then passes the
; comparison result to $636F. Iterates channels 1-3, and for channels matching mode $08,
; reads channel data, applies arithmetic scaling ($7D8F/$7E59/$7FA4), and stores via $6478.
3ae3: fc c1 d5        LDD    $C1D5
3ae6: 17 42 67        LBSR   $7D50
3ae9: ce 00 08        LDU    #$0008
3aec: 10 8e 00 02     LDY    #$0002
3af0: 34 60           PSHS   U,Y
3af2: 17 ff 37        LBSR   $3A2C
3af5: 32 64           LEAS   $4,S
3af7: ce 23 b9        LDU    #$23B9
3afa: 31 65           LEAY   $5,S
3afc: 8e 00 04        LDX    #$0004
3aff: 34 70           PSHS   U,Y,X
3b01: 17 18 47        LBSR   $534B
3b04: 32 66           LEAS   $6,S
3b06: e7 64           STB    $4,S
3b08: e6 64           LDB    $4,S
3b0a: 4f              CLRA
3b0b: 1f 03           TFR    D,U
3b0d: 10 8e 00 02     LDY    #$0002
3b11: 34 60           PSHS   U,Y
3b13: 17 28 59        LBSR   $636F
3b16: 32 64           LEAS   $4,S
3b18: c6 01           LDB    #$01
3b1a: e7 62           STB    $2,S
3b1c: e6 62           LDB    $2,S
3b1e: c1 04           CMPB   #$04
3b20: 10 24 00 71     LBCC   $3B95
3b24: ce 24 f5        LDU    #$24F5
3b27: e6 62           LDB    $2,S
3b29: 4f              CLRA
3b2a: 1f 02           TFR    D,Y
3b2c: 34 60           PSHS   U,Y
3b2e: 86 01           LDA    #$01
3b30: 8e c1 cd        LDX    #$C1CD
3b33: 17 41 b4        LBSR   $7CEA
3b36: 30 88 21        LEAX   $21,X
3b39: ae 84           LDX    ,X
3b3b: 8c 00 08        CMPX   #$0008
3b3e: 10 27 00 03     LBEQ   $3B45
3b42: 16 00 48        LBRA   $3B8D
3b45: ce 24 f5        LDU    #$24F5
3b48: e6 62           LDB    $2,S
3b4a: 4f              CLRA
3b4b: 1f 02           TFR    D,Y
3b4d: 34 60           PSHS   U,Y
3b4f: 86 01           LDA    #$01
3b51: 8e c1 cd        LDX    #$C1CD
3b54: 17 41 93        LBSR   $7CEA
3b57: 30 0a           LEAX   $A,X
3b59: af 67           STX    $7,S
3b5b: ee 67           LDU    $7,S
3b5d: 31 65           LEAY   $5,S
3b5f: 8e 00 04        LDX    #$0004
3b62: 34 70           PSHS   U,Y,X
3b64: 17 17 e4        LBSR   $534B
3b67: 32 66           LEAS   $6,S
3b69: e7 63           STB    $3,S
3b6b: a6 63           LDA    $3,S
3b6d: e6 64           LDB    $4,S
3b6f: 17 42 1d        LBSR   $7D8F
3b72: 17 42 e4        LBSR   $7E59
3b75: ae 65           LDX    $5,S
3b77: 17 44 2a        LBSR   $7FA4
3b7a: ed 65           STD    $5,S
3b7c: ee 65           LDU    $5,S
3b7e: e6 62           LDB    $2,S
3b80: 4f              CLRA
3b81: 1f 02           TFR    D,Y
3b83: 8e 00 04        LDX    #$0004
3b86: 34 70           PSHS   U,Y,X
3b88: 17 28 ed        LBSR   $6478
3b8b: 32 66           LEAS   $6,S
3b8d: e6 62           LDB    $2,S
3b8f: cb 01           ADDB   #$01
3b91: e7 62           STB    $2,S
3b93: 20 87           BRA    $3B1C
3b95: 32 69           LEAS   $9,S
3b97: 39              RTS
; Frequency parameter scaling — $3B98.
; Reads a raw parameter from the caller's data pointer, clamps to max $03E8 (1000).
; If under limit, performs binary long division against $03E8 (up to 16 iterations),
; then multiplies the quotient by $23BC via $5303. For mode $05 channels, applies
; additional scaling via $B6C9. Returns the scaled 16-bit result in D.
3b98: fc c1 d7        LDD    $C1D7
3b9b: 17 41 b2        LBSR   $7D50
3b9e: ae e9 00 14     LDX    $0014,S
3ba2: 30 01           LEAX   $1,X
3ba4: ae 84           LDX    ,X
3ba6: af 62           STX    $2,S
3ba8: ae 62           LDX    $2,S
3baa: 8c 03 e8        CMPX   #$03E8
3bad: 10 25 00 08     LBCS   $3BB9
3bb1: fc 23 bc        LDD    $23BC
3bb4: ed 64           STD    $4,S
3bb6: 16 00 4e        LBRA   $3C07
3bb9: cc 03 e8        LDD    #$03E8
3bbc: ed 66           STD    $6,S
3bbe: 5f              CLRB
3bbf: 4f              CLRA
3bc0: ed 68           STD    $8,S
3bc2: 5f              CLRB
3bc3: 4f              CLRA
3bc4: ed 6a           STD    $A,S
3bc6: ae 6a           LDX    $A,S
3bc8: 8c 00 10        CMPX   #$0010
3bcb: 10 24 00 26     LBCC   $3BF5
3bcf: ae 62           LDX    $2,S
3bd1: ac 66           CMPX   $6,S
3bd3: 10 23 00 0d     LBLS   $3BE4
3bd7: ec 62           LDD    $2,S
3bd9: a3 66           SUBD   $6,S
3bdb: ed 62           STD    $2,S
3bdd: ec 68           LDD    $8,S
3bdf: c3 00 01        ADDD   #$0001
3be2: ed 68           STD    $8,S
3be4: 68 63           ASL    $3,S
3be6: 69 62           ROL    $2,S
3be8: 68 69           ASL    $9,S
3bea: 69 68           ROL    $8,S
3bec: ec 6a           LDD    $A,S
3bee: c3 00 01        ADDD   #$0001
3bf1: ed 6a           STD    $A,S
3bf3: 20 d1           BRA    $3BC6
3bf5: ee 68           LDU    $8,S
3bf7: 10 be 23 bc     LDY    $23BC
3bfb: 8e 00 04        LDX    #$0004
3bfe: 34 70           PSHS   U,Y,X
3c00: 17 17 00        LBSR   $5303
3c03: 32 66           LEAS   $6,S
3c05: ed 64           STD    $4,S
3c07: ce 24 f5        LDU    #$24F5
3c0a: 10 ae e9 00 12  LDY    $0012,S
3c0f: 34 60           PSHS   U,Y
3c11: 86 01           LDA    #$01
3c13: 8e c1 cd        LDX    #$C1CD
3c16: 17 40 d1        LBSR   $7CEA
3c19: 30 88 1f        LEAX   $1F,X
3c1c: ae 84           LDX    ,X
3c1e: 8c 00 05        CMPX   #$0005
3c21: 10 26 00 12     LBNE   $3C37
3c25: ce b6 c9        LDU    #$B6C9
3c28: 10 ae 64        LDY    $4,S
3c2b: 8e 00 04        LDX    #$0004
3c2e: 34 70           PSHS   U,Y,X
3c30: 17 16 d0        LBSR   $5303
3c33: 32 66           LEAS   $6,S
3c35: ed 64           STD    $4,S
3c37: ec 64           LDD    $4,S
3c39: ed 6c           STD    $C,S
3c3b: 32 6e           LEAS   $E,S
3c3d: 39              RTS
; Frequency tuning word computation — $3C3E.
; Checks if $2514 == 4 (flags a special mode). Saves/clears $24F4 (channel iterator).
; For each of up to 16 entries in the $2581 array (via $7CEA at $C1D9), reads a 7-byte
; record via $53EC, applies offset/scaling adjustments based on the special mode flag
; (mirrors around $1000/$0800 boundary), then writes the computed tuning word back
; into the array (offset $02). Calls $5E2E to program the hardware. Restores $24F4.
3c3e: fc c1 df        LDD    $C1DF
3c41: 17 41 0c        LBSR   $7D50
3c44: 6f 65           CLR    $5,S
3c46: be 25 14        LDX    $2514
3c49: 8c 00 04        CMPX   #$0004
3c4c: 10 26 00 04     LBNE   $3C54
3c50: c6 01           LDB    #$01
3c52: e7 65           STB    $5,S
3c54: f6 24 f4        LDB    $24F4
3c57: e7 62           STB    $2,S
3c59: 7f 24 f4        CLR    $24F4
3c5c: f6 24 f4        LDB    $24F4
3c5f: c1 10           CMPB   #$10
3c61: 10 24 00 b3     LBCC   $3D18
3c65: 6f 64           CLR    $4,S
3c67: ce 25 81        LDU    #$2581
3c6a: f6 24 f4        LDB    $24F4
3c6d: 4f              CLRA
3c6e: 1f 02           TFR    D,Y
3c70: 34 60           PSHS   U,Y
3c72: 86 01           LDA    #$01
3c74: 8e c1 d9        LDX    #$C1D9
3c77: 17 40 70        LBSR   $7CEA
3c7a: 30 07           LEAX   $7,X
3c7c: af 68           STX    $8,S
3c7e: 33 66           LEAU   $6,S
3c80: 10 ae 68        LDY    $8,S
3c83: 5f              CLRB
3c84: 1d              SEX
3c85: 1f 01           TFR    D,X
3c87: cc 00 06        LDD    #$0006
3c8a: 34 76           PSHS   U,Y,X,D
3c8c: 17 17 5d        LBSR   $53EC
3c8f: 32 68           LEAS   $8,S
3c91: e7 63           STB    $3,S
3c93: e6 65           LDB    $5,S
3c95: c1 00           CMPB   #$00
3c97: 10 27 00 0c     LBEQ   $3CA7
3c9b: ae 66           LDX    $6,S
3c9d: 8c 08 00        CMPX   #$0800
3ca0: 10 2d 00 03     LBLT   $3CA7
3ca4: 16 00 03        LBRA   $3CAA
3ca7: 16 00 0b        LBRA   $3CB5
3caa: cc 10 00        LDD    #$1000
3cad: a3 66           SUBD   $6,S
3caf: ed 66           STD    $6,S
3cb1: c6 01           LDB    #$01
3cb3: e7 64           STB    $4,S
3cb5: e6 63           LDB    $3,S
3cb7: 4f              CLRA
3cb8: a3 e9 00 0e     SUBD   $000E,S
3cbc: 17 41 9a        LBSR   $7E59
3cbf: ae 66           LDX    $6,S
3cc1: 17 42 e0        LBSR   $7FA4
3cc4: ed 66           STD    $6,S
3cc6: e6 64           LDB    $4,S
3cc8: c1 00           CMPB   #$00
3cca: 10 27 00 15     LBEQ   $3CE3
3cce: cc 0f ff        LDD    #$0FFF
3cd1: a3 66           SUBD   $6,S
3cd3: ed 66           STD    $6,S
3cd5: ae 66           LDX    $6,S
3cd7: 8c 08 00        CMPX   #$0800
3cda: 10 26 00 05     LBNE   $3CE3
3cde: cc 08 01        LDD    #$0801
3ce1: ed 66           STD    $6,S
3ce3: ce 25 81        LDU    #$2581
3ce6: f6 24 f4        LDB    $24F4
3ce9: 4f              CLRA
3cea: 1f 02           TFR    D,Y
3cec: 34 60           PSHS   U,Y
3cee: 86 01           LDA    #$01
3cf0: 8e c1 d9        LDX    #$C1D9
3cf3: 17 3f f4        LBSR   $7CEA
3cf6: 30 02           LEAX   $2,X
3cf8: ec 66           LDD    $6,S
3cfa: ed 84           STD    ,X
3cfc: f6 24 f4        LDB    $24F4
3cff: 4f              CLRA
3d00: 1f 03           TFR    D,U
3d02: 10 8e 00 02     LDY    #$0002
3d06: 34 60           PSHS   U,Y
3d08: 17 21 23        LBSR   $5E2E
3d0b: 32 64           LEAS   $4,S
3d0d: f6 24 f4        LDB    $24F4
3d10: cb 01           ADDB   #$01
3d12: f7 24 f4        STB    $24F4
3d15: 16 ff 44        LBRA   $3C5C
3d18: e6 62           LDB    $2,S
3d1a: f7 24 f4        STB    $24F4
3d1d: 32 6a           LEAS   $A,S
3d1f: 39              RTS
; Apply parameter update to matching channels — $3D20.
; Iterates channels 0-3 in the $24F5 structure. For each channel whose mode field
; (offset $21) matches the caller's argument: channel 0 with $2202 bit 6 set calls
; $3C3E directly; otherwise reads channel data via $53EC and stores updated parameters
; back. Copies the caller's parameter byte into the channel record.
3d20: fc c1 d5        LDD    $C1D5
3d23: 17 40 2a        LBSR   $7D50
3d26: e6 e9 00 0e     LDB    $000E,S
3d2a: e7 64           STB    $4,S
3d2c: 6f 62           CLR    $2,S
3d2e: e6 62           LDB    $2,S
3d30: c1 04           CMPB   #$04
3d32: 10 24 01 23     LBCC   $3E59
3d36: ce 24 f5        LDU    #$24F5
3d39: e6 62           LDB    $2,S
3d3b: 4f              CLRA
3d3c: 1f 02           TFR    D,Y
3d3e: 34 60           PSHS   U,Y
3d40: 86 01           LDA    #$01
3d42: 8e c1 cd        LDX    #$C1CD
3d45: 17 3f a2        LBSR   $7CEA
3d48: 30 88 21        LEAX   $21,X
3d4b: ae 84           LDX    ,X
3d4d: ac e9 00 0f     CMPX   $000F,S
3d51: 10 27 00 03     LBEQ   $3D58
3d55: 16 00 f8        LBRA   $3E50
3d58: 6f 63           CLR    $3,S
3d5a: e6 62           LDB    $2,S
3d5c: c1 00           CMPB   #$00
3d5e: 10 26 00 12     LBNE   $3D74
3d62: fc 22 02        LDD    $2202
3d65: 84 00           ANDA   #$00
3d67: c4 40           ANDB   #$40
3d69: 10 83 00 00     CMPD   #$0000
3d6d: 10 27 00 03     LBEQ   $3D74
3d71: 16 00 03        LBRA   $3D77
3d74: 16 00 16        LBRA   $3D8D
3d77: e6 64           LDB    $4,S
3d79: 4f              CLRA
3d7a: 1f 03           TFR    D,U
3d7c: 10 8e 00 02     LDY    #$0002
3d80: 34 60           PSHS   U,Y
3d82: 17 fe b9        LBSR   $3C3E
3d85: 32 64           LEAS   $4,S
3d87: 16 00 c6        LBRA   $3E50
3d8a: 16 00 2c        LBRA   $3DB9
3d8d: ce 24 f5        LDU    #$24F5
3d90: e6 62           LDB    $2,S
3d92: 4f              CLRA
3d93: 1f 02           TFR    D,Y
3d95: 34 60           PSHS   U,Y
3d97: 86 01           LDA    #$01
3d99: 8e c1 cd        LDX    #$C1CD
3d9c: 17 3f 4b        LBSR   $7CEA
3d9f: 30 0a           LEAX   $A,X
3da1: af 67           STX    $7,S
3da3: 33 65           LEAU   $5,S
3da5: 10 ae 67        LDY    $7,S
3da8: e6 62           LDB    $2,S
3daa: 4f              CLRA
3dab: 1f 01           TFR    D,X
3dad: cc 00 06        LDD    #$0006
3db0: 34 76           PSHS   U,Y,X,D
3db2: 17 16 37        LBSR   $53EC
3db5: 32 68           LEAS   $8,S
3db7: e7 64           STB    $4,S
3db9: ce 24 f5        LDU    #$24F5
3dbc: e6 62           LDB    $2,S
3dbe: 4f              CLRA
3dbf: 1f 02           TFR    D,Y
3dc1: 34 60           PSHS   U,Y
3dc3: 86 01           LDA    #$01
3dc5: 8e c1 cd        LDX    #$C1CD
3dc8: 17 3f 1f        LBSR   $7CEA
3dcb: 30 88 1f        LEAX   $1F,X
3dce: ae 84           LDX    ,X
3dd0: 8c 00 04        CMPX   #$0004
3dd3: 10 26 00 0c     LBNE   $3DE3
3dd7: ae 65           LDX    $5,S
3dd9: 8c 08 00        CMPX   #$0800
3ddc: 10 2d 00 03     LBLT   $3DE3
3de0: 16 00 03        LBRA   $3DE6
3de3: 16 00 0b        LBRA   $3DF1
3de6: cc 10 00        LDD    #$1000
3de9: a3 65           SUBD   $5,S
3deb: ed 65           STD    $5,S
3ded: c6 01           LDB    #$01
3def: e7 63           STB    $3,S
3df1: e6 64           LDB    $4,S
3df3: 4f              CLRA
3df4: a3 e9 00 0d     SUBD   $000D,S
3df8: 17 40 5e        LBSR   $7E59
3dfb: ae 65           LDX    $5,S
3dfd: 17 41 a4        LBSR   $7FA4
3e00: ed 65           STD    $5,S
3e02: e6 62           LDB    $2,S
3e04: c1 00           CMPB   #$00
3e06: 10 26 00 0c     LBNE   $3E16
3e0a: f6 24 0d        LDB    $240D
3e0d: c1 00           CMPB   #$00
3e0f: 10 23 00 03     LBLS   $3E16
3e13: 16 00 03        LBRA   $3E19
3e16: 16 00 09        LBRA   $3E22
3e19: ec 65           LDD    $5,S
3e1b: fd 23 bc        STD    $23BC
3e1e: 64 65           LSR    $5,S
3e20: 66 66           ROR    $6,S
3e22: e6 63           LDB    $3,S
3e24: c1 00           CMPB   #$00
3e26: 10 27 00 15     LBEQ   $3E3F
3e2a: cc 0f ff        LDD    #$0FFF
3e2d: a3 65           SUBD   $5,S
3e2f: ed 65           STD    $5,S
3e31: ae 65           LDX    $5,S
3e33: 8c 08 00        CMPX   #$0800
3e36: 10 26 00 05     LBNE   $3E3F
3e3a: cc 08 01        LDD    #$0801
3e3d: ed 65           STD    $5,S
3e3f: ee 65           LDU    $5,S
3e41: e6 62           LDB    $2,S
3e43: 4f              CLRA
3e44: 1f 02           TFR    D,Y
3e46: 8e 00 04        LDX    #$0004
3e49: 34 70           PSHS   U,Y,X
3e4b: 17 26 2a        LBSR   $6478
3e4e: 32 66           LEAS   $6,S
3e50: e6 62           LDB    $2,S
3e52: cb 01           ADDB   #$01
3e54: e7 62           STB    $2,S
3e56: 16 fe d5        LBRA   $3D2E
3e59: 32 69           LEAS   $9,S
3e5b: 39              RTS
; Channel mode selection and output configuration — $3E5C.
; Reads the mode field (offset $21) from the caller's channel in the $24F5/$C1CD structure.
; For mode $10: writes zero to channel via $6478 and returns. For mode $0A or a mode
; matching $2516: calls $4765 to get an enable byte, conditionally writes via $367B.
; If the mode matches $2516 and $240E > 0: runs a full parameter update sequence —
; $3A2C, $537D, cross-mode copy with $5392/$53EC, then $3D20 for both modes. Also
; applies $3B98 scaling to mode-$07 sub-channels and programs them via $6478.
; Finally calls $35EF/$367B for hardware I/O port programming.
3e5c: fc c1 e1        LDD    $C1E1
3e5f: 17 3e ee        LBSR   $7D50
3e62: ce 24 f5        LDU    #$24F5
3e65: 10 ae e9 00 14  LDY    $0014,S
3e6a: 34 60           PSHS   U,Y
3e6c: 86 01           LDA    #$01
3e6e: 8e c1 cd        LDX    #$C1CD
3e71: 17 3e 76        LBSR   $7CEA
3e74: 30 88 21        LEAX   $21,X
3e77: ae 84           LDX    ,X
3e79: af 62           STX    $2,S
3e7b: fc 25 16        LDD    $2516
3e7e: ed 64           STD    $4,S
3e80: ae 62           LDX    $2,S
3e82: 8c 00 10        CMPX   #$0010
3e85: 10 26 00 16     LBNE   $3E9F
3e89: 5f              CLRB
3e8a: 1d              SEX
3e8b: 1f 03           TFR    D,U
3e8d: 10 ae e9 00 14  LDY    $0014,S
3e92: 8e 00 04        LDX    #$0004
3e95: 34 70           PSHS   U,Y,X
3e97: 17 25 de        LBSR   $6478
3e9a: 32 66           LEAS   $6,S
3e9c: 16 01 c6        LBRA   $4065
3e9f: ae 62           LDX    $2,S
3ea1: 8c 00 0a        CMPX   #$000A
3ea4: 10 26 00 12     LBNE   $3EBA
3ea8: ee 64           LDU    $4,S
3eaa: 10 8e 00 02     LDY    #$0002
3eae: 34 60           PSHS   U,Y
3eb0: 17 08 b2        LBSR   $4765
3eb3: 32 64           LEAS   $4,S
3eb5: e7 68           STB    $8,S
3eb7: 16 00 0f        LBRA   $3EC9
3eba: ee 62           LDU    $2,S
3ebc: 10 8e 00 02     LDY    #$0002
3ec0: 34 60           PSHS   U,Y
3ec2: 17 08 a0        LBSR   $4765
3ec5: 32 64           LEAS   $4,S
3ec7: e7 68           STB    $8,S
3ec9: e6 68           LDB    $8,S
3ecb: 4f              CLRA
3ecc: 10 83 00 ff     CMPD   #$00FF
3ed0: 10 27 00 13     LBEQ   $3EE7
3ed4: 5f              CLRB
3ed5: 1d              SEX
3ed6: 1f 03           TFR    D,U
3ed8: e6 68           LDB    $8,S
3eda: 4f              CLRA
3edb: 1f 02           TFR    D,Y
3edd: 8e 00 04        LDX    #$0004
3ee0: 34 70           PSHS   U,Y,X
3ee2: 17 f7 96        LBSR   $367B
3ee5: 32 66           LEAS   $6,S
3ee7: ae 62           LDX    $2,S
3ee9: 8c 00 0a        CMPX   #$000A
3eec: 10 27 00 17     LBEQ   $3F07
3ef0: f6 24 0e        LDB    $240E
3ef3: c1 00           CMPB   #$00
3ef5: 10 23 00 0b     LBLS   $3F04
3ef9: ae 62           LDX    $2,S
3efb: ac 64           CMPX   $4,S
3efd: 10 26 00 03     LBNE   $3F04
3f01: 16 00 03        LBRA   $3F07
3f04: 16 00 76        LBRA   $3F7D
3f07: ee 64           LDU    $4,S
3f09: 10 8e 00 02     LDY    #$0002
3f0d: 34 60           PSHS   U,Y
3f0f: 17 fb 1a        LBSR   $3A2C
3f12: 32 64           LEAS   $4,S
3f14: ce 23 b9        LDU    #$23B9
3f17: 31 6b           LEAY   $B,S
3f19: 8e 00 04        LDX    #$0004
3f1c: 34 70           PSHS   U,Y,X
3f1e: 17 14 5c        LBSR   $537D
3f21: 32 66           LEAS   $6,S
3f23: ce 00 0a        LDU    #$000A
3f26: 10 8e 00 02     LDY    #$0002
3f2a: 34 60           PSHS   U,Y
3f2c: 17 fa fd        LBSR   $3A2C
3f2f: 32 64           LEAS   $4,S
3f31: 33 6b           LEAU   $B,S
3f33: 10 8e 23 b9     LDY    #$23B9
3f37: 30 6b           LEAX   $B,S
3f39: cc 00 06        LDD    #$0006
3f3c: 34 76           PSHS   U,Y,X,D
3f3e: 17 14 51        LBSR   $5392
3f41: 32 68           LEAS   $8,S
3f43: 33 69           LEAU   $9,S
3f45: 31 6b           LEAY   $B,S
3f47: ae e9 00 14     LDX    $0014,S
3f4b: cc 00 06        LDD    #$0006
3f4e: 34 76           PSHS   U,Y,X,D
3f50: 17 14 99        LBSR   $53EC
3f53: 32 68           LEAS   $8,S
3f55: e7 67           STB    $7,S
3f57: ce 00 0a        LDU    #$000A
3f5a: e6 67           LDB    $7,S
3f5c: 4f              CLRA
3f5d: 1f 02           TFR    D,Y
3f5f: 8e 00 04        LDX    #$0004
3f62: 34 70           PSHS   U,Y,X
3f64: 17 fd b9        LBSR   $3D20
3f67: 32 66           LEAS   $6,S
3f69: ee 64           LDU    $4,S
3f6b: e6 67           LDB    $7,S
3f6d: 4f              CLRA
3f6e: 1f 02           TFR    D,Y
3f70: 8e 00 04        LDX    #$0004
3f73: 34 70           PSHS   U,Y,X
3f75: 17 fd a8        LBSR   $3D20
3f78: 32 66           LEAS   $6,S
3f7a: 16 00 34        LBRA   $3FB1
3f7d: ee 62           LDU    $2,S
3f7f: 10 8e 00 02     LDY    #$0002
3f83: 34 60           PSHS   U,Y
3f85: 17 fa a4        LBSR   $3A2C
3f88: 32 64           LEAS   $4,S
3f8a: 33 69           LEAU   $9,S
3f8c: 10 8e 23 b9     LDY    #$23B9
3f90: ae e9 00 14     LDX    $0014,S
3f94: cc 00 06        LDD    #$0006
3f97: 34 76           PSHS   U,Y,X,D
3f99: 17 14 50        LBSR   $53EC
3f9c: 32 68           LEAS   $8,S
3f9e: e7 67           STB    $7,S
3fa0: ee 62           LDU    $2,S
3fa2: e6 67           LDB    $7,S
3fa4: 4f              CLRA
3fa5: 1f 02           TFR    D,Y
3fa7: 8e 00 04        LDX    #$0004
3faa: 34 70           PSHS   U,Y,X
3fac: 17 fd 71        LBSR   $3D20
3faf: 32 66           LEAS   $6,S
3fb1: ae 62           LDX    $2,S
3fb3: ac 64           CMPX   $4,S
3fb5: 10 26 00 0c     LBNE   $3FC5
3fb9: f6 24 0d        LDB    $240D
3fbc: c1 00           CMPB   #$00
3fbe: 10 23 00 03     LBLS   $3FC5
3fc2: 16 00 03        LBRA   $3FC8
3fc5: 16 00 6a        LBRA   $4032
3fc8: c6 01           LDB    #$01
3fca: e7 66           STB    $6,S
3fcc: e6 66           LDB    $6,S
3fce: c1 04           CMPB   #$04
3fd0: 10 24 00 5e     LBCC   $4032
3fd4: ce 24 f5        LDU    #$24F5
3fd7: e6 66           LDB    $6,S
3fd9: 4f              CLRA
3fda: 1f 02           TFR    D,Y
3fdc: 34 60           PSHS   U,Y
3fde: 86 01           LDA    #$01
3fe0: 8e c1 cd        LDX    #$C1CD
3fe3: 17 3d 04        LBSR   $7CEA
3fe6: 30 88 21        LEAX   $21,X
3fe9: ae 84           LDX    ,X
3feb: 8c 00 07        CMPX   #$0007
3fee: 10 26 00 38     LBNE   $402A
3ff2: ce 24 f5        LDU    #$24F5
3ff5: e6 66           LDB    $6,S
3ff7: 4f              CLRA
3ff8: 1f 02           TFR    D,Y
3ffa: 34 60           PSHS   U,Y
3ffc: 86 01           LDA    #$01
3ffe: 8e c1 cd        LDX    #$C1CD
4001: 17 3c e6        LBSR   $7CEA
4004: 30 0a           LEAX   $A,X
4006: af 6e           STX    $E,S
4008: ee 6e           LDU    $E,S
400a: e6 66           LDB    $6,S
400c: 4f              CLRA
400d: 1f 02           TFR    D,Y
400f: 8e 00 04        LDX    #$0004
4012: 34 70           PSHS   U,Y,X
4014: 17 fb 81        LBSR   $3B98
4017: 32 66           LEAS   $6,S
4019: 1f 03           TFR    D,U
401b: e6 66           LDB    $6,S
401d: 4f              CLRA
401e: 1f 02           TFR    D,Y
4020: 8e 00 04        LDX    #$0004
4023: 34 70           PSHS   U,Y,X
4025: 17 24 50        LBSR   $6478
4028: 32 66           LEAS   $6,S
402a: e6 66           LDB    $6,S
402c: cb 01           ADDB   #$01
402e: e7 66           STB    $6,S
4030: 20 9a           BRA    $3FCC
4032: e6 68           LDB    $8,S
4034: 4f              CLRA
4035: 10 83 00 ff     CMPD   #$00FF
4039: 10 27 00 28     LBEQ   $4065
403d: e6 67           LDB    $7,S
403f: 4f              CLRA
4040: 1f 03           TFR    D,U
4042: e6 68           LDB    $8,S
4044: 4f              CLRA
4045: 1f 02           TFR    D,Y
4047: 8e 00 04        LDX    #$0004
404a: 34 70           PSHS   U,Y,X
404c: 17 f5 a0        LBSR   $35EF
404f: 32 66           LEAS   $6,S
4051: c6 01           LDB    #$01
4053: 1d              SEX
4054: 1f 03           TFR    D,U
4056: e6 68           LDB    $8,S
4058: 4f              CLRA
4059: 1f 02           TFR    D,Y
405b: 8e 00 04        LDX    #$0004
405e: 34 70           PSHS   U,Y,X
4060: 17 f6 18        LBSR   $367B
4063: 32 66           LEAS   $6,S
4065: 32 e8 10        LEAS   $10,S
4068: 39              RTS
; Channel parameter write dispatcher — $4069.
; Reads a parameter type code from the channel's data structure (offset $0D) and dispatches
; via a 15-entry jump table at $C163. Handles frequency ($3B98→$6478), DC offset ($52A9→
; $48C6→shift→$6478), sweep ($3AE3), and direct-write modes. For channel 0 with $2202
; bit 6 set, also writes zero via $6478. Falls through to $3E5C for final output config.
4069: fc c1 c9        LDD    $C1C9
406c: 17 3c e1        LBSR   $7D50
406f: ae e9 00 0a     LDX    $000A,S
4073: 30 01           LEAX   $1,X
4075: ae 84           LDX    ,X
4077: af 62           STX    $2,S
4079: ce 24 f5        LDU    #$24F5
407c: 10 ae e9 00 08  LDY    $0008,S
4081: 34 60           PSHS   U,Y
4083: 86 01           LDA    #$01
4085: 8e c1 cd        LDX    #$C1CD
4088: 17 3c 5f        LBSR   $7CEA
408b: 30 0d           LEAX   $D,X
408d: ae 84           LDX    ,X
408f: 16 00 be        LBRA   $4150
4092: ce 05 55        LDU    #$0555
4095: 10 ae e9 00 08  LDY    $0008,S
409a: 8e 00 04        LDX    #$0004
409d: 34 70           PSHS   U,Y,X
409f: 17 23 d6        LBSR   $6478
40a2: 32 66           LEAS   $6,S
40a4: 16 01 1c        LBRA   $41C3
40a7: ee e9 00 0a     LDU    $000A,S
40ab: 10 ae e9 00 08  LDY    $0008,S
40b0: 8e 00 04        LDX    #$0004
40b3: 34 70           PSHS   U,Y,X
40b5: 17 fa e0        LBSR   $3B98
40b8: 32 66           LEAS   $6,S
40ba: 1f 03           TFR    D,U
40bc: 10 ae e9 00 08  LDY    $0008,S
40c1: 8e 00 04        LDX    #$0004
40c4: 34 70           PSHS   U,Y,X
40c6: 17 23 af        LBSR   $6478
40c9: 32 66           LEAS   $6,S
40cb: 16 00 f5        LBRA   $41C3
40ce: ee 62           LDU    $2,S
40d0: 10 8e 00 02     LDY    #$0002
40d4: 34 60           PSHS   U,Y
40d6: 17 11 d0        LBSR   $52A9
40d9: 32 64           LEAS   $4,S
40db: ed 62           STD    $2,S
40dd: ee 62           LDU    $2,S
40df: 10 8e 00 02     LDY    #$0002
40e3: 34 60           PSHS   U,Y
40e5: 17 07 de        LBSR   $48C6
40e8: 32 64           LEAS   $4,S
40ea: ed 62           STD    $2,S
40ec: ec 62           LDD    $2,S
40ee: c3 00 04        ADDD   #$0004
40f1: ed 62           STD    $2,S
40f3: ec 62           LDD    $2,S
40f5: 44              LSRA
40f6: 56              RORB
40f7: 44              LSRA
40f8: 56              RORB
40f9: 44              LSRA
40fa: 56              RORB
40fb: ed 62           STD    $2,S
40fd: ee 62           LDU    $2,S
40ff: 10 ae e9 00 08  LDY    $0008,S
4104: 8e 00 04        LDX    #$0004
4107: 34 70           PSHS   U,Y,X
4109: 17 23 6c        LBSR   $6478
410c: 32 66           LEAS   $6,S
410e: 16 00 b2        LBRA   $41C3
4111: ce 00 00        LDU    #$0000
4114: 34 40           PSHS   U
4116: 17 f9 ca        LBSR   $3AE3
4119: 32 62           LEAS   $2,S
411b: 16 00 a5        LBRA   $41C3
411e: 16 00 60        LBRA   $4181
4121: 5f              CLRB
4122: 1d              SEX
4123: 1f 03           TFR    D,U
4125: 10 ae e9 00 08  LDY    $0008,S
412a: 8e 00 04        LDX    #$0004
412d: 34 70           PSHS   U,Y,X
412f: 17 23 46        LBSR   $6478
4132: 32 66           LEAS   $6,S
4134: 16 00 4a        LBRA   $4181
4137: 5f              CLRB
4138: 1d              SEX
4139: 1f 03           TFR    D,U
413b: 10 ae e9 00 08  LDY    $0008,S
4140: 8e 00 04        LDX    #$0004
4143: 34 70           PSHS   U,Y,X
4145: 17 23 30        LBSR   $6478
4148: 32 66           LEAS   $6,S
414a: 16 00 76        LBRA   $41C3
414d: 16 00 31        LBRA   $4181
4150: 8c 00 0f        CMPX   #$000F
4153: 2e e2           BGT    $4137
4155: 1f 10           TFR    X,D
4157: 83 00 01        SUBD   #$0001
415a: 2d db           BLT    $4137
415c: 8e c1 63        LDX    #$C163
415f: 58              ASLB
4160: 49              ROLA
4161: 6e 9b           JMP    [D,X]
4163: c1 11           CMPB   #$11
4165: c1 11           CMPB   #$11
4167: c0 dd           SUBB   #$DD
4169: c0 ce           SUBB   #$CE
416b: c1 1e           CMPB   #$1E
416d: c1 1e           CMPB   #$1E
416f: c1 1e           CMPB   #$1E
4171: c1 37           CMPB   #$37
4173: c1 37           CMPB   #$37
4175: c1 37           CMPB   #$37
4177: c0 a7           SUBB   #$A7
4179: c1 37           CMPB   #$37
417b: c1 37           CMPB   #$37
417d: c1 21           CMPB   #$21
417f: c0 92           SUBB   #$92
4181: ae e9 00 08     LDX    $0008,S
4185: 8c 00 00        CMPX   #$0000
4188: 10 26 00 12     LBNE   $419E
418c: fc 22 02        LDD    $2202
418f: 84 00           ANDA   #$00
4191: c4 40           ANDB   #$40
4193: 10 83 00 00     CMPD   #$0000
4197: 10 27 00 03     LBEQ   $419E
419b: 16 00 03        LBRA   $41A1
419e: 16 00 13        LBRA   $41B4
41a1: 5f              CLRB
41a2: 1d              SEX
41a3: 1f 03           TFR    D,U
41a5: 10 ae e9 00 08  LDY    $0008,S
41aa: 8e 00 04        LDX    #$0004
41ad: 34 70           PSHS   U,Y,X
41af: 17 22 c6        LBSR   $6478
41b2: 32 66           LEAS   $6,S
41b4: ee e9 00 08     LDU    $0008,S
41b8: 10 8e 00 02     LDY    #$0002
41bc: 34 60           PSHS   U,Y
41be: 17 fc 9b        LBSR   $3E5C
41c1: 32 64           LEAS   $4,S
41c3: 32 64           LEAS   $4,S
41c5: 39              RTS
41c6: 00 01           NEG    <$01
41c8: 00 00           NEG    <$00
41ca: 02 00           XNC    <$00
41cc: 04 00           LSR    <$00
41ce: 01 00           NEG    <$00
41d0: 00 00           NEG    <$00
41d2: 23 00           BLS    $41D4
41d4: 0d 00           TST    <$00
41d6: 07 00           ASR    <$00
41d8: 0c 00           INC    <$00
41da: 01 00           NEG    <$00
41dc: 00 00           NEG    <$00
41de: 0f 00           CLR    <$00
41e0: 08 00           ASL    <$00
; Paged ROM byte reader — $41E2.
; Saves current ROM page ($247B), switches to the page specified by arg 1 via $5AE0,
; reads one byte from the indirect pointer at arg 2, restores the original page, and
; returns the read byte in B.
41e2: 0e fc           JMP    <$FC
41e4: c8 b2           EORB   #$B2
41e6: 17 3b 67        LBSR   $7D50
41e9: f6 24 7b        LDB    $247B
41ec: e7 62           STB    $2,S
41ee: ee e9 00 09     LDU    $0009,S
41f2: 10 8e 00 02     LDY    #$0002
41f6: 34 60           PSHS   U,Y
41f8: 17 18 e5        LBSR   $5AE0
41fb: 32 64           LEAS   $4,S
41fd: e6 f9 00 0b     LDB    [$000B,S]
4201: e7 63           STB    $3,S
4203: e6 62           LDB    $2,S
4205: 4f              CLRA
4206: 1f 03           TFR    D,U
4208: 10 8e 00 02     LDY    #$0002
420c: 34 60           PSHS   U,Y
420e: 17 18 cf        LBSR   $5AE0
4211: 32 64           LEAS   $4,S
4213: e6 63           LDB    $3,S
4215: e7 64           STB    $4,S
4217: 32 65           LEAS   $5,S
4219: 39              RTS
; Compute channel data pointer from $23BE index — $421A.
; Uses $23BE (stored by Group A request stubs at $1BDC-$1C15) as an index into the $24F5
; channel structure via $7CEA at $C8B4. Stores the resulting pointer in $23BF for use
; by the request dispatcher.
421a: fc c8 b6        LDD    $C8B6
421d: 17 3b 30        LBSR   $7D50
4220: ce 24 f5        LDU    #$24F5
4223: f6 23 be        LDB    $23BE
4226: 4f              CLRA
4227: 1f 02           TFR    D,Y
4229: 34 60           PSHS   U,Y
422b: 86 01           LDA    #$01
422d: 8e c8 b4        LDX    #$C8B4
4230: 17 3a b7        LBSR   $7CEA
4233: bf 23 bf        STX    $23BF
4236: 32 62           LEAS   $2,S
4238: 39              RTS
; No-op stub — $4239.
; Allocates and immediately deallocates a 2-byte stack frame. Placeholder or removed function.
4239: fc c8 b6        LDD    $C8B6
423c: 17 3b 11        LBSR   $7D50
423f: 32 62           LEAS   $2,S
4241: 39              RTS
; Memory block compare — $4242.
; Compares count bytes between two memory blocks (source at arg 2, dest at arg 3).
; Returns B=1 if any byte differs, B=0 if all match.
4242: fc c8 b2        LDD    $C8B2
4245: 17 3b 08        LBSR   $7D50       ; allocate frame
4248: 5f              CLRB
4249: 4f              CLRA
424a: ed 62           STD    $2,S        ; loop index = 0
424c: ae 62           LDX    $2,S        ; loop: X = index
424e: ac e9 00 09     CMPX   $0009,S     ; index >= count?
4252: 10 2c 00 28     LBGE   $427E       ; yes → all match
4256: ae e9 00 0b     LDX    $000B,S     ; X = source base
425a: ec 62           LDD    $2,S        ; D = index
425c: 30 8b           LEAX   D,X         ; X = &source[index]
425e: ee e9 00 0d     LDU    $000D,S     ; U = dest base
4262: ec 62           LDD    $2,S
4264: 33 cb           LEAU   D,U         ; U = &dest[index]
4266: e6 84           LDB    ,X          ; B = source byte
4268: e1 c4           CMPB   ,U          ; compare with dest byte
426a: 10 27 00 07     LBEQ   $4275       ; match → next byte
426e: c6 01           LDB    #$01
4270: e7 64           STB    $4,S        ; result = 1 (mismatch found)
4272: 16 00 0b        LBRA   $4280       ; → return
4275: ec 62           LDD    $2,S
4277: c3 00 01        ADDD   #$0001      ; index++
427a: ed 62           STD    $2,S
427c: 20 ce           BRA    $424C       ; → loop
427e: 6f 64           CLR    $4,S        ; result = 0 (all match)
4280: e6 64           LDB    $4,S        ; B = result
4282: 32 65           LEAS   $5,S        ; deallocate frame
4284: 39              RTS
; Memory block copy (byte-by-byte, forward) — $4285.
; Copies a block of bytes from source to destination.
; Inputs on stack: count at $0006,S, source pointer at $0008,S, dest pointer at $000A,S.
; Copies count bytes, incrementing both pointers after each byte.
4285: fc c8 b6        LDD    $C8B6
4288: 17 3a c5        LBSR   $7D50       ; allocate frame
428b: ec e9 00 06     LDD    $0006,S     ; load remaining count
428f: 83 00 01        SUBD   #$0001      ; count-- (pre-decrement, stops at -1)
4292: ed e9 00 06     STD    $0006,S
4296: ae e9 00 06     LDX    $0006,S
429a: 8c ff ff        CMPX   #$FFFF      ; underflowed to -1?
429d: 10 27 00 20     LBEQ   $42C1       ; yes → done
42a1: e6 f9 00 08     LDB    [$0008,S]   ; B = *source
42a5: e7 f9 00 0a     STB    [$000A,S]   ; *dest = B
42a9: ec e9 00 0a     LDD    $000A,S     ; dest++
42ad: c3 00 01        ADDD   #$0001
42b0: ed e9 00 0a     STD    $000A,S
42b4: ec e9 00 08     LDD    $0008,S     ; source++
42b8: c3 00 01        ADDD   #$0001
42bb: ed e9 00 08     STD    $0008,S
42bf: 20 ca           BRA    $428B       ; → loop
42c1: 32 62           LEAS   $2,S
42c3: 39              RTS
; System configuration reset / factory defaults — $42C4.
; Clears $23C1 (16-bit parameter scratch), resets HP-IB address to 26 ($1A), sets $227E to 19
; ($13, tentative: default GPIB secondary address or device ID), then initializes all 12 channel
; parameter slots via the array indexer at $7CEA.
42c4: fc c8 b4        LDD    $C8B4
42c7: 17 3a 86        LBSR   $7D50       ; allocate frame
42ca: 5f              CLRB
42cb: 4f              CLRA
42cc: fd 23 c1        STD    $23C1       ; clear parameter scratch
42cf: c6 1a           LDB    #$1A        ; default HP-IB address = 26
42d1: f7 22 7f        STB    $227F
42d4: c6 13           LDB    #$13        ; default secondary parameter = 19
42d6: f7 22 7e        STB    $227E
; Clear all 12 channel parameter slot pointers to $C239 (stub RTS)
42d9: 6f 62           CLR    $2,S        ; slot index = 0
42db: e6 62           LDB    $2,S        ; loop: load index
42dd: c1 0c           CMPB   #$0C        ; all 12 slots done?
42df: 10 24 00 1f     LBCC   $4302       ; yes → copy defaults
42e3: ce 26 8f        LDU    #$268F      ; U = slot array base
42e6: e6 62           LDB    $2,S
42e8: 4f              CLRA
42e9: 1f 02           TFR    D,Y         ; Y = slot index
42eb: 34 60           PSHS   U,Y
42ed: 86 01           LDA    #$01
42ef: 8e c8 ba        LDX    #$C8BA      ; descriptor for slot array
42f2: 17 39 f5        LBSR   $7CEA       ; → array element indexer
42f5: cc c2 39        LDD    #$C239      ; $C239 = stub RTS sentinel
42f8: ed 84           STD    ,X          ; store sentinel into slot
42fa: e6 62           LDB    $2,S
42fc: cb 01           ADDB   #$01        ; index++
42fe: e7 62           STB    $2,S
4300: 20 d9           BRA    $42DB       ; → loop
; Copy 24 ($18) bytes of factory defaults from ROM ($4037) to $23C5
4302: ce 23 c5        LDU    #$23C5      ; U = dest (parameter block)
4305: 10 8e 40 37     LDY    #$4037      ; Y = source (ROM defaults)
4309: c6 18           LDB    #$18        ; count = 24 bytes
430b: 1d              SEX
430c: 1f 01           TFR    D,X
430e: cc 00 06        LDD    #$0006
4311: 34 76           PSHS   U,Y,X,D
4313: 17 ff 6f        LBSR   $4285       ; → block copy
4316: 32 68           LEAS   $8,S
4318: be 40 51        LDX    $4051       ; indirect call through page 0 vector
431b: ad 84           JSR    ,X
431d: ce 20 00        LDU    #$2000
4320: 10 8e ec 85     LDY    #$EC85
4324: c6 3c           LDB    #$3C
4326: 1d              SEX
4327: 1f 01           TFR    D,X
4329: cc 00 06        LDD    #$0006
432c: 34 76           PSHS   U,Y,X,D
432e: 17 ff 54        LBSR   $4285
4331: 32 68           LEAS   $8,S
4333: fe 23 c3        LDU    $23C3
4336: 10 8e 00 02     LDY    #$0002
433a: 34 60           PSHS   U,Y
433c: 17 16 4a        LBSR   $5989
433f: 32 64           LEAS   $4,S
4341: 6f 62           CLR    $2,S
4343: e6 62           LDB    $2,S
4345: c1 03           CMPB   #$03
4347: 10 24 00 20     LBCC   $436B
434b: ce 05 dc        LDU    #$05DC
434e: 10 8e 00 02     LDY    #$0002
4352: 34 60           PSHS   U,Y
4354: 17 13 19        LBSR   $5670
4357: 32 64           LEAS   $4,S
4359: ce 00 00        LDU    #$0000
435c: 34 40           PSHS   U
435e: 17 13 67        LBSR   $56C8
4361: 32 62           LEAS   $2,S
4363: e6 62           LDB    $2,S
4365: cb 01           ADDB   #$01
4367: e7 62           STB    $2,S
4369: 20 d8           BRA    $4343
436b: 32 63           LEAS   $3,S
436d: 39              RTS
; Save instrument state to non-volatile storage — $436E.
; Copies key configuration variables ($23C1, $2383, $23C6, $2388) into the save area starting
; at $3FEE (appears to be battery-backed SRAM or EEPROM at the top of the paged region).
; Then runs two verification passes via $4242 comparing the saved state against ROM templates
; at $EC85 and $ECBB. $23DD accumulates the verification error count.
436e: fc c8 c0        LDD    $C8C0
4371: 17 39 dc        LBSR   $7D50       ; allocate frame
; Save first config block: $23C1 → $3FEE, $2383 (4 bytes) → $3FEF
4374: cc 23 c1        LDD    #$23C1
4377: ed 62           STD    $2,S
4379: e6 f8 02        LDB    [$02,S]     ; B = byte at $23C1
437c: f7 3f ee        STB    $3FEE       ; → non-volatile save area
437f: ce 23 83        LDU    #$2383      ; source: $2383
4382: 10 8e 3f ef     LDY    #$3FEF      ; dest: $3FEF
4386: 8e 00 04        LDX    #$0004      ; count = 4 bytes
4389: 34 70           PSHS   U,Y,X
438b: 17 0f ef        LBSR   $537D       ; → block copy (dest, source, count)
438e: 32 66           LEAS   $6,S
; Save second config block: $23C6 → $3FF2, $2388 (4 bytes) → $3FF3
4390: cc 23 c6        LDD    #$23C6
4393: ed 62           STD    $2,S
4395: e6 f8 02        LDB    [$02,S]     ; B = byte at $23C6
4398: f7 3f f2        STB    $3FF2       ; → non-volatile save area
439b: ce 23 88        LDU    #$2388      ; source: $2388
439e: 10 8e 3f f3     LDY    #$3FF3      ; dest: $3FF3
43a2: 8e 00 04        LDX    #$0004      ; count = 4 bytes
43a5: 34 70           PSHS   U,Y,X
43a7: 17 0f d3        LBSR   $537D       ; → block copy
43aa: 32 66           LEAS   $6,S
; Verify saved data against ROM templates
43ac: 7f 23 dd        CLR    $23DD       ; clear verification error count
; Verify pass 1: compare $2000 (54 bytes) against ROM template $EC85
43af: ce 20 00        LDU    #$2000      ; U = RAM data
43b2: 10 8e ec 85     LDY    #$EC85      ; Y = ROM template
43b6: c6 36           LDB    #$36        ; count = 54 bytes
43b8: 1d              SEX
43b9: 1f 01           TFR    D,X
43bb: cc 00 06        LDD    #$0006
43be: 34 76           PSHS   U,Y,X,D
43c0: 17 fe 7f        LBSR   $4242       ; → block compare
43c3: 32 68           LEAS   $8,S
43c5: c1 00           CMPB   #$00        ; match?
43c7: 10 27 00 05     LBEQ   $43D0       ; yes → skip error
43cb: c6 02           LDB    #$02
43cd: f7 23 dd        STB    $23DD       ; mismatch → error count = 2
; Verify pass 2: compare $2036 (6 bytes) against ROM template $ECBB
43d0: 8e 20 00        LDX    #$2000
43d3: 30 88 36        LEAX   $36,X       ; X = $2036
43d6: af 64           STX    $4,S
43d8: ee 64           LDU    $4,S        ; U = $2036
43da: 10 8e ec bb     LDY    #$ECBB      ; Y = ROM template
43de: c6 06           LDB    #$06        ; count = 6 bytes
43e0: 1d              SEX
43e1: 1f 01           TFR    D,X
43e3: cc 00 06        LDD    #$0006
43e6: 34 76           PSHS   U,Y,X,D
43e8: 17 fe 57        LBSR   $4242       ; → block compare
43eb: 32 68           LEAS   $8,S
43ed: c1 00           CMPB   #$00        ; match?
43ef: 10 27 00 08     LBEQ   $43FB       ; yes → done
43f3: f6 23 dd        LDB    $23DD       ; mismatch → increment error count
43f6: cb 01           ADDB   #$01
43f8: f7 23 dd        STB    $23DD
43fb: 32 66           LEAS   $6,S        ; deallocate frame
43fd: 39              RTS
; UI state save and parameter capture — $43FE.
; Calls $56C8 (display/UI state snapshot), then stores the caller-supplied byte argument at
; $0007,S into $23DE (the auxiliary HP-IB parameter byte used by reply formatters like $230E).
43fe: fc c8 b6        LDD    $C8B6
4401: 17 39 4c        LBSR   $7D50       ; allocate frame
4404: ce 00 00        LDU    #$0000
4407: 34 40           PSHS   U
4409: 17 12 bc        LBSR   $56C8       ; → save UI/display state
440c: 32 62           LEAS   $2,S
440e: e6 e9 00 07     LDB    $0007,S     ; caller argument
4412: f7 23 de        STB    $23DE       ; store as auxiliary HP-IB byte
4415: 32 62           LEAS   $2,S
4417: 39              RTS
; UI parameter display setup — $4418.
; Saves the current selector byte from $247B, sets $2204 bit 4, loads two ROM display strings
; (from $ED61 and $ED11) into display lines via $58A5, then begins building a formatted display
; from the auxiliary parameter at $23DE. This is the front-panel UI for a parameter editing screen.
4418: fc c8 c2        LDD    $C8C2
441b: 17 39 32        LBSR   $7D50       ; allocate frame
441e: f6 24 7b        LDB    $247B       ; save current selector byte
4421: e7 64           STB    $4,S
4423: fc 22 04        LDD    $2204
4426: 8a 00           ORA    #$00
4428: ca 10           ORB    #$10        ; set bit 4 (parameter edit mode active)
442a: fd 22 04        STD    $2204
; Load display line 1 from ROM string at $ED61
442d: ce ed 61        LDU    #$ED61      ; source: ROM string
4430: c6 28           LDB    #$28        ; display row offset 40
4432: 1d              SEX
4433: 1f 02           TFR    D,Y
4435: 5f              CLRB              ; display column 0
4436: 1d              SEX
4437: 1f 01           TFR    D,X
4439: cc 00 06        LDD    #$0006
443c: 34 76           PSHS   U,Y,X,D
443e: 17 14 64        LBSR   $58A5       ; → copy string to display RAM
4441: 32 68           LEAS   $8,S
; Load display line 2 from ROM string at $ED11
4443: ce ed 11        LDU    #$ED11      ; source: ROM string
4446: c6 28           LDB    #$28        ; display row offset 40
4448: 1d              SEX
4449: 1f 02           TFR    D,Y
444b: c6 40           LDB    #$40        ; display column 64
444d: 1d              SEX
444e: 1f 01           TFR    D,X
4450: cc 00 06        LDD    #$0006
4453: 34 76           PSHS   U,Y,X,D
4455: 17 14 4d        LBSR   $58A5       ; → copy string to display RAM
4458: 32 68           LEAS   $8,S
; Begin formatting the auxiliary parameter value
445a: 33 68           LEAU   $8,S        ; U = pointer past frame for formatted output
445c: f6 23 de        LDB    $23DE       ; load auxiliary HP-IB parameter byte
445f: 4f              CLRA
4460: 1f 02           TFR    D,Y
4462: 8e 00 04        LDX    #$0004
4465: 34 70           PSHS   U,Y,X
4467: 17 05 67        LBSR   $49D1
446a: 32 66           LEAS   $6,S
446c: 33 68           LEAU   $8,S
446e: c6 02           LDB    #$02
4470: 1d              SEX
4471: 1f 02           TFR    D,Y
4473: 8e 00 04        LDX    #$0004
4476: 34 70           PSHS   U,Y,X
4478: 17 08 84        LBSR   $4CFF
447b: 32 66           LEAS   $6,S
447d: 33 68           LEAU   $8,S
447f: c6 03           LDB    #$03
4481: 1d              SEX
4482: 1f 02           TFR    D,Y
4484: c6 20           LDB    #$20
4486: 1d              SEX
4487: 1f 01           TFR    D,X
4489: cc 00 06        LDD    #$0006
448c: 34 76           PSHS   U,Y,X,D
448e: 17 14 14        LBSR   $58A5
4491: 32 68           LEAS   $8,S
4493: 7f 23 df        CLR    $23DF
4496: 5f              CLRB
4497: 1d              SEX
4498: 1f 03           TFR    D,U
449a: 10 8e 00 02     LDY    #$0002
449e: 34 60           PSHS   U,Y
44a0: 17 16 3d        LBSR   $5AE0
44a3: 32 64           LEAS   $4,S
44a5: be 40 4f        LDX    $404F
44a8: ad 84           JSR    ,X
44aa: ce 23 e0        LDU    #$23E0
44ad: f6 23 df        LDB    $23DF
44b0: 4f              CLRA
44b1: 1f 02           TFR    D,Y
44b3: c6 40           LDB    #$40
44b5: 1d              SEX
44b6: 1f 01           TFR    D,X
44b8: cc 00 06        LDD    #$0006
44bb: 34 76           PSHS   U,Y,X,D
44bd: 17 13 e5        LBSR   $58A5
44c0: 32 68           LEAS   $8,S
44c2: e6 64           LDB    $4,S
44c4: 4f              CLRA
44c5: 1f 03           TFR    D,U
44c7: 10 8e 00 02     LDY    #$0002
44cb: 34 60           PSHS   U,Y
44cd: 17 16 10        LBSR   $5AE0
44d0: 32 64           LEAS   $4,S
44d2: 7f 23 de        CLR    $23DE
44d5: ce 0b b8        LDU    #$0BB8
44d8: 10 8e 00 02     LDY    #$0002
44dc: 34 60           PSHS   U,Y
44de: 17 11 8f        LBSR   $5670
44e1: 32 64           LEAS   $4,S
44e3: ce 00 00        LDU    #$0000
44e6: 34 40           PSHS   U
44e8: 17 14 db        LBSR   $59C6
44eb: 32 62           LEAS   $2,S
44ed: 32 6f           LEAS   $F,S
44ef: 39              RTS
; Channel initialization from hardware scan results — $44F0.
; Initializes 4 channel mode words to $0010 (disabled). Based on $23B2 (detected channel
; count from $3852), assigns modes $0C-$0F to the detected channels. Then iterates
; channels 0-3, loading default parameters ($35 bytes) from ROM ($ED89 or $EDAC based
; on mode) into each channel's slot in the $23BF structure via $4285. Sets $24F4 to $0F.
44f0: fc c8 c2        LDD    $C8C2
44f3: 17 38 5a        LBSR   $7D50       ; allocate frame
; Init local mode word array: 4 entries at $5,S, each set to $0010 (disabled)
44f6: 6f 62           CLR    $2,S        ; channel index = 0
44f8: e6 62           LDB    $2,S        ; loop: load index
44fa: c1 04           CMPB   #$04        ; all 4 done?
44fc: 10 24 00 16     LBCC   $4516       ; yes → assign modes
4500: e6 62           LDB    $2,S
4502: 4f              CLRA
4503: 58              ASLB              ; D = index * 2 (word offset)
4504: 49              ROLA
4505: 30 65           LEAX   $5,S        ; X = local array base
4507: 30 8b           LEAX   D,X         ; X = &array[index]
4509: cc 00 10        LDD    #$0010      ; $0010 = disabled mode
450c: ed 84           STD    ,X          ; array[index] = $0010
450e: e6 62           LDB    $2,S
4510: cb 01           ADDB   #$01        ; index++
4512: e7 62           STB    $2,S
4514: 20 e2           BRA    $44F8       ; → loop
; Assign modes $0C-$0F to detected channels (fall-through switch)
4516: f6 23 b2        LDB    $23B2       ; B = detected channel count
4519: 16 00 17        LBRA   $4533       ; → switch on count
451c: cc 00 0f        LDD    #$000F      ; case 4: channel 3 = mode $0F
451f: ed 6b           STD    $B,S
4521: cc 00 0e        LDD    #$000E      ; case 3: channel 2 = mode $0E
4524: ed 69           STD    $9,S
4526: cc 00 0d        LDD    #$000D      ; case 2: channel 1 = mode $0D
4529: ed 67           STD    $7,S
452b: cc 00 0c        LDD    #$000C      ; case 1: channel 0 = mode $0C
452e: ed 65           STD    $5,S
4530: 16 00 13        LBRA   $4546       ; → load defaults
4533: c1 01           CMPB   #$01        ; switch: 1 channel?
4535: 27 f4           BEQ    $452B       ; → assign $0C only
4537: c1 02           CMPB   #$02        ; 2 channels?
4539: 27 eb           BEQ    $4526       ; → assign $0C, $0D
453b: c1 03           CMPB   #$03        ; 3 channels?
453d: 27 e2           BEQ    $4521       ; → assign $0C, $0D, $0E
453f: c1 04           CMPB   #$04        ; 4 channels?
4541: 27 d9           BEQ    $451C       ; → assign all four
4543: 16 00 00        LBRA   $4546       ; 0 channels → skip
; Load default parameters for each channel slot
4546: 7f 23 be        CLR    $23BE       ; channel index = 0
4549: f6 23 be        LDB    $23BE       ; loop: load index
454c: c1 04           CMPB   #$04        ; all 4 channels done?
454e: 10 24 00 57     LBCC   $45A9       ; yes → finalize
4552: ce 00 00        LDU    #$0000
4555: 34 40           PSHS   U
4557: 17 fc c0        LBSR   $421A       ; → resolve channel pointer into $23BF
455a: 32 62           LEAS   $2,S
; Look up this channel's mode word from the local array
455c: f6 23 be        LDB    $23BE       ; B = channel index
455f: 4f              CLRA
4560: 58              ASLB              ; D = index * 2
4561: 49              ROLA
4562: 30 65           LEAX   $5,S        ; X = local array base
4564: 30 8b           LEAX   D,X         ; X = &array[channel]
4566: ae 84           LDX    ,X          ; X = mode word
4568: af 6d           STX    $D,S        ; save mode
456a: ae 6d           LDX    $D,S
456c: 8c 00 10        CMPX   #$0010      ; mode == $0010 (disabled)?
456f: 10 26 00 08     LBNE   $457B       ; no → use active defaults
4573: cc ed ac        LDD    #$EDAC      ; disabled: ROM defaults at $EDAC
4576: ed 63           STD    $3,S
4578: 16 00 05        LBRA   $4580       ; → copy
457b: cc ed 89        LDD    #$ED89      ; active: ROM defaults at $ED89
457e: ed 63           STD    $3,S
; Copy $23 (35) bytes of ROM defaults into channel's parameter slot
4580: fe 23 bf        LDU    $23BF       ; U = dest (channel slot pointer)
4583: 10 ae 63        LDY    $3,S        ; Y = source (ROM defaults)
4586: c6 23           LDB    #$23        ; count = 35 bytes
4588: 4f              CLRA
4589: 1f 01           TFR    D,X
458b: cc 00 06        LDD    #$0006
458e: 34 76           PSHS   U,Y,X,D
4590: 17 fc f2        LBSR   $4285       ; → block copy defaults
4593: 32 68           LEAS   $8,S
; Store mode word at offset $21 within the channel slot
4595: be 23 bf        LDX    $23BF       ; X = channel slot base
4598: 30 88 21        LEAX   $21,X       ; X = &slot[0x21] (mode word field)
459b: ec 6d           LDD    $D,S        ; D = mode word
459d: ed 84           STD    ,X          ; store mode word
459f: f6 23 be        LDB    $23BE
45a2: cb 01           ADDB   #$01        ; channel index++
45a4: f7 23 be        STB    $23BE
45a7: 20 a0           BRA    $4549       ; → loop
45a9: c6 0f           LDB    #$0F        ; $24F4 = $0F (all channels flagged)
45ab: f7 24 f4        STB    $24F4
45ae: 32 6f           LEAS   $F,S
45b0: 39              RTS
; Channel reconfiguration — $45B1.
; Saves current mode field (offset $21) of each channel 0-3 from the $24F5 array into $24DE[ch],
; then sets all channel modes to $0010 (disabled). Clears $2408-$2411 state block. Second pass
; replays each channel's output configuration through $62C1, $638F (offset $1F), $6562 (offset $15),
; and $4069 (offset $0A parameter write dispatcher). Finally checks $2204 bit 5 and calls $67C4
; with $24F4 and the flag. Used during full instrument reconfiguration sequences.
45b1: fc c8 c0        LDD    $C8C0
45b4: 17 37 99        LBSR   $7D50
45b7: 6f 63           CLR    $3,S
45b9: 6f 62           CLR    $2,S
45bb: e6 62           LDB    $2,S
45bd: c1 04           CMPB   #$04
45bf: 10 24 00 39     LBCC   $45FC
45c3: ce 24 f5        LDU    #$24F5
45c6: e6 62           LDB    $2,S
45c8: 4f              CLRA
45c9: 1f 02           TFR    D,Y
45cb: 34 60           PSHS   U,Y
45cd: 86 01           LDA    #$01
45cf: 8e c8 b4        LDX    #$C8B4
45d2: 17 37 15        LBSR   $7CEA
45d5: af 64           STX    $4,S
45d7: e6 62           LDB    $2,S
45d9: 4f              CLRA
45da: 58              ASLB
45db: 49              ROLA
45dc: 8e 24 de        LDX    #$24DE
45df: 30 8b           LEAX   D,X
45e1: ee 64           LDU    $4,S
45e3: 33 c8 21        LEAU   $21,U
45e6: ee c4           LDU    ,U
45e8: ef 84           STU    ,X
45ea: ae 64           LDX    $4,S
45ec: 30 88 21        LEAX   $21,X
45ef: cc 00 10        LDD    #$0010
45f2: ed 84           STD    ,X
45f4: e6 62           LDB    $2,S
45f6: cb 01           ADDB   #$01
45f8: e7 62           STB    $2,S
45fa: 20 bf           BRA    $45BB
45fc: c6 04           LDB    #$04
45fe: f7 24 08        STB    $2408
4601: 7f 24 09        CLR    $2409
4604: 7f 24 0a        CLR    $240A
4607: 7f 24 0b        CLR    $240B
460a: 7f 24 0c        CLR    $240C
460d: 7f 24 0d        CLR    $240D
4610: 7f 24 0e        CLR    $240E
4613: 7f 24 0f        CLR    $240F
4616: 7f 24 10        CLR    $2410
4619: 7f 24 11        CLR    $2411
461c: 6f 62           CLR    $2,S
461e: e6 62           LDB    $2,S
4620: c1 04           CMPB   #$04
4622: 10 24 00 72     LBCC   $4698
4626: ce 24 f5        LDU    #$24F5
4629: e6 62           LDB    $2,S
462b: 4f              CLRA
462c: 1f 02           TFR    D,Y
462e: 34 60           PSHS   U,Y
4630: 86 01           LDA    #$01
4632: 8e c8 b4        LDX    #$C8B4
4635: 17 36 b2        LBSR   $7CEA
4638: af 64           STX    $4,S
463a: ee 64           LDU    $4,S
463c: e6 62           LDB    $2,S
463e: 4f              CLRA
463f: 1f 02           TFR    D,Y
4641: 8e 00 04        LDX    #$0004
4644: 34 70           PSHS   U,Y,X
4646: 17 1c 78        LBSR   $62C1
4649: 32 66           LEAS   $6,S
464b: ae 64           LDX    $4,S
464d: 30 88 1f        LEAX   $1F,X
4650: ae 84           LDX    ,X
4652: 1f 13           TFR    X,U
4654: e6 62           LDB    $2,S
4656: 4f              CLRA
4657: 1f 02           TFR    D,Y
4659: 8e 00 04        LDX    #$0004
465c: 34 70           PSHS   U,Y,X
465e: 17 1d 2e        LBSR   $638F
4661: 32 66           LEAS   $6,S
4663: ae 64           LDX    $4,S
4665: 30 88 15        LEAX   $15,X
4668: ae 84           LDX    ,X
466a: 1f 13           TFR    X,U
466c: e6 62           LDB    $2,S
466e: 4f              CLRA
466f: 1f 02           TFR    D,Y
4671: 8e 00 04        LDX    #$0004
4674: 34 70           PSHS   U,Y,X
4676: 17 1e e9        LBSR   $6562
4679: 32 66           LEAS   $6,S
467b: ae 64           LDX    $4,S
467d: 30 0a           LEAX   $A,X
467f: 1f 13           TFR    X,U
4681: e6 62           LDB    $2,S
4683: 4f              CLRA
4684: 1f 02           TFR    D,Y
4686: 8e 00 04        LDX    #$0004
4689: 34 70           PSHS   U,Y,X
468b: 17 f9 db        LBSR   $4069
468e: 32 66           LEAS   $6,S
4690: e6 62           LDB    $2,S
4692: cb 01           ADDB   #$01
4694: e7 62           STB    $2,S
4696: 20 86           BRA    $461E
4698: fc 22 04        LDD    $2204
469b: 84 20           ANDA   #$20
469d: c4 00           ANDB   #$00
469f: 10 83 00 00     CMPD   #$0000
46a3: 10 27 00 04     LBEQ   $46AB
46a7: c6 01           LDB    #$01
46a9: e7 63           STB    $3,S
46ab: f6 24 f4        LDB    $24F4
46ae: 4f              CLRA
46af: 1f 03           TFR    D,U
46b1: e6 63           LDB    $3,S
46b3: 4f              CLRA
46b4: 1f 02           TFR    D,Y
46b6: 8e 00 04        LDX    #$0004
46b9: 34 70           PSHS   U,Y,X
46bb: 17 21 06        LBSR   $67C4
46be: 32 66           LEAS   $6,S
46c0: 32 66           LEAS   $6,S
46c2: 39              RTS
; Full channel initialization sequence — $46C3.
; Calls $67F9(0) for pre-initialization, $44F0(0) for channel initialization from hardware
; scan results, then $45B1(0) for channel reconfiguration. This is the top-level startup
; sequence that detects hardware and configures all output channels.
46c3: fc c8 b6        LDD    $C8B6
46c6: 17 36 87        LBSR   $7D50       ; allocate frame
46c9: ce 00 00        LDU    #$0000
46cc: 34 40           PSHS   U
46ce: 17 21 28        LBSR   $67F9       ; → $67F9: hardware pre-init (scan ports)
46d1: 32 62           LEAS   $2,S
46d3: ce 00 00        LDU    #$0000
46d6: 34 40           PSHS   U
46d8: 17 fe 15        LBSR   $44F0       ; → $44F0: init channels from scan results
46db: 32 62           LEAS   $2,S
46dd: ce 00 00        LDU    #$0000
46e0: 34 40           PSHS   U
46e2: 17 fe cc        LBSR   $45B1       ; → $45B1: channel reconfiguration
46e5: 32 62           LEAS   $2,S
46e7: 32 62           LEAS   $2,S        ; deallocate frame
46e9: 39              RTS
; Hardware port and display reset — $46EA.
; Resets all hardware output ports: clears $0B00, masks bit 7 off $241F→$0A00 and $2420→$0900
; (LED port shadows), clears $0600, clears bits 1 and 9 of $2202 system control word, clears
; $23DE. Enters idle watchdog via $5B5C(0). Loops channels 0-3 calling $65BF(0, ch, 4).
; Called via $55F1 and $5F17 for hardware setup before channel initialization.
46ea: fc c8 b4        LDD    $C8B4
46ed: 17 36 60        LBSR   $7D50       ; allocate frame
46f0: ce 00 00        LDU    #$0000
46f3: 34 40           PSHS   U
46f5: 17 0e f9        LBSR   $55F1       ; → $55F1: DDS/timer subsystem reset
46f8: 32 62           LEAS   $2,S
46fa: ce 00 00        LDU    #$0000
46fd: 34 40           PSHS   U
46ff: 17 18 15        LBSR   $5F17       ; → $5F17: output port hardware reset
4702: 32 62           LEAS   $2,S
; Clear miscellaneous I/O ports
4704: 7f 0b 00        CLR    $0B00       ; clear aux output port
4707: f6 24 1f        LDB    $241F       ; keypad row shadow
470a: c4 7f           ANDB   #$7F        ; clear bit 7
470c: f7 24 1f        STB    $241F
470f: f6 24 1f        LDB    $241F
4712: f7 0a 00        STB    $0A00       ; write to keypad row port
4715: f6 24 20        LDB    $2420       ; LED shadow
4718: c4 7f           ANDB   #$7F        ; clear bit 7
471a: f7 24 20        STB    $2420
471d: f6 24 20        LDB    $2420
4720: f7 09 00        STB    $0900       ; write to LED port
4723: 7f 06 00        CLR    $0600       ; clear display control port
; Clear system control bits 1 and 9 of $2202
4726: fc 22 02        LDD    $2202
4729: 84 7d           ANDA   #$7D        ; clear high-byte bit 1 (= bit 9)
472b: c4 ff           ANDB   #$FF        ; (no-op — bit 1 clear is in high byte only)
472d: fd 22 02        STD    $2202
4730: 7f 23 de        CLR    $23DE       ; clear auxiliary parameter
; Enter idle-timeout state
4733: ce 00 00        LDU    #$0000
4736: 34 40           PSHS   U
4738: 17 14 21        LBSR   $5B5C       ; → enter idle-timeout (set bit 7, LED off)
473b: 32 62           LEAS   $2,S
; Loop channels 0-3: call $65BF(0, channel, 4)
473d: 6f 62           CLR    $2,S        ; channel index = 0
473f: e6 62           LDB    $2,S        ; loop: load index
4741: c1 04           CMPB   #$04        ; all 4 done?
4743: 10 24 00 1b     LBCC   $4762       ; yes → exit
4747: 5f              CLRB
4748: 1d              SEX
4749: 1f 03           TFR    D,U         ; U = 0 (arg 3)
474b: e6 62           LDB    $2,S
474d: 4f              CLRA
474e: 1f 02           TFR    D,Y         ; Y = channel index (arg 2)
4750: 8e 00 04        LDX    #$0004      ; X = 4 (arg 1: reset mode)
4753: 34 70           PSHS   U,Y,X
4755: 17 1e 67        LBSR   $65BF       ; → $65BF: channel output config
4758: 32 66           LEAS   $6,S
475a: e6 62           LDB    $2,S
475c: cb 01           ADDB   #$01        ; channel index++
475e: e7 62           STB    $2,S
4760: 20 dd           BRA    $473f       ; → loop
4762: 32 63           LEAS   $3,S        ; deallocate frame
4764: 39              RTS
; Channel mode to output-enable code — $4765.
; Maps a channel mode value to an output enable code: mode $0C→0, $0D→1, $0E→2, $0F→3,
; all others→$FF (invalid). Used by $3E5C and $47B0 for hardware output configuration.
4765: fc c8 c4        LDD    $C8C4
4768: 17 35 e5        LBSR   $7D50
476b: ae e9 00 08     LDX    $0008,S
476f: 16 00 21        LBRA   $4793
4772: 6f 62           CLR    $2,S
4774: 16 00 32        LBRA   $47A9
4777: c6 01           LDB    #$01
4779: e7 62           STB    $2,S
477b: 16 00 2b        LBRA   $47A9
477e: c6 02           LDB    #$02
4780: e7 62           STB    $2,S
4782: 16 00 24        LBRA   $47A9
4785: c6 03           LDB    #$03
4787: e7 62           STB    $2,S
4789: 16 00 1d        LBRA   $47A9
478c: c6 ff           LDB    #$FF
478e: e7 62           STB    $2,S
4790: 16 00 16        LBRA   $47A9
4793: 8c 00 0c        CMPX   #$000C
4796: 27 da           BEQ    $4772
4798: 8c 00 0d        CMPX   #$000D
479b: 27 da           BEQ    $4777
479d: 8c 00 0e        CMPX   #$000E
47a0: 27 dc           BEQ    $477E
47a2: 8c 00 0f        CMPX   #$000F
47a5: 27 de           BEQ    $4785
47a7: 20 e3           BRA    $478C
47a9: e6 62           LDB    $2,S
47ab: e7 63           STB    $3,S
47ad: 32 64           LEAS   $4,S
47af: 39              RTS
; Channel output parameter setup — $47B0.
; Determines output routing based on channel mode: modes $0F+ get a 4-column/8-offset
; layout, modes $04-$0E get 4-column/0-offset, others use the caller's values.
; Calls $4765 to get the enable code, then either $65E8 (for codes 0-3) or $669C
; (for larger codes, with special $0A mode adding $20 to the offset).
47b0: fc c8 b2        LDD    $C8B2
47b3: 17 35 9a        LBSR   $7D50
47b6: ae e9 00 0b     LDX    $000B,S
47ba: 8c 00 0f        CMPX   #$000F
47bd: 10 25 00 0b     LBCS   $47CC
47c1: c6 04           LDB    #$04
47c3: e7 63           STB    $3,S
47c5: c6 08           LDB    #$08
47c7: e7 64           STB    $4,S
47c9: 16 00 23        LBRA   $47EF
47cc: ae e9 00 0b     LDX    $000B,S
47d0: 8c 00 04        CMPX   #$0004
47d3: 10 25 00 09     LBCS   $47E0
47d7: c6 04           LDB    #$04
47d9: e7 63           STB    $3,S
47db: 6f 64           CLR    $4,S
47dd: 16 00 0f        LBRA   $47EF
47e0: e6 e9 00 0c     LDB    $000C,S
47e4: e7 63           STB    $3,S
47e6: cc 00 0c        LDD    #$000C
47e9: e3 e9 00 0b     ADDD   $000B,S
47ed: e7 64           STB    $4,S
47ef: ee e9 00 09     LDU    $0009,S
47f3: 10 8e 00 02     LDY    #$0002
47f7: 34 60           PSHS   U,Y
47f9: 17 ff 69        LBSR   $4765
47fc: 32 64           LEAS   $4,S
47fe: e7 62           STB    $2,S
4800: e6 62           LDB    $2,S
4802: c1 03           CMPB   #$03
4804: 10 22 00 17     LBHI   $481F
4808: e6 63           LDB    $3,S
480a: 4f              CLRA
480b: 1f 03           TFR    D,U
480d: e6 62           LDB    $2,S
480f: 4f              CLRA
4810: 1f 02           TFR    D,Y
4812: 8e 00 04        LDX    #$0004
4815: 34 70           PSHS   U,Y,X
4817: 17 1d ce        LBSR   $65E8
481a: 32 66           LEAS   $6,S
481c: 16 00 33        LBRA   $4852
481f: ae e9 00 09     LDX    $0009,S
4823: 8c 00 0a        CMPX   #$000A
4826: 10 26 00 0b     LBNE   $4835
482a: e6 64           LDB    $4,S
482c: c1 00           CMPB   #$00
482e: 10 27 00 03     LBEQ   $4835
4832: 16 00 03        LBRA   $4838
4835: 16 00 06        LBRA   $483E
4838: e6 64           LDB    $4,S
483a: cb 20           ADDB   #$20
483c: e7 64           STB    $4,S
483e: e6 64           LDB    $4,S
4840: 4f              CLRA
4841: 1f 03           TFR    D,U
4843: 10 ae e9 00 09  LDY    $0009,S
4848: 8e 00 04        LDX    #$0004
484b: 34 70           PSHS   U,Y,X
484d: 17 1e 4c        LBSR   $669C
4850: 32 66           LEAS   $6,S
4852: 32 65           LEAS   $5,S
4854: 39              RTS
; Display indicator write — $4855.
; Writes a marker character ($07, likely a custom HD44780 glyph) to the display at row position
; given by the stack argument ($0008,S) and column 1. Sets $2413 flag to indicate the marker is
; active, saves row to $2412. Called to show a visual indicator (e.g., active-channel arrow) on
; the display; cleared by $4885.
4855: fc c8 b4        LDD    $C8B4
4858: 17 34 f5        LBSR   $7D50
485b: c6 07           LDB    #$07
485d: e7 62           STB    $2,S
485f: c6 01           LDB    #$01
4861: f7 24 13        STB    $2413
4864: e6 e9 00 08     LDB    $0008,S
4868: f7 24 12        STB    $2412
486b: 33 62           LEAU   $2,S
486d: c6 01           LDB    #$01
486f: 1d              SEX
4870: 1f 02           TFR    D,Y
4872: f6 24 12        LDB    $2412
4875: 4f              CLRA
4876: 1f 01           TFR    D,X
4878: cc 00 06        LDD    #$0006
487b: 34 76           PSHS   U,Y,X,D
487d: 17 10 6a        LBSR   $58EA
4880: 32 68           LEAS   $8,S
4882: 32 63           LEAS   $3,S
4884: 39              RTS
; Clear display indicator — $4885.
; If $2413 flag is set (marker active), overwrites the marker position with ROM string at $ED11
; using $58EA at row $2412, column 1. Clears $2413 afterward. Companion to $4855 — removes
; the visual indicator previously written to the display.
4885: fc c8 b6        LDD    $C8B6
4888: 17 34 c5        LBSR   $7D50
488b: f6 24 13        LDB    $2413
488e: c1 00           CMPB   #$00
4890: 10 27 00 18     LBEQ   $48AC
4894: ce ed 11        LDU    #$ED11
4897: c6 01           LDB    #$01
4899: 1d              SEX
489a: 1f 02           TFR    D,Y
489c: f6 24 12        LDB    $2412
489f: 4f              CLRA
48a0: 1f 01           TFR    D,X
48a2: cc 00 06        LDD    #$0006
48a5: 34 76           PSHS   U,Y,X,D
48a7: 17 10 40        LBSR   $58EA
48aa: 32 68           LEAS   $8,S
48ac: 7f 24 13        CLR    $2413
48af: 32 62           LEAS   $2,S
48b1: 39              RTS
48b2: 00 03           NEG    <$03
48b4: 00 01           NEG    <$01
48b6: 00 00           NEG    <$00
48b8: 00 23           NEG    <$23
48ba: 00 01           NEG    <$01
48bc: 00 00           NEG    <$00
48be: 01 a9           NEG    <$A9
48c0: 00 04           NEG    <$04
48c2: 00 0d           NEG    <$0D
48c4: 00 02           NEG    <$02
; 16-bit division by 3600 — $48C6.
; Divides the 16-bit value at $000B,S by $0E10 (3600 decimal) using repeated
; shift-and-subtract (restoring binary long division, 16 iterations).
; Returns the quotient as a 16-bit result in D.
48c6: fc d2 e7        LDD    $D2E7
48c9: 17 34 84        LBSR   $7D50
48cc: 6f 62           CLR    $2,S
48ce: 5f              CLRB
48cf: 4f              CLRA
48d0: ed 63           STD    $3,S
48d2: e6 62           LDB    $2,S
48d4: c1 10           CMPB   #$10
48d6: 10 24 00 31     LBCC   $490B
48da: 68 e9 00 0c     ASL    $000C,S
48de: 69 e9 00 0b     ROL    $000B,S
48e2: 68 64           ASL    $4,S
48e4: 69 63           ROL    $3,S
48e6: ae e9 00 0b     LDX    $000B,S
48ea: 8c 0e 10        CMPX   #$0E10
48ed: 10 25 00 12     LBCS   $4903
48f1: ec e9 00 0b     LDD    $000B,S
48f5: 83 0e 10        SUBD   #$0E10
48f8: ed e9 00 0b     STD    $000B,S
48fc: ec 63           LDD    $3,S
48fe: c3 00 01        ADDD   #$0001
4901: ed 63           STD    $3,S
4903: e6 62           LDB    $2,S
4905: cb 01           ADDB   #$01
4907: e7 62           STB    $2,S
4909: 20 c7           BRA    $48D2
490b: ec 63           LDD    $3,S
490d: ed 65           STD    $5,S
490f: 32 67           LEAS   $7,S
4911: 39              RTS
; 16-bit unsigned integer to 5-digit ASCII decimal — $4912.
; Converts the 16-bit value at $0009,S into a 5-character ASCII string at the buffer pointed to
; by $000B,S. Uses repeated subtraction of decreasing powers of 10 ($2710=10000, then /10 via
; $7EC7 for each subsequent digit). Each digit starts at '0' ($30) and increments.
4912: fc d2 e9        LDD    $D2E9
4915: 17 34 38        LBSR   $7D50       ; allocate 5-byte frame
4918: 6f 64           CLR    $4,S        ; digit index = 0
491a: cc 27 10        LDD    #$2710      ; divisor = 10000 (ten-thousands place)
491d: ed 62           STD    $2,S
; Outer loop: one iteration per decimal digit position
491f: e6 64           LDB    $4,S        ; B = digit index
4921: c1 04           CMPB   #$04        ; all 5 digits done?
4923: 10 22 00 49     LBHI   $4970       ; yes → exit
4927: ae e9 00 0b     LDX    $000B,S     ; X = output buffer
492b: e6 64           LDB    $4,S
492d: 3a              ABX               ; X = &buffer[digit_index]
492e: c6 30           LDB    #$30        ; init digit to '0'
4930: e7 84           STB    ,X
; Inner loop: repeated subtraction for this digit position
4932: ae e9 00 09     LDX    $0009,S     ; X = remaining value
4936: ac 62           CMPX   $2,S        ; value >= divisor?
4938: 10 25 00 19     LBCS   $4955       ; no → next digit position
493c: ec e9 00 09     LDD    $0009,S
4940: a3 62           SUBD   $2,S        ; value -= divisor
4942: ed e9 00 09     STD    $0009,S
4946: ae e9 00 0b     LDX    $000B,S     ; increment the ASCII digit
494a: e6 64           LDB    $4,S
494c: 3a              ABX
494d: e6 84           LDB    ,X
494f: cb 01           ADDB   #$01        ; digit++
4951: e7 84           STB    ,X
4953: 20 dd           BRA    $4932       ; → subtract again
; Move to next digit: divisor /= 10
4955: ae 62           LDX    $2,S        ; X = current divisor
4957: 8c 00 0a        CMPX   #$000A      ; divisor < 10?
495a: 10 25 00 0a     LBCS   $4968       ; yes → skip division (ones place)
495e: ae 62           LDX    $2,S
4960: cc 00 0a        LDD    #$000A
4963: 17 35 61        LBSR   $7EC7       ; → X / D, result in D
4966: ed 62           STD    $2,S        ; divisor = divisor / 10
4968: e6 64           LDB    $4,S
496a: cb 01           ADDB   #$01        ; digit index++
496c: e7 64           STB    $4,S
496e: 20 af           BRA    $491F       ; → outer loop
4970: 32 65           LEAS   $5,S        ; deallocate frame
4972: 39              RTS
; 5-digit ASCII decimal to 16-bit unsigned integer — $4973.
; The inverse of $4912. Reads 5 ASCII digit characters from the buffer at $000E,S, converting
; each by subtracting '0' ($30) and accumulating via repeated addition of the corresponding
; power of 10 (starting at 10000, dividing by 10 each iteration via $7EC7).
; Returns the 16-bit result in D.
4973: fc d2 eb        LDD    $D2EB
4976: 17 33 d7        LBSR   $7D50       ; allocate frame
4979: 6f 66           CLR    $6,S        ; digit index = 0
497b: cc 27 10        LDD    #$2710      ; weight = 10000 (ten-thousands place)
497e: ed 62           STD    $2,S        ; current place weight
4980: 5f              CLRB
4981: 4f              CLRA
4982: ed 64           STD    $4,S        ; accumulator = 0
; Outer loop: one iteration per digit position
4984: e6 66           LDB    $6,S        ; B = digit index
4986: c1 04           CMPB   #$04        ; all 5 digits done?
4988: 10 22 00 3e     LBHI   $49CA       ; yes → return result
; Read ASCII digit and convert to binary
498c: ae e9 00 0e     LDX    $000E,S     ; X = input buffer
4990: e6 66           LDB    $6,S
4992: 3a              ABX               ; X = &buffer[digit_index]
4993: e6 84           LDB    ,X          ; B = ASCII char
4995: c0 30           SUBB   #$30        ; B = binary digit (0-9)
4997: e7 67           STB    $7,S        ; save digit value
; Inner loop: add weight N times (N = digit value)
4999: e6 67           LDB    $7,S        ; B = remaining adds
499b: c1 00           CMPB   #$00
499d: 10 23 00 0e     LBLS   $49AF       ; zero → next digit position
49a1: ec 64           LDD    $4,S        ; D = accumulator
49a3: e3 62           ADDD   $2,S        ; accumulator += weight
49a5: ed 64           STD    $4,S
49a7: e6 67           LDB    $7,S        ; remaining adds--
49a9: c0 01           SUBB   #$01
49ab: e7 67           STB    $7,S
49ad: 20 ea           BRA    $4999       ; → inner loop
; Move to next digit: weight /= 10
49af: ae 62           LDX    $2,S        ; X = current weight
49b1: 8c 00 0a        CMPX   #$000A      ; weight < 10?
49b4: 10 25 00 0a     LBCS   $49C2       ; yes → skip division (ones place)
49b8: ae 62           LDX    $2,S
49ba: cc 00 0a        LDD    #$000A
49bd: 17 35 07        LBSR   $7EC7       ; → X / D, result in D
49c0: ed 62           STD    $2,S        ; weight = weight / 10
49c2: e6 66           LDB    $6,S
49c4: cb 01           ADDB   #$01        ; digit index++
49c6: e7 66           STB    $6,S
49c8: 20 ba           BRA    $4984
49ca: ec 64           LDD    $4,S
49cc: ed 68           STD    $8,S
49ce: 32 6a           LEAS   $A,S
49d0: 39              RTS
; 8-bit unsigned integer to 3-digit ASCII decimal — $49D1.
; Converts the byte value at $000A,S into a 3-character ASCII string at the buffer pointed to
; by $000C,S. Uses repeated subtraction starting from 100 ($64), dividing by 10 each round.
; Commonly used for HP-IB status byte and address formatting.
49d1: fc d2 ed        LDD    $D2ED
49d4: 17 33 79        LBSR   $7D50       ; allocate 4-byte frame
49d7: 6f 63           CLR    $3,S        ; digit index = 0
49d9: c6 64           LDB    #$64        ; divisor = 100 (hundreds place)
49db: e7 62           STB    $2,S
; Outer loop: for digit positions 0, 1, 2 (hundreds, tens, ones)
49dd: e6 63           LDB    $3,S
49df: c1 02           CMPB   #$02        ; done all 3 digits?
49e1: 10 22 00 4e     LBHI   $4A33       ; yes → exit
49e5: ae e9 00 0c     LDX    $000C,S     ; X = output buffer base
49e9: e6 63           LDB    $3,S
49eb: 3a              ABX               ; X = &buffer[digit_index]
49ec: c6 30           LDB    #$30        ; initialize digit to '0'
49ee: e7 84           STB    ,X
; Inner loop: repeated subtraction — increment ASCII digit while value >= divisor
49f0: e6 62           LDB    $2,S        ; B = current divisor
49f2: 4f              CLRA              ; D = divisor (16-bit)
49f3: 10 a3 e9 00 0a  CMPD   $000A,S     ; divisor > remaining value?
49f8: 10 22 00 1e     LBHI   $4A1A       ; yes → move to next digit
49fc: e6 62           LDB    $2,S        ; subtract divisor from value
49fe: 4f              CLRA
49ff: ed 64           STD    $4,S        ; temp = divisor
4a01: ec e9 00 0a     LDD    $000A,S     ; D = remaining value
4a05: a3 64           SUBD   $4,S        ; D -= divisor
4a07: ed e9 00 0a     STD    $000A,S     ; store back
4a0b: ae e9 00 0c     LDX    $000C,S     ; increment digit character
4a0f: e6 63           LDB    $3,S
4a11: 3a              ABX
4a12: e6 84           LDB    ,X          ; load current digit char
4a14: cb 01           ADDB   #$01        ; digit++
4a16: e7 84           STB    ,X
4a18: 20 d6           BRA    $49F0       ; → repeat subtraction
; Move to next digit: divisor /= 10
4a1a: e6 62           LDB    $2,S        ; current divisor
4a1c: c1 0a           CMPB   #$0A        ; < 10? (ones place has no further divide)
4a1e: 10 25 00 09     LBCS   $4A2B       ; yes → skip divide
4a22: a6 62           LDA    $2,S        ; A = divisor
4a24: c6 0a           LDB    #$0A
4a26: 17 34 36        LBSR   $7E5F       ; → 8÷8 divide: A/B, result in B
4a29: e7 62           STB    $2,S        ; divisor = divisor / 10
4a2b: e6 63           LDB    $3,S
4a2d: cb 01           ADDB   #$01
4a2f: e7 63           STB    $3,S
4a31: 20 aa           BRA    $49DD
4a33: 32 66           LEAS   $6,S
4a35: 39              RTS
; 3-digit ASCII decimal to 8-bit unsigned integer — $4A36.
; The inverse of $49D1. Reads 3 ASCII digit characters from the buffer at $000B,S, converting
; each by subtracting '0' and accumulating via repeated addition of the place value (100, 10, 1).
; Returns the 8-bit result in B.
4a36: fc d2 e7        LDD    $D2E7
4a39: 17 33 14        LBSR   $7D50       ; allocate frame
4a3c: 6f 64           CLR    $4,S        ; digit index = 0
4a3e: c6 64           LDB    #$64        ; weight = 100 (hundreds place)
4a40: e7 62           STB    $2,S
4a42: 6f 63           CLR    $3,S        ; accumulator = 0
4a44: e6 64           LDB    $4,S
4a46: c1 02           CMPB   #$02
4a48: 10 22 00 3c     LBHI   $4A88
4a4c: ae e9 00 0b     LDX    $000B,S
4a50: e6 64           LDB    $4,S
4a52: 3a              ABX
4a53: e6 84           LDB    ,X
4a55: c0 30           SUBB   #$30
4a57: e7 65           STB    $5,S
4a59: e6 65           LDB    $5,S
4a5b: c1 00           CMPB   #$00
4a5d: 10 23 00 0e     LBLS   $4A6F
4a61: e6 63           LDB    $3,S
4a63: eb 62           ADDB   $2,S
4a65: e7 63           STB    $3,S
4a67: e6 65           LDB    $5,S
4a69: c0 01           SUBB   #$01
4a6b: e7 65           STB    $5,S
4a6d: 20 ea           BRA    $4A59
4a6f: e6 62           LDB    $2,S
4a71: c1 0a           CMPB   #$0A
4a73: 10 25 00 09     LBCS   $4A80
4a77: a6 62           LDA    $2,S
4a79: c6 0a           LDB    #$0A
4a7b: 17 33 e1        LBSR   $7E5F
4a7e: e7 62           STB    $2,S
4a80: e6 64           LDB    $4,S
4a82: cb 01           ADDB   #$01
4a84: e7 64           STB    $4,S
4a86: 20 bc           BRA    $4A44
4a88: e6 63           LDB    $3,S
4a8a: e7 66           STB    $6,S
4a8c: 32 67           LEAS   $7,S
4a8e: 39              RTS
; Multi-digit parameter formatter — $4A8F.
; Formats a multi-byte numeric value (pointed to by $000D,S) into an 8-character ASCII string at
; the buffer pointed to by $000F,S. Uses the array descriptor table at $D2EF ($EE4A data table)
; to extract individual BCD digits via $7CEA, comparing each digit-position value via $53C6 and
; building the ASCII representation by repeated subtraction (same pattern as $4912/$49D1).
4a8f: fc d2 f5        LDD    $D2F5
4a92: 17 32 bb        LBSR   $7D50       ; allocate frame
4a95: ee e9 00 0d     LDU    $000D,S     ; U = source value pointer
4a99: 31 64           LEAY   $4,S        ; Y = local temp buffer
4a9b: 8e 00 04        LDX    #$0004
4a9e: 34 70           PSHS   U,Y,X
4aa0: 17 08 da        LBSR   $537D       ; → copy value to local temp
4aa3: 32 66           LEAS   $6,S
4aa5: 6f 62           CLR    $2,S
4aa7: e6 62           LDB    $2,S
4aa9: c1 08           CMPB   #$08
4aab: 10 24 00 5e     LBCC   $4B0D
4aaf: ae e9 00 0f     LDX    $000F,S
4ab3: e6 62           LDB    $2,S
4ab5: 3a              ABX
4ab6: c6 30           LDB    #$30
4ab8: e7 84           STB    ,X
4aba: ce ee 4a        LDU    #$EE4A
4abd: e6 62           LDB    $2,S
4abf: 4f              CLRA
4ac0: 1f 02           TFR    D,Y
4ac2: 34 60           PSHS   U,Y
4ac4: 86 01           LDA    #$01
4ac6: 8e d2 ef        LDX    #$D2EF
4ac9: 17 32 1e        LBSR   $7CEA
4acc: af 67           STX    $7,S
4ace: 33 64           LEAU   $4,S
4ad0: 10 ae 67        LDY    $7,S
4ad3: 30 64           LEAX   $4,S
4ad5: cc 00 06        LDD    #$0006
4ad8: 34 76           PSHS   U,Y,X,D
4ada: 17 08 e9        LBSR   $53C6
4add: 32 68           LEAS   $8,S
4adf: c1 00           CMPB   #$00
4ae1: 10 26 00 0f     LBNE   $4AF4
4ae5: ae e9 00 0f     LDX    $000F,S
4ae9: e6 62           LDB    $2,S
4aeb: 3a              ABX
4aec: e6 84           LDB    ,X
4aee: cb 01           ADDB   #$01
4af0: e7 84           STB    ,X
4af2: 20 da           BRA    $4ACE
4af4: 33 64           LEAU   $4,S
4af6: 10 ae 67        LDY    $7,S
4af9: 30 64           LEAX   $4,S
4afb: cc 00 06        LDD    #$0006
4afe: 34 76           PSHS   U,Y,X,D
4b00: 17 08 8f        LBSR   $5392
4b03: 32 68           LEAS   $8,S
4b05: e6 62           LDB    $2,S
4b07: cb 01           ADDB   #$01
4b09: e7 62           STB    $2,S
4b0b: 20 9a           BRA    $4AA7
4b0d: 32 69           LEAS   $9,S
4b0f: 39              RTS
; ASCII decimal to packed fixed-point conversion — $4B10.
; Converts an 8-digit ASCII decimal string (at $000C,S) into a 3-byte packed fixed-point value
; (stored at [$000E,S]). Initializes the result from ROM default at $EA58, then for each of 8
; digit positions, uses $7CEA at $D2EF/$EE4A to look up the positional weight and accumulates
; digit × weight via repeated $5392 (packed add). On overflow, saturates the result to $FF,$FFFF.
4b10: fc d2 f7        LDD    $D2F7
4b13: 17 32 3a        LBSR   $7D50
4b16: ce ea 58        LDU    #$EA58
4b19: 10 ae e9 00 0e  LDY    $000E,S
4b1e: 8e 00 04        LDX    #$0004
4b21: 34 70           PSHS   U,Y,X
4b23: 17 08 57        LBSR   $537D
4b26: 32 66           LEAS   $6,S
4b28: 6f 62           CLR    $2,S
4b2a: e6 62           LDB    $2,S
4b2c: c1 08           CMPB   #$08
4b2e: 10 24 00 71     LBCC   $4BA3
4b32: ce ee 4a        LDU    #$EE4A
4b35: e6 62           LDB    $2,S
4b37: 4f              CLRA
4b38: 1f 02           TFR    D,Y
4b3a: 34 60           PSHS   U,Y
4b3c: 86 01           LDA    #$01
4b3e: 8e d2 ef        LDX    #$D2EF
4b41: 17 31 a6        LBSR   $7CEA
4b44: af 64           STX    $4,S
4b46: ae e9 00 0c     LDX    $000C,S
4b4a: e6 62           LDB    $2,S
4b4c: 3a              ABX
4b4d: e6 84           LDB    ,X
4b4f: c0 30           SUBB   #$30
4b51: e7 63           STB    $3,S
4b53: e6 63           LDB    $3,S
4b55: c1 00           CMPB   #$00
4b57: 10 23 00 40     LBLS   $4B9B
4b5b: ee e9 00 0e     LDU    $000E,S
4b5f: 10 ae e9 00 0e  LDY    $000E,S
4b64: ae 64           LDX    $4,S
4b66: cc 00 06        LDD    #$0006
4b69: 34 76           PSHS   U,Y,X,D
4b6b: 17 08 24        LBSR   $5392
4b6e: 32 68           LEAS   $8,S
4b70: c1 00           CMPB   #$00
4b72: 10 27 00 1d     LBEQ   $4B93
4b76: ae e9 00 0e     LDX    $000E,S
4b7a: ee e9 00 0e     LDU    $000E,S
4b7e: 33 41           LEAU   $1,U
4b80: 10 ae e9 00 0e  LDY    $000E,S
4b85: 31 22           LEAY   $2,Y
4b87: c6 ff           LDB    #$FF
4b89: e7 a4           STB    ,Y
4b8b: c6 ff           LDB    #$FF
4b8d: e7 c4           STB    ,U
4b8f: ef 66           STU    $6,S
4b91: e7 84           STB    ,X
4b93: e6 63           LDB    $3,S
4b95: c0 01           SUBB   #$01
4b97: e7 63           STB    $3,S
4b99: 20 b8           BRA    $4B53
4b9b: e6 62           LDB    $2,S
4b9d: cb 01           ADDB   #$01
4b9f: e7 62           STB    $2,S
4ba1: 20 87           BRA    $4B2A
4ba3: 32 68           LEAS   $8,S
4ba5: 39              RTS
; Byte to 2-character hex ASCII — $4BA6.
; Converts a byte value (low byte of $000A,S) into two hex ASCII characters. Extracts the low
; nibble directly and the high nibble via $7FA4 right-shift-4. Each nibble is converted: 0-9
; becomes '0'-'9' (+$30), 10-15 becomes 'A'-'F' (+$37). Writes the high nibble character
; first, then the low nibble character, to the buffer pointer at $000C,S (which is advanced).
4ba6: fc d2 ed        LDD    $D2ED
4ba9: 17 31 a4        LBSR   $7D50
4bac: ec e9 00 0a     LDD    $000A,S
4bb0: 84 00           ANDA   #$00
4bb2: c4 0f           ANDB   #$0F
4bb4: e7 65           STB    $5,S
4bb6: ae e9 00 0a     LDX    $000A,S
4bba: c6 fc           LDB    #$FC
4bbc: 17 33 e5        LBSR   $7FA4
4bbf: e7 64           STB    $4,S
4bc1: e6 65           LDB    $5,S
4bc3: c1 09           CMPB   #$09
4bc5: 10 22 00 09     LBHI   $4BD2
4bc9: e6 65           LDB    $5,S
4bcb: cb 30           ADDB   #$30
4bcd: e7 65           STB    $5,S
4bcf: 16 00 06        LBRA   $4BD8
4bd2: e6 65           LDB    $5,S
4bd4: cb 37           ADDB   #$37
4bd6: e7 65           STB    $5,S
4bd8: e6 64           LDB    $4,S
4bda: c1 09           CMPB   #$09
4bdc: 10 22 00 09     LBHI   $4BE9
4be0: e6 64           LDB    $4,S
4be2: cb 30           ADDB   #$30
4be4: e7 64           STB    $4,S
4be6: 16 00 06        LBRA   $4BEF
4be9: e6 64           LDB    $4,S
4beb: cb 37           ADDB   #$37
4bed: e7 64           STB    $4,S
4bef: e6 64           LDB    $4,S
4bf1: e7 f9 00 0c     STB    [$000C,S]
4bf5: ec e9 00 0c     LDD    $000C,S
4bf9: c3 00 01        ADDD   #$0001
4bfc: ed e9 00 0c     STD    $000C,S
4c00: e6 65           LDB    $5,S
4c02: e7 f9 00 0c     STB    [$000C,S]
4c06: 32 66           LEAS   $6,S
4c08: 39              RTS
; 16-bit value to 4-character hex ASCII — $4C09.
; Converts a 16-bit value (at $0008,S) into a 4-character hex ASCII string at the buffer pointed
; to by $000A,S. Splits the value: high byte via $7FA4 right-shift-8, low byte from $0009,S.
; Calls $4BA6 twice — once for the high byte, once for the low byte — advancing the buffer
; pointer by 2 between calls.
4c09: fc d2 f9        LDD    $D2F9
4c0c: 17 31 41        LBSR   $7D50
4c0f: e6 e9 00 09     LDB    $0009,S
4c13: e7 63           STB    $3,S
4c15: ae e9 00 08     LDX    $0008,S
4c19: c6 f8           LDB    #$F8
4c1b: 17 33 86        LBSR   $7FA4
4c1e: e7 62           STB    $2,S
4c20: ee e9 00 0a     LDU    $000A,S
4c24: e6 62           LDB    $2,S
4c26: 4f              CLRA
4c27: 1f 02           TFR    D,Y
4c29: 8e 00 04        LDX    #$0004
4c2c: 34 70           PSHS   U,Y,X
4c2e: 17 ff 75        LBSR   $4BA6
4c31: 32 66           LEAS   $6,S
4c33: ae e9 00 0a     LDX    $000A,S
4c37: 30 02           LEAX   $2,X
4c39: af e9 00 0a     STX    $000A,S
4c3d: ee e9 00 0a     LDU    $000A,S
4c41: e6 63           LDB    $3,S
4c43: 4f              CLRA
4c44: 1f 02           TFR    D,Y
4c46: 8e 00 04        LDX    #$0004
4c49: 34 70           PSHS   U,Y,X
4c4b: 17 ff 58        LBSR   $4BA6
4c4e: 32 66           LEAS   $6,S
4c50: 32 64           LEAS   $4,S
4c52: 39              RTS
; 2-character hex ASCII to byte — $4C53.
; Converts two hex ASCII characters (read via indirect pointer [$0009,S]) into a single byte
; value. For each character: if >= 'A' ($41), subtracts $37 to get 10-15; otherwise subtracts
; $30 to get 0-9. Combines the two nibbles: (first_char << 4) | second_char. Returns the
; result in B. Inverse of $4BA6.
4c53: fc d2 e9        LDD    $D2E9
4c56: 17 30 f7        LBSR   $7D50
4c59: e6 f9 00 09     LDB    [$0009,S]
4c5d: e7 62           STB    $2,S
4c5f: ec e9 00 09     LDD    $0009,S
4c63: c3 00 01        ADDD   #$0001
4c66: ed e9 00 09     STD    $0009,S
4c6a: e6 f9 00 09     LDB    [$0009,S]
4c6e: e7 63           STB    $3,S
4c70: e6 62           LDB    $2,S
4c72: c1 41           CMPB   #$41
4c74: 10 25 00 09     LBCS   $4C81
4c78: e6 62           LDB    $2,S
4c7a: c0 37           SUBB   #$37
4c7c: e7 62           STB    $2,S
4c7e: 16 00 06        LBRA   $4C87
4c81: e6 62           LDB    $2,S
4c83: c0 30           SUBB   #$30
4c85: e7 62           STB    $2,S
4c87: e6 63           LDB    $3,S
4c89: c1 41           CMPB   #$41
4c8b: 10 25 00 09     LBCS   $4C98
4c8f: e6 63           LDB    $3,S
4c91: c0 37           SUBB   #$37
4c93: e7 63           STB    $3,S
4c95: 16 00 06        LBRA   $4C9E
4c98: e6 63           LDB    $3,S
4c9a: c0 30           SUBB   #$30
4c9c: e7 63           STB    $3,S
4c9e: e6 62           LDB    $2,S
4ca0: 58              ASLB
4ca1: 58              ASLB
4ca2: 58              ASLB
4ca3: 58              ASLB
4ca4: e7 62           STB    $2,S
4ca6: e6 63           LDB    $3,S
4ca8: c4 0f           ANDB   #$0F
4caa: e7 63           STB    $3,S
4cac: e6 63           LDB    $3,S
4cae: eb 62           ADDB   $2,S
4cb0: e7 64           STB    $4,S
4cb2: 32 65           LEAS   $5,S
4cb4: 39              RTS
; 4-character hex ASCII to 16-bit value — $4CB5.
; Converts a 4-character hex ASCII string (at $000C,S) into a 16-bit unsigned value. Calls
; $4C53 twice to decode high byte and low byte, then combines: high_byte × $0100 (via $7F42)
; + low_byte. Returns the 16-bit result in D. Inverse of $4C09.
4cb5: fc d2 f7        LDD    $D2F7
4cb8: 17 30 95        LBSR   $7D50
4cbb: ee e9 00 0c     LDU    $000C,S
4cbf: 10 8e 00 02     LDY    #$0002
4cc3: 34 60           PSHS   U,Y
4cc5: 8d 8c           BSR    $4C53
4cc7: 32 64           LEAS   $4,S
4cc9: e7 62           STB    $2,S
4ccb: ae e9 00 0c     LDX    $000C,S
4ccf: 30 02           LEAX   $2,X
4cd1: af e9 00 0c     STX    $000C,S
4cd5: ee e9 00 0c     LDU    $000C,S
4cd9: 10 8e 00 02     LDY    #$0002
4cdd: 34 60           PSHS   U,Y
4cdf: 17 ff 71        LBSR   $4C53
4ce2: 32 64           LEAS   $4,S
4ce4: e7 63           STB    $3,S
4ce6: e6 62           LDB    $2,S
4ce8: 4f              CLRA
4ce9: 8e 01 00        LDX    #$0100
4cec: 17 32 53        LBSR   $7F42
4cef: ed 64           STD    $4,S
4cf1: e6 63           LDB    $3,S
4cf3: 4f              CLRA
4cf4: e3 64           ADDD   $4,S
4cf6: ed 64           STD    $4,S
4cf8: ec 64           LDD    $4,S
4cfa: ed 66           STD    $6,S
4cfc: 32 68           LEAS   $8,S
4cfe: 39              RTS
; Leading-zero suppression — $4CFF.
; Scans the ASCII string at [$0009,S] and replaces leading '0' ($30) and space ($20) characters
; with spaces, stopping when a non-zero/non-space character is found or the position reaches
; the limit in $0007,S. Used to blank leading zeros in numeric display fields.
4cff: fc d2 ef        LDD    $D2EF
4d02: 17 30 4b        LBSR   $7D50
4d05: 6f 62           CLR    $2,S
4d07: ae e9 00 09     LDX    $0009,S
4d0b: e6 62           LDB    $2,S
4d0d: 3a              ABX
4d0e: e6 84           LDB    ,X
4d10: c1 30           CMPB   #$30
4d12: 10 27 00 12     LBEQ   $4D28
4d16: ae e9 00 09     LDX    $0009,S
4d1a: e6 62           LDB    $2,S
4d1c: 3a              ABX
4d1d: e6 84           LDB    ,X
4d1f: c1 20           CMPB   #$20
4d21: 10 27 00 03     LBEQ   $4D28
4d25: 16 00 0f        LBRA   $4D37
4d28: e6 62           LDB    $2,S
4d2a: 4f              CLRA
4d2b: 10 a3 e9 00 07  CMPD   $0007,S
4d30: 10 24 00 03     LBCC   $4D37
4d34: 16 00 03        LBRA   $4D3A
4d37: 16 00 13        LBRA   $4D4D
4d3a: ae e9 00 09     LDX    $0009,S
4d3e: e6 62           LDB    $2,S
4d40: 3a              ABX
4d41: c6 20           LDB    #$20
4d43: e7 84           STB    ,X
4d45: e6 62           LDB    $2,S
4d47: cb 01           ADDB   #$01
4d49: e7 62           STB    $2,S
4d4b: 20 ba           BRA    $4D07
4d4d: 32 63           LEAS   $3,S
4d4f: 39              RTS
; Decimal string formatter with decimal point insertion — $4D50.
; Takes a source digit string ($0012,S), source length ($0016,S), decimal point position
; ($0018,S), leading-zero suppress flag ($001A,S), and destination buffer pointer ($0014,S).
; Copies source characters into a local buffer, inserting a '.' ($2E) at the decimal position.
; If the suppress flag is non-zero and the digit at the insertion point is '0', replaces it
; with space. Copies (source_length + 1) bytes to the destination via $4285.
4d50: fc d2 fb        LDD    $D2FB
4d53: 17 2f fa        LBSR   $7D50
4d56: 6f 62           CLR    $2,S
4d58: 6f 63           CLR    $3,S
4d5a: e6 62           LDB    $2,S
4d5c: 4f              CLRA
4d5d: 10 a3 e9 00 16  CMPD   $0016,S
4d62: 10 24 00 38     LBCC   $4D9E
4d66: e6 63           LDB    $3,S
4d68: 4f              CLRA
4d69: 10 a3 e9 00 18  CMPD   $0018,S
4d6e: 10 26 00 0c     LBNE   $4D7E
4d72: 30 64           LEAX   $4,S
4d74: e6 63           LDB    $3,S
4d76: 3a              ABX
4d77: c6 2e           LDB    #$2E
4d79: e7 84           STB    ,X
4d7b: 16 00 18        LBRA   $4D96
4d7e: 30 64           LEAX   $4,S
4d80: e6 63           LDB    $3,S
4d82: 3a              ABX
4d83: ee e9 00 12     LDU    $0012,S
4d87: e6 62           LDB    $2,S
4d89: 4f              CLRA
4d8a: 33 cb           LEAU   D,U
4d8c: e6 c4           LDB    ,U
4d8e: e7 84           STB    ,X
4d90: e6 62           LDB    $2,S
4d92: cb 01           ADDB   #$01
4d94: e7 62           STB    $2,S
4d96: e6 63           LDB    $3,S
4d98: cb 01           ADDB   #$01
4d9a: e7 63           STB    $3,S
4d9c: 20 bc           BRA    $4D5A
4d9e: ae e9 00 1a     LDX    $001A,S
4da2: 8c 00 00        CMPX   #$0000
4da5: 10 27 00 1c     LBEQ   $4DC5
4da9: 30 64           LEAX   $4,S
4dab: ec e9 00 16     LDD    $0016,S
4daf: 30 8b           LEAX   D,X
4db1: e6 84           LDB    ,X
4db3: c1 30           CMPB   #$30
4db5: 10 26 00 0c     LBNE   $4DC5
4db9: 30 64           LEAX   $4,S
4dbb: ec e9 00 16     LDD    $0016,S
4dbf: 30 8b           LEAX   D,X
4dc1: c6 20           LDB    #$20
4dc3: e7 84           STB    ,X
4dc5: ec e9 00 16     LDD    $0016,S
4dc9: c3 00 01        ADDD   #$0001
4dcc: ee e9 00 14     LDU    $0014,S
4dd0: 31 64           LEAY   $4,S
4dd2: 1f 01           TFR    D,X
4dd4: cc 00 06        LDD    #$0006
4dd7: 34 76           PSHS   U,Y,X,D
4dd9: 17 f4 a9        LBSR   $4285
4ddc: 32 68           LEAS   $8,S
4dde: 32 6e           LEAS   $E,S
4de0: 39              RTS
; Numeric entry master formatter — $4DE1.
; Converts the raw numeric entry buffer $239A into a fully formatted display string for the
; active parameter type. Initializes a 22-byte ('0'-filled) working buffer. Checks for leading
; sign ('+'/'-') in $239A[0] → $241E. Uses $2204 bit 3 to select between $23A4 direct digit
; count or $3223-computed formatting. Scans $239A to locate the decimal point and count
; significant digits. Dispatches through a 19-entry jump table at $D124 indexed by a computed
; format code (0-18) to set field width, integer digit count, and decimal digit count. Calls
; $4D50 to build the formatted output string with decimal point insertion. Returns the format
; result byte (or $FF on empty/invalid input).
4de1: fc d2 fd        LDD    $D2FD
4de4: 17 2f 69        LBSR   $7D50
4de7: 6f 63           CLR    $3,S
4de9: e6 63           LDB    $3,S
4deb: c1 16           CMPB   #$16
4ded: 10 24 00 11     LBCC   $4E02
4df1: 30 68           LEAX   $8,S
4df3: e6 63           LDB    $3,S
4df5: 3a              ABX
4df6: c6 30           LDB    #$30
4df8: e7 84           STB    ,X
4dfa: e6 63           LDB    $3,S
4dfc: cb 01           ADDB   #$01
4dfe: e7 63           STB    $3,S
4e00: 20 e7           BRA    $4DE9
4e02: c6 ff           LDB    #$FF
4e04: e7 67           STB    $7,S
4e06: f6 23 9a        LDB    $239A
4e09: c1 2b           CMPB   #$2B
4e0b: 10 27 00 0c     LBEQ   $4E1B
4e0f: f6 23 9a        LDB    $239A
4e12: c1 2d           CMPB   #$2D
4e14: 10 27 00 03     LBEQ   $4E1B
4e18: 16 00 06        LBRA   $4E21
4e1b: f6 23 9a        LDB    $239A
4e1e: f7 24 1e        STB    $241E
4e21: fc 22 04        LDD    $2204
4e24: 84 00           ANDA   #$00
4e26: c4 08           ANDB   #$08
4e28: 10 83 00 00     CMPD   #$0000
4e2c: 10 27 00 1d     LBEQ   $4E4D
4e30: f6 23 a4        LDB    $23A4
4e33: e7 65           STB    $5,S
4e35: e6 65           LDB    $5,S
4e37: c1 00           CMPB   #$00
4e39: 10 26 00 08     LBNE   $4E45
4e3d: e6 67           LDB    $7,S
4e3f: e7 e8 1e        STB    $1E,S
4e42: 16 01 d6        LBRA   $501B
4e45: f6 23 88        LDB    $2388
4e48: e7 62           STB    $2,S
4e4a: 16 00 8b        LBRA   $4ED8
4e4d: c6 08           LDB    #$08
4e4f: 1d              SEX
4e50: 1f 03           TFR    D,U
4e52: 10 8e 00 02     LDY    #$0002
4e56: 34 60           PSHS   U,Y
4e58: 17 e3 c8        LBSR   $3223
4e5b: 32 64           LEAS   $4,S
4e5d: e7 65           STB    $5,S
4e5f: e6 65           LDB    $5,S
4e61: c1 00           CMPB   #$00
4e63: 10 26 00 08     LBNE   $4E6F
4e67: e6 67           LDB    $7,S
4e69: e7 e8 1e        STB    $1E,S
4e6c: 16 01 ac        LBRA   $501B
4e6f: c6 07           LDB    #$07
4e71: e7 63           STB    $3,S
4e73: c6 07           LDB    #$07
4e75: e7 64           STB    $4,S
4e77: c6 07           LDB    #$07
4e79: e7 62           STB    $2,S
4e7b: e6 65           LDB    $5,S
4e7d: e7 66           STB    $6,S
4e7f: e6 66           LDB    $6,S
4e81: c1 00           CMPB   #$00
4e83: 10 23 00 41     LBLS   $4EC8
4e87: 8e 23 9a        LDX    #$239A
4e8a: e6 63           LDB    $3,S
4e8c: 3a              ABX
4e8d: e6 84           LDB    ,X
4e8f: c1 2e           CMPB   #$2E
4e91: 10 26 00 0d     LBNE   $4EA2
4e95: e6 63           LDB    $3,S
4e97: e7 62           STB    $2,S
4e99: e6 65           LDB    $5,S
4e9b: c0 01           SUBB   #$01
4e9d: e7 65           STB    $5,S
4e9f: 16 00 18        LBRA   $4EBA
4ea2: 8e 23 9a        LDX    #$239A
4ea5: e6 64           LDB    $4,S
4ea7: 3a              ABX
4ea8: ce 23 9a        LDU    #$239A
4eab: e6 63           LDB    $3,S
4ead: 4f              CLRA
4eae: 33 cb           LEAU   D,U
4eb0: e6 c4           LDB    ,U
4eb2: e7 84           STB    ,X
4eb4: e6 64           LDB    $4,S
4eb6: c0 01           SUBB   #$01
4eb8: e7 64           STB    $4,S
4eba: e6 66           LDB    $6,S
4ebc: c0 01           SUBB   #$01
4ebe: e7 66           STB    $6,S
4ec0: e6 63           LDB    $3,S
4ec2: c0 01           SUBB   #$01
4ec4: e7 63           STB    $3,S
4ec6: 20 b7           BRA    $4E7F
4ec8: e6 65           LDB    $5,S
4eca: c1 00           CMPB   #$00
4ecc: 10 26 00 08     LBNE   $4ED8
4ed0: e6 67           LDB    $7,S
4ed2: e7 e8 1e        STB    $1E,S
4ed5: 16 01 43        LBRA   $501B
4ed8: e6 65           LDB    $5,S
4eda: eb 62           ADDB   $2,S
4edc: e7 66           STB    $6,S
4ede: ae e9 00 23     LDX    $0023,S
4ee2: 16 00 a2        LBRA   $4F87
4ee5: 86 12           LDA    #$12
4ee7: e6 66           LDB    $6,S
4ee9: 17 2e a3        LBSR   $7D8F
4eec: e7 64           STB    $4,S
4eee: c6 10           LDB    #$10
4ef0: e0 64           SUBB   $4,S
4ef2: e7 67           STB    $7,S
4ef4: 16 00 b9        LBRA   $4FB0
4ef7: 86 15           LDA    #$15
4ef9: e6 66           LDB    $6,S
4efb: 17 2e 91        LBSR   $7D8F
4efe: e7 64           STB    $4,S
4f00: c6 10           LDB    #$10
4f02: e0 64           SUBB   $4,S
4f04: e7 67           STB    $7,S
4f06: 16 00 a7        LBRA   $4FB0
4f09: 86 0f           LDA    #$0F
4f0b: e6 66           LDB    $6,S
4f0d: 17 2e 7f        LBSR   $7D8F
4f10: e7 64           STB    $4,S
4f12: c6 0c           LDB    #$0C
4f14: e0 64           SUBB   $4,S
4f16: e7 67           STB    $7,S
4f18: 16 00 95        LBRA   $4FB0
4f1b: 86 0f           LDA    #$0F
4f1d: e6 66           LDB    $6,S
4f1f: 17 2e 6d        LBSR   $7D8F
4f22: e7 64           STB    $4,S
4f24: c6 0e           LDB    #$0E
4f26: e0 64           SUBB   $4,S
4f28: e7 67           STB    $7,S
4f2a: 16 00 83        LBRA   $4FB0
4f2d: 86 12           LDA    #$12
4f2f: e6 66           LDB    $6,S
4f31: 17 2e 5b        LBSR   $7D8F
4f34: e7 64           STB    $4,S
4f36: c6 0e           LDB    #$0E
4f38: e0 64           SUBB   $4,S
4f3a: e7 67           STB    $7,S
4f3c: 16 00 71        LBRA   $4FB0
4f3f: 86 15           LDA    #$15
4f41: e6 66           LDB    $6,S
4f43: 17 2e 49        LBSR   $7D8F
4f46: e7 64           STB    $4,S
4f48: c6 0e           LDB    #$0E
4f4a: e0 64           SUBB   $4,S
4f4c: e7 67           STB    $7,S
4f4e: 16 00 5f        LBRA   $4FB0
4f51: 86 12           LDA    #$12
4f53: e6 66           LDB    $6,S
4f55: 17 2e 37        LBSR   $7D8F
4f58: e7 64           STB    $4,S
4f5a: c6 0c           LDB    #$0C
4f5c: e0 64           SUBB   $4,S
4f5e: e7 67           STB    $7,S
4f60: 16 00 4d        LBRA   $4FB0
4f63: 86 0f           LDA    #$0F
4f65: e6 66           LDB    $6,S
4f67: 17 2e 25        LBSR   $7D8F
4f6a: e7 64           STB    $4,S
4f6c: c6 0b           LDB    #$0B
4f6e: e0 64           SUBB   $4,S
4f70: e7 67           STB    $7,S
4f72: 16 00 3b        LBRA   $4FB0
4f75: 86 12           LDA    #$12
4f77: e6 66           LDB    $6,S
4f79: 17 2e 13        LBSR   $7D8F
4f7c: e7 64           STB    $4,S
4f7e: c6 0b           LDB    #$0B
4f80: e0 64           SUBB   $4,S
4f82: e7 67           STB    $7,S
4f84: 16 00 29        LBRA   $4FB0
4f87: 8c 00 0b        CMPX   #$000B
4f8a: 2e e9           BGT    $4F75
4f8c: 1f 10           TFR    X,D
4f8e: 83 00 01        SUBD   #$0001
4f91: 2d e2           BLT    $4F75
4f93: 8e cf 9a        LDX    #$CF9A
4f96: 58              ASLB
4f97: 49              ROLA
4f98: 6e 9b           JMP    [D,X]
4f9a: cf 09 cf        XSTU   #$09CF
4f9d: 51              NEGB
4f9e: cf 51 cf        XSTU   #$51CF
4fa1: 63 cf           COM    ,W++
4fa3: 1b              NOP
4fa4: cf 2d cf        XSTU   #$2DCF
4fa7: 3f              SWI
4fa8: cf 75 ce        XSTU   #$75CE
4fab: e5 ce           BITB   W,U
4fad: f7 cf 51        STB    $CF51
4fb0: e6 65           LDB    $5,S
4fb2: e7 66           STB    $6,S
4fb4: c6 08           LDB    #$08
4fb6: e0 65           SUBB   $5,S
4fb8: e7 63           STB    $3,S
4fba: e6 66           LDB    $6,S
4fbc: c1 00           CMPB   #$00
4fbe: 10 23 00 25     LBLS   $4FE7
4fc2: 30 68           LEAX   $8,S
4fc4: e6 64           LDB    $4,S
4fc6: 3a              ABX
4fc7: ce 23 9a        LDU    #$239A
4fca: e6 63           LDB    $3,S
4fcc: 4f              CLRA
4fcd: 33 cb           LEAU   D,U
4fcf: e6 c4           LDB    ,U
4fd1: e7 84           STB    ,X
4fd3: e6 66           LDB    $6,S
4fd5: c0 01           SUBB   #$01
4fd7: e7 66           STB    $6,S
4fd9: e6 64           LDB    $4,S
4fdb: cb 01           ADDB   #$01
4fdd: e7 64           STB    $4,S
4fdf: e6 63           LDB    $3,S
4fe1: cb 01           ADDB   #$01
4fe3: e7 63           STB    $3,S
4fe5: 20 d3           BRA    $4FBA
4fe7: e6 e9 00 26     LDB    $0026,S
4feb: e7 63           STB    $3,S
4fed: 6f 64           CLR    $4,S
4fef: e6 64           LDB    $4,S
4ff1: c1 08           CMPB   #$08
4ff3: 10 24 00 1f     LBCC   $5016
4ff7: 8e 24 14        LDX    #$2414
4ffa: e6 64           LDB    $4,S
4ffc: 3a              ABX
4ffd: 33 68           LEAU   $8,S
4fff: e6 63           LDB    $3,S
5001: 4f              CLRA
5002: 33 cb           LEAU   D,U
5004: e6 c4           LDB    ,U
5006: e7 84           STB    ,X
5008: e6 64           LDB    $4,S
500a: cb 01           ADDB   #$01
500c: e7 64           STB    $4,S
500e: e6 63           LDB    $3,S
5010: cb 01           ADDB   #$01
5012: e7 63           STB    $3,S
5014: 20 d9           BRA    $4FEF
5016: e6 67           LDB    $7,S
5018: e7 e8 1e        STB    $1E,S
501b: e6 e8 1e        LDB    $1E,S
501e: 32 e8 1f        LEAS   $1F,S
5021: 39              RTS
; Binary parameter to formatted display string — $5022.
; Converts a binary parameter value (8 bytes at $0017,S) into a formatted decimal display
; string. Copies the raw value into a local buffer, converts to hex ASCII via $4CFF, then
; strips leading spaces and detects a '1' prefix to compute a format index (0-18). Dispatches
; through the 19-entry jump table at $D124 (shared with $4DE1) to set field width ($F,S),
; integer digit count ($D,S), and decimal digit count ($E,S). Calls $4D50 for decimal point
; insertion and formatting. Used to display stored parameter values rather than active entry.
5022: fc d2 ff        LDD    $D2FF
5025: 17 2d 28        LBSR   $7D50
5028: 33 62           LEAU   $2,S
502a: 10 ae e9 00 17  LDY    $0017,S
502f: c6 08           LDB    #$08
5031: 1d              SEX
5032: 1f 01           TFR    D,X
5034: cc 00 06        LDD    #$0006
5037: 34 76           PSHS   U,Y,X,D
5039: 17 f2 49        LBSR   $4285
503c: 32 68           LEAS   $8,S
503e: 33 62           LEAU   $2,S
5040: c6 08           LDB    #$08
5042: 1d              SEX
5043: 1f 02           TFR    D,Y
5045: 8e 00 04        LDX    #$0004
5048: 34 70           PSHS   U,Y,X
504a: 17 fc b2        LBSR   $4CFF
504d: 32 66           LEAS   $6,S
504f: c6 30           LDB    #$30
5051: e7 6a           STB    $A,S
5053: c6 30           LDB    #$30
5055: e7 6b           STB    $B,S
5057: 6f 6c           CLR    $C,S
5059: e6 6c           LDB    $C,S
505b: c1 0a           CMPB   #$0A
505d: 10 24 00 10     LBCC   $5071
5061: 30 62           LEAX   $2,S
5063: e6 6c           LDB    $C,S
5065: 3a              ABX
5066: e6 84           LDB    ,X
5068: c1 20           CMPB   #$20
506a: 10 26 00 03     LBNE   $5071
506e: 16 00 03        LBRA   $5074
5071: 16 00 08        LBRA   $507C
5074: e6 6c           LDB    $C,S
5076: cb 01           ADDB   #$01
5078: e7 6c           STB    $C,S
507a: 20 dd           BRA    $5059
507c: 30 62           LEAX   $2,S
507e: e6 6c           LDB    $C,S
5080: 3a              ABX
5081: e6 84           LDB    ,X
5083: c1 31           CMPB   #$31
5085: 10 26 00 06     LBNE   $508F
5089: e6 6c           LDB    $C,S
508b: cb 0a           ADDB   #$0A
508d: e7 6c           STB    $C,S
508f: e6 6c           LDB    $C,S
5091: 16 00 7c        LBRA   $5110
5094: cc 00 05        LDD    #$0005
5097: ed 6f           STD    $F,S
5099: c6 02           LDB    #$02
509b: e7 6d           STB    $D,S
509d: 6f 6e           CLR    $E,S
509f: 16 00 a8        LBRA   $514A
50a2: cc 00 05        LDD    #$0005
50a5: ed 6f           STD    $F,S
50a7: c6 01           LDB    #$01
50a9: e7 6d           STB    $D,S
50ab: c6 01           LDB    #$01
50ad: e7 6e           STB    $E,S
50af: 16 00 98        LBRA   $514A
50b2: cc 00 06        LDD    #$0006
50b5: ed 6f           STD    $F,S
50b7: c6 05           LDB    #$05
50b9: e7 6d           STB    $D,S
50bb: 6f 6e           CLR    $E,S
50bd: 16 00 8a        LBRA   $514A
50c0: cc 00 06        LDD    #$0006
50c3: ed 6f           STD    $F,S
50c5: c6 03           LDB    #$03
50c7: e7 6d           STB    $D,S
50c9: c6 02           LDB    #$02
50cb: e7 6e           STB    $E,S
50cd: 16 00 7a        LBRA   $514A
50d0: cc 00 06        LDD    #$0006
50d3: ed 6f           STD    $F,S
50d5: c6 02           LDB    #$02
50d7: e7 6d           STB    $D,S
50d9: c6 03           LDB    #$03
50db: e7 6e           STB    $E,S
50dd: 16 00 6a        LBRA   $514A
50e0: cc 00 06        LDD    #$0006
50e3: ed 6f           STD    $F,S
50e5: c6 01           LDB    #$01
50e7: e7 6d           STB    $D,S
50e9: c6 04           LDB    #$04
50eb: e7 6e           STB    $E,S
50ed: 16 00 5a        LBRA   $514A
50f0: cc 00 07        LDD    #$0007
50f3: ed 6f           STD    $F,S
50f5: c6 05           LDB    #$05
50f7: e7 6d           STB    $D,S
50f9: c6 03           LDB    #$03
50fb: e7 6e           STB    $E,S
50fd: 16 00 4a        LBRA   $514A
5100: cc 00 07        LDD    #$0007
5103: ed 6f           STD    $F,S
5105: c6 05           LDB    #$05
5107: e7 6d           STB    $D,S
5109: c6 04           LDB    #$04
510b: e7 6e           STB    $E,S
510d: 16 00 3a        LBRA   $514A
5110: c1 00           CMPB   #$00
5112: 10 25 00 34     LBCS   $514A
5116: c1 12           CMPB   #$12
5118: 10 22 00 2e     LBHI   $514A
511c: 8e d1 24        LDX    #$D124
511f: 4f              CLRA
5120: 58              ASLB
5121: 49              ROLA
5122: 6e 9b           JMP    [D,X]
5124: d0 94           SUBB   <$94
5126: d0 94           SUBB   <$94
5128: d0 b2           SUBB   <$B2
512a: d0 c0           SUBB   <$C0
512c: d0 d0           SUBB   <$D0
512e: d0 f0           SUBB   <$F0
5130: d0 f0           SUBB   <$F0
5132: d0 f0           SUBB   <$F0
5134: d1 00           CMPB   <$00
5136: d1 4a           CMPB   <$4A
5138: d0 94           SUBB   <$94
513a: d0 a2           SUBB   <$A2
513c: d0 c0           SUBB   <$C0
513e: d0 d0           SUBB   <$D0
5140: d0 e0           SUBB   <$E0
5142: d0 f0           SUBB   <$F0
5144: d0 f0           SUBB   <$F0
5146: d0 f0           SUBB   <$F0
5148: d1 00           CMPB   <$00
514a: 30 62           LEAX   $2,S
514c: e6 6e           LDB    $E,S
514e: 3a              ABX
514f: 5f              CLRB
5150: 1d              SEX
5151: 1f 03           TFR    D,U
5153: e6 6d           LDB    $D,S
5155: 4f              CLRA
5156: 1f 02           TFR    D,Y
5158: c6 05           LDB    #$05
515a: 1d              SEX
515b: af e8 11        STX    $11,S
515e: 1f 01           TFR    D,X
5160: ec e9 00 17     LDD    $0017,S
5164: 34 76           PSHS   U,Y,X,D
5166: ee e8 19        LDU    $19,S
5169: 10 8e 00 0a     LDY    #$000A
516d: 34 60           PSHS   U,Y
516f: 17 fb de        LBSR   $4D50
5172: 32 6c           LEAS   $C,S
5174: ec 6f           LDD    $F,S
5176: ed e8 11        STD    $11,S
5179: 32 e8 13        LEAS   $13,S
517c: 39              RTS
; Binary parameter to formatted display string (alternate scale) — $517D.
; Variant of $5022 for parameters using a different numeric scale. Copies 8 bytes from $0018,S
; to local buffer, converts to hex via $4CFF at offset 7, strips leading spaces and detects
; prefix digit. Uses a comparison-based dispatch (CMP chain) instead of jump table to select
; format parameters, with a $0001 base multiplier rather than the $0005/$0006/$0007 used by
; $5022. Tentatively for parameters with finer resolution or different unit scaling.
517d: fc d3 01        LDD    $D301
5180: 17 2b cd        LBSR   $7D50
5183: 33 63           LEAU   $3,S
5185: 10 ae e9 00 18  LDY    $0018,S
518a: c6 08           LDB    #$08
518c: 1d              SEX
518d: 1f 01           TFR    D,X
518f: cc 00 06        LDD    #$0006
5192: 34 76           PSHS   U,Y,X,D
5194: 17 f0 ee        LBSR   $4285
5197: 32 68           LEAS   $8,S
5199: c6 30           LDB    #$30
519b: e7 62           STB    $2,S
519d: 33 62           LEAU   $2,S
519f: c6 07           LDB    #$07
51a1: 1d              SEX
51a2: 1f 02           TFR    D,Y
51a4: 8e 00 04        LDX    #$0004
51a7: 34 70           PSHS   U,Y,X
51a9: 17 fb 53        LBSR   $4CFF
51ac: 32 66           LEAS   $6,S
51ae: c6 30           LDB    #$30
51b0: e7 6b           STB    $B,S
51b2: c6 30           LDB    #$30
51b4: e7 6c           STB    $C,S
51b6: 6f 6d           CLR    $D,S
51b8: e6 6d           LDB    $D,S
51ba: c1 0a           CMPB   #$0A
51bc: 10 24 00 10     LBCC   $51D0
51c0: 30 62           LEAX   $2,S
51c2: e6 6d           LDB    $D,S
51c4: 3a              ABX
51c5: e6 84           LDB    ,X
51c7: c1 20           CMPB   #$20
51c9: 10 26 00 03     LBNE   $51D0
51cd: 16 00 03        LBRA   $51D3
51d0: 16 00 08        LBRA   $51DB
51d3: e6 6d           LDB    $D,S
51d5: cb 01           ADDB   #$01
51d7: e7 6d           STB    $D,S
51d9: 20 dd           BRA    $51B8
51db: 30 62           LEAX   $2,S
51dd: e6 6d           LDB    $D,S
51df: 3a              ABX
51e0: e6 84           LDB    ,X
51e2: c1 31           CMPB   #$31
51e4: 10 26 00 06     LBNE   $51EE
51e8: e6 6d           LDB    $D,S
51ea: cb 0a           ADDB   #$0A
51ec: e7 6d           STB    $D,S
51ee: e6 6d           LDB    $D,S
51f0: 16 00 64        LBRA   $5257
51f3: cc 00 01        LDD    #$0001
51f6: ed e8 10        STD    $10,S
51f9: c6 05           LDB    #$05
51fb: e7 6e           STB    $E,S
51fd: 6f 6f           CLR    $F,S
51ff: 16 00 73        LBRA   $5275
5202: cc 00 01        LDD    #$0001
5205: ed e8 10        STD    $10,S
5208: c6 03           LDB    #$03
520a: e7 6e           STB    $E,S
520c: c6 02           LDB    #$02
520e: e7 6f           STB    $F,S
5210: 16 00 62        LBRA   $5275
5213: cc 00 01        LDD    #$0001
5216: ed e8 10        STD    $10,S
5219: c6 02           LDB    #$02
521b: e7 6e           STB    $E,S
521d: c6 03           LDB    #$03
521f: e7 6f           STB    $F,S
5221: 16 00 51        LBRA   $5275
5224: cc 00 01        LDD    #$0001
5227: ed e8 10        STD    $10,S
522a: c6 01           LDB    #$01
522c: e7 6e           STB    $E,S
522e: c6 04           LDB    #$04
5230: e7 6f           STB    $F,S
5232: 16 00 40        LBRA   $5275
5235: cc 00 02        LDD    #$0002
5238: ed e8 10        STD    $10,S
523b: c6 05           LDB    #$05
523d: e7 6e           STB    $E,S
523f: c6 03           LDB    #$03
5241: e7 6f           STB    $F,S
5243: 16 00 2f        LBRA   $5275
5246: cc 00 02        LDD    #$0002
5249: ed e8 10        STD    $10,S
524c: c6 03           LDB    #$03
524e: e7 6e           STB    $E,S
5250: c6 05           LDB    #$05
5252: e7 6f           STB    $F,S
5254: 16 00 1e        LBRA   $5275
5257: c1 02           CMPB   #$02
5259: 27 98           BEQ    $51F3
525b: c1 03           CMPB   #$03
525d: 27 a3           BEQ    $5202
525f: c1 04           CMPB   #$04
5261: 27 b0           BEQ    $5213
5263: c1 05           CMPB   #$05
5265: 27 ce           BEQ    $5235
5267: c1 0c           CMPB   #$0C
5269: 27 97           BEQ    $5202
526b: c1 0d           CMPB   #$0D
526d: 27 a4           BEQ    $5213
526f: c1 0e           CMPB   #$0E
5271: 27 b1           BEQ    $5224
5273: 20 d1           BRA    $5246
5275: 30 62           LEAX   $2,S
5277: e6 6f           LDB    $F,S
5279: 3a              ABX
527a: 5f              CLRB
527b: 1d              SEX
527c: 1f 03           TFR    D,U
527e: e6 6e           LDB    $E,S
5280: 4f              CLRA
5281: 1f 02           TFR    D,Y
5283: c6 05           LDB    #$05
5285: 1d              SEX
5286: af e8 12        STX    $12,S
5289: 1f 01           TFR    D,X
528b: ec e9 00 18     LDD    $0018,S
528f: 34 76           PSHS   U,Y,X,D
5291: ee e8 1a        LDU    $1A,S
5294: 10 8e 00 0a     LDY    #$000A
5298: 34 60           PSHS   U,Y
529a: 17 fa b3        LBSR   $4D50
529d: 32 6c           LEAS   $C,S
529f: ec e8 10        LDD    $10,S
52a2: ed e8 12        STD    $12,S
52a5: 32 e8 14        LEAS   $14,S
52a8: 39              RTS
; Fixed-point multiply by ROM constant at $92AD — $52A9.
; Multiplies the caller's 16-bit argument by the 16-bit value at $92AD (→$12AD in ROM)
; using $5303 (16×16 unsigned multiply). Returns the upper 16 bits of the 32-bit product.
52a9: fc d2 f9        LDD    $D2F9
52ac: 17 2a a1        LBSR   $7D50
52af: ce 92 ad        LDU    #$92AD
52b2: 10 ae e9 00 08  LDY    $0008,S
52b7: 8e 00 04        LDX    #$0004
52ba: 34 70           PSHS   U,Y,X
52bc: 17 00 44        LBSR   $5303
52bf: 32 66           LEAS   $6,S
52c1: ed 62           STD    $2,S
52c3: 32 64           LEAS   $4,S
52c5: 39              RTS
; Fixed-point multiply by ROM constant at $BECE, then add — $52C6.
; Multiplies the caller's argument by $BECE, adds the original argument to the product,
; and returns the sum. Likely computes value * (1 + K) for a scaling correction.
52c6: fc d2 f9        LDD    $D2F9
52c9: 17 2a 84        LBSR   $7D50
52cc: ce be ce        LDU    #$BECE
52cf: 10 ae e9 00 08  LDY    $0008,S
52d4: 8e 00 04        LDX    #$0004
52d7: 34 70           PSHS   U,Y,X
52d9: 17 00 27        LBSR   $5303
52dc: 32 66           LEAS   $6,S
52de: e3 e9 00 08     ADDD   $0008,S
52e2: ed 62           STD    $2,S
52e4: 32 64           LEAS   $4,S
52e6: 39              RTS
52e7: 00 05           NEG    <$05
52e9: 00 03           NEG    <$03
52eb: 00 08           NEG    <$08
52ed: 00 04           NEG    <$04
52ef: 00 01           NEG    <$01
52f1: 00 00           NEG    <$00
52f3: 00 03           NEG    <$03
52f5: 00 07           NEG    <$07
52f7: 00 06           NEG    <$06
52f9: 00 02           NEG    <$02
52fb: 00 0c           NEG    <$0C
52fd: 00 1d           NEG    <$1D
52ff: 00 11           NEG    <$11
5301: 00 12           NEG    <$12
; 16×16 unsigned multiply with rounding — $5303.
; Multiplies two 16-bit unsigned values using shift-and-add (16 iterations). The
; multiplicand is at $11,S, the multiplier is passed in U. Produces a 32-bit result;
; returns the upper 16 bits in D, rounded up if bit 15 of the lower half is set.
5303: cc 00 0b        LDD    #$000B
5306: 17 2a 47        LBSR   $7D50
5309: cc 00 00        LDD    #$0000
530c: ed 62           STD    $2,S
530e: ed 64           STD    $4,S
5310: ed 68           STD    $8,S
5312: ec e8 11        LDD    $11,S
5315: ed 66           STD    $6,S
5317: 86 10           LDA    #$10
5319: a7 6a           STA    $A,S
531b: 64 66           LSR    $6,S
531d: 66 67           ROR    $7,S
531f: 66 68           ROR    $8,S
5321: 66 69           ROR    $9,S
5323: 68 e8 14        ASL    $14,S
5326: 69 e8 13        ROL    $13,S
5329: 24 0e           BCC    $5339
532b: ec 64           LDD    $4,S
532d: e3 68           ADDD   $8,S
532f: ed 64           STD    $4,S
5331: ec 62           LDD    $2,S
5333: e9 67           ADCB   $7,S
5335: a9 66           ADCA   $6,S
5337: ed 62           STD    $2,S
5339: 6a 6a           DEC    $A,S
533b: 26 de           BNE    $531B
533d: ec 62           LDD    $2,S
533f: 6d 64           TST    $4,S
5341: 2a 03           BPL    $5346
5343: c3 00 01        ADDD   #$0001
5346: ed 6b           STD    $B,S
5348: 32 6d           LEAS   $D,S
534a: 39              RTS
; Packed fixed-point normalize and store — $534B.
; Reads a 3-byte packed value (1 byte exponent + 2 byte mantissa) from [$0D,S].
; Right-shifts the mantissa until it fits in 11 bits (exponent ≤ $0F), decrementing
; the shift count each time. Stores the normalized 2-byte mantissa at the indirect
; destination and returns the final shift count in B.
534b: cc 00 05        LDD    #$0005
534e: 17 29 ff        LBSR   $7D50
5351: ae 6d           LDX    $D,S
5353: e6 84           LDB    ,X
5355: e7 63           STB    $3,S
5357: ae 01           LDX    $1,X
5359: af 64           STX    $4,S
535b: c6 0b           LDB    #$0B
535d: e7 62           STB    $2,S
535f: cc 00 0f        LDD    #$000F
5362: 10 a3 63        CMPD   $3,S
5365: 24 0a           BCC    $5371
5367: 64 63           LSR    $3,S
5369: 66 64           ROR    $4,S
536b: 66 65           ROR    $5,S
536d: 6a 62           DEC    $2,S
536f: 26 f1           BNE    $5362
5371: ec 64           LDD    $4,S
5373: ed f8 0b        STD    [$0B,S]
5376: e6 62           LDB    $2,S
5378: e7 66           STB    $6,S
537a: 32 67           LEAS   $7,S
537c: 39              RTS
; 3-byte packed data copy — $537D.
; Copies a 3-byte packed value (byte + word) from the source pointer to the destination.
; Used to transfer packed fixed-point channel parameters between buffers.
537d: cc 00 00        LDD    #$0000
5380: 17 29 cd        LBSR   $7D50
5383: ae 66           LDX    $6,S
5385: ee 68           LDU    $8,S
5387: e6 c0           LDB    ,U+
5389: e7 80           STB    ,X+
538b: ec c4           LDD    ,U
538d: ed 84           STD    ,X
538f: 32 62           LEAS   $2,S
5391: 39              RTS
; 3-byte packed data addition — $5392.
; Adds two 3-byte packed values (byte + word) pointed to by X and U. The 2-byte low
; portions are added first with carry propagating to the high byte. Result is stored
; back and the overflow/carry status determines further normalization via $534B.
5392: cc 00 05        LDD    #$0005
5395: 17 29 b8        LBSR   $7D50
5398: ae 6b           LDX    $B,S
539a: ee 6d           LDU    $D,S
539c: ec 01           LDD    $1,X
539e: e3 41           ADDD   $1,U
53a0: ed 64           STD    $4,S
53a2: e6 84           LDB    ,X
53a4: e9 c4           ADCB   ,U
53a6: e7 63           STB    $3,S
53a8: c6 00           LDB    #$00
53aa: 24 02           BCC    $53AE
53ac: c6 ff           LDB    #$FF
53ae: e7 62           STB    $2,S
53b0: 33 63           LEAU   $3,S
53b2: 10 ae 6f        LDY    $F,S
53b5: 8e 00 04        LDX    #$0004
53b8: 34 70           PSHS   U,Y,X
53ba: 17 ff c0        LBSR   $537D
53bd: 32 66           LEAS   $6,S
53bf: e6 62           LDB    $2,S
53c1: e7 66           STB    $6,S
53c3: 32 67           LEAS   $7,S
53c5: 39              RTS
; 3-byte packed data subtraction — $53C6.
; Subtracts two 3-byte packed values: result = [U] - [Y], stored at [X]. Returns B=$FF
; if the subtraction underflowed (borrow from high byte), B=$00 otherwise.
53c6: cc 00 02        LDD    #$0002
53c9: 17 29 84        LBSR   $7D50
53cc: ae 6c           LDX    $C,S
53ce: ee 68           LDU    $8,S
53d0: 10 ae 6a        LDY    $A,S
53d3: ec 41           LDD    $1,U
53d5: a3 21           SUBD   $1,Y
53d7: ed 01           STD    $1,X
53d9: e6 c4           LDB    ,U
53db: e2 a4           SBCB   ,Y
53dd: e7 84           STB    ,X
53df: c6 00           LDB    #$00
53e1: 24 02           BCC    $53E5
53e3: c6 ff           LDB    #$FF
53e5: e7 62           STB    $2,S
53e7: e7 63           STB    $3,S
53e9: 32 64           LEAS   $4,S
53eb: 39              RTS
; Packed fixed-point denormalize and compare — $53EC.
; Reads a 3-byte packed value from [$16,S], left-shifts the mantissa until it reaches
; a maximum exponent ($0F) or exceeds the ROM limit at $EE47-$EE49. Then performs
; element-wise comparison/subtraction with another packed value and returns the delta.
53ec: cc 00 0e        LDD    #$000E
53ef: 17 29 5e        LBSR   $7D50
53f2: ee e8 16        LDU    $16,S
53f5: e6 c0           LDB    ,U+
53f7: e7 68           STB    $8,S
53f9: ec c4           LDD    ,U
53fb: ed 69           STD    $9,S
53fd: 6f 62           CLR    $2,S
53ff: e6 62           LDB    $2,S
5401: c1 0f           CMPB   #$0F
5403: 24 1f           BCC    $5424
5405: ec 68           LDD    $8,S
5407: 10 b3 ee 47     CMPD   $EE47
540b: 22 17           BHI    $5424
540d: 26 07           BNE    $5416
540f: e6 6a           LDB    $A,S
5411: f1 ee 49        CMPB   $EE49
5414: 24 0e           BCC    $5424
5416: 68 6a           ASL    $A,S
5418: 69 69           ROL    $9,S
541a: 69 68           ROL    $8,S
541c: e6 62           LDB    $2,S
541e: cb 01           ADDB   #$01
5420: e7 62           STB    $2,S
5422: 20 db           BRA    $53FF
5424: 6f 63           CLR    $3,S
5426: 5f              CLRB
5427: 4f              CLRA
5428: ed 64           STD    $4,S
542a: e6 63           LDB    $3,S
542c: c1 0d           CMPB   #$0D
542e: 24 31           BCC    $5461
5430: 68 65           ASL    $5,S
5432: 69 64           ROL    $4,S
5434: ec 69           LDD    $9,S
5436: b3 ee 48        SUBD   $EE48
5439: ed 6c           STD    $C,S
543b: e6 68           LDB    $8,S
543d: f2 ee 47        SBCB   $EE47
5440: e7 6b           STB    $B,S
5442: 25 0f           BCS    $5453
5444: e6 6b           LDB    $B,S
5446: e7 68           STB    $8,S
5448: ec 6c           LDD    $C,S
544a: ed 69           STD    $9,S
544c: ec 64           LDD    $4,S
544e: c3 00 01        ADDD   #$0001
5451: ed 64           STD    $4,S
5453: 68 6a           ASL    $A,S
5455: 69 69           ROL    $9,S
5457: 69 68           ROL    $8,S
5459: e6 63           LDB    $3,S
545b: cb 01           ADDB   #$01
545d: e7 63           STB    $3,S
545f: 20 c9           BRA    $542A
5461: 8e 24 f5        LDX    #$24F5
5464: e6 e8 15        LDB    $15,S
5467: 4f              CLRA
5468: 5d              TSTB
5469: 27 06           BEQ    $5471
546b: bb 22 00        ADDA   $2200
546e: 5a              DECB
546f: 20 f7           BRA    $5468
5471: 30 86           LEAX   A,X
5473: 30 88 1f        LEAX   $1F,X
5476: ae 84           LDX    ,X
5478: af 66           STX    $6,S
547a: 8c 00 04        CMPX   #$0004
547d: 27 0d           BEQ    $548C
547f: e6 65           LDB    $5,S
5481: c4 01           ANDB   #$01
5483: 27 07           BEQ    $548C
5485: ec 64           LDD    $4,S
5487: c3 00 02        ADDD   #$0002
548a: ed 64           STD    $4,S
548c: 64 64           LSR    $4,S
548e: 66 65           ROR    $5,S
5490: ae 64           LDX    $4,S
5492: 8c 0f ff        CMPX   #$0FFF
5495: 2f 05           BLE    $549C
5497: cc 0f ff        LDD    #$0FFF
549a: ed 64           STD    $4,S
549c: ae 66           LDX    $6,S
549e: 8c 00 04        CMPX   #$0004
54a1: 26 59           BNE    $54FC
54a3: 64 64           LSR    $4,S
54a5: 66 65           ROR    $5,S
54a7: e6 e8 15        LDB    $15,S
54aa: 26 20           BNE    $54CC
54ac: fc 22 02        LDD    $2202
54af: c4 40           ANDB   #$40
54b1: 27 19           BEQ    $54CC
54b3: 8e 25 81        LDX    #$2581
54b6: b6 24 f4        LDA    $24F4
54b9: 5f              CLRB
54ba: 4d              TSTA
54bb: 27 06           BEQ    $54C3
54bd: fb 22 01        ADDB   $2201
54c0: 4a              DECA
54c1: 20 f7           BRA    $54BA
54c3: 3a              ABX
54c4: 30 0a           LEAX   $A,X
54c6: e6 84           LDB    ,X
54c8: e7 6e           STB    $E,S
54ca: 20 19           BRA    $54E5
54cc: 8e 24 f5        LDX    #$24F5
54cf: e6 e8 15        LDB    $15,S
54d2: 4f              CLRA
54d3: 5d              TSTB
54d4: 27 06           BEQ    $54DC
54d6: bb 22 00        ADDA   $2200
54d9: 5a              DECB
54da: 20 f7           BRA    $54D3
54dc: 30 86           LEAX   A,X
54de: 30 88 14        LEAX   $14,X
54e1: e6 84           LDB    ,X
54e3: e7 6e           STB    $E,S
54e5: e6 6e           LDB    $E,S
54e7: c1 2d           CMPB   #$2D
54e9: 10 27 00 07     LBEQ   $54F4
54ed: cc 10 00        LDD    #$1000
54f0: a3 64           SUBD   $4,S
54f2: ed 64           STD    $4,S
54f4: ec 64           LDD    $4,S
54f6: 84 0f           ANDA   #$0F
54f8: c4 ff           ANDB   #$FF
54fa: ed 64           STD    $4,S
54fc: ae 66           LDX    $6,S
54fe: 8c 00 05        CMPX   #$0005
5501: 10 26 00 12     LBNE   $5517
5505: ce b6 c9        LDU    #$B6C9
5508: 10 ae 64        LDY    $4,S
550b: 8e 00 04        LDX    #$0004
550e: 34 70           PSHS   U,Y,X
5510: 17 fd f0        LBSR   $5303
5513: 32 66           LEAS   $6,S
5515: ed 64           STD    $4,S
5517: ec 64           LDD    $4,S
5519: ed f8 18        STD    [$18,S]
551c: e6 62           LDB    $2,S
551e: e7 6f           STB    $F,S
5520: 32 e8 10        LEAS   $10,S
5523: 39              RTS
; Keypad and column port shutdown — $5524.
; Calls $1A37(0), clears $0600 control register, clears column output shadow $241F and port
; $0A00, then reads and returns the raw keypad input byte from $0000.
5524: fc dc 34        LDD    $DC34
5527: 17 28 26        LBSR   $7D50
552a: ce 00 00        LDU    #$0000
552d: 34 40           PSHS   U
552f: 17 c5 05        LBSR   $1A37
5532: 32 62           LEAS   $2,S
5534: 7f 06 00        CLR    $0600
5537: 7f 24 1f        CLR    $241F
553a: 7f 0a 00        CLR    $0A00
553d: f6 00 00        LDB    >$0000
5540: e7 62           STB    $2,S
5542: 32 63           LEAS   $3,S
5544: 39              RTS
; Read keypad input with settle delay — $5545.
; Sets the column output port $0A00 to idle state (bit 7 preserved + bit 6 set), delays 10
; iterations via $5670 for electrical settling, then reads the raw keypad input from port $0000.
; Returns the raw input byte in B. Used for debounced single-shot key reads.
5545: fc dc 34        LDD    $DC34
5548: 17 28 05        LBSR   $7D50       ; allocate frame
; Set column output to idle
554b: f6 24 1f        LDB    $241F       ; column output shadow
554e: 4f              CLRA
554f: 84 00           ANDA   #$00
5551: c4 80           ANDB   #$80        ; preserve bit 7 only
5553: f7 24 1f        STB    $241F
5556: f6 24 1f        LDB    $241F
5559: ca 40           ORB    #$40        ; set bit 6 (idle pattern)
555b: f7 24 1f        STB    $241F
555e: f6 24 1f        LDB    $241F
5561: f7 0a 00        STB    $0A00       ; write idle to column port
; Delay for settle
5564: c6 0a           LDB    #$0A        ; 10 iterations
5566: 1d              SEX
5567: 1f 03           TFR    D,U
5569: 10 8e 00 02     LDY    #$0002
556d: 34 60           PSHS   U,Y
556f: 17 00 fe        LBSR   $5670       ; → calibrated delay
5572: 32 64           LEAS   $4,S
; Read settled input
5574: f6 00 00        LDB    >$0000      ; read keypad input port
5577: e7 62           STB    $2,S        ; return value
5579: 32 63           LEAS   $3,S
557b: 39              RTS
; Reset column output port — $557C.
; Clears all column drive bits in $0A00 to idle (bit 7 preserved, bits 6:0 cleared).
; Shorter version of $5545 without the delay or input read — just deactivates the column scan.
557c: fc dc 36        LDD    $DC36
557f: 17 27 ce        LBSR   $7D50       ; allocate frame
5582: f6 24 1f        LDB    $241F       ; column output shadow
5585: 4f              CLRA
5586: 84 00           ANDA   #$00
5588: c4 80           ANDB   #$80        ; preserve bit 7 only
558a: f7 24 1f        STB    $241F
558d: f6 24 1f        LDB    $241F
5590: f7 0a 00        STB    $0A00       ; write to column port (all columns inactive)
5593: 32 62           LEAS   $2,S
5595: 39              RTS
; MC6840 PTM timer initialization — $5596.
; Programs the PTM timer registers and their shadow copies. Sets timer 1 latch ($1002/$2424)
; and timer 2 latch ($1004/$2426) with specific countdown values. $00D2 = 210 decimal.
5596: fc dc 36        LDD    $DC36
5599: 17 27 b4        LBSR   $7D50       ; allocate frame
; Timer 1 latch: $00D2 (210 counts)
559c: cc 00 d2        LDD    #$00D2
559f: fd 24 24        STD    $2424       ; timer 1 shadow
55a2: cc 00 d2        LDD    #$00D2
55a5: fd 10 02        STD    $1002       ; PTM timer 1 latch register
; Timer 2 latch: $0000 (disabled)
55a8: 5f              CLRB
55a9: 4f              CLRA
55aa: fd 24 26        STD    $2426       ; timer 2 shadow
55ad: 5f              CLRB
55ae: 4f              CLRA
55af: fd 10 04        STD    $1004       ; PTM timer 2 latch register
; Timer 3 latch: $01D2 (466 counts)
55b2: cc 01 d2        LDD    #$01D2
55b5: fd 24 28        STD    $2428       ; timer 3 shadow
55b8: cc 01 d2        LDD    #$01D2
55bb: fd 10 06        STD    $1006       ; PTM timer 3 latch register
; Configure control registers
55be: c6 01           LDB    #$01        ; CR2: bit 0 set → select CR1 for next write
55c0: f7 10 01        STB    $1001
55c3: c6 01           LDB    #$01        ; CR1: bit 0 set (internal clock select)
55c5: f7 10 00        STB    $1000
55c8: c6 02           LDB    #$02        ; update CR1 shadow
55ca: f7 24 21        STB    $2421       ; CR1 shadow = $02 (continuous, IRQ disabled)
55cd: c6 02           LDB    #$02
55cf: f7 10 00        STB    $1000       ; write CR1
; CR2: clear (deselect CR1, timer 2 continuous)
55d2: 7f 24 22        CLR    $2422       ; CR2 shadow = $00
55d5: f6 24 22        LDB    $2422
55d8: f7 10 01        STB    $1001       ; write CR2
; CR3 shadow: $27 (bit 5 + bit 2 + bit 1 + bit 0: prescale + IRQ enable)
55db: c6 27           LDB    #$27
55dd: f7 24 23        STB    $2423       ; CR3 shadow
55e0: c6 27           LDB    #$27
55e2: f7 10 00        STB    $1000       ; write CR3
55e5: 7f 24 22        CLR    $2422       ; re-clear CR2 shadow
55e8: f6 24 22        LDB    $2422
55eb: f7 10 01        STB    $1001       ; write CR2 (ensure bit 0 clear)
55ee: 32 62           LEAS   $2,S        ; deallocate frame
55f0: 39              RTS
; MC6840 PTM timer output disable — $55F1.
; Disables all three PTM timer output pins by clearing bit 6 (output enable) in each control
; register shadow ($2421 CR1, $2423 CR3, $2422 CR2) and writing them to the hardware at
; $1000/$1001. Uses CR2 bit 0 to select CR1 for write access per MC6840 convention.
55f1: fc dc 36        LDD    $DC36
55f4: 17 27 59        LBSR   $7D50       ; allocate frame
; Select CR1 for write (set CR2 bit 0)
55f7: f6 24 22        LDB    $2422       ; CR2 shadow
55fa: ca 01           ORB    #$01        ; set bit 0 → next write targets CR1
55fc: f7 10 01        STB    $1001       ; write to PTM CR register
; Disable CR1 output (clear bit 6)
55ff: f6 24 21        LDB    $2421       ; CR1 shadow
5602: 4f              CLRA
5603: 84 00           ANDA   #$00
5605: c4 bf           ANDB   #$BF        ; clear bit 6 (timer 1 output disable)
5607: f7 24 21        STB    $2421       ; update shadow
560a: f6 24 21        LDB    $2421
560d: f7 10 00        STB    $1000       ; write to PTM CR1
; Deselect CR1 (clear CR2 bit 0)
5610: f6 24 22        LDB    $2422
5613: 4f              CLRA
5614: 84 00           ANDA   #$00
5616: c4 fe           ANDB   #$FE        ; clear bit 0 → next write targets CR2/3
5618: f7 10 01        STB    $1001
; Disable CR3 output (clear bit 6)
561b: f6 24 23        LDB    $2423       ; CR3 shadow
561e: 4f              CLRA
561f: 84 00           ANDA   #$00
5621: c4 bf           ANDB   #$BF        ; clear bit 6 (timer 3 output disable)
5623: f7 24 23        STB    $2423       ; update shadow
5626: f6 24 23        LDB    $2423
5629: f7 10 00        STB    $1000       ; write to PTM CR3 (via $1000 when bit 0=0)
; Disable CR2 output (clear bit 6)
562c: f6 24 22        LDB    $2422       ; CR2 shadow
562f: 4f              CLRA
5630: 84 00           ANDA   #$00
5632: c4 bf           ANDB   #$BF        ; clear bit 6 (timer 2 output disable)
5634: f7 24 22        STB    $2422       ; update shadow
5637: f6 24 22        LDB    $2422
563a: f7 10 01        STB    $1001       ; write to PTM CR2
563d: 32 62           LEAS   $2,S        ; deallocate frame
563f: 39              RTS
; PTM timer 3 one-shot delay — $5640.
; Programs PTM timer 3 latch ($1006) with (argument_high_byte + $00D2) and busy-waits for
; timer 3 flag (bit 2 of status register $1001) to assert. Used as the elemental delay
; primitive by $5670 (calibrated delay loop).
5640: fc dc 37        LDD    $DC37
5643: 17 27 0a        LBSR   $7D50       ; allocate frame
5646: ae e9 00 08     LDX    $0008,S     ; X = delay argument
564a: c6 08           LDB    #$08        ; shift right 8 (extract high byte)
564c: 17 29 55        LBSR   $7FA4       ; → right-shift X by B positions
564f: ed 62           STD    $2,S        ; D = high byte of argument
5651: ec 62           LDD    $2,S
5653: c3 00 d2        ADDD   #$00D2      ; add base delay offset $D2 (210)
5656: ed 62           STD    $2,S
5658: ec 62           LDD    $2,S
565a: fd 10 06        STD    $1006       ; write to PTM timer 3 latch
; Busy-wait for timer 3 interrupt flag
565d: f6 10 01        LDB    $1001       ; read PTM status register
5660: c4 04           ANDB   #$04        ; isolate bit 2 (timer 3 flag)
5662: 4f              CLRA
5663: 10 83 00 00     CMPD   #$0000
5667: 10 26 00 02     LBNE   $566D       ; flag set → timer expired
566b: 20 f0           BRA    $565D       ; not yet → poll again
566d: 32 64           LEAS   $4,S        ; deallocate frame
566f: 39              RTS
; Calibrated delay loop — $5670.
; Delays for approximately N iterations, where N is the 16-bit value on stack at $0007,S.
; Each iteration calls $5640 which programs a PTM timer interval and busy-waits for it to fire.
; When the remaining count > 255, subdivides into 255-iteration chunks (via $7FA4 right-shift
; to compute chunk count). Used by $5545 (key settle delay) and $56C8 (display stabilization).
5670: fc dc 34        LDD    $DC34
5673: 17 26 da        LBSR   $7D50       ; allocate frame
5676: ae e9 00 07     LDX    $0007,S     ; X = requested delay count
567a: 8c 00 00        CMPX   #$0000
567d: 10 23 00 44     LBLS   $56C5       ; count ≤ 0 → return immediately
; First iteration: delay with (count - 1) as argument
5681: ec e9 00 07     LDD    $0007,S
5685: 83 00 01        SUBD   #$0001      ; count--
5688: ed e9 00 07     STD    $0007,S
568c: e6 e9 00 08     LDB    $0008,S     ; low byte of remaining count
5690: 4f              CLRA
5691: 1f 03           TFR    D,U         ; U = iteration argument
5693: 10 8e 00 02     LDY    #$0002
5697: 34 60           PSHS   U,Y
5699: 8d a5           BSR    $5640       ; → PTM one-shot delay
569b: 32 64           LEAS   $4,S
; Compute number of 255-iteration chunks remaining
569d: ae e9 00 07     LDX    $0007,S     ; X = remaining count
56a1: c6 f8           LDB    #$F8        ; shift right by 8 (÷256)
56a3: 17 28 fe        LBSR   $7FA4       ; → chunk count
56a6: e7 62           STB    $2,S        ; save chunk count
; Loop: execute 255-iteration chunks
56a8: e6 62           LDB    $2,S        ; B = remaining chunks
56aa: c1 00           CMPB   #$00
56ac: 10 23 00 15     LBLS   $56C5       ; zero → done
56b0: ce 00 ff        LDU    #$00FF      ; U = 255 (full chunk)
56b3: 10 8e 00 02     LDY    #$0002
56b7: 34 60           PSHS   U,Y
56b9: 8d 85           BSR    $5640       ; → PTM one-shot delay
56bb: 32 64           LEAS   $4,S
56bd: e6 62           LDB    $2,S        ; chunks--
56bf: c0 01           SUBB   #$01
56c1: e7 62           STB    $2,S
56c3: 20 e3           BRA    $56A8       ; → loop
56c5: 32 63           LEAS   $3,S        ; deallocate frame
56c7: 39              RTS
; Display/UI state snapshot with PTM-based stabilization delay — $56C8.
; If $23C1 bit 2 is clear, enables PTM timer 1 output (bit 7 of CR1 shadow $2421), delays 100
; iterations via $5670 to let the display settle, then disables timer 1 output again.
; If $23C1 bit 2 is set, skips the delay entirely (fast mode / already stabilized).
; Called by $43FE as part of UI state save before parameter editing.
56c8: fc dc 36        LDD    $DC36
56cb: 17 26 82        LBSR   $7D50       ; allocate frame
56ce: fc 23 c1        LDD    $23C1
56d1: 84 00           ANDA   #$00
56d3: c4 04           ANDB   #$04        ; test bit 2
56d5: 10 83 00 00     CMPD   #$0000
56d9: 10 26 00 3d     LBNE   $571A       ; set → skip delay
; Enable PTM CR1 write access (set CR2 bit 0)
56dd: f6 24 22        LDB    $2422       ; CR2 shadow
56e0: ca 01           ORB    #$01        ; set bit 0 (enable CR1 write)
56e2: f7 24 22        STB    $2422
56e5: f6 24 22        LDB    $2422
56e8: f7 10 01        STB    $1001       ; write to PTM CR2
; Enable timer 1 output (set CR1 bit 7)
56eb: f6 24 21        LDB    $2421       ; CR1 shadow
56ee: 4f              CLRA
56ef: 8a 00           ORA    #$00
56f1: ca 80           ORB    #$80        ; set bit 7 (timer 1 output enable)
56f3: f7 24 21        STB    $2421
56f6: f6 24 21        LDB    $2421
56f9: f7 10 00        STB    $1000       ; write to PTM CR1
; Delay 100 iterations for display stabilization
56fc: c6 64           LDB    #$64        ; 100 iterations
56fe: 1d              SEX
56ff: 1f 03           TFR    D,U
5701: 10 8e 00 02     LDY    #$0002
5705: 34 60           PSHS   U,Y
5707: 17 ff 66        LBSR   $5670       ; → calibrated delay
570a: 32 64           LEAS   $4,S
; Disable timer 1 output (clear CR1 bit 7)
570c: f6 24 21        LDB    $2421
570f: c4 7f           ANDB   #$7F        ; clear bit 7
5711: f7 24 21        STB    $2421
5714: f6 24 21        LDB    $2421
5717: f7 10 00        STB    $1000       ; write to PTM CR1
571a: 32 62           LEAS   $2,S
571c: 39              RTS
; LCD command write with busy-wait — $571D.
; Busy-waits on $0300 bit 7 (HD44780 busy flag) until clear, then writes the argument byte
; to $0300 (LCD instruction register, RS=0). Used for all LCD commands: initialization ($38,
; $0C, $01), cursor positioning (via $57A0), and display control updates.
571d: fc dc 36        LDD    $DC36
5720: 17 26 2d        LBSR   $7D50
5723: f6 03 00        LDB    $0300
5726: 4f              CLRA
5727: 84 00           ANDA   #$00
5729: c4 80           ANDB   #$80
572b: 10 83 00 00     CMPD   #$0000
572f: 10 27 00 02     LBEQ   $5735
5733: 20 ee           BRA    $5723
5735: e6 e9 00 07     LDB    $0007,S
5739: f7 03 00        STB    $0300
573c: 32 62           LEAS   $2,S
573e: 39              RTS
; LCD data write with busy-wait — $573F.
; Busy-waits on $0300 bit 7 (HD44780 busy flag) until clear, then writes the argument byte
; to $0301 (LCD data register, RS=1). Used to write individual characters to the display
; at the current cursor position.
573f: fc dc 36        LDD    $DC36
5742: 17 26 0b        LBSR   $7D50
5745: f6 03 00        LDB    $0300
5748: 4f              CLRA
5749: 84 00           ANDA   #$00
574b: c4 80           ANDB   #$80
574d: 10 83 00 00     CMPD   #$0000
5751: 10 27 00 02     LBEQ   $5757
5755: 20 ee           BRA    $5745
5757: e6 e9 00 07     LDB    $0007,S
575b: f7 03 01        STB    $0301
575e: 32 62           LEAS   $2,S
5760: 39              RTS
; LCD data read with busy-wait — $5761.
; Busy-waits on $0300 bit 7 (HD44780 busy flag) until clear, then reads and returns the byte
; from $0301 (LCD data register, RS=1). Reads character data from the display at the current
; cursor position.
5761: fc dc 34        LDD    $DC34
5764: 17 25 e9        LBSR   $7D50
5767: f6 03 00        LDB    $0300
576a: 4f              CLRA
576b: 84 00           ANDA   #$00
576d: c4 80           ANDB   #$80
576f: 10 83 00 00     CMPD   #$0000
5773: 10 27 00 02     LBEQ   $5779
5777: 20 ee           BRA    $5767
5779: f6 03 01        LDB    $0301
577c: e7 62           STB    $2,S
577e: 32 63           LEAS   $3,S
5780: 39              RTS
; LCD address counter read with busy-wait — $5781.
; Busy-waits on $0300 bit 7 (HD44780 busy flag) until clear, then returns the full $0300
; value — bits 6:0 contain the current DDRAM/CGRAM address counter. Used to read the LCD's
; internal cursor position.
5781: fc dc 37        LDD    $DC37
5784: 17 25 c9        LBSR   $7D50
5787: f6 03 00        LDB    $0300
578a: e7 62           STB    $2,S
578c: e6 62           LDB    $2,S
578e: 4f              CLRA
578f: 84 00           ANDA   #$00
5791: c4 80           ANDB   #$80
5793: 10 83 00 00     CMPD   #$0000
5797: 26 ee           BNE    $5787
5799: e6 62           LDB    $2,S
579b: e7 63           STB    $3,S
579d: 32 64           LEAS   $4,S
579f: 39              RTS
; LCD set cursor position — $57A0.
; Sets the HD44780 DDRAM address (cursor position) by ORing bit 7 onto the argument (forming
; the "set DDRAM address" command $80|addr) and writing via $571D. Row 0 starts at address
; $00, row 1 at $40 on standard 2-line displays.
57a0: fc dc 36        LDD    $DC36
57a3: 17 25 aa        LBSR   $7D50
57a6: ec e9 00 06     LDD    $0006,S
57aa: 8a 00           ORA    #$00
57ac: ca 80           ORB    #$80
57ae: 1f 03           TFR    D,U
57b0: 10 8e 00 02     LDY    #$0002
57b4: 34 60           PSHS   U,Y
57b6: 17 ff 64        LBSR   $571D
57b9: 32 64           LEAS   $4,S
57bb: 32 62           LEAS   $2,S
57bd: 39              RTS
; LCD display control bit set/clear — $57BE.
; Modifies the HD44780 display control register shadow $242A based on argument index (0-5):
; 0=display on (set bit 2), 1=cursor on (set bit 1), 2=blink on (set bit 0),
; 3=display off (clear bit 2), 4=cursor off (clear bit 1), 5=blink off (clear bit 0).
; Writes the updated control byte to the LCD via $571D. Jump table at $D811.
57be: fc dc 37        LDD    $DC37
57c1: 17 25 8c        LBSR   $7D50
57c4: c6 ff           LDB    #$FF
57c6: e7 62           STB    $2,S
57c8: 6f 63           CLR    $3,S
57ca: ae e9 00 08     LDX    $0008,S
57ce: 16 00 2d        LBRA   $57FE
57d1: c6 04           LDB    #$04
57d3: e7 63           STB    $3,S
57d5: 16 00 45        LBRA   $581D
57d8: c6 02           LDB    #$02
57da: e7 63           STB    $3,S
57dc: 16 00 3e        LBRA   $581D
57df: c6 01           LDB    #$01
57e1: e7 63           STB    $3,S
57e3: 16 00 37        LBRA   $581D
57e6: c6 fb           LDB    #$FB
57e8: e7 62           STB    $2,S
57ea: 16 00 30        LBRA   $581D
57ed: c6 fd           LDB    #$FD
57ef: e7 62           STB    $2,S
57f1: 16 00 29        LBRA   $581D
57f4: c6 fe           LDB    #$FE
57f6: e7 62           STB    $2,S
57f8: 16 00 22        LBRA   $581D
57fb: 16 00 1f        LBRA   $581D
57fe: 8c 00 00        CMPX   #$0000
5801: 2d f8           BLT    $57FB
5803: 8c 00 05        CMPX   #$0005
5806: 2e f3           BGT    $57FB
5808: 1f 10           TFR    X,D
580a: 8e d8 11        LDX    #$D811
580d: 58              ASLB
580e: 49              ROLA
580f: 6e 9b           JMP    [D,X]
5811: d7 d8           STB    <$D8
5813: d7 ed           STB    <$ED
5815: d7 df           STB    <$DF
5817: d7 f4           STB    <$F4
5819: d7 d1           STB    <$D1
581b: d7 e6           STB    <$E6
581d: f6 24 2a        LDB    $242A
5820: e4 62           ANDB   $2,S
5822: f7 24 2a        STB    $242A
5825: f6 24 2a        LDB    $242A
5828: ea 63           ORB    $3,S
582a: f7 24 2a        STB    $242A
582d: f6 24 2a        LDB    $242A
5830: 4f              CLRA
5831: 1f 03           TFR    D,U
5833: 10 8e 00 02     LDY    #$0002
5837: 34 60           PSHS   U,Y
5839: 17 fe e1        LBSR   $571D
583c: 32 64           LEAS   $4,S
583e: 32 64           LEAS   $4,S
5840: 39              RTS
; LCD custom character (CGRAM) programming — $5841.
; Programs an HD44780 custom character pattern. The first argument ($0007,S) specifies the
; character code (shifted left 3 to form the CGRAM address, ORed with $40 for the "set CGRAM
; address" command). The second argument ($0009,S) points to an 8-byte pattern buffer. Writes
; the command via $571D, then writes 8 pattern bytes via $573F. Resets cursor to DDRAM $00 via
; $57A0 afterward. Used during display initialization to load custom glyphs.
5841: fc dc 34        LDD    $DC34
5844: 17 25 09        LBSR   $7D50
5847: ec e9 00 07     LDD    $0007,S
584b: 58              ASLB
584c: 49              ROLA
584d: 58              ASLB
584e: 49              ROLA
584f: 58              ASLB
5850: 49              ROLA
5851: ed e9 00 07     STD    $0007,S
5855: cc 00 40        LDD    #$0040
5858: aa e9 00 07     ORA    $0007,S
585c: ea e9 00 08     ORB    $0008,S
5860: 1f 03           TFR    D,U
5862: 10 8e 00 02     LDY    #$0002
5866: 34 60           PSHS   U,Y
5868: 17 fe b2        LBSR   $571D
586b: 32 64           LEAS   $4,S
586d: 6f 62           CLR    $2,S
586f: e6 62           LDB    $2,S
5871: c1 08           CMPB   #$08
5873: 10 2c 00 1c     LBGE   $5893
5877: ae e9 00 09     LDX    $0009,S
587b: e6 62           LDB    $2,S
587d: 30 85           LEAX   B,X
587f: e6 84           LDB    ,X
5881: 4f              CLRA
5882: 1f 03           TFR    D,U
5884: 10 8e 00 02     LDY    #$0002
5888: 34 60           PSHS   U,Y
588a: 17 fe b2        LBSR   $573F
588d: 32 64           LEAS   $4,S
588f: 6c 62           INC    $2,S
5891: 20 dc           BRA    $586F
5893: 5f              CLRB
5894: 1d              SEX
5895: 1f 03           TFR    D,U
5897: 10 8e 00 02     LDY    #$0002
589b: 34 60           PSHS   U,Y
589d: 17 ff 00        LBSR   $57A0
58a0: 32 64           LEAS   $4,S
58a2: 32 63           LEAS   $3,S
58a4: 39              RTS
; Display string write (simple) — $58A5.
; Sets the display cursor position via $57A0 to the value at $0007,S, then writes a string to
; the display by calling $573F for each character. Source buffer at $000B,S, length at $0009,S.
58a5: fc dc 34        LDD    $DC34
58a8: 17 24 a5        LBSR   $7D50       ; allocate frame
58ab: ee e9 00 07     LDU    $0007,S     ; cursor position
58af: 10 8e 00 02     LDY    #$0002
58b3: 34 60           PSHS   U,Y
58b5: 17 fe e8        LBSR   $57A0       ; → set display cursor position
58b8: 32 64           LEAS   $4,S
58ba: 6f 62           CLR    $2,S        ; char index = 0
58bc: e6 62           LDB    $2,S        ; loop: for each character
58be: 4f              CLRA
58bf: 10 a3 e9 00 09  CMPD   $0009,S     ; index < length?
58c4: 10 24 00 1f     LBCC   $58E7       ; no → done
58c8: ae e9 00 0b     LDX    $000B,S     ; X = source buffer
58cc: e6 62           LDB    $2,S
58ce: 3a              ABX               ; X = &buffer[index]
58cf: e6 84           LDB    ,X          ; B = character
58d1: 4f              CLRA
58d2: 1f 03           TFR    D,U         ; U = character
58d4: 10 8e 00 02     LDY    #$0002
58d8: 34 60           PSHS   U,Y
58da: 17 fe 62        LBSR   $573F       ; → write character to display
58dd: 32 64           LEAS   $4,S
58df: e6 62           LDB    $2,S        ; index++
58e1: cb 01           ADDB   #$01
58e3: e7 62           STB    $2,S
58e5: 20 d5           BRA    $58BC       ; → loop
58e7: 32 63           LEAS   $3,S
58e9: 39              RTS
; Display string write (with row/column mapping) — $58EA.
; Extended version of $58A5 that maps a row/column coordinate pair into a display address before
; writing. Handles wrapping (column ≥ 40 → subtract 24 to remap to second row region), computes
; available character count as min(caller_length, row_capacity), and then either calls $57A0 +
; $573F loop (if $2204 bit 4 is clear) or writes to the display character map at $242B (if set).
; Inputs on stack: row at $000A,S, length at $000B,S, source at $000D,S, position at $0009,S.
58ea: fc dc 39        LDD    $DC39
58ed: 17 24 60        LBSR   $7D50       ; allocate frame
58f0: e6 e9 00 0a     LDB    $000A,S     ; load row/position byte
58f4: e7 63           STB    $3,S        ; save locally
58f6: e6 63           LDB    $3,S
58f8: c1 27           CMPB   #$27
58fa: 10 23 00 06     LBLS   $5904
58fe: e6 63           LDB    $3,S
5900: c0 18           SUBB   #$18
5902: e7 63           STB    $3,S
5904: 86 50           LDA    #$50
5906: e6 63           LDB    $3,S
5908: 17 24 84        LBSR   $7D8F
590b: e7 64           STB    $4,S
590d: e6 64           LDB    $4,S
590f: 4f              CLRA
5910: 10 a3 e9 00 0b  CMPD   $000B,S
5915: 10 24 00 07     LBCC   $5920
5919: e6 64           LDB    $4,S
591b: 4f              CLRA
591c: ed e9 00 0b     STD    $000B,S
5920: fc 22 04        LDD    $2204
5923: 84 00           ANDA   #$00
5925: c4 10           ANDB   #$10
5927: 10 83 00 00     CMPD   #$0000
592b: 10 26 00 3c     LBNE   $596B
592f: ee e9 00 09     LDU    $0009,S
5933: 10 8e 00 02     LDY    #$0002
5937: 34 60           PSHS   U,Y
5939: 17 fe 64        LBSR   $57A0
593c: 32 64           LEAS   $4,S
593e: 6f 62           CLR    $2,S
5940: e6 62           LDB    $2,S
5942: 4f              CLRA
5943: 10 a3 e9 00 0b  CMPD   $000B,S
5948: 10 24 00 1f     LBCC   $596B
594c: ae e9 00 0d     LDX    $000D,S
5950: e6 62           LDB    $2,S
5952: 3a              ABX
5953: e6 84           LDB    ,X
5955: 4f              CLRA
5956: 1f 03           TFR    D,U
5958: 10 8e 00 02     LDY    #$0002
595c: 34 60           PSHS   U,Y
595e: 17 fd de        LBSR   $573F
5961: 32 64           LEAS   $4,S
5963: e6 62           LDB    $2,S
5965: cb 01           ADDB   #$01
5967: e7 62           STB    $2,S
5969: 20 d5           BRA    $5940
596b: 8e 24 2b        LDX    #$242B
596e: e6 63           LDB    $3,S
5970: 3a              ABX
5971: 1f 13           TFR    X,U
5973: 10 ae e9 00 0d  LDY    $000D,S
5978: ae e9 00 0b     LDX    $000B,S
597c: cc 00 06        LDD    #$0006
597f: 34 76           PSHS   U,Y,X,D
5981: 17 e9 01        LBSR   $4285
5984: 32 68           LEAS   $8,S
5986: 32 65           LEAS   $5,S
5988: 39              RTS
; Full display buffer write (2×40 LCD) — $5989.
; Writes the entire display contents from a buffer pointed to by $0006,S. Sends the first 40
; bytes ($28) to LCD row 0 (DDRAM address $00) and the next 40 bytes to row 1 (DDRAM address
; $40) via $58EA. Called by $59C6 (display refresh) with the character map at $242B.
5989: fc dc 36        LDD    $DC36
598c: 17 23 c1        LBSR   $7D50
598f: ee e9 00 06     LDU    $0006,S
5993: c6 28           LDB    #$28
5995: 1d              SEX
5996: 1f 02           TFR    D,Y
5998: 5f              CLRB
5999: 1d              SEX
599a: 1f 01           TFR    D,X
599c: cc 00 06        LDD    #$0006
599f: 34 76           PSHS   U,Y,X,D
59a1: 17 ff 46        LBSR   $58EA
59a4: 32 68           LEAS   $8,S
59a6: ae e9 00 06     LDX    $0006,S
59aa: 30 88 28        LEAX   $28,X
59ad: 1f 13           TFR    X,U
59af: c6 28           LDB    #$28
59b1: 1d              SEX
59b2: 1f 02           TFR    D,Y
59b4: c6 40           LDB    #$40
59b6: 1d              SEX
59b7: 1f 01           TFR    D,X
59b9: cc 00 06        LDD    #$0006
59bc: 34 76           PSHS   U,Y,X,D
59be: 17 ff 29        LBSR   $58EA
59c1: 32 68           LEAS   $8,S
59c3: 32 62           LEAS   $2,S
59c5: 39              RTS
; Display refresh — $59C6.
; Clears $2204 bit 4 (exits parameter edit mode overlay) and then pushes the entire display
; character map at $242B to the physical display via $5989. This is the main display refresh
; called from the foreground loop when $0100 bit 5 triggers a display update.
59c6: fc dc 36        LDD    $DC36
59c9: 17 23 84        LBSR   $7D50       ; allocate frame
59cc: fc 22 04        LDD    $2204
59cf: 84 ff           ANDA   #$FF
59d1: c4 ef           ANDB   #$EF        ; clear bit 4 (parameter edit overlay)
59d3: fd 22 04        STD    $2204
59d6: ce 24 2b        LDU    #$242B      ; display character map base address
59d9: 10 8e 00 02     LDY    #$0002
59dd: 34 60           PSHS   U,Y
59df: 8d a8           BSR    $5989       ; → push character map to display hardware
59e1: 32 64           LEAS   $4,S
59e3: 32 62           LEAS   $2,S
59e5: 39              RTS
; Display full initialization — $59E6.
; Initializes the front-panel display hardware via $571D (display command write) with a
; sequence of initialization commands ($38, $0C, $01 — standard HD44780 LCD init sequence:
; 8-bit mode/2-line, display on/cursor off, clear display). Then loads the power-on banner
; strings from ROM ($ED39/$ED11) and the 8 soft-key labels from $EA15..$EA4D via $5841.
59e6: fc dc 34        LDD    $DC34
59e9: 17 23 64        LBSR   $7D50       ; allocate frame
59ec: c6 38           LDB    #$38        ; LCD command: function set (8-bit, 2-line)
59ee: 1d              SEX
59ef: 1f 03           TFR    D,U
59f1: 10 8e 00 02     LDY    #$0002
59f5: 34 60           PSHS   U,Y
59f7: 17 fd 23        LBSR   $571D
59fa: 32 64           LEAS   $4,S
59fc: c6 0c           LDB    #$0C
59fe: f7 24 2a        STB    $242A
5a01: c6 0c           LDB    #$0C
5a03: 1d              SEX
5a04: 1f 03           TFR    D,U
5a06: 10 8e 00 02     LDY    #$0002
5a0a: 34 60           PSHS   U,Y
5a0c: 17 fd 0e        LBSR   $571D
5a0f: 32 64           LEAS   $4,S
5a11: c6 01           LDB    #$01
5a13: 1d              SEX
5a14: 1f 03           TFR    D,U
5a16: 10 8e 00 02     LDY    #$0002
5a1a: 34 60           PSHS   U,Y
5a1c: 17 fc fe        LBSR   $571D
5a1f: 32 64           LEAS   $4,S
5a21: ce ed 39        LDU    #$ED39
5a24: c6 28           LDB    #$28
5a26: 1d              SEX
5a27: 1f 02           TFR    D,Y
5a29: 5f              CLRB
5a2a: 1d              SEX
5a2b: 1f 01           TFR    D,X
5a2d: cc 00 06        LDD    #$0006
5a30: 34 76           PSHS   U,Y,X,D
5a32: 17 fe b5        LBSR   $58EA
5a35: 32 68           LEAS   $8,S
5a37: ce ed 39        LDU    #$ED39
5a3a: c6 28           LDB    #$28
5a3c: 1d              SEX
5a3d: 1f 02           TFR    D,Y
5a3f: c6 40           LDB    #$40
5a41: 1d              SEX
5a42: 1f 01           TFR    D,X
5a44: cc 00 06        LDD    #$0006
5a47: 34 76           PSHS   U,Y,X,D
5a49: 17 fe 9e        LBSR   $58EA
5a4c: 32 68           LEAS   $8,S
5a4e: ce ea 15        LDU    #$EA15
5a51: 5f              CLRB
5a52: 1d              SEX
5a53: 1f 02           TFR    D,Y
5a55: 8e 00 04        LDX    #$0004
5a58: 34 70           PSHS   U,Y,X
5a5a: 17 fd e4        LBSR   $5841
5a5d: 32 66           LEAS   $6,S
5a5f: ce ea 1d        LDU    #$EA1D
5a62: c6 01           LDB    #$01
5a64: 1d              SEX
5a65: 1f 02           TFR    D,Y
5a67: 8e 00 04        LDX    #$0004
5a6a: 34 70           PSHS   U,Y,X
5a6c: 17 fd d2        LBSR   $5841
5a6f: 32 66           LEAS   $6,S
5a71: ce ea 25        LDU    #$EA25
5a74: c6 02           LDB    #$02
5a76: 1d              SEX
5a77: 1f 02           TFR    D,Y
5a79: 8e 00 04        LDX    #$0004
5a7c: 34 70           PSHS   U,Y,X
5a7e: 17 fd c0        LBSR   $5841
5a81: 32 66           LEAS   $6,S
5a83: ce ea 2d        LDU    #$EA2D
5a86: c6 03           LDB    #$03
5a88: 1d              SEX
5a89: 1f 02           TFR    D,Y
5a8b: 8e 00 04        LDX    #$0004
5a8e: 34 70           PSHS   U,Y,X
5a90: 17 fd ae        LBSR   $5841
5a93: 32 66           LEAS   $6,S
5a95: ce ea 35        LDU    #$EA35
5a98: c6 04           LDB    #$04
5a9a: 1d              SEX
5a9b: 1f 02           TFR    D,Y
5a9d: 8e 00 04        LDX    #$0004
5aa0: 34 70           PSHS   U,Y,X
5aa2: 17 fd 9c        LBSR   $5841
5aa5: 32 66           LEAS   $6,S
5aa7: ce ea 3d        LDU    #$EA3D
5aaa: c6 05           LDB    #$05
5aac: 1d              SEX
5aad: 1f 02           TFR    D,Y
5aaf: 8e 00 04        LDX    #$0004
5ab2: 34 70           PSHS   U,Y,X
5ab4: 17 fd 8a        LBSR   $5841
5ab7: 32 66           LEAS   $6,S
5ab9: ce ea 45        LDU    #$EA45
5abc: c6 06           LDB    #$06
5abe: 1d              SEX
5abf: 1f 02           TFR    D,Y
5ac1: 8e 00 04        LDX    #$0004
5ac4: 34 70           PSHS   U,Y,X
5ac6: 17 fd 78        LBSR   $5841
5ac9: 32 66           LEAS   $6,S
5acb: ce ea 4d        LDU    #$EA4D
5ace: c6 07           LDB    #$07
5ad0: 1d              SEX
5ad1: 1f 02           TFR    D,Y
5ad3: 8e 00 04        LDX    #$0004
5ad6: 34 70           PSHS   U,Y,X
5ad8: 17 fd 66        LBSR   $5841
5adb: 32 66           LEAS   $6,S
5add: 32 63           LEAS   $3,S
5adf: 39              RTS
; ROM page switch — $5AE0.
; Selects a page of the banked ROM (4×16KB at CPU $4000-$7FFF). Calls $4BA6 to compute
; the page-select byte from the caller argument at $0008,S and stores it at $2414/$2415.
; Then writes the page-select byte to $4000 (the hardware page register) and reads it back
; to verify the switch succeeded. On success, stores the page index at $247B and returns B=0.
; On failure (read-back mismatch), sets $247B to $FF and returns B=1.
5ae0: fc dc 37        LDD    $DC37
5ae3: 17 22 6a        LBSR   $7D50       ; allocate frame
5ae6: ce 24 14        LDU    #$2414      ; destination for page descriptor
5ae9: 10 ae e9 00 08  LDY    $0008,S     ; caller-supplied page argument
5aee: 8e 00 04        LDX    #$0004
5af1: 34 70           PSHS   U,Y,X
5af3: 17 f0 b0        LBSR   $4BA6       ; → compute page-select byte into $2414/$2415
5af6: 32 66           LEAS   $6,S
5af8: f6 24 15        LDB    $2415       ; load computed page-select byte
5afb: e7 62           STB    $2,S        ; save locally
; Write page register and verify
5afd: e6 62           LDB    $2,S
5aff: f7 40 00        STB    $4000       ; write to hardware page register
5b02: f6 40 00        LDB    $4000       ; read back
5b05: e1 62           CMPB   $2,S        ; match?
5b07: 10 26 00 0f     LBNE   $5B1A       ; no → page switch failed
; Success
5b0b: e6 e9 00 09     LDB    $0009,S     ; store page index
5b0f: f7 24 7b        STB    $247B
5b12: 6f 63           CLR    $3,S        ; return 0 (success)
5b14: 16 00 0f        LBRA   $5B26
5b17: 16 00 0c        LBRA   $5B26
; Failure
5b1a: c6 ff           LDB    #$FF        ; mark page as invalid
5b1c: f7 24 7b        STB    $247B
5b1f: c6 01           LDB    #$01        ; return 1 (failure)
5b21: e7 63           STB    $3,S
5b23: 16 00 00        LBRA   $5B26
5b26: e6 63           LDB    $3,S        ; load return value
5b28: 32 64           LEAS   $4,S
5b2a: 39              RTS
; Paged function call — $5B2B.
; Saves the current ROM page ($247B), switches to the page requested by the caller at $0007,S,
; calls the function at $0009,S via JSR ,X, then switches back to the original page.
; This enables cross-page function calls in the 4×16KB banked ROM.
5b2b: fc dc 34        LDD    $DC34
5b2e: 17 22 1f        LBSR   $7D50       ; allocate frame
5b31: f6 24 7b        LDB    $247B       ; save current page
5b34: e7 62           STB    $2,S
5b36: ee e9 00 07     LDU    $0007,S     ; requested page
5b3a: 10 8e 00 02     LDY    #$0002
5b3e: 34 60           PSHS   U,Y
5b40: 8d 9e           BSR    $5AE0
5b42: 32 64           LEAS   $4,S
5b44: ae e9 00 09     LDX    $0009,S
5b48: ad 84           JSR    ,X
5b4a: e6 62           LDB    $2,S
5b4c: 4f              CLRA
5b4d: 1f 03           TFR    D,U
5b4f: 10 8e 00 02     LDY    #$0002
5b53: 34 60           PSHS   U,Y
5b55: 8d 89           BSR    $5AE0
5b57: 32 64           LEAS   $4,S
5b59: 32 63           LEAS   $3,S
5b5b: 39              RTS
; Enter idle/watchdog timeout state — $5B5C.
; Sets $2204 bit 7 (idle-timeout flag) and turns OFF LED bit 6 (active-low: set the bit to
; turn off the LED) in the LED shadow register $2420 and hardware port $0900.
; Called from the main loop watchdog when 18 consecutive idle overflows are detected.
5b5c: fc dc 36        LDD    $DC36
5b5f: 17 21 ee        LBSR   $7D50       ; allocate frame
5b62: fc 22 04        LDD    $2204
5b65: 8a 00           ORA    #$00
5b67: ca 80           ORB    #$80        ; set bit 7 (idle-timeout active)
5b69: fd 22 04        STD    $2204
5b6c: f6 24 20        LDB    $2420       ; LED shadow register
5b6f: ca 40           ORB    #$40        ; set bit 6 (active-low: LED 6 OFF)
5b71: f7 24 20        STB    $2420
5b74: f6 24 20        LDB    $2420
5b77: f7 09 00        STB    $0900       ; write to LED hardware port
5b7a: 32 62           LEAS   $2,S
5b7c: 39              RTS
; Exit idle/watchdog timeout state — $5B7D (periodic service entry).
; Clears $2204 bit 7 (idle-timeout flag) and turns ON LED bit 6 (active-low: clear the bit to
; turn on the LED). This re-activates the instrument after the watchdog/idle timeout.
; Called from the main loop periodic counter path when activity resumes.
5b7d: fc dc 36        LDD    $DC36
5b80: 17 21 cd        LBSR   $7D50       ; allocate frame
5b83: fc 22 04        LDD    $2204
5b86: 84 ff           ANDA   #$FF
5b88: c4 7f           ANDB   #$7F        ; clear bit 7 (idle-timeout no longer active)
5b8a: fd 22 04        STD    $2204
5b8d: f6 24 20        LDB    $2420       ; LED shadow register
5b90: 4f              CLRA
5b91: 84 00           ANDA   #$00
5b93: c4 bf           ANDB   #$BF        ; clear bit 6 (active-low: LED 6 ON)
5b95: f7 24 20        STB    $2420
5b98: f6 24 20        LDB    $2420
5b9b: f7 09 00        STB    $0900       ; write to LED hardware port
5b9e: 32 62           LEAS   $2,S
5ba0: 39              RTS
; I/O port bit-field write — $5BA1.
; Writes a masked value to a hardware I/O register. The target register is selected by the
; index at $000C,S (0→$0C00, 1→$0D00, 2→$0E00, 3→$0F00), and the value is constructed from
; a mask at $000E,S and data bits at $0010,S. Also shadows the result at $24F0+index.
5ba1: fc dc 3b        LDD    $DC3B
5ba4: 17 21 a9        LBSR   $7D50       ; allocate frame
5ba7: ae e9 00 0c     LDX    $000C,S     ; X = port index (0-3)
5bab: 16 00 20        LBRA   $5BCE       ; → switch on port index
; Port address lookup: index → hardware I/O address
5bae: cc 0c 00        LDD    #$0C00      ; port 0 → $0C00
5bb1: ed 62           STD    $2,S
5bb3: 16 00 2f        LBRA   $5BE5
5bb6: cc 0d 00        LDD    #$0D00      ; port 1 → $0D00
5bb9: ed 62           STD    $2,S
5bbb: 16 00 27        LBRA   $5BE5
5bbe: cc 0e 00        LDD    #$0E00      ; port 2 → $0E00
5bc1: ed 62           STD    $2,S
5bc3: 16 00 1f        LBRA   $5BE5
5bc6: cc 0f 00        LDD    #$0F00      ; port 3 → $0F00
5bc9: ed 62           STD    $2,S
5bcb: 16 00 17        LBRA   $5BE5
5bce: 8c 00 00        CMPX   #$0000      ; switch: port 0?
5bd1: 27 db           BEQ    $5BAE
5bd3: 8c 00 01        CMPX   #$0001      ; port 1?
5bd6: 27 de           BEQ    $5BB6
5bd8: 8c 00 02        CMPX   #$0002      ; port 2?
5bdb: 27 e1           BEQ    $5BBE
5bdd: 8c 00 03        CMPX   #$0003      ; port 3?
5be0: 27 e4           BEQ    $5BC6
5be2: 16 00 00        LBRA   $5BE5       ; invalid → fall through
; Compute shadow address and apply masked write
5be5: 8e 24 f0        LDX    #$24F0      ; shadow register base
5be8: ec e9 00 0c     LDD    $000C,S     ; D = port index
5bec: 30 8b           LEAX   D,X         ; X = &shadow[port]
5bee: af 64           STX    $4,S        ; save shadow address
5bf0: ec e9 00 0e     LDD    $000E,S     ; D = mask argument
5bf4: 43              COMA                ; invert mask: ~mask
5bf5: 53              COMB
5bf6: ed 66           STD    $6,S        ; save inverted mask
5bf8: e6 f8 04        LDB    [$04,S]     ; B = current shadow value
5bfb: 4f              CLRA
5bfc: a4 66           ANDA   $6,S        ; D = shadow AND ~mask (preserve unmasked bits)
5bfe: e4 67           ANDB   $7,S
5c00: aa e9 00 10     ORA    $0010,S     ; D = D OR value (apply new masked bits)
5c04: ea e9 00 11     ORB    $0011,S
5c08: e7 f8 04        STB    [$04,S]     ; write back to shadow
5c0b: e6 f8 04        LDB    [$04,S]     ; re-read shadow
5c0e: e7 f8 02        STB    [$02,S]     ; write to hardware I/O register
5c11: 32 68           LEAS   $8,S        ; deallocate frame
5c13: 39              RTS
; Hardware input bit 6 test — $5C14.
; Reads port $0000 bit 6 and returns the logical inverse: B=0 if bit is set, B=1 if clear.
; Called by $233D to get a runtime status value for HP-IB reply formatting.
5c14: fc dc 34        LDD    $DC34
5c17: 17 21 36        LBSR   $7D50       ; allocate frame
5c1a: f6 00 00        LDB    >$0000      ; read hardware input port
5c1d: c4 40           ANDB   #$40        ; isolate bit 6
5c1f: 10 27 00 08     LBEQ   $5C2B       ; bit 6 clear → return 1
5c23: 6f 62           CLR    $2,S        ; bit 6 set → return 0
5c25: 16 00 07        LBRA   $5C2F
5c28: 16 00 04        LBRA   $5C2F
5c2b: c6 01           LDB    #$01        ; return 1
5c2d: e7 62           STB    $2,S
5c2f: e6 62           LDB    $2,S
5c31: 32 63           LEAS   $3,S
5c33: 39              RTS
; =====================================================================================
; Data region at $5C34: 4 × 2-byte values (tentative: MC6840 PTM timer reload constants).
; These follow the disassembler's misalignment at $5C3C.
; =====================================================================================
5c34: 00 01           NEG    <$01        ; data: $0001
5c36: 00 00           NEG    <$00        ; data: $0000
5c38: 02 00           XNC    <$00        ; data: $0200
5c3a: 03 00           COM    <$00        ; data: $0300
; =====================================================================================
; NMI handler entry — $5C3D (CPU address $DC3D).
; NOTE: The disassembler started decoding at $5C3C (data byte $06), consuming $5C3D as its
; operand. The actual NMI entry instruction at $5C3D is: LDA $2202 ($B6 $22 $02).
; Correct decode from raw bytes:
;   $5C3D: B6 22 02 → LDA $2202       ; read system flags
;   $5C40: 2A 04    → BPL $5C46       ; bit 7 clear → standard PTM service
;   $5C42: 6E 9F 24 D8 → JMP [$24D8]  ; bit 7 set → dispatch through callback pointer
; The PTM service path reads shadow registers $2421-$2423, writes them to PTM ($1000-$1001)
; to reset the timers, then calls $705E (PTM register-poll helper) and returns via RTI.
; =====================================================================================
5c3c: 06 b6           ROR    <$B6        ; misaligned: real entry is $5C3D (LDA $2202)
5c3e: 22 02           BHI    $5C42       ; part of LDA $2202 + BPL $5C46
5c40: 2a 04           BPL    $5C46       ; bit 7 clear → PTM service path
5c42: 6e 9f 24 d8     JMP    [$24D8]     ; bit 7 set → dispatch via callback pointer at $24D8
; Standard PTM service: reset timer channels from shadow registers
5c46: b6 24 22        LDA    $2422       ; PTM CR2 shadow
5c49: 8a 01           ORA    #$01        ; set bit 0 (enable CR1 write)
5c4b: b7 10 01        STA    $1001       ; write to PTM CR1/2 register
5c4e: b6 24 21        LDA    $2421       ; PTM CR1 shadow
5c51: 84 bf           ANDA   #$BF        ; clear bit 6 (tentative: reset timer 1)
5c53: b7 24 21        STA    $2421       ; update shadow
5c56: b7 10 00        STA    $1000       ; write to PTM CR0/1
5c59: b6 24 22        LDA    $2422       ; PTM CR2 shadow again
5c5c: 84 fe           ANDA   #$FE        ; clear bit 0 (disable CR1 write)
5c5e: b7 10 01        STA    $1001
5c61: b6 24 23        LDA    $2423       ; PTM CR3 shadow
5c64: 84 bf           ANDA   #$BF        ; clear bit 6 (tentative: reset timer 3)
5c66: b7 24 23        STA    $2423       ; update shadow
5c69: b7 10 00        STA    $1000       ; write to PTM
5c6c: b6 24 22        LDA    $2422       ; restore CR2 shadow
5c6f: 84 bf           ANDA   #$BF        ; clear bit 6
5c71: b7 24 22        STA    $2422       ; update shadow
5c74: b7 10 01        STA    $1001       ; write to PTM
5c77: 17 13 e4        LBSR   $705E       ; → $705E: poll PTM until stable
5c7a: 3b              RTI               ; return from NMI
; =====================================================================================
; Self-test entry — $5C7B.
; Calls the RAM test ($5C82) and the ROM checksum test ($5CA9) in sequence.
; =====================================================================================
5c7b: 17 00 04        LBSR   $5C82       ; → RAM test
5c7e: 17 00 28        LBSR   $5CA9       ; → ROM checksum test
5c81: 39              RTS
; =====================================================================================
; RAM test — $5C82.
; Tests RAM from $2000 to $3FFF by complementing each byte and verifying it reads back correctly.
; Each byte is complemented twice (COM, check, COM, check) to verify both write values.
; On failure: sets $2202 bit 6 (RAM test fail flag) and restores the original byte.
; =====================================================================================
5c82: 8e 1f ff        LDX    #$1FFF      ; start just before $2000
5c85: 30 01           LEAX   $1,X        ; advance to next address
5c87: e6 84           LDB    ,X          ; read original byte
5c89: 53              COMB               ; complement in register
5c8a: 63 84           COM    ,X          ; complement in memory
5c8c: e1 84           CMPB   ,X          ; compare: should match
5c8e: 26 0e           BNE    $5C9E       ; mismatch → restore and fail
5c90: 53              COMB               ; complement back
5c91: 63 84           COM    ,X          ; complement memory back (restore)
5c93: e1 84           CMPB   ,X          ; verify restoration
5c95: 26 09           BNE    $5CA0       ; mismatch → fail (byte already restored by COM)
5c97: 8c 3f ff        CMPX   #$3FFF      ; end of RAM range?
5c9a: 26 e9           BNE    $5C85       ; no → next byte
5c9c: 20 0a           BRA    $5CA8       ; all pass → return
5c9e: 63 84           COM    ,X          ; restore original byte after first COM failed
5ca0: fc 22 02        LDD    $2202
5ca3: 8a 40           ORA    #$40        ; set bit 6 = RAM test failure
5ca5: fd 22 02        STD    $2202
5ca8: 39              RTS
; =====================================================================================
; ROM checksum test — $5CA9.
; Phase 1: Checksums A2U12 ROM ($8000-$FFFF, file offsets $0000-$7FFF) by accumulating all
; bytes with ADC into B. Result stored at $2480. If nonzero → sets $2202 bit 5 (A2U12 ROM fail).
; Phase 2: Iterates through all A2U13 pages. For each page:
;   - Writes page number to $4000 (page select)
;   - Checksums $4000-$7FFF (the 16KB page window) with ADC into B
;   - Stores result at $2481+page. If nonzero → sets $2202 bit 4 (A2U13 ROM fail).
; Finally restores the original A2U13 page from $247B.
; =====================================================================================
5ca9: 8e 7f ff        LDX    #$7FFF      ; start just before $8000 (file offset $0000)
5cac: 5f              CLRB               ; clear checksum accumulator
5cad: 30 01           LEAX   $1,X        ; advance
5caf: e9 84           ADCB   ,X          ; accumulate byte with carry
5cb1: 8c ff ff        CMPX   #$FFFF      ; end of A2U12 ROM?
5cb4: 26 f7           BNE    $5CAD
5cb6: f7 24 80        STB    $2480       ; store A2U12 checksum result
5cb9: 5d              TSTB
5cba: 27 08           BEQ    $5CC4       ; zero = pass
5cbc: fc 22 02        LDD    $2202
5cbf: 8a 20           ORA    #$20        ; set bit 5 = A2U12 ROM checksum failure
5cc1: fd 22 02        STD    $2202
; Phase 2: A2U13 paged ROM checksum
5cc4: 4f              CLRA
5cc5: b7 40 00        STA    $4000       ; select page 0
5cc8: b6 40 02        LDA    $4002       ; read page-count marker at $4002
5ccb: 4a              DECA               ; A = last page index (0-based)
5ccc: b7 24 7f        STA    $247F       ; save as loop counter
5ccf: b7 40 00        STA    $4000       ; select this page
5cd2: 8e 3f ff        LDX    #$3FFF      ; start just before $4000
5cd5: 5f              CLRB               ; clear checksum
5cd6: 30 01           LEAX   $1,X        ; advance
5cd8: e9 84           ADCB   ,X          ; accumulate
5cda: 8c 7f ff        CMPX   #$7FFF      ; end of page?
5cdd: 26 f7           BNE    $5CD6
5cdf: 8e 24 81        LDX    #$2481      ; per-page result table base
5ce2: b6 24 7f        LDA    $247F       ; current page index
5ce5: e7 86           STB    A,X         ; store checksum at $2481+page
5ce7: f1 24 7f        CMPB   $247F       ; (tentative: compare with expected; $247F is reused)
5cea: 27 08           BEQ    $5CF4       ; match → this page passes
5cec: fc 22 02        LDD    $2202
5cef: 8a 10           ORA    #$10        ; set bit 4 = A2U13 ROM checksum failure
5cf1: fd 22 02        STD    $2202
5cf4: b6 24 7f        LDA    $247F       ; loop counter
5cf7: 26 d2           BNE    $5CCB       ; more pages → decrement and loop
; Restore original A2U13 page
5cf9: f6 24 7b        LDB    $247B       ; saved active page
5cfc: f7 40 00        STB    $4000       ; restore page select
5cff: 39              RTS
; Simple CC-manipulation helpers used throughout the foreground code:
; - $5D00: clear I (enable IRQ)
; - $5D03: clear F (enable FIRQ)
; - $5D06: set I   (disable IRQ)
; - $5D09: set F   (disable FIRQ)
5d00: 1c ef           ANDCC  #$EF
5d02: 39              RTS
5d03: 1c bf           ANDCC  #$BF
5d05: 39              RTS
5d06: 1a 10           ORCC   #$10
5d08: 39              RTS
5d09: 1a 40           ORCC   #$40
5d0b: 39              RTS
; =====================================================================================
; FIRQ wrapper — $5D0C (vector at $FFF6).
; FIRQ on MC6809 only saves CC and PC. This wrapper manually saves all other registers,
; calls $70A1 (the real FIRQ handler which processes $0100 interrupt latch bits $80/$10),
; restores registers, and returns via RTI.
; =====================================================================================
5d0c: 34 7e           PSHS   U,Y,X,DP,D ; save registers not auto-saved by FIRQ
5d0e: 17 13 90        LBSR   $70A1       ; → $70A1: FIRQ service routine
5d11: 35 7e           PULS   D,DP,X,Y,U ; restore
5d13: 3b              RTI
; =====================================================================================
; IRQ wrapper — $5D14 (vector at $FFF8).
; Foreground-driven design: the IRQ handler does NOT process the P8291A directly.
; It only calls $7154 which sets $2204 bit 0 ("IRQ occurred" flag), then modifies the
; stacked CC to set the I bit so IRQs remain masked on return. The main loop at $04CA
; checks $2204 bit 0 and calls the P8291A handler $10D3 in foreground context.
; =====================================================================================
5d14: 17 14 3d        LBSR   $7154       ; → $7154: set $2204 bit 0
5d17: 86 10           LDA    #$10        ; I bit mask in CC
5d19: aa e4           ORA    ,S          ; OR into stacked CC
5d1b: a7 e4           STA    ,S          ; write back (IRQs will be masked on RTI)
5d1d: 3b              RTI
; Startup continuation: loads page number from $247C, calls $5AE0 with it, then dispatches
; through function pointer at $247D. This is the bridge from reset/cold-start into the main
; application loop.
5d1e: cc 00 00        LDD    #$0000      ; frame size = 0
5d21: 17 20 2c        LBSR   $7D50       ; allocate frame
5d24: f6 24 7c        LDB    $247C       ; load saved A2U13 page number
5d27: 1d              SEX
5d28: 1f 03           TFR    D,U
5d2a: 10 8e 00 02     LDY    #$0002
5d2e: 34 60           PSHS   U,Y
5d30: 17 fd ad        LBSR   $5AE0       ; → $5AE0: page-switching helper
5d33: 32 64           LEAS   $4,S
5d35: 32 62           LEAS   $2,S
5d37: 6e 9f 24 7d     JMP    [$247D]     ; dispatch through main-loop entry pointer
; =====================================================================================
; Key-mapping / front-panel dispatch — $5D3B.
; Translates a raw key code (0..$29) into a parameter-block pointer and group index.
; Uses the 42-entry lookup table at $5D73 (CPU $DD73). Each table byte encodes:
;   Bits 7:6 → group index (0..3), extracted and converted to 1..4 via ASL/ROL/ROL/INC.
;   Bits 5:0 → offset into the parameter array at $248A.
; Outputs:
;   The pointer $248A+offset is written through the caller's indirect reference at [$0A,S].
;   The group index (1..4) is returned in B as the function result.
; If the key code exceeds $29, it is forced to 0 (first table entry).
; =====================================================================================
5d3b: cc 00 02        LDD    #$0002
5d3e: 17 20 0f        LBSR   $7D50
5d41: ae 68           LDX    $8,S        ; X = raw key code from caller
5d43: 8c 00 29        CMPX   #$0029      ; valid range 0..$29?
5d46: 22 04           BHI    $5D4C       ; out of range → clamp to 0
5d48: 1f 10           TFR    X,D         ; D = key code
5d4a: 20 03           BRA    $5D4F
5d4c: cc 00 00        LDD    #$0000      ; fallback key code = 0
5d4f: 8e dd 73        LDX    #$DD73      ; X → base of lookup table (CPU address of $5D73)
5d52: 30 8b           LEAX   D,X         ; X → table[key_code]
5d54: a6 84           LDA    ,X          ; A = packed byte: [group:2][offset:6]
5d56: 1f 89           TFR    A,B         ; B = copy
5d58: c4 3f           ANDB   #$3F        ; B = offset (bits 5:0)
5d5a: 84 c0           ANDA   #$C0        ; A = group bits (bits 7:6)
5d5c: 48              ASLA               ; } shift group bits 7:6 into bits 1:0
5d5d: 49              ROLA               ; } through carry
5d5e: 49              ROLA               ; } A now = group (0..3)
5d5f: 4c              INCA               ; A = group + 1 (1..4)
5d60: a7 62           STA    $2,S        ; save group index in local
5d62: 10 8e 24 8a     LDY    #$248A      ; Y → parameter array base
5d66: 31 a5           LEAY   B,Y         ; Y = $248A + offset
5d68: 10 af f8 0a     STY    [$0A,S]     ; store parameter pointer via caller's indirect
5d6c: e6 62           LDB    $2,S        ; B = group index
5d6e: e7 63           STB    $3,S        ; place in return slot
5d70: 32 64           LEAS   $4,S
5d72: 39              RTS
; ROM data: key-code → [group:offset] lookup table ($5D73, 42 entries).
; Each byte: bits 7:6 = group (0..3), bits 5:0 = offset into $248A parameter array.
; First 8 entries map key codes 0-7 to consecutive offsets 0-7 in group 0.
5d73: 00 01           NEG    <$01
5d75: 02 03           XNC    <$03
5d77: 04 05           LSR    <$05
5d79: 06 07           ROR    <$07
5d7b: c8 cb           EORB   #$CB
5d7d: ce d1 54        LDU    #$D154
5d80: 56              RORB
5d81: 58              ASLB
5d82: 5a              DECB
5d83: 9c 9e           CMPX   <$9E
5d85: a0 a2           SUBA   ,-Y
5d87: 00 24           NEG    <$24
5d89: 25 26           BCS    $5DB1
5d8b: 27 28           BEQ    $5DB5
5d8d: 29 2a           BVS    $5DB9
5d8f: 2b 2c           BMI    $5DBD
5d91: 2d 2e           BLT    $5DC1
5d93: 2f 30           BLE    $5DC5
5d95: 31 32           LEAY   -$E,Y
5d97: 33 34           LEAU   -$C,Y
5d99: 35 f6           PULS   D,X,Y,U,PC
5d9b: 39              RTS
5d9c: 3a              ABX
; DDS parameter write from key mapping — $5D9D.
; Calls $5D3B to map a key code (arg $8,S) to a parameter group and pointer, then dispatches
; based on group code: group 1 writes a single byte to $0200, groups 2-3 write multi-word
; sequences via $5DFE/$5DF7, group 4 writes 3+ words. Each $5DF7 call stores A:B → $0200
; and decrements the DDS write counter $2489. Port $0200 is the DDS chip programming interface.
5d9d: cc 00 02        LDD    #$0002
5da0: 17 1f ad        LBSR   $7D50
5da3: 33 62           LEAU   $2,S
5da5: 10 ae 68        LDY    $8,S
5da8: 8e 00 04        LDX    #$0004
5dab: 34 70           PSHS   U,Y,X
5dad: 17 ff 8b        LBSR   $5D3B
5db0: 32 66           LEAS   $6,S
5db2: ae 6a           LDX    $A,S
5db4: c1 02           CMPB   #$02
5db6: 27 0f           BEQ    $5DC7
5db8: c1 03           CMPB   #$03
5dba: 27 0f           BEQ    $5DCB
5dbc: c1 04           CMPB   #$04
5dbe: 27 12           BEQ    $5DD2
5dc0: e6 84           LDB    ,X
5dc2: e7 f8 02        STB    [$02,S]
5dc5: 20 29           BRA    $5DF0
5dc7: c6 01           LDB    #$01
5dc9: 20 02           BRA    $5DCD
5dcb: c6 03           LDB    #$03
5dcd: f7 24 89        STB    $2489
5dd0: 20 16           BRA    $5DE8
5dd2: c6 03           LDB    #$03
5dd4: f7 24 89        STB    $2489
5dd7: e6 84           LDB    ,X
5dd9: e7 f8 02        STB    [$02,S]
5ddc: 8d 39           BSR    $5E17
5dde: 30 01           LEAX   $1,X
5de0: 10 ae 62        LDY    $2,S
5de3: 31 21           LEAY   $1,Y
5de5: 10 af 62        STY    $2,S
5de8: ec 84           LDD    ,X
5dea: ed f8 02        STD    [$02,S]
5ded: 8d 0f           BSR    $5DFE
5def: 5f              CLRB
5df0: a6 69           LDA    $9,S
5df2: 8d 03           BSR    $5DF7
5df4: 32 64           LEAS   $4,S
5df6: 39              RTS
5df7: fd 02 00        STD    $0200
5dfa: 7a 24 89        DEC    $2489
5dfd: 39              RTS
5dfe: ec 84           LDD    ,X
5e00: 84 0f           ANDA   #$0F
5e02: 58              ASLB
5e03: 49              ROLA
5e04: 58              ASLB
5e05: 49              ROLA
5e06: 1f 89           TFR    A,B
5e08: b6 24 89        LDA    $2489
5e0b: 8d ea           BSR    $5DF7
5e0d: e6 01           LDB    $1,X
5e0f: c4 3f           ANDB   #$3F
5e11: b6 24 89        LDA    $2489
5e14: 8d e1           BSR    $5DF7
5e16: 39              RTS
5e17: e6 84           LDB    ,X
5e19: 54              LSRB
5e1a: 54              LSRB
5e1b: b6 24 89        LDA    $2489
5e1e: 8d d7           BSR    $5DF7
5e20: ec 84           LDD    ,X
5e22: 44              LSRA
5e23: 56              RORB
5e24: 44              LSRA
5e25: 56              RORB
5e26: 54              LSRB
5e27: 54              LSRB
5e28: b6 24 89        LDA    $2489
5e2b: 8d ca           BSR    $5DF7
5e2d: 39              RTS
; DDS full tuning word write — $5E2E.
; Sets the DDS write counter $2489 to 7, computes an index into the $2581 tuning word array
; using $2201 channel and the argument's low nibble, then writes a complete tuning word sequence
; (frequency, phase, control words) to the DDS via $0200. Also writes configuration words
; ($14, $15 registers) including $248A offset $24 data. Called during frequency/parameter updates.
5e2e: cc 00 00        LDD    #$0000
5e31: 17 1f 1c        LBSR   $7D50
5e34: c6 07           LDB    #$07
5e36: f7 24 89        STB    $2489
5e39: ec 66           LDD    $6,S
5e3b: b6 22 01        LDA    $2201
5e3e: c4 0f           ANDB   #$0F
5e40: e7 67           STB    $7,S
5e42: 3d              MUL
5e43: 8e 25 81        LDX    #$2581
5e46: 30 8b           LEAX   D,X
5e48: 8d b4           BSR    $5DFE
5e4a: 30 02           LEAX   $2,X
5e4c: 8d b0           BSR    $5DFE
5e4e: 30 02           LEAX   $2,X
5e50: 8d c5           BSR    $5E17
5e52: 30 01           LEAX   $1,X
5e54: 8d a8           BSR    $5DFE
5e56: 86 15           LDA    #$15
5e58: e6 67           LDB    $7,S
5e5a: 8d 9b           BSR    $5DF7
5e5c: 86 14           LDA    #$14
5e5e: 5f              CLRB
5e5f: 8d 96           BSR    $5DF7
5e61: 86 15           LDA    #$15
5e63: 10 8e 24 8a     LDY    #$248A
5e67: e6 a8 24        LDB    $24,Y
5e6a: 8d 8b           BSR    $5DF7
5e6c: 32 62           LEAS   $2,S
5e6e: 39              RTS
; DDS direct register write — $5E6F.
; Writes two bytes to the DDS chip: A (from $7,S) and B (from $9,S) are combined and stored
; to port $0200. The A byte typically contains the register address, B the data value.
5e6f: cc 00 00        LDD    #$0000
5e72: 17 1e db        LBSR   $7D50
5e75: a6 67           LDA    $7,S
5e77: e6 69           LDB    $9,S
5e79: fd 02 00        STD    $0200
5e7c: 32 62           LEAS   $2,S
5e7e: 39              RTS
; DDS configuration register $26 update — $5E7F.
; Writes DDS register $26 twice: first with $24BF bit 3 cleared (transition state), then with
; $24BF unmodified (final state). This two-write sequence tentatively provides a glitch-free
; configuration update for the DDS output mode control register.
5e7f: fc e9 f7        LDD    $E9F7
5e82: 17 1e cb        LBSR   $7D50
5e85: f6 24 bf        LDB    $24BF
5e88: 4f              CLRA
5e89: 84 00           ANDA   #$00
5e8b: c4 f7           ANDB   #$F7
5e8d: 1f 03           TFR    D,U
5e8f: c6 26           LDB    #$26
5e91: 1d              SEX
5e92: 1f 02           TFR    D,Y
5e94: 8e 00 04        LDX    #$0004
5e97: 34 70           PSHS   U,Y,X
5e99: 17 ff d3        LBSR   $5E6F
5e9c: 32 66           LEAS   $6,S
5e9e: f6 24 bf        LDB    $24BF
5ea1: 4f              CLRA
5ea2: 1f 03           TFR    D,U
5ea4: c6 26           LDB    #$26
5ea6: 1d              SEX
5ea7: 1f 02           TFR    D,Y
5ea9: 8e 00 04        LDX    #$0004
5eac: 34 70           PSHS   U,Y,X
5eae: 17 ff be        LBSR   $5E6F
5eb1: 32 66           LEAS   $6,S
5eb3: 32 62           LEAS   $2,S
5eb5: 39              RTS
; Conditional DDS configuration update — $5EB6.
; Checks $23C1 bit 1: if clear, calls $5E7F(0) to update DDS register $26. If set, skips
; the update (DDS configuration already current or updates inhibited).
5eb6: fc e9 f7        LDD    $E9F7
5eb9: 17 1e 94        LBSR   $7D50
5ebc: fc 23 c1        LDD    $23C1
5ebf: 84 00           ANDA   #$00
5ec1: c4 02           ANDB   #$02
5ec3: 10 83 00 00     CMPD   #$0000
5ec7: 10 27 00 03     LBEQ   $5ECE
5ecb: 16 00 09        LBRA   $5ED7
5ece: ce 00 00        LDU    #$0000
5ed1: 34 40           PSHS   U
5ed3: 8d aa           BSR    $5E7F
5ed5: 32 62           LEAS   $2,S
5ed7: 32 62           LEAS   $2,S
5ed9: 39              RTS
; DDS full parameter replay — $5EDA.
; Loops through all 42 key codes (0 to $29), calling $5D3B then $5D9D for each to reprogram
; the entire DDS register set from the current parameter array $248A. Used after parameter
; initialization or bulk changes to synchronize the DDS hardware with RAM state.
5eda: fc e9 f8        LDD    $E9F8
5edd: 17 1e 70        LBSR   $7D50
5ee0: 5f              CLRB
5ee1: 4f              CLRA
5ee2: ed 62           STD    $2,S
5ee4: ae 62           LDX    $2,S
5ee6: 8c 00 2a        CMPX   #$002A
5ee9: 10 24 00 27     LBCC   $5F14
5eed: 33 64           LEAU   $4,S
5eef: 10 ae 62        LDY    $2,S
5ef2: 8e 00 04        LDX    #$0004
5ef5: 34 70           PSHS   U,Y,X
5ef7: 17 fe 41        LBSR   $5D3B
5efa: 32 66           LEAS   $6,S
5efc: ee 64           LDU    $4,S
5efe: 10 ae 62        LDY    $2,S
5f01: 8e 00 04        LDX    #$0004
5f04: 34 70           PSHS   U,Y,X
5f06: 17 fe 94        LBSR   $5D9D
5f09: 32 66           LEAS   $6,S
5f0b: ec 62           LDD    $2,S
5f0d: c3 00 01        ADDD   #$0001
5f10: ed 62           STD    $2,S
5f12: 20 d0           BRA    $5EE4
5f14: 32 66           LEAS   $6,S
5f16: 39              RTS
; DDS parameter RAM initialization — $5F17.
; Clears the parameter array $248A-$24C4 (59 bytes), then loads default values for DDS
; configuration registers ($24B4=$04, $24BF=$0B, $24B6/$B7=$36, $24B5=$0F, $24C0=$5F,
; $24C1=$5E, $24C2=$10, $24BA=$1F). Programs the DDS twice via $5EDA: first with
; $24BB/$24BC=0, then with $24BB/$24BC=$24. Clears system control bits in $2202 and $2204.
5f17: fc e9 fa        LDD    $E9FA
5f1a: 17 1e 33        LBSR   $7D50       ; allocate frame
; Clear parameter array $248A-$24C4 (59 bytes)
5f1d: cc 24 8a        LDD    #$248A      ; pointer = array start
5f20: ed 62           STD    $2,S
5f22: ae 62           LDX    $2,S        ; loop: X = current address
5f24: 8c 24 c4        CMPX   #$24C4      ; past end?
5f27: 10 22 00 0c     LBHI   $5F37       ; yes → load defaults
5f2b: 6f f8 02        CLR    [$02,S]     ; clear byte at [pointer]
5f2e: ec 62           LDD    $2,S
5f30: c3 00 01        ADDD   #$0001      ; pointer++
5f33: ed 62           STD    $2,S
5f35: 20 eb           BRA    $5F22       ; → loop
; Load DDS configuration register defaults
5f37: c6 04           LDB    #$04
5f39: f7 24 b4        STB    $24B4       ; DDS config reg A
5f3c: c6 0b           LDB    #$0B
5f3e: f7 24 bf        STB    $24BF       ; DDS config reg B
5f41: c6 36           LDB    #$36
5f43: f7 24 b6        STB    $24B6       ; DDS freq word high
5f46: c6 36           LDB    #$36
5f48: f7 24 b7        STB    $24B7       ; DDS freq word low
5f4b: c6 0f           LDB    #$0F
5f4d: f7 24 b5        STB    $24B5       ; DDS amplitude/gain
5f50: c6 5f           LDB    #$5F
5f52: f7 24 c0        STB    $24C0       ; DDS control word A
5f55: c6 5e           LDB    #$5E
5f57: f7 24 c1        STB    $24C1       ; DDS control word B
5f5a: c6 10           LDB    #$10
5f5c: f7 24 c2        STB    $24C2       ; DDS control word C
5f5f: c6 1f           LDB    #$1F
5f61: f7 24 ba        STB    $24BA       ; DDS mode select
; First DDS programming pass: zero offset
5f64: 7f 24 bb        CLR    $24BB       ; phase offset A = 0
5f67: 7f 24 bc        CLR    $24BC       ; phase offset B = 0
5f6a: ce 00 00        LDU    #$0000
5f6d: 34 40           PSHS   U
5f6f: 17 ff 68        LBSR   $5EDA       ; → program DDS hardware
5f72: 32 62           LEAS   $2,S
; Second DDS programming pass: $24 offset
5f74: c6 24           LDB    #$24
5f76: f7 24 bb        STB    $24BB       ; phase offset A = $24
5f79: c6 24           LDB    #$24
5f7b: f7 24 bc        STB    $24BC       ; phase offset B = $24
5f7e: ce 00 00        LDU    #$0000
5f81: 34 40           PSHS   U
5f83: 17 ff 54        LBSR   $5EDA       ; → program DDS hardware
5f86: 32 62           LEAS   $2,S
; Clear system control bits
5f88: fc 22 02        LDD    $2202
5f8b: 84 fe           ANDA   #$FE        ; clear bit 8
5f8d: c4 1f           ANDB   #$1F        ; clear bits 5-7
5f8f: fd 22 02        STD    $2202
5f92: fc 22 04        LDD    $2204
5f95: 84 c7           ANDA   #$C7        ; clear bits 11-13
5f97: c4 ff           ANDB   #$FF
5f99: fd 22 04        STD    $2204
5f9c: 32 64           LEAS   $4,S        ; deallocate frame
5f9e: 39              RTS
; DDS output mode selector — $5F9F.
; Selects DDS output configuration based on $2204 bits 11 and 12, and the argument's bits 3
; and 2. Returns the DDS mode code and word count. Maps to: bit 11 set → mode $0A (10),
; bit 12 set → no change needed, arg bit 3 → mode $08/count 3, arg bit 2 → mode $04/count 2,
; default → mode $02/count 1. Calls $5D9D with key $20 for the selected configuration.
5f9f: fc e9 fc        LDD    $E9FC
5fa2: 17 1d ab        LBSR   $7D50
5fa5: fc 22 04        LDD    $2204
5fa8: 84 08           ANDA   #$08
5faa: c4 00           ANDB   #$00
5fac: 10 83 00 00     CMPD   #$0000
5fb0: 10 26 00 07     LBNE   $5FBB
5fb4: 6f 63           CLR    $3,S
5fb6: 6f 62           CLR    $2,S
5fb8: 16 00 56        LBRA   $6011
5fbb: fc 22 04        LDD    $2204
5fbe: 84 10           ANDA   #$10
5fc0: c4 00           ANDB   #$00
5fc2: 10 83 00 00     CMPD   #$0000
5fc6: 10 27 00 09     LBEQ   $5FD3
5fca: c6 0a           LDB    #$0A
5fcc: e7 63           STB    $3,S
5fce: 6f 62           CLR    $2,S
5fd0: 16 00 3e        LBRA   $6011
5fd3: ec e9 00 09     LDD    $0009,S
5fd7: 84 00           ANDA   #$00
5fd9: c4 08           ANDB   #$08
5fdb: 10 83 00 00     CMPD   #$0000
5fdf: 10 27 00 0b     LBEQ   $5FEE
5fe3: c6 08           LDB    #$08
5fe5: e7 63           STB    $3,S
5fe7: c6 03           LDB    #$03
5fe9: e7 62           STB    $2,S
5feb: 16 00 23        LBRA   $6011
5fee: ec e9 00 09     LDD    $0009,S
5ff2: 84 00           ANDA   #$00
5ff4: c4 04           ANDB   #$04
5ff6: 10 83 00 00     CMPD   #$0000
5ffa: 10 27 00 0b     LBEQ   $6009
5ffe: c6 04           LDB    #$04
6000: e7 63           STB    $3,S
6002: c6 02           LDB    #$02
6004: e7 62           STB    $2,S
6006: 16 00 08        LBRA   $6011
6009: c6 02           LDB    #$02
600b: e7 63           STB    $3,S
600d: c6 01           LDB    #$01
600f: e7 62           STB    $2,S
6011: 33 63           LEAU   $3,S
6013: c6 20           LDB    #$20
6015: 1d              SEX
6016: 1f 02           TFR    D,Y
6018: 8e 00 04        LDX    #$0004
601b: 34 70           PSHS   U,Y,X
601d: 17 fd 7d        LBSR   $5D9D
6020: 32 66           LEAS   $6,S
6022: e6 62           LDB    $2,S
6024: e7 64           STB    $4,S
6026: 32 65           LEAS   $5,S
6028: 39              RTS
; DDS channel output programming — $6029.
; Programs the DDS output for a specific channel. Calls $5D3B with key $1F to get the output
; parameter pointer. If $2204 bit 11 is clear, sets it and scans the channel data array $24F5
; to find a channel matching the requested mode, computes a combined output code, and calls
; $5F9F. If $2204 bit 11 is already set, handles special cases for mode values $03 and $0C
; (sets $2204 bit 12 and reconfigures the DDS output routing).
6029: fc ea 04        LDD    $EA04
602c: 17 1d 21        LBSR   $7D50
602f: 33 64           LEAU   $4,S
6031: c6 1f           LDB    #$1F
6033: 1d              SEX
6034: 1f 02           TFR    D,Y
6036: 8e 00 04        LDX    #$0004
6039: 34 70           PSHS   U,Y,X
603b: 17 fc fd        LBSR   $5D3B
603e: 32 66           LEAS   $6,S
6040: e6 f8 04        LDB    [$04,S]
6043: e7 62           STB    $2,S
6045: fc 22 04        LDD    $2204
6048: 84 08           ANDA   #$08
604a: c4 00           ANDB   #$00
604c: 10 83 00 00     CMPD   #$0000
6050: 10 26 00 73     LBNE   $60C7
6054: fc 22 04        LDD    $2204
6057: 8a 08           ORA    #$08
6059: ca 00           ORB    #$00
605b: fd 22 04        STD    $2204
605e: 6f 63           CLR    $3,S
6060: ce 24 f5        LDU    #$24F5
6063: e6 63           LDB    $3,S
6065: 4f              CLRA
6066: 1f 02           TFR    D,Y
6068: 34 60           PSHS   U,Y
606a: 86 01           LDA    #$01
606c: 8e e9 fe        LDX    #$E9FE
606f: 17 1c 78        LBSR   $7CEA
6072: 30 88 21        LEAX   $21,X
6075: ae 84           LDX    ,X
6077: ac e9 00 12     CMPX   $0012,S
607b: 10 27 00 0b     LBEQ   $608A
607f: e6 63           LDB    $3,S
6081: c1 04           CMPB   #$04
6083: 10 24 00 03     LBCC   $608A
6087: 16 00 03        LBRA   $608D
608a: 16 00 08        LBRA   $6095
608d: e6 63           LDB    $3,S
608f: cb 01           ADDB   #$01
6091: e7 63           STB    $3,S
6093: 20 cb           BRA    $6060
6095: 8e 00 01        LDX    #$0001
6098: e6 63           LDB    $3,S
609a: 17 1f 07        LBSR   $7FA4
609d: e7 62           STB    $2,S
609f: 8e 00 01        LDX    #$0001
60a2: e6 e9 00 11     LDB    $0011,S
60a6: 17 1e fb        LBSR   $7FA4
60a9: ed 67           STD    $7,S
60ab: e6 62           LDB    $2,S
60ad: 4f              CLRA
60ae: e3 67           ADDD   $7,S
60b0: e7 62           STB    $2,S
60b2: e6 62           LDB    $2,S
60b4: 4f              CLRA
60b5: 1f 03           TFR    D,U
60b7: 10 8e 00 02     LDY    #$0002
60bb: 34 60           PSHS   U,Y
60bd: 17 fe df        LBSR   $5F9F
60c0: 32 64           LEAS   $4,S
60c2: e7 66           STB    $6,S
60c4: 16 00 92        LBRA   $6159
60c7: ae e9 00 0e     LDX    $000E,S
60cb: 8c 00 01        CMPX   #$0001
60ce: 10 27 00 28     LBEQ   $60FA
60d2: 8e 00 01        LDX    #$0001
60d5: e6 e9 00 11     LDB    $0011,S
60d9: 17 1e c8        LBSR   $7FA4
60dc: ed 67           STD    $7,S
60de: e6 62           LDB    $2,S
60e0: 4f              CLRA
60e1: e3 67           ADDD   $7,S
60e3: e7 62           STB    $2,S
60e5: e6 62           LDB    $2,S
60e7: 4f              CLRA
60e8: 1f 03           TFR    D,U
60ea: 10 8e 00 02     LDY    #$0002
60ee: 34 60           PSHS   U,Y
60f0: 17 fe ac        LBSR   $5F9F
60f3: 32 64           LEAS   $4,S
60f5: e7 66           STB    $6,S
60f7: 16 00 5f        LBRA   $6159
60fa: e6 62           LDB    $2,S
60fc: c1 03           CMPB   #$03
60fe: 10 27 00 0b     LBEQ   $610D
6102: e6 62           LDB    $2,S
6104: c1 0c           CMPB   #$0C
6106: 10 27 00 03     LBEQ   $610D
610a: 16 00 45        LBRA   $6152
610d: fc 22 04        LDD    $2204
6110: 8a 10           ORA    #$10
6112: ca 00           ORB    #$00
6114: fd 22 04        STD    $2204
6117: c6 0f           LDB    #$0F
6119: e7 62           STB    $2,S
611b: ae e9 00 10     LDX    $0010,S
611f: 8c 00 00        CMPX   #$0000
6122: 10 27 00 0e     LBEQ   $6134
6126: ae e9 00 10     LDX    $0010,S
612a: 8c 00 01        CMPX   #$0001
612d: 10 27 00 03     LBEQ   $6134
6131: 16 00 07        LBRA   $613B
6134: c6 01           LDB    #$01
6136: e7 66           STB    $6,S
6138: 16 00 04        LBRA   $613F
613b: c6 03           LDB    #$03
613d: e7 66           STB    $6,S
613f: e6 62           LDB    $2,S
6141: 4f              CLRA
6142: 1f 03           TFR    D,U
6144: 10 8e 00 02     LDY    #$0002
6148: 34 60           PSHS   U,Y
614a: 17 fe 52        LBSR   $5F9F
614d: 32 64           LEAS   $4,S
614f: 16 00 07        LBRA   $6159
6152: c6 01           LDB    #$01
6154: e7 69           STB    $9,S
6156: 16 00 27        LBRA   $6180
6159: e6 66           LDB    $6,S
615b: 4f              CLRA
615c: 1f 03           TFR    D,U
615e: 10 ae e9 00 12  LDY    $0012,S
6163: 8e 00 04        LDX    #$0004
6166: 34 70           PSHS   U,Y,X
6168: 17 e6 45        LBSR   $47B0
616b: 32 66           LEAS   $6,S
616d: 33 62           LEAU   $2,S
616f: c6 1f           LDB    #$1F
6171: 1d              SEX
6172: 1f 02           TFR    D,Y
6174: 8e 00 04        LDX    #$0004
6177: 34 70           PSHS   U,Y,X
6179: 17 fc 21        LBSR   $5D9D
617c: 32 66           LEAS   $6,S
617e: 6f 69           CLR    $9,S
6180: e6 69           LDB    $9,S
6182: 32 6a           LEAS   $A,S
6184: 39              RTS
; DDS output routing reconfiguration — $6185.
; Reads key $1F parameter via $5D3B. If $2204 bit 12 is set, clears it and dispatches based on
; argument (0-3) to select DDS mode codes ($0C or $03) with output counts. If $2204 bit 12 is
; clear but bit 11 set, computes output mode from bit field and calls $5F9F. Finishes by calling
; $47B0 for channel output parameter setup and $5D9D with key $1F for DDS programming.
6185: fc ea 06        LDD    $EA06
6188: 17 1b c5        LBSR   $7D50
618b: 33 63           LEAU   $3,S
618d: c6 1f           LDB    #$1F
618f: 1d              SEX
6190: 1f 02           TFR    D,Y
6192: 8e 00 04        LDX    #$0004
6195: 34 70           PSHS   U,Y,X
6197: 17 fb a1        LBSR   $5D3B
619a: 32 66           LEAS   $6,S
619c: e6 f8 03        LDB    [$03,S]
619f: e7 62           STB    $2,S
61a1: ae e9 00 0c     LDX    $000C,S
61a5: 8c 00 01        CMPX   #$0001
61a8: 10 26 00 c8     LBNE   $6274
61ac: fc 22 04        LDD    $2204
61af: 84 10           ANDA   #$10
61b1: c4 00           ANDB   #$00
61b3: 10 83 00 00     CMPD   #$0000
61b7: 10 27 00 55     LBEQ   $6210
61bb: fc 22 04        LDD    $2204
61be: 84 ef           ANDA   #$EF
61c0: c4 ff           ANDB   #$FF
61c2: fd 22 04        STD    $2204
61c5: ae e9 00 0e     LDX    $000E,S
61c9: 16 00 2a        LBRA   $61F6
61cc: c6 0c           LDB    #$0C
61ce: e7 62           STB    $2,S
61d0: c6 01           LDB    #$01
61d2: e7 65           STB    $5,S
61d4: 16 00 36        LBRA   $620D
61d7: c6 0c           LDB    #$0C
61d9: e7 62           STB    $2,S
61db: 6f 65           CLR    $5,S
61dd: 16 00 2d        LBRA   $620D
61e0: c6 03           LDB    #$03
61e2: e7 62           STB    $2,S
61e4: c6 03           LDB    #$03
61e6: e7 65           STB    $5,S
61e8: 16 00 22        LBRA   $620D
61eb: c6 03           LDB    #$03
61ed: e7 62           STB    $2,S
61ef: c6 02           LDB    #$02
61f1: e7 65           STB    $5,S
61f3: 16 00 17        LBRA   $620D
61f6: 8c 00 00        CMPX   #$0000
61f9: 27 d1           BEQ    $61CC
61fb: 8c 00 01        CMPX   #$0001
61fe: 27 d7           BEQ    $61D7
6200: 8c 00 02        CMPX   #$0002
6203: 27 db           BEQ    $61E0
6205: 8c 00 03        CMPX   #$0003
6208: 27 e1           BEQ    $61EB
620a: 16 00 00        LBRA   $620D
620d: 16 00 51        LBRA   $6261
6210: fc 22 04        LDD    $2204
6213: 84 f7           ANDA   #$F7
6215: c4 ff           ANDB   #$FF
6217: fd 22 04        STD    $2204
621a: 8e 00 01        LDX    #$0001
621d: e6 e9 00 0f     LDB    $000F,S
6221: 17 1d 80        LBSR   $7FA4
6224: ed 66           STD    $6,S
6226: e6 62           LDB    $2,S
6228: 4f              CLRA
6229: a3 66           SUBD   $6,S
622b: e7 62           STB    $2,S
622d: e6 62           LDB    $2,S
622f: 16 00 1a        LBRA   $624C
6232: 6f 65           CLR    $5,S
6234: 16 00 28        LBRA   $625F
6237: c6 01           LDB    #$01
6239: e7 65           STB    $5,S
623b: 16 00 21        LBRA   $625F
623e: c6 02           LDB    #$02
6240: e7 65           STB    $5,S
6242: 16 00 1a        LBRA   $625F
6245: c6 03           LDB    #$03
6247: e7 65           STB    $5,S
6249: 16 00 13        LBRA   $625F
624c: c1 01           CMPB   #$01
624e: 27 e2           BEQ    $6232
6250: c1 02           CMPB   #$02
6252: 27 e3           BEQ    $6237
6254: c1 04           CMPB   #$04
6256: 27 e6           BEQ    $623E
6258: c1 08           CMPB   #$08
625a: 27 e9           BEQ    $6245
625c: 16 00 00        LBRA   $625F
625f: 6f 62           CLR    $2,S
6261: e6 62           LDB    $2,S
6263: 4f              CLRA
6264: 1f 03           TFR    D,U
6266: 10 8e 00 02     LDY    #$0002
626a: 34 60           PSHS   U,Y
626c: 17 fd 30        LBSR   $5F9F
626f: 32 64           LEAS   $4,S
6271: 16 00 25        LBRA   $6299
6274: 8e 00 01        LDX    #$0001
6277: e6 e9 00 0f     LDB    $000F,S
627b: 17 1d 26        LBSR   $7FA4
627e: ed 66           STD    $6,S
6280: e6 62           LDB    $2,S
6282: 4f              CLRA
6283: a3 66           SUBD   $6,S
6285: e7 62           STB    $2,S
6287: e6 62           LDB    $2,S
6289: 4f              CLRA
628a: 1f 03           TFR    D,U
628c: 10 8e 00 02     LDY    #$0002
6290: 34 60           PSHS   U,Y
6292: 17 fd 0a        LBSR   $5F9F
6295: 32 64           LEAS   $4,S
6297: e7 65           STB    $5,S
6299: e6 65           LDB    $5,S
629b: 4f              CLRA
629c: 1f 03           TFR    D,U
629e: 10 ae e9 00 10  LDY    $0010,S
62a3: 8e 00 04        LDX    #$0004
62a6: 34 70           PSHS   U,Y,X
62a8: 17 e5 05        LBSR   $47B0
62ab: 32 66           LEAS   $6,S
62ad: 33 62           LEAU   $2,S
62af: c6 1f           LDB    #$1F
62b1: 1d              SEX
62b2: 1f 02           TFR    D,Y
62b4: 8e 00 04        LDX    #$0004
62b7: 34 70           PSHS   U,Y,X
62b9: 17 fa e1        LBSR   $5D9D
62bc: 32 66           LEAS   $6,S
62be: 32 68           LEAS   $8,S
62c0: 39              RTS
; Channel-indexed DDS frequency parameter write — $62C1.
; Maps a channel index (0-3) to DDS key codes 8-11 ($08-$0B) and calls $5D9D with the
; channel's DDS parameter data at $000A,S. Used to program per-channel frequency tuning words
; into the DDS hardware.
62c1: fc e9 fa        LDD    $E9FA
62c4: 17 1a 89        LBSR   $7D50
62c7: ae e9 00 08     LDX    $0008,S
62cb: 16 00 20        LBRA   $62EE
62ce: cc 00 08        LDD    #$0008
62d1: ed 62           STD    $2,S
62d3: 16 00 2f        LBRA   $6305
62d6: cc 00 09        LDD    #$0009
62d9: ed 62           STD    $2,S
62db: 16 00 27        LBRA   $6305
62de: cc 00 0a        LDD    #$000A
62e1: ed 62           STD    $2,S
62e3: 16 00 1f        LBRA   $6305
62e6: cc 00 0b        LDD    #$000B
62e9: ed 62           STD    $2,S
62eb: 16 00 17        LBRA   $6305
62ee: 8c 00 00        CMPX   #$0000
62f1: 27 db           BEQ    $62CE
62f3: 8c 00 01        CMPX   #$0001
62f6: 27 de           BEQ    $62D6
62f8: 8c 00 02        CMPX   #$0002
62fb: 27 e1           BEQ    $62DE
62fd: 8c 00 03        CMPX   #$0003
6300: 27 e4           BEQ    $62E6
6302: 16 00 00        LBRA   $6305
6305: ee e9 00 0a     LDU    $000A,S
6309: 10 ae 62        LDY    $2,S
630c: 8e 00 04        LDX    #$0004
630f: 34 70           PSHS   U,Y,X
6311: 17 fa 89        LBSR   $5D9D
6314: 32 66           LEAS   $6,S
6316: 32 64           LEAS   $4,S
6318: 39              RTS
; Channel DDS parameter write with conditional mode — $6319.
; If $23C1 bit 3 is set, copies packed 3-byte data directly to local via $537D; if clear,
; subtracts the ROM reference at $EA58 via $53C6. Then calls $62C1 with the result and
; the channel index to program the DDS frequency register.
6319: fc e9 f8        LDD    $E9F8
631c: 17 1a 31        LBSR   $7D50
631f: e6 e9 00 0b     LDB    $000B,S
6323: e7 62           STB    $2,S
6325: fc 23 c1        LDD    $23C1
6328: 84 00           ANDA   #$00
632a: c4 08           ANDB   #$08
632c: 10 83 00 00     CMPD   #$0000
6330: 10 27 00 13     LBEQ   $6347
6334: ee e9 00 0c     LDU    $000C,S
6338: 31 63           LEAY   $3,S
633a: 8e 00 04        LDX    #$0004
633d: 34 70           PSHS   U,Y,X
633f: 17 f0 3b        LBSR   $537D
6342: 32 66           LEAS   $6,S
6344: 16 00 14        LBRA   $635B
6347: 33 63           LEAU   $3,S
6349: 10 ae e9 00 0c  LDY    $000C,S
634e: 8e ea 58        LDX    #$EA58
6351: cc 00 06        LDD    #$0006
6354: 34 76           PSHS   U,Y,X,D
6356: 17 f0 6d        LBSR   $53C6
6359: 32 68           LEAS   $8,S
635b: 33 63           LEAU   $3,S
635d: e6 62           LDB    $2,S
635f: 4f              CLRA
6360: 1f 02           TFR    D,Y
6362: 8e 00 04        LDX    #$0004
6365: 34 70           PSHS   U,Y,X
6367: 17 ff 57        LBSR   $62C1
636a: 32 66           LEAS   $6,S
636c: 32 66           LEAS   $6,S
636e: 39              RTS
; Single-byte DDS register write via key $16 — $636F.
; Wraps a byte argument into the local frame and calls $5D9D with key $16 ($22 decimal) to
; write a single configuration byte to the DDS.
636f: fc e9 fe        LDD    $E9FE
6372: 17 19 db        LBSR   $7D50
6375: e6 e9 00 08     LDB    $0008,S
6379: e7 62           STB    $2,S
637b: 33 62           LEAU   $2,S
637d: c6 16           LDB    #$16
637f: 1d              SEX
6380: 1f 02           TFR    D,Y
6382: 8e 00 04        LDX    #$0004
6385: 34 70           PSHS   U,Y,X
6387: 17 fa 13        LBSR   $5D9D
638a: 32 66           LEAS   $6,S
638c: 32 63           LEAS   $3,S
638e: 39              RTS
; Channel DDS mode/configuration write — $638F.
; Maps a parameter index (1-6) via jump table at $E3DB to a DDS configuration code, then
; maps channel index (0-3) to DDS key $1D or $1E with bit offset. Reads the current parameter
; value via $5D3B, applies the new configuration bits using shift/mask/OR, and writes back via
; $5D9D. Used to update DDS mode settings per channel.
638f: fc ea 04        LDD    $EA04
6392: 17 19 bb        LBSR   $7D50
6395: ae e9 00 10     LDX    $0010,S
6399: 16 00 28        LBRA   $63C4
639c: c6 03           LDB    #$03
639e: e7 62           STB    $2,S
63a0: 16 00 44        LBRA   $63E7
63a3: 6f 62           CLR    $2,S
63a5: 16 00 3f        LBRA   $63E7
63a8: c6 02           LDB    #$02
63aa: e7 62           STB    $2,S
63ac: 16 00 38        LBRA   $63E7
63af: c6 06           LDB    #$06
63b1: e7 62           STB    $2,S
63b3: 16 00 31        LBRA   $63E7
63b6: c6 05           LDB    #$05
63b8: e7 62           STB    $2,S
63ba: 16 00 2a        LBRA   $63E7
63bd: c6 01           LDB    #$01
63bf: e7 62           STB    $2,S
63c1: 16 00 23        LBRA   $63E7
63c4: 8c 00 06        CMPX   #$0006
63c7: 10 2e 00 1c     LBGT   $63E7
63cb: 1f 10           TFR    X,D
63cd: 83 00 01        SUBD   #$0001
63d0: 10 2d 00 13     LBLT   $63E7
63d4: 8e e3 db        LDX    #$E3DB
63d7: 58              ASLB
63d8: 49              ROLA
63d9: 6e 9b           JMP    [D,X]
63db: e3 9c e3        ADDD   [$63C1,PCR]
63de: a3 e3           SUBD   ,--S
63e0: a8 e3           EORA   ,--S
63e2: af e3           STX    ,--S
63e4: b6 e3 bd        LDA    $E3BD
63e7: ae e9 00 0e     LDX    $000E,S
63eb: 16 00 2c        LBRA   $641A
63ee: cc 00 1d        LDD    #$001D
63f1: ed 66           STD    $6,S
63f3: 6f 63           CLR    $3,S
63f5: 16 00 39        LBRA   $6431
63f8: cc 00 1d        LDD    #$001D
63fb: ed 66           STD    $6,S
63fd: c6 03           LDB    #$03
63ff: e7 63           STB    $3,S
6401: 16 00 2d        LBRA   $6431
6404: cc 00 1e        LDD    #$001E
6407: ed 66           STD    $6,S
6409: 6f 63           CLR    $3,S
640b: 16 00 23        LBRA   $6431
640e: cc 00 1e        LDD    #$001E
6411: ed 66           STD    $6,S
6413: c6 03           LDB    #$03
6415: e7 63           STB    $3,S
6417: 16 00 17        LBRA   $6431
641a: 8c 00 00        CMPX   #$0000
641d: 27 cf           BEQ    $63EE
641f: 8c 00 01        CMPX   #$0001
6422: 27 d4           BEQ    $63F8
6424: 8c 00 02        CMPX   #$0002
6427: 27 db           BEQ    $6404
6429: 8c 00 03        CMPX   #$0003
642c: 27 e0           BEQ    $640E
642e: 16 00 00        LBRA   $6431
6431: 33 68           LEAU   $8,S
6433: 10 ae 66        LDY    $6,S
6436: 8e 00 04        LDX    #$0004
6439: 34 70           PSHS   U,Y,X
643b: 17 f8 fd        LBSR   $5D3B
643e: 32 66           LEAS   $6,S
6440: e6 f8 08        LDB    [$08,S]
6443: e7 64           STB    $4,S
6445: e6 63           LDB    $3,S
6447: 50              NEGB
6448: 1d              SEX
6449: 8e 00 38        LDX    #$0038
644c: 17 1b 55        LBSR   $7FA4
644f: e7 65           STB    $5,S
6451: a6 62           LDA    $2,S
6453: e6 63           LDB    $3,S
6455: 17 19 46        LBSR   $7D9E
6458: e7 62           STB    $2,S
645a: e6 64           LDB    $4,S
645c: e4 65           ANDB   $5,S
645e: e7 64           STB    $4,S
6460: e6 64           LDB    $4,S
6462: ea 62           ORB    $2,S
6464: e7 64           STB    $4,S
6466: 33 64           LEAU   $4,S
6468: 10 ae 66        LDY    $6,S
646b: 8e 00 04        LDX    #$0004
646e: 34 70           PSHS   U,Y,X
6470: 17 f9 2a        LBSR   $5D9D
6473: 32 66           LEAS   $6,S
6475: 32 6a           LEAS   $A,S
6477: 39              RTS
; Channel-indexed DDS phase parameter write — $6478.
; Maps channel index (0-3) to DDS key codes $0C-$0F and calls $5D9D with the channel's
; parameter data at $000A,S. Companion to $62C1 — programs a different DDS register set
; (tentatively phase offset or amplitude) than the frequency keys $08-$0B.
6478: fc e9 fa        LDD    $E9FA
647b: 17 18 d2        LBSR   $7D50
647e: ae e9 00 08     LDX    $0008,S
6482: 16 00 20        LBRA   $64A5
6485: cc 00 0c        LDD    #$000C
6488: ed 62           STD    $2,S
648a: 16 00 2f        LBRA   $64BC
648d: cc 00 0d        LDD    #$000D
6490: ed 62           STD    $2,S
6492: 16 00 27        LBRA   $64BC
6495: cc 00 0e        LDD    #$000E
6498: ed 62           STD    $2,S
649a: 16 00 1f        LBRA   $64BC
649d: cc 00 0f        LDD    #$000F
64a0: ed 62           STD    $2,S
64a2: 16 00 17        LBRA   $64BC
64a5: 8c 00 00        CMPX   #$0000
64a8: 27 db           BEQ    $6485
64aa: 8c 00 01        CMPX   #$0001
64ad: 27 de           BEQ    $648D
64af: 8c 00 02        CMPX   #$0002
64b2: 27 e1           BEQ    $6495
64b4: 8c 00 03        CMPX   #$0003
64b7: 27 e4           BEQ    $649D
64b9: 16 00 00        LBRA   $64BC
64bc: 33 e9 00 0a     LEAU   $000A,S
64c0: 10 ae 62        LDY    $2,S
64c3: 8e 00 04        LDX    #$0004
64c6: 34 70           PSHS   U,Y,X
64c8: 17 f8 d2        LBSR   $5D9D
64cb: 32 66           LEAS   $6,S
64cd: 32 64           LEAS   $4,S
64cf: 39              RTS
; Channel DDS sweep/modulation parameter write — $64D0.
; Maps channel index (0-3) to DDS key codes $10-$13, computes a combined parameter from
; arrays at $24C5 and $24CD (channel×2 indexed), adjusts for rounding (adds 8 if bit 3 set),
; right-shifts by 4 via $7FA4, and writes to the DDS via $5D9D. Programs sweep rate or
; modulation depth parameters.
64d0: fc e9 f8        LDD    $E9F8
64d3: 17 18 7a        LBSR   $7D50
64d6: ae e9 00 0a     LDX    $000A,S
64da: 16 00 20        LBRA   $64FD
64dd: cc 00 10        LDD    #$0010
64e0: ed 62           STD    $2,S
64e2: 16 00 2f        LBRA   $6514
64e5: cc 00 11        LDD    #$0011
64e8: ed 62           STD    $2,S
64ea: 16 00 27        LBRA   $6514
64ed: cc 00 12        LDD    #$0012
64f0: ed 62           STD    $2,S
64f2: 16 00 1f        LBRA   $6514
64f5: cc 00 13        LDD    #$0013
64f8: ed 62           STD    $2,S
64fa: 16 00 17        LBRA   $6514
64fd: 8c 00 00        CMPX   #$0000
6500: 27 db           BEQ    $64DD
6502: 8c 00 01        CMPX   #$0001
6505: 27 de           BEQ    $64E5
6507: 8c 00 02        CMPX   #$0002
650a: 27 e1           BEQ    $64ED
650c: 8c 00 03        CMPX   #$0003
650f: 27 e4           BEQ    $64F5
6511: 16 00 00        LBRA   $6514
6514: ec e9 00 0a     LDD    $000A,S
6518: 58              ASLB
6519: 49              ROLA
651a: 8e 24 c5        LDX    #$24C5
651d: 30 8b           LEAX   D,X
651f: ec e9 00 0a     LDD    $000A,S
6523: 58              ASLB
6524: 49              ROLA
6525: ce 24 cd        LDU    #$24CD
6528: 33 cb           LEAU   D,U
652a: ae 84           LDX    ,X
652c: 1f 10           TFR    X,D
652e: e3 c4           ADDD   ,U
6530: ed 64           STD    $4,S
6532: ec 64           LDD    $4,S
6534: 84 00           ANDA   #$00
6536: c4 08           ANDB   #$08
6538: 10 83 00 00     CMPD   #$0000
653c: 10 27 00 07     LBEQ   $6547
6540: ec 64           LDD    $4,S
6542: c3 00 08        ADDD   #$0008
6545: ed 64           STD    $4,S
6547: ae 64           LDX    $4,S
6549: c6 fc           LDB    #$FC
654b: 17 1a 56        LBSR   $7FA4
654e: ed 64           STD    $4,S
6550: 33 64           LEAU   $4,S
6552: 10 ae 62        LDY    $2,S
6555: 8e 00 04        LDX    #$0004
6558: 34 70           PSHS   U,Y,X
655a: 17 f8 40        LBSR   $5D9D
655d: 32 66           LEAS   $6,S
655f: 32 66           LEAS   $6,S
6561: 39              RTS
; Channel DDS frequency write with division by 3600 — $6562.
; For channel 0 with $2202 bit 7 set, clears the parameter to zero. Otherwise divides the
; parameter value at $000A,S by 3600 ($0E10) via $48C6, stores the quotient into $24C5
; (channel×2 indexed array), then calls $64D0 to program the DDS sweep register.
6562: fc e9 fa        LDD    $E9FA
6565: 17 17 e8        LBSR   $7D50
6568: ae e9 00 08     LDX    $0008,S
656c: 8c 00 00        CMPX   #$0000
656f: 10 26 00 12     LBNE   $6585
6573: fc 22 02        LDD    $2202
6576: 84 00           ANDA   #$00
6578: c4 80           ANDB   #$80
657a: 10 83 00 00     CMPD   #$0000
657e: 10 27 00 03     LBEQ   $6585
6582: 16 00 03        LBRA   $6588
6585: 16 00 06        LBRA   $658E
6588: 5f              CLRB
6589: 4f              CLRA
658a: ed e9 00 0a     STD    $000A,S
658e: ec e9 00 08     LDD    $0008,S
6592: 58              ASLB
6593: 49              ROLA
6594: 8e 24 c5        LDX    #$24C5
6597: 30 8b           LEAX   D,X
6599: af 62           STX    $2,S
659b: ee e9 00 0a     LDU    $000A,S
659f: 10 8e 00 02     LDY    #$0002
65a3: 34 60           PSHS   U,Y
65a5: 17 e3 1e        LBSR   $48C6
65a8: 32 64           LEAS   $4,S
65aa: ed f8 02        STD    [$02,S]
65ad: ee e9 00 08     LDU    $0008,S
65b1: 10 8e 00 02     LDY    #$0002
65b5: 34 60           PSHS   U,Y
65b7: 17 ff 16        LBSR   $64D0
65ba: 32 64           LEAS   $4,S
65bc: 32 64           LEAS   $4,S
65be: 39              RTS
; Channel DDS modulation offset write — $65BF.
; Stores the 16-bit parameter at $0008,S into the $24CD array (channel×2 indexed), then calls
; $64D0 to reprogram the DDS sweep/modulation register for the specified channel.
65bf: fc e9 f7        LDD    $E9F7
65c2: 17 17 8b        LBSR   $7D50       ; allocate frame
65c5: ec e9 00 06     LDD    $0006,S     ; D = channel index
65c9: 58              ASLB              ; D *= 2 (word offset)
65ca: 49              ROLA
65cb: 8e 24 cd        LDX    #$24CD      ; X = modulation offset array base
65ce: 30 8b           LEAX   D,X         ; X = &array[channel]
65d0: ec e9 00 08     LDD    $0008,S     ; D = parameter value
65d4: ed 84           STD    ,X          ; store into array
65d6: ee e9 00 06     LDU    $0006,S     ; U = channel index
65da: 10 8e 00 02     LDY    #$0002
65de: 34 60           PSHS   U,Y
65e0: 17 fe ed        LBSR   $64D0       ; → reprogram DDS for this channel
65e3: 32 64           LEAS   $4,S
65e5: 32 62           LEAS   $2,S        ; deallocate frame
65e7: 39              RTS
; Channel DDS waveform/amplitude configuration — $65E8.
; Maps channel index (0-3) to DDS key codes $22-$23 with bit offset. Reads the current
; parameter, applies a bit-field update based on the mode argument ($0C,S) and $2204 bits.
; If mode=$08, sets the corresponding $2202 control bit (bit 6 for ch 0/A, bit 5 for ch B,
; bit 7 for ch 9); otherwise clears it. Programs the DDS via $5D9D with the updated value.
65e8: fc ea 08        LDD    $EA08
65eb: 17 17 62        LBSR   $7D50
65ee: ae e9 00 0d     LDX    $000D,S
65f2: 16 00 2c        LBRA   $6621
65f5: cc 00 22        LDD    #$0022
65f8: ed 65           STD    $5,S
65fa: 6f 62           CLR    $2,S
65fc: 16 00 39        LBRA   $6638
65ff: cc 00 22        LDD    #$0022
6602: ed 65           STD    $5,S
6604: c6 03           LDB    #$03
6606: e7 62           STB    $2,S
6608: 16 00 2d        LBRA   $6638
660b: cc 00 23        LDD    #$0023
660e: ed 65           STD    $5,S
6610: 6f 62           CLR    $2,S
6612: 16 00 23        LBRA   $6638
6615: cc 00 23        LDD    #$0023
6618: ed 65           STD    $5,S
661a: c6 03           LDB    #$03
661c: e7 62           STB    $2,S
661e: 16 00 17        LBRA   $6638
6621: 8c 00 00        CMPX   #$0000
6624: 27 cf           BEQ    $65F5
6626: 8c 00 01        CMPX   #$0001
6629: 27 d4           BEQ    $65FF
662b: 8c 00 02        CMPX   #$0002
662e: 27 db           BEQ    $660B
6630: 8c 00 03        CMPX   #$0003
6633: 27 e0           BEQ    $6615
6635: 16 00 00        LBRA   $6638
6638: 33 67           LEAU   $7,S
663a: 10 ae 65        LDY    $5,S
663d: 8e 00 04        LDX    #$0004
6640: 34 70           PSHS   U,Y,X
6642: 17 f6 f6        LBSR   $5D3B
6645: 32 66           LEAS   $6,S
6647: ae e9 00 0f     LDX    $000F,S
664b: 8c 00 03        CMPX   #$0003
664e: 10 23 00 07     LBLS   $6659
6652: cc 00 04        LDD    #$0004
6655: ed e9 00 0f     STD    $000F,S
6659: e6 f8 07        LDB    [$07,S]
665c: e7 63           STB    $3,S
665e: e6 62           LDB    $2,S
6660: 50              NEGB
6661: 1d              SEX
6662: 8e 00 38        LDX    #$0038
6665: 17 19 3c        LBSR   $7FA4
6668: e7 64           STB    $4,S
666a: ae e9 00 0f     LDX    $000F,S
666e: e6 62           LDB    $2,S
6670: 17 19 31        LBSR   $7FA4
6673: ed e9 00 0f     STD    $000F,S
6677: e6 63           LDB    $3,S
6679: e4 64           ANDB   $4,S
667b: e7 63           STB    $3,S
667d: e6 63           LDB    $3,S
667f: 4f              CLRA
6680: aa e9 00 0f     ORA    $000F,S
6684: ea e9 00 10     ORB    $0010,S
6688: e7 63           STB    $3,S
668a: 33 63           LEAU   $3,S
668c: 10 ae 65        LDY    $5,S
668f: 8e 00 04        LDX    #$0004
6692: 34 70           PSHS   U,Y,X
6694: 17 f7 06        LBSR   $5D9D
6697: 32 66           LEAS   $6,S
6699: 32 69           LEAS   $9,S
669b: 39              RTS
; Channel DDS output mode and system control write — $669C.
; Complex function mapping channel parameter index (at $0009,S) to DDS register keys $17-$1B
; and conditionally setting/clearing $2202 system control bits based on mode ($000C,S). Handles
; multiple parameter types: $07/$0A→key $19 (bit 6 of $2202), $0B→key $18 (bit 5), $09→key $17
; (bit 7), $08→key $1A, $15→key $1B (bit 8 of $2202, with special $04 OR). Default cases fall
; through to key write via $5D9D.
669c: fc e9 fc        LDD    $E9FC
669f: 17 16 ae        LBSR   $7D50
66a2: e6 e9 00 0c     LDB    $000C,S
66a6: e7 64           STB    $4,S
66a8: ae e9 00 09     LDX    $0009,S
66ac: 16 00 b2        LBRA   $6761
66af: cc 00 19        LDD    #$0019
66b2: ed 62           STD    $2,S
66b4: e6 64           LDB    $4,S
66b6: c1 08           CMPB   #$08
66b8: 10 26 00 0d     LBNE   $66C9
66bc: fc 22 02        LDD    $2202
66bf: 8a 00           ORA    #$00
66c1: ca 40           ORB    #$40
66c3: fd 22 02        STD    $2202
66c6: 16 00 0a        LBRA   $66D3
66c9: fc 22 02        LDD    $2202
66cc: 84 ff           ANDA   #$FF
66ce: c4 bf           ANDB   #$BF
66d0: fd 22 02        STD    $2202
66d3: 16 00 b1        LBRA   $6787
66d6: cc 00 18        LDD    #$0018
66d9: ed 62           STD    $2,S
66db: e6 64           LDB    $4,S
66dd: c1 08           CMPB   #$08
66df: 10 26 00 0d     LBNE   $66F0
66e3: fc 22 02        LDD    $2202
66e6: 8a 00           ORA    #$00
66e8: ca 20           ORB    #$20
66ea: fd 22 02        STD    $2202
66ed: 16 00 0a        LBRA   $66FA
66f0: fc 22 02        LDD    $2202
66f3: 84 ff           ANDA   #$FF
66f5: c4 df           ANDB   #$DF
66f7: fd 22 02        STD    $2202
66fa: 16 00 8a        LBRA   $6787
66fd: cc 00 17        LDD    #$0017
6700: ed 62           STD    $2,S
6702: e6 64           LDB    $4,S
6704: c1 08           CMPB   #$08
6706: 10 26 00 0d     LBNE   $6717
670a: fc 22 02        LDD    $2202
670d: 8a 00           ORA    #$00
670f: ca 80           ORB    #$80
6711: fd 22 02        STD    $2202
6714: 16 00 0a        LBRA   $6721
6717: fc 22 02        LDD    $2202
671a: 84 ff           ANDA   #$FF
671c: c4 7f           ANDB   #$7F
671e: fd 22 02        STD    $2202
6721: 16 00 63        LBRA   $6787
6724: cc 00 1a        LDD    #$001A
6727: ed 62           STD    $2,S
6729: 16 00 5b        LBRA   $6787
672c: cc 00 1b        LDD    #$001B
672f: ed 62           STD    $2,S
6731: e6 64           LDB    $4,S
6733: c1 08           CMPB   #$08
6735: 10 26 00 0f     LBNE   $6748
6739: 6f 64           CLR    $4,S
673b: fc 22 02        LDD    $2202
673e: 8a 01           ORA    #$01
6740: ca 00           ORB    #$00
6742: fd 22 02        STD    $2202
6745: 16 00 10        LBRA   $6758
6748: fc 22 02        LDD    $2202
674b: 84 fe           ANDA   #$FE
674d: c4 ff           ANDB   #$FF
674f: fd 22 02        STD    $2202
6752: e6 64           LDB    $4,S
6754: ca 04           ORB    #$04
6756: e7 64           STB    $4,S
6758: 16 00 2c        LBRA   $6787
675b: 16 00 38        LBRA   $6796
675e: 16 00 26        LBRA   $6787
6761: 8c 00 07        CMPX   #$0007
6764: 10 27 ff 47     LBEQ   $66AF
6768: 8c 00 08        CMPX   #$0008
676b: 27 b7           BEQ    $6724
676d: 8c 00 09        CMPX   #$0009
6770: 27 8b           BEQ    $66FD
6772: 8c 00 0a        CMPX   #$000A
6775: 10 27 ff 36     LBEQ   $66AF
6779: 8c 00 0b        CMPX   #$000B
677c: 10 27 ff 56     LBEQ   $66D6
6780: 8c 00 15        CMPX   #$0015
6783: 27 a7           BEQ    $672C
6785: 20 d4           BRA    $675B
6787: 33 64           LEAU   $4,S
6789: 10 ae 62        LDY    $2,S
678c: 8e 00 04        LDX    #$0004
678f: 34 70           PSHS   U,Y,X
6791: 17 f6 09        LBSR   $5D9D
6794: 32 66           LEAS   $6,S
6796: 32 65           LEAS   $5,S
6798: 39              RTS
; DDS all-channel tuning word refresh — $6799.
; Loops through indices 0-15 ($10), calling $5E2E for each to write a complete DDS tuning
; word sequence. Reprograms all 16 DDS channel slots from the current $2581 tuning word array.
6799: fc e9 fe        LDD    $E9FE
679c: 17 15 b1        LBSR   $7D50
679f: 6f 62           CLR    $2,S
67a1: e6 62           LDB    $2,S
67a3: c1 10           CMPB   #$10
67a5: 10 24 00 18     LBCC   $67C1
67a9: e6 62           LDB    $2,S
67ab: 4f              CLRA
67ac: 1f 03           TFR    D,U
67ae: 10 8e 00 02     LDY    #$0002
67b2: 34 60           PSHS   U,Y
67b4: 17 f6 77        LBSR   $5E2E
67b7: 32 64           LEAS   $4,S
67b9: e6 62           LDB    $2,S
67bb: cb 01           ADDB   #$01
67bd: e7 62           STB    $2,S
67bf: 20 e0           BRA    $67A1
67c1: 32 63           LEAS   $3,S
67c3: 39              RTS
; DDS global control word write via key $15 — $67C4.
; Builds a control byte: low nibble from $0009,S masked to 4 bits, bit 4 set if $0007,S is
; non-zero. Writes the result to DDS key $15 ($21 decimal) via $5D9D. Used to update the
; DDS global control/status register.
67c4: fc e9 fe        LDD    $E9FE
67c7: 17 15 86        LBSR   $7D50
67ca: ec e9 00 09     LDD    $0009,S
67ce: 84 00           ANDA   #$00
67d0: c4 0f           ANDB   #$0F
67d2: e7 62           STB    $2,S
67d4: ae e9 00 07     LDX    $0007,S
67d8: 8c 00 00        CMPX   #$0000
67db: 10 27 00 06     LBEQ   $67E5
67df: e6 62           LDB    $2,S
67e1: ca 10           ORB    #$10
67e3: e7 62           STB    $2,S
67e5: 33 62           LEAU   $2,S
67e7: c6 15           LDB    #$15
67e9: 1d              SEX
67ea: 1f 02           TFR    D,Y
67ec: 8e 00 04        LDX    #$0004
67ef: 34 70           PSHS   U,Y,X
67f1: 17 f5 a9        LBSR   $5D9D
67f4: 32 66           LEAS   $6,S
67f6: 32 63           LEAS   $3,S
67f8: 39              RTS
; DDS tuning word array initialization — $67F9.
; Clears the $2581-$2670 tuning word array (240 bytes), then loops through 16 entries
; initializing each: sets offset $0A to '+' ($2B) marker and copies ROM defaults from $EA0A
; descriptor via $7CEA. Establishes the default frequency/phase configuration for all DDS slots.
67f9: fc ea 10        LDD    $EA10
67fc: 17 15 51        LBSR   $7D50
67ff: cc 26 71        LDD    #$2671
6802: ed 64           STD    $4,S
6804: cc 25 81        LDD    #$2581
6807: ed 62           STD    $2,S
6809: ae 62           LDX    $2,S
680b: ac 64           CMPX   $4,S
680d: 10 24 00 0d     LBCC   $681E
6811: ae 62           LDX    $2,S
6813: ec 62           LDD    $2,S
6815: c3 00 01        ADDD   #$0001
6818: ed 62           STD    $2,S
681a: 6f 84           CLR    ,X
681c: 20 eb           BRA    $6809
681e: 6f 66           CLR    $6,S
6820: e6 66           LDB    $6,S
6822: c1 10           CMPB   #$10
6824: 10 24 00 39     LBCC   $6861
6828: ce 25 81        LDU    #$2581
682b: e6 66           LDB    $6,S
682d: 4f              CLRA
682e: 1f 02           TFR    D,Y
6830: 34 60           PSHS   U,Y
6832: 86 01           LDA    #$01
6834: 8e ea 0a        LDX    #$EA0A
6837: 17 14 b0        LBSR   $7CEA
683a: 30 0a           LEAX   $A,X
683c: c6 2b           LDB    #$2B
683e: e7 84           STB    ,X
6840: ce 25 81        LDU    #$2581
6843: e6 66           LDB    $6,S
6845: 4f              CLRA
6846: 1f 02           TFR    D,Y
6848: 34 60           PSHS   U,Y
684a: 86 01           LDA    #$01
684c: 8e ea 0a        LDX    #$EA0A
684f: 17 14 98        LBSR   $7CEA
6852: 30 0d           LEAX   $D,X
6854: cc 00 03        LDD    #$0003
6857: ed 84           STD    ,X
6859: e6 66           LDB    $6,S
685b: cb 01           ADDB   #$01
685d: e7 66           STB    $6,S
685f: 20 bf           BRA    $6820
6861: ce 00 00        LDU    #$0000
6864: 34 40           PSHS   U
6866: 17 ff 30        LBSR   $6799
6869: 32 62           LEAS   $2,S
686b: ce ea 58        LDU    #$EA58
686e: 10 8e 26 71     LDY    #$2671
6872: 8e 00 04        LDX    #$0004
6875: 34 70           PSHS   U,Y,X
6877: 17 eb 03        LBSR   $537D
687a: 32 66           LEAS   $6,S
687c: ce ea 58        LDU    #$EA58
687f: 10 8e 26 74     LDY    #$2674
6883: 8e 00 04        LDX    #$0004
6886: 34 70           PSHS   U,Y,X
6888: 17 ea f2        LBSR   $537D
688b: 32 66           LEAS   $6,S
688d: cc 00 02        LDD    #$0002
6890: fd 26 77        STD    $2677
6893: cc 00 03        LDD    #$0003
6896: fd 26 79        STD    $2679
6899: cc 00 02        LDD    #$0002
689c: fd 26 7b        STD    $267B
689f: 5f              CLRB
68a0: 4f              CLRA
68a1: fd 26 7d        STD    $267D
68a4: 32 67           LEAS   $7,S
68a6: 39              RTS
; Channel packed parameter accumulation — $68A7.
; Maps channel index ($0013,S) to a packed 3-byte parameter at $2492/$2495/$2498/$249B (3 bytes
; each for channels 0-3). Copies to local via $537D, then reads channel mode from $24F5 array
; offset $21: if mode matches $257F, loops 6 times; otherwise 5 times — accumulating via $5392
; (packed add) to compute a scaled parameter value. Returns the 16-bit mantissa result in D.
68a7: fc ea 12        LDD    $EA12
68aa: 17 14 a3        LBSR   $7D50
68ad: ae e9 00 13     LDX    $0013,S
68b1: 16 00 26        LBRA   $68DA
68b4: cc 24 92        LDD    #$2492
68b7: ed 6b           STD    $B,S
68b9: 16 00 34        LBRA   $68F0
68bc: cc 24 95        LDD    #$2495
68bf: ed 6b           STD    $B,S
68c1: 16 00 2c        LBRA   $68F0
68c4: cc 24 98        LDD    #$2498
68c7: ed 6b           STD    $B,S
68c9: 16 00 24        LBRA   $68F0
68cc: cc 24 9b        LDD    #$249B
68cf: ed 6b           STD    $B,S
68d1: 16 00 1c        LBRA   $68F0
68d4: 16 00 86        LBRA   $695D
68d7: 16 00 16        LBRA   $68F0
68da: 8c 00 00        CMPX   #$0000
68dd: 27 d5           BEQ    $68B4
68df: 8c 00 01        CMPX   #$0001
68e2: 27 d8           BEQ    $68BC
68e4: 8c 00 02        CMPX   #$0002
68e7: 27 db           BEQ    $68C4
68e9: 8c 00 03        CMPX   #$0003
68ec: 27 de           BEQ    $68CC
68ee: 20 e4           BRA    $68D4
68f0: ee 6b           LDU    $B,S
68f2: 31 68           LEAY   $8,S
68f4: 8e 00 04        LDX    #$0004
68f7: 34 70           PSHS   U,Y,X
68f9: 17 ea 81        LBSR   $537D
68fc: 32 66           LEAS   $6,S
68fe: 33 68           LEAU   $8,S
6900: 31 65           LEAY   $5,S
6902: 8e 00 04        LDX    #$0004
6905: 34 70           PSHS   U,Y,X
6907: 17 ea 73        LBSR   $537D
690a: 32 66           LEAS   $6,S
690c: ce 24 f5        LDU    #$24F5
690f: 10 ae e9 00 13  LDY    $0013,S
6914: 34 60           PSHS   U,Y
6916: 86 01           LDA    #$01
6918: 8e e9 fe        LDX    #$E9FE
691b: 17 13 cc        LBSR   $7CEA
691e: 30 88 21        LEAX   $21,X
6921: ae 84           LDX    ,X
6923: bc 25 7f        CMPX   $257F
6926: 10 26 00 07     LBNE   $6931
692a: c6 07           LDB    #$07
692c: e7 62           STB    $2,S
692e: 16 00 04        LBRA   $6935
6931: c6 06           LDB    #$06
6933: e7 62           STB    $2,S
6935: e6 62           LDB    $2,S
6937: c0 01           SUBB   #$01
6939: e7 62           STB    $2,S
693b: e6 62           LDB    $2,S
693d: c1 00           CMPB   #$00
693f: 10 23 00 12     LBLS   $6955
6943: 33 65           LEAU   $5,S
6945: 31 65           LEAY   $5,S
6947: 30 68           LEAX   $8,S
6949: cc 00 06        LDD    #$0006
694c: 34 76           PSHS   U,Y,X,D
694e: 17 ea 41        LBSR   $5392
6951: 32 68           LEAS   $8,S
6953: 20 e0           BRA    $6935
6955: ec 65           LDD    $5,S
6957: ed 63           STD    $3,S
6959: ec 63           LDD    $3,S
695b: ed 6d           STD    $D,S
695d: ec 6d           LDD    $D,S
695f: 32 6f           LEAS   $F,S
6961: 39              RTS
; DDS tuning word maximum search — $6962.
; Initializes $24D5 from ROM default $EA58. Loops through 16 DDS tuning word entries, selecting
; offset $04 (if arg $000E,S = 6) or offset $07 (otherwise) from each $EA0A-described entry in
; the $2581 array. Subtracts each from $24D5 via $53C6: if borrow occurs, copies the larger
; value to $24D5. Effectively finds the maximum packed parameter across all DDS slots.
6962: fc ea 04        LDD    $EA04
6965: 17 13 e8        LBSR   $7D50
6968: ce ea 58        LDU    #$EA58
696b: 10 8e 24 d5     LDY    #$24D5
696f: 8e 00 04        LDX    #$0004
6972: 34 70           PSHS   U,Y,X
6974: 17 ea 06        LBSR   $537D
6977: 32 66           LEAS   $6,S
6979: 6f 67           CLR    $7,S
697b: e6 67           LDB    $7,S
697d: c1 10           CMPB   #$10
697f: 10 24 00 6a     LBCC   $69ED
6983: ae e9 00 0e     LDX    $000E,S
6987: 8c 00 06        CMPX   #$0006
698a: 10 26 00 19     LBNE   $69A7
698e: ce 25 81        LDU    #$2581
6991: e6 67           LDB    $7,S
6993: 4f              CLRA
6994: 1f 02           TFR    D,Y
6996: 34 60           PSHS   U,Y
6998: 86 01           LDA    #$01
699a: 8e ea 0a        LDX    #$EA0A
699d: 17 13 4a        LBSR   $7CEA
69a0: 30 04           LEAX   $4,X
69a2: af 65           STX    $5,S
69a4: 16 00 16        LBRA   $69BD
69a7: ce 25 81        LDU    #$2581
69aa: e6 67           LDB    $7,S
69ac: 4f              CLRA
69ad: 1f 02           TFR    D,Y
69af: 34 60           PSHS   U,Y
69b1: 86 01           LDA    #$01
69b3: 8e ea 0a        LDX    #$EA0A
69b6: 17 13 31        LBSR   $7CEA
69b9: 30 07           LEAX   $7,X
69bb: af 65           STX    $5,S
69bd: 33 62           LEAU   $2,S
69bf: 10 ae 65        LDY    $5,S
69c2: 8e 24 d5        LDX    #$24D5
69c5: cc 00 06        LDD    #$0006
69c8: 34 76           PSHS   U,Y,X,D
69ca: 17 e9 f9        LBSR   $53C6
69cd: 32 68           LEAS   $8,S
69cf: c1 00           CMPB   #$00
69d1: 10 27 00 10     LBEQ   $69E5
69d5: ee 65           LDU    $5,S
69d7: 10 8e 24 d5     LDY    #$24D5
69db: 8e 00 04        LDX    #$0004
69de: 34 70           PSHS   U,Y,X
69e0: 17 e9 9a        LBSR   $537D
69e3: 32 66           LEAS   $6,S
69e5: e6 67           LDB    $7,S
69e7: cb 01           ADDB   #$01
69e9: e7 67           STB    $7,S
69eb: 20 8e           BRA    $697B
69ed: 8e 24 d5        LDX    #$24D5
69f0: af 68           STX    $8,S
69f2: 1f 10           TFR    X,D
69f4: 32 6a           LEAS   $A,S
69f6: 39              RTS
69f7: 00 00           NEG    <$00
69f9: 04 00           LSR    <$00
69fb: 02 00           XNC    <$00
69fd: 03 00           COM    <$00
69ff: 01 00           NEG    <$00
6a01: 00 00           NEG    <$00
6a03: 23 00           BLS    $6A05
6a05: 08 00           ASL    <$00
6a07: 06 00           ROR    <$00
6a09: 07 00           ASR    <$00
6a0b: 01 00           NEG    <$00
6a0d: 00 00           NEG    <$00
6a0f: 0f 00           CLR    <$00
6a11: 05 00           LSR    <$00
6a13: 0d d6           TST    <$D6
6a15: 06 09           ROR    <$09
6a17: 08 1c           ASL    <$1C
6a19: 08 08           ASL    <$08
6a1b: 00 1f           NEG    <$1F
6a1d: 04 0c           LSR    <$0C
6a1f: 04 04           LSR    <$04
6a21: 04 0e           LSR    <$0E
6a23: 00 1f           NEG    <$1F
6a25: 0c 12           INC    <$12
6a27: 04 08           LSR    <$08
6a29: 10 1e 00        EXG    D,D
6a2c: 1f 1e           TFR    X,inv
6a2e: 02 04           XNC    <$04
6a30: 02 12           XNC    <$12
6a32: 0c 00           INC    <$00
6a34: 1f 10           TFR    X,D
6a36: 14              XHCF
6a37: 14              XHCF
6a38: 1e 04           EXG    D,S
6a3a: 04 00           LSR    <$00
6a3c: 1f 01           TFR    D,X
6a3e: 0e 13           JMP    <$13
6a40: 15              XHCF
6a41: 19              DAA
6a42: 0e 10           JMP    <$10
6a44: 00 00           NEG    <$00
6a46: 00 09           NEG    <$09
6a48: 09 09           ROL    <$09
6a4a: 0f 11           CLR    <$11
6a4c: 00 00           NEG    <$00
6a4e: 10 03 14        COM    <$14
6a51: 12              NOP
6a52: 11 16 00 5b     LBRA   $6AB1
6a56: 8d 80           BSR    $69D8
6a58: 00 00           NEG    <$00
6a5a: 00 0e           NEG    <$0E
6a5c: 0f 18           CLR    <$18
6a5e: 8a 07           ORA    #$07
6a60: a1 20           CMPA   $0,Y
6a62: 98 96           EORA   <$96
6a64: 80 5b           SUBA   #$5B
6a66: 8d 80           BSR    $69E8
6a68: 00 07           NEG    <$07
6a6a: 07 00           ASR    <$00
6a6c: 0c 44           INC    <$44
6a6e: 00 03           NEG    <$03
6a70: e8 21           EORB   $1,Y
6a72: 48              ASLA
6a73: 61 72           NEG    -$E,S
6a75: 64 77           LSR    -$9,S
6a77: 61 72           NEG    -$E,S
6a79: 65 20           LSR    $0,Y
6a7b: 65 72           LSR    -$E,S
6a7d: 72 6f 72        XNC    $6F72
6a80: 20 20           BRA    $6AA2
6a82: 20 20           BRA    $6AA4
6a84: 72 65 70        XNC    $6570
6a87: 6f 72           CLR    -$E,S
6a89: 74 65 64        LSR    $6564
6a8c: 20 6f           BRA    $6AFD
6a8e: 6e 20           JMP    $0,Y
6a90: 70 6f 77        NEG    $6F77
6a93: 65 72           LSR    -$E,S
6a95: 20 75           BRA    $6B0C
6a97: 70 21 46        NEG    $2146
6a9a: 69 72           ROL    -$E,S
6a9c: 6d 77           TST    -$9,S
6a9e: 61 72           NEG    -$E,S
6aa0: 65 20           LSR    $0,Y
6aa2: 52              XNCB
6aa3: 65 76           LSR    -$A,S
6aa5: 69 73           ROL    -$D,S
6aa7: 69 6f           ROL    $F,S
6aa9: 6e 20           JMP    $0,Y
6aab: 32 37           LEAS   -$9,Y
6aad: 38 38           XANDCC #$38
6aaf: 37 41           PULU   CC,S
6ab1: 20 53           BRA    $6B06
6ab3: 65 72           LSR    -$E,S
6ab5: 69 61           ROL    $1,S
6ab7: 6c 20           INC    $0,Y
6ab9: 4e              XCLRA
6aba: 6f 20           CLR    $0,Y
6abc: 2a 20           BPL    $6ADE
6abe: 20 20           BRA    $6AE0
6ac0: 20 48           BRA    $6B0A
6ac2: 50              NEGB
6ac3: 20 38           BRA    $6AFD
6ac5: 39              RTS
6ac6: 30 34           LEAX   -$C,Y
6ac8: 41              NEGA
6ac9: 20 20           BRA    $6AEB
6acb: 4d              TSTA
6acc: 61 69           NEG    $9,S
6ace: 6e 20           JMP    $0,Y
6ad0: 53              COMB
6ad1: 65 6c           LSR    $C,S
6ad3: 65 63           LSR    $3,S
6ad5: 74 69 6f        LSR    $696F
6ad8: 6e 20           JMP    $0,Y
6ada: 4c              INCA
6adb: 65 76           LSR    -$A,S
6add: 65 6c           LSR    $C,S
6adf: 20 20           BRA    $6B01
6ae1: 20 20           BRA    $6B03
6ae3: 2a 3f           BPL    $6B24
6ae5: 20 4e           BRA    $6B35
6ae7: 6f 20           CLR    $0,Y
6ae9: 44              LSRA
6aea: 61 74           NEG    -$C,S
6aec: 61 20           NEG    $0,Y
6aee: 3f              SWI
6aef: 0d 0a           TST    <$0A
6af1: 48              ASLA
6af2: 50              NEGB
6af3: 2d 49           BLT    $6B3E
6af5: 42              XNCA
6af6: 20 41           BRA    $6B39
6af8: 64 64           LSR    $4,S
6afa: 72 65 73        XNC    $6573
6afd: 73 20 3d        COM    $203D
6b00: 20 20           BRA    $6B22
6b02: 20 20           BRA    $6B24
6b04: 20 20           BRA    $6B26
6b06: 20 20           BRA    $6B28
6b08: 20 30           BRA    $6B3A
6b0a: 20 2d           BRA    $6B39
6b0c: 20 33           BRA    $6B41
6b0e: 30 20           LEAX   $0,Y
6b10: 41              NEGA
6b11: 72 65 20        XNC    $6520
6b14: 56              RORB
6b15: 61 6c           NEG    $C,S
6b17: 69 64           ROL    $4,S
6b19: 45              LSRA
6b1a: 6e 74           JMP    -$C,S
6b1c: 65 72           LSR    -$E,S
6b1e: 20 6e           BRA    $6B8E
6b20: 65 77           LSR    -$9,S
6b22: 20 61           BRA    $6B85
6b24: 64 64           LSR    $4,S
6b26: 72 65 73        XNC    $6573
6b29: 73 20 61        COM    $2061
6b2c: 6e 64           JMP    $4,S
6b2e: 2f 6f           BLE    $6B9F
6b30: 72 20 20        XNC    $2020
6b33: 45              LSRA
6b34: 4e              XCLRA
6b35: 54              LSRB
6b36: 45              LSRA
6b37: 52              XNCB
6b38: 20 20           BRA    $6B5A
6b3a: 74 6f 20        LSR    $6F20
6b3d: 65 78           LSR    -$8,S
6b3f: 69 74           ROL    -$C,S
6b41: 20 20           BRA    $6B63
6b43: 53              COMB
6b44: 61 76           NEG    -$A,S
6b46: 65 20           LSR    $0,Y
6b48: 52              XNCB
6b49: 65 67           LSR    $7,S
6b4b: 69 73           ROL    -$D,S
6b4d: 74 65 72        LSR    $6572
6b50: 20 20           BRA    $6B72
6b52: 20 3f           BRA    $6B93
6b54: 20 20           BRA    $6B76
6b56: 20 30           BRA    $6B88
6b58: 20 2d           BRA    $6B87
6b5a: 20 31           BRA    $6B8D
6b5c: 31 20           LEAY   $0,Y
6b5e: 41              NEGA
6b5f: 72 65 20        XNC    $6520
6b62: 56              RORB
6b63: 61 6c           NEG    $C,S
6b65: 69 64           ROL    $4,S
6b67: 20 20           BRA    $6B89
6b69: 20 20           BRA    $6B8B
6b6b: 52              XNCB
6b6c: 65 63           LSR    $3,S
6b6e: 61 6c           NEG    $C,S
6b70: 6c 20           INC    $0,Y
6b72: 52              XNCB
6b73: 65 67           LSR    $7,S
6b75: 69 73           ROL    -$D,S
6b77: 74 65 72        LSR    $6572
6b7a: 20 3f           BRA    $6BBB
6b7c: 20 20           BRA    $6B9E
6b7e: 20 30           BRA    $6BB0
6b80: 20 2d           BRA    $6BAF
6b82: 20 31           BRA    $6BB5
6b84: 31 20           LEAY   $0,Y
6b86: 41              NEGA
6b87: 72 65 20        XNC    $6520
6b8a: 56              RORB
6b8b: 61 6c           NEG    $C,S
6b8d: 69 64           ROL    $4,S
6b8f: 20 20           BRA    $6BB1
6b91: 20 20           BRA    $6BB3
6b93: 45              LSRA
6b94: 6e 74           JMP    -$C,S
6b96: 65 72           LSR    -$E,S
6b98: 20 72           BRA    $6C0C
6b9a: 65 67           LSR    $7,S
6b9c: 69 73           ROL    -$D,S
6b9e: 74 65 72        LSR    $6572
6ba1: 20 6e           BRA    $6C11
6ba3: 75 6d 62        LSR    $6D62
6ba6: 65 72           LSR    -$E,S
6ba8: 20 61           BRA    $6C0B
6baa: 6e 64           JMP    $4,S
6bac: 2f 6f           BLE    $6C1D
6bae: 72 20 20        XNC    $2020
6bb1: 45              LSRA
6bb2: 4e              XCLRA
6bb3: 54              LSRB
6bb4: 45              LSRA
6bb5: 52              XNCB
6bb6: 20 20           BRA    $6BD8
6bb8: 20 4f           BRA    $6C09
6bba: 75 74 70        LSR    $7470
6bbd: 75 74 20        LSR    $7420
6bc0: 4f              CLRA
6bc1: 6e 2f           JMP    $F,Y
6bc3: 4f              CLRA
6bc4: 66 66           ROR    $6,S
6bc6: 20 43           BRA    $6C0B
6bc8: 6f 6e           CLR    $E,S
6bca: 74 72 6f        LSR    $726F
6bcd: 6c 4f           INC    $F,U
6bcf: 75 74 70        LSR    $7470
6bd2: 75 74 20        LSR    $7420
6bd5: 46              RORA
6bd6: 6c 6f           INC    $F,S
6bd8: 61 74           NEG    -$C,S
6bda: 20 43           BRA    $6C1F
6bdc: 6f 6e           CLR    $E,S
6bde: 74 72 6f        LSR    $726F
6be1: 6c 20           INC    $0,Y
6be3: 20 20           BRA    $6C05
6be5: 20 45           BRA    $6C2C
6be7: 6e 74           JMP    -$C,S
6be9: 65 72           LSR    -$E,S
6beb: 20 6f           BRA    $6C5C
6bed: 75 74 70        LSR    $7470
6bf0: 75 74 20        LSR    $7420
6bf3: 6e 75           JMP    -$B,S
6bf5: 6d 62           TST    $2,S
6bf7: 65 72           LSR    -$E,S
6bf9: 20 3d           BRA    $6C38
6bfb: 20 20           BRA    $6C1D
6bfd: 20 61           BRA    $6C60
6bff: 6e 64           JMP    $4,S
6c01: 20 4f           BRA    $6C52
6c03: 4e              XCLRA
6c04: 2f 4f           BLE    $6C55
6c06: 46              RORA
6c07: 46              RORA
6c08: 20 20           BRA    $6C2A
6c0a: 20 4f           BRA    $6C5B
6c0c: 75 74 70        LSR    $7470
6c0f: 75 74 20        LSR    $7420
6c12: 20 20           BRA    $6C34
6c14: 50              NEGB
6c15: 72 65 73        XNC    $6573
6c18: 65 6e           LSR    $E,S
6c1a: 74 20 46        LSR    $2046
6c1d: 69 6c           ROL    $C,S
6c1f: 74 65 72        LSR    $6572
6c22: 20 3d           BRA    $6C61
6c24: 20 20           BRA    $6C46
6c26: 20 20           BRA    $6C48
6c28: 20 20           BRA    $6C4A
6c2a: 20 20           BRA    $6C4C
6c2c: 20 20           BRA    $6C4E
6c2e: 20 20           BRA    $6C50
6c30: 20 20           BRA    $6C52
6c32: 20 00           BRA    $6C34
6c34: 01 20           NEG    <$20
6c36: 46              RORA
6c37: 69 6c           ROL    $C,S
6c39: 74 65 72        LSR    $6572
6c3c: 20 53           BRA    $6C91
6c3e: 65 6c           LSR    $C,S
6c40: 65 63           LSR    $3,S
6c42: 74 20 3d        LSR    $203D
6c45: 20 20           BRA    $6C67
6c47: 20 20           BRA    $6C69
6c49: 20 20           BRA    $6C6B
6c4b: 20 20           BRA    $6C6D
6c4d: 20 20           BRA    $6C6F
6c4f: 20 20           BRA    $6C71
6c51: 20 20           BRA    $6C73
6c53: 20 00           BRA    $6C55
6c55: 04 20           LSR    <$20
6c57: 45              LSRA
6c58: 78 69 74        ASL    $6974
6c5b: 41              NEGA
6c5c: 75 74 6f        LSR    $746F
6c5f: 6d 61           TST    $1,S
6c61: 74 69 63        LSR    $6963
6c64: 20 20           BRA    $6C86
6c66: 20 20           BRA    $6C88
6c68: 20 53           BRA    $6CBD
6c6a: 68 61           ASL    $1,S
6c6c: 72 70 20        XNC    $7020
6c6f: 43              COMA
6c70: 75 74 6f        LSR    $746F
6c73: 66 66           ROR    $6,S
6c75: 20 20           BRA    $6C97
6c77: 4c              INCA
6c78: 6f 77           CLR    -$9,S
6c7a: 20 4f           BRA    $6CCB
6c7c: 76 65 72        ROR    $6572
6c7f: 73 68 6f        COM    $686F
6c82: 6f 74           CLR    -$C,S
6c84: 20 48           BRA    $6CCE
6c86: 50              NEGB
6c87: 20 38           BRA    $6CC1
6c89: 39              RTS
6c8a: 30 34           LEAX   -$C,Y
6c8c: 41              NEGA
6c8d: 20 46           BRA    $6CD5
6c8f: 69 72           ROL    -$E,S
6c91: 6d 77           TST    -$9,S
6c93: 61 72           NEG    -$E,S
6c95: 65 20           LSR    $0,Y
6c97: 43              COMA
6c98: 6f 70           CLR    -$10,S
6c9a: 79 72 69        ROL    $7269
6c9d: 67 68           ASR    $8,S
6c9f: 74 20 31        LSR    $2031
6ca2: 39              RTS
6ca3: 38 37           XANDCC #$37
6ca5: 20 48           BRA    $6CEF
6ca7: 65 77           LSR    -$9,S
6ca9: 6c 65           INC    $5,S
6cab: 74 74 50        LSR    $7450
6cae: 61 63           NEG    $3,S
6cb0: 6b 61           XDEC   $1,S
6cb2: 72 64 20        XNC    $6420
6cb5: 43              COMA
6cb6: 6f 72           CLR    -$E,S
6cb8: 70 2e 20        NEG    $2E20
6cbb: 32 37           LEAS   -$9,Y
6cbd: 38 38           XANDCC #$38
6cbf: 37 41           PULU   CC,S
6cc1: 52              XNCB
6cc2: 61 6d           NEG    $D,S
6cc4: 20 43           BRA    $6D09
6cc6: 6f 6e           CLR    $E,S
6cc8: 74 65 6e        LSR    $656E
6ccb: 74 73 20        LSR    $7320
6cce: 77 65 72        ASR    $6572
6cd1: 65 20           LSR    $0,Y
6cd3: 66 6f           ROR    $F,S
6cd5: 75 6e 64        LSR    $6E64
6cd8: 20 69           BRA    $6D43
6cda: 6e 76           JMP    -$A,S
6cdc: 61 6c           NEG    $C,S
6cde: 69 64           ROL    $4,S
6ce0: 21 20           BRN    $6D02
6ce2: 20 43           BRA    $6D27
6ce4: 68 65           ASL    $5,S
6ce6: 63 6b           COM    $B,S
6ce8: 20 42           BRA    $6D2C
6cea: 61 74           NEG    -$C,S
6cec: 74 65 72        LSR    $6572
6cef: 79 21 20        ROL    $2120
6cf2: 20 44           BRA    $6D38
6cf4: 65 66           LSR    $6,S
6cf6: 61 75           NEG    -$B,S
6cf8: 6c 74           INC    -$C,S
6cfa: 20 76           BRA    $6D72
6cfc: 61 6c           NEG    $C,S
6cfe: 75 65 73        LSR    $6573
6d01: 20 77           BRA    $6D7A
6d03: 65 72           LSR    -$E,S
6d05: 65 20           LSR    $0,Y
6d07: 69 6e           ROL    $E,S
6d09: 73 74 61        COM    $7461
6d0c: 6c 6c           INC    $C,S
6d0e: 65 64           LSR    $4,S
6d10: 2e 20           BGT    $6D32
6d12: 20 20           BRA    $6D34
6d14: 20 20           BRA    $6D36
6d16: 20 20           BRA    $6D38
6d18: 20 20           BRA    $6D3A
6d1a: 20 20           BRA    $6D3C
6d1c: 20 20           BRA    $6D3E
6d1e: 20 20           BRA    $6D40
6d20: 20 20           BRA    $6D42
6d22: 20 20           BRA    $6D44
6d24: 20 20           BRA    $6D46
6d26: 20 20           BRA    $6D48
6d28: 20 20           BRA    $6D4A
6d2a: 20 20           BRA    $6D4C
6d2c: 20 20           BRA    $6D4E
6d2e: 20 20           BRA    $6D50
6d30: 20 20           BRA    $6D52
6d32: 20 20           BRA    $6D54
6d34: 20 20           BRA    $6D56
6d36: 20 20           BRA    $6D58
6d38: 20 ff           BRA    $6D39
6d3a: ff ff ff        STU    $FFFF
6d3d: ff ff ff        STU    $FFFF
6d40: ff ff ff        STU    $FFFF
6d43: ff ff ff        STU    $FFFF
6d46: ff ff ff        STU    $FFFF
6d49: ff ff ff        STU    $FFFF
6d4c: ff ff ff        STU    $FFFF
6d4f: ff ff ff        STU    $FFFF
6d52: ff ff ff        STU    $FFFF
6d55: ff ff ff        STU    $FFFF
6d58: ff ff ff        STU    $FFFF
6d5b: ff ff ff        STU    $FFFF
6d5e: ff ff ff        STU    $FFFF
6d61: 2a 20           BPL    $6D83
6d63: 20 4c           BRA    $6DB1
6d65: 61 73           NEG    -$D,S
6d67: 74 20 72        LSR    $2072
6d6a: 65 70           LSR    -$10,S
6d6c: 6f 72           CLR    -$E,S
6d6e: 74 65 64        LSR    $6564
6d71: 20 65           BRA    $6DD8
6d73: 72 72 6f        XNC    $726F
6d76: 72 20 77        XNC    $2077
6d79: 61 73           NEG    -$D,S
6d7b: 20 6e           BRA    $6DEB
6d7d: 6f 2e           CLR    $E,Y
6d7f: 20 20           BRA    $6DA1
6d81: 20 20           BRA    $6DA3
6d83: 20 20           BRA    $6DA5
6d85: 20 20           BRA    $6DA7
6d87: 20 2a           BRA    $6DB3
6d89: 00 27           NEG    <$27
6d8b: 10 00 02        NEG    <$02
6d8e: 00 03           NEG    <$03
6d90: e8 00           EORB   $0,X
6d92: 02 00           XNC    <$00
6d94: 00 8c           NEG    <$8C
6d96: 00 07           NEG    <$07
6d98: 00 00           NEG    <$00
6d9a: 01 00           NEG    <$00
6d9c: 07 2b           ASR    <$2B
6d9e: 00 00           NEG    <$00
6da0: 00 00           NEG    <$00
6da2: 00 03           NEG    <$03
6da4: 00 0a           NEG    <$0A
6da6: 00 12           NEG    <$12
6da8: 00 01           NEG    <$01
6daa: 00 10           NEG    <$10
6dac: 00 27           NEG    <$27
6dae: 10 00 02        NEG    <$02
6db1: 00 03           NEG    <$03
6db3: e8 00           EORB   $0,X
6db5: 02 00           XNC    <$00
6db7: 00 00           NEG    <$00
6db9: 00 0d           NEG    <$0D
6dbb: 00 00           NEG    <$00
6dbd: 00 00           NEG    <$00
6dbf: 0d 2b           TST    <$2B
6dc1: 00 00           NEG    <$00
6dc3: 00 00           NEG    <$00
6dc5: 00 03           NEG    <$03
6dc7: 00 0a           NEG    <$0A
6dc9: 00 12           NEG    <$12
6dcb: 00 01           NEG    <$01
6dcd: 00 10           NEG    <$10
6dcf: 21 21           BRN    $6DF2
6dd1: 20 52           BRA    $6E25
6dd3: 65 66           LSR    $6,S
6dd5: 65 72           LSR    -$E,S
6dd7: 65 6e           LSR    $E,S
6dd9: 63 65           COM    $5,S
6ddb: 20 4c           BRA    $6E29
6ddd: 6f 6f           CLR    $F,S
6ddf: 70 20 52        NEG    $2052
6de2: 65 70           LSR    -$10,S
6de4: 6f 72           CLR    -$E,S
6de6: 74 73 20        LSR    $7320
6de9: 4f              CLRA
6dea: 75 74 20        LSR    $7420
6ded: 4f              CLRA
6dee: 66 20           ROR    $0,Y
6df0: 4c              INCA
6df1: 6f 63           CLR    $3,S
6df3: 6b 20           XDEC   $0,Y
6df5: 21 21           BRN    $6E18
6df7: 52              XNCB
6df8: 65 76           LSR    -$A,S
6dfa: 65 72           LSR    -$E,S
6dfc: 73 65 20        COM    $6520
6dff: 50              NEGB
6e00: 6f 77           CLR    -$9,S
6e02: 65 72           LSR    -$E,S
6e04: 20 52           BRA    $6E58
6e06: 65 6c           LSR    $C,S
6e08: 61 79           NEG    -$7,S
6e0a: 20 54           BRA    $6E60
6e0c: 72 69 70        XNC    $6970
6e0f: 70 65 64        NEG    $6564
6e12: 20 6f           BRA    $6E83
6e14: 6e 20           JMP    $0,Y
6e16: 4f              CLRA
6e17: 75 74 70        LSR    $7470
6e1a: 75 74 20        LSR    $7420
6e1d: 20 20           BRA    $6E3F
6e1f: 50              NEGB
6e20: 72 65 73        XNC    $6573
6e23: 73 20 61        COM    $2061
6e26: 6e 79           JMP    -$7,S
6e28: 20 6b           BRA    $6E95
6e2a: 65 79           LSR    -$7,S
6e2c: 20 74           BRA    $6EA2
6e2e: 6f 20           CLR    $0,Y
6e30: 72 65 73        XNC    $6573
6e33: 65 74           LSR    -$C,S
6e35: 20 61           BRA    $6E98
6e37: 6e 64           JMP    $4,S
6e39: 20 63           BRA    $6E9E
6e3b: 6f 6e           CLR    $E,S
6e3d: 74 69 6e        LSR    $696E
6e40: 75 65 2e        LSR    $652E
6e43: 20 20           BRA    $6E65
6e45: 20 20           BRA    $6E67
6e47: 4c              INCA
6e48: 50              NEGB
6e49: 05 98           LSR    <$98
6e4b: 96 80           LDA    <$80
6e4d: 0f 42           CLR    <$42
6e4f: 40              NEGA
6e50: 01 86           NEG    <$86
6e52: a0 00           SUBA   $0,X
6e54: 27 10           BEQ    $6E66
6e56: 00 03           NEG    <$03
6e58: e8 00           EORB   $0,X
6e5a: 00 64           NEG    <$64
6e5c: 00 00           NEG    <$00
6e5e: 0a 00           DEC    <$00
6e60: 00 01           NEG    <$01
6e62: ee 88 ee        LDU    -$12,X
6e65: 8e ee 94        LDX    #$EE94
6e68: ee 9a           LDU    [F,X]
6e6a: ee a0           LDU    ,Y+
6e6c: ee a6           LDU    A,Y
6e6e: ee ac ee        LDU    $6E5F,PCR
6e71: b2 ee b7        SBCA   $EEB7
6e74: ee bc ee        LDU    [$6E65,PCR]
6e77: c1 ee           CMPB   #$EE
6e79: c6 ee           LDB    #$EE
6e7b: cb ee           ADDB   #$EE
6e7d: d0 ee           SUBB   <$EE
6e7f: d5 ee           BITB   <$EE
6e81: da ee           ORB    <$EE
6e83: df ee           STU    <$EE
6e85: e4 ee           ANDB   W,S
6e87: e9 05           ADCB   $5,X
6e89: 20 20           BRA    $6EAB
6e8b: 20 20           BRA    $6EAD
6e8d: 20 05           BRA    $6E94
6e8f: 53              COMB
6e90: 69 6e           ROL    $E,S
6e92: 65 20           LSR    $0,Y
6e94: 05 52           LSR    <$52
6e96: 61 6d           NEG    $D,S
6e98: 70 20 05        NEG    $2005
6e9b: 54              LSRB
6e9c: 72 6e 67        XNC    $6E67
6e9f: 6c 05           INC    $5,X
6ea1: 64 63           LSR    $3,S
6ea3: 20 20           BRA    $6EC5
6ea5: 20 05           BRA    $6EAC
6ea7: 4e              XCLRA
6ea8: 6f 69           CLR    $9,S
6eaa: 73 65 05        COM    $6505
6ead: 53              COMB
6eae: 71 20 20        NEG    $2020
6eb1: 20 04           BRA    $6EB7
6eb3: 41              NEGA
6eb4: 4d              TSTA
6eb5: 20 20           BRA    $6ED7
6eb7: 04 46           LSR    <$46
6eb9: 4d              TSTA
6eba: 20 20           BRA    $6EDC
6ebc: 04 05           LSR    <$05
6ebe: 4d              TSTA
6ebf: 20 20           BRA    $6EE1
6ec1: 04 44           LSR    <$44
6ec3: 53              COMB
6ec4: 42              XNCA
6ec5: 20 04           BRA    $6ECB
6ec7: 50              NEGB
6ec8: 6c 73           INC    -$D,S
6eca: 65 04           LSR    $4,X
6ecc: 4f              CLRA
6ecd: 75 74 31        LSR    $7431
6ed0: 04 4f           LSR    <$4F
6ed2: 75 74 32        LSR    $7432
6ed5: 04 4f           LSR    <$4F
6ed7: 75 74 33        LSR    $7433
6eda: 04 4f           LSR    <$4F
6edc: 75 74 34        LSR    $7434
6edf: 04 4f           LSR    <$4F
6ee1: 66 66           ROR    $6,S
6ee3: 20 04           BRA    $6EE9
6ee5: 4f              CLRA
6ee6: 6e 20           JMP    $0,Y
6ee8: 20 04           BRA    $6EEE
6eea: 20 20           BRA    $6F0C
6eec: 20 20           BRA    $6F0E
6eee: ef 0e           STU    $E,X
6ef0: ef 12           STU    -$E,X
6ef2: ef 16           STU    -$A,X
6ef4: ef 1a           STU    -$6,X
6ef6: ef 1e           STU    -$2,X
6ef8: ef 22           STU    $2,Y
6efa: ef 26           STU    $6,Y
6efc: ef 2a           STU    $A,Y
6efe: ef 2e           STU    $E,Y
6f00: ef 31           STU    -$F,Y
6f02: ef 34           STU    -$C,Y
6f04: ef 37           STU    -$9,Y
6f06: ef 3b           STU    -$5,Y
6f08: ef 3e           STU    -$2,Y
6f0a: ef 42           STU    $2,U
6f0c: ef 46           STU    $6,U
6f0e: 03 20           COM    <$20
6f10: 20 20           BRA    $6F32
6f12: 03 6b           COM    <$6B
6f14: 48              ASLA
6f15: 7a 03 20        DEC    $0320
6f18: 48              ASLA
6f19: 7a 03 64        DEC    $0364
6f1c: 65 67           LSR    $7,S
6f1e: 03 72           COM    <$72
6f20: 61 64           NEG    $4,S
6f22: 03 20           COM    <$20
6f24: 56              RORB
6f25: 20 03           BRA    $6F2A
6f27: 6d 56           TST    -$A,U
6f29: 20 03           BRA    $6F2E
6f2b: 06 56           ROR    <$56
6f2d: 20 02           BRA    $6F31
6f2f: 20 20           BRA    $6F51
6f31: 02 20           XNC    <$20
6f33: 73 02 6d        COM    $026D
6f36: 73 03 25        COM    $0325
6f39: 20 20           BRA    $6F5B
6f3b: 02 20           XNC    <$20
6f3d: 20 03           BRA    $6F42
6f3f: 20 20           BRA    $6F61
6f41: 20 03           BRA    $6F46
6f43: 44              LSRA
6f44: 53              COMB
6f45: 42              XNCA
6f46: 03 20           COM    <$20
6f48: 20 20           BRA    $6F6A
6f4a: 00 00           NEG    <$00
6f4c: 02 29           XNC    <$29
6f4e: 12              NOP
6f4f: 12              NOP
6f50: 08 32           ASL    <$32
6f52: 10              FCB    $10
6f53: 10 0a 0a        DEC    <$0A
6f56: 07 07           ASR    <$07
6f58: 14              XHCF
6f59: 2c 18           BGE    $6F73
6f5b: 18              X18
6f5c: 0e 2e           JMP    <$2E
6f5e: 16 16 09        LBRA   $856A
6f61: 09 01           ROL    <$01
6f63: 27 1a           BEQ    $6F7F
6f65: 31 1e           LEAY   -$2,X
6f67: 1e 20           EXG    Y,D
6f69: 33 1c           LEAU   -$4,X
6f6b: 1c 1f           ANDCC  #$1F
6f6d: 30 21           LEAX   $1,Y
6f6f: 21 06           BRN    $6F77
6f71: 25 11           BCS    $6F84
6f73: 11 03 26        COM    <$26
6f76: 0f 0f           CLR    <$0F
6f78: 13              SYNC
6f79: 2f 22           BLE    $6F9D
6f7b: 22 05           BHI    $6F82
6f7d: 28 17           BVC    $6F96
6f7f: 17 04 2a        LBSR   $73AC
6f82: 15              XHCF
6f83: 15              XHCF
6f84: 19              DAA
6f85: 2d 23           BLT    $6FAA
6f87: 23 0c           BLS    $6F95
6f89: 0c 1d           INC    <$1D
6f8b: 1d              SEX
6f8c: 0b 0b           XDEC   <$0B
6f8e: 1b              NOP
6f8f: 34 0d           PSHS   DP,B,CC
6f91: 2b 24           BMI    $6FB7
6f93: 24 0f           BCC    $6FA4
6f95: 58              ASLB
6f96: 0b 58           XDEC   <$58
6f98: 30 30           LEAX   -$10,Y
6f9a: 30 30           LEAX   -$10,Y
6f9c: 0c 58           INC    <$58
6f9e: 0c 01           INC    <$01
6fa0: 31 31           LEAY   -$F,Y
6fa2: 31 31           LEAY   -$F,Y
6fa4: 12              NOP
6fa5: 58              ASLB
6fa6: 0d 02           TST    <$02
6fa8: 32 32           LEAS   -$E,Y
6faa: 32 32           LEAS   -$E,Y
6fac: 18              X18
6fad: 58              ASLB
6fae: 0e 03           JMP    <$03
6fb0: 33 33           LEAU   -$D,Y
6fb2: 33 33           LEAU   -$D,Y
6fb4: 0b 58           XDEC   <$58
6fb6: 0f 06           CLR    <$06
6fb8: 34 34           PSHS   Y,X,B
6fba: 34 34           PSHS   Y,X,B
6fbc: 11 58           ASLB
6fbe: 58              ASLB
6fbf: 05 35           LSR    <$35
6fc1: 35 35           PULS   CC,B,X,Y
6fc3: 35 17           PULS   CC,D,X
6fc5: 58              ASLB
6fc6: 58              ASLB
6fc7: 04 36           LSR    <$36
6fc9: 36 36           PSHU   Y,X,D
6fcb: 36 0a           PSHU   DP,A
6fcd: 58              ASLB
6fce: 07 58           ASR    <$58
6fd0: 37 37           PULU   CC,D,X,Y
6fd2: 37 37           PULU   CC,D,X,Y
6fd4: 10 58           ASLB
6fd6: 08 58           ASL    <$58
6fd8: 38 38           XANDCC #$38
6fda: 38 38           XANDCC #$38
6fdc: 16 58 09        LBRA   $C7E8
6fdf: 58              ASLB
6fe0: 39              RTS
6fe1: 39              RTS
6fe2: 39              RTS
6fe3: 39              RTS
6fe4: 1e 58           EXG    PC,A
6fe6: 58              ASLB
6fe7: 58              ASLB
6fe8: 58              ASLB
6fe9: 41              NEGA
6fea: 58              ASLB
6feb: 58              ASLB
6fec: 1d              SEX
6fed: 58              ASLB
6fee: 58              ASLB
6fef: 58              ASLB
6ff0: 58              ASLB
6ff1: 42              XNCA
6ff2: 58              ASLB
6ff3: 58              ASLB
6ff4: 1c 58           ANDCC  #$58
6ff6: 58              ASLB
6ff7: 58              ASLB
6ff8: 58              ASLB
6ff9: 43              COMA
6ffa: 58              ASLB
6ffb: 58              ASLB
6ffc: 1b              NOP
6ffd: 11 58           ASLB
6fff: 58              ASLB
7000: 58              ASLB
7001: 44              LSRA
7002: 58              ASLB
7003: 58              ASLB
7004: 09 58           ROL    <$58
7006: 0a 58           DEC    <$58
7008: 58              ASLB
7009: 45              LSRA
700a: 2d 58           BLT    $7064
700c: 15              XHCF
700d: 10              FCB    $10
700e: 10 58           ASLB
7010: 58              ASLB
7011: 46              RORA
7012: 2e 2e           BGT    $7042
7014: 00 08           NEG    <$08
7016: 08 08           ASL    <$08
7018: 08 08           ASL    <$08
701a: 08 04           ASL    <$04
701c: 04 04           LSR    <$04
701e: 04 04           LSR    <$04
7020: 04 04           LSR    <$04
7022: 04 04           LSR    <$04
7024: 05 01           LSR    <$01
7026: 02 02           XNC    <$02
7028: 02 00           XNC    <$00
; Install NMI callback pointer and enable NMI dispatch — $702A.
; Stores the 16-bit function pointer argument (at $0006,S) into $24D8, then sets
; $2202 bit 15 ($80 in high byte). The NMI handler at $5C3D dispatches through
; $24D8 via JMP [$24D8] when $2202 bit 15 is set.
702a: fc f1 67        LDD    $F167
702d: 17 0d 20        LBSR   $7D50
7030: ec e9 00 06     LDD    $0006,S
7034: fd 24 d8        STD    $24D8
7037: fc 22 02        LDD    $2202
703a: 8a 80           ORA    #$80
703c: ca 00           ORB    #$00
703e: fd 22 02        STD    $2202
7041: 32 62           LEAS   $2,S
7043: 39              RTS
; Install FIRQ measurement callback pointer and enable dispatch — $7044.
; Stores the 16-bit function pointer argument (at $0006,S) into $24DA, then sets
; $2202 bit 9 ($02 in high byte). The FIRQ handler at $70A1 dispatches through
; $24DA via JSR ,X when $2202 bit 9 is set and $0100 bit 7 (external I/O interrupt)
; is active.
7044: fc f1 67        LDD    $F167
7047: 17 0d 06        LBSR   $7D50
704a: ec e9 00 06     LDD    $0006,S
704e: fd 24 da        STD    $24DA
7051: fc 22 02        LDD    $2202
7054: 8a 02           ORA    #$02
7056: ca 00           ORB    #$00
7058: fd 22 02        STD    $2202
705b: 32 62           LEAS   $2,S
705d: 39              RTS
; -------------------------------------------------------------------------------------
; MC6840 PTM interrupt drain — $7061.
; Allocates 5-byte frame via $7D50.
; Reads the PTM status register ($1001) and for each timer whose status bit is set
; (bit 0 = timer 1, bit 1 = timer 2, bit 2 = timer 3), reads the corresponding
; counter register ($1002/$1004/$1006). In the MC6840, reading a timer's counter
; register clears its interrupt flag. Loops while bit 7 (composite IRQ) remains set.
; This drains all pending PTM timer interrupts to a quiescent state.
; -------------------------------------------------------------------------------------
705e: fc f1 68        LDD    $F168
7061: 17 0c ec        LBSR   $7D50
; Top of drain loop
7064: f6 10 01        LDB    $1001       ; read PTM status register
7067: e7 62           STB    $2,S
7069: e6 62           LDB    $2,S
706b: c4 01           ANDB   #$01        ; timer 1 interrupt pending?
706d: 10 27 00 05     LBEQ   $7076       ; no → check timer 2
7071: fc 10 02        LDD    $1002       ; read timer 1 counter (clears its IRQ flag)
7074: ed 63           STD    $3,S
7076: e6 62           LDB    $2,S
7078: c4 02           ANDB   #$02        ; timer 2 interrupt pending?
707a: 10 27 00 05     LBEQ   $7083       ; no → check timer 3
707e: fc 10 04        LDD    $1004       ; read timer 2 counter (clears its IRQ flag)
7081: ed 63           STD    $3,S
7083: e6 62           LDB    $2,S
7085: c4 04           ANDB   #$04        ; timer 3 interrupt pending?
7087: 10 27 00 05     LBEQ   $7090       ; no → check if all drained
708b: fc 10 06        LDD    $1006       ; read timer 3 counter (clears its IRQ flag)
708e: ed 63           STD    $3,S
7090: f6 10 01        LDB    $1001       ; re-read PTM status
7093: 4f              CLRA
7094: 84 00           ANDA   #$00
7096: c4 80           ANDB   #$80        ; composite IRQ still asserted?
7098: 10 83 00 00     CMPD   #$0000
709c: 26 c6           BNE    $7064       ; yes → drain again
709e: 32 65           LEAS   $5,S
70a0: 39              RTS
; =====================================================================================
; FIRQ service routine — $70A1.
; Called from the FIRQ wrapper at $5D0C. Polls the system interrupt latch at $0100 and
; handles two known interrupt sources:
;   Bit 7 ($80): reads $0600 (external I/O port), then if $2202 bit 1 is set, dispatches
;                through the function pointer at $24DA. This appears to be an external
;                measurement/input acquisition interrupt.
;   Bit 4 ($10): calls $2AC4 (key scanner). If a key event occurred, sets $2204 bit 1
;                and calls $2AE8 to decode the key. If the decoded key code is $0019 or
;                $0013, also sets $2204 bit 2 (request dispatch pending) and reloads the
;                main-loop idle countdown timer at $220B with value $1002 (4098 decimal).
; Loops back to re-read $0100 after processing, exiting only when both bits are clear.
; =====================================================================================
70a1: fc f1 68        LDD    $F168       ; load frame size from ROM
70a4: 17 0c a9        LBSR   $7D50       ; allocate stack frame
; Top of FIRQ poll loop — re-reads $0100 after each source is handled
70a7: f6 01 00        LDB    $0100       ; read system interrupt latch
70aa: 4f              CLRA
70ab: 84 00           ANDA   #$00
70ad: c4 90           ANDB   #$90        ; isolate bits 7 and 4
70af: e7 62           STB    $2,S        ; save masked interrupt sources
70b1: e6 62           LDB    $2,S
70b3: c1 00           CMPB   #$00
70b5: 10 27 00 98     LBEQ   $7151       ; both clear → all sources serviced, exit
; --- Bit 7: external measurement/input acquisition interrupt ---
70b9: e6 62           LDB    $2,S
70bb: 4f              CLRA
70bc: 84 00           ANDA   #$00
70be: c4 80           ANDB   #$80        ; test bit 7
70c0: 10 83 00 00     CMPD   #$0000
70c4: 10 27 00 19     LBEQ   $70E1       ; not set → skip to bit 4
70c8: f6 06 00        LDB    $0600       ; read external I/O port data
70cb: e7 63           STB    $3,S        ; save in stack frame
70cd: fc 22 02        LDD    $2202
70d0: 84 02           ANDA   #$02        ; test $2202 bit 9 (measurement callback enabled)
70d2: c4 00           ANDB   #$00
70d4: 10 83 00 00     CMPD   #$0000
70d8: 10 27 00 05     LBEQ   $70E1       ; not enabled → skip callback
70dc: be 24 da        LDX    $24DA       ; dispatch through measurement callback pointer
70df: ad 84           JSR    ,X
; --- Bit 4: key scanner interrupt ---
70e1: e6 62           LDB    $2,S
70e3: c4 10           ANDB   #$10        ; test bit 4
70e5: 10 27 00 65     LBEQ   $714E       ; not set → loop back
70e9: ce 00 00        LDU    #$0000
70ec: 34 40           PSHS   U
70ee: 17 b9 d3        LBSR   $2AC4       ; → $2AC4: scan key matrix
70f1: 32 62           LEAS   $2,S
70f3: e7 64           STB    $4,S        ; save scan result
70f5: e6 64           LDB    $4,S
70f7: c1 00           CMPB   #$00
70f9: 10 27 00 47     LBEQ   $7144       ; no key → clear high-byte bit 2, loop
; Key detected: set $2204 bit 1 (FIRQ key event flag)
70fd: fc 22 04        LDD    $2204
7100: 8a 00           ORA    #$00
7102: ca 02           ORB    #$02        ; set bit 1
7104: fd 22 04        STD    $2204
; Decode key via $2AE8, store result in $24DC
7107: e6 64           LDB    $4,S
7109: 4f              CLRA
710a: 1f 03           TFR    D,U
710c: 10 8e 00 02     LDY    #$0002
7110: 34 60           PSHS   U,Y
7112: 17 b9 d3        LBSR   $2AE8       ; → $2AE8: decode raw key to key code
7115: 32 64           LEAS   $4,S
7117: fd 24 dc        STD    $24DC       ; save decoded key code
; Check for special key codes $0019 or $0013 → arm timer and dispatch
711a: be 24 dc        LDX    $24DC
711d: 8c 00 19        CMPX   #$0019      ; key code $19?
7120: 10 27 00 0d     LBEQ   $7131       ; yes → arm
7124: be 24 dc        LDX    $24DC
7127: 8c 00 13        CMPX   #$0013      ; key code $13?
712a: 10 27 00 03     LBEQ   $7131       ; yes → arm
712e: 16 00 10        LBRA   $7141       ; neither → skip arming, loop
; Arm: set $2204 high-byte bit 2 (timer gate) and reload idle timer to $1002 (4098)
7131: fc 22 04        LDD    $2204
7134: 8a 04           ORA    #$04        ; set high-byte bit 2
7136: ca 00           ORB    #$00
7138: fd 22 04        STD    $2204
713b: cc 10 02        LDD    #$1002      ; idle timer reload = 4098
713e: fd 22 0b        STD    $220B
7141: 16 00 0a        LBRA   $714E       ; → loop back
; No key detected: clear $2204 high-byte bit 2 (disarm timer gate)
7144: fc 22 04        LDD    $2204
7147: 84 fb           ANDA   #$FB        ; clear high-byte bit 2
7149: c4 ff           ANDB   #$FF
714b: fd 22 04        STD    $2204
714e: 16 ff 56        LBRA   $70A7       ; → re-poll $0100
7151: 32 65           LEAS   $5,S        ; deallocate frame
7153: 39              RTS
; Minimal IRQ-latch helper used by the IRQ wrapper at $5D14.
; =====================================================================================
; IRQ latch setter — $7154.
; Called from the IRQ wrapper ($5D14). Allocates a minimal stack frame, then sets $2204 bit 0
; to signal to the main loop that an IRQ occurred and P8291A polling is needed.
; For the observed *IDN? failure, this latch itself is not missing: traces show $7154 does run.
; The failure occurs later when foreground code resumes a stale 16-bit write to $2204 and
; overwrites the newly-set low byte before $07E4 tests it.
; =====================================================================================
7154: fc f1 67        LDD    $F167       ; load frame size from ROM (= $0000, 0 bytes)
7157: 17 0b f6        LBSR   $7D50       ; allocate stack frame
715a: fc 22 04        LDD    $2204       ; load foreground event flags
715d: 8a 00           ORA    #$00        ; (no-op on high byte)
715f: ca 01           ORB    #$01        ; set bit 0 = "IRQ occurred"
7161: fd 22 04        STD    $2204       ; store back
7164: 32 62           LEAS   $2,S        ; deallocate frame
7166: 39              RTS
; -------------------------------------------------------------------------------------
; ROM data: frame-size constant at $7167 (00 00 = 0 bytes) and $7169 (03 = padding).
;
; Indexed paged-callback dispatcher ($716A).
; NOTE: disassembler misalignment — the actual entry is at $716A which is byte $FC
; (LDD extended), giving: LDD $FCDC; LBSR $7D50 (4-byte frame). The bytes shown
; below at $7167-$716E are offset by one due to the data/code boundary.
;
; Takes an index argument at $0008,S (range 0–11).
; Looks up a function pointer from the $268F array via $7CEA with descriptor at $FCD6.
; If the pointer == $C239 (default stub RTS in paged ROM): calls $43FE($0E) for
; UI state save/error display, then exits.
; Otherwise: calls the pre-dispatch hook at $2213, switches to ROM page 0 via $5AE0,
; then invokes the looked-up function pointer with ROM page 1 via $5AE0.
; This dispatches one of up to 12 paged-ROM callback handlers indexed by the argument.
; -------------------------------------------------------------------------------------
7167: 00 00           NEG    <$00
7169: 03 fc           COM    <$FC
716b: fc dc 17        LDD    $DC17
716e: 0b e0           XDEC   <$E0
7170: ae e9 00 08     LDX    $0008,S
7174: 8c 00 0b        CMPX   #$000B
7177: 10 23 00 03     LBLS   $717E
717b: 16 00 58        LBRA   $71D6
717e: ce 26 8f        LDU    #$268F
7181: 10 ae e9 00 08  LDY    $0008,S
7186: 34 60           PSHS   U,Y
7188: 86 01           LDA    #$01
718a: 8e fc d6        LDX    #$FCD6
718d: 17 0b 5a        LBSR   $7CEA
7190: ae 84           LDX    ,X
7192: af 62           STX    $2,S
7194: cc c2 39        LDD    #$C239
7197: 10 a3 62        CMPD   $2,S
719a: 10 26 00 13     LBNE   $71B1
719e: c6 0e           LDB    #$0E
71a0: 1d              SEX
71a1: 1f 03           TFR    D,U
71a3: 10 8e 00 02     LDY    #$0002
71a7: 34 60           PSHS   U,Y
71a9: 17 d2 52        LBSR   $43FE
71ac: 32 64           LEAS   $4,S
71ae: 16 00 25        LBRA   $71D6
71b1: be 22 13        LDX    $2213
71b4: ad 84           JSR    ,X
71b6: 5f              CLRB
71b7: 1d              SEX
71b8: 1f 03           TFR    D,U
71ba: 10 8e 00 02     LDY    #$0002
71be: 34 60           PSHS   U,Y
71c0: 17 e9 1d        LBSR   $5AE0
71c3: 32 64           LEAS   $4,S
71c5: c6 01           LDB    #$01
71c7: 1d              SEX
71c8: 1f 03           TFR    D,U
71ca: 10 8e 00 02     LDY    #$0002
71ce: 34 60           PSHS   U,Y
71d0: ae 66           LDX    $6,S
71d2: ad 84           JSR    ,X
71d4: 32 64           LEAS   $4,S
71d6: 32 64           LEAS   $4,S
71d8: 39              RTS
; State-specific numeric-entry callback used while request $0023 is active.
; High-confidence behavior:
; - parses a small integer from the editable buffer at $2414
; - accepts values 0..11 and forwards the accepted selector through $716A
; - on larger/invalid values, either posts HP-IB event slot $13 (or $0F on early failure) through
;   $1DD3 when the callback gate is active, or falls back to a local error-display path
71d9: fc fc de        LDD    $FCDE
71dc: 17 0b 71        LBSR   $7D50
71df: 6f 63           CLR    $3,S
71e1: be 22 17        LDX    $2217
71e4: 8c 00 23        CMPX   #$0023
71e7: 10 26 01 04     LBNE   $72EF
71eb: c6 01           LDB    #$01
71ed: e7 63           STB    $3,S
71ef: c6 08           LDB    #$08
71f1: 1d              SEX
71f2: 1f 03           TFR    D,U
71f4: 10 8e 00 00     LDY    #$0000
71f8: 8e 00 04        LDX    #$0004
71fb: 34 70           PSHS   U,Y,X
71fd: 17 db e1        LBSR   $4DE1
7200: 32 66           LEAS   $6,S
7202: c1 03           CMPB   #$03
7204: 10 24 00 e7     LBCC   $72EF
7208: ce 24 14        LDU    #$2414
720b: 10 8e 00 02     LDY    #$0002
720f: 34 60           PSHS   U,Y
7211: 17 d8 22        LBSR   $4A36
7214: 32 64           LEAS   $4,S
7216: e7 62           STB    $2,S
7218: e6 62           LDB    $2,S
721a: c1 0b           CMPB   #$0B
721c: 10 2e 00 51     LBGT   $7271
7220: e6 62           LDB    $2,S
7222: f7 22 19        STB    $2219
7225: fc 22 04        LDD    $2204
7228: 84 00           ANDA   #$00
722a: c4 08           ANDB   #$08
722c: 10 83 00 00     CMPD   #$0000
7230: 10 26 00 0a     LBNE   $723E
7234: ce 00 00        LDU    #$0000
7237: 34 40           PSHS   U
7239: 17 e7 8a        LBSR   $59C6
723c: 32 62           LEAS   $2,S
723e: fc 22 02        LDD    $2202
7241: 84 ff           ANDA   #$FF
7243: c4 f7           ANDB   #$F7
7245: fd 22 02        STD    $2202
7248: f6 3a 7b        LDB    $3A7B
724b: c1 00           CMPB   #$00
724d: 10 27 00 05     LBEQ   $7256
7251: 6f 64           CLR    $4,S
7253: 16 00 d6        LBRA   $732C
7256: f6 22 19        LDB    $2219
7259: 4f              CLRA
725a: 1f 03           TFR    D,U
725c: 10 8e 00 02     LDY    #$0002
7260: 34 60           PSHS   U,Y
7262: 17 ff 05        LBSR   $716A
7265: 32 64           LEAS   $4,S
7267: e6 63           LDB    $3,S
7269: e7 64           STB    $4,S
726b: 16 00 be        LBRA   $732C
726e: 16 00 7e        LBRA   $72EF
7271: fc 22 04        LDD    $2204
7274: 84 00           ANDA   #$00
7276: c4 08           ANDB   #$08
7278: 10 83 00 00     CMPD   #$0000
727c: 10 27 00 20     LBEQ   $72A0
7280: c6 13           LDB    #$13
7282: 1d              SEX
7283: 1f 03           TFR    D,U
7285: 5f              CLRB
7286: 1d              SEX
7287: 1f 02           TFR    D,Y
7289: 8e 00 04        LDX    #$0004
728c: 34 70           PSHS   U,Y,X
728e: 17 ab 42        LBSR   $1DD3
7291: 32 66           LEAS   $6,S
7293: fc 22 02        LDD    $2202
7296: 84 ff           ANDA   #$FF
7298: c4 f7           ANDB   #$F7
729a: fd 22 02        STD    $2202
729d: 16 00 48        LBRA   $72E8
72a0: c6 13           LDB    #$13
72a2: 1d              SEX
72a3: 1f 03           TFR    D,U
72a5: 10 8e 00 02     LDY    #$0002
72a9: 34 60           PSHS   U,Y
72ab: 17 d1 50        LBSR   $43FE
72ae: 32 64           LEAS   $4,S
72b0: ce ed 11        LDU    #$ED11
72b3: c6 02           LDB    #$02
72b5: 1d              SEX
72b6: 1f 02           TFR    D,Y
72b8: c6 12           LDB    #$12
72ba: 1d              SEX
72bb: 1f 01           TFR    D,X
72bd: cc 00 06        LDD    #$0006
72c0: 34 76           PSHS   U,Y,X,D
72c2: 17 e5 e0        LBSR   $58A5
72c5: 32 68           LEAS   $8,S
72c7: c6 12           LDB    #$12
72c9: 1d              SEX
72ca: 1f 03           TFR    D,U
72cc: 10 8e 00 02     LDY    #$0002
72d0: c6 12           LDB    #$12
72d2: 1d              SEX
72d3: 1f 01           TFR    D,X
72d5: c6 02           LDB    #$02
72d7: 1d              SEX
72d8: 34 76           PSHS   U,Y,X,D
72da: ce 00 00        LDU    #$0000
72dd: 10 8e 00 0a     LDY    #$000A
72e1: 34 60           PSHS   U,Y
72e3: 17 b9 4f        LBSR   $2C35
72e6: 32 6c           LEAS   $C,S
72e8: e6 63           LDB    $3,S
72ea: e7 64           STB    $4,S
72ec: 16 00 3d        LBRA   $732C
72ef: fc 22 04        LDD    $2204
72f2: 84 00           ANDA   #$00
72f4: c4 08           ANDB   #$08
72f6: 10 83 00 00     CMPD   #$0000
72fa: 10 27 00 16     LBEQ   $7314
72fe: c6 0f           LDB    #$0F
7300: 1d              SEX
7301: 1f 03           TFR    D,U
7303: 5f              CLRB
7304: 1d              SEX
7305: 1f 02           TFR    D,Y
7307: 8e 00 04        LDX    #$0004
730a: 34 70           PSHS   U,Y,X
730c: 17 aa c4        LBSR   $1DD3
730f: 32 66           LEAS   $6,S
7311: 16 00 0a        LBRA   $731E
7314: ce 00 00        LDU    #$0000
7317: 34 40           PSHS   U
7319: 17 e6 aa        LBSR   $59C6
731c: 32 62           LEAS   $2,S
731e: fc 22 02        LDD    $2202
7321: 84 ff           ANDA   #$FF
7323: c4 f7           ANDB   #$F7
7325: fd 22 02        STD    $2202
7328: e6 63           LDB    $3,S
732a: e7 64           STB    $4,S
732c: e6 64           LDB    $4,S
732e: 32 65           LEAS   $5,S
7330: 39              RTS
; -------------------------------------------------------------------------------------
; Request handler UI setup — numeric port/channel selector ($7334).
; Allocates 4-byte frame via $7D50.
; Takes one argument (at $0008,S): compared to $0022 to set the $3A7B flag
; (0 if arg==$0022, 1 otherwise). This flag selects between two prompt strings.
;
; If HP-IB is active ($2204 bit 3 set): posts the request to the HP-IB handler
; via $2415 with no additional arguments, then exits.
;
; If local (front-panel): sets $2204 bit 4 (UI-active flag), displays one of two
; prompt strings on LCD row 0 ($EB41 when $3A7B!=0, $EB69 when $3A7B==0) at
; position ($28,$00), and a second-row prompt $EB91 at ($28,$40).
; Sets up a numeric entry field via $2C35 at cursor position ($12,$12) with
; validation mode $0A (decimal integer).
; Installs callback pointer $F1D9 at $220D (paged ROM callback for the next
; stage of this request), sets $2202 bit 3 to signal active numeric entry.
;
; This is the initial screen for request $0023 — it prompts the user to enter
; a port or channel number. The $71D9 function (above) handles the commit
; callback that validates the entered value.
; -------------------------------------------------------------------------------------
7331: fc fc dc        LDD    $FCDC
7334: 17 0a 19        LBSR   $7D50
7337: ae e9 00 08     LDX    $0008,S
733b: 8c 00 22        CMPX   #$0022
733e: 10 26 00 06     LBNE   $7348
7342: 7f 3a 7b        CLR    $3A7B
7345: 16 00 05        LBRA   $734D
7348: c6 01           LDB    #$01
734a: f7 3a 7b        STB    $3A7B
734d: fc 22 04        LDD    $2204
7350: 84 00           ANDA   #$00
7352: c4 08           ANDB   #$08
7354: 10 83 00 00     CMPD   #$0000
7358: 10 27 00 14     LBEQ   $7370
735c: ce 00 00        LDU    #$0000
735f: 10 8e 00 00     LDY    #$0000
7363: 8e 00 04        LDX    #$0004
7366: 34 70           PSHS   U,Y,X
7368: 17 b0 aa        LBSR   $2415
736b: 32 66           LEAS   $6,S
736d: 16 00 6d        LBRA   $73DD
7370: fc 22 04        LDD    $2204
7373: 8a 00           ORA    #$00
7375: ca 10           ORB    #$10
7377: fd 22 04        STD    $2204
737a: f6 3a 7b        LDB    $3A7B
737d: c1 00           CMPB   #$00
737f: 10 27 00 08     LBEQ   $738B
7383: cc eb 41        LDD    #$EB41
7386: ed 62           STD    $2,S
7388: 16 00 05        LBRA   $7390
738b: cc eb 69        LDD    #$EB69
738e: ed 62           STD    $2,S
7390: ee 62           LDU    $2,S
7392: c6 28           LDB    #$28
7394: 1d              SEX
7395: 1f 02           TFR    D,Y
7397: 5f              CLRB
7398: 1d              SEX
7399: 1f 01           TFR    D,X
739b: cc 00 06        LDD    #$0006
739e: 34 76           PSHS   U,Y,X,D
73a0: 17 e5 02        LBSR   $58A5
73a3: 32 68           LEAS   $8,S
73a5: ce eb 91        LDU    #$EB91
73a8: c6 28           LDB    #$28
73aa: 1d              SEX
73ab: 1f 02           TFR    D,Y
73ad: c6 40           LDB    #$40
73af: 1d              SEX
73b0: 1f 01           TFR    D,X
73b2: cc 00 06        LDD    #$0006
73b5: 34 76           PSHS   U,Y,X,D
73b7: 17 e4 eb        LBSR   $58A5
73ba: 32 68           LEAS   $8,S
73bc: c6 12           LDB    #$12
73be: 1d              SEX
73bf: 1f 03           TFR    D,U
73c1: 10 8e 00 02     LDY    #$0002
73c5: c6 12           LDB    #$12
73c7: 1d              SEX
73c8: 1f 01           TFR    D,X
73ca: c6 02           LDB    #$02
73cc: 1d              SEX
73cd: 34 76           PSHS   U,Y,X,D
73cf: ce 00 00        LDU    #$0000
73d2: 10 8e 00 0a     LDY    #$000A
73d6: 34 60           PSHS   U,Y
73d8: 17 b8 5a        LBSR   $2C35
73db: 32 6c           LEAS   $C,S
73dd: cc f1 d9        LDD    #$F1D9
73e0: fd 22 0d        STD    $220D
73e3: fc 22 02        LDD    $2202
73e6: 8a 00           ORA    #$00
73e8: ca 08           ORB    #$08
73ea: fd 22 02        STD    $2202
73ed: 32 64           LEAS   $4,S
73ef: 39              RTS
; Follow-on callback in the same request-$0023 family.
; The early-exit branch shown first here posts HP-IB event slot $18 through $1DD3 when the request
; context is no longer what this state expects; otherwise it falls back to local cleanup/display
; work. The later request-$0023 path below continues with additional numeric validation.
73f0: fc fc dc        LDD    $FCDC
73f3: 17 09 5a        LBSR   $7D50
73f6: be 22 17        LDX    $2217
73f9: 8c 00 23        CMPX   #$0023
73fc: 10 27 00 3e     LBEQ   $743E
7400: fc 22 04        LDD    $2204
7403: 84 00           ANDA   #$00
7405: c4 08           ANDB   #$08
7407: 10 83 00 00     CMPD   #$0000
740b: 10 27 00 16     LBEQ   $7425
740f: c6 18           LDB    #$18
7411: 1d              SEX
7412: 1f 03           TFR    D,U
7414: 5f              CLRB
7415: 1d              SEX
7416: 1f 02           TFR    D,Y
7418: 8e 00 04        LDX    #$0004
741b: 34 70           PSHS   U,Y,X
741d: 17 a9 b3        LBSR   $1DD3
7420: 32 66           LEAS   $6,S
7422: 16 00 0a        LBRA   $742F
7425: ce 00 00        LDU    #$0000
7428: 34 40           PSHS   U
742a: 17 e5 99        LBSR   $59C6
742d: 32 62           LEAS   $2,S
742f: fc 22 02        LDD    $2202
7432: 84 ff           ANDA   #$FF
7434: c4 f7           ANDB   #$F7
7436: fd 22 02        STD    $2202
7439: 6f 63           CLR    $3,S
743b: 16 01 5d        LBRA   $759B
743e: f6 3a 7d        LDB    $3A7D
7441: c1 00           CMPB   #$00
7443: 10 26 00 dc     LBNE   $7523
7447: c6 08           LDB    #$08
7449: 1d              SEX
744a: 1f 03           TFR    D,U
744c: 10 8e 00 00     LDY    #$0000
7450: 8e 00 04        LDX    #$0004
7453: 34 70           PSHS   U,Y,X
7455: 17 d9 89        LBSR   $4DE1
7458: 32 66           LEAS   $6,S
745a: ce 24 14        LDU    #$2414
745d: 10 8e 00 02     LDY    #$0002
7461: 34 60           PSHS   U,Y
7463: 17 d5 d0        LBSR   $4A36
7466: 32 64           LEAS   $4,S
7468: f7 3a 7c        STB    $3A7C
746b: f6 3a 7c        LDB    $3A7C
746e: c1 00           CMPB   #$00
7470: 10 23 00 0d     LBLS   $7481
7474: f6 3a 7c        LDB    $3A7C
7477: f1 23 b2        CMPB   $23B2
747a: 10 22 00 03     LBHI   $7481
747e: 16 00 03        LBRA   $7484
7481: 16 00 52        LBRA   $74D6
7484: ce 24 14        LDU    #$2414
7487: f6 3a 7c        LDB    $3A7C
748a: 4f              CLRA
748b: 1f 02           TFR    D,Y
748d: 8e 00 04        LDX    #$0004
7490: 34 70           PSHS   U,Y,X
7492: 17 d5 3c        LBSR   $49D1
7495: 32 66           LEAS   $6,S
7497: ce 24 16        LDU    #$2416
749a: c6 01           LDB    #$01
749c: 1d              SEX
749d: 1f 02           TFR    D,Y
749f: c6 59           LDB    #$59
74a1: 1d              SEX
74a2: 1f 01           TFR    D,X
74a4: cc 00 06        LDD    #$0006
74a7: 34 76           PSHS   U,Y,X,D
74a9: 17 e3 f9        LBSR   $58A5
74ac: 32 68           LEAS   $8,S
74ae: c6 01           LDB    #$01
74b0: f7 3a 7d        STB    $3A7D
74b3: c6 5f           LDB    #$5F
74b5: 1d              SEX
74b6: 1f 03           TFR    D,U
74b8: 10 8e 00 00     LDY    #$0000
74bc: c6 5f           LDB    #$5F
74be: 1d              SEX
74bf: 1f 01           TFR    D,X
74c1: 5f              CLRB
74c2: 1d              SEX
74c3: 34 76           PSHS   U,Y,X,D
74c5: ce 00 06        LDU    #$0006
74c8: 10 8e 00 0a     LDY    #$000A
74cc: 34 60           PSHS   U,Y
74ce: 17 b7 64        LBSR   $2C35
74d1: 32 6c           LEAS   $C,S
74d3: 16 00 46        LBRA   $751C
74d6: ce 00 a0        LDU    #$00A0
74d9: 10 8e 00 02     LDY    #$0002
74dd: 34 60           PSHS   U,Y
74df: 17 cf 1c        LBSR   $43FE
74e2: 32 64           LEAS   $4,S
74e4: ce ed 11        LDU    #$ED11
74e7: c6 01           LDB    #$01
74e9: 1d              SEX
74ea: 1f 02           TFR    D,Y
74ec: c6 59           LDB    #$59
74ee: 1d              SEX
74ef: 1f 01           TFR    D,X
74f1: cc 00 06        LDD    #$0006
74f4: 34 76           PSHS   U,Y,X,D
74f6: 17 e3 ac        LBSR   $58A5
74f9: 32 68           LEAS   $8,S
74fb: c6 59           LDB    #$59
74fd: 1d              SEX
74fe: 1f 03           TFR    D,U
7500: 10 8e 00 00     LDY    #$0000
7504: c6 59           LDB    #$59
7506: 1d              SEX
7507: 1f 01           TFR    D,X
7509: c6 01           LDB    #$01
750b: 1d              SEX
750c: 34 76           PSHS   U,Y,X,D
750e: ce 00 00        LDU    #$0000
7511: 10 8e 00 0a     LDY    #$000A
7515: 34 60           PSHS   U,Y
7517: 17 b7 1b        LBSR   $2C35
751a: 32 6c           LEAS   $C,S
751c: c6 01           LDB    #$01
751e: e7 63           STB    $3,S
7520: 16 00 78        LBRA   $759B
7523: be 22 1f        LDX    $221F
7526: 8c 00 11        CMPX   #$0011
7529: 10 26 00 07     LBNE   $7534
752d: c6 01           LDB    #$01
752f: e7 62           STB    $2,S
7531: 16 00 02        LBRA   $7536
7534: 6f 62           CLR    $2,S
7536: f6 3a 7c        LDB    $3A7C
7539: c0 01           SUBB   #$01
753b: f7 3a 7c        STB    $3A7C
753e: f6 3a 7e        LDB    $3A7E
7541: c1 00           CMPB   #$00
7543: 10 27 00 18     LBEQ   $755F
7547: e6 62           LDB    $2,S
7549: 4f              CLRA
754a: 1f 03           TFR    D,U
754c: f6 3a 7c        LDB    $3A7C
754f: 4f              CLRA
7550: 1f 02           TFR    D,Y
7552: 8e 00 04        LDX    #$0004
7555: 34 70           PSHS   U,Y,X
7557: 17 c1 95        LBSR   $36EF
755a: 32 66           LEAS   $6,S
755c: 16 00 15        LBRA   $7574
755f: e6 62           LDB    $2,S
7561: 4f              CLRA
7562: 1f 03           TFR    D,U
7564: f6 3a 7c        LDB    $3A7C
7567: 4f              CLRA
7568: 1f 02           TFR    D,Y
756a: 8e 00 04        LDX    #$0004
756d: 34 70           PSHS   U,Y,X
756f: 17 c2 2a        LBSR   $379C
7572: 32 66           LEAS   $6,S
7574: fc 22 04        LDD    $2204
7577: 84 00           ANDA   #$00
7579: c4 08           ANDB   #$08
757b: 10 83 00 00     CMPD   #$0000
757f: 10 26 00 0a     LBNE   $758D
7583: ce 00 00        LDU    #$0000
7586: 34 40           PSHS   U
7588: 17 e4 3b        LBSR   $59C6
758b: 32 62           LEAS   $2,S
758d: fc 22 02        LDD    $2202
7590: 84 ff           ANDA   #$FF
7592: c4 f7           ANDB   #$F7
7594: fd 22 02        STD    $2202
7597: c6 01           LDB    #$01
7599: e7 63           STB    $3,S
759b: e6 63           LDB    $3,S
759d: 32 64           LEAS   $4,S
759f: 39              RTS
; -------------------------------------------------------------------------------------
; Request handler UI setup — port enable/direction configuration ($75A3).
; Allocates 2-byte frame via $7D50.
; Takes one argument (at $0006,S): compared to $000F to set the $3A7E flag
; (0 if arg==$000F, 1 otherwise). This flag selects between two mode labels.
;
; If HP-IB is active ($2204 bit 3 set): copies the current port index from
; $2219 to $3A7C, posts to the HP-IB handler via $2415 with type=6, sets
; $3A7D=1 (indicating first-stage HP-IB handoff complete), then exits.
;
; If local (front-panel): sets $2204 bit 4 (UI-active), clears LCD row 0
; with $ED11, displays a mode label at position ($15,$09) — either $EBCE
; (when $3A7E!=0) or $EBB9 (when $3A7E==0) — and a second-row prompt
; $EBE3 at ($28,$40).
; Sets up numeric entry at cursor ($59,$59) with validation mode $0A,
; clears $3A7D (no HP-IB handoff in local mode).
; Installs callback $F3F0 at $220D, sets $2202 bit 3.
;
; This is the setup phase for the port enable/direction selection UI.
; The $73F0 function handles the follow-on commit callback.
; -------------------------------------------------------------------------------------
75a0: fc fc d8        LDD    $FCD8
75a3: 17 07 aa        LBSR   $7D50
75a6: ae e9 00 06     LDX    $0006,S
75aa: 8c 00 0f        CMPX   #$000F
75ad: 10 26 00 06     LBNE   $75B7
75b1: 7f 3a 7e        CLR    $3A7E
75b4: 16 00 05        LBRA   $75BC
75b7: c6 01           LDB    #$01
75b9: f7 3a 7e        STB    $3A7E
75bc: fc 22 04        LDD    $2204
75bf: 84 00           ANDA   #$00
75c1: c4 08           ANDB   #$08
75c3: 10 83 00 00     CMPD   #$0000
75c7: 10 27 00 1f     LBEQ   $75EA
75cb: f6 22 19        LDB    $2219
75ce: f7 3a 7c        STB    $3A7C
75d1: ce 00 00        LDU    #$0000
75d4: 10 8e 00 06     LDY    #$0006
75d8: 8e 00 04        LDX    #$0004
75db: 34 70           PSHS   U,Y,X
75dd: 17 ae 35        LBSR   $2415
75e0: 32 66           LEAS   $6,S
75e2: c6 01           LDB    #$01
75e4: f7 3a 7d        STB    $3A7D
75e7: 16 00 95        LBRA   $767F
75ea: fc 22 04        LDD    $2204
75ed: 8a 00           ORA    #$00
75ef: ca 10           ORB    #$10
75f1: fd 22 04        STD    $2204
75f4: ce ed 11        LDU    #$ED11
75f7: c6 28           LDB    #$28
75f9: 1d              SEX
75fa: 1f 02           TFR    D,Y
75fc: 5f              CLRB
75fd: 1d              SEX
75fe: 1f 01           TFR    D,X
7600: cc 00 06        LDD    #$0006
7603: 34 76           PSHS   U,Y,X,D
7605: 17 e2 9d        LBSR   $58A5
7608: 32 68           LEAS   $8,S
760a: f6 3a 7e        LDB    $3A7E
760d: c1 00           CMPB   #$00
760f: 10 27 00 1a     LBEQ   $762D
7613: ce eb ce        LDU    #$EBCE
7616: c6 15           LDB    #$15
7618: 1d              SEX
7619: 1f 02           TFR    D,Y
761b: c6 09           LDB    #$09
761d: 1d              SEX
761e: 1f 01           TFR    D,X
7620: cc 00 06        LDD    #$0006
7623: 34 76           PSHS   U,Y,X,D
7625: 17 e2 7d        LBSR   $58A5
7628: 32 68           LEAS   $8,S
762a: 16 00 17        LBRA   $7644
762d: ce eb b9        LDU    #$EBB9
7630: c6 15           LDB    #$15
7632: 1d              SEX
7633: 1f 02           TFR    D,Y
7635: c6 09           LDB    #$09
7637: 1d              SEX
7638: 1f 01           TFR    D,X
763a: cc 00 06        LDD    #$0006
763d: 34 76           PSHS   U,Y,X,D
763f: 17 e2 63        LBSR   $58A5
7642: 32 68           LEAS   $8,S
7644: ce eb e3        LDU    #$EBE3
7647: c6 28           LDB    #$28
7649: 1d              SEX
764a: 1f 02           TFR    D,Y
764c: c6 40           LDB    #$40
764e: 1d              SEX
764f: 1f 01           TFR    D,X
7651: cc 00 06        LDD    #$0006
7654: 34 76           PSHS   U,Y,X,D
7656: 17 e2 4c        LBSR   $58A5
7659: 32 68           LEAS   $8,S
765b: c6 59           LDB    #$59
765d: 1d              SEX
765e: 1f 03           TFR    D,U
7660: 10 8e 00 00     LDY    #$0000
7664: c6 59           LDB    #$59
7666: 1d              SEX
7667: 1f 01           TFR    D,X
7669: c6 01           LDB    #$01
766b: 1d              SEX
766c: 34 76           PSHS   U,Y,X,D
766e: ce 00 00        LDU    #$0000
7671: 10 8e 00 0a     LDY    #$000A
7675: 34 60           PSHS   U,Y
7677: 17 b5 bb        LBSR   $2C35
767a: 32 6c           LEAS   $C,S
767c: 7f 3a 7d        CLR    $3A7D
767f: cc f3 f0        LDD    #$F3F0
7682: fd 22 0d        STD    $220D
7685: fc 22 02        LDD    $2202
7688: 8a 00           ORA    #$00
768a: ca 08           ORB    #$08
768c: fd 22 02        STD    $2202
768f: 32 62           LEAS   $2,S
7691: 39              RTS
; -------------------------------------------------------------------------------------
; I/O port output transition with settle delay ($7695).
; Allocates 2-byte frame via $7D50.
; Args: port index (arg1 at $0006,S), desired output state (arg2 at $0008,S).
;
; Reads $24F0[arg1] bit 0 (current output state) and compares to arg2.
; If already at the desired state: returns immediately (no-op).
;
; Otherwise performs a glitch-free transition sequence:
;   1. Clears the port output via $367B(0, arg1) — conditional disable
;   2. Delays via $5670(5) for settle time
;   3. Writes the new state via $5BA1(arg2, 1, arg1) — direct port write
;   4. Delays via $5670(5) again
;   5. Re-enables the port via $367B(1, arg1) — conditional enable
;
; The disable-settle-set-settle-enable sequence prevents output glitches
; during the transition by ensuring the port is inactive while the new
; value propagates.
; -------------------------------------------------------------------------------------
7692: fc fc d8        LDD    $FCD8
7695: 17 06 b8        LBSR   $7D50
7698: 8e 24 f0        LDX    #$24F0
769b: ec e9 00 06     LDD    $0006,S
769f: 30 8b           LEAX   D,X
76a1: e6 84           LDB    ,X
76a3: c4 01           ANDB   #$01
76a5: 4f              CLRA
76a6: 10 a3 e9 00 08  CMPD   $0008,S
76ab: 10 26 00 03     LBNE   $76B2
76af: 16 00 5e        LBRA   $7710
76b2: 5f              CLRB
76b3: 1d              SEX
76b4: 1f 03           TFR    D,U
76b6: 10 ae e9 00 06  LDY    $0006,S
76bb: 8e 00 04        LDX    #$0004
76be: 34 70           PSHS   U,Y,X
76c0: 17 bf b8        LBSR   $367B
76c3: 32 66           LEAS   $6,S
76c5: c6 05           LDB    #$05
76c7: 1d              SEX
76c8: 1f 03           TFR    D,U
76ca: 10 8e 00 02     LDY    #$0002
76ce: 34 60           PSHS   U,Y
76d0: 17 df 9d        LBSR   $5670
76d3: 32 64           LEAS   $4,S
76d5: ee e9 00 08     LDU    $0008,S
76d9: c6 01           LDB    #$01
76db: 1d              SEX
76dc: 1f 02           TFR    D,Y
76de: ae e9 00 06     LDX    $0006,S
76e2: cc 00 06        LDD    #$0006
76e5: 34 76           PSHS   U,Y,X,D
76e7: 17 e4 b7        LBSR   $5BA1
76ea: 32 68           LEAS   $8,S
76ec: c6 05           LDB    #$05
76ee: 1d              SEX
76ef: 1f 03           TFR    D,U
76f1: 10 8e 00 02     LDY    #$0002
76f5: 34 60           PSHS   U,Y
76f7: 17 df 76        LBSR   $5670
76fa: 32 64           LEAS   $4,S
76fc: c6 01           LDB    #$01
76fe: 1d              SEX
76ff: 1f 03           TFR    D,U
7701: 10 ae e9 00 06  LDY    $0006,S
7706: 8e 00 04        LDX    #$0004
7709: 34 70           PSHS   U,Y,X
770b: 17 bf 6d        LBSR   $367B
770e: 32 66           LEAS   $6,S
7710: 32 62           LEAS   $2,S
7712: 39              RTS
; -------------------------------------------------------------------------------------
; I/O port enable store and conditional apply ($7716).
; Allocates 2-byte frame via $7D50.
; Args: port index (arg1 at $0006,S), enable value (arg2 at $0008,S).
;
; Validates arg1 < $23B2 (configured port count); exits if out of range.
; Normalizes arg2: if not exactly 1, clears to 0.
; Stores the normalized enable value at $24EC[arg1] (port enable array).
;
; Then reads the port's current mode from $24E8[arg1]:
; if mode == 3 (active output), applies the change immediately by calling
; $7692(arg2, arg1) to perform the glitch-free output transition.
; If the port is in any other mode, the enable value is stored but not
; physically applied until the mode changes to 3.
; -------------------------------------------------------------------------------------
7713: fc fc d8        LDD    $FCD8
7716: 17 06 37        LBSR   $7D50
7719: f6 23 b2        LDB    $23B2
771c: 4f              CLRA
771d: 10 a3 e9 00 06  CMPD   $0006,S
7722: 10 24 00 03     LBCC   $7729
7726: 16 00 44        LBRA   $776D
7729: ae e9 00 08     LDX    $0008,S
772d: 8c 00 01        CMPX   #$0001
7730: 10 27 00 06     LBEQ   $773A
7734: 5f              CLRB
7735: 4f              CLRA
7736: ed e9 00 08     STD    $0008,S
773a: 8e 24 ec        LDX    #$24EC
773d: ec e9 00 06     LDD    $0006,S
7741: 30 8b           LEAX   D,X
7743: e6 e9 00 09     LDB    $0009,S
7747: e7 84           STB    ,X
7749: 8e 24 e8        LDX    #$24E8
774c: ec e9 00 06     LDD    $0006,S
7750: 30 8b           LEAX   D,X
7752: e6 84           LDB    ,X
7754: c1 03           CMPB   #$03
7756: 10 26 00 13     LBNE   $776D
775a: ee e9 00 08     LDU    $0008,S
775e: 10 ae e9 00 06  LDY    $0006,S
7763: 8e 00 04        LDX    #$0004
7766: 34 70           PSHS   U,Y,X
7768: 17 ff 27        LBSR   $7692
776b: 32 66           LEAS   $6,S
776d: 32 62           LEAS   $2,S
776f: 39              RTS
; -------------------------------------------------------------------------------------
; I/O port mode set and apply ($7773).
; Allocates 3-byte frame via $7D50.
; Args: port index (arg1 at $0007,S), mode selector (arg2 at $0009,S),
;       enable value (arg3 at $000A,S).
;
; Validates arg1 < $23B2 (configured port count); exits if out of range.
;
; The mode selector (arg2) determines the enable value for the transition:
;   0 or 1: uses arg3 directly as the enable value
;   3:      reads the stored enable from $24EC[arg1] instead of arg3
;   other:  exits without applying (invalid mode)
;
; Stores arg3 at $24E8[arg1] (port mode array), then calls $7692(enable, arg1)
; to perform the glitch-free output transition with the determined enable value.
; -------------------------------------------------------------------------------------
7770: fc fc d6        LDD    $FCD6
7773: 17 05 da        LBSR   $7D50
7776: f6 23 b2        LDB    $23B2
7779: 4f              CLRA
777a: 10 a3 e9 00 07  CMPD   $0007,S
777f: 10 24 00 03     LBCC   $7786
7783: 16 00 63        LBRA   $77E9
7786: ae e9 00 09     LDX    $0009,S
778a: 8c 00 00        CMPX   #$0000
778d: 10 27 00 0e     LBEQ   $779F
7791: ae e9 00 09     LDX    $0009,S
7795: 8c 00 01        CMPX   #$0001
7798: 10 27 00 03     LBEQ   $779F
779c: 16 00 09        LBRA   $77A8
779f: e6 e9 00 0a     LDB    $000A,S
77a3: e7 62           STB    $2,S
77a5: 16 00 1e        LBRA   $77C6
77a8: ae e9 00 09     LDX    $0009,S
77ac: 8c 00 03        CMPX   #$0003
77af: 10 26 00 10     LBNE   $77C3
77b3: 8e 24 ec        LDX    #$24EC
77b6: ec e9 00 07     LDD    $0007,S
77ba: 30 8b           LEAX   D,X
77bc: e6 84           LDB    ,X
77be: e7 62           STB    $2,S
77c0: 16 00 03        LBRA   $77C6
77c3: 16 00 23        LBRA   $77E9
77c6: 8e 24 e8        LDX    #$24E8
77c9: ec e9 00 07     LDD    $0007,S
77cd: 30 8b           LEAX   D,X
77cf: e6 e9 00 0a     LDB    $000A,S
77d3: e7 84           STB    ,X
77d5: e6 62           LDB    $2,S
77d7: 4f              CLRA
77d8: 1f 03           TFR    D,U
77da: 10 ae e9 00 07  LDY    $0007,S
77df: 8e 00 04        LDX    #$0004
77e2: 34 70           PSHS   U,Y,X
77e4: 17 fe ab        LBSR   $7692
77e7: 32 66           LEAS   $6,S
77e9: 32 63           LEAS   $3,S
77eb: 39              RTS
; -------------------------------------------------------------------------------------
; Channel output mode validation and application ($77EF).
; Allocates 18-byte frame via $7D50 (frame size from $FCE6).
; Takes the target output mode at $0016,S.
; Returns immediately if mode == $0010 (disabled).
;
; Reads the starting channel from $2516 and converts the mode to an
; output-enable code via $4765. If $4765 returns $FF (no mapping), retries
; with the $2516 channel's own mode; exits if still $FF.
; Sets a same-mode flag if the target mode matches $2516's current mode.
;
; Scans channels 0–3 via $24F5/$7CEA:
;   - Skips channels with mode $0010 (disabled)
;   - Reads each channel's output control word at descriptor offset $1F
;   - For channels whose mode matches the target:
;     * Channel 0 with $2202 bit 8 set: calls $6962 (DDS tuning word max
;       search) and compares the result against the limit at $EA5F —
;       if exceeded, clears the enable flag
;     * Other channels: compares the channel's data pointer against $EA5F
;   - Checks output control for values $0002, $0003, or $0006 — sets a
;     conflict flag if any match
;
; After the scan, evaluates the final enable decision: the enable flag must
; be set AND either (the same-mode flag is set with $2411 nonzero) OR the
; conflict flag is set. If both conditions fail, enable is cleared.
;
; Calls $7713(enable, output-code) to store and apply the result.
; -------------------------------------------------------------------------------------
77ec: fc fc e6        LDD    $FCE6
77ef: 17 05 5e        LBSR   $7D50
77f2: ae e9 00 16     LDX    $0016,S
77f6: 8c 00 10        CMPX   #$0010
77f9: 10 26 00 03     LBNE   $7800
77fd: 16 01 d0        LBRA   $79D0
7800: c6 01           LDB    #$01
7802: e7 6a           STB    $A,S
7804: 6f 6b           CLR    $B,S
7806: fc 25 16        LDD    $2516
7809: ed 62           STD    $2,S
780b: ec e9 00 16     LDD    $0016,S
780f: ed 64           STD    $4,S
7811: ee e9 00 16     LDU    $0016,S
7815: 10 8e 00 02     LDY    #$0002
7819: 34 60           PSHS   U,Y
781b: 17 cf 47        LBSR   $4765
781e: 32 64           LEAS   $4,S
7820: e7 69           STB    $9,S
7822: e6 69           LDB    $9,S
7824: 4f              CLRA
7825: 10 83 00 ff     CMPD   #$00FF
7829: 10 26 00 21     LBNE   $784E
782d: ec 62           LDD    $2,S
782f: ed 64           STD    $4,S
7831: ee 62           LDU    $2,S
7833: 10 8e 00 02     LDY    #$0002
7837: 34 60           PSHS   U,Y
7839: 17 cf 29        LBSR   $4765
783c: 32 64           LEAS   $4,S
783e: e7 69           STB    $9,S
7840: e6 69           LDB    $9,S
7842: 4f              CLRA
7843: 10 83 00 ff     CMPD   #$00FF
7847: 10 26 00 03     LBNE   $784E
784b: 16 01 82        LBRA   $79D0
784e: ae 64           LDX    $4,S
7850: ac 62           CMPX   $2,S
7852: 10 26 00 04     LBNE   $785A
7856: c6 01           LDB    #$01
7858: e7 6b           STB    $B,S
785a: 6f 6c           CLR    $C,S
785c: 6f 68           CLR    $8,S
785e: e6 68           LDB    $8,S
7860: c1 04           CMPB   #$04
7862: 10 24 01 21     LBCC   $7987
7866: ce 24 f5        LDU    #$24F5
7869: e6 68           LDB    $8,S
786b: 4f              CLRA
786c: 1f 02           TFR    D,Y
786e: 34 60           PSHS   U,Y
7870: 86 01           LDA    #$01
7872: 8e fc e0        LDX    #$FCE0
7875: 17 04 72        LBSR   $7CEA
7878: 30 88 21        LEAX   $21,X
787b: ae 84           LDX    ,X
787d: af e9 00 16     STX    $0016,S
7881: ae e9 00 16     LDX    $0016,S
7885: 8c 00 10        CMPX   #$0010
7888: 10 26 00 03     LBNE   $788F
788c: 16 00 ef        LBRA   $797E
788f: ce 24 f5        LDU    #$24F5
7892: e6 68           LDB    $8,S
7894: 4f              CLRA
7895: 1f 02           TFR    D,Y
7897: 34 60           PSHS   U,Y
7899: 86 01           LDA    #$01
789b: 8e fc e0        LDX    #$FCE0
789e: 17 04 49        LBSR   $7CEA
78a1: 30 88 1f        LEAX   $1F,X
78a4: ae 84           LDX    ,X
78a6: af 66           STX    $6,S
78a8: ae e9 00 16     LDX    $0016,S
78ac: ac 64           CMPX   $4,S
78ae: 10 27 00 26     LBEQ   $78D8
78b2: ee e9 00 16     LDU    $0016,S
78b6: 10 8e 00 02     LDY    #$0002
78ba: 34 60           PSHS   U,Y
78bc: 17 ce a6        LBSR   $4765
78bf: 32 64           LEAS   $4,S
78c1: 4f              CLRA
78c2: 10 83 00 ff     CMPD   #$00FF
78c6: 10 26 00 0b     LBNE   $78D5
78ca: e6 6b           LDB    $B,S
78cc: c1 00           CMPB   #$00
78ce: 10 27 00 03     LBEQ   $78D5
78d2: 16 00 03        LBRA   $78D8
78d5: 16 00 a6        LBRA   $797E
78d8: e6 68           LDB    $8,S
78da: c1 00           CMPB   #$00
78dc: 10 26 00 12     LBNE   $78F2
78e0: fc 22 02        LDD    $2202
78e3: 84 01           ANDA   #$01
78e5: c4 00           ANDB   #$00
78e7: 10 83 00 00     CMPD   #$0000
78eb: 10 27 00 03     LBEQ   $78F2
78ef: 16 00 03        LBRA   $78F5
78f2: 16 00 34        LBRA   $7929
78f5: ce 00 06        LDU    #$0006
78f8: 10 8e 00 02     LDY    #$0002
78fc: 34 60           PSHS   U,Y
78fe: 17 f0 61        LBSR   $6962
7901: 32 64           LEAS   $4,S
7903: 1f 01           TFR    D,X
7905: af e8 10        STX    $10,S
7908: 33 6d           LEAU   $D,S
790a: 10 ae e8 10     LDY    $10,S
790e: 8e ea 5f        LDX    #$EA5F
7911: cc 00 06        LDD    #$0006
7914: 34 76           PSHS   U,Y,X,D
7916: 17 da ad        LBSR   $53C6
7919: 32 68           LEAS   $8,S
791b: c1 00           CMPB   #$00
791d: 10 27 00 05     LBEQ   $7926
7921: 6f 6a           CLR    $A,S
7923: 16 00 61        LBRA   $7987
7926: 16 00 33        LBRA   $795C
7929: ce 24 f5        LDU    #$24F5
792c: e6 68           LDB    $8,S
792e: 4f              CLRA
792f: 1f 02           TFR    D,Y
7931: 34 60           PSHS   U,Y
7933: 86 01           LDA    #$01
7935: 8e fc e0        LDX    #$FCE0
7938: 17 03 af        LBSR   $7CEA
793b: af e8 10        STX    $10,S
793e: 33 6d           LEAU   $D,S
7940: 10 ae e8 10     LDY    $10,S
7944: 8e ea 5f        LDX    #$EA5F
7947: cc 00 06        LDD    #$0006
794a: 34 76           PSHS   U,Y,X,D
794c: 17 da 77        LBSR   $53C6
794f: 32 68           LEAS   $8,S
7951: c1 00           CMPB   #$00
7953: 10 27 00 05     LBEQ   $795C
7957: 6f 6a           CLR    $A,S
7959: 16 00 2b        LBRA   $7987
795c: ae 66           LDX    $6,S
795e: 8c 00 02        CMPX   #$0002
7961: 10 27 00 15     LBEQ   $797A
7965: ae 66           LDX    $6,S
7967: 8c 00 03        CMPX   #$0003
796a: 10 27 00 0c     LBEQ   $797A
796e: ae 66           LDX    $6,S
7970: 8c 00 06        CMPX   #$0006
7973: 10 27 00 03     LBEQ   $797A
7977: 16 00 04        LBRA   $797E
797a: c6 01           LDB    #$01
797c: e7 6c           STB    $C,S
797e: e6 68           LDB    $8,S
7980: cb 01           ADDB   #$01
7982: e7 68           STB    $8,S
7984: 16 fe d7        LBRA   $785E
7987: e6 6a           LDB    $A,S
7989: c1 00           CMPB   #$00
798b: 10 27 00 2d     LBEQ   $79BC
798f: e6 6b           LDB    $B,S
7991: c1 00           CMPB   #$00
7993: 10 27 00 0e     LBEQ   $79A5
7997: f6 24 11        LDB    $2411
799a: c1 00           CMPB   #$00
799c: 10 27 00 05     LBEQ   $79A5
79a0: c6 01           LDB    #$01
79a2: 16 00 01        LBRA   $79A6
79a5: 5f              CLRB
79a6: c1 00           CMPB   #$00
79a8: 10 26 00 0b     LBNE   $79B7
79ac: e6 6c           LDB    $C,S
79ae: c1 00           CMPB   #$00
79b0: 10 26 00 03     LBNE   $79B7
79b4: 16 00 03        LBRA   $79BA
79b7: 16 00 02        LBRA   $79BC
79ba: 6f 6a           CLR    $A,S
79bc: e6 6a           LDB    $A,S
79be: 4f              CLRA
79bf: 1f 03           TFR    D,U
79c1: e6 69           LDB    $9,S
79c3: 4f              CLRA
79c4: 1f 02           TFR    D,Y
79c6: 8e 00 04        LDX    #$0004
79c9: 34 70           PSHS   U,Y,X
79cb: 17 fd 45        LBSR   $7713
79ce: 32 66           LEAS   $6,S
79d0: 32 e8 12        LEAS   $12,S
79d3: 39              RTS
; -------------------------------------------------------------------------------------
; Multi-state I/O port configuration request handler ($79D7).
; Allocates 10-byte frame via $7D50 (frame size from $FCE8).
; Initializes: direction ($3,S) = 3 (bidirectional default), return flag ($2,S) = 1.
;
; Dispatches on the current request type ($2217) via a jump table at $7B1B:
;   $0023 → numeric entry path at $79E8
;   $0013 → port mode application path at $7AC1
;   $0016 → sets $3A7F=2 (finalize), falls through
;   default → clears return flag, sets $3A7F=2
;
; Request $0023 path ($79E8):
;   HP-IB active ($2204 bit 3): decrements $3A7C (port index), reads $221F
;   to determine direction ($0012→0, $0013→1), calls $7770 to set port mode,
;   sets $3A7F=2 (done). Local: formats numeric entry via $4DE1, parses via
;   $4A36 into $3A7C, validates range 1..$23B2, displays the port number at
;   LCD position ($01,$07), decrements $3A7C (convert 1-based to 0-based),
;   sets $3A7F=1. Invalid input: calls $43FE($00A0) for error display.
;
; Request $0013 path ($7AC1): requires $3A7F==1 (port selected). Reads
;   $24E8[$3A7C] to determine port mode: mode 0 → direction=1, mode 3 →
;   direction=0. Calls $7770(direction, $3A7C) to apply.
;
; After dispatch, the display phase is selected by $3A7F:
;   0: initial prompt — displays $EC0B/$EC33 strings, sets up numeric entry
;      at ($07,$07) with validation $0A
;   1: port status — shows mode string from ROM table ($EC69/$EC77/$EC5B
;      based on port mode 0/1/other) and enable state from $24F0 bit 0
;   2: finalize — refreshes display via $59C6, clears $2202 bit 3 (entry done)
; -------------------------------------------------------------------------------------
79d4: fc fc e8        LDD    $FCE8
79d7: 17 03 76        LBSR   $7D50
79da: c6 03           LDB    #$03
79dc: e7 63           STB    $3,S
79de: c6 01           LDB    #$01
79e0: e7 62           STB    $2,S
79e2: be 22 17        LDX    $2217
79e5: 16 01 33        LBRA   $7B1B
79e8: fc 22 04        LDD    $2204
79eb: 84 00           ANDA   #$00
79ed: c4 08           ANDB   #$08
79ef: 10 83 00 00     CMPD   #$0000
79f3: 10 27 00 42     LBEQ   $7A39
79f7: f6 3a 7c        LDB    $3A7C
79fa: c0 01           SUBB   #$01
79fc: f7 3a 7c        STB    $3A7C
79ff: be 22 1f        LDX    $221F
7a02: 8c 00 12        CMPX   #$0012
7a05: 10 26 00 02     LBNE   $7A0B
7a09: 6f 63           CLR    $3,S
7a0b: be 22 1f        LDX    $221F
7a0e: 8c 00 13        CMPX   #$0013
7a11: 10 26 00 04     LBNE   $7A19
7a15: c6 01           LDB    #$01
7a17: e7 63           STB    $3,S
7a19: e6 63           LDB    $3,S
7a1b: 4f              CLRA
7a1c: 1f 03           TFR    D,U
7a1e: f6 3a 7c        LDB    $3A7C
7a21: 4f              CLRA
7a22: 1f 02           TFR    D,Y
7a24: 8e 00 04        LDX    #$0004
7a27: 34 70           PSHS   U,Y,X
7a29: 17 fd 44        LBSR   $7770
7a2c: 32 66           LEAS   $6,S
7a2e: c6 02           LDB    #$02
7a30: f7 3a 7f        STB    $3A7F
7a33: 16 00 f8        LBRA   $7B2E
7a36: 16 00 85        LBRA   $7ABE
7a39: c6 08           LDB    #$08
7a3b: 1d              SEX
7a3c: 1f 03           TFR    D,U
7a3e: 10 8e 00 00     LDY    #$0000
7a42: 8e 00 04        LDX    #$0004
7a45: 34 70           PSHS   U,Y,X
7a47: 17 d3 97        LBSR   $4DE1
7a4a: 32 66           LEAS   $6,S
7a4c: ce 24 14        LDU    #$2414
7a4f: 10 8e 00 02     LDY    #$0002
7a53: 34 60           PSHS   U,Y
7a55: 17 cf de        LBSR   $4A36
7a58: 32 64           LEAS   $4,S
7a5a: f7 3a 7c        STB    $3A7C
7a5d: f6 3a 7c        LDB    $3A7C
7a60: c1 00           CMPB   #$00
7a62: 10 23 00 0d     LBLS   $7A73
7a66: f6 3a 7c        LDB    $3A7C
7a69: f1 23 b2        CMPB   $23B2
7a6c: 10 22 00 03     LBHI   $7A73
7a70: 16 00 03        LBRA   $7A76
7a73: 16 00 3a        LBRA   $7AB0
7a76: ce 24 14        LDU    #$2414
7a79: f6 3a 7c        LDB    $3A7C
7a7c: 4f              CLRA
7a7d: 1f 02           TFR    D,Y
7a7f: 8e 00 04        LDX    #$0004
7a82: 34 70           PSHS   U,Y,X
7a84: 17 cf 4a        LBSR   $49D1
7a87: 32 66           LEAS   $6,S
7a89: ce 24 16        LDU    #$2416
7a8c: c6 01           LDB    #$01
7a8e: 1d              SEX
7a8f: 1f 02           TFR    D,Y
7a91: c6 07           LDB    #$07
7a93: 1d              SEX
7a94: 1f 01           TFR    D,X
7a96: cc 00 06        LDD    #$0006
7a99: 34 76           PSHS   U,Y,X,D
7a9b: 17 de 07        LBSR   $58A5
7a9e: 32 68           LEAS   $8,S
7aa0: f6 3a 7c        LDB    $3A7C
7aa3: c0 01           SUBB   #$01
7aa5: f7 3a 7c        STB    $3A7C
7aa8: c6 01           LDB    #$01
7aaa: f7 3a 7f        STB    $3A7F
7aad: 16 00 0e        LBRA   $7ABE
7ab0: ce 00 a0        LDU    #$00A0
7ab3: 10 8e 00 02     LDY    #$0002
7ab7: 34 60           PSHS   U,Y
7ab9: 17 c9 42        LBSR   $43FE
7abc: 32 64           LEAS   $4,S
7abe: 16 00 6d        LBRA   $7B2E
7ac1: f6 3a 7f        LDB    $3A7F
7ac4: c1 01           CMPB   #$01
7ac6: 10 27 00 03     LBEQ   $7ACD
7aca: 16 00 61        LBRA   $7B2E
7acd: 8e 24 e8        LDX    #$24E8
7ad0: f6 3a 7c        LDB    $3A7C
7ad3: 3a              ABX
7ad4: e6 84           LDB    ,X
7ad6: e7 64           STB    $4,S
7ad8: e6 64           LDB    $4,S
7ada: c1 00           CMPB   #$00
7adc: 10 26 00 07     LBNE   $7AE7
7ae0: c6 01           LDB    #$01
7ae2: e7 63           STB    $3,S
7ae4: 16 00 0a        LBRA   $7AF1
7ae7: e6 64           LDB    $4,S
7ae9: c1 03           CMPB   #$03
7aeb: 10 26 00 02     LBNE   $7AF1
7aef: 6f 63           CLR    $3,S
7af1: e6 63           LDB    $3,S
7af3: 4f              CLRA
7af4: 1f 03           TFR    D,U
7af6: f6 3a 7c        LDB    $3A7C
7af9: 4f              CLRA
7afa: 1f 02           TFR    D,Y
7afc: 8e 00 04        LDX    #$0004
7aff: 34 70           PSHS   U,Y,X
7b01: 17 fc 6c        LBSR   $7770
7b04: 32 66           LEAS   $6,S
7b06: 16 00 25        LBRA   $7B2E
7b09: c6 02           LDB    #$02
7b0b: f7 3a 7f        STB    $3A7F
7b0e: 16 00 1d        LBRA   $7B2E
7b11: 6f 62           CLR    $2,S
7b13: c6 02           LDB    #$02
7b15: f7 3a 7f        STB    $3A7F
7b18: 16 00 13        LBRA   $7B2E
7b1b: 8c 00 13        CMPX   #$0013
7b1e: 27 a1           BEQ    $7AC1
7b20: 8c 00 16        CMPX   #$0016
7b23: 27 e4           BEQ    $7B09
7b25: 8c 00 23        CMPX   #$0023
7b28: 10 27 fe bc     LBEQ   $79E8
7b2c: 20 e3           BRA    $7B11
7b2e: f6 3a 7f        LDB    $3A7F
7b31: c1 00           CMPB   #$00
7b33: 10 26 00 4e     LBNE   $7B85
7b37: ce ec 0b        LDU    #$EC0B
7b3a: c6 28           LDB    #$28
7b3c: 1d              SEX
7b3d: 1f 02           TFR    D,Y
7b3f: 5f              CLRB
7b40: 1d              SEX
7b41: 1f 01           TFR    D,X
7b43: cc 00 06        LDD    #$0006
7b46: 34 76           PSHS   U,Y,X,D
7b48: 17 dd 5a        LBSR   $58A5
7b4b: 32 68           LEAS   $8,S
7b4d: ce ec 33        LDU    #$EC33
7b50: c6 28           LDB    #$28
7b52: 1d              SEX
7b53: 1f 02           TFR    D,Y
7b55: c6 40           LDB    #$40
7b57: 1d              SEX
7b58: 1f 01           TFR    D,X
7b5a: cc 00 06        LDD    #$0006
7b5d: 34 76           PSHS   U,Y,X,D
7b5f: 17 dd 43        LBSR   $58A5
7b62: 32 68           LEAS   $8,S
7b64: c6 07           LDB    #$07
7b66: 1d              SEX
7b67: 1f 03           TFR    D,U
7b69: 10 8e 00 00     LDY    #$0000
7b6d: c6 07           LDB    #$07
7b6f: 1d              SEX
7b70: 1f 01           TFR    D,X
7b72: c6 01           LDB    #$01
7b74: 1d              SEX
7b75: 34 76           PSHS   U,Y,X,D
7b77: ce 00 00        LDU    #$0000
7b7a: 10 8e 00 0a     LDY    #$000A
7b7e: 34 60           PSHS   U,Y
7b80: 17 b0 b2        LBSR   $2C35
7b83: 32 6c           LEAS   $C,S
7b85: f6 3a 7f        LDB    $3A7F
7b88: c1 01           CMPB   #$01
7b8a: 10 26 00 78     LBNE   $7C06
7b8e: 8e 24 e8        LDX    #$24E8
7b91: f6 3a 7c        LDB    $3A7C
7b94: 3a              ABX
7b95: e6 84           LDB    ,X
7b97: e7 64           STB    $4,S
7b99: e6 64           LDB    $4,S
7b9b: c1 00           CMPB   #$00
7b9d: 10 26 00 08     LBNE   $7BA9
7ba1: cc ec 69        LDD    #$EC69
7ba4: ed 67           STD    $7,S
7ba6: 16 00 15        LBRA   $7BBE
7ba9: e6 64           LDB    $4,S
7bab: c1 01           CMPB   #$01
7bad: 10 26 00 08     LBNE   $7BB9
7bb1: cc ec 77        LDD    #$EC77
7bb4: ed 67           STD    $7,S
7bb6: 16 00 05        LBRA   $7BBE
7bb9: cc ec 5b        LDD    #$EC5B
7bbc: ed 67           STD    $7,S
7bbe: ee 67           LDU    $7,S
7bc0: c6 0e           LDB    #$0E
7bc2: 1d              SEX
7bc3: 1f 02           TFR    D,Y
7bc5: c6 53           LDB    #$53
7bc7: 1d              SEX
7bc8: 1f 01           TFR    D,X
7bca: cc 00 06        LDD    #$0006
7bcd: 34 76           PSHS   U,Y,X,D
7bcf: 17 dc d3        LBSR   $58A5
7bd2: 32 68           LEAS   $8,S
7bd4: 8e 24 f0        LDX    #$24F0
7bd7: f6 3a 7c        LDB    $3A7C
7bda: 3a              ABX
7bdb: e6 84           LDB    ,X
7bdd: c4 01           ANDB   #$01
7bdf: 10 27 00 08     LBEQ   $7BEB
7be3: cc ec 77        LDD    #$EC77
7be6: ed 65           STD    $5,S
7be8: 16 00 05        LBRA   $7BF0
7beb: cc ec 69        LDD    #$EC69
7bee: ed 65           STD    $5,S
7bf0: ee 65           LDU    $5,S
7bf2: c6 0e           LDB    #$0E
7bf4: 1d              SEX
7bf5: 1f 02           TFR    D,Y
7bf7: c6 1a           LDB    #$1A
7bf9: 1d              SEX
7bfa: 1f 01           TFR    D,X
7bfc: cc 00 06        LDD    #$0006
7bff: 34 76           PSHS   U,Y,X,D
7c01: 17 dc a1        LBSR   $58A5
7c04: 32 68           LEAS   $8,S
7c06: f6 3a 7f        LDB    $3A7F
7c09: c1 02           CMPB   #$02
7c0b: 10 26 00 23     LBNE   $7C32
7c0f: fc 22 04        LDD    $2204
7c12: 84 00           ANDA   #$00
7c14: c4 08           ANDB   #$08
7c16: 10 83 00 00     CMPD   #$0000
7c1a: 10 26 00 0a     LBNE   $7C28
7c1e: ce 00 00        LDU    #$0000
7c21: 34 40           PSHS   U
7c23: 17 dd a0        LBSR   $59C6
7c26: 32 62           LEAS   $2,S
7c28: fc 22 02        LDD    $2202
7c2b: 84 ff           ANDA   #$FF
7c2d: c4 f7           ANDB   #$F7
7c2f: fd 22 02        STD    $2202
7c32: e6 62           LDB    $2,S
7c34: e7 69           STB    $9,S
7c36: 32 6a           LEAS   $A,S
7c38: 39              RTS
; -------------------------------------------------------------------------------------
; I/O port configuration request initial UI setup ($7C3C).
; Allocates 2-byte frame via $7D50.
;
; If HP-IB is active ($2204 bit 3 set): copies the current selector from
; $2219 to $3A7C, posts to the HP-IB handler via $2415 with type=7, then exits.
;
; If local (front-panel): sets $2204 bit 4 (UI-active), displays prompt
; strings $EC0B on LCD row 0 at ($28,$00) and $EC33 on row 1 at ($28,$40).
; Sets up a numeric entry field via $2C35 at cursor ($07,$07) with
; validation mode $0A (decimal integer).
; Clears $3A7F (wizard state = initial), installs callback $F9D4 at $220D
; (paged ROM entry point for the multi-state handler $79D7), and sets
; $2202 bit 3 to signal active numeric entry.
;
; This is the entry point for the I/O port configuration wizard. The
; subsequent states (port selection → mode display → apply) are handled
; by $79D7, which is invoked via the $F9D4 callback.
; -------------------------------------------------------------------------------------
7c39: fc fc d8        LDD    $FCD8
7c3c: 17 01 11        LBSR   $7D50
7c3f: fc 22 04        LDD    $2204
7c42: 84 00           ANDA   #$00
7c44: c4 08           ANDB   #$08
7c46: 10 83 00 00     CMPD   #$0000
7c4a: 10 27 00 1a     LBEQ   $7C68
7c4e: f6 22 19        LDB    $2219
7c51: f7 3a 7c        STB    $3A7C
7c54: ce 00 00        LDU    #$0000
7c57: 10 8e 00 07     LDY    #$0007
7c5b: 8e 00 04        LDX    #$0004
7c5e: 34 70           PSHS   U,Y,X
7c60: 17 a7 b2        LBSR   $2415
7c63: 32 66           LEAS   $6,S
7c65: 16 00 58        LBRA   $7CC0
7c68: fc 22 04        LDD    $2204
7c6b: 8a 00           ORA    #$00
7c6d: ca 10           ORB    #$10
7c6f: fd 22 04        STD    $2204
7c72: ce ec 0b        LDU    #$EC0B
7c75: c6 28           LDB    #$28
7c77: 1d              SEX
7c78: 1f 02           TFR    D,Y
7c7a: 5f              CLRB
7c7b: 1d              SEX
7c7c: 1f 01           TFR    D,X
7c7e: cc 00 06        LDD    #$0006
7c81: 34 76           PSHS   U,Y,X,D
7c83: 17 dc 1f        LBSR   $58A5
7c86: 32 68           LEAS   $8,S
7c88: ce ec 33        LDU    #$EC33
7c8b: c6 28           LDB    #$28
7c8d: 1d              SEX
7c8e: 1f 02           TFR    D,Y
7c90: c6 40           LDB    #$40
7c92: 1d              SEX
7c93: 1f 01           TFR    D,X
7c95: cc 00 06        LDD    #$0006
7c98: 34 76           PSHS   U,Y,X,D
7c9a: 17 dc 08        LBSR   $58A5
7c9d: 32 68           LEAS   $8,S
7c9f: c6 07           LDB    #$07
7ca1: 1d              SEX
7ca2: 1f 03           TFR    D,U
7ca4: 10 8e 00 00     LDY    #$0000
7ca8: c6 07           LDB    #$07
7caa: 1d              SEX
7cab: 1f 01           TFR    D,X
7cad: c6 01           LDB    #$01
7caf: 1d              SEX
7cb0: 34 76           PSHS   U,Y,X,D
7cb2: ce 00 00        LDU    #$0000
7cb5: 10 8e 00 0a     LDY    #$000A
7cb9: 34 60           PSHS   U,Y
7cbb: 17 af 77        LBSR   $2C35
7cbe: 32 6c           LEAS   $C,S
7cc0: 7f 3a 7f        CLR    $3A7F
7cc3: cc f9 d4        LDD    #$F9D4
7cc6: fd 22 0d        STD    $220D
7cc9: fc 22 02        LDD    $2202
7ccc: 8a 00           ORA    #$00
7cce: ca 08           ORB    #$08
7cd0: fd 22 02        STD    $2202
7cd3: 32 62           LEAS   $2,S
7cd5: 39              RTS
7cd6: 00 01           NEG    <$01
7cd8: 00 00           NEG    <$00
7cda: 01 a9           NEG    <$A9
7cdc: 00 02           NEG    <$02
7cde: 00 03           NEG    <$03
7ce0: 00 01           NEG    <$01
7ce2: 00 00           NEG    <$00
7ce4: 00 23           NEG    <$23
; ROM data: frame-size constants referenced by nearby functions.
; $7CE6 = $0010, $7CE8 = $0008. NOT executable code.
7ce6: 00 10           NEG    <$10
7ce8: 00 08           NEG    <$08
; =====================================================================================
; Compiler runtime: multi-dimensional array indexer — $7CEA.
; Computes the address of an element in a multi-dimensional array.
; Entry: A = number of dimensions, X → descriptor table (array of dimension sizes as 16-bit
; words), stack contains index values pushed by caller.
; Returns: X = computed element address/offset.
; The algorithm multiplies each index by the product of subsequent dimension sizes
; (row-major order) and sums the results.
; Subroutine $7D48: advances the running address pointer ($7,S) by 2 bytes.
; =====================================================================================
7cea: 34 12           PSHS   X,A
7cec: 32 7c           LEAS   -$4,S       ; allocate 4-byte local frame
7cee: ab 64           ADDA   $4,S        ; compute stack offsets for index array
7cf0: 8b 09           ADDA   #$09
7cf2: a7 61           STA    $1,S        ; save computed stack depth reference
7cf4: 80 02           SUBA   #$02
7cf6: a7 e4           STA    ,S          ; current dimension pointer
7cf8: ee 67           LDU    $7,S        ; save caller's frame pointer in U
7cfa: ec 84           LDD    ,X          ; load first dimension pair
7cfc: e7 63           STB    $3,S        ; save low byte (element size)
7cfe: e0 64           SUBB   $4,S        ; remaining dimension count
7d00: e7 62           STB    $2,S        ; loop counter for trailing dimensions
7d02: 8d 44           BSR    $7D48       ; advance pointer by 2
; First index: load directly, add base offset
7d04: a6 61           LDA    $1,S
7d06: ec e6           LDD    A,S         ; load first index from stack
7d08: e3 f8 05        ADDD   [$05,S]     ; add base element offset
7d0b: ed 67           STD    $7,S        ; store running address
; Process each dimension: multiply index by dimension size, accumulate
7d0d: 8d 39           BSR    $7D48       ; advance dimension descriptor pointer
7d0f: ae f8 05        LDX    [$05,S]     ; X = current dimension size
7d12: a6 e4           LDA    ,S          ; current stack offset for index
7d14: ec e6           LDD    A,S         ; D = index for this dimension
7d16: 6a e4           DEC    ,S          ; } step stack offset back by 2
7d18: 6a e4           DEC    ,S          ; }
7d1a: 17 00 a2        LBSR   $7DBF       ; signed 16×16 multiply: X × D → X:D
7d1d: e3 67           ADDD   $7,S        ; add to running address
7d1f: ed 67           STD    $7,S
7d21: 6a 64           DEC    $4,S        ; decrement dimension loop counter
7d23: 26 e8           BNE    $7D0D       ; more dimensions → continue
; Handle element-size scaling for trailing dimensions
7d25: e6 62           LDB    $2,S        ; remaining count
7d27: 27 16           BEQ    $7D3F       ; zero → done
7d29: e6 63           LDB    $3,S        ; element size
7d2b: eb 63           ADDB   $3,S        ; double it (stride for 16-bit entries)
7d2d: 4f              CLRA
7d2e: e3 65           ADDD   $5,S        ; offset into descriptor table
7d30: ed 65           STD    $5,S
7d32: ec f8 05        LDD    [$05,S]     ; load next dimension element
7d35: e3 67           ADDD   $7,S        ; add to running address
7d37: ed 67           STD    $7,S
7d39: 8d 0d           BSR    $7D48       ; advance pointer
7d3b: 6a 62           DEC    $2,S        ; decrement remaining count
7d3d: 26 f3           BNE    $7D32       ; more → loop
7d3f: ae 67           LDX    $7,S        ; X = final computed address
7d41: a6 61           LDA    $1,S        ; stack cleanup depth
7d43: ef e6           STU    A,S         ; restore caller's frame pointer
7d45: 32 e6           LEAS   A,S         ; deallocate index array from stack
7d47: 39              RTS
; Helper: advance running pointer by 2 bytes (element size for 16-bit entries).
7d48: ec 67           LDD    $7,S
7d4a: c3 00 02        ADDD   #$0002
7d4d: ed 67           STD    $7,S
7d4f: 39              RTS
; =====================================================================================
; Common stack-frame allocator — $7D50.
; Convention: the `LDD $xxxx` instruction preceding `LBSR $7D50` loads the 16-bit frame size
; directly from a ROM constant at CPU address $xxxx into D. This function:
;   1. Pops the return address into U (the caller's next instruction).
;   2. Negates D (COMA; COMB; ADDD #1 = two's complement).
;   3. Adjusts S by the negated value (LEAS D,S → S = S - frame_size).
;   4. Pushes the new frame base (X = S) onto the stack.
;   5. Returns to the caller via TFR U,PC.
; After return, the caller's stack has: [frame_base_ptr(2 bytes)] [frame(N bytes)] [prev stack].
; Functions access frame locals via offsets from S: S+0 = frame base pointer, S+2 = first local.
; =====================================================================================
7d50: ee e1           LDU    ,S++        ; pop return address into U
7d52: 43              COMA               ; } negate D (two's complement)
7d53: 53              COMB               ; }
7d54: c3 00 01        ADDD   #$0001      ; }
7d57: 32 eb           LEAS   D,S         ; allocate frame: S -= frame_size
7d59: 30 e4           LEAX   ,S          ; X = new frame base
7d5b: 34 10           PSHS   X           ; push frame base pointer
7d5d: 1f 35           TFR    U,PC        ; return to caller
; =====================================================================================
; Hardware RESET entry point — $7D5F (CPU $FD5F).
; All vectors except FIRQ/IRQ/NMI point here. Initializes stack to $21FF (top of 8KB RAM),
; pushes a zero word (sentinel for the stack frame convention), and enters cold start at $03A0.
; =====================================================================================
7d5f: 10 ce 21 ff     LDS    #$21FF      ; initialize stack pointer (top of RAM at $2000-$21FF)
7d63: 8e 00 00        LDX    #$0000
7d66: 34 10           PSHS   X           ; push zero sentinel
7d68: 17 86 35        LBSR   $03A0       ; → $03A0: cold start sequence
7d6b: 17 02 5f        LBSR   $7FCD       ; → $7FCD: infinite halt loop (should not be reached)
; ROM data / unreachable code after reset entry ($7D6E-$7D74) — not meaningful as instructions.
7d6e: ff ff 34        STU    $FF34
7d71: 01 34           NEG    <$34
7d73: 02 1d           XNC    <$1D
; =====================================================================================
; Compiler runtime: signed byte subtract — $7D75.
; Computes D = sign_extend(B@$2,S) - D. Used by compiled C code for char subtraction.
; =====================================================================================
7d75: 34 06           PSHS   D
7d77: e6 62           LDB    $2,S        ; B = saved byte from caller's frame
7d79: 1d              SEX               ; sign-extend B → D
7d7a: a3 e4           SUBD   ,S          ; D = sign_extend(B) - original_D
7d7c: 32 63           LEAS   $3,S        ; clean up
7d7e: 35 81           PULS   CC,PC
; =====================================================================================
; Compiler runtime: unsigned byte add — $7D80.
; Computes D = zero_extend(A) + zero_extend(B@$2,S). Preserves U, X.
; =====================================================================================
7d80: 34 51           PSHS   U,X,CC
7d82: 34 02           PSHS   A
7d84: 4f              CLRA              ; zero-extend: A=0, B intact from push
7d85: 34 06           PSHS   D
7d87: e6 62           LDB    $2,S        ; reload original A (now at offset 2)
7d89: e3 e4           ADDD   ,S          ; D = zero_extend(A_orig) + zero_extend(B_orig)
7d8b: 32 63           LEAS   $3,S
7d8d: 35 d1           PULS   CC,X,U,PC
; =====================================================================================
; Compiler runtime: signed byte subtract (CC-preserving variant) — $7D8F.
; Computes D = sign_extend(B@$2,S) - sign_extend(A). Restores CC from stack.
; =====================================================================================
7d8f: 34 01           PSHS   CC
7d91: 34 02           PSHS   A
7d93: 4f              CLRA
7d94: 34 06           PSHS   D
7d96: e6 62           LDB    $2,S        ; reload original A
7d98: a3 e4           SUBD   ,S          ; D = sign_extend(A_orig) - zero_extend(B_orig)
7d9a: 32 63           LEAS   $3,S
7d9c: 35 81           PULS   CC,PC
; =====================================================================================
; Compiler runtime: arithmetic shift — $7D9E.
; Shifts A by B positions. B > 0 → left shift (ASL), B < 0 → right shift (LSR).
; Returns result in B (low byte only). Preserves original A.
; =====================================================================================
7d9e: 34 03           PSHS   A,CC
7da0: c1 00           CMPB   #$00
7da2: 2d 08           BLT    $7DAC       ; B < 0 → right shift
7da4: 27 0c           BEQ    $7DB2       ; B = 0 → no shift
7da6: 48              ASLA              ; left shift A by 1
7da7: 5a              DECB              ; decrement count
7da8: 27 08           BEQ    $7DB2       ; done
7daa: 20 fa           BRA    $7DA6
7dac: 44              LSRA              ; right shift A by 1
7dad: 5c              INCB              ; increment toward 0
7dae: 27 02           BEQ    $7DB2       ; done
7db0: 20 fa           BRA    $7DAC
7db2: 1f 89           TFR    A,B         ; result in B
7db4: 35 83           PULS   CC,A,PC     ; restore original A and return
; =====================================================================================
; Compiler runtime: test-and-branch for Z flag — $7DB6.
; If Z set (D == 0): returns via $7FC6 (B=1, Z clear). Otherwise: $7FC0 (B=0, Z set).
; Used by compiled C boolean coercion (converts D==0 to B=1 and vice versa).
; =====================================================================================
7db6: 34 01           PSHS   CC
7db8: 10 27 02 0a     LBEQ   $7FC6       ; D == 0 → return B=1, Z clear
7dbc: 16 02 01        LBRA   $7FC0       ; D != 0 → return B=0, Z set
; =====================================================================================
; Compiler runtime: 16×16 signed multiply — $7DBF.
; Computes X × D (both signed 16-bit) → 32-bit result in X:D (X=high, D=low).
; Algorithm: convert both operands to positive, do unsigned multiply via four 8×8 MULs
; with carry propagation, then negate result if the input signs differed.
; Stack frame layout (7 bytes): $0,S/$1,S = |X|, $2,S = sign toggle, $3,S-$6,S = product.
; Subroutine at $7DE7: if D <= 0, negate D and toggle sign flag at $4,S.
; =====================================================================================
7dbf: 34 07           PSHS   D,CC        ; save multiplicand (D) and CC
7dc1: 32 79           LEAS   -$7,S       ; allocate 7-byte frame
7dc3: 86 ff           LDA    #$FF
7dc5: a7 62           STA    $2,S        ; sign toggle = $FF (odd parity → result negative)
7dc7: 6f 64           CLR    $4,S        ; } clear product accumulator
7dc9: 6f 63           CLR    $3,S        ; }
; Convert multiplier (X) to absolute value
7dcb: 1f 10           TFR    X,D
7dcd: 8d 18           BSR    $7DE7       ; negate D if <= 0, toggle sign
7dcf: ed e9 00 00     STD    $0000,S     ; store |X| in frame
7dd3: 10 27 00 6f     LBEQ   $7E46       ; |X| = 0 → result is 0
; Convert multiplicand (original D) to absolute value
7dd7: ec e9 00 08     LDD    $0008,S     ; reload original D from stack
7ddb: 8d 0a           BSR    $7DE7       ; negate if <= 0, toggle sign
7ddd: ed e9 00 08     STD    $0008,S     ; store |D| back
7de1: 10 27 00 61     LBEQ   $7E46       ; |D| = 0 → result is 0
7de5: 20 0e           BRA    $7DF5       ; → unsigned multiply core
; Helper: make D positive, toggle sign flag if negated
7de7: 10 83 00 00     CMPD   #$0000
7deb: 2e 07           BGT    $7DF4       ; > 0 → already positive
7ded: 60 64           NEG    $4,S        ; toggle sign counter (odd = negative result)
7def: 43              COMA               ; } two's-complement negate D
7df0: 53              COMB               ; }
7df1: c3 00 01        ADDD   #$0001      ; }
7df4: 39              RTS
; Unsigned 16×16 multiply core: |X| × |D| using four 8×8 MULs
; Product in $3,S..$6,S (32-bit big-endian)
7df5: a6 e9 00 01     LDA    $0001,S     ; X_lo
7df9: e6 e9 00 09     LDB    $0009,S     ; D_lo
7dfd: 3d              MUL               ; X_lo × D_lo → D
7dfe: ed 65           STD    $5,S        ; product bytes 2-3 (low half)
7e00: a6 e9 00 00     LDA    $0000,S     ; X_hi
7e04: e6 e9 00 09     LDB    $0009,S     ; D_lo
7e08: 3d              MUL               ; X_hi × D_lo → D
7e09: e3 64           ADDD   $4,S        ; add to product bytes 1-2
7e0b: ed 64           STD    $4,S
7e0d: 24 02           BCC    $7E11
7e0f: 6c 63           INC    $3,S        ; propagate carry to byte 0
7e11: a6 e9 00 01     LDA    $0001,S     ; X_lo
7e15: e6 e9 00 08     LDB    $0008,S     ; D_hi
7e19: 3d              MUL               ; X_lo × D_hi → D
7e1a: e3 64           ADDD   $4,S        ; add to product bytes 1-2
7e1c: ed 64           STD    $4,S
7e1e: 24 02           BCC    $7E22
7e20: 6c 63           INC    $3,S        ; propagate carry
7e22: a6 e9 00 00     LDA    $0000,S     ; X_hi
7e26: e6 e9 00 08     LDB    $0008,S     ; D_hi
7e2a: 3d              MUL               ; X_hi × D_hi → D
7e2b: e3 63           ADDD   $3,S        ; add to product bytes 0-1
7e2d: ed 63           STD    $3,S
; Apply sign: negate 32-bit result if sign toggle is odd
7e2f: a6 e9 00 02     LDA    $0002,S     ; sign toggle byte
7e33: 48              ASLA              ; bit 7 into carry (odd toggles → C set)
7e34: ec 65           LDD    $5,S        ; load low 16 bits of product
7e36: ae 63           LDX    $3,S        ; load high 16 bits
7e38: 25 12           BCS    $7E4C       ; sign toggle odd → negate
; Even toggles → result is positive, just negate both halves (they're already positive)
7e3a: 1e 10           EXG    X,D
7e3c: 17 ff b0        LBSR   $7DEF       ; negate high 16 bits via helper at $7DEF
7e3f: 1e 10           EXG    X,D
7e41: 17 ff ab        LBSR   $7DEF       ; negate low 16 bits
7e44: 20 06           BRA    $7E4C
; Zero result path
7e46: cc 00 00        LDD    #$0000
7e49: 8e 00 00        LDX    #$0000
; Common exit
7e4c: 32 67           LEAS   $7,S        ; deallocate frame
7e4e: 35 01           PULS   CC
7e50: 32 62           LEAS   $2,S
7e52: 39              RTS
; Compiler runtime: 16-bit absolute value — $7E53. Negates D if negative.
7e53: 10 83 00 00     CMPD   #$0000
7e57: 2c 05           BGE    $7E5E       ; already positive → return
7e59: 43              COMA               ; } negate D
7e5a: 53              COMB               ; }
7e5b: c3 00 01        ADDD   #$0001      ; }
7e5e: 39              RTS
; =====================================================================================
; Compiler runtime: 8÷8 unsigned divide — $7E5F.
; Divides A by B. Returns quotient in B, remainder lost. If B=0, returns B=0.
; Uses non-restoring division algorithm with bit-by-bit trial subtraction.
; =====================================================================================
7e5f: 34 01           PSHS   CC
7e61: 32 7c           LEAS   -$4,S
7e63: 6f e9 00 00     CLR    $0000,S
7e67: 6f e9 00 03     CLR    $0003,S
7e6b: a7 e9 00 01     STA    $0001,S
7e6f: 27 47           BEQ    $7EB8
7e71: c4 ff           ANDB   #$FF
7e73: 27 45           BEQ    $7EBA
7e75: 6c e9 00 03     INC    $0003,S
7e79: 58              ASLB
7e7a: 25 02           BCS    $7E7E
7e7c: 20 f7           BRA    $7E75
7e7e: 56              RORB
7e7f: e7 e9 00 02     STB    $0002,S
7e83: a0 e9 00 02     SUBA   $0002,S
7e87: 25 0d           BCS    $7E96
7e89: e6 e9 00 00     LDB    $0000,S
7e8d: 58              ASLB
7e8e: cb 01           ADDB   #$01
7e90: e7 e9 00 00     STB    $0000,S
7e94: 20 0d           BRA    $7EA3
7e96: ab e9 00 02     ADDA   $0002,S
7e9a: e6 e9 00 00     LDB    $0000,S
7e9e: 58              ASLB
7e9f: e7 e9 00 00     STB    $0000,S
7ea3: e6 e9 00 02     LDB    $0002,S
7ea7: 54              LSRB
7ea8: e7 e9 00 02     STB    $0002,S
7eac: 6a e9 00 03     DEC    $0003,S
7eb0: 26 d1           BNE    $7E83
7eb2: e6 e9 00 00     LDB    $0000,S
7eb6: 20 02           BRA    $7EBA
7eb8: c6 00           LDB    #$00
7eba: 32 64           LEAS   $4,S
7ebc: 35 81           PULS   CC,PC
; Compiler runtime: unsigned compare B — $7EBE. Returns B=0/Z=1 if LS, B=1/Z=0 if HI.
7ebe: 34 01           PSHS   CC
7ec0: 10 23 00 fc     LBLS   $7FC0       ; LS (lower or same) → B=0, Z set
7ec4: 16 00 ff        LBRA   $7FC6       ; HI (higher) → B=1, Z clear
; =====================================================================================
; Compiler runtime: 16÷16 unsigned divide — $7EC7.
; Divides X by D. Returns quotient in D, remainder in X. If D=0, returns D=0, X=0.
; Uses non-restoring division with 16-bit trial subtraction, iterating over all
; significant bits of the divisor.
; =====================================================================================
7ec7: 34 01           PSHS   CC
7ec9: 32 79           LEAS   -$7,S
7ecb: 6f e9 00 00     CLR    $0000,S
7ecf: 6f e9 00 01     CLR    $0001,S
7ed3: 6f e9 00 04     CLR    $0004,S
7ed7: af e9 00 02     STX    $0002,S
7edb: 10 27 00 59     LBEQ   $7F38
7edf: ed e9 00 05     STD    $0005,S
7ee3: 10 27 00 57     LBEQ   $7F3E
7ee7: 6c e9 00 04     INC    $0004,S
7eeb: 58              ASLB
7eec: 49              ROLA
7eed: 25 02           BCS    $7EF1
7eef: 20 f6           BRA    $7EE7
7ef1: 46              RORA
7ef2: 56              RORB
7ef3: ed e9 00 05     STD    $0005,S
7ef7: ec e9 00 02     LDD    $0002,S
7efb: a3 e9 00 05     SUBD   $0005,S
7eff: 25 13           BCS    $7F14
7f01: ed e9 00 02     STD    $0002,S
7f05: ec e9 00 00     LDD    $0000,S
7f09: 58              ASLB
7f0a: 49              ROLA
7f0b: c3 00 01        ADDD   #$0001
7f0e: ed e9 00 00     STD    $0000,S
7f12: 20 0a           BRA    $7F1E
7f14: ec e9 00 00     LDD    $0000,S
7f18: 58              ASLB
7f19: 49              ROLA
7f1a: ed e9 00 00     STD    $0000,S
7f1e: ec e9 00 05     LDD    $0005,S
7f22: 44              LSRA
7f23: 56              RORB
7f24: ed e9 00 05     STD    $0005,S
7f28: 6a e9 00 04     DEC    $0004,S
7f2c: 26 c9           BNE    $7EF7
7f2e: ae e9 00 02     LDX    $0002,S
7f32: ec e9 00 00     LDD    $0000,S
7f36: 20 06           BRA    $7F3E
7f38: cc 00 00        LDD    #$0000
7f3b: 8e 00 00        LDX    #$0000
7f3e: 32 67           LEAS   $7,S
7f40: 35 81           PULS   CC,PC
; =====================================================================================
; Compiler runtime: 16×16 unsigned multiply — $7F42.
; Computes X × D (both unsigned 16-bit) → 32-bit result in X:D (X=high, D=low).
; Same four-MUL cross-product algorithm as $7DBF but without sign handling.
; If either operand is zero, returns X:D = 0.
; =====================================================================================
7f42: 34 01           PSHS   CC
7f44: 32 78           LEAS   -$8,S
7f46: 6f 62           CLR    $2,S
7f48: 6f 63           CLR    $3,S
7f4a: af e9 00 00     STX    $0000,S
7f4e: 10 27 00 48     LBEQ   $7F9A
7f52: ed e9 00 06     STD    $0006,S
7f56: 10 27 00 40     LBEQ   $7F9A
7f5a: a6 e9 00 01     LDA    $0001,S
7f5e: e6 e9 00 07     LDB    $0007,S
7f62: 3d              MUL
7f63: ed 64           STD    $4,S
7f65: a6 e9 00 00     LDA    $0000,S
7f69: e6 e9 00 07     LDB    $0007,S
7f6d: 3d              MUL
7f6e: e3 63           ADDD   $3,S
7f70: ed 63           STD    $3,S
7f72: 24 02           BCC    $7F76
7f74: 6c 62           INC    $2,S
7f76: a6 e9 00 01     LDA    $0001,S
7f7a: e6 e9 00 06     LDB    $0006,S
7f7e: 3d              MUL
7f7f: e3 63           ADDD   $3,S
7f81: ed 63           STD    $3,S
7f83: 24 02           BCC    $7F87
7f85: 6c 62           INC    $2,S
7f87: a6 e9 00 00     LDA    $0000,S
7f8b: e6 e9 00 06     LDB    $0006,S
7f8f: 3d              MUL
7f90: e3 62           ADDD   $2,S
7f92: ed 62           STD    $2,S
7f94: ec 64           LDD    $4,S
7f96: ae 62           LDX    $2,S
7f98: 20 06           BRA    $7FA0
7f9a: cc 00 00        LDD    #$0000
7f9d: 8e 00 00        LDX    #$0000
7fa0: 32 68           LEAS   $8,S
7fa2: 35 81           PULS   CC,PC
; =====================================================================================
; Compiler runtime: 16-bit arithmetic shift by signed count — $7FA4.
; Entry: B = value to shift (sign-extended to D), X = shift count.
; X > 0 → left shift D by X, X < 0 → right shift D by |X|, X = 0 → no shift.
; Returns shifted value in D.
; =====================================================================================
7fa4: 34 11           PSHS   X,CC
7fa6: 1d              SEX               ; sign-extend B → D (16-bit value)
7fa7: 1e 10           EXG    X,D         ; X = value, D = shift count
7fa9: 8c 00 00        CMPX   #$0000      ; shift count = 0?
7fac: 27 10           BEQ    $7FBE       ; yes → no shift
7fae: 2a 08           BPL    $7FB8       ; positive → left shift
; Right shift loop (X < 0, counting up toward 0)
7fb0: 44              LSRA              ; } logical right shift D by 1
7fb1: 56              RORB              ; }
7fb2: 30 01           LEAX   $1,X        ; increment count toward 0
7fb4: 26 fa           BNE    $7FB0
7fb6: 27 06           BEQ    $7FBE
; Left shift loop (X > 0, counting down toward 0)
7fb8: 58              ASLB              ; } arithmetic left shift D by 1
7fb9: 49              ROLA              ; }
7fba: 30 1f           LEAX   -$1,X       ; decrement count toward 0
7fbc: 26 fa           BNE    $7FB8
7fbe: 35 91           PULS   CC,X,PC
; Compiler runtime: return B=0, Z=1 (false) — $7FC0.
7fc0: 5f              CLRB
7fc1: 35 01           PULS   CC
7fc3: 1a 04           ORCC   #$04        ; set Z flag
7fc5: 39              RTS
; Compiler runtime: return B=1, Z=0 (true) — $7FC6.
7fc6: c6 01           LDB    #$01
7fc8: 35 01           PULS   CC
7fca: 1c fb           ANDCC  #$FB        ; clear Z flag
7fcc: 39              RTS
; Infinite halt loop — $7FCD. Reached on fatal error or if cold-start returns (shouldn't happen).
7fcd: 20 fe           BRA    $7FCD
7fcf: ff ff ff        STU    $FFFF
7fd2: ff ff ff        STU    $FFFF
7fd5: ff ff ff        STU    $FFFF
7fd8: ff ff ff        STU    $FFFF
7fdb: ff ff ff        STU    $FFFF
7fde: ff ff ff        STU    $FFFF
7fe1: ff ff ff        STU    $FFFF
7fe4: ff ff ff        STU    $FFFF
7fe7: ff ff ff        STU    $FFFF
7fea: ff ff ff        STU    $FFFF
7fed: ff ff ff        STU    $FFFF
; =====================================================================================
; MC6809 interrupt / reset vector table — CPU $FFF0-$FFFF (file $7FF0-$7FFF).
; This region is DATA, not code. The disassembler renders it as garbled instructions.
; Decoded as 8 big-endian 16-bit vectors:
;   $FFF0: $FD5F  Reserved       → reset entry ($7D5F)
;   $FFF2: $FD5F  SWI3           → reset entry (unused, falls through to cold start)
;   $FFF4: $FD5F  SWI2           → reset entry (unused)
;   $FFF6: $DD0C  FIRQ           → FIRQ wrapper ($5D0C: saves regs, calls $70A1)
;   $FFF8: $DD14  IRQ            → IRQ wrapper ($5D14: latches $2204 bit 0, masks IRQ)
;   $FFFA: $FD5F  SWI            → reset entry (unused)
;   $FFFC: $DC3D  NMI            → NMI handler ($5C3D: PTM service + callback dispatch)
;   $FFFE: $FD5F  RESET          → reset entry ($7D5F: cold start)
; Note: SWI/SWI2/SWI3/Reserved all point to the reset vector, indicating they are unused.
; =====================================================================================
7ff0: fd 5f fd        STD    $5FFD       ; data: $FD5F $FD5F (Reserved, SWI3)
7ff3: 5f              CLRB
7ff4: fd 5f dd        STD    $5FDD       ; data: $FD5F $DD0C (SWI2, FIRQ)
7ff7: 0c dd           INC    <$DD
7ff9: 14              XHCF
7ffa: fd 5f dc        STD    $5FDC       ; data: $FD5F $DC3D (SWI, NMI)
7ffd: 3d              MUL
7ffe: fd 5f fc        STD    $5F00       ; data: $FD5F (RESET) — last 2 bytes not shown
