; =====================================================================================
; HP 8904A Multifunction Synthesizer — A2U13 Paged ROM (Intel D27513, 64KB).
; =====================================================================================
;
; Physical ROM: 64KB organized as 4 × 16KB pages.
; CPU mapping: pages are banked into the $4000-$7FFF window.
; Page select: write page number (0-3) to $4000.
;
; File layout (file offsets = page × $4000 + offset within page):
;   Page 0: $0000-$3FFF (CPU $4000-$7FFF when page 0 selected)
;   Page 1: $4000-$7FFF (CPU $4000-$7FFF when page 1 selected)
;   Page 2: $8000-$BFFF (CPU $4000-$7FFF when page 2 selected)
;   Page 3: $C000-$FFFF (CPU $4000-$7FFF when page 3 selected)
;
; Stack frame allocator: all pages call CPU $FD50 (= A2U12 $7D50) via LBSR.
;   Disassembler shows different targets per page due to file-offset arithmetic:
;     Page 0: LBSR $BD50  (file $03D7 + offset → file $BD50, CPU $FD50)
;     Page 1: LBSR $FD50  (file $456A + offset → file $FD50, CPU $FD50)
;     Page 2: LBSR $3D50  (file $84A0 + offset → wraps to $3D50, CPU $FD50)
;     Page 3: LBSR $7D50  (file $C46F + offset → wraps to $7D50, CPU $FD50)
;   Pattern: LDD <frame-size-addr>; LBSR <allocator> — allocates stack frame, returns
;   frame base in X. Frame size constant is a 16-bit value stored in ROM.
;
; Page 0 ($0000-$3FFF) — Main application mode and channel configuration.
;   $0000-$03C5: String data — LCD display templates with length/type prefix bytes.
;     Key strings: "HP 8904A Opts 02/01/03/...", "Channel Config.", "Tone Sequence",
;     "DTMF Sequence", "Digital Sequence", firmware update notice, stack overflow message,
;     channel parameter labels (FREQ, AMPTD, PHASE, WFORM, DESTN), hop RAM labels.
;   $03C6-$03D3: Small helper (calls $4AD0, cleans stack, returns).
;   $03D4-$3FEA: C-compiled functions (49 frame-allocating) — channel configuration
;     handlers, menu navigation, parameter editing, freq/amptd/phase/wform setting.
;   $3FEB-$3FFF: $FF padding.
;
; Page 1 ($4000-$7FFF) — Tone/DTMF/digital sequence editing.
;   $4000-$4232: String data — tone/DTMF/digital sequence display templates, mode labels.
;   $4233-$4266: Lookup tables — function pointer arrays (with $C239 null entries),
;     parameter descriptor tables for sequence modes.
;   $4267-$4566: Hand-written assembly — DDS programming ($0200), MC6840 PTM timing
;     ($1001/$1004), sequence playback engine, interrupt handler (ends RTI at $43BB),
;     timer comparison loop, port $0B00 control.
;   $4567-$7AAB: C-compiled functions (98 frame-allocating) — tone sequence editor,
;     DTMF sequence editor, digital pattern editor, hop RAM management.
;   $7AAC-$7FFF: $FF padding (~$554 bytes).
;
; Page 2 ($8000-$BFFF) — Sequence editing and digital I/O.
;   $8000-$8167: String data — "Seq Index", "Seq Base Hex", "Period", "On Lev",
;     "Off Lev", "Edit Sequence", "Bit", "Exit", etc.
;   $8168-$8195: Lookup tables — function pointer arrays, parameter descriptors.
;   $8196-$849C: Hand-written assembly — digital sequence timing engine, DDS programming
;     ($0200), MC6840 PTM ($1001/$1004), port output control, JSR $53F9.
;   $849D-$B391: C-compiled functions — bit-level sequence editing, digital port
;     configuration, sequence data management.
;   $B392-$BFFF: $FF padding (~$0C6E bytes unused).
;
; Page 3 ($C000-$FFFF) — Diagnostics and self-test.
;   $C000-$C46B: String data — copyright "HP8904A Firmware Copyright 1987 Hewlett
;     Packard Corp.", "Diagnostic Tests and Checks" banner, test menu labels
;     ("Keyboard Check", "Exit", etc.), diagnostic parameter display templates.
;   $C46C-$FEBE: C-compiled functions — diagnostic test routines, keyboard test,
;     display test, hardware verification, self-test sequencer.
;   $FEBF-$FFFF: $FF padding.
;
; Cross-references to A2U12 (CPU $8000-$FFFF):
;   Many functions in this ROM call A2U12 routines via LBSR with addresses in the $8xxx-$Fxxx
;   range. The stack frame allocator at CPU $7D50 (A2U12 file $7D50) is called as LBSR $BD50
;   from page code. Key A2U12 entry points used from here:
;     $10D3 ($90D3) — P8291A handler (via wrappers in A2U12)
;     $1743 ($9743) — event slot set
;     $175E ($975E) — event slot read
;     $1729 ($9729) — transmit buffer install
;     $7CEA ($FCEA) — table lookup helper
;     $58A5 ($D8A5) — display/menu rendering helper
;     $2415 ($A415) — foreground task dispatcher
;
; =====================================================================================
0000: 30 74           LEAX   -$C,S
0002: 04 02           LSR    <$02
0004: 52              XNCB
0005: 8f c2 39        XSTX   #$C239
0008: 41              NEGA
0009: ca 41           ORB    #$41
000b: d1 41           CMPB   <$41
000d: d8 c2           EORB   <$C2
000f: 39              RTS
0010: c2 39           SBCB   #$39
0012: c2 39           SBCB   #$39
0014: c2 39           SBCB   #$39
0016: c2 39           SBCB   #$39
0018: 40              NEGA
0019: 53              COMB
001a: 40              NEGA
001b: 7b 40 a3        XDEC   $40A3
001e: 40              NEGA
001f: cb 40           ADDB   #$40
0021: f3 41 df        ADDD   $41DF
0024: 41              NEGA
0025: e6 03           LDB    $3,X
0027: 48              ASLA
0028: 50              NEGB
0029: 20 38           BRA    $0063
002b: 39              RTS
002c: 30 34           LEAX   -$C,Y
002e: 41              NEGA
002f: 20 4f           BRA    $0080
0031: 70 74 73        NEG    $7473
0034: 20 30           BRA    $0066
0036: 32 2f           LEAS   $F,Y
0038: 30 31           LEAX   -$F,Y
003a: 2f 30           BLE    $006C
003c: 33 2f           LEAU   $F,Y
003e: 20 20           BRA    $0060
0040: 2f 20           BLE    $0062
0042: 20 2f           BRA    $0073
0044: 20 20           BRA    $0066
0046: 2f 20           BLE    $0068
0048: 20 2f           BRA    $0079
004a: 20 20           BRA    $006C
004c: 2f 20           BLE    $006E
004e: 20 41           BRA    $0091
0050: ed 69           STD    $9,S
0052: ff 00 01        STU    >$0001
0055: 20 43           BRA    $009A
0057: 68 61           ASL    $1,S
0059: 6e 6e           JMP    $E,S
005b: 65 6c           LSR    $C,S
005d: 20 43           BRA    $00A2
005f: 6f 6e           CLR    $E,S
0061: 66 69           ROR    $9,S
0063: 67 2e           ASR    $E,Y
0065: 20 20           BRA    $0087
0067: 20 20           BRA    $0089
0069: 20 20           BRA    $008B
006b: 20 20           BRA    $008D
006d: 20 20           BRA    $008F
006f: 20 20           BRA    $0091
0071: 20 20           BRA    $0093
0073: 20 20           BRA    $0095
0075: 20 20           BRA    $0097
0077: 20 20           BRA    $0099
0079: 20 20           BRA    $009B
007b: 00 01           NEG    <$01
007d: 20 54           BRA    $00D3
007f: 6f 6e           CLR    $E,S
0081: 65 20           LSR    $0,Y
0083: 53              COMB
0084: 65 71           LSR    -$F,S
0086: 75 65 6e        LSR    $656E
0089: 63 65           COM    $5,S
008b: 20 20           BRA    $00AD
008d: 20 20           BRA    $00AF
008f: 00 03           NEG    <$03
0091: 20 44           BRA    $00D7
0093: 54              LSRB
0094: 4d              TSTA
0095: 46              RORA
0096: 20 53           BRA    $00EB
0098: 65 71           LSR    -$F,S
009a: 75 65 6e        LSR    $656E
009d: 63 65           COM    $5,S
009f: 20 20           BRA    $00C1
00a1: 20 20           BRA    $00C3
00a3: 00 01           NEG    <$01
00a5: 20 44           BRA    $00EB
00a7: 69 67           ROL    $7,S
00a9: 69 74           ROL    -$C,S
00ab: 61 6c           NEG    $C,S
00ad: 20 53           BRA    $0102
00af: 65 71           LSR    -$F,S
00b1: 75 65 6e        LSR    $656E
00b4: 63 65           COM    $5,S
00b6: 20 20           BRA    $00D8
00b8: 20 20           BRA    $00DA
00ba: 20 20           BRA    $00DC
00bc: 20 20           BRA    $00DE
00be: 20 20           BRA    $00E0
00c0: 20 20           BRA    $00E2
00c2: 20 20           BRA    $00E4
00c4: 20 20           BRA    $00E6
00c6: 20 20           BRA    $00E8
00c8: 20 20           BRA    $00EA
00ca: 20 00           BRA    $00CC
00cc: 01 20           NEG    <$20
00ce: 20 20           BRA    $00F0
00d0: 20 20           BRA    $00F2
00d2: 20 20           BRA    $00F4
00d4: 20 20           BRA    $00F6
00d6: 20 20           BRA    $00F8
00d8: 20 20           BRA    $00FA
00da: 20 20           BRA    $00FC
00dc: 20 20           BRA    $00FE
00de: 20 00           BRA    $00E0
00e0: 03 20           COM    <$20
00e2: 20 20           BRA    $0104
00e4: 20 20           BRA    $0106
00e6: 20 20           BRA    $0108
00e8: 20 20           BRA    $010A
00ea: 20 20           BRA    $010C
00ec: 20 20           BRA    $010E
00ee: 20 20           BRA    $0110
00f0: 20 20           BRA    $0112
00f2: 20 00           BRA    $00F4
00f4: 01 20           NEG    <$20
00f6: 20 20           BRA    $0118
00f8: 20 20           BRA    $011A
00fa: 20 20           BRA    $011C
00fc: 20 20           BRA    $011E
00fe: 20 20           BRA    $0120
0100: 20 20           BRA    $0122
0102: 20 20           BRA    $0124
0104: 20 20           BRA    $0126
0106: 20 00           BRA    $0108
0108: 03 20           COM    <$20
010a: 20 20           BRA    $012C
010c: 20 20           BRA    $012E
010e: 20 20           BRA    $0130
0110: 20 20           BRA    $0132
0112: 20 20           BRA    $0134
0114: 20 20           BRA    $0136
0116: 20 20           BRA    $0138
0118: 20 20           BRA    $013A
011a: 20 54           BRA    $0170
011c: 68 65           ASL    $5,S
011e: 20 66           BRA    $0186
0120: 69 72           ROL    -$E,S
0122: 6d 77           TST    -$9,S
0124: 61 72           NEG    -$E,S
0126: 65 20           LSR    $0,Y
0128: 68 61           ASL    $1,S
012a: 73 20 62        COM    $2062
012d: 65 65           LSR    $5,S
012f: 6e 20           JMP    $0,Y
0131: 75 70 64        LSR    $7064
0134: 61 74           NEG    -$C,S
0136: 65 64           LSR    $4,S
0138: 2e 20           BGT    $015A
013a: 20 56           BRA    $0192
013c: 65 72           LSR    -$E,S
013e: 69 66           ROL    $6,S
0140: 79 20 20        ROL    $2020
0143: 6f 70           CLR    -$10,S
0145: 74 69 6f        LSR    $696F
0148: 6e 73           JMP    -$D,S
014a: 20 61           BRA    $01AD
014c: 6e 64           JMP    $4,S
014e: 20 73           BRA    $01C3
0150: 65 72           LSR    -$E,S
0152: 69 61           ROL    $1,S
0154: 6c 20           INC    $0,Y
0156: 6e 75           JMP    -$B,S
0158: 6d 62           TST    $2,S
015a: 65 72           LSR    -$E,S
015c: 20 77           BRA    $01D5
015e: 69 74           ROL    -$C,S
0160: 68 20           ASL    $0,Y
0162: 50              NEGB
0163: 52              XNCB
0164: 45              LSRA
0165: 53              COMB
0166: 45              LSRA
0167: 54              LSRB
0168: 2e 20           BGT    $018A
016a: 20 41           BRA    $01AD
016c: 20 73           BRA    $01E1
016e: 74 61 63        LSR    $6163
0171: 6b 20           XDEC   $0,Y
0173: 6f 76           CLR    -$A,S
0175: 65 72           LSR    -$E,S
0177: 66 6c           ROR    $C,S
0179: 6f 77           CLR    -$9,S
017b: 20 63           BRA    $01E0
017d: 72 61 73        XNC    $6173
0180: 68 20           ASL    $0,Y
0182: 68 61           ASL    $1,S
0184: 73 20 6f        COM    $206F
0187: 63 63           COM    $3,S
0189: 75 72 72        LSR    $7272
018c: 65 64           LSR    $4,S
018e: 21 21           BRN    $01B1
0190: 21 21           BRN    $01B3
0192: 21 50           BRN    $01E4
0194: 6c 65           INC    $5,S
0196: 61 73           NEG    -$D,S
0198: 65 20           LSR    $0,Y
019a: 6e 6f           JMP    $F,S
019c: 74 69 66        LSR    $6966
019f: 79 20 48        ROL    $2048
01a2: 65 77           LSR    -$9,S
01a4: 6c 65           INC    $5,S
01a6: 74 74 20        LSR    $7420
01a9: 50              NEGB
01aa: 61 63           NEG    $3,S
01ac: 6b 61           XDEC   $1,S
01ae: 72 64 20        XNC    $6420
01b1: 53              COMB
01b2: 70 6f 6b        NEG    $6F6B
01b5: 61 6e           NEG    $E,S
01b7: 65 2e           LSR    $E,Y
01b9: 20 20           BRA    $01DB
01bb: 32 30           LEAS   -$10,Y
01bd: 39              RTS
01be: 38 37           XANDCC #$37
01c0: 41              NEGA
01c1: 32 32           LEAS   -$E,Y
01c3: 39              RTS
01c4: 38 37           XANDCC #$37
01c6: 41              NEGA
01c7: 0a ae           DEC    <$AE
01c9: 60 86           NEG    A,X
01cb: 01 ce           NEG    <$CE
01cd: 55              LSRB
01ce: c5 20           BITB   #$20
01d0: 23 86           BLS    $0158
01d2: 01 ce           NEG    <$CE
01d4: 7a 81 20        DEC    $8120
01d7: 1c 86           ANDCC  #$86
01d9: 02 ce           XNC    <$CE
01db: 73 64 20        COM    $6420
01de: 15              XHCF
01df: 86 03           LDA    #$03
01e1: ce 4c 26        LDU    #$4C26
01e4: 20 0e           BRA    $01F4
01e6: 86 03           LDA    #$03
01e8: ce 72 46        LDU    #$7246
01eb: 20 07           BRA    $01F4
01ed: 86 03           LDA    #$03
01ef: ce 7a c3        LDU    #$7AC3
01f2: 20 00           BRA    $01F4
01f4: b7 24 7c        STA    $247C
01f7: ff 24 7d        STU    $247D
01fa: 16 9b 21        LBRA   $9D1E
01fd: 2a 2a           BPL    $0229
01ff: 20 20           BRA    $0221
0201: 20 20           BRA    $0223
0203: 20 43           BRA    $0248
0205: 68 61           ASL    $1,S
0207: 6e 6e           JMP    $E,S
0209: 65 6c           LSR    $C,S
020b: 20 43           BRA    $0250
020d: 6f 6e           CLR    $E,S
020f: 66 69           ROR    $9,S
0211: 67 75           ASR    -$B,S
0213: 72 61 74        XNC    $6174
0216: 69 6f           ROL    $F,S
0218: 6e 20           JMP    $0,Y
021a: 4d              TSTA
021b: 6f 64           CLR    $4,S
021d: 65 20           LSR    $0,Y
021f: 20 20           BRA    $0241
0221: 20 20           BRA    $0243
0223: 2a 2a           BPL    $024F
0225: 50              NEGB
0226: 72 65 73        XNC    $6573
0229: 73 20 4e        COM    $204E
022c: 45              LSRA
022d: 58              ASLB
022e: 54              LSRB
022f: 2f 4c           BLE    $027D
0231: 41              NEGA
0232: 53              COMB
0233: 54              LSRB
0234: 20 6b           BRA    $02A1
0236: 65 79           LSR    -$7,S
0238: 73 2e 20        COM    $2E20
023b: 20 20           BRA    $025D
023d: 20 00           BRA    $023F
023f: 04 20           LSR    <$20
0241: 45              LSRA
0242: 78 69 74        ASL    $6974
0245: 20 20           BRA    $0267
0247: 20 20           BRA    $0269
0249: 20 20           BRA    $026B
024b: 20 20           BRA    $026D
024d: 63 68           COM    $8,S
024f: 20 20           BRA    $0271
0251: 3a              ABX
0252: 20 46           BRA    $029A
0254: 52              XNCB
0255: 45              LSRA
0256: 51              NEGB
0257: 20 20           BRA    $0279
0259: 20 20           BRA    $027B
025b: 20 20           BRA    $027D
025d: 20 20           BRA    $027F
025f: 20 20           BRA    $0281
0261: 20 20           BRA    $0283
0263: 20 20           BRA    $0285
0265: 41              NEGA
0266: 4d              TSTA
0267: 50              NEGB
0268: 54              LSRB
0269: 44              LSRA
026a: 20 20           BRA    $028C
026c: 20 20           BRA    $028E
026e: 20 20           BRA    $0290
0270: 20 20           BRA    $0292
0272: 20 20           BRA    $0294
0274: 20 50           BRA    $02C6
0276: 48              ASLA
0277: 41              NEGA
0278: 53              COMB
0279: 45              LSRA
027a: 20 20           BRA    $029C
027c: 20 20           BRA    $029E
027e: 20 20           BRA    $02A0
0280: 20 20           BRA    $02A2
0282: 20 20           BRA    $02A4
0284: 20 20           BRA    $02A6
0286: 57              ASRB
0287: 46              RORA
0288: 4f              CLRA
0289: 52              XNCB
028a: 4d              TSTA
028b: 20 20           BRA    $02AD
028d: 20 20           BRA    $02AF
028f: 20 20           BRA    $02B1
0291: 20 20           BRA    $02B3
0293: 44              LSRA
0294: 45              LSRA
0295: 53              COMB
0296: 54              LSRB
0297: 4e              XCLRA
0298: 20 20           BRA    $02BA
029a: 20 20           BRA    $02BC
029c: 20 00           BRA    $029E
029e: 01 20           NEG    <$20
02a0: 48              ASLA
02a1: 6f 70           CLR    -$10,S
02a3: 20 52           BRA    $02F7
02a5: 61 6d           NEG    $D,S
02a7: 20 41           BRA    $02EA
02a9: 64 72           LSR    -$E,S
02ab: 73 20 20        COM    $2020
02ae: 20 20           BRA    $02D0
02b0: 20 46           BRA    $02F8
02b2: 52              XNCB
02b3: 45              LSRA
02b4: 51              NEGB
02b5: 20 20           BRA    $02D7
02b7: 20 20           BRA    $02D9
02b9: 20 20           BRA    $02DB
02bb: 20 20           BRA    $02DD
02bd: 20 20           BRA    $02DF
02bf: 20 20           BRA    $02E1
02c1: 20 20           BRA    $02E3
02c3: 20 20           BRA    $02E5
02c5: 41              NEGA
02c6: 4d              TSTA
02c7: 50              NEGB
02c8: 54              LSRB
02c9: 44              LSRA
02ca: 20 20           BRA    $02EC
02cc: 20 20           BRA    $02EE
02ce: 20 20           BRA    $02F0
02d0: 20 20           BRA    $02F2
02d2: 20 20           BRA    $02F4
02d4: 20 20           BRA    $02F6
02d6: 20 20           BRA    $02F8
02d8: 20 50           BRA    $032A
02da: 48              ASLA
02db: 41              NEGA
02dc: 53              COMB
02dd: 45              LSRA
02de: 20 20           BRA    $0300
02e0: 20 20           BRA    $0302
02e2: 20 20           BRA    $0304
02e4: 20 20           BRA    $0306
02e6: 20 20           BRA    $0308
02e8: 20 20           BRA    $030A
02ea: 20 20           BRA    $030C
02ec: 20 00           BRA    $02EE
02ee: 01 20           NEG    <$20
02f0: 44              LSRA
02f1: 69 67           ROL    $7,S
02f3: 69 74           ROL    -$C,S
02f5: 61 6c           NEG    $C,S
02f7: 20 50           BRA    $0349
02f9: 6f 72           CLR    -$E,S
02fb: 74 20 20        LSR    $2020
02fe: 20 20           BRA    $0320
0300: 20 00           BRA    $0302
0302: 03 20           COM    <$20
0304: 46              RORA
0305: 72 65 71        XNC    $6571
0308: 20 48           BRA    $0352
030a: 6f 70           CLR    -$10,S
030c: 20 20           BRA    $032E
030e: 20 20           BRA    $0330
0310: 20 20           BRA    $0332
0312: 20 20           BRA    $0334
0314: 20 00           BRA    $0316
0316: 02 20           XNC    <$20
0318: 41              NEGA
0319: 6d 70           TST    -$10,S
031b: 74 64 20        LSR    $6420
031e: 48              ASLA
031f: 6f 70           CLR    -$10,S
0321: 20 20           BRA    $0343
0323: 20 20           BRA    $0345
0325: 20 20           BRA    $0347
0327: 20 20           BRA    $0349
0329: 00 04           NEG    <$04
032b: 20 50           BRA    $037D
032d: 68 61           ASL    $1,S
032f: 73 65 20        COM    $6520
0332: 48              ASLA
0333: 6f 70           CLR    -$10,S
0335: 20 20           BRA    $0357
0337: 20 20           BRA    $0359
0339: 20 20           BRA    $035B
033b: 20 20           BRA    $035D
033d: 06 41           ROR    <$41
033f: fd c2 39        STD    $C239
0342: c2 39           SBCB   #$39
0344: c2 39           SBCB   #$39
0346: 8b 4c           ADDA   #$4C
0348: 42              XNCA
0349: 4d              TSTA
034a: c2 39           SBCB   #$39
034c: c2 39           SBCB   #$39
034e: c2 39           SBCB   #$39
0350: c2 39           SBCB   #$39
0352: 42              XNCA
0353: 4d              TSTA
0354: c2 39           SBCB   #$39
0356: c2 39           SBCB   #$39
0358: c2 39           SBCB   #$39
035a: c2 39           SBCB   #$39
035c: 42              XNCA
035d: 4d              TSTA
035e: c2 39           SBCB   #$39
0360: c2 39           SBCB   #$39
0362: c2 39           SBCB   #$39
0364: c2 39           SBCB   #$39
0366: 42              XNCA
0367: 4d              TSTA
0368: c2 39           SBCB   #$39
036a: c2 39           SBCB   #$39
036c: c2 39           SBCB   #$39
036e: c2 39           SBCB   #$39
0370: 42              XNCA
0371: 9d 43           JSR    <$43
0373: bd c2 39        JSR    $C239
0376: c2 39           SBCB   #$39
0378: c2 39           SBCB   #$39
037a: 42              XNCA
037b: ed 49           STD    $9,U
037d: 08 49           ASL    <$49
037f: 08 49           ASL    <$49
0381: 08 49           ASL    <$49
0383: 08 2a           ASL    <$2A
0385: 48              ASLA
0386: 6f 70           CLR    -$10,S
0388: 20 52           BRA    $03DC
038a: 61 6d           NEG    $D,S
038c: 2a 20           BPL    $03AE
038e: 20 20           BRA    $03B0
0390: 20 2a           BRA    $03BC
0392: 20 20           BRA    $03B4
0394: 2a 2a           BPL    $03C0
0396: 20 20           BRA    $03B8
0398: 20 20           BRA    $03BA
039a: 20 20           BRA    $03BC
039c: 20 20           BRA    $03BE
039e: 20 20           BRA    $03C0
03a0: 20 20           BRA    $03C2
03a2: 20 2a           BRA    $03CE
03a4: 2a 20           BPL    $03C6
03a6: 20 20           BRA    $03C8
03a8: 20 20           BRA    $03CA
03aa: 20 20           BRA    $03CC
03ac: 20 20           BRA    $03CE
03ae: 20 2a           BRA    $03DA
03b0: 2a 20           BPL    $03D2
03b2: 20 20           BRA    $03D4
03b4: 20 20           BRA    $03D6
03b6: 20 20           BRA    $03D8
03b8: 20 20           BRA    $03DA
03ba: 20 20           BRA    $03DC
03bc: 2a fc           BPL    $03BA
03be: 4e              XCLRA
03bf: c3 17 b9        ADDD   #$17B9
03c2: 8d ce           BSR    $0392
03c4: 00 27           NEG    <$27
; ---------------------------------------------------------------------------
; End of string data region.  Small helper: push args, call $4AD0, return.
; ---------------------------------------------------------------------------
03c6: 10 8e 00 02     LDY    #$0002
03ca: 34 60           PSHS   U,Y
03cc: 17 47 01        LBSR   $4AD0
03cf: 32 64           LEAS   $4,S
03d1: 32 62           LEAS   $2,S
03d3: 39              RTS
; ---------------------------------------------------------------------------
; First C-compiled function (page 0).  49 frame-allocating functions follow,
; covering channel configuration, menu navigation, and parameter editing.
; Pattern: LDD <rom-addr>; LBSR $BD50 allocates stack frame.
; ---------------------------------------------------------------------------
03d4: fc 4e c4        LDD    $4EC4
03d7: 17 b9 76        LBSR   $BD50
03da: f6 3b 81        LDB    $3B81
03dd: c1 05           CMPB   #$05
03df: 10 27 00 03     LBEQ   $03E6
03e3: 16 00 78        LBRA   $045E
03e6: f6 24 f4        LDB    $24F4
03e9: 53              COMB
03ea: 1d              SEX
03eb: 84 00           ANDA   #$00
03ed: c4 0f           ANDB   #$0F
03ef: e7 62           STB    $2,S
03f1: ce 24 14        LDU    #$2414
03f4: e6 62           LDB    $2,S
03f6: 4f              CLRA
03f7: 1f 02           TFR    D,Y
03f9: 8e 00 04        LDX    #$0004
03fc: 34 70           PSHS   U,Y,X
03fe: 17 85 d0        LBSR   $89D1
0401: 32 66           LEAS   $6,S
0403: ce 24 14        LDU    #$2414
0406: c6 02           LDB    #$02
0408: 1d              SEX
0409: 1f 02           TFR    D,Y
040b: 8e 00 04        LDX    #$0004
040e: 34 70           PSHS   U,Y,X
0410: 17 88 ec        LBSR   $8CFF
0413: 32 66           LEAS   $6,S
0415: fc 22 04        LDD    $2204
0418: 84 20           ANDA   #$20
041a: c4 00           ANDB   #$00
041c: 10 83 00 00     CMPD   #$0000
0420: 10 27 00 08     LBEQ   $042C
0424: cc 43 91        LDD    #$4391
0427: ed 63           STD    $3,S
0429: 16 00 05        LBRA   $0431
042c: cc ed 11        LDD    #$ED11
042f: ed 63           STD    $3,S
0431: ee 63           LDU    $3,S
0433: c6 04           LDB    #$04
0435: 1d              SEX
0436: 1f 02           TFR    D,Y
0438: c6 0f           LDB    #$0F
043a: 1d              SEX
043b: 1f 01           TFR    D,X
043d: cc 00 06        LDD    #$0006
0440: 34 76           PSHS   U,Y,X,D
0442: 17 94 a5        LBSR   $98EA
0445: 32 68           LEAS   $8,S
0447: ce 24 15        LDU    #$2415
044a: c6 02           LDB    #$02
044c: 1d              SEX
044d: 1f 02           TFR    D,Y
044f: c6 10           LDB    #$10
0451: 1d              SEX
0452: 1f 01           TFR    D,X
0454: cc 00 06        LDD    #$0006
0457: 34 76           PSHS   U,Y,X,D
0459: 17 94 8e        LBSR   $98EA
045c: 32 68           LEAS   $8,S
045e: 32 65           LEAS   $5,S
0460: 39              RTS
0461: fc 4e cc        LDD    $4ECC
0464: 17 b8 e9        LBSR   $BD50
0467: f6 3b 81        LDB    $3B81
046a: c1 05           CMPB   #$05
046c: 10 27 00 03     LBEQ   $0473
0470: 16 01 03        LBRA   $0576
0473: be 22 15        LDX    $2215
0476: 8c 00 0f        CMPX   #$000F
0479: 10 26 00 1d     LBNE   $049A
047d: c6 18           LDB    #$18
047f: 1d              SEX
0480: 1f 03           TFR    D,U
0482: 10 8e 00 02     LDY    #$0002
0486: 34 60           PSHS   U,Y
0488: 17 83 ca        LBSR   $8855
048b: 32 64           LEAS   $4,S
048d: cc 26 71        LDD    #$2671
0490: ed 62           STD    $2,S
0492: fc 26 7b        LDD    $267B
0495: ed 64           STD    $4,S
0497: 16 00 1c        LBRA   $04B6
049a: ce 25 81        LDU    #$2581
049d: f6 24 f4        LDB    $24F4
04a0: 4f              CLRA
04a1: 1f 02           TFR    D,Y
04a3: 34 60           PSHS   U,Y
04a5: 86 01           LDA    #$01
04a7: 8e 4e c6        LDX    #$4EC6
04aa: 17 b8 3d        LBSR   $BCEA
04ad: 30 04           LEAX   $4,X
04af: af 62           STX    $2,S
04b1: fc 26 77        LDD    $2677
04b4: ed 64           STD    $4,S
04b6: ce 24 14        LDU    #$2414
04b9: 10 ae 62        LDY    $2,S
04bc: 8e 00 04        LDX    #$0004
04bf: 34 70           PSHS   U,Y,X
04c1: 17 85 cb        LBSR   $8A8F
04c4: 32 66           LEAS   $6,S
04c6: ae 64           LDX    $4,S
04c8: 8c 00 02        CMPX   #$0002
04cb: 10 26 00 0d     LBNE   $04DC
04cf: c6 06           LDB    #$06
04d1: e7 68           STB    $8,S
04d3: c6 07           LDB    #$07
04d5: e7 69           STB    $9,S
04d7: 6f 6a           CLR    $A,S
04d9: 16 00 0c        LBRA   $04E8
04dc: c6 03           LDB    #$03
04de: e7 68           STB    $8,S
04e0: c6 04           LDB    #$04
04e2: e7 69           STB    $9,S
04e4: c6 01           LDB    #$01
04e6: e7 6a           STB    $A,S
04e8: ce 24 14        LDU    #$2414
04eb: e6 68           LDB    $8,S
04ed: 4f              CLRA
04ee: 1f 02           TFR    D,Y
04f0: 8e 00 04        LDX    #$0004
04f3: 34 70           PSHS   U,Y,X
04f5: 17 88 07        LBSR   $8CFF
04f8: 32 66           LEAS   $6,S
04fa: e6 6a           LDB    $A,S
04fc: 4f              CLRA
04fd: 1f 03           TFR    D,U
04ff: e6 69           LDB    $9,S
0501: 4f              CLRA
0502: 1f 02           TFR    D,Y
0504: c6 08           LDB    #$08
0506: 1d              SEX
0507: 1f 01           TFR    D,X
0509: cc 24 14        LDD    #$2414
050c: 34 76           PSHS   U,Y,X,D
050e: ce 24 14        LDU    #$2414
0511: 10 8e 00 0a     LDY    #$000A
0515: 34 60           PSHS   U,Y
0517: 17 88 36        LBSR   $8D50
051a: 32 6c           LEAS   $C,S
051c: fc 22 02        LDD    $2202
051f: 84 01           ANDA   #$01
0521: c4 00           ANDB   #$00
0523: 10 83 00 00     CMPD   #$0000
0527: 10 27 00 08     LBEQ   $0533
052b: cc ed 11        LDD    #$ED11
052e: ed 66           STD    $6,S
0530: 16 00 05        LBRA   $0538
0533: cc 43 95        LDD    #$4395
0536: ed 66           STD    $6,S
0538: ee 66           LDU    $6,S
053a: c6 0f           LDB    #$0F
053c: 1d              SEX
053d: 1f 02           TFR    D,Y
053f: c6 19           LDB    #$19
0541: 1d              SEX
0542: 1f 01           TFR    D,X
0544: cc 00 06        LDD    #$0006
0547: 34 76           PSHS   U,Y,X,D
0549: 17 93 9e        LBSR   $98EA
054c: 32 68           LEAS   $8,S
054e: ce 24 15        LDU    #$2415
0551: c6 08           LDB    #$08
0553: 1d              SEX
0554: 1f 02           TFR    D,Y
0556: c6 1b           LDB    #$1B
0558: 1d              SEX
0559: 1f 01           TFR    D,X
055b: cc 00 06        LDD    #$0006
055e: 34 76           PSHS   U,Y,X,D
0560: 17 93 87        LBSR   $98EA
0563: 32 68           LEAS   $8,S
0565: ee 64           LDU    $4,S
0567: c6 24           LDB    #$24
0569: 1d              SEX
056a: 1f 02           TFR    D,Y
056c: 8e 00 04        LDX    #$0004
056f: 34 70           PSHS   U,Y,X
0571: 17 66 7b        LBSR   $6BEF
0574: 32 66           LEAS   $6,S
0576: 32 6b           LEAS   $B,S
0578: 39              RTS
0579: fc 4e ce        LDD    $4ECE
057c: 17 b7 d1        LBSR   $BD50
057f: f6 3b 81        LDB    $3B81
0582: c1 05           CMPB   #$05
0584: 10 27 00 03     LBEQ   $058B
0588: 16 01 00        LBRA   $068B
058b: be 22 15        LDX    $2215
058e: 8c 00 10        CMPX   #$0010
0591: 10 26 00 18     LBNE   $05AD
0595: c6 45           LDB    #$45
0597: 1d              SEX
0598: 1f 03           TFR    D,U
059a: 10 8e 00 02     LDY    #$0002
059e: 34 60           PSHS   U,Y
05a0: 17 82 b2        LBSR   $8855
05a3: 32 64           LEAS   $4,S
05a5: cc 26 74        LDD    #$2674
05a8: ed 65           STD    $5,S
05aa: 16 00 17        LBRA   $05C4
05ad: ce 25 81        LDU    #$2581
05b0: f6 24 f4        LDB    $24F4
05b3: 4f              CLRA
05b4: 1f 02           TFR    D,Y
05b6: 34 60           PSHS   U,Y
05b8: 86 01           LDA    #$01
05ba: 8e 4e c6        LDX    #$4EC6
05bd: 17 b7 2a        LBSR   $BCEA
05c0: 30 07           LEAX   $7,X
05c2: af 65           STX    $5,S
05c4: ce 24 14        LDU    #$2414
05c7: 10 ae 65        LDY    $5,S
05ca: 8e 00 04        LDX    #$0004
05cd: 34 70           PSHS   U,Y,X
05cf: 17 84 bd        LBSR   $8A8F
05d2: 32 66           LEAS   $6,S
05d4: c6 20           LDB    #$20
05d6: e7 64           STB    $4,S
05d8: be 25 14        LDX    $2514
05db: 8c 00 04        CMPX   #$0004
05de: 10 26 00 0d     LBNE   $05EF
05e2: be 22 15        LDX    $2215
05e5: 8c 00 10        CMPX   #$0010
05e8: 10 27 00 03     LBEQ   $05EF
05ec: 16 00 03        LBRA   $05F2
05ef: 16 00 19        LBRA   $060B
05f2: ce 25 81        LDU    #$2581
05f5: f6 24 f4        LDB    $24F4
05f8: 4f              CLRA
05f9: 1f 02           TFR    D,Y
05fb: 34 60           PSHS   U,Y
05fd: 86 01           LDA    #$01
05ff: 8e 4e c6        LDX    #$4EC6
0602: 17 b6 e5        LBSR   $BCEA
0605: 30 0a           LEAX   $A,X
0607: e6 84           LDB    ,X
0609: e7 64           STB    $4,S
060b: ce 24 14        LDU    #$2414
060e: 10 8e 00 02     LDY    #$0002
0612: 34 60           PSHS   U,Y
0614: 17 8a 0b        LBSR   $9022
0617: 32 64           LEAS   $4,S
0619: ed 67           STD    $7,S
061b: fc 22 02        LDD    $2202
061e: 84 00           ANDA   #$00
0620: c4 40           ANDB   #$40
0622: 10 83 00 00     CMPD   #$0000
0626: 10 27 00 08     LBEQ   $0632
062a: cc ed 11        LDD    #$ED11
062d: ed 62           STD    $2,S
062f: 16 00 05        LBRA   $0637
0632: cc 43 a4        LDD    #$43A4
0635: ed 62           STD    $2,S
0637: ee 62           LDU    $2,S
0639: c6 0c           LDB    #$0C
063b: 1d              SEX
063c: 1f 02           TFR    D,Y
063e: c6 46           LDB    #$46
0640: 1d              SEX
0641: 1f 01           TFR    D,X
0643: cc 00 06        LDD    #$0006
0646: 34 76           PSHS   U,Y,X,D
0648: 17 92 9f        LBSR   $98EA
064b: 32 68           LEAS   $8,S
064d: ee 67           LDU    $7,S
064f: c6 4e           LDB    #$4E
0651: 1d              SEX
0652: 1f 02           TFR    D,Y
0654: 8e 00 04        LDX    #$0004
0657: 34 70           PSHS   U,Y,X
0659: 17 65 93        LBSR   $6BEF
065c: 32 66           LEAS   $6,S
065e: 33 64           LEAU   $4,S
0660: c6 01           LDB    #$01
0662: 1d              SEX
0663: 1f 02           TFR    D,Y
0665: c6 47           LDB    #$47
0667: 1d              SEX
0668: 1f 01           TFR    D,X
066a: cc 00 06        LDD    #$0006
066d: 34 76           PSHS   U,Y,X,D
066f: 17 92 78        LBSR   $98EA
0672: 32 68           LEAS   $8,S
0674: ce 24 14        LDU    #$2414
0677: c6 05           LDB    #$05
0679: 1d              SEX
067a: 1f 02           TFR    D,Y
067c: c6 48           LDB    #$48
067e: 1d              SEX
067f: 1f 01           TFR    D,X
0681: cc 00 06        LDD    #$0006
0684: 34 76           PSHS   U,Y,X,D
0686: 17 92 61        LBSR   $98EA
0689: 32 68           LEAS   $8,S
068b: 32 69           LEAS   $9,S
068d: 39              RTS
068e: fc 4e d0        LDD    $4ED0
0691: 17 b6 bc        LBSR   $BD50
0694: f6 3b 81        LDB    $3B81
0697: c1 05           CMPB   #$05
0699: 10 27 00 03     LBEQ   $06A0
069d: 16 01 23        LBRA   $07C3
06a0: be 22 15        LDX    $2215
06a3: 8c 00 11        CMPX   #$0011
06a6: 10 26 00 1d     LBNE   $06C7
06aa: c6 59           LDB    #$59
06ac: 1d              SEX
06ad: 1f 03           TFR    D,U
06af: 10 8e 00 02     LDY    #$0002
06b3: 34 60           PSHS   U,Y
06b5: 17 81 9d        LBSR   $8855
06b8: 32 64           LEAS   $4,S
06ba: fc 26 7d        LDD    $267D
06bd: ed 64           STD    $4,S
06bf: fc 26 79        LDD    $2679
06c2: ed 66           STD    $6,S
06c4: 16 00 32        LBRA   $06F9
06c7: ce 25 81        LDU    #$2581
06ca: f6 24 f4        LDB    $24F4
06cd: 4f              CLRA
06ce: 1f 02           TFR    D,Y
06d0: 34 60           PSHS   U,Y
06d2: 86 01           LDA    #$01
06d4: 8e 4e c6        LDX    #$4EC6
06d7: 17 b6 10        LBSR   $BCEA
06da: 30 0b           LEAX   $B,X
06dc: ae 84           LDX    ,X
06de: af 64           STX    $4,S
06e0: ce 25 81        LDU    #$2581
06e3: f6 24 f4        LDB    $24F4
06e6: 4f              CLRA
06e7: 1f 02           TFR    D,Y
06e9: 34 60           PSHS   U,Y
06eb: 86 01           LDA    #$01
06ed: 8e 4e c6        LDX    #$4EC6
06f0: 17 b5 f7        LBSR   $BCEA
06f3: 30 0d           LEAX   $D,X
06f5: ae 84           LDX    ,X
06f7: af 66           STX    $6,S
06f9: ce 24 14        LDU    #$2414
06fc: 10 ae 64        LDY    $4,S
06ff: 8e 00 04        LDX    #$0004
0702: 34 70           PSHS   U,Y,X
0704: 17 82 0b        LBSR   $8912
0707: 32 66           LEAS   $6,S
0709: ae 66           LDX    $6,S
070b: 8c 00 04        CMPX   #$0004
070e: 10 26 00 24     LBNE   $0736
0712: 5f              CLRB
0713: 1d              SEX
0714: 1f 03           TFR    D,U
0716: c6 02           LDB    #$02
0718: 1d              SEX
0719: 1f 02           TFR    D,Y
071b: c6 05           LDB    #$05
071d: 1d              SEX
071e: 1f 01           TFR    D,X
0720: cc 24 14        LDD    #$2414
0723: 34 76           PSHS   U,Y,X,D
0725: ce 24 14        LDU    #$2414
0728: 10 8e 00 0a     LDY    #$000A
072c: 34 60           PSHS   U,Y
072e: 17 86 1f        LBSR   $8D50
0731: 32 6c           LEAS   $C,S
0733: 16 00 33        LBRA   $0769
0736: ce 24 14        LDU    #$2414
0739: c6 03           LDB    #$03
073b: 1d              SEX
073c: 1f 02           TFR    D,Y
073e: 8e 00 04        LDX    #$0004
0741: 34 70           PSHS   U,Y,X
0743: 17 85 b9        LBSR   $8CFF
0746: 32 66           LEAS   $6,S
0748: 5f              CLRB
0749: 1d              SEX
074a: 1f 03           TFR    D,U
074c: c6 04           LDB    #$04
074e: 1d              SEX
074f: 1f 02           TFR    D,Y
0751: c6 05           LDB    #$05
0753: 1d              SEX
0754: 1f 01           TFR    D,X
0756: cc 24 14        LDD    #$2414
0759: 34 76           PSHS   U,Y,X,D
075b: ce 24 14        LDU    #$2414
075e: 10 8e 00 0a     LDY    #$000A
0762: 34 60           PSHS   U,Y
0764: 17 85 e9        LBSR   $8D50
0767: 32 6c           LEAS   $C,S
0769: fc 22 02        LDD    $2202
076c: 84 00           ANDA   #$00
076e: c4 80           ANDB   #$80
0770: 10 83 00 00     CMPD   #$0000
0774: 10 27 00 08     LBEQ   $0780
0778: cc ed 11        LDD    #$ED11
077b: ed 62           STD    $2,S
077d: 16 00 05        LBRA   $0785
0780: cc 43 b0        LDD    #$43B0
0783: ed 62           STD    $2,S
0785: ee 62           LDU    $2,S
0787: c6 0d           LDB    #$0D
0789: 1d              SEX
078a: 1f 02           TFR    D,Y
078c: c6 5a           LDB    #$5A
078e: 1d              SEX
078f: 1f 01           TFR    D,X
0791: cc 00 06        LDD    #$0006
0794: 34 76           PSHS   U,Y,X,D
0796: 17 91 51        LBSR   $98EA
0799: 32 68           LEAS   $8,S
079b: ce 24 15        LDU    #$2415
079e: c6 05           LDB    #$05
07a0: 1d              SEX
07a1: 1f 02           TFR    D,Y
07a3: c6 5c           LDB    #$5C
07a5: 1d              SEX
07a6: 1f 01           TFR    D,X
07a8: cc 00 06        LDD    #$0006
07ab: 34 76           PSHS   U,Y,X,D
07ad: 17 91 3a        LBSR   $98EA
07b0: 32 68           LEAS   $8,S
07b2: ee 66           LDU    $6,S
07b4: c6 62           LDB    #$62
07b6: 1d              SEX
07b7: 1f 02           TFR    D,Y
07b9: 8e 00 04        LDX    #$0004
07bc: 34 70           PSHS   U,Y,X
07be: 17 64 2e        LBSR   $6BEF
07c1: 32 66           LEAS   $6,S
07c3: 32 68           LEAS   $8,S
07c5: 39              RTS
07c6: fc 4e c3        LDD    $4EC3
07c9: 17 b5 84        LBSR   $BD50
07cc: f6 3b 81        LDB    $3B81
07cf: c1 05           CMPB   #$05
07d1: 10 27 00 03     LBEQ   $07D8
07d5: 16 00 28        LBRA   $0800
07d8: ce 00 00        LDU    #$0000
07db: 34 40           PSHS   U
07dd: 17 fb f4        LBSR   $03D4
07e0: 32 62           LEAS   $2,S
07e2: ce 00 00        LDU    #$0000
07e5: 34 40           PSHS   U
07e7: 17 fc 77        LBSR   $0461
07ea: 32 62           LEAS   $2,S
07ec: ce 00 00        LDU    #$0000
07ef: 34 40           PSHS   U
07f1: 17 fd 85        LBSR   $0579
07f4: 32 62           LEAS   $2,S
07f6: ce 00 00        LDU    #$0000
07f9: 34 40           PSHS   U
07fb: 17 fe 90        LBSR   $068E
07fe: 32 62           LEAS   $2,S
0800: 32 62           LEAS   $2,S
0802: 39              RTS
0803: fc 4e c6        LDD    $4EC6
0806: 17 b5 47        LBSR   $BD50
0809: 6f 62           CLR    $2,S
080b: fc 22 04        LDD    $2204
080e: 84 20           ANDA   #$20
0810: c4 00           ANDB   #$00
0812: 10 83 00 00     CMPD   #$0000
0816: 10 27 00 04     LBEQ   $081E
081a: c6 01           LDB    #$01
081c: e7 62           STB    $2,S
081e: f6 24 f4        LDB    $24F4
0821: 4f              CLRA
0822: 1f 03           TFR    D,U
0824: e6 62           LDB    $2,S
0826: 4f              CLRA
0827: 1f 02           TFR    D,Y
0829: 8e 00 04        LDX    #$0004
082c: 34 70           PSHS   U,Y,X
082e: 17 9f 93        LBSR   $A7C4
0831: 32 66           LEAS   $6,S
0833: ce 00 00        LDU    #$0000
0836: 34 40           PSHS   U
0838: 8d 8c           BSR    $07C6
083a: 32 62           LEAS   $2,S
083c: 32 63           LEAS   $3,S
083e: 39              RTS
083f: fc 4e d2        LDD    $4ED2
0842: 17 b5 0b        LBSR   $BD50
0845: f6 3b 81        LDB    $3B81
0848: c1 06           CMPB   #$06
084a: 10 27 00 03     LBEQ   $0851
084e: 16 00 b4        LBRA   $0905
0851: fc 22 04        LDD    $2204
0854: 84 20           ANDA   #$20
0856: c4 00           ANDB   #$00
0858: 10 83 00 00     CMPD   #$0000
085c: 10 27 00 08     LBEQ   $0868
0860: cc 00 11        LDD    #$0011
0863: ed 62           STD    $2,S
0865: 16 00 05        LBRA   $086D
0868: cc 00 10        LDD    #$0010
086b: ed 62           STD    $2,S
086d: fc 22 02        LDD    $2202
0870: 84 01           ANDA   #$01
0872: c4 00           ANDB   #$00
0874: 10 83 00 00     CMPD   #$0000
0878: 10 27 00 08     LBEQ   $0884
087c: cc 00 11        LDD    #$0011
087f: ed 64           STD    $4,S
0881: 16 00 05        LBRA   $0889
0884: cc 00 10        LDD    #$0010
0887: ed 64           STD    $4,S
0889: fc 22 02        LDD    $2202
088c: 84 00           ANDA   #$00
088e: c4 40           ANDB   #$40
0890: 10 83 00 00     CMPD   #$0000
0894: 10 27 00 08     LBEQ   $08A0
0898: cc 00 11        LDD    #$0011
089b: ed 66           STD    $6,S
089d: 16 00 05        LBRA   $08A5
08a0: cc 00 10        LDD    #$0010
08a3: ed 66           STD    $6,S
08a5: fc 22 02        LDD    $2202
08a8: 84 00           ANDA   #$00
08aa: c4 80           ANDB   #$80
08ac: 10 83 00 00     CMPD   #$0000
08b0: 10 27 00 08     LBEQ   $08BC
08b4: cc 00 11        LDD    #$0011
08b7: ed 68           STD    $8,S
08b9: 16 00 05        LBRA   $08C1
08bc: cc 00 10        LDD    #$0010
08bf: ed 68           STD    $8,S
08c1: ee 62           LDU    $2,S
08c3: c6 10           LDB    #$10
08c5: 1d              SEX
08c6: 1f 02           TFR    D,Y
08c8: 8e 00 04        LDX    #$0004
08cb: 34 70           PSHS   U,Y,X
08cd: 17 62 d9        LBSR   $6BA9
08d0: 32 66           LEAS   $6,S
08d2: ee 64           LDU    $4,S
08d4: c6 24           LDB    #$24
08d6: 1d              SEX
08d7: 1f 02           TFR    D,Y
08d9: 8e 00 04        LDX    #$0004
08dc: 34 70           PSHS   U,Y,X
08de: 17 62 c8        LBSR   $6BA9
08e1: 32 66           LEAS   $6,S
08e3: ee 66           LDU    $6,S
08e5: c6 50           LDB    #$50
08e7: 1d              SEX
08e8: 1f 02           TFR    D,Y
08ea: 8e 00 04        LDX    #$0004
08ed: 34 70           PSHS   U,Y,X
08ef: 17 62 b7        LBSR   $6BA9
08f2: 32 66           LEAS   $6,S
08f4: ee 68           LDU    $8,S
08f6: c6 64           LDB    #$64
08f8: 1d              SEX
08f9: 1f 02           TFR    D,Y
08fb: 8e 00 04        LDX    #$0004
08fe: 34 70           PSHS   U,Y,X
0900: 17 62 a6        LBSR   $6BA9
0903: 32 66           LEAS   $6,S
0905: 32 6a           LEAS   $A,S
0907: 39              RTS
0908: fc 4e c3        LDD    $4EC3
090b: 17 b4 42        LBSR   $BD50
090e: cc 00 13        LDD    #$0013
0911: fd 22 15        STD    $2215
0914: be 22 17        LDX    $2217
0917: 16 00 3c        LBRA   $0956
091a: 7f 3b 80        CLR    $3B80
091d: 16 00 51        LBRA   $0971
0920: c6 02           LDB    #$02
0922: f7 3b 80        STB    $3B80
0925: 16 00 49        LBRA   $0971
0928: c6 01           LDB    #$01
092a: f7 3b 80        STB    $3B80
092d: 16 00 41        LBRA   $0971
0930: c6 03           LDB    #$03
0932: f7 3b 80        STB    $3B80
0935: 16 00 39        LBRA   $0971
0938: f6 22 19        LDB    $2219
093b: c1 04           CMPB   #$04
093d: 10 24 00 09     LBCC   $094A
0941: f6 22 19        LDB    $2219
0944: f7 3b 80        STB    $3B80
0947: 16 00 03        LBRA   $094D
094a: 16 00 34        LBRA   $0981
094d: 16 00 21        LBRA   $0971
0950: 16 00 2e        LBRA   $0981
0953: 16 00 1b        LBRA   $0971
0956: 8c 00 13        CMPX   #$0013
0959: 27 bf           BEQ    $091A
095b: 8c 00 14        CMPX   #$0014
095e: 27 c0           BEQ    $0920
0960: 8c 00 15        CMPX   #$0015
0963: 27 c3           BEQ    $0928
0965: 8c 00 16        CMPX   #$0016
0968: 27 c6           BEQ    $0930
096a: 8c 00 2b        CMPX   #$002B
096d: 27 c9           BEQ    $0938
096f: 20 df           BRA    $0950
0971: ce 00 09        LDU    #$0009
0974: 10 8e 00 02     LDY    #$0002
0978: 34 60           PSHS   U,Y
097a: be 3b 85        LDX    $3B85
097d: ad 84           JSR    ,X
097f: 32 64           LEAS   $4,S
0981: 32 62           LEAS   $2,S
0983: 39              RTS
0984: fc 4e d4        LDD    $4ED4
0987: 17 b3 c6        LBSR   $BD50
098a: 6f 62           CLR    $2,S
098c: ae e9 00 0b     LDX    $000B,S
0990: 8c 00 11        CMPX   #$0011
0993: 10 26 00 04     LBNE   $099B
0997: c6 08           LDB    #$08
0999: e7 62           STB    $2,S
099b: f6 3b 80        LDB    $3B80
099e: 16 02 11        LBRA   $0BB2
09a1: ae e9 00 0b     LDX    $000B,S
09a5: 8c 00 11        CMPX   #$0011
09a8: 10 26 00 0d     LBNE   $09B9
09ac: fc 22 04        LDD    $2204
09af: 8a 20           ORA    #$20
09b1: ca 00           ORB    #$00
09b3: fd 22 04        STD    $2204
09b6: 16 00 0a        LBRA   $09C3
09b9: fc 22 04        LDD    $2204
09bc: 84 df           ANDA   #$DF
09be: c4 ff           ANDB   #$FF
09c0: fd 22 04        STD    $2204
09c3: ce 00 00        LDU    #$0000
09c6: 34 40           PSHS   U
09c8: 17 fe 38        LBSR   $0803
09cb: 32 62           LEAS   $2,S
09cd: 16 01 fb        LBRA   $0BCB
09d0: ae e9 00 0b     LDX    $000B,S
09d4: 8c 00 11        CMPX   #$0011
09d7: 10 26 00 3e     LBNE   $0A19
09db: ce 00 06        LDU    #$0006
09de: 10 8e 00 02     LDY    #$0002
09e2: 34 60           PSHS   U,Y
09e4: 17 9f 7b        LBSR   $A962
09e7: 32 64           LEAS   $4,S
09e9: 1f 01           TFR    D,X
09eb: af 65           STX    $5,S
09ed: ee 65           LDU    $5,S
09ef: 5f              CLRB
09f0: 1d              SEX
09f1: 1f 02           TFR    D,Y
09f3: 8e 00 04        LDX    #$0004
09f6: 34 70           PSHS   U,Y,X
09f8: 17 19 d7        LBSR   $23D2
09fb: 32 66           LEAS   $6,S
09fd: c1 00           CMPB   #$00
09ff: 10 27 00 13     LBEQ   $0A16
0a03: c6 70           LDB    #$70
0a05: 1d              SEX
0a06: 1f 03           TFR    D,U
0a08: 10 8e 00 02     LDY    #$0002
0a0c: 34 60           PSHS   U,Y
0a0e: 17 79 ed        LBSR   $83FE
0a11: 32 64           LEAS   $4,S
0a13: 16 01 b5        LBRA   $0BCB
0a16: 16 00 2a        LBRA   $0A43
0a19: ce 24 f5        LDU    #$24F5
0a1c: 5f              CLRB
0a1d: 1d              SEX
0a1e: 1f 02           TFR    D,Y
0a20: 8e 00 04        LDX    #$0004
0a23: 34 70           PSHS   U,Y,X
0a25: 17 19 aa        LBSR   $23D2
0a28: 32 66           LEAS   $6,S
0a2a: c1 00           CMPB   #$00
0a2c: 10 27 00 13     LBEQ   $0A43
0a30: c6 73           LDB    #$73
0a32: 1d              SEX
0a33: 1f 03           TFR    D,U
0a35: 10 8e 00 02     LDY    #$0002
0a39: 34 60           PSHS   U,Y
0a3b: 17 79 c0        LBSR   $83FE
0a3e: 32 64           LEAS   $4,S
0a40: 16 01 88        LBRA   $0BCB
0a43: e6 62           LDB    $2,S
0a45: 4f              CLRA
0a46: 1f 03           TFR    D,U
0a48: 10 8e 00 15     LDY    #$0015
0a4c: 8e 00 04        LDX    #$0004
0a4f: 34 70           PSHS   U,Y,X
0a51: 17 9c 48        LBSR   $A69C
0a54: 32 66           LEAS   $6,S
0a56: fe 25 16        LDU    $2516
0a59: 10 8e 00 02     LDY    #$0002
0a5d: 34 60           PSHS   U,Y
0a5f: 17 ad 8a        LBSR   $B7EC
0a62: 32 64           LEAS   $4,S
0a64: ce 00 00        LDU    #$0000
0a67: 34 40           PSHS   U
0a69: 17 0a 7a        LBSR   $14E6
0a6c: 32 62           LEAS   $2,S
0a6e: 16 01 5a        LBRA   $0BCB
0a71: f6 24 0d        LDB    $240D
0a74: c1 00           CMPB   #$00
0a76: 10 26 00 0c     LBNE   $0A86
0a7a: f6 24 0e        LDB    $240E
0a7d: c1 00           CMPB   #$00
0a7f: 10 26 00 03     LBNE   $0A86
0a83: 16 00 13        LBRA   $0A99
0a86: c6 6e           LDB    #$6E
0a88: 1d              SEX
0a89: 1f 03           TFR    D,U
0a8b: 10 8e 00 02     LDY    #$0002
0a8f: 34 60           PSHS   U,Y
0a91: 17 79 6a        LBSR   $83FE
0a94: 32 64           LEAS   $4,S
0a96: 16 01 32        LBRA   $0BCB
0a99: ae e9 00 0b     LDX    $000B,S
0a9d: 8c 00 11        CMPX   #$0011
0aa0: 10 26 00 56     LBNE   $0AFA
0aa4: ce 00 04        LDU    #$0004
0aa7: 10 8e 00 02     LDY    #$0002
0aab: 34 60           PSHS   U,Y
0aad: 17 9e b2        LBSR   $A962
0ab0: 32 64           LEAS   $4,S
0ab2: 1f 01           TFR    D,X
0ab4: af 65           STX    $5,S
0ab6: ee 65           LDU    $5,S
0ab8: 5f              CLRB
0ab9: 1d              SEX
0aba: 1f 02           TFR    D,Y
0abc: 8e 00 04        LDX    #$0004
0abf: 34 70           PSHS   U,Y,X
0ac1: 17 6e 08        LBSR   $78CC
0ac4: 32 66           LEAS   $6,S
0ac6: c1 00           CMPB   #$00
0ac8: 10 27 00 13     LBEQ   $0ADF
0acc: c6 6f           LDB    #$6F
0ace: 1d              SEX
0acf: 1f 03           TFR    D,U
0ad1: 10 8e 00 02     LDY    #$0002
0ad5: 34 60           PSHS   U,Y
0ad7: 17 79 24        LBSR   $83FE
0ada: 32 64           LEAS   $4,S
0adc: 16 00 ec        LBRA   $0BCB
0adf: e6 62           LDB    $2,S
0ae1: 4f              CLRA
0ae2: 1f 03           TFR    D,U
0ae4: 10 8e 00 07     LDY    #$0007
0ae8: 8e 00 04        LDX    #$0004
0aeb: 34 70           PSHS   U,Y,X
0aed: 17 9b ac        LBSR   $A69C
0af0: 32 66           LEAS   $6,S
0af2: cc ea 58        LDD    #$EA58
0af5: ed 63           STD    $3,S
0af7: 16 00 4e        LBRA   $0B48
0afa: e6 62           LDB    $2,S
0afc: 4f              CLRA
0afd: 1f 03           TFR    D,U
0aff: 10 8e 00 07     LDY    #$0007
0b03: 8e 00 04        LDX    #$0004
0b06: 34 70           PSHS   U,Y,X
0b08: 17 9b 91        LBSR   $A69C
0b0b: 32 66           LEAS   $6,S
0b0d: cc 24 ff        LDD    #$24FF
0b10: ed 63           STD    $3,S
0b12: ee 63           LDU    $3,S
0b14: 5f              CLRB
0b15: 1d              SEX
0b16: 1f 02           TFR    D,Y
0b18: 8e 00 04        LDX    #$0004
0b1b: 34 70           PSHS   U,Y,X
0b1d: 17 6d ac        LBSR   $78CC
0b20: 32 66           LEAS   $6,S
0b22: c1 00           CMPB   #$00
0b24: 10 27 00 20     LBEQ   $0B48
0b28: ce ea 58        LDU    #$EA58
0b2b: 10 ae 63        LDY    $3,S
0b2e: 8e 00 04        LDX    #$0004
0b31: 34 70           PSHS   U,Y,X
0b33: 17 88 47        LBSR   $937D
0b36: 32 66           LEAS   $6,S
0b38: c6 7c           LDB    #$7C
0b3a: 1d              SEX
0b3b: 1f 03           TFR    D,U
0b3d: 10 8e 00 02     LDY    #$0002
0b41: 34 60           PSHS   U,Y
0b43: 17 78 b8        LBSR   $83FE
0b46: 32 64           LEAS   $4,S
0b48: ee 63           LDU    $3,S
0b4a: 5f              CLRB
0b4b: 1d              SEX
0b4c: 1f 02           TFR    D,Y
0b4e: 8e 00 04        LDX    #$0004
0b51: 34 70           PSHS   U,Y,X
0b53: 17 75 13        LBSR   $8069
0b56: 32 66           LEAS   $6,S
0b58: ce 00 00        LDU    #$0000
0b5b: 34 40           PSHS   U
0b5d: 17 0c 51        LBSR   $17B1
0b60: 32 62           LEAS   $2,S
0b62: 16 00 66        LBRA   $0BCB
0b65: f6 24 10        LDB    $2410
0b68: c1 00           CMPB   #$00
0b6a: 10 27 00 13     LBEQ   $0B81
0b6e: c6 72           LDB    #$72
0b70: 1d              SEX
0b71: 1f 03           TFR    D,U
0b73: 10 8e 00 02     LDY    #$0002
0b77: 34 60           PSHS   U,Y
0b79: 17 78 82        LBSR   $83FE
0b7c: 32 64           LEAS   $4,S
0b7e: 16 00 4a        LBRA   $0BCB
0b81: e6 62           LDB    $2,S
0b83: 4f              CLRA
0b84: 1f 03           TFR    D,U
0b86: 10 8e 00 09     LDY    #$0009
0b8a: 8e 00 04        LDX    #$0004
0b8d: 34 70           PSHS   U,Y,X
0b8f: 17 9b 0a        LBSR   $A69C
0b92: 32 66           LEAS   $6,S
0b94: fe 25 0a        LDU    $250A
0b97: 5f              CLRB
0b98: 1d              SEX
0b99: 1f 02           TFR    D,Y
0b9b: 8e 00 04        LDX    #$0004
0b9e: 34 70           PSHS   U,Y,X
0ba0: 17 99 bf        LBSR   $A562
0ba3: 32 66           LEAS   $6,S
0ba5: ce 00 00        LDU    #$0000
0ba8: 34 40           PSHS   U
0baa: 17 0c a7        LBSR   $1854
0bad: 32 62           LEAS   $2,S
0baf: 16 00 19        LBRA   $0BCB
0bb2: c1 00           CMPB   #$00
0bb4: 10 27 fd e9     LBEQ   $09A1
0bb8: c1 01           CMPB   #$01
0bba: 10 27 fe 12     LBEQ   $09D0
0bbe: c1 02           CMPB   #$02
0bc0: 10 27 fe ad     LBEQ   $0A71
0bc4: c1 03           CMPB   #$03
0bc6: 27 9d           BEQ    $0B65
0bc8: 16 00 00        LBRA   $0BCB
0bcb: ce 00 00        LDU    #$0000
0bce: 34 40           PSHS   U
0bd0: 17 fc 6c        LBSR   $083F
0bd3: 32 62           LEAS   $2,S
0bd5: ce 00 00        LDU    #$0000
0bd8: 34 40           PSHS   U
0bda: 17 fb e9        LBSR   $07C6
0bdd: 32 62           LEAS   $2,S
0bdf: fc 22 04        LDD    $2204
0be2: fd 26 7f        STD    $267F
0be5: fc 22 02        LDD    $2202
0be8: fd 26 81        STD    $2681
0beb: ce 00 09        LDU    #$0009
0bee: 10 8e 00 02     LDY    #$0002
0bf2: 34 60           PSHS   U,Y
0bf4: be 3b 85        LDX    $3B85
0bf7: ad 84           JSR    ,X
0bf9: 32 64           LEAS   $4,S
0bfb: 32 67           LEAS   $7,S
0bfd: 39              RTS
0bfe: fc 4e d6        LDD    $4ED6
0c01: 17 b1 4c        LBSR   $BD50
0c04: fc 22 02        LDD    $2202
0c07: 84 01           ANDA   #$01
0c09: c4 00           ANDB   #$00
0c0b: 10 83 00 00     CMPD   #$0000
0c0f: 10 27 00 16     LBEQ   $0C29
0c13: ce 22 1c        LDU    #$221C
0c16: 5f              CLRB
0c17: 1d              SEX
0c18: 1f 02           TFR    D,Y
0c1a: 8e 00 04        LDX    #$0004
0c1d: 34 70           PSHS   U,Y,X
0c1f: 17 17 b0        LBSR   $23D2
0c22: 32 66           LEAS   $6,S
0c24: e7 62           STB    $2,S
0c26: 16 00 15        LBRA   $0C3E
0c29: 33 63           LEAU   $3,S
0c2b: 10 8e 22 1c     LDY    #$221C
0c2f: 8e ea 55        LDX    #$EA55
0c32: cc 00 06        LDD    #$0006
0c35: 34 76           PSHS   U,Y,X,D
0c37: 17 87 8c        LBSR   $93C6
0c3a: 32 68           LEAS   $8,S
0c3c: e7 62           STB    $2,S
0c3e: e6 62           LDB    $2,S
0c40: c1 00           CMPB   #$00
0c42: 10 27 00 13     LBEQ   $0C59
0c46: c6 71           LDB    #$71
0c48: 1d              SEX
0c49: 1f 03           TFR    D,U
0c4b: 10 8e 00 02     LDY    #$0002
0c4f: 34 60           PSHS   U,Y
0c51: 17 77 aa        LBSR   $83FE
0c54: 32 64           LEAS   $4,S
0c56: 16 00 43        LBRA   $0C9C
0c59: ce 25 81        LDU    #$2581
0c5c: f6 24 f4        LDB    $24F4
0c5f: 4f              CLRA
0c60: 1f 02           TFR    D,Y
0c62: 34 60           PSHS   U,Y
0c64: 86 01           LDA    #$01
0c66: 8e 4e c6        LDX    #$4EC6
0c69: 17 b0 7e        LBSR   $BCEA
0c6c: 30 04           LEAX   $4,X
0c6e: ce 22 1c        LDU    #$221C
0c71: 1f 12           TFR    X,Y
0c73: 8e 00 04        LDX    #$0004
0c76: 34 70           PSHS   U,Y,X
0c78: 17 87 02        LBSR   $937D
0c7b: 32 66           LEAS   $6,S
0c7d: f6 24 f4        LDB    $24F4
0c80: 4f              CLRA
0c81: 1f 03           TFR    D,U
0c83: 10 8e 00 02     LDY    #$0002
0c87: 34 60           PSHS   U,Y
0c89: 17 91 a2        LBSR   $9E2E
0c8c: 32 64           LEAS   $4,S
0c8e: fe 25 16        LDU    $2516
0c91: 10 8e 00 02     LDY    #$0002
0c95: 34 60           PSHS   U,Y
0c97: 17 ab 52        LBSR   $B7EC
0c9a: 32 64           LEAS   $4,S
0c9c: 32 66           LEAS   $6,S
0c9e: 39              RTS
0c9f: fc 4e c4        LDD    $4EC4
0ca2: 17 b0 ab        LBSR   $BD50
0ca5: 33 62           LEAU   $2,S
0ca7: 10 8e 22 1c     LDY    #$221C
0cab: 8e ea 55        LDX    #$EA55
0cae: cc 00 06        LDD    #$0006
0cb1: 34 76           PSHS   U,Y,X,D
0cb3: 17 87 10        LBSR   $93C6
0cb6: 32 68           LEAS   $8,S
0cb8: c1 00           CMPB   #$00
0cba: 10 27 00 03     LBEQ   $0CC1
0cbe: 16 00 11        LBRA   $0CD2
0cc1: ce 22 1c        LDU    #$221C
0cc4: 10 8e 26 71     LDY    #$2671
0cc8: 8e 00 04        LDX    #$0004
0ccb: 34 70           PSHS   U,Y,X
0ccd: 17 86 ad        LBSR   $937D
0cd0: 32 66           LEAS   $6,S
0cd2: 32 65           LEAS   $5,S
0cd4: 39              RTS
0cd5: fc 4e d6        LDD    $4ED6
0cd8: 17 b0 75        LBSR   $BD50
0cdb: fc 22 02        LDD    $2202
0cde: 84 00           ANDA   #$00
0ce0: c4 40           ANDB   #$40
0ce2: 10 83 00 00     CMPD   #$0000
0ce6: 10 27 00 16     LBEQ   $0D00
0cea: ce 22 1c        LDU    #$221C
0ced: 5f              CLRB
0cee: 1d              SEX
0cef: 1f 02           TFR    D,Y
0cf1: 8e 00 04        LDX    #$0004
0cf4: 34 70           PSHS   U,Y,X
0cf6: 17 6b d3        LBSR   $78CC
0cf9: 32 66           LEAS   $6,S
0cfb: e7 62           STB    $2,S
0cfd: 16 00 10        LBRA   $0D10
0d00: ce 22 1c        LDU    #$221C
0d03: 10 8e 00 02     LDY    #$0002
0d07: 34 60           PSHS   U,Y
0d09: 17 6b a1        LBSR   $78AD
0d0c: 32 64           LEAS   $4,S
0d0e: e7 62           STB    $2,S
0d10: e6 62           LDB    $2,S
0d12: c1 00           CMPB   #$00
0d14: 10 27 00 13     LBEQ   $0D2B
0d18: c6 7a           LDB    #$7A
0d1a: 1d              SEX
0d1b: 1f 03           TFR    D,U
0d1d: 10 8e 00 02     LDY    #$0002
0d21: 34 60           PSHS   U,Y
0d23: 17 76 d8        LBSR   $83FE
0d26: 32 64           LEAS   $4,S
0d28: 16 00 68        LBRA   $0D93
0d2b: ce 25 81        LDU    #$2581
0d2e: f6 24 f4        LDB    $24F4
0d31: 4f              CLRA
0d32: 1f 02           TFR    D,Y
0d34: 34 60           PSHS   U,Y
0d36: 86 01           LDA    #$01
0d38: 8e 4e c6        LDX    #$4EC6
0d3b: 17 af ac        LBSR   $BCEA
0d3e: 30 07           LEAX   $7,X
0d40: ce 22 1c        LDU    #$221C
0d43: 1f 12           TFR    X,Y
0d45: 8e 00 04        LDX    #$0004
0d48: 34 70           PSHS   U,Y,X
0d4a: 17 86 30        LBSR   $937D
0d4d: 32 66           LEAS   $6,S
0d4f: be 25 14        LDX    $2514
0d52: 8c 00 04        CMPX   #$0004
0d55: 10 26 00 1a     LBNE   $0D73
0d59: ce 25 81        LDU    #$2581
0d5c: f6 24 f4        LDB    $24F4
0d5f: 4f              CLRA
0d60: 1f 02           TFR    D,Y
0d62: 34 60           PSHS   U,Y
0d64: 86 01           LDA    #$01
0d66: 8e 4e c6        LDX    #$4EC6
0d69: 17 af 7e        LBSR   $BCEA
0d6c: 30 0a           LEAX   $A,X
0d6e: f6 24 1e        LDB    $241E
0d71: e7 84           STB    ,X
0d73: fc 22 02        LDD    $2202
0d76: 84 00           ANDA   #$00
0d78: c4 40           ANDB   #$40
0d7a: 10 83 00 00     CMPD   #$0000
0d7e: 10 27 00 11     LBEQ   $0D93
0d82: ce 22 1c        LDU    #$221C
0d85: 5f              CLRB
0d86: 1d              SEX
0d87: 1f 02           TFR    D,Y
0d89: 8e 00 04        LDX    #$0004
0d8c: 34 70           PSHS   U,Y,X
0d8e: 17 72 d8        LBSR   $8069
0d91: 32 66           LEAS   $6,S
0d93: 32 66           LEAS   $6,S
0d95: 39              RTS
0d96: fc 4e c4        LDD    $4EC4
0d99: 17 af b4        LBSR   $BD50
0d9c: ce 22 1c        LDU    #$221C
0d9f: 10 8e 00 02     LDY    #$0002
0da3: 34 60           PSHS   U,Y
0da5: 17 6b 05        LBSR   $78AD
0da8: 32 64           LEAS   $4,S
0daa: c1 00           CMPB   #$00
0dac: 10 27 00 03     LBEQ   $0DB3
0db0: 16 00 11        LBRA   $0DC4
0db3: ce 22 1c        LDU    #$221C
0db6: 10 8e 26 74     LDY    #$2674
0dba: 8e 00 04        LDX    #$0004
0dbd: 34 70           PSHS   U,Y,X
0dbf: 17 85 bb        LBSR   $937D
0dc2: 32 66           LEAS   $6,S
0dc4: 32 65           LEAS   $5,S
0dc6: 39              RTS
0dc7: fc 4e d6        LDD    $4ED6
0dca: 17 af 83        LBSR   $BD50
0dcd: be 22 21        LDX    $2221
0dd0: 8c 00 04        CMPX   #$0004
0dd3: 10 26 00 20     LBNE   $0DF7
0dd7: be 22 1a        LDX    $221A
0dda: bc ea 5d        CMPX   $EA5D
0ddd: 10 23 00 03     LBLS   $0DE4
0de1: 16 00 a0        LBRA   $0E84
0de4: fe 22 1a        LDU    $221A
0de7: 10 8e 00 02     LDY    #$0002
0deb: 34 60           PSHS   U,Y
0ded: 17 84 b9        LBSR   $92A9
0df0: 32 64           LEAS   $4,S
0df2: ed 62           STD    $2,S
0df4: 16 00 12        LBRA   $0E09
0df7: be 22 1a        LDX    $221A
0dfa: bc ea 5b        CMPX   $EA5B
0dfd: 10 23 00 03     LBLS   $0E04
0e01: 16 00 80        LBRA   $0E84
0e04: fc 22 1a        LDD    $221A
0e07: ed 62           STD    $2,S
0e09: ce 25 81        LDU    #$2581
0e0c: f6 24 f4        LDB    $24F4
0e0f: 4f              CLRA
0e10: 1f 02           TFR    D,Y
0e12: 34 60           PSHS   U,Y
0e14: 86 01           LDA    #$01
0e16: 8e 4e c6        LDX    #$4EC6
0e19: 17 ae ce        LBSR   $BCEA
0e1c: 30 0d           LEAX   $D,X
0e1e: fc 22 21        LDD    $2221
0e21: ed 84           STD    ,X
0e23: ce 25 81        LDU    #$2581
0e26: f6 24 f4        LDB    $24F4
0e29: 4f              CLRA
0e2a: 1f 02           TFR    D,Y
0e2c: 34 60           PSHS   U,Y
0e2e: 86 01           LDA    #$01
0e30: 8e 4e c6        LDX    #$4EC6
0e33: 17 ae b4        LBSR   $BCEA
0e36: 30 0b           LEAX   $B,X
0e38: fc 22 1a        LDD    $221A
0e3b: ed 84           STD    ,X
0e3d: ee 62           LDU    $2,S
0e3f: 10 8e 00 02     LDY    #$0002
0e43: 34 60           PSHS   U,Y
0e45: 17 7a 7e        LBSR   $88C6
0e48: 32 64           LEAS   $4,S
0e4a: ed 64           STD    $4,S
0e4c: ec 64           LDD    $4,S
0e4e: c3 00 08        ADDD   #$0008
0e51: ed 64           STD    $4,S
0e53: ae 64           LDX    $4,S
0e55: c6 fc           LDB    #$FC
0e57: 17 b1 4a        LBSR   $BFA4
0e5a: ed 64           STD    $4,S
0e5c: ce 25 81        LDU    #$2581
0e5f: f6 24 f4        LDB    $24F4
0e62: 4f              CLRA
0e63: 1f 02           TFR    D,Y
0e65: 34 60           PSHS   U,Y
0e67: 86 01           LDA    #$01
0e69: 8e 4e c6        LDX    #$4EC6
0e6c: 17 ae 7b        LBSR   $BCEA
0e6f: ec 64           LDD    $4,S
0e71: ed 84           STD    ,X
0e73: f6 24 f4        LDB    $24F4
0e76: 4f              CLRA
0e77: 1f 03           TFR    D,U
0e79: 10 8e 00 02     LDY    #$0002
0e7d: 34 60           PSHS   U,Y
0e7f: 17 8f ac        LBSR   $9E2E
0e82: 32 64           LEAS   $4,S
0e84: 32 66           LEAS   $6,S
0e86: 39              RTS
0e87: fc 4e c3        LDD    $4EC3
0e8a: 17 ae c3        LBSR   $BD50
0e8d: be 22 21        LDX    $2221
0e90: 8c 00 04        CMPX   #$0004
0e93: 10 26 00 10     LBNE   $0EA7
0e97: be 22 1a        LDX    $221A
0e9a: bc ea 5d        CMPX   $EA5D
0e9d: 10 23 00 03     LBLS   $0EA4
0ea1: 16 00 1c        LBRA   $0EC0
0ea4: 16 00 0d        LBRA   $0EB4
0ea7: be 22 1a        LDX    $221A
0eaa: bc ea 5b        CMPX   $EA5B
0ead: 10 23 00 03     LBLS   $0EB4
0eb1: 16 00 0c        LBRA   $0EC0
0eb4: fc 22 21        LDD    $2221
0eb7: fd 26 79        STD    $2679
0eba: fc 22 1a        LDD    $221A
0ebd: fd 26 7d        STD    $267D
0ec0: 32 62           LEAS   $2,S
0ec2: 39              RTS
0ec3: 00 00           NEG    <$00
0ec5: 03 00           COM    <$00
0ec7: 01 00           NEG    <$00
0ec9: 00 00           NEG    <$00
0ecb: 0f 00           CLR    <$00
0ecd: 09 00           ROL    <$00
0ecf: 07 00           ASR    <$00
0ed1: 06 00           ROR    <$00
0ed3: 08 00           ASL    <$00
0ed5: 05 00           LSR    <$00
0ed7: 04 fc           LSR    <$FC
0ed9: 5c              INCB
0eda: cc 17 ae        LDD    #$17AE
0edd: 72 ae e9        XNC    $AEE9
0ee0: 00 0d           NEG    <$0D
0ee2: 16 02 19        LBRA   $10FE
0ee5: cc 00 03        LDD    #$0003
0ee8: ed 67           STD    $7,S
0eea: cc 00 06        LDD    #$0006
0eed: ed 65           STD    $5,S
0eef: c6 08           LDB    #$08
0ef1: e7 62           STB    $2,S
0ef3: c6 0b           LDB    #$0B
0ef5: e7 63           STB    $3,S
0ef7: c6 14           LDB    #$14
0ef9: e7 64           STB    $4,S
0efb: 16 02 2d        LBRA   $112B
0efe: c6 05           LDB    #$05
0f00: e7 62           STB    $2,S
0f02: c6 1f           LDB    #$1F
0f04: e7 63           STB    $3,S
0f06: c6 25           LDB    #$25
0f08: e7 64           STB    $4,S
0f0a: cc 00 03        LDD    #$0003
0f0d: ed 67           STD    $7,S
0f0f: be 23 bf        LDX    $23BF
0f12: 30 0d           LEAX   $D,X
0f14: ae 84           LDX    ,X
0f16: 16 00 8e        LBRA   $0FA7
0f19: cc ea 6e        LDD    #$EA6E
0f1c: fd 23 b7        STD    $23B7
0f1f: cc 00 07        LDD    #$0007
0f22: ed 65           STD    $5,S
0f24: 16 00 b5        LBRA   $0FDC
0f27: ce 00 00        LDU    #$0000
0f2a: 34 40           PSHS   U
0f2c: 17 55 43        LBSR   $6472
0f2f: 32 62           LEAS   $2,S
0f31: 5f              CLRB
0f32: 1d              SEX
0f33: 1f 03           TFR    D,U
0f35: 10 8e 00 02     LDY    #$0002
0f39: 34 60           PSHS   U,Y
0f3b: 17 64 4d        LBSR   $738B
0f3e: 32 64           LEAS   $4,S
0f40: 16 02 07        LBRA   $114A
0f43: cc ea 65        LDD    #$EA65
0f46: fd 23 b7        STD    $23B7
0f49: cc 00 06        LDD    #$0006
0f4c: ed 65           STD    $5,S
0f4e: 16 00 8b        LBRA   $0FDC
0f51: cc ea 68        LDD    #$EA68
0f54: fd 23 b7        STD    $23B7
0f57: cc 00 03        LDD    #$0003
0f5a: ed 65           STD    $5,S
0f5c: 16 00 7d        LBRA   $0FDC
0f5f: cc ea 6b        LDD    #$EA6B
0f62: fd 23 b7        STD    $23B7
0f65: cc 00 03        LDD    #$0003
0f68: ed 65           STD    $5,S
0f6a: 16 00 6f        LBRA   $0FDC
0f6d: cc ea 62        LDD    #$EA62
0f70: fd 23 b7        STD    $23B7
0f73: cc 00 04        LDD    #$0004
0f76: ed 65           STD    $5,S
0f78: be 23 bf        LDX    $23BF
0f7b: 30 88 1f        LEAX   $1F,X
0f7e: ae 84           LDX    ,X
0f80: 8c 00 04        CMPX   #$0004
0f83: 10 26 00 0d     LBNE   $0F94
0f87: be 22 15        LDX    $2215
0f8a: 8c 00 07        CMPX   #$0007
0f8d: 10 27 00 03     LBEQ   $0F94
0f91: 16 00 03        LBRA   $0F97
0f94: 16 00 0d        LBRA   $0FA4
0f97: c6 06           LDB    #$06
0f99: e7 62           STB    $2,S
0f9b: c6 1e           LDB    #$1E
0f9d: e7 63           STB    $3,S
0f9f: cc 00 02        LDD    #$0002
0fa2: ed 67           STD    $7,S
0fa4: 16 00 35        LBRA   $0FDC
0fa7: 8c 00 0f        CMPX   #$000F
0faa: 10 2e 00 2e     LBGT   $0FDC
0fae: 1f 10           TFR    X,D
0fb0: 83 00 01        SUBD   #$0001
0fb3: 10 2d 00 25     LBLT   $0FDC
0fb7: 8e 4f be        LDX    #$4FBE
0fba: 58              ASLB
0fbb: 49              ROLA
0fbc: 6e 9b           JMP    [D,X]
0fbe: 4f              CLRA
0fbf: 43              COMA
0fc0: 4f              CLRA
0fc1: 43              COMA
0fc2: 4f              CLRA
0fc3: 51              NEGB
0fc4: 4f              CLRA
0fc5: 5f              CLRB
0fc6: 4f              CLRA
0fc7: 6d 4f           TST    $F,U
0fc9: 6d 4f           TST    $F,U
0fcb: 6d 4f           TST    $F,U
0fcd: dc 4f           LDD    <$4F
0fcf: dc 4f           LDD    <$4F
0fd1: dc 4f           LDD    <$4F
0fd3: 19              DAA
0fd4: 4f              CLRA
0fd5: dc 4f           LDD    <$4F
0fd7: 27 4f           BEQ    $1028
0fd9: 27 4f           BEQ    $102A
0fdb: 27 16           BEQ    $0FF3
0fdd: 01 4c           NEG    <$4C
0fdf: cc 00 03        LDD    #$0003
0fe2: ed 67           STD    $7,S
0fe4: cc 00 03        LDD    #$0003
0fe7: ed 65           STD    $5,S
0fe9: c6 05           LDB    #$05
0feb: e7 62           STB    $2,S
0fed: c6 46           LDB    #$46
0fef: e7 63           STB    $3,S
0ff1: c6 4c           LDB    #$4C
0ff3: e7 64           STB    $4,S
0ff5: 16 01 33        LBRA   $112B
0ff8: cc 00 05        LDD    #$0005
0ffb: ed 67           STD    $7,S
0ffd: 5f              CLRB
0ffe: 4f              CLRA
0fff: ed 65           STD    $5,S
1001: 6f 62           CLR    $2,S
1003: c6 57           LDB    #$57
1005: e7 63           STB    $3,S
1007: c6 57           LDB    #$57
1009: e7 64           STB    $4,S
100b: 16 01 1d        LBRA   $112B
100e: cc 00 04        LDD    #$0004
1011: ed 67           STD    $7,S
1013: 5f              CLRB
1014: 4f              CLRA
1015: ed 65           STD    $5,S
1017: 6f 62           CLR    $2,S
1019: c6 64           LDB    #$64
101b: e7 63           STB    $3,S
101d: c6 64           LDB    #$64
101f: e7 64           STB    $4,S
1021: 16 01 07        LBRA   $112B
1024: cc 00 03        LDD    #$0003
1027: ed 67           STD    $7,S
1029: cc 00 06        LDD    #$0006
102c: ed 65           STD    $5,S
102e: c6 08           LDB    #$08
1030: e7 62           STB    $2,S
1032: c6 1b           LDB    #$1B
1034: e7 63           STB    $3,S
1036: c6 24           LDB    #$24
1038: e7 64           STB    $4,S
103a: 16 00 ee        LBRA   $112B
103d: c6 4e           LDB    #$4E
103f: e7 64           STB    $4,S
1041: cc ea 62        LDD    #$EA62
1044: fd 23 b7        STD    $23B7
1047: cc 00 04        LDD    #$0004
104a: ed 65           STD    $5,S
104c: be 25 14        LDX    $2514
104f: 8c 00 04        CMPX   #$0004
1052: 10 26 00 0d     LBNE   $1063
1056: be 22 15        LDX    $2215
1059: 8c 00 10        CMPX   #$0010
105c: 10 27 00 03     LBEQ   $1063
1060: 16 00 03        LBRA   $1066
1063: 16 00 10        LBRA   $1076
1066: c6 06           LDB    #$06
1068: e7 62           STB    $2,S
106a: c6 47           LDB    #$47
106c: e7 63           STB    $3,S
106e: cc 00 02        LDD    #$0002
1071: ed 67           STD    $7,S
1073: 16 00 0d        LBRA   $1083
1076: cc 00 03        LDD    #$0003
1079: ed 67           STD    $7,S
107b: c6 05           LDB    #$05
107d: e7 62           STB    $2,S
107f: c6 48           LDB    #$48
1081: e7 63           STB    $3,S
1083: 16 00 a5        LBRA   $112B
1086: cc 00 03        LDD    #$0003
1089: ed 67           STD    $7,S
108b: cc 00 03        LDD    #$0003
108e: ed 65           STD    $5,S
1090: c6 05           LDB    #$05
1092: e7 62           STB    $2,S
1094: c6 5c           LDB    #$5C
1096: e7 63           STB    $3,S
1098: c6 62           LDB    #$62
109a: e7 64           STB    $4,S
109c: 16 00 8c        LBRA   $112B
109f: cc 00 06        LDD    #$0006
10a2: ed 67           STD    $7,S
10a4: 5f              CLRB
10a5: 4f              CLRA
10a6: ed 65           STD    $5,S
10a8: 6f 62           CLR    $2,S
10aa: c6 10           LDB    #$10
10ac: e7 64           STB    $4,S
10ae: f6 3b 80        LDB    $3B80
10b1: 16 00 1c        LBRA   $10D0
10b4: c6 10           LDB    #$10
10b6: e7 63           STB    $3,S
10b8: 16 00 28        LBRA   $10E3
10bb: c6 24           LDB    #$24
10bd: e7 63           STB    $3,S
10bf: 16 00 21        LBRA   $10E3
10c2: c6 50           LDB    #$50
10c4: e7 63           STB    $3,S
10c6: 16 00 1a        LBRA   $10E3
10c9: c6 64           LDB    #$64
10cb: e7 63           STB    $3,S
10cd: 16 00 13        LBRA   $10E3
10d0: c1 00           CMPB   #$00
10d2: 27 e0           BEQ    $10B4
10d4: c1 01           CMPB   #$01
10d6: 27 e3           BEQ    $10BB
10d8: c1 02           CMPB   #$02
10da: 27 e6           BEQ    $10C2
10dc: c1 03           CMPB   #$03
10de: 27 e9           BEQ    $10C9
10e0: 16 00 00        LBRA   $10E3
10e3: 16 00 45        LBRA   $112B
10e6: 5f              CLRB
10e7: 4f              CLRA
10e8: ed 67           STD    $7,S
10ea: cc 00 02        LDD    #$0002
10ed: ed 65           STD    $5,S
10ef: c6 02           LDB    #$02
10f1: e7 62           STB    $2,S
10f3: c6 10           LDB    #$10
10f5: e7 63           STB    $3,S
10f7: c6 10           LDB    #$10
10f9: e7 64           STB    $4,S
10fb: 16 00 2d        LBRA   $112B
10fe: 8c 00 00        CMPX   #$0000
1101: 10 2d 00 26     LBLT   $112B
1105: 8c 00 0a        CMPX   #$000A
1108: 10 2e 00 1f     LBGT   $112B
110c: 1f 10           TFR    X,D
110e: 8e 51 15        LDX    #$5115
1111: 58              ASLB
1112: 49              ROLA
1113: 6e 9b           JMP    [D,X]
1115: 4e              XCLRA
1116: e5 4e           BITB   $E,U
1118: fe 4f df        LDU    $4FDF
111b: 4f              CLRA
111c: f8 50 0e        EORB   $500E
111f: 51              NEGB
1120: 2b 50           BMI    $1172
1122: 24 50           BCC    $1174
1124: 3d              MUL
1125: 50              NEGB
1126: 86 50           LDA    #$50
1128: 9f 50           STX    <$50
112a: e6 e6           LDB    A,S
112c: 64 4f           LSR    $F,U
112e: 1f 03           TFR    D,U
1130: 10 ae 65        LDY    $5,S
1133: e6 63           LDB    $3,S
1135: 4f              CLRA
1136: 1f 01           TFR    D,X
1138: e6 62           LDB    $2,S
113a: 4f              CLRA
113b: 34 76           PSHS   U,Y,X,D
113d: ee 6f           LDU    $F,S
113f: 10 8e 00 0a     LDY    #$000A
1143: 34 60           PSHS   U,Y
1145: 17 5a ed        LBSR   $6C35
1148: 32 6c           LEAS   $C,S
114a: 32 69           LEAS   $9,S
114c: 39              RTS
114d: fc 5c d5        LDD    $5CD5
1150: 17 ab fd        LBSR   $BD50
1153: f6 26 8e        LDB    $268E
1156: 16 00 b5        LBRA   $120E
1159: c6 ff           LDB    #$FF
115b: f7 3b 81        STB    $3B81
115e: 16 00 ef        LBRA   $1250
1161: cc 5c ce        LDD    #$5CCE
1164: ed 62           STD    $2,S
1166: 7f 23 be        CLR    $23BE
1169: ce 00 00        LDU    #$0000
116c: 34 40           PSHS   U
116e: 17 70 a9        LBSR   $821A
1171: 32 62           LEAS   $2,S
1173: 7f 3b 81        CLR    $3B81
1176: 16 00 b7        LBRA   $1230
1179: cc 5c d0        LDD    #$5CD0
117c: ed 62           STD    $2,S
117e: c6 01           LDB    #$01
1180: f7 23 be        STB    $23BE
1183: ce 00 00        LDU    #$0000
1186: 34 40           PSHS   U
1188: 17 70 8f        LBSR   $821A
118b: 32 62           LEAS   $2,S
118d: c6 01           LDB    #$01
118f: f7 3b 81        STB    $3B81
1192: 16 00 9b        LBRA   $1230
1195: cc 5c d2        LDD    #$5CD2
1198: ed 62           STD    $2,S
119a: c6 02           LDB    #$02
119c: f7 23 be        STB    $23BE
119f: ce 00 00        LDU    #$0000
11a2: 34 40           PSHS   U
11a4: 17 70 73        LBSR   $821A
11a7: 32 62           LEAS   $2,S
11a9: c6 02           LDB    #$02
11ab: f7 3b 81        STB    $3B81
11ae: 16 00 7f        LBRA   $1230
11b1: cc 5c d4        LDD    #$5CD4
11b4: ed 62           STD    $2,S
11b6: c6 03           LDB    #$03
11b8: f7 23 be        STB    $23BE
11bb: ce 00 00        LDU    #$0000
11be: 34 40           PSHS   U
11c0: 17 70 57        LBSR   $821A
11c3: 32 62           LEAS   $2,S
11c5: c6 03           LDB    #$03
11c7: f7 3b 81        STB    $3B81
11ca: 16 00 63        LBRA   $1230
11cd: 7f 23 be        CLR    $23BE
11d0: ce 00 00        LDU    #$0000
11d3: 34 40           PSHS   U
11d5: 17 70 42        LBSR   $821A
11d8: 32 62           LEAS   $2,S
11da: c6 05           LDB    #$05
11dc: f7 3b 81        STB    $3B81
11df: ce 00 00        LDU    #$0000
11e2: 34 40           PSHS   U
11e4: 17 f5 df        LBSR   $07C6
11e7: 32 62           LEAS   $2,S
11e9: 16 00 64        LBRA   $1250
11ec: 7f 23 be        CLR    $23BE
11ef: ce 00 00        LDU    #$0000
11f2: 34 40           PSHS   U
11f4: 17 70 23        LBSR   $821A
11f7: 32 62           LEAS   $2,S
11f9: c6 06           LDB    #$06
11fb: f7 3b 81        STB    $3B81
11fe: ce 00 00        LDU    #$0000
1201: 34 40           PSHS   U
1203: 17 f6 39        LBSR   $083F
1206: 32 62           LEAS   $2,S
1208: 16 00 45        LBRA   $1250
120b: 16 00 22        LBRA   $1230
120e: c1 00           CMPB   #$00
1210: 10 25 00 1c     LBCS   $1230
1214: c1 06           CMPB   #$06
1216: 10 22 00 16     LBHI   $1230
121a: 8e 52 22        LDX    #$5222
121d: 4f              CLRA
121e: 58              ASLB
121f: 49              ROLA
1220: 6e 9b           JMP    [D,X]
1222: 51              NEGB
1223: 59              ROLB
1224: 51              NEGB
1225: 61 51           NEG    -$F,U
1227: 79 51 95        ROL    $5195
122a: 51              NEGB
122b: b1 51 cd        CMPA   $51CD
122e: 51              NEGB
122f: ec ee           LDD    W,S
1231: 62 c6           XNC    A,U
1233: 01 1d           NEG    <$1D
1235: 1f 02           TFR    D,Y
1237: c6 03           LDB    #$03
1239: 1d              SEX
123a: 1f 01           TFR    D,X
123c: cc 00 06        LDD    #$0006
123f: 34 76           PSHS   U,Y,X,D
1241: 17 86 a6        LBSR   $98EA
1244: 32 68           LEAS   $8,S
1246: ce 00 00        LDU    #$0000
1249: 34 40           PSHS   U
124b: 17 0a 31        LBSR   $1C7F
124e: 32 62           LEAS   $2,S
1250: 32 64           LEAS   $4,S
1252: 39              RTS
1253: fc 5c d7        LDD    $5CD7
1256: 17 aa f7        LBSR   $BD50
1259: 7f 23 be        CLR    $23BE
125c: f6 23 be        LDB    $23BE
125f: c1 04           CMPB   #$04
1261: 10 24 00 27     LBCC   $128C
1265: ce 00 00        LDU    #$0000
1268: 34 40           PSHS   U
126a: 17 6f ad        LBSR   $821A
126d: 32 62           LEAS   $2,S
126f: ce 00 10        LDU    #$0010
1272: f6 23 be        LDB    $23BE
1275: 4f              CLRA
1276: 1f 02           TFR    D,Y
1278: 8e 00 04        LDX    #$0004
127b: 34 70           PSHS   U,Y,X
127d: 17 26 3f        LBSR   $38BF
1280: 32 66           LEAS   $6,S
1282: f6 23 be        LDB    $23BE
1285: cb 01           ADDB   #$01
1287: f7 23 be        STB    $23BE
128a: 20 d0           BRA    $125C
128c: 32 62           LEAS   $2,S
128e: 39              RTS
128f: fc 5c cc        LDD    $5CCC
1292: 17 aa bb        LBSR   $BD50
1295: c6 ff           LDB    #$FF
1297: f7 3b 81        STB    $3B81
129a: 7f 3b 84        CLR    $3B84
129d: ae e9 00 0d     LDX    $000D,S
12a1: 8c 00 02        CMPX   #$0002
12a4: 10 27 00 0a     LBEQ   $12B2
12a8: ce 00 00        LDU    #$0000
12ab: 34 40           PSHS   U
12ad: 17 74 3a        LBSR   $86EA
12b0: 32 62           LEAS   $2,S
12b2: ae e9 00 0d     LDX    $000D,S
12b6: 8c 00 01        CMPX   #$0001
12b9: 10 26 00 3d     LBNE   $12FA
12bd: ce 26 8f        LDU    #$268F
12c0: f6 22 19        LDB    $2219
12c3: 4f              CLRA
12c4: 1f 02           TFR    D,Y
12c6: 34 60           PSHS   U,Y
12c8: 86 01           LDA    #$01
12ca: 8e 5c d8        LDX    #$5CD8
12cd: 17 aa 1a        LBSR   $BCEA
12d0: ce 24 e6        LDU    #$24E6
12d3: 1f 12           TFR    X,Y
12d5: 8e 01 a9        LDX    #$01A9
12d8: cc 00 06        LDD    #$0006
12db: 34 76           PSHS   U,Y,X,D
12dd: 17 6f a5        LBSR   $8285
12e0: 32 68           LEAS   $8,S
12e2: f6 26 83        LDB    $2683
12e5: f7 23 b3        STB    $23B3
12e8: f6 26 84        LDB    $2684
12eb: f7 23 b4        STB    $23B4
12ee: f6 26 85        LDB    $2685
12f1: f7 23 b5        STB    $23B5
12f4: f6 26 86        LDB    $2686
12f7: f7 23 b6        STB    $23B6
12fa: ae e9 00 0d     LDX    $000D,S
12fe: 8c 00 00        CMPX   #$0000
1301: 10 27 00 f2     LBEQ   $13F7
1305: fc 26 7f        LDD    $267F
1308: ed 65           STD    $5,S
130a: fc 26 81        LDD    $2681
130d: ed 67           STD    $7,S
130f: ce 00 00        LDU    #$0000
1312: 34 40           PSHS   U
1314: 17 72 9a        LBSR   $85B1
1317: 32 62           LEAS   $2,S
1319: ce 00 00        LDU    #$0000
131c: 34 40           PSHS   U
131e: 17 94 78        LBSR   $A799
1321: 32 62           LEAS   $2,S
1323: ae e9 00 0d     LDX    $000D,S
1327: 8c 00 01        CMPX   #$0001
132a: 10 26 00 44     LBNE   $1372
132e: 6f 62           CLR    $2,S
1330: e6 62           LDB    $2,S
1332: c1 04           CMPB   #$04
1334: 10 24 00 3a     LBCC   $1372
1338: 8e 24 f0        LDX    #$24F0
133b: e6 62           LDB    $2,S
133d: 3a              ABX
133e: e6 84           LDB    ,X
1340: e7 63           STB    $3,S
1342: e6 63           LDB    $3,S
1344: 4f              CLRA
1345: 1f 03           TFR    D,U
1347: 10 8e 00 ff     LDY    #$00FF
134b: e6 62           LDB    $2,S
134d: 4f              CLRA
134e: 1f 01           TFR    D,X
1350: cc 00 06        LDD    #$0006
1353: 34 76           PSHS   U,Y,X,D
1355: 17 88 49        LBSR   $9BA1
1358: 32 68           LEAS   $8,S
135a: e6 62           LDB    $2,S
135c: 4f              CLRA
135d: 1f 03           TFR    D,U
135f: 10 8e 00 02     LDY    #$0002
1363: 34 60           PSHS   U,Y
1365: 17 63 c7        LBSR   $772F
1368: 32 64           LEAS   $4,S
136a: e6 62           LDB    $2,S
136c: cb 01           ADDB   #$01
136e: e7 62           STB    $2,S
1370: 20 be           BRA    $1330
1372: ec 65           LDD    $5,S
1374: 84 20           ANDA   #$20
1376: c4 00           ANDB   #$00
1378: 10 83 00 00     CMPD   #$0000
137c: 10 27 00 11     LBEQ   $1391
1380: 7f 3b 80        CLR    $3B80
1383: ce 00 11        LDU    #$0011
1386: 10 8e 00 02     LDY    #$0002
138a: 34 60           PSHS   U,Y
138c: 17 f5 f5        LBSR   $0984
138f: 32 64           LEAS   $4,S
1391: ec 67           LDD    $7,S
1393: 84 01           ANDA   #$01
1395: c4 00           ANDB   #$00
1397: 10 83 00 00     CMPD   #$0000
139b: 10 27 00 13     LBEQ   $13B2
139f: c6 01           LDB    #$01
13a1: f7 3b 80        STB    $3B80
13a4: ce 00 11        LDU    #$0011
13a7: 10 8e 00 02     LDY    #$0002
13ab: 34 60           PSHS   U,Y
13ad: 17 f5 d4        LBSR   $0984
13b0: 32 64           LEAS   $4,S
13b2: ec 67           LDD    $7,S
13b4: 84 00           ANDA   #$00
13b6: c4 40           ANDB   #$40
13b8: 10 83 00 00     CMPD   #$0000
13bc: 10 27 00 13     LBEQ   $13D3
13c0: c6 02           LDB    #$02
13c2: f7 3b 80        STB    $3B80
13c5: ce 00 11        LDU    #$0011
13c8: 10 8e 00 02     LDY    #$0002
13cc: 34 60           PSHS   U,Y
13ce: 17 f5 b3        LBSR   $0984
13d1: 32 64           LEAS   $4,S
13d3: ec 67           LDD    $7,S
13d5: 84 00           ANDA   #$00
13d7: c4 80           ANDB   #$80
13d9: 10 83 00 00     CMPD   #$0000
13dd: 10 27 00 13     LBEQ   $13F4
13e1: c6 03           LDB    #$03
13e3: f7 3b 80        STB    $3B80
13e6: ce 00 11        LDU    #$0011
13e9: 10 8e 00 02     LDY    #$0002
13ed: 34 60           PSHS   U,Y
13ef: 17 f5 92        LBSR   $0984
13f2: 32 64           LEAS   $4,S
13f4: 16 00 0a        LBRA   $1401
13f7: ce 00 00        LDU    #$0000
13fa: 34 40           PSHS   U
13fc: 17 72 c4        LBSR   $86C3
13ff: 32 62           LEAS   $2,S
1401: 7f 23 be        CLR    $23BE
1404: f6 23 be        LDB    $23BE
1407: c1 04           CMPB   #$04
1409: 10 24 00 33     LBCC   $1440
140d: ce 00 00        LDU    #$0000
1410: 34 40           PSHS   U
1412: 17 6e 05        LBSR   $821A
1415: 32 62           LEAS   $2,S
1417: f6 23 be        LDB    $23BE
141a: 4f              CLRA
141b: 58              ASLB
141c: 49              ROLA
141d: 8e 24 de        LDX    #$24DE
1420: 30 8b           LEAX   D,X
1422: ae 84           LDX    ,X
1424: 1f 13           TFR    X,U
1426: f6 23 be        LDB    $23BE
1429: 4f              CLRA
142a: 1f 02           TFR    D,Y
142c: 8e 00 04        LDX    #$0004
142f: 34 70           PSHS   U,Y,X
1431: 17 24 8b        LBSR   $38BF
1434: 32 66           LEAS   $6,S
1436: f6 23 be        LDB    $23BE
1439: cb 01           ADDB   #$01
143b: f7 23 be        STB    $23BE
143e: 20 c4           BRA    $1404
1440: ce 00 00        LDU    #$0000
1443: 34 40           PSHS   U
1445: 17 8a 6e        LBSR   $9EB6
1448: 32 62           LEAS   $2,S
144a: 5f              CLRB
144b: 4f              CLRA
144c: fd 22 15        STD    $2215
144f: f6 26 8e        LDB    $268E
1452: e7 64           STB    $4,S
1454: ce 43 3e        LDU    #$433E
1457: 10 8e 00 02     LDY    #$0002
145b: 34 60           PSHS   U,Y
145d: 17 35 a8        LBSR   $4A08
1460: 32 64           LEAS   $4,S
1462: ae e9 00 0d     LDX    $000D,S
1466: 8c 00 00        CMPX   #$0000
1469: 10 27 00 0c     LBEQ   $1479
146d: e6 64           LDB    $4,S
146f: f1 22 42        CMPB   $2242
1472: 10 22 00 03     LBHI   $1479
1476: 16 00 03        LBRA   $147C
1479: 16 00 0f        LBRA   $148B
147c: e6 64           LDB    $4,S
147e: f7 26 8e        STB    $268E
1481: ce 00 00        LDU    #$0000
1484: 34 40           PSHS   U
1486: 17 35 21        LBSR   $49AA
1489: 32 62           LEAS   $2,S
148b: ce 00 00        LDU    #$0000
148e: 34 40           PSHS   U
1490: 17 fc ba        LBSR   $114D
1493: 32 62           LEAS   $2,S
1495: f6 3f fc        LDB    $3FFC
1498: c4 02           ANDB   #$02
149a: 4f              CLRA
149b: 10 83 00 00     CMPD   #$0000
149f: 10 26 00 1c     LBNE   $14BF
14a3: f6 3f fc        LDB    $3FFC
14a6: c4 01           ANDB   #$01
14a8: 4f              CLRA
14a9: 10 83 00 00     CMPD   #$0000
14ad: 10 26 00 09     LBNE   $14BA
14b1: f6 23 b2        LDB    $23B2
14b4: f7 22 42        STB    $2242
14b7: 16 00 05        LBRA   $14BF
14ba: c6 04           LDB    #$04
14bc: f7 22 42        STB    $2242
14bf: cc 5d 0c        LDD    #$5D0C
14c2: fd 22 0f        STD    $220F
14c5: cc c2 39        LDD    #$C239
14c8: fd 22 11        STD    $2211
14cb: cc 4e d8        LDD    #$4ED8
14ce: fd 3b 85        STD    $3B85
14d1: cc 52 53        LDD    #$5253
14d4: fd 22 13        STD    $2213
14d7: fc 22 04        LDD    $2204
14da: fd 26 7f        STD    $267F
14dd: fc 22 02        LDD    $2202
14e0: fd 26 81        STD    $2681
14e3: 32 69           LEAS   $9,S
14e5: 39              RTS
14e6: fc 5c d5        LDD    $5CD5
14e9: 17 a8 64        LBSR   $BD50
14ec: ce 24 f5        LDU    #$24F5
14ef: f6 23 be        LDB    $23BE
14f2: 4f              CLRA
14f3: 1f 02           TFR    D,Y
14f5: 34 60           PSHS   U,Y
14f7: 86 01           LDA    #$01
14f9: 8e 5c de        LDX    #$5CDE
14fc: 17 a7 eb        LBSR   $BCEA
14ff: af 62           STX    $2,S
1501: f6 23 be        LDB    $23BE
1504: f1 3b 81        CMPB   $3B81
1507: 10 27 00 03     LBEQ   $150E
150b: 16 01 3d        LBRA   $164B
150e: ce ed 11        LDU    #$ED11
1511: c6 0c           LDB    #$0C
1513: 1d              SEX
1514: 1f 02           TFR    D,Y
1516: c6 0b           LDB    #$0B
1518: 1d              SEX
1519: 1f 01           TFR    D,X
151b: cc 00 06        LDD    #$0006
151e: 34 76           PSHS   U,Y,X,D
1520: 17 83 c7        LBSR   $98EA
1523: 32 68           LEAS   $8,S
1525: f6 23 be        LDB    $23BE
1528: c1 00           CMPB   #$00
152a: 10 26 00 12     LBNE   $1540
152e: fc 22 02        LDD    $2202
1531: 84 01           ANDA   #$01
1533: c4 00           ANDB   #$00
1535: 10 83 00 00     CMPD   #$0000
1539: 10 27 00 03     LBEQ   $1540
153d: 16 00 03        LBRA   $1543
1540: 16 00 1a        LBRA   $155D
1543: ce 43 84        LDU    #$4384
1546: c6 0c           LDB    #$0C
1548: 1d              SEX
1549: 1f 02           TFR    D,Y
154b: c6 0b           LDB    #$0B
154d: 1d              SEX
154e: 1f 01           TFR    D,X
1550: cc 00 06        LDD    #$0006
1553: 34 76           PSHS   U,Y,X,D
1555: 17 83 92        LBSR   $98EA
1558: 32 68           LEAS   $8,S
155a: 16 00 ee        LBRA   $164B
155d: ae 62           LDX    $2,S
155f: 30 88 1f        LEAX   $1F,X
1562: ae 84           LDX    ,X
1564: 8c 00 04        CMPX   #$0004
1567: 10 27 00 11     LBEQ   $157C
156b: ae 62           LDX    $2,S
156d: 30 88 1f        LEAX   $1F,X
1570: ae 84           LDX    ,X
1572: 8c 00 05        CMPX   #$0005
1575: 10 27 00 03     LBEQ   $157C
1579: 16 00 1a        LBRA   $1596
157c: ce ed 11        LDU    #$ED11
157f: c6 0c           LDB    #$0C
1581: 1d              SEX
1582: 1f 02           TFR    D,Y
1584: c6 0b           LDB    #$0B
1586: 1d              SEX
1587: 1f 01           TFR    D,X
1589: cc 00 06        LDD    #$0006
158c: 34 76           PSHS   U,Y,X,D
158e: 17 83 59        LBSR   $98EA
1591: 32 68           LEAS   $8,S
1593: 16 00 b5        LBRA   $164B
1596: ce 24 14        LDU    #$2414
1599: 10 ae 62        LDY    $2,S
159c: 8e 00 04        LDX    #$0004
159f: 34 70           PSHS   U,Y,X
15a1: 17 74 eb        LBSR   $8A8F
15a4: 32 66           LEAS   $6,S
15a6: ae 62           LDX    $2,S
15a8: 30 03           LEAX   $3,X
15aa: ae 84           LDX    ,X
15ac: 8c 00 02        CMPX   #$0002
15af: 10 26 00 36     LBNE   $15E9
15b3: ce 24 14        LDU    #$2414
15b6: c6 06           LDB    #$06
15b8: 1d              SEX
15b9: 1f 02           TFR    D,Y
15bb: 8e 00 04        LDX    #$0004
15be: 34 70           PSHS   U,Y,X
15c0: 17 77 3c        LBSR   $8CFF
15c3: 32 66           LEAS   $6,S
15c5: 5f              CLRB
15c6: 1d              SEX
15c7: 1f 03           TFR    D,U
15c9: c6 07           LDB    #$07
15cb: 1d              SEX
15cc: 1f 02           TFR    D,Y
15ce: c6 08           LDB    #$08
15d0: 1d              SEX
15d1: 1f 01           TFR    D,X
15d3: cc 24 14        LDD    #$2414
15d6: 34 76           PSHS   U,Y,X,D
15d8: ce 24 14        LDU    #$2414
15db: 10 8e 00 0a     LDY    #$000A
15df: 34 60           PSHS   U,Y
15e1: 17 77 6c        LBSR   $8D50
15e4: 32 6c           LEAS   $C,S
15e6: 16 00 34        LBRA   $161D
15e9: ce 24 14        LDU    #$2414
15ec: c6 03           LDB    #$03
15ee: 1d              SEX
15ef: 1f 02           TFR    D,Y
15f1: 8e 00 04        LDX    #$0004
15f4: 34 70           PSHS   U,Y,X
15f6: 17 77 06        LBSR   $8CFF
15f9: 32 66           LEAS   $6,S
15fb: c6 01           LDB    #$01
15fd: 1d              SEX
15fe: 1f 03           TFR    D,U
1600: c6 04           LDB    #$04
1602: 1d              SEX
1603: 1f 02           TFR    D,Y
1605: c6 08           LDB    #$08
1607: 1d              SEX
1608: 1f 01           TFR    D,X
160a: cc 24 14        LDD    #$2414
160d: 34 76           PSHS   U,Y,X,D
160f: ce 24 14        LDU    #$2414
1612: 10 8e 00 0a     LDY    #$000A
1616: 34 60           PSHS   U,Y
1618: 17 77 35        LBSR   $8D50
161b: 32 6c           LEAS   $C,S
161d: ce 24 15        LDU    #$2415
1620: c6 08           LDB    #$08
1622: 1d              SEX
1623: 1f 02           TFR    D,Y
1625: c6 0b           LDB    #$0B
1627: 1d              SEX
1628: 1f 01           TFR    D,X
162a: cc 00 06        LDD    #$0006
162d: 34 76           PSHS   U,Y,X,D
162f: 17 82 b8        LBSR   $98EA
1632: 32 68           LEAS   $8,S
1634: ae 62           LDX    $2,S
1636: 30 03           LEAX   $3,X
1638: ae 84           LDX    ,X
163a: 1f 13           TFR    X,U
163c: c6 14           LDB    #$14
163e: 1d              SEX
163f: 1f 02           TFR    D,Y
1641: 8e 00 04        LDX    #$0004
1644: 34 70           PSHS   U,Y,X
1646: 17 55 a6        LBSR   $6BEF
1649: 32 66           LEAS   $6,S
164b: 32 64           LEAS   $4,S
164d: 39              RTS
164e: fc 5c cc        LDD    $5CCC
1651: 17 a6 fc        LBSR   $BD50
1654: ec e9 00 13     LDD    $0013,S
1658: ed 65           STD    $5,S
165a: cc 24 14        LDD    #$2414
165d: ed 63           STD    $3,S
165f: c6 20           LDB    #$20
1661: e7 62           STB    $2,S
1663: ae 65           LDX    $5,S
1665: 16 00 cf        LBRA   $1737
1668: cc ed 11        LDD    #$ED11
166b: ed 63           STD    $3,S
166d: 16 00 fc        LBRA   $176C
1670: be 23 bf        LDX    $23BF
1673: 30 88 1f        LEAX   $1F,X
1676: ae 84           LDX    ,X
1678: 8c 00 04        CMPX   #$0004
167b: 10 26 00 0d     LBNE   $168C
167f: be 22 15        LDX    $2215
1682: 8c 00 07        CMPX   #$0007
1685: 10 27 00 03     LBEQ   $168C
1689: 16 00 03        LBRA   $168F
168c: 16 00 0a        LBRA   $1699
168f: be 23 bf        LDX    $23BF
1692: 30 88 14        LEAX   $14,X
1695: e6 84           LDB    ,X
1697: e7 62           STB    $2,S
1699: ce 24 14        LDU    #$2414
169c: 10 8e 00 02     LDY    #$0002
16a0: 34 60           PSHS   U,Y
16a2: 17 79 7d        LBSR   $9022
16a5: 32 64           LEAS   $4,S
16a7: ed 65           STD    $5,S
16a9: 16 00 c0        LBRA   $176C
16ac: ce 24 14        LDU    #$2414
16af: c6 06           LDB    #$06
16b1: 1d              SEX
16b2: 1f 02           TFR    D,Y
16b4: 8e 00 04        LDX    #$0004
16b7: 34 70           PSHS   U,Y,X
16b9: 17 76 43        LBSR   $8CFF
16bc: 32 66           LEAS   $6,S
16be: 8e 24 14        LDX    #$2414
16c1: 30 04           LEAX   $4,X
16c3: 5f              CLRB
16c4: 1d              SEX
16c5: 1f 03           TFR    D,U
16c7: c6 03           LDB    #$03
16c9: 1d              SEX
16ca: 1f 02           TFR    D,Y
16cc: c6 05           LDB    #$05
16ce: 1d              SEX
16cf: af 67           STX    $7,S
16d1: 1f 01           TFR    D,X
16d3: cc 24 14        LDD    #$2414
16d6: 34 76           PSHS   U,Y,X,D
16d8: ee 6f           LDU    $F,S
16da: 10 8e 00 0a     LDY    #$000A
16de: 34 60           PSHS   U,Y
16e0: 17 76 6d        LBSR   $8D50
16e3: 32 6c           LEAS   $C,S
16e5: 16 00 84        LBRA   $176C
16e8: ce 24 14        LDU    #$2414
16eb: c6 03           LDB    #$03
16ed: 1d              SEX
16ee: 1f 02           TFR    D,Y
16f0: 8e 00 04        LDX    #$0004
16f3: 34 70           PSHS   U,Y,X
16f5: 17 76 07        LBSR   $8CFF
16f8: 32 66           LEAS   $6,S
16fa: 8e 24 14        LDX    #$2414
16fd: 30 04           LEAX   $4,X
16ff: 5f              CLRB
1700: 1d              SEX
1701: 1f 03           TFR    D,U
1703: c6 01           LDB    #$01
1705: 1d              SEX
1706: 1f 02           TFR    D,Y
1708: c6 05           LDB    #$05
170a: 1d              SEX
170b: af 67           STX    $7,S
170d: 1f 01           TFR    D,X
170f: cc 24 14        LDD    #$2414
1712: 34 76           PSHS   U,Y,X,D
1714: ee 6f           LDU    $F,S
1716: 10 8e 00 0a     LDY    #$000A
171a: 34 60           PSHS   U,Y
171c: 17 76 31        LBSR   $8D50
171f: 32 6c           LEAS   $C,S
1721: 16 00 48        LBRA   $176C
1724: ce 24 14        LDU    #$2414
1727: 10 8e 00 02     LDY    #$0002
172b: 34 60           PSHS   U,Y
172d: 17 7a 4d        LBSR   $917D
1730: 32 64           LEAS   $4,S
1732: ed 65           STD    $5,S
1734: 16 00 35        LBRA   $176C
1737: 8c 00 0f        CMPX   #$000F
173a: 10 2e 00 2e     LBGT   $176C
173e: 1f 10           TFR    X,D
1740: 83 00 01        SUBD   #$0001
1743: 10 2d 00 25     LBLT   $176C
1747: 8e 57 4e        LDX    #$574E
174a: 58              ASLB
174b: 49              ROLA
174c: 6e 9b           JMP    [D,X]
174e: 57              ASRB
174f: 24 57           BCC    $17A8
1751: 24 56           BCC    $17A9
1753: ac 56           CMPX   -$A,U
1755: e8 56           EORB   -$A,U
1757: 70 56 70        NEG    $5670
175a: 56              RORB
175b: 70 57 6c        NEG    $576C
175e: 57              ASRB
175f: 6c 57           INC    -$9,U
1761: 6c 56           INC    -$A,U
1763: ac 57           CMPX   -$9,U
1765: 6c 56           INC    -$A,U
1767: 68 56           ASL    -$A,U
1769: 68 56           ASL    -$A,U
176b: 68 ee           ASL    W,S
176d: 65 10           LSR    -$10,X
176f: ae e9 00 11     LDX    $0011,S
1773: 8e 00 04        LDX    #$0004
1776: 34 70           PSHS   U,Y,X
1778: 17 54 74        LBSR   $6BEF
177b: 32 66           LEAS   $6,S
177d: ec e9 00 0f     LDD    $000F,S
1781: 83 00 01        SUBD   #$0001
1784: 33 62           LEAU   $2,S
1786: ed 67           STD    $7,S
1788: c6 01           LDB    #$01
178a: 1d              SEX
178b: 1f 02           TFR    D,Y
178d: ae 67           LDX    $7,S
178f: cc 00 06        LDD    #$0006
1792: 34 76           PSHS   U,Y,X,D
1794: 17 81 53        LBSR   $98EA
1797: 32 68           LEAS   $8,S
1799: ee 63           LDU    $3,S
179b: c6 05           LDB    #$05
179d: 1d              SEX
179e: 1f 02           TFR    D,Y
17a0: ae e9 00 0f     LDX    $000F,S
17a4: cc 00 06        LDD    #$0006
17a7: 34 76           PSHS   U,Y,X,D
17a9: 17 81 3e        LBSR   $98EA
17ac: 32 68           LEAS   $8,S
17ae: 32 69           LEAS   $9,S
17b0: 39              RTS
17b1: fc 5c e4        LDD    $5CE4
17b4: 17 a5 99        LBSR   $BD50
17b7: f6 23 be        LDB    $23BE
17ba: f1 3b 81        CMPB   $3B81
17bd: 17 a5 f6        LBSR   $BDB6
17c0: c1 00           CMPB   #$00
17c2: 10 26 00 03     LBNE   $17C9
17c6: 16 00 88        LBRA   $1851
17c9: ce ed 11        LDU    #$ED11
17cc: c6 09           LDB    #$09
17ce: 1d              SEX
17cf: 1f 02           TFR    D,Y
17d1: c6 1f           LDB    #$1F
17d3: 1d              SEX
17d4: 1f 01           TFR    D,X
17d6: cc 00 06        LDD    #$0006
17d9: 34 76           PSHS   U,Y,X,D
17db: 17 81 0c        LBSR   $98EA
17de: 32 68           LEAS   $8,S
17e0: f6 23 be        LDB    $23BE
17e3: c1 00           CMPB   #$00
17e5: 10 26 00 12     LBNE   $17FB
17e9: fc 22 02        LDD    $2202
17ec: 84 00           ANDA   #$00
17ee: c4 40           ANDB   #$40
17f0: 10 83 00 00     CMPD   #$0000
17f4: 10 27 00 03     LBEQ   $17FB
17f8: 16 00 03        LBRA   $17FE
17fb: 16 00 1a        LBRA   $1818
17fe: ce 43 84        LDU    #$4384
1801: c6 09           LDB    #$09
1803: 1d              SEX
1804: 1f 02           TFR    D,Y
1806: c6 1f           LDB    #$1F
1808: 1d              SEX
1809: 1f 01           TFR    D,X
180b: cc 00 06        LDD    #$0006
180e: 34 76           PSHS   U,Y,X,D
1810: 17 80 d7        LBSR   $98EA
1813: 32 68           LEAS   $8,S
1815: 16 00 39        LBRA   $1851
1818: be 23 bf        LDX    $23BF
181b: 30 0a           LEAX   $A,X
181d: ce 24 14        LDU    #$2414
1820: 1f 12           TFR    X,Y
1822: 8e 00 04        LDX    #$0004
1825: 34 70           PSHS   U,Y,X
1827: 17 72 65        LBSR   $8A8F
182a: 32 66           LEAS   $6,S
182c: be 23 bf        LDX    $23BF
182f: 30 0d           LEAX   $D,X
1831: ae 84           LDX    ,X
1833: af 65           STX    $5,S
1835: ee 65           LDU    $5,S
1837: c6 25           LDB    #$25
1839: 1d              SEX
183a: 1f 02           TFR    D,Y
183c: c6 1f           LDB    #$1F
183e: 1d              SEX
183f: 1f 01           TFR    D,X
1841: f6 23 be        LDB    $23BE
1844: 4f              CLRA
1845: 34 76           PSHS   U,Y,X,D
1847: ce 00 08        LDU    #$0008
184a: 34 40           PSHS   U
184c: 17 fd ff        LBSR   $164E
184f: 32 6a           LEAS   $A,S
1851: 32 67           LEAS   $7,S
1853: 39              RTS
1854: fc 5c e6        LDD    $5CE6
1857: 17 a4 f6        LBSR   $BD50
185a: ce 24 f5        LDU    #$24F5
185d: f6 23 be        LDB    $23BE
1860: 4f              CLRA
1861: 1f 02           TFR    D,Y
1863: 34 60           PSHS   U,Y
1865: 86 01           LDA    #$01
1867: 8e 5c de        LDX    #$5CDE
186a: 17 a4 7d        LBSR   $BCEA
186d: af 62           STX    $2,S
186f: f6 23 be        LDB    $23BE
1872: f1 3b 81        CMPB   $3B81
1875: 17 a5 3e        LBSR   $BDB6
1878: c1 00           CMPB   #$00
187a: 10 26 00 03     LBNE   $1881
187e: 16 01 2f        LBRA   $19B0
1881: ce ed 11        LDU    #$ED11
1884: c6 0a           LDB    #$0A
1886: 1d              SEX
1887: 1f 02           TFR    D,Y
1889: c6 46           LDB    #$46
188b: 1d              SEX
188c: 1f 01           TFR    D,X
188e: cc 00 06        LDD    #$0006
1891: 34 76           PSHS   U,Y,X,D
1893: 17 80 54        LBSR   $98EA
1896: 32 68           LEAS   $8,S
1898: f6 23 be        LDB    $23BE
189b: c1 00           CMPB   #$00
189d: 10 26 00 12     LBNE   $18B3
18a1: fc 22 02        LDD    $2202
18a4: 84 00           ANDA   #$00
18a6: c4 80           ANDB   #$80
18a8: 10 83 00 00     CMPD   #$0000
18ac: 10 27 00 03     LBEQ   $18B3
18b0: 16 00 03        LBRA   $18B6
18b3: 16 00 1a        LBRA   $18D0
18b6: ce 43 84        LDU    #$4384
18b9: c6 0a           LDB    #$0A
18bb: 1d              SEX
18bc: 1f 02           TFR    D,Y
18be: c6 46           LDB    #$46
18c0: 1d              SEX
18c1: 1f 01           TFR    D,X
18c3: cc 00 06        LDD    #$0006
18c6: 34 76           PSHS   U,Y,X,D
18c8: 17 80 1f        LBSR   $98EA
18cb: 32 68           LEAS   $8,S
18cd: 16 00 e0        LBRA   $19B0
18d0: ae 62           LDX    $2,S
18d2: 30 88 1f        LEAX   $1F,X
18d5: ae 84           LDX    ,X
18d7: 8c 00 04        CMPX   #$0004
18da: 10 27 00 11     LBEQ   $18EF
18de: ae 62           LDX    $2,S
18e0: 30 88 1f        LEAX   $1F,X
18e3: ae 84           LDX    ,X
18e5: 8c 00 05        CMPX   #$0005
18e8: 10 27 00 03     LBEQ   $18EF
18ec: 16 00 1a        LBRA   $1909
18ef: ce ed 11        LDU    #$ED11
18f2: c6 09           LDB    #$09
18f4: 1d              SEX
18f5: 1f 02           TFR    D,Y
18f7: c6 46           LDB    #$46
18f9: 1d              SEX
18fa: 1f 01           TFR    D,X
18fc: cc 00 06        LDD    #$0006
18ff: 34 76           PSHS   U,Y,X,D
1901: 17 7f e6        LBSR   $98EA
1904: 32 68           LEAS   $8,S
1906: 16 00 a7        LBRA   $19B0
1909: ae 62           LDX    $2,S
190b: 30 88 19        LEAX   $19,X
190e: ae 84           LDX    ,X
1910: 8c 00 03        CMPX   #$0003
1913: 10 26 00 2f     LBNE   $1946
1917: ae 62           LDX    $2,S
1919: 30 88 15        LEAX   $15,X
191c: ce 24 14        LDU    #$2414
191f: ae 84           LDX    ,X
1921: 1f 12           TFR    X,Y
1923: 8e 00 04        LDX    #$0004
1926: 34 70           PSHS   U,Y,X
1928: 17 6f e7        LBSR   $8912
192b: 32 66           LEAS   $6,S
192d: ce 24 14        LDU    #$2414
1930: c6 03           LDB    #$03
1932: 1d              SEX
1933: 1f 02           TFR    D,Y
1935: 8e 00 04        LDX    #$0004
1938: 34 70           PSHS   U,Y,X
193a: 17 73 c2        LBSR   $8CFF
193d: 32 66           LEAS   $6,S
193f: c6 04           LDB    #$04
1941: e7 64           STB    $4,S
1943: 16 00 1a        LBRA   $1960
1946: ae 62           LDX    $2,S
1948: 30 88 17        LEAX   $17,X
194b: ce 24 14        LDU    #$2414
194e: ae 84           LDX    ,X
1950: 1f 12           TFR    X,Y
1952: 8e 00 04        LDX    #$0004
1955: 34 70           PSHS   U,Y,X
1957: 17 6f b8        LBSR   $8912
195a: 32 66           LEAS   $6,S
195c: c6 02           LDB    #$02
195e: e7 64           STB    $4,S
1960: 5f              CLRB
1961: 1d              SEX
1962: 1f 03           TFR    D,U
1964: e6 64           LDB    $4,S
1966: 4f              CLRA
1967: 1f 02           TFR    D,Y
1969: c6 05           LDB    #$05
196b: 1d              SEX
196c: 1f 01           TFR    D,X
196e: cc 24 14        LDD    #$2414
1971: 34 76           PSHS   U,Y,X,D
1973: ce 24 14        LDU    #$2414
1976: 10 8e 00 0a     LDY    #$000A
197a: 34 60           PSHS   U,Y
197c: 17 73 d1        LBSR   $8D50
197f: 32 6c           LEAS   $C,S
1981: ce 24 15        LDU    #$2415
1984: c6 05           LDB    #$05
1986: 1d              SEX
1987: 1f 02           TFR    D,Y
1989: c6 46           LDB    #$46
198b: 1d              SEX
198c: 1f 01           TFR    D,X
198e: cc 00 06        LDD    #$0006
1991: 34 76           PSHS   U,Y,X,D
1993: 17 7f 54        LBSR   $98EA
1996: 32 68           LEAS   $8,S
1998: ae 62           LDX    $2,S
199a: 30 88 19        LEAX   $19,X
199d: ae 84           LDX    ,X
199f: 1f 13           TFR    X,U
19a1: c6 4c           LDB    #$4C
19a3: 1d              SEX
19a4: 1f 02           TFR    D,Y
19a6: 8e 00 04        LDX    #$0004
19a9: 34 70           PSHS   U,Y,X
19ab: 17 52 41        LBSR   $6BEF
19ae: 32 66           LEAS   $6,S
19b0: 32 65           LEAS   $5,S
19b2: 39              RTS
19b3: fc 5c d7        LDD    $5CD7
19b6: 17 a3 97        LBSR   $BD50
19b9: f6 23 be        LDB    $23BE
19bc: f1 3b 81        CMPB   $3B81
19bf: 17 a3 f4        LBSR   $BDB6
19c2: c1 00           CMPB   #$00
19c4: 10 26 00 03     LBNE   $19CB
19c8: 16 00 19        LBRA   $19E4
19cb: be 23 bf        LDX    $23BF
19ce: 30 88 1f        LEAX   $1F,X
19d1: ae 84           LDX    ,X
19d3: 1f 13           TFR    X,U
19d5: c6 57           LDB    #$57
19d7: 1d              SEX
19d8: 1f 02           TFR    D,Y
19da: 8e 00 04        LDX    #$0004
19dd: 34 70           PSHS   U,Y,X
19df: 17 51 c7        LBSR   $6BA9
19e2: 32 66           LEAS   $6,S
19e4: 32 62           LEAS   $2,S
19e6: 39              RTS
19e7: fc 5c d7        LDD    $5CD7
19ea: 17 a3 63        LBSR   $BD50
19ed: f6 23 be        LDB    $23BE
19f0: f1 3b 81        CMPB   $3B81
19f3: 17 a3 c0        LBSR   $BDB6
19f6: c1 00           CMPB   #$00
19f8: 10 26 00 03     LBNE   $19FF
19fc: 16 00 19        LBRA   $1A18
19ff: be 23 bf        LDX    $23BF
1a02: 30 88 21        LEAX   $21,X
1a05: ae 84           LDX    ,X
1a07: 1f 13           TFR    X,U
1a09: c6 64           LDB    #$64
1a0b: 1d              SEX
1a0c: 1f 02           TFR    D,Y
1a0e: 8e 00 04        LDX    #$0004
1a11: 34 70           PSHS   U,Y,X
1a13: 17 51 93        LBSR   $6BA9
1a16: 32 66           LEAS   $6,S
1a18: 32 62           LEAS   $2,S
1a1a: 39              RTS
1a1b: fc 5c d5        LDD    $5CD5
1a1e: 17 a3 2f        LBSR   $BD50
1a21: ce 24 f5        LDU    #$24F5
1a24: f6 23 be        LDB    $23BE
1a27: 4f              CLRA
1a28: 1f 02           TFR    D,Y
1a2a: 34 60           PSHS   U,Y
1a2c: 86 01           LDA    #$01
1a2e: 8e 5c de        LDX    #$5CDE
1a31: 17 a2 b6        LBSR   $BCEA
1a34: af 62           STX    $2,S
1a36: f6 23 be        LDB    $23BE
1a39: f1 3b 81        CMPB   $3B81
1a3c: 17 a3 77        LBSR   $BDB6
1a3f: c1 00           CMPB   #$00
1a41: 10 26 00 03     LBNE   $1A48
1a45: 16 00 c8        LBRA   $1B10
1a48: ae 62           LDX    $2,S
1a4a: 30 05           LEAX   $5,X
1a4c: ce 24 14        LDU    #$2414
1a4f: 1f 12           TFR    X,Y
1a51: 8e 00 04        LDX    #$0004
1a54: 34 70           PSHS   U,Y,X
1a56: 17 70 36        LBSR   $8A8F
1a59: 32 66           LEAS   $6,S
1a5b: ae 62           LDX    $2,S
1a5d: 30 08           LEAX   $8,X
1a5f: ae 84           LDX    ,X
1a61: 8c 00 02        CMPX   #$0002
1a64: 10 26 00 36     LBNE   $1A9E
1a68: ce 24 14        LDU    #$2414
1a6b: c6 06           LDB    #$06
1a6d: 1d              SEX
1a6e: 1f 02           TFR    D,Y
1a70: 8e 00 04        LDX    #$0004
1a73: 34 70           PSHS   U,Y,X
1a75: 17 72 87        LBSR   $8CFF
1a78: 32 66           LEAS   $6,S
1a7a: 5f              CLRB
1a7b: 1d              SEX
1a7c: 1f 03           TFR    D,U
1a7e: c6 07           LDB    #$07
1a80: 1d              SEX
1a81: 1f 02           TFR    D,Y
1a83: c6 08           LDB    #$08
1a85: 1d              SEX
1a86: 1f 01           TFR    D,X
1a88: cc 24 14        LDD    #$2414
1a8b: 34 76           PSHS   U,Y,X,D
1a8d: ce 24 14        LDU    #$2414
1a90: 10 8e 00 0a     LDY    #$000A
1a94: 34 60           PSHS   U,Y
1a96: 17 72 b7        LBSR   $8D50
1a99: 32 6c           LEAS   $C,S
1a9b: 16 00 34        LBRA   $1AD2
1a9e: ce 24 14        LDU    #$2414
1aa1: c6 03           LDB    #$03
1aa3: 1d              SEX
1aa4: 1f 02           TFR    D,Y
1aa6: 8e 00 04        LDX    #$0004
1aa9: 34 70           PSHS   U,Y,X
1aab: 17 72 51        LBSR   $8CFF
1aae: 32 66           LEAS   $6,S
1ab0: c6 01           LDB    #$01
1ab2: 1d              SEX
1ab3: 1f 03           TFR    D,U
1ab5: c6 04           LDB    #$04
1ab7: 1d              SEX
1ab8: 1f 02           TFR    D,Y
1aba: c6 08           LDB    #$08
1abc: 1d              SEX
1abd: 1f 01           TFR    D,X
1abf: cc 24 14        LDD    #$2414
1ac2: 34 76           PSHS   U,Y,X,D
1ac4: ce 24 14        LDU    #$2414
1ac7: 10 8e 00 0a     LDY    #$000A
1acb: 34 60           PSHS   U,Y
1acd: 17 72 80        LBSR   $8D50
1ad0: 32 6c           LEAS   $C,S
1ad2: c6 0a           LDB    #$0A
1ad4: 1d              SEX
1ad5: 1f 03           TFR    D,U
1ad7: 10 8e 00 02     LDY    #$0002
1adb: 34 60           PSHS   U,Y
1add: 17 6d 75        LBSR   $8855
1ae0: 32 64           LEAS   $4,S
1ae2: ce 24 15        LDU    #$2415
1ae5: c6 08           LDB    #$08
1ae7: 1d              SEX
1ae8: 1f 02           TFR    D,Y
1aea: c6 0b           LDB    #$0B
1aec: 1d              SEX
1aed: 1f 01           TFR    D,X
1aef: cc 00 06        LDD    #$0006
1af2: 34 76           PSHS   U,Y,X,D
1af4: 17 7d f3        LBSR   $98EA
1af7: 32 68           LEAS   $8,S
1af9: ae 62           LDX    $2,S
1afb: 30 08           LEAX   $8,X
1afd: ae 84           LDX    ,X
1aff: 1f 13           TFR    X,U
1b01: c6 14           LDB    #$14
1b03: 1d              SEX
1b04: 1f 02           TFR    D,Y
1b06: 8e 00 04        LDX    #$0004
1b09: 34 70           PSHS   U,Y,X
1b0b: 17 50 e1        LBSR   $6BEF
1b0e: 32 66           LEAS   $6,S
1b10: 32 64           LEAS   $4,S
1b12: 39              RTS
1b13: fc 5c d5        LDD    $5CD5
1b16: 17 a2 37        LBSR   $BD50
1b19: f6 23 be        LDB    $23BE
1b1c: f1 3b 81        CMPB   $3B81
1b1f: 17 a2 94        LBSR   $BDB6
1b22: c1 00           CMPB   #$00
1b24: 10 26 00 03     LBNE   $1B2B
1b28: 16 00 6a        LBRA   $1B95
1b2b: ce 24 f5        LDU    #$24F5
1b2e: f6 23 be        LDB    $23BE
1b31: 4f              CLRA
1b32: 1f 02           TFR    D,Y
1b34: 34 60           PSHS   U,Y
1b36: 86 01           LDA    #$01
1b38: 8e 5c de        LDX    #$5CDE
1b3b: 17 a1 ac        LBSR   $BCEA
1b3e: 30 0f           LEAX   $F,X
1b40: ce 24 14        LDU    #$2414
1b43: 1f 12           TFR    X,Y
1b45: 8e 00 04        LDX    #$0004
1b48: 34 70           PSHS   U,Y,X
1b4a: 17 6f 42        LBSR   $8A8F
1b4d: 32 66           LEAS   $6,S
1b4f: ce 24 f5        LDU    #$24F5
1b52: f6 23 be        LDB    $23BE
1b55: 4f              CLRA
1b56: 1f 02           TFR    D,Y
1b58: 34 60           PSHS   U,Y
1b5a: 86 01           LDA    #$01
1b5c: 8e 5c de        LDX    #$5CDE
1b5f: 17 a1 88        LBSR   $BCEA
1b62: 30 88 12        LEAX   $12,X
1b65: ae 84           LDX    ,X
1b67: af 62           STX    $2,S
1b69: c6 1d           LDB    #$1D
1b6b: 1d              SEX
1b6c: 1f 03           TFR    D,U
1b6e: 10 8e 00 02     LDY    #$0002
1b72: 34 60           PSHS   U,Y
1b74: 17 6c de        LBSR   $8855
1b77: 32 64           LEAS   $4,S
1b79: ee 62           LDU    $2,S
1b7b: c6 25           LDB    #$25
1b7d: 1d              SEX
1b7e: 1f 02           TFR    D,Y
1b80: c6 1f           LDB    #$1F
1b82: 1d              SEX
1b83: 1f 01           TFR    D,X
1b85: f6 23 be        LDB    $23BE
1b88: 4f              CLRA
1b89: 34 76           PSHS   U,Y,X,D
1b8b: ce 00 08        LDU    #$0008
1b8e: 34 40           PSHS   U
1b90: 17 fa bb        LBSR   $164E
1b93: 32 6a           LEAS   $A,S
1b95: 32 64           LEAS   $4,S
1b97: 39              RTS
1b98: fc 5c e6        LDD    $5CE6
1b9b: 17 a1 b2        LBSR   $BD50
1b9e: ce 24 f5        LDU    #$24F5
1ba1: f6 23 be        LDB    $23BE
1ba4: 4f              CLRA
1ba5: 1f 02           TFR    D,Y
1ba7: 34 60           PSHS   U,Y
1ba9: 86 01           LDA    #$01
1bab: 8e 5c de        LDX    #$5CDE
1bae: 17 a1 39        LBSR   $BCEA
1bb1: af 63           STX    $3,S
1bb3: f6 23 be        LDB    $23BE
1bb6: f1 3b 81        CMPB   $3B81
1bb9: 17 a1 fa        LBSR   $BDB6
1bbc: c1 00           CMPB   #$00
1bbe: 10 26 00 03     LBNE   $1BC5
1bc2: 16 00 b7        LBRA   $1C7C
1bc5: ae 63           LDX    $3,S
1bc7: 30 88 19        LEAX   $19,X
1bca: ae 84           LDX    ,X
1bcc: 8c 00 03        CMPX   #$0003
1bcf: 10 26 00 2f     LBNE   $1C02
1bd3: ae 63           LDX    $3,S
1bd5: 30 88 1b        LEAX   $1B,X
1bd8: ce 24 14        LDU    #$2414
1bdb: ae 84           LDX    ,X
1bdd: 1f 12           TFR    X,Y
1bdf: 8e 00 04        LDX    #$0004
1be2: 34 70           PSHS   U,Y,X
1be4: 17 6d 2b        LBSR   $8912
1be7: 32 66           LEAS   $6,S
1be9: ce 24 14        LDU    #$2414
1bec: c6 03           LDB    #$03
1bee: 1d              SEX
1bef: 1f 02           TFR    D,Y
1bf1: 8e 00 04        LDX    #$0004
1bf4: 34 70           PSHS   U,Y,X
1bf6: 17 71 06        LBSR   $8CFF
1bf9: 32 66           LEAS   $6,S
1bfb: c6 04           LDB    #$04
1bfd: e7 62           STB    $2,S
1bff: 16 00 1a        LBRA   $1C1C
1c02: ae 63           LDX    $3,S
1c04: 30 88 1d        LEAX   $1D,X
1c07: ce 24 14        LDU    #$2414
1c0a: ae 84           LDX    ,X
1c0c: 1f 12           TFR    X,Y
1c0e: 8e 00 04        LDX    #$0004
1c11: 34 70           PSHS   U,Y,X
1c13: 17 6c fc        LBSR   $8912
1c16: 32 66           LEAS   $6,S
1c18: c6 02           LDB    #$02
1c1a: e7 62           STB    $2,S
1c1c: 5f              CLRB
1c1d: 1d              SEX
1c1e: 1f 03           TFR    D,U
1c20: e6 62           LDB    $2,S
1c22: 4f              CLRA
1c23: 1f 02           TFR    D,Y
1c25: c6 05           LDB    #$05
1c27: 1d              SEX
1c28: 1f 01           TFR    D,X
1c2a: cc 24 14        LDD    #$2414
1c2d: 34 76           PSHS   U,Y,X,D
1c2f: ce 24 14        LDU    #$2414
1c32: 10 8e 00 0a     LDY    #$000A
1c36: 34 60           PSHS   U,Y
1c38: 17 71 15        LBSR   $8D50
1c3b: 32 6c           LEAS   $C,S
1c3d: c6 45           LDB    #$45
1c3f: 1d              SEX
1c40: 1f 03           TFR    D,U
1c42: 10 8e 00 02     LDY    #$0002
1c46: 34 60           PSHS   U,Y
1c48: 17 6c 0a        LBSR   $8855
1c4b: 32 64           LEAS   $4,S
1c4d: ce 24 15        LDU    #$2415
1c50: c6 05           LDB    #$05
1c52: 1d              SEX
1c53: 1f 02           TFR    D,Y
1c55: c6 46           LDB    #$46
1c57: 1d              SEX
1c58: 1f 01           TFR    D,X
1c5a: cc 00 06        LDD    #$0006
1c5d: 34 76           PSHS   U,Y,X,D
1c5f: 17 7c 88        LBSR   $98EA
1c62: 32 68           LEAS   $8,S
1c64: ae 63           LDX    $3,S
1c66: 30 88 19        LEAX   $19,X
1c69: ae 84           LDX    ,X
1c6b: 1f 13           TFR    X,U
1c6d: c6 4c           LDB    #$4C
1c6f: 1d              SEX
1c70: 1f 02           TFR    D,Y
1c72: 8e 00 04        LDX    #$0004
1c75: 34 70           PSHS   U,Y,X
1c77: 17 4f 75        LBSR   $6BEF
1c7a: 32 66           LEAS   $6,S
1c7c: 32 65           LEAS   $5,S
1c7e: 39              RTS
1c7f: fc 5c d7        LDD    $5CD7
1c82: 17 a0 cb        LBSR   $BD50
1c85: f6 23 be        LDB    $23BE
1c88: f1 3b 81        CMPB   $3B81
1c8b: 17 a1 28        LBSR   $BDB6
1c8e: c1 00           CMPB   #$00
1c90: 10 26 00 03     LBNE   $1C97
1c94: 16 00 32        LBRA   $1CC9
1c97: ce 00 00        LDU    #$0000
1c9a: 34 40           PSHS   U
1c9c: 17 f8 47        LBSR   $14E6
1c9f: 32 62           LEAS   $2,S
1ca1: ce 00 00        LDU    #$0000
1ca4: 34 40           PSHS   U
1ca6: 17 fb 08        LBSR   $17B1
1ca9: 32 62           LEAS   $2,S
1cab: ce 00 00        LDU    #$0000
1cae: 34 40           PSHS   U
1cb0: 17 fb a1        LBSR   $1854
1cb3: 32 62           LEAS   $2,S
1cb5: ce 00 00        LDU    #$0000
1cb8: 34 40           PSHS   U
1cba: 17 fc f6        LBSR   $19B3
1cbd: 32 62           LEAS   $2,S
1cbf: ce 00 00        LDU    #$0000
1cc2: 34 40           PSHS   U
1cc4: 17 fd 20        LBSR   $19E7
1cc7: 32 62           LEAS   $2,S
1cc9: 32 62           LEAS   $2,S
1ccb: 39              RTS
1ccc: 00 07           NEG    <$07
1cce: 41              NEGA
1ccf: 00 42           NEG    <$42
1cd1: 00 43           NEG    <$43
1cd3: 00 44           NEG    <$44
1cd5: 00 02           NEG    <$02
1cd7: 00 00           NEG    <$00
1cd9: 01 00           NEG    <$00
1cdb: 00 01           NEG    <$01
1cdd: a9 00           ADCA   $0,X
1cdf: 01 00           NEG    <$00
1ce1: 00 00           NEG    <$00
1ce3: 23 00           BLS    $1CE5
1ce5: 05 00           LSR    <$00
1ce7: 03 fc           COM    <$FC
1ce9: 63 cf           COM    ,W++
1ceb: 17 a0 62        LBSR   $BD50
1cee: f6 3b 84        LDB    $3B84
1cf1: c1 00           CMPB   #$00
1cf3: 10 27 00 12     LBEQ   $1D09
1cf7: ce 00 00        LDU    #$0000
1cfa: 34 40           PSHS   U
1cfc: 17 6b 86        LBSR   $8885
1cff: 32 62           LEAS   $2,S
1d01: 7f 3b 84        CLR    $3B84
1d04: be 3b 82        LDX    $3B82
1d07: ad 84           JSR    ,X
1d09: 32 62           LEAS   $2,S
1d0b: 39              RTS
1d0c: fc 63 d0        LDD    $63D0
1d0f: 17 a0 3e        LBSR   $BD50
1d12: be 22 17        LDX    $2217
1d15: 16 01 06        LBRA   $1E1E
1d18: ce 00 00        LDU    #$0000
1d1b: 34 40           PSHS   U
1d1d: 17 66 f8        LBSR   $8418
1d20: 32 62           LEAS   $2,S
1d22: 5f              CLRB
1d23: 4f              CLRA
1d24: fd 22 15        STD    $2215
1d27: ce 00 00        LDU    #$0000
1d2a: 34 40           PSHS   U
1d2c: 8d ba           BSR    $1CE8
1d2e: 32 62           LEAS   $2,S
1d30: 16 06 99        LBRA   $23CC
1d33: 5f              CLRB
1d34: 4f              CLRA
1d35: fd 22 15        STD    $2215
1d38: ce 00 00        LDU    #$0000
1d3b: 34 40           PSHS   U
1d3d: 8d a9           BSR    $1CE8
1d3f: 32 62           LEAS   $2,S
1d41: ce 00 00        LDU    #$0000
1d44: 34 40           PSHS   U
1d46: 17 f4 04        LBSR   $114D
1d49: 32 62           LEAS   $2,S
1d4b: 16 06 7e        LBRA   $23CC
1d4e: 5f              CLRB
1d4f: 4f              CLRA
1d50: fd 22 15        STD    $2215
1d53: ce 00 00        LDU    #$0000
1d56: 34 40           PSHS   U
1d58: 8d 8e           BSR    $1CE8
1d5a: 32 62           LEAS   $2,S
1d5c: ce 00 00        LDU    #$0000
1d5f: 34 40           PSHS   U
1d61: 17 2c cb        LBSR   $4A2F
1d64: 32 62           LEAS   $2,S
1d66: 16 06 63        LBRA   $23CC
1d69: f6 3f fc        LDB    $3FFC
1d6c: c4 02           ANDB   #$02
1d6e: 10 27 00 11     LBEQ   $1D83
1d72: f6 3f fc        LDB    $3FFC
1d75: c4 01           ANDB   #$01
1d77: 4f              CLRA
1d78: 10 83 00 00     CMPD   #$0000
1d7c: 10 26 00 03     LBNE   $1D83
1d80: 16 00 03        LBRA   $1D86
1d83: 16 00 2d        LBRA   $1DB3
1d86: be 22 17        LDX    $2217
1d89: 8c 00 17        CMPX   #$0017
1d8c: 10 26 00 12     LBNE   $1DA2
1d90: f6 26 8e        LDB    $268E
1d93: f1 23 b2        CMPB   $23B2
1d96: 10 26 00 05     LBNE   $1D9F
1d9a: c6 04           LDB    #$04
1d9c: f7 26 8e        STB    $268E
1d9f: 16 00 11        LBRA   $1DB3
1da2: f6 26 8e        LDB    $268E
1da5: c1 05           CMPB   #$05
1da7: 10 26 00 08     LBNE   $1DB3
1dab: f6 23 b2        LDB    $23B2
1dae: cb 01           ADDB   #$01
1db0: f7 26 8e        STB    $268E
1db3: ce 00 00        LDU    #$0000
1db6: 34 40           PSHS   U
1db8: 17 ff 2d        LBSR   $1CE8
1dbb: 32 62           LEAS   $2,S
1dbd: ce 00 00        LDU    #$0000
1dc0: 34 40           PSHS   U
1dc2: 17 2c 6a        LBSR   $4A2F
1dc5: 32 62           LEAS   $2,S
1dc7: 5f              CLRB
1dc8: 4f              CLRA
1dc9: fd 22 15        STD    $2215
1dcc: ce 00 00        LDU    #$0000
1dcf: 34 40           PSHS   U
1dd1: 17 f3 79        LBSR   $114D
1dd4: 32 62           LEAS   $2,S
1dd6: 16 05 f3        LBRA   $23CC
1dd9: ce 00 00        LDU    #$0000
1ddc: 34 40           PSHS   U
1dde: 17 ff 07        LBSR   $1CE8
1de1: 32 62           LEAS   $2,S
1de3: cc 00 09        LDD    #$0009
1de6: fd 22 15        STD    $2215
1de9: ce 00 21        LDU    #$0021
1dec: 10 8e 00 02     LDY    #$0002
1df0: 34 60           PSHS   U,Y
1df2: 17 95 3c        LBSR   $B331
1df5: 32 64           LEAS   $4,S
1df7: 16 05 d2        LBRA   $23CC
1dfa: ce 00 00        LDU    #$0000
1dfd: 34 40           PSHS   U
1dff: 17 0d 82        LBSR   $2B84
1e02: 32 62           LEAS   $2,S
1e04: be 22 15        LDX    $2215
1e07: 8c 00 01        CMPX   #$0001
1e0a: 10 26 00 0a     LBNE   $1E18
1e0e: ce 00 00        LDU    #$0000
1e11: 34 40           PSHS   U
1e13: 17 80 a0        LBSR   $9EB6
1e16: 32 62           LEAS   $2,S
1e18: 16 05 b1        LBRA   $23CC
1e1b: 16 00 4e        LBRA   $1E6C
1e1e: 8c 00 01        CMPX   #$0001
1e21: 10 27 ff 0e     LBEQ   $1D33
1e25: 8c 00 10        CMPX   #$0010
1e28: 10 27 fe ec     LBEQ   $1D18
1e2c: 8c 00 13        CMPX   #$0013
1e2f: 10 27 ff 1b     LBEQ   $1D4E
1e33: 8c 00 14        CMPX   #$0014
1e36: 10 27 ff 14     LBEQ   $1D4E
1e3a: 8c 00 15        CMPX   #$0015
1e3d: 10 27 ff 0d     LBEQ   $1D4E
1e41: 8c 00 16        CMPX   #$0016
1e44: 10 27 ff 06     LBEQ   $1D4E
1e48: 8c 00 17        CMPX   #$0017
1e4b: 10 27 ff 1a     LBEQ   $1D69
1e4f: 8c 00 18        CMPX   #$0018
1e52: 10 27 ff 13     LBEQ   $1D69
1e56: 8c 00 21        CMPX   #$0021
1e59: 10 27 ff 7c     LBEQ   $1DD9
1e5d: 8c 00 23        CMPX   #$0023
1e60: 27 98           BEQ    $1DFA
1e62: 8c 00 3c        CMPX   #$003C
1e65: 10 27 fe b9     LBEQ   $1D22
1e69: 16 00 00        LBRA   $1E6C
1e6c: fc 22 04        LDD    $2204
1e6f: 84 00           ANDA   #$00
1e71: c4 08           ANDB   #$08
1e73: 10 83 00 00     CMPD   #$0000
1e77: 10 26 00 0c     LBNE   $1E87
1e7b: f6 26 8e        LDB    $268E
1e7e: c1 00           CMPB   #$00
1e80: 10 26 00 03     LBNE   $1E87
1e84: 16 00 03        LBRA   $1E8A
1e87: 16 00 13        LBRA   $1E9D
1e8a: c6 18           LDB    #$18
1e8c: 1d              SEX
1e8d: 1f 03           TFR    D,U
1e8f: 10 8e 00 02     LDY    #$0002
1e93: 34 60           PSHS   U,Y
1e95: 17 65 66        LBSR   $83FE
1e98: 32 64           LEAS   $4,S
1e9a: 16 05 2f        LBRA   $23CC
1e9d: fc 22 04        LDD    $2204
1ea0: 84 00           ANDA   #$00
1ea2: c4 08           ANDB   #$08
1ea4: 10 83 00 00     CMPD   #$0000
1ea8: 10 26 00 18     LBNE   $1EC4
1eac: f6 26 8e        LDB    $268E
1eaf: c1 01           CMPB   #$01
1eb1: 10 25 00 0c     LBCS   $1EC1
1eb5: f6 26 8e        LDB    $268E
1eb8: c1 04           CMPB   #$04
1eba: 10 22 00 03     LBHI   $1EC1
1ebe: 16 00 03        LBRA   $1EC4
1ec1: 16 01 8a        LBRA   $204E
1ec4: be 22 17        LDX    $2217
1ec7: 16 01 63        LBRA   $202D
1eca: f6 23 be        LDB    $23BE
1ecd: c1 00           CMPB   #$00
1ecf: 10 26 00 21     LBNE   $1EF4
1ed3: fc 22 02        LDD    $2202
1ed6: 84 01           ANDA   #$01
1ed8: c4 00           ANDB   #$00
1eda: 10 83 00 00     CMPD   #$0000
1ede: 10 27 00 12     LBEQ   $1EF4
1ee2: fc 22 04        LDD    $2204
1ee5: 84 00           ANDA   #$00
1ee7: c4 08           ANDB   #$08
1ee9: 10 83 00 00     CMPD   #$0000
1eed: 10 26 00 03     LBNE   $1EF4
1ef1: 16 00 03        LBRA   $1EF7
1ef4: 16 00 03        LBRA   $1EFA
1ef7: 16 04 d2        LBRA   $23CC
1efa: cc 00 01        LDD    #$0001
1efd: fd 22 15        STD    $2215
1f00: ce 00 00        LDU    #$0000
1f03: 34 40           PSHS   U
1f05: 17 fd e0        LBSR   $1CE8
1f08: 32 62           LEAS   $2,S
1f0a: ce 00 00        LDU    #$0000
1f0d: 10 8e 00 02     LDY    #$0002
1f11: 34 60           PSHS   U,Y
1f13: be 3b 85        LDX    $3B85
1f16: ad 84           JSR    ,X
1f18: 32 64           LEAS   $4,S
1f1a: 16 04 af        LBRA   $23CC
1f1d: f6 23 be        LDB    $23BE
1f20: c1 00           CMPB   #$00
1f22: 10 26 00 21     LBNE   $1F47
1f26: fc 22 02        LDD    $2202
1f29: 84 00           ANDA   #$00
1f2b: c4 40           ANDB   #$40
1f2d: 10 83 00 00     CMPD   #$0000
1f31: 10 27 00 12     LBEQ   $1F47
1f35: fc 22 04        LDD    $2204
1f38: 84 00           ANDA   #$00
1f3a: c4 08           ANDB   #$08
1f3c: 10 83 00 00     CMPD   #$0000
1f40: 10 26 00 03     LBNE   $1F47
1f44: 16 00 03        LBRA   $1F4A
1f47: 16 00 03        LBRA   $1F4D
1f4a: 16 04 7f        LBRA   $23CC
1f4d: cc 00 02        LDD    #$0002
1f50: fd 22 15        STD    $2215
1f53: ce 00 00        LDU    #$0000
1f56: 34 40           PSHS   U
1f58: 17 fd 8d        LBSR   $1CE8
1f5b: 32 62           LEAS   $2,S
1f5d: ce 00 01        LDU    #$0001
1f60: 10 8e 00 02     LDY    #$0002
1f64: 34 60           PSHS   U,Y
1f66: be 3b 85        LDX    $3B85
1f69: ad 84           JSR    ,X
1f6b: 32 64           LEAS   $4,S
1f6d: 16 04 5c        LBRA   $23CC
1f70: f6 23 be        LDB    $23BE
1f73: c1 00           CMPB   #$00
1f75: 10 26 00 21     LBNE   $1F9A
1f79: fc 22 02        LDD    $2202
1f7c: 84 00           ANDA   #$00
1f7e: c4 80           ANDB   #$80
1f80: 10 83 00 00     CMPD   #$0000
1f84: 10 27 00 12     LBEQ   $1F9A
1f88: fc 22 04        LDD    $2204
1f8b: 84 00           ANDA   #$00
1f8d: c4 08           ANDB   #$08
1f8f: 10 83 00 00     CMPD   #$0000
1f93: 10 26 00 03     LBNE   $1F9A
1f97: 16 00 03        LBRA   $1F9D
1f9a: 16 00 03        LBRA   $1FA0
1f9d: 16 04 2c        LBRA   $23CC
1fa0: cc 00 03        LDD    #$0003
1fa3: fd 22 15        STD    $2215
1fa6: ce 00 00        LDU    #$0000
1fa9: 34 40           PSHS   U
1fab: 17 fd 3a        LBSR   $1CE8
1fae: 32 62           LEAS   $2,S
1fb0: ce 00 02        LDU    #$0002
1fb3: 10 8e 00 02     LDY    #$0002
1fb7: 34 60           PSHS   U,Y
1fb9: be 3b 85        LDX    $3B85
1fbc: ad 84           JSR    ,X
1fbe: 32 64           LEAS   $4,S
1fc0: 16 04 09        LBRA   $23CC
1fc3: cc 00 04        LDD    #$0004
1fc6: fd 22 15        STD    $2215
1fc9: ce 00 00        LDU    #$0000
1fcc: 34 40           PSHS   U
1fce: 17 fd 17        LBSR   $1CE8
1fd1: 32 62           LEAS   $2,S
1fd3: ce 00 03        LDU    #$0003
1fd6: 10 8e 00 02     LDY    #$0002
1fda: 34 60           PSHS   U,Y
1fdc: be 3b 85        LDX    $3B85
1fdf: ad 84           JSR    ,X
1fe1: 32 64           LEAS   $4,S
1fe3: 16 03 e6        LBRA   $23CC
1fe6: f6 3f fc        LDB    $3FFC
1fe9: c4 01           ANDB   #$01
1feb: 4f              CLRA
1fec: 10 83 00 00     CMPD   #$0000
1ff0: 10 26 00 13     LBNE   $2007
1ff4: c6 1f           LDB    #$1F
1ff6: 1d              SEX
1ff7: 1f 03           TFR    D,U
1ff9: 10 8e 00 02     LDY    #$0002
1ffd: 34 60           PSHS   U,Y
1fff: 17 63 fc        LBSR   $83FE
2002: 32 64           LEAS   $4,S
2004: 16 03 c5        LBRA   $23CC
2007: ce 00 00        LDU    #$0000
200a: 34 40           PSHS   U
200c: 17 fc d9        LBSR   $1CE8
200f: 32 62           LEAS   $2,S
2011: cc 00 05        LDD    #$0005
2014: fd 22 15        STD    $2215
2017: ce 00 04        LDU    #$0004
201a: 10 8e 00 02     LDY    #$0002
201e: 34 60           PSHS   U,Y
2020: be 3b 85        LDX    $3B85
2023: ad 84           JSR    ,X
2025: 32 64           LEAS   $4,S
2027: 16 03 a2        LBRA   $23CC
202a: 16 00 21        LBRA   $204E
202d: 8c 00 1d        CMPX   #$001D
2030: 10 2e 00 1a     LBGT   $204E
2034: 1f 10           TFR    X,D
2036: 83 00 19        SUBD   #$0019
2039: 10 2d 00 11     LBLT   $204E
203d: 8e 60 44        LDX    #$6044
2040: 58              ASLB
2041: 49              ROLA
2042: 6e 9b           JMP    [D,X]
2044: 5e              XCLRB
2045: ca 5f           ORB    #$5F
2047: 1d              SEX
2048: 5f              CLRB
2049: c3 5f 70        ADDD   #$5F70
204c: 5f              CLRB
204d: e6 f6           LDB    [A,S]
204f: 3f              SWI
2050: fc c4 02        LDD    $C402
2053: 10 27 00 1e     LBEQ   $2075
2057: fc 22 04        LDD    $2204
205a: 84 00           ANDA   #$00
205c: c4 08           ANDB   #$08
205e: 10 83 00 00     CMPD   #$0000
2062: 10 26 00 0c     LBNE   $2072
2066: f6 26 8e        LDB    $268E
2069: c1 05           CMPB   #$05
206b: 10 27 00 03     LBEQ   $2072
206f: 16 00 03        LBRA   $2075
2072: 16 00 03        LBRA   $2078
2075: 16 01 2b        LBRA   $21A3
2078: be 22 17        LDX    $2217
207b: 16 00 e3        LBRA   $2161
207e: cc 00 0c        LDD    #$000C
2081: fd 22 15        STD    $2215
2084: ce 00 00        LDU    #$0000
2087: 34 40           PSHS   U
2089: 17 fc 5c        LBSR   $1CE8
208c: 32 62           LEAS   $2,S
208e: ce 00 06        LDU    #$0006
2091: 10 8e 00 02     LDY    #$0002
2095: 34 60           PSHS   U,Y
2097: be 3b 85        LDX    $3B85
209a: ad 84           JSR    ,X
209c: 32 64           LEAS   $4,S
209e: 16 03 2b        LBRA   $23CC
20a1: cc 00 0d        LDD    #$000D
20a4: fd 22 15        STD    $2215
20a7: ce 00 00        LDU    #$0000
20aa: 34 40           PSHS   U
20ac: 17 fc 39        LBSR   $1CE8
20af: 32 62           LEAS   $2,S
20b1: ce 00 07        LDU    #$0007
20b4: 10 8e 00 02     LDY    #$0002
20b8: 34 60           PSHS   U,Y
20ba: be 3b 85        LDX    $3B85
20bd: ad 84           JSR    ,X
20bf: 32 64           LEAS   $4,S
20c1: 16 03 08        LBRA   $23CC
20c4: cc 00 0e        LDD    #$000E
20c7: fd 22 15        STD    $2215
20ca: ce 00 00        LDU    #$0000
20cd: 34 40           PSHS   U
20cf: 17 fc 16        LBSR   $1CE8
20d2: 32 62           LEAS   $2,S
20d4: ce 00 08        LDU    #$0008
20d7: 10 8e 00 02     LDY    #$0002
20db: 34 60           PSHS   U,Y
20dd: be 3b 85        LDX    $3B85
20e0: ad 84           JSR    ,X
20e2: 32 64           LEAS   $4,S
20e4: 16 02 e5        LBRA   $23CC
20e7: cc 00 12        LDD    #$0012
20ea: fd 22 15        STD    $2215
20ed: ce 00 0a        LDU    #$000A
20f0: 10 8e 00 02     LDY    #$0002
20f4: 34 60           PSHS   U,Y
20f6: be 3b 85        LDX    $3B85
20f9: ad 84           JSR    ,X
20fb: 32 64           LEAS   $4,S
20fd: 16 02 cc        LBRA   $23CC
2100: ce 00 00        LDU    #$0000
2103: 34 40           PSHS   U
2105: 17 e8 00        LBSR   $0908
2108: 32 62           LEAS   $2,S
210a: 16 02 bf        LBRA   $23CC
210d: cc 01 e0        LDD    #$01E0
2110: b4 22 02        ANDA   $2202
2113: f4 22 03        ANDB   $2203
2116: ed 63           STD    $3,S
2118: ae 63           LDX    $3,S
211a: c6 fb           LDB    #$FB
211c: 17 9e 85        LBSR   $BFA4
211f: e7 62           STB    $2,S
2121: fc 22 04        LDD    $2204
2124: 84 20           ANDA   #$20
2126: c4 00           ANDB   #$00
2128: 10 83 00 00     CMPD   #$0000
212c: 10 27 00 06     LBEQ   $2136
2130: e6 62           LDB    $2,S
2132: ca 10           ORB    #$10
2134: e7 62           STB    $2,S
2136: ce 22 85        LDU    #$2285
2139: e6 62           LDB    $2,S
213b: 4f              CLRA
213c: 1f 02           TFR    D,Y
213e: 8e 00 04        LDX    #$0004
2141: 34 70           PSHS   U,Y,X
2143: 17 68 8b        LBSR   $89D1
2146: 32 66           LEAS   $6,S
2148: c6 03           LDB    #$03
214a: 1d              SEX
214b: 1f 03           TFR    D,U
214d: 10 8e 22 85     LDY    #$2285
2151: 8e 00 04        LDX    #$0004
2154: 34 70           PSHS   U,Y,X
2156: 17 3e a5        LBSR   $5FFE
2159: 32 66           LEAS   $6,S
215b: 16 02 6e        LBRA   $23CC
215e: 16 00 42        LBRA   $21A3
2161: 8c 00 19        CMPX   #$0019
2164: 10 27 ff 16     LBEQ   $207E
2168: 8c 00 1a        CMPX   #$001A
216b: 10 27 ff 32     LBEQ   $20A1
216f: 8c 00 1c        CMPX   #$001C
2172: 10 27 ff 4e     LBEQ   $20C4
2176: 8c 00 27        CMPX   #$0027
2179: 10 27 ff 6a     LBEQ   $20E7
217d: 8c 00 28        CMPX   #$0028
2180: 10 27 fe fa     LBEQ   $207E
2184: 8c 00 29        CMPX   #$0029
2187: 10 27 ff 16     LBEQ   $20A1
218b: 8c 00 2a        CMPX   #$002A
218e: 10 27 ff 32     LBEQ   $20C4
2192: 8c 00 2b        CMPX   #$002B
2195: 10 27 ff 67     LBEQ   $2100
2199: 8c 00 36        CMPX   #$0036
219c: 10 27 ff 6d     LBEQ   $210D
21a0: 16 00 00        LBRA   $21A3
21a3: be 22 17        LDX    $2217
21a6: 16 02 07        LBRA   $23B0
21a9: be 22 15        LDX    $2215
21ac: 16 01 2a        LBRA   $22D9
21af: cc 00 06        LDD    #$0006
21b2: fd 22 15        STD    $2215
21b5: ce 00 00        LDU    #$0000
21b8: 34 40           PSHS   U
21ba: 17 f8 5e        LBSR   $1A1B
21bd: 32 62           LEAS   $2,S
21bf: c6 01           LDB    #$01
21c1: f7 3b 84        STB    $3B84
21c4: cc 54 e6        LDD    #$54E6
21c7: fd 3b 82        STD    $3B82
21ca: ce 00 00        LDU    #$0000
21cd: 10 8e 00 02     LDY    #$0002
21d1: 34 60           PSHS   U,Y
21d3: be 3b 85        LDX    $3B85
21d6: ad 84           JSR    ,X
21d8: 32 64           LEAS   $4,S
21da: 16 01 31        LBRA   $230E
21dd: cc 00 07        LDD    #$0007
21e0: fd 22 15        STD    $2215
21e3: ce 00 00        LDU    #$0000
21e6: 34 40           PSHS   U
21e8: 17 f9 28        LBSR   $1B13
21eb: 32 62           LEAS   $2,S
21ed: c6 01           LDB    #$01
21ef: f7 3b 84        STB    $3B84
21f2: cc 57 b1        LDD    #$57B1
21f5: fd 3b 82        STD    $3B82
21f8: ce 00 01        LDU    #$0001
21fb: 10 8e 00 02     LDY    #$0002
21ff: 34 60           PSHS   U,Y
2201: be 3b 85        LDX    $3B85
2204: ad 84           JSR    ,X
2206: 32 64           LEAS   $4,S
2208: 16 01 03        LBRA   $230E
220b: cc 00 08        LDD    #$0008
220e: fd 22 15        STD    $2215
2211: ce 00 00        LDU    #$0000
2214: 34 40           PSHS   U
2216: 17 f9 7f        LBSR   $1B98
2219: 32 62           LEAS   $2,S
221b: c6 01           LDB    #$01
221d: f7 3b 84        STB    $3B84
2220: cc 58 54        LDD    #$5854
2223: fd 3b 82        STD    $3B82
2226: ce 00 02        LDU    #$0002
2229: 10 8e 00 02     LDY    #$0002
222d: 34 60           PSHS   U,Y
222f: be 3b 85        LDX    $3B85
2232: ad 84           JSR    ,X
2234: 32 64           LEAS   $4,S
2236: 16 00 d5        LBRA   $230E
2239: cc 00 0f        LDD    #$000F
223c: fd 22 15        STD    $2215
223f: ce 00 00        LDU    #$0000
2242: 34 40           PSHS   U
2244: 17 e2 1a        LBSR   $0461
2247: 32 62           LEAS   $2,S
2249: c6 01           LDB    #$01
224b: f7 3b 84        STB    $3B84
224e: cc 44 61        LDD    #$4461
2251: fd 3b 82        STD    $3B82
2254: ce 00 06        LDU    #$0006
2257: 10 8e 00 02     LDY    #$0002
225b: 34 60           PSHS   U,Y
225d: be 3b 85        LDX    $3B85
2260: ad 84           JSR    ,X
2262: 32 64           LEAS   $4,S
2264: 16 00 a7        LBRA   $230E
2267: cc 00 10        LDD    #$0010
226a: fd 22 15        STD    $2215
226d: ce 00 00        LDU    #$0000
2270: 34 40           PSHS   U
2272: 17 e3 04        LBSR   $0579
2275: 32 62           LEAS   $2,S
2277: c6 01           LDB    #$01
2279: f7 3b 84        STB    $3B84
227c: cc 45 79        LDD    #$4579
227f: fd 3b 82        STD    $3B82
2282: ce 00 07        LDU    #$0007
2285: 10 8e 00 02     LDY    #$0002
2289: 34 60           PSHS   U,Y
228b: be 3b 85        LDX    $3B85
228e: ad 84           JSR    ,X
2290: 32 64           LEAS   $4,S
2292: 16 00 79        LBRA   $230E
2295: cc 00 11        LDD    #$0011
2298: fd 22 15        STD    $2215
229b: ce 00 00        LDU    #$0000
229e: 34 40           PSHS   U
22a0: 17 e3 eb        LBSR   $068E
22a3: 32 62           LEAS   $2,S
22a5: c6 01           LDB    #$01
22a7: f7 3b 84        STB    $3B84
22aa: cc 46 8e        LDD    #$468E
22ad: fd 3b 82        STD    $3B82
22b0: ce 00 08        LDU    #$0008
22b3: 10 8e 00 02     LDY    #$0002
22b7: 34 60           PSHS   U,Y
22b9: be 3b 85        LDX    $3B85
22bc: ad 84           JSR    ,X
22be: 32 64           LEAS   $4,S
22c0: 16 00 4b        LBRA   $230E
22c3: c6 14           LDB    #$14
22c5: 1d              SEX
22c6: 1f 03           TFR    D,U
22c8: 10 8e 00 02     LDY    #$0002
22cc: 34 60           PSHS   U,Y
22ce: 17 61 2d        LBSR   $83FE
22d1: 32 64           LEAS   $4,S
22d3: 16 00 f6        LBRA   $23CC
22d6: 16 00 35        LBRA   $230E
22d9: 8c 00 11        CMPX   #$0011
22dc: 2e e5           BGT    $22C3
22de: 1f 10           TFR    X,D
22e0: 83 00 01        SUBD   #$0001
22e3: 2d de           BLT    $22C3
22e5: 8e 62 ec        LDX    #$62EC
22e8: 58              ASLB
22e9: 49              ROLA
22ea: 6e 9b           JMP    [D,X]
22ec: 61 af 61 dd     NEG    $61DD,W
22f0: 62 0b           XNC    $B,X
22f2: 62 c3           XNC    ,--U
22f4: 62 c3           XNC    ,--U
22f6: 61 b5           NEG    [B,Y]
22f8: 61 e3           NEG    ,--S
22fa: 62 11           XNC    -$F,X
22fc: 62 c3           XNC    ,--U
22fe: 62 c3           XNC    ,--U
2300: 62 c3           XNC    ,--U
2302: 62 39           XNC    -$7,Y
2304: 62 67           XNC    $7,S
2306: 62 95           XNC    [B,X]
2308: 62 3f           XNC    -$1,Y
230a: 62 6d           XNC    $D,S
230c: 62 9b           XNC    [D,X]
230e: 16 00 bb        LBRA   $23CC
2311: c6 01           LDB    #$01
2313: 1d              SEX
2314: 1f 03           TFR    D,U
2316: 10 8e 00 02     LDY    #$0002
231a: 34 60           PSHS   U,Y
231c: 17 0e 84        LBSR   $31A3
231f: 32 64           LEAS   $4,S
2321: be 22 15        LDX    $2215
2324: 8c 00 01        CMPX   #$0001
2327: 10 26 00 0a     LBNE   $2335
232b: ce 00 00        LDU    #$0000
232e: 34 40           PSHS   U
2330: 17 7b 83        LBSR   $9EB6
2333: 32 62           LEAS   $2,S
2335: 16 00 94        LBRA   $23CC
2338: 5f              CLRB
2339: 1d              SEX
233a: 1f 03           TFR    D,U
233c: 10 8e 00 02     LDY    #$0002
2340: 34 60           PSHS   U,Y
2342: 17 0e 5e        LBSR   $31A3
2345: 32 64           LEAS   $4,S
2347: be 22 15        LDX    $2215
234a: 8c 00 01        CMPX   #$0001
234d: 10 26 00 0a     LBNE   $235B
2351: ce 00 00        LDU    #$0000
2354: 34 40           PSHS   U
2356: 17 7b 5d        LBSR   $9EB6
2359: 32 62           LEAS   $2,S
235b: 16 00 6e        LBRA   $23CC
235e: cc 7b 7a        LDD    #$7B7A
2361: 1f 03           TFR    D,U
2363: c6 03           LDB    #$03
2365: 1d              SEX
2366: 1f 02           TFR    D,Y
2368: 8e 00 04        LDX    #$0004
236b: 34 70           PSHS   U,Y,X
236d: 17 77 bb        LBSR   $9B2B
2370: 32 66           LEAS   $6,S
2372: 16 00 57        LBRA   $23CC
2375: fc 22 04        LDD    $2204
2378: 84 00           ANDA   #$00
237a: c4 08           ANDB   #$08
237c: 10 83 00 00     CMPD   #$0000
2380: 10 27 00 16     LBEQ   $239A
2384: c6 18           LDB    #$18
2386: 1d              SEX
2387: 1f 03           TFR    D,U
2389: 5f              CLRB
238a: 1d              SEX
238b: 1f 02           TFR    D,Y
238d: 8e 00 04        LDX    #$0004
2390: 34 70           PSHS   U,Y,X
2392: 17 3a 3e        LBSR   $5DD3
2395: 32 66           LEAS   $6,S
2397: 16 00 10        LBRA   $23AA
239a: c6 18           LDB    #$18
239c: 1d              SEX
239d: 1f 03           TFR    D,U
239f: 10 8e 00 02     LDY    #$0002
23a3: 34 60           PSHS   U,Y
23a5: 17 60 56        LBSR   $83FE
23a8: 32 64           LEAS   $4,S
23aa: 16 00 1f        LBRA   $23CC
23ad: 16 00 1c        LBRA   $23CC
23b0: 8c 00 1e        CMPX   #$001E
23b3: 10 27 fd f2     LBEQ   $21A9
23b7: 8c 00 1f        CMPX   #$001F
23ba: 10 27 ff 7a     LBEQ   $2338
23be: 8c 00 20        CMPX   #$0020
23c1: 10 27 ff 4c     LBEQ   $2311
23c5: 8c 00 25        CMPX   #$0025
23c8: 27 94           BEQ    $235E
23ca: 20 a9           BRA    $2375
23cc: 32 65           LEAS   $5,S
23ce: 39              RTS
23cf: 00 00           NEG    <$00
23d1: 03 fc           COM    <$FC
23d3: 6b 34           XDEC   -$C,Y
23d5: 17 99 78        LBSR   $BD50
23d8: 6f 62           CLR    $2,S
23da: ce 24 f5        LDU    #$24F5
23dd: 10 ae e9 00 11  LDY    $0011,S
23e2: 34 60           PSHS   U,Y
23e4: 86 01           LDA    #$01
23e6: 8e 6b 2e        LDX    #$6B2E
23e9: 17 98 fe        LBSR   $BCEA
23ec: 30 88 21        LEAX   $21,X
23ef: ae 84           LDX    ,X
23f1: af 63           STX    $3,S
23f3: ce 24 f5        LDU    #$24F5
23f6: 10 ae e9 00 11  LDY    $0011,S
23fb: 34 60           PSHS   U,Y
23fd: 86 01           LDA    #$01
23ff: 8e 6b 2e        LDX    #$6B2E
2402: 17 98 e5        LBSR   $BCEA
2405: 30 88 1f        LEAX   $1F,X
2408: ae 84           LDX    ,X
240a: af 65           STX    $5,S
240c: cc ea 55        LDD    #$EA55
240f: ed 6a           STD    $A,S
2411: c6 7b           LDB    #$7B
2413: e7 62           STB    $2,S
2415: ae 63           LDX    $3,S
2417: 8c 00 0b        CMPX   #$000B
241a: 10 26 00 0c     LBNE   $242A
241e: cc ea 5f        LDD    #$EA5F
2421: ed 6a           STD    $A,S
2423: c6 6c           LDB    #$6C
2425: e7 62           STB    $2,S
2427: 16 00 27        LBRA   $2451
242a: ae 65           LDX    $5,S
242c: 8c 00 02        CMPX   #$0002
242f: 10 27 00 15     LBEQ   $2448
2433: ae 65           LDX    $5,S
2435: 8c 00 03        CMPX   #$0003
2438: 10 27 00 0c     LBEQ   $2448
243c: ae 65           LDX    $5,S
243e: 8c 00 06        CMPX   #$0006
2441: 10 27 00 03     LBEQ   $2448
2445: 16 00 09        LBRA   $2451
2448: cc ea 5f        LDD    #$EA5F
244b: ed 6a           STD    $A,S
244d: c6 6d           LDB    #$6D
244f: e7 62           STB    $2,S
2451: 33 67           LEAU   $7,S
2453: 10 ae e9 00 13  LDY    $0013,S
2458: ae 6a           LDX    $A,S
245a: cc 00 06        LDD    #$0006
245d: 34 76           PSHS   U,Y,X,D
245f: 17 6f 64        LBSR   $93C6
2462: 32 68           LEAS   $8,S
2464: c1 00           CMPB   #$00
2466: 10 27 00 0a     LBEQ   $2474
246a: e6 62           LDB    $2,S
246c: e7 6c           STB    $C,S
246e: 16 00 05        LBRA   $2476
2471: 16 00 02        LBRA   $2476
2474: 6f 6c           CLR    $C,S
2476: e6 6c           LDB    $C,S
2478: 32 6d           LEAS   $D,S
247a: 39              RTS
247b: fc 6b 36        LDD    $6B36
247e: 17 98 cf        LBSR   $BD50
2481: ce 22 1c        LDU    #$221C
2484: f6 23 be        LDB    $23BE
2487: 4f              CLRA
2488: 1f 02           TFR    D,Y
248a: 8e 00 04        LDX    #$0004
248d: 34 70           PSHS   U,Y,X
248f: 17 ff 40        LBSR   $23D2
2492: 32 66           LEAS   $6,S
2494: e7 62           STB    $2,S
2496: e6 62           LDB    $2,S
2498: c1 00           CMPB   #$00
249a: 10 27 00 13     LBEQ   $24B1
249e: e6 62           LDB    $2,S
24a0: 4f              CLRA
24a1: 1f 03           TFR    D,U
24a3: 10 8e 00 02     LDY    #$0002
24a7: 34 60           PSHS   U,Y
24a9: 17 5f 52        LBSR   $83FE
24ac: 32 64           LEAS   $4,S
24ae: 16 00 93        LBRA   $2544
24b1: be 23 bf        LDX    $23BF
24b4: 30 88 21        LEAX   $21,X
24b7: ae 84           LDX    ,X
24b9: af 64           STX    $4,S
24bb: ee 64           LDU    $4,S
24bd: 10 8e 00 02     LDY    #$0002
24c1: 34 60           PSHS   U,Y
24c3: 17 13 13        LBSR   $37D9
24c6: 32 64           LEAS   $4,S
24c8: e7 63           STB    $3,S
24ca: ce 22 1c        LDU    #$221C
24cd: 10 be 23 bf     LDY    $23BF
24d1: 8e 00 04        LDX    #$0004
24d4: 34 70           PSHS   U,Y,X
24d6: 17 6e a4        LBSR   $937D
24d9: 32 66           LEAS   $6,S
24db: e6 63           LDB    $3,S
24dd: c1 00           CMPB   #$00
24df: 10 27 00 16     LBEQ   $24F9
24e3: fe 23 bf        LDU    $23BF
24e6: f6 23 be        LDB    $23BE
24e9: 4f              CLRA
24ea: 1f 02           TFR    D,Y
24ec: 8e 00 04        LDX    #$0004
24ef: 34 70           PSHS   U,Y,X
24f1: 17 7e 25        LBSR   $A319
24f4: 32 66           LEAS   $6,S
24f6: 16 00 13        LBRA   $250C
24f9: fe 23 bf        LDU    $23BF
24fc: f6 23 be        LDB    $23BE
24ff: 4f              CLRA
2500: 1f 02           TFR    D,Y
2502: 8e 00 04        LDX    #$0004
2505: 34 70           PSHS   U,Y,X
2507: 17 7d b7        LBSR   $A2C1
250a: 32 66           LEAS   $6,S
250c: ee 64           LDU    $4,S
250e: 10 8e 00 02     LDY    #$0002
2512: 34 60           PSHS   U,Y
2514: 17 92 d5        LBSR   $B7EC
2517: 32 64           LEAS   $4,S
2519: e6 63           LDB    $3,S
251b: c1 00           CMPB   #$00
251d: 10 27 00 23     LBEQ   $2544
2521: f6 23 be        LDB    $23BE
2524: 4f              CLRA
2525: 1f 03           TFR    D,U
2527: 10 8e 00 02     LDY    #$0002
252b: 34 60           PSHS   U,Y
252d: 17 83 77        LBSR   $A8A7
2530: 32 64           LEAS   $4,S
2532: 1f 03           TFR    D,U
2534: f6 23 be        LDB    $23BE
2537: 4f              CLRA
2538: 1f 02           TFR    D,Y
253a: 8e 00 04        LDX    #$0004
253d: 34 70           PSHS   U,Y,X
253f: 17 80 7d        LBSR   $A5BF
2542: 32 66           LEAS   $6,S
2544: 32 66           LEAS   $6,S
2546: 39              RTS
2547: fc 6b 38        LDD    $6B38
254a: 17 98 03        LBSR   $BD50
254d: ce 24 f5        LDU    #$24F5
2550: f6 23 be        LDB    $23BE
2553: 4f              CLRA
2554: 1f 02           TFR    D,Y
2556: 34 60           PSHS   U,Y
2558: 86 01           LDA    #$01
255a: 8e 6b 2e        LDX    #$6B2E
255d: 17 97 8a        LBSR   $BCEA
2560: 30 0d           LEAX   $D,X
2562: ae 84           LDX    ,X
2564: af 66           STX    $6,S
2566: ae 66           LDX    $6,S
2568: 8c 00 03        CMPX   #$0003
256b: 10 26 00 06     LBNE   $2575
256f: cc ea 68        LDD    #$EA68
2572: fd 23 b7        STD    $23B7
2575: ae 66           LDX    $6,S
2577: 8c 00 04        CMPX   #$0004
257a: 10 26 00 06     LBNE   $2584
257e: cc ea 6b        LDD    #$EA6B
2581: fd 23 b7        STD    $23B7
2584: f6 23 be        LDB    $23BE
2587: c1 00           CMPB   #$00
2589: 10 26 00 12     LBNE   $259F
258d: fc 22 02        LDD    $2202
2590: 84 00           ANDA   #$00
2592: c4 40           ANDB   #$40
2594: 10 83 00 00     CMPD   #$0000
2598: 10 27 00 03     LBEQ   $259F
259c: 16 00 03        LBRA   $25A2
259f: 16 00 13        LBRA   $25B5
25a2: ce 22 1c        LDU    #$221C
25a5: 10 8e 00 02     LDY    #$0002
25a9: 34 60           PSHS   U,Y
25ab: 17 52 ff        LBSR   $78AD
25ae: 32 64           LEAS   $4,S
25b0: e7 62           STB    $2,S
25b2: 16 00 15        LBRA   $25CA
25b5: ce 22 1c        LDU    #$221C
25b8: f6 23 be        LDB    $23BE
25bb: 4f              CLRA
25bc: 1f 02           TFR    D,Y
25be: 8e 00 04        LDX    #$0004
25c1: 34 70           PSHS   U,Y,X
25c3: 17 53 06        LBSR   $78CC
25c6: 32 66           LEAS   $6,S
25c8: e7 62           STB    $2,S
25ca: e6 62           LDB    $2,S
25cc: c1 00           CMPB   #$00
25ce: 10 27 00 15     LBEQ   $25E7
25d2: c6 7a           LDB    #$7A
25d4: 1d              SEX
25d5: 1f 03           TFR    D,U
25d7: 10 8e 00 02     LDY    #$0002
25db: 34 60           PSHS   U,Y
25dd: 17 5e 1e        LBSR   $83FE
25e0: 32 64           LEAS   $4,S
25e2: 6f 68           CLR    $8,S
25e4: 16 00 49        LBRA   $2630
25e7: be 23 bf        LDX    $23BF
25ea: 30 0a           LEAX   $A,X
25ec: ce 22 1c        LDU    #$221C
25ef: 1f 12           TFR    X,Y
25f1: 8e 00 04        LDX    #$0004
25f4: 34 70           PSHS   U,Y,X
25f6: 17 6d 84        LBSR   $937D
25f9: 32 66           LEAS   $6,S
25fb: be 23 bf        LDX    $23BF
25fe: 30 88 1f        LEAX   $1F,X
2601: ae 84           LDX    ,X
2603: 8c 00 04        CMPX   #$0004
2606: 10 26 00 0b     LBNE   $2615
260a: be 23 bf        LDX    $23BF
260d: 30 88 14        LEAX   $14,X
2610: f6 24 1e        LDB    $241E
2613: e7 84           STB    ,X
2615: be 23 bf        LDX    $23BF
2618: 30 0a           LEAX   $A,X
261a: 1f 13           TFR    X,U
261c: f6 23 be        LDB    $23BE
261f: 4f              CLRA
2620: 1f 02           TFR    D,Y
2622: 8e 00 04        LDX    #$0004
2625: 34 70           PSHS   U,Y,X
2627: 17 5a 3f        LBSR   $8069
262a: 32 66           LEAS   $6,S
262c: c6 01           LDB    #$01
262e: e7 68           STB    $8,S
2630: e6 68           LDB    $8,S
2632: 32 69           LEAS   $9,S
2634: 39              RTS
2635: fc 6b 38        LDD    $6B38
2638: 17 97 15        LBSR   $BD50
263b: e6 e9 00 0e     LDB    $000E,S
263f: e7 62           STB    $2,S
2641: ce 24 f5        LDU    #$24F5
2644: e6 62           LDB    $2,S
2646: 4f              CLRA
2647: 1f 02           TFR    D,Y
2649: 34 60           PSHS   U,Y
264b: 86 01           LDA    #$01
264d: 8e 6b 2e        LDX    #$6B2E
2650: 17 96 97        LBSR   $BCEA
2653: af 63           STX    $3,S
2655: ae 63           LDX    $3,S
2657: 30 88 15        LEAX   $15,X
265a: ae 84           LDX    ,X
265c: af 65           STX    $5,S
265e: fc 23 c1        LDD    $23C1
2661: 84 00           ANDA   #$00
2663: c4 08           ANDB   #$08
2665: 10 83 00 00     CMPD   #$0000
2669: 10 26 00 1e     LBNE   $268B
266d: ae 63           LDX    $3,S
266f: 30 88 21        LEAX   $21,X
2672: af 67           STX    $7,S
2674: ee f8 07        LDU    [$07,S]
2677: 10 8e 00 02     LDY    #$0002
267b: 34 60           PSHS   U,Y
267d: 17 11 59        LBSR   $37D9
2680: 32 64           LEAS   $4,S
2682: c1 00           CMPB   #$00
2684: 10 27 00 03     LBEQ   $268B
2688: 16 00 03        LBRA   $268E
268b: 16 00 10        LBRA   $269E
268e: ae 65           LDX    $5,S
2690: 8c 00 00        CMPX   #$0000
2693: 10 27 00 07     LBEQ   $269E
2697: cc 0e 10        LDD    #$0E10
269a: a3 65           SUBD   $5,S
269c: ed 65           STD    $5,S
269e: ee 65           LDU    $5,S
26a0: e6 62           LDB    $2,S
26a2: 4f              CLRA
26a3: 1f 02           TFR    D,Y
26a5: 8e 00 04        LDX    #$0004
26a8: 34 70           PSHS   U,Y,X
26aa: 17 7e b5        LBSR   $A562
26ad: 32 66           LEAS   $6,S
26af: 32 69           LEAS   $9,S
26b1: 39              RTS
26b2: fc 6b 3a        LDD    $6B3A
26b5: 17 96 98        LBSR   $BD50
26b8: be 23 bf        LDX    $23BF
26bb: 30 88 19        LEAX   $19,X
26be: ae 84           LDX    ,X
26c0: 16 00 68        LBRA   $272B
26c3: be 22 1a        LDX    $221A
26c6: bc ea 5b        CMPX   $EA5B
26c9: 10 23 00 03     LBLS   $26D0
26cd: 16 00 79        LBRA   $2749
26d0: be 23 bf        LDX    $23BF
26d3: 30 88 15        LEAX   $15,X
26d6: fc 22 1a        LDD    $221A
26d9: ed 84           STD    ,X
26db: be 23 bf        LDX    $23BF
26de: 30 88 17        LEAX   $17,X
26e1: af 62           STX    $2,S
26e3: fe 22 1a        LDU    $221A
26e6: 10 8e 00 02     LDY    #$0002
26ea: 34 60           PSHS   U,Y
26ec: 17 6b d7        LBSR   $92C6
26ef: 32 64           LEAS   $4,S
26f1: ed f8 02        STD    [$02,S]
26f4: 16 00 41        LBRA   $2738
26f7: be 22 1a        LDX    $221A
26fa: bc ea 5d        CMPX   $EA5D
26fd: 10 23 00 03     LBLS   $2704
2701: 16 00 45        LBRA   $2749
2704: be 23 bf        LDX    $23BF
2707: 30 88 17        LEAX   $17,X
270a: fc 22 1a        LDD    $221A
270d: ed 84           STD    ,X
270f: be 23 bf        LDX    $23BF
2712: 30 88 15        LEAX   $15,X
2715: af 62           STX    $2,S
2717: fe 22 1a        LDU    $221A
271a: 10 8e 00 02     LDY    #$0002
271e: 34 60           PSHS   U,Y
2720: 17 6b 86        LBSR   $92A9
2723: 32 64           LEAS   $4,S
2725: ed f8 02        STD    [$02,S]
2728: 16 00 0d        LBRA   $2738
272b: 8c 00 03        CMPX   #$0003
272e: 27 93           BEQ    $26C3
2730: 8c 00 04        CMPX   #$0004
2733: 27 c2           BEQ    $26F7
2735: 16 00 00        LBRA   $2738
2738: f6 23 be        LDB    $23BE
273b: 4f              CLRA
273c: 1f 03           TFR    D,U
273e: 10 8e 00 02     LDY    #$0002
2742: 34 60           PSHS   U,Y
2744: 17 fe ee        LBSR   $2635
2747: 32 64           LEAS   $4,S
2749: 32 64           LEAS   $4,S
274b: 39              RTS
274c: fc 6b 38        LDD    $6B38
274f: 17 95 fe        LBSR   $BD50
2752: be 23 bf        LDX    $23BF
2755: 30 88 21        LEAX   $21,X
2758: ae 84           LDX    ,X
275a: af 65           STX    $5,S
275c: be 22 1f        LDX    $221F
275f: 8c 00 02        CMPX   #$0002
2762: 10 27 00 17     LBEQ   $277D
2766: be 22 1f        LDX    $221F
2769: 8c 00 03        CMPX   #$0003
276c: 10 27 00 0d     LBEQ   $277D
2770: be 22 1f        LDX    $221F
2773: 8c 00 06        CMPX   #$0006
2776: 10 27 00 03     LBEQ   $277D
277a: 16 00 88        LBRA   $2805
277d: fc 22 02        LDD    $2202
2780: 84 01           ANDA   #$01
2782: c4 00           ANDB   #$00
2784: 10 83 00 00     CMPD   #$0000
2788: 10 27 00 0c     LBEQ   $2798
278c: f6 23 be        LDB    $23BE
278f: c1 00           CMPB   #$00
2791: 10 26 00 03     LBNE   $2798
2795: 16 00 03        LBRA   $279B
2798: 16 00 40        LBRA   $27DB
279b: ce 00 06        LDU    #$0006
279e: 10 8e 00 02     LDY    #$0002
27a2: 34 60           PSHS   U,Y
27a4: 17 81 bb        LBSR   $A962
27a7: 32 64           LEAS   $4,S
27a9: 1f 01           TFR    D,X
27ab: af 67           STX    $7,S
27ad: 33 62           LEAU   $2,S
27af: 10 ae 67        LDY    $7,S
27b2: 8e ea 5f        LDX    #$EA5F
27b5: cc 00 06        LDD    #$0006
27b8: 34 76           PSHS   U,Y,X,D
27ba: 17 6c 09        LBSR   $93C6
27bd: 32 68           LEAS   $8,S
27bf: c1 00           CMPB   #$00
27c1: 10 27 00 13     LBEQ   $27D8
27c5: c6 71           LDB    #$71
27c7: 1d              SEX
27c8: 1f 03           TFR    D,U
27ca: 10 8e 00 02     LDY    #$0002
27ce: 34 60           PSHS   U,Y
27d0: 17 5c 2b        LBSR   $83FE
27d3: 32 64           LEAS   $4,S
27d5: 16 00 df        LBRA   $28B7
27d8: 16 00 2a        LBRA   $2805
27db: 33 62           LEAU   $2,S
27dd: 10 be 23 bf     LDY    $23BF
27e1: 8e ea 5f        LDX    #$EA5F
27e4: cc 00 06        LDD    #$0006
27e7: 34 76           PSHS   U,Y,X,D
27e9: 17 6b da        LBSR   $93C6
27ec: 32 68           LEAS   $8,S
27ee: c1 00           CMPB   #$00
27f0: 10 27 00 11     LBEQ   $2805
27f4: ce 00 96        LDU    #$0096
27f7: 10 8e 00 02     LDY    #$0002
27fb: 34 60           PSHS   U,Y
27fd: 17 5b fe        LBSR   $83FE
2800: 32 64           LEAS   $4,S
2802: 16 00 b2        LBRA   $28B7
2805: be 22 1f        LDX    $221F
2808: 8c 00 04        CMPX   #$0004
280b: 10 26 00 7d     LBNE   $288C
280f: ee 65           LDU    $5,S
2811: 10 8e 00 02     LDY    #$0002
2815: 34 60           PSHS   U,Y
2817: 17 0f bf        LBSR   $37D9
281a: 32 64           LEAS   $4,S
281c: c1 00           CMPB   #$00
281e: 10 27 00 11     LBEQ   $2833
2822: ce 00 97        LDU    #$0097
2825: 10 8e 00 02     LDY    #$0002
2829: 34 60           PSHS   U,Y
282b: 17 5b d0        LBSR   $83FE
282e: 32 64           LEAS   $4,S
2830: 16 00 84        LBRA   $28B7
2833: f6 23 be        LDB    $23BE
2836: c1 00           CMPB   #$00
2838: 10 26 00 13     LBNE   $284F
283c: ce 00 00        LDU    #$0000
283f: 34 40           PSHS   U
2841: 17 0f 69        LBSR   $37AD
2844: 32 62           LEAS   $2,S
2846: c1 00           CMPB   #$00
2848: 10 27 00 03     LBEQ   $284F
284c: 16 00 03        LBRA   $2852
284f: 16 00 11        LBRA   $2863
2852: ce 00 98        LDU    #$0098
2855: 10 8e 00 02     LDY    #$0002
2859: 34 60           PSHS   U,Y
285b: 17 5b a0        LBSR   $83FE
285e: 32 64           LEAS   $4,S
2860: 16 00 54        LBRA   $28B7
2863: ee 65           LDU    $5,S
2865: f6 23 be        LDB    $23BE
2868: 4f              CLRA
2869: 1f 02           TFR    D,Y
286b: 8e 00 04        LDX    #$0004
286e: 34 70           PSHS   U,Y,X
2870: 17 0e c3        LBSR   $3736
2873: 32 66           LEAS   $6,S
2875: c1 00           CMPB   #$00
2877: 10 27 00 11     LBEQ   $288C
287b: ce 00 99        LDU    #$0099
287e: 10 8e 00 02     LDY    #$0002
2882: 34 60           PSHS   U,Y
2884: 17 5b 77        LBSR   $83FE
2887: 32 64           LEAS   $4,S
2889: 16 00 2b        LBRA   $28B7
288c: be 23 bf        LDX    $23BF
288f: 30 88 1f        LEAX   $1F,X
2892: fc 22 1f        LDD    $221F
2895: ed 84           STD    ,X
2897: fe 22 1f        LDU    $221F
289a: f6 23 be        LDB    $23BE
289d: 4f              CLRA
289e: 1f 02           TFR    D,Y
28a0: 8e 00 04        LDX    #$0004
28a3: 34 70           PSHS   U,Y,X
28a5: 17 7a e7        LBSR   $A38F
28a8: 32 66           LEAS   $6,S
28aa: ee 65           LDU    $5,S
28ac: 10 8e 00 02     LDY    #$0002
28b0: 34 60           PSHS   U,Y
28b2: 17 8f 37        LBSR   $B7EC
28b5: 32 64           LEAS   $4,S
28b7: 32 69           LEAS   $9,S
28b9: 39              RTS
28ba: fc 6b 30        LDD    $6B30
28bd: 17 94 90        LBSR   $BD50
28c0: fe 22 1f        LDU    $221F
28c3: f6 23 be        LDB    $23BE
28c6: 4f              CLRA
28c7: 1f 02           TFR    D,Y
28c9: 8e 00 04        LDX    #$0004
28cc: 34 70           PSHS   U,Y,X
28ce: 17 0f ee        LBSR   $38BF
28d1: 32 66           LEAS   $6,S
28d3: 32 62           LEAS   $2,S
28d5: 39              RTS
28d6: fc 6b 3c        LDD    $6B3C
28d9: 17 94 74        LBSR   $BD50
28dc: 33 62           LEAU   $2,S
28de: 10 8e 22 1c     LDY    #$221C
28e2: 8e ea 55        LDX    #$EA55
28e5: cc 00 06        LDD    #$0006
28e8: 34 76           PSHS   U,Y,X,D
28ea: 17 6a d9        LBSR   $93C6
28ed: 32 68           LEAS   $8,S
28ef: c1 00           CMPB   #$00
28f1: 10 27 00 03     LBEQ   $28F8
28f5: 16 00 14        LBRA   $290C
28f8: be 23 bf        LDX    $23BF
28fb: 30 05           LEAX   $5,X
28fd: ce 22 1c        LDU    #$221C
2900: 1f 12           TFR    X,Y
2902: 8e 00 04        LDX    #$0004
2905: 34 70           PSHS   U,Y,X
2907: 17 6a 73        LBSR   $937D
290a: 32 66           LEAS   $6,S
290c: 32 65           LEAS   $5,S
290e: 39              RTS
290f: fc 6b 36        LDD    $6B36
2912: 17 94 3b        LBSR   $BD50
2915: be 22 21        LDX    $2221
2918: 8c 00 03        CMPX   #$0003
291b: 10 26 00 06     LBNE   $2925
291f: cc ea 68        LDD    #$EA68
2922: fd 23 b7        STD    $23B7
2925: be 22 21        LDX    $2221
2928: 8c 00 04        CMPX   #$0004
292b: 10 26 00 06     LBNE   $2935
292f: cc ea 6b        LDD    #$EA6B
2932: fd 23 b7        STD    $23B7
2935: ce 22 1c        LDU    #$221C
2938: 10 8e 00 02     LDY    #$0002
293c: 34 60           PSHS   U,Y
293e: 17 4f 6c        LBSR   $78AD
2941: 32 64           LEAS   $4,S
2943: c1 00           CMPB   #$00
2945: 10 27 00 15     LBEQ   $295E
2949: c6 79           LDB    #$79
294b: 1d              SEX
294c: 1f 03           TFR    D,U
294e: 10 8e 00 02     LDY    #$0002
2952: 34 60           PSHS   U,Y
2954: 17 5a a7        LBSR   $83FE
2957: 32 64           LEAS   $4,S
2959: 6f 65           CLR    $5,S
295b: 16 00 18        LBRA   $2976
295e: be 23 bf        LDX    $23BF
2961: 30 0f           LEAX   $F,X
2963: ce 22 1c        LDU    #$221C
2966: 1f 12           TFR    X,Y
2968: 8e 00 04        LDX    #$0004
296b: 34 70           PSHS   U,Y,X
296d: 17 6a 0d        LBSR   $937D
2970: 32 66           LEAS   $6,S
2972: c6 01           LDB    #$01
2974: e7 65           STB    $5,S
2976: e6 65           LDB    $5,S
2978: 32 66           LEAS   $6,S
297a: 39              RTS
297b: fc 6b 3a        LDD    $6B3A
297e: 17 93 cf        LBSR   $BD50
2981: be 22 21        LDX    $2221
2984: 16 00 68        LBRA   $29EF
2987: be 22 1a        LDX    $221A
298a: bc ea 5b        CMPX   $EA5B
298d: 10 23 00 03     LBLS   $2994
2991: 16 00 68        LBRA   $29FC
2994: be 23 bf        LDX    $23BF
2997: 30 88 1b        LEAX   $1B,X
299a: fc 22 1a        LDD    $221A
299d: ed 84           STD    ,X
299f: be 23 bf        LDX    $23BF
29a2: 30 88 1d        LEAX   $1D,X
29a5: af 62           STX    $2,S
29a7: fe 22 1a        LDU    $221A
29aa: 10 8e 00 02     LDY    #$0002
29ae: 34 60           PSHS   U,Y
29b0: 17 69 13        LBSR   $92C6
29b3: 32 64           LEAS   $4,S
29b5: ed f8 02        STD    [$02,S]
29b8: 16 00 41        LBRA   $29FC
29bb: be 22 1a        LDX    $221A
29be: bc ea 5d        CMPX   $EA5D
29c1: 10 23 00 03     LBLS   $29C8
29c5: 16 00 34        LBRA   $29FC
29c8: be 23 bf        LDX    $23BF
29cb: 30 88 1d        LEAX   $1D,X
29ce: fc 22 1a        LDD    $221A
29d1: ed 84           STD    ,X
29d3: be 23 bf        LDX    $23BF
29d6: 30 88 1b        LEAX   $1B,X
29d9: af 62           STX    $2,S
29db: fe 22 1a        LDU    $221A
29de: 10 8e 00 02     LDY    #$0002
29e2: 34 60           PSHS   U,Y
29e4: 17 68 c2        LBSR   $92A9
29e7: 32 64           LEAS   $4,S
29e9: ed f8 02        STD    [$02,S]
29ec: 16 00 0d        LBRA   $29FC
29ef: 8c 00 03        CMPX   #$0003
29f2: 27 93           BEQ    $2987
29f4: 8c 00 04        CMPX   #$0004
29f7: 27 c2           BEQ    $29BB
29f9: 16 00 00        LBRA   $29FC
29fc: 32 64           LEAS   $4,S
29fe: 39              RTS
29ff: fc 6b 3c        LDD    $6B3C
2a02: 17 93 4b        LBSR   $BD50
2a05: 6f 62           CLR    $2,S
2a07: f6 23 dd        LDB    $23DD
2a0a: c1 02           CMPB   #$02
2a0c: 10 27 00 0c     LBEQ   $2A1C
2a10: f6 23 dd        LDB    $23DD
2a13: c1 03           CMPB   #$03
2a15: 10 27 00 03     LBEQ   $2A1C
2a19: 16 00 42        LBRA   $2A5E
2a1c: ce 3f f6        LDU    #$3FF6
2a1f: 10 8e ec bb     LDY    #$ECBB
2a23: c6 06           LDB    #$06
2a25: 1d              SEX
2a26: 1f 01           TFR    D,X
2a28: cc 00 06        LDD    #$0006
2a2b: 34 76           PSHS   U,Y,X,D
2a2d: 17 58 12        LBSR   $8242
2a30: 32 68           LEAS   $8,S
2a32: c1 00           CMPB   #$00
2a34: 10 26 00 09     LBNE   $2A41
2a38: cc 41 6b        LDD    #$416B
2a3b: fd 23 c3        STD    $23C3
2a3e: 16 00 1a        LBRA   $2A5B
2a41: cc ec c1        LDD    #$ECC1
2a44: fd 23 c3        STD    $23C3
2a47: 7f 3f fc        CLR    $3FFC
2a4a: ce ea 58        LDU    #$EA58
2a4d: 10 8e 3f fd     LDY    #$3FFD
2a51: 8e 00 04        LDX    #$0004
2a54: 34 70           PSHS   U,Y,X
2a56: 17 69 24        LBSR   $937D
2a59: 32 66           LEAS   $6,S
2a5b: 16 00 b7        LBRA   $2B15
2a5e: cc 41 1b        LDD    #$411B
2a61: fd 23 c3        STD    $23C3
2a64: 8e 20 00        LDX    #$2000
2a67: 30 88 36        LEAX   $36,X
2a6a: af 63           STX    $3,S
2a6c: ce 41 bb        LDU    #$41BB
2a6f: 10 ae 63        LDY    $3,S
2a72: c6 06           LDB    #$06
2a74: 1d              SEX
2a75: 1f 01           TFR    D,X
2a77: cc 00 06        LDD    #$0006
2a7a: 34 76           PSHS   U,Y,X,D
2a7c: 17 57 c3        LBSR   $8242
2a7f: 32 68           LEAS   $8,S
2a81: c1 00           CMPB   #$00
2a83: 10 26 00 1b     LBNE   $2AA2
2a87: f6 3f ee        LDB    $3FEE
2a8a: f7 3f fc        STB    $3FFC
2a8d: ce 3f ef        LDU    #$3FEF
2a90: 10 8e 3f fd     LDY    #$3FFD
2a94: 8e 00 04        LDX    #$0004
2a97: 34 70           PSHS   U,Y,X
2a99: 17 68 e1        LBSR   $937D
2a9c: 32 66           LEAS   $6,S
2a9e: c6 01           LDB    #$01
2aa0: e7 62           STB    $2,S
2aa2: 8e 20 00        LDX    #$2000
2aa5: 30 88 36        LEAX   $36,X
2aa8: af 63           STX    $3,S
2aaa: ce 41 c1        LDU    #$41C1
2aad: 10 ae 63        LDY    $3,S
2ab0: c6 06           LDB    #$06
2ab2: 1d              SEX
2ab3: 1f 01           TFR    D,X
2ab5: cc 00 06        LDD    #$0006
2ab8: 34 76           PSHS   U,Y,X,D
2aba: 17 57 85        LBSR   $8242
2abd: 32 68           LEAS   $8,S
2abf: c1 00           CMPB   #$00
2ac1: 10 26 00 1b     LBNE   $2AE0
2ac5: f6 3f f2        LDB    $3FF2
2ac8: f7 3f fc        STB    $3FFC
2acb: ce 3f f3        LDU    #$3FF3
2ace: 10 8e 3f fd     LDY    #$3FFD
2ad2: 8e 00 04        LDX    #$0004
2ad5: 34 70           PSHS   U,Y,X
2ad7: 17 68 a3        LBSR   $937D
2ada: 32 66           LEAS   $6,S
2adc: c6 01           LDB    #$01
2ade: e7 62           STB    $2,S
2ae0: e6 62           LDB    $2,S
2ae2: c1 00           CMPB   #$00
2ae4: 10 27 00 2d     LBEQ   $2B15
2ae8: ce ea 58        LDU    #$EA58
2aeb: 10 8e 3f fd     LDY    #$3FFD
2aef: c6 03           LDB    #$03
2af1: 1d              SEX
2af2: 1f 01           TFR    D,X
2af4: cc 00 06        LDD    #$0006
2af7: 34 76           PSHS   U,Y,X,D
2af9: 17 57 46        LBSR   $8242
2afc: 32 68           LEAS   $8,S
2afe: c1 00           CMPB   #$00
2b00: 10 26 00 11     LBNE   $2B15
2b04: ce 41 c7        LDU    #$41C7
2b07: 10 8e 3f fd     LDY    #$3FFD
2b0b: 8e 00 04        LDX    #$0004
2b0e: 34 70           PSHS   U,Y,X
2b10: 17 68 6a        LBSR   $937D
2b13: 32 66           LEAS   $6,S
2b15: ce 3f f6        LDU    #$3FF6
2b18: 10 8e ec bb     LDY    #$ECBB
2b1c: c6 06           LDB    #$06
2b1e: 1d              SEX
2b1f: 1f 01           TFR    D,X
2b21: cc 00 06        LDD    #$0006
2b24: 34 76           PSHS   U,Y,X,D
2b26: 17 57 5c        LBSR   $8285
2b29: 32 68           LEAS   $8,S
2b2b: 32 65           LEAS   $5,S
2b2d: 39              RTS
2b2e: 00 01           NEG    <$01
2b30: 00 00           NEG    <$00
2b32: 00 23           NEG    <$23
2b34: 00 0b           NEG    <$0B
2b36: 00 04           NEG    <$04
2b38: 00 07           NEG    <$07
2b3a: 00 02           NEG    <$02
2b3c: 00 03           NEG    <$03
2b3e: fc 77 2a        LDD    $772A
2b41: 17 92 0c        LBSR   $BD50
2b44: f6 23 b3        LDB    $23B3
2b47: f7 26 83        STB    $2683
2b4a: f6 23 b4        LDB    $23B4
2b4d: f7 26 84        STB    $2684
2b50: f6 23 b5        LDB    $23B5
2b53: f7 26 85        STB    $2685
2b56: f6 23 b6        LDB    $23B6
2b59: f7 26 86        STB    $2686
2b5c: ce 26 8f        LDU    #$268F
2b5f: 10 ae e9 00 06  LDY    $0006,S
2b64: 34 60           PSHS   U,Y
2b66: 86 01           LDA    #$01
2b68: 8e 77 28        LDX    #$7728
2b6b: 17 91 7c        LBSR   $BCEA
2b6e: 1f 13           TFR    X,U
2b70: 10 8e 24 e6     LDY    #$24E6
2b74: 8e 01 a9        LDX    #$01A9
2b77: cc 00 06        LDD    #$0006
2b7a: 34 76           PSHS   U,Y,X,D
2b7c: 17 57 06        LBSR   $8285
2b7f: 32 68           LEAS   $8,S
2b81: 32 62           LEAS   $2,S
2b83: 39              RTS
2b84: fc 77 2e        LDD    $772E
2b87: 17 91 c6        LBSR   $BD50
2b8a: 6f 64           CLR    $4,S
2b8c: f6 3b 84        LDB    $3B84
2b8f: c1 00           CMPB   #$00
2b91: 10 27 00 0a     LBEQ   $2B9F
2b95: ce 00 00        LDU    #$0000
2b98: 34 40           PSHS   U
2b9a: 17 5c e8        LBSR   $8885
2b9d: 32 62           LEAS   $2,S
2b9f: be 22 15        LDX    $2215
2ba2: 16 05 be        LBRA   $3163
2ba5: c6 04           LDB    #$04
2ba7: 1d              SEX
2ba8: 1f 03           TFR    D,U
2baa: 10 be 22 21     LDY    $2221
2bae: 8e 00 04        LDX    #$0004
2bb1: 34 70           PSHS   U,Y,X
2bb3: 17 62 2b        LBSR   $8DE1
2bb6: 32 66           LEAS   $6,S
2bb8: c1 08           CMPB   #$08
2bba: 10 24 00 32     LBCC   $2BF0
2bbe: ce 22 1c        LDU    #$221C
2bc1: 10 8e 24 14     LDY    #$2414
2bc5: 8e 00 04        LDX    #$0004
2bc8: 34 70           PSHS   U,Y,X
2bca: 17 5f 43        LBSR   $8B10
2bcd: 32 66           LEAS   $6,S
2bcf: be 22 15        LDX    $2215
2bd2: 8c 00 06        CMPX   #$0006
2bd5: 10 26 00 0d     LBNE   $2BE6
2bd9: ce 00 00        LDU    #$0000
2bdc: 34 40           PSHS   U
2bde: 17 fc f5        LBSR   $28D6
2be1: 32 62           LEAS   $2,S
2be3: 16 00 0a        LBRA   $2BF0
2be6: ce 00 00        LDU    #$0000
2be9: 34 40           PSHS   U
2beb: 17 f8 8d        LBSR   $247B
2bee: 32 62           LEAS   $2,S
2bf0: be 22 15        LDX    $2215
2bf3: 8c 00 06        CMPX   #$0006
2bf6: 10 26 00 0d     LBNE   $2C07
2bfa: be 23 bf        LDX    $23BF
2bfd: 30 08           LEAX   $8,X
2bff: fc 22 21        LDD    $2221
2c02: ed 84           STD    ,X
2c04: 16 00 0a        LBRA   $2C11
2c07: be 23 bf        LDX    $23BF
2c0a: 30 03           LEAX   $3,X
2c0c: fc 22 21        LDD    $2221
2c0f: ed 84           STD    ,X
2c11: cc 00 01        LDD    #$0001
2c14: fd 22 15        STD    $2215
2c17: 7f 3b 84        CLR    $3B84
2c1a: ce 00 00        LDU    #$0000
2c1d: 34 40           PSHS   U
2c1f: 17 e8 c4        LBSR   $14E6
2c22: 32 62           LEAS   $2,S
2c24: ce 00 00        LDU    #$0000
2c27: 10 8e 00 02     LDY    #$0002
2c2b: 34 60           PSHS   U,Y
2c2d: be 3b 85        LDX    $3B85
2c30: ad 84           JSR    ,X
2c32: 32 64           LEAS   $4,S
2c34: 16 05 69        LBRA   $31A0
2c37: be 22 21        LDX    $2221
2c3a: 16 00 3f        LBRA   $2C7C
2c3d: c6 04           LDB    #$04
2c3f: e7 62           STB    $2,S
2c41: c6 05           LDB    #$05
2c43: e7 63           STB    $3,S
2c45: c6 01           LDB    #$01
2c47: e7 64           STB    $4,S
2c49: 16 00 5d        LBRA   $2CA9
2c4c: c6 03           LDB    #$03
2c4e: e7 62           STB    $2,S
2c50: c6 05           LDB    #$05
2c52: e7 63           STB    $3,S
2c54: c6 01           LDB    #$01
2c56: e7 64           STB    $4,S
2c58: 16 00 4e        LBRA   $2CA9
2c5b: c6 06           LDB    #$06
2c5d: e7 62           STB    $2,S
2c5f: c6 09           LDB    #$09
2c61: e7 63           STB    $3,S
2c63: 16 00 43        LBRA   $2CA9
2c66: c6 04           LDB    #$04
2c68: e7 62           STB    $2,S
2c6a: c6 08           LDB    #$08
2c6c: e7 63           STB    $3,S
2c6e: 16 00 38        LBRA   $2CA9
2c71: c6 04           LDB    #$04
2c73: e7 62           STB    $2,S
2c75: c6 05           LDB    #$05
2c77: e7 63           STB    $3,S
2c79: 16 00 2d        LBRA   $2CA9
2c7c: 8c 00 0b        CMPX   #$000B
2c7f: 10 2e 00 26     LBGT   $2CA9
2c83: 1f 10           TFR    X,D
2c85: 83 00 01        SUBD   #$0001
2c88: 10 2d 00 1d     LBLT   $2CA9
2c8c: 8e 6c 93        LDX    #$6C93
2c8f: 58              ASLB
2c90: 49              ROLA
2c91: 6e 9b           JMP    [D,X]
2c93: 6c 66           INC    $6,S
2c95: 6c 66           INC    $6,S
2c97: 6c 3d           INC    -$3,Y
2c99: 6c 4c           INC    $C,U
2c9b: 6c 5b           INC    -$5,U
2c9d: 6c 5b           INC    -$5,U
2c9f: 6c 5b           INC    -$5,U
2ca1: 6c a9 6c a9     INC    $6CA9,Y
2ca5: 6c a9 6c 71     INC    $6C71,Y
2ca9: be 22 15        LDX    $2215
2cac: 8c 00 07        CMPX   #$0007
2caf: 10 26 00 53     LBNE   $2D06
2cb3: e6 62           LDB    $2,S
2cb5: 4f              CLRA
2cb6: 1f 03           TFR    D,U
2cb8: 10 be 22 21     LDY    $2221
2cbc: 8e 00 04        LDX    #$0004
2cbf: 34 70           PSHS   U,Y,X
2cc1: 17 61 1d        LBSR   $8DE1
2cc4: 32 66           LEAS   $6,S
2cc6: e1 63           CMPB   $3,S
2cc8: 10 24 00 2e     LBCC   $2CFA
2ccc: ce 22 1c        LDU    #$221C
2ccf: 10 8e 24 14     LDY    #$2414
2cd3: 8e 00 04        LDX    #$0004
2cd6: 34 70           PSHS   U,Y,X
2cd8: 17 5e 35        LBSR   $8B10
2cdb: 32 66           LEAS   $6,S
2cdd: ce 00 00        LDU    #$0000
2ce0: 34 40           PSHS   U
2ce2: 17 fc 2a        LBSR   $290F
2ce5: 32 62           LEAS   $2,S
2ce7: 10 83 00 00     CMPD   #$0000
2ceb: 10 27 00 0b     LBEQ   $2CFA
2cef: be 23 bf        LDX    $23BF
2cf2: 30 88 12        LEAX   $12,X
2cf5: fc 22 21        LDD    $2221
2cf8: ed 84           STD    ,X
2cfa: cc 00 02        LDD    #$0002
2cfd: fd 22 15        STD    $2215
2d00: 7f 3b 84        CLR    $3B84
2d03: 16 00 b1        LBRA   $2DB7
2d06: e6 62           LDB    $2,S
2d08: 4f              CLRA
2d09: 1f 03           TFR    D,U
2d0b: 10 be 22 21     LDY    $2221
2d0f: 8e 00 04        LDX    #$0004
2d12: 34 70           PSHS   U,Y,X
2d14: 17 60 ca        LBSR   $8DE1
2d17: 32 66           LEAS   $6,S
2d19: e1 63           CMPB   $3,S
2d1b: 10 24 00 40     LBCC   $2D5F
2d1f: ce 22 1c        LDU    #$221C
2d22: 10 8e 24 14     LDY    #$2414
2d26: 8e 00 04        LDX    #$0004
2d29: 34 70           PSHS   U,Y,X
2d2b: 17 5d e2        LBSR   $8B10
2d2e: 32 66           LEAS   $6,S
2d30: be 23 bf        LDX    $23BF
2d33: 30 0d           LEAX   $D,X
2d35: ae 84           LDX    ,X
2d37: af 68           STX    $8,S
2d39: be 23 bf        LDX    $23BF
2d3c: 30 0d           LEAX   $D,X
2d3e: fc 22 21        LDD    $2221
2d41: ed 84           STD    ,X
2d43: ce 00 00        LDU    #$0000
2d46: 34 40           PSHS   U
2d48: 17 f7 fc        LBSR   $2547
2d4b: 32 62           LEAS   $2,S
2d4d: c1 00           CMPB   #$00
2d4f: 10 26 00 09     LBNE   $2D5C
2d53: be 23 bf        LDX    $23BF
2d56: 30 0d           LEAX   $D,X
2d58: ec 68           LDD    $8,S
2d5a: ed 84           STD    ,X
2d5c: 16 00 58        LBRA   $2DB7
2d5f: e6 64           LDB    $4,S
2d61: c1 00           CMPB   #$00
2d63: 10 27 00 50     LBEQ   $2DB7
2d67: be 23 bf        LDX    $23BF
2d6a: 30 0a           LEAX   $A,X
2d6c: 30 01           LEAX   $1,X
2d6e: af 66           STX    $6,S
2d70: be 23 bf        LDX    $23BF
2d73: 30 0d           LEAX   $D,X
2d75: ae 84           LDX    ,X
2d77: bc 22 21        CMPX   $2221
2d7a: 10 27 00 39     LBEQ   $2DB7
2d7e: be 22 21        LDX    $2221
2d81: 8c 00 03        CMPX   #$0003
2d84: 10 26 00 14     LBNE   $2D9C
2d88: ee f8 06        LDU    [$06,S]
2d8b: 10 8e 00 02     LDY    #$0002
2d8f: 34 60           PSHS   U,Y
2d91: 17 65 15        LBSR   $92A9
2d94: 32 64           LEAS   $4,S
2d96: ed f8 06        STD    [$06,S]
2d99: 16 00 11        LBRA   $2DAD
2d9c: ee f8 06        LDU    [$06,S]
2d9f: 10 8e 00 02     LDY    #$0002
2da3: 34 60           PSHS   U,Y
2da5: 17 65 1e        LBSR   $92C6
2da8: 32 64           LEAS   $4,S
2daa: ed f8 06        STD    [$06,S]
2dad: be 23 bf        LDX    $23BF
2db0: 30 0d           LEAX   $D,X
2db2: fc 22 21        LDD    $2221
2db5: ed 84           STD    ,X
2db7: e6 64           LDB    $4,S
2db9: c1 00           CMPB   #$00
2dbb: 10 27 00 6a     LBEQ   $2E29
2dbf: be 23 bf        LDX    $23BF
2dc2: 30 0f           LEAX   $F,X
2dc4: 30 01           LEAX   $1,X
2dc6: af 66           STX    $6,S
2dc8: be 23 bf        LDX    $23BF
2dcb: 30 88 12        LEAX   $12,X
2dce: fe 23 bf        LDU    $23BF
2dd1: 33 4d           LEAU   $D,U
2dd3: ae 84           LDX    ,X
2dd5: ac c4           CMPX   ,U
2dd7: 10 27 00 4e     LBEQ   $2E29
2ddb: be 23 bf        LDX    $23BF
2dde: 30 0d           LEAX   $D,X
2de0: ae 84           LDX    ,X
2de2: 8c 00 03        CMPX   #$0003
2de5: 10 26 00 1a     LBNE   $2E03
2de9: ee f8 06        LDU    [$06,S]
2dec: 10 8e 00 02     LDY    #$0002
2df0: 34 60           PSHS   U,Y
2df2: 17 64 b4        LBSR   $92A9
2df5: 32 64           LEAS   $4,S
2df7: ed f8 06        STD    [$06,S]
2dfa: cc ea 68        LDD    #$EA68
2dfd: fd 23 b7        STD    $23B7
2e00: 16 00 17        LBRA   $2E1A
2e03: ee f8 06        LDU    [$06,S]
2e06: 10 8e 00 02     LDY    #$0002
2e0a: 34 60           PSHS   U,Y
2e0c: 17 64 b7        LBSR   $92C6
2e0f: 32 64           LEAS   $4,S
2e11: ed f8 06        STD    [$06,S]
2e14: cc ea 6b        LDD    #$EA6B
2e17: fd 23 b7        STD    $23B7
2e1a: be 23 bf        LDX    $23BF
2e1d: 30 88 12        LEAX   $12,X
2e20: fe 23 bf        LDU    $23BF
2e23: 33 4d           LEAU   $D,U
2e25: ee c4           LDU    ,U
2e27: ef 84           STU    ,X
2e29: ce 00 00        LDU    #$0000
2e2c: 34 40           PSHS   U
2e2e: 17 e9 80        LBSR   $17B1
2e31: 32 62           LEAS   $2,S
2e33: ce 00 01        LDU    #$0001
2e36: 10 8e 00 02     LDY    #$0002
2e3a: 34 60           PSHS   U,Y
2e3c: be 3b 85        LDX    $3B85
2e3f: ad 84           JSR    ,X
2e41: 32 64           LEAS   $4,S
2e43: 16 03 5a        LBRA   $31A0
2e46: be 23 bf        LDX    $23BF
2e49: 30 88 19        LEAX   $19,X
2e4c: fc 22 21        LDD    $2221
2e4f: ed 84           STD    ,X
2e51: be 22 21        LDX    $2221
2e54: 8c 00 03        CMPX   #$0003
2e57: 10 26 00 07     LBNE   $2E62
2e5b: c6 07           LDB    #$07
2e5d: e7 62           STB    $2,S
2e5f: 16 00 04        LBRA   $2E66
2e62: c6 06           LDB    #$06
2e64: e7 62           STB    $2,S
2e66: e6 62           LDB    $2,S
2e68: 4f              CLRA
2e69: 1f 03           TFR    D,U
2e6b: 10 be 22 21     LDY    $2221
2e6f: 8e 00 04        LDX    #$0004
2e72: 34 70           PSHS   U,Y,X
2e74: 17 5f 6a        LBSR   $8DE1
2e77: 32 66           LEAS   $6,S
2e79: c1 05           CMPB   #$05
2e7b: 10 24 00 32     LBCC   $2EB1
2e7f: ce 24 14        LDU    #$2414
2e82: 10 8e 00 02     LDY    #$0002
2e86: 34 60           PSHS   U,Y
2e88: 17 5a e8        LBSR   $8973
2e8b: 32 64           LEAS   $4,S
2e8d: fd 22 1a        STD    $221A
2e90: be 22 15        LDX    $2215
2e93: 8c 00 08        CMPX   #$0008
2e96: 10 26 00 0d     LBNE   $2EA7
2e9a: ce 00 00        LDU    #$0000
2e9d: 34 40           PSHS   U
2e9f: 17 fa d9        LBSR   $297B
2ea2: 32 62           LEAS   $2,S
2ea4: 16 00 0a        LBRA   $2EB1
2ea7: ce 00 00        LDU    #$0000
2eaa: 34 40           PSHS   U
2eac: 17 f8 03        LBSR   $26B2
2eaf: 32 62           LEAS   $2,S
2eb1: cc 00 03        LDD    #$0003
2eb4: fd 22 15        STD    $2215
2eb7: 7f 3b 84        CLR    $3B84
2eba: ce 00 00        LDU    #$0000
2ebd: 34 40           PSHS   U
2ebf: 17 e9 92        LBSR   $1854
2ec2: 32 62           LEAS   $2,S
2ec4: ce 00 02        LDU    #$0002
2ec7: 10 8e 00 02     LDY    #$0002
2ecb: 34 60           PSHS   U,Y
2ecd: be 3b 85        LDX    $3B85
2ed0: ad 84           JSR    ,X
2ed2: 32 64           LEAS   $4,S
2ed4: 16 02 c9        LBRA   $31A0
2ed7: ce 00 00        LDU    #$0000
2eda: 34 40           PSHS   U
2edc: 17 f8 6d        LBSR   $274C
2edf: 32 62           LEAS   $2,S
2ee1: be 23 bf        LDX    $23BF
2ee4: 30 0a           LEAX   $A,X
2ee6: 1f 13           TFR    X,U
2ee8: f6 23 be        LDB    $23BE
2eeb: 4f              CLRA
2eec: 1f 02           TFR    D,Y
2eee: 8e 00 04        LDX    #$0004
2ef1: 34 70           PSHS   U,Y,X
2ef3: 17 51 73        LBSR   $8069
2ef6: 32 66           LEAS   $6,S
2ef8: ce 00 00        LDU    #$0000
2efb: 34 40           PSHS   U
2efd: 17 ea b3        LBSR   $19B3
2f00: 32 62           LEAS   $2,S
2f02: ce 00 00        LDU    #$0000
2f05: 34 40           PSHS   U
2f07: 17 e5 dc        LBSR   $14E6
2f0a: 32 62           LEAS   $2,S
2f0c: ce 00 00        LDU    #$0000
2f0f: 34 40           PSHS   U
2f11: 17 e8 9d        LBSR   $17B1
2f14: 32 62           LEAS   $2,S
2f16: ce 00 00        LDU    #$0000
2f19: 34 40           PSHS   U
2f1b: 17 e9 36        LBSR   $1854
2f1e: 32 62           LEAS   $2,S
2f20: ce 00 03        LDU    #$0003
2f23: 10 8e 00 02     LDY    #$0002
2f27: 34 60           PSHS   U,Y
2f29: be 3b 85        LDX    $3B85
2f2c: ad 84           JSR    ,X
2f2e: 32 64           LEAS   $4,S
2f30: 16 02 6d        LBRA   $31A0
2f33: ce 00 00        LDU    #$0000
2f36: 34 40           PSHS   U
2f38: 17 f9 7f        LBSR   $28BA
2f3b: 32 62           LEAS   $2,S
2f3d: ce 00 00        LDU    #$0000
2f40: 34 40           PSHS   U
2f42: 17 ea a2        LBSR   $19E7
2f45: 32 62           LEAS   $2,S
2f47: ce 00 00        LDU    #$0000
2f4a: 34 40           PSHS   U
2f4c: 17 e8 62        LBSR   $17B1
2f4f: 32 62           LEAS   $2,S
2f51: ce 00 04        LDU    #$0004
2f54: 10 8e 00 02     LDY    #$0002
2f58: 34 60           PSHS   U,Y
2f5a: be 3b 85        LDX    $3B85
2f5d: ad 84           JSR    ,X
2f5f: 32 64           LEAS   $4,S
2f61: 16 02 3c        LBRA   $31A0
2f64: f6 22 19        LDB    $2219
2f67: 4f              CLRA
2f68: 1f 03           TFR    D,U
2f6a: 10 8e 00 02     LDY    #$0002
2f6e: 34 60           PSHS   U,Y
2f70: 17 fb cb        LBSR   $2B3E
2f73: 32 64           LEAS   $4,S
2f75: 16 02 28        LBRA   $31A0
2f78: c6 08           LDB    #$08
2f7a: 1d              SEX
2f7b: 1f 03           TFR    D,U
2f7d: 10 8e 00 00     LDY    #$0000
2f81: 8e 00 04        LDX    #$0004
2f84: 34 70           PSHS   U,Y,X
2f86: 17 5e 58        LBSR   $8DE1
2f89: 32 66           LEAS   $6,S
2f8b: ce 24 14        LDU    #$2414
2f8e: 10 8e 00 02     LDY    #$0002
2f92: 34 60           PSHS   U,Y
2f94: 17 5a 9f        LBSR   $8A36
2f97: 32 64           LEAS   $4,S
2f99: e7 65           STB    $5,S
2f9b: e6 65           LDB    $5,S
2f9d: c1 10           CMPB   #$10
2f9f: 10 24 00 0b     LBCC   $2FAE
2fa3: e6 65           LDB    $5,S
2fa5: 53              COMB
2fa6: 1d              SEX
2fa7: 84 00           ANDA   #$00
2fa9: c4 0f           ANDB   #$0F
2fab: f7 24 f4        STB    $24F4
2fae: ce 00 00        LDU    #$0000
2fb1: 34 40           PSHS   U
2fb3: 17 d8 4d        LBSR   $0803
2fb6: 32 62           LEAS   $2,S
2fb8: ce 00 0a        LDU    #$000A
2fbb: 10 8e 00 02     LDY    #$0002
2fbf: 34 60           PSHS   U,Y
2fc1: be 3b 85        LDX    $3B85
2fc4: ad 84           JSR    ,X
2fc6: 32 64           LEAS   $4,S
2fc8: 16 01 d5        LBRA   $31A0
2fcb: fe 22 1f        LDU    $221F
2fce: 10 8e 00 02     LDY    #$0002
2fd2: 34 60           PSHS   U,Y
2fd4: 17 d9 ad        LBSR   $0984
2fd7: 32 64           LEAS   $4,S
2fd9: 16 01 c4        LBRA   $31A0
2fdc: fc 22 21        LDD    $2221
2fdf: fd 26 7b        STD    $267B
2fe2: 7f 3b 84        CLR    $3B84
2fe5: c6 04           LDB    #$04
2fe7: 1d              SEX
2fe8: 1f 03           TFR    D,U
2fea: 10 be 22 21     LDY    $2221
2fee: 8e 00 04        LDX    #$0004
2ff1: 34 70           PSHS   U,Y,X
2ff3: 17 5d eb        LBSR   $8DE1
2ff6: 32 66           LEAS   $6,S
2ff8: c1 08           CMPB   #$08
2ffa: 10 24 00 32     LBCC   $3030
2ffe: ce 22 1c        LDU    #$221C
3001: 10 8e 24 14     LDY    #$2414
3005: 8e 00 04        LDX    #$0004
3008: 34 70           PSHS   U,Y,X
300a: 17 5b 03        LBSR   $8B10
300d: 32 66           LEAS   $6,S
300f: be 22 15        LDX    $2215
3012: 8c 00 0f        CMPX   #$000F
3015: 10 26 00 0d     LBNE   $3026
3019: ce 00 00        LDU    #$0000
301c: 34 40           PSHS   U
301e: 17 dc 7e        LBSR   $0C9F
3021: 32 62           LEAS   $2,S
3023: 16 00 0a        LBRA   $3030
3026: ce 00 00        LDU    #$0000
3029: 34 40           PSHS   U
302b: 17 db d0        LBSR   $0BFE
302e: 32 62           LEAS   $2,S
3030: be 22 15        LDX    $2215
3033: 8c 00 0c        CMPX   #$000C
3036: 10 26 00 06     LBNE   $3040
303a: fc 22 21        LDD    $2221
303d: fd 26 77        STD    $2677
3040: cc 00 0c        LDD    #$000C
3043: fd 22 15        STD    $2215
3046: ce 00 00        LDU    #$0000
3049: 34 40           PSHS   U
304b: 17 d4 13        LBSR   $0461
304e: 32 62           LEAS   $2,S
3050: ce 00 06        LDU    #$0006
3053: 10 8e 00 02     LDY    #$0002
3057: 34 60           PSHS   U,Y
3059: be 3b 85        LDX    $3B85
305c: ad 84           JSR    ,X
305e: 32 64           LEAS   $4,S
3060: 16 01 3d        LBRA   $31A0
3063: 7f 3b 84        CLR    $3B84
3066: c6 06           LDB    #$06
3068: 1d              SEX
3069: 1f 03           TFR    D,U
306b: 10 be 22 21     LDY    $2221
306f: 8e 00 04        LDX    #$0004
3072: 34 70           PSHS   U,Y,X
3074: 17 5d 6a        LBSR   $8DE1
3077: 32 66           LEAS   $6,S
3079: c1 09           CMPB   #$09
307b: 10 24 00 32     LBCC   $30B1
307f: ce 22 1c        LDU    #$221C
3082: 10 8e 24 14     LDY    #$2414
3086: 8e 00 04        LDX    #$0004
3089: 34 70           PSHS   U,Y,X
308b: 17 5a 82        LBSR   $8B10
308e: 32 66           LEAS   $6,S
3090: be 22 15        LDX    $2215
3093: 8c 00 10        CMPX   #$0010
3096: 10 26 00 0d     LBNE   $30A7
309a: ce 00 00        LDU    #$0000
309d: 34 40           PSHS   U
309f: 17 dc f4        LBSR   $0D96
30a2: 32 62           LEAS   $2,S
30a4: 16 00 0a        LBRA   $30B1
30a7: ce 00 00        LDU    #$0000
30aa: 34 40           PSHS   U
30ac: 17 dc 26        LBSR   $0CD5
30af: 32 62           LEAS   $2,S
30b1: cc 00 0d        LDD    #$000D
30b4: fd 22 15        STD    $2215
30b7: ce 00 00        LDU    #$0000
30ba: 34 40           PSHS   U
30bc: 17 d4 ba        LBSR   $0579
30bf: 32 62           LEAS   $2,S
30c1: ce 00 07        LDU    #$0007
30c4: 10 8e 00 02     LDY    #$0002
30c8: 34 60           PSHS   U,Y
30ca: be 3b 85        LDX    $3B85
30cd: ad 84           JSR    ,X
30cf: 32 64           LEAS   $4,S
30d1: 16 00 cc        LBRA   $31A0
30d4: fc 22 21        LDD    $2221
30d7: fd 26 79        STD    $2679
30da: 7f 3b 84        CLR    $3B84
30dd: be 22 21        LDX    $2221
30e0: 8c 00 03        CMPX   #$0003
30e3: 10 26 00 07     LBNE   $30EE
30e7: c6 07           LDB    #$07
30e9: e7 62           STB    $2,S
30eb: 16 00 04        LBRA   $30F2
30ee: c6 06           LDB    #$06
30f0: e7 62           STB    $2,S
30f2: e6 62           LDB    $2,S
30f4: 4f              CLRA
30f5: 1f 03           TFR    D,U
30f7: 10 be 22 21     LDY    $2221
30fb: 8e 00 04        LDX    #$0004
30fe: 34 70           PSHS   U,Y,X
3100: 17 5c de        LBSR   $8DE1
3103: 32 66           LEAS   $6,S
3105: c1 05           CMPB   #$05
3107: 10 24 00 32     LBCC   $313D
310b: ce 24 14        LDU    #$2414
310e: 10 8e 00 02     LDY    #$0002
3112: 34 60           PSHS   U,Y
3114: 17 58 5c        LBSR   $8973
3117: 32 64           LEAS   $4,S
3119: fd 22 1a        STD    $221A
311c: be 22 15        LDX    $2215
311f: 8c 00 11        CMPX   #$0011
3122: 10 26 00 0d     LBNE   $3133
3126: ce 00 00        LDU    #$0000
3129: 34 40           PSHS   U
312b: 17 dd 59        LBSR   $0E87
312e: 32 62           LEAS   $2,S
3130: 16 00 0a        LBRA   $313D
3133: ce 00 00        LDU    #$0000
3136: 34 40           PSHS   U
3138: 17 dc 8c        LBSR   $0DC7
313b: 32 62           LEAS   $2,S
313d: cc 00 0e        LDD    #$000E
3140: fd 22 15        STD    $2215
3143: ce 00 00        LDU    #$0000
3146: 34 40           PSHS   U
3148: 17 d5 43        LBSR   $068E
314b: 32 62           LEAS   $2,S
314d: ce 00 08        LDU    #$0008
3150: 10 8e 00 02     LDY    #$0002
3154: 34 60           PSHS   U,Y
3156: be 3b 85        LDX    $3B85
3159: ad 84           JSR    ,X
315b: 32 64           LEAS   $4,S
315d: 16 00 40        LBRA   $31A0
3160: 16 00 3d        LBRA   $31A0
3163: 8c 00 13        CMPX   #$0013
3166: 10 2e 00 36     LBGT   $31A0
316a: 1f 10           TFR    X,D
316c: 83 00 01        SUBD   #$0001
316f: 10 2d 00 2d     LBLT   $31A0
3173: 8e 71 7a        LDX    #$717A
3176: 58              ASLB
3177: 49              ROLA
3178: 6e 9b           JMP    [D,X]
317a: 6b a5           XDEC   B,Y
317c: 6c 37           INC    -$9,Y
317e: 6e 46           JMP    $6,U
3180: 6e d7           JMP    [E,U]
3182: 6f 33           CLR    -$D,Y
3184: 6b a5           XDEC   B,Y
3186: 6c 37           INC    -$9,Y
3188: 6e 51           JMP    -$F,U
318a: 6f 64           CLR    $4,S
318c: 71 a0 71        NEG    $A071
318f: a0 6f           SUBA   $F,S
3191: e5 70           BITB   -$10,S
3193: 66 70           ROR    -$10,S
3195: dd 6f           STD    <$6F
3197: dc 70           LDD    <$70
3199: 63 70           COM    -$10,S
319b: d4 6f           ANDB   <$6F
319d: 78 6f cb        ASL    $6FCB
31a0: 32 6a           LEAS   $A,S
31a2: 39              RTS
31a3: fc 77 2e        LDD    $772E
31a6: 17 8b a7        LBSR   $BD50
31a9: ce 25 81        LDU    #$2581
31ac: f6 24 f4        LDB    $24F4
31af: 4f              CLRA
31b0: 1f 02           TFR    D,Y
31b2: 34 60           PSHS   U,Y
31b4: 86 01           LDA    #$01
31b6: 8e 77 30        LDX    #$7730
31b9: 17 8b 2e        LBSR   $BCEA
31bc: af 64           STX    $4,S
31be: f6 3b 84        LDB    $3B84
31c1: c1 00           CMPB   #$00
31c3: 10 27 00 0a     LBEQ   $31D1
31c7: ce 00 00        LDU    #$0000
31ca: 34 40           PSHS   U
31cc: 17 56 b6        LBSR   $8885
31cf: 32 62           LEAS   $2,S
31d1: be 22 15        LDX    $2215
31d4: 16 05 17        LBRA   $36EE
31d7: cc 00 01        LDD    #$0001
31da: fd 22 15        STD    $2215
31dd: ae e9 00 0e     LDX    $000E,S
31e1: 8c 00 00        CMPX   #$0000
31e4: 10 27 00 24     LBEQ   $320C
31e8: be 23 bf        LDX    $23BF
31eb: 30 05           LEAX   $5,X
31ed: ce 22 1c        LDU    #$221C
31f0: 1f 12           TFR    X,Y
31f2: be 23 bf        LDX    $23BF
31f5: cc 00 06        LDD    #$0006
31f8: 34 76           PSHS   U,Y,X,D
31fa: 17 61 95        LBSR   $9392
31fd: 32 68           LEAS   $8,S
31ff: ce 00 00        LDU    #$0000
3202: 34 40           PSHS   U
3204: 17 f2 74        LBSR   $247B
3207: 32 62           LEAS   $2,S
3209: 16 00 2a        LBRA   $3236
320c: be 23 bf        LDX    $23BF
320f: 30 05           LEAX   $5,X
3211: af 66           STX    $6,S
3213: ce 22 1c        LDU    #$221C
3216: 10 ae 66        LDY    $6,S
3219: be 23 bf        LDX    $23BF
321c: cc 00 06        LDD    #$0006
321f: 34 76           PSHS   U,Y,X,D
3221: 17 61 a2        LBSR   $93C6
3224: 32 68           LEAS   $8,S
3226: c1 00           CMPB   #$00
3228: 10 26 00 0a     LBNE   $3236
322c: ce 00 00        LDU    #$0000
322f: 34 40           PSHS   U
3231: 17 f2 47        LBSR   $247B
3234: 32 62           LEAS   $2,S
3236: ce 00 00        LDU    #$0000
3239: 34 40           PSHS   U
323b: 17 e2 a8        LBSR   $14E6
323e: 32 62           LEAS   $2,S
3240: ce 00 00        LDU    #$0000
3243: 10 8e 00 02     LDY    #$0002
3247: 34 60           PSHS   U,Y
3249: be 3b 85        LDX    $3B85
324c: ad 84           JSR    ,X
324e: 32 64           LEAS   $4,S
3250: 16 04 d2        LBRA   $3725
3253: cc 00 02        LDD    #$0002
3256: fd 22 15        STD    $2215
3259: be 23 bf        LDX    $23BF
325c: 30 88 14        LEAX   $14,X
325f: e6 84           LDB    ,X
3261: f7 24 1e        STB    $241E
3264: be 23 bf        LDX    $23BF
3267: 30 88 1f        LEAX   $1F,X
326a: ae 84           LDX    ,X
326c: 8c 00 04        CMPX   #$0004
326f: 10 26 00 11     LBNE   $3284
3273: be 23 bf        LDX    $23BF
3276: 30 88 14        LEAX   $14,X
3279: e6 84           LDB    ,X
327b: c1 2d           CMPB   #$2D
327d: 10 26 00 03     LBNE   $3284
3281: 16 00 03        LBRA   $3287
3284: 16 00 0c        LBRA   $3293
3287: ec e9 00 0e     LDD    $000E,S
328b: 88 00           EORA   #$00
328d: c8 01           EORB   #$01
328f: ed e9 00 0e     STD    $000E,S
3293: ae e9 00 0e     LDX    $000E,S
3297: 8c 00 00        CMPX   #$0000
329a: 10 27 00 33     LBEQ   $32D1
329e: be 23 bf        LDX    $23BF
32a1: 30 0f           LEAX   $F,X
32a3: fe 23 bf        LDU    $23BF
32a6: 33 4a           LEAU   $A,U
32a8: af 66           STX    $6,S
32aa: ef 68           STU    $8,S
32ac: ce 22 1c        LDU    #$221C
32af: 10 ae 66        LDY    $6,S
32b2: ae 68           LDX    $8,S
32b4: cc 00 06        LDD    #$0006
32b7: 34 76           PSHS   U,Y,X,D
32b9: 17 60 d6        LBSR   $9392
32bc: 32 68           LEAS   $8,S
32be: c1 00           CMPB   #$00
32c0: 10 26 00 0a     LBNE   $32CE
32c4: ce 00 00        LDU    #$0000
32c7: 34 40           PSHS   U
32c9: 17 f2 7b        LBSR   $2547
32cc: 32 62           LEAS   $2,S
32ce: 16 00 84        LBRA   $3355
32d1: be 23 bf        LDX    $23BF
32d4: 30 0f           LEAX   $F,X
32d6: fe 23 bf        LDU    $23BF
32d9: 33 4a           LEAU   $A,U
32db: af 68           STX    $8,S
32dd: ef 66           STU    $6,S
32df: ce 22 1c        LDU    #$221C
32e2: 10 ae 68        LDY    $8,S
32e5: ae 66           LDX    $6,S
32e7: cc 00 06        LDD    #$0006
32ea: 34 76           PSHS   U,Y,X,D
32ec: 17 60 d7        LBSR   $93C6
32ef: 32 68           LEAS   $8,S
32f1: c1 00           CMPB   #$00
32f3: 10 26 00 0d     LBNE   $3304
32f7: ce 00 00        LDU    #$0000
32fa: 34 40           PSHS   U
32fc: 17 f2 48        LBSR   $2547
32ff: 32 62           LEAS   $2,S
3301: 16 00 51        LBRA   $3355
3304: be 23 bf        LDX    $23BF
3307: 30 88 1f        LEAX   $1F,X
330a: ae 84           LDX    ,X
330c: 8c 00 04        CMPX   #$0004
330f: 10 26 00 42     LBNE   $3355
3313: be 23 bf        LDX    $23BF
3316: 30 0a           LEAX   $A,X
3318: fe 23 bf        LDU    $23BF
331b: 33 4f           LEAU   $F,U
331d: ef 66           STU    $6,S
331f: ce 22 1c        LDU    #$221C
3322: 1f 12           TFR    X,Y
3324: ae 66           LDX    $6,S
3326: cc 00 06        LDD    #$0006
3329: 34 76           PSHS   U,Y,X,D
332b: 17 60 98        LBSR   $93C6
332e: 32 68           LEAS   $8,S
3330: be 23 bf        LDX    $23BF
3333: 30 88 14        LEAX   $14,X
3336: e6 84           LDB    ,X
3338: c1 2d           CMPB   #$2D
333a: 10 26 00 08     LBNE   $3346
333e: c6 2b           LDB    #$2B
3340: f7 24 1e        STB    $241E
3343: 16 00 05        LBRA   $334B
3346: c6 2d           LDB    #$2D
3348: f7 24 1e        STB    $241E
334b: ce 00 00        LDU    #$0000
334e: 34 40           PSHS   U
3350: 17 f1 f4        LBSR   $2547
3353: 32 62           LEAS   $2,S
3355: ce 00 00        LDU    #$0000
3358: 34 40           PSHS   U
335a: 17 e4 54        LBSR   $17B1
335d: 32 62           LEAS   $2,S
335f: ce 00 01        LDU    #$0001
3362: 10 8e 00 02     LDY    #$0002
3366: 34 60           PSHS   U,Y
3368: be 3b 85        LDX    $3B85
336b: ad 84           JSR    ,X
336d: 32 64           LEAS   $4,S
336f: 16 03 b3        LBRA   $3725
3372: cc 00 03        LDD    #$0003
3375: fd 22 15        STD    $2215
3378: be 23 bf        LDX    $23BF
337b: 30 88 19        LEAX   $19,X
337e: ae 84           LDX    ,X
3380: 16 00 b8        LBRA   $343B
3383: ae e9 00 0e     LDX    $000E,S
3387: 8c 00 00        CMPX   #$0000
338a: 10 27 00 22     LBEQ   $33B0
338e: be 23 bf        LDX    $23BF
3391: 30 88 15        LEAX   $15,X
3394: fe 23 bf        LDU    $23BF
3397: 33 c8 1b        LEAU   $1B,U
339a: ae 84           LDX    ,X
339c: 1f 10           TFR    X,D
339e: e3 c4           ADDD   ,U
33a0: fd 22 1a        STD    $221A
33a3: ce 00 00        LDU    #$0000
33a6: 34 40           PSHS   U
33a8: 17 f3 07        LBSR   $26B2
33ab: 32 62           LEAS   $2,S
33ad: 16 00 2c        LBRA   $33DC
33b0: be 23 bf        LDX    $23BF
33b3: 30 88 15        LEAX   $15,X
33b6: fe 23 bf        LDU    $23BF
33b9: 33 c8 1b        LEAU   $1B,U
33bc: ae 84           LDX    ,X
33be: 1f 10           TFR    X,D
33c0: a3 c4           SUBD   ,U
33c2: ed 62           STD    $2,S
33c4: ae 62           LDX    $2,S
33c6: 8c 00 00        CMPX   #$0000
33c9: 10 2d 00 0f     LBLT   $33DC
33cd: ec 62           LDD    $2,S
33cf: fd 22 1a        STD    $221A
33d2: ce 00 00        LDU    #$0000
33d5: 34 40           PSHS   U
33d7: 17 f2 d8        LBSR   $26B2
33da: 32 62           LEAS   $2,S
33dc: 16 00 6b        LBRA   $344A
33df: ae e9 00 0e     LDX    $000E,S
33e3: 8c 00 00        CMPX   #$0000
33e6: 10 27 00 22     LBEQ   $340C
33ea: be 23 bf        LDX    $23BF
33ed: 30 88 17        LEAX   $17,X
33f0: fe 23 bf        LDU    $23BF
33f3: 33 c8 1d        LEAU   $1D,U
33f6: ae 84           LDX    ,X
33f8: 1f 10           TFR    X,D
33fa: e3 c4           ADDD   ,U
33fc: fd 22 1a        STD    $221A
33ff: ce 00 00        LDU    #$0000
3402: 34 40           PSHS   U
3404: 17 f2 ab        LBSR   $26B2
3407: 32 62           LEAS   $2,S
3409: 16 00 2c        LBRA   $3438
340c: be 23 bf        LDX    $23BF
340f: 30 88 17        LEAX   $17,X
3412: fe 23 bf        LDU    $23BF
3415: 33 c8 1d        LEAU   $1D,U
3418: ae 84           LDX    ,X
341a: 1f 10           TFR    X,D
341c: a3 c4           SUBD   ,U
341e: ed 62           STD    $2,S
3420: ae 62           LDX    $2,S
3422: 8c 00 00        CMPX   #$0000
3425: 10 2d 00 0f     LBLT   $3438
3429: ec 62           LDD    $2,S
342b: fd 22 1a        STD    $221A
342e: ce 00 00        LDU    #$0000
3431: 34 40           PSHS   U
3433: 17 f2 7c        LBSR   $26B2
3436: 32 62           LEAS   $2,S
3438: 16 00 0f        LBRA   $344A
343b: 8c 00 03        CMPX   #$0003
343e: 10 27 ff 41     LBEQ   $3383
3442: 8c 00 04        CMPX   #$0004
3445: 27 98           BEQ    $33DF
3447: 16 00 00        LBRA   $344A
344a: ce 00 00        LDU    #$0000
344d: 34 40           PSHS   U
344f: 17 e4 02        LBSR   $1854
3452: 32 62           LEAS   $2,S
3454: ce 00 02        LDU    #$0002
3457: 10 8e 00 02     LDY    #$0002
345b: 34 60           PSHS   U,Y
345d: be 3b 85        LDX    $3B85
3460: ad 84           JSR    ,X
3462: 32 64           LEAS   $4,S
3464: 16 02 be        LBRA   $3725
3467: ae e9 00 0e     LDX    $000E,S
346b: 8c 00 00        CMPX   #$0000
346e: 10 27 00 14     LBEQ   $3486
3472: f6 24 f4        LDB    $24F4
3475: c1 00           CMPB   #$00
3477: 10 27 00 08     LBEQ   $3483
347b: f6 24 f4        LDB    $24F4
347e: c0 01           SUBB   #$01
3480: f7 24 f4        STB    $24F4
3483: 16 00 11        LBRA   $3497
3486: f6 24 f4        LDB    $24F4
3489: c1 0f           CMPB   #$0F
348b: 10 27 00 08     LBEQ   $3497
348f: f6 24 f4        LDB    $24F4
3492: cb 01           ADDB   #$01
3494: f7 24 f4        STB    $24F4
3497: ce 00 00        LDU    #$0000
349a: 34 40           PSHS   U
349c: 17 d3 64        LBSR   $0803
349f: 32 62           LEAS   $2,S
34a1: ce 00 0a        LDU    #$000A
34a4: 10 8e 00 02     LDY    #$0002
34a8: 34 60           PSHS   U,Y
34aa: be 3b 85        LDX    $3B85
34ad: ad 84           JSR    ,X
34af: 32 64           LEAS   $4,S
34b1: 16 02 71        LBRA   $3725
34b4: cc 00 0c        LDD    #$000C
34b7: fd 22 15        STD    $2215
34ba: ae e9 00 0e     LDX    $000E,S
34be: 8c 00 00        CMPX   #$0000
34c1: 10 27 00 22     LBEQ   $34E7
34c5: ae 64           LDX    $4,S
34c7: 30 04           LEAX   $4,X
34c9: ce 22 1c        LDU    #$221C
34cc: 10 8e 26 71     LDY    #$2671
34d0: cc 00 06        LDD    #$0006
34d3: 34 76           PSHS   U,Y,X,D
34d5: 17 5e ba        LBSR   $9392
34d8: 32 68           LEAS   $8,S
34da: ce 00 00        LDU    #$0000
34dd: 34 40           PSHS   U
34df: 17 d7 1c        LBSR   $0BFE
34e2: 32 62           LEAS   $2,S
34e4: 16 00 29        LBRA   $3510
34e7: ae 64           LDX    $4,S
34e9: 30 04           LEAX   $4,X
34eb: af 66           STX    $6,S
34ed: ce 22 1c        LDU    #$221C
34f0: 10 8e 26 71     LDY    #$2671
34f4: ae 66           LDX    $6,S
34f6: cc 00 06        LDD    #$0006
34f9: 34 76           PSHS   U,Y,X,D
34fb: 17 5e c8        LBSR   $93C6
34fe: 32 68           LEAS   $8,S
3500: c1 00           CMPB   #$00
3502: 10 26 00 0a     LBNE   $3510
3506: ce 00 00        LDU    #$0000
3509: 34 40           PSHS   U
350b: 17 d6 f0        LBSR   $0BFE
350e: 32 62           LEAS   $2,S
3510: ce 00 00        LDU    #$0000
3513: 34 40           PSHS   U
3515: 17 cf 49        LBSR   $0461
3518: 32 62           LEAS   $2,S
351a: ce 00 06        LDU    #$0006
351d: 10 8e 00 02     LDY    #$0002
3521: 34 60           PSHS   U,Y
3523: be 3b 85        LDX    $3B85
3526: ad 84           JSR    ,X
3528: 32 64           LEAS   $4,S
352a: 16 01 f8        LBRA   $3725
352d: cc 00 0d        LDD    #$000D
3530: fd 22 15        STD    $2215
3533: ae 64           LDX    $4,S
3535: 30 0a           LEAX   $A,X
3537: e6 84           LDB    ,X
3539: f7 24 1e        STB    $241E
353c: be 25 14        LDX    $2514
353f: 8c 00 04        CMPX   #$0004
3542: 10 26 00 0c     LBNE   $3552
3546: f6 24 1e        LDB    $241E
3549: c1 2d           CMPB   #$2D
354b: 10 26 00 03     LBNE   $3552
354f: 16 00 03        LBRA   $3555
3552: 16 00 0c        LBRA   $3561
3555: ec e9 00 0e     LDD    $000E,S
3559: 88 00           EORA   #$00
355b: c8 01           EORB   #$01
355d: ed e9 00 0e     STD    $000E,S
3561: ae e9 00 0e     LDX    $000E,S
3565: 8c 00 00        CMPX   #$0000
3568: 10 27 00 2c     LBEQ   $3598
356c: ae 64           LDX    $4,S
356e: 30 07           LEAX   $7,X
3570: af 66           STX    $6,S
3572: ce 22 1c        LDU    #$221C
3575: 10 8e 26 74     LDY    #$2674
3579: ae 66           LDX    $6,S
357b: cc 00 06        LDD    #$0006
357e: 34 76           PSHS   U,Y,X,D
3580: 17 5e 0f        LBSR   $9392
3583: 32 68           LEAS   $8,S
3585: c1 00           CMPB   #$00
3587: 10 26 00 0a     LBNE   $3595
358b: ce 00 00        LDU    #$0000
358e: 34 40           PSHS   U
3590: 17 d7 42        LBSR   $0CD5
3593: 32 62           LEAS   $2,S
3595: 16 00 6f        LBRA   $3607
3598: ae 64           LDX    $4,S
359a: 30 07           LEAX   $7,X
359c: af 66           STX    $6,S
359e: ce 22 1c        LDU    #$221C
35a1: 10 8e 26 74     LDY    #$2674
35a5: ae 66           LDX    $6,S
35a7: cc 00 06        LDD    #$0006
35aa: 34 76           PSHS   U,Y,X,D
35ac: 17 5e 17        LBSR   $93C6
35af: 32 68           LEAS   $8,S
35b1: c1 00           CMPB   #$00
35b3: 10 26 00 0d     LBNE   $35C4
35b7: ce 00 00        LDU    #$0000
35ba: 34 40           PSHS   U
35bc: 17 d7 16        LBSR   $0CD5
35bf: 32 62           LEAS   $2,S
35c1: 16 00 43        LBRA   $3607
35c4: be 25 14        LDX    $2514
35c7: 8c 00 04        CMPX   #$0004
35ca: 10 26 00 39     LBNE   $3607
35ce: ae 64           LDX    $4,S
35d0: 30 07           LEAX   $7,X
35d2: ce 22 1c        LDU    #$221C
35d5: 1f 12           TFR    X,Y
35d7: 8e 26 74        LDX    #$2674
35da: cc 00 06        LDD    #$0006
35dd: 34 76           PSHS   U,Y,X,D
35df: 17 5d e4        LBSR   $93C6
35e2: 32 68           LEAS   $8,S
35e4: ae 64           LDX    $4,S
35e6: 30 0a           LEAX   $A,X
35e8: e6 84           LDB    ,X
35ea: c1 2d           CMPB   #$2D
35ec: 10 26 00 08     LBNE   $35F8
35f0: c6 2b           LDB    #$2B
35f2: f7 24 1e        STB    $241E
35f5: 16 00 05        LBRA   $35FD
35f8: c6 2d           LDB    #$2D
35fa: f7 24 1e        STB    $241E
35fd: ce 00 00        LDU    #$0000
3600: 34 40           PSHS   U
3602: 17 d6 d0        LBSR   $0CD5
3605: 32 62           LEAS   $2,S
3607: ce 00 00        LDU    #$0000
360a: 34 40           PSHS   U
360c: 17 cf 6a        LBSR   $0579
360f: 32 62           LEAS   $2,S
3611: ce 00 07        LDU    #$0007
3614: 10 8e 00 02     LDY    #$0002
3618: 34 60           PSHS   U,Y
361a: be 3b 85        LDX    $3B85
361d: ad 84           JSR    ,X
361f: 32 64           LEAS   $4,S
3621: 16 01 01        LBRA   $3725
3624: cc 00 0e        LDD    #$000E
3627: fd 22 15        STD    $2215
362a: ae 64           LDX    $4,S
362c: 30 0d           LEAX   $D,X
362e: ae 84           LDX    ,X
3630: bf 22 21        STX    $2221
3633: be 26 79        LDX    $2679
3636: bc 22 21        CMPX   $2221
3639: 10 27 00 30     LBEQ   $366D
363d: be 26 79        LDX    $2679
3640: 8c 00 03        CMPX   #$0003
3643: 10 26 00 13     LBNE   $365A
3647: fe 26 7d        LDU    $267D
364a: 10 8e 00 02     LDY    #$0002
364e: 34 60           PSHS   U,Y
3650: 17 5c 73        LBSR   $92C6
3653: 32 64           LEAS   $4,S
3655: ed 62           STD    $2,S
3657: 16 00 10        LBRA   $366A
365a: fe 26 7d        LDU    $267D
365d: 10 8e 00 02     LDY    #$0002
3661: 34 60           PSHS   U,Y
3663: 17 5c 43        LBSR   $92A9
3666: 32 64           LEAS   $4,S
3668: ed 62           STD    $2,S
366a: 16 00 05        LBRA   $3672
366d: fc 26 7d        LDD    $267D
3670: ed 62           STD    $2,S
3672: ae e9 00 0e     LDX    $000E,S
3676: 8c 00 00        CMPX   #$0000
3679: 10 27 00 1a     LBEQ   $3697
367d: ae 64           LDX    $4,S
367f: 30 0b           LEAX   $B,X
3681: ae 84           LDX    ,X
3683: 1f 10           TFR    X,D
3685: e3 62           ADDD   $2,S
3687: fd 22 1a        STD    $221A
368a: ce 00 00        LDU    #$0000
368d: 34 40           PSHS   U
368f: 17 d7 35        LBSR   $0DC7
3692: 32 62           LEAS   $2,S
3694: 16 00 24        LBRA   $36BB
3697: ae 64           LDX    $4,S
3699: 30 0b           LEAX   $B,X
369b: ae 84           LDX    ,X
369d: 1f 10           TFR    X,D
369f: a3 62           SUBD   $2,S
36a1: ed 62           STD    $2,S
36a3: ae 62           LDX    $2,S
36a5: 8c 00 00        CMPX   #$0000
36a8: 10 2d 00 0f     LBLT   $36BB
36ac: ec 62           LDD    $2,S
36ae: fd 22 1a        STD    $221A
36b1: ce 00 00        LDU    #$0000
36b4: 34 40           PSHS   U
36b6: 17 d7 0e        LBSR   $0DC7
36b9: 32 62           LEAS   $2,S
36bb: ce 00 00        LDU    #$0000
36be: 34 40           PSHS   U
36c0: 17 cf cb        LBSR   $068E
36c3: 32 62           LEAS   $2,S
36c5: ce 00 08        LDU    #$0008
36c8: 10 8e 00 02     LDY    #$0002
36cc: 34 60           PSHS   U,Y
36ce: be 3b 85        LDX    $3B85
36d1: ad 84           JSR    ,X
36d3: 32 64           LEAS   $4,S
36d5: 16 00 4d        LBRA   $3725
36d8: c6 04           LDB    #$04
36da: 1d              SEX
36db: 1f 03           TFR    D,U
36dd: 10 8e 00 02     LDY    #$0002
36e1: 34 60           PSHS   U,Y
36e3: 17 4d 18        LBSR   $83FE
36e6: 32 64           LEAS   $4,S
36e8: 16 00 3a        LBRA   $3725
36eb: 16 00 37        LBRA   $3725
36ee: 8c 00 12        CMPX   #$0012
36f1: 2e e5           BGT    $36D8
36f3: 1f 10           TFR    X,D
36f5: 83 00 01        SUBD   #$0001
36f8: 2d de           BLT    $36D8
36fa: 8e 77 01        LDX    #$7701
36fd: 58              ASLB
36fe: 49              ROLA
36ff: 6e 9b           JMP    [D,X]
3701: 71 dd 72        NEG    $DD72
3704: 59              ROLB
3705: 73 78 76        COM    $7876
3708: d8 76           EORB   <$76
370a: d8 71           EORB   <$71
370c: d7 72           STB    <$72
370e: 53              COMB
370f: 73 72 76        COM    $7276
3712: d8 76           EORB   <$76
3714: d8 76           EORB   <$76
3716: d8 74           EORB   <$74
3718: ba 75 33        ORA    $7533
371b: 76 2a 74        ROR    $2A74
371e: b4 75 2d        ANDA   $752D
3721: 76 24 74        ROR    $2474
3724: 67 32           ASR    -$E,Y
3726: 6a 39           DEC    -$7,Y
3728: 00 01           NEG    <$01
372a: 00 00           NEG    <$00
372c: 01 a9           NEG    <$A9
372e: 00 08           NEG    <$08
3730: 00 01           NEG    <$01
3732: 00 00           NEG    <$00
3734: 00 0f           NEG    <$0F
3736: fc 7f e5        LDD    $7FE5
3739: 17 86 14        LBSR   $BD50
373c: 6f 63           CLR    $3,S
373e: 6f 62           CLR    $2,S
3740: e6 62           LDB    $2,S
3742: c1 04           CMPB   #$04
3744: 10 24 00 5e     LBCC   $37A6
3748: e6 62           LDB    $2,S
374a: 4f              CLRA
374b: 10 a3 e9 00 09  CMPD   $0009,S
3750: 10 26 00 03     LBNE   $3757
3754: 16 00 47        LBRA   $379E
3757: ce 24 f5        LDU    #$24F5
375a: e6 62           LDB    $2,S
375c: 4f              CLRA
375d: 1f 02           TFR    D,Y
375f: 34 60           PSHS   U,Y
3761: 86 01           LDA    #$01
3763: 8e 7f df        LDX    #$7FDF
3766: 17 85 81        LBSR   $BCEA
3769: 30 88 21        LEAX   $21,X
376c: ae 84           LDX    ,X
376e: ac e9 00 0b     CMPX   $000B,S
3772: 10 26 00 21     LBNE   $3797
3776: ce 24 f5        LDU    #$24F5
3779: e6 62           LDB    $2,S
377b: 4f              CLRA
377c: 1f 02           TFR    D,Y
377e: 34 60           PSHS   U,Y
3780: 86 01           LDA    #$01
3782: 8e 7f df        LDX    #$7FDF
3785: 17 85 62        LBSR   $BCEA
3788: 30 88 1f        LEAX   $1F,X
378b: ae 84           LDX    ,X
378d: 8c 00 04        CMPX   #$0004
3790: 10 26 00 03     LBNE   $3797
3794: 16 00 03        LBRA   $379A
3797: 16 00 04        LBRA   $379E
379a: c6 01           LDB    #$01
379c: e7 63           STB    $3,S
379e: e6 62           LDB    $2,S
37a0: cb 01           ADDB   #$01
37a2: e7 62           STB    $2,S
37a4: 20 9a           BRA    $3740
37a6: e6 63           LDB    $3,S
37a8: e7 64           STB    $4,S
37aa: 32 65           LEAS   $5,S
37ac: 39              RTS
37ad: fc 7f e5        LDD    $7FE5
37b0: 17 85 9d        LBSR   $BD50
37b3: b6 24 0d        LDA    $240D
37b6: f6 24 0e        LDB    $240E
37b9: 17 85 c4        LBSR   $BD80
37bc: ed 62           STD    $2,S
37be: f6 24 0f        LDB    $240F
37c1: 4f              CLRA
37c2: e3 62           ADDD   $2,S
37c4: ed 62           STD    $2,S
37c6: f6 24 10        LDB    $2410
37c9: 4f              CLRA
37ca: e3 62           ADDD   $2,S
37cc: ed 62           STD    $2,S
37ce: f6 24 11        LDB    $2411
37d1: 4f              CLRA
37d2: e3 62           ADDD   $2,S
37d4: e7 64           STB    $4,S
37d6: 32 65           LEAS   $5,S
37d8: 39              RTS
37d9: fc 7f df        LDD    $7FDF
37dc: 17 85 71        LBSR   $BD50
37df: ae e9 00 07     LDX    $0007,S
37e3: 8c 00 07        CMPX   #$0007
37e6: 10 27 00 2f     LBEQ   $3819
37ea: ae e9 00 07     LDX    $0007,S
37ee: 8c 00 0a        CMPX   #$000A
37f1: 10 27 00 24     LBEQ   $3819
37f5: ae e9 00 07     LDX    $0007,S
37f9: 8c 00 08        CMPX   #$0008
37fc: 10 27 00 19     LBEQ   $3819
3800: ae e9 00 07     LDX    $0007,S
3804: 8c 00 09        CMPX   #$0009
3807: 10 27 00 0e     LBEQ   $3819
380b: ae e9 00 07     LDX    $0007,S
380f: 8c 00 0b        CMPX   #$000B
3812: 10 27 00 03     LBEQ   $3819
3816: 16 00 0a        LBRA   $3823
3819: c6 01           LDB    #$01
381b: e7 62           STB    $2,S
381d: 16 00 05        LBRA   $3825
3820: 16 00 02        LBRA   $3825
3823: 6f 62           CLR    $2,S
3825: e6 62           LDB    $2,S
3827: 32 63           LEAS   $3,S
3829: 39              RTS
382a: fc 7f e7        LDD    $7FE7
382d: 17 85 20        LBSR   $BD50
3830: ae e9 00 0a     LDX    $000A,S
3834: 16 00 58        LBRA   $388F
3837: cc 24 0d        LDD    #$240D
383a: ed 62           STD    $2,S
383c: 16 00 77        LBRA   $38B6
383f: cc 24 0f        LDD    #$240F
3842: ed 62           STD    $2,S
3844: 16 00 6f        LBRA   $38B6
3847: cc 24 10        LDD    #$2410
384a: ed 62           STD    $2,S
384c: 16 00 67        LBRA   $38B6
384f: cc 24 0e        LDD    #$240E
3852: ed 62           STD    $2,S
3854: 16 00 5f        LBRA   $38B6
3857: cc 24 11        LDD    #$2411
385a: ed 62           STD    $2,S
385c: 16 00 57        LBRA   $38B6
385f: cc 24 09        LDD    #$2409
3862: ed 62           STD    $2,S
3864: 16 00 4f        LBRA   $38B6
3867: cc 24 0a        LDD    #$240A
386a: ed 62           STD    $2,S
386c: 16 00 47        LBRA   $38B6
386f: cc 24 0b        LDD    #$240B
3872: ed 62           STD    $2,S
3874: 16 00 3f        LBRA   $38B6
3877: cc 24 0c        LDD    #$240C
387a: ed 62           STD    $2,S
387c: 16 00 37        LBRA   $38B6
387f: cc 24 08        LDD    #$2408
3882: ed 62           STD    $2,S
3884: 16 00 2f        LBRA   $38B6
3887: cc 24 08        LDD    #$2408
388a: ed 62           STD    $2,S
388c: 16 00 27        LBRA   $38B6
388f: 8c 00 10        CMPX   #$0010
3892: 2e f3           BGT    $3887
3894: 1f 10           TFR    X,D
3896: 83 00 07        SUBD   #$0007
3899: 2d ec           BLT    $3887
389b: 8e 78 a2        LDX    #$78A2
389e: 58              ASLB
389f: 49              ROLA
38a0: 6e 9b           JMP    [D,X]
38a2: 78 37 78        ASL    $3778
38a5: 3f              SWI
38a6: 78 47 78        ASL    $4778
38a9: 4f              CLRA
38aa: 78 57 78        ASL    $5778
38ad: 5f              CLRB
38ae: 78 67 78        ASL    $6778
38b1: 6f 78           CLR    -$8,S
38b3: 77 78 7f        ASR    $787F
38b6: ae 62           LDX    $2,S
38b8: af 64           STX    $4,S
38ba: 1f 10           TFR    X,D
38bc: 32 66           LEAS   $6,S
38be: 39              RTS
38bf: fc 7f e9        LDD    $7FE9
38c2: 17 84 8b        LBSR   $BD50
38c5: be 23 bf        LDX    $23BF
38c8: 30 88 21        LEAX   $21,X
38cb: ae 84           LDX    ,X
38cd: af 62           STX    $2,S
38cf: 6f 69           CLR    $9,S
38d1: ee e9 00 1a     LDU    $001A,S
38d5: 10 8e 00 02     LDY    #$0002
38d9: 34 60           PSHS   U,Y
38db: 17 fe fb        LBSR   $37D9
38de: 32 64           LEAS   $4,S
38e0: c1 00           CMPB   #$00
38e2: 10 27 00 5d     LBEQ   $3943
38e6: ae e9 00 18     LDX    $0018,S
38ea: 8c 00 00        CMPX   #$0000
38ed: 10 26 00 04     LBNE   $38F5
38f1: c6 65           LDB    #$65
38f3: e7 69           STB    $9,S
38f5: be 25 14        LDX    $2514
38f8: 8c 00 04        CMPX   #$0004
38fb: 10 26 00 04     LBNE   $3903
38ff: c6 66           LDB    #$66
3901: e7 69           STB    $9,S
3903: ce 24 f5        LDU    #$24F5
3906: 10 ae e9 00 18  LDY    $0018,S
390b: 34 60           PSHS   U,Y
390d: 86 01           LDA    #$01
390f: 8e 7f df        LDX    #$7FDF
3912: 17 83 d5        LBSR   $BCEA
3915: 30 88 1f        LEAX   $1F,X
3918: ae 84           LDX    ,X
391a: 8c 00 04        CMPX   #$0004
391d: 10 26 00 04     LBNE   $3925
3921: c6 67           LDB    #$67
3923: e7 69           STB    $9,S
3925: e6 69           LDB    $9,S
3927: c1 00           CMPB   #$00
3929: 10 27 00 13     LBEQ   $3940
392d: e6 69           LDB    $9,S
392f: 4f              CLRA
3930: 1f 03           TFR    D,U
3932: 10 8e 00 02     LDY    #$0002
3936: 34 60           PSHS   U,Y
3938: 17 4a c3        LBSR   $83FE
393b: 32 64           LEAS   $4,S
393d: 16 06 9b        LBRA   $3FDB
3940: 16 00 53        LBRA   $3996
3943: ae e9 00 1a     LDX    $001A,S
3947: 8c 00 10        CMPX   #$0010
394a: 10 27 00 48     LBEQ   $3996
394e: ce 24 f5        LDU    #$24F5
3951: 10 ae e9 00 18  LDY    $0018,S
3956: 34 60           PSHS   U,Y
3958: 86 01           LDA    #$01
395a: 8e 7f df        LDX    #$7FDF
395d: 17 83 8a        LBSR   $BCEA
3960: 30 88 1f        LEAX   $1F,X
3963: ae 84           LDX    ,X
3965: 8c 00 04        CMPX   #$0004
3968: 10 26 00 2a     LBNE   $3996
396c: ee e9 00 1a     LDU    $001A,S
3970: 10 ae e9 00 18  LDY    $0018,S
3975: 8e 00 04        LDX    #$0004
3978: 34 70           PSHS   U,Y,X
397a: 17 fd b9        LBSR   $3736
397d: 32 66           LEAS   $6,S
397f: c1 00           CMPB   #$00
3981: 10 27 00 11     LBEQ   $3996
3985: ce 00 99        LDU    #$0099
3988: 10 8e 00 02     LDY    #$0002
398c: 34 60           PSHS   U,Y
398e: 17 4a 6d        LBSR   $83FE
3991: 32 64           LEAS   $4,S
3993: 16 06 45        LBRA   $3FDB
3996: ae 62           LDX    $2,S
3998: ac e9 00 1a     CMPX   $001A,S
399c: 10 26 00 03     LBNE   $39A3
39a0: 16 06 38        LBRA   $3FDB
39a3: ee e9 00 1a     LDU    $001A,S
39a7: 10 8e 00 02     LDY    #$0002
39ab: 34 60           PSHS   U,Y
39ad: 17 4d b5        LBSR   $8765
39b0: 32 64           LEAS   $4,S
39b2: e7 66           STB    $6,S
39b4: e6 66           LDB    $6,S
39b6: 4f              CLRA
39b7: 10 83 00 ff     CMPD   #$00FF
39bb: 10 27 00 19     LBEQ   $39D8
39bf: a6 66           LDA    $6,S
39c1: c6 01           LDB    #$01
39c3: 17 83 ba        LBSR   $BD80
39c6: ed e8 10        STD    $10,S
39c9: f6 23 b2        LDB    $23B2
39cc: 4f              CLRA
39cd: 10 a3 e8 10     CMPD   $10,S
39d1: 10 24 00 03     LBCC   $39D8
39d5: 16 00 03        LBRA   $39DB
39d8: 16 00 13        LBRA   $39EE
39db: c6 68           LDB    #$68
39dd: 1d              SEX
39de: 1f 03           TFR    D,U
39e0: 10 8e 00 02     LDY    #$0002
39e4: 34 60           PSHS   U,Y
39e6: 17 4a 15        LBSR   $83FE
39e9: 32 64           LEAS   $4,S
39eb: 16 05 ed        LBRA   $3FDB
39ee: ae 62           LDX    $2,S
39f0: 8c 00 0a        CMPX   #$000A
39f3: 10 26 00 0c     LBNE   $3A03
39f7: f6 24 0e        LDB    $240E
39fa: c1 01           CMPB   #$01
39fc: 10 26 00 03     LBNE   $3A03
3a00: 16 00 03        LBRA   $3A06
3a03: 16 00 3f        LBRA   $3A45
3a06: be 23 bf        LDX    $23BF
3a09: 30 0a           LEAX   $A,X
3a0b: 1f 13           TFR    X,U
3a0d: 10 8e 24 ff     LDY    #$24FF
3a11: 8e 00 04        LDX    #$0004
3a14: 34 70           PSHS   U,Y,X
3a16: 17 59 64        LBSR   $937D
3a19: 32 66           LEAS   $6,S
3a1b: be 23 bf        LDX    $23BF
3a1e: 30 0f           LEAX   $F,X
3a20: 1f 13           TFR    X,U
3a22: 10 8e 25 04     LDY    #$2504
3a26: 8e 00 04        LDX    #$0004
3a29: 34 70           PSHS   U,Y,X
3a2b: 17 59 4f        LBSR   $937D
3a2e: 32 66           LEAS   $6,S
3a30: be 23 bf        LDX    $23BF
3a33: 30 0d           LEAX   $D,X
3a35: ae 84           LDX    ,X
3a37: bf 25 02        STX    $2502
3a3a: be 23 bf        LDX    $23BF
3a3d: 30 88 12        LEAX   $12,X
3a40: ae 84           LDX    ,X
3a42: bf 25 07        STX    $2507
3a45: ae 62           LDX    $2,S
3a47: 8c 00 10        CMPX   #$0010
3a4a: 10 27 00 3d     LBEQ   $3A8B
3a4e: be 23 bf        LDX    $23BF
3a51: 30 0a           LEAX   $A,X
3a53: ce ea 58        LDU    #$EA58
3a56: 1f 12           TFR    X,Y
3a58: 8e 00 04        LDX    #$0004
3a5b: 34 70           PSHS   U,Y,X
3a5d: 17 59 1d        LBSR   $937D
3a60: 32 66           LEAS   $6,S
3a62: be 23 bf        LDX    $23BF
3a65: 30 0f           LEAX   $F,X
3a67: ce ea 58        LDU    #$EA58
3a6a: 1f 12           TFR    X,Y
3a6c: 8e 00 04        LDX    #$0004
3a6f: 34 70           PSHS   U,Y,X
3a71: 17 59 09        LBSR   $937D
3a74: 32 66           LEAS   $6,S
3a76: be 23 bf        LDX    $23BF
3a79: 30 0d           LEAX   $D,X
3a7b: cc 00 0d        LDD    #$000D
3a7e: ed 84           STD    ,X
3a80: be 23 bf        LDX    $23BF
3a83: 30 88 12        LEAX   $12,X
3a86: cc 00 0d        LDD    #$000D
3a89: ed 84           STD    ,X
3a8b: be 23 bf        LDX    $23BF
3a8e: 30 0a           LEAX   $A,X
3a90: 1f 13           TFR    X,U
3a92: 10 ae e9 00 18  LDY    $0018,S
3a97: 8e 00 04        LDX    #$0004
3a9a: 34 70           PSHS   U,Y,X
3a9c: 17 45 ca        LBSR   $8069
3a9f: 32 66           LEAS   $6,S
3aa1: ee 62           LDU    $2,S
3aa3: 10 8e 00 02     LDY    #$0002
3aa7: 34 60           PSHS   U,Y
3aa9: 17 fd 7e        LBSR   $382A
3aac: 32 64           LEAS   $4,S
3aae: 1f 01           TFR    D,X
3ab0: af 67           STX    $7,S
3ab2: e6 f8 07        LDB    [$07,S]
3ab5: c0 01           SUBB   #$01
3ab7: e7 f8 07        STB    [$07,S]
3aba: e6 f8 07        LDB    [$07,S]
3abd: c1 00           CMPB   #$00
3abf: 10 26 00 53     LBNE   $3B16
3ac3: c6 04           LDB    #$04
3ac5: 1d              SEX
3ac6: 1f 03           TFR    D,U
3ac8: 10 ae 62        LDY    $2,S
3acb: 8e 00 04        LDX    #$0004
3ace: 34 70           PSHS   U,Y,X
3ad0: 17 4c dd        LBSR   $87B0
3ad3: 32 66           LEAS   $6,S
3ad5: ae 62           LDX    $2,S
3ad7: 8c 00 08        CMPX   #$0008
3ada: 10 26 00 0f     LBNE   $3AED
3ade: 5f              CLRB
3adf: 1d              SEX
3ae0: 1f 03           TFR    D,U
3ae2: 10 8e 00 02     LDY    #$0002
3ae6: 34 60           PSHS   U,Y
3ae8: 17 68 84        LBSR   $A36F
3aeb: 32 64           LEAS   $4,S
3aed: ae 62           LDX    $2,S
3aef: 8c 00 07        CMPX   #$0007
3af2: 10 27 00 0c     LBEQ   $3B02
3af6: ae 62           LDX    $2,S
3af8: 8c 00 0a        CMPX   #$000A
3afb: 10 27 00 03     LBEQ   $3B02
3aff: 16 00 11        LBRA   $3B13
3b02: ce 24 ff        LDU    #$24FF
3b05: 5f              CLRB
3b06: 1d              SEX
3b07: 1f 02           TFR    D,Y
3b09: 8e 00 04        LDX    #$0004
3b0c: 34 70           PSHS   U,Y,X
3b0e: 17 45 58        LBSR   $8069
3b11: 32 66           LEAS   $6,S
3b13: 16 00 61        LBRA   $3B77
3b16: ae 62           LDX    $2,S
3b18: 8c 00 10        CMPX   #$0010
3b1b: 10 27 00 58     LBEQ   $3B77
3b1f: ee 62           LDU    $2,S
3b21: 10 ae e9 00 18  LDY    $0018,S
3b26: e6 f8 07        LDB    [$07,S]
3b29: 4f              CLRA
3b2a: 1f 01           TFR    D,X
3b2c: cc 00 06        LDD    #$0006
3b2f: 34 76           PSHS   U,Y,X,D
3b31: 17 66 51        LBSR   $A185
3b34: 32 68           LEAS   $8,S
3b36: ae 62           LDX    $2,S
3b38: 8c 00 08        CMPX   #$0008
3b3b: 10 26 00 0a     LBNE   $3B49
3b3f: ce 00 00        LDU    #$0000
3b42: 34 40           PSHS   U
3b44: 17 3f 9c        LBSR   $7AE3
3b47: 32 62           LEAS   $2,S
3b49: ae 62           LDX    $2,S
3b4b: 8c 00 0a        CMPX   #$000A
3b4e: 10 27 00 16     LBEQ   $3B68
3b52: ee 62           LDU    $2,S
3b54: 10 8e 00 02     LDY    #$0002
3b58: 34 60           PSHS   U,Y
3b5a: 17 fc 7c        LBSR   $37D9
3b5d: 32 64           LEAS   $4,S
3b5f: c1 00           CMPB   #$00
3b61: 10 27 00 03     LBEQ   $3B68
3b65: 16 00 0f        LBRA   $3B77
3b68: ee e9 00 18     LDU    $0018,S
3b6c: 10 8e 00 02     LDY    #$0002
3b70: 34 60           PSHS   U,Y
3b72: 17 42 e7        LBSR   $7E5C
3b75: 32 64           LEAS   $4,S
3b77: be 23 bf        LDX    $23BF
3b7a: 30 88 21        LEAX   $21,X
3b7d: cc 00 10        LDD    #$0010
3b80: ed 84           STD    ,X
3b82: ae e9 00 1a     LDX    $001A,S
3b86: 8c 00 07        CMPX   #$0007
3b89: 10 26 00 0c     LBNE   $3B99
3b8d: f6 24 0e        LDB    $240E
3b90: c1 00           CMPB   #$00
3b92: 10 27 00 03     LBEQ   $3B99
3b96: 16 00 1a        LBRA   $3BB3
3b99: ae e9 00 1a     LDX    $001A,S
3b9d: 8c 00 0a        CMPX   #$000A
3ba0: 10 26 00 0c     LBNE   $3BB0
3ba4: f6 24 0d        LDB    $240D
3ba7: c1 00           CMPB   #$00
3ba9: 10 27 00 03     LBEQ   $3BB0
3bad: 16 00 03        LBRA   $3BB3
3bb0: 16 00 17        LBRA   $3BCA
3bb3: c6 69           LDB    #$69
3bb5: 1d              SEX
3bb6: 1f 03           TFR    D,U
3bb8: 10 8e 00 02     LDY    #$0002
3bbc: 34 60           PSHS   U,Y
3bbe: 17 48 3d        LBSR   $83FE
3bc1: 32 64           LEAS   $4,S
3bc3: cc 00 10        LDD    #$0010
3bc6: ed e9 00 1a     STD    $001A,S
3bca: ee 62           LDU    $2,S
3bcc: 10 8e 00 02     LDY    #$0002
3bd0: 34 60           PSHS   U,Y
3bd2: 17 7c 17        LBSR   $B7EC
3bd5: 32 64           LEAS   $4,S
3bd7: e6 f8 07        LDB    [$07,S]
3bda: c1 00           CMPB   #$00
3bdc: 10 26 00 3b     LBNE   $3C1B
3be0: ee 62           LDU    $2,S
3be2: 10 8e 00 02     LDY    #$0002
3be6: 34 60           PSHS   U,Y
3be8: 17 4b 7a        LBSR   $8765
3beb: 32 64           LEAS   $4,S
3bed: e7 6c           STB    $C,S
3bef: e6 6c           LDB    $C,S
3bf1: 4f              CLRA
3bf2: 10 83 00 ff     CMPD   #$00FF
3bf6: 10 27 00 0b     LBEQ   $3C05
3bfa: e6 6c           LDB    $C,S
3bfc: c1 03           CMPB   #$03
3bfe: 10 22 00 03     LBHI   $3C05
3c02: 16 00 03        LBRA   $3C08
3c05: 16 00 13        LBRA   $3C1B
3c08: 5f              CLRB
3c09: 1d              SEX
3c0a: 1f 03           TFR    D,U
3c0c: e6 6c           LDB    $C,S
3c0e: 4f              CLRA
3c0f: 1f 02           TFR    D,Y
3c11: 8e 00 04        LDX    #$0004
3c14: 34 70           PSHS   U,Y,X
3c16: 17 3a 62        LBSR   $767B
3c19: 32 66           LEAS   $6,S
3c1b: ee e9 00 1a     LDU    $001A,S
3c1f: 10 8e 00 02     LDY    #$0002
3c23: 34 60           PSHS   U,Y
3c25: 17 fc 02        LBSR   $382A
3c28: 32 64           LEAS   $4,S
3c2a: 1f 01           TFR    D,X
3c2c: af 67           STX    $7,S
3c2e: 6f 69           CLR    $9,S
3c30: 6f 6a           CLR    $A,S
3c32: e6 f8 07        LDB    [$07,S]
3c35: c1 00           CMPB   #$00
3c37: 10 27 00 0e     LBEQ   $3C49
3c3b: ae e9 00 1a     LDX    $001A,S
3c3f: 8c 00 10        CMPX   #$0010
3c42: 10 27 00 03     LBEQ   $3C49
3c46: 16 00 03        LBRA   $3C4C
3c49: 16 00 4c        LBRA   $3C98
3c4c: ee e9 00 1a     LDU    $001A,S
3c50: 10 ae e9 00 18  LDY    $0018,S
3c55: e6 f8 07        LDB    [$07,S]
3c58: 4f              CLRA
3c59: 1f 01           TFR    D,X
3c5b: cc 00 06        LDD    #$0006
3c5e: 34 76           PSHS   U,Y,X,D
3c60: 17 63 c6        LBSR   $A029
3c63: 32 68           LEAS   $8,S
3c65: c1 00           CMPB   #$00
3c67: 10 27 00 2a     LBEQ   $3C95
3c6b: c6 6a           LDB    #$6A
3c6d: 1d              SEX
3c6e: 1f 03           TFR    D,U
3c70: 10 8e 00 02     LDY    #$0002
3c74: 34 60           PSHS   U,Y
3c76: 17 47 85        LBSR   $83FE
3c79: 32 64           LEAS   $4,S
3c7b: cc 00 10        LDD    #$0010
3c7e: ed e9 00 1a     STD    $001A,S
3c82: ee e9 00 1a     LDU    $001A,S
3c86: 10 8e 00 02     LDY    #$0002
3c8a: 34 60           PSHS   U,Y
3c8c: 17 fb 9b        LBSR   $382A
3c8f: 32 64           LEAS   $4,S
3c91: 1f 01           TFR    D,X
3c93: af 67           STX    $7,S
3c95: 16 01 58        LBRA   $3DF0
3c98: ae e9 00 1a     LDX    $001A,S
3c9c: 16 00 e0        LBRA   $3D7F
3c9f: fc 22 02        LDD    $2202
3ca2: 84 00           ANDA   #$00
3ca4: c4 40           ANDB   #$40
3ca6: 10 83 00 00     CMPD   #$0000
3caa: 10 27 00 07     LBEQ   $3CB5
3cae: c6 01           LDB    #$01
3cb0: e7 69           STB    $9,S
3cb2: 16 00 ef        LBRA   $3DA4
3cb5: c6 01           LDB    #$01
3cb7: e7 6a           STB    $A,S
3cb9: 16 00 e8        LBRA   $3DA4
3cbc: fc 22 02        LDD    $2202
3cbf: 84 00           ANDA   #$00
3cc1: c4 80           ANDB   #$80
3cc3: 10 83 00 00     CMPD   #$0000
3cc7: 10 27 00 04     LBEQ   $3CCF
3ccb: c6 01           LDB    #$01
3ccd: e7 69           STB    $9,S
3ccf: 16 00 d2        LBRA   $3DA4
3cd2: fc 22 02        LDD    $2202
3cd5: 84 00           ANDA   #$00
3cd7: c4 40           ANDB   #$40
3cd9: 10 83 00 00     CMPD   #$0000
3cdd: 10 27 00 07     LBEQ   $3CE8
3ce1: c6 01           LDB    #$01
3ce3: e7 69           STB    $9,S
3ce5: 16 00 bc        LBRA   $3DA4
3ce8: ce ea 58        LDU    #$EA58
3ceb: 10 8e 24 ff     LDY    #$24FF
3cef: 8e 00 04        LDX    #$0004
3cf2: 34 70           PSHS   U,Y,X
3cf4: 17 56 86        LBSR   $937D
3cf7: 32 66           LEAS   $6,S
3cf9: ce ea 58        LDU    #$EA58
3cfc: 10 8e 25 04     LDY    #$2504
3d00: 8e 00 04        LDX    #$0004
3d03: 34 70           PSHS   U,Y,X
3d05: 17 56 75        LBSR   $937D
3d08: 32 66           LEAS   $6,S
3d0a: cc 00 0e        LDD    #$000E
3d0d: fd 25 02        STD    $2502
3d10: cc 00 0e        LDD    #$000E
3d13: fd 25 07        STD    $2507
3d16: c6 01           LDB    #$01
3d18: e7 6a           STB    $A,S
3d1a: 16 00 87        LBRA   $3DA4
3d1d: fc 22 02        LDD    $2202
3d20: 84 00           ANDA   #$00
3d22: c4 20           ANDB   #$20
3d24: 10 83 00 00     CMPD   #$0000
3d28: 10 27 00 04     LBEQ   $3D30
3d2c: c6 01           LDB    #$01
3d2e: e7 69           STB    $9,S
3d30: ce 24 f5        LDU    #$24F5
3d33: 10 ae e9 00 18  LDY    $0018,S
3d38: 34 60           PSHS   U,Y
3d3a: 86 01           LDA    #$01
3d3c: 8e 7f df        LDX    #$7FDF
3d3f: 17 7f a8        LBSR   $BCEA
3d42: af e8 12        STX    $12,S
3d45: 33 6d           LEAU   $D,S
3d47: 10 ae e8 12     LDY    $12,S
3d4b: 8e ea 5f        LDX    #$EA5F
3d4e: cc 00 06        LDD    #$0006
3d51: 34 76           PSHS   U,Y,X,D
3d53: 17 56 70        LBSR   $93C6
3d56: 32 68           LEAS   $8,S
3d58: c1 00           CMPB   #$00
3d5a: 10 27 00 04     LBEQ   $3D62
3d5e: c6 02           LDB    #$02
3d60: e7 69           STB    $9,S
3d62: 16 00 3f        LBRA   $3DA4
3d65: c6 01           LDB    #$01
3d67: 1d              SEX
3d68: 1f 03           TFR    D,U
3d6a: e6 66           LDB    $6,S
3d6c: 4f              CLRA
3d6d: 1f 02           TFR    D,Y
3d6f: 8e 00 04        LDX    #$0004
3d72: 34 70           PSHS   U,Y,X
3d74: 17 39 04        LBSR   $767B
3d77: 32 66           LEAS   $6,S
3d79: 16 00 28        LBRA   $3DA4
3d7c: 16 00 25        LBRA   $3DA4
3d7f: 8c 00 0f        CMPX   #$000F
3d82: 2e f8           BGT    $3D7C
3d84: 1f 10           TFR    X,D
3d86: 83 00 07        SUBD   #$0007
3d89: 2d f1           BLT    $3D7C
3d8b: 8e 7d 92        LDX    #$7D92
3d8e: 58              ASLB
3d8f: 49              ROLA
3d90: 6e 9b           JMP    [D,X]
3d92: 7c 9f 7d        INC    $9F7D
3d95: 7c 7c bc        INC    $7CBC
3d98: 7c d2 7d        INC    $D27D
3d9b: 1d              SEX
3d9c: 7d 65 7d        TST    $657D
3d9f: 65 7d           LSR    -$3,S
3da1: 65 7d           LSR    -$3,S
3da3: 65 e6           LSR    A,S
3da5: 69 c1           ROL    ,U++
3da7: 00 10           NEG    <$10
3da9: 27 00           BEQ    $3DAB
3dab: 31 86           LEAY   A,X
3dad: 6a e6           DEC    A,S
3daf: 69 17           ROL    -$9,X
3db1: 7f cd 1f        CLR    $CD1F
3db4: 03 10           COM    <$10
3db6: 8e 00 02        LDX    #$0002
3db9: 34 60           PSHS   U,Y
3dbb: 17 46 40        LBSR   $83FE
3dbe: 32 64           LEAS   $4,S
3dc0: cc 00 10        LDD    #$0010
3dc3: ed e9 00 1a     STD    $001A,S
3dc7: ee e9 00 1a     LDU    $001A,S
3dcb: 10 8e 00 02     LDY    #$0002
3dcf: 34 60           PSHS   U,Y
3dd1: 17 fa 56        LBSR   $382A
3dd4: 32 64           LEAS   $4,S
3dd6: 1f 01           TFR    D,X
3dd8: af 67           STX    $7,S
3dda: 16 00 13        LBRA   $3DF0
3ddd: ee e9 00 18     LDU    $0018,S
3de1: 10 ae e9 00 1a  LDY    $001A,S
3de6: 8e 00 04        LDX    #$0004
3de9: 34 70           PSHS   U,Y,X
3deb: 17 49 c2        LBSR   $87B0
3dee: 32 66           LEAS   $6,S
3df0: e6 f8 07        LDB    [$07,S]
3df3: cb 01           ADDB   #$01
3df5: e7 f8 07        STB    [$07,S]
3df8: be 23 bf        LDX    $23BF
3dfb: 30 88 21        LEAX   $21,X
3dfe: ec e9 00 1a     LDD    $001A,S
3e02: ed 84           STD    ,X
3e04: ae e9 00 1a     LDX    $001A,S
3e08: 16 00 5a        LBRA   $3E65
3e0b: cc 00 0b        LDD    #$000B
3e0e: ed 64           STD    $4,S
3e10: 16 00 79        LBRA   $3E8C
3e13: cc 00 02        LDD    #$0002
3e16: ed 64           STD    $4,S
3e18: 16 00 71        LBRA   $3E8C
3e1b: cc 00 03        LDD    #$0003
3e1e: ed 64           STD    $4,S
3e20: 16 00 69        LBRA   $3E8C
3e23: cc 00 05        LDD    #$0005
3e26: ed 64           STD    $4,S
3e28: 16 00 61        LBRA   $3E8C
3e2b: cc 00 0f        LDD    #$000F
3e2e: ed 64           STD    $4,S
3e30: 16 00 59        LBRA   $3E8C
3e33: ae e9 00 18     LDX    $0018,S
3e37: 8c 00 00        CMPX   #$0000
3e3a: 10 26 00 0c     LBNE   $3E4A
3e3e: f6 24 0e        LDB    $240E
3e41: c1 00           CMPB   #$00
3e43: 10 27 00 03     LBEQ   $3E4A
3e47: 16 00 03        LBRA   $3E4D
3e4a: 16 00 08        LBRA   $3E55
3e4d: cc 00 0e        LDD    #$000E
3e50: ed 64           STD    $4,S
3e52: 16 00 05        LBRA   $3E5A
3e55: cc 00 05        LDD    #$0005
3e58: ed 64           STD    $4,S
3e5a: 16 00 2f        LBRA   $3E8C
3e5d: cc 00 0d        LDD    #$000D
3e60: ed 64           STD    $4,S
3e62: 16 00 27        LBRA   $3E8C
3e65: 8c 00 10        CMPX   #$0010
3e68: 2e f3           BGT    $3E5D
3e6a: 1f 10           TFR    X,D
3e6c: 83 00 07        SUBD   #$0007
3e6f: 2d ec           BLT    $3E5D
3e71: 8e 7e 78        LDX    #$7E78
3e74: 58              ASLB
3e75: 49              ROLA
3e76: 6e 9b           JMP    [D,X]
3e78: 7e 0b 7e        JMP    $0B7E
3e7b: 13              SYNC
3e7c: 7e 1b 7e        JMP    $1B7E
3e7f: 23 7e           BLS    $3EFF
3e81: 2b 7e           BMI    $3F01
3e83: 33 7e           LEAU   -$2,S
3e85: 33 7e           LEAU   -$2,S
3e87: 33 7e           LEAU   -$2,S
3e89: 33 7e           LEAU   -$2,S
3e8b: 5d              TSTB
3e8c: be 23 bf        LDX    $23BF
3e8f: 30 0d           LEAX   $D,X
3e91: ec 64           LDD    $4,S
3e93: ed 84           STD    ,X
3e95: be 23 bf        LDX    $23BF
3e98: 30 88 12        LEAX   $12,X
3e9b: ec 64           LDD    $4,S
3e9d: ed 84           STD    ,X
3e9f: e6 6a           LDB    $A,S
3ea1: c1 00           CMPB   #$00
3ea3: 10 27 00 11     LBEQ   $3EB8
3ea7: ce 24 ff        LDU    #$24FF
3eaa: 5f              CLRB
3eab: 1d              SEX
3eac: 1f 02           TFR    D,Y
3eae: 8e 00 04        LDX    #$0004
3eb1: 34 70           PSHS   U,Y,X
3eb3: 17 41 b3        LBSR   $8069
3eb6: 32 66           LEAS   $6,S
3eb8: be 23 bf        LDX    $23BF
3ebb: 30 0a           LEAX   $A,X
3ebd: 1f 13           TFR    X,U
3ebf: 10 ae e9 00 18  LDY    $0018,S
3ec4: 8e 00 04        LDX    #$0004
3ec7: 34 70           PSHS   U,Y,X
3ec9: 17 41 9d        LBSR   $8069
3ecc: 32 66           LEAS   $6,S
3ece: ee e9 00 1a     LDU    $001A,S
3ed2: 10 8e 00 02     LDY    #$0002
3ed6: 34 60           PSHS   U,Y
3ed8: 17 79 11        LBSR   $B7EC
3edb: 32 64           LEAS   $4,S
3edd: ee e9 00 1a     LDU    $001A,S
3ee1: 10 8e 00 02     LDY    #$0002
3ee5: 34 60           PSHS   U,Y
3ee7: 17 f8 ef        LBSR   $37D9
3eea: 32 64           LEAS   $4,S
3eec: c1 00           CMPB   #$00
3eee: 10 27 00 3f     LBEQ   $3F31
3ef2: fe 23 bf        LDU    $23BF
3ef5: 10 ae e9 00 18  LDY    $0018,S
3efa: 8e 00 04        LDX    #$0004
3efd: 34 70           PSHS   U,Y,X
3eff: 17 64 17        LBSR   $A319
3f02: 32 66           LEAS   $6,S
3f04: ee e9 00 18     LDU    $0018,S
3f08: 10 8e 00 02     LDY    #$0002
3f0c: 34 60           PSHS   U,Y
3f0e: 17 69 96        LBSR   $A8A7
3f11: 32 64           LEAS   $4,S
3f13: 1f 03           TFR    D,U
3f15: 10 ae e9 00 18  LDY    $0018,S
3f1a: 8e 00 04        LDX    #$0004
3f1d: 34 70           PSHS   U,Y,X
3f1f: 17 66 9d        LBSR   $A5BF
3f22: 32 66           LEAS   $6,S
3f24: ce 00 00        LDU    #$0000
3f27: 34 40           PSHS   U
3f29: 17 5f 8a        LBSR   $9EB6
3f2c: 32 62           LEAS   $2,S
3f2e: 16 00 2f        LBRA   $3F60
3f31: fe 23 bf        LDU    $23BF
3f34: 10 ae e9 00 18  LDY    $0018,S
3f39: 8e 00 04        LDX    #$0004
3f3c: 34 70           PSHS   U,Y,X
3f3e: 17 63 80        LBSR   $A2C1
3f41: 32 66           LEAS   $6,S
3f43: 5f              CLRB
3f44: 1d              SEX
3f45: 1f 03           TFR    D,U
3f47: 10 ae e9 00 18  LDY    $0018,S
3f4c: 8e 00 04        LDX    #$0004
3f4f: 34 70           PSHS   U,Y,X
3f51: 17 66 6b        LBSR   $A5BF
3f54: 32 66           LEAS   $6,S
3f56: ce 00 00        LDU    #$0000
3f59: 34 40           PSHS   U
3f5b: 17 5f 58        LBSR   $9EB6
3f5e: 32 62           LEAS   $2,S
3f60: ae e9 00 18     LDX    $0018,S
3f64: 8c 00 03        CMPX   #$0003
3f67: 10 26 00 61     LBNE   $3FCC
3f6b: c6 01           LDB    #$01
3f6d: e7 6b           STB    $B,S
3f6f: e6 6b           LDB    $B,S
3f71: c1 03           CMPB   #$03
3f73: 10 24 00 55     LBCC   $3FCC
3f77: ce 24 f5        LDU    #$24F5
3f7a: e6 6b           LDB    $B,S
3f7c: 4f              CLRA
3f7d: 1f 02           TFR    D,Y
3f7f: 34 60           PSHS   U,Y
3f81: 86 01           LDA    #$01
3f83: 8e 7f df        LDX    #$7FDF
3f86: 17 7d 61        LBSR   $BCEA
3f89: 30 88 21        LEAX   $21,X
3f8c: af e8 12        STX    $12,S
3f8f: ee f8 12        LDU    [$12,S]
3f92: 10 8e 00 02     LDY    #$0002
3f96: 34 60           PSHS   U,Y
3f98: 17 f8 3e        LBSR   $37D9
3f9b: 32 64           LEAS   $4,S
3f9d: c1 00           CMPB   #$00
3f9f: 10 27 00 21     LBEQ   $3FC4
3fa3: e6 6b           LDB    $B,S
3fa5: 4f              CLRA
3fa6: 1f 03           TFR    D,U
3fa8: 10 8e 00 02     LDY    #$0002
3fac: 34 60           PSHS   U,Y
3fae: 17 68 f6        LBSR   $A8A7
3fb1: 32 64           LEAS   $4,S
3fb3: 1f 03           TFR    D,U
3fb5: e6 6b           LDB    $B,S
3fb7: 4f              CLRA
3fb8: 1f 02           TFR    D,Y
3fba: 8e 00 04        LDX    #$0004
3fbd: 34 70           PSHS   U,Y,X
3fbf: 17 65 fd        LBSR   $A5BF
3fc2: 32 66           LEAS   $6,S
3fc4: e6 6b           LDB    $B,S
3fc6: cb 01           ADDB   #$01
3fc8: e7 6b           STB    $B,S
3fca: 20 a3           BRA    $3F6F
3fcc: ee e9 00 18     LDU    $0018,S
3fd0: 10 8e 00 02     LDY    #$0002
3fd4: 34 60           PSHS   U,Y
3fd6: 17 e6 5c        LBSR   $2635
3fd9: 32 64           LEAS   $4,S
3fdb: 32 e8 14        LEAS   $14,S
3fde: 39              RTS
3fdf: 00 01           NEG    <$01
3fe1: 00 00           NEG    <$00
3fe3: 00 23           NEG    <$23
3fe5: 00 03           NEG    <$03
3fe7: 00 04           NEG    <$04
3fe9: 00 12           NEG    <$12
; --- $FF padding to end of page 0 ---
3feb: ff ff ff        STU    $FFFF
3fee: ff ff ff        STU    $FFFF
3ff1: ff ff ff        STU    $FFFF
3ff4: ff ff ff        STU    $FFFF
3ff7: ff ff ff        STU    $FFFF
3ffa: ff ff ff        STU    $FFFF
3ffd: ff ff ff        STU    $FFFF
;
; #####################################################################################
; PAGE 1 — Tone/DTMF/digital sequence editing (file offset $4000-$7FFF, CPU $4000-$7FFF)
; #####################################################################################
;
4000: 31 72           LEAY   -$E,S
4002: 2a 2a           BPL    $402E
4004: 20 20           BRA    $4026
4006: 20 20           BRA    $4028
4008: 20 20           BRA    $402A
400a: 20 20           BRA    $402C
400c: 20 54           BRA    $4062
400e: 6f 6e           CLR    $E,S
4010: 65 20           LSR    $0,Y
4012: 53              COMB
4013: 65 71           LSR    -$F,S
4015: 75 65 6e        LSR    $656E
4018: 63 65           COM    $5,S
401a: 20 4d           BRA    $4069
401c: 6f 64           CLR    $4,S
401e: 65 20           LSR    $0,Y
4020: 20 20           BRA    $4042
4022: 20 20           BRA    $4044
4024: 20 20           BRA    $4046
4026: 20 20           BRA    $4048
4028: 2a 2a           BPL    $4054
402a: 50              NEGB
402b: 72 65 73        XNC    $6573
402e: 73 20 4e        COM    $204E
4031: 45              LSRA
4032: 58              ASLB
4033: 54              LSRB
4034: 2f 4c           BLE    $4082
4036: 41              NEGA
4037: 53              COMB
4038: 54              LSRB
4039: 20 6b           BRA    $40A6
403b: 65 79           LSR    -$7,S
403d: 73 2e 20        COM    $2E20
4040: 20 20           BRA    $4062
4042: 20 00           BRA    $4044
4044: 04 20           LSR    <$20
4046: 45              LSRA
4047: 78 69 74        ASL    $6974
404a: 20 20           BRA    $406C
404c: 20 20           BRA    $406E
404e: 20 20           BRA    $4070
4050: 20 20           BRA    $4072
4052: 00 01           NEG    <$01
4054: 20 54           BRA    $40AA
4056: 6f 6e           CLR    $E,S
4058: 65 20           LSR    $0,Y
405a: 4e              XCLRA
405b: 75 6d 62        LSR    $6D62
405e: 65 72           LSR    -$E,S
4060: 20 39           BRA    $409B
4062: 20 20           BRA    $4084
4064: 20 20           BRA    $4086
4066: 46              RORA
4067: 52              XNCB
4068: 45              LSRA
4069: 51              NEGB
406a: 20 20           BRA    $408C
406c: 31 30           LEAY   -$10,Y
406e: 30 30           LEAX   -$10,Y
4070: 35 2e           PULS   D,DP,Y
4072: 35 20           PULS   Y
4074: 20 48           BRA    $40BE
4076: 7a 20 20        DEC    $2020
4079: 20 00           BRA    $407B
407b: 02 20           XNC    <$20
407d: 4f              CLRA
407e: 6e 20           JMP    $0,Y
4080: 54              LSRB
4081: 69 6d           ROL    $D,S
4083: 65 20           LSR    $0,Y
4085: 35 30           PULS   X,Y
4087: 30 20           LEAX   $0,Y
4089: 20 6d           BRA    $40F8
408b: 73 20 20        COM    $2020
408e: 00 04           NEG    <$04
4090: 20 4f           BRA    $40E1
4092: 66 66           ROR    $6,S
4094: 20 54           BRA    $40EA
4096: 69 6d           ROL    $D,S
4098: 65 20           LSR    $0,Y
409a: 31 30           LEAY   -$10,Y
409c: 30 20           LEAX   $0,Y
409e: 20 6d           BRA    $410D
40a0: 73 20 00        COM    $2000
40a3: 01 20           NEG    <$20
40a5: 53              COMB
40a6: 65 71           LSR    -$F,S
40a8: 20 49           BRA    $40F3
40aa: 6e 64           JMP    $4,S
40ac: 65 78           LSR    -$8,S
40ae: 20 20           BRA    $40D0
40b0: 31 32           LEAY   -$E,Y
40b2: 36 20           PSHU   Y
40b4: 20 20           BRA    $40D6
40b6: 5b              XDECB
40b7: 31 32           LEAY   -$E,Y
40b9: 33 34           LEAU   -$C,Y
40bb: 35 36           PULS   D,X,Y
40bd: 37 38           PULU   DP,X,Y
40bf: 39              RTS
40c0: 41              NEGA
40c1: 42              XNCA
40c2: 43              COMA
40c3: 44              LSRA
40c4: 45              LSRA
40c5: 46              RORA
40c6: 30 5d           LEAX   -$3,U
40c8: 20 20           BRA    $40EA
40ca: 00 02           NEG    <$02
40cc: 20 53           BRA    $4121
40ce: 65 71           LSR    -$F,S
40d0: 20 45           BRA    $4117
40d2: 6e 64           JMP    $4,S
40d4: 20 20           BRA    $40F6
40d6: 31 32           LEAY   -$E,Y
40d8: 37 20           PULU   Y
40da: 20 20           BRA    $40FC
40dc: 20 20           BRA    $40FE
40de: 00 04           NEG    <$04
40e0: 20 45           BRA    $4127
40e2: 64 69           LSR    $9,S
40e4: 74 20 53        LSR    $2053
40e7: 65 71           LSR    -$F,S
40e9: 75 65 6e        LSR    $656E
40ec: 63 65           COM    $5,S
40ee: 20 20           BRA    $4110
40f0: 20 20           BRA    $4112
40f2: 00 01           NEG    <$01
40f4: 20 53           BRA    $4149
40f6: 65 71           LSR    -$F,S
40f8: 20 20           BRA    $411A
40fa: 31 31           LEAY   -$F,Y
40fc: 35 20           PULS   Y
40fe: 20 5b           BRA    $415B
4100: 45              LSRA
4101: 5d              TSTB
4102: 20 20           BRA    $4124
4104: 20 20           BRA    $4126
4106: 20 20           BRA    $4128
4108: 20 41           BRA    $414B
410a: 4d              TSTA
410b: 50              NEGB
410c: 54              LSRB
410d: 44              LSRA
410e: 20 20           BRA    $4130
4110: 31 2e           LEAY   $E,Y
4112: 30 30           LEAX   -$10,Y
4114: 31 20           LEAY   $0,Y
4116: 56              RORB
4117: 20 20           BRA    $4139
4119: 20 00           BRA    $411B
411b: 02 20           XNC    <$20
411d: 43              COMA
411e: 6f 6e           CLR    $E,S
4120: 74 69 6e        LSR    $696E
4123: 75 6f 75        LSR    $6F75
4126: 73 20 20        COM    $2020
4129: 20 20           BRA    $414B
412b: 20 20           BRA    $414D
412d: 20 00           BRA    $412F
412f: 03 20           COM    <$20
4131: 53              COMB
4132: 69 6e           ROL    $E,S
4134: 67 6c           ASR    $C,S
4136: 65 20           LSR    $0,Y
4138: 20 00           BRA    $413A
413a: 04 20           LSR    <$20
413c: 53              COMB
413d: 74 6f 70        LSR    $6F70
4140: 20 20           BRA    $4162
4142: 00 01           NEG    <$01
4144: 20 4d           BRA    $4193
4146: 61 6e           NEG    $E,S
4148: 75 61 6c        LSR    $616C
414b: 20 20           BRA    $416D
414d: 20 20           BRA    $416F
414f: 20 20           BRA    $4171
4151: 20 20           BRA    $4173
4153: 20 20           BRA    $4175
4155: 20 00           BRA    $4157
4157: 03 20           COM    <$20
4159: 44              LSRA
415a: 65 6c           LSR    $C,S
415c: 65 74           LSR    -$C,S
415e: 65 20           LSR    $0,Y
4160: 20 00           BRA    $4162
4162: 04 20           LSR    <$20
4164: 49              ROLA
4165: 6e 73           JMP    -$D,S
4167: 65 72           LSR    -$E,S
4169: 74 03 40        LSR    $0340
416c: 02 c2           XNC    <$C2
416e: 39              RTS
416f: c2 39           SBCB   #$39
4171: c2 39           SBCB   #$39
4173: 8b 4c           ADDA   #$4C
4175: 40              NEGA
4176: 52              XNCB
4177: 47              ASRA
4178: fa 48 42        ORB    $4842
417b: 49              ROLA
417c: 2c 48           BGE    $41C6
417e: 60 40           NEG    $0,U
4180: a2 71           SBCA   -$F,S
4182: b4 71 de        ANDA   $71DE
4185: 72 6a 72        XNC    $6A72
4188: 03 40           COM    <$40
418a: f2 49 ee        SBCB   $49EE
418d: 4a              DECA
418e: 19              DAA
418f: 4a              DECA
4190: a2 4a           SBCA   $A,U
4192: b9 2a 2a        ADCA   $2A2A
4195: 20 20           BRA    $41B7
4197: 20 20           BRA    $41B9
4199: 20 20           BRA    $41BB
419b: 20 20           BRA    $41BD
419d: 20 44           BRA    $41E3
419f: 54              LSRB
41a0: 4d              TSTA
41a1: 46              RORA
41a2: 20 53           BRA    $41F7
41a4: 65 71           LSR    -$F,S
41a6: 75 65 6e        LSR    $656E
41a9: 63 65           COM    $5,S
41ab: 20 4d           BRA    $41FA
41ad: 6f 64           CLR    $4,S
41af: 65 20           LSR    $0,Y
41b1: 20 20           BRA    $41D3
41b3: 20 20           BRA    $41D5
41b5: 20 20           BRA    $41D7
41b7: 20 20           BRA    $41D9
41b9: 2a 2a           BPL    $41E5
41bb: 50              NEGB
41bc: 72 65 73        XNC    $6573
41bf: 73 20 4e        COM    $204E
41c2: 45              LSRA
41c3: 58              ASLB
41c4: 54              LSRB
41c5: 2f 4c           BLE    $4213
41c7: 41              NEGA
41c8: 53              COMB
41c9: 54              LSRB
41ca: 20 6b           BRA    $4237
41cc: 65 79           LSR    -$7,S
41ce: 73 2e 20        COM    $2E20
41d1: 20 20           BRA    $41F3
41d3: 20 00           BRA    $41D5
41d5: 04 20           LSR    <$20
41d7: 45              LSRA
41d8: 78 69 74        ASL    $6974
41db: 20 20           BRA    $41FD
41dd: 20 20           BRA    $41FF
41df: 20 20           BRA    $4201
41e1: 20 20           BRA    $4203
41e3: 00 01           NEG    <$01
41e5: 20 54           BRA    $423B
41e7: 6f 6e           CLR    $E,S
41e9: 65 20           LSR    $0,Y
41eb: 4e              XCLRA
41ec: 75 6d 62        LSR    $6D62
41ef: 65 72           LSR    -$E,S
41f1: 20 39           BRA    $422C
41f3: 20 20           BRA    $4215
41f5: 20 20           BRA    $4217
41f7: 00 03           NEG    <$03
41f9: 20 4d           BRA    $4248
41fb: 61 6e           NEG    $E,S
41fd: 75 61 6c        LSR    $616C
4200: 20 44           BRA    $4246
4202: 69 61           ROL    $1,S
4204: 6c 20           INC    $0,Y
4206: 20 20           BRA    $4228
4208: 20 20           BRA    $422A
420a: 20 00           BRA    $420C
420c: 02 20           XNC    <$20
420e: 4f              CLRA
420f: 6e 20           JMP    $0,Y
4211: 54              LSRB
4212: 69 6d           ROL    $D,S
4214: 65 20           LSR    $0,Y
4216: 35 30           PULS   X,Y
4218: 30 20           LEAX   $0,Y
421a: 6d 73           TST    -$D,S
421c: 20 20           BRA    $423E
421e: 20 00           BRA    $4220
4220: 04 20           LSR    <$20
4222: 4f              CLRA
4223: 66 66           ROR    $6,S
4225: 20 54           BRA    $427B
4227: 69 6d           ROL    $D,S
4229: 65 20           LSR    $0,Y
422b: 31 30           LEAY   -$10,Y
422d: 30 20           LEAX   $0,Y
422f: 6d 73           TST    -$D,S
4231: 20 20           BRA    $4253
; ---------------------------------------------------------------------------
; End of string data.  Lookup tables follow: function pointer arrays (entries
; $C239 = null/unused), parameter descriptors for sequence modes.
; ---------------------------------------------------------------------------
4233: 03 41           COM    <$41
4235: 93 c2           SUBD   <$C2
4237: 39              RTS
4238: c2 39           SBCB   #$39
423a: c2 39           SBCB   #$39
423c: 8b 4c           ADDA   #$4C
423e: 41              NEGA
423f: e3 47           ADDD   $7,U
4241: fa 48 42        ORB    $4842
4244: 49              ROLA
4245: 2c 48           BGE    $428F
4247: 60 40           NEG    $0,U
4249: a2 71           SBCA   -$F,S
424b: b4 71 de        ANDA   $71DE
424e: 72 6a 72        XNC    $6A72
4251: 03 40           COM    <$40
4253: f2 49 ee        SBCB   $49EE
4256: 4a              DECA
4257: 19              DAA
4258: 4a              DECA
4259: a2 4a           SBCA   $A,U
425b: b9 1e 84        ADCA   $1E84
425e: 80 0f           SUBA   #$0F
4260: 42              XNCA
4261: 40              NEGA
4262: 03 0d           COM    <$0D
4264: 40              NEGA
4265: 01 86           NEG    <$86
; ---------------------------------------------------------------------------
; Hand-written assembly: DDS programming ($0200), MC6840 PTM timing
; ($1001/$1004), sequence playback engine.  Includes an interrupt handler
; (RTI at $43BB) for timed sequence output and a DDS register programming
; loop.  Runs through $4566.
; ---------------------------------------------------------------------------
4267: a0 fc 3d        SUBA   [$42A7,PCR]
426a: 2c 44           BGE    $42B0
426c: 56              RORB
426d: 24 0b           BCC    $427A
426f: c3 3c 90        ADDD   #$3C90
4272: 1f 01           TFR    D,X
4274: e6 84           LDB    ,X
4276: c4 0f           ANDB   #$0F
4278: 20 0b           BRA    $4285
427a: c3 3c 90        ADDD   #$3C90
427d: 1f 01           TFR    D,X
427f: e6 84           LDB    ,X
4281: 54              LSRB
4282: 54              LSRB
4283: 54              LSRB
4284: 54              LSRB
4285: f7 3d 27        STB    $3D27
4288: 58              ASLB
4289: 58              ASLB
428a: 4f              CLRA
428b: c3 3c 10        ADDD   #$3C10
428e: 1f 01           TFR    D,X
4290: b6 3d 32        LDA    $3D32
4293: 47              ASRA
4294: 25 15           BCS    $42AB
4296: 30 02           LEAX   $2,X
4298: 7d 3c 81        TST    $3C81
429b: 27 0e           BEQ    $42AB
429d: fc 3d 2c        LDD    $3D2C
42a0: 10 b3 3d 0f     CMPD   $3D0F
42a4: 26 05           BNE    $42AB
42a6: 8e 00 c8        LDX    #$00C8
42a9: 20 02           BRA    $42AD
42ab: ae 84           LDX    ,X
42ad: bf 3d 30        STX    $3D30
42b0: 39              RTS
42b1: 7c 3d 32        INC    $3D32
42b4: b6 3d 32        LDA    $3D32
42b7: 47              ASRA
42b8: 24 16           BCC    $42D0
42ba: be 3d 2c        LDX    $3D2C
42bd: 30 01           LEAX   $1,X
42bf: bf 3d 2c        STX    $3D2C
42c2: bc 3d 0f        CMPX   $3D0F
42c5: 23 09           BLS    $42D0
42c7: 7f 3d 2c        CLR    $3D2C
42ca: 7f 3d 2d        CLR    $3D2D
42cd: 7f 3d 34        CLR    $3D34
42d0: 39              RTS
42d1: b6 10 01        LDA    $1001
42d4: fc 3d 30        LDD    $3D30
42d7: 83 00 05        SUBD   #$0005
42da: 10 b3 10 04     CMPD   $1004
42de: 27 1f           BEQ    $42FF
42e0: 10 b3 10 04     CMPD   $1004
42e4: 27 19           BEQ    $42FF
42e6: 10 b3 10 04     CMPD   $1004
42ea: 27 13           BEQ    $42FF
42ec: 10 b3 10 04     CMPD   $1004
42f0: 27 0d           BEQ    $42FF
42f2: 10 b3 10 04     CMPD   $1004
42f6: 27 07           BEQ    $42FF
42f8: 10 b3 10 04     CMPD   $1004
42fc: 27 01           BEQ    $42FF
42fe: 12              NOP
42ff: b6 3d 32        LDA    $3D32
4302: 2a 1e           BPL    $4322
4304: 84 7f           ANDA   #$7F
4306: b7 3d 32        STA    $3D32
4309: be 3d 30        LDX    $3D30
430c: 30 1f           LEAX   -$1,X
430e: bf 10 04        STX    $1004
4311: bf 3d 2e        STX    $3D2E
4314: 47              ASRA
4315: 24 08           BCC    $431F
4317: b6 3d 27        LDA    $3D27
431a: 8a c0           ORA    #$C0
431c: b7 0b 00        STA    $0B00
431f: 16 00 99        LBRA   $43BB
4322: 7d 3c 81        TST    $3C81
4325: 26 05           BNE    $432C
4327: 7d 3d 34        TST    $3D34
432a: 20 05           BRA    $4331
432c: 7d 3d 34        TST    $3D34
432f: 27 3c           BEQ    $436D
4331: 47              ASRA
4332: 86 01           LDA    #$01
4334: 25 04           BCS    $433A
4336: c6 21           LDB    #$21
4338: 20 05           BRA    $433F
433a: c6 20           LDB    #$20
433c: 20 01           BRA    $433F
433e: 12              NOP
433f: f1 3d 33        CMPB   $3D33
4342: 27 3d           BEQ    $4381
4344: f7 3d 33        STB    $3D33
4347: c1 21           CMPB   #$21
4349: 26 06           BNE    $4351
434b: 12              NOP
434c: 12              NOP
434d: 12              NOP
434e: 12              NOP
434f: 12              NOP
4350: 12              NOP
4351: 8e 22 21        LDX    #$2221
4354: bf 02 00        STX    $0200
4357: 8e 26 03        LDX    #$2603
435a: bf 02 00        STX    $0200
435d: 86 0b           LDA    #$0B
435f: b7 02 01        STA    $0201
4362: 86 22           LDA    #$22
4364: fd 02 00        STD    $0200
4367: 4f              CLRA
4368: f6 3d 33        LDB    $3D33
436b: 20 14           BRA    $4381
436d: 86 22           LDA    #$22
436f: c6 21           LDB    #$21
4371: f7 3d 33        STB    $3D33
4374: fd 02 00        STD    $0200
4377: 86 91           LDA    #$91
4379: b7 10 01        STA    $1001
437c: bd 6c 45        JSR    $6C45
437f: 20 32           BRA    $43B3
4381: 34 06           PSHS   D
4383: bd 42 b1        JSR    $42B1
4386: bd 42 68        JSR    $4268
4389: 27 f8           BEQ    $4383
438b: 35 06           PULS   D
438d: be 3d 2e        LDX    $3D2E
4390: 81 01           CMPA   #$01
4392: 26 0f           BNE    $43A3
4394: c1 20           CMPB   #$20
4396: 26 1b           BNE    $43B3
4398: b6 3d 32        LDA    $3D32
439b: 47              ASRA
439c: 25 15           BCS    $43B3
439e: 30 88 e8        LEAX   -$18,X
43a1: 20 0d           BRA    $43B0
43a3: c1 20           CMPB   #$20
43a5: 26 0c           BNE    $43B3
43a7: b6 3d 32        LDA    $3D32
43aa: 47              ASRA
43ab: 24 06           BCC    $43B3
43ad: 30 88 18        LEAX   $18,X
43b0: bf 10 04        STX    $1004
43b3: b6 3d 32        LDA    $3D32
43b6: 8a 80           ORA    #$80
43b8: b7 3d 32        STA    $3D32
43bb: 3b              RTI
43bc: 01 2c           NEG    <$2C
43be: 34 01           PSHS   CC
43c0: 38 14           XANDCC #$14
43c2: 02 05           XNC    <$05
43c4: 08 02           ASL    <$02
43c6: 13              SYNC
43c7: 02 02           XNC    <$02
43c9: 3c 3a           CWAI   #$3A
43cb: 03 10           COM    <$10
43cd: 30 03           LEAX   $3,X
43cf: 26 32           BNE    $4403
43d1: 03 3f           COM    <$3F
43d3: 0a 03           DEC    <$03
43d5: 05 00           LSR    <$00
43d7: 04 00           LSR    <$00
43d9: 05 00           LSR    <$00
43db: 06 01           ROR    <$01
43dd: 04 01           LSR    <$01
43df: 05 01           LSR    <$01
43e1: 06 02           ROR    <$02
43e3: 04 02           LSR    <$02
43e5: 05 02           LSR    <$02
43e7: 06 00           ROR    <$00
43e9: 07 01           ASR    <$01
43eb: 07 02           ASR    <$02
43ed: 07 03           ASR    <$03
43ef: 07 03           ASR    <$03
43f1: 04 03           LSR    <$03
43f3: 06 34           ROR    <$34
43f5: 02 1f           XNC    <$1F
43f7: 01 58           NEG    <$58
43f9: 3a              ABX
43fa: 1f 10           TFR    X,D
43fc: 8e 43 bc        LDX    #$43BC
43ff: 3a              ABX
4400: cc 03 00        LDD    #$0300
4403: fd 02 00        STD    $0200
4406: 4a              DECA
4407: e6 84           LDB    ,X
4409: fd 02 00        STD    $0200
440c: 4a              DECA
440d: e6 01           LDB    $1,X
440f: fd 02 00        STD    $0200
4412: 4a              DECA
4413: e6 02           LDB    $2,X
4415: fd 02 00        STD    $0200
4418: 35 02           PULS   A
441a: fd 02 00        STD    $0200
441d: 39              RTS
441e: f6 3d 27        LDB    $3D27
4421: c4 0f           ANDB   #$0F
4423: 58              ASLB
4424: 8e 43 d4        LDX    #$43D4
4427: 3a              ABX
4428: ec 84           LDD    ,X
442a: 34 02           PSHS   A
442c: 86 08           LDA    #$08
442e: bd 43 f4        JSR    $43F4
4431: 35 04           PULS   B
4433: 86 0a           LDA    #$0A
4435: bd 43 f4        JSR    $43F4
4438: 39              RTS
4439: 8e 22 1c        LDX    #$221C
443c: a6 84           LDA    ,X
443e: 44              LSRA
443f: a7 84           STA    ,X
4441: a6 01           LDA    $1,X
4443: 46              RORA
4444: a7 01           STA    $1,X
4446: a6 02           LDA    $2,X
4448: 46              RORA
4449: a7 02           STA    $2,X
444b: 39              RTS
444c: b6 10 01        LDA    $1001
444f: fc 3d 30        LDD    $3D30
4452: 83 00 05        SUBD   #$0005
4455: 10 b3 10 04     CMPD   $1004
4459: 27 1f           BEQ    $447A
445b: 10 b3 10 04     CMPD   $1004
445f: 27 19           BEQ    $447A
4461: 10 b3 10 04     CMPD   $1004
4465: 27 13           BEQ    $447A
4467: 10 b3 10 04     CMPD   $1004
446b: 27 0d           BEQ    $447A
446d: 10 b3 10 04     CMPD   $1004
4471: 27 07           BEQ    $447A
4473: 10 b3 10 04     CMPD   $1004
4477: 27 01           BEQ    $447A
4479: 12              NOP
447a: b6 3d 32        LDA    $3D32
447d: 7d 3c 81        TST    $3C81
4480: 26 05           BNE    $4487
4482: 7d 3d 34        TST    $3D34
4485: 20 05           BRA    $448C
4487: 7d 3d 34        TST    $3D34
448a: 27 45           BEQ    $44D1
448c: 8e 29 00        LDX    #$2900
448f: bf 02 00        STX    $0200
4492: 86 10           LDA    #$10
4494: b7 02 01        STA    $0201
4497: b6 3d 32        LDA    $3D32
449a: 47              ASRA
449b: 25 04           BCS    $44A1
449d: c6 21           LDB    #$21
449f: 20 05           BRA    $44A6
44a1: c6 22           LDB    #$22
44a3: 20 01           BRA    $44A6
44a5: 12              NOP
44a6: f1 3d 33        CMPB   $3D33
44a9: 27 3b           BEQ    $44E6
44ab: f7 3d 33        STB    $3D33
44ae: c1 21           CMPB   #$21
44b0: 26 07           BNE    $44B9
44b2: 12              NOP
44b3: 12              NOP
44b4: 12              NOP
44b5: 12              NOP
44b6: 12              NOP
44b7: 12              NOP
44b8: 12              NOP
44b9: 8e 22 21        LDX    #$2221
44bc: bf 02 00        STX    $0200
44bf: 8e 26 03        LDX    #$2603
44c2: bf 02 00        STX    $0200
44c5: 86 0b           LDA    #$0B
44c7: b7 02 01        STA    $0201
44ca: 86 22           LDA    #$22
44cc: fd 02 00        STD    $0200
44cf: 20 15           BRA    $44E6
44d1: 86 22           LDA    #$22
44d3: c6 21           LDB    #$21
44d5: f7 3d 33        STB    $3D33
44d8: fd 02 00        STD    $0200
44db: 86 91           LDA    #$91
44dd: b7 10 01        STA    $1001
44e0: bd 6c 45        JSR    $6C45
44e3: 16 00 08        LBRA   $44EE
44e6: bd 42 b1        JSR    $42B1
44e9: bd 42 68        JSR    $4268
44ec: 27 f8           BEQ    $44E6
44ee: bd 44 1e        JSR    $441E
44f1: be 3d 30        LDX    $3D30
44f4: 30 1f           LEAX   -$1,X
44f6: bf 10 04        STX    $1004
44f9: 3b              RTI
44fa: 32 7d           LEAS   -$3,S
44fc: ec 67           LDD    $7,S
44fe: e3 69           ADDD   $9,S
4500: 25 06           BCS    $4508
4502: ed f8 0b        STD    [$0B,S]
4505: 5f              CLRB
4506: 20 02           BRA    $450A
4508: c6 01           LDB    #$01
450a: e7 62           STB    $2,S
450c: 32 63           LEAS   $3,S
450e: 39              RTS
450f: 32 7d           LEAS   -$3,S
4511: ec 67           LDD    $7,S
4513: 44              LSRA
4514: 56              RORB
4515: 34 01           PSHS   CC
4517: c3 3c 90        ADDD   #$3C90
451a: 1f 01           TFR    D,X
451c: e6 84           LDB    ,X
451e: 35 01           PULS   CC
4520: 24 04           BCC    $4526
4522: c4 0f           ANDB   #$0F
4524: 20 04           BRA    $452A
4526: 54              LSRB
4527: 54              LSRB
4528: 54              LSRB
4529: 54              LSRB
452a: 32 63           LEAS   $3,S
452c: 39              RTS
452d: 32 7e           LEAS   -$2,S
452f: ec 66           LDD    $6,S
4531: 10 83 00 fa     CMPD   #$00FA
4535: 25 02           BCS    $4539
4537: 20 2b           BRA    $4564
4539: 44              LSRA
453a: 56              RORB
453b: 34 01           PSHS   CC
453d: c3 3c 90        ADDD   #$3C90
4540: 1f 01           TFR    D,X
4542: e6 84           LDB    ,X
4544: 35 01           PULS   CC
4546: 24 0e           BCC    $4556
4548: a6 69           LDA    $9,S
454a: c4 f0           ANDB   #$F0
454c: e7 84           STB    ,X
454e: 84 0f           ANDA   #$0F
4550: ab 84           ADDA   ,X
4552: a7 84           STA    ,X
4554: 20 0e           BRA    $4564
4556: a6 69           LDA    $9,S
4558: c4 0f           ANDB   #$0F
455a: e7 84           STB    ,X
455c: 48              ASLA
455d: 48              ASLA
455e: 48              ASLA
455f: 48              ASLA
4560: ab 84           ADDA   ,X
4562: a7 84           STA    ,X
4564: 32 62           LEAS   $2,S
4566: 39              RTS
; ---------------------------------------------------------------------------
; First C-compiled function (page 1).  98 frame-allocating functions follow,
; covering tone/DTMF/digital sequence editing, hop RAM management.
; Pattern: LDD <rom-addr>; LBSR $FD50 allocates stack frame.
; ---------------------------------------------------------------------------
4567: fc 56 01        LDD    $5601
456a: 17 b7 e3        LBSR   $FD50
456d: ae e9 00 0d     LDX    $000D,S
4571: 16 00 d0        LBRA   $4644
4574: cc 00 03        LDD    #$0003
4577: ed 67           STD    $7,S
4579: cc 00 06        LDD    #$0006
457c: ed 65           STD    $5,S
457e: c6 08           LDB    #$08
4580: e7 62           STB    $2,S
4582: c6 19           LDB    #$19
4584: e7 63           STB    $3,S
4586: c6 23           LDB    #$23
4588: e7 64           STB    $4,S
458a: 16 00 da        LBRA   $4667
458d: cc 00 03        LDD    #$0003
4590: ed 67           STD    $7,S
4592: cc 00 04        LDD    #$0004
4595: ed 65           STD    $5,S
4597: c6 05           LDB    #$05
4599: e7 62           STB    $2,S
459b: c6 1e           LDB    #$1E
459d: e7 63           STB    $3,S
459f: c6 24           LDB    #$24
45a1: e7 64           STB    $4,S
45a3: 16 00 c1        LBRA   $4667
45a6: cc 00 03        LDD    #$0003
45a9: ed 67           STD    $7,S
45ab: cc 00 05        LDD    #$0005
45ae: ed 65           STD    $5,S
45b0: c6 06           LDB    #$06
45b2: e7 62           STB    $2,S
45b4: f6 3d 1c        LDB    $3D1C
45b7: c1 00           CMPB   #$00
45b9: 10 27 00 0b     LBEQ   $45C8
45bd: c6 60           LDB    #$60
45bf: e7 63           STB    $3,S
45c1: c6 66           LDB    #$66
45c3: e7 64           STB    $4,S
45c5: 16 00 08        LBRA   $45D0
45c8: c6 4b           LDB    #$4B
45ca: e7 63           STB    $3,S
45cc: c6 51           LDB    #$51
45ce: e7 64           STB    $4,S
45d0: 16 00 94        LBRA   $4667
45d3: fc 22 04        LDD    $2204
45d6: 84 00           ANDA   #$00
45d8: c4 08           ANDB   #$08
45da: 10 83 00 00     CMPD   #$0000
45de: 10 27 00 14     LBEQ   $45F6
45e2: 5f              CLRB
45e3: 4f              CLRA
45e4: ed 67           STD    $7,S
45e6: cc 00 02        LDD    #$0002
45e9: ed 65           STD    $5,S
45eb: c6 03           LDB    #$03
45ed: e7 62           STB    $2,S
45ef: c6 0f           LDB    #$0F
45f1: e7 63           STB    $3,S
45f3: 16 00 22        LBRA   $4618
45f6: cc 00 01        LDD    #$0001
45f9: ed 67           STD    $7,S
45fb: 5f              CLRB
45fc: 4f              CLRA
45fd: ed 65           STD    $5,S
45ff: c6 01           LDB    #$01
4601: e7 62           STB    $2,S
4603: be 3d 11        LDX    $3D11
4606: 8c 00 0d        CMPX   #$000D
4609: 10 26 00 07     LBNE   $4614
460d: c6 23           LDB    #$23
460f: e7 63           STB    $3,S
4611: 16 00 04        LBRA   $4618
4614: c6 0f           LDB    #$0F
4616: e7 63           STB    $3,S
4618: 16 00 4c        LBRA   $4667
461b: 5f              CLRB
461c: 4f              CLRA
461d: ed 67           STD    $7,S
461f: cc 00 02        LDD    #$0002
4622: ed 65           STD    $5,S
4624: c6 04           LDB    #$04
4626: e7 62           STB    $2,S
4628: f6 3d 36        LDB    $3D36
462b: e7 63           STB    $3,S
462d: 16 00 37        LBRA   $4667
4630: 5f              CLRB
4631: 4f              CLRA
4632: ed 67           STD    $7,S
4634: cc 00 02        LDD    #$0002
4637: ed 65           STD    $5,S
4639: c6 04           LDB    #$04
463b: e7 62           STB    $2,S
463d: c6 4c           LDB    #$4C
463f: e7 63           STB    $3,S
4641: 16 00 23        LBRA   $4667
4644: 8c 00 00        CMPX   #$0000
4647: 10 2d 00 1c     LBLT   $4667
464b: 8c 00 05        CMPX   #$0005
464e: 10 2e 00 15     LBGT   $4667
4652: 1f 10           TFR    X,D
4654: 8e 46 5b        LDX    #$465B
4657: 58              ASLB
4658: 49              ROLA
4659: 6e 9b           JMP    [D,X]
465b: 45              LSRA
465c: 74 45 8d        LSR    $458D
465f: 45              LSRA
4660: a6 45           LDA    $5,U
4662: d3 46           ADDD   <$46
4664: 1b              NOP
4665: 46              RORA
4666: 30 e6           LEAX   A,S
4668: 64 4f           LSR    $F,U
466a: 1f 03           TFR    D,U
466c: 10 ae 65        LDY    $5,S
466f: e6 63           LDB    $3,S
4671: 4f              CLRA
4672: 1f 01           TFR    D,X
4674: e6 62           LDB    $2,S
4676: 4f              CLRA
4677: 34 76           PSHS   U,Y,X,D
4679: ee 6f           LDU    $F,S
467b: 10 8e 00 0a     LDY    #$000A
467f: 34 60           PSHS   U,Y
4681: 17 65 b1        LBSR   $AC35
4684: 32 6c           LEAS   $C,S
4686: 32 69           LEAS   $9,S
4688: 39              RTS
4689: fc 56 03        LDD    $5603
468c: 17 b6 c1        LBSR   $FD50
468f: f6 26 8e        LDB    $268E
4692: f7 3c 8f        STB    $3C8F
4695: f6 26 8e        LDB    $268E
4698: 16 00 4f        LBRA   $46EA
469b: 5f              CLRB
469c: 1d              SEX
469d: 1f 03           TFR    D,U
469f: 10 8e 00 02     LDY    #$0002
46a3: 34 60           PSHS   U,Y
46a5: 17 31 97        LBSR   $783F
46a8: 32 64           LEAS   $4,S
46aa: 16 00 48        LBRA   $46F5
46ad: c6 08           LDB    #$08
46af: 1d              SEX
46b0: 1f 03           TFR    D,U
46b2: 10 8e 00 02     LDY    #$0002
46b6: 34 60           PSHS   U,Y
46b8: 17 31 84        LBSR   $783F
46bb: 32 64           LEAS   $4,S
46bd: f6 3c 82        LDB    $3C82
46c0: c1 00           CMPB   #$00
46c2: 10 27 00 21     LBEQ   $46E7
46c6: ce 00 00        LDU    #$0000
46c9: 34 40           PSHS   U
46cb: 17 26 98        LBSR   $6D66
46ce: 32 62           LEAS   $2,S
46d0: e7 62           STB    $2,S
46d2: f6 3c 80        LDB    $3C80
46d5: 4f              CLRA
46d6: 1f 03           TFR    D,U
46d8: e6 62           LDB    $2,S
46da: 4f              CLRA
46db: 1f 02           TFR    D,Y
46dd: 8e 00 04        LDX    #$0004
46e0: 34 70           PSHS   U,Y,X
46e2: 17 23 b0        LBSR   $6A95
46e5: 32 66           LEAS   $6,S
46e7: 16 00 0b        LBRA   $46F5
46ea: c1 02           CMPB   #$02
46ec: 27 ad           BEQ    $469B
46ee: c1 03           CMPB   #$03
46f0: 27 bb           BEQ    $46AD
46f2: 16 00 00        LBRA   $46F5
46f5: ce 00 00        LDU    #$0000
46f8: 34 40           PSHS   U
46fa: 17 15 cf        LBSR   $5CCC
46fd: 32 62           LEAS   $2,S
46ff: 32 63           LEAS   $3,S
4701: 39              RTS
4702: fc 56 03        LDD    $5603
4705: 17 b6 48        LBSR   $FD50
4708: ae e9 00 07     LDX    $0007,S
470c: 8c 00 00        CMPX   #$0000
470f: 10 27 00 5e     LBEQ   $4771
4713: c6 01           LDB    #$01
4715: f7 3c 80        STB    $3C80
4718: ce 00 00        LDU    #$0000
471b: 34 40           PSHS   U
471d: 17 26 46        LBSR   $6D66
4720: 32 62           LEAS   $2,S
4722: e7 62           STB    $2,S
4724: f6 3c 80        LDB    $3C80
4727: 4f              CLRA
4728: 1f 03           TFR    D,U
472a: e6 62           LDB    $2,S
472c: 4f              CLRA
472d: 1f 02           TFR    D,Y
472f: 8e 00 04        LDX    #$0004
4732: 34 70           PSHS   U,Y,X
4734: 17 23 5e        LBSR   $6A95
4737: 32 66           LEAS   $6,S
4739: ce 00 00        LDU    #$0000
473c: 34 40           PSHS   U
473e: 17 14 da        LBSR   $5C1B
4741: 32 62           LEAS   $2,S
4743: fc 22 04        LDD    $2204
4746: 84 00           ANDA   #$00
4748: c4 08           ANDB   #$08
474a: 10 83 00 00     CMPD   #$0000
474e: 10 27 00 12     LBEQ   $4764
4752: ce 00 ff        LDU    #$00FF
4755: c6 02           LDB    #$02
4757: 1d              SEX
4758: 1f 02           TFR    D,Y
475a: 8e 00 04        LDX    #$0004
475d: 34 70           PSHS   U,Y,X
475f: 17 56 71        LBSR   $9DD3
4762: 32 66           LEAS   $6,S
4764: ce 00 00        LDU    #$0000
4767: 34 40           PSHS   U
4769: 17 24 64        LBSR   $6BD0
476c: 32 62           LEAS   $2,S
476e: 16 00 62        LBRA   $47D3
4771: f6 3c 80        LDB    $3C80
4774: c1 00           CMPB   #$00
4776: 10 27 00 21     LBEQ   $479B
477a: fc 22 04        LDD    $2204
477d: 84 00           ANDA   #$00
477f: c4 08           ANDB   #$08
4781: 10 83 00 00     CMPD   #$0000
4785: 10 27 00 12     LBEQ   $479B
4789: ce 00 ff        LDU    #$00FF
478c: c6 03           LDB    #$03
478e: 1d              SEX
478f: 1f 02           TFR    D,Y
4791: 8e 00 04        LDX    #$0004
4794: 34 70           PSHS   U,Y,X
4796: 17 56 3a        LBSR   $9DD3
4799: 32 66           LEAS   $6,S
479b: 7f 3c 80        CLR    $3C80
479e: ce 00 00        LDU    #$0000
47a1: 34 40           PSHS   U
47a3: 17 14 75        LBSR   $5C1B
47a6: 32 62           LEAS   $2,S
47a8: ce 00 00        LDU    #$0000
47ab: 34 40           PSHS   U
47ad: 17 24 72        LBSR   $6C22
47b0: 32 62           LEAS   $2,S
47b2: ce 00 00        LDU    #$0000
47b5: 34 40           PSHS   U
47b7: 17 25 ac        LBSR   $6D66
47ba: 32 62           LEAS   $2,S
47bc: e7 62           STB    $2,S
47be: f6 3c 80        LDB    $3C80
47c1: 4f              CLRA
47c2: 1f 03           TFR    D,U
47c4: e6 62           LDB    $2,S
47c6: 4f              CLRA
47c7: 1f 02           TFR    D,Y
47c9: 8e 00 04        LDX    #$0004
47cc: 34 70           PSHS   U,Y,X
47ce: 17 22 c4        LBSR   $6A95
47d1: 32 66           LEAS   $6,S
47d3: 32 63           LEAS   $3,S
47d5: 39              RTS
47d6: fc 56 05        LDD    $5605
47d9: 17 b5 74        LBSR   $FD50
47dc: f6 3c 0d        LDB    $3C0D
47df: c1 00           CMPB   #$00
47e1: 10 27 00 12     LBEQ   $47F7
47e5: 7f 3c 0d        CLR    $3C0D
47e8: ce 00 00        LDU    #$0000
47eb: 34 40           PSHS   U
47ed: 17 80 95        LBSR   $C885
47f0: 32 62           LEAS   $2,S
47f2: be 3c 00        LDX    $3C00
47f5: ad 84           JSR    ,X
47f7: 32 62           LEAS   $2,S
47f9: 39              RTS
47fa: fc 56 05        LDD    $5605
47fd: 17 b5 50        LBSR   $FD50
4800: cc 00 07        LDD    #$0007
4803: fd 3d 11        STD    $3D11
4806: ce 00 03        LDU    #$0003
4809: 10 8e 00 02     LDY    #$0002
480d: 34 60           PSHS   U,Y
480f: be 3c 0e        LDX    $3C0E
4812: ad 84           JSR    ,X
4814: 32 64           LEAS   $4,S
4816: 32 62           LEAS   $2,S
4818: 39              RTS
4819: fc 56 05        LDD    $5605
481c: 17 b5 31        LBSR   $FD50
481f: ce 00 00        LDU    #$0000
4822: 34 40           PSHS   U
4824: 17 0d f3        LBSR   $561A
4827: 32 62           LEAS   $2,S
4829: cc 00 05        LDD    #$0005
482c: fd 3d 11        STD    $3D11
482f: ce 00 02        LDU    #$0002
4832: 10 8e 00 02     LDY    #$0002
4836: 34 60           PSHS   U,Y
4838: be 3c 0e        LDX    $3C0E
483b: ad 84           JSR    ,X
483d: 32 64           LEAS   $4,S
483f: 32 62           LEAS   $2,S
4841: 39              RTS
4842: fc 56 05        LDD    $5605
4845: 17 b5 08        LBSR   $FD50
4848: ce 00 00        LDU    #$0000
484b: 34 40           PSHS   U
484d: 8d 87           BSR    $47D6
484f: 32 62           LEAS   $2,S
4851: 7f 3d 1c        CLR    $3D1C
4854: ce 00 00        LDU    #$0000
4857: 34 40           PSHS   U
4859: 8d be           BSR    $4819
485b: 32 62           LEAS   $2,S
485d: 32 62           LEAS   $2,S
485f: 39              RTS
4860: fc 56 05        LDD    $5605
4863: 17 b4 ea        LBSR   $FD50
4866: ce 00 00        LDU    #$0000
4869: 34 40           PSHS   U
486b: 17 ff 68        LBSR   $47D6
486e: 32 62           LEAS   $2,S
4870: c6 01           LDB    #$01
4872: f7 3d 1c        STB    $3D1C
4875: ce 00 00        LDU    #$0000
4878: 34 40           PSHS   U
487a: 8d 9d           BSR    $4819
487c: 32 62           LEAS   $2,S
487e: 32 62           LEAS   $2,S
4880: 39              RTS
4881: fc 56 05        LDD    $5605
4884: 17 b4 c9        LBSR   $FD50
4887: 7f 3c 82        CLR    $3C82
488a: f6 3c 80        LDB    $3C80
488d: c1 00           CMPB   #$00
488f: 10 27 00 12     LBEQ   $48A5
4893: 5f              CLRB
4894: 1d              SEX
4895: 1f 03           TFR    D,U
4897: 10 8e 00 02     LDY    #$0002
489b: 34 60           PSHS   U,Y
489d: 17 fe 62        LBSR   $4702
48a0: 32 64           LEAS   $4,S
48a2: 16 00 0a        LBRA   $48AF
48a5: ce 00 00        LDU    #$0000
48a8: 34 40           PSHS   U
48aa: 17 13 6e        LBSR   $5C1B
48ad: 32 62           LEAS   $2,S
48af: 5f              CLRB
48b0: 1d              SEX
48b1: 1f 03           TFR    D,U
48b3: 10 8e 00 02     LDY    #$0002
48b7: 34 60           PSHS   U,Y
48b9: 17 22 d6        LBSR   $6B92
48bc: 32 64           LEAS   $4,S
48be: 32 62           LEAS   $2,S
48c0: 39              RTS
48c1: fc 56 05        LDD    $5605
48c4: 17 b4 89        LBSR   $FD50
48c7: ce 00 00        LDU    #$0000
48ca: 34 40           PSHS   U
48cc: 8d b3           BSR    $4881
48ce: 32 62           LEAS   $2,S
48d0: ce 00 00        LDU    #$0000
48d3: 34 40           PSHS   U
48d5: 17 13 1d        LBSR   $5BF5
48d8: 32 62           LEAS   $2,S
48da: ce 3c 10        LDU    #$3C10
48dd: f6 3c 05        LDB    $3C05
48e0: 4f              CLRA
48e1: 1f 02           TFR    D,Y
48e3: 34 60           PSHS   U,Y
48e5: 86 01           LDA    #$01
48e7: 8e 56 03        LDX    #$5603
48ea: 17 b3 fd        LBSR   $FCEA
48ed: fc 3c 07        LDD    $3C07
48f0: ed 84           STD    ,X
48f2: ce 3c 10        LDU    #$3C10
48f5: f6 3c 05        LDB    $3C05
48f8: 4f              CLRA
48f9: 1f 02           TFR    D,Y
48fb: 34 60           PSHS   U,Y
48fd: 86 01           LDA    #$01
48ff: 8e 56 03        LDX    #$5603
4902: 17 b3 e5        LBSR   $FCEA
4905: 30 02           LEAX   $2,X
4907: fc 3c 09        LDD    $3C09
490a: ed 84           STD    ,X
490c: fc 3c 0b        LDD    $3C0B
490f: fd 3d 0f        STD    $3D0F
4912: f6 3c 06        LDB    $3C06
4915: 4f              CLRA
4916: 1f 03           TFR    D,U
4918: 5f              CLRB
4919: 1d              SEX
491a: 1f 02           TFR    D,Y
491c: 8e 00 04        LDX    #$0004
491f: 34 70           PSHS   U,Y,X
4921: 17 fc 09        LBSR   $452D
4924: 32 66           LEAS   $6,S
4926: 7f 3c 04        CLR    $3C04
4929: 32 62           LEAS   $2,S
492b: 39              RTS
492c: fc 56 05        LDD    $5605
492f: 17 b4 1e        LBSR   $FD50
4932: f6 3c 03        LDB    $3C03
4935: c1 00           CMPB   #$00
4937: 10 27 00 82     LBEQ   $49BD
493b: ce 00 00        LDU    #$0000
493e: 34 40           PSHS   U
4940: 17 ff 3e        LBSR   $4881
4943: 32 62           LEAS   $2,S
4945: 5f              CLRB
4946: 1d              SEX
4947: 1f 03           TFR    D,U
4949: 10 8e 00 02     LDY    #$0002
494d: 34 60           PSHS   U,Y
494f: 17 fb bd        LBSR   $450F
4952: 32 64           LEAS   $4,S
4954: f7 3c 06        STB    $3C06
4957: f6 3c 06        LDB    $3C06
495a: f7 3c 05        STB    $3C05
495d: ce 3c 10        LDU    #$3C10
4960: f6 3c 05        LDB    $3C05
4963: 4f              CLRA
4964: 1f 02           TFR    D,Y
4966: 34 60           PSHS   U,Y
4968: 86 01           LDA    #$01
496a: 8e 56 03        LDX    #$5603
496d: 17 b3 7a        LBSR   $FCEA
4970: ae 84           LDX    ,X
4972: bf 3c 07        STX    $3C07
4975: ce 3c 10        LDU    #$3C10
4978: f6 3c 05        LDB    $3C05
497b: 4f              CLRA
497c: 1f 02           TFR    D,Y
497e: 34 60           PSHS   U,Y
4980: 86 01           LDA    #$01
4982: 8e 56 03        LDX    #$5603
4985: 17 b3 62        LBSR   $FCEA
4988: 30 02           LEAX   $2,X
498a: ae 84           LDX    ,X
498c: bf 3c 09        STX    $3C09
498f: fc 3d 0f        LDD    $3D0F
4992: fd 3c 0b        STD    $3C0B
4995: 7f 3d 1c        CLR    $3D1C
4998: ce 00 00        LDU    #$0000
499b: 34 40           PSHS   U
499d: 17 0c 7a        LBSR   $561A
49a0: 32 62           LEAS   $2,S
49a2: c6 01           LDB    #$01
49a4: f7 3c 04        STB    $3C04
49a7: cc 00 0d        LDD    #$000D
49aa: fd 3d 11        STD    $3D11
49ad: ce 00 03        LDU    #$0003
49b0: 10 8e 00 02     LDY    #$0002
49b4: 34 60           PSHS   U,Y
49b6: be 3c 0e        LDX    $3C0E
49b9: ad 84           JSR    ,X
49bb: 32 64           LEAS   $4,S
49bd: 32 62           LEAS   $2,S
49bf: 39              RTS
49c0: fc 56 05        LDD    $5605
49c3: 17 b3 8a        LBSR   $FD50
49c6: cc 00 0b        LDD    #$000B
49c9: fd 3d 11        STD    $3D11
49cc: c6 01           LDB    #$01
49ce: f7 3c 82        STB    $3C82
49d1: c6 01           LDB    #$01
49d3: 1d              SEX
49d4: 1f 03           TFR    D,U
49d6: 10 8e 00 02     LDY    #$0002
49da: 34 60           PSHS   U,Y
49dc: 17 21 b3        LBSR   $6B92
49df: 32 64           LEAS   $4,S
49e1: ce 00 00        LDU    #$0000
49e4: 34 40           PSHS   U
49e6: 17 12 32        LBSR   $5C1B
49e9: 32 62           LEAS   $2,S
49eb: 32 62           LEAS   $2,S
49ed: 39              RTS
49ee: fc 56 05        LDD    $5605
49f1: 17 b3 5c        LBSR   $FD50
49f4: f6 3c 80        LDB    $3C80
49f7: c1 00           CMPB   #$00
49f9: 10 26 00 19     LBNE   $4A16
49fd: ce 00 00        LDU    #$0000
4a00: 34 40           PSHS   U
4a02: 8d bc           BSR    $49C0
4a04: 32 62           LEAS   $2,S
4a06: ce 00 04        LDU    #$0004
4a09: 10 8e 00 02     LDY    #$0002
4a0d: 34 60           PSHS   U,Y
4a0f: be 3c 0e        LDX    $3C0E
4a12: ad 84           JSR    ,X
4a14: 32 64           LEAS   $4,S
4a16: 32 62           LEAS   $2,S
4a18: 39              RTS
4a19: fc 56 05        LDD    $5605
4a1c: 17 b3 31        LBSR   $FD50
4a1f: 5f              CLRB
4a20: 4f              CLRA
4a21: fd 3d 11        STD    $3D11
4a24: 7f 3c 82        CLR    $3C82
4a27: 7f 3c 81        CLR    $3C81
4a2a: f6 3c 80        LDB    $3C80
4a2d: c1 00           CMPB   #$00
4a2f: 10 27 00 0a     LBEQ   $4A3D
4a33: ce 00 00        LDU    #$0000
4a36: 34 40           PSHS   U
4a38: 17 21 e7        LBSR   $6C22
4a3b: 32 62           LEAS   $2,S
4a3d: 5f              CLRB
4a3e: 1d              SEX
4a3f: 1f 03           TFR    D,U
4a41: 10 8e 00 02     LDY    #$0002
4a45: 34 60           PSHS   U,Y
4a47: 17 fc b8        LBSR   $4702
4a4a: 32 64           LEAS   $4,S
4a4c: c6 01           LDB    #$01
4a4e: 1d              SEX
4a4f: 1f 03           TFR    D,U
4a51: 10 8e 00 02     LDY    #$0002
4a55: 34 60           PSHS   U,Y
4a57: 17 fc a8        LBSR   $4702
4a5a: 32 64           LEAS   $4,S
4a5c: 32 62           LEAS   $2,S
4a5e: 39              RTS
4a5f: fc 56 05        LDD    $5605
4a62: 17 b2 eb        LBSR   $FD50
4a65: 7f 3c 82        CLR    $3C82
4a68: c6 01           LDB    #$01
4a6a: f7 3c 81        STB    $3C81
4a6d: f6 3c 80        LDB    $3C80
4a70: c1 00           CMPB   #$00
4a72: 10 27 00 0a     LBEQ   $4A80
4a76: ce 00 00        LDU    #$0000
4a79: 34 40           PSHS   U
4a7b: 17 21 a4        LBSR   $6C22
4a7e: 32 62           LEAS   $2,S
4a80: 5f              CLRB
4a81: 1d              SEX
4a82: 1f 03           TFR    D,U
4a84: 10 8e 00 02     LDY    #$0002
4a88: 34 60           PSHS   U,Y
4a8a: 17 fc 75        LBSR   $4702
4a8d: 32 64           LEAS   $4,S
4a8f: c6 01           LDB    #$01
4a91: 1d              SEX
4a92: 1f 03           TFR    D,U
4a94: 10 8e 00 02     LDY    #$0002
4a98: 34 60           PSHS   U,Y
4a9a: 17 fc 65        LBSR   $4702
4a9d: 32 64           LEAS   $4,S
4a9f: 32 62           LEAS   $2,S
4aa1: 39              RTS
4aa2: fc 56 05        LDD    $5605
4aa5: 17 b2 a8        LBSR   $FD50
4aa8: 5f              CLRB
4aa9: 4f              CLRA
4aaa: fd 3d 11        STD    $3D11
4aad: ce 00 00        LDU    #$0000
4ab0: 34 40           PSHS   U
4ab2: 8d ab           BSR    $4A5F
4ab4: 32 62           LEAS   $2,S
4ab6: 32 62           LEAS   $2,S
4ab8: 39              RTS
4ab9: fc 56 05        LDD    $5605
4abc: 17 b2 91        LBSR   $FD50
4abf: 5f              CLRB
4ac0: 4f              CLRA
4ac1: fd 3d 11        STD    $3D11
4ac4: ce 00 00        LDU    #$0000
4ac7: 34 40           PSHS   U
4ac9: 17 fd b5        LBSR   $4881
4acc: 32 62           LEAS   $2,S
4ace: 32 62           LEAS   $2,S
4ad0: 39              RTS
4ad1: fc 56 05        LDD    $5605
4ad4: 17 b2 79        LBSR   $FD50
4ad7: f6 3c 80        LDB    $3C80
4ada: c1 00           CMPB   #$00
4adc: 10 26 00 0a     LBNE   $4AEA
4ae0: ce 00 00        LDU    #$0000
4ae3: 34 40           PSHS   U
4ae5: 17 93 ce        LBSR   $DEB6
4ae8: 32 62           LEAS   $2,S
4aea: 32 62           LEAS   $2,S
4aec: 39              RTS
4aed: fc 56 10        LDD    $5610
4af0: 17 b2 5d        LBSR   $FD50
4af3: cc 56 09        LDD    #$5609
4af6: ed 6d           STD    $D,S
4af8: be 22 17        LDX    $2217
4afb: 8c 00 37        CMPX   #$0037
4afe: 10 26 00 28     LBNE   $4B2A
4b02: cc 3c 10        LDD    #$3C10
4b05: ed 66           STD    $6,S
4b07: cc 3c 12        LDD    #$3C12
4b0a: ed 68           STD    $8,S
4b0c: ce 3c 10        LDU    #$3C10
4b0f: f6 3d 1b        LDB    $3D1B
4b12: 4f              CLRA
4b13: 1f 02           TFR    D,Y
4b15: 34 60           PSHS   U,Y
4b17: 86 01           LDA    #$01
4b19: 8e 56 03        LDX    #$5603
4b1c: 17 b1 cb        LBSR   $FCEA
4b1f: ae 84           LDX    ,X
4b21: af 62           STX    $2,S
4b23: c6 4b           LDB    #$4B
4b25: e7 6c           STB    $C,S
4b27: 16 00 27        LBRA   $4B51
4b2a: cc 3c 12        LDD    #$3C12
4b2d: ed 66           STD    $6,S
4b2f: cc 3c 10        LDD    #$3C10
4b32: ed 68           STD    $8,S
4b34: ce 3c 10        LDU    #$3C10
4b37: f6 3d 1b        LDB    $3D1B
4b3a: 4f              CLRA
4b3b: 1f 02           TFR    D,Y
4b3d: 34 60           PSHS   U,Y
4b3f: 86 01           LDA    #$01
4b41: 8e 56 03        LDX    #$5603
4b44: 17 b1 a3        LBSR   $FCEA
4b47: 30 02           LEAX   $2,X
4b49: ae 84           LDX    ,X
4b4b: af 62           STX    $2,S
4b4d: c6 60           LDB    #$60
4b4f: e7 6c           STB    $C,S
4b51: c6 01           LDB    #$01
4b53: 1d              SEX
4b54: 1f 03           TFR    D,U
4b56: 10 ae 6d        LDY    $D,S
4b59: c6 07           LDB    #$07
4b5b: 1d              SEX
4b5c: 1f 01           TFR    D,X
4b5e: e6 6c           LDB    $C,S
4b60: 4f              CLRA
4b61: 34 76           PSHS   U,Y,X,D
4b63: ce 00 08        LDU    #$0008
4b66: 34 40           PSHS   U
4b68: 17 0b 39        LBSR   $56A4
4b6b: 32 6a           LEAS   $A,S
4b6d: 6f 6b           CLR    $B,S
4b6f: e6 6b           LDB    $B,S
4b71: c1 10           CMPB   #$10
4b73: 10 24 00 5c     LBCC   $4BD3
4b77: c6 01           LDB    #$01
4b79: e7 6a           STB    $A,S
4b7b: ae 62           LDX    $2,S
4b7d: 8c 00 00        CMPX   #$0000
4b80: 10 26 00 0c     LBNE   $4B90
4b84: ae f8 08        LDX    [$08,S]
4b87: 8c 00 00        CMPX   #$0000
4b8a: 10 26 00 02     LBNE   $4B90
4b8e: 6f 6a           CLR    $A,S
4b90: e6 6a           LDB    $A,S
4b92: c1 00           CMPB   #$00
4b94: 10 27 00 08     LBEQ   $4BA0
4b98: ec 62           LDD    $2,S
4b9a: ed f8 06        STD    [$06,S]
4b9d: 16 00 05        LBRA   $4BA5
4ba0: c6 33           LDB    #$33
4ba2: f7 3c 02        STB    $3C02
4ba5: c6 02           LDB    #$02
4ba7: 1d              SEX
4ba8: 58              ASLB
4ba9: 49              ROLA
4baa: ae 66           LDX    $6,S
4bac: 30 8b           LEAX   D,X
4bae: af 66           STX    $6,S
4bb0: c6 02           LDB    #$02
4bb2: 1d              SEX
4bb3: 58              ASLB
4bb4: 49              ROLA
4bb5: ae 68           LDX    $8,S
4bb7: 30 8b           LEAX   D,X
4bb9: af 68           STX    $8,S
4bbb: c6 14           LDB    #$14
4bbd: 1d              SEX
4bbe: 1f 03           TFR    D,U
4bc0: 10 8e 00 02     LDY    #$0002
4bc4: 34 60           PSHS   U,Y
4bc6: 17 8a a7        LBSR   $D670
4bc9: 32 64           LEAS   $4,S
4bcb: e6 6b           LDB    $B,S
4bcd: cb 01           ADDB   #$01
4bcf: e7 6b           STB    $B,S
4bd1: 20 9c           BRA    $4B6F
4bd3: ce 00 00        LDU    #$0000
4bd6: 34 40           PSHS   U
4bd8: 17 10 f1        LBSR   $5CCC
4bdb: 32 62           LEAS   $2,S
4bdd: be 22 17        LDX    $2217
4be0: 8c 00 37        CMPX   #$0037
4be3: 10 26 00 0d     LBNE   $4BF4
4be7: ce 00 00        LDU    #$0000
4bea: 34 40           PSHS   U
4bec: 17 fc 53        LBSR   $4842
4bef: 32 62           LEAS   $2,S
4bf1: 16 00 0a        LBRA   $4BFE
4bf4: ce 00 00        LDU    #$0000
4bf7: 34 40           PSHS   U
4bf9: 17 fc 64        LBSR   $4860
4bfc: 32 62           LEAS   $2,S
4bfe: 32 6f           LEAS   $F,S
4c00: 39              RTS
4c01: fc 56 12        LDD    $5612
4c04: 17 b1 49        LBSR   $FD50
4c07: 7f 3c 02        CLR    $3C02
4c0a: 5f              CLRB
4c0b: 1d              SEX
4c0c: 1f 03           TFR    D,U
4c0e: 10 8e 00 02     LDY    #$0002
4c12: 34 60           PSHS   U,Y
4c14: 17 1e cc        LBSR   $6AE3
4c17: 32 64           LEAS   $4,S
4c19: f6 3c 04        LDB    $3C04
4c1c: c1 00           CMPB   #$00
4c1e: 10 27 00 0a     LBEQ   $4C2C
4c22: ce 00 00        LDU    #$0000
4c25: 34 40           PSHS   U
4c27: 17 fc 97        LBSR   $48C1
4c2a: 32 62           LEAS   $2,S
4c2c: f6 23 be        LDB    $23BE
4c2f: e7 62           STB    $2,S
4c31: f6 23 be        LDB    $23BE
4c34: c1 00           CMPB   #$00
4c36: 10 27 00 0d     LBEQ   $4C47
4c3a: 7f 23 be        CLR    $23BE
4c3d: ce 00 00        LDU    #$0000
4c40: 34 40           PSHS   U
4c42: 17 75 d5        LBSR   $C21A
4c45: 32 62           LEAS   $2,S
4c47: be 22 17        LDX    $2217
4c4a: 16 04 2c        LBRA   $5079
4c4d: ce 00 00        LDU    #$0000
4c50: 34 40           PSHS   U
4c52: 17 fb 81        LBSR   $47D6
4c55: 32 62           LEAS   $2,S
4c57: ce 00 00        LDU    #$0000
4c5a: 34 40           PSHS   U
4c5c: 17 3d d0        LBSR   $8A2F
4c5f: 32 62           LEAS   $2,S
4c61: 16 04 a0        LBRA   $5104
4c64: 5f              CLRB
4c65: 4f              CLRA
4c66: fd 3d 11        STD    $3D11
4c69: f6 3c 8f        LDB    $3C8F
4c6c: c1 01           CMPB   #$01
4c6e: 10 26 00 0d     LBNE   $4C7F
4c72: ce 00 00        LDU    #$0000
4c75: 34 40           PSHS   U
4c77: 17 fe 73        LBSR   $4AED
4c7a: 32 62           LEAS   $2,S
4c7c: 16 00 05        LBRA   $4C84
4c7f: c6 3b           LDB    #$3B
4c81: f7 3c 02        STB    $3C02
4c84: 16 04 7d        LBRA   $5104
4c87: ce 00 00        LDU    #$0000
4c8a: 34 40           PSHS   U
4c8c: 17 fb 47        LBSR   $47D6
4c8f: 32 62           LEAS   $2,S
4c91: ce 00 00        LDU    #$0000
4c94: 34 40           PSHS   U
4c96: 17 3d 96        LBSR   $8A2F
4c99: 32 62           LEAS   $2,S
4c9b: 5f              CLRB
4c9c: 4f              CLRA
4c9d: fd 3d 11        STD    $3D11
4ca0: ce 00 00        LDU    #$0000
4ca3: 34 40           PSHS   U
4ca5: 17 f9 e1        LBSR   $4689
4ca8: 32 62           LEAS   $2,S
4caa: 16 04 57        LBRA   $5104
4cad: ce 00 00        LDU    #$0000
4cb0: 34 40           PSHS   U
4cb2: 17 fb 21        LBSR   $47D6
4cb5: 32 62           LEAS   $2,S
4cb7: cc 00 0c        LDD    #$000C
4cba: fd 3d 11        STD    $3D11
4cbd: ce 00 21        LDU    #$0021
4cc0: 10 8e 00 02     LDY    #$0002
4cc4: 34 60           PSHS   U,Y
4cc6: 17 a6 68        LBSR   $F331
4cc9: 32 64           LEAS   $4,S
4ccb: 16 04 36        LBRA   $5104
4cce: f6 3c 0d        LDB    $3C0D
4cd1: c1 00           CMPB   #$00
4cd3: 10 27 00 0a     LBEQ   $4CE1
4cd7: ce 00 00        LDU    #$0000
4cda: 34 40           PSHS   U
4cdc: 17 7b a6        LBSR   $C885
4cdf: 32 62           LEAS   $2,S
4ce1: ce 00 00        LDU    #$0000
4ce4: 34 40           PSHS   U
4ce6: 17 15 99        LBSR   $6282
4ce9: 32 62           LEAS   $2,S
4ceb: be 3d 11        LDX    $3D11
4cee: 8c 00 01        CMPX   #$0001
4cf1: 10 26 00 0a     LBNE   $4CFF
4cf5: ce 00 00        LDU    #$0000
4cf8: 34 40           PSHS   U
4cfa: 17 fd d4        LBSR   $4AD1
4cfd: 32 62           LEAS   $2,S
4cff: 16 04 02        LBRA   $5104
4d02: f6 3c 03        LDB    $3C03
4d05: c1 00           CMPB   #$00
4d07: 10 26 00 34     LBNE   $4D3F
4d0b: f6 3c 8f        LDB    $3C8F
4d0e: c1 01           CMPB   #$01
4d10: 10 26 00 23     LBNE   $4D37
4d14: cc 00 01        LDD    #$0001
4d17: fd 3d 11        STD    $3D11
4d1a: ce 00 00        LDU    #$0000
4d1d: 34 40           PSHS   U
4d1f: 17 fa b4        LBSR   $47D6
4d22: 32 62           LEAS   $2,S
4d24: ce 00 00        LDU    #$0000
4d27: 10 8e 00 02     LDY    #$0002
4d2b: 34 60           PSHS   U,Y
4d2d: be 3c 0e        LDX    $3C0E
4d30: ad 84           JSR    ,X
4d32: 32 64           LEAS   $4,S
4d34: 16 00 05        LBRA   $4D3C
4d37: c6 3b           LDB    #$3B
4d39: f7 3c 02        STB    $3C02
4d3c: 16 00 05        LBRA   $4D44
4d3f: c6 3a           LDB    #$3A
4d41: f7 3c 02        STB    $3C02
4d44: 16 03 bd        LBRA   $5104
4d47: f6 3c 8f        LDB    $3C8F
4d4a: c1 03           CMPB   #$03
4d4c: 10 26 00 23     LBNE   $4D73
4d50: cc 00 03        LDD    #$0003
4d53: fd 3d 11        STD    $3D11
4d56: ce 00 00        LDU    #$0000
4d59: 34 40           PSHS   U
4d5b: 17 fa 78        LBSR   $47D6
4d5e: 32 62           LEAS   $2,S
4d60: ce 00 01        LDU    #$0001
4d63: 10 8e 00 02     LDY    #$0002
4d67: 34 60           PSHS   U,Y
4d69: be 3c 0e        LDX    $3C0E
4d6c: ad 84           JSR    ,X
4d6e: 32 64           LEAS   $4,S
4d70: 16 00 05        LBRA   $4D78
4d73: c6 3b           LDB    #$3B
4d75: f7 3c 02        STB    $3C02
4d78: 16 03 89        LBRA   $5104
4d7b: be 3d 11        LDX    $3D11
4d7e: 16 00 92        LBRA   $4E13
4d81: cc 00 02        LDD    #$0002
4d84: fd 3d 11        STD    $3D11
4d87: ce 00 00        LDU    #$0000
4d8a: 34 40           PSHS   U
4d8c: 17 0a d0        LBSR   $585F
4d8f: 32 62           LEAS   $2,S
4d91: c6 01           LDB    #$01
4d93: f7 3c 0d        STB    $3C0D
4d96: cc 58 26        LDD    #$5826
4d99: fd 3c 00        STD    $3C00
4d9c: ce 00 00        LDU    #$0000
4d9f: 10 8e 00 02     LDY    #$0002
4da3: 34 60           PSHS   U,Y
4da5: be 3c 0e        LDX    $3C0E
4da8: ad 84           JSR    ,X
4daa: 32 64           LEAS   $4,S
4dac: 16 00 83        LBRA   $4E32
4daf: cc 00 04        LDD    #$0004
4db2: fd 3d 11        STD    $3D11
4db5: ce 00 00        LDU    #$0000
4db8: 34 40           PSHS   U
4dba: 17 0b b1        LBSR   $596E
4dbd: 32 62           LEAS   $2,S
4dbf: c6 01           LDB    #$01
4dc1: f7 3c 0d        STB    $3C0D
4dc4: cc 59 3a        LDD    #$593A
4dc7: fd 3c 00        STD    $3C00
4dca: ce 00 01        LDU    #$0001
4dcd: 10 8e 00 02     LDY    #$0002
4dd1: 34 60           PSHS   U,Y
4dd3: be 3c 0e        LDX    $3C0E
4dd6: ad 84           JSR    ,X
4dd8: 32 64           LEAS   $4,S
4dda: 16 00 55        LBRA   $4E32
4ddd: cc 00 06        LDD    #$0006
4de0: fd 3d 11        STD    $3D11
4de3: ce 00 00        LDU    #$0000
4de6: 34 40           PSHS   U
4de8: 17 0c e6        LBSR   $5AD1
4deb: 32 62           LEAS   $2,S
4ded: c6 01           LDB    #$01
4def: f7 3c 0d        STB    $3C0D
4df2: cc 5a ae        LDD    #$5AAE
4df5: fd 3c 00        STD    $3C00
4df8: ce 00 02        LDU    #$0002
4dfb: 10 8e 00 02     LDY    #$0002
4dff: 34 60           PSHS   U,Y
4e01: be 3c 0e        LDX    $3C0E
4e04: ad 84           JSR    ,X
4e06: 32 64           LEAS   $4,S
4e08: 16 00 27        LBRA   $4E32
4e0b: c6 14           LDB    #$14
4e0d: f7 3c 02        STB    $3C02
4e10: 16 00 1f        LBRA   $4E32
4e13: 8c 00 06        CMPX   #$0006
4e16: 2e f3           BGT    $4E0B
4e18: 1f 10           TFR    X,D
4e1a: 83 00 01        SUBD   #$0001
4e1d: 2d ec           BLT    $4E0B
4e1f: 8e 4e 26        LDX    #$4E26
4e22: 58              ASLB
4e23: 49              ROLA
4e24: 6e 9b           JMP    [D,X]
4e26: 4d              TSTA
4e27: 81 4d           CMPA   #$4D
4e29: 87 4d           XSTA   #$4D
4e2b: af 4d           STX    $D,U
4e2d: b5 4d dd        BITA   $4DDD
4e30: 4d              TSTA
4e31: e3 16           ADDD   -$A,X
4e33: 02 cf           XNC    <$CF
4e35: f6 3c 0d        LDB    $3C0D
4e38: c1 00           CMPB   #$00
4e3a: 10 27 00 0a     LBEQ   $4E48
4e3e: ce 00 00        LDU    #$0000
4e41: 34 40           PSHS   U
4e43: 17 7a 3f        LBSR   $C885
4e46: 32 62           LEAS   $2,S
4e48: c6 01           LDB    #$01
4e4a: 1d              SEX
4e4b: 1f 03           TFR    D,U
4e4d: 10 8e 00 02     LDY    #$0002
4e51: 34 60           PSHS   U,Y
4e53: 17 18 17        LBSR   $666D
4e56: 32 64           LEAS   $4,S
4e58: be 3d 11        LDX    $3D11
4e5b: 8c 00 01        CMPX   #$0001
4e5e: 10 26 00 0a     LBNE   $4E6C
4e62: ce 00 00        LDU    #$0000
4e65: 34 40           PSHS   U
4e67: 17 fc 67        LBSR   $4AD1
4e6a: 32 62           LEAS   $2,S
4e6c: 16 02 95        LBRA   $5104
4e6f: f6 3c 0d        LDB    $3C0D
4e72: c1 00           CMPB   #$00
4e74: 10 27 00 0a     LBEQ   $4E82
4e78: ce 00 00        LDU    #$0000
4e7b: 34 40           PSHS   U
4e7d: 17 7a 05        LBSR   $C885
4e80: 32 62           LEAS   $2,S
4e82: 5f              CLRB
4e83: 1d              SEX
4e84: 1f 03           TFR    D,U
4e86: 10 8e 00 02     LDY    #$0002
4e8a: 34 60           PSHS   U,Y
4e8c: 17 17 de        LBSR   $666D
4e8f: 32 64           LEAS   $4,S
4e91: be 3d 11        LDX    $3D11
4e94: 8c 00 01        CMPX   #$0001
4e97: 10 26 00 0a     LBNE   $4EA5
4e9b: ce 00 00        LDU    #$0000
4e9e: 34 40           PSHS   U
4ea0: 17 fc 2e        LBSR   $4AD1
4ea3: 32 62           LEAS   $2,S
4ea5: 16 02 5c        LBRA   $5104
4ea8: f6 3c 80        LDB    $3C80
4eab: c1 00           CMPB   #$00
4ead: 10 27 00 0a     LBEQ   $4EBB
4eb1: ce 00 00        LDU    #$0000
4eb4: 34 40           PSHS   U
4eb6: 17 f9 c8        LBSR   $4881
4eb9: 32 62           LEAS   $2,S
4ebb: ce 00 00        LDU    #$0000
4ebe: 34 40           PSHS   U
4ec0: 17 0e 6f        LBSR   $5D32
4ec3: 32 62           LEAS   $2,S
4ec5: 16 02 3c        LBRA   $5104
4ec8: 86 02           LDA    #$02
4eca: f6 3c 8f        LDB    $3C8F
4ecd: 17 ae bf        LBSR   $FD8F
4ed0: 1f 03           TFR    D,U
4ed2: 10 8e 00 02     LDY    #$0002
4ed6: 34 60           PSHS   U,Y
4ed8: 17 24 95        LBSR   $7370
4edb: 32 64           LEAS   $4,S
4edd: 16 02 24        LBRA   $5104
4ee0: ce 00 00        LDU    #$0000
4ee3: 34 40           PSHS   U
4ee5: 17 f9 12        LBSR   $47FA
4ee8: 32 62           LEAS   $2,S
4eea: 16 02 17        LBRA   $5104
4eed: cc 00 01        LDD    #$0001
4ef0: fd 3d 11        STD    $3D11
4ef3: ce 00 00        LDU    #$0000
4ef6: 34 40           PSHS   U
4ef8: 17 f8 db        LBSR   $47D6
4efb: 32 62           LEAS   $2,S
4efd: ce 00 00        LDU    #$0000
4f00: 10 8e 00 02     LDY    #$0002
4f04: 34 60           PSHS   U,Y
4f06: be 3c 0e        LDX    $3C0E
4f09: ad 84           JSR    ,X
4f0b: 32 64           LEAS   $4,S
4f0d: 16 01 f4        LBRA   $5104
4f10: ce 00 00        LDU    #$0000
4f13: 34 40           PSHS   U
4f15: 17 f9 2a        LBSR   $4842
4f18: 32 62           LEAS   $2,S
4f1a: 16 01 e7        LBRA   $5104
4f1d: ce 00 00        LDU    #$0000
4f20: 34 40           PSHS   U
4f22: 17 f9 3b        LBSR   $4860
4f25: 32 62           LEAS   $2,S
4f27: 16 01 da        LBRA   $5104
4f2a: cc 00 03        LDD    #$0003
4f2d: fd 3d 11        STD    $3D11
4f30: ce 00 00        LDU    #$0000
4f33: 34 40           PSHS   U
4f35: 17 f8 9e        LBSR   $47D6
4f38: 32 62           LEAS   $2,S
4f3a: ce 00 01        LDU    #$0001
4f3d: 10 8e 00 02     LDY    #$0002
4f41: 34 60           PSHS   U,Y
4f43: be 3c 0e        LDX    $3C0E
4f46: ad 84           JSR    ,X
4f48: 32 64           LEAS   $4,S
4f4a: 16 01 b7        LBRA   $5104
4f4d: ce 00 00        LDU    #$0000
4f50: 34 40           PSHS   U
4f52: 17 fa c4        LBSR   $4A19
4f55: 32 62           LEAS   $2,S
4f57: 16 01 aa        LBRA   $5104
4f5a: f6 3c 80        LDB    $3C80
4f5d: c1 00           CMPB   #$00
4f5f: 10 27 00 0f     LBEQ   $4F72
4f63: 5f              CLRB
4f64: 1d              SEX
4f65: 1f 03           TFR    D,U
4f67: 10 8e 00 02     LDY    #$0002
4f6b: 34 60           PSHS   U,Y
4f6d: 17 f7 92        LBSR   $4702
4f70: 32 64           LEAS   $4,S
4f72: f6 3c 8f        LDB    $3C8F
4f75: c1 03           CMPB   #$03
4f77: 10 26 00 10     LBNE   $4F8B
4f7b: c6 08           LDB    #$08
4f7d: 1d              SEX
4f7e: 1f 03           TFR    D,U
4f80: 10 8e 00 02     LDY    #$0002
4f84: 34 60           PSHS   U,Y
4f86: 17 28 b6        LBSR   $783F
4f89: 32 64           LEAS   $4,S
4f8b: ce 00 00        LDU    #$0000
4f8e: 34 40           PSHS   U
4f90: 17 fa 5b        LBSR   $49EE
4f93: 32 62           LEAS   $2,S
4f95: 16 01 6c        LBRA   $5104
4f98: ce 00 00        LDU    #$0000
4f9b: 34 40           PSHS   U
4f9d: 17 fb 02        LBSR   $4AA2
4fa0: 32 62           LEAS   $2,S
4fa2: 16 01 5f        LBRA   $5104
4fa5: ce 00 00        LDU    #$0000
4fa8: 34 40           PSHS   U
4faa: 17 fb 0c        LBSR   $4AB9
4fad: 32 62           LEAS   $2,S
4faf: 16 01 52        LBRA   $5104
4fb2: f6 3c 8f        LDB    $3C8F
4fb5: c1 03           CMPB   #$03
4fb7: 10 26 00 3f     LBNE   $4FFA
4fbb: f6 3c 82        LDB    $3C82
4fbe: c1 00           CMPB   #$00
4fc0: 10 27 00 29     LBEQ   $4FED
4fc4: c6 08           LDB    #$08
4fc6: 1d              SEX
4fc7: 1f 03           TFR    D,U
4fc9: 10 8e 00 02     LDY    #$0002
4fcd: 34 60           PSHS   U,Y
4fcf: 17 28 6d        LBSR   $783F
4fd2: 32 64           LEAS   $4,S
4fd4: cc 00 0b        LDD    #$000B
4fd7: fd 3d 11        STD    $3D11
4fda: ce 00 04        LDU    #$0004
4fdd: 10 8e 00 02     LDY    #$0002
4fe1: 34 60           PSHS   U,Y
4fe3: be 3c 0e        LDX    $3C0E
4fe6: ad 84           JSR    ,X
4fe8: 32 64           LEAS   $4,S
4fea: 16 00 0a        LBRA   $4FF7
4fed: ce 00 00        LDU    #$0000
4ff0: 34 40           PSHS   U
4ff2: 17 21 bf        LBSR   $71B4
4ff5: 32 62           LEAS   $2,S
4ff7: 16 00 0a        LBRA   $5004
4ffa: ce 00 00        LDU    #$0000
4ffd: 34 40           PSHS   U
4fff: 17 21 b2        LBSR   $71B4
5002: 32 62           LEAS   $2,S
5004: 16 00 fd        LBRA   $5104
5007: f6 3c 8f        LDB    $3C8F
500a: c1 03           CMPB   #$03
500c: 10 26 00 2b     LBNE   $503B
5010: f6 3c 82        LDB    $3C82
5013: c1 00           CMPB   #$00
5015: 10 27 00 13     LBEQ   $502C
5019: c6 08           LDB    #$08
501b: 1d              SEX
501c: 1f 03           TFR    D,U
501e: 10 8e 00 02     LDY    #$0002
5022: 34 60           PSHS   U,Y
5024: 17 28 18        LBSR   $783F
5027: 32 64           LEAS   $4,S
5029: 16 00 0f        LBRA   $503B
502c: 5f              CLRB
502d: 1d              SEX
502e: 1f 03           TFR    D,U
5030: 10 8e 00 02     LDY    #$0002
5034: 34 60           PSHS   U,Y
5036: 17 28 06        LBSR   $783F
5039: 32 64           LEAS   $4,S
503b: ce 00 00        LDU    #$0000
503e: 34 40           PSHS   U
5040: 17 21 9b        LBSR   $71DE
5043: 32 62           LEAS   $2,S
5045: 16 00 bc        LBRA   $5104
5048: ce 00 00        LDU    #$0000
504b: 34 40           PSHS   U
504d: 17 29 73        LBSR   $79C3
5050: 32 62           LEAS   $2,S
5052: 16 00 af        LBRA   $5104
5055: ce 00 00        LDU    #$0000
5058: 34 40           PSHS   U
505a: 17 73 bb        LBSR   $C418
505d: 32 62           LEAS   $2,S
505f: ce 00 00        LDU    #$0000
5062: 34 40           PSHS   U
5064: 17 f7 6f        LBSR   $47D6
5067: 32 62           LEAS   $2,S
5069: 5f              CLRB
506a: 4f              CLRA
506b: fd 3d 11        STD    $3D11
506e: 16 00 93        LBRA   $5104
5071: c6 3a           LDB    #$3A
5073: f7 3c 02        STB    $3C02
5076: 16 00 8b        LBRA   $5104
5079: 8c 00 3c        CMPX   #$003C
507c: 2e f3           BGT    $5071
507e: 1f 10           TFR    X,D
5080: 83 00 01        SUBD   #$0001
5083: 2d ec           BLT    $5071
5085: 8e 50 8c        LDX    #$508C
5088: 58              ASLB
5089: 49              ROLA
508a: 6e 9b           JMP    [D,X]
508c: 50              NEGB
508d: 5f              CLRB
508e: 50              NEGB
508f: 71 50 71        NEG    $5071
5092: 50              NEGB
5093: 71 50 71        NEG    $5071
5096: 50              NEGB
5097: 71 50 71        NEG    $5071
509a: 50              NEGB
509b: 5f              CLRB
509c: 50              NEGB
509d: 5f              CLRB
509e: 50              NEGB
509f: 71 50 71        NEG    $5071
50a2: 50              NEGB
50a3: 71 50 5f        NEG    $505F
50a6: 50              NEGB
50a7: 5f              CLRB
50a8: 50              NEGB
50a9: 71 50 55        NEG    $5055
50ac: 50              NEGB
50ad: 5f              CLRB
50ae: 50              NEGB
50af: 71 4c 4d        NEG    $4C4D
50b2: 4c              INCA
50b3: 4d              TSTA
50b4: 4c              INCA
50b5: 4d              TSTA
50b6: 4c              INCA
50b7: 4d              TSTA
50b8: 4c              INCA
50b9: 87 4c           XSTA   #$4C
50bb: 87 4d           XSTA   #$4D
50bd: 02 4d           XNC    <$4D
50bf: 47              ASRA
50c0: 50              NEGB
50c1: 71 50 71        NEG    $5071
50c4: 50              NEGB
50c5: 71 4d 7b        NEG    $4D7B
50c8: 4e              XCLRA
50c9: 6f 4e           CLR    $E,U
50cb: 35 4c           PULS   B,DP,U
50cd: ad 50           JSR    -$10,U
50cf: 71 4c ce        NEG    $4CCE
50d2: 50              NEGB
50d3: 71 4e a8        NEG    $4EA8
50d6: 4e              XCLRA
50d7: c8 4e           EORB   #$4E
50d9: e0 4e           SUBB   $E,U
50db: ed 4f           STD    $F,U
50dd: 2a 50           BPL    $512F
50df: 71 50 71        NEG    $5071
50e2: 50              NEGB
50e3: 48              ASLA
50e4: 4f              CLRA
50e5: 4d              TSTA
50e6: 4f              CLRA
50e7: 98 4f           EORA   <$4F
50e9: 5a              DECB
50ea: 4f              CLRA
50eb: a5 4f           BITA   $F,U
50ed: 10 4f           CLRA
50ef: 1d              SEX
50f0: 4f              CLRA
50f1: b2 50 07        SBCA   $5007
50f4: 50              NEGB
50f5: 71 50 71        NEG    $5071
50f8: 4c              INCA
50f9: 64 4c           LSR    $C,U
50fb: 64 50           LSR    -$10,U
50fd: 71 50 71        NEG    $5071
5100: 50              NEGB
5101: 71 50 5f        NEG    $505F
5104: c6 02           LDB    #$02
5106: 1d              SEX
5107: 1f 03           TFR    D,U
5109: 10 8e 00 02     LDY    #$0002
510d: 34 60           PSHS   U,Y
510f: 17 19 d1        LBSR   $6AE3
5112: 32 64           LEAS   $4,S
5114: f6 3c 02        LDB    $3C02
5117: c1 00           CMPB   #$00
5119: 10 27 00 65     LBEQ   $5182
511d: fc 22 04        LDD    $2204
5120: 84 00           ANDA   #$00
5122: c4 08           ANDB   #$08
5124: 10 83 00 00     CMPD   #$0000
5128: 10 27 00 17     LBEQ   $5143
512c: f6 3c 02        LDB    $3C02
512f: 4f              CLRA
5130: 1f 03           TFR    D,U
5132: 5f              CLRB
5133: 1d              SEX
5134: 1f 02           TFR    D,Y
5136: 8e 00 04        LDX    #$0004
5139: 34 70           PSHS   U,Y,X
513b: 17 4c 95        LBSR   $9DD3
513e: 32 66           LEAS   $6,S
5140: 16 00 11        LBRA   $5154
5143: f6 3c 02        LDB    $3C02
5146: 4f              CLRA
5147: 1f 03           TFR    D,U
5149: 10 8e 00 02     LDY    #$0002
514d: 34 60           PSHS   U,Y
514f: 17 72 ac        LBSR   $C3FE
5152: 32 64           LEAS   $4,S
5154: c6 01           LDB    #$01
5156: e7 63           STB    $3,S
5158: f6 3c 02        LDB    $3C02
515b: c1 3a           CMPB   #$3A
515d: 10 27 00 14     LBEQ   $5175
5161: f6 3c 02        LDB    $3C02
5164: c1 3b           CMPB   #$3B
5166: 10 27 00 0b     LBEQ   $5175
516a: f6 3c 02        LDB    $3C02
516d: c1 14           CMPB   #$14
516f: 10 27 00 02     LBEQ   $5175
5173: 6f 63           CLR    $3,S
5175: e6 63           LDB    $3,S
5177: c1 00           CMPB   #$00
5179: 10 27 00 05     LBEQ   $5182
517d: 5f              CLRB
517e: 4f              CLRA
517f: fd 3d 11        STD    $3D11
5182: 32 64           LEAS   $4,S
5184: 39              RTS
5185: fc 56 05        LDD    $5605
5188: 17 ab c5        LBSR   $FD50
518b: f6 3d 35        LDB    $3D35
518e: c1 00           CMPB   #$00
5190: 10 27 00 4c     LBEQ   $51E0
5194: be 22 17        LDX    $2217
5197: 8c 00 15        CMPX   #$0015
519a: 10 27 00 42     LBEQ   $51E0
519e: be 22 17        LDX    $2217
51a1: 8c 00 16        CMPX   #$0016
51a4: 10 27 00 38     LBEQ   $51E0
51a8: be 22 17        LDX    $2217
51ab: 8c 00 23        CMPX   #$0023
51ae: 10 27 00 2e     LBEQ   $51E0
51b2: be 22 17        LDX    $2217
51b5: 8c 00 20        CMPX   #$0020
51b8: 10 27 00 24     LBEQ   $51E0
51bc: be 22 17        LDX    $2217
51bf: 8c 00 1f        CMPX   #$001F
51c2: 10 27 00 1a     LBEQ   $51E0
51c6: be 22 17        LDX    $2217
51c9: 8c 00 26        CMPX   #$0026
51cc: 10 27 00 10     LBEQ   $51E0
51d0: c6 01           LDB    #$01
51d2: 1d              SEX
51d3: 1f 03           TFR    D,U
51d5: 10 8e 00 02     LDY    #$0002
51d9: 34 60           PSHS   U,Y
51db: 17 1f 82        LBSR   $7160
51de: 32 64           LEAS   $4,S
51e0: 32 62           LEAS   $2,S
51e2: 39              RTS
51e3: fc 56 05        LDD    $5605
51e6: 17 ab 67        LBSR   $FD50
51e9: 5f              CLRB
51ea: 1d              SEX
51eb: 1f 03           TFR    D,U
51ed: 10 8e 00 02     LDY    #$0002
51f1: 34 60           PSHS   U,Y
51f3: 17 f5 0c        LBSR   $4702
51f6: 32 64           LEAS   $4,S
51f8: 5f              CLRB
51f9: 1d              SEX
51fa: 1f 03           TFR    D,U
51fc: 10 8e 00 02     LDY    #$0002
5200: 34 60           PSHS   U,Y
5202: 17 19 8d        LBSR   $6B92
5205: 32 64           LEAS   $4,S
5207: fc 22 04        LDD    $2204
520a: 84 7f           ANDA   #$7F
520c: c4 ff           ANDB   #$FF
520e: fd 22 04        STD    $2204
5211: fc 22 04        LDD    $2204
5214: 84 bf           ANDA   #$BF
5216: c4 ff           ANDB   #$FF
5218: fd 22 04        STD    $2204
521b: cc c2 39        LDD    #$C239
521e: fd 22 11        STD    $2211
5221: 32 62           LEAS   $2,S
5223: 39              RTS
5224: fc 56 03        LDD    $5603
5227: 17 ab 26        LBSR   $FD50
522a: ce 00 00        LDU    #$0000
522d: 34 40           PSHS   U
522f: 17 74 b8        LBSR   $C6EA
5232: 32 62           LEAS   $2,S
5234: ce 00 00        LDU    #$0000
5237: 34 40           PSHS   U
5239: 17 72 b4        LBSR   $C4F0
523c: 32 62           LEAS   $2,S
523e: ce 00 00        LDU    #$0000
5241: 34 40           PSHS   U
5243: 17 73 6b        LBSR   $C5B1
5246: 32 62           LEAS   $2,S
5248: c6 01           LDB    #$01
524a: f7 23 be        STB    $23BE
524d: ce 00 00        LDU    #$0000
5250: 34 40           PSHS   U
5252: 17 6f c5        LBSR   $C21A
5255: 32 62           LEAS   $2,S
5257: f6 3c 03        LDB    $3C03
525a: c1 00           CMPB   #$00
525c: 10 27 00 14     LBEQ   $5274
5260: ce 42 5f        LDU    #$425F
5263: 10 be 23 bf     LDY    $23BF
5267: 8e 00 04        LDX    #$0004
526a: 34 70           PSHS   U,Y,X
526c: 17 81 0e        LBSR   $D37D
526f: 32 66           LEAS   $6,S
5271: 16 00 11        LBRA   $5285
5274: ce 42 5c        LDU    #$425C
5277: 10 be 23 bf     LDY    $23BF
527b: 8e 00 04        LDX    #$0004
527e: 34 70           PSHS   U,Y,X
5280: 17 80 fa        LBSR   $D37D
5283: 32 66           LEAS   $6,S
5285: fe 23 bf        LDU    $23BF
5288: c6 01           LDB    #$01
528a: 1d              SEX
528b: 1f 02           TFR    D,Y
528d: 8e 00 04        LDX    #$0004
5290: 34 70           PSHS   U,Y,X
5292: 17 90 2c        LBSR   $E2C1
5295: 32 66           LEAS   $6,S
5297: be 23 bf        LDX    $23BF
529a: 30 0a           LEAX   $A,X
529c: ce ea 58        LDU    #$EA58
529f: 1f 12           TFR    X,Y
52a1: 8e 00 04        LDX    #$0004
52a4: 34 70           PSHS   U,Y,X
52a6: 17 80 d4        LBSR   $D37D
52a9: 32 66           LEAS   $6,S
52ab: be 23 bf        LDX    $23BF
52ae: 30 0a           LEAX   $A,X
52b0: 1f 13           TFR    X,U
52b2: c6 01           LDB    #$01
52b4: 1d              SEX
52b5: 1f 02           TFR    D,Y
52b7: 8e 00 04        LDX    #$0004
52ba: 34 70           PSHS   U,Y,X
52bc: 17 6d aa        LBSR   $C069
52bf: 32 66           LEAS   $6,S
52c1: 6f 62           CLR    $2,S
52c3: e6 62           LDB    $2,S
52c5: c1 10           CMPB   #$10
52c7: 10 24 00 59     LBCC   $5324
52cb: ce 3c 50        LDU    #$3C50
52ce: e6 62           LDB    $2,S
52d0: 4f              CLRA
52d1: 1f 02           TFR    D,Y
52d3: 34 60           PSHS   U,Y
52d5: 86 01           LDA    #$01
52d7: 8e 56 14        LDX    #$5614
52da: 17 aa 0d        LBSR   $FCEA
52dd: ce ea 58        LDU    #$EA58
52e0: 1f 12           TFR    X,Y
52e2: 8e 00 04        LDX    #$0004
52e5: 34 70           PSHS   U,Y,X
52e7: 17 80 93        LBSR   $D37D
52ea: 32 66           LEAS   $6,S
52ec: ce 3c 10        LDU    #$3C10
52ef: e6 62           LDB    $2,S
52f1: 4f              CLRA
52f2: 1f 02           TFR    D,Y
52f4: 34 60           PSHS   U,Y
52f6: 86 01           LDA    #$01
52f8: 8e 56 03        LDX    #$5603
52fb: 17 a9 ec        LBSR   $FCEA
52fe: cc 00 64        LDD    #$0064
5301: ed 84           STD    ,X
5303: ce 3c 10        LDU    #$3C10
5306: e6 62           LDB    $2,S
5308: 4f              CLRA
5309: 1f 02           TFR    D,Y
530b: 34 60           PSHS   U,Y
530d: 86 01           LDA    #$01
530f: 8e 56 03        LDX    #$5603
5312: 17 a9 d5        LBSR   $FCEA
5315: 30 02           LEAX   $2,X
5317: cc 00 64        LDD    #$0064
531a: ed 84           STD    ,X
531c: e6 62           LDB    $2,S
531e: cb 01           ADDB   #$01
5320: e7 62           STB    $2,S
5322: 20 9f           BRA    $52C3
5324: ce 00 00        LDU    #$0000
5327: 34 40           PSHS   U
5329: 17 17 2b        LBSR   $6A57
532c: 32 62           LEAS   $2,S
532e: 7f 3c 80        CLR    $3C80
5331: 7f 3c 82        CLR    $3C82
5334: cc 00 0a        LDD    #$000A
5337: fd 3c 87        STD    $3C87
533a: cc 00 0a        LDD    #$000A
533d: fd 3c 89        STD    $3C89
5340: cc 00 0a        LDD    #$000A
5343: fd 3c 83        STD    $3C83
5346: cc 00 0a        LDD    #$000A
5349: fd 3c 85        STD    $3C85
534c: cc 00 0a        LDD    #$000A
534f: fd 3c 8b        STD    $3C8B
5352: cc 00 0a        LDD    #$000A
5355: fd 3c 8d        STD    $3C8D
5358: 7f 3d 1b        CLR    $3D1B
535b: 5f              CLRB
535c: 1d              SEX
535d: 1f 03           TFR    D,U
535f: 10 8e 00 02     LDY    #$0002
5363: 34 60           PSHS   U,Y
5365: 17 18 2a        LBSR   $6B92
5368: 32 64           LEAS   $4,S
536a: c6 01           LDB    #$01
536c: 1d              SEX
536d: 1f 03           TFR    D,U
536f: 5f              CLRB
5370: 1d              SEX
5371: 1f 02           TFR    D,Y
5373: 8e 00 04        LDX    #$0004
5376: 34 70           PSHS   U,Y,X
5378: 17 a3 98        LBSR   $F713
537b: 32 66           LEAS   $6,S
537d: 32 63           LEAS   $3,S
537f: 39              RTS
5380: fc 56 18        LDD    $5618
5383: 17 a9 ca        LBSR   $FD50
5386: ae e9 00 09     LDX    $0009,S
538a: 8c 00 02        CMPX   #$0002
538d: 10 27 00 0d     LBEQ   $539E
5391: ce 00 00        LDU    #$0000
5394: 34 40           PSHS   U
5396: 17 73 51        LBSR   $C6EA
5399: 32 62           LEAS   $2,S
539b: 16 00 1c        LBRA   $53BA
539e: f6 3c 03        LDB    $3C03
53a1: c1 00           CMPB   #$00
53a3: 10 27 00 13     LBEQ   $53BA
53a7: f6 3c 04        LDB    $3C04
53aa: c1 00           CMPB   #$00
53ac: 10 27 00 0a     LBEQ   $53BA
53b0: ce 00 00        LDU    #$0000
53b3: 34 40           PSHS   U
53b5: 17 f5 09        LBSR   $48C1
53b8: 32 62           LEAS   $2,S
53ba: ae e9 00 09     LDX    $0009,S
53be: 8c 00 01        CMPX   #$0001
53c1: 10 26 00 11     LBNE   $53D6
53c5: f6 22 19        LDB    $2219
53c8: 4f              CLRA
53c9: 1f 03           TFR    D,U
53cb: 10 8e 00 02     LDY    #$0002
53cf: 34 60           PSHS   U,Y
53d1: 17 19 45        LBSR   $6D19
53d4: 32 64           LEAS   $4,S
53d6: ae e9 00 09     LDX    $0009,S
53da: 8c 00 00        CMPX   #$0000
53dd: 10 26 00 0d     LBNE   $53EE
53e1: ce 00 00        LDU    #$0000
53e4: 34 40           PSHS   U
53e6: 17 fe 3b        LBSR   $5224
53e9: 32 62           LEAS   $2,S
53eb: 16 00 95        LBRA   $5483
53ee: ce 00 00        LDU    #$0000
53f1: 34 40           PSHS   U
53f3: 17 71 bb        LBSR   $C5B1
53f6: 32 62           LEAS   $2,S
53f8: ce 00 00        LDU    #$0000
53fb: 34 40           PSHS   U
53fd: 17 16 57        LBSR   $6A57
5400: 32 62           LEAS   $2,S
5402: ae e9 00 09     LDX    $0009,S
5406: 8c 00 01        CMPX   #$0001
5409: 10 26 00 66     LBNE   $5473
540d: 6f 62           CLR    $2,S
540f: e6 62           LDB    $2,S
5411: c1 04           CMPB   #$04
5413: 10 24 00 5c     LBCC   $5473
5417: 8e 24 f0        LDX    #$24F0
541a: e6 62           LDB    $2,S
541c: 3a              ABX
541d: e6 84           LDB    ,X
541f: e7 63           STB    $3,S
5421: e6 63           LDB    $3,S
5423: 4f              CLRA
5424: 1f 03           TFR    D,U
5426: 10 8e 00 ff     LDY    #$00FF
542a: e6 62           LDB    $2,S
542c: 4f              CLRA
542d: 1f 01           TFR    D,X
542f: cc 00 06        LDD    #$0006
5432: 34 76           PSHS   U,Y,X,D
5434: 17 87 6a        LBSR   $DBA1
5437: 32 68           LEAS   $8,S
5439: e6 63           LDB    $3,S
543b: c4 04           ANDB   #$04
543d: 10 27 00 16     LBEQ   $5457
5441: 5f              CLRB
5442: 1d              SEX
5443: 1f 03           TFR    D,U
5445: e6 62           LDB    $2,S
5447: 4f              CLRA
5448: 1f 02           TFR    D,Y
544a: 8e 00 04        LDX    #$0004
544d: 34 70           PSHS   U,Y,X
544f: 17 63 4a        LBSR   $B79C
5452: 32 66           LEAS   $6,S
5454: 16 00 14        LBRA   $546B
5457: c6 01           LDB    #$01
5459: 1d              SEX
545a: 1f 03           TFR    D,U
545c: e6 62           LDB    $2,S
545e: 4f              CLRA
545f: 1f 02           TFR    D,Y
5461: 8e 00 04        LDX    #$0004
5464: 34 70           PSHS   U,Y,X
5466: 17 63 33        LBSR   $B79C
5469: 32 66           LEAS   $6,S
546b: e6 62           LDB    $2,S
546d: cb 01           ADDB   #$01
546f: e7 62           STB    $2,S
5471: 20 9c           BRA    $540F
5473: f6 3c 8f        LDB    $3C8F
5476: f7 26 8e        STB    $268E
5479: ce 00 00        LDU    #$0000
547c: 34 40           PSHS   U
547e: 17 35 29        LBSR   $89AA
5481: 32 62           LEAS   $2,S
5483: 7f 23 be        CLR    $23BE
5486: ce 00 00        LDU    #$0000
5489: 34 40           PSHS   U
548b: 17 6d 8c        LBSR   $C21A
548e: 32 62           LEAS   $2,S
5490: be 23 bf        LDX    $23BF
5493: 30 88 21        LEAX   $21,X
5496: cc 00 0c        LDD    #$000C
5499: ed 84           STD    ,X
549b: 5f              CLRB
549c: 1d              SEX
549d: 1f 03           TFR    D,U
549f: 10 8e 00 0c     LDY    #$000C
54a3: 8e 00 04        LDX    #$0004
54a6: 34 70           PSHS   U,Y,X
54a8: 17 73 05        LBSR   $C7B0
54ab: 32 66           LEAS   $6,S
54ad: f6 3c 03        LDB    $3C03
54b0: c1 00           CMPB   #$00
54b2: 10 27 00 2c     LBEQ   $54E2
54b6: c6 05           LDB    #$05
54b8: 1d              SEX
54b9: 1f 03           TFR    D,U
54bb: 10 8e 00 02     LDY    #$0002
54bf: 34 60           PSHS   U,Y
54c1: 17 16 42        LBSR   $6B06
54c4: 32 64           LEAS   $4,S
54c6: c6 04           LDB    #$04
54c8: 1d              SEX
54c9: 1f 03           TFR    D,U
54cb: 10 8e 00 02     LDY    #$0002
54cf: 34 60           PSHS   U,Y
54d1: 17 16 55        LBSR   $6B29
54d4: 32 64           LEAS   $4,S
54d6: cc 00 0c        LDD    #$000C
54d9: fd 25 5c        STD    $255C
54dc: cc 00 05        LDD    #$0005
54df: fd 25 48        STD    $2548
54e2: ce 00 00        LDU    #$0000
54e5: 34 40           PSHS   U
54e7: 17 0a 86        LBSR   $5F70
54ea: 32 62           LEAS   $2,S
54ec: 5f              CLRB
54ed: 1d              SEX
54ee: 1f 03           TFR    D,U
54f0: 10 8e 00 02     LDY    #$0002
54f4: 34 60           PSHS   U,Y
54f6: 17 16 99        LBSR   $6B92
54f9: 32 64           LEAS   $4,S
54fb: c6 02           LDB    #$02
54fd: 1d              SEX
54fe: 1f 03           TFR    D,U
5500: 10 8e 00 02     LDY    #$0002
5504: 34 60           PSHS   U,Y
5506: 17 15 da        LBSR   $6AE3
5509: 32 64           LEAS   $4,S
550b: cc 4c 01        LDD    #$4C01
550e: fd 22 0f        STD    $220F
5511: cc 51 85        LDD    #$5185
5514: fd 22 11        STD    $2211
5517: cc 45 67        LDD    #$4567
551a: fd 3c 0e        STD    $3C0E
551d: 7f 3c 0d        CLR    $3C0D
5520: 7f 3d 1c        CLR    $3D1C
5523: ce 00 00        LDU    #$0000
5526: 34 40           PSHS   U
5528: 17 00 ef        LBSR   $561A
552b: 32 62           LEAS   $2,S
552d: ee e9 00 09     LDU    $0009,S
5531: 10 8e 00 02     LDY    #$0002
5535: 34 60           PSHS   U,Y
5537: 17 24 c4        LBSR   $79FE
553a: 32 64           LEAS   $4,S
553c: ce 00 00        LDU    #$0000
553f: 34 40           PSHS   U
5541: 17 17 5e        LBSR   $6CA2
5544: 32 62           LEAS   $2,S
5546: 7f 3c 04        CLR    $3C04
5549: f6 3c 81        LDB    $3C81
554c: c1 00           CMPB   #$00
554e: 10 27 00 03     LBEQ   $5555
5552: 7f 3c 80        CLR    $3C80
5555: ce 00 00        LDU    #$0000
5558: 34 40           PSHS   U
555a: 17 f1 2c        LBSR   $4689
555d: 32 62           LEAS   $2,S
555f: f6 3c 03        LDB    $3C03
5562: c1 00           CMPB   #$00
5564: 10 27 00 21     LBEQ   $5589
5568: ce 00 00        LDU    #$0000
556b: 34 40           PSHS   U
556d: 17 17 f6        LBSR   $6D66
5570: 32 62           LEAS   $2,S
5572: e7 64           STB    $4,S
5574: f6 3c 80        LDB    $3C80
5577: 4f              CLRA
5578: 1f 03           TFR    D,U
557a: e6 64           LDB    $4,S
557c: 4f              CLRA
557d: 1f 02           TFR    D,Y
557f: 8e 00 04        LDX    #$0004
5582: 34 70           PSHS   U,Y,X
5584: 17 15 0e        LBSR   $6A95
5587: 32 66           LEAS   $6,S
5589: f6 3c 80        LDB    $3C80
558c: c1 00           CMPB   #$00
558e: 10 27 00 0d     LBEQ   $559F
5592: ce 00 00        LDU    #$0000
5595: 34 40           PSHS   U
5597: 17 f4 7f        LBSR   $4A19
559a: 32 62           LEAS   $2,S
559c: 16 00 13        LBRA   $55B2
559f: f6 3c 82        LDB    $3C82
55a2: c1 00           CMPB   #$00
55a4: 10 27 00 0a     LBEQ   $55B2
55a8: ce 00 00        LDU    #$0000
55ab: 34 40           PSHS   U
55ad: 17 f4 10        LBSR   $49C0
55b0: 32 62           LEAS   $2,S
55b2: fc 22 04        LDD    $2204
55b5: 8a 40           ORA    #$40
55b7: ca 00           ORB    #$00
55b9: fd 22 04        STD    $2204
55bc: cc 51 e3        LDD    #$51E3
55bf: fd 22 13        STD    $2213
55c2: 32 65           LEAS   $5,S
55c4: 39              RTS
55c5: fc 56 05        LDD    $5605
55c8: 17 a7 85        LBSR   $FD50
55cb: ce 41 6b        LDU    #$416B
55ce: 10 8e 00 02     LDY    #$0002
55d2: 34 60           PSHS   U,Y
55d4: 17 34 31        LBSR   $8A08
55d7: 32 64           LEAS   $4,S
55d9: 7f 3c 03        CLR    $3C03
55dc: ee e9 00 06     LDU    $0006,S
55e0: 10 8e 00 02     LDY    #$0002
55e4: 34 60           PSHS   U,Y
55e6: 17 fd 97        LBSR   $5380
55e9: 32 64           LEAS   $4,S
55eb: c6 08           LDB    #$08
55ed: 1d              SEX
55ee: 1f 03           TFR    D,U
55f0: 10 8e 00 15     LDY    #$0015
55f4: 8e 00 04        LDX    #$0004
55f7: 34 70           PSHS   U,Y,X
55f9: 17 90 a0        LBSR   $E69C
55fc: 32 66           LEAS   $6,S
55fe: 32 62           LEAS   $2,S
5600: 39              RTS
5601: 00 07           NEG    <$07
5603: 00 01           NEG    <$01
5605: 00 00           NEG    <$00
5607: 00 04           NEG    <$04
5609: 2a 43           BPL    $564E
560b: 6f 70           CLR    -$10,S
560d: 79 2a 20        ROL    $2A20
5610: 00 0d           NEG    <$0D
5612: 00 02           NEG    <$02
5614: 00 01           NEG    <$01
5616: 00 00           NEG    <$00
5618: 00 03           NEG    <$03
561a: fc 69 a4        LDD    $69A4
561d: 17 a7 30        LBSR   $FD50
5620: f6 3d 1c        LDB    $3D1C
5623: c1 00           CMPB   #$00
5625: 10 27 00 2d     LBEQ   $5656
5629: ce 3c 10        LDU    #$3C10
562c: f6 3d 1b        LDB    $3D1B
562f: 4f              CLRA
5630: 1f 02           TFR    D,Y
5632: 34 60           PSHS   U,Y
5634: 86 01           LDA    #$01
5636: 8e 69 98        LDX    #$6998
5639: 17 a6 ae        LBSR   $FCEA
563c: 30 02           LEAX   $2,X
563e: bf 3d 13        STX    $3D13
5641: cc 3c 89        LDD    #$3C89
5644: fd 3d 17        STD    $3D17
5647: cc 3c 85        LDD    #$3C85
564a: fd 3d 15        STD    $3D15
564d: cc 3c 8d        LDD    #$3C8D
5650: fd 3d 19        STD    $3D19
5653: 16 00 28        LBRA   $567E
5656: ce 3c 10        LDU    #$3C10
5659: f6 3d 1b        LDB    $3D1B
565c: 4f              CLRA
565d: 1f 02           TFR    D,Y
565f: 34 60           PSHS   U,Y
5661: 86 01           LDA    #$01
5663: 8e 69 98        LDX    #$6998
5666: 17 a6 81        LBSR   $FCEA
5669: bf 3d 13        STX    $3D13
566c: cc 3c 87        LDD    #$3C87
566f: fd 3d 17        STD    $3D17
5672: cc 3c 83        LDD    #$3C83
5675: fd 3d 15        STD    $3D15
5678: cc 3c 8b        LDD    #$3C8B
567b: fd 3d 19        STD    $3D19
567e: ce 3c 50        LDU    #$3C50
5681: f6 3d 1b        LDB    $3D1B
5684: 4f              CLRA
5685: 1f 02           TFR    D,Y
5687: 34 60           PSHS   U,Y
5689: 86 01           LDA    #$01
568b: 8e 69 9e        LDX    #$699E
568e: 17 a6 59        LBSR   $FCEA
5691: 1f 13           TFR    X,U
5693: 10 be 23 bf     LDY    $23BF
5697: 8e 00 04        LDX    #$0004
569a: 34 70           PSHS   U,Y,X
569c: 17 7c de        LBSR   $D37D
569f: 32 66           LEAS   $6,S
56a1: 32 64           LEAS   $4,S
56a3: 39              RTS
56a4: fc 69 9a        LDD    $699A
56a7: 17 a6 a6        LBSR   $FD50
56aa: f6 3c 8f        LDB    $3C8F
56ad: 4f              CLRA
56ae: 10 a3 e9 00 0c  CMPD   $000C,S
56b3: 10 26 00 17     LBNE   $56CE
56b7: ee e9 00 0a     LDU    $000A,S
56bb: 10 ae e9 00 08  LDY    $0008,S
56c0: ae e9 00 06     LDX    $0006,S
56c4: cc 00 06        LDD    #$0006
56c7: 34 76           PSHS   U,Y,X,D
56c9: 17 82 1e        LBSR   $D8EA
56cc: 32 68           LEAS   $8,S
56ce: 32 62           LEAS   $2,S
56d0: 39              RTS
56d1: fc 69 9a        LDD    $699A
56d4: 17 a6 79        LBSR   $FD50
56d7: f6 3c 8f        LDB    $3C8F
56da: 4f              CLRA
56db: 10 a3 e9 00 0a  CMPD   $000A,S
56e0: 10 26 00 13     LBNE   $56F7
56e4: ee e9 00 08     LDU    $0008,S
56e8: 10 ae e9 00 06  LDY    $0006,S
56ed: 8e 00 04        LDX    #$0004
56f0: 34 70           PSHS   U,Y,X
56f2: 17 54 fa        LBSR   $ABEF
56f5: 32 66           LEAS   $6,S
56f7: 32 62           LEAS   $2,S
56f9: 39              RTS
56fa: fc 69 9a        LDD    $699A
56fd: 17 a6 50        LBSR   $FD50
5700: f6 3c 8f        LDB    $3C8F
5703: 4f              CLRA
5704: 10 a3 e9 00 08  CMPD   $0008,S
5709: 10 26 00 0f     LBNE   $571C
570d: ee e9 00 06     LDU    $0006,S
5711: 10 8e 00 02     LDY    #$0002
5715: 34 60           PSHS   U,Y
5717: 17 71 3b        LBSR   $C855
571a: 32 64           LEAS   $4,S
571c: 32 62           LEAS   $2,S
571e: 39              RTS
571f: fc 69 a4        LDD    $69A4
5722: 17 a6 2b        LBSR   $FD50
5725: ce 24 14        LDU    #$2414
5728: 10 8e 3d 1d     LDY    #$3D1D
572c: 8e 00 04        LDX    #$0004
572f: 34 70           PSHS   U,Y,X
5731: 17 73 5b        LBSR   $CA8F
5734: 32 66           LEAS   $6,S
5736: be 3d 22        LDX    $3D22
5739: 8c 00 02        CMPX   #$0002
573c: 10 26 00 36     LBNE   $5776
5740: ce 24 14        LDU    #$2414
5743: c6 06           LDB    #$06
5745: 1d              SEX
5746: 1f 02           TFR    D,Y
5748: 8e 00 04        LDX    #$0004
574b: 34 70           PSHS   U,Y,X
574d: 17 75 af        LBSR   $CCFF
5750: 32 66           LEAS   $6,S
5752: 5f              CLRB
5753: 1d              SEX
5754: 1f 03           TFR    D,U
5756: c6 07           LDB    #$07
5758: 1d              SEX
5759: 1f 02           TFR    D,Y
575b: c6 08           LDB    #$08
575d: 1d              SEX
575e: 1f 01           TFR    D,X
5760: cc 24 14        LDD    #$2414
5763: 34 76           PSHS   U,Y,X,D
5765: ce 24 14        LDU    #$2414
5768: 10 8e 00 0a     LDY    #$000A
576c: 34 60           PSHS   U,Y
576e: 17 75 df        LBSR   $CD50
5771: 32 6c           LEAS   $C,S
5773: 16 00 34        LBRA   $57AA
5776: ce 24 14        LDU    #$2414
5779: c6 03           LDB    #$03
577b: 1d              SEX
577c: 1f 02           TFR    D,Y
577e: 8e 00 04        LDX    #$0004
5781: 34 70           PSHS   U,Y,X
5783: 17 75 79        LBSR   $CCFF
5786: 32 66           LEAS   $6,S
5788: c6 01           LDB    #$01
578a: 1d              SEX
578b: 1f 03           TFR    D,U
578d: c6 04           LDB    #$04
578f: 1d              SEX
5790: 1f 02           TFR    D,Y
5792: c6 08           LDB    #$08
5794: 1d              SEX
5795: 1f 01           TFR    D,X
5797: cc 24 14        LDD    #$2414
579a: 34 76           PSHS   U,Y,X,D
579c: ce 24 14        LDU    #$2414
579f: 10 8e 00 0a     LDY    #$000A
57a3: 34 60           PSHS   U,Y
57a5: 17 75 a8        LBSR   $CD50
57a8: 32 6c           LEAS   $C,S
57aa: f6 3d 24        LDB    $3D24
57ad: c1 00           CMPB   #$00
57af: 10 27 00 1c     LBEQ   $57CF
57b3: b6 3d 25        LDA    $3D25
57b6: c6 01           LDB    #$01
57b8: 17 a5 d4        LBSR   $FD8F
57bb: ed 62           STD    $2,S
57bd: c6 01           LDB    #$01
57bf: 1d              SEX
57c0: 1f 03           TFR    D,U
57c2: 10 ae 62        LDY    $2,S
57c5: 8e 00 04        LDX    #$0004
57c8: 34 70           PSHS   U,Y,X
57ca: 17 ff 2d        LBSR   $56FA
57cd: 32 66           LEAS   $6,S
57cf: c6 01           LDB    #$01
57d1: 1d              SEX
57d2: 1f 03           TFR    D,U
57d4: 10 8e 24 15     LDY    #$2415
57d8: c6 08           LDB    #$08
57da: 1d              SEX
57db: 1f 01           TFR    D,X
57dd: f6 3d 25        LDB    $3D25
57e0: 4f              CLRA
57e1: 34 76           PSHS   U,Y,X,D
57e3: ce 00 08        LDU    #$0008
57e6: 34 40           PSHS   U
57e8: 17 fe b9        LBSR   $56A4
57eb: 32 6a           LEAS   $A,S
57ed: c6 01           LDB    #$01
57ef: 1d              SEX
57f0: 1f 03           TFR    D,U
57f2: 10 be 3d 22     LDY    $3D22
57f6: f6 3d 26        LDB    $3D26
57f9: 4f              CLRA
57fa: 1f 01           TFR    D,X
57fc: cc 00 06        LDD    #$0006
57ff: 34 76           PSHS   U,Y,X,D
5801: 17 fe cd        LBSR   $56D1
5804: 32 68           LEAS   $8,S
5806: 32 64           LEAS   $4,S
5808: 39              RTS
5809: fc 69 9a        LDD    $699A
580c: 17 a5 41        LBSR   $FD50
580f: c6 19           LDB    #$19
5811: f7 3d 25        STB    $3D25
5814: c6 23           LDB    #$23
5816: f7 3d 26        STB    $3D26
5819: ce 00 00        LDU    #$0000
581c: 34 40           PSHS   U
581e: 17 fe fe        LBSR   $571F
5821: 32 62           LEAS   $2,S
5823: 32 62           LEAS   $2,S
5825: 39              RTS
5826: fc 69 9a        LDD    $699A
5829: 17 a5 24        LBSR   $FD50
582c: f6 3c 03        LDB    $3C03
582f: c1 00           CMPB   #$00
5831: 10 26 00 27     LBNE   $585C
5835: fe 23 bf        LDU    $23BF
5838: 10 8e 3d 1d     LDY    #$3D1D
583c: 8e 00 04        LDX    #$0004
583f: 34 70           PSHS   U,Y,X
5841: 17 7b 39        LBSR   $D37D
5844: 32 66           LEAS   $6,S
5846: be 23 bf        LDX    $23BF
5849: 30 03           LEAX   $3,X
584b: ae 84           LDX    ,X
584d: bf 3d 22        STX    $3D22
5850: 7f 3d 24        CLR    $3D24
5853: ce 00 00        LDU    #$0000
5856: 34 40           PSHS   U
5858: 8d af           BSR    $5809
585a: 32 62           LEAS   $2,S
585c: 32 62           LEAS   $2,S
585e: 39              RTS
585f: fc 69 9a        LDD    $699A
5862: 17 a4 eb        LBSR   $FD50
5865: be 23 bf        LDX    $23BF
5868: 30 05           LEAX   $5,X
586a: 1f 13           TFR    X,U
586c: 10 8e 3d 1d     LDY    #$3D1D
5870: 8e 00 04        LDX    #$0004
5873: 34 70           PSHS   U,Y,X
5875: 17 7b 05        LBSR   $D37D
5878: 32 66           LEAS   $6,S
587a: be 23 bf        LDX    $23BF
587d: 30 08           LEAX   $8,X
587f: ae 84           LDX    ,X
5881: bf 3d 22        STX    $3D22
5884: c6 01           LDB    #$01
5886: f7 3d 24        STB    $3D24
5889: ce 00 00        LDU    #$0000
588c: 34 40           PSHS   U
588e: 17 ff 78        LBSR   $5809
5891: 32 62           LEAS   $2,S
5893: 32 62           LEAS   $2,S
5895: 39              RTS
5896: fc 69 a4        LDD    $69A4
5899: 17 a4 b4        LBSR   $FD50
589c: ce 24 14        LDU    #$2414
589f: 10 8e 3d 1d     LDY    #$3D1D
58a3: 8e 00 04        LDX    #$0004
58a6: 34 70           PSHS   U,Y,X
58a8: 17 71 e4        LBSR   $CA8F
58ab: 32 66           LEAS   $6,S
58ad: ce 24 14        LDU    #$2414
58b0: 10 8e 00 02     LDY    #$0002
58b4: 34 60           PSHS   U,Y
58b6: 17 77 69        LBSR   $D022
58b9: 32 64           LEAS   $4,S
58bb: fd 3d 22        STD    $3D22
58be: f6 3d 24        LDB    $3D24
58c1: c1 00           CMPB   #$00
58c3: 10 27 00 1c     LBEQ   $58E3
58c7: b6 3d 25        LDA    $3D25
58ca: c6 02           LDB    #$02
58cc: 17 a4 c0        LBSR   $FD8F
58cf: ed 62           STD    $2,S
58d1: c6 03           LDB    #$03
58d3: 1d              SEX
58d4: 1f 03           TFR    D,U
58d6: 10 ae 62        LDY    $2,S
58d9: 8e 00 04        LDX    #$0004
58dc: 34 70           PSHS   U,Y,X
58de: 17 fe 19        LBSR   $56FA
58e1: 32 66           LEAS   $6,S
58e3: c6 03           LDB    #$03
58e5: 1d              SEX
58e6: 1f 03           TFR    D,U
58e8: 10 8e 24 14     LDY    #$2414
58ec: c6 05           LDB    #$05
58ee: 1d              SEX
58ef: 1f 01           TFR    D,X
58f1: f6 3d 25        LDB    $3D25
58f4: 4f              CLRA
58f5: 34 76           PSHS   U,Y,X,D
58f7: ce 00 08        LDU    #$0008
58fa: 34 40           PSHS   U
58fc: 17 fd a5        LBSR   $56A4
58ff: 32 6a           LEAS   $A,S
5901: c6 03           LDB    #$03
5903: 1d              SEX
5904: 1f 03           TFR    D,U
5906: 10 be 3d 22     LDY    $3D22
590a: f6 3d 26        LDB    $3D26
590d: 4f              CLRA
590e: 1f 01           TFR    D,X
5910: cc 00 06        LDD    #$0006
5913: 34 76           PSHS   U,Y,X,D
5915: 17 fd b9        LBSR   $56D1
5918: 32 68           LEAS   $8,S
591a: 32 64           LEAS   $4,S
591c: 39              RTS
591d: fc 69 9a        LDD    $699A
5920: 17 a4 2d        LBSR   $FD50
5923: c6 1e           LDB    #$1E
5925: f7 3d 25        STB    $3D25
5928: c6 24           LDB    #$24
592a: f7 3d 26        STB    $3D26
592d: ce 00 00        LDU    #$0000
5930: 34 40           PSHS   U
5932: 17 ff 61        LBSR   $5896
5935: 32 62           LEAS   $2,S
5937: 32 62           LEAS   $2,S
5939: 39              RTS
593a: fc 69 9a        LDD    $699A
593d: 17 a4 10        LBSR   $FD50
5940: be 23 bf        LDX    $23BF
5943: 30 0a           LEAX   $A,X
5945: 1f 13           TFR    X,U
5947: 10 8e 3d 1d     LDY    #$3D1D
594b: 8e 00 04        LDX    #$0004
594e: 34 70           PSHS   U,Y,X
5950: 17 7a 2a        LBSR   $D37D
5953: 32 66           LEAS   $6,S
5955: 7f 3d 24        CLR    $3D24
5958: ce 00 00        LDU    #$0000
595b: 34 40           PSHS   U
595d: 8d be           BSR    $591D
595f: 32 62           LEAS   $2,S
5961: be 23 bf        LDX    $23BF
5964: 30 0d           LEAX   $D,X
5966: fc 3d 22        LDD    $3D22
5969: ed 84           STD    ,X
596b: 32 62           LEAS   $2,S
596d: 39              RTS
596e: fc 69 9a        LDD    $699A
5971: 17 a3 dc        LBSR   $FD50
5974: be 23 bf        LDX    $23BF
5977: 30 0f           LEAX   $F,X
5979: 1f 13           TFR    X,U
597b: 10 8e 3d 1d     LDY    #$3D1D
597f: 8e 00 04        LDX    #$0004
5982: 34 70           PSHS   U,Y,X
5984: 17 79 f6        LBSR   $D37D
5987: 32 66           LEAS   $6,S
5989: c6 01           LDB    #$01
598b: f7 3d 24        STB    $3D24
598e: ce 00 00        LDU    #$0000
5991: 34 40           PSHS   U
5993: 8d 88           BSR    $591D
5995: 32 62           LEAS   $2,S
5997: be 23 bf        LDX    $23BF
599a: 30 88 12        LEAX   $12,X
599d: fc 3d 22        LDD    $3D22
59a0: ed 84           STD    ,X
59a2: 32 62           LEAS   $2,S
59a4: 39              RTS
59a5: fc 69 a4        LDD    $69A4
59a8: 17 a3 a5        LBSR   $FD50
59ab: ce 24 14        LDU    #$2414
59ae: 10 be 3d 20     LDY    $3D20
59b2: 8e 00 04        LDX    #$0004
59b5: 34 70           PSHS   U,Y,X
59b7: 17 6f 58        LBSR   $C912
59ba: 32 66           LEAS   $6,S
59bc: be 3d 22        LDX    $3D22
59bf: 8c 00 09        CMPX   #$0009
59c2: 10 26 00 23     LBNE   $59E9
59c6: 5f              CLRB
59c7: 1d              SEX
59c8: 1f 03           TFR    D,U
59ca: 5f              CLRB
59cb: 1d              SEX
59cc: 1f 02           TFR    D,Y
59ce: c6 05           LDB    #$05
59d0: 1d              SEX
59d1: 1f 01           TFR    D,X
59d3: cc 24 14        LDD    #$2414
59d6: 34 76           PSHS   U,Y,X,D
59d8: ce 24 14        LDU    #$2414
59db: 10 8e 00 0a     LDY    #$000A
59df: 34 60           PSHS   U,Y
59e1: 17 73 6c        LBSR   $CD50
59e4: 32 6c           LEAS   $C,S
59e6: 16 00 33        LBRA   $5A1C
59e9: ce 24 14        LDU    #$2414
59ec: c6 03           LDB    #$03
59ee: 1d              SEX
59ef: 1f 02           TFR    D,Y
59f1: 8e 00 04        LDX    #$0004
59f4: 34 70           PSHS   U,Y,X
59f6: 17 73 06        LBSR   $CCFF
59f9: 32 66           LEAS   $6,S
59fb: 5f              CLRB
59fc: 1d              SEX
59fd: 1f 03           TFR    D,U
59ff: c6 03           LDB    #$03
5a01: 1d              SEX
5a02: 1f 02           TFR    D,Y
5a04: c6 05           LDB    #$05
5a06: 1d              SEX
5a07: 1f 01           TFR    D,X
5a09: cc 24 14        LDD    #$2414
5a0c: 34 76           PSHS   U,Y,X,D
5a0e: ce 24 14        LDU    #$2414
5a11: 10 8e 00 0a     LDY    #$000A
5a15: 34 60           PSHS   U,Y
5a17: 17 73 36        LBSR   $CD50
5a1a: 32 6c           LEAS   $C,S
5a1c: f6 3d 24        LDB    $3D24
5a1f: c1 00           CMPB   #$00
5a21: 10 27 00 1c     LBEQ   $5A41
5a25: b6 3d 25        LDA    $3D25
5a28: c6 01           LDB    #$01
5a2a: 17 a3 62        LBSR   $FD8F
5a2d: ed 62           STD    $2,S
5a2f: c6 01           LDB    #$01
5a31: 1d              SEX
5a32: 1f 03           TFR    D,U
5a34: 10 ae 62        LDY    $2,S
5a37: 8e 00 04        LDX    #$0004
5a3a: 34 70           PSHS   U,Y,X
5a3c: 17 fc bb        LBSR   $56FA
5a3f: 32 66           LEAS   $6,S
5a41: c6 01           LDB    #$01
5a43: 1d              SEX
5a44: 1f 03           TFR    D,U
5a46: 10 8e 24 14     LDY    #$2414
5a4a: c6 06           LDB    #$06
5a4c: 1d              SEX
5a4d: 1f 01           TFR    D,X
5a4f: f6 3d 25        LDB    $3D25
5a52: 4f              CLRA
5a53: 34 76           PSHS   U,Y,X,D
5a55: ce 00 08        LDU    #$0008
5a58: 34 40           PSHS   U
5a5a: 17 fc 47        LBSR   $56A4
5a5d: 32 6a           LEAS   $A,S
5a5f: c6 01           LDB    #$01
5a61: 1d              SEX
5a62: 1f 03           TFR    D,U
5a64: 10 be 3d 22     LDY    $3D22
5a68: f6 3d 26        LDB    $3D26
5a6b: 4f              CLRA
5a6c: 1f 01           TFR    D,X
5a6e: cc 00 06        LDD    #$0006
5a71: 34 76           PSHS   U,Y,X,D
5a73: 17 fc 5b        LBSR   $56D1
5a76: 32 68           LEAS   $8,S
5a78: 32 64           LEAS   $4,S
5a7a: 39              RTS
5a7b: fc 69 9a        LDD    $699A
5a7e: 17 a2 cf        LBSR   $FD50
5a81: f6 3d 1c        LDB    $3D1C
5a84: c1 00           CMPB   #$00
5a86: 10 27 00 0d     LBEQ   $5A97
5a8a: c6 60           LDB    #$60
5a8c: f7 3d 25        STB    $3D25
5a8f: c6 66           LDB    #$66
5a91: f7 3d 26        STB    $3D26
5a94: 16 00 0a        LBRA   $5AA1
5a97: c6 4b           LDB    #$4B
5a99: f7 3d 25        STB    $3D25
5a9c: c6 51           LDB    #$51
5a9e: f7 3d 26        STB    $3D26
5aa1: ce 00 00        LDU    #$0000
5aa4: 34 40           PSHS   U
5aa6: 17 fe fc        LBSR   $59A5
5aa9: 32 62           LEAS   $2,S
5aab: 32 62           LEAS   $2,S
5aad: 39              RTS
5aae: fc 69 9a        LDD    $699A
5ab1: 17 a2 9c        LBSR   $FD50
5ab4: ec 9f 3d 13     LDD    [$3D13]
5ab8: fd 3d 20        STD    $3D20
5abb: ec 9f 3d 17     LDD    [$3D17]
5abf: fd 3d 22        STD    $3D22
5ac2: 7f 3d 24        CLR    $3D24
5ac5: ce 00 00        LDU    #$0000
5ac8: 34 40           PSHS   U
5aca: 8d af           BSR    $5A7B
5acc: 32 62           LEAS   $2,S
5ace: 32 62           LEAS   $2,S
5ad0: 39              RTS
5ad1: fc 69 9a        LDD    $699A
5ad4: 17 a2 79        LBSR   $FD50
5ad7: ec 9f 3d 15     LDD    [$3D15]
5adb: fd 3d 20        STD    $3D20
5ade: ec 9f 3d 19     LDD    [$3D19]
5ae2: fd 3d 22        STD    $3D22
5ae5: c6 01           LDB    #$01
5ae7: f7 3d 24        STB    $3D24
5aea: ce 00 00        LDU    #$0000
5aed: 34 40           PSHS   U
5aef: 8d 8a           BSR    $5A7B
5af1: 32 62           LEAS   $2,S
5af3: 32 62           LEAS   $2,S
5af5: 39              RTS
5af6: fc 69 9a        LDD    $699A
5af9: 17 a2 54        LBSR   $FD50
5afc: f6 3c 03        LDB    $3C03
5aff: c1 00           CMPB   #$00
5b01: 10 27 00 23     LBEQ   $5B28
5b05: e6 f9 00 06     LDB    [$0006,S]
5b09: c1 45           CMPB   #$45
5b0b: 10 26 00 09     LBNE   $5B18
5b0f: c6 2a           LDB    #$2A
5b11: e7 f9 00 06     STB    [$0006,S]
5b15: 16 00 10        LBRA   $5B28
5b18: e6 f9 00 06     LDB    [$0006,S]
5b1c: c1 46           CMPB   #$46
5b1e: 10 26 00 06     LBNE   $5B28
5b22: c6 23           LDB    #$23
5b24: e7 f9 00 06     STB    [$0006,S]
5b28: 32 62           LEAS   $2,S
5b2a: 39              RTS
5b2b: fc 69 9a        LDD    $699A
5b2e: 17 a2 1f        LBSR   $FD50
5b31: f6 3c 03        LDB    $3C03
5b34: c1 00           CMPB   #$00
5b36: 10 27 00 23     LBEQ   $5B5D
5b3a: e6 f9 00 06     LDB    [$0006,S]
5b3e: c1 2a           CMPB   #$2A
5b40: 10 26 00 09     LBNE   $5B4D
5b44: c6 45           LDB    #$45
5b46: e7 f9 00 06     STB    [$0006,S]
5b4a: 16 00 10        LBRA   $5B5D
5b4d: e6 f9 00 06     LDB    [$0006,S]
5b51: c1 23           CMPB   #$23
5b53: 10 26 00 06     LBNE   $5B5D
5b57: c6 46           LDB    #$46
5b59: e7 f9 00 06     STB    [$0006,S]
5b5d: 32 62           LEAS   $2,S
5b5f: 39              RTS
5b60: fc 69 98        LDD    $6998
5b63: 17 a1 ea        LBSR   $FD50
5b66: ce 24 14        LDU    #$2414
5b69: f6 3d 1b        LDB    $3D1B
5b6c: 4f              CLRA
5b6d: 1f 02           TFR    D,Y
5b6f: 8e 00 04        LDX    #$0004
5b72: 34 70           PSHS   U,Y,X
5b74: 17 70 2f        LBSR   $CBA6
5b77: 32 66           LEAS   $6,S
5b79: ce 24 15        LDU    #$2415
5b7c: 10 8e 00 02     LDY    #$0002
5b80: 34 60           PSHS   U,Y
5b82: 17 ff 71        LBSR   $5AF6
5b85: 32 64           LEAS   $4,S
5b87: c6 01           LDB    #$01
5b89: 1d              SEX
5b8a: 1f 03           TFR    D,U
5b8c: 10 8e 24 15     LDY    #$2415
5b90: c6 01           LDB    #$01
5b92: 1d              SEX
5b93: 1f 01           TFR    D,X
5b95: c6 0f           LDB    #$0F
5b97: 1d              SEX
5b98: 34 76           PSHS   U,Y,X,D
5b9a: ce 00 08        LDU    #$0008
5b9d: 34 40           PSHS   U
5b9f: 17 fb 02        LBSR   $56A4
5ba2: 32 6a           LEAS   $A,S
5ba4: f6 3d 1c        LDB    $3D1C
5ba7: e7 62           STB    $2,S
5ba9: 7f 3d 1c        CLR    $3D1C
5bac: ce 00 00        LDU    #$0000
5baf: 34 40           PSHS   U
5bb1: 17 fa 66        LBSR   $561A
5bb4: 32 62           LEAS   $2,S
5bb6: ce 00 00        LDU    #$0000
5bb9: 34 40           PSHS   U
5bbb: 17 fe f0        LBSR   $5AAE
5bbe: 32 62           LEAS   $2,S
5bc0: c6 01           LDB    #$01
5bc2: f7 3d 1c        STB    $3D1C
5bc5: ce 00 00        LDU    #$0000
5bc8: 34 40           PSHS   U
5bca: 17 fa 4d        LBSR   $561A
5bcd: 32 62           LEAS   $2,S
5bcf: ce 00 00        LDU    #$0000
5bd2: 34 40           PSHS   U
5bd4: 17 fe d7        LBSR   $5AAE
5bd7: 32 62           LEAS   $2,S
5bd9: e6 62           LDB    $2,S
5bdb: f7 3d 1c        STB    $3D1C
5bde: ce 00 00        LDU    #$0000
5be1: 34 40           PSHS   U
5be3: 17 fa 34        LBSR   $561A
5be6: 32 62           LEAS   $2,S
5be8: ce 00 00        LDU    #$0000
5beb: 34 40           PSHS   U
5bed: 17 fc 36        LBSR   $5826
5bf0: 32 62           LEAS   $2,S
5bf2: 32 63           LEAS   $3,S
5bf4: 39              RTS
5bf5: fc 69 9a        LDD    $699A
5bf8: 17 a1 55        LBSR   $FD50
5bfb: c6 01           LDB    #$01
5bfd: 1d              SEX
5bfe: 1f 03           TFR    D,U
5c00: 10 8e ed 11     LDY    #$ED11
5c04: c6 01           LDB    #$01
5c06: 1d              SEX
5c07: 1f 01           TFR    D,X
5c09: c6 23           LDB    #$23
5c0b: 1d              SEX
5c0c: 34 76           PSHS   U,Y,X,D
5c0e: ce 00 08        LDU    #$0008
5c11: 34 40           PSHS   U
5c13: 17 fa 8e        LBSR   $56A4
5c16: 32 6a           LEAS   $A,S
5c18: 32 62           LEAS   $2,S
5c1a: 39              RTS
5c1b: fc 69 a2        LDD    $69A2
5c1e: 17 a1 2f        LBSR   $FD50
5c21: f6 3c 8f        LDB    $3C8F
5c24: c1 03           CMPB   #$03
5c26: 10 26 00 9f     LBNE   $5CC9
5c2a: f6 3c 80        LDB    $3C80
5c2d: c1 00           CMPB   #$00
5c2f: 10 27 00 38     LBEQ   $5C6B
5c33: f6 3c 81        LDB    $3C81
5c36: c1 00           CMPB   #$00
5c38: 10 27 00 08     LBEQ   $5C44
5c3c: cc 69 a6        LDD    #$69A6
5c3f: ed 62           STD    $2,S
5c41: 16 00 05        LBRA   $5C49
5c44: cc 69 bb        LDD    #$69BB
5c47: ed 62           STD    $2,S
5c49: c6 14           LDB    #$14
5c4b: e7 64           STB    $4,S
5c4d: c6 03           LDB    #$03
5c4f: 1d              SEX
5c50: 1f 03           TFR    D,U
5c52: 10 ae 62        LDY    $2,S
5c55: e6 64           LDB    $4,S
5c57: 4f              CLRA
5c58: 1f 01           TFR    D,X
5c5a: 5f              CLRB
5c5b: 1d              SEX
5c5c: 34 76           PSHS   U,Y,X,D
5c5e: ce 00 08        LDU    #$0008
5c61: 34 40           PSHS   U
5c63: 17 fa 3e        LBSR   $56A4
5c66: 32 6a           LEAS   $A,S
5c68: 16 00 5e        LBRA   $5CC9
5c6b: f6 3c 82        LDB    $3C82
5c6e: c1 00           CMPB   #$00
5c70: 10 27 00 39     LBEQ   $5CAD
5c74: c6 03           LDB    #$03
5c76: 1d              SEX
5c77: 1f 03           TFR    D,U
5c79: 10 8e 40 f2     LDY    #$40F2
5c7d: c6 14           LDB    #$14
5c7f: 1d              SEX
5c80: 1f 01           TFR    D,X
5c82: 5f              CLRB
5c83: 1d              SEX
5c84: 34 76           PSHS   U,Y,X,D
5c86: ce 00 08        LDU    #$0008
5c89: 34 40           PSHS   U
5c8b: 17 fa 16        LBSR   $56A4
5c8e: 32 6a           LEAS   $A,S
5c90: ce 00 00        LDU    #$0000
5c93: 34 40           PSHS   U
5c95: 17 12 59        LBSR   $6EF1
5c98: 32 62           LEAS   $2,S
5c9a: c6 0e           LDB    #$0E
5c9c: 1d              SEX
5c9d: 1f 03           TFR    D,U
5c9f: 10 8e 00 02     LDY    #$0002
5ca3: 34 60           PSHS   U,Y
5ca5: 17 13 04        LBSR   $6FAC
5ca8: 32 64           LEAS   $4,S
5caa: 16 00 1c        LBRA   $5CC9
5cad: c6 03           LDB    #$03
5caf: 1d              SEX
5cb0: 1f 03           TFR    D,U
5cb2: 10 8e 41 42     LDY    #$4142
5cb6: c6 14           LDB    #$14
5cb8: 1d              SEX
5cb9: 1f 01           TFR    D,X
5cbb: 5f              CLRB
5cbc: 1d              SEX
5cbd: 34 76           PSHS   U,Y,X,D
5cbf: ce 00 08        LDU    #$0008
5cc2: 34 40           PSHS   U
5cc4: 17 f9 dd        LBSR   $56A4
5cc7: 32 6a           LEAS   $A,S
5cc9: 32 65           LEAS   $5,S
5ccb: 39              RTS
5ccc: fc 69 9a        LDD    $699A
5ccf: 17 a0 7e        LBSR   $FD50
5cd2: f6 3c 8f        LDB    $3C8F
5cd5: c1 01           CMPB   #$01
5cd7: 10 26 00 21     LBNE   $5CFC
5cdb: ce 00 00        LDU    #$0000
5cde: 34 40           PSHS   U
5ce0: 17 fb 43        LBSR   $5826
5ce3: 32 62           LEAS   $2,S
5ce5: ce 00 00        LDU    #$0000
5ce8: 34 40           PSHS   U
5cea: 17 fe 73        LBSR   $5B60
5ced: 32 62           LEAS   $2,S
5cef: ce 00 00        LDU    #$0000
5cf2: 34 40           PSHS   U
5cf4: 17 fd b7        LBSR   $5AAE
5cf7: 32 62           LEAS   $2,S
5cf9: 16 00 33        LBRA   $5D2F
5cfc: f6 3c 8f        LDB    $3C8F
5cff: c1 02           CMPB   #$02
5d01: 10 26 00 0d     LBNE   $5D12
5d05: ce 00 00        LDU    #$0000
5d08: 34 40           PSHS   U
5d0a: 17 13 b8        LBSR   $70C5
5d0d: 32 62           LEAS   $2,S
5d0f: 16 00 1d        LBRA   $5D2F
5d12: f6 3c 8f        LDB    $3C8F
5d15: c1 03           CMPB   #$03
5d17: 10 26 00 14     LBNE   $5D2F
5d1b: ce 00 00        LDU    #$0000
5d1e: 34 40           PSHS   U
5d20: 17 fc 17        LBSR   $593A
5d23: 32 62           LEAS   $2,S
5d25: ce 00 00        LDU    #$0000
5d28: 34 40           PSHS   U
5d2a: 17 fe ee        LBSR   $5C1B
5d2d: 32 62           LEAS   $2,S
5d2f: 32 62           LEAS   $2,S
5d31: 39              RTS
5d32: fc 69 98        LDD    $6998
5d35: 17 a0 18        LBSR   $FD50
5d38: be 3d 11        LDX    $3D11
5d3b: 16 01 b2        LBRA   $5EF0
5d3e: ce 22 85        LDU    #$2285
5d41: 10 be 23 bf     LDY    $23BF
5d45: 8e 00 04        LDX    #$0004
5d48: 34 70           PSHS   U,Y,X
5d4a: 17 6d 42        LBSR   $CA8F
5d4d: 32 66           LEAS   $6,S
5d4f: 5f              CLRB
5d50: 1d              SEX
5d51: 1f 03           TFR    D,U
5d53: c6 07           LDB    #$07
5d55: 1d              SEX
5d56: 1f 02           TFR    D,Y
5d58: c6 08           LDB    #$08
5d5a: 1d              SEX
5d5b: 1f 01           TFR    D,X
5d5d: cc 22 85        LDD    #$2285
5d60: 34 76           PSHS   U,Y,X,D
5d62: ce 22 85        LDU    #$2285
5d65: 10 8e 00 0a     LDY    #$000A
5d69: 34 60           PSHS   U,Y
5d6b: 17 6f e2        LBSR   $CD50
5d6e: 32 6c           LEAS   $C,S
5d70: c6 09           LDB    #$09
5d72: e7 62           STB    $2,S
5d74: 16 01 a6        LBRA   $5F1D
5d77: be 23 bf        LDX    $23BF
5d7a: 30 0a           LEAX   $A,X
5d7c: ce 22 85        LDU    #$2285
5d7f: 1f 12           TFR    X,Y
5d81: 8e 00 04        LDX    #$0004
5d84: 34 70           PSHS   U,Y,X
5d86: 17 6d 06        LBSR   $CA8F
5d89: 32 66           LEAS   $6,S
5d8b: 5f              CLRB
5d8c: 1d              SEX
5d8d: 1f 03           TFR    D,U
5d8f: c6 02           LDB    #$02
5d91: 1d              SEX
5d92: 1f 02           TFR    D,Y
5d94: c6 08           LDB    #$08
5d96: 1d              SEX
5d97: 1f 01           TFR    D,X
5d99: cc 22 85        LDD    #$2285
5d9c: 34 76           PSHS   U,Y,X,D
5d9e: ce 22 85        LDU    #$2285
5da1: 10 8e 00 0a     LDY    #$000A
5da5: 34 60           PSHS   U,Y
5da7: 17 6f a6        LBSR   $CD50
5daa: 32 6c           LEAS   $C,S
5dac: c6 09           LDB    #$09
5dae: e7 62           STB    $2,S
5db0: 16 01 6a        LBRA   $5F1D
5db3: be 23 bf        LDX    $23BF
5db6: 30 05           LEAX   $5,X
5db8: ce 22 85        LDU    #$2285
5dbb: 1f 12           TFR    X,Y
5dbd: 8e 00 04        LDX    #$0004
5dc0: 34 70           PSHS   U,Y,X
5dc2: 17 6c ca        LBSR   $CA8F
5dc5: 32 66           LEAS   $6,S
5dc7: 5f              CLRB
5dc8: 1d              SEX
5dc9: 1f 03           TFR    D,U
5dcb: c6 07           LDB    #$07
5dcd: 1d              SEX
5dce: 1f 02           TFR    D,Y
5dd0: c6 08           LDB    #$08
5dd2: 1d              SEX
5dd3: 1f 01           TFR    D,X
5dd5: cc 22 85        LDD    #$2285
5dd8: 34 76           PSHS   U,Y,X,D
5dda: ce 22 85        LDU    #$2285
5ddd: 10 8e 00 0a     LDY    #$000A
5de1: 34 60           PSHS   U,Y
5de3: 17 6f 6a        LBSR   $CD50
5de6: 32 6c           LEAS   $C,S
5de8: c6 09           LDB    #$09
5dea: e7 62           STB    $2,S
5dec: 16 01 2e        LBRA   $5F1D
5def: be 23 bf        LDX    $23BF
5df2: 30 0f           LEAX   $F,X
5df4: ce 22 85        LDU    #$2285
5df7: 1f 12           TFR    X,Y
5df9: 8e 00 04        LDX    #$0004
5dfc: 34 70           PSHS   U,Y,X
5dfe: 17 6c 8e        LBSR   $CA8F
5e01: 32 66           LEAS   $6,S
5e03: 5f              CLRB
5e04: 1d              SEX
5e05: 1f 03           TFR    D,U
5e07: c6 02           LDB    #$02
5e09: 1d              SEX
5e0a: 1f 02           TFR    D,Y
5e0c: c6 08           LDB    #$08
5e0e: 1d              SEX
5e0f: 1f 01           TFR    D,X
5e11: cc 22 85        LDD    #$2285
5e14: 34 76           PSHS   U,Y,X,D
5e16: ce 22 85        LDU    #$2285
5e19: 10 8e 00 0a     LDY    #$000A
5e1d: 34 60           PSHS   U,Y
5e1f: 17 6f 2e        LBSR   $CD50
5e22: 32 6c           LEAS   $C,S
5e24: c6 09           LDB    #$09
5e26: e7 62           STB    $2,S
5e28: 16 00 f2        LBRA   $5F1D
5e2b: ce 22 85        LDU    #$2285
5e2e: 10 ae 9f 3d 13  LDY    [$3D13]
5e33: 8e 00 04        LDX    #$0004
5e36: 34 70           PSHS   U,Y,X
5e38: 17 6a d7        LBSR   $C912
5e3b: 32 66           LEAS   $6,S
5e3d: 5f              CLRB
5e3e: 1d              SEX
5e3f: 1f 03           TFR    D,U
5e41: 5f              CLRB
5e42: 1d              SEX
5e43: 1f 02           TFR    D,Y
5e45: c6 05           LDB    #$05
5e47: 1d              SEX
5e48: 1f 01           TFR    D,X
5e4a: cc 22 85        LDD    #$2285
5e4d: 34 76           PSHS   U,Y,X,D
5e4f: ce 22 85        LDU    #$2285
5e52: 10 8e 00 0a     LDY    #$000A
5e56: 34 60           PSHS   U,Y
5e58: 17 6e f5        LBSR   $CD50
5e5b: 32 6c           LEAS   $C,S
5e5d: c6 06           LDB    #$06
5e5f: e7 62           STB    $2,S
5e61: 16 00 b9        LBRA   $5F1D
5e64: ce 22 85        LDU    #$2285
5e67: 10 ae 9f 3d 15  LDY    [$3D15]
5e6c: 8e 00 04        LDX    #$0004
5e6f: 34 70           PSHS   U,Y,X
5e71: 17 6a 9e        LBSR   $C912
5e74: 32 66           LEAS   $6,S
5e76: 5f              CLRB
5e77: 1d              SEX
5e78: 1f 03           TFR    D,U
5e7a: 5f              CLRB
5e7b: 1d              SEX
5e7c: 1f 02           TFR    D,Y
5e7e: c6 05           LDB    #$05
5e80: 1d              SEX
5e81: 1f 01           TFR    D,X
5e83: cc 22 85        LDD    #$2285
5e86: 34 76           PSHS   U,Y,X,D
5e88: ce 22 85        LDU    #$2285
5e8b: 10 8e 00 0a     LDY    #$000A
5e8f: 34 60           PSHS   U,Y
5e91: 17 6e bc        LBSR   $CD50
5e94: 32 6c           LEAS   $C,S
5e96: c6 06           LDB    #$06
5e98: e7 62           STB    $2,S
5e9a: 16 00 80        LBRA   $5F1D
5e9d: ce 22 85        LDU    #$2285
5ea0: f6 3d 1b        LDB    $3D1B
5ea3: 4f              CLRA
5ea4: 1f 02           TFR    D,Y
5ea6: 8e 00 04        LDX    #$0004
5ea9: 34 70           PSHS   U,Y,X
5eab: 17 6b 23        LBSR   $C9D1
5eae: 32 66           LEAS   $6,S
5eb0: c6 03           LDB    #$03
5eb2: e7 62           STB    $2,S
5eb4: 16 00 66        LBRA   $5F1D
5eb7: cc 00 08        LDD    #$0008
5eba: fd 3d 11        STD    $3D11
5ebd: ce 00 00        LDU    #$0000
5ec0: 34 40           PSHS   U
5ec2: 17 13 ed        LBSR   $72B2
5ec5: 32 62           LEAS   $2,S
5ec7: cc 00 0b        LDD    #$000B
5eca: fd 3d 11        STD    $3D11
5ecd: ce 00 04        LDU    #$0004
5ed0: 10 8e 00 02     LDY    #$0002
5ed4: 34 60           PSHS   U,Y
5ed6: be 3c 0e        LDX    $3C0E
5ed9: ad 84           JSR    ,X
5edb: 32 64           LEAS   $4,S
5edd: 16 00 50        LBRA   $5F30
5ee0: ce 00 00        LDU    #$0000
5ee3: 34 40           PSHS   U
5ee5: 17 13 ca        LBSR   $72B2
5ee8: 32 62           LEAS   $2,S
5eea: 16 00 43        LBRA   $5F30
5eed: 16 00 2d        LBRA   $5F1D
5ef0: 8c 00 0b        CMPX   #$000B
5ef3: 10 2e 00 26     LBGT   $5F1D
5ef7: 1f 10           TFR    X,D
5ef9: 83 00 01        SUBD   #$0001
5efc: 10 2d 00 1d     LBLT   $5F1D
5f00: 8e 5f 07        LDX    #$5F07
5f03: 58              ASLB
5f04: 49              ROLA
5f05: 6e 9b           JMP    [D,X]
5f07: 5d              TSTB
5f08: 3e              XRES
5f09: 5d              TSTB
5f0a: b3 5d 77        SUBD   $5D77
5f0d: 5d              TSTB
5f0e: ef 5e           STU    -$2,U
5f10: 2b 5e           BMI    $5F70
5f12: 64 5e           LSR    -$2,U
5f14: 9d 5e           JSR    <$5E
5f16: e0 5e           SUBB   -$2,U
5f18: e0 5e           SUBB   -$2,U
5f1a: e0 5e           SUBB   -$2,U
5f1c: b7 e6 62        STA    $E662
5f1f: 4f              CLRA
5f20: 1f 03           TFR    D,U
5f22: 10 8e 22 85     LDY    #$2285
5f26: 8e 00 04        LDX    #$0004
5f29: 34 70           PSHS   U,Y,X
5f2b: 17 40 d0        LBSR   $9FFE
5f2e: 32 66           LEAS   $6,S
5f30: 32 63           LEAS   $3,S
5f32: 39              RTS
5f33: fc 69 98        LDD    $6998
5f36: 17 9e 17        LBSR   $FD50
5f39: fe 23 bf        LDU    $23BF
5f3c: f6 3d 1b        LDB    $3D1B
5f3f: 4f              CLRA
5f40: 1f 02           TFR    D,Y
5f42: 8e 00 04        LDX    #$0004
5f45: 34 70           PSHS   U,Y,X
5f47: 17 0a 92        LBSR   $69DC
5f4a: 32 66           LEAS   $6,S
5f4c: ce 00 00        LDU    #$0000
5f4f: 34 40           PSHS   U
5f51: 17 0e 12        LBSR   $6D66
5f54: 32 62           LEAS   $2,S
5f56: e7 62           STB    $2,S
5f58: f6 3c 80        LDB    $3C80
5f5b: 4f              CLRA
5f5c: 1f 03           TFR    D,U
5f5e: e6 62           LDB    $2,S
5f60: 4f              CLRA
5f61: 1f 02           TFR    D,Y
5f63: 8e 00 04        LDX    #$0004
5f66: 34 70           PSHS   U,Y,X
5f68: 17 0b 2a        LBSR   $6A95
5f6b: 32 66           LEAS   $6,S
5f6d: 32 63           LEAS   $3,S
5f6f: 39              RTS
5f70: fc 69 cf        LDD    $69CF
5f73: 17 9d da        LBSR   $FD50
5f76: be 23 bf        LDX    $23BF
5f79: 30 0a           LEAX   $A,X
5f7b: 1f 13           TFR    X,U
5f7d: 10 8e 22 1c     LDY    #$221C
5f81: 8e 00 04        LDX    #$0004
5f84: 34 70           PSHS   U,Y,X
5f86: 17 73 f4        LBSR   $D37D
5f89: 32 66           LEAS   $6,S
5f8b: ce 22 1c        LDU    #$221C
5f8e: 31 65           LEAY   $5,S
5f90: 8e 00 04        LDX    #$0004
5f93: 34 70           PSHS   U,Y,X
5f95: 17 73 e5        LBSR   $D37D
5f98: 32 66           LEAS   $6,S
5f9a: f6 3c 03        LDB    $3C03
5f9d: c1 00           CMPB   #$00
5f9f: 10 27 00 0a     LBEQ   $5FAD
5fa3: ce 00 00        LDU    #$0000
5fa6: 34 40           PSHS   U
5fa8: 17 e4 8e        LBSR   $4439
5fab: 32 62           LEAS   $2,S
5fad: be 23 bf        LDX    $23BF
5fb0: 30 0a           LEAX   $A,X
5fb2: ce 22 1c        LDU    #$221C
5fb5: 1f 12           TFR    X,Y
5fb7: 8e 00 04        LDX    #$0004
5fba: 34 70           PSHS   U,Y,X
5fbc: 17 73 be        LBSR   $D37D
5fbf: 32 66           LEAS   $6,S
5fc1: ce 22 1c        LDU    #$221C
5fc4: 5f              CLRB
5fc5: 1d              SEX
5fc6: 1f 02           TFR    D,Y
5fc8: 8e 00 04        LDX    #$0004
5fcb: 34 70           PSHS   U,Y,X
5fcd: 17 60 99        LBSR   $C069
5fd0: 32 66           LEAS   $6,S
5fd2: f6 3c 03        LDB    $3C03
5fd5: c1 00           CMPB   #$00
5fd7: 10 27 00 42     LBEQ   $601D
5fdb: c6 02           LDB    #$02
5fdd: f7 23 be        STB    $23BE
5fe0: ce 00 00        LDU    #$0000
5fe3: 34 40           PSHS   U
5fe5: 17 62 32        LBSR   $C21A
5fe8: 32 62           LEAS   $2,S
5fea: be 23 bf        LDX    $23BF
5fed: 30 0a           LEAX   $A,X
5fef: ce 22 1c        LDU    #$221C
5ff2: 1f 12           TFR    X,Y
5ff4: 8e 00 04        LDX    #$0004
5ff7: 34 70           PSHS   U,Y,X
5ff9: 17 73 81        LBSR   $D37D
5ffc: 32 66           LEAS   $6,S
5ffe: ce 22 1c        LDU    #$221C
6001: c6 02           LDB    #$02
6003: 1d              SEX
6004: 1f 02           TFR    D,Y
6006: 8e 00 04        LDX    #$0004
6009: 34 70           PSHS   U,Y,X
600b: 17 60 5b        LBSR   $C069
600e: 32 66           LEAS   $6,S
6010: 7f 23 be        CLR    $23BE
6013: ce 00 00        LDU    #$0000
6016: 34 40           PSHS   U
6018: 17 61 ff        LBSR   $C21A
601b: 32 62           LEAS   $2,S
601d: be 23 bf        LDX    $23BF
6020: 30 0a           LEAX   $A,X
6022: 33 65           LEAU   $5,S
6024: 1f 12           TFR    X,Y
6026: 8e 00 04        LDX    #$0004
6029: 34 70           PSHS   U,Y,X
602b: 17 73 4f        LBSR   $D37D
602e: 32 66           LEAS   $6,S
6030: 32 68           LEAS   $8,S
6032: 39              RTS
6033: fc 69 9c        LDD    $699C
6036: 17 9d 17        LBSR   $FD50
6039: cc 00 50        LDD    #$0050
603c: ed 64           STD    $4,S
603e: f6 3c 03        LDB    $3C03
6041: c1 00           CMPB   #$00
6043: 10 27 00 05     LBEQ   $604C
6047: cc 00 64        LDD    #$0064
604a: ed 64           STD    $4,S
604c: ae 9f 3d 13     LDX    [$3D13]
6050: ac 64           CMPX   $4,S
6052: 10 24 00 6a     LBCC   $60C0
6056: ae 9f 3d 13     LDX    [$3D13]
605a: 8c 00 00        CMPX   #$0000
605d: 10 26 00 52     LBNE   $60B3
6061: ce 3c 10        LDU    #$3C10
6064: f6 3d 1b        LDB    $3D1B
6067: 4f              CLRA
6068: 1f 02           TFR    D,Y
606a: 34 60           PSHS   U,Y
606c: 86 01           LDA    #$01
606e: 8e 69 98        LDX    #$6998
6071: 17 9c 76        LBSR   $FCEA
6074: bc 3d 13        CMPX   $3D13
6077: 10 26 00 11     LBNE   $608C
607b: c6 01           LDB    #$01
607d: 1d              SEX
607e: 58              ASLB
607f: 49              ROLA
6080: be 3d 13        LDX    $3D13
6083: 30 8b           LEAX   D,X
6085: ae 84           LDX    ,X
6087: af 62           STX    $2,S
6089: 16 00 0e        LBRA   $609A
608c: cc ff ff        LDD    #$FFFF
608f: 58              ASLB
6090: 49              ROLA
6091: be 3d 13        LDX    $3D13
6094: 30 8b           LEAX   D,X
6096: ae 84           LDX    ,X
6098: af 62           STX    $2,S
609a: ae 62           LDX    $2,S
609c: 8c 00 00        CMPX   #$0000
609f: 10 26 00 0d     LBNE   $60B0
60a3: ec e9 00 0a     LDD    $000A,S
60a7: ed 9f 3d 13     STD    [$3D13]
60ab: c6 33           LDB    #$33
60ad: f7 3c 02        STB    $3C02
60b0: 16 00 0d        LBRA   $60C0
60b3: ec e9 00 0a     LDD    $000A,S
60b7: ed 9f 3d 13     STD    [$3D13]
60bb: c6 32           LDB    #$32
60bd: f7 3c 02        STB    $3C02
60c0: 32 66           LEAS   $6,S
60c2: 39              RTS
60c3: fc 69 d6        LDD    $69D6
60c6: 17 9c 87        LBSR   $FD50
60c9: 6f 62           CLR    $2,S
60cb: 6f 63           CLR    $3,S
60cd: cc 69 d1        LDD    #$69D1
60d0: ed 67           STD    $7,S
60d2: c6 05           LDB    #$05
60d4: e7 66           STB    $6,S
60d6: e6 66           LDB    $6,S
60d8: c1 00           CMPB   #$00
60da: 10 23 00 37     LBLS   $6115
60de: 8e 24 14        LDX    #$2414
60e1: e6 66           LDB    $6,S
60e3: 3a              ABX
60e4: e6 84           LDB    ,X
60e6: e7 64           STB    $4,S
60e8: e6 f8 07        LDB    [$07,S]
60eb: e7 65           STB    $5,S
60ed: e6 65           LDB    $5,S
60ef: eb 63           ADDB   $3,S
60f1: e7 65           STB    $5,S
60f3: e6 65           LDB    $5,S
60f5: e1 64           CMPB   $4,S
60f7: 10 23 00 07     LBLS   $6102
60fb: c6 01           LDB    #$01
60fd: e7 63           STB    $3,S
60ff: 16 00 02        LBRA   $6104
6102: 6f 63           CLR    $3,S
6104: e6 66           LDB    $6,S
6106: c0 01           SUBB   #$01
6108: e7 66           STB    $6,S
610a: ae 67           LDX    $7,S
610c: ec 67           LDD    $7,S
610e: c3 00 01        ADDD   #$0001
6111: ed 67           STD    $7,S
6113: 20 c1           BRA    $60D6
6115: e6 63           LDB    $3,S
6117: c1 00           CMPB   #$00
6119: 10 26 00 09     LBNE   $6126
611d: c6 32           LDB    #$32
611f: f7 3c 02        STB    $3C02
6122: c6 01           LDB    #$01
6124: e7 62           STB    $2,S
6126: e6 62           LDB    $2,S
6128: e7 69           STB    $9,S
612a: 32 6a           LEAS   $A,S
612c: 39              RTS
612d: fc 69 9c        LDD    $699C
6130: 17 9c 1d        LBSR   $FD50
6133: c6 04           LDB    #$04
6135: 1d              SEX
6136: 1f 03           TFR    D,U
6138: 10 be 22 21     LDY    $2221
613c: 8e 00 04        LDX    #$0004
613f: 34 70           PSHS   U,Y,X
6141: 17 6c 9d        LBSR   $CDE1
6144: 32 66           LEAS   $6,S
6146: e7 62           STB    $2,S
6148: e6 62           LDB    $2,S
614a: c1 08           CMPB   #$08
614c: 10 24 00 47     LBCC   $6197
6150: ce 22 1c        LDU    #$221C
6153: 10 8e 24 14     LDY    #$2414
6157: 8e 00 04        LDX    #$0004
615a: 34 70           PSHS   U,Y,X
615c: 17 69 b1        LBSR   $CB10
615f: 32 66           LEAS   $6,S
6161: 33 63           LEAU   $3,S
6163: 10 8e 22 1c     LDY    #$221C
6167: 8e ea 55        LDX    #$EA55
616a: cc 00 06        LDD    #$0006
616d: 34 76           PSHS   U,Y,X,D
616f: 17 72 54        LBSR   $D3C6
6172: 32 68           LEAS   $8,S
6174: c1 00           CMPB   #$00
6176: 10 26 00 15     LBNE   $618F
617a: ce 22 1c        LDU    #$221C
617d: 10 ae e9 00 0a  LDY    $000A,S
6182: 8e 00 04        LDX    #$0004
6185: 34 70           PSHS   U,Y,X
6187: 17 71 f3        LBSR   $D37D
618a: 32 66           LEAS   $6,S
618c: 16 00 05        LBRA   $6194
618f: c6 35           LDB    #$35
6191: f7 3c 02        STB    $3C02
6194: 16 00 10        LBRA   $61A7
6197: e6 62           LDB    $2,S
6199: 4f              CLRA
619a: 10 83 00 ff     CMPD   #$00FF
619e: 10 27 00 05     LBEQ   $61A7
61a2: c6 35           LDB    #$35
61a4: f7 3c 02        STB    $3C02
61a7: 32 66           LEAS   $6,S
61a9: 39              RTS
61aa: fc 69 9c        LDD    $699C
61ad: 17 9b a0        LBSR   $FD50
61b0: c6 06           LDB    #$06
61b2: 1d              SEX
61b3: 1f 03           TFR    D,U
61b5: 10 be 22 21     LDY    $2221
61b9: 8e 00 04        LDX    #$0004
61bc: 34 70           PSHS   U,Y,X
61be: 17 6c 20        LBSR   $CDE1
61c1: 32 66           LEAS   $6,S
61c3: e7 62           STB    $2,S
61c5: e6 62           LDB    $2,S
61c7: c1 09           CMPB   #$09
61c9: 10 24 00 47     LBCC   $6214
61cd: ce 22 1c        LDU    #$221C
61d0: 10 8e 24 14     LDY    #$2414
61d4: 8e 00 04        LDX    #$0004
61d7: 34 70           PSHS   U,Y,X
61d9: 17 69 34        LBSR   $CB10
61dc: 32 66           LEAS   $6,S
61de: 33 63           LEAU   $3,S
61e0: 10 8e 22 1c     LDY    #$221C
61e4: 8e ea 62        LDX    #$EA62
61e7: cc 00 06        LDD    #$0006
61ea: 34 76           PSHS   U,Y,X,D
61ec: 17 71 d7        LBSR   $D3C6
61ef: 32 68           LEAS   $8,S
61f1: c1 00           CMPB   #$00
61f3: 10 26 00 15     LBNE   $620C
61f7: ce 22 1c        LDU    #$221C
61fa: 10 ae e9 00 0a  LDY    $000A,S
61ff: 8e 00 04        LDX    #$0004
6202: 34 70           PSHS   U,Y,X
6204: 17 71 76        LBSR   $D37D
6207: 32 66           LEAS   $6,S
6209: 16 00 05        LBRA   $6211
620c: c6 34           LDB    #$34
620e: f7 3c 02        STB    $3C02
6211: 16 00 10        LBRA   $6224
6214: e6 62           LDB    $2,S
6216: 4f              CLRA
6217: 10 83 00 ff     CMPD   #$00FF
621b: 10 27 00 05     LBEQ   $6224
621f: c6 34           LDB    #$34
6221: f7 3c 02        STB    $3C02
6224: 32 66           LEAS   $6,S
6226: 39              RTS
6227: fc 69 98        LDD    $6998
622a: 17 9b 23        LBSR   $FD50
622d: c6 0a           LDB    #$0A
622f: 1d              SEX
6230: 1f 03           TFR    D,U
6232: 10 be 22 21     LDY    $2221
6236: 8e 00 04        LDX    #$0004
6239: 34 70           PSHS   U,Y,X
623b: 17 6b a3        LBSR   $CDE1
623e: 32 66           LEAS   $6,S
6240: e7 62           STB    $2,S
6242: e6 62           LDB    $2,S
6244: c1 06           CMPB   #$06
6246: 10 24 00 25     LBCC   $626F
624a: ce 00 00        LDU    #$0000
624d: 34 40           PSHS   U
624f: 17 fe 71        LBSR   $60C3
6252: 32 62           LEAS   $2,S
6254: c1 00           CMPB   #$00
6256: 10 26 00 12     LBNE   $626C
625a: ce 24 15        LDU    #$2415
625d: 10 8e 00 02     LDY    #$0002
6261: 34 60           PSHS   U,Y
6263: 17 67 0d        LBSR   $C973
6266: 32 64           LEAS   $4,S
6268: ed f9 00 07     STD    [$0007,S]
626c: 16 00 10        LBRA   $627F
626f: e6 62           LDB    $2,S
6271: 4f              CLRA
6272: 10 83 00 ff     CMPD   #$00FF
6276: 10 27 00 05     LBEQ   $627F
627a: c6 32           LDB    #$32
627c: f7 3c 02        STB    $3C02
627f: 32 63           LEAS   $3,S
6281: 39              RTS
6282: fc 69 d8        LDD    $69D8
6285: 17 9a c8        LBSR   $FD50
6288: be 3d 11        LDX    $3D11
628b: 16 03 ab        LBRA   $6639
628e: fe 23 bf        LDU    $23BF
6291: 10 8e 00 02     LDY    #$0002
6295: 34 60           PSHS   U,Y
6297: 17 fe 93        LBSR   $612D
629a: 32 64           LEAS   $4,S
629c: ce 00 00        LDU    #$0000
629f: 34 40           PSHS   U
62a1: 17 fc 8f        LBSR   $5F33
62a4: 32 62           LEAS   $2,S
62a6: be 23 bf        LDX    $23BF
62a9: 30 03           LEAX   $3,X
62ab: fc 22 21        LDD    $2221
62ae: ed 84           STD    ,X
62b0: ce 00 00        LDU    #$0000
62b3: 34 40           PSHS   U
62b5: 17 f5 6e        LBSR   $5826
62b8: 32 62           LEAS   $2,S
62ba: ce 00 00        LDU    #$0000
62bd: 10 8e 00 02     LDY    #$0002
62c1: 34 60           PSHS   U,Y
62c3: be 3c 0e        LDX    $3C0E
62c6: ad 84           JSR    ,X
62c8: 32 64           LEAS   $4,S
62ca: 16 03 9d        LBRA   $666A
62cd: be 23 bf        LDX    $23BF
62d0: 30 05           LEAX   $5,X
62d2: 1f 13           TFR    X,U
62d4: 10 8e 00 02     LDY    #$0002
62d8: 34 60           PSHS   U,Y
62da: 17 fe 50        LBSR   $612D
62dd: 32 64           LEAS   $4,S
62df: be 23 bf        LDX    $23BF
62e2: 30 08           LEAX   $8,X
62e4: fc 22 21        LDD    $2221
62e7: ed 84           STD    ,X
62e9: cc 00 01        LDD    #$0001
62ec: fd 3d 11        STD    $3D11
62ef: ce 00 00        LDU    #$0000
62f2: 34 40           PSHS   U
62f4: 17 f5 2f        LBSR   $5826
62f7: 32 62           LEAS   $2,S
62f9: ce 00 00        LDU    #$0000
62fc: 10 8e 00 02     LDY    #$0002
6300: 34 60           PSHS   U,Y
6302: be 3c 0e        LDX    $3C0E
6305: ad 84           JSR    ,X
6307: 32 64           LEAS   $4,S
6309: 16 03 5e        LBRA   $666A
630c: be 23 bf        LDX    $23BF
630f: 30 0a           LEAX   $A,X
6311: 1f 13           TFR    X,U
6313: 10 8e 00 02     LDY    #$0002
6317: 34 60           PSHS   U,Y
6319: 17 fe 8e        LBSR   $61AA
631c: 32 64           LEAS   $4,S
631e: ce 00 00        LDU    #$0000
6321: 34 40           PSHS   U
6323: 17 fc 4a        LBSR   $5F70
6326: 32 62           LEAS   $2,S
6328: be 23 bf        LDX    $23BF
632b: 30 0d           LEAX   $D,X
632d: fc 22 21        LDD    $2221
6330: ed 84           STD    ,X
6332: ce 00 00        LDU    #$0000
6335: 34 40           PSHS   U
6337: 17 f6 00        LBSR   $593A
633a: 32 62           LEAS   $2,S
633c: ce 00 01        LDU    #$0001
633f: 10 8e 00 02     LDY    #$0002
6343: 34 60           PSHS   U,Y
6345: be 3c 0e        LDX    $3C0E
6348: ad 84           JSR    ,X
634a: 32 64           LEAS   $4,S
634c: 16 03 1b        LBRA   $666A
634f: be 23 bf        LDX    $23BF
6352: 30 0f           LEAX   $F,X
6354: 1f 13           TFR    X,U
6356: 10 8e 00 02     LDY    #$0002
635a: 34 60           PSHS   U,Y
635c: 17 fe 4b        LBSR   $61AA
635f: 32 64           LEAS   $4,S
6361: be 23 bf        LDX    $23BF
6364: 30 88 12        LEAX   $12,X
6367: fc 22 21        LDD    $2221
636a: ed 84           STD    ,X
636c: cc 00 03        LDD    #$0003
636f: fd 3d 11        STD    $3D11
6372: ce 00 00        LDU    #$0000
6375: 34 40           PSHS   U
6377: 17 f5 c0        LBSR   $593A
637a: 32 62           LEAS   $2,S
637c: ce 00 01        LDU    #$0001
637f: 10 8e 00 02     LDY    #$0002
6383: 34 60           PSHS   U,Y
6385: be 3c 0e        LDX    $3C0E
6388: ad 84           JSR    ,X
638a: 32 64           LEAS   $4,S
638c: 16 02 db        LBRA   $666A
638f: ec 9f 3d 13     LDD    [$3D13]
6393: ed 66           STD    $6,S
6395: fe 3d 13        LDU    $3D13
6398: 10 8e 00 02     LDY    #$0002
639c: 34 60           PSHS   U,Y
639e: 17 fe 86        LBSR   $6227
63a1: 32 64           LEAS   $4,S
63a3: fc 22 21        LDD    $2221
63a6: ed 9f 3d 17     STD    [$3D17]
63aa: ee 66           LDU    $6,S
63ac: 10 8e 00 02     LDY    #$0002
63b0: 34 60           PSHS   U,Y
63b2: 17 fc 7e        LBSR   $6033
63b5: 32 64           LEAS   $4,S
63b7: ce 00 00        LDU    #$0000
63ba: 34 40           PSHS   U
63bc: 17 f6 ef        LBSR   $5AAE
63bf: 32 62           LEAS   $2,S
63c1: ce 00 02        LDU    #$0002
63c4: 10 8e 00 02     LDY    #$0002
63c8: 34 60           PSHS   U,Y
63ca: be 3c 0e        LDX    $3C0E
63cd: ad 84           JSR    ,X
63cf: 32 64           LEAS   $4,S
63d1: 16 02 96        LBRA   $666A
63d4: fe 3d 15        LDU    $3D15
63d7: 10 8e 00 02     LDY    #$0002
63db: 34 60           PSHS   U,Y
63dd: 17 fe 47        LBSR   $6227
63e0: 32 64           LEAS   $4,S
63e2: fc 22 21        LDD    $2221
63e5: ed 9f 3d 19     STD    [$3D19]
63e9: cc 00 05        LDD    #$0005
63ec: fd 3d 11        STD    $3D11
63ef: ce 00 00        LDU    #$0000
63f2: 34 40           PSHS   U
63f4: 17 f6 b7        LBSR   $5AAE
63f7: 32 62           LEAS   $2,S
63f9: ce 00 02        LDU    #$0002
63fc: 10 8e 00 02     LDY    #$0002
6400: 34 60           PSHS   U,Y
6402: be 3c 0e        LDX    $3C0E
6405: ad 84           JSR    ,X
6407: 32 64           LEAS   $4,S
6409: 16 02 5e        LBRA   $666A
640c: fc 22 04        LDD    $2204
640f: 84 00           ANDA   #$00
6411: c4 08           ANDB   #$08
6413: 10 83 00 00     CMPD   #$0000
6417: 10 27 00 4e     LBEQ   $6469
641b: c6 08           LDB    #$08
641d: 1d              SEX
641e: 1f 03           TFR    D,U
6420: 10 8e 00 00     LDY    #$0000
6424: 8e 00 04        LDX    #$0004
6427: 34 70           PSHS   U,Y,X
6429: 17 69 b5        LBSR   $CDE1
642c: 32 66           LEAS   $6,S
642e: 10 83 00 03     CMPD   #$0003
6432: 10 2c 00 14     LBGE   $644A
6436: ce 24 14        LDU    #$2414
6439: 10 8e 00 02     LDY    #$0002
643d: 34 60           PSHS   U,Y
643f: 17 65 f4        LBSR   $CA36
6442: 32 64           LEAS   $4,S
6444: f7 22 19        STB    $2219
6447: 16 00 05        LBRA   $644F
644a: c6 7f           LDB    #$7F
644c: f7 22 19        STB    $2219
644f: f6 22 19        LDB    $2219
6452: c1 10           CMPB   #$10
6454: 10 24 00 09     LBCC   $6461
6458: f6 22 19        LDB    $2219
645b: f7 3d 1b        STB    $3D1B
645e: 16 00 05        LBRA   $6466
6461: c6 36           LDB    #$36
6463: f7 3c 02        STB    $3C02
6466: 16 00 1c        LBRA   $6485
6469: f6 23 9a        LDB    $239A
646c: f7 24 15        STB    $2415
646f: c6 30           LDB    #$30
6471: f7 24 14        STB    $2414
6474: ce 24 14        LDU    #$2414
6477: 10 8e 00 02     LDY    #$0002
647b: 34 60           PSHS   U,Y
647d: 17 67 d3        LBSR   $CC53
6480: 32 64           LEAS   $4,S
6482: f7 3d 1b        STB    $3D1B
6485: ce 00 00        LDU    #$0000
6488: 34 40           PSHS   U
648a: 17 f1 8d        LBSR   $561A
648d: 32 62           LEAS   $2,S
648f: ce 00 00        LDU    #$0000
6492: 34 40           PSHS   U
6494: 17 f6 c9        LBSR   $5B60
6497: 32 62           LEAS   $2,S
6499: ce 00 03        LDU    #$0003
649c: 10 8e 00 02     LDY    #$0002
64a0: 34 60           PSHS   U,Y
64a2: be 3c 0e        LDX    $3C0E
64a5: ad 84           JSR    ,X
64a7: 32 64           LEAS   $4,S
64a9: 16 01 be        LBRA   $666A
64ac: cc 00 08        LDD    #$0008
64af: fd 3d 11        STD    $3D11
64b2: fe 3d 11        LDU    $3D11
64b5: 10 8e 00 02     LDY    #$0002
64b9: 34 60           PSHS   U,Y
64bb: 17 11 8b        LBSR   $7649
64be: 32 64           LEAS   $4,S
64c0: ce 00 00        LDU    #$0000
64c3: 34 40           PSHS   U
64c5: 17 08 9e        LBSR   $6D66
64c8: 32 62           LEAS   $2,S
64ca: e7 68           STB    $8,S
64cc: f6 3c 80        LDB    $3C80
64cf: 4f              CLRA
64d0: 1f 03           TFR    D,U
64d2: e6 68           LDB    $8,S
64d4: 4f              CLRA
64d5: 1f 02           TFR    D,Y
64d7: 8e 00 04        LDX    #$0004
64da: 34 70           PSHS   U,Y,X
64dc: 17 05 b6        LBSR   $6A95
64df: 32 66           LEAS   $6,S
64e1: cc 00 0b        LDD    #$000B
64e4: fd 3d 11        STD    $3D11
64e7: ce 00 04        LDU    #$0004
64ea: 10 8e 00 02     LDY    #$0002
64ee: 34 60           PSHS   U,Y
64f0: be 3c 0e        LDX    $3C0E
64f3: ad 84           JSR    ,X
64f5: 32 64           LEAS   $4,S
64f7: 16 01 70        LBRA   $666A
64fa: fe 3d 11        LDU    $3D11
64fd: 10 8e 00 02     LDY    #$0002
6501: 34 60           PSHS   U,Y
6503: 17 11 43        LBSR   $7649
6506: 32 64           LEAS   $4,S
6508: ce 00 00        LDU    #$0000
650b: 34 40           PSHS   U
650d: 17 08 56        LBSR   $6D66
6510: 32 62           LEAS   $2,S
6512: e7 68           STB    $8,S
6514: f6 3c 80        LDB    $3C80
6517: 4f              CLRA
6518: 1f 03           TFR    D,U
651a: e6 68           LDB    $8,S
651c: 4f              CLRA
651d: 1f 02           TFR    D,Y
651f: 8e 00 04        LDX    #$0004
6522: 34 70           PSHS   U,Y,X
6524: 17 05 6e        LBSR   $6A95
6527: 32 66           LEAS   $6,S
6529: 16 01 3e        LBRA   $666A
652c: f6 22 19        LDB    $2219
652f: 4f              CLRA
6530: 1f 03           TFR    D,U
6532: 10 8e 00 02     LDY    #$0002
6536: 34 60           PSHS   U,Y
6538: 17 07 9c        LBSR   $6CD7
653b: 32 64           LEAS   $4,S
653d: 16 01 2a        LBRA   $666A
6540: f6 23 9a        LDB    $239A
6543: f7 24 15        STB    $2415
6546: c6 30           LDB    #$30
6548: f7 24 14        STB    $2414
654b: ce 24 14        LDU    #$2414
654e: 10 8e 00 02     LDY    #$0002
6552: 34 60           PSHS   U,Y
6554: 17 66 fc        LBSR   $CC53
6557: 32 64           LEAS   $4,S
6559: f7 3c 05        STB    $3C05
655c: 5f              CLRB
655d: 1d              SEX
655e: 1f 03           TFR    D,U
6560: 10 8e 00 02     LDY    #$0002
6564: 34 60           PSHS   U,Y
6566: 17 df a6        LBSR   $450F
6569: 32 64           LEAS   $4,S
656b: f7 3c 06        STB    $3C06
656e: f6 3c 05        LDB    $3C05
6571: 4f              CLRA
6572: 1f 03           TFR    D,U
6574: 5f              CLRB
6575: 1d              SEX
6576: 1f 02           TFR    D,Y
6578: 8e 00 04        LDX    #$0004
657b: 34 70           PSHS   U,Y,X
657d: 17 df ad        LBSR   $452D
6580: 32 66           LEAS   $6,S
6582: ce 3c 10        LDU    #$3C10
6585: f6 3c 05        LDB    $3C05
6588: 4f              CLRA
6589: 1f 02           TFR    D,Y
658b: 34 60           PSHS   U,Y
658d: 86 01           LDA    #$01
658f: 8e 69 98        LDX    #$6998
6592: 17 97 55        LBSR   $FCEA
6595: ae 84           LDX    ,X
6597: bf 3c 07        STX    $3C07
659a: ce 3c 10        LDU    #$3C10
659d: f6 3c 05        LDB    $3C05
65a0: 4f              CLRA
65a1: 1f 02           TFR    D,Y
65a3: 34 60           PSHS   U,Y
65a5: 86 01           LDA    #$01
65a7: 8e 69 98        LDX    #$6998
65aa: 17 97 3d        LBSR   $FCEA
65ad: 30 02           LEAX   $2,X
65af: ae 84           LDX    ,X
65b1: bf 3c 09        STX    $3C09
65b4: ce 3c 10        LDU    #$3C10
65b7: f6 3c 05        LDB    $3C05
65ba: 4f              CLRA
65bb: 1f 02           TFR    D,Y
65bd: 34 60           PSHS   U,Y
65bf: 86 01           LDA    #$01
65c1: 8e 69 98        LDX    #$6998
65c4: 17 97 23        LBSR   $FCEA
65c7: ec 9f 3d 13     LDD    [$3D13]
65cb: ed 84           STD    ,X
65cd: ce 3c 10        LDU    #$3C10
65d0: f6 3c 05        LDB    $3C05
65d3: 4f              CLRA
65d4: 1f 02           TFR    D,Y
65d6: 34 60           PSHS   U,Y
65d8: 86 01           LDA    #$01
65da: 8e 69 98        LDX    #$6998
65dd: 17 97 0a        LBSR   $FCEA
65e0: 30 02           LEAX   $2,X
65e2: cc 01 5e        LDD    #$015E
65e5: ed 84           STD    ,X
65e7: 5f              CLRB
65e8: 4f              CLRA
65e9: fd 3d 0f        STD    $3D0F
65ec: ce 24 15        LDU    #$2415
65ef: 10 8e 00 02     LDY    #$0002
65f3: 34 60           PSHS   U,Y
65f5: 17 f4 fe        LBSR   $5AF6
65f8: 32 64           LEAS   $4,S
65fa: c6 01           LDB    #$01
65fc: 1d              SEX
65fd: 1f 03           TFR    D,U
65ff: 10 8e 24 15     LDY    #$2415
6603: c6 01           LDB    #$01
6605: 1d              SEX
6606: 1f 01           TFR    D,X
6608: c6 23           LDB    #$23
660a: 1d              SEX
660b: 34 76           PSHS   U,Y,X,D
660d: ce 00 08        LDU    #$0008
6610: 34 40           PSHS   U
6612: 17 f0 8f        LBSR   $56A4
6615: 32 6a           LEAS   $A,S
6617: ce 00 00        LDU    #$0000
661a: 34 40           PSHS   U
661c: 17 e4 40        LBSR   $4A5F
661f: 32 62           LEAS   $2,S
6621: c6 01           LDB    #$01
6623: f7 3c 04        STB    $3C04
6626: ce 00 03        LDU    #$0003
6629: 10 8e 00 02     LDY    #$0002
662d: 34 60           PSHS   U,Y
662f: be 3c 0e        LDX    $3C0E
6632: ad 84           JSR    ,X
6634: 32 64           LEAS   $4,S
6636: 16 00 31        LBRA   $666A
6639: 8c 00 0d        CMPX   #$000D
663c: 10 2e 00 2a     LBGT   $666A
6640: 1f 10           TFR    X,D
6642: 83 00 01        SUBD   #$0001
6645: 10 2d 00 21     LBLT   $666A
6649: 8e 66 50        LDX    #$6650
664c: 58              ASLB
664d: 49              ROLA
664e: 6e 9b           JMP    [D,X]
6650: 62 8e           XNC    W,X
6652: 62 cd 63 0c     XNC    $C962,PCR
6656: 63 4f           COM    $F,U
6658: 63 8f           COM    ,W
665a: 63 d4           COM    [,U]
665c: 64 0c           LSR    $C,X
665e: 64 fa           LSR    [F,S]
6660: 64 fa           LSR    [F,S]
6662: 64 fa           LSR    [F,S]
6664: 64 ac 65        LSR    $66CC,PCR
6667: 2c 65           BGE    $66CE
6669: 40              NEGA
666a: 32 69           LEAS   $9,S
666c: 39              RTS
666d: fc 69 da        LDD    $69DA
6670: 17 96 dd        LBSR   $FD50
6673: c6 01           LDB    #$01
6675: e7 62           STB    $2,S
6677: be 3d 11        LDX    $3D11
667a: 16 02 ef        LBRA   $696C
667d: cc 00 01        LDD    #$0001
6680: fd 3d 11        STD    $3D11
6683: ae e9 00 11     LDX    $0011,S
6687: 8c 00 00        CMPX   #$0000
668a: 10 27 00 24     LBEQ   $66B2
668e: be 23 bf        LDX    $23BF
6691: 30 05           LEAX   $5,X
6693: af 68           STX    $8,S
6695: ce 22 1c        LDU    #$221C
6698: 10 ae 68        LDY    $8,S
669b: be 23 bf        LDX    $23BF
669e: cc 00 06        LDD    #$0006
66a1: 34 76           PSHS   U,Y,X,D
66a3: 17 6c ec        LBSR   $D392
66a6: 32 68           LEAS   $8,S
66a8: c1 00           CMPB   #$00
66aa: 17 97 09        LBSR   $FDB6
66ad: e7 62           STB    $2,S
66af: 16 00 21        LBRA   $66D3
66b2: be 23 bf        LDX    $23BF
66b5: 30 05           LEAX   $5,X
66b7: af 68           STX    $8,S
66b9: ce 22 1c        LDU    #$221C
66bc: 10 ae 68        LDY    $8,S
66bf: be 23 bf        LDX    $23BF
66c2: cc 00 06        LDD    #$0006
66c5: 34 76           PSHS   U,Y,X,D
66c7: 17 6c fc        LBSR   $D3C6
66ca: 32 68           LEAS   $8,S
66cc: c1 00           CMPB   #$00
66ce: 17 96 e5        LBSR   $FDB6
66d1: e7 62           STB    $2,S
66d3: e6 62           LDB    $2,S
66d5: c1 00           CMPB   #$00
66d7: 10 27 00 34     LBEQ   $670F
66db: 33 65           LEAU   $5,S
66dd: 10 8e 22 1c     LDY    #$221C
66e1: 8e ea 55        LDX    #$EA55
66e4: cc 00 06        LDD    #$0006
66e7: 34 76           PSHS   U,Y,X,D
66e9: 17 6c da        LBSR   $D3C6
66ec: 32 68           LEAS   $8,S
66ee: c1 00           CMPB   #$00
66f0: 10 26 00 1b     LBNE   $670F
66f4: ce 22 1c        LDU    #$221C
66f7: 10 be 23 bf     LDY    $23BF
66fb: 8e 00 04        LDX    #$0004
66fe: 34 70           PSHS   U,Y,X
6700: 17 6c 7a        LBSR   $D37D
6703: 32 66           LEAS   $6,S
6705: ce 00 00        LDU    #$0000
6708: 34 40           PSHS   U
670a: 17 f8 26        LBSR   $5F33
670d: 32 62           LEAS   $2,S
670f: ce 00 00        LDU    #$0000
6712: 34 40           PSHS   U
6714: 17 f1 0f        LBSR   $5826
6717: 32 62           LEAS   $2,S
6719: ce 00 00        LDU    #$0000
671c: 10 8e 00 02     LDY    #$0002
6720: 34 60           PSHS   U,Y
6722: be 3c 0e        LDX    $3C0E
6725: ad 84           JSR    ,X
6727: 32 64           LEAS   $4,S
6729: 16 02 69        LBRA   $6995
672c: cc 00 03        LDD    #$0003
672f: fd 3d 11        STD    $3D11
6732: ae e9 00 11     LDX    $0011,S
6736: 8c 00 00        CMPX   #$0000
6739: 10 27 00 2a     LBEQ   $6767
673d: be 23 bf        LDX    $23BF
6740: 30 0f           LEAX   $F,X
6742: fe 23 bf        LDU    $23BF
6745: 33 4a           LEAU   $A,U
6747: af 68           STX    $8,S
6749: ef 6a           STU    $A,S
674b: ce 22 1c        LDU    #$221C
674e: 10 ae 68        LDY    $8,S
6751: ae 6a           LDX    $A,S
6753: cc 00 06        LDD    #$0006
6756: 34 76           PSHS   U,Y,X,D
6758: 17 6c 37        LBSR   $D392
675b: 32 68           LEAS   $8,S
675d: c1 00           CMPB   #$00
675f: 17 96 54        LBSR   $FDB6
6762: e7 62           STB    $2,S
6764: 16 00 27        LBRA   $678E
6767: be 23 bf        LDX    $23BF
676a: 30 0f           LEAX   $F,X
676c: fe 23 bf        LDU    $23BF
676f: 33 4a           LEAU   $A,U
6771: af 6a           STX    $A,S
6773: ef 68           STU    $8,S
6775: ce 22 1c        LDU    #$221C
6778: 10 ae 6a        LDY    $A,S
677b: ae 68           LDX    $8,S
677d: cc 00 06        LDD    #$0006
6780: 34 76           PSHS   U,Y,X,D
6782: 17 6c 41        LBSR   $D3C6
6785: 32 68           LEAS   $8,S
6787: c1 00           CMPB   #$00
6789: 17 96 2a        LBSR   $FDB6
678c: e7 62           STB    $2,S
678e: e6 62           LDB    $2,S
6790: c1 00           CMPB   #$00
6792: 10 27 00 37     LBEQ   $67CD
6796: 33 65           LEAU   $5,S
6798: 10 8e 22 1c     LDY    #$221C
679c: 8e ea 62        LDX    #$EA62
679f: cc 00 06        LDD    #$0006
67a2: 34 76           PSHS   U,Y,X,D
67a4: 17 6c 1f        LBSR   $D3C6
67a7: 32 68           LEAS   $8,S
67a9: c1 00           CMPB   #$00
67ab: 10 26 00 1e     LBNE   $67CD
67af: be 23 bf        LDX    $23BF
67b2: 30 0a           LEAX   $A,X
67b4: ce 22 1c        LDU    #$221C
67b7: 1f 12           TFR    X,Y
67b9: 8e 00 04        LDX    #$0004
67bc: 34 70           PSHS   U,Y,X
67be: 17 6b bc        LBSR   $D37D
67c1: 32 66           LEAS   $6,S
67c3: ce 00 00        LDU    #$0000
67c6: 34 40           PSHS   U
67c8: 17 f7 a5        LBSR   $5F70
67cb: 32 62           LEAS   $2,S
67cd: ce 00 00        LDU    #$0000
67d0: 34 40           PSHS   U
67d2: 17 f1 65        LBSR   $593A
67d5: 32 62           LEAS   $2,S
67d7: ce 00 01        LDU    #$0001
67da: 10 8e 00 02     LDY    #$0002
67de: 34 60           PSHS   U,Y
67e0: be 3c 0e        LDX    $3C0E
67e3: ad 84           JSR    ,X
67e5: 32 64           LEAS   $4,S
67e7: 16 01 ab        LBRA   $6995
67ea: cc 00 05        LDD    #$0005
67ed: fd 3d 11        STD    $3D11
67f0: ec 9f 3d 13     LDD    [$3D13]
67f4: ed 63           STD    $3,S
67f6: ae e9 00 11     LDX    $0011,S
67fa: 8c 00 00        CMPX   #$0000
67fd: 10 27 00 20     LBEQ   $6821
6801: ce 22 1a        LDU    #$221A
6804: 10 ae 9f 3d 15  LDY    [$3D15]
6809: ae 9f 3d 13     LDX    [$3D13]
680d: cc 00 06        LDD    #$0006
6810: 34 76           PSHS   U,Y,X,D
6812: 17 dc e5        LBSR   $44FA
6815: 32 68           LEAS   $8,S
6817: c1 00           CMPB   #$00
6819: 17 95 9a        LBSR   $FDB6
681c: e7 62           STB    $2,S
681e: 16 00 1c        LBRA   $683D
6821: ae 9f 3d 13     LDX    [$3D13]
6825: ac 9f 3d 15     CMPX   [$3D15]
6829: 10 25 00 0e     LBCS   $683B
682d: ec 9f 3d 13     LDD    [$3D13]
6831: a3 9f 3d 15     SUBD   [$3D15]
6835: fd 22 1a        STD    $221A
6838: 16 00 02        LBRA   $683D
683b: 6f 62           CLR    $2,S
683d: e6 62           LDB    $2,S
683f: c1 00           CMPB   #$00
6841: 10 27 00 17     LBEQ   $685C
6845: fc 22 1a        LDD    $221A
6848: ed 9f 3d 13     STD    [$3D13]
684c: ee 63           LDU    $3,S
684e: 10 8e 00 02     LDY    #$0002
6852: 34 60           PSHS   U,Y
6854: 17 f7 dc        LBSR   $6033
6857: 32 64           LEAS   $4,S
6859: 7f 3c 02        CLR    $3C02
685c: ce 00 00        LDU    #$0000
685f: 34 40           PSHS   U
6861: 17 f2 4a        LBSR   $5AAE
6864: 32 62           LEAS   $2,S
6866: ce 00 02        LDU    #$0002
6869: 10 8e 00 02     LDY    #$0002
686d: 34 60           PSHS   U,Y
686f: be 3c 0e        LDX    $3C0E
6872: ad 84           JSR    ,X
6874: 32 64           LEAS   $4,S
6876: 16 01 1c        LBRA   $6995
6879: ae e9 00 11     LDX    $0011,S
687d: 8c 00 00        CMPX   #$0000
6880: 10 27 00 19     LBEQ   $689D
6884: f6 3d 1b        LDB    $3D1B
6887: c1 0f           CMPB   #$0F
6889: 10 24 00 0b     LBCC   $6898
688d: f6 3d 1b        LDB    $3D1B
6890: cb 01           ADDB   #$01
6892: f7 3d 1b        STB    $3D1B
6895: 16 00 02        LBRA   $689A
6898: 6f 62           CLR    $2,S
689a: 16 00 16        LBRA   $68B3
689d: f6 3d 1b        LDB    $3D1B
68a0: c1 00           CMPB   #$00
68a2: 10 23 00 0b     LBLS   $68B1
68a6: f6 3d 1b        LDB    $3D1B
68a9: c0 01           SUBB   #$01
68ab: f7 3d 1b        STB    $3D1B
68ae: 16 00 02        LBRA   $68B3
68b1: 6f 62           CLR    $2,S
68b3: e6 62           LDB    $2,S
68b5: c1 00           CMPB   #$00
68b7: 10 27 00 14     LBEQ   $68CF
68bb: ce 00 00        LDU    #$0000
68be: 34 40           PSHS   U
68c0: 17 ed 57        LBSR   $561A
68c3: 32 62           LEAS   $2,S
68c5: ce 00 00        LDU    #$0000
68c8: 34 40           PSHS   U
68ca: 17 f2 93        LBSR   $5B60
68cd: 32 62           LEAS   $2,S
68cf: ce 00 03        LDU    #$0003
68d2: 10 8e 00 02     LDY    #$0002
68d6: 34 60           PSHS   U,Y
68d8: be 3c 0e        LDX    $3C0E
68db: ad 84           JSR    ,X
68dd: 32 64           LEAS   $4,S
68df: 16 00 b3        LBRA   $6995
68e2: cc 00 08        LDD    #$0008
68e5: fd 3d 11        STD    $3D11
68e8: ee e9 00 11     LDU    $0011,S
68ec: 10 8e 00 02     LDY    #$0002
68f0: 34 60           PSHS   U,Y
68f2: 17 0b 56        LBSR   $744B
68f5: 32 64           LEAS   $4,S
68f7: ce 00 00        LDU    #$0000
68fa: 34 40           PSHS   U
68fc: 17 04 67        LBSR   $6D66
68ff: 32 62           LEAS   $2,S
6901: e7 6c           STB    $C,S
6903: f6 3c 80        LDB    $3C80
6906: 4f              CLRA
6907: 1f 03           TFR    D,U
6909: e6 6c           LDB    $C,S
690b: 4f              CLRA
690c: 1f 02           TFR    D,Y
690e: 8e 00 04        LDX    #$0004
6911: 34 70           PSHS   U,Y,X
6913: 17 01 7f        LBSR   $6A95
6916: 32 66           LEAS   $6,S
6918: cc 00 0b        LDD    #$000B
691b: fd 3d 11        STD    $3D11
691e: ce 00 04        LDU    #$0004
6921: 10 8e 00 02     LDY    #$0002
6925: 34 60           PSHS   U,Y
6927: be 3c 0e        LDX    $3C0E
692a: ad 84           JSR    ,X
692c: 32 64           LEAS   $4,S
692e: 16 00 64        LBRA   $6995
6931: ee e9 00 11     LDU    $0011,S
6935: 10 8e 00 02     LDY    #$0002
6939: 34 60           PSHS   U,Y
693b: 17 0b 0d        LBSR   $744B
693e: 32 64           LEAS   $4,S
6940: ce 00 00        LDU    #$0000
6943: 34 40           PSHS   U
6945: 17 04 1e        LBSR   $6D66
6948: 32 62           LEAS   $2,S
694a: e7 6c           STB    $C,S
694c: f6 3c 80        LDB    $3C80
694f: 4f              CLRA
6950: 1f 03           TFR    D,U
6952: e6 6c           LDB    $C,S
6954: 4f              CLRA
6955: 1f 02           TFR    D,Y
6957: 8e 00 04        LDX    #$0004
695a: 34 70           PSHS   U,Y,X
695c: 17 01 36        LBSR   $6A95
695f: 32 66           LEAS   $6,S
6961: 16 00 31        LBRA   $6995
6964: c6 04           LDB    #$04
6966: f7 3c 02        STB    $3C02
6969: 16 00 29        LBRA   $6995
696c: 8c 00 0b        CMPX   #$000B
696f: 2e f3           BGT    $6964
6971: 1f 10           TFR    X,D
6973: 83 00 01        SUBD   #$0001
6976: 2d ec           BLT    $6964
6978: 8e 69 7f        LDX    #$697F
697b: 58              ASLB
697c: 49              ROLA
697d: 6e 9b           JMP    [D,X]
697f: 66 83           ROR    ,--X
6981: 66 7d           ROR    -$3,S
6983: 67 32           ASR    -$E,Y
6985: 67 2c           ASR    $C,Y
6987: 67 f0           ASR    [,--W]
6989: 67 ea           ASR    F,S
698b: 68 79           ASL    -$7,S
698d: 69 31           ROL    -$F,Y
698f: 69 31           ROL    -$F,Y
6991: 69 31           ROL    -$F,Y
6993: 68 e2           ASL    ,-S
6995: 32 6d           LEAS   $D,S
6997: 39              RTS
6998: 00 01           NEG    <$01
699a: 00 00           NEG    <$00
699c: 00 04           NEG    <$04
699e: 00 01           NEG    <$01
69a0: 00 00           NEG    <$00
69a2: 00 03           NEG    <$03
69a4: 00 02           NEG    <$02
69a6: 2a 2a           BPL    $69D2
69a8: 20 52           BRA    $69FC
69aa: 75 6e 6e        LSR    $6E6E
69ad: 69 6e           ROL    $E,S
69af: 67 20           ASR    $0,Y
69b1: 53              COMB
69b2: 69 6e           ROL    $E,S
69b4: 67 6c           ASR    $C,S
69b6: 65 20           LSR    $0,Y
69b8: 2a 2a           BPL    $69E4
69ba: 00 2a           NEG    <$2A
69bc: 2a 20           BPL    $69DE
69be: 52              XNCB
69bf: 75 6e 6e        LSR    $6E6E
69c2: 69 6e           ROL    $E,S
69c4: 67 20           ASR    $0,Y
69c6: 43              COMA
69c7: 6f 6e           CLR    $E,S
69c9: 74 20 2a        LSR    $202A
69cc: 2a 20           BPL    $69EE
69ce: 20 00           BRA    $69D0
69d0: 06 36           ROR    <$36
69d2: 33 35           LEAU   -$B,Y
69d4: 35 36           PULS   D,X,Y
69d6: 00 08           NEG    <$08
69d8: 00 07           NEG    <$07
69da: 00 0b           NEG    <$0B
69dc: fc 6d 5a        LDD    $6D5A
69df: 17 93 6e        LBSR   $FD50
69e2: ce 3c 50        LDU    #$3C50
69e5: 10 ae e9 00 07  LDY    $0007,S
69ea: 34 60           PSHS   U,Y
69ec: 86 01           LDA    #$01
69ee: 8e 6d 5a        LDX    #$6D5A
69f1: 17 92 f6        LBSR   $FCEA
69f4: ee e9 00 09     LDU    $0009,S
69f8: 1f 12           TFR    X,Y
69fa: 8e 00 04        LDX    #$0004
69fd: 34 70           PSHS   U,Y,X
69ff: 17 69 7b        LBSR   $D37D
6a02: 32 66           LEAS   $6,S
6a04: f6 24 ae        LDB    $24AE
6a07: e7 62           STB    $2,S
6a09: ee e9 00 07     LDU    $0007,S
6a0d: 5f              CLRB
6a0e: 1d              SEX
6a0f: 1f 02           TFR    D,Y
6a11: 8e 00 04        LDX    #$0004
6a14: 34 70           PSHS   U,Y,X
6a16: 17 7d ab        LBSR   $E7C4
6a19: 32 66           LEAS   $6,S
6a1b: ee e9 00 09     LDU    $0009,S
6a1f: 5f              CLRB
6a20: 1d              SEX
6a21: 1f 02           TFR    D,Y
6a23: 8e 00 04        LDX    #$0004
6a26: 34 70           PSHS   U,Y,X
6a28: 17 78 96        LBSR   $E2C1
6a2b: 32 66           LEAS   $6,S
6a2d: 5f              CLRB
6a2e: 1d              SEX
6a2f: 1f 03           TFR    D,U
6a31: c6 14           LDB    #$14
6a33: 1d              SEX
6a34: 1f 02           TFR    D,Y
6a36: 8e 00 04        LDX    #$0004
6a39: 34 70           PSHS   U,Y,X
6a3b: 17 74 31        LBSR   $DE6F
6a3e: 32 66           LEAS   $6,S
6a40: e6 62           LDB    $2,S
6a42: 4f              CLRA
6a43: 1f 03           TFR    D,U
6a45: c6 15           LDB    #$15
6a47: 1d              SEX
6a48: 1f 02           TFR    D,Y
6a4a: 8e 00 04        LDX    #$0004
6a4d: 34 70           PSHS   U,Y,X
6a4f: 17 74 1d        LBSR   $DE6F
6a52: 32 66           LEAS   $6,S
6a54: 32 63           LEAS   $3,S
6a56: 39              RTS
6a57: fc 6d 5a        LDD    $6D5A
6a5a: 17 92 f3        LBSR   $FD50
6a5d: 6f 62           CLR    $2,S
6a5f: e6 62           LDB    $2,S
6a61: c1 10           CMPB   #$10
6a63: 10 24 00 2b     LBCC   $6A92
6a67: ce 3c 50        LDU    #$3C50
6a6a: e6 62           LDB    $2,S
6a6c: 4f              CLRA
6a6d: 1f 02           TFR    D,Y
6a6f: 34 60           PSHS   U,Y
6a71: 86 01           LDA    #$01
6a73: 8e 6d 5a        LDX    #$6D5A
6a76: 17 92 71        LBSR   $FCEA
6a79: 1f 13           TFR    X,U
6a7b: e6 62           LDB    $2,S
6a7d: 4f              CLRA
6a7e: 1f 02           TFR    D,Y
6a80: 8e 00 04        LDX    #$0004
6a83: 34 70           PSHS   U,Y,X
6a85: 17 ff 54        LBSR   $69DC
6a88: 32 66           LEAS   $6,S
6a8a: e6 62           LDB    $2,S
6a8c: cb 01           ADDB   #$01
6a8e: e7 62           STB    $2,S
6a90: 20 cd           BRA    $6A5F
6a92: 32 63           LEAS   $3,S
6a94: 39              RTS
6a95: fc 6d 5c        LDD    $6D5C
6a98: 17 92 b5        LBSR   $FD50
6a9b: ae e9 00 06     LDX    $0006,S
6a9f: 8c 00 10        CMPX   #$0010
6aa2: 10 24 00 3a     LBCC   $6AE0
6aa6: f6 3c 03        LDB    $3C03
6aa9: c1 00           CMPB   #$00
6aab: 10 26 00 16     LBNE   $6AC5
6aaf: ee e9 00 06     LDU    $0006,S
6ab3: 10 ae e9 00 08  LDY    $0008,S
6ab8: 8e 00 04        LDX    #$0004
6abb: 34 70           PSHS   U,Y,X
6abd: 17 7d 04        LBSR   $E7C4
6ac0: 32 66           LEAS   $6,S
6ac2: 16 00 11        LBRA   $6AD6
6ac5: e6 e9 00 07     LDB    $0007,S
6ac9: f7 3d 27        STB    $3D27
6acc: ce 00 00        LDU    #$0000
6acf: 34 40           PSHS   U
6ad1: 17 d9 4a        LBSR   $441E
6ad4: 32 62           LEAS   $2,S
6ad6: ce 00 00        LDU    #$0000
6ad9: 34 40           PSHS   U
6adb: 17 df f3        LBSR   $4AD1
6ade: 32 62           LEAS   $2,S
6ae0: 32 62           LEAS   $2,S
6ae2: 39              RTS
6ae3: fc 6d 5c        LDD    $6D5C
6ae6: 17 92 67        LBSR   $FD50
6ae9: e6 e9 00 07     LDB    $0007,S
6aed: f7 24 b5        STB    $24B5
6af0: ee e9 00 06     LDU    $0006,S
6af4: c6 1c           LDB    #$1C
6af6: 1d              SEX
6af7: 1f 02           TFR    D,Y
6af9: 8e 00 04        LDX    #$0004
6afc: 34 70           PSHS   U,Y,X
6afe: 17 73 6e        LBSR   $DE6F
6b01: 32 66           LEAS   $6,S
6b03: 32 62           LEAS   $2,S
6b05: 39              RTS
6b06: fc 6d 5c        LDD    $6D5C
6b09: 17 92 44        LBSR   $FD50
6b0c: e6 e9 00 07     LDB    $0007,S
6b10: f7 24 b8        STB    $24B8
6b13: ee e9 00 06     LDU    $0006,S
6b17: c6 1f           LDB    #$1F
6b19: 1d              SEX
6b1a: 1f 02           TFR    D,Y
6b1c: 8e 00 04        LDX    #$0004
6b1f: 34 70           PSHS   U,Y,X
6b21: 17 73 4b        LBSR   $DE6F
6b24: 32 66           LEAS   $6,S
6b26: 32 62           LEAS   $2,S
6b28: 39              RTS
6b29: fc 6d 5c        LDD    $6D5C
6b2c: 17 92 21        LBSR   $FD50
6b2f: e6 e9 00 07     LDB    $0007,S
6b33: f7 24 b9        STB    $24B9
6b36: ee e9 00 06     LDU    $0006,S
6b3a: c6 20           LDB    #$20
6b3c: 1d              SEX
6b3d: 1f 02           TFR    D,Y
6b3f: 8e 00 04        LDX    #$0004
6b42: 34 70           PSHS   U,Y,X
6b44: 17 73 28        LBSR   $DE6F
6b47: 32 66           LEAS   $6,S
6b49: 32 62           LEAS   $2,S
6b4b: 39              RTS
6b4c: fc 6d 5c        LDD    $6D5C
6b4f: 17 91 fe        LBSR   $FD50
6b52: e6 e9 00 07     LDB    $0007,S
6b56: f7 24 c4        STB    $24C4
6b59: ee e9 00 06     LDU    $0006,S
6b5d: c6 29           LDB    #$29
6b5f: 1d              SEX
6b60: 1f 02           TFR    D,Y
6b62: 8e 00 04        LDX    #$0004
6b65: 34 70           PSHS   U,Y,X
6b67: 17 73 05        LBSR   $DE6F
6b6a: 32 66           LEAS   $6,S
6b6c: 32 62           LEAS   $2,S
6b6e: 39              RTS
6b6f: fc 6d 5c        LDD    $6D5C
6b72: 17 91 db        LBSR   $FD50
6b75: e6 e9 00 07     LDB    $0007,S
6b79: f7 24 bb        STB    $24BB
6b7c: ee e9 00 06     LDU    $0006,S
6b80: c6 22           LDB    #$22
6b82: 1d              SEX
6b83: 1f 02           TFR    D,Y
6b85: 8e 00 04        LDX    #$0004
6b88: 34 70           PSHS   U,Y,X
6b8a: 17 72 e2        LBSR   $DE6F
6b8d: 32 66           LEAS   $6,S
6b8f: 32 62           LEAS   $2,S
6b91: 39              RTS
6b92: fc 6d 5a        LDD    $6D5A
6b95: 17 91 b8        LBSR   $FD50
6b98: ae e9 00 07     LDX    $0007,S
6b9c: 8c 00 00        CMPX   #$0000
6b9f: 10 26 00 07     LBNE   $6BAA
6ba3: c6 21           LDB    #$21
6ba5: e7 62           STB    $2,S
6ba7: 16 00 14        LBRA   $6BBE
6baa: f6 3c 03        LDB    $3C03
6bad: c1 00           CMPB   #$00
6baf: 10 27 00 07     LBEQ   $6BBA
6bb3: c6 22           LDB    #$22
6bb5: e7 62           STB    $2,S
6bb7: 16 00 04        LBRA   $6BBE
6bba: c6 20           LDB    #$20
6bbc: e7 62           STB    $2,S
6bbe: e6 62           LDB    $2,S
6bc0: 4f              CLRA
6bc1: 1f 03           TFR    D,U
6bc3: 10 8e 00 02     LDY    #$0002
6bc7: 34 60           PSHS   U,Y
6bc9: 8d a4           BSR    $6B6F
6bcb: 32 64           LEAS   $4,S
6bcd: 32 63           LEAS   $3,S
6bcf: 39              RTS
6bd0: fc 6d 5a        LDD    $6D5A
6bd3: 17 91 7a        LBSR   $FD50
6bd6: c6 02           LDB    #$02
6bd8: f7 3d 32        STB    $3D32
6bdb: cc ff ff        LDD    #$FFFF
6bde: fd 3d 2c        STD    $3D2C
6be1: 7f 3d 33        CLR    $3D33
6be4: c6 ff           LDB    #$FF
6be6: f7 3d 34        STB    $3D34
6be9: cc 00 c8        LDD    #$00C8
6bec: fd 3d 30        STD    $3D30
6bef: cc 00 c8        LDD    #$00C8
6bf2: fd 10 04        STD    $1004
6bf5: c6 01           LDB    #$01
6bf7: f7 10 01        STB    $1001
6bfa: f6 24 21        LDB    $2421
6bfd: ca 01           ORB    #$01
6bff: e7 62           STB    $2,S
6c01: e6 62           LDB    $2,S
6c03: f7 10 00        STB    $1000
6c06: e6 62           LDB    $2,S
6c08: 4f              CLRA
6c09: 84 00           ANDA   #$00
6c0b: c4 fe           ANDB   #$FE
6c0d: e7 62           STB    $2,S
6c0f: e6 62           LDB    $2,S
6c11: f7 10 00        STB    $1000
6c14: c6 d1           LDB    #$D1
6c16: f7 24 22        STB    $2422
6c19: f6 24 22        LDB    $2422
6c1c: f7 10 01        STB    $1001
6c1f: 32 63           LEAS   $3,S
6c21: 39              RTS
6c22: fc 6d 5c        LDD    $6D5C
6c25: 17 91 28        LBSR   $FD50
6c28: c6 91           LDB    #$91
6c2a: f7 24 22        STB    $2422
6c2d: f6 24 22        LDB    $2422
6c30: f7 10 01        STB    $1001
6c33: 5f              CLRB
6c34: 1d              SEX
6c35: 1f 03           TFR    D,U
6c37: 10 8e 00 02     LDY    #$0002
6c3b: 34 60           PSHS   U,Y
6c3d: 17 ff 0c        LBSR   $6B4C
6c40: 32 64           LEAS   $4,S
6c42: 32 62           LEAS   $2,S
6c44: 39              RTS
6c45: fc 6d 5a        LDD    $6D5A
6c48: 17 91 05        LBSR   $FD50
6c4b: ce 00 00        LDU    #$0000
6c4e: 34 40           PSHS   U
6c50: 17 6b 2e        LBSR   $D781
6c53: 32 62           LEAS   $2,S
6c55: e7 62           STB    $2,S
6c57: ce 00 00        LDU    #$0000
6c5a: 34 40           PSHS   U
6c5c: 17 dc 22        LBSR   $4881
6c5f: 32 62           LEAS   $2,S
6c61: f6 3c 04        LDB    $3C04
6c64: c1 00           CMPB   #$00
6c66: 10 27 00 0a     LBEQ   $6C74
6c6a: ce 00 00        LDU    #$0000
6c6d: 34 40           PSHS   U
6c6f: 17 ef 83        LBSR   $5BF5
6c72: 32 62           LEAS   $2,S
6c74: e6 62           LDB    $2,S
6c76: 4f              CLRA
6c77: 1f 03           TFR    D,U
6c79: 10 8e 00 02     LDY    #$0002
6c7d: 34 60           PSHS   U,Y
6c7f: 17 6b 1e        LBSR   $D7A0
6c82: 32 64           LEAS   $4,S
6c84: ce 00 00        LDU    #$0000
6c87: 34 40           PSHS   U
6c89: 17 6a f5        LBSR   $D781
6c8c: 32 62           LEAS   $2,S
6c8e: e7 62           STB    $2,S
6c90: 5f              CLRB
6c91: 1d              SEX
6c92: 1f 03           TFR    D,U
6c94: 10 8e 00 02     LDY    #$0002
6c98: 34 60           PSHS   U,Y
6c9a: 17 fe af        LBSR   $6B4C
6c9d: 32 64           LEAS   $4,S
6c9f: 32 63           LEAS   $3,S
6ca1: 39              RTS
6ca2: fc 6d 5c        LDD    $6D5C
6ca5: 17 90 a8        LBSR   $FD50
6ca8: f6 3c 03        LDB    $3C03
6cab: c1 00           CMPB   #$00
6cad: 10 27 00 13     LBEQ   $6CC4
6cb1: cc 44 4c        LDD    #$444C
6cb4: 1f 03           TFR    D,U
6cb6: 10 8e 00 02     LDY    #$0002
6cba: 34 60           PSHS   U,Y
6cbc: 17 83 6b        LBSR   $F02A
6cbf: 32 64           LEAS   $4,S
6cc1: 16 00 10        LBRA   $6CD4
6cc4: cc 42 d1        LDD    #$42D1
6cc7: 1f 03           TFR    D,U
6cc9: 10 8e 00 02     LDY    #$0002
6ccd: 34 60           PSHS   U,Y
6ccf: 17 83 58        LBSR   $F02A
6cd2: 32 64           LEAS   $4,S
6cd4: 32 62           LEAS   $2,S
6cd6: 39              RTS
6cd7: fc 6d 5c        LDD    $6D5C
6cda: 17 90 73        LBSR   $FD50
6cdd: ce 25 81        LDU    #$2581
6ce0: 10 8e 3c 10     LDY    #$3C10
6ce4: 8e 01 01        LDX    #$0101
6ce7: cc 00 06        LDD    #$0006
6cea: 34 76           PSHS   U,Y,X,D
6cec: 17 55 96        LBSR   $C285
6cef: 32 68           LEAS   $8,S
6cf1: ce 26 8f        LDU    #$268F
6cf4: 10 ae e9 00 06  LDY    $0006,S
6cf9: 34 60           PSHS   U,Y
6cfb: 86 01           LDA    #$01
6cfd: 8e 6d 60        LDX    #$6D60
6d00: 17 8f e7        LBSR   $FCEA
6d03: 1f 13           TFR    X,U
6d05: 10 8e 24 e6     LDY    #$24E6
6d09: 8e 01 a9        LDX    #$01A9
6d0c: cc 00 06        LDD    #$0006
6d0f: 34 76           PSHS   U,Y,X,D
6d11: 17 55 71        LBSR   $C285
6d14: 32 68           LEAS   $8,S
6d16: 32 62           LEAS   $2,S
6d18: 39              RTS
6d19: fc 6d 5c        LDD    $6D5C
6d1c: 17 90 31        LBSR   $FD50
6d1f: ce 26 8f        LDU    #$268F
6d22: 10 ae e9 00 06  LDY    $0006,S
6d27: 34 60           PSHS   U,Y
6d29: 86 01           LDA    #$01
6d2b: 8e 6d 60        LDX    #$6D60
6d2e: 17 8f b9        LBSR   $FCEA
6d31: ce 24 e6        LDU    #$24E6
6d34: 1f 12           TFR    X,Y
6d36: 8e 01 a9        LDX    #$01A9
6d39: cc 00 06        LDD    #$0006
6d3c: 34 76           PSHS   U,Y,X,D
6d3e: 17 55 44        LBSR   $C285
6d41: 32 68           LEAS   $8,S
6d43: ce 3c 10        LDU    #$3C10
6d46: 10 8e 25 81     LDY    #$2581
6d4a: 8e 01 01        LDX    #$0101
6d4d: cc 00 06        LDD    #$0006
6d50: 34 76           PSHS   U,Y,X,D
6d52: 17 55 30        LBSR   $C285
6d55: 32 68           LEAS   $8,S
6d57: 32 62           LEAS   $2,S
6d59: 39              RTS
6d5a: 00 01           NEG    <$01
6d5c: 00 00           NEG    <$00
6d5e: 00 03           NEG    <$03
6d60: 00 01           NEG    <$01
6d62: 00 00           NEG    <$00
6d64: 01 a9           NEG    <$A9
6d66: fc 7a 74        LDD    $7A74
6d69: 17 8f e4        LBSR   $FD50
6d6c: be 3d 0d        LDX    $3D0D
6d6f: bc 3d 0f        CMPX   $3D0F
6d72: 10 22 00 16     LBHI   $6D8C
6d76: fe 3d 0d        LDU    $3D0D
6d79: 10 8e 00 02     LDY    #$0002
6d7d: 34 60           PSHS   U,Y
6d7f: 17 d7 8d        LBSR   $450F
6d82: 32 64           LEAS   $4,S
6d84: e7 62           STB    $2,S
6d86: 16 00 07        LBRA   $6D90
6d89: 16 00 04        LBRA   $6D90
6d8c: c6 64           LDB    #$64
6d8e: e7 62           STB    $2,S
6d90: e6 62           LDB    $2,S
6d92: 32 63           LEAS   $3,S
6d94: 39              RTS
6d95: fc 7a 76        LDD    $7A76
6d98: 17 8f b5        LBSR   $FD50
6d9b: be 3d 0f        LDX    $3D0F
6d9e: 8c 00 f9        CMPX   #$00F9
6da1: 10 24 00 09     LBCC   $6DAE
6da5: fc 3d 0f        LDD    $3D0F
6da8: c3 00 01        ADDD   #$0001
6dab: fd 3d 0f        STD    $3D0F
6dae: be 3d 0d        LDX    $3D0D
6db1: bc 3d 0f        CMPX   $3D0F
6db4: 10 22 00 51     LBHI   $6E09
6db8: fc 3d 0f        LDD    $3D0F
6dbb: ed 62           STD    $2,S
6dbd: ae 62           LDX    $2,S
6dbf: bc 3d 0d        CMPX   $3D0D
6dc2: 10 23 00 31     LBLS   $6DF7
6dc6: ec 62           LDD    $2,S
6dc8: 83 00 01        SUBD   #$0001
6dcb: ed 65           STD    $5,S
6dcd: ee 65           LDU    $5,S
6dcf: 10 8e 00 02     LDY    #$0002
6dd3: 34 60           PSHS   U,Y
6dd5: 17 d7 37        LBSR   $450F
6dd8: 32 64           LEAS   $4,S
6dda: e7 64           STB    $4,S
6ddc: e6 64           LDB    $4,S
6dde: 4f              CLRA
6ddf: 1f 03           TFR    D,U
6de1: 10 ae 62        LDY    $2,S
6de4: 8e 00 04        LDX    #$0004
6de7: 34 70           PSHS   U,Y,X
6de9: 17 d7 41        LBSR   $452D
6dec: 32 66           LEAS   $6,S
6dee: ec 62           LDD    $2,S
6df0: 83 00 01        SUBD   #$0001
6df3: ed 62           STD    $2,S
6df5: 20 c6           BRA    $6DBD
6df7: ee e9 00 0b     LDU    $000B,S
6dfb: 10 be 3d 0d     LDY    $3D0D
6dff: 8e 00 04        LDX    #$0004
6e02: 34 70           PSHS   U,Y,X
6e04: 17 d7 26        LBSR   $452D
6e07: 32 66           LEAS   $6,S
6e09: 32 67           LEAS   $7,S
6e0b: 39              RTS
6e0c: fc 7a 76        LDD    $7A76
6e0f: 17 8f 3e        LBSR   $FD50
6e12: be 3d 0d        LDX    $3D0D
6e15: bc 3d 0f        CMPX   $3D0F
6e18: 10 22 00 52     LBHI   $6E6E
6e1c: fc 3d 0d        LDD    $3D0D
6e1f: ed 62           STD    $2,S
6e21: ae 62           LDX    $2,S
6e23: bc 3d 0f        CMPX   $3D0F
6e26: 10 24 00 31     LBCC   $6E5B
6e2a: ec 62           LDD    $2,S
6e2c: c3 00 01        ADDD   #$0001
6e2f: ed 65           STD    $5,S
6e31: ee 65           LDU    $5,S
6e33: 10 8e 00 02     LDY    #$0002
6e37: 34 60           PSHS   U,Y
6e39: 17 d6 d3        LBSR   $450F
6e3c: 32 64           LEAS   $4,S
6e3e: e7 64           STB    $4,S
6e40: e6 64           LDB    $4,S
6e42: 4f              CLRA
6e43: 1f 03           TFR    D,U
6e45: 10 ae 62        LDY    $2,S
6e48: 8e 00 04        LDX    #$0004
6e4b: 34 70           PSHS   U,Y,X
6e4d: 17 d6 dd        LBSR   $452D
6e50: 32 66           LEAS   $6,S
6e52: ec 62           LDD    $2,S
6e54: c3 00 01        ADDD   #$0001
6e57: ed 62           STD    $2,S
6e59: 20 c6           BRA    $6E21
6e5b: be 3d 0f        LDX    $3D0F
6e5e: 8c 00 00        CMPX   #$0000
6e61: 10 23 00 09     LBLS   $6E6E
6e65: fc 3d 0f        LDD    $3D0F
6e68: 83 00 01        SUBD   #$0001
6e6b: fd 3d 0f        STD    $3D0F
6e6e: 32 67           LEAS   $7,S
6e70: 39              RTS
6e71: fc 7a 78        LDD    $7A78
6e74: 17 8e d9        LBSR   $FD50
6e77: c6 64           LDB    #$64
6e79: e7 63           STB    $3,S
6e7b: ec 9f 3d 37     LDD    [$3D37]
6e7f: c3 00 01        ADDD   #$0001
6e82: ce 24 14        LDU    #$2414
6e85: 1f 02           TFR    D,Y
6e87: 8e 00 04        LDX    #$0004
6e8a: 34 70           PSHS   U,Y,X
6e8c: 17 5a 83        LBSR   $C912
6e8f: 32 66           LEAS   $6,S
6e91: ce 24 14        LDU    #$2414
6e94: c6 04           LDB    #$04
6e96: 1d              SEX
6e97: 1f 02           TFR    D,Y
6e99: 8e 00 04        LDX    #$0004
6e9c: 34 70           PSHS   U,Y,X
6e9e: 17 5e 5e        LBSR   $CCFF
6ea1: 32 66           LEAS   $6,S
6ea3: f6 3d 3d        LDB    $3D3D
6ea6: c1 00           CMPB   #$00
6ea8: 10 27 00 07     LBEQ   $6EB3
6eac: c6 02           LDB    #$02
6eae: e7 63           STB    $3,S
6eb0: 16 00 04        LBRA   $6EB7
6eb3: c6 03           LDB    #$03
6eb5: e7 63           STB    $3,S
6eb7: be 3d 37        LDX    $3D37
6eba: 8c 3d 0d        CMPX   #$3D0D
6ebd: 10 26 00 08     LBNE   $6EC9
6ec1: f6 3d 36        LDB    $3D36
6ec4: e7 62           STB    $2,S
6ec6: 16 00 08        LBRA   $6ED1
6ec9: c6 4c           LDB    #$4C
6ecb: e7 62           STB    $2,S
6ecd: c6 02           LDB    #$02
6ecf: e7 63           STB    $3,S
6ed1: e6 63           LDB    $3,S
6ed3: 4f              CLRA
6ed4: 1f 03           TFR    D,U
6ed6: 10 8e 24 15     LDY    #$2415
6eda: c6 04           LDB    #$04
6edc: 1d              SEX
6edd: 1f 01           TFR    D,X
6edf: e6 62           LDB    $2,S
6ee1: 4f              CLRA
6ee2: 34 76           PSHS   U,Y,X,D
6ee4: ce 00 08        LDU    #$0008
6ee7: 34 40           PSHS   U
6ee9: 17 e7 b8        LBSR   $56A4
6eec: 32 6a           LEAS   $A,S
6eee: 32 64           LEAS   $4,S
6ef0: 39              RTS
6ef1: fc 7a 78        LDD    $7A78
6ef4: 17 8e 59        LBSR   $FD50
6ef7: fc 3d 37        LDD    $3D37
6efa: ed 62           STD    $2,S
6efc: cc 3d 0d        LDD    #$3D0D
6eff: fd 3d 37        STD    $3D37
6f02: ce 00 00        LDU    #$0000
6f05: 34 40           PSHS   U
6f07: 17 ff 67        LBSR   $6E71
6f0a: 32 62           LEAS   $2,S
6f0c: ec 62           LDD    $2,S
6f0e: fd 3d 37        STD    $3D37
6f11: 32 64           LEAS   $4,S
6f13: 39              RTS
6f14: fc 7a 78        LDD    $7A78
6f17: 17 8e 36        LBSR   $FD50
6f1a: fc 3d 37        LDD    $3D37
6f1d: ed 62           STD    $2,S
6f1f: cc 3d 0f        LDD    #$3D0F
6f22: fd 3d 37        STD    $3D37
6f25: ce 00 00        LDU    #$0000
6f28: 34 40           PSHS   U
6f2a: 17 ff 44        LBSR   $6E71
6f2d: 32 62           LEAS   $2,S
6f2f: ec 62           LDD    $2,S
6f31: fd 3d 37        STD    $3D37
6f34: 32 64           LEAS   $4,S
6f36: 39              RTS
6f37: fc 7a 7a        LDD    $7A7A
6f3a: 17 8e 13        LBSR   $FD50
6f3d: ce 24 14        LDU    #$2414
6f40: 10 ae e9 00 08  LDY    $0008,S
6f45: 8e 00 04        LDX    #$0004
6f48: 34 70           PSHS   U,Y,X
6f4a: 17 5c 59        LBSR   $CBA6
6f4d: 32 66           LEAS   $6,S
6f4f: ec e9 00 0a     LDD    $000A,S
6f53: e3 e9 00 06     ADDD   $0006,S
6f57: ed e9 00 0a     STD    $000A,S
6f5b: ae e9 00 08     LDX    $0008,S
6f5f: 8c 00 10        CMPX   #$0010
6f62: 10 26 00 08     LBNE   $6F6E
6f66: c6 20           LDB    #$20
6f68: f7 24 15        STB    $2415
6f6b: 16 00 10        LBRA   $6F7E
6f6e: ae e9 00 08     LDX    $0008,S
6f72: 8c 00 11        CMPX   #$0011
6f75: 10 26 00 05     LBNE   $6F7E
6f79: c6 2e           LDB    #$2E
6f7b: f7 24 15        STB    $2415
6f7e: ce 24 15        LDU    #$2415
6f81: 10 8e 00 02     LDY    #$0002
6f85: 34 60           PSHS   U,Y
6f87: 17 eb 6c        LBSR   $5AF6
6f8a: 32 64           LEAS   $4,S
6f8c: ee e9 00 0c     LDU    $000C,S
6f90: 10 8e 24 15     LDY    #$2415
6f94: c6 01           LDB    #$01
6f96: 1d              SEX
6f97: 1f 01           TFR    D,X
6f99: ec e9 00 0a     LDD    $000A,S
6f9d: 34 76           PSHS   U,Y,X,D
6f9f: ce 00 08        LDU    #$0008
6fa2: 34 40           PSHS   U
6fa4: 17 e6 fd        LBSR   $56A4
6fa7: 32 6a           LEAS   $A,S
6fa9: 32 62           LEAS   $2,S
6fab: 39              RTS
6fac: fc 7a 74        LDD    $7A74
6faf: 17 8d 9e        LBSR   $FD50
6fb2: f6 3c 82        LDB    $3C82
6fb5: c1 00           CMPB   #$00
6fb7: 10 27 00 3e     LBEQ   $6FF9
6fbb: be 3d 0d        LDX    $3D0D
6fbe: bc 3d 0f        CMPX   $3D0F
6fc1: 10 22 00 13     LBHI   $6FD8
6fc5: fe 3d 0d        LDU    $3D0D
6fc8: 10 8e 00 02     LDY    #$0002
6fcc: 34 60           PSHS   U,Y
6fce: 17 d5 3e        LBSR   $450F
6fd1: 32 64           LEAS   $4,S
6fd3: e7 62           STB    $2,S
6fd5: 16 00 04        LBRA   $6FDC
6fd8: c6 11           LDB    #$11
6fda: e7 62           STB    $2,S
6fdc: c6 03           LDB    #$03
6fde: 1d              SEX
6fdf: 1f 03           TFR    D,U
6fe1: 10 ae e9 00 07  LDY    $0007,S
6fe6: e6 62           LDB    $2,S
6fe8: 4f              CLRA
6fe9: 1f 01           TFR    D,X
6feb: 5f              CLRB
6fec: 1d              SEX
6fed: 34 76           PSHS   U,Y,X,D
6fef: ce 00 08        LDU    #$0008
6ff2: 34 40           PSHS   U
6ff4: 17 ff 40        LBSR   $6F37
6ff7: 32 6a           LEAS   $A,S
6ff9: 32 63           LEAS   $3,S
6ffb: 39              RTS
6ffc: fc 7a 7b        LDD    $7A7B
6fff: 17 8d 4e        LBSR   $FD50
7002: fc 3d 39        LDD    $3D39
7005: ed 64           STD    $4,S
7007: 5f              CLRB
7008: 4f              CLRA
7009: ed 66           STD    $6,S
700b: 5f              CLRB
700c: 4f              CLRA
700d: ed 62           STD    $2,S
700f: ae 62           LDX    $2,S
7011: 8c 00 10        CMPX   #$0010
7014: 10 24 00 aa     LBCC   $70C2
7018: f6 3d 3e        LDB    $3D3E
701b: c1 00           CMPB   #$00
701d: 10 27 00 34     LBEQ   $7055
7021: ae 64           LDX    $4,S
7023: bc 3d 0d        CMPX   $3D0D
7026: 10 26 00 2b     LBNE   $7055
702a: c6 02           LDB    #$02
702c: 1d              SEX
702d: 1f 03           TFR    D,U
702f: c6 15           LDB    #$15
7031: 1d              SEX
7032: 1f 02           TFR    D,Y
7034: c6 10           LDB    #$10
7036: 1d              SEX
7037: 1f 01           TFR    D,X
7039: ec 66           LDD    $6,S
703b: 34 76           PSHS   U,Y,X,D
703d: ce 00 08        LDU    #$0008
7040: 34 40           PSHS   U
7042: 17 fe f2        LBSR   $6F37
7045: 32 6a           LEAS   $A,S
7047: ec 66           LDD    $6,S
7049: c3 00 01        ADDD   #$0001
704c: ed 66           STD    $6,S
704e: ec 62           LDD    $2,S
7050: c3 00 01        ADDD   #$0001
7053: ed 62           STD    $2,S
7055: ae 64           LDX    $4,S
7057: bc 3d 0f        CMPX   $3D0F
705a: 10 22 00 12     LBHI   $7070
705e: ee 64           LDU    $4,S
7060: 10 8e 00 02     LDY    #$0002
7064: 34 60           PSHS   U,Y
7066: 17 d4 a6        LBSR   $450F
7069: 32 64           LEAS   $4,S
706b: e7 68           STB    $8,S
706d: 16 00 14        LBRA   $7084
7070: ae 64           LDX    $4,S
7072: 8c 00 fa        CMPX   #$00FA
7075: 10 24 00 07     LBCC   $7080
7079: c6 11           LDB    #$11
707b: e7 68           STB    $8,S
707d: 16 00 04        LBRA   $7084
7080: c6 10           LDB    #$10
7082: e7 68           STB    $8,S
7084: ae 66           LDX    $6,S
7086: 8c 00 10        CMPX   #$0010
7089: 10 24 00 1d     LBCC   $70AA
708d: c6 02           LDB    #$02
708f: 1d              SEX
7090: 1f 03           TFR    D,U
7092: c6 15           LDB    #$15
7094: 1d              SEX
7095: 1f 02           TFR    D,Y
7097: e6 68           LDB    $8,S
7099: 4f              CLRA
709a: 1f 01           TFR    D,X
709c: ec 66           LDD    $6,S
709e: 34 76           PSHS   U,Y,X,D
70a0: ce 00 08        LDU    #$0008
70a3: 34 40           PSHS   U
70a5: 17 fe 8f        LBSR   $6F37
70a8: 32 6a           LEAS   $A,S
70aa: ec 62           LDD    $2,S
70ac: c3 00 01        ADDD   #$0001
70af: ed 62           STD    $2,S
70b1: ec 64           LDD    $4,S
70b3: c3 00 01        ADDD   #$0001
70b6: ed 64           STD    $4,S
70b8: ec 66           LDD    $6,S
70ba: c3 00 01        ADDD   #$0001
70bd: ed 66           STD    $6,S
70bf: 16 ff 4d        LBRA   $700F
70c2: 32 69           LEAS   $9,S
70c4: 39              RTS
70c5: fc 7a 7a        LDD    $7A7A
70c8: 17 8c 85        LBSR   $FD50
70cb: ce 00 00        LDU    #$0000
70ce: 34 40           PSHS   U
70d0: 17 ff 29        LBSR   $6FFC
70d3: 32 62           LEAS   $2,S
70d5: ce 00 00        LDU    #$0000
70d8: 34 40           PSHS   U
70da: 17 fe 14        LBSR   $6EF1
70dd: 32 62           LEAS   $2,S
70df: ce 00 00        LDU    #$0000
70e2: 34 40           PSHS   U
70e4: 17 fe 2d        LBSR   $6F14
70e7: 32 62           LEAS   $2,S
70e9: f6 3d 35        LDB    $3D35
70ec: c1 00           CMPB   #$00
70ee: 10 27 00 20     LBEQ   $7112
70f2: c6 02           LDB    #$02
70f4: 1d              SEX
70f5: 1f 03           TFR    D,U
70f7: 10 8e 41 56     LDY    #$4156
70fb: c6 14           LDB    #$14
70fd: 1d              SEX
70fe: 1f 01           TFR    D,X
7100: c6 54           LDB    #$54
7102: 1d              SEX
7103: 34 76           PSHS   U,Y,X,D
7105: ce 00 08        LDU    #$0008
7108: 34 40           PSHS   U
710a: 17 e5 97        LBSR   $56A4
710d: 32 6a           LEAS   $A,S
710f: 16 00 1d        LBRA   $712F
7112: c6 02           LDB    #$02
7114: 1d              SEX
7115: 1f 03           TFR    D,U
7117: 10 8e 40 de     LDY    #$40DE
711b: c6 14           LDB    #$14
711d: 1d              SEX
711e: 1f 01           TFR    D,X
7120: c6 54           LDB    #$54
7122: 1d              SEX
7123: 34 76           PSHS   U,Y,X,D
7125: ce 00 08        LDU    #$0008
7128: 34 40           PSHS   U
712a: 17 e5 77        LBSR   $56A4
712d: 32 6a           LEAS   $A,S
712f: 32 62           LEAS   $2,S
7131: 39              RTS
7132: fc 7a 78        LDD    $7A78
7135: 17 8c 18        LBSR   $FD50
7138: cc 00 15        LDD    #$0015
713b: f3 3d 3b        ADDD   $3D3B
713e: ed 62           STD    $2,S
7140: 5f              CLRB
7141: 1d              SEX
7142: 1f 03           TFR    D,U
7144: 10 8e 00 00     LDY    #$0000
7148: ae 62           LDX    $2,S
714a: c6 01           LDB    #$01
714c: 1d              SEX
714d: 34 76           PSHS   U,Y,X,D
714f: ce 00 01        LDU    #$0001
7152: 10 8e 00 0a     LDY    #$000A
7156: 34 60           PSHS   U,Y
7158: 17 3a da        LBSR   $AC35
715b: 32 6c           LEAS   $C,S
715d: 32 64           LEAS   $4,S
715f: 39              RTS
7160: fc 7a 74        LDD    $7A74
7163: 17 8b ea        LBSR   $FD50
7166: f6 3d 35        LDB    $3D35
7169: c1 00           CMPB   #$00
716b: 10 27 00 42     LBEQ   $71B1
716f: 7f 3d 35        CLR    $3D35
7172: 7f 3d 3e        CLR    $3D3E
7175: fc 3d 39        LDD    $3D39
7178: fd 3d 0d        STD    $3D0D
717b: ce 00 00        LDU    #$0000
717e: 34 40           PSHS   U
7180: 17 fb e3        LBSR   $6D66
7183: 32 62           LEAS   $2,S
7185: e7 62           STB    $2,S
7187: f6 3c 80        LDB    $3C80
718a: 4f              CLRA
718b: 1f 03           TFR    D,U
718d: e6 62           LDB    $2,S
718f: 4f              CLRA
7190: 1f 02           TFR    D,Y
7192: 8e 00 04        LDX    #$0004
7195: 34 70           PSHS   U,Y,X
7197: 17 f8 fb        LBSR   $6A95
719a: 32 66           LEAS   $6,S
719c: ae e9 00 07     LDX    $0007,S
71a0: 8c 00 00        CMPX   #$0000
71a3: 10 27 00 0a     LBEQ   $71B1
71a7: ce 00 00        LDU    #$0000
71aa: 34 40           PSHS   U
71ac: 17 ff 16        LBSR   $70C5
71af: 32 62           LEAS   $2,S
71b1: 32 63           LEAS   $3,S
71b3: 39              RTS
71b4: fc 7a 7a        LDD    $7A7A
71b7: 17 8b 96        LBSR   $FD50
71ba: c6 01           LDB    #$01
71bc: f7 3d 3d        STB    $3D3D
71bf: cc 00 08        LDD    #$0008
71c2: fd 3d 11        STD    $3D11
71c5: cc 3d 0d        LDD    #$3D0D
71c8: fd 3d 37        STD    $3D37
71cb: ce 00 04        LDU    #$0004
71ce: 10 8e 00 02     LDY    #$0002
71d2: 34 60           PSHS   U,Y
71d4: be 3c 0e        LDX    $3C0E
71d7: ad 84           JSR    ,X
71d9: 32 64           LEAS   $4,S
71db: 32 62           LEAS   $2,S
71dd: 39              RTS
71de: fc 7a 7a        LDD    $7A7A
71e1: 17 8b 6c        LBSR   $FD50
71e4: cc 00 0a        LDD    #$000A
71e7: fd 3d 11        STD    $3D11
71ea: cc 3d 0f        LDD    #$3D0F
71ed: fd 3d 37        STD    $3D37
71f0: ce 00 05        LDU    #$0005
71f3: 10 8e 00 02     LDY    #$0002
71f7: 34 60           PSHS   U,Y
71f9: be 3c 0e        LDX    $3C0E
71fc: ad 84           JSR    ,X
71fe: 32 64           LEAS   $4,S
7200: 32 62           LEAS   $2,S
7202: 39              RTS
7203: fc 7a 78        LDD    $7A78
7206: 17 8b 47        LBSR   $FD50
7209: f6 3d 35        LDB    $3D35
720c: c1 00           CMPB   #$00
720e: 10 27 00 2b     LBEQ   $723D
7212: f6 3d 3e        LDB    $3D3E
7215: c1 00           CMPB   #$00
7217: 10 27 00 06     LBEQ   $7221
721b: 7f 3d 3e        CLR    $3D3E
721e: 16 00 05        LBRA   $7226
7221: c6 01           LDB    #$01
7223: f7 3d 3e        STB    $3D3E
7226: ce 00 00        LDU    #$0000
7229: 34 40           PSHS   U
722b: 17 fd ce        LBSR   $6FFC
722e: 32 62           LEAS   $2,S
7230: ce 00 00        LDU    #$0000
7233: 34 40           PSHS   U
7235: 17 fe fa        LBSR   $7132
7238: 32 62           LEAS   $2,S
723a: 16 00 2a        LBRA   $7267
723d: c6 01           LDB    #$01
723f: f7 3d 35        STB    $3D35
7242: cc 3d 0d        LDD    #$3D0D
7245: fd 3d 37        STD    $3D37
7248: 5f              CLRB
7249: 4f              CLRA
724a: fd 3d 3b        STD    $3D3B
724d: cc 00 09        LDD    #$0009
7250: fd 3d 11        STD    $3D11
7253: ce 00 00        LDU    #$0000
7256: 34 40           PSHS   U
7258: 17 fe 6a        LBSR   $70C5
725b: 32 62           LEAS   $2,S
725d: ce 00 00        LDU    #$0000
7260: 34 40           PSHS   U
7262: 17 fe cd        LBSR   $7132
7265: 32 62           LEAS   $2,S
7267: 32 64           LEAS   $4,S
7269: 39              RTS
726a: fc 7a 78        LDD    $7A78
726d: 17 8a e0        LBSR   $FD50
7270: be 3d 11        LDX    $3D11
7273: 8c 00 09        CMPX   #$0009
7276: 10 26 00 30     LBNE   $72AA
727a: f6 3d 3e        LDB    $3D3E
727d: c1 00           CMPB   #$00
727f: 10 27 00 06     LBEQ   $7289
7283: 7f 3d 3e        CLR    $3D3E
7286: 16 00 0a        LBRA   $7293
7289: ce 00 00        LDU    #$0000
728c: 34 40           PSHS   U
728e: 17 fb 7b        LBSR   $6E0C
7291: 32 62           LEAS   $2,S
7293: ce 00 00        LDU    #$0000
7296: 34 40           PSHS   U
7298: 17 fe 2a        LBSR   $70C5
729b: 32 62           LEAS   $2,S
729d: ce 00 00        LDU    #$0000
72a0: 34 40           PSHS   U
72a2: 17 fe 8d        LBSR   $7132
72a5: 32 62           LEAS   $2,S
72a7: 16 00 05        LBRA   $72AF
72aa: 5f              CLRB
72ab: 4f              CLRA
72ac: fd 3d 11        STD    $3D11
72af: 32 64           LEAS   $4,S
72b1: 39              RTS
72b2: fc 7a 7d        LDD    $7A7D
72b5: 17 8a 98        LBSR   $FD50
72b8: be 3d 11        LDX    $3D11
72bb: 16 00 86        LBRA   $7344
72be: ec 9f 3d 37     LDD    [$3D37]
72c2: c3 00 01        ADDD   #$0001
72c5: ce 22 85        LDU    #$2285
72c8: 1f 02           TFR    D,Y
72ca: 8e 00 04        LDX    #$0004
72cd: 34 70           PSHS   U,Y,X
72cf: 17 56 40        LBSR   $C912
72d2: 32 66           LEAS   $6,S
72d4: c6 05           LDB    #$05
72d6: e7 62           STB    $2,S
72d8: 16 00 7f        LBRA   $735A
72db: f6 3d 0e        LDB    $3D0E
72de: e7 63           STB    $3,S
72e0: 6f 62           CLR    $2,S
72e2: e6 63           LDB    $3,S
72e4: 4f              CLRA
72e5: 10 b3 3d 0f     CMPD   $3D0F
72e9: 10 22 00 54     LBHI   $7341
72ed: e6 63           LDB    $3,S
72ef: 4f              CLRA
72f0: 1f 03           TFR    D,U
72f2: 10 8e 00 02     LDY    #$0002
72f6: 34 60           PSHS   U,Y
72f8: 17 d2 14        LBSR   $450F
72fb: 32 64           LEAS   $4,S
72fd: e7 64           STB    $4,S
72ff: e6 64           LDB    $4,S
7301: c1 09           CMPB   #$09
7303: 10 23 00 0f     LBLS   $7316
7307: a6 64           LDA    $4,S
7309: c6 0a           LDB    #$0A
730b: 17 8a 81        LBSR   $FD8F
730e: c3 00 41        ADDD   #$0041
7311: e7 64           STB    $4,S
7313: 16 00 06        LBRA   $731C
7316: e6 64           LDB    $4,S
7318: cb 30           ADDB   #$30
731a: e7 64           STB    $4,S
731c: 33 64           LEAU   $4,S
731e: 10 8e 00 02     LDY    #$0002
7322: 34 60           PSHS   U,Y
7324: 17 e7 cf        LBSR   $5AF6
7327: 32 64           LEAS   $4,S
7329: 8e 22 85        LDX    #$2285
732c: e6 62           LDB    $2,S
732e: 3a              ABX
732f: e6 64           LDB    $4,S
7331: e7 84           STB    ,X
7333: e6 63           LDB    $3,S
7335: cb 01           ADDB   #$01
7337: e7 63           STB    $3,S
7339: e6 62           LDB    $2,S
733b: cb 01           ADDB   #$01
733d: e7 62           STB    $2,S
733f: 20 a1           BRA    $72E2
7341: 16 00 16        LBRA   $735A
7344: 8c 00 08        CMPX   #$0008
7347: 10 27 ff 73     LBEQ   $72BE
734b: 8c 00 09        CMPX   #$0009
734e: 27 8b           BEQ    $72DB
7350: 8c 00 0a        CMPX   #$000A
7353: 10 27 ff 67     LBEQ   $72BE
7357: 16 00 00        LBRA   $735A
735a: e6 62           LDB    $2,S
735c: 4f              CLRA
735d: 1f 03           TFR    D,U
735f: 10 8e 22 85     LDY    #$2285
7363: 8e 00 04        LDX    #$0004
7366: 34 70           PSHS   U,Y,X
7368: 17 2c 93        LBSR   $9FFE
736b: 32 66           LEAS   $6,S
736d: 32 65           LEAS   $5,S
736f: 39              RTS
7370: fc 7a 7a        LDD    $7A7A
7373: 17 89 da        LBSR   $FD50
7376: fc 3d 0d        LDD    $3D0D
7379: fd 3d 0f        STD    $3D0F
737c: ae e9 00 06     LDX    $0006,S
7380: 8c 00 00        CMPX   #$0000
7383: 10 26 00 58     LBNE   $73DF
7387: ce 00 00        LDU    #$0000
738a: 34 40           PSHS   U
738c: 17 fd 36        LBSR   $70C5
738f: 32 62           LEAS   $2,S
7391: be 3d 11        LDX    $3D11
7394: 8c 00 08        CMPX   #$0008
7397: 10 26 00 13     LBNE   $73AE
739b: ce 00 04        LDU    #$0004
739e: 10 8e 00 02     LDY    #$0002
73a2: 34 60           PSHS   U,Y
73a4: be 3c 0e        LDX    $3C0E
73a7: ad 84           JSR    ,X
73a9: 32 64           LEAS   $4,S
73ab: 16 00 31        LBRA   $73DF
73ae: be 3d 11        LDX    $3D11
73b1: 8c 00 0a        CMPX   #$000A
73b4: 10 26 00 13     LBNE   $73CB
73b8: ce 00 05        LDU    #$0005
73bb: 10 8e 00 02     LDY    #$0002
73bf: 34 60           PSHS   U,Y
73c1: be 3c 0e        LDX    $3C0E
73c4: ad 84           JSR    ,X
73c6: 32 64           LEAS   $4,S
73c8: 16 00 14        LBRA   $73DF
73cb: be 3d 11        LDX    $3D11
73ce: 8c 00 09        CMPX   #$0009
73d1: 10 26 00 0a     LBNE   $73DF
73d5: ce 00 00        LDU    #$0000
73d8: 34 40           PSHS   U
73da: 17 fd 55        LBSR   $7132
73dd: 32 62           LEAS   $2,S
73df: 32 62           LEAS   $2,S
73e1: 39              RTS
73e2: fc 7a 7a        LDD    $7A7A
73e5: 17 89 68        LBSR   $FD50
73e8: fc 3d 0f        LDD    $3D0F
73eb: c3 00 01        ADDD   #$0001
73ee: 10 b3 3d 0d     CMPD   $3D0D
73f2: 10 24 00 52     LBCC   $7448
73f6: be 3d 37        LDX    $3D37
73f9: 8c 3d 0d        CMPX   #$3D0D
73fc: 10 26 00 0f     LBNE   $740F
7400: c6 37           LDB    #$37
7402: f7 3c 02        STB    $3C02
7405: ec e9 00 06     LDD    $0006,S
7409: fd 3d 0d        STD    $3D0D
740c: 16 00 39        LBRA   $7448
740f: fc 3d 0f        LDD    $3D0F
7412: c3 00 01        ADDD   #$0001
7415: fd 3d 0d        STD    $3D0D
7418: fc 3d 0d        LDD    $3D0D
741b: fd 3d 39        STD    $3D39
741e: f6 3d 3d        LDB    $3D3D
7421: c1 00           CMPB   #$00
7423: 10 27 00 17     LBEQ   $743E
7427: ce 00 00        LDU    #$0000
742a: 34 40           PSHS   U
742c: 17 fa c2        LBSR   $6EF1
742f: 32 62           LEAS   $2,S
7431: ce 00 00        LDU    #$0000
7434: 34 40           PSHS   U
7436: 17 fb c3        LBSR   $6FFC
7439: 32 62           LEAS   $2,S
743b: 16 00 0a        LBRA   $7448
743e: ce 00 00        LDU    #$0000
7441: 34 40           PSHS   U
7443: 17 e7 d5        LBSR   $5C1B
7446: 32 62           LEAS   $2,S
7448: 32 62           LEAS   $2,S
744a: 39              RTS
744b: fc 7a 7b        LDD    $7A7B
744e: 17 88 ff        LBSR   $FD50
7451: cc 00 01        LDD    #$0001
7454: ed 62           STD    $2,S
7456: c6 01           LDB    #$01
7458: e7 66           STB    $6,S
745a: be 3d 11        LDX    $3D11
745d: 16 01 ae        LBRA   $760E
7460: ae e9 00 0d     LDX    $000D,S
7464: 8c 00 00        CMPX   #$0000
7467: 10 27 00 27     LBEQ   $7492
746b: be 3d 0d        LDX    $3D0D
746e: 8c 00 f9        CMPX   #$00F9
7471: 10 24 00 1a     LBCC   $748F
7475: be 3d 0d        LDX    $3D0D
7478: bc 3d 0f        CMPX   $3D0F
747b: 10 22 00 0c     LBHI   $748B
747f: fc 3d 0d        LDD    $3D0D
7482: c3 00 01        ADDD   #$0001
7485: fd 3d 0d        STD    $3D0D
7488: 16 00 04        LBRA   $748F
748b: 5f              CLRB
748c: 4f              CLRA
748d: ed 62           STD    $2,S
748f: 16 00 1a        LBRA   $74AC
7492: be 3d 0d        LDX    $3D0D
7495: 8c 00 00        CMPX   #$0000
7498: 10 23 00 0c     LBLS   $74A8
749c: fc 3d 0d        LDD    $3D0D
749f: 83 00 01        SUBD   #$0001
74a2: fd 3d 0d        STD    $3D0D
74a5: 16 00 04        LBRA   $74AC
74a8: 5f              CLRB
74a9: 4f              CLRA
74aa: ed 62           STD    $2,S
74ac: ae 62           LDX    $2,S
74ae: 8c 00 00        CMPX   #$0000
74b1: 10 27 00 57     LBEQ   $750C
74b5: fc 3d 39        LDD    $3D39
74b8: ed 64           STD    $4,S
74ba: be 3d 0d        LDX    $3D0D
74bd: bc 3d 39        CMPX   $3D39
74c0: 10 24 00 09     LBCC   $74CD
74c4: fc 3d 0d        LDD    $3D0D
74c7: fd 3d 39        STD    $3D39
74ca: 16 00 17        LBRA   $74E4
74cd: fc 3d 39        LDD    $3D39
74d0: c3 00 0f        ADDD   #$000F
74d3: 10 b3 3d 0d     CMPD   $3D0D
74d7: 10 24 00 09     LBCC   $74E4
74db: fc 3d 0d        LDD    $3D0D
74de: 83 00 0f        SUBD   #$000F
74e1: fd 3d 39        STD    $3D39
74e4: fc 3d 0d        LDD    $3D0D
74e7: b3 3d 39        SUBD   $3D39
74ea: fd 3d 3b        STD    $3D3B
74ed: ae 64           LDX    $4,S
74ef: bc 3d 39        CMPX   $3D39
74f2: 10 26 00 0c     LBNE   $7502
74f6: f6 3d 3e        LDB    $3D3E
74f9: c1 00           CMPB   #$00
74fb: 10 26 00 03     LBNE   $7502
74ff: 16 00 00        LBRA   $7502
7502: ce 00 00        LDU    #$0000
7505: 34 40           PSHS   U
7507: 17 fa f2        LBSR   $6FFC
750a: 32 62           LEAS   $2,S
750c: ce 00 00        LDU    #$0000
750f: 34 40           PSHS   U
7511: 17 f9 dd        LBSR   $6EF1
7514: 32 62           LEAS   $2,S
7516: c6 0e           LDB    #$0E
7518: 1d              SEX
7519: 1f 03           TFR    D,U
751b: 10 8e 00 02     LDY    #$0002
751f: 34 60           PSHS   U,Y
7521: 17 fa 88        LBSR   $6FAC
7524: 32 64           LEAS   $4,S
7526: ce 00 00        LDU    #$0000
7529: 34 40           PSHS   U
752b: 17 fc 04        LBSR   $7132
752e: 32 62           LEAS   $2,S
7530: 16 00 f3        LBRA   $7626
7533: ec 9f 3d 37     LDD    [$3D37]
7537: ed 67           STD    $7,S
7539: ae e9 00 0d     LDX    $000D,S
753d: 8c 00 00        CMPX   #$0000
7540: 10 27 00 1e     LBEQ   $7562
7544: ae 9f 3d 37     LDX    [$3D37]
7548: 8c 00 f9        CMPX   #$00F9
754b: 10 24 00 0e     LBCC   $755D
754f: ec 9f 3d 37     LDD    [$3D37]
7553: c3 00 01        ADDD   #$0001
7556: ed 9f 3d 37     STD    [$3D37]
755a: 16 00 02        LBRA   $755F
755d: 6f 66           CLR    $6,S
755f: 16 00 1b        LBRA   $757D
7562: ae 9f 3d 37     LDX    [$3D37]
7566: 8c 00 00        CMPX   #$0000
7569: 10 23 00 0e     LBLS   $757B
756d: ec 9f 3d 37     LDD    [$3D37]
7571: 83 00 01        SUBD   #$0001
7574: ed 9f 3d 37     STD    [$3D37]
7578: 16 00 02        LBRA   $757D
757b: 6f 66           CLR    $6,S
757d: e6 66           LDB    $6,S
757f: c1 00           CMPB   #$00
7581: 10 27 00 3d     LBEQ   $75C2
7585: ee 67           LDU    $7,S
7587: 10 8e 00 02     LDY    #$0002
758b: 34 60           PSHS   U,Y
758d: 17 fe 52        LBSR   $73E2
7590: 32 64           LEAS   $4,S
7592: 7f 3c 02        CLR    $3C02
7595: ce 00 00        LDU    #$0000
7598: 34 40           PSHS   U
759a: 17 f8 d4        LBSR   $6E71
759d: 32 62           LEAS   $2,S
759f: be 3d 37        LDX    $3D37
75a2: 8c 3d 0d        CMPX   #$3D0D
75a5: 10 26 00 06     LBNE   $75AF
75a9: fc 3d 0d        LDD    $3D0D
75ac: fd 3d 39        STD    $3D39
75af: f6 3d 3d        LDB    $3D3D
75b2: c1 00           CMPB   #$00
75b4: 10 27 00 0a     LBEQ   $75C2
75b8: ce 00 00        LDU    #$0000
75bb: 34 40           PSHS   U
75bd: 17 fa 3c        LBSR   $6FFC
75c0: 32 62           LEAS   $2,S
75c2: f6 3d 3d        LDB    $3D3D
75c5: c1 00           CMPB   #$00
75c7: 10 27 00 2d     LBEQ   $75F8
75cb: be 3d 37        LDX    $3D37
75ce: 8c 3d 0d        CMPX   #$3D0D
75d1: 10 26 00 13     LBNE   $75E8
75d5: ce 00 04        LDU    #$0004
75d8: 10 8e 00 02     LDY    #$0002
75dc: 34 60           PSHS   U,Y
75de: be 3c 0e        LDX    $3C0E
75e1: ad 84           JSR    ,X
75e3: 32 64           LEAS   $4,S
75e5: 16 00 10        LBRA   $75F8
75e8: ce 00 05        LDU    #$0005
75eb: 10 8e 00 02     LDY    #$0002
75ef: 34 60           PSHS   U,Y
75f1: be 3c 0e        LDX    $3C0E
75f4: ad 84           JSR    ,X
75f6: 32 64           LEAS   $4,S
75f8: c6 0e           LDB    #$0E
75fa: 1d              SEX
75fb: 1f 03           TFR    D,U
75fd: 10 8e 00 02     LDY    #$0002
7601: 34 60           PSHS   U,Y
7603: 17 f9 a6        LBSR   $6FAC
7606: 32 64           LEAS   $4,S
7608: 16 00 1b        LBRA   $7626
760b: 16 00 18        LBRA   $7626
760e: 8c 00 08        CMPX   #$0008
7611: 10 27 ff 1e     LBEQ   $7533
7615: 8c 00 09        CMPX   #$0009
7618: 10 27 fe 44     LBEQ   $7460
761c: 8c 00 0a        CMPX   #$000A
761f: 10 27 ff 10     LBEQ   $7533
7623: 16 00 00        LBRA   $7626
7626: 32 69           LEAS   $9,S
7628: 39              RTS
7629: fc 7a 7a        LDD    $7A7A
762c: 17 87 21        LBSR   $FD50
762f: be 3d 37        LDX    $3D37
7632: 8c 3d 0d        CMPX   #$3D0D
7635: 10 26 00 08     LBNE   $7641
7639: c6 37           LDB    #$37
763b: f7 3c 02        STB    $3C02
763e: 16 00 05        LBRA   $7646
7641: c6 38           LDB    #$38
7643: f7 3c 02        STB    $3C02
7646: 32 62           LEAS   $2,S
7648: 39              RTS
7649: fc 7a 7f        LDD    $7A7F
764c: 17 87 01        LBSR   $FD50
764f: 6f 63           CLR    $3,S
7651: be 3d 11        LDX    $3D11
7654: 16 01 cd        LBRA   $7824
7657: f6 23 9a        LDB    $239A
765a: f7 24 15        STB    $2415
765d: c6 30           LDB    #$30
765f: f7 24 14        STB    $2414
7662: ce 24 14        LDU    #$2414
7665: 10 8e 00 02     LDY    #$0002
7669: 34 60           PSHS   U,Y
766b: 17 55 e5        LBSR   $CC53
766e: 32 64           LEAS   $4,S
7670: e7 62           STB    $2,S
7672: fc 3d 0f        LDD    $3D0F
7675: c3 00 01        ADDD   #$0001
7678: 10 b3 3d 0d     CMPD   $3D0D
767c: 10 26 00 2a     LBNE   $76AA
7680: be 3d 0f        LDX    $3D0F
7683: 8c 00 f9        CMPX   #$00F9
7686: 10 24 00 20     LBCC   $76AA
768a: f6 3d 3e        LDB    $3D3E
768d: c1 00           CMPB   #$00
768f: 10 27 00 04     LBEQ   $7697
7693: c6 01           LDB    #$01
7695: e7 63           STB    $3,S
7697: fc 3d 0f        LDD    $3D0F
769a: c3 00 01        ADDD   #$0001
769d: fd 3d 0f        STD    $3D0F
76a0: ce 00 00        LDU    #$0000
76a3: 34 40           PSHS   U
76a5: 17 f8 6c        LBSR   $6F14
76a8: 32 62           LEAS   $2,S
76aa: be 3d 0d        LDX    $3D0D
76ad: bc 3d 0f        CMPX   $3D0F
76b0: 10 22 00 82     LBHI   $7736
76b4: f6 3d 3e        LDB    $3D3E
76b7: c1 00           CMPB   #$00
76b9: 10 27 00 38     LBEQ   $76F5
76bd: e6 63           LDB    $3,S
76bf: c1 00           CMPB   #$00
76c1: 10 27 00 13     LBEQ   $76D8
76c5: be 3d 0f        LDX    $3D0F
76c8: 8c 00 00        CMPX   #$0000
76cb: 10 23 00 09     LBLS   $76D8
76cf: fc 3d 0f        LDD    $3D0F
76d2: 83 00 01        SUBD   #$0001
76d5: fd 3d 0f        STD    $3D0F
76d8: e6 62           LDB    $2,S
76da: 4f              CLRA
76db: 1f 03           TFR    D,U
76dd: 10 8e 00 02     LDY    #$0002
76e1: 34 60           PSHS   U,Y
76e3: 17 f6 af        LBSR   $6D95
76e6: 32 64           LEAS   $4,S
76e8: ce 00 00        LDU    #$0000
76eb: 34 40           PSHS   U
76ed: 17 f9 d5        LBSR   $70C5
76f0: 32 62           LEAS   $2,S
76f2: 16 00 31        LBRA   $7726
76f5: e6 62           LDB    $2,S
76f7: 4f              CLRA
76f8: 1f 03           TFR    D,U
76fa: 10 be 3d 0d     LDY    $3D0D
76fe: 8e 00 04        LDX    #$0004
7701: 34 70           PSHS   U,Y,X
7703: 17 ce 27        LBSR   $452D
7706: 32 66           LEAS   $6,S
7708: c6 02           LDB    #$02
770a: 1d              SEX
770b: 1f 03           TFR    D,U
770d: c6 15           LDB    #$15
770f: 1d              SEX
7710: 1f 02           TFR    D,Y
7712: e6 62           LDB    $2,S
7714: 4f              CLRA
7715: 1f 01           TFR    D,X
7717: fc 3d 3b        LDD    $3D3B
771a: 34 76           PSHS   U,Y,X,D
771c: ce 00 08        LDU    #$0008
771f: 34 40           PSHS   U
7721: 17 f8 13        LBSR   $6F37
7724: 32 6a           LEAS   $A,S
7726: c6 01           LDB    #$01
7728: 1d              SEX
7729: 1f 03           TFR    D,U
772b: 10 8e 00 02     LDY    #$0002
772f: 34 60           PSHS   U,Y
7731: 17 fd 17        LBSR   $744B
7734: 32 64           LEAS   $4,S
7736: c6 0e           LDB    #$0E
7738: 1d              SEX
7739: 1f 03           TFR    D,U
773b: 10 8e 00 02     LDY    #$0002
773f: 34 60           PSHS   U,Y
7741: 17 f8 68        LBSR   $6FAC
7744: 32 64           LEAS   $4,S
7746: 16 00 f3        LBRA   $783C
7749: ec 9f 3d 37     LDD    [$3D37]
774d: ed 64           STD    $4,S
774f: c6 06           LDB    #$06
7751: 1d              SEX
7752: 1f 03           TFR    D,U
7754: 10 8e 00 08     LDY    #$0008
7758: 8e 00 04        LDX    #$0004
775b: 34 70           PSHS   U,Y,X
775d: 17 56 81        LBSR   $CDE1
7760: 32 66           LEAS   $6,S
7762: c1 05           CMPB   #$05
7764: 10 24 00 35     LBCC   $779D
7768: ce 24 14        LDU    #$2414
776b: 10 8e 00 02     LDY    #$0002
776f: 34 60           PSHS   U,Y
7771: 17 51 ff        LBSR   $C973
7774: 32 64           LEAS   $4,S
7776: 83 00 01        SUBD   #$0001
7779: fd 22 1a        STD    $221A
777c: be 22 1a        LDX    $221A
777f: 8c 00 fa        CMPX   #$00FA
7782: 10 24 00 0a     LBCC   $7790
7786: fc 22 1a        LDD    $221A
7789: ed 9f 3d 37     STD    [$3D37]
778d: 16 00 0a        LBRA   $779A
7790: ce 00 00        LDU    #$0000
7793: 34 40           PSHS   U
7795: 17 fe 91        LBSR   $7629
7798: 32 62           LEAS   $2,S
779a: 16 00 0a        LBRA   $77A7
779d: ce 00 00        LDU    #$0000
77a0: 34 40           PSHS   U
77a2: 17 fe 84        LBSR   $7629
77a5: 32 62           LEAS   $2,S
77a7: ee 64           LDU    $4,S
77a9: 10 8e 00 02     LDY    #$0002
77ad: 34 60           PSHS   U,Y
77af: 17 fc 30        LBSR   $73E2
77b2: 32 64           LEAS   $4,S
77b4: ce 00 00        LDU    #$0000
77b7: 34 40           PSHS   U
77b9: 17 f6 b5        LBSR   $6E71
77bc: 32 62           LEAS   $2,S
77be: be 3d 37        LDX    $3D37
77c1: 8c 3d 0d        CMPX   #$3D0D
77c4: 10 26 00 06     LBNE   $77CE
77c8: fc 3d 0d        LDD    $3D0D
77cb: fd 3d 39        STD    $3D39
77ce: f6 3d 3d        LDB    $3D3D
77d1: c1 00           CMPB   #$00
77d3: 10 27 00 37     LBEQ   $780E
77d7: ce 00 00        LDU    #$0000
77da: 34 40           PSHS   U
77dc: 17 f8 1d        LBSR   $6FFC
77df: 32 62           LEAS   $2,S
77e1: be 3d 37        LDX    $3D37
77e4: 8c 3d 0d        CMPX   #$3D0D
77e7: 10 26 00 13     LBNE   $77FE
77eb: ce 00 04        LDU    #$0004
77ee: 10 8e 00 02     LDY    #$0002
77f2: 34 60           PSHS   U,Y
77f4: be 3c 0e        LDX    $3C0E
77f7: ad 84           JSR    ,X
77f9: 32 64           LEAS   $4,S
77fb: 16 00 10        LBRA   $780E
77fe: ce 00 05        LDU    #$0005
7801: 10 8e 00 02     LDY    #$0002
7805: 34 60           PSHS   U,Y
7807: be 3c 0e        LDX    $3C0E
780a: ad 84           JSR    ,X
780c: 32 64           LEAS   $4,S
780e: c6 0e           LDB    #$0E
7810: 1d              SEX
7811: 1f 03           TFR    D,U
7813: 10 8e 00 02     LDY    #$0002
7817: 34 60           PSHS   U,Y
7819: 17 f7 90        LBSR   $6FAC
781c: 32 64           LEAS   $4,S
781e: 16 00 1b        LBRA   $783C
7821: 16 00 18        LBRA   $783C
7824: 8c 00 08        CMPX   #$0008
7827: 10 27 ff 1e     LBEQ   $7749
782b: 8c 00 09        CMPX   #$0009
782e: 10 27 fe 25     LBEQ   $7657
7832: 8c 00 0a        CMPX   #$000A
7835: 10 27 ff 10     LBEQ   $7749
7839: 16 00 00        LBRA   $783C
783c: 32 66           LEAS   $6,S
783e: 39              RTS
783f: fc 7a 7a        LDD    $7A7A
7842: 17 85 0b        LBSR   $FD50
7845: c6 01           LDB    #$01
7847: f7 3d 3d        STB    $3D3D
784a: ae e9 00 06     LDX    $0006,S
784e: 8c 00 00        CMPX   #$0000
7851: 10 26 00 08     LBNE   $785D
7855: c6 0e           LDB    #$0E
7857: f7 3d 36        STB    $3D36
785a: 16 00 10        LBRA   $786D
785d: e6 e9 00 07     LDB    $0007,S
7861: f7 3d 36        STB    $3D36
7864: cc 3d 0d        LDD    #$3D0D
7867: fd 3d 37        STD    $3D37
786a: 7f 3d 3d        CLR    $3D3D
786d: 32 62           LEAS   $2,S
786f: 39              RTS
7870: fc 7a 76        LDD    $7A76
7873: 17 84 da        LBSR   $FD50
7876: 6f 62           CLR    $2,S
7878: ec e9 00 0b     LDD    $000B,S
787c: 84 00           ANDA   #$00
787e: c4 7f           ANDB   #$7F
7880: ed e9 00 0b     STD    $000B,S
7884: e6 e9 00 0c     LDB    $000C,S
7888: e7 63           STB    $3,S
788a: 33 63           LEAU   $3,S
788c: 10 8e 00 02     LDY    #$0002
7890: 34 60           PSHS   U,Y
7892: 17 e2 96        LBSR   $5B2B
7895: 32 64           LEAS   $4,S
7897: e6 63           LDB    $3,S
7899: c1 20           CMPB   #$20
789b: 10 26 00 07     LBNE   $78A6
789f: c6 01           LDB    #$01
78a1: e7 62           STB    $2,S
78a3: 16 01 16        LBRA   $79BC
78a6: e6 63           LDB    $3,S
78a8: c1 30           CMPB   #$30
78aa: 10 25 00 0b     LBCS   $78B9
78ae: e6 63           LDB    $3,S
78b0: c1 39           CMPB   #$39
78b2: 10 22 00 03     LBHI   $78B9
78b6: 16 00 16        LBRA   $78CF
78b9: e6 63           LDB    $3,S
78bb: c1 41           CMPB   #$41
78bd: 10 25 00 0b     LBCS   $78CC
78c1: e6 63           LDB    $3,S
78c3: c1 46           CMPB   #$46
78c5: 10 22 00 03     LBHI   $78CC
78c9: 16 00 03        LBRA   $78CF
78cc: 16 00 ed        LBRA   $79BC
78cf: c6 30           LDB    #$30
78d1: f7 24 14        STB    $2414
78d4: e6 63           LDB    $3,S
78d6: f7 24 15        STB    $2415
78d9: ce 24 14        LDU    #$2414
78dc: 10 8e 00 02     LDY    #$0002
78e0: 34 60           PSHS   U,Y
78e2: 17 53 6e        LBSR   $CC53
78e5: 32 64           LEAS   $4,S
78e7: f7 22 19        STB    $2219
78ea: f6 22 19        LDB    $2219
78ed: 4f              CLRA
78ee: 1f 03           TFR    D,U
78f0: 10 be 3d 3f     LDY    $3D3F
78f4: 8e 00 04        LDX    #$0004
78f7: 34 70           PSHS   U,Y,X
78f9: 17 cc 31        LBSR   $452D
78fc: 32 66           LEAS   $6,S
78fe: f6 3c 8f        LDB    $3C8F
7901: c1 02           CMPB   #$02
7903: 10 26 00 4b     LBNE   $7952
7907: be 3d 3f        LDX    $3D3F
790a: bc 3d 39        CMPX   $3D39
790d: 10 25 00 3e     LBCS   $794F
7911: be 3d 3f        LDX    $3D3F
7914: bc 3d 0f        CMPX   $3D0F
7917: 10 22 00 34     LBHI   $794F
791b: fc 3d 39        LDD    $3D39
791e: c3 00 0f        ADDD   #$000F
7921: 10 b3 3d 3f     CMPD   $3D3F
7925: 10 25 00 26     LBCS   $794F
7929: fc 3d 3f        LDD    $3D3F
792c: b3 3d 39        SUBD   $3D39
792f: ed 64           STD    $4,S
7931: c6 02           LDB    #$02
7933: 1d              SEX
7934: 1f 03           TFR    D,U
7936: c6 15           LDB    #$15
7938: 1d              SEX
7939: 1f 02           TFR    D,Y
793b: f6 22 19        LDB    $2219
793e: 4f              CLRA
793f: 1f 01           TFR    D,X
7941: ec 64           LDD    $4,S
7943: 34 76           PSHS   U,Y,X,D
7945: ce 00 08        LDU    #$0008
7948: 34 40           PSHS   U
794a: 17 f5 ea        LBSR   $6F37
794d: 32 6a           LEAS   $A,S
794f: 16 00 4d        LBRA   $799F
7952: f6 3c 8f        LDB    $3C8F
7955: c1 03           CMPB   #$03
7957: 10 26 00 44     LBNE   $799F
795b: be 3d 3f        LDX    $3D3F
795e: bc 3d 0d        CMPX   $3D0D
7961: 10 26 00 3a     LBNE   $799F
7965: f6 3c 82        LDB    $3C82
7968: c1 00           CMPB   #$00
796a: 10 27 00 31     LBEQ   $799F
796e: c6 0e           LDB    #$0E
7970: 1d              SEX
7971: 1f 03           TFR    D,U
7973: 10 8e 00 02     LDY    #$0002
7977: 34 60           PSHS   U,Y
7979: 17 f6 30        LBSR   $6FAC
797c: 32 64           LEAS   $4,S
797e: ce 00 00        LDU    #$0000
7981: 34 40           PSHS   U
7983: 17 f3 e0        LBSR   $6D66
7986: 32 62           LEAS   $2,S
7988: e7 66           STB    $6,S
798a: f6 3c 80        LDB    $3C80
798d: 4f              CLRA
798e: 1f 03           TFR    D,U
7990: e6 66           LDB    $6,S
7992: 4f              CLRA
7993: 1f 02           TFR    D,Y
7995: 8e 00 04        LDX    #$0004
7998: 34 70           PSHS   U,Y,X
799a: 17 f0 f8        LBSR   $6A95
799d: 32 66           LEAS   $6,S
799f: fc 3d 3f        LDD    $3D3F
79a2: c3 00 01        ADDD   #$0001
79a5: fd 3d 3f        STD    $3D3F
79a8: be 3d 3f        LDX    $3D3F
79ab: 8c 00 f9        CMPX   #$00F9
79ae: 10 23 00 06     LBLS   $79B8
79b2: cc 00 f9        LDD    #$00F9
79b5: fd 3d 3f        STD    $3D3F
79b8: c6 01           LDB    #$01
79ba: e7 62           STB    $2,S
79bc: e6 62           LDB    $2,S
79be: e7 66           STB    $6,S
79c0: 32 67           LEAS   $7,S
79c2: 39              RTS
79c3: fc 7a 7a        LDD    $7A7A
79c6: 17 83 87        LBSR   $FD50
79c9: f6 3d 3e        LDB    $3D3E
79cc: c1 00           CMPB   #$00
79ce: 10 27 00 0d     LBEQ   $79DF
79d2: 7f 3d 3e        CLR    $3D3E
79d5: ce 00 00        LDU    #$0000
79d8: 34 40           PSHS   U
79da: 17 f6 1f        LBSR   $6FFC
79dd: 32 62           LEAS   $2,S
79df: cc 00 09        LDD    #$0009
79e2: fd 3d 11        STD    $3D11
79e5: cc 78 70        LDD    #$7870
79e8: 1f 03           TFR    D,U
79ea: 10 8e 00 02     LDY    #$0002
79ee: 34 60           PSHS   U,Y
79f0: 17 29 f0        LBSR   $A3E3
79f3: 32 64           LEAS   $4,S
79f5: fc 3d 0d        LDD    $3D0D
79f8: fd 3d 3f        STD    $3D3F
79fb: 32 62           LEAS   $2,S
79fd: 39              RTS
79fe: fc 7a 7a        LDD    $7A7A
7a01: 17 83 4c        LBSR   $FD50
7a04: 7f 3d 35        CLR    $3D35
7a07: 7f 3d 3e        CLR    $3D3E
7a0a: ae e9 00 06     LDX    $0006,S
7a0e: 8c 00 00        CMPX   #$0000
7a11: 10 26 00 3c     LBNE   $7A51
7a15: 5f              CLRB
7a16: 4f              CLRA
7a17: fd 3d 0d        STD    $3D0D
7a1a: be 3d 0d        LDX    $3D0D
7a1d: 8c 00 fa        CMPX   #$00FA
7a20: 10 24 00 22     LBCC   $7A46
7a24: fc 3d 0d        LDD    $3D0D
7a27: 84 00           ANDA   #$00
7a29: c4 0f           ANDB   #$0F
7a2b: 1f 03           TFR    D,U
7a2d: 10 be 3d 0d     LDY    $3D0D
7a31: 8e 00 04        LDX    #$0004
7a34: 34 70           PSHS   U,Y,X
7a36: 17 ca f4        LBSR   $452D
7a39: 32 66           LEAS   $6,S
7a3b: fc 3d 0d        LDD    $3D0D
7a3e: c3 00 01        ADDD   #$0001
7a41: fd 3d 0d        STD    $3D0D
7a44: 20 d4           BRA    $7A1A
7a46: 5f              CLRB
7a47: 4f              CLRA
7a48: fd 3d 0d        STD    $3D0D
7a4b: cc 00 f9        LDD    #$00F9
7a4e: fd 3d 0f        STD    $3D0F
7a51: cc 3d 0d        LDD    #$3D0D
7a54: fd 3d 37        STD    $3D37
7a57: fc 3d 0d        LDD    $3D0D
7a5a: fd 3d 39        STD    $3D39
7a5d: 5f              CLRB
7a5e: 4f              CLRA
7a5f: fd 3d 3b        STD    $3D3B
7a62: 5f              CLRB
7a63: 1d              SEX
7a64: 1f 03           TFR    D,U
7a66: 10 8e 00 02     LDY    #$0002
7a6a: 34 60           PSHS   U,Y
7a6c: 17 fd d0        LBSR   $783F
7a6f: 32 64           LEAS   $4,S
7a71: 32 62           LEAS   $2,S
7a73: 39              RTS
7a74: 00 01           NEG    <$01
7a76: 00 05           NEG    <$05
7a78: 00 02           NEG    <$02
7a7a: 00 00           NEG    <$00
7a7c: 07 00           ASR    <$00
7a7e: 03 00           COM    <$00
7a80: 04 fc           LSR    <$FC
7a82: 7a ac 17        DEC    $AC17
7a85: 82 c9           SBCA   #$C9
7a87: ce 42 34        LDU    #$4234
7a8a: 10 8e 00 02     LDY    #$0002
7a8e: 34 60           PSHS   U,Y
7a90: 17 0f 75        LBSR   $8A08
7a93: 32 64           LEAS   $4,S
7a95: c6 01           LDB    #$01
7a97: f7 3c 03        STB    $3C03
7a9a: ee e9 00 06     LDU    $0006,S
7a9e: 10 8e 00 02     LDY    #$0002
7aa2: 34 60           PSHS   U,Y
7aa4: 17 d8 d9        LBSR   $5380
7aa7: 32 64           LEAS   $4,S
7aa9: 32 62           LEAS   $2,S
7aab: 39              RTS
; --- $FF padding to end of page 1 ---
7aac: 00 00           NEG    <$00
7aae: ff ff ff        STU    $FFFF
7ab1: ff ff ff        STU    $FFFF
7ab4: ff ff ff        STU    $FFFF
7ab7: ff ff ff        STU    $FFFF
7aba: ff ff ff        STU    $FFFF
7abd: ff ff ff        STU    $FFFF
7ac0: ff ff ff        STU    $FFFF
7ac3: ff ff ff        STU    $FFFF
7ac6: ff ff ff        STU    $FFFF
7ac9: ff ff ff        STU    $FFFF
7acc: ff ff ff        STU    $FFFF
7acf: ff ff ff        STU    $FFFF
7ad2: ff ff ff        STU    $FFFF
7ad5: ff ff ff        STU    $FFFF
7ad8: ff ff ff        STU    $FFFF
7adb: ff ff ff        STU    $FFFF
7ade: ff ff ff        STU    $FFFF
7ae1: ff ff ff        STU    $FFFF
7ae4: ff ff ff        STU    $FFFF
7ae7: ff ff ff        STU    $FFFF
7aea: ff ff ff        STU    $FFFF
7aed: ff ff ff        STU    $FFFF
7af0: ff ff ff        STU    $FFFF
7af3: ff ff ff        STU    $FFFF
7af6: ff ff ff        STU    $FFFF
7af9: ff ff ff        STU    $FFFF
7afc: ff ff ff        STU    $FFFF
7aff: ff ff ff        STU    $FFFF
7b02: ff ff ff        STU    $FFFF
7b05: ff ff ff        STU    $FFFF
7b08: ff ff ff        STU    $FFFF
7b0b: ff ff ff        STU    $FFFF
7b0e: ff ff ff        STU    $FFFF
7b11: ff ff ff        STU    $FFFF
7b14: ff ff ff        STU    $FFFF
7b17: ff ff ff        STU    $FFFF
7b1a: ff ff ff        STU    $FFFF
7b1d: ff ff ff        STU    $FFFF
7b20: ff ff ff        STU    $FFFF
7b23: ff ff ff        STU    $FFFF
7b26: ff ff ff        STU    $FFFF
7b29: ff ff ff        STU    $FFFF
7b2c: ff ff ff        STU    $FFFF
7b2f: ff ff ff        STU    $FFFF
7b32: ff ff ff        STU    $FFFF
7b35: ff ff ff        STU    $FFFF
7b38: ff ff ff        STU    $FFFF
7b3b: ff ff ff        STU    $FFFF
7b3e: ff ff ff        STU    $FFFF
7b41: ff ff ff        STU    $FFFF
7b44: ff ff ff        STU    $FFFF
7b47: ff ff ff        STU    $FFFF
7b4a: ff ff ff        STU    $FFFF
7b4d: ff ff ff        STU    $FFFF
7b50: ff ff ff        STU    $FFFF
7b53: ff ff ff        STU    $FFFF
7b56: ff ff ff        STU    $FFFF
7b59: ff ff ff        STU    $FFFF
7b5c: ff ff ff        STU    $FFFF
7b5f: ff ff ff        STU    $FFFF
7b62: ff ff ff        STU    $FFFF
7b65: ff ff ff        STU    $FFFF
7b68: ff ff ff        STU    $FFFF
7b6b: ff ff ff        STU    $FFFF
7b6e: ff ff ff        STU    $FFFF
7b71: ff ff ff        STU    $FFFF
7b74: ff ff ff        STU    $FFFF
7b77: ff ff ff        STU    $FFFF
7b7a: ff ff ff        STU    $FFFF
7b7d: ff ff ff        STU    $FFFF
7b80: ff ff ff        STU    $FFFF
7b83: ff ff ff        STU    $FFFF
7b86: ff ff ff        STU    $FFFF
7b89: ff ff ff        STU    $FFFF
7b8c: ff ff ff        STU    $FFFF
7b8f: ff ff ff        STU    $FFFF
7b92: ff ff ff        STU    $FFFF
7b95: ff ff ff        STU    $FFFF
7b98: ff ff ff        STU    $FFFF
7b9b: ff ff ff        STU    $FFFF
7b9e: ff ff ff        STU    $FFFF
7ba1: ff ff ff        STU    $FFFF
7ba4: ff ff ff        STU    $FFFF
7ba7: ff ff ff        STU    $FFFF
7baa: ff ff ff        STU    $FFFF
7bad: ff ff ff        STU    $FFFF
7bb0: ff ff ff        STU    $FFFF
7bb3: ff ff ff        STU    $FFFF
7bb6: ff ff ff        STU    $FFFF
7bb9: ff ff ff        STU    $FFFF
7bbc: ff ff ff        STU    $FFFF
7bbf: ff ff ff        STU    $FFFF
7bc2: ff ff ff        STU    $FFFF
7bc5: ff ff ff        STU    $FFFF
7bc8: ff ff ff        STU    $FFFF
7bcb: ff ff ff        STU    $FFFF
7bce: ff ff ff        STU    $FFFF
7bd1: ff ff ff        STU    $FFFF
7bd4: ff ff ff        STU    $FFFF
7bd7: ff ff ff        STU    $FFFF
7bda: ff ff ff        STU    $FFFF
7bdd: ff ff ff        STU    $FFFF
7be0: ff ff ff        STU    $FFFF
7be3: ff ff ff        STU    $FFFF
7be6: ff ff ff        STU    $FFFF
7be9: ff ff ff        STU    $FFFF
7bec: ff ff ff        STU    $FFFF
7bef: ff ff ff        STU    $FFFF
7bf2: ff ff ff        STU    $FFFF
7bf5: ff ff ff        STU    $FFFF
7bf8: ff ff ff        STU    $FFFF
7bfb: ff ff ff        STU    $FFFF
7bfe: ff ff ff        STU    $FFFF
7c01: ff ff ff        STU    $FFFF
7c04: ff ff ff        STU    $FFFF
7c07: ff ff ff        STU    $FFFF
7c0a: ff ff ff        STU    $FFFF
7c0d: ff ff ff        STU    $FFFF
7c10: ff ff ff        STU    $FFFF
7c13: ff ff ff        STU    $FFFF
7c16: ff ff ff        STU    $FFFF
7c19: ff ff ff        STU    $FFFF
7c1c: ff ff ff        STU    $FFFF
7c1f: ff ff ff        STU    $FFFF
7c22: ff ff ff        STU    $FFFF
7c25: ff ff ff        STU    $FFFF
7c28: ff ff ff        STU    $FFFF
7c2b: ff ff ff        STU    $FFFF
7c2e: ff ff ff        STU    $FFFF
7c31: ff ff ff        STU    $FFFF
7c34: ff ff ff        STU    $FFFF
7c37: ff ff ff        STU    $FFFF
7c3a: ff ff ff        STU    $FFFF
7c3d: ff ff ff        STU    $FFFF
7c40: ff ff ff        STU    $FFFF
7c43: ff ff ff        STU    $FFFF
7c46: ff ff ff        STU    $FFFF
7c49: ff ff ff        STU    $FFFF
7c4c: ff ff ff        STU    $FFFF
7c4f: ff ff ff        STU    $FFFF
7c52: ff ff ff        STU    $FFFF
7c55: ff ff ff        STU    $FFFF
7c58: ff ff ff        STU    $FFFF
7c5b: ff ff ff        STU    $FFFF
7c5e: ff ff ff        STU    $FFFF
7c61: ff ff ff        STU    $FFFF
7c64: ff ff ff        STU    $FFFF
7c67: ff ff ff        STU    $FFFF
7c6a: ff ff ff        STU    $FFFF
7c6d: ff ff ff        STU    $FFFF
7c70: ff ff ff        STU    $FFFF
7c73: ff ff ff        STU    $FFFF
7c76: ff ff ff        STU    $FFFF
7c79: ff ff ff        STU    $FFFF
7c7c: ff ff ff        STU    $FFFF
7c7f: ff ff ff        STU    $FFFF
7c82: ff ff ff        STU    $FFFF
7c85: ff ff ff        STU    $FFFF
7c88: ff ff ff        STU    $FFFF
7c8b: ff ff ff        STU    $FFFF
7c8e: ff ff ff        STU    $FFFF
7c91: ff ff ff        STU    $FFFF
7c94: ff ff ff        STU    $FFFF
7c97: ff ff ff        STU    $FFFF
7c9a: ff ff ff        STU    $FFFF
7c9d: ff ff ff        STU    $FFFF
7ca0: ff ff ff        STU    $FFFF
7ca3: ff ff ff        STU    $FFFF
7ca6: ff ff ff        STU    $FFFF
7ca9: ff ff ff        STU    $FFFF
7cac: ff ff ff        STU    $FFFF
7caf: ff ff ff        STU    $FFFF
7cb2: ff ff ff        STU    $FFFF
7cb5: ff ff ff        STU    $FFFF
7cb8: ff ff ff        STU    $FFFF
7cbb: ff ff ff        STU    $FFFF
7cbe: ff ff ff        STU    $FFFF
7cc1: ff ff ff        STU    $FFFF
7cc4: ff ff ff        STU    $FFFF
7cc7: ff ff ff        STU    $FFFF
7cca: ff ff ff        STU    $FFFF
7ccd: ff ff ff        STU    $FFFF
7cd0: ff ff ff        STU    $FFFF
7cd3: ff ff ff        STU    $FFFF
7cd6: ff ff ff        STU    $FFFF
7cd9: ff ff ff        STU    $FFFF
7cdc: ff ff ff        STU    $FFFF
7cdf: ff ff ff        STU    $FFFF
7ce2: ff ff ff        STU    $FFFF
7ce5: ff ff ff        STU    $FFFF
7ce8: ff ff ff        STU    $FFFF
7ceb: ff ff ff        STU    $FFFF
7cee: ff ff ff        STU    $FFFF
7cf1: ff ff ff        STU    $FFFF
7cf4: ff ff ff        STU    $FFFF
7cf7: ff ff ff        STU    $FFFF
7cfa: ff ff ff        STU    $FFFF
7cfd: ff ff ff        STU    $FFFF
7d00: ff ff ff        STU    $FFFF
7d03: ff ff ff        STU    $FFFF
7d06: ff ff ff        STU    $FFFF
7d09: ff ff ff        STU    $FFFF
7d0c: ff ff ff        STU    $FFFF
7d0f: ff ff ff        STU    $FFFF
7d12: ff ff ff        STU    $FFFF
7d15: ff ff ff        STU    $FFFF
7d18: ff ff ff        STU    $FFFF
7d1b: ff ff ff        STU    $FFFF
7d1e: ff ff ff        STU    $FFFF
7d21: ff ff ff        STU    $FFFF
7d24: ff ff ff        STU    $FFFF
7d27: ff ff ff        STU    $FFFF
7d2a: ff ff ff        STU    $FFFF
7d2d: ff ff ff        STU    $FFFF
7d30: ff ff ff        STU    $FFFF
7d33: ff ff ff        STU    $FFFF
7d36: ff ff ff        STU    $FFFF
7d39: ff ff ff        STU    $FFFF
7d3c: ff ff ff        STU    $FFFF
7d3f: ff ff ff        STU    $FFFF
7d42: ff ff ff        STU    $FFFF
7d45: ff ff ff        STU    $FFFF
7d48: ff ff ff        STU    $FFFF
7d4b: ff ff ff        STU    $FFFF
7d4e: ff ff ff        STU    $FFFF
7d51: ff ff ff        STU    $FFFF
7d54: ff ff ff        STU    $FFFF
7d57: ff ff ff        STU    $FFFF
7d5a: ff ff ff        STU    $FFFF
7d5d: ff ff ff        STU    $FFFF
7d60: ff ff ff        STU    $FFFF
7d63: ff ff ff        STU    $FFFF
7d66: ff ff ff        STU    $FFFF
7d69: ff ff ff        STU    $FFFF
7d6c: ff ff ff        STU    $FFFF
7d6f: ff ff ff        STU    $FFFF
7d72: ff ff ff        STU    $FFFF
7d75: ff ff ff        STU    $FFFF
7d78: ff ff ff        STU    $FFFF
7d7b: ff ff ff        STU    $FFFF
7d7e: ff ff ff        STU    $FFFF
7d81: ff ff ff        STU    $FFFF
7d84: ff ff ff        STU    $FFFF
7d87: ff ff ff        STU    $FFFF
7d8a: ff ff ff        STU    $FFFF
7d8d: ff ff ff        STU    $FFFF
7d90: ff ff ff        STU    $FFFF
7d93: ff ff ff        STU    $FFFF
7d96: ff ff ff        STU    $FFFF
7d99: ff ff ff        STU    $FFFF
7d9c: ff ff ff        STU    $FFFF
7d9f: ff ff ff        STU    $FFFF
7da2: ff ff ff        STU    $FFFF
7da5: ff ff ff        STU    $FFFF
7da8: ff ff ff        STU    $FFFF
7dab: ff ff ff        STU    $FFFF
7dae: ff ff ff        STU    $FFFF
7db1: ff ff ff        STU    $FFFF
7db4: ff ff ff        STU    $FFFF
7db7: ff ff ff        STU    $FFFF
7dba: ff ff ff        STU    $FFFF
7dbd: ff ff ff        STU    $FFFF
7dc0: ff ff ff        STU    $FFFF
7dc3: ff ff ff        STU    $FFFF
7dc6: ff ff ff        STU    $FFFF
7dc9: ff ff ff        STU    $FFFF
7dcc: ff ff ff        STU    $FFFF
7dcf: ff ff ff        STU    $FFFF
7dd2: ff ff ff        STU    $FFFF
7dd5: ff ff ff        STU    $FFFF
7dd8: ff ff ff        STU    $FFFF
7ddb: ff ff ff        STU    $FFFF
7dde: ff ff ff        STU    $FFFF
7de1: ff ff ff        STU    $FFFF
7de4: ff ff ff        STU    $FFFF
7de7: ff ff ff        STU    $FFFF
7dea: ff ff ff        STU    $FFFF
7ded: ff ff ff        STU    $FFFF
7df0: ff ff ff        STU    $FFFF
7df3: ff ff ff        STU    $FFFF
7df6: ff ff ff        STU    $FFFF
7df9: ff ff ff        STU    $FFFF
7dfc: ff ff ff        STU    $FFFF
7dff: ff ff ff        STU    $FFFF
7e02: ff ff ff        STU    $FFFF
7e05: ff ff ff        STU    $FFFF
7e08: ff ff ff        STU    $FFFF
7e0b: ff ff ff        STU    $FFFF
7e0e: ff ff ff        STU    $FFFF
7e11: ff ff ff        STU    $FFFF
7e14: ff ff ff        STU    $FFFF
7e17: ff ff ff        STU    $FFFF
7e1a: ff ff ff        STU    $FFFF
7e1d: ff ff ff        STU    $FFFF
7e20: ff ff ff        STU    $FFFF
7e23: ff ff ff        STU    $FFFF
7e26: ff ff ff        STU    $FFFF
7e29: ff ff ff        STU    $FFFF
7e2c: ff ff ff        STU    $FFFF
7e2f: ff ff ff        STU    $FFFF
7e32: ff ff ff        STU    $FFFF
7e35: ff ff ff        STU    $FFFF
7e38: ff ff ff        STU    $FFFF
7e3b: ff ff ff        STU    $FFFF
7e3e: ff ff ff        STU    $FFFF
7e41: ff ff ff        STU    $FFFF
7e44: ff ff ff        STU    $FFFF
7e47: ff ff ff        STU    $FFFF
7e4a: ff ff ff        STU    $FFFF
7e4d: ff ff ff        STU    $FFFF
7e50: ff ff ff        STU    $FFFF
7e53: ff ff ff        STU    $FFFF
7e56: ff ff ff        STU    $FFFF
7e59: ff ff ff        STU    $FFFF
7e5c: ff ff ff        STU    $FFFF
7e5f: ff ff ff        STU    $FFFF
7e62: ff ff ff        STU    $FFFF
7e65: ff ff ff        STU    $FFFF
7e68: ff ff ff        STU    $FFFF
7e6b: ff ff ff        STU    $FFFF
7e6e: ff ff ff        STU    $FFFF
7e71: ff ff ff        STU    $FFFF
7e74: ff ff ff        STU    $FFFF
7e77: ff ff ff        STU    $FFFF
7e7a: ff ff ff        STU    $FFFF
7e7d: ff ff ff        STU    $FFFF
7e80: ff ff ff        STU    $FFFF
7e83: ff ff ff        STU    $FFFF
7e86: ff ff ff        STU    $FFFF
7e89: ff ff ff        STU    $FFFF
7e8c: ff ff ff        STU    $FFFF
7e8f: ff ff ff        STU    $FFFF
7e92: ff ff ff        STU    $FFFF
7e95: ff ff ff        STU    $FFFF
7e98: ff ff ff        STU    $FFFF
7e9b: ff ff ff        STU    $FFFF
7e9e: ff ff ff        STU    $FFFF
7ea1: ff ff ff        STU    $FFFF
7ea4: ff ff ff        STU    $FFFF
7ea7: ff ff ff        STU    $FFFF
7eaa: ff ff ff        STU    $FFFF
7ead: ff ff ff        STU    $FFFF
7eb0: ff ff ff        STU    $FFFF
7eb3: ff ff ff        STU    $FFFF
7eb6: ff ff ff        STU    $FFFF
7eb9: ff ff ff        STU    $FFFF
7ebc: ff ff ff        STU    $FFFF
7ebf: ff ff ff        STU    $FFFF
7ec2: ff ff ff        STU    $FFFF
7ec5: ff ff ff        STU    $FFFF
7ec8: ff ff ff        STU    $FFFF
7ecb: ff ff ff        STU    $FFFF
7ece: ff ff ff        STU    $FFFF
7ed1: ff ff ff        STU    $FFFF
7ed4: ff ff ff        STU    $FFFF
7ed7: ff ff ff        STU    $FFFF
7eda: ff ff ff        STU    $FFFF
7edd: ff ff ff        STU    $FFFF
7ee0: ff ff ff        STU    $FFFF
7ee3: ff ff ff        STU    $FFFF
7ee6: ff ff ff        STU    $FFFF
7ee9: ff ff ff        STU    $FFFF
7eec: ff ff ff        STU    $FFFF
7eef: ff ff ff        STU    $FFFF
7ef2: ff ff ff        STU    $FFFF
7ef5: ff ff ff        STU    $FFFF
7ef8: ff ff ff        STU    $FFFF
7efb: ff ff ff        STU    $FFFF
7efe: ff ff ff        STU    $FFFF
7f01: ff ff ff        STU    $FFFF
7f04: ff ff ff        STU    $FFFF
7f07: ff ff ff        STU    $FFFF
7f0a: ff ff ff        STU    $FFFF
7f0d: ff ff ff        STU    $FFFF
7f10: ff ff ff        STU    $FFFF
7f13: ff ff ff        STU    $FFFF
7f16: ff ff ff        STU    $FFFF
7f19: ff ff ff        STU    $FFFF
7f1c: ff ff ff        STU    $FFFF
7f1f: ff ff ff        STU    $FFFF
7f22: ff ff ff        STU    $FFFF
7f25: ff ff ff        STU    $FFFF
7f28: ff ff ff        STU    $FFFF
7f2b: ff ff ff        STU    $FFFF
7f2e: ff ff ff        STU    $FFFF
7f31: ff ff ff        STU    $FFFF
7f34: ff ff ff        STU    $FFFF
7f37: ff ff ff        STU    $FFFF
7f3a: ff ff ff        STU    $FFFF
7f3d: ff ff ff        STU    $FFFF
7f40: ff ff ff        STU    $FFFF
7f43: ff ff ff        STU    $FFFF
7f46: ff ff ff        STU    $FFFF
7f49: ff ff ff        STU    $FFFF
7f4c: ff ff ff        STU    $FFFF
7f4f: ff ff ff        STU    $FFFF
7f52: ff ff ff        STU    $FFFF
7f55: ff ff ff        STU    $FFFF
7f58: ff ff ff        STU    $FFFF
7f5b: ff ff ff        STU    $FFFF
7f5e: ff ff ff        STU    $FFFF
7f61: ff ff ff        STU    $FFFF
7f64: ff ff ff        STU    $FFFF
7f67: ff ff ff        STU    $FFFF
7f6a: ff ff ff        STU    $FFFF
7f6d: ff ff ff        STU    $FFFF
7f70: ff ff ff        STU    $FFFF
7f73: ff ff ff        STU    $FFFF
7f76: ff ff ff        STU    $FFFF
7f79: ff ff ff        STU    $FFFF
7f7c: ff ff ff        STU    $FFFF
7f7f: ff ff ff        STU    $FFFF
7f82: ff ff ff        STU    $FFFF
7f85: ff ff ff        STU    $FFFF
7f88: ff ff ff        STU    $FFFF
7f8b: ff ff ff        STU    $FFFF
7f8e: ff ff ff        STU    $FFFF
7f91: ff ff ff        STU    $FFFF
7f94: ff ff ff        STU    $FFFF
7f97: ff ff ff        STU    $FFFF
7f9a: ff ff ff        STU    $FFFF
7f9d: ff ff ff        STU    $FFFF
7fa0: ff ff ff        STU    $FFFF
7fa3: ff ff ff        STU    $FFFF
7fa6: ff ff ff        STU    $FFFF
7fa9: ff ff ff        STU    $FFFF
7fac: ff ff ff        STU    $FFFF
7faf: ff ff ff        STU    $FFFF
7fb2: ff ff ff        STU    $FFFF
7fb5: ff ff ff        STU    $FFFF
7fb8: ff ff ff        STU    $FFFF
7fbb: ff ff ff        STU    $FFFF
7fbe: ff ff ff        STU    $FFFF
7fc1: ff ff ff        STU    $FFFF
7fc4: ff ff ff        STU    $FFFF
7fc7: ff ff ff        STU    $FFFF
7fca: ff ff ff        STU    $FFFF
7fcd: ff ff ff        STU    $FFFF
7fd0: ff ff ff        STU    $FFFF
7fd3: ff ff ff        STU    $FFFF
7fd6: ff ff ff        STU    $FFFF
7fd9: ff ff ff        STU    $FFFF
7fdc: ff ff ff        STU    $FFFF
7fdf: ff ff ff        STU    $FFFF
7fe2: ff ff ff        STU    $FFFF
7fe5: ff ff ff        STU    $FFFF
7fe8: ff ff ff        STU    $FFFF
7feb: ff ff ff        STU    $FFFF
7fee: ff ff ff        STU    $FFFF
7ff1: ff ff ff        STU    $FFFF
7ff4: ff ff ff        STU    $FFFF
7ff7: ff ff ff        STU    $FFFF
7ffa: ff ff ff        STU    $FFFF
7ffd: ff ff ff        STU    $FFFF
;
; #####################################################################################
; PAGE 2 — Sequence editing and digital I/O (file offset $8000-$BFFF, CPU $4000-$7FFF)
; #####################################################################################
;
8000: 32 41           LEAS   $1,U
8002: 00 01           NEG    <$01
8004: 20 53           BRA    $8059
8006: 65 71           LSR    -$F,S
8008: 20 49           BRA    $8053
800a: 6e 64           JMP    $4,S
800c: 65 78           LSR    -$8,S
800e: 20 20           BRA    $8030
8010: 31 32           LEAY   -$E,Y
8012: 36 20           PSHU   Y
8014: 20 20           BRA    $8036
8016: 5b              XDECB
8017: 31 32           LEAY   -$E,Y
8019: 33 34           LEAU   -$C,Y
801b: 35 36           PULS   D,X,Y
801d: 37 38           PULU   DP,X,Y
801f: 39              RTS
8020: 41              NEGA
8021: 42              XNCA
8022: 43              COMA
8023: 44              LSRA
8024: 45              LSRA
8025: 46              RORA
8026: 30 5d           LEAX   -$3,U
8028: 20 20           BRA    $804A
802a: 00 02           NEG    <$02
802c: 20 53           BRA    $8081
802e: 65 71           LSR    -$F,S
8030: 20 45           BRA    $8077
8032: 6e 64           JMP    $4,S
8034: 20 20           BRA    $8056
8036: 31 32           LEAY   -$E,Y
8038: 37 20           PULU   Y
803a: 20 20           BRA    $805C
803c: 20 20           BRA    $805E
803e: 00 04           NEG    <$04
8040: 20 45           BRA    $8087
8042: 64 69           LSR    $9,S
8044: 74 20 53        LSR    $2053
8047: 65 71           LSR    -$F,S
8049: 75 65 6e        LSR    $656E
804c: 63 65           COM    $5,S
804e: 20 20           BRA    $8070
8050: 20 20           BRA    $8072
8052: 00 01           NEG    <$01
8054: 20 42           BRA    $8098
8056: 69 74           ROL    -$C,S
8058: 20 20           BRA    $807A
805a: 31 31           LEAY   -$F,Y
805c: 35 20           PULS   Y
805e: 20 5b           BRA    $80BB
8060: 31 5d           LEAY   -$3,U
8062: 20 20           BRA    $8084
8064: 20 20           BRA    $8086
8066: 20 20           BRA    $8088
8068: 20 20           BRA    $808A
806a: 20 20           BRA    $808C
806c: 20 20           BRA    $808E
806e: 20 20           BRA    $8090
8070: 20 20           BRA    $8092
8072: 20 20           BRA    $8094
8074: 20 20           BRA    $8096
8076: 20 20           BRA    $8098
8078: 20 20           BRA    $809A
807a: 00 02           NEG    <$02
807c: 20 43           BRA    $80C1
807e: 6f 6e           CLR    $E,S
8080: 74 69 6e        LSR    $696E
8083: 75 6f 75        LSR    $6F75
8086: 73 20 20        COM    $2020
8089: 20 20           BRA    $80AB
808b: 20 20           BRA    $80AD
808d: 20 00           BRA    $808F
808f: 03 20           COM    <$20
8091: 53              COMB
8092: 69 6e           ROL    $E,S
8094: 67 6c           ASR    $C,S
8096: 65 20           LSR    $0,Y
8098: 20 00           BRA    $809A
809a: 04 20           LSR    <$20
809c: 53              COMB
809d: 74 6f 70        LSR    $6F70
80a0: 20 20           BRA    $80C2
80a2: 00 01           NEG    <$01
80a4: 20 4d           BRA    $80F3
80a6: 61 6e           NEG    $E,S
80a8: 75 61 6c        LSR    $616C
80ab: 20 20           BRA    $80CD
80ad: 20 20           BRA    $80CF
80af: 20 20           BRA    $80D1
80b1: 20 20           BRA    $80D3
80b3: 20 20           BRA    $80D5
80b5: 20 00           BRA    $80B7
80b7: 03 20           COM    <$20
80b9: 44              LSRA
80ba: 65 6c           LSR    $C,S
80bc: 65 74           LSR    -$C,S
80be: 65 20           LSR    $0,Y
80c0: 20 00           BRA    $80C2
80c2: 04 20           LSR    <$20
80c4: 49              ROLA
80c5: 6e 73           JMP    -$D,S
80c7: 65 72           LSR    -$E,S
80c9: 74 2a 2a        LSR    $2A2A
80cc: 20 20           BRA    $80EE
80ce: 20 20           BRA    $80F0
80d0: 20 20           BRA    $80F2
80d2: 20 44           BRA    $8118
80d4: 69 67           ROL    $7,S
80d6: 69 74           ROL    -$C,S
80d8: 61 6c           NEG    $C,S
80da: 20 53           BRA    $812F
80dc: 65 71           LSR    -$F,S
80de: 75 65 6e        LSR    $656E
80e1: 63 65           COM    $5,S
80e3: 20 4d           BRA    $8132
80e5: 6f 64           CLR    $4,S
80e7: 65 20           LSR    $0,Y
80e9: 20 20           BRA    $810B
80eb: 20 20           BRA    $810D
80ed: 20 20           BRA    $810F
80ef: 20 2a           BRA    $811B
80f1: 2a 50           BPL    $8143
80f3: 72 65 73        XNC    $6573
80f6: 73 20 4e        COM    $204E
80f9: 45              LSRA
80fa: 58              ASLB
80fb: 54              LSRB
80fc: 2f 4c           BLE    $814A
80fe: 41              NEGA
80ff: 53              COMB
8100: 54              LSRB
8101: 20 4b           BRA    $814E
8103: 65 79           LSR    -$7,S
8105: 73 2e 20        COM    $2E20
8108: 20 20           BRA    $812A
810a: 20 00           BRA    $810C
810c: 04 20           LSR    <$20
810e: 45              LSRA
810f: 78 69 74        ASL    $6974
8112: 20 20           BRA    $8134
8114: 20 20           BRA    $8136
8116: 20 20           BRA    $8138
8118: 20 20           BRA    $813A
811a: 00 01           NEG    <$01
811c: 20 53           BRA    $8171
811e: 65 71           LSR    -$F,S
8120: 20 42           BRA    $8164
8122: 61 73           NEG    -$D,S
8124: 65 20           LSR    $0,Y
8126: 48              ASLA
8127: 65 78           LSR    -$8,S
8129: 20 20           BRA    $814B
812b: 20 20           BRA    $814D
812d: 20 00           BRA    $812F
812f: 03 20           COM    <$20
8131: 50              NEGB
8132: 65 72           LSR    -$E,S
8134: 69 6f           ROL    $F,S
8136: 64 20           LSR    $0,Y
8138: 20 20           BRA    $815A
813a: 31 2e           LEAY   $E,Y
813c: 30 20           LEAX   $0,Y
813e: 20 6d           BRA    $81AD
8140: 73 20 00        COM    $2000
8143: 02 20           XNC    <$20
8145: 4f              CLRA
8146: 6e 20           JMP    $0,Y
8148: 4c              INCA
8149: 65 76           LSR    -$A,S
814b: 20 20           BRA    $816D
814d: 35 2e           PULS   D,DP,Y
814f: 30 30           LEAX   -$10,Y
8151: 20 20           BRA    $8173
8153: 20 56           BRA    $81AB
8155: 20 00           BRA    $8157
8157: 04 20           LSR    <$20
8159: 4f              CLRA
815a: 66 66           ROR    $6,S
815c: 20 4c           BRA    $81AA
815e: 65 76           LSR    -$A,S
8160: 20 20           BRA    $8182
8162: 20 20           BRA    $8184
8164: 20 30           BRA    $8196
8166: 20 20           BRA    $8188
; ---------------------------------------------------------------------------
; End of string data.  Lookup tables follow: function pointer arrays (entries
; $C239 = null/unused), parameter descriptors for digital sequence modes.
; ---------------------------------------------------------------------------
8168: 75 56 03        LSR    $5603
816b: 40              NEGA
816c: ca c2           ORB    #$C2
816e: 39              RTS
816f: c2 39           SBCB   #$39
8171: c2 39           SBCB   #$39
8173: 8b 4c           ADDA   #$4C
8175: 41              NEGA
8176: 1a 68           ORCC   #$68
8178: 9b 69           ADDA   <$69
817a: 40              NEGA
817b: 69 17           ROL    -$9,X
817d: 69 76           ROL    -$A,S
817f: 40              NEGA
8180: 02 5b           XNC    <$5B
8182: 24 5b           BCC    $81DF
8184: 4e              XCLRA
8185: 5b              XDECB
8186: da 5b           ORB    <$5B
8188: 73 40 52        COM    $4052
818b: 69 ed 6a 18     ROL    $EBA7,PCR
818f: 6a a1           DEC    ,Y++
8191: 6a b8 0f        DEC    [$0F,Y]
8194: 42              XNCA
8195: 40              NEGA
; ---------------------------------------------------------------------------
; Hand-written assembly: digital sequence timing engine.  Programs DDS
; ($0200), reads/writes MC6840 PTM ($1001/$1004), manages sequence counters
; in $3Cxx RAM, calls $53F9 for output transitions.  Runs through $849C.
; ---------------------------------------------------------------------------
8196: b6 10 01        LDA    $1001
8199: b6 10 04        LDA    $1004
819c: 78 3c c9        ASL    $3CC9
819f: 24 29           BCC    $81CA
81a1: 8e 22 20        LDX    #$2220
81a4: bf 02 00        STX    $0200
81a7: be 3c c4        LDX    $3CC4
81aa: 30 01           LEAX   $1,X
81ac: bf 3c c4        STX    $3CC4
81af: 26 42           BNE    $81F3
81b1: 10 be 3c 9e     LDY    $3C9E
81b5: 31 3f           LEAY   -$1,Y
81b7: 10 bf 10 04     STY    $1004
81bb: 7d 3c c8        TST    $3CC8
81be: 27 33           BEQ    $81F3
81c0: 86 91           LDA    #$91
81c2: b7 10 01        STA    $1001
81c5: bd 53 f9        JSR    $53F9
81c8: 20 65           BRA    $822F
81ca: 8e 22 22        LDX    #$2222
81cd: bf 02 00        STX    $0200
81d0: be 3c c4        LDX    $3CC4
81d3: 30 01           LEAX   $1,X
81d5: bf 3c c4        STX    $3CC4
81d8: 26 19           BNE    $81F3
81da: 10 be 3c 9e     LDY    $3C9E
81de: 31 3f           LEAY   -$1,Y
81e0: 10 bf 10 04     STY    $1004
81e4: 7d 3c c8        TST    $3CC8
81e7: 27 0a           BEQ    $81F3
81e9: 86 91           LDA    #$91
81eb: b7 10 01        STA    $1001
81ee: bd 53 f9        JSR    $53F9
81f1: 20 3c           BRA    $822F
81f3: bc 3c aa        CMPX   $3CAA
81f6: 23 24           BLS    $821C
81f8: 7d 3c 03        TST    $3C03
81fb: 26 12           BNE    $820F
81fd: 8e 00 00        LDX    #$0000
8200: bf 3c c4        STX    $3CC4
8203: 8e 3c 21        LDX    #$3C21
8206: bf 3c c6        STX    $3CC6
8209: a6 84           LDA    ,X
820b: b7 3c c9        STA    $3CC9
820e: 3b              RTI
820f: cc ff ff        LDD    #$FFFF
8212: fd 3c c4        STD    $3CC4
8215: b7 3c c8        STA    $3CC8
8218: 7f 3c c9        CLR    $3CC9
821b: 3b              RTI
821c: 1f 10           TFR    X,D
821e: c4 07           ANDB   #$07
8220: 26 0d           BNE    $822F
8222: be 3c c6        LDX    $3CC6
8225: 30 01           LEAX   $1,X
8227: a6 84           LDA    ,X
8229: bf 3c c6        STX    $3CC6
822c: b7 3c c9        STA    $3CC9
822f: 3b              RTI
8230: 32 7d           LEAS   -$3,S
8232: ec 67           LDD    $7,S
8234: e3 69           ADDD   $9,S
8236: 25 06           BCS    $823E
8238: ed f8 0b        STD    [$0B,S]
823b: 5f              CLRB
823c: 20 02           BRA    $8240
823e: c6 01           LDB    #$01
8240: e7 62           STB    $2,S
8242: 32 63           LEAS   $3,S
8244: 39              RTS
8245: 42              XNCA
8246: d3 42           ADDD   <$42
8248: d9 42           ADCB   <$42
824a: e1 42           CMPB   $2,U
824c: f0 42 f8        SUBB   $42F8
824f: 43              COMA
8250: 00 43           NEG    <$43
8252: 18              X18
8253: 43              COMA
8254: 20 80           BRA    $81D6
8256: 40              NEGA
8257: 20 10           BRA    $8269
8259: 08 04           ASL    <$04
825b: 02 01           XNC    <$01
825d: 32 7d           LEAS   -$3,S
825f: ae 67           LDX    $7,S
8261: b6 3c 20        LDA    $3C20
8264: 27 20           BEQ    $8286
8266: 4a              DECA
8267: 27 46           BEQ    $82AF
8269: 1f 10           TFR    X,D
826b: 44              LSRA
826c: 56              RORB
826d: 34 01           PSHS   CC
826f: c3 3c 21        ADDD   #$3C21
8272: 1f 01           TFR    D,X
8274: e6 84           LDB    ,X
8276: 35 01           PULS   CC
8278: 24 05           BCC    $827F
827a: c4 0f           ANDB   #$0F
827c: 16 00 ae        LBRA   $832D
827f: 54              LSRB
8280: 54              LSRB
8281: 54              LSRB
8282: 54              LSRB
8283: 16 00 a7        LBRA   $832D
8286: 1f 10           TFR    X,D
8288: c4 07           ANDB   #$07
828a: 1f 12           TFR    X,Y
828c: 8e 42 55        LDX    #$4255
828f: 3a              ABX
8290: a6 84           LDA    ,X
8292: 34 02           PSHS   A
8294: 1f 20           TFR    Y,D
8296: 44              LSRA
8297: 56              RORB
8298: 44              LSRA
8299: 56              RORB
829a: 44              LSRA
829b: 56              RORB
829c: c3 3c 21        ADDD   #$3C21
829f: 1f 01           TFR    D,X
82a1: a6 84           LDA    ,X
82a3: 5f              CLRB
82a4: a4 e4           ANDA   ,S
82a6: 35 02           PULS   A
82a8: 27 02           BEQ    $82AC
82aa: c6 01           LDB    #$01
82ac: 16 00 7e        LBRA   $832D
82af: 1f 10           TFR    X,D
82b1: 44              LSRA
82b2: 56              RORB
82b3: 44              LSRA
82b4: 56              RORB
82b5: 44              LSRA
82b6: 56              RORB
82b7: 34 06           PSHS   D
82b9: 58              ASLB
82ba: 49              ROLA
82bb: e3 e4           ADDD   ,S
82bd: 32 62           LEAS   $2,S
82bf: c3 3c 21        ADDD   #$3C21
82c2: 34 06           PSHS   D
82c4: 1f 10           TFR    X,D
82c6: c4 07           ANDB   #$07
82c8: 58              ASLB
82c9: 8e 42 45        LDX    #$4245
82cc: 3a              ABX
82cd: ae 84           LDX    ,X
82cf: 35 06           PULS   D
82d1: 6e 84           JMP    ,X
82d3: 1f 01           TFR    D,X
82d5: e6 84           LDB    ,X
82d7: 20 4f           BRA    $8328
82d9: 1f 01           TFR    D,X
82db: e6 84           LDB    ,X
82dd: c4 1f           ANDB   #$1F
82df: 20 4a           BRA    $832B
82e1: 1f 01           TFR    D,X
82e3: e6 84           LDB    ,X
82e5: c4 03           ANDB   #$03
82e7: 58              ASLB
82e8: a6 01           LDA    $1,X
82ea: 49              ROLA
82eb: c9 00           ADCB   #$00
82ed: 16 00 3d        LBRA   $832D
82f0: 1f 01           TFR    D,X
82f2: e6 01           LDB    $1,X
82f4: c4 7f           ANDB   #$7F
82f6: 20 31           BRA    $8329
82f8: 1f 01           TFR    D,X
82fa: e6 01           LDB    $1,X
82fc: c4 0f           ANDB   #$0F
82fe: 20 2c           BRA    $832C
8300: 1f 01           TFR    D,X
8302: e6 01           LDB    $1,X
8304: c4 01           ANDB   #$01
8306: 58              ASLB
8307: 58              ASLB
8308: a6 02           LDA    $2,X
830a: 49              ROLA
830b: 49              ROLA
830c: 49              ROLA
830d: 84 03           ANDA   #$03
830f: 1f 01           TFR    D,X
8311: 1f 89           TFR    A,B
8313: 3a              ABX
8314: 1f 10           TFR    X,D
8316: 20 15           BRA    $832D
8318: 1f 01           TFR    D,X
831a: e6 02           LDB    $2,X
831c: c4 3f           ANDB   #$3F
831e: 20 0a           BRA    $832A
8320: 1f 01           TFR    D,X
8322: e6 02           LDB    $2,X
8324: c4 07           ANDB   #$07
8326: 20 05           BRA    $832D
8328: 54              LSRB
8329: 54              LSRB
832a: 54              LSRB
832b: 54              LSRB
832c: 54              LSRB
832d: 32 63           LEAS   $3,S
832f: 39              RTS
8330: 43              COMA
8331: eb 44           ADDB   $4,U
8333: 01 44           NEG    <$44
8335: 14              XHCF
8336: 44              LSRA
8337: 35 44           PULS   B,U
8339: 49              ROLA
833a: 44              LSRA
833b: 5a              DECB
833c: 44              LSRA
833d: 7d 44 90        TST    $4490
8340: 32 7e           LEAS   -$2,S
8342: ae 66           LDX    $6,S
8344: b6 3c 20        LDA    $3C20
8347: 27 3d           BEQ    $8386
8349: 4a              DECA
834a: 27 72           BEQ    $83BE
834c: 1f 10           TFR    X,D
834e: 10 83 00 fa     CMPD   #$00FA
8352: 25 03           BCS    $8357
8354: 16 01 43        LBRA   $849A
8357: 44              LSRA
8358: 56              RORB
8359: 34 01           PSHS   CC
835b: c3 3c 21        ADDD   #$3C21
835e: 1f 01           TFR    D,X
8360: e6 84           LDB    ,X
8362: 35 01           PULS   CC
8364: 24 0f           BCC    $8375
8366: a6 69           LDA    $9,S
8368: c4 f0           ANDB   #$F0
836a: e7 84           STB    ,X
836c: 84 0f           ANDA   #$0F
836e: ab 84           ADDA   ,X
8370: a7 84           STA    ,X
8372: 16 01 25        LBRA   $849A
8375: a6 69           LDA    $9,S
8377: c4 0f           ANDB   #$0F
8379: e7 84           STB    ,X
837b: 48              ASLA
837c: 48              ASLA
837d: 48              ASLA
837e: 48              ASLA
837f: ab 84           ADDA   ,X
8381: a7 84           STA    ,X
8383: 16 01 14        LBRA   $849A
8386: 1f 10           TFR    X,D
8388: 10 83 03 e8     CMPD   #$03E8
838c: 25 03           BCS    $8391
838e: 16 01 09        LBRA   $849A
8391: c4 07           ANDB   #$07
8393: 1f 12           TFR    X,Y
8395: 8e 42 55        LDX    #$4255
8398: 3a              ABX
8399: a6 84           LDA    ,X
839b: 34 02           PSHS   A
839d: 43              COMA
839e: 34 02           PSHS   A
83a0: 1f 20           TFR    Y,D
83a2: 44              LSRA
83a3: 56              RORB
83a4: 44              LSRA
83a5: 56              RORB
83a6: 44              LSRA
83a7: 56              RORB
83a8: c3 3c 21        ADDD   #$3C21
83ab: 1f 01           TFR    D,X
83ad: e6 84           LDB    ,X
83af: e4 e4           ANDB   ,S
83b1: 66 6b           ROR    $B,S
83b3: 24 02           BCC    $83B7
83b5: ea 61           ORB    $1,S
83b7: 32 62           LEAS   $2,S
83b9: e7 84           STB    ,X
83bb: 16 00 dc        LBRA   $849A
83be: 1f 10           TFR    X,D
83c0: 10 83 01 4d     CMPD   #$014D
83c4: 25 03           BCS    $83C9
83c6: 16 00 d1        LBRA   $849A
83c9: 44              LSRA
83ca: 56              RORB
83cb: 44              LSRA
83cc: 56              RORB
83cd: 44              LSRA
83ce: 56              RORB
83cf: 34 06           PSHS   D
83d1: 58              ASLB
83d2: 49              ROLA
83d3: e3 e4           ADDD   ,S
83d5: 32 62           LEAS   $2,S
83d7: c3 3c 21        ADDD   #$3C21
83da: 34 06           PSHS   D
83dc: 1f 10           TFR    X,D
83de: c4 07           ANDB   #$07
83e0: 58              ASLB
83e1: 8e 43 30        LDX    #$4330
83e4: 3a              ABX
83e5: ae 84           LDX    ,X
83e7: 35 06           PULS   D
83e9: 6e 84           JMP    ,X
83eb: 1f 01           TFR    D,X
83ed: e6 84           LDB    ,X
83ef: c4 1f           ANDB   #$1F
83f1: e7 84           STB    ,X
83f3: a6 69           LDA    $9,S
83f5: 48              ASLA
83f6: 48              ASLA
83f7: 48              ASLA
83f8: 48              ASLA
83f9: 48              ASLA
83fa: ab 84           ADDA   ,X
83fc: a7 84           STA    ,X
83fe: 16 00 99        LBRA   $849A
8401: 1f 01           TFR    D,X
8403: e6 84           LDB    ,X
8405: c4 e3           ANDB   #$E3
8407: e7 84           STB    ,X
8409: a6 69           LDA    $9,S
840b: 48              ASLA
840c: 48              ASLA
840d: ab 84           ADDA   ,X
840f: a7 84           STA    ,X
8411: 16 00 86        LBRA   $849A
8414: 1f 01           TFR    D,X
8416: e6 84           LDB    ,X
8418: c4 fc           ANDB   #$FC
841a: e7 84           STB    ,X
841c: a6 69           LDA    $9,S
841e: 44              LSRA
841f: ab 84           ADDA   ,X
8421: a7 84           STA    ,X
8423: e6 01           LDB    $1,X
8425: c4 7f           ANDB   #$7F
8427: e7 01           STB    $1,X
8429: a6 69           LDA    $9,S
842b: 46              RORA
842c: 46              RORA
842d: 84 80           ANDA   #$80
842f: ab 01           ADDA   $1,X
8431: a7 01           STA    $1,X
8433: 20 65           BRA    $849A
8435: 1f 01           TFR    D,X
8437: e6 01           LDB    $1,X
8439: c4 8f           ANDB   #$8F
843b: e7 01           STB    $1,X
843d: a6 69           LDA    $9,S
843f: 48              ASLA
8440: 48              ASLA
8441: 48              ASLA
8442: 48              ASLA
8443: ab 01           ADDA   $1,X
8445: a7 01           STA    $1,X
8447: 20 51           BRA    $849A
8449: 1f 01           TFR    D,X
844b: e6 01           LDB    $1,X
844d: c4 f1           ANDB   #$F1
844f: e7 01           STB    $1,X
8451: a6 69           LDA    $9,S
8453: 48              ASLA
8454: ab 01           ADDA   $1,X
8456: a7 01           STA    $1,X
8458: 20 40           BRA    $849A
845a: 1f 01           TFR    D,X
845c: e6 01           LDB    $1,X
845e: c4 fe           ANDB   #$FE
8460: e7 01           STB    $1,X
8462: a6 69           LDA    $9,S
8464: 44              LSRA
8465: 44              LSRA
8466: ab 01           ADDA   $1,X
8468: a7 01           STA    $1,X
846a: e6 02           LDB    $2,X
846c: c4 3f           ANDB   #$3F
846e: e7 02           STB    $2,X
8470: a6 69           LDA    $9,S
8472: 46              RORA
8473: 46              RORA
8474: 46              RORA
8475: 84 c0           ANDA   #$C0
8477: ab 02           ADDA   $2,X
8479: a7 02           STA    $2,X
847b: 20 1d           BRA    $849A
847d: 1f 01           TFR    D,X
847f: e6 02           LDB    $2,X
8481: c4 c7           ANDB   #$C7
8483: e7 02           STB    $2,X
8485: a6 69           LDA    $9,S
8487: 48              ASLA
8488: 48              ASLA
8489: 48              ASLA
848a: ab 02           ADDA   $2,X
848c: a7 02           STA    $2,X
848e: 20 0a           BRA    $849A
8490: 1f 01           TFR    D,X
8492: e6 02           LDB    $2,X
8494: c4 f8           ANDB   #$F8
8496: eb 69           ADDB   $9,S
8498: e7 02           STB    $2,X
849a: 32 62           LEAS   $2,S
849c: 39              RTS
; ---------------------------------------------------------------------------
; First C-compiled function (page 2).  Frame-allocating functions follow,
; covering bit-level sequence editing, digital port configuration.
; Pattern: LDD <rom-addr>; LBSR $3D50 allocates stack frame (= CPU $FD50).
; ---------------------------------------------------------------------------
849d: fc 51 3d        LDD    $513D
84a0: 17 b8 ad        LBSR   $3D50
84a3: f6 3c b8        LDB    $3CB8
84a6: c1 00           CMPB   #$00
84a8: 10 27 00 21     LBEQ   $84CD
84ac: cc 3c 08        LDD    #$3C08
84af: fd 3c ae        STD    $3CAE
84b2: cc 3c 15        LDD    #$3C15
84b5: fd 3c b4        STD    $3CB4
84b8: cc 3c 12        LDD    #$3C12
84bb: fd 3c b2        STD    $3CB2
84be: cc 3c 0e        LDD    #$3C0E
84c1: fd 3c b0        STD    $3CB0
84c4: cc 3c 19        LDD    #$3C19
84c7: fd 3c b6        STD    $3CB6
84ca: 16 00 1e        LBRA   $84EB
84cd: cc 3c 05        LDD    #$3C05
84d0: fd 3c ae        STD    $3CAE
84d3: cc 3c 13        LDD    #$3C13
84d6: fd 3c b4        STD    $3CB4
84d9: cc 3c 11        LDD    #$3C11
84dc: fd 3c b2        STD    $3CB2
84df: cc 3c 0b        LDD    #$3C0B
84e2: fd 3c b0        STD    $3CB0
84e5: cc 3c 17        LDD    #$3C17
84e8: fd 3c b6        STD    $3CB6
84eb: 32 62           LEAS   $2,S
84ed: 39              RTS
84ee: fc 51 3d        LDD    $513D
84f1: 17 b8 5c        LBSR   $3D50
84f4: f6 3c 1f        LDB    $3C1F
84f7: 4f              CLRA
84f8: 10 a3 e9 00 0c  CMPD   $000C,S
84fd: 10 26 00 17     LBNE   $8518
8501: ee e9 00 0a     LDU    $000A,S
8505: 10 ae e9 00 08  LDY    $0008,S
850a: ae e9 00 06     LDX    $0006,S
850e: cc 00 06        LDD    #$0006
8511: 34 76           PSHS   U,Y,X,D
8513: 17 93 d4        LBSR   $18EA
8516: 32 68           LEAS   $8,S
8518: 32 62           LEAS   $2,S
851a: 39              RTS
851b: fc 51 3d        LDD    $513D
851e: 17 b8 2f        LBSR   $3D50
8521: f6 3c 1f        LDB    $3C1F
8524: 4f              CLRA
8525: 10 a3 e9 00 0a  CMPD   $000A,S
852a: 10 26 00 13     LBNE   $8541
852e: ee e9 00 08     LDU    $0008,S
8532: 10 ae e9 00 06  LDY    $0006,S
8537: 8e 00 04        LDX    #$0004
853a: 34 70           PSHS   U,Y,X
853c: 17 66 b0        LBSR   $EBEF
853f: 32 66           LEAS   $6,S
8541: 32 62           LEAS   $2,S
8543: 39              RTS
8544: fc 51 3d        LDD    $513D
8547: 17 b8 06        LBSR   $3D50
854a: f6 3c 1f        LDB    $3C1F
854d: 4f              CLRA
854e: 10 a3 e9 00 08  CMPD   $0008,S
8553: 10 26 00 0f     LBNE   $8566
8557: ee e9 00 06     LDU    $0006,S
855b: 10 8e 00 02     LDY    #$0002
855f: 34 60           PSHS   U,Y
8561: 17 82 f1        LBSR   $0855
8564: 32 64           LEAS   $4,S
8566: 32 62           LEAS   $2,S
8568: 39              RTS
8569: fc 51 3e        LDD    $513E
856c: 17 b7 e1        LBSR   $3D50
856f: f6 3c c2        LDB    $3CC2
8572: c0 01           SUBB   #$01
8574: e7 62           STB    $2,S
8576: c6 01           LDB    #$01
8578: 1d              SEX
8579: 1f 03           TFR    D,U
857b: 10 8e ed 11     LDY    #$ED11
857f: c6 01           LDB    #$01
8581: 1d              SEX
8582: 1f 01           TFR    D,X
8584: e6 62           LDB    $2,S
8586: 4f              CLRA
8587: 34 76           PSHS   U,Y,X,D
8589: ce 00 08        LDU    #$0008
858c: 34 40           PSHS   U
858e: 17 ff 5d        LBSR   $84EE
8591: 32 6a           LEAS   $A,S
8593: e6 62           LDB    $2,S
8595: cb 01           ADDB   #$01
8597: e7 62           STB    $2,S
8599: e6 62           LDB    $2,S
859b: 4f              CLRA
859c: 1f 03           TFR    D,U
859e: 10 8e 00 02     LDY    #$0002
85a2: 34 60           PSHS   U,Y
85a4: 17 91 f9        LBSR   $17A0
85a7: 32 64           LEAS   $4,S
85a9: ce 00 00        LDU    #$0000
85ac: 34 40           PSHS   U
85ae: 17 91 b0        LBSR   $1761
85b1: 32 62           LEAS   $2,S
85b3: e7 63           STB    $3,S
85b5: e6 63           LDB    $3,S
85b7: c1 20           CMPB   #$20
85b9: 27 d8           BEQ    $8593
85bb: e6 63           LDB    $3,S
85bd: c1 30           CMPB   #$30
85bf: 10 27 00 25     LBEQ   $85E8
85c3: a6 62           LDA    $2,S
85c5: c6 01           LDB    #$01
85c7: 17 b7 c5        LBSR   $3D8F
85ca: ed 64           STD    $4,S
85cc: c6 01           LDB    #$01
85ce: 1d              SEX
85cf: 1f 03           TFR    D,U
85d1: 10 8e 3c c0     LDY    #$3CC0
85d5: c6 01           LDB    #$01
85d7: 1d              SEX
85d8: 1f 01           TFR    D,X
85da: ec 64           LDD    $4,S
85dc: 34 76           PSHS   U,Y,X,D
85de: ce 00 08        LDU    #$0008
85e1: 34 40           PSHS   U
85e3: 17 ff 08        LBSR   $84EE
85e6: 32 6a           LEAS   $A,S
85e8: 32 66           LEAS   $6,S
85ea: 39              RTS
85eb: fc 51 40        LDD    $5140
85ee: 17 b7 5f        LBSR   $3D50
85f1: ce 24 14        LDU    #$2414
85f4: 10 8e 3c b9     LDY    #$3CB9
85f8: 8e 00 04        LDX    #$0004
85fb: 34 70           PSHS   U,Y,X
85fd: 17 84 8f        LBSR   $0A8F
8600: 32 66           LEAS   $6,S
8602: ce 24 14        LDU    #$2414
8605: 10 8e 00 02     LDY    #$0002
8609: 34 60           PSHS   U,Y
860b: 17 8a 14        LBSR   $1022
860e: 32 64           LEAS   $4,S
8610: fd 3c be        STD    $3CBE
8613: f6 3c c1        LDB    $3CC1
8616: c1 00           CMPB   #$00
8618: 10 27 00 1c     LBEQ   $8638
861c: b6 3c c2        LDA    $3CC2
861f: c6 02           LDB    #$02
8621: 17 b7 6b        LBSR   $3D8F
8624: ed 62           STD    $2,S
8626: c6 01           LDB    #$01
8628: 1d              SEX
8629: 1f 03           TFR    D,U
862b: 10 ae 62        LDY    $2,S
862e: 8e 00 04        LDX    #$0004
8631: 34 70           PSHS   U,Y,X
8633: 17 ff 0e        LBSR   $8544
8636: 32 66           LEAS   $6,S
8638: c6 01           LDB    #$01
863a: 1d              SEX
863b: 1f 03           TFR    D,U
863d: 10 8e 24 14     LDY    #$2414
8641: c6 05           LDB    #$05
8643: 1d              SEX
8644: 1f 01           TFR    D,X
8646: f6 3c c2        LDB    $3CC2
8649: 4f              CLRA
864a: 34 76           PSHS   U,Y,X,D
864c: ce 00 08        LDU    #$0008
864f: 34 40           PSHS   U
8651: 17 fe 9a        LBSR   $84EE
8654: 32 6a           LEAS   $A,S
8656: c6 01           LDB    #$01
8658: 1d              SEX
8659: 1f 03           TFR    D,U
865b: 10 be 3c be     LDY    $3CBE
865f: f6 3c c3        LDB    $3CC3
8662: 4f              CLRA
8663: 1f 01           TFR    D,X
8665: cc 00 06        LDD    #$0006
8668: 34 76           PSHS   U,Y,X,D
866a: 17 fe ae        LBSR   $851B
866d: 32 68           LEAS   $8,S
866f: ce 00 00        LDU    #$0000
8672: 34 40           PSHS   U
8674: 17 fe f2        LBSR   $8569
8677: 32 62           LEAS   $2,S
8679: 32 64           LEAS   $4,S
867b: 39              RTS
867c: fc 51 3d        LDD    $513D
867f: 17 b6 ce        LBSR   $3D50
8682: f6 3c b8        LDB    $3CB8
8685: c1 00           CMPB   #$00
8687: 10 27 00 0d     LBEQ   $8698
868b: c6 60           LDB    #$60
868d: f7 3c c2        STB    $3CC2
8690: c6 66           LDB    #$66
8692: f7 3c c3        STB    $3CC3
8695: 16 00 0a        LBRA   $86A2
8698: c6 4b           LDB    #$4B
869a: f7 3c c2        STB    $3CC2
869d: c6 51           LDB    #$51
869f: f7 3c c3        STB    $3CC3
86a2: ce 00 00        LDU    #$0000
86a5: 34 40           PSHS   U
86a7: 17 ff 41        LBSR   $85EB
86aa: 32 62           LEAS   $2,S
86ac: 32 62           LEAS   $2,S
86ae: 39              RTS
86af: fc 51 3d        LDD    $513D
86b2: 17 b6 9b        LBSR   $3D50
86b5: fe 3c ae        LDU    $3CAE
86b8: 10 8e 3c b9     LDY    #$3CB9
86bc: 8e 00 04        LDX    #$0004
86bf: 34 70           PSHS   U,Y,X
86c1: 17 8c b9        LBSR   $137D
86c4: 32 66           LEAS   $6,S
86c6: e6 9f 3c b2     LDB    [$3CB2]
86ca: f7 3c c0        STB    $3CC0
86cd: 7f 3c c1        CLR    $3CC1
86d0: ce 00 00        LDU    #$0000
86d3: 34 40           PSHS   U
86d5: 8d a5           BSR    $867C
86d7: 32 62           LEAS   $2,S
86d9: fc 3c be        LDD    $3CBE
86dc: ed 9f 3c b4     STD    [$3CB4]
86e0: 32 62           LEAS   $2,S
86e2: 39              RTS
86e3: fc 51 42        LDD    $5142
86e6: 17 b6 67        LBSR   $3D50
86e9: f6 3c b8        LDB    $3CB8
86ec: e7 62           STB    $2,S
86ee: 7f 3c b8        CLR    $3CB8
86f1: ce 00 00        LDU    #$0000
86f4: 34 40           PSHS   U
86f6: 17 fd a4        LBSR   $849D
86f9: 32 62           LEAS   $2,S
86fb: ec 9f 3c b4     LDD    [$3CB4]
86ff: fd 3c be        STD    $3CBE
8702: ce 00 00        LDU    #$0000
8705: 34 40           PSHS   U
8707: 8d a6           BSR    $86AF
8709: 32 62           LEAS   $2,S
870b: c6 01           LDB    #$01
870d: f7 3c b8        STB    $3CB8
8710: ce 00 00        LDU    #$0000
8713: 34 40           PSHS   U
8715: 17 fd 85        LBSR   $849D
8718: 32 62           LEAS   $2,S
871a: ec 9f 3c b4     LDD    [$3CB4]
871e: fd 3c be        STD    $3CBE
8721: ce 00 00        LDU    #$0000
8724: 34 40           PSHS   U
8726: 8d 87           BSR    $86AF
8728: 32 62           LEAS   $2,S
872a: e6 62           LDB    $2,S
872c: f7 3c b8        STB    $3CB8
872f: ce 00 00        LDU    #$0000
8732: 34 40           PSHS   U
8734: 17 fd 66        LBSR   $849D
8737: 32 62           LEAS   $2,S
8739: 32 63           LEAS   $3,S
873b: 39              RTS
873c: fc 51 3d        LDD    $513D
873f: 17 b6 0e        LBSR   $3D50
8742: c6 20           LDB    #$20
8744: f7 3c c0        STB    $3CC0
8747: fe 3c b0        LDU    $3CB0
874a: 10 8e 3c b9     LDY    #$3CB9
874e: 8e 00 04        LDX    #$0004
8751: 34 70           PSHS   U,Y,X
8753: 17 8c 27        LBSR   $137D
8756: 32 66           LEAS   $6,S
8758: c6 01           LDB    #$01
875a: f7 3c c1        STB    $3CC1
875d: ce 00 00        LDU    #$0000
8760: 34 40           PSHS   U
8762: 17 ff 17        LBSR   $867C
8765: 32 62           LEAS   $2,S
8767: fc 3c be        LDD    $3CBE
876a: ed 9f 3c b6     STD    [$3CB6]
876e: 32 62           LEAS   $2,S
8770: 39              RTS
8771: fc 51 40        LDD    $5140
8774: 17 b5 d9        LBSR   $3D50
8777: ce 24 14        LDU    #$2414
877a: 10 be 3c bc     LDY    $3CBC
877e: 8e 00 04        LDX    #$0004
8781: 34 70           PSHS   U,Y,X
8783: 17 81 8c        LBSR   $0912
8786: 32 66           LEAS   $6,S
8788: be 3c be        LDX    $3CBE
878b: 8c 00 09        CMPX   #$0009
878e: 10 26 00 23     LBNE   $87B5
8792: 5f              CLRB
8793: 1d              SEX
8794: 1f 03           TFR    D,U
8796: 5f              CLRB
8797: 1d              SEX
8798: 1f 02           TFR    D,Y
879a: c6 05           LDB    #$05
879c: 1d              SEX
879d: 1f 01           TFR    D,X
879f: cc 24 14        LDD    #$2414
87a2: 34 76           PSHS   U,Y,X,D
87a4: ce 24 14        LDU    #$2414
87a7: 10 8e 00 0a     LDY    #$000A
87ab: 34 60           PSHS   U,Y
87ad: 17 85 a0        LBSR   $0D50
87b0: 32 6c           LEAS   $C,S
87b2: 16 00 33        LBRA   $87E8
87b5: ce 24 14        LDU    #$2414
87b8: c6 03           LDB    #$03
87ba: 1d              SEX
87bb: 1f 02           TFR    D,Y
87bd: 8e 00 04        LDX    #$0004
87c0: 34 70           PSHS   U,Y,X
87c2: 17 85 3a        LBSR   $0CFF
87c5: 32 66           LEAS   $6,S
87c7: 5f              CLRB
87c8: 1d              SEX
87c9: 1f 03           TFR    D,U
87cb: c6 03           LDB    #$03
87cd: 1d              SEX
87ce: 1f 02           TFR    D,Y
87d0: c6 05           LDB    #$05
87d2: 1d              SEX
87d3: 1f 01           TFR    D,X
87d5: cc 24 14        LDD    #$2414
87d8: 34 76           PSHS   U,Y,X,D
87da: ce 24 14        LDU    #$2414
87dd: 10 8e 00 0a     LDY    #$000A
87e1: 34 60           PSHS   U,Y
87e3: 17 85 6a        LBSR   $0D50
87e6: 32 6c           LEAS   $C,S
87e8: f6 3c c1        LDB    $3CC1
87eb: c1 00           CMPB   #$00
87ed: 10 27 00 1c     LBEQ   $880D
87f1: b6 3c c2        LDA    $3CC2
87f4: c6 01           LDB    #$01
87f6: 17 b5 96        LBSR   $3D8F
87f9: ed 62           STD    $2,S
87fb: c6 01           LDB    #$01
87fd: 1d              SEX
87fe: 1f 03           TFR    D,U
8800: 10 ae 62        LDY    $2,S
8803: 8e 00 04        LDX    #$0004
8806: 34 70           PSHS   U,Y,X
8808: 17 fd 39        LBSR   $8544
880b: 32 66           LEAS   $6,S
880d: c6 01           LDB    #$01
880f: 1d              SEX
8810: 1f 03           TFR    D,U
8812: 10 8e 24 14     LDY    #$2414
8816: c6 06           LDB    #$06
8818: 1d              SEX
8819: 1f 01           TFR    D,X
881b: f6 3c c2        LDB    $3CC2
881e: 4f              CLRA
881f: 34 76           PSHS   U,Y,X,D
8821: ce 00 08        LDU    #$0008
8824: 34 40           PSHS   U
8826: 17 fc c5        LBSR   $84EE
8829: 32 6a           LEAS   $A,S
882b: c6 01           LDB    #$01
882d: 1d              SEX
882e: 1f 03           TFR    D,U
8830: 10 be 3c be     LDY    $3CBE
8834: f6 3c c3        LDB    $3CC3
8837: 4f              CLRA
8838: 1f 01           TFR    D,X
883a: cc 00 06        LDD    #$0006
883d: 34 76           PSHS   U,Y,X,D
883f: 17 fc d9        LBSR   $851B
8842: 32 68           LEAS   $8,S
8844: 32 64           LEAS   $4,S
8846: 39              RTS
8847: fc 51 3d        LDD    $513D
884a: 17 b5 03        LBSR   $3D50
884d: c6 1e           LDB    #$1E
884f: f7 3c c2        STB    $3CC2
8852: c6 25           LDB    #$25
8854: f7 3c c3        STB    $3CC3
8857: ce 00 00        LDU    #$0000
885a: 34 40           PSHS   U
885c: 17 ff 12        LBSR   $8771
885f: 32 62           LEAS   $2,S
8861: 32 62           LEAS   $2,S
8863: 39              RTS
8864: fc 51 3d        LDD    $513D
8867: 17 b4 e6        LBSR   $3D50
886a: fc 3c 9e        LDD    $3C9E
886d: fd 3c bc        STD    $3CBC
8870: fc 3c 1b        LDD    $3C1B
8873: fd 3c be        STD    $3CBE
8876: 7f 3c c1        CLR    $3CC1
8879: ce 00 00        LDU    #$0000
887c: 34 40           PSHS   U
887e: 8d c7           BSR    $8847
8880: 32 62           LEAS   $2,S
8882: 32 62           LEAS   $2,S
8884: 39              RTS
8885: fc 51 3d        LDD    $513D
8888: 17 b4 c5        LBSR   $3D50
888b: fc 3c a0        LDD    $3CA0
888e: fd 3c bc        STD    $3CBC
8891: fc 3c 1d        LDD    $3C1D
8894: fd 3c be        STD    $3CBE
8897: c6 01           LDB    #$01
8899: f7 3c c1        STB    $3CC1
889c: ce 00 00        LDU    #$0000
889f: 34 40           PSHS   U
88a1: 8d a4           BSR    $8847
88a3: 32 62           LEAS   $2,S
88a5: 32 62           LEAS   $2,S
88a7: 39              RTS
88a8: fc 51 6d        LDD    $516D
88ab: 17 b4 a2        LBSR   $3D50
88ae: f6 3c 1f        LDB    $3C1F
88b1: c1 03           CMPB   #$03
88b3: 10 26 00 9f     LBNE   $8956
88b7: f6 3c 02        LDB    $3C02
88ba: c1 00           CMPB   #$00
88bc: 10 27 00 38     LBEQ   $88F8
88c0: f6 3c 03        LDB    $3C03
88c3: c1 00           CMPB   #$00
88c5: 10 27 00 08     LBEQ   $88D1
88c9: cc 51 44        LDD    #$5144
88cc: ed 62           STD    $2,S
88ce: 16 00 05        LBRA   $88D6
88d1: cc 51 59        LDD    #$5159
88d4: ed 62           STD    $2,S
88d6: c6 14           LDB    #$14
88d8: e7 64           STB    $4,S
88da: c6 03           LDB    #$03
88dc: 1d              SEX
88dd: 1f 03           TFR    D,U
88df: 10 ae 62        LDY    $2,S
88e2: e6 64           LDB    $4,S
88e4: 4f              CLRA
88e5: 1f 01           TFR    D,X
88e7: 5f              CLRB
88e8: 1d              SEX
88e9: 34 76           PSHS   U,Y,X,D
88eb: ce 00 08        LDU    #$0008
88ee: 34 40           PSHS   U
88f0: 17 fb fb        LBSR   $84EE
88f3: 32 6a           LEAS   $A,S
88f5: 16 00 5e        LBRA   $8956
88f8: f6 3c 04        LDB    $3C04
88fb: c1 00           CMPB   #$00
88fd: 10 27 00 39     LBEQ   $893A
8901: c6 03           LDB    #$03
8903: 1d              SEX
8904: 1f 03           TFR    D,U
8906: 10 8e 40 52     LDY    #$4052
890a: c6 14           LDB    #$14
890c: 1d              SEX
890d: 1f 01           TFR    D,X
890f: 5f              CLRB
8910: 1d              SEX
8911: 34 76           PSHS   U,Y,X,D
8913: ce 00 08        LDU    #$0008
8916: 34 40           PSHS   U
8918: 17 fb d3        LBSR   $84EE
891b: 32 6a           LEAS   $A,S
891d: ce 00 00        LDU    #$0000
8920: 34 40           PSHS   U
8922: 17 0f 17        LBSR   $983C
8925: 32 62           LEAS   $2,S
8927: c6 0e           LDB    #$0E
8929: 1d              SEX
892a: 1f 03           TFR    D,U
892c: 10 8e 00 02     LDY    #$0002
8930: 34 60           PSHS   U,Y
8932: 17 0f b4        LBSR   $98E9
8935: 32 64           LEAS   $4,S
8937: 16 00 1c        LBRA   $8956
893a: c6 03           LDB    #$03
893c: 1d              SEX
893d: 1f 03           TFR    D,U
893f: 10 8e 40 a2     LDY    #$40A2
8943: c6 14           LDB    #$14
8945: 1d              SEX
8946: 1f 01           TFR    D,X
8948: 5f              CLRB
8949: 1d              SEX
894a: 34 76           PSHS   U,Y,X,D
894c: ce 00 08        LDU    #$0008
894f: 34 40           PSHS   U
8951: 17 fb 9a        LBSR   $84EE
8954: 32 6a           LEAS   $A,S
8956: 32 65           LEAS   $5,S
8958: 39              RTS
8959: fc 51 40        LDD    $5140
895c: 17 b3 f1        LBSR   $3D50
895f: f6 3c 20        LDB    $3C20
8962: c1 00           CMPB   #$00
8964: 10 26 00 08     LBNE   $8970
8968: cc 51 6f        LDD    #$516F
896b: ed 62           STD    $2,S
896d: 16 00 16        LBRA   $8986
8970: f6 3c 20        LDB    $3C20
8973: c1 01           CMPB   #$01
8975: 10 26 00 08     LBNE   $8981
8979: cc 51 73        LDD    #$5173
897c: ed 62           STD    $2,S
897e: 16 00 05        LBRA   $8986
8981: cc 51 77        LDD    #$5177
8984: ed 62           STD    $2,S
8986: c6 01           LDB    #$01
8988: 1d              SEX
8989: 1f 03           TFR    D,U
898b: 10 ae 62        LDY    $2,S
898e: c6 03           LDB    #$03
8990: 1d              SEX
8991: 1f 01           TFR    D,X
8993: c6 0c           LDB    #$0C
8995: 1d              SEX
8996: 34 76           PSHS   U,Y,X,D
8998: ce 00 08        LDU    #$0008
899b: 34 40           PSHS   U
899d: 17 fb 4e        LBSR   $84EE
89a0: 32 6a           LEAS   $A,S
89a2: 32 64           LEAS   $4,S
89a4: 39              RTS
89a5: fc 51 3d        LDD    $513D
89a8: 17 b3 a5        LBSR   $3D50
89ab: f6 3c 1f        LDB    $3C1F
89ae: c1 01           CMPB   #$01
89b0: 10 26 00 20     LBNE   $89D4
89b4: ce 00 00        LDU    #$0000
89b7: 34 40           PSHS   U
89b9: 17 fd 27        LBSR   $86E3
89bc: 32 62           LEAS   $2,S
89be: ce 00 00        LDU    #$0000
89c1: 34 40           PSHS   U
89c3: 17 fe 9e        LBSR   $8864
89c6: 32 62           LEAS   $2,S
89c8: ce 00 00        LDU    #$0000
89cb: 34 40           PSHS   U
89cd: 8d 8a           BSR    $8959
89cf: 32 62           LEAS   $2,S
89d1: 16 00 29        LBRA   $89FD
89d4: f6 3c 1f        LDB    $3C1F
89d7: c1 02           CMPB   #$02
89d9: 10 26 00 0d     LBNE   $89EA
89dd: ce 00 00        LDU    #$0000
89e0: 34 40           PSHS   U
89e2: 17 10 2a        LBSR   $9A0F
89e5: 32 62           LEAS   $2,S
89e7: 16 00 13        LBRA   $89FD
89ea: f6 3c 1f        LDB    $3C1F
89ed: c1 03           CMPB   #$03
89ef: 10 26 00 0a     LBNE   $89FD
89f3: ce 00 00        LDU    #$0000
89f6: 34 40           PSHS   U
89f8: 17 fe ad        LBSR   $88A8
89fb: 32 62           LEAS   $2,S
89fd: 32 62           LEAS   $2,S
89ff: 39              RTS
8a00: fc 51 42        LDD    $5142
8a03: 17 b3 4a        LBSR   $3D50
8a06: be 3c ac        LDX    $3CAC
8a09: 16 01 22        LBRA   $8B2E
8a0c: e6 9f 3c b2     LDB    [$3CB2]
8a10: f7 22 85        STB    $2285
8a13: ce 22 86        LDU    #$2286
8a16: 10 be 3c ae     LDY    $3CAE
8a1a: 8e 00 04        LDX    #$0004
8a1d: 34 70           PSHS   U,Y,X
8a1f: 17 80 6d        LBSR   $0A8F
8a22: 32 66           LEAS   $6,S
8a24: 5f              CLRB
8a25: 1d              SEX
8a26: 1f 03           TFR    D,U
8a28: c6 02           LDB    #$02
8a2a: 1d              SEX
8a2b: 1f 02           TFR    D,Y
8a2d: c6 08           LDB    #$08
8a2f: 1d              SEX
8a30: 1f 01           TFR    D,X
8a32: cc 22 86        LDD    #$2286
8a35: 34 76           PSHS   U,Y,X,D
8a37: ce 22 86        LDU    #$2286
8a3a: 10 8e 00 0a     LDY    #$000A
8a3e: 34 60           PSHS   U,Y
8a40: 17 83 0d        LBSR   $0D50
8a43: 32 6c           LEAS   $C,S
8a45: c6 0a           LDB    #$0A
8a47: e7 62           STB    $2,S
8a49: 16 01 0b        LBRA   $8B57
8a4c: ce 22 85        LDU    #$2285
8a4f: 10 be 3c b0     LDY    $3CB0
8a53: 8e 00 04        LDX    #$0004
8a56: 34 70           PSHS   U,Y,X
8a58: 17 80 34        LBSR   $0A8F
8a5b: 32 66           LEAS   $6,S
8a5d: 5f              CLRB
8a5e: 1d              SEX
8a5f: 1f 03           TFR    D,U
8a61: c6 02           LDB    #$02
8a63: 1d              SEX
8a64: 1f 02           TFR    D,Y
8a66: c6 08           LDB    #$08
8a68: 1d              SEX
8a69: 1f 01           TFR    D,X
8a6b: cc 22 85        LDD    #$2285
8a6e: 34 76           PSHS   U,Y,X,D
8a70: ce 22 85        LDU    #$2285
8a73: 10 8e 00 0a     LDY    #$000A
8a77: 34 60           PSHS   U,Y
8a79: 17 82 d4        LBSR   $0D50
8a7c: 32 6c           LEAS   $C,S
8a7e: c6 09           LDB    #$09
8a80: e7 62           STB    $2,S
8a82: 16 00 d2        LBRA   $8B57
8a85: ce 22 85        LDU    #$2285
8a88: 10 be 3c 9e     LDY    $3C9E
8a8c: 8e 00 04        LDX    #$0004
8a8f: 34 70           PSHS   U,Y,X
8a91: 17 7e 7e        LBSR   $0912
8a94: 32 66           LEAS   $6,S
8a96: 5f              CLRB
8a97: 1d              SEX
8a98: 1f 03           TFR    D,U
8a9a: 5f              CLRB
8a9b: 1d              SEX
8a9c: 1f 02           TFR    D,Y
8a9e: c6 05           LDB    #$05
8aa0: 1d              SEX
8aa1: 1f 01           TFR    D,X
8aa3: cc 22 85        LDD    #$2285
8aa6: 34 76           PSHS   U,Y,X,D
8aa8: ce 22 85        LDU    #$2285
8aab: 10 8e 00 0a     LDY    #$000A
8aaf: 34 60           PSHS   U,Y
8ab1: 17 82 9c        LBSR   $0D50
8ab4: 32 6c           LEAS   $C,S
8ab6: c6 06           LDB    #$06
8ab8: e7 62           STB    $2,S
8aba: 16 00 9a        LBRA   $8B57
8abd: ce 22 85        LDU    #$2285
8ac0: 10 be 3c a0     LDY    $3CA0
8ac4: 8e 00 04        LDX    #$0004
8ac7: 34 70           PSHS   U,Y,X
8ac9: 17 7e 46        LBSR   $0912
8acc: 32 66           LEAS   $6,S
8ace: 5f              CLRB
8acf: 1d              SEX
8ad0: 1f 03           TFR    D,U
8ad2: 5f              CLRB
8ad3: 1d              SEX
8ad4: 1f 02           TFR    D,Y
8ad6: c6 05           LDB    #$05
8ad8: 1d              SEX
8ad9: 1f 01           TFR    D,X
8adb: cc 22 85        LDD    #$2285
8ade: 34 76           PSHS   U,Y,X,D
8ae0: ce 22 85        LDU    #$2285
8ae3: 10 8e 00 0a     LDY    #$000A
8ae7: 34 60           PSHS   U,Y
8ae9: 17 82 64        LBSR   $0D50
8aec: 32 6c           LEAS   $C,S
8aee: c6 06           LDB    #$06
8af0: e7 62           STB    $2,S
8af2: 16 00 62        LBRA   $8B57
8af5: cc 00 08        LDD    #$0008
8af8: fd 3c ac        STD    $3CAC
8afb: ce 00 00        LDU    #$0000
8afe: 34 40           PSHS   U
8b00: 17 11 2d        LBSR   $9C30
8b03: 32 62           LEAS   $2,S
8b05: cc 00 0b        LDD    #$000B
8b08: fd 3c ac        STD    $3CAC
8b0b: ce 00 04        LDU    #$0004
8b0e: 10 8e 00 02     LDY    #$0002
8b12: 34 60           PSHS   U,Y
8b14: be 3c 00        LDX    $3C00
8b17: ad 84           JSR    ,X
8b19: 32 64           LEAS   $4,S
8b1b: 16 00 4c        LBRA   $8B6A
8b1e: ce 00 00        LDU    #$0000
8b21: 34 40           PSHS   U
8b23: 17 11 0a        LBSR   $9C30
8b26: 32 62           LEAS   $2,S
8b28: 16 00 3f        LBRA   $8B6A
8b2b: 16 00 29        LBRA   $8B57
8b2e: 8c 00 0b        CMPX   #$000B
8b31: 10 2e 00 22     LBGT   $8B57
8b35: 1f 10           TFR    X,D
8b37: 83 00 03        SUBD   #$0003
8b3a: 10 2d 00 19     LBLT   $8B57
8b3e: 8e 4b 45        LDX    #$4B45
8b41: 58              ASLB
8b42: 49              ROLA
8b43: 6e 9b           JMP    [D,X]
8b45: 4a              DECA
8b46: 0c 4a           INC    <$4A
8b48: 4c              INCA
8b49: 4a              DECA
8b4a: 85 4a           BITA   #$4A
8b4c: bd 4b 57        JSR    $4B57
8b4f: 4b              XDECA
8b50: 1e 4b           EXG    S,DP
8b52: 1e 4b           EXG    S,DP
8b54: 1e 4a           EXG    S,CC
8b56: f5 e6 62        BITB   $E662
8b59: 4f              CLRA
8b5a: 1f 03           TFR    D,U
8b5c: 10 8e 22 85     LDY    #$2285
8b60: 8e 00 04        LDX    #$0004
8b63: 34 70           PSHS   U,Y,X
8b65: 17 54 96        LBSR   $DFFE
8b68: 32 66           LEAS   $6,S
8b6a: 32 63           LEAS   $3,S
8b6c: 39              RTS
8b6d: fc 51 40        LDD    $5140
8b70: 17 b1 dd        LBSR   $3D50
8b73: be 3c 9e        LDX    $3C9E
8b76: 8c 00 0a        CMPX   #$000A
8b79: 10 24 00 0c     LBCC   $8B89
8b7d: c6 32           LDB    #$32
8b7f: f7 3c dc        STB    $3CDC
8b82: ec e9 00 08     LDD    $0008,S
8b86: fd 3c 9e        STD    $3C9E
8b89: 32 64           LEAS   $4,S
8b8b: 39              RTS
8b8c: fc 51 80        LDD    $5180
8b8f: 17 b1 be        LBSR   $3D50
8b92: 6f 62           CLR    $2,S
8b94: 6f 63           CLR    $3,S
8b96: cc 51 7b        LDD    #$517B
8b99: ed 67           STD    $7,S
8b9b: c6 05           LDB    #$05
8b9d: e7 66           STB    $6,S
8b9f: e6 66           LDB    $6,S
8ba1: c1 00           CMPB   #$00
8ba3: 10 23 00 37     LBLS   $8BDE
8ba7: 8e 24 14        LDX    #$2414
8baa: e6 66           LDB    $6,S
8bac: 3a              ABX
8bad: e6 84           LDB    ,X
8baf: e7 64           STB    $4,S
8bb1: e6 f8 07        LDB    [$07,S]
8bb4: e7 65           STB    $5,S
8bb6: e6 65           LDB    $5,S
8bb8: eb 63           ADDB   $3,S
8bba: e7 65           STB    $5,S
8bbc: e6 65           LDB    $5,S
8bbe: e1 64           CMPB   $4,S
8bc0: 10 23 00 07     LBLS   $8BCB
8bc4: c6 01           LDB    #$01
8bc6: e7 63           STB    $3,S
8bc8: 16 00 02        LBRA   $8BCD
8bcb: 6f 63           CLR    $3,S
8bcd: e6 66           LDB    $6,S
8bcf: c0 01           SUBB   #$01
8bd1: e7 66           STB    $6,S
8bd3: ae 67           LDX    $7,S
8bd5: ec 67           LDD    $7,S
8bd7: c3 00 01        ADDD   #$0001
8bda: ed 67           STD    $7,S
8bdc: 20 c1           BRA    $8B9F
8bde: e6 63           LDB    $3,S
8be0: c1 00           CMPB   #$00
8be2: 10 26 00 09     LBNE   $8BEF
8be6: c6 32           LDB    #$32
8be8: f7 3c dc        STB    $3CDC
8beb: c6 01           LDB    #$01
8bed: e7 62           STB    $2,S
8bef: e6 62           LDB    $2,S
8bf1: e7 69           STB    $9,S
8bf3: 32 6a           LEAS   $A,S
8bf5: 39              RTS
8bf6: fc 51 42        LDD    $5142
8bf9: 17 b1 54        LBSR   $3D50
8bfc: c6 0a           LDB    #$0A
8bfe: 1d              SEX
8bff: 1f 03           TFR    D,U
8c01: 10 be 22 21     LDY    $2221
8c05: 8e 00 04        LDX    #$0004
8c08: 34 70           PSHS   U,Y,X
8c0a: 17 81 d4        LBSR   $0DE1
8c0d: 32 66           LEAS   $6,S
8c0f: e7 62           STB    $2,S
8c11: e6 62           LDB    $2,S
8c13: c1 06           CMPB   #$06
8c15: 10 24 00 25     LBCC   $8C3E
8c19: ce 00 00        LDU    #$0000
8c1c: 34 40           PSHS   U
8c1e: 17 ff 6b        LBSR   $8B8C
8c21: 32 62           LEAS   $2,S
8c23: c1 00           CMPB   #$00
8c25: 10 26 00 12     LBNE   $8C3B
8c29: ce 24 15        LDU    #$2415
8c2c: 10 8e 00 02     LDY    #$0002
8c30: 34 60           PSHS   U,Y
8c32: 17 7d 3e        LBSR   $0973
8c35: 32 64           LEAS   $4,S
8c37: ed f9 00 07     STD    [$0007,S]
8c3b: 16 00 10        LBRA   $8C4E
8c3e: e6 62           LDB    $2,S
8c40: 4f              CLRA
8c41: 10 83 00 ff     CMPD   #$00FF
8c45: 10 27 00 05     LBEQ   $8C4E
8c49: c6 32           LDB    #$32
8c4b: f7 3c dc        STB    $3CDC
8c4e: 32 63           LEAS   $3,S
8c50: 39              RTS
8c51: fc 51 3e        LDD    $513E
8c54: 17 b0 f9        LBSR   $3D50
8c57: c6 06           LDB    #$06
8c59: 1d              SEX
8c5a: 1f 03           TFR    D,U
8c5c: 10 be 22 21     LDY    $2221
8c60: 8e 00 04        LDX    #$0004
8c63: 34 70           PSHS   U,Y,X
8c65: 17 81 79        LBSR   $0DE1
8c68: 32 66           LEAS   $6,S
8c6a: e7 62           STB    $2,S
8c6c: e6 62           LDB    $2,S
8c6e: c1 09           CMPB   #$09
8c70: 10 24 00 47     LBCC   $8CBB
8c74: ce 22 1c        LDU    #$221C
8c77: 10 8e 24 14     LDY    #$2414
8c7b: 8e 00 04        LDX    #$0004
8c7e: 34 70           PSHS   U,Y,X
8c80: 17 7e 8d        LBSR   $0B10
8c83: 32 66           LEAS   $6,S
8c85: 33 63           LEAU   $3,S
8c87: 10 8e 22 1c     LDY    #$221C
8c8b: 8e ea 62        LDX    #$EA62
8c8e: cc 00 06        LDD    #$0006
8c91: 34 76           PSHS   U,Y,X,D
8c93: 17 87 30        LBSR   $13C6
8c96: 32 68           LEAS   $8,S
8c98: c1 00           CMPB   #$00
8c9a: 10 26 00 15     LBNE   $8CB3
8c9e: ce 22 1c        LDU    #$221C
8ca1: 10 ae e9 00 0a  LDY    $000A,S
8ca6: 8e 00 04        LDX    #$0004
8ca9: 34 70           PSHS   U,Y,X
8cab: 17 86 cf        LBSR   $137D
8cae: 32 66           LEAS   $6,S
8cb0: 16 00 05        LBRA   $8CB8
8cb3: c6 34           LDB    #$34
8cb5: f7 3c dc        STB    $3CDC
8cb8: 16 00 10        LBRA   $8CCB
8cbb: e6 62           LDB    $2,S
8cbd: 4f              CLRA
8cbe: 10 83 00 ff     CMPD   #$00FF
8cc2: 10 27 00 05     LBEQ   $8CCB
8cc6: c6 34           LDB    #$34
8cc8: f7 3c dc        STB    $3CDC
8ccb: 32 66           LEAS   $6,S
8ccd: 39              RTS
8cce: fc 51 6d        LDD    $516D
8cd1: 17 b0 7c        LBSR   $3D50
8cd4: be 3c ac        LDX    $3CAC
8cd7: 16 01 92        LBRA   $8E6C
8cda: fe 3c ae        LDU    $3CAE
8cdd: 10 8e 00 02     LDY    #$0002
8ce1: 34 60           PSHS   U,Y
8ce3: 17 ff 6b        LBSR   $8C51
8ce6: 32 64           LEAS   $4,S
8ce8: f6 3c dc        LDB    $3CDC
8ceb: c1 00           CMPB   #$00
8ced: 10 26 00 11     LBNE   $8D02
8cf1: f6 24 1e        LDB    $241E
8cf4: e7 9f 3c b2     STB    [$3CB2]
8cf8: ce 00 00        LDU    #$0000
8cfb: 34 40           PSHS   U
8cfd: 17 05 23        LBSR   $9223
8d00: 32 62           LEAS   $2,S
8d02: fc 22 21        LDD    $2221
8d05: ed 9f 3c b4     STD    [$3CB4]
8d09: ce 00 00        LDU    #$0000
8d0c: 34 40           PSHS   U
8d0e: 17 f9 9e        LBSR   $86AF
8d11: 32 62           LEAS   $2,S
8d13: ce 00 01        LDU    #$0001
8d16: 10 8e 00 02     LDY    #$0002
8d1a: 34 60           PSHS   U,Y
8d1c: be 3c 00        LDX    $3C00
8d1f: ad 84           JSR    ,X
8d21: 32 64           LEAS   $4,S
8d23: 16 01 71        LBRA   $8E97
8d26: fe 3c b0        LDU    $3CB0
8d29: 10 8e 00 02     LDY    #$0002
8d2d: 34 60           PSHS   U,Y
8d2f: 17 ff 1f        LBSR   $8C51
8d32: 32 64           LEAS   $4,S
8d34: fc 22 21        LDD    $2221
8d37: ed 9f 3c b6     STD    [$3CB6]
8d3b: cc 00 03        LDD    #$0003
8d3e: fd 3c ac        STD    $3CAC
8d41: ce 00 00        LDU    #$0000
8d44: 34 40           PSHS   U
8d46: 17 f9 66        LBSR   $86AF
8d49: 32 62           LEAS   $2,S
8d4b: ce 00 01        LDU    #$0001
8d4e: 10 8e 00 02     LDY    #$0002
8d52: 34 60           PSHS   U,Y
8d54: be 3c 00        LDX    $3C00
8d57: ad 84           JSR    ,X
8d59: 32 64           LEAS   $4,S
8d5b: 16 01 39        LBRA   $8E97
8d5e: fc 3c 9e        LDD    $3C9E
8d61: ed 62           STD    $2,S
8d63: ce 3c 9e        LDU    #$3C9E
8d66: 10 8e 00 02     LDY    #$0002
8d6a: 34 60           PSHS   U,Y
8d6c: 17 fe 87        LBSR   $8BF6
8d6f: 32 64           LEAS   $4,S
8d71: fc 22 21        LDD    $2221
8d74: fd 3c 1b        STD    $3C1B
8d77: ee 62           LDU    $2,S
8d79: 10 8e 00 02     LDY    #$0002
8d7d: 34 60           PSHS   U,Y
8d7f: 17 fd eb        LBSR   $8B6D
8d82: 32 64           LEAS   $4,S
8d84: fc 3c 9e        LDD    $3C9E
8d87: 83 00 01        SUBD   #$0001
8d8a: fd 10 04        STD    $1004
8d8d: ce 00 00        LDU    #$0000
8d90: 34 40           PSHS   U
8d92: 17 fa cf        LBSR   $8864
8d95: 32 62           LEAS   $2,S
8d97: ce 00 02        LDU    #$0002
8d9a: 10 8e 00 02     LDY    #$0002
8d9e: 34 60           PSHS   U,Y
8da0: be 3c 00        LDX    $3C00
8da3: ad 84           JSR    ,X
8da5: 32 64           LEAS   $4,S
8da7: 16 00 ed        LBRA   $8E97
8daa: ce 3c a0        LDU    #$3CA0
8dad: 10 8e 00 02     LDY    #$0002
8db1: 34 60           PSHS   U,Y
8db3: 17 fe 40        LBSR   $8BF6
8db6: 32 64           LEAS   $4,S
8db8: fc 22 21        LDD    $2221
8dbb: fd 3c 1d        STD    $3C1D
8dbe: cc 00 05        LDD    #$0005
8dc1: fd 3c ac        STD    $3CAC
8dc4: ce 00 00        LDU    #$0000
8dc7: 34 40           PSHS   U
8dc9: 17 fa 98        LBSR   $8864
8dcc: 32 62           LEAS   $2,S
8dce: ce 00 02        LDU    #$0002
8dd1: 10 8e 00 02     LDY    #$0002
8dd5: 34 60           PSHS   U,Y
8dd7: be 3c 00        LDX    $3C00
8dda: ad 84           JSR    ,X
8ddc: 32 64           LEAS   $4,S
8dde: 16 00 b6        LBRA   $8E97
8de1: fe 3c ac        LDU    $3CAC
8de4: 10 8e 00 02     LDY    #$0002
8de8: 34 60           PSHS   U,Y
8dea: 17 12 cf        LBSR   $A0BC
8ded: 32 64           LEAS   $4,S
8def: ce 00 00        LDU    #$0000
8df2: 34 40           PSHS   U
8df4: 17 06 e8        LBSR   $94DF
8df7: 32 62           LEAS   $2,S
8df9: e7 64           STB    $4,S
8dfb: f6 3c 04        LDB    $3C04
8dfe: 4f              CLRA
8dff: 1f 03           TFR    D,U
8e01: e6 64           LDB    $4,S
8e03: 4f              CLRA
8e04: 1f 02           TFR    D,Y
8e06: 8e 00 04        LDX    #$0004
8e09: 34 70           PSHS   U,Y,X
8e0b: 17 03 e8        LBSR   $91F6
8e0e: 32 66           LEAS   $6,S
8e10: ce 00 04        LDU    #$0004
8e13: 10 8e 00 02     LDY    #$0002
8e17: 34 60           PSHS   U,Y
8e19: be 3c 00        LDX    $3C00
8e1c: ad 84           JSR    ,X
8e1e: 32 64           LEAS   $4,S
8e20: 16 00 74        LBRA   $8E97
8e23: fe 3c ac        LDU    $3CAC
8e26: 10 8e 00 02     LDY    #$0002
8e2a: 34 60           PSHS   U,Y
8e2c: 17 12 8d        LBSR   $A0BC
8e2f: 32 64           LEAS   $4,S
8e31: ce 00 00        LDU    #$0000
8e34: 34 40           PSHS   U
8e36: 17 06 a6        LBSR   $94DF
8e39: 32 62           LEAS   $2,S
8e3b: e7 64           STB    $4,S
8e3d: f6 3c 04        LDB    $3C04
8e40: 4f              CLRA
8e41: 1f 03           TFR    D,U
8e43: e6 64           LDB    $4,S
8e45: 4f              CLRA
8e46: 1f 02           TFR    D,Y
8e48: 8e 00 04        LDX    #$0004
8e4b: 34 70           PSHS   U,Y,X
8e4d: 17 03 a6        LBSR   $91F6
8e50: 32 66           LEAS   $6,S
8e52: 16 00 42        LBRA   $8E97
8e55: f6 22 19        LDB    $2219
8e58: 4f              CLRA
8e59: 1f 03           TFR    D,U
8e5b: 10 8e 00 02     LDY    #$0002
8e5f: 34 60           PSHS   U,Y
8e61: 17 05 e9        LBSR   $944D
8e64: 32 64           LEAS   $4,S
8e66: 16 00 2e        LBRA   $8E97
8e69: 16 00 2b        LBRA   $8E97
8e6c: 8c 00 0c        CMPX   #$000C
8e6f: 10 2e 00 24     LBGT   $8E97
8e73: 1f 10           TFR    X,D
8e75: 83 00 03        SUBD   #$0003
8e78: 10 2d 00 1b     LBLT   $8E97
8e7c: 8e 4e 83        LDX    #$4E83
8e7f: 58              ASLB
8e80: 49              ROLA
8e81: 6e 9b           JMP    [D,X]
8e83: 4c              INCA
8e84: da 4d           ORB    <$4D
8e86: 26 4d           BNE    $8ED5
8e88: 5e              XCLRB
8e89: 4d              TSTA
8e8a: aa 4e           ORA    $E,U
8e8c: 97 4e           STA    <$4E
8e8e: 23 4e           BLS    $8EDE
8e90: 23 4e           BLS    $8EE0
8e92: 23 4d           BLS    $8EE1
8e94: e1 4e           CMPB   $E,U
8e96: 55              LSRB
8e97: 32 65           LEAS   $5,S
8e99: 39              RTS
8e9a: fc 51 80        LDD    $5180
8e9d: 17 ae b0        LBSR   $3D50
8ea0: c6 01           LDB    #$01
8ea2: e7 63           STB    $3,S
8ea4: be 3c ac        LDX    $3CAC
8ea7: 16 02 65        LBRA   $910F
8eaa: cc 00 03        LDD    #$0003
8ead: fd 3c ac        STD    $3CAC
8eb0: e6 9f 3c b2     LDB    [$3CB2]
8eb4: c1 2d           CMPB   #$2D
8eb6: 10 26 00 0c     LBNE   $8EC6
8eba: ec e9 00 0e     LDD    $000E,S
8ebe: 88 00           EORA   #$00
8ec0: c8 01           EORB   #$01
8ec2: ed e9 00 0e     STD    $000E,S
8ec6: ae e9 00 0e     LDX    $000E,S
8eca: 8c 00 00        CMPX   #$0000
8ecd: 10 27 00 1e     LBEQ   $8EEF
8ed1: ce 22 1c        LDU    #$221C
8ed4: 10 be 3c b0     LDY    $3CB0
8ed8: be 3c ae        LDX    $3CAE
8edb: cc 00 06        LDD    #$0006
8ede: 34 76           PSHS   U,Y,X,D
8ee0: 17 84 af        LBSR   $1392
8ee3: 32 68           LEAS   $8,S
8ee5: c1 00           CMPB   #$00
8ee7: 17 ae cc        LBSR   $3DB6
8eea: e7 63           STB    $3,S
8eec: 16 00 47        LBRA   $8F36
8eef: ce 22 1c        LDU    #$221C
8ef2: 10 be 3c b0     LDY    $3CB0
8ef6: be 3c ae        LDX    $3CAE
8ef9: cc 00 06        LDD    #$0006
8efc: 34 76           PSHS   U,Y,X,D
8efe: 17 84 c5        LBSR   $13C6
8f01: 32 68           LEAS   $8,S
8f03: c1 00           CMPB   #$00
8f05: 10 27 00 2d     LBEQ   $8F36
8f09: ce 22 1c        LDU    #$221C
8f0c: 10 be 3c ae     LDY    $3CAE
8f10: be 3c b0        LDX    $3CB0
8f13: cc 00 06        LDD    #$0006
8f16: 34 76           PSHS   U,Y,X,D
8f18: 17 84 ab        LBSR   $13C6
8f1b: 32 68           LEAS   $8,S
8f1d: e6 9f 3c b2     LDB    [$3CB2]
8f21: c1 2d           CMPB   #$2D
8f23: 10 26 00 09     LBNE   $8F30
8f27: c6 2b           LDB    #$2B
8f29: e7 9f 3c b2     STB    [$3CB2]
8f2d: 16 00 06        LBRA   $8F36
8f30: c6 2d           LDB    #$2D
8f32: e7 9f 3c b2     STB    [$3CB2]
8f36: e6 63           LDB    $3,S
8f38: c1 00           CMPB   #$00
8f3a: 10 27 00 34     LBEQ   $8F72
8f3e: 33 66           LEAU   $6,S
8f40: 10 8e 22 1c     LDY    #$221C
8f44: 8e ea 62        LDX    #$EA62
8f47: cc 00 06        LDD    #$0006
8f4a: 34 76           PSHS   U,Y,X,D
8f4c: 17 84 77        LBSR   $13C6
8f4f: 32 68           LEAS   $8,S
8f51: c1 00           CMPB   #$00
8f53: 10 26 00 1b     LBNE   $8F72
8f57: ce 22 1c        LDU    #$221C
8f5a: 10 be 3c ae     LDY    $3CAE
8f5e: 8e 00 04        LDX    #$0004
8f61: 34 70           PSHS   U,Y,X
8f63: 17 84 17        LBSR   $137D
8f66: 32 66           LEAS   $6,S
8f68: ce 00 00        LDU    #$0000
8f6b: 34 40           PSHS   U
8f6d: 17 02 b3        LBSR   $9223
8f70: 32 62           LEAS   $2,S
8f72: ce 00 00        LDU    #$0000
8f75: 34 40           PSHS   U
8f77: 17 f7 35        LBSR   $86AF
8f7a: 32 62           LEAS   $2,S
8f7c: ce 00 01        LDU    #$0001
8f7f: 10 8e 00 02     LDY    #$0002
8f83: 34 60           PSHS   U,Y
8f85: be 3c 00        LDX    $3C00
8f88: ad 84           JSR    ,X
8f8a: 32 64           LEAS   $4,S
8f8c: 16 01 ab        LBRA   $913A
8f8f: cc 00 05        LDD    #$0005
8f92: fd 3c ac        STD    $3CAC
8f95: fc 3c 9e        LDD    $3C9E
8f98: ed 64           STD    $4,S
8f9a: ae e9 00 0e     LDX    $000E,S
8f9e: 8c 00 00        CMPX   #$0000
8fa1: 10 27 00 1e     LBEQ   $8FC3
8fa5: ce 22 1a        LDU    #$221A
8fa8: 10 be 3c a0     LDY    $3CA0
8fac: be 3c 9e        LDX    $3C9E
8faf: cc 00 06        LDD    #$0006
8fb2: 34 76           PSHS   U,Y,X,D
8fb4: 17 f2 79        LBSR   $8230
8fb7: 32 68           LEAS   $8,S
8fb9: c1 00           CMPB   #$00
8fbb: 17 ad f8        LBSR   $3DB6
8fbe: e7 63           STB    $3,S
8fc0: 16 00 18        LBRA   $8FDB
8fc3: be 3c 9e        LDX    $3C9E
8fc6: bc 3c a0        CMPX   $3CA0
8fc9: 10 25 00 0c     LBCS   $8FD9
8fcd: fc 3c 9e        LDD    $3C9E
8fd0: b3 3c a0        SUBD   $3CA0
8fd3: fd 22 1a        STD    $221A
8fd6: 16 00 02        LBRA   $8FDB
8fd9: 6f 63           CLR    $3,S
8fdb: e6 63           LDB    $3,S
8fdd: c1 00           CMPB   #$00
8fdf: 10 27 00 1f     LBEQ   $9002
8fe3: fc 22 1a        LDD    $221A
8fe6: fd 3c 9e        STD    $3C9E
8fe9: ee 64           LDU    $4,S
8feb: 10 8e 00 02     LDY    #$0002
8fef: 34 60           PSHS   U,Y
8ff1: 17 fb 79        LBSR   $8B6D
8ff4: 32 64           LEAS   $4,S
8ff6: fc 3c 9e        LDD    $3C9E
8ff9: 83 00 01        SUBD   #$0001
8ffc: fd 10 04        STD    $1004
8fff: 7f 3c dc        CLR    $3CDC
9002: ce 00 00        LDU    #$0000
9005: 34 40           PSHS   U
9007: 17 f8 5a        LBSR   $8864
900a: 32 62           LEAS   $2,S
900c: ce 00 02        LDU    #$0002
900f: 10 8e 00 02     LDY    #$0002
9013: 34 60           PSHS   U,Y
9015: be 3c 00        LDX    $3C00
9018: ad 84           JSR    ,X
901a: 32 64           LEAS   $4,S
901c: 16 01 1b        LBRA   $913A
901f: ee e9 00 0e     LDU    $000E,S
9023: 10 8e 00 02     LDY    #$0002
9027: 34 60           PSHS   U,Y
9029: 17 0d dc        LBSR   $9E08
902c: 32 64           LEAS   $4,S
902e: ce 00 00        LDU    #$0000
9031: 34 40           PSHS   U
9033: 17 04 a9        LBSR   $94DF
9036: 32 62           LEAS   $2,S
9038: e7 69           STB    $9,S
903a: f6 3c 04        LDB    $3C04
903d: 4f              CLRA
903e: 1f 03           TFR    D,U
9040: e6 69           LDB    $9,S
9042: 4f              CLRA
9043: 1f 02           TFR    D,Y
9045: 8e 00 04        LDX    #$0004
9048: 34 70           PSHS   U,Y,X
904a: 17 01 a9        LBSR   $91F6
904d: 32 66           LEAS   $6,S
904f: ce 00 04        LDU    #$0004
9052: 10 8e 00 02     LDY    #$0002
9056: 34 60           PSHS   U,Y
9058: be 3c 00        LDX    $3C00
905b: ad 84           JSR    ,X
905d: 32 64           LEAS   $4,S
905f: 16 00 d8        LBRA   $913A
9062: ee e9 00 0e     LDU    $000E,S
9066: 10 8e 00 02     LDY    #$0002
906a: 34 60           PSHS   U,Y
906c: 17 0d 99        LBSR   $9E08
906f: 32 64           LEAS   $4,S
9071: ce 00 00        LDU    #$0000
9074: 34 40           PSHS   U
9076: 17 04 66        LBSR   $94DF
9079: 32 62           LEAS   $2,S
907b: e7 69           STB    $9,S
907d: f6 3c 04        LDB    $3C04
9080: 4f              CLRA
9081: 1f 03           TFR    D,U
9083: e6 69           LDB    $9,S
9085: 4f              CLRA
9086: 1f 02           TFR    D,Y
9088: 8e 00 04        LDX    #$0004
908b: 34 70           PSHS   U,Y,X
908d: 17 01 66        LBSR   $91F6
9090: 32 66           LEAS   $6,S
9092: 16 00 a5        LBRA   $913A
9095: f6 3c 20        LDB    $3C20
9098: e7 62           STB    $2,S
909a: ae e9 00 0e     LDX    $000E,S
909e: 8c 00 00        CMPX   #$0000
90a1: 10 27 00 09     LBEQ   $90AE
90a5: e6 62           LDB    $2,S
90a7: cb 01           ADDB   #$01
90a9: e7 62           STB    $2,S
90ab: 16 00 06        LBRA   $90B4
90ae: e6 62           LDB    $2,S
90b0: c0 01           SUBB   #$01
90b2: e7 62           STB    $2,S
90b4: e6 62           LDB    $2,S
90b6: c1 03           CMPB   #$03
90b8: 10 26 00 05     LBNE   $90C1
90bc: 6f 62           CLR    $2,S
90be: 16 00 0f        LBRA   $90D0
90c1: e6 62           LDB    $2,S
90c3: 4f              CLRA
90c4: 10 83 00 ff     CMPD   #$00FF
90c8: 10 26 00 04     LBNE   $90D0
90cc: c6 02           LDB    #$02
90ce: e7 62           STB    $2,S
90d0: e6 62           LDB    $2,S
90d2: 4f              CLRA
90d3: 1f 03           TFR    D,U
90d5: 10 8e 00 02     LDY    #$0002
90d9: 34 60           PSHS   U,Y
90db: 17 06 0b        LBSR   $96E9
90de: 32 64           LEAS   $4,S
90e0: ce 00 00        LDU    #$0000
90e3: 34 40           PSHS   U
90e5: 17 f8 71        LBSR   $8959
90e8: 32 62           LEAS   $2,S
90ea: ce 00 00        LDU    #$0000
90ed: 34 40           PSHS   U
90ef: 17 09 1d        LBSR   $9A0F
90f2: 32 62           LEAS   $2,S
90f4: ce 00 06        LDU    #$0006
90f7: 10 8e 00 02     LDY    #$0002
90fb: 34 60           PSHS   U,Y
90fd: be 3c 00        LDX    $3C00
9100: ad 84           JSR    ,X
9102: 32 64           LEAS   $4,S
9104: 16 00 33        LBRA   $913A
9107: c6 04           LDB    #$04
9109: f7 3c dc        STB    $3CDC
910c: 16 00 2b        LBRA   $913A
910f: 8c 00 0e        CMPX   #$000E
9112: 2e f3           BGT    $9107
9114: 1f 10           TFR    X,D
9116: 83 00 03        SUBD   #$0003
9119: 2d ec           BLT    $9107
911b: 8e 51 22        LDX    #$5122
911e: 58              ASLB
911f: 49              ROLA
9120: 6e 9b           JMP    [D,X]
9122: 4e              XCLRA
9123: b0 4e aa        SUBA   $4EAA
9126: 4f              CLRA
9127: 95 4f           BITA   <$4F
9129: 8f 51 07        XSTX   #$5107
912c: 50              NEGB
912d: 62 50           XNC    -$10,U
912f: 62 50           XNC    -$10,U
9131: 62 50           XNC    -$10,U
9133: 1f 51           TFR    PC,X
9135: 07 51           ASR    <$51
9137: 07 50           ASR    <$50
9139: 95 32           BITA   <$32
913b: 6a 39           DEC    -$7,Y
913d: 00 00           NEG    <$00
913f: 04 00           LSR    <$00
9141: 02 00           XNC    <$00
9143: 01 2a           NEG    <$2A
9145: 2a 20           BPL    $9167
9147: 52              XNCB
9148: 75 6e 6e        LSR    $6E6E
914b: 69 6e           ROL    $E,S
914d: 67 20           ASR    $0,Y
914f: 53              COMB
9150: 69 6e           ROL    $E,S
9152: 67 6c           ASR    $C,S
9154: 65 20           LSR    $0,Y
9156: 2a 2a           BPL    $9182
9158: 00 2a           NEG    <$2A
915a: 2a 20           BPL    $917C
915c: 52              XNCB
915d: 75 6e 6e        LSR    $6E6E
9160: 69 6e           ROL    $E,S
9162: 67 20           ASR    $0,Y
9164: 43              COMA
9165: 6f 6e           CLR    $E,S
9167: 74 20 2a        LSR    $202A
916a: 2a 20           BPL    $918C
916c: 20 00           BRA    $916E
916e: 03 42           COM    <$42
9170: 69 6e           ROL    $E,S
9172: 00 4f           NEG    <$4F
9174: 63 74           COM    -$C,S
9176: 00 48           NEG    <$48
9178: 65 78           LSR    -$8,S
917a: 00 36           NEG    <$36
917c: 33 35           LEAU   -$B,Y
917e: 35 36           PULS   D,X,Y
9180: 00 08           NEG    <$08
9182: fc 54 d4        LDD    $54D4
9185: 17 ab c8        LBSR   $3D50
9188: e6 e9 00 07     LDB    $0007,S
918c: f7 24 b5        STB    $24B5
918f: ee e9 00 06     LDU    $0006,S
9193: c6 1c           LDB    #$1C
9195: 1d              SEX
9196: 1f 02           TFR    D,Y
9198: 8e 00 04        LDX    #$0004
919b: 34 70           PSHS   U,Y,X
919d: 17 8c cf        LBSR   $1E6F
91a0: 32 66           LEAS   $6,S
91a2: 32 62           LEAS   $2,S
91a4: 39              RTS
91a5: fc 54 d4        LDD    $54D4
91a8: 17 ab a5        LBSR   $3D50
91ab: e6 e9 00 07     LDB    $0007,S
91af: f7 24 bb        STB    $24BB
91b2: ee e9 00 06     LDU    $0006,S
91b6: c6 22           LDB    #$22
91b8: 1d              SEX
91b9: 1f 02           TFR    D,Y
91bb: 8e 00 04        LDX    #$0004
91be: 34 70           PSHS   U,Y,X
91c0: 17 8c ac        LBSR   $1E6F
91c3: 32 66           LEAS   $6,S
91c5: 32 62           LEAS   $2,S
91c7: 39              RTS
91c8: fc 54 d5        LDD    $54D5
91cb: 17 ab 82        LBSR   $3D50
91ce: ae e9 00 07     LDX    $0007,S
91d2: 8c 00 00        CMPX   #$0000
91d5: 10 26 00 07     LBNE   $91E0
91d9: c6 22           LDB    #$22
91db: e7 62           STB    $2,S
91dd: 16 00 04        LBRA   $91E4
91e0: c6 20           LDB    #$20
91e2: e7 62           STB    $2,S
91e4: e6 62           LDB    $2,S
91e6: 4f              CLRA
91e7: 1f 03           TFR    D,U
91e9: 10 8e 00 02     LDY    #$0002
91ed: 34 60           PSHS   U,Y
91ef: 8d b4           BSR    $91A5
91f1: 32 64           LEAS   $4,S
91f3: 32 63           LEAS   $3,S
91f5: 39              RTS
91f6: fc 54 d4        LDD    $54D4
91f9: 17 ab 54        LBSR   $3D50
91fc: ae e9 00 08     LDX    $0008,S
9200: 8c 00 00        CMPX   #$0000
9203: 10 27 00 19     LBEQ   $9220
9207: ae e9 00 06     LDX    $0006,S
920b: 8c 00 02        CMPX   #$0002
920e: 10 24 00 0e     LBCC   $9220
9212: ee e9 00 06     LDU    $0006,S
9216: 10 8e 00 02     LDY    #$0002
921a: 34 60           PSHS   U,Y
921c: 8d aa           BSR    $91C8
921e: 32 64           LEAS   $4,S
9220: 32 62           LEAS   $2,S
9222: 39              RTS
9223: fc 54 d7        LDD    $54D7
9226: 17 ab 27        LBSR   $3D50
9229: 6f 62           CLR    $2,S
922b: f6 3c b8        LDB    $3CB8
922e: e7 65           STB    $5,S
9230: f6 24 bb        LDB    $24BB
9233: e7 66           STB    $6,S
9235: c6 23           LDB    #$23
9237: 1d              SEX
9238: 1f 03           TFR    D,U
923a: 10 8e 00 02     LDY    #$0002
923e: 34 60           PSHS   U,Y
9240: 17 ff 62        LBSR   $91A5
9243: 32 64           LEAS   $4,S
9245: ce 22 1c        LDU    #$221C
9248: 10 8e 3c 08     LDY    #$3C08
924c: 8e 3c 05        LDX    #$3C05
924f: cc 00 06        LDD    #$0006
9252: 34 76           PSHS   U,Y,X,D
9254: 17 81 6f        LBSR   $13C6
9257: 32 68           LEAS   $8,S
9259: c1 00           CMPB   #$00
925b: 10 27 00 08     LBEQ   $9267
925f: c6 01           LDB    #$01
9261: f7 3c b8        STB    $3CB8
9264: 16 00 03        LBRA   $926A
9267: 7f 3c b8        CLR    $3CB8
926a: ce 00 00        LDU    #$0000
926d: 34 40           PSHS   U
926f: 17 f2 2b        LBSR   $849D
9272: 32 62           LEAS   $2,S
9274: be 23 bf        LDX    $23BF
9277: 30 88 14        LEAX   $14,X
927a: e6 9f 3c b2     LDB    [$3CB2]
927e: e7 84           STB    ,X
9280: be 23 bf        LDX    $23BF
9283: 30 0a           LEAX   $A,X
9285: fe 3c ae        LDU    $3CAE
9288: 1f 12           TFR    X,Y
928a: 8e 00 04        LDX    #$0004
928d: 34 70           PSHS   U,Y,X
928f: 17 80 eb        LBSR   $137D
9292: 32 66           LEAS   $6,S
9294: fe 3c ae        LDU    $3CAE
9297: 5f              CLRB
9298: 1d              SEX
9299: 1f 02           TFR    D,Y
929b: 8e 00 04        LDX    #$0004
929e: 34 70           PSHS   U,Y,X
92a0: 17 6d c6        LBSR   $0069
92a3: 32 66           LEAS   $6,S
92a5: 33 69           LEAU   $9,S
92a7: 10 be 3c ae     LDY    $3CAE
92ab: 5f              CLRB
92ac: 1d              SEX
92ad: 1f 01           TFR    D,X
92af: cc 00 06        LDD    #$0006
92b2: 34 76           PSHS   U,Y,X,D
92b4: 17 81 35        LBSR   $13EC
92b7: 32 68           LEAS   $8,S
92b9: e7 63           STB    $3,S
92bb: 86 01           LDA    #$01
92bd: f6 3c b8        LDB    $3CB8
92c0: 17 aa cc        LBSR   $3D8F
92c3: f7 3c b8        STB    $3CB8
92c6: ce 00 00        LDU    #$0000
92c9: 34 40           PSHS   U
92cb: 17 f1 cf        LBSR   $849D
92ce: 32 62           LEAS   $2,S
92d0: be 23 bf        LDX    $23BF
92d3: 30 88 14        LEAX   $14,X
92d6: e6 9f 3c b2     LDB    [$3CB2]
92da: e7 84           STB    ,X
92dc: be 23 bf        LDX    $23BF
92df: 30 0a           LEAX   $A,X
92e1: fe 3c ae        LDU    $3CAE
92e4: 1f 12           TFR    X,Y
92e6: 8e 00 04        LDX    #$0004
92e9: 34 70           PSHS   U,Y,X
92eb: 17 80 8f        LBSR   $137D
92ee: 32 66           LEAS   $6,S
92f0: 33 67           LEAU   $7,S
92f2: 10 be 3c ae     LDY    $3CAE
92f6: 5f              CLRB
92f7: 1d              SEX
92f8: 1f 01           TFR    D,X
92fa: cc 00 06        LDD    #$0006
92fd: 34 76           PSHS   U,Y,X,D
92ff: 17 80 ea        LBSR   $13EC
9302: 32 68           LEAS   $8,S
9304: e7 64           STB    $4,S
9306: ae 67           LDX    $7,S
9308: 8c 08 00        CMPX   #$0800
930b: 10 2d 00 0b     LBLT   $931A
930f: cc 10 00        LDD    #$1000
9312: a3 67           SUBD   $7,S
9314: ed 67           STD    $7,S
9316: c6 01           LDB    #$01
9318: e7 62           STB    $2,S
931a: a6 64           LDA    $4,S
931c: e6 63           LDB    $3,S
931e: 17 aa 6e        LBSR   $3D8F
9321: 17 ab 35        LBSR   $3E59
9324: ae 67           LDX    $7,S
9326: 17 ac 7b        LBSR   $3FA4
9329: ed 67           STD    $7,S
932b: e6 62           LDB    $2,S
932d: c1 00           CMPB   #$00
932f: 10 27 00 15     LBEQ   $9348
9333: cc 0f ff        LDD    #$0FFF
9336: a3 67           SUBD   $7,S
9338: ed 67           STD    $7,S
933a: ae 67           LDX    $7,S
933c: 8c 08 00        CMPX   #$0800
933f: 10 26 00 05     LBNE   $9348
9343: cc 08 01        LDD    #$0801
9346: ed 67           STD    $7,S
9348: f6 3c b8        LDB    $3CB8
934b: c1 00           CMPB   #$00
934d: 10 26 00 14     LBNE   $9365
9351: ee 67           LDU    $7,S
9353: 5f              CLRB
9354: 1d              SEX
9355: 1f 02           TFR    D,Y
9357: 8e 00 04        LDX    #$0004
935a: 34 70           PSHS   U,Y,X
935c: 17 91 19        LBSR   $2478
935f: 32 66           LEAS   $6,S
9361: ec 69           LDD    $9,S
9363: ed 67           STD    $7,S
9365: ee 67           LDU    $7,S
9367: c6 02           LDB    #$02
9369: 1d              SEX
936a: 1f 02           TFR    D,Y
936c: 8e 00 04        LDX    #$0004
936f: 34 70           PSHS   U,Y,X
9371: 17 91 04        LBSR   $2478
9374: 32 66           LEAS   $6,S
9376: e6 65           LDB    $5,S
9378: f7 3c b8        STB    $3CB8
937b: ce 00 00        LDU    #$0000
937e: 34 40           PSHS   U
9380: 17 f1 1a        LBSR   $849D
9383: 32 62           LEAS   $2,S
9385: e6 66           LDB    $6,S
9387: 4f              CLRA
9388: 1f 03           TFR    D,U
938a: 10 8e 00 02     LDY    #$0002
938e: 34 60           PSHS   U,Y
9390: 17 fe 12        LBSR   $91A5
9393: 32 64           LEAS   $4,S
9395: 32 6b           LEAS   $B,S
9397: 39              RTS
9398: fc 54 d5        LDD    $54D5
939b: 17 a9 b2        LBSR   $3D50
939e: cc ff ff        LDD    #$FFFF
93a1: fd 3c c4        STD    $3CC4
93a4: 8e 3c 21        LDX    #$3C21
93a7: 30 1f           LEAX   -$1,X
93a9: bf 3c c6        STX    $3CC6
93ac: 7f 3c c9        CLR    $3CC9
93af: 7f 3c c8        CLR    $3CC8
93b2: cc 00 c8        LDD    #$00C8
93b5: fd 10 04        STD    $1004
93b8: c6 01           LDB    #$01
93ba: f7 10 01        STB    $1001
93bd: f6 24 21        LDB    $2421
93c0: ca 01           ORB    #$01
93c2: e7 62           STB    $2,S
93c4: e6 62           LDB    $2,S
93c6: f7 10 00        STB    $1000
93c9: e6 62           LDB    $2,S
93cb: 4f              CLRA
93cc: 84 00           ANDA   #$00
93ce: c4 fe           ANDB   #$FE
93d0: e7 62           STB    $2,S
93d2: e6 62           LDB    $2,S
93d4: f7 10 00        STB    $1000
93d7: c6 d1           LDB    #$D1
93d9: f7 24 22        STB    $2422
93dc: f6 24 22        LDB    $2422
93df: f7 10 01        STB    $1001
93e2: 32 63           LEAS   $3,S
93e4: 39              RTS
93e5: fc 54 d4        LDD    $54D4
93e8: 17 a9 65        LBSR   $3D50
93eb: c6 91           LDB    #$91
93ed: f7 24 22        STB    $2422
93f0: f6 24 22        LDB    $2422
93f3: f7 10 01        STB    $1001
93f6: 32 62           LEAS   $2,S
93f8: 39              RTS
93f9: fc 54 d5        LDD    $54D5
93fc: 17 a9 51        LBSR   $3D50
93ff: ce 00 00        LDU    #$0000
9402: 34 40           PSHS   U
9404: 17 83 7a        LBSR   $1781
9407: 32 62           LEAS   $2,S
9409: e7 62           STB    $2,S
940b: ce 00 00        LDU    #$0000
940e: 34 40           PSHS   U
9410: 17 14 c4        LBSR   $A8D7
9413: 32 62           LEAS   $2,S
9415: e6 62           LDB    $2,S
9417: 4f              CLRA
9418: 1f 03           TFR    D,U
941a: 10 8e 00 02     LDY    #$0002
941e: 34 60           PSHS   U,Y
9420: 17 83 7d        LBSR   $17A0
9423: 32 64           LEAS   $4,S
9425: ce 00 00        LDU    #$0000
9428: 34 40           PSHS   U
942a: 17 83 54        LBSR   $1781
942d: 32 62           LEAS   $2,S
942f: e7 62           STB    $2,S
9431: 32 63           LEAS   $3,S
9433: 39              RTS
9434: fc 54 d4        LDD    $54D4
9437: 17 a9 16        LBSR   $3D50
943a: cc 41 96        LDD    #$4196
943d: 1f 03           TFR    D,U
943f: 10 8e 00 02     LDY    #$0002
9443: 34 60           PSHS   U,Y
9445: 17 9b e2        LBSR   $302A
9448: 32 64           LEAS   $4,S
944a: 32 62           LEAS   $2,S
944c: 39              RTS
944d: fc 54 d4        LDD    $54D4
9450: 17 a8 fd        LBSR   $3D50
9453: ce 25 81        LDU    #$2581
9456: 10 8e 3c 02     LDY    #$3C02
945a: c6 aa           LDB    #$AA
945c: 4f              CLRA
945d: 1f 01           TFR    D,X
945f: cc 00 06        LDD    #$0006
9462: 34 76           PSHS   U,Y,X,D
9464: 17 6e 1e        LBSR   $0285
9467: 32 68           LEAS   $8,S
9469: ce 26 8f        LDU    #$268F
946c: 10 ae e9 00 06  LDY    $0006,S
9471: 34 60           PSHS   U,Y
9473: 86 01           LDA    #$01
9475: 8e 54 d9        LDX    #$54D9
9478: 17 a8 6f        LBSR   $3CEA
947b: 1f 13           TFR    X,U
947d: 10 8e 24 e6     LDY    #$24E6
9481: 8e 01 a9        LDX    #$01A9
9484: cc 00 06        LDD    #$0006
9487: 34 76           PSHS   U,Y,X,D
9489: 17 6d f9        LBSR   $0285
948c: 32 68           LEAS   $8,S
948e: 32 62           LEAS   $2,S
9490: 39              RTS
9491: fc 54 d4        LDD    $54D4
9494: 17 a8 b9        LBSR   $3D50
9497: ce 26 8f        LDU    #$268F
949a: 10 ae e9 00 06  LDY    $0006,S
949f: 34 60           PSHS   U,Y
94a1: 86 01           LDA    #$01
94a3: 8e 54 d9        LDX    #$54D9
94a6: 17 a8 41        LBSR   $3CEA
94a9: ce 24 e6        LDU    #$24E6
94ac: 1f 12           TFR    X,Y
94ae: 8e 01 a9        LDX    #$01A9
94b1: cc 00 06        LDD    #$0006
94b4: 34 76           PSHS   U,Y,X,D
94b6: 17 6d cc        LBSR   $0285
94b9: 32 68           LEAS   $8,S
94bb: ce 3c 02        LDU    #$3C02
94be: 10 8e 25 81     LDY    #$2581
94c2: c6 aa           LDB    #$AA
94c4: 4f              CLRA
94c5: 1f 01           TFR    D,X
94c7: cc 00 06        LDD    #$0006
94ca: 34 76           PSHS   U,Y,X,D
94cc: 17 6d b6        LBSR   $0285
94cf: 32 68           LEAS   $8,S
94d1: 32 62           LEAS   $2,S
94d3: 39              RTS
94d4: 00 00           NEG    <$00
94d6: 01 00           NEG    <$00
94d8: 09 00           ROL    <$00
94da: 01 00           NEG    <$00
94dc: 00 01           NEG    <$01
94de: a9 fc 66        ADCA   [$9547,PCR]
94e1: 37 17           PULU   CC,D,X
94e3: a8 6b           EORA   $B,S
94e5: c6 64           LDB    #$64
94e7: e7 62           STB    $2,S
94e9: be 3c a6        LDX    $3CA6
94ec: bc 3c a8        CMPX   $3CA8
94ef: 10 22 00 1d     LBHI   $9510
94f3: f6 3c 20        LDB    $3C20
94f6: e7 63           STB    $3,S
94f8: 7f 3c 20        CLR    $3C20
94fb: fe 3c a6        LDU    $3CA6
94fe: 10 8e 00 02     LDY    #$0002
9502: 34 60           PSHS   U,Y
9504: 17 ed 56        LBSR   $825D
9507: 32 64           LEAS   $4,S
9509: e7 62           STB    $2,S
950b: e6 63           LDB    $3,S
950d: f7 3c 20        STB    $3C20
9510: e6 62           LDB    $2,S
9512: e7 64           STB    $4,S
9514: 32 65           LEAS   $5,S
9516: 39              RTS
9517: fc 66 39        LDD    $6639
951a: 17 a8 33        LBSR   $3D50
951d: be 3c a4        LDX    $3CA4
9520: bc 3c ce        CMPX   $3CCE
9523: 10 24 00 09     LBCC   $9530
9527: fc 3c a4        LDD    $3CA4
952a: c3 00 01        ADDD   #$0001
952d: fd 3c a4        STD    $3CA4
9530: be 3c a2        LDX    $3CA2
9533: bc 3c a4        CMPX   $3CA4
9536: 10 22 00 51     LBHI   $958B
953a: fc 3c a4        LDD    $3CA4
953d: ed 62           STD    $2,S
953f: ae 62           LDX    $2,S
9541: bc 3c a2        CMPX   $3CA2
9544: 10 23 00 31     LBLS   $9579
9548: ec 62           LDD    $2,S
954a: 83 00 01        SUBD   #$0001
954d: ed 65           STD    $5,S
954f: ee 65           LDU    $5,S
9551: 10 8e 00 02     LDY    #$0002
9555: 34 60           PSHS   U,Y
9557: 17 ed 03        LBSR   $825D
955a: 32 64           LEAS   $4,S
955c: e7 64           STB    $4,S
955e: e6 64           LDB    $4,S
9560: 4f              CLRA
9561: 1f 03           TFR    D,U
9563: 10 ae 62        LDY    $2,S
9566: 8e 00 04        LDX    #$0004
9569: 34 70           PSHS   U,Y,X
956b: 17 ed d2        LBSR   $8340
956e: 32 66           LEAS   $6,S
9570: ec 62           LDD    $2,S
9572: 83 00 01        SUBD   #$0001
9575: ed 62           STD    $2,S
9577: 20 c6           BRA    $953F
9579: ee e9 00 0b     LDU    $000B,S
957d: 10 be 3c a2     LDY    $3CA2
9581: 8e 00 04        LDX    #$0004
9584: 34 70           PSHS   U,Y,X
9586: 17 ed b7        LBSR   $8340
9589: 32 66           LEAS   $6,S
958b: 32 67           LEAS   $7,S
958d: 39              RTS
958e: fc 66 39        LDD    $6639
9591: 17 a7 bc        LBSR   $3D50
9594: be 3c a2        LDX    $3CA2
9597: bc 3c a4        CMPX   $3CA4
959a: 10 22 00 52     LBHI   $95F0
959e: fc 3c a2        LDD    $3CA2
95a1: ed 62           STD    $2,S
95a3: ae 62           LDX    $2,S
95a5: bc 3c a4        CMPX   $3CA4
95a8: 10 24 00 31     LBCC   $95DD
95ac: ec 62           LDD    $2,S
95ae: c3 00 01        ADDD   #$0001
95b1: ed 65           STD    $5,S
95b3: ee 65           LDU    $5,S
95b5: 10 8e 00 02     LDY    #$0002
95b9: 34 60           PSHS   U,Y
95bb: 17 ec 9f        LBSR   $825D
95be: 32 64           LEAS   $4,S
95c0: e7 64           STB    $4,S
95c2: e6 64           LDB    $4,S
95c4: 4f              CLRA
95c5: 1f 03           TFR    D,U
95c7: 10 ae 62        LDY    $2,S
95ca: 8e 00 04        LDX    #$0004
95cd: 34 70           PSHS   U,Y,X
95cf: 17 ed 6e        LBSR   $8340
95d2: 32 66           LEAS   $6,S
95d4: ec 62           LDD    $2,S
95d6: c3 00 01        ADDD   #$0001
95d9: ed 62           STD    $2,S
95db: 20 c6           BRA    $95A3
95dd: be 3c a4        LDX    $3CA4
95e0: 8c 00 00        CMPX   #$0000
95e3: 10 23 00 09     LBLS   $95F0
95e7: fc 3c a4        LDD    $3CA4
95ea: 83 00 01        SUBD   #$0001
95ed: fd 3c a4        STD    $3CA4
95f0: 32 67           LEAS   $7,S
95f2: 39              RTS
95f3: fc 66 3b        LDD    $663B
95f6: 17 a7 57        LBSR   $3D50
95f9: f6 3c 20        LDB    $3C20
95fc: 16 00 31        LBRA   $9630
95ff: ec e9 00 0a     LDD    $000A,S
9603: ed 62           STD    $2,S
9605: 16 00 37        LBRA   $963F
9608: ec e9 00 0a     LDD    $000A,S
960c: c3 00 01        ADDD   #$0001
960f: 8e 00 03        LDX    #$0003
9612: 17 a9 2d        LBSR   $3F42
9615: 83 00 01        SUBD   #$0001
9618: ed 62           STD    $2,S
961a: 16 00 22        LBRA   $963F
961d: ec e9 00 0a     LDD    $000A,S
9621: c3 00 01        ADDD   #$0001
9624: 58              ASLB
9625: 49              ROLA
9626: 58              ASLB
9627: 49              ROLA
9628: 83 00 01        SUBD   #$0001
962b: ed 62           STD    $2,S
962d: 16 00 0f        LBRA   $963F
9630: c1 00           CMPB   #$00
9632: 27 cb           BEQ    $95FF
9634: c1 01           CMPB   #$01
9636: 27 d0           BEQ    $9608
9638: c1 02           CMPB   #$02
963a: 27 e1           BEQ    $961D
963c: 16 00 00        LBRA   $963F
963f: ec 62           LDD    $2,S
9641: ed 64           STD    $4,S
9643: 32 66           LEAS   $6,S
9645: 39              RTS
9646: fc 66 3d        LDD    $663D
9649: 17 a7 04        LBSR   $3D50
964c: ae e9 00 06     LDX    $0006,S
9650: 8c 3c a2        CMPX   #$3CA2
9653: 10 26 00 13     LBNE   $966A
9657: fe 3c a2        LDU    $3CA2
965a: 10 8e 00 02     LDY    #$0002
965e: 34 60           PSHS   U,Y
9660: 8d 91           BSR    $95F3
9662: 32 64           LEAS   $4,S
9664: fd 3c a6        STD    $3CA6
9667: 16 00 36        LBRA   $96A0
966a: ae e9 00 06     LDX    $0006,S
966e: 8c 3c aa        CMPX   #$3CAA
9671: 10 26 00 14     LBNE   $9689
9675: fe 3c a4        LDU    $3CA4
9678: 10 8e 00 02     LDY    #$0002
967c: 34 60           PSHS   U,Y
967e: 17 ff 72        LBSR   $95F3
9681: 32 64           LEAS   $4,S
9683: fd 3c aa        STD    $3CAA
9686: 16 00 17        LBRA   $96A0
9689: fe 3c a4        LDU    $3CA4
968c: 10 8e 00 02     LDY    #$0002
9690: 34 60           PSHS   U,Y
9692: 17 ff 5e        LBSR   $95F3
9695: 32 64           LEAS   $4,S
9697: fd 3c a8        STD    $3CA8
969a: fc 3c a8        LDD    $3CA8
969d: fd 3c aa        STD    $3CAA
96a0: 32 62           LEAS   $2,S
96a2: 39              RTS
96a3: fc 66 3d        LDD    $663D
96a6: 17 a6 a7        LBSR   $3D50
96a9: ae e9 00 06     LDX    $0006,S
96ad: 16 00 1b        LBRA   $96CB
96b0: cc 03 e8        LDD    #$03E8
96b3: fd 3c cc        STD    $3CCC
96b6: 16 00 24        LBRA   $96DD
96b9: cc 01 4d        LDD    #$014D
96bc: fd 3c cc        STD    $3CCC
96bf: 16 00 1b        LBRA   $96DD
96c2: cc 00 fa        LDD    #$00FA
96c5: fd 3c cc        STD    $3CCC
96c8: 16 00 12        LBRA   $96DD
96cb: 8c 00 00        CMPX   #$0000
96ce: 27 e0           BEQ    $96B0
96d0: 8c 00 01        CMPX   #$0001
96d3: 27 e4           BEQ    $96B9
96d5: 8c 00 02        CMPX   #$0002
96d8: 27 e8           BEQ    $96C2
96da: 16 00 00        LBRA   $96DD
96dd: fc 3c cc        LDD    $3CCC
96e0: 83 00 01        SUBD   #$0001
96e3: fd 3c ce        STD    $3CCE
96e6: 32 62           LEAS   $2,S
96e8: 39              RTS
96e9: fc 66 3d        LDD    $663D
96ec: 17 a6 61        LBSR   $3D50
96ef: f6 3c 20        LDB    $3C20
96f2: 4f              CLRA
96f3: 10 a3 e9 00 06  CMPD   $0006,S
96f8: 10 27 00 a6     LBEQ   $97A2
96fc: e6 e9 00 07     LDB    $0007,S
9700: f7 3c 20        STB    $3C20
9703: f6 3c 20        LDB    $3C20
9706: 16 00 45        LBRA   $974E
9709: fc 3c a8        LDD    $3CA8
970c: fd 3c a4        STD    $3CA4
970f: fc 3c a6        LDD    $3CA6
9712: fd 3c a2        STD    $3CA2
9715: 16 00 45        LBRA   $975D
9718: be 3c a8        LDX    $3CA8
971b: cc 00 03        LDD    #$0003
971e: 17 a7 a6        LBSR   $3EC7
9721: fd 3c a4        STD    $3CA4
9724: be 3c a6        LDX    $3CA6
9727: cc 00 03        LDD    #$0003
972a: 17 a7 9a        LBSR   $3EC7
972d: fd 3c a2        STD    $3CA2
9730: 16 00 2a        LBRA   $975D
9733: be 3c a8        LDX    $3CA8
9736: cc 00 04        LDD    #$0004
9739: 17 a7 8b        LBSR   $3EC7
973c: fd 3c a4        STD    $3CA4
973f: be 3c a6        LDX    $3CA6
9742: cc 00 04        LDD    #$0004
9745: 17 a7 7f        LBSR   $3EC7
9748: fd 3c a2        STD    $3CA2
974b: 16 00 0f        LBRA   $975D
974e: c1 00           CMPB   #$00
9750: 27 b7           BEQ    $9709
9752: c1 01           CMPB   #$01
9754: 27 c2           BEQ    $9718
9756: c1 02           CMPB   #$02
9758: 27 d9           BEQ    $9733
975a: 16 00 00        LBRA   $975D
975d: f6 3c 20        LDB    $3C20
9760: 4f              CLRA
9761: 1f 03           TFR    D,U
9763: 10 8e 00 02     LDY    #$0002
9767: 34 60           PSHS   U,Y
9769: 17 ff 37        LBSR   $96A3
976c: 32 64           LEAS   $4,S
976e: be 3c a4        LDX    $3CA4
9771: bc 3c ce        CMPX   $3CCE
9774: 10 23 00 06     LBLS   $977E
9778: fc 3c ce        LDD    $3CCE
977b: fd 3c a4        STD    $3CA4
977e: be 3c a2        LDX    $3CA2
9781: bc 3c ce        CMPX   $3CCE
9784: 10 23 00 06     LBLS   $978E
9788: fc 3c ce        LDD    $3CCE
978b: fd 3c a2        STD    $3CA2
978e: ce 3c aa        LDU    #$3CAA
9791: 10 8e 00 02     LDY    #$0002
9795: 34 60           PSHS   U,Y
9797: 17 fe ac        LBSR   $9646
979a: 32 64           LEAS   $4,S
979c: fc 3c a2        LDD    $3CA2
979f: fd 3c d2        STD    $3CD2
97a2: 32 62           LEAS   $2,S
97a4: 39              RTS
97a5: fc 66 3b        LDD    $663B
97a8: 17 a5 a5        LBSR   $3D50
97ab: c6 64           LDB    #$64
97ad: e7 65           STB    $5,S
97af: f6 3c 1f        LDB    $3C1F
97b2: c1 03           CMPB   #$03
97b4: 10 27 00 0c     LBEQ   $97C4
97b8: ec 9f 3c d0     LDD    [$3CD0]
97bc: c3 00 01        ADDD   #$0001
97bf: ed 63           STD    $3,S
97c1: 16 00 08        LBRA   $97CC
97c4: fc 3c a6        LDD    $3CA6
97c7: c3 00 01        ADDD   #$0001
97ca: ed 63           STD    $3,S
97cc: ce 24 14        LDU    #$2414
97cf: 10 ae 63        LDY    $3,S
97d2: 8e 00 04        LDX    #$0004
97d5: 34 70           PSHS   U,Y,X
97d7: 17 71 38        LBSR   $0912
97da: 32 66           LEAS   $6,S
97dc: ce 24 14        LDU    #$2414
97df: c6 04           LDB    #$04
97e1: 1d              SEX
97e2: 1f 02           TFR    D,Y
97e4: 8e 00 04        LDX    #$0004
97e7: 34 70           PSHS   U,Y,X
97e9: 17 75 13        LBSR   $0CFF
97ec: 32 66           LEAS   $6,S
97ee: f6 3c d6        LDB    $3CD6
97f1: c1 00           CMPB   #$00
97f3: 10 27 00 07     LBEQ   $97FE
97f7: c6 02           LDB    #$02
97f9: e7 65           STB    $5,S
97fb: 16 00 04        LBRA   $9802
97fe: c6 03           LDB    #$03
9800: e7 65           STB    $5,S
9802: be 3c d0        LDX    $3CD0
9805: 8c 3c a2        CMPX   #$3CA2
9808: 10 26 00 08     LBNE   $9814
980c: f6 3c cb        LDB    $3CCB
980f: e7 62           STB    $2,S
9811: 16 00 08        LBRA   $981C
9814: c6 4c           LDB    #$4C
9816: e7 62           STB    $2,S
9818: c6 02           LDB    #$02
981a: e7 65           STB    $5,S
981c: e6 65           LDB    $5,S
981e: 4f              CLRA
981f: 1f 03           TFR    D,U
9821: 10 8e 24 15     LDY    #$2415
9825: c6 04           LDB    #$04
9827: 1d              SEX
9828: 1f 01           TFR    D,X
982a: e6 62           LDB    $2,S
982c: 4f              CLRA
982d: 34 76           PSHS   U,Y,X,D
982f: ce 00 08        LDU    #$0008
9832: 34 40           PSHS   U
9834: 17 ec b7        LBSR   $84EE
9837: 32 6a           LEAS   $A,S
9839: 32 66           LEAS   $6,S
983b: 39              RTS
983c: fc 66 3e        LDD    $663E
983f: 17 a5 0e        LBSR   $3D50
9842: fc 3c d0        LDD    $3CD0
9845: ed 62           STD    $2,S
9847: cc 3c a2        LDD    #$3CA2
984a: fd 3c d0        STD    $3CD0
984d: ce 00 00        LDU    #$0000
9850: 34 40           PSHS   U
9852: 17 ff 50        LBSR   $97A5
9855: 32 62           LEAS   $2,S
9857: ec 62           LDD    $2,S
9859: fd 3c d0        STD    $3CD0
985c: 32 64           LEAS   $4,S
985e: 39              RTS
985f: fc 66 3e        LDD    $663E
9862: 17 a4 eb        LBSR   $3D50
9865: fc 3c d0        LDD    $3CD0
9868: ed 62           STD    $2,S
986a: cc 3c a4        LDD    #$3CA4
986d: fd 3c d0        STD    $3CD0
9870: ce 00 00        LDU    #$0000
9873: 34 40           PSHS   U
9875: 17 ff 2d        LBSR   $97A5
9878: 32 62           LEAS   $2,S
987a: ec 62           LDD    $2,S
987c: fd 3c d0        STD    $3CD0
987f: 32 64           LEAS   $4,S
9881: 39              RTS
9882: fc 66 3d        LDD    $663D
9885: 17 a4 c8        LBSR   $3D50
9888: ce 24 14        LDU    #$2414
988b: 10 ae e9 00 08  LDY    $0008,S
9890: 8e 00 04        LDX    #$0004
9893: 34 70           PSHS   U,Y,X
9895: 17 73 0e        LBSR   $0BA6
9898: 32 66           LEAS   $6,S
989a: ec e9 00 0a     LDD    $000A,S
989e: e3 e9 00 06     ADDD   $0006,S
98a2: ed e9 00 0a     STD    $000A,S
98a6: ae e9 00 08     LDX    $0008,S
98aa: 8c 00 10        CMPX   #$0010
98ad: 10 26 00 08     LBNE   $98B9
98b1: c6 20           LDB    #$20
98b3: f7 24 15        STB    $2415
98b6: 16 00 10        LBRA   $98C9
98b9: ae e9 00 08     LDX    $0008,S
98bd: 8c 00 11        CMPX   #$0011
98c0: 10 26 00 05     LBNE   $98C9
98c4: c6 2e           LDB    #$2E
98c6: f7 24 15        STB    $2415
98c9: ee e9 00 0c     LDU    $000C,S
98cd: 10 8e 24 15     LDY    #$2415
98d1: c6 01           LDB    #$01
98d3: 1d              SEX
98d4: 1f 01           TFR    D,X
98d6: ec e9 00 0a     LDD    $000A,S
98da: 34 76           PSHS   U,Y,X,D
98dc: ce 00 08        LDU    #$0008
98df: 34 40           PSHS   U
98e1: 17 ec 0a        LBSR   $84EE
98e4: 32 6a           LEAS   $A,S
98e6: 32 62           LEAS   $2,S
98e8: 39              RTS
98e9: fc 66 3e        LDD    $663E
98ec: 17 a4 61        LBSR   $3D50
98ef: f6 3c 04        LDB    $3C04
98f2: c1 00           CMPB   #$00
98f4: 10 27 00 4b     LBEQ   $9943
98f8: f6 3c 20        LDB    $3C20
98fb: e7 63           STB    $3,S
98fd: 7f 3c 20        CLR    $3C20
9900: be 3c a6        LDX    $3CA6
9903: bc 3c a8        CMPX   $3CA8
9906: 10 22 00 13     LBHI   $991D
990a: fe 3c a6        LDU    $3CA6
990d: 10 8e 00 02     LDY    #$0002
9911: 34 60           PSHS   U,Y
9913: 17 e9 47        LBSR   $825D
9916: 32 64           LEAS   $4,S
9918: e7 62           STB    $2,S
991a: 16 00 04        LBRA   $9921
991d: c6 11           LDB    #$11
991f: e7 62           STB    $2,S
9921: c6 03           LDB    #$03
9923: 1d              SEX
9924: 1f 03           TFR    D,U
9926: 10 ae e9 00 08  LDY    $0008,S
992b: e6 62           LDB    $2,S
992d: 4f              CLRA
992e: 1f 01           TFR    D,X
9930: 5f              CLRB
9931: 1d              SEX
9932: 34 76           PSHS   U,Y,X,D
9934: ce 00 08        LDU    #$0008
9937: 34 40           PSHS   U
9939: 17 ff 46        LBSR   $9882
993c: 32 6a           LEAS   $A,S
993e: e6 63           LDB    $3,S
9940: f7 3c 20        STB    $3C20
9943: 32 64           LEAS   $4,S
9945: 39              RTS
9946: fc 66 40        LDD    $6640
9949: 17 a4 04        LBSR   $3D50
994c: fc 3c d2        LDD    $3CD2
994f: ed 64           STD    $4,S
9951: 5f              CLRB
9952: 4f              CLRA
9953: ed 66           STD    $6,S
9955: 5f              CLRB
9956: 4f              CLRA
9957: ed 62           STD    $2,S
9959: ae 62           LDX    $2,S
995b: 8c 00 10        CMPX   #$0010
995e: 10 24 00 aa     LBCC   $9A0C
9962: f6 3c d7        LDB    $3CD7
9965: c1 00           CMPB   #$00
9967: 10 27 00 34     LBEQ   $999F
996b: ae 64           LDX    $4,S
996d: bc 3c a2        CMPX   $3CA2
9970: 10 26 00 2b     LBNE   $999F
9974: c6 02           LDB    #$02
9976: 1d              SEX
9977: 1f 03           TFR    D,U
9979: c6 15           LDB    #$15
997b: 1d              SEX
997c: 1f 02           TFR    D,Y
997e: c6 10           LDB    #$10
9980: 1d              SEX
9981: 1f 01           TFR    D,X
9983: ec 66           LDD    $6,S
9985: 34 76           PSHS   U,Y,X,D
9987: ce 00 08        LDU    #$0008
998a: 34 40           PSHS   U
998c: 17 fe f3        LBSR   $9882
998f: 32 6a           LEAS   $A,S
9991: ec 66           LDD    $6,S
9993: c3 00 01        ADDD   #$0001
9996: ed 66           STD    $6,S
9998: ec 62           LDD    $2,S
999a: c3 00 01        ADDD   #$0001
999d: ed 62           STD    $2,S
999f: ae 64           LDX    $4,S
99a1: bc 3c a4        CMPX   $3CA4
99a4: 10 22 00 12     LBHI   $99BA
99a8: ee 64           LDU    $4,S
99aa: 10 8e 00 02     LDY    #$0002
99ae: 34 60           PSHS   U,Y
99b0: 17 e8 aa        LBSR   $825D
99b3: 32 64           LEAS   $4,S
99b5: e7 68           STB    $8,S
99b7: 16 00 14        LBRA   $99CE
99ba: ae 64           LDX    $4,S
99bc: bc 3c cc        CMPX   $3CCC
99bf: 10 24 00 07     LBCC   $99CA
99c3: c6 11           LDB    #$11
99c5: e7 68           STB    $8,S
99c7: 16 00 04        LBRA   $99CE
99ca: c6 10           LDB    #$10
99cc: e7 68           STB    $8,S
99ce: ae 66           LDX    $6,S
99d0: 8c 00 10        CMPX   #$0010
99d3: 10 24 00 1d     LBCC   $99F4
99d7: c6 02           LDB    #$02
99d9: 1d              SEX
99da: 1f 03           TFR    D,U
99dc: c6 15           LDB    #$15
99de: 1d              SEX
99df: 1f 02           TFR    D,Y
99e1: e6 68           LDB    $8,S
99e3: 4f              CLRA
99e4: 1f 01           TFR    D,X
99e6: ec 66           LDD    $6,S
99e8: 34 76           PSHS   U,Y,X,D
99ea: ce 00 08        LDU    #$0008
99ed: 34 40           PSHS   U
99ef: 17 fe 90        LBSR   $9882
99f2: 32 6a           LEAS   $A,S
99f4: ec 62           LDD    $2,S
99f6: c3 00 01        ADDD   #$0001
99f9: ed 62           STD    $2,S
99fb: ec 64           LDD    $4,S
99fd: c3 00 01        ADDD   #$0001
9a00: ed 64           STD    $4,S
9a02: ec 66           LDD    $6,S
9a04: c3 00 01        ADDD   #$0001
9a07: ed 66           STD    $6,S
9a09: 16 ff 4d        LBRA   $9959
9a0c: 32 69           LEAS   $9,S
9a0e: 39              RTS
9a0f: fc 66 3d        LDD    $663D
9a12: 17 a3 3b        LBSR   $3D50
9a15: ce 00 00        LDU    #$0000
9a18: 34 40           PSHS   U
9a1a: 17 ff 29        LBSR   $9946
9a1d: 32 62           LEAS   $2,S
9a1f: ce 00 00        LDU    #$0000
9a22: 34 40           PSHS   U
9a24: 17 fe 15        LBSR   $983C
9a27: 32 62           LEAS   $2,S
9a29: ce 00 00        LDU    #$0000
9a2c: 34 40           PSHS   U
9a2e: 17 fe 2e        LBSR   $985F
9a31: 32 62           LEAS   $2,S
9a33: f6 3c ca        LDB    $3CCA
9a36: c1 00           CMPB   #$00
9a38: 10 27 00 20     LBEQ   $9A5C
9a3c: c6 02           LDB    #$02
9a3e: 1d              SEX
9a3f: 1f 03           TFR    D,U
9a41: 10 8e 40 b6     LDY    #$40B6
9a45: c6 14           LDB    #$14
9a47: 1d              SEX
9a48: 1f 01           TFR    D,X
9a4a: c6 54           LDB    #$54
9a4c: 1d              SEX
9a4d: 34 76           PSHS   U,Y,X,D
9a4f: ce 00 08        LDU    #$0008
9a52: 34 40           PSHS   U
9a54: 17 ea 97        LBSR   $84EE
9a57: 32 6a           LEAS   $A,S
9a59: 16 00 1d        LBRA   $9A79
9a5c: c6 02           LDB    #$02
9a5e: 1d              SEX
9a5f: 1f 03           TFR    D,U
9a61: 10 8e 40 3e     LDY    #$403E
9a65: c6 14           LDB    #$14
9a67: 1d              SEX
9a68: 1f 01           TFR    D,X
9a6a: c6 54           LDB    #$54
9a6c: 1d              SEX
9a6d: 34 76           PSHS   U,Y,X,D
9a6f: ce 00 08        LDU    #$0008
9a72: 34 40           PSHS   U
9a74: 17 ea 77        LBSR   $84EE
9a77: 32 6a           LEAS   $A,S
9a79: 32 62           LEAS   $2,S
9a7b: 39              RTS
9a7c: fc 66 3e        LDD    $663E
9a7f: 17 a2 ce        LBSR   $3D50
9a82: cc 00 15        LDD    #$0015
9a85: f3 3c d4        ADDD   $3CD4
9a88: ed 62           STD    $2,S
9a8a: 5f              CLRB
9a8b: 1d              SEX
9a8c: 1f 03           TFR    D,U
9a8e: 10 8e 00 00     LDY    #$0000
9a92: ae 62           LDX    $2,S
9a94: c6 01           LDB    #$01
9a96: 1d              SEX
9a97: 34 76           PSHS   U,Y,X,D
9a99: ce 00 01        LDU    #$0001
9a9c: 10 8e 00 0a     LDY    #$000A
9aa0: 34 60           PSHS   U,Y
9aa2: 17 51 90        LBSR   $EC35
9aa5: 32 6c           LEAS   $C,S
9aa7: 32 64           LEAS   $4,S
9aa9: 39              RTS
9aaa: fc 66 3e        LDD    $663E
9aad: 17 a2 a0        LBSR   $3D50
9ab0: 6f 62           CLR    $2,S
9ab2: f6 3c ca        LDB    $3CCA
9ab5: c1 00           CMPB   #$00
9ab7: 10 27 00 66     LBEQ   $9B21
9abb: 7f 3c ca        CLR    $3CCA
9abe: 7f 3c d7        CLR    $3CD7
9ac1: be 3c a2        LDX    $3CA2
9ac4: bc 3c d2        CMPX   $3CD2
9ac7: 10 27 00 04     LBEQ   $9ACF
9acb: c6 01           LDB    #$01
9acd: e7 62           STB    $2,S
9acf: fc 3c d2        LDD    $3CD2
9ad2: fd 3c a2        STD    $3CA2
9ad5: ce 00 00        LDU    #$0000
9ad8: 34 40           PSHS   U
9ada: 17 fa 02        LBSR   $94DF
9add: 32 62           LEAS   $2,S
9adf: e7 63           STB    $3,S
9ae1: f6 3c 04        LDB    $3C04
9ae4: 4f              CLRA
9ae5: 1f 03           TFR    D,U
9ae7: e6 63           LDB    $3,S
9ae9: 4f              CLRA
9aea: 1f 02           TFR    D,Y
9aec: 8e 00 04        LDX    #$0004
9aef: 34 70           PSHS   U,Y,X
9af1: 17 f7 02        LBSR   $91F6
9af4: 32 66           LEAS   $6,S
9af6: e6 62           LDB    $2,S
9af8: c1 00           CMPB   #$00
9afa: 10 27 00 0e     LBEQ   $9B0C
9afe: ce 3c a2        LDU    #$3CA2
9b01: 10 8e 00 02     LDY    #$0002
9b05: 34 60           PSHS   U,Y
9b07: 17 fb 3c        LBSR   $9646
9b0a: 32 64           LEAS   $4,S
9b0c: ae e9 00 08     LDX    $0008,S
9b10: 8c 00 00        CMPX   #$0000
9b13: 10 27 00 0a     LBEQ   $9B21
9b17: ce 00 00        LDU    #$0000
9b1a: 34 40           PSHS   U
9b1c: 17 fe f0        LBSR   $9A0F
9b1f: 32 62           LEAS   $2,S
9b21: 32 64           LEAS   $4,S
9b23: 39              RTS
9b24: fc 66 3d        LDD    $663D
9b27: 17 a2 26        LBSR   $3D50
9b2a: c6 01           LDB    #$01
9b2c: f7 3c d6        STB    $3CD6
9b2f: cc 00 08        LDD    #$0008
9b32: fd 3c ac        STD    $3CAC
9b35: cc 3c a2        LDD    #$3CA2
9b38: fd 3c d0        STD    $3CD0
9b3b: ce 00 04        LDU    #$0004
9b3e: 10 8e 00 02     LDY    #$0002
9b42: 34 60           PSHS   U,Y
9b44: be 3c 00        LDX    $3C00
9b47: ad 84           JSR    ,X
9b49: 32 64           LEAS   $4,S
9b4b: 32 62           LEAS   $2,S
9b4d: 39              RTS
9b4e: fc 66 3d        LDD    $663D
9b51: 17 a1 fc        LBSR   $3D50
9b54: cc 00 0a        LDD    #$000A
9b57: fd 3c ac        STD    $3CAC
9b5a: cc 3c a4        LDD    #$3CA4
9b5d: fd 3c d0        STD    $3CD0
9b60: ce 00 05        LDU    #$0005
9b63: 10 8e 00 02     LDY    #$0002
9b67: 34 60           PSHS   U,Y
9b69: be 3c 00        LDX    $3C00
9b6c: ad 84           JSR    ,X
9b6e: 32 64           LEAS   $4,S
9b70: 32 62           LEAS   $2,S
9b72: 39              RTS
9b73: fc 66 3e        LDD    $663E
9b76: 17 a1 d7        LBSR   $3D50
9b79: f6 3c ca        LDB    $3CCA
9b7c: c1 00           CMPB   #$00
9b7e: 10 27 00 2b     LBEQ   $9BAD
9b82: f6 3c d7        LDB    $3CD7
9b85: c1 00           CMPB   #$00
9b87: 10 27 00 06     LBEQ   $9B91
9b8b: 7f 3c d7        CLR    $3CD7
9b8e: 16 00 05        LBRA   $9B96
9b91: c6 01           LDB    #$01
9b93: f7 3c d7        STB    $3CD7
9b96: ce 00 00        LDU    #$0000
9b99: 34 40           PSHS   U
9b9b: 17 fd a8        LBSR   $9946
9b9e: 32 62           LEAS   $2,S
9ba0: ce 00 00        LDU    #$0000
9ba3: 34 40           PSHS   U
9ba5: 17 fe d4        LBSR   $9A7C
9ba8: 32 62           LEAS   $2,S
9baa: 16 00 2a        LBRA   $9BD7
9bad: c6 01           LDB    #$01
9baf: f7 3c ca        STB    $3CCA
9bb2: cc 3c a2        LDD    #$3CA2
9bb5: fd 3c d0        STD    $3CD0
9bb8: 5f              CLRB
9bb9: 4f              CLRA
9bba: fd 3c d4        STD    $3CD4
9bbd: cc 00 09        LDD    #$0009
9bc0: fd 3c ac        STD    $3CAC
9bc3: ce 00 00        LDU    #$0000
9bc6: 34 40           PSHS   U
9bc8: 17 fe 44        LBSR   $9A0F
9bcb: 32 62           LEAS   $2,S
9bcd: ce 00 00        LDU    #$0000
9bd0: 34 40           PSHS   U
9bd2: 17 fe a7        LBSR   $9A7C
9bd5: 32 62           LEAS   $2,S
9bd7: 32 64           LEAS   $4,S
9bd9: 39              RTS
9bda: fc 66 3e        LDD    $663E
9bdd: 17 a1 70        LBSR   $3D50
9be0: be 3c ac        LDX    $3CAC
9be3: 8c 00 09        CMPX   #$0009
9be6: 10 26 00 3e     LBNE   $9C28
9bea: f6 3c d7        LDB    $3CD7
9bed: c1 00           CMPB   #$00
9bef: 10 27 00 06     LBEQ   $9BF9
9bf3: 7f 3c d7        CLR    $3CD7
9bf6: 16 00 0a        LBRA   $9C03
9bf9: ce 00 00        LDU    #$0000
9bfc: 34 40           PSHS   U
9bfe: 17 f9 8d        LBSR   $958E
9c01: 32 62           LEAS   $2,S
9c03: ce 3c a4        LDU    #$3CA4
9c06: 10 8e 00 02     LDY    #$0002
9c0a: 34 60           PSHS   U,Y
9c0c: 17 fa 37        LBSR   $9646
9c0f: 32 64           LEAS   $4,S
9c11: ce 00 00        LDU    #$0000
9c14: 34 40           PSHS   U
9c16: 17 fd f6        LBSR   $9A0F
9c19: 32 62           LEAS   $2,S
9c1b: ce 00 00        LDU    #$0000
9c1e: 34 40           PSHS   U
9c20: 17 fe 59        LBSR   $9A7C
9c23: 32 62           LEAS   $2,S
9c25: 16 00 05        LBRA   $9C2D
9c28: 5f              CLRB
9c29: 4f              CLRA
9c2a: fd 3c ac        STD    $3CAC
9c2d: 32 64           LEAS   $4,S
9c2f: 39              RTS
9c30: fc 66 3b        LDD    $663B
9c33: 17 a1 1a        LBSR   $3D50
9c36: be 3c ac        LDX    $3CAC
9c39: 16 00 9e        LBRA   $9CDA
9c3c: ec 9f 3c d0     LDD    [$3CD0]
9c40: c3 00 01        ADDD   #$0001
9c43: ce 22 85        LDU    #$2285
9c46: 1f 02           TFR    D,Y
9c48: 8e 00 04        LDX    #$0004
9c4b: 34 70           PSHS   U,Y,X
9c4d: 17 6c c2        LBSR   $0912
9c50: 32 66           LEAS   $6,S
9c52: c6 05           LDB    #$05
9c54: e7 62           STB    $2,S
9c56: 16 00 99        LBRA   $9CF2
9c59: f6 3c 20        LDB    $3C20
9c5c: e7 65           STB    $5,S
9c5e: c6 02           LDB    #$02
9c60: 1d              SEX
9c61: 1f 03           TFR    D,U
9c63: 10 8e 00 02     LDY    #$0002
9c67: 34 60           PSHS   U,Y
9c69: 17 fa 7d        LBSR   $96E9
9c6c: 32 64           LEAS   $4,S
9c6e: f6 3c a3        LDB    $3CA3
9c71: e7 63           STB    $3,S
9c73: 6f 62           CLR    $2,S
9c75: e6 63           LDB    $3,S
9c77: 4f              CLRA
9c78: 10 b3 3c a4     CMPD   $3CA4
9c7c: 10 22 00 47     LBHI   $9CC7
9c80: e6 63           LDB    $3,S
9c82: 4f              CLRA
9c83: 1f 03           TFR    D,U
9c85: 10 8e 00 02     LDY    #$0002
9c89: 34 60           PSHS   U,Y
9c8b: 17 e5 cf        LBSR   $825D
9c8e: 32 64           LEAS   $4,S
9c90: e7 64           STB    $4,S
9c92: e6 64           LDB    $4,S
9c94: c1 09           CMPB   #$09
9c96: 10 23 00 0f     LBLS   $9CA9
9c9a: a6 64           LDA    $4,S
9c9c: c6 0a           LDB    #$0A
9c9e: 17 a0 ee        LBSR   $3D8F
9ca1: c3 00 41        ADDD   #$0041
9ca4: e7 64           STB    $4,S
9ca6: 16 00 06        LBRA   $9CAF
9ca9: e6 64           LDB    $4,S
9cab: cb 30           ADDB   #$30
9cad: e7 64           STB    $4,S
9caf: 8e 22 85        LDX    #$2285
9cb2: e6 62           LDB    $2,S
9cb4: 3a              ABX
9cb5: e6 64           LDB    $4,S
9cb7: e7 84           STB    ,X
9cb9: e6 63           LDB    $3,S
9cbb: cb 01           ADDB   #$01
9cbd: e7 63           STB    $3,S
9cbf: e6 62           LDB    $2,S
9cc1: cb 01           ADDB   #$01
9cc3: e7 62           STB    $2,S
9cc5: 20 ae           BRA    $9C75
9cc7: e6 65           LDB    $5,S
9cc9: 4f              CLRA
9cca: 1f 03           TFR    D,U
9ccc: 10 8e 00 02     LDY    #$0002
9cd0: 34 60           PSHS   U,Y
9cd2: 17 fa 14        LBSR   $96E9
9cd5: 32 64           LEAS   $4,S
9cd7: 16 00 18        LBRA   $9CF2
9cda: 8c 00 08        CMPX   #$0008
9cdd: 10 27 ff 5b     LBEQ   $9C3C
9ce1: 8c 00 09        CMPX   #$0009
9ce4: 10 27 ff 71     LBEQ   $9C59
9ce8: 8c 00 0a        CMPX   #$000A
9ceb: 10 27 ff 4d     LBEQ   $9C3C
9cef: 16 00 00        LBRA   $9CF2
9cf2: e6 62           LDB    $2,S
9cf4: 4f              CLRA
9cf5: 1f 03           TFR    D,U
9cf7: 10 8e 22 85     LDY    #$2285
9cfb: 8e 00 04        LDX    #$0004
9cfe: 34 70           PSHS   U,Y,X
9d00: 17 42 fb        LBSR   $DFFE
9d03: 32 66           LEAS   $6,S
9d05: 32 66           LEAS   $6,S
9d07: 39              RTS
9d08: fc 66 3d        LDD    $663D
9d0b: 17 a0 42        LBSR   $3D50
9d0e: fc 3c a2        LDD    $3CA2
9d11: fd 3c a4        STD    $3CA4
9d14: fc 3c a6        LDD    $3CA6
9d17: fd 3c a8        STD    $3CA8
9d1a: fe 3c a4        LDU    $3CA4
9d1d: 10 8e 00 02     LDY    #$0002
9d21: 34 60           PSHS   U,Y
9d23: 17 f8 cd        LBSR   $95F3
9d26: 32 64           LEAS   $4,S
9d28: fd 3c aa        STD    $3CAA
9d2b: ae e9 00 06     LDX    $0006,S
9d2f: 8c 00 00        CMPX   #$0000
9d32: 10 26 00 58     LBNE   $9D8E
9d36: ce 00 00        LDU    #$0000
9d39: 34 40           PSHS   U
9d3b: 17 fc d1        LBSR   $9A0F
9d3e: 32 62           LEAS   $2,S
9d40: be 3c ac        LDX    $3CAC
9d43: 8c 00 08        CMPX   #$0008
9d46: 10 26 00 13     LBNE   $9D5D
9d4a: ce 00 04        LDU    #$0004
9d4d: 10 8e 00 02     LDY    #$0002
9d51: 34 60           PSHS   U,Y
9d53: be 3c 00        LDX    $3C00
9d56: ad 84           JSR    ,X
9d58: 32 64           LEAS   $4,S
9d5a: 16 00 31        LBRA   $9D8E
9d5d: be 3c ac        LDX    $3CAC
9d60: 8c 00 0a        CMPX   #$000A
9d63: 10 26 00 13     LBNE   $9D7A
9d67: ce 00 05        LDU    #$0005
9d6a: 10 8e 00 02     LDY    #$0002
9d6e: 34 60           PSHS   U,Y
9d70: be 3c 00        LDX    $3C00
9d73: ad 84           JSR    ,X
9d75: 32 64           LEAS   $4,S
9d77: 16 00 14        LBRA   $9D8E
9d7a: be 3c ac        LDX    $3CAC
9d7d: 8c 00 09        CMPX   #$0009
9d80: 10 26 00 0a     LBNE   $9D8E
9d84: ce 00 00        LDU    #$0000
9d87: 34 40           PSHS   U
9d89: 17 fc f0        LBSR   $9A7C
9d8c: 32 62           LEAS   $2,S
9d8e: 32 62           LEAS   $2,S
9d90: 39              RTS
9d91: fc 66 3d        LDD    $663D
9d94: 17 9f b9        LBSR   $3D50
9d97: fc 3c a4        LDD    $3CA4
9d9a: c3 00 01        ADDD   #$0001
9d9d: 10 b3 3c a2     CMPD   $3CA2
9da1: 10 24 00 60     LBCC   $9E05
9da5: be 3c d0        LDX    $3CD0
9da8: 8c 3c a2        CMPX   #$3CA2
9dab: 10 26 00 0f     LBNE   $9DBE
9daf: ec e9 00 06     LDD    $0006,S
9db3: fd 3c a2        STD    $3CA2
9db6: c6 37           LDB    #$37
9db8: f7 3c dc        STB    $3CDC
9dbb: 16 00 47        LBRA   $9E05
9dbe: fc 3c a4        LDD    $3CA4
9dc1: c3 00 01        ADDD   #$0001
9dc4: fd 3c a2        STD    $3CA2
9dc7: fc 3c a2        LDD    $3CA2
9dca: fd 3c d2        STD    $3CD2
9dcd: f6 3c d6        LDB    $3CD6
9dd0: c1 00           CMPB   #$00
9dd2: 10 27 00 25     LBEQ   $9DFB
9dd6: ce 3c a2        LDU    #$3CA2
9dd9: 10 8e 00 02     LDY    #$0002
9ddd: 34 60           PSHS   U,Y
9ddf: 17 f8 64        LBSR   $9646
9de2: 32 64           LEAS   $4,S
9de4: ce 00 00        LDU    #$0000
9de7: 34 40           PSHS   U
9de9: 17 fa 50        LBSR   $983C
9dec: 32 62           LEAS   $2,S
9dee: ce 00 00        LDU    #$0000
9df1: 34 40           PSHS   U
9df3: 17 fb 50        LBSR   $9946
9df6: 32 62           LEAS   $2,S
9df8: 16 00 0a        LBRA   $9E05
9dfb: ce 00 00        LDU    #$0000
9dfe: 34 40           PSHS   U
9e00: 17 ea a5        LBSR   $88A8
9e03: 32 62           LEAS   $2,S
9e05: 32 62           LEAS   $2,S
9e07: 39              RTS
9e08: fc 66 42        LDD    $6642
9e0b: 17 9f 42        LBSR   $3D50
9e0e: cc 00 01        LDD    #$0001
9e11: ed 62           STD    $2,S
9e13: c6 01           LDB    #$01
9e15: e7 68           STB    $8,S
9e17: be 3c ac        LDX    $3CAC
9e1a: 16 02 1f        LBRA   $A03C
9e1d: ae e9 00 0e     LDX    $000E,S
9e21: 8c 00 00        CMPX   #$0000
9e24: 10 27 00 27     LBEQ   $9E4F
9e28: be 3c a2        LDX    $3CA2
9e2b: bc 3c ce        CMPX   $3CCE
9e2e: 10 24 00 1a     LBCC   $9E4C
9e32: be 3c a2        LDX    $3CA2
9e35: bc 3c a4        CMPX   $3CA4
9e38: 10 22 00 0c     LBHI   $9E48
9e3c: fc 3c a2        LDD    $3CA2
9e3f: c3 00 01        ADDD   #$0001
9e42: fd 3c a2        STD    $3CA2
9e45: 16 00 04        LBRA   $9E4C
9e48: 5f              CLRB
9e49: 4f              CLRA
9e4a: ed 62           STD    $2,S
9e4c: 16 00 1a        LBRA   $9E69
9e4f: be 3c a2        LDX    $3CA2
9e52: 8c 00 00        CMPX   #$0000
9e55: 10 23 00 0c     LBLS   $9E65
9e59: fc 3c a2        LDD    $3CA2
9e5c: 83 00 01        SUBD   #$0001
9e5f: fd 3c a2        STD    $3CA2
9e62: 16 00 04        LBRA   $9E69
9e65: 5f              CLRB
9e66: 4f              CLRA
9e67: ed 62           STD    $2,S
9e69: ae 62           LDX    $2,S
9e6b: 8c 00 00        CMPX   #$0000
9e6e: 10 27 00 57     LBEQ   $9EC9
9e72: fc 3c d2        LDD    $3CD2
9e75: ed 64           STD    $4,S
9e77: be 3c a2        LDX    $3CA2
9e7a: bc 3c d2        CMPX   $3CD2
9e7d: 10 24 00 09     LBCC   $9E8A
9e81: fc 3c a2        LDD    $3CA2
9e84: fd 3c d2        STD    $3CD2
9e87: 16 00 17        LBRA   $9EA1
9e8a: fc 3c d2        LDD    $3CD2
9e8d: c3 00 0f        ADDD   #$000F
9e90: 10 b3 3c a2     CMPD   $3CA2
9e94: 10 24 00 09     LBCC   $9EA1
9e98: fc 3c a2        LDD    $3CA2
9e9b: 83 00 0f        SUBD   #$000F
9e9e: fd 3c d2        STD    $3CD2
9ea1: fc 3c a2        LDD    $3CA2
9ea4: b3 3c d2        SUBD   $3CD2
9ea7: fd 3c d4        STD    $3CD4
9eaa: ae 64           LDX    $4,S
9eac: bc 3c d2        CMPX   $3CD2
9eaf: 10 26 00 0c     LBNE   $9EBF
9eb3: f6 3c d7        LDB    $3CD7
9eb6: c1 00           CMPB   #$00
9eb8: 10 26 00 03     LBNE   $9EBF
9ebc: 16 00 00        LBRA   $9EBF
9ebf: ce 00 00        LDU    #$0000
9ec2: 34 40           PSHS   U
9ec4: 17 fa 7f        LBSR   $9946
9ec7: 32 62           LEAS   $2,S
9ec9: ce 3c a2        LDU    #$3CA2
9ecc: 10 8e 00 02     LDY    #$0002
9ed0: 34 60           PSHS   U,Y
9ed2: 17 f7 71        LBSR   $9646
9ed5: 32 64           LEAS   $4,S
9ed7: ce 00 00        LDU    #$0000
9eda: 34 40           PSHS   U
9edc: 17 f9 5d        LBSR   $983C
9edf: 32 62           LEAS   $2,S
9ee1: c6 0e           LDB    #$0E
9ee3: 1d              SEX
9ee4: 1f 03           TFR    D,U
9ee6: 10 8e 00 02     LDY    #$0002
9eea: 34 60           PSHS   U,Y
9eec: 17 f9 fa        LBSR   $98E9
9eef: 32 64           LEAS   $4,S
9ef1: ce 00 00        LDU    #$0000
9ef4: 34 40           PSHS   U
9ef6: 17 fb 83        LBSR   $9A7C
9ef9: 32 62           LEAS   $2,S
9efb: 16 01 5d        LBRA   $A05B
9efe: be 3c ac        LDX    $3CAC
9f01: 8c 00 0b        CMPX   #$000B
9f04: 10 26 00 14     LBNE   $9F1C
9f08: f6 3c 20        LDB    $3C20
9f0b: e7 69           STB    $9,S
9f0d: 5f              CLRB
9f0e: 1d              SEX
9f0f: 1f 03           TFR    D,U
9f11: 10 8e 00 02     LDY    #$0002
9f15: 34 60           PSHS   U,Y
9f17: 17 f7 cf        LBSR   $96E9
9f1a: 32 64           LEAS   $4,S
9f1c: ec 9f 3c d0     LDD    [$3CD0]
9f20: ed 66           STD    $6,S
9f22: ae e9 00 0e     LDX    $000E,S
9f26: 8c 00 00        CMPX   #$0000
9f29: 10 27 00 1e     LBEQ   $9F4B
9f2d: ae 9f 3c d0     LDX    [$3CD0]
9f31: bc 3c ce        CMPX   $3CCE
9f34: 10 24 00 0e     LBCC   $9F46
9f38: ec 9f 3c d0     LDD    [$3CD0]
9f3c: c3 00 01        ADDD   #$0001
9f3f: ed 9f 3c d0     STD    [$3CD0]
9f43: 16 00 02        LBRA   $9F48
9f46: 6f 68           CLR    $8,S
9f48: 16 00 1b        LBRA   $9F66
9f4b: ae 9f 3c d0     LDX    [$3CD0]
9f4f: 8c 00 00        CMPX   #$0000
9f52: 10 23 00 0e     LBLS   $9F64
9f56: ec 9f 3c d0     LDD    [$3CD0]
9f5a: 83 00 01        SUBD   #$0001
9f5d: ed 9f 3c d0     STD    [$3CD0]
9f61: 16 00 02        LBRA   $9F66
9f64: 6f 68           CLR    $8,S
9f66: e6 68           LDB    $8,S
9f68: c1 00           CMPB   #$00
9f6a: 10 27 00 68     LBEQ   $9FD6
9f6e: ee 66           LDU    $6,S
9f70: 10 8e 00 02     LDY    #$0002
9f74: 34 60           PSHS   U,Y
9f76: 17 fe 18        LBSR   $9D91
9f79: 32 64           LEAS   $4,S
9f7b: 7f 3c dc        CLR    $3CDC
9f7e: fe 3c d0        LDU    $3CD0
9f81: 10 8e 00 02     LDY    #$0002
9f85: 34 60           PSHS   U,Y
9f87: 17 f6 bc        LBSR   $9646
9f8a: 32 64           LEAS   $4,S
9f8c: ce 00 00        LDU    #$0000
9f8f: 34 40           PSHS   U
9f91: 17 f8 11        LBSR   $97A5
9f94: 32 62           LEAS   $2,S
9f96: be 3c ac        LDX    $3CAC
9f99: 8c 00 0b        CMPX   #$000B
9f9c: 10 26 00 10     LBNE   $9FB0
9fa0: e6 69           LDB    $9,S
9fa2: 4f              CLRA
9fa3: 1f 03           TFR    D,U
9fa5: 10 8e 00 02     LDY    #$0002
9fa9: 34 60           PSHS   U,Y
9fab: 17 f7 3b        LBSR   $96E9
9fae: 32 64           LEAS   $4,S
9fb0: be 3c d0        LDX    $3CD0
9fb3: 8c 3c a2        CMPX   #$3CA2
9fb6: 10 26 00 06     LBNE   $9FC0
9fba: fc 3c a2        LDD    $3CA2
9fbd: fd 3c d2        STD    $3CD2
9fc0: f6 3c d6        LDB    $3CD6
9fc3: c1 00           CMPB   #$00
9fc5: 10 27 00 0a     LBEQ   $9FD3
9fc9: ce 00 00        LDU    #$0000
9fcc: 34 40           PSHS   U
9fce: 17 f9 75        LBSR   $9946
9fd1: 32 62           LEAS   $2,S
9fd3: 16 00 1a        LBRA   $9FF0
9fd6: be 3c ac        LDX    $3CAC
9fd9: 8c 00 0b        CMPX   #$000B
9fdc: 10 26 00 10     LBNE   $9FF0
9fe0: e6 69           LDB    $9,S
9fe2: 4f              CLRA
9fe3: 1f 03           TFR    D,U
9fe5: 10 8e 00 02     LDY    #$0002
9fe9: 34 60           PSHS   U,Y
9feb: 17 f6 fb        LBSR   $96E9
9fee: 32 64           LEAS   $4,S
9ff0: f6 3c d6        LDB    $3CD6
9ff3: c1 00           CMPB   #$00
9ff5: 10 27 00 2d     LBEQ   $A026
9ff9: be 3c d0        LDX    $3CD0
9ffc: 8c 3c a2        CMPX   #$3CA2
9fff: 10 26 00 13     LBNE   $A016
a003: ce 00 04        LDU    #$0004
a006: 10 8e 00 02     LDY    #$0002
a00a: 34 60           PSHS   U,Y
a00c: be 3c 00        LDX    $3C00
a00f: ad 84           JSR    ,X
a011: 32 64           LEAS   $4,S
a013: 16 00 10        LBRA   $A026
a016: ce 00 05        LDU    #$0005
a019: 10 8e 00 02     LDY    #$0002
a01d: 34 60           PSHS   U,Y
a01f: be 3c 00        LDX    $3C00
a022: ad 84           JSR    ,X
a024: 32 64           LEAS   $4,S
a026: c6 0e           LDB    #$0E
a028: 1d              SEX
a029: 1f 03           TFR    D,U
a02b: 10 8e 00 02     LDY    #$0002
a02f: 34 60           PSHS   U,Y
a031: 17 f8 b5        LBSR   $98E9
a034: 32 64           LEAS   $4,S
a036: 16 00 22        LBRA   $A05B
a039: 16 00 1f        LBRA   $A05B
a03c: 8c 00 08        CMPX   #$0008
a03f: 10 27 fe bb     LBEQ   $9EFE
a043: 8c 00 09        CMPX   #$0009
a046: 10 27 fd d3     LBEQ   $9E1D
a04a: 8c 00 0a        CMPX   #$000A
a04d: 10 27 fe ad     LBEQ   $9EFE
a051: 8c 00 0b        CMPX   #$000B
a054: 10 27 fe a6     LBEQ   $9EFE
a058: 16 00 00        LBRA   $A05B
a05b: 32 6a           LEAS   $A,S
a05d: 39              RTS
a05e: fc 66 3d        LDD    $663D
a061: 17 9c ec        LBSR   $3D50
a064: be 3c d0        LDX    $3CD0
a067: 8c 3c a2        CMPX   #$3CA2
a06a: 10 26 00 08     LBNE   $A076
a06e: c6 37           LDB    #$37
a070: f7 3c dc        STB    $3CDC
a073: 16 00 05        LBRA   $A07B
a076: c6 38           LDB    #$38
a078: f7 3c dc        STB    $3CDC
a07b: 32 62           LEAS   $2,S
a07d: 39              RTS
a07e: fc 66 37        LDD    $6637
a081: 17 9c cc        LBSR   $3D50
a084: 6f 63           CLR    $3,S
a086: f6 3c 20        LDB    $3C20
a089: 58              ASLB
a08a: 58              ASLB
a08b: 58              ASLB
a08c: e7 62           STB    $2,S
a08e: e6 62           LDB    $2,S
a090: c1 00           CMPB   #$00
a092: 10 26 00 04     LBNE   $A09A
a096: c6 02           LDB    #$02
a098: e7 62           STB    $2,S
a09a: e6 62           LDB    $2,S
a09c: 4f              CLRA
a09d: 10 a3 e9 00 09  CMPD   $0009,S
a0a2: 10 23 00 0b     LBLS   $A0B1
a0a6: e6 e9 00 0a     LDB    $000A,S
a0aa: e7 f9 00 0b     STB    [$000B,S]
a0ae: 16 00 04        LBRA   $A0B5
a0b1: c6 01           LDB    #$01
a0b3: e7 63           STB    $3,S
a0b5: e6 63           LDB    $3,S
a0b7: e7 64           STB    $4,S
a0b9: 32 65           LEAS   $5,S
a0bb: 39              RTS
a0bc: fc 66 44        LDD    $6644
a0bf: 17 9c 8e        LBSR   $3D50
a0c2: 6f 64           CLR    $4,S
a0c4: 6f 65           CLR    $5,S
a0c6: be 3c ac        LDX    $3CAC
a0c9: 16 02 6a        LBRA   $A336
a0cc: f6 23 9a        LDB    $239A
a0cf: f7 24 15        STB    $2415
a0d2: c6 30           LDB    #$30
a0d4: f7 24 14        STB    $2414
a0d7: ce 24 14        LDU    #$2414
a0da: 10 8e 00 02     LDY    #$0002
a0de: 34 60           PSHS   U,Y
a0e0: 17 6b 70        LBSR   $0C53
a0e3: 32 64           LEAS   $4,S
a0e5: e7 62           STB    $2,S
a0e7: 33 62           LEAU   $2,S
a0e9: e6 62           LDB    $2,S
a0eb: 4f              CLRA
a0ec: 1f 02           TFR    D,Y
a0ee: 8e 00 04        LDX    #$0004
a0f1: 34 70           PSHS   U,Y,X
a0f3: 8d 89           BSR    $A07E
a0f5: 32 66           LEAS   $6,S
a0f7: e7 65           STB    $5,S
a0f9: e6 65           LDB    $5,S
a0fb: c1 00           CMPB   #$00
a0fd: 10 27 00 19     LBEQ   $A11A
a101: c6 39           LDB    #$39
a103: f7 3c dc        STB    $3CDC
a106: ce 00 00        LDU    #$0000
a109: 34 40           PSHS   U
a10b: 17 f9 01        LBSR   $9A0F
a10e: 32 62           LEAS   $2,S
a110: ce 00 00        LDU    #$0000
a113: 34 40           PSHS   U
a115: 17 f9 64        LBSR   $9A7C
a118: 32 62           LEAS   $2,S
a11a: e6 65           LDB    $5,S
a11c: c1 00           CMPB   #$00
a11e: 10 26 00 e0     LBNE   $A202
a122: fc 3c a4        LDD    $3CA4
a125: c3 00 01        ADDD   #$0001
a128: 10 b3 3c a2     CMPD   $3CA2
a12c: 10 26 00 38     LBNE   $A168
a130: be 3c a4        LDX    $3CA4
a133: bc 3c ce        CMPX   $3CCE
a136: 10 24 00 2e     LBCC   $A168
a13a: f6 3c d7        LDB    $3CD7
a13d: c1 00           CMPB   #$00
a13f: 10 27 00 04     LBEQ   $A147
a143: c6 01           LDB    #$01
a145: e7 64           STB    $4,S
a147: fc 3c a4        LDD    $3CA4
a14a: c3 00 01        ADDD   #$0001
a14d: fd 3c a4        STD    $3CA4
a150: ce 3c a4        LDU    #$3CA4
a153: 10 8e 00 02     LDY    #$0002
a157: 34 60           PSHS   U,Y
a159: 17 f4 ea        LBSR   $9646
a15c: 32 64           LEAS   $4,S
a15e: ce 00 00        LDU    #$0000
a161: 34 40           PSHS   U
a163: 17 f6 f9        LBSR   $985F
a166: 32 62           LEAS   $2,S
a168: be 3c a2        LDX    $3CA2
a16b: bc 3c a4        CMPX   $3CA4
a16e: 10 22 00 90     LBHI   $A202
a172: f6 3c d7        LDB    $3CD7
a175: c1 00           CMPB   #$00
a177: 10 27 00 46     LBEQ   $A1C1
a17b: e6 64           LDB    $4,S
a17d: c1 00           CMPB   #$00
a17f: 10 27 00 13     LBEQ   $A196
a183: be 3c a4        LDX    $3CA4
a186: 8c 00 00        CMPX   #$0000
a189: 10 23 00 09     LBLS   $A196
a18d: fc 3c a4        LDD    $3CA4
a190: 83 00 01        SUBD   #$0001
a193: fd 3c a4        STD    $3CA4
a196: e6 62           LDB    $2,S
a198: 4f              CLRA
a199: 1f 03           TFR    D,U
a19b: 10 8e 00 02     LDY    #$0002
a19f: 34 60           PSHS   U,Y
a1a1: 17 f3 73        LBSR   $9517
a1a4: 32 64           LEAS   $4,S
a1a6: ce 3c a2        LDU    #$3CA2
a1a9: 10 8e 00 02     LDY    #$0002
a1ad: 34 60           PSHS   U,Y
a1af: 17 f4 94        LBSR   $9646
a1b2: 32 64           LEAS   $4,S
a1b4: ce 00 00        LDU    #$0000
a1b7: 34 40           PSHS   U
a1b9: 17 f8 53        LBSR   $9A0F
a1bc: 32 62           LEAS   $2,S
a1be: 16 00 31        LBRA   $A1F2
a1c1: e6 62           LDB    $2,S
a1c3: 4f              CLRA
a1c4: 1f 03           TFR    D,U
a1c6: 10 be 3c a2     LDY    $3CA2
a1ca: 8e 00 04        LDX    #$0004
a1cd: 34 70           PSHS   U,Y,X
a1cf: 17 e1 6e        LBSR   $8340
a1d2: 32 66           LEAS   $6,S
a1d4: c6 02           LDB    #$02
a1d6: 1d              SEX
a1d7: 1f 03           TFR    D,U
a1d9: c6 15           LDB    #$15
a1db: 1d              SEX
a1dc: 1f 02           TFR    D,Y
a1de: e6 62           LDB    $2,S
a1e0: 4f              CLRA
a1e1: 1f 01           TFR    D,X
a1e3: fc 3c d4        LDD    $3CD4
a1e6: 34 76           PSHS   U,Y,X,D
a1e8: ce 00 08        LDU    #$0008
a1eb: 34 40           PSHS   U
a1ed: 17 f6 92        LBSR   $9882
a1f0: 32 6a           LEAS   $A,S
a1f2: c6 01           LDB    #$01
a1f4: 1d              SEX
a1f5: 1f 03           TFR    D,U
a1f7: 10 8e 00 02     LDY    #$0002
a1fb: 34 60           PSHS   U,Y
a1fd: 17 fc 08        LBSR   $9E08
a200: 32 64           LEAS   $4,S
a202: c6 0e           LDB    #$0E
a204: 1d              SEX
a205: 1f 03           TFR    D,U
a207: 10 8e 00 02     LDY    #$0002
a20b: 34 60           PSHS   U,Y
a20d: 17 f6 d9        LBSR   $98E9
a210: 32 64           LEAS   $4,S
a212: 16 01 40        LBRA   $A355
a215: be 3c ac        LDX    $3CAC
a218: 8c 00 0b        CMPX   #$000B
a21b: 10 26 00 14     LBNE   $A233
a21f: f6 3c 20        LDB    $3C20
a222: e7 63           STB    $3,S
a224: 5f              CLRB
a225: 1d              SEX
a226: 1f 03           TFR    D,U
a228: 10 8e 00 02     LDY    #$0002
a22c: 34 60           PSHS   U,Y
a22e: 17 f4 b8        LBSR   $96E9
a231: 32 64           LEAS   $4,S
a233: ec 9f 3c d0     LDD    [$3CD0]
a237: ed 66           STD    $6,S
a239: c6 06           LDB    #$06
a23b: 1d              SEX
a23c: 1f 03           TFR    D,U
a23e: 10 8e 00 08     LDY    #$0008
a242: 8e 00 04        LDX    #$0004
a245: 34 70           PSHS   U,Y,X
a247: 17 6b 97        LBSR   $0DE1
a24a: 32 66           LEAS   $6,S
a24c: c1 05           CMPB   #$05
a24e: 10 24 00 35     LBCC   $A287
a252: ce 24 14        LDU    #$2414
a255: 10 8e 00 02     LDY    #$0002
a259: 34 60           PSHS   U,Y
a25b: 17 67 15        LBSR   $0973
a25e: 32 64           LEAS   $4,S
a260: 83 00 01        SUBD   #$0001
a263: fd 22 1a        STD    $221A
a266: be 22 1a        LDX    $221A
a269: bc 3c cc        CMPX   $3CCC
a26c: 10 24 00 0a     LBCC   $A27A
a270: fc 22 1a        LDD    $221A
a273: ed 9f 3c d0     STD    [$3CD0]
a277: 16 00 0a        LBRA   $A284
a27a: ce 00 00        LDU    #$0000
a27d: 34 40           PSHS   U
a27f: 17 fd dc        LBSR   $A05E
a282: 32 62           LEAS   $2,S
a284: 16 00 0a        LBRA   $A291
a287: ce 00 00        LDU    #$0000
a28a: 34 40           PSHS   U
a28c: 17 fd cf        LBSR   $A05E
a28f: 32 62           LEAS   $2,S
a291: ee 66           LDU    $6,S
a293: 10 8e 00 02     LDY    #$0002
a297: 34 60           PSHS   U,Y
a299: 17 fa f5        LBSR   $9D91
a29c: 32 64           LEAS   $4,S
a29e: fe 3c d0        LDU    $3CD0
a2a1: 10 8e 00 02     LDY    #$0002
a2a5: 34 60           PSHS   U,Y
a2a7: 17 f3 9c        LBSR   $9646
a2aa: 32 64           LEAS   $4,S
a2ac: ce 00 00        LDU    #$0000
a2af: 34 40           PSHS   U
a2b1: 17 f4 f1        LBSR   $97A5
a2b4: 32 62           LEAS   $2,S
a2b6: be 3c ac        LDX    $3CAC
a2b9: 8c 00 0b        CMPX   #$000B
a2bc: 10 26 00 10     LBNE   $A2D0
a2c0: e6 63           LDB    $3,S
a2c2: 4f              CLRA
a2c3: 1f 03           TFR    D,U
a2c5: 10 8e 00 02     LDY    #$0002
a2c9: 34 60           PSHS   U,Y
a2cb: 17 f4 1b        LBSR   $96E9
a2ce: 32 64           LEAS   $4,S
a2d0: be 3c d0        LDX    $3CD0
a2d3: 8c 3c a2        CMPX   #$3CA2
a2d6: 10 26 00 06     LBNE   $A2E0
a2da: fc 3c a2        LDD    $3CA2
a2dd: fd 3c d2        STD    $3CD2
a2e0: f6 3c d6        LDB    $3CD6
a2e3: c1 00           CMPB   #$00
a2e5: 10 27 00 37     LBEQ   $A320
a2e9: ce 00 00        LDU    #$0000
a2ec: 34 40           PSHS   U
a2ee: 17 f6 55        LBSR   $9946
a2f1: 32 62           LEAS   $2,S
a2f3: be 3c d0        LDX    $3CD0
a2f6: 8c 3c a2        CMPX   #$3CA2
a2f9: 10 26 00 13     LBNE   $A310
a2fd: ce 00 04        LDU    #$0004
a300: 10 8e 00 02     LDY    #$0002
a304: 34 60           PSHS   U,Y
a306: be 3c 00        LDX    $3C00
a309: ad 84           JSR    ,X
a30b: 32 64           LEAS   $4,S
a30d: 16 00 10        LBRA   $A320
a310: ce 00 05        LDU    #$0005
a313: 10 8e 00 02     LDY    #$0002
a317: 34 60           PSHS   U,Y
a319: be 3c 00        LDX    $3C00
a31c: ad 84           JSR    ,X
a31e: 32 64           LEAS   $4,S
a320: c6 0e           LDB    #$0E
a322: 1d              SEX
a323: 1f 03           TFR    D,U
a325: 10 8e 00 02     LDY    #$0002
a329: 34 60           PSHS   U,Y
a32b: 17 f5 bb        LBSR   $98E9
a32e: 32 64           LEAS   $4,S
a330: 16 00 22        LBRA   $A355
a333: 16 00 1f        LBRA   $A355
a336: 8c 00 08        CMPX   #$0008
a339: 10 27 fe d8     LBEQ   $A215
a33d: 8c 00 09        CMPX   #$0009
a340: 10 27 fd 88     LBEQ   $A0CC
a344: 8c 00 0a        CMPX   #$000A
a347: 10 27 fe ca     LBEQ   $A215
a34b: 8c 00 0b        CMPX   #$000B
a34e: 10 27 fe c3     LBEQ   $A215
a352: 16 00 00        LBRA   $A355
a355: 32 68           LEAS   $8,S
a357: 39              RTS
a358: fc 66 3d        LDD    $663D
a35b: 17 99 f2        LBSR   $3D50
a35e: c6 01           LDB    #$01
a360: f7 3c d6        STB    $3CD6
a363: ae e9 00 06     LDX    $0006,S
a367: 8c 00 00        CMPX   #$0000
a36a: 10 26 00 08     LBNE   $A376
a36e: c6 0e           LDB    #$0E
a370: f7 3c cb        STB    $3CCB
a373: 16 00 10        LBRA   $A386
a376: e6 e9 00 07     LDB    $0007,S
a37a: f7 3c cb        STB    $3CCB
a37d: cc 3c a2        LDD    #$3CA2
a380: fd 3c d0        STD    $3CD0
a383: 7f 3c d6        CLR    $3CD6
a386: 32 62           LEAS   $2,S
a388: 39              RTS
a389: fc 66 3e        LDD    $663E
a38c: 17 99 c1        LBSR   $3D50
a38f: 6f 62           CLR    $2,S
a391: f6 3c 20        LDB    $3C20
a394: 16 00 7f        LBRA   $A416
a397: ae e9 00 08     LDX    $0008,S
a39b: 8c 00 30        CMPX   #$0030
a39e: 10 27 00 0e     LBEQ   $A3B0
a3a2: ae e9 00 08     LDX    $0008,S
a3a6: 8c 00 31        CMPX   #$0031
a3a9: 10 27 00 03     LBEQ   $A3B0
a3ad: 16 00 04        LBRA   $A3B4
a3b0: c6 01           LDB    #$01
a3b2: e7 62           STB    $2,S
a3b4: 16 00 70        LBRA   $A427
a3b7: ae e9 00 08     LDX    $0008,S
a3bb: 8c 00 30        CMPX   #$0030
a3be: 10 25 00 0e     LBCS   $A3D0
a3c2: ae e9 00 08     LDX    $0008,S
a3c6: 8c 00 37        CMPX   #$0037
a3c9: 10 22 00 03     LBHI   $A3D0
a3cd: 16 00 03        LBRA   $A3D3
a3d0: 16 00 04        LBRA   $A3D7
a3d3: c6 01           LDB    #$01
a3d5: e7 62           STB    $2,S
a3d7: 16 00 4d        LBRA   $A427
a3da: ae e9 00 08     LDX    $0008,S
a3de: 8c 00 30        CMPX   #$0030
a3e1: 10 25 00 0e     LBCS   $A3F3
a3e5: ae e9 00 08     LDX    $0008,S
a3e9: 8c 00 39        CMPX   #$0039
a3ec: 10 22 00 03     LBHI   $A3F3
a3f0: 16 00 1c        LBRA   $A40F
a3f3: ae e9 00 08     LDX    $0008,S
a3f7: 8c 00 41        CMPX   #$0041
a3fa: 10 25 00 0e     LBCS   $A40C
a3fe: ae e9 00 08     LDX    $0008,S
a402: 8c 00 46        CMPX   #$0046
a405: 10 22 00 03     LBHI   $A40C
a409: 16 00 03        LBRA   $A40F
a40c: 16 00 04        LBRA   $A413
a40f: c6 01           LDB    #$01
a411: e7 62           STB    $2,S
a413: 16 00 11        LBRA   $A427
a416: c1 00           CMPB   #$00
a418: 10 27 ff 7b     LBEQ   $A397
a41c: c1 01           CMPB   #$01
a41e: 27 97           BEQ    $A3B7
a420: c1 02           CMPB   #$02
a422: 27 b6           BEQ    $A3DA
a424: 16 00 00        LBRA   $A427
a427: e6 62           LDB    $2,S
a429: e7 63           STB    $3,S
a42b: 32 64           LEAS   $4,S
a42d: 39              RTS
a42e: fc 66 3b        LDD    $663B
a431: 17 99 1c        LBSR   $3D50
a434: 6f 62           CLR    $2,S
a436: ec e9 00 0a     LDD    $000A,S
a43a: 84 00           ANDA   #$00
a43c: c4 7f           ANDB   #$7F
a43e: ed e9 00 0a     STD    $000A,S
a442: ae e9 00 0a     LDX    $000A,S
a446: 8c 00 20        CMPX   #$0020
a449: 10 26 00 07     LBNE   $A454
a44d: c6 01           LDB    #$01
a44f: e7 62           STB    $2,S
a451: 16 01 04        LBRA   $A558
a454: ee e9 00 0a     LDU    $000A,S
a458: 10 8e 00 02     LDY    #$0002
a45c: 34 60           PSHS   U,Y
a45e: 17 ff 28        LBSR   $A389
a461: 32 64           LEAS   $4,S
a463: c1 00           CMPB   #$00
a465: 10 27 00 ef     LBEQ   $A558
a469: c6 30           LDB    #$30
a46b: f7 24 14        STB    $2414
a46e: e6 e9 00 0b     LDB    $000B,S
a472: f7 24 15        STB    $2415
a475: ce 24 14        LDU    #$2414
a478: 10 8e 00 02     LDY    #$0002
a47c: 34 60           PSHS   U,Y
a47e: 17 67 d2        LBSR   $0C53
a481: 32 64           LEAS   $4,S
a483: f7 22 19        STB    $2219
a486: f6 22 19        LDB    $2219
a489: 4f              CLRA
a48a: 1f 03           TFR    D,U
a48c: 10 be 3c d8     LDY    $3CD8
a490: 8e 00 04        LDX    #$0004
a493: 34 70           PSHS   U,Y,X
a495: 17 de a8        LBSR   $8340
a498: 32 66           LEAS   $6,S
a49a: f6 3c 1f        LDB    $3C1F
a49d: c1 02           CMPB   #$02
a49f: 10 26 00 4b     LBNE   $A4EE
a4a3: be 3c d8        LDX    $3CD8
a4a6: bc 3c d2        CMPX   $3CD2
a4a9: 10 25 00 3e     LBCS   $A4EB
a4ad: be 3c d8        LDX    $3CD8
a4b0: bc 3c a4        CMPX   $3CA4
a4b3: 10 22 00 34     LBHI   $A4EB
a4b7: fc 3c d2        LDD    $3CD2
a4ba: c3 00 0f        ADDD   #$000F
a4bd: 10 b3 3c d8     CMPD   $3CD8
a4c1: 10 25 00 26     LBCS   $A4EB
a4c5: fc 3c d8        LDD    $3CD8
a4c8: b3 3c d2        SUBD   $3CD2
a4cb: ed 63           STD    $3,S
a4cd: c6 02           LDB    #$02
a4cf: 1d              SEX
a4d0: 1f 03           TFR    D,U
a4d2: c6 15           LDB    #$15
a4d4: 1d              SEX
a4d5: 1f 02           TFR    D,Y
a4d7: f6 22 19        LDB    $2219
a4da: 4f              CLRA
a4db: 1f 01           TFR    D,X
a4dd: ec 63           LDD    $3,S
a4df: 34 76           PSHS   U,Y,X,D
a4e1: ce 00 08        LDU    #$0008
a4e4: 34 40           PSHS   U
a4e6: 17 f3 99        LBSR   $9882
a4e9: 32 6a           LEAS   $A,S
a4eb: 16 00 4d        LBRA   $A53B
a4ee: f6 3c 1f        LDB    $3C1F
a4f1: c1 03           CMPB   #$03
a4f3: 10 26 00 44     LBNE   $A53B
a4f7: be 3c d8        LDX    $3CD8
a4fa: bc 3c a2        CMPX   $3CA2
a4fd: 10 26 00 3a     LBNE   $A53B
a501: f6 3c 04        LDB    $3C04
a504: c1 00           CMPB   #$00
a506: 10 27 00 31     LBEQ   $A53B
a50a: c6 0e           LDB    #$0E
a50c: 1d              SEX
a50d: 1f 03           TFR    D,U
a50f: 10 8e 00 02     LDY    #$0002
a513: 34 60           PSHS   U,Y
a515: 17 f3 d1        LBSR   $98E9
a518: 32 64           LEAS   $4,S
a51a: ce 00 00        LDU    #$0000
a51d: 34 40           PSHS   U
a51f: 17 ef bd        LBSR   $94DF
a522: 32 62           LEAS   $2,S
a524: e7 65           STB    $5,S
a526: f6 3c 04        LDB    $3C04
a529: 4f              CLRA
a52a: 1f 03           TFR    D,U
a52c: e6 65           LDB    $5,S
a52e: 4f              CLRA
a52f: 1f 02           TFR    D,Y
a531: 8e 00 04        LDX    #$0004
a534: 34 70           PSHS   U,Y,X
a536: 17 ec bd        LBSR   $91F6
a539: 32 66           LEAS   $6,S
a53b: fc 3c d8        LDD    $3CD8
a53e: c3 00 01        ADDD   #$0001
a541: fd 3c d8        STD    $3CD8
a544: be 3c d8        LDX    $3CD8
a547: bc 3c ce        CMPX   $3CCE
a54a: 10 23 00 06     LBLS   $A554
a54e: fc 3c ce        LDD    $3CCE
a551: fd 3c d8        STD    $3CD8
a554: c6 01           LDB    #$01
a556: e7 62           STB    $2,S
a558: e6 62           LDB    $2,S
a55a: e7 65           STB    $5,S
a55c: 32 66           LEAS   $6,S
a55e: 39              RTS
a55f: fc 66 3d        LDD    $663D
a562: 17 97 eb        LBSR   $3D50
a565: f6 3c d7        LDB    $3CD7
a568: c1 00           CMPB   #$00
a56a: 10 27 00 0d     LBEQ   $A57B
a56e: 7f 3c d7        CLR    $3CD7
a571: ce 00 00        LDU    #$0000
a574: 34 40           PSHS   U
a576: 17 f3 cd        LBSR   $9946
a579: 32 62           LEAS   $2,S
a57b: cc 00 09        LDD    #$0009
a57e: fd 3c ac        STD    $3CAC
a581: cc 64 2e        LDD    #$642E
a584: 1f 03           TFR    D,U
a586: 10 8e 00 02     LDY    #$0002
a58a: 34 60           PSHS   U,Y
a58c: 17 3e 54        LBSR   $E3E3
a58f: 32 64           LEAS   $4,S
a591: fc 3c a2        LDD    $3CA2
a594: fd 3c d8        STD    $3CD8
a597: 32 62           LEAS   $2,S
a599: 39              RTS
a59a: fc 66 3d        LDD    $663D
a59d: 17 97 b0        LBSR   $3D50
a5a0: 7f 3c ca        CLR    $3CCA
a5a3: 7f 3c d7        CLR    $3CD7
a5a6: ae e9 00 06     LDX    $0006,S
a5aa: 8c 00 00        CMPX   #$0000
a5ad: 10 26 00 52     LBNE   $A603
a5b1: c6 02           LDB    #$02
a5b3: f7 3c 20        STB    $3C20
a5b6: 5f              CLRB
a5b7: 4f              CLRA
a5b8: fd 3c a2        STD    $3CA2
a5bb: be 3c a2        LDX    $3CA2
a5be: 8c 00 fa        CMPX   #$00FA
a5c1: 10 24 00 22     LBCC   $A5E7
a5c5: fc 3c a2        LDD    $3CA2
a5c8: 84 00           ANDA   #$00
a5ca: c4 0f           ANDB   #$0F
a5cc: 1f 03           TFR    D,U
a5ce: 10 be 3c a2     LDY    $3CA2
a5d2: 8e 00 04        LDX    #$0004
a5d5: 34 70           PSHS   U,Y,X
a5d7: 17 dd 66        LBSR   $8340
a5da: 32 66           LEAS   $6,S
a5dc: fc 3c a2        LDD    $3CA2
a5df: c3 00 01        ADDD   #$0001
a5e2: fd 3c a2        STD    $3CA2
a5e5: 20 d4           BRA    $A5BB
a5e7: 5f              CLRB
a5e8: 4f              CLRA
a5e9: fd 3c a2        STD    $3CA2
a5ec: cc 00 f9        LDD    #$00F9
a5ef: fd 3c a4        STD    $3CA4
a5f2: 5f              CLRB
a5f3: 4f              CLRA
a5f4: fd 3c a6        STD    $3CA6
a5f7: cc 03 e7        LDD    #$03E7
a5fa: fd 3c a8        STD    $3CA8
a5fd: fc 3c a8        LDD    $3CA8
a600: fd 3c aa        STD    $3CAA
a603: f6 3c 20        LDB    $3C20
a606: 4f              CLRA
a607: 1f 03           TFR    D,U
a609: 10 8e 00 02     LDY    #$0002
a60d: 34 60           PSHS   U,Y
a60f: 17 f0 91        LBSR   $96A3
a612: 32 64           LEAS   $4,S
a614: cc 3c a2        LDD    #$3CA2
a617: fd 3c d0        STD    $3CD0
a61a: fc 3c a2        LDD    $3CA2
a61d: fd 3c d2        STD    $3CD2
a620: 5f              CLRB
a621: 4f              CLRA
a622: fd 3c d4        STD    $3CD4
a625: 5f              CLRB
a626: 1d              SEX
a627: 1f 03           TFR    D,U
a629: 10 8e 00 02     LDY    #$0002
a62d: 34 60           PSHS   U,Y
a62f: 17 fd 26        LBSR   $A358
a632: 32 64           LEAS   $4,S
a634: 32 62           LEAS   $2,S
a636: 39              RTS
a637: 00 03           NEG    <$03
a639: 00 05           NEG    <$05
a63b: 00 04           NEG    <$04
a63d: 00 00           NEG    <$00
a63f: 02 00           XNC    <$00
a641: 07 00           ASR    <$00
a643: 08 00           ASL    <$00
a645: 06 fc           ROR    <$FC
a647: 73 8a 17        COM    $8A17
a64a: 97 04           STA    <$04
a64c: ae e9 00 0d     LDX    $000D,S
a650: 16 00 92        LBRA   $A6E5
a653: f6 3c dd        LDB    $3CDD
a656: c1 00           CMPB   #$00
a658: 10 27 00 08     LBEQ   $A664
a65c: cc 00 03        LDD    #$0003
a65f: ed 67           STD    $7,S
a661: 16 00 05        LBRA   $A669
a664: cc 00 02        LDD    #$0002
a667: ed 67           STD    $7,S
a669: cc 00 04        LDD    #$0004
a66c: ed 65           STD    $5,S
a66e: c6 06           LDB    #$06
a670: e7 62           STB    $2,S
a672: f6 3c b8        LDB    $3CB8
a675: c1 00           CMPB   #$00
a677: 10 27 00 0b     LBEQ   $A686
a67b: c6 5f           LDB    #$5F
a67d: e7 63           STB    $3,S
a67f: c6 66           LDB    #$66
a681: e7 64           STB    $4,S
a683: 16 00 08        LBRA   $A68E
a686: c6 4a           LDB    #$4A
a688: e7 63           STB    $3,S
a68a: c6 51           LDB    #$51
a68c: e7 64           STB    $4,S
a68e: 16 00 77        LBRA   $A708
a691: cc 00 03        LDD    #$0003
a694: ed 67           STD    $7,S
a696: cc 00 05        LDD    #$0005
a699: ed 65           STD    $5,S
a69b: c6 06           LDB    #$06
a69d: e7 62           STB    $2,S
a69f: c6 1e           LDB    #$1E
a6a1: e7 63           STB    $3,S
a6a3: c6 25           LDB    #$25
a6a5: e7 64           STB    $4,S
a6a7: 16 00 5e        LBRA   $A708
a6aa: 5f              CLRB
a6ab: 4f              CLRA
a6ac: ed 67           STD    $7,S
a6ae: cc 00 02        LDD    #$0002
a6b1: ed 65           STD    $5,S
a6b3: c6 04           LDB    #$04
a6b5: e7 62           STB    $2,S
a6b7: f6 3c cb        LDB    $3CCB
a6ba: e7 63           STB    $3,S
a6bc: 16 00 49        LBRA   $A708
a6bf: 5f              CLRB
a6c0: 4f              CLRA
a6c1: ed 67           STD    $7,S
a6c3: cc 00 02        LDD    #$0002
a6c6: ed 65           STD    $5,S
a6c8: c6 04           LDB    #$04
a6ca: e7 62           STB    $2,S
a6cc: c6 4c           LDB    #$4C
a6ce: e7 63           STB    $3,S
a6d0: 16 00 35        LBRA   $A708
a6d3: cc 00 01        LDD    #$0001
a6d6: ed 67           STD    $7,S
a6d8: 5f              CLRB
a6d9: 4f              CLRA
a6da: ed 65           STD    $5,S
a6dc: 6f 62           CLR    $2,S
a6de: c6 0c           LDB    #$0C
a6e0: e7 63           STB    $3,S
a6e2: 16 00 23        LBRA   $A708
a6e5: 8c 00 06        CMPX   #$0006
a6e8: 10 2e 00 1c     LBGT   $A708
a6ec: 1f 10           TFR    X,D
a6ee: 83 00 01        SUBD   #$0001
a6f1: 10 2d 00 13     LBLT   $A708
a6f5: 8e 66 fc        LDX    #$66FC
a6f8: 58              ASLB
a6f9: 49              ROLA
a6fa: 6e 9b           JMP    [D,X]
a6fc: 66 53           ROR    -$D,U
a6fe: 66 91           ROR    [,X++]
a700: 67 08           ASR    $8,X
a702: 66 aa           ROR    F,Y
a704: 66 bf 66 d3     ROR    [$66D3]
a708: e6 64           LDB    $4,S
a70a: 4f              CLRA
a70b: 1f 03           TFR    D,U
a70d: 10 ae 65        LDY    $5,S
a710: e6 63           LDB    $3,S
a712: 4f              CLRA
a713: 1f 01           TFR    D,X
a715: e6 62           LDB    $2,S
a717: 4f              CLRA
a718: 34 76           PSHS   U,Y,X,D
a71a: ee 6f           LDU    $F,S
a71c: 10 8e 00 0a     LDY    #$000A
a720: 34 60           PSHS   U,Y
a722: 17 45 10        LBSR   $EC35
a725: 32 6c           LEAS   $C,S
a727: 32 69           LEAS   $9,S
a729: 39              RTS
a72a: fc 73 8c        LDD    $738C
a72d: 17 96 20        LBSR   $3D50
a730: f6 26 8e        LDB    $268E
a733: f7 3c 1f        STB    $3C1F
a736: f6 26 8e        LDB    $268E
a739: 16 00 4f        LBRA   $A78B
a73c: 5f              CLRB
a73d: 1d              SEX
a73e: 1f 03           TFR    D,U
a740: 10 8e 00 02     LDY    #$0002
a744: 34 60           PSHS   U,Y
a746: 17 fc 0f        LBSR   $A358
a749: 32 64           LEAS   $4,S
a74b: 16 00 48        LBRA   $A796
a74e: c6 08           LDB    #$08
a750: 1d              SEX
a751: 1f 03           TFR    D,U
a753: 10 8e 00 02     LDY    #$0002
a757: 34 60           PSHS   U,Y
a759: 17 fb fc        LBSR   $A358
a75c: 32 64           LEAS   $4,S
a75e: f6 3c 04        LDB    $3C04
a761: c1 00           CMPB   #$00
a763: 10 27 00 21     LBEQ   $A788
a767: ce 00 00        LDU    #$0000
a76a: 34 40           PSHS   U
a76c: 17 ed 70        LBSR   $94DF
a76f: 32 62           LEAS   $2,S
a771: e7 62           STB    $2,S
a773: f6 3c 04        LDB    $3C04
a776: 4f              CLRA
a777: 1f 03           TFR    D,U
a779: e6 62           LDB    $2,S
a77b: 4f              CLRA
a77c: 1f 02           TFR    D,Y
a77e: 8e 00 04        LDX    #$0004
a781: 34 70           PSHS   U,Y,X
a783: 17 ea 70        LBSR   $91F6
a786: 32 66           LEAS   $6,S
a788: 16 00 0b        LBRA   $A796
a78b: c1 02           CMPB   #$02
a78d: 27 ad           BEQ    $A73C
a78f: c1 03           CMPB   #$03
a791: 27 bb           BEQ    $A74E
a793: 16 00 00        LBRA   $A796
a796: ce 00 00        LDU    #$0000
a799: 34 40           PSHS   U
a79b: 17 e2 07        LBSR   $89A5
a79e: 32 62           LEAS   $2,S
a7a0: 32 63           LEAS   $3,S
a7a2: 39              RTS
a7a3: fc 73 8c        LDD    $738C
a7a6: 17 95 a7        LBSR   $3D50
a7a9: ae e9 00 07     LDX    $0007,S
a7ad: 8c 00 00        CMPX   #$0000
a7b0: 10 27 00 5e     LBEQ   $A812
a7b4: c6 01           LDB    #$01
a7b6: f7 3c 02        STB    $3C02
a7b9: ce 00 00        LDU    #$0000
a7bc: 34 40           PSHS   U
a7be: 17 ed 1e        LBSR   $94DF
a7c1: 32 62           LEAS   $2,S
a7c3: e7 62           STB    $2,S
a7c5: f6 3c 04        LDB    $3C04
a7c8: 4f              CLRA
a7c9: 1f 03           TFR    D,U
a7cb: e6 62           LDB    $2,S
a7cd: 4f              CLRA
a7ce: 1f 02           TFR    D,Y
a7d0: 8e 00 04        LDX    #$0004
a7d3: 34 70           PSHS   U,Y,X
a7d5: 17 ea 1e        LBSR   $91F6
a7d8: 32 66           LEAS   $6,S
a7da: ce 00 00        LDU    #$0000
a7dd: 34 40           PSHS   U
a7df: 17 e0 c6        LBSR   $88A8
a7e2: 32 62           LEAS   $2,S
a7e4: fc 22 04        LDD    $2204
a7e7: 84 00           ANDA   #$00
a7e9: c4 08           ANDB   #$08
a7eb: 10 83 00 00     CMPD   #$0000
a7ef: 10 27 00 12     LBEQ   $A805
a7f3: ce 00 ff        LDU    #$00FF
a7f6: c6 02           LDB    #$02
a7f8: 1d              SEX
a7f9: 1f 02           TFR    D,Y
a7fb: 8e 00 04        LDX    #$0004
a7fe: 34 70           PSHS   U,Y,X
a800: 17 35 d0        LBSR   $DDD3
a803: 32 66           LEAS   $6,S
a805: ce 00 00        LDU    #$0000
a808: 34 40           PSHS   U
a80a: 17 eb 8b        LBSR   $9398
a80d: 32 62           LEAS   $2,S
a80f: 16 00 62        LBRA   $A874
a812: f6 3c 02        LDB    $3C02
a815: c1 00           CMPB   #$00
a817: 10 27 00 21     LBEQ   $A83C
a81b: fc 22 04        LDD    $2204
a81e: 84 00           ANDA   #$00
a820: c4 08           ANDB   #$08
a822: 10 83 00 00     CMPD   #$0000
a826: 10 27 00 12     LBEQ   $A83C
a82a: ce 00 ff        LDU    #$00FF
a82d: c6 03           LDB    #$03
a82f: 1d              SEX
a830: 1f 02           TFR    D,Y
a832: 8e 00 04        LDX    #$0004
a835: 34 70           PSHS   U,Y,X
a837: 17 35 99        LBSR   $DDD3
a83a: 32 66           LEAS   $6,S
a83c: 7f 3c 02        CLR    $3C02
a83f: ce 00 00        LDU    #$0000
a842: 34 40           PSHS   U
a844: 17 e0 61        LBSR   $88A8
a847: 32 62           LEAS   $2,S
a849: ce 00 00        LDU    #$0000
a84c: 34 40           PSHS   U
a84e: 17 eb 94        LBSR   $93E5
a851: 32 62           LEAS   $2,S
a853: ce 00 00        LDU    #$0000
a856: 34 40           PSHS   U
a858: 17 ec 84        LBSR   $94DF
a85b: 32 62           LEAS   $2,S
a85d: e7 62           STB    $2,S
a85f: f6 3c 04        LDB    $3C04
a862: 4f              CLRA
a863: 1f 03           TFR    D,U
a865: e6 62           LDB    $2,S
a867: 4f              CLRA
a868: 1f 02           TFR    D,Y
a86a: 8e 00 04        LDX    #$0004
a86d: 34 70           PSHS   U,Y,X
a86f: 17 e9 84        LBSR   $91F6
a872: 32 66           LEAS   $6,S
a874: 32 63           LEAS   $3,S
a876: 39              RTS
a877: fc 73 8e        LDD    $738E
a87a: 17 94 d3        LBSR   $3D50
a87d: f6 3c dd        LDB    $3CDD
a880: c1 00           CMPB   #$00
a882: 10 27 00 12     LBEQ   $A898
a886: ce 00 00        LDU    #$0000
a889: 34 40           PSHS   U
a88b: 17 5f f7        LBSR   $0885
a88e: 32 62           LEAS   $2,S
a890: 7f 3c dd        CLR    $3CDD
a893: be 3c da        LDX    $3CDA
a896: ad 84           JSR    ,X
a898: 32 62           LEAS   $2,S
a89a: 39              RTS
a89b: fc 73 8e        LDD    $738E
a89e: 17 94 af        LBSR   $3D50
a8a1: be 3c ac        LDX    $3CAC
a8a4: 8c 00 0e        CMPX   #$000E
a8a7: 10 27 00 19     LBEQ   $A8C4
a8ab: cc 00 0e        LDD    #$000E
a8ae: fd 3c ac        STD    $3CAC
a8b1: ce 00 06        LDU    #$0006
a8b4: 10 8e 00 02     LDY    #$0002
a8b8: 34 60           PSHS   U,Y
a8ba: be 3c 00        LDX    $3C00
a8bd: ad 84           JSR    ,X
a8bf: 32 64           LEAS   $4,S
a8c1: 16 00 10        LBRA   $A8D4
a8c4: c6 01           LDB    #$01
a8c6: 1d              SEX
a8c7: 1f 03           TFR    D,U
a8c9: 10 8e 00 02     LDY    #$0002
a8cd: 34 60           PSHS   U,Y
a8cf: 17 e5 c8        LBSR   $8E9A
a8d2: 32 64           LEAS   $4,S
a8d4: 32 62           LEAS   $2,S
a8d6: 39              RTS
a8d7: fc 73 8e        LDD    $738E
a8da: 17 94 73        LBSR   $3D50
a8dd: 7f 3c 04        CLR    $3C04
a8e0: f6 3c 02        LDB    $3C02
a8e3: c1 00           CMPB   #$00
a8e5: 10 27 00 12     LBEQ   $A8FB
a8e9: 5f              CLRB
a8ea: 1d              SEX
a8eb: 1f 03           TFR    D,U
a8ed: 10 8e 00 02     LDY    #$0002
a8f1: 34 60           PSHS   U,Y
a8f3: 17 fe ad        LBSR   $A7A3
a8f6: 32 64           LEAS   $4,S
a8f8: 16 00 0a        LBRA   $A905
a8fb: ce 00 00        LDU    #$0000
a8fe: 34 40           PSHS   U
a900: 17 df a5        LBSR   $88A8
a903: 32 62           LEAS   $2,S
a905: 5f              CLRB
a906: 1d              SEX
a907: 1f 03           TFR    D,U
a909: 10 8e 00 02     LDY    #$0002
a90d: 34 60           PSHS   U,Y
a90f: 17 e8 b6        LBSR   $91C8
a912: 32 64           LEAS   $4,S
a914: 32 62           LEAS   $2,S
a916: 39              RTS
a917: fc 73 8e        LDD    $738E
a91a: 17 94 33        LBSR   $3D50
a91d: cc 00 05        LDD    #$0005
a920: fd 3c ac        STD    $3CAC
a923: ce 00 00        LDU    #$0000
a926: 34 40           PSHS   U
a928: 17 ff 4c        LBSR   $A877
a92b: 32 62           LEAS   $2,S
a92d: ce 00 02        LDU    #$0002
a930: 10 8e 00 02     LDY    #$0002
a934: 34 60           PSHS   U,Y
a936: be 3c 00        LDX    $3C00
a939: ad 84           JSR    ,X
a93b: 32 64           LEAS   $4,S
a93d: 32 62           LEAS   $2,S
a93f: 39              RTS
a940: fc 73 8e        LDD    $738E
a943: 17 94 0a        LBSR   $3D50
a946: ce 00 00        LDU    #$0000
a949: 34 40           PSHS   U
a94b: 17 ff 29        LBSR   $A877
a94e: 32 62           LEAS   $2,S
a950: 7f 3c b8        CLR    $3CB8
a953: ce 00 00        LDU    #$0000
a956: 34 40           PSHS   U
a958: 17 db 42        LBSR   $849D
a95b: 32 62           LEAS   $2,S
a95d: cc 00 03        LDD    #$0003
a960: fd 3c ac        STD    $3CAC
a963: ce 00 01        LDU    #$0001
a966: 10 8e 00 02     LDY    #$0002
a96a: 34 60           PSHS   U,Y
a96c: be 3c 00        LDX    $3C00
a96f: ad 84           JSR    ,X
a971: 32 64           LEAS   $4,S
a973: 32 62           LEAS   $2,S
a975: 39              RTS
a976: fc 73 8e        LDD    $738E
a979: 17 93 d4        LBSR   $3D50
a97c: ce 00 00        LDU    #$0000
a97f: 34 40           PSHS   U
a981: 17 fe f3        LBSR   $A877
a984: 32 62           LEAS   $2,S
a986: c6 01           LDB    #$01
a988: f7 3c b8        STB    $3CB8
a98b: ce 00 00        LDU    #$0000
a98e: 34 40           PSHS   U
a990: 17 db 0a        LBSR   $849D
a993: 32 62           LEAS   $2,S
a995: cc 00 03        LDD    #$0003
a998: fd 3c ac        STD    $3CAC
a99b: ce 00 01        LDU    #$0001
a99e: 10 8e 00 02     LDY    #$0002
a9a2: 34 60           PSHS   U,Y
a9a4: be 3c 00        LDX    $3C00
a9a7: ad 84           JSR    ,X
a9a9: 32 64           LEAS   $4,S
a9ab: 32 62           LEAS   $2,S
a9ad: 39              RTS
a9ae: fc 73 8c        LDD    $738C
a9b1: 17 93 9c        LBSR   $3D50
a9b4: cc 00 0b        LDD    #$000B
a9b7: fd 3c ac        STD    $3CAC
a9ba: c6 01           LDB    #$01
a9bc: f7 3c 04        STB    $3C04
a9bf: ce 00 00        LDU    #$0000
a9c2: 34 40           PSHS   U
a9c4: 17 eb 18        LBSR   $94DF
a9c7: 32 62           LEAS   $2,S
a9c9: e7 62           STB    $2,S
a9cb: f6 3c 04        LDB    $3C04
a9ce: 4f              CLRA
a9cf: 1f 03           TFR    D,U
a9d1: e6 62           LDB    $2,S
a9d3: 4f              CLRA
a9d4: 1f 02           TFR    D,Y
a9d6: 8e 00 04        LDX    #$0004
a9d9: 34 70           PSHS   U,Y,X
a9db: 17 e8 18        LBSR   $91F6
a9de: 32 66           LEAS   $6,S
a9e0: ce 00 00        LDU    #$0000
a9e3: 34 40           PSHS   U
a9e5: 17 de c0        LBSR   $88A8
a9e8: 32 62           LEAS   $2,S
a9ea: 32 63           LEAS   $3,S
a9ec: 39              RTS
a9ed: fc 73 8e        LDD    $738E
a9f0: 17 93 5d        LBSR   $3D50
a9f3: f6 3c 02        LDB    $3C02
a9f6: c1 00           CMPB   #$00
a9f8: 10 26 00 19     LBNE   $AA15
a9fc: ce 00 00        LDU    #$0000
a9ff: 34 40           PSHS   U
aa01: 8d ab           BSR    $A9AE
aa03: 32 62           LEAS   $2,S
aa05: ce 00 04        LDU    #$0004
aa08: 10 8e 00 02     LDY    #$0002
aa0c: 34 60           PSHS   U,Y
aa0e: be 3c 00        LDX    $3C00
aa11: ad 84           JSR    ,X
aa13: 32 64           LEAS   $4,S
aa15: 32 62           LEAS   $2,S
aa17: 39              RTS
aa18: fc 73 8e        LDD    $738E
aa1b: 17 93 32        LBSR   $3D50
aa1e: 5f              CLRB
aa1f: 4f              CLRA
aa20: fd 3c ac        STD    $3CAC
aa23: 7f 3c 04        CLR    $3C04
aa26: 7f 3c 03        CLR    $3C03
aa29: f6 3c 02        LDB    $3C02
aa2c: c1 00           CMPB   #$00
aa2e: 10 27 00 0a     LBEQ   $AA3C
aa32: ce 00 00        LDU    #$0000
aa35: 34 40           PSHS   U
aa37: 17 e9 ab        LBSR   $93E5
aa3a: 32 62           LEAS   $2,S
aa3c: 5f              CLRB
aa3d: 1d              SEX
aa3e: 1f 03           TFR    D,U
aa40: 10 8e 00 02     LDY    #$0002
aa44: 34 60           PSHS   U,Y
aa46: 17 fd 5a        LBSR   $A7A3
aa49: 32 64           LEAS   $4,S
aa4b: c6 01           LDB    #$01
aa4d: 1d              SEX
aa4e: 1f 03           TFR    D,U
aa50: 10 8e 00 02     LDY    #$0002
aa54: 34 60           PSHS   U,Y
aa56: 17 fd 4a        LBSR   $A7A3
aa59: 32 64           LEAS   $4,S
aa5b: 32 62           LEAS   $2,S
aa5d: 39              RTS
aa5e: fc 73 8e        LDD    $738E
aa61: 17 92 ec        LBSR   $3D50
aa64: 7f 3c 04        CLR    $3C04
aa67: c6 01           LDB    #$01
aa69: f7 3c 03        STB    $3C03
aa6c: f6 3c 02        LDB    $3C02
aa6f: c1 00           CMPB   #$00
aa71: 10 27 00 0a     LBEQ   $AA7F
aa75: ce 00 00        LDU    #$0000
aa78: 34 40           PSHS   U
aa7a: 17 e9 68        LBSR   $93E5
aa7d: 32 62           LEAS   $2,S
aa7f: 5f              CLRB
aa80: 1d              SEX
aa81: 1f 03           TFR    D,U
aa83: 10 8e 00 02     LDY    #$0002
aa87: 34 60           PSHS   U,Y
aa89: 17 fd 17        LBSR   $A7A3
aa8c: 32 64           LEAS   $4,S
aa8e: c6 01           LDB    #$01
aa90: 1d              SEX
aa91: 1f 03           TFR    D,U
aa93: 10 8e 00 02     LDY    #$0002
aa97: 34 60           PSHS   U,Y
aa99: 17 fd 07        LBSR   $A7A3
aa9c: 32 64           LEAS   $4,S
aa9e: 32 62           LEAS   $2,S
aaa0: 39              RTS
aaa1: fc 73 8e        LDD    $738E
aaa4: 17 92 a9        LBSR   $3D50
aaa7: 5f              CLRB
aaa8: 4f              CLRA
aaa9: fd 3c ac        STD    $3CAC
aaac: ce 00 00        LDU    #$0000
aaaf: 34 40           PSHS   U
aab1: 8d ab           BSR    $AA5E
aab3: 32 62           LEAS   $2,S
aab5: 32 62           LEAS   $2,S
aab7: 39              RTS
aab8: fc 73 8e        LDD    $738E
aabb: 17 92 92        LBSR   $3D50
aabe: 5f              CLRB
aabf: 4f              CLRA
aac0: fd 3c ac        STD    $3CAC
aac3: ce 00 00        LDU    #$0000
aac6: 34 40           PSHS   U
aac8: 17 fe 0c        LBSR   $A8D7
aacb: 32 62           LEAS   $2,S
aacd: 32 62           LEAS   $2,S
aacf: 39              RTS
aad0: fc 73 8f        LDD    $738F
aad3: 17 92 7a        LBSR   $3D50
aad6: 7f 3c dc        CLR    $3CDC
aad9: 5f              CLRB
aada: 1d              SEX
aadb: 1f 03           TFR    D,U
aadd: 10 8e 00 02     LDY    #$0002
aae1: 34 60           PSHS   U,Y
aae3: 17 e6 9c        LBSR   $9182
aae6: 32 64           LEAS   $4,S
aae8: f6 23 be        LDB    $23BE
aaeb: e7 62           STB    $2,S
aaed: f6 23 be        LDB    $23BE
aaf0: c1 00           CMPB   #$00
aaf2: 10 27 00 0d     LBEQ   $AB03
aaf6: 7f 23 be        CLR    $23BE
aaf9: ce 00 00        LDU    #$0000
aafc: 34 40           PSHS   U
aafe: 17 57 19        LBSR   $021A
ab01: 32 62           LEAS   $2,S
ab03: be 22 17        LDX    $2217
ab06: 16 03 4b        LBRA   $AE54
ab09: ce 00 00        LDU    #$0000
ab0c: 34 40           PSHS   U
ab0e: 17 fd 66        LBSR   $A877
ab11: 32 62           LEAS   $2,S
ab13: ce 00 00        LDU    #$0000
ab16: 34 40           PSHS   U
ab18: 17 1f 14        LBSR   $CA2F
ab1b: 32 62           LEAS   $2,S
ab1d: 16 03 bf        LBRA   $AEDF
ab20: ce 00 00        LDU    #$0000
ab23: 34 40           PSHS   U
ab25: 17 fd 4f        LBSR   $A877
ab28: 32 62           LEAS   $2,S
ab2a: ce 00 00        LDU    #$0000
ab2d: 34 40           PSHS   U
ab2f: 17 1e fd        LBSR   $CA2F
ab32: 32 62           LEAS   $2,S
ab34: 5f              CLRB
ab35: 4f              CLRA
ab36: fd 3c ac        STD    $3CAC
ab39: ce 00 00        LDU    #$0000
ab3c: 34 40           PSHS   U
ab3e: 17 fb e9        LBSR   $A72A
ab41: 32 62           LEAS   $2,S
ab43: 16 03 99        LBRA   $AEDF
ab46: ce 00 00        LDU    #$0000
ab49: 34 40           PSHS   U
ab4b: 17 fd 29        LBSR   $A877
ab4e: 32 62           LEAS   $2,S
ab50: cc 00 0c        LDD    #$000C
ab53: fd 3c ac        STD    $3CAC
ab56: ce 00 21        LDU    #$0021
ab59: 10 8e 00 02     LDY    #$0002
ab5d: 34 60           PSHS   U,Y
ab5f: 17 87 cf        LBSR   $3331
ab62: 32 64           LEAS   $4,S
ab64: 16 03 78        LBRA   $AEDF
ab67: f6 3c dd        LDB    $3CDD
ab6a: c1 00           CMPB   #$00
ab6c: 10 27 00 0a     LBEQ   $AB7A
ab70: ce 00 00        LDU    #$0000
ab73: 34 40           PSHS   U
ab75: 17 5d 0d        LBSR   $0885
ab78: 32 62           LEAS   $2,S
ab7a: ce 00 00        LDU    #$0000
ab7d: 34 40           PSHS   U
ab7f: 17 e1 4c        LBSR   $8CCE
ab82: 32 62           LEAS   $2,S
ab84: 16 03 58        LBRA   $AEDF
ab87: be 3c ac        LDX    $3CAC
ab8a: 16 00 64        LBRA   $ABF1
ab8d: cc 00 04        LDD    #$0004
ab90: fd 3c ac        STD    $3CAC
ab93: ce 00 00        LDU    #$0000
ab96: 34 40           PSHS   U
ab98: 17 db a1        LBSR   $873C
ab9b: 32 62           LEAS   $2,S
ab9d: c6 01           LDB    #$01
ab9f: f7 3c dd        STB    $3CDD
aba2: cc 46 af        LDD    #$46AF
aba5: fd 3c da        STD    $3CDA
aba8: ce 00 01        LDU    #$0001
abab: 10 8e 00 02     LDY    #$0002
abaf: 34 60           PSHS   U,Y
abb1: be 3c 00        LDX    $3C00
abb4: ad 84           JSR    ,X
abb6: 32 64           LEAS   $4,S
abb8: 16 00 4c        LBRA   $AC07
abbb: cc 00 06        LDD    #$0006
abbe: fd 3c ac        STD    $3CAC
abc1: ce 00 00        LDU    #$0000
abc4: 34 40           PSHS   U
abc6: 17 dc bc        LBSR   $8885
abc9: 32 62           LEAS   $2,S
abcb: c6 01           LDB    #$01
abcd: f7 3c dd        STB    $3CDD
abd0: cc 48 64        LDD    #$4864
abd3: fd 3c da        STD    $3CDA
abd6: ce 00 02        LDU    #$0002
abd9: 10 8e 00 02     LDY    #$0002
abdd: 34 60           PSHS   U,Y
abdf: be 3c 00        LDX    $3C00
abe2: ad 84           JSR    ,X
abe4: 32 64           LEAS   $4,S
abe6: 16 00 1e        LBRA   $AC07
abe9: c6 14           LDB    #$14
abeb: f7 3c dc        STB    $3CDC
abee: 16 00 16        LBRA   $AC07
abf1: 8c 00 03        CMPX   #$0003
abf4: 27 97           BEQ    $AB8D
abf6: 8c 00 04        CMPX   #$0004
abf9: 27 98           BEQ    $AB93
abfb: 8c 00 05        CMPX   #$0005
abfe: 27 bb           BEQ    $ABBB
ac00: 8c 00 06        CMPX   #$0006
ac03: 27 bc           BEQ    $ABC1
ac05: 20 e2           BRA    $ABE9
ac07: 16 02 d5        LBRA   $AEDF
ac0a: f6 3c dd        LDB    $3CDD
ac0d: c1 00           CMPB   #$00
ac0f: 10 27 00 0a     LBEQ   $AC1D
ac13: ce 00 00        LDU    #$0000
ac16: 34 40           PSHS   U
ac18: 17 5c 6a        LBSR   $0885
ac1b: 32 62           LEAS   $2,S
ac1d: c6 01           LDB    #$01
ac1f: 1d              SEX
ac20: 1f 03           TFR    D,U
ac22: 10 8e 00 02     LDY    #$0002
ac26: 34 60           PSHS   U,Y
ac28: 17 e2 6f        LBSR   $8E9A
ac2b: 32 64           LEAS   $4,S
ac2d: 16 02 af        LBRA   $AEDF
ac30: f6 3c dd        LDB    $3CDD
ac33: c1 00           CMPB   #$00
ac35: 10 27 00 0a     LBEQ   $AC43
ac39: ce 00 00        LDU    #$0000
ac3c: 34 40           PSHS   U
ac3e: 17 5c 44        LBSR   $0885
ac41: 32 62           LEAS   $2,S
ac43: 5f              CLRB
ac44: 1d              SEX
ac45: 1f 03           TFR    D,U
ac47: 10 8e 00 02     LDY    #$0002
ac4b: 34 60           PSHS   U,Y
ac4d: 17 e2 4a        LBSR   $8E9A
ac50: 32 64           LEAS   $4,S
ac52: 16 02 8a        LBRA   $AEDF
ac55: f6 3c 02        LDB    $3C02
ac58: c1 00           CMPB   #$00
ac5a: 10 27 00 0a     LBEQ   $AC68
ac5e: ce 00 00        LDU    #$0000
ac61: 34 40           PSHS   U
ac63: 17 fc 71        LBSR   $A8D7
ac66: 32 62           LEAS   $2,S
ac68: ce 00 00        LDU    #$0000
ac6b: 34 40           PSHS   U
ac6d: 17 dd 90        LBSR   $8A00
ac70: 32 62           LEAS   $2,S
ac72: 16 02 6a        LBRA   $AEDF
ac75: 86 02           LDA    #$02
ac77: f6 3c 1f        LDB    $3C1F
ac7a: 17 91 12        LBSR   $3D8F
ac7d: 1f 03           TFR    D,U
ac7f: 10 8e 00 02     LDY    #$0002
ac83: 34 60           PSHS   U,Y
ac85: 17 f0 80        LBSR   $9D08
ac88: 32 64           LEAS   $4,S
ac8a: 16 02 52        LBRA   $AEDF
ac8d: fc 22 04        LDD    $2204
ac90: 84 00           ANDA   #$00
ac92: c4 08           ANDB   #$08
ac94: 10 83 00 00     CMPD   #$0000
ac98: 10 27 00 32     LBEQ   $ACCE
ac9c: e6 62           LDB    $2,S
ac9e: c1 00           CMPB   #$00
aca0: 10 26 00 0d     LBNE   $ACB1
aca4: ce 00 00        LDU    #$0000
aca7: 34 40           PSHS   U
aca9: 17 fc 94        LBSR   $A940
acac: 32 62           LEAS   $2,S
acae: 16 00 1a        LBRA   $ACCB
acb1: e6 62           LDB    $2,S
acb3: c1 01           CMPB   #$01
acb5: 10 26 00 0d     LBNE   $ACC6
acb9: ce 00 00        LDU    #$0000
acbc: 34 40           PSHS   U
acbe: 17 fc b5        LBSR   $A976
acc1: 32 62           LEAS   $2,S
acc3: 16 00 05        LBRA   $ACCB
acc6: c6 3a           LDB    #$3A
acc8: f7 3c dc        STB    $3CDC
accb: 16 00 05        LBRA   $ACD3
acce: c6 3a           LDB    #$3A
acd0: f7 3c dc        STB    $3CDC
acd3: 16 02 09        LBRA   $AEDF
acd6: ce 00 00        LDU    #$0000
acd9: 34 40           PSHS   U
acdb: 17 fc 39        LBSR   $A917
acde: 32 62           LEAS   $2,S
ace0: 16 01 fc        LBRA   $AEDF
ace3: ce 00 00        LDU    #$0000
ace6: 34 40           PSHS   U
ace8: 17 fd 2d        LBSR   $AA18
aceb: 32 62           LEAS   $2,S
aced: 16 01 ef        LBRA   $AEDF
acf0: f6 3c 02        LDB    $3C02
acf3: c1 00           CMPB   #$00
acf5: 10 27 00 0f     LBEQ   $AD08
acf9: 5f              CLRB
acfa: 1d              SEX
acfb: 1f 03           TFR    D,U
acfd: 10 8e 00 02     LDY    #$0002
ad01: 34 60           PSHS   U,Y
ad03: 17 fa 9d        LBSR   $A7A3
ad06: 32 64           LEAS   $4,S
ad08: f6 3c 1f        LDB    $3C1F
ad0b: c1 03           CMPB   #$03
ad0d: 10 26 00 10     LBNE   $AD21
ad11: c6 08           LDB    #$08
ad13: 1d              SEX
ad14: 1f 03           TFR    D,U
ad16: 10 8e 00 02     LDY    #$0002
ad1a: 34 60           PSHS   U,Y
ad1c: 17 f6 39        LBSR   $A358
ad1f: 32 64           LEAS   $4,S
ad21: ce 00 00        LDU    #$0000
ad24: 34 40           PSHS   U
ad26: 17 fc c4        LBSR   $A9ED
ad29: 32 62           LEAS   $2,S
ad2b: 16 01 b1        LBRA   $AEDF
ad2e: ce 00 00        LDU    #$0000
ad31: 34 40           PSHS   U
ad33: 17 fd 6b        LBSR   $AAA1
ad36: 32 62           LEAS   $2,S
ad38: 16 01 a4        LBRA   $AEDF
ad3b: ce 00 00        LDU    #$0000
ad3e: 34 40           PSHS   U
ad40: 17 fd 75        LBSR   $AAB8
ad43: 32 62           LEAS   $2,S
ad45: 16 01 97        LBRA   $AEDF
ad48: f6 3c 1f        LDB    $3C1F
ad4b: c1 03           CMPB   #$03
ad4d: 10 26 00 3f     LBNE   $AD90
ad51: f6 3c 04        LDB    $3C04
ad54: c1 00           CMPB   #$00
ad56: 10 27 00 29     LBEQ   $AD83
ad5a: c6 08           LDB    #$08
ad5c: 1d              SEX
ad5d: 1f 03           TFR    D,U
ad5f: 10 8e 00 02     LDY    #$0002
ad63: 34 60           PSHS   U,Y
ad65: 17 f5 f0        LBSR   $A358
ad68: 32 64           LEAS   $4,S
ad6a: cc 00 08        LDD    #$0008
ad6d: fd 3c ac        STD    $3CAC
ad70: ce 00 04        LDU    #$0004
ad73: 10 8e 00 02     LDY    #$0002
ad77: 34 60           PSHS   U,Y
ad79: be 3c 00        LDX    $3C00
ad7c: ad 84           JSR    ,X
ad7e: 32 64           LEAS   $4,S
ad80: 16 00 0a        LBRA   $AD8D
ad83: ce 00 00        LDU    #$0000
ad86: 34 40           PSHS   U
ad88: 17 ed 99        LBSR   $9B24
ad8b: 32 62           LEAS   $2,S
ad8d: 16 00 0a        LBRA   $AD9A
ad90: ce 00 00        LDU    #$0000
ad93: 34 40           PSHS   U
ad95: 17 ed 8c        LBSR   $9B24
ad98: 32 62           LEAS   $2,S
ad9a: 16 01 42        LBRA   $AEDF
ad9d: f6 3c 1f        LDB    $3C1F
ada0: c1 03           CMPB   #$03
ada2: 10 26 00 2b     LBNE   $ADD1
ada6: f6 3c 04        LDB    $3C04
ada9: c1 00           CMPB   #$00
adab: 10 27 00 13     LBEQ   $ADC2
adaf: c6 08           LDB    #$08
adb1: 1d              SEX
adb2: 1f 03           TFR    D,U
adb4: 10 8e 00 02     LDY    #$0002
adb8: 34 60           PSHS   U,Y
adba: 17 f5 9b        LBSR   $A358
adbd: 32 64           LEAS   $4,S
adbf: 16 00 0f        LBRA   $ADD1
adc2: 5f              CLRB
adc3: 1d              SEX
adc4: 1f 03           TFR    D,U
adc6: 10 8e 00 02     LDY    #$0002
adca: 34 60           PSHS   U,Y
adcc: 17 f5 89        LBSR   $A358
adcf: 32 64           LEAS   $4,S
add1: ce 00 00        LDU    #$0000
add4: 34 40           PSHS   U
add6: 17 ed 75        LBSR   $9B4E
add9: 32 62           LEAS   $2,S
addb: 16 01 01        LBRA   $AEDF
adde: ce 00 00        LDU    #$0000
ade1: 34 40           PSHS   U
ade3: 17 f7 79        LBSR   $A55F
ade6: 32 62           LEAS   $2,S
ade8: 16 00 f4        LBRA   $AEDF
adeb: be 22 17        LDX    $2217
adee: 8c 00 39        CMPX   #$0039
adf1: 10 26 00 06     LBNE   $ADFB
adf5: 7f 22 19        CLR    $2219
adf8: 16 00 17        LBRA   $AE12
adfb: be 22 17        LDX    $2217
adfe: 8c 00 3a        CMPX   #$003A
ae01: 10 26 00 08     LBNE   $AE0D
ae05: c6 01           LDB    #$01
ae07: f7 22 19        STB    $2219
ae0a: 16 00 05        LBRA   $AE12
ae0d: c6 02           LDB    #$02
ae0f: f7 22 19        STB    $2219
ae12: f6 22 19        LDB    $2219
ae15: 4f              CLRA
ae16: 1f 03           TFR    D,U
ae18: 10 8e 00 02     LDY    #$0002
ae1c: 34 60           PSHS   U,Y
ae1e: 17 e8 c8        LBSR   $96E9
ae21: 32 64           LEAS   $4,S
ae23: ce 00 00        LDU    #$0000
ae26: 34 40           PSHS   U
ae28: 17 db 7a        LBSR   $89A5
ae2b: 32 62           LEAS   $2,S
ae2d: 16 00 af        LBRA   $AEDF
ae30: ce 00 00        LDU    #$0000
ae33: 34 40           PSHS   U
ae35: 17 55 e0        LBSR   $0418
ae38: 32 62           LEAS   $2,S
ae3a: ce 00 00        LDU    #$0000
ae3d: 34 40           PSHS   U
ae3f: 17 fa 35        LBSR   $A877
ae42: 32 62           LEAS   $2,S
ae44: 5f              CLRB
ae45: 4f              CLRA
ae46: fd 3c ac        STD    $3CAC
ae49: 16 00 93        LBRA   $AEDF
ae4c: c6 3a           LDB    #$3A
ae4e: f7 3c dc        STB    $3CDC
ae51: 16 00 8b        LBRA   $AEDF
ae54: 8c 00 3c        CMPX   #$003C
ae57: 2e f3           BGT    $AE4C
ae59: 1f 10           TFR    X,D
ae5b: 83 00 01        SUBD   #$0001
ae5e: 2d ec           BLT    $AE4C
ae60: 8e 6e 67        LDX    #$6E67
ae63: 58              ASLB
ae64: 49              ROLA
ae65: 6e 9b           JMP    [D,X]
ae67: 6e 3a           JMP    -$6,Y
ae69: 6e 4c           JMP    $C,U
ae6b: 6e 4c           JMP    $C,U
ae6d: 6e 4c           JMP    $C,U
ae6f: 6e 4c           JMP    $C,U
ae71: 6e 4c           JMP    $C,U
ae73: 6e 4c           JMP    $C,U
ae75: 6e 3a           JMP    -$6,Y
ae77: 6e 3a           JMP    -$6,Y
ae79: 6e 4c           JMP    $C,U
ae7b: 6e 4c           JMP    $C,U
ae7d: 6e 4c           JMP    $C,U
ae7f: 6e 3a           JMP    -$6,Y
ae81: 6e 3a           JMP    -$6,Y
ae83: 6e 4c           JMP    $C,U
ae85: 6e 30           JMP    -$10,Y
ae87: 6e 3a           JMP    -$6,Y
ae89: 6e 4c           JMP    $C,U
ae8b: 6b 09           XDEC   $9,X
ae8d: 6b 09           XDEC   $9,X
ae8f: 6b 09           XDEC   $9,X
ae91: 6b 09           XDEC   $9,X
ae93: 6b 20           XDEC   $0,Y
ae95: 6b 20           XDEC   $0,Y
ae97: 6e 4c           JMP    $C,U
ae99: 6c 8d 6e 4c     INC    $1CE9,PCR
ae9d: 6e 4c           JMP    $C,U
ae9f: 6e 4c           JMP    $C,U
aea1: 6b 87           XDEC   E,X
aea3: 6c 30           INC    -$10,Y
aea5: 6c 0a           INC    $A,X
aea7: 6b 46           XDEC   $6,U
aea9: 6e 4c           JMP    $C,U
aeab: 6b 67           XDEC   $7,S
aead: 6e 4c           JMP    $C,U
aeaf: 6c 55           INC    -$B,U
aeb1: 6c 75           INC    -$B,S
aeb3: 6e 4c           JMP    $C,U
aeb5: 6e 4c           JMP    $C,U
aeb7: 6e 4c           JMP    $C,U
aeb9: 6e 4c           JMP    $C,U
aebb: 6e 4c           JMP    $C,U
aebd: 6d de           TST    [W,U]
aebf: 6c e3           INC    ,--S
aec1: 6d 2e           TST    $E,Y
aec3: 6c f0           INC    [,--W]
aec5: 6d 3b           TST    -$5,Y
aec7: 6c d6           INC    [A,U]
aec9: 6e 4c           JMP    $C,U
aecb: 6d 48           TST    $8,U
aecd: 6d 9d 6e 4c     TST    [$1D1D,PCR]
aed1: 6e 4c           JMP    $C,U
aed3: 6e 4c           JMP    $C,U
aed5: 6e 4c           JMP    $C,U
aed7: 6d eb           TST    D,S
aed9: 6d eb           TST    D,S
aedb: 6d eb           TST    D,S
aedd: 6e 3a           JMP    -$6,Y
aedf: c6 02           LDB    #$02
aee1: 1d              SEX
aee2: 1f 03           TFR    D,U
aee4: 10 8e 00 02     LDY    #$0002
aee8: 34 60           PSHS   U,Y
aeea: 17 e2 95        LBSR   $9182
aeed: 32 64           LEAS   $4,S
aeef: f6 3c dc        LDB    $3CDC
aef2: c1 00           CMPB   #$00
aef4: 10 27 00 65     LBEQ   $AF5D
aef8: fc 22 04        LDD    $2204
aefb: 84 00           ANDA   #$00
aefd: c4 08           ANDB   #$08
aeff: 10 83 00 00     CMPD   #$0000
af03: 10 27 00 17     LBEQ   $AF1E
af07: f6 3c dc        LDB    $3CDC
af0a: 4f              CLRA
af0b: 1f 03           TFR    D,U
af0d: 5f              CLRB
af0e: 1d              SEX
af0f: 1f 02           TFR    D,Y
af11: 8e 00 04        LDX    #$0004
af14: 34 70           PSHS   U,Y,X
af16: 17 2e ba        LBSR   $DDD3
af19: 32 66           LEAS   $6,S
af1b: 16 00 11        LBRA   $AF2F
af1e: f6 3c dc        LDB    $3CDC
af21: 4f              CLRA
af22: 1f 03           TFR    D,U
af24: 10 8e 00 02     LDY    #$0002
af28: 34 60           PSHS   U,Y
af2a: 17 54 d1        LBSR   $03FE
af2d: 32 64           LEAS   $4,S
af2f: c6 01           LDB    #$01
af31: e7 63           STB    $3,S
af33: f6 3c dc        LDB    $3CDC
af36: c1 3a           CMPB   #$3A
af38: 10 27 00 14     LBEQ   $AF50
af3c: f6 3c dc        LDB    $3CDC
af3f: c1 3b           CMPB   #$3B
af41: 10 27 00 0b     LBEQ   $AF50
af45: f6 3c dc        LDB    $3CDC
af48: c1 14           CMPB   #$14
af4a: 10 27 00 02     LBEQ   $AF50
af4e: 6f 63           CLR    $3,S
af50: e6 63           LDB    $3,S
af52: c1 00           CMPB   #$00
af54: 10 27 00 05     LBEQ   $AF5D
af58: 5f              CLRB
af59: 4f              CLRA
af5a: fd 3c ac        STD    $3CAC
af5d: 32 64           LEAS   $4,S
af5f: 39              RTS
af60: fc 73 8e        LDD    $738E
af63: 17 8d ea        LBSR   $3D50
af66: f6 3c ca        LDB    $3CCA
af69: c1 00           CMPB   #$00
af6b: 10 27 00 4c     LBEQ   $AFBB
af6f: be 22 17        LDX    $2217
af72: 8c 00 15        CMPX   #$0015
af75: 10 27 00 42     LBEQ   $AFBB
af79: be 22 17        LDX    $2217
af7c: 8c 00 16        CMPX   #$0016
af7f: 10 27 00 38     LBEQ   $AFBB
af83: be 22 17        LDX    $2217
af86: 8c 00 23        CMPX   #$0023
af89: 10 27 00 2e     LBEQ   $AFBB
af8d: be 22 17        LDX    $2217
af90: 8c 00 20        CMPX   #$0020
af93: 10 27 00 24     LBEQ   $AFBB
af97: be 22 17        LDX    $2217
af9a: 8c 00 1f        CMPX   #$001F
af9d: 10 27 00 1a     LBEQ   $AFBB
afa1: be 22 17        LDX    $2217
afa4: 8c 00 26        CMPX   #$0026
afa7: 10 27 00 10     LBEQ   $AFBB
afab: c6 01           LDB    #$01
afad: 1d              SEX
afae: 1f 03           TFR    D,U
afb0: 10 8e 00 02     LDY    #$0002
afb4: 34 60           PSHS   U,Y
afb6: 17 ea f1        LBSR   $9AAA
afb9: 32 64           LEAS   $4,S
afbb: 32 62           LEAS   $2,S
afbd: 39              RTS
afbe: fc 73 8e        LDD    $738E
afc1: 17 8d 8c        LBSR   $3D50
afc4: 5f              CLRB
afc5: 1d              SEX
afc6: 1f 03           TFR    D,U
afc8: 10 8e 00 02     LDY    #$0002
afcc: 34 60           PSHS   U,Y
afce: 17 f7 d2        LBSR   $A7A3
afd1: 32 64           LEAS   $4,S
afd3: 5f              CLRB
afd4: 1d              SEX
afd5: 1f 03           TFR    D,U
afd7: 10 8e 00 02     LDY    #$0002
afdb: 34 60           PSHS   U,Y
afdd: 17 e1 e8        LBSR   $91C8
afe0: 32 64           LEAS   $4,S
afe2: fc 22 04        LDD    $2204
afe5: 84 7f           ANDA   #$7F
afe7: c4 ff           ANDB   #$FF
afe9: fd 22 04        STD    $2204
afec: fc 22 04        LDD    $2204
afef: 84 bf           ANDA   #$BF
aff1: c4 ff           ANDB   #$FF
aff3: fd 22 04        STD    $2204
aff6: cc c2 39        LDD    #$C239
aff9: fd 22 11        STD    $2211
affc: 32 62           LEAS   $2,S
affe: 39              RTS
afff: fc 73 8c        LDD    $738C
b002: 17 8d 4b        LBSR   $3D50
b005: ce 00 00        LDU    #$0000
b008: 34 40           PSHS   U
b00a: 17 56 dd        LBSR   $06EA
b00d: 32 62           LEAS   $2,S
b00f: ce 00 00        LDU    #$0000
b012: 34 40           PSHS   U
b014: 17 54 d9        LBSR   $04F0
b017: 32 62           LEAS   $2,S
b019: ce 00 00        LDU    #$0000
b01c: 34 40           PSHS   U
b01e: 17 55 90        LBSR   $05B1
b021: 32 62           LEAS   $2,S
b023: c6 01           LDB    #$01
b025: f7 23 be        STB    $23BE
b028: ce 00 00        LDU    #$0000
b02b: 34 40           PSHS   U
b02d: 17 51 ea        LBSR   $021A
b030: 32 62           LEAS   $2,S
b032: ce 41 93        LDU    #$4193
b035: 10 be 23 bf     LDY    $23BF
b039: 8e 00 04        LDX    #$0004
b03c: 34 70           PSHS   U,Y,X
b03e: 17 63 3c        LBSR   $137D
b041: 32 66           LEAS   $6,S
b043: fe 23 bf        LDU    $23BF
b046: c6 01           LDB    #$01
b048: 1d              SEX
b049: 1f 02           TFR    D,Y
b04b: 8e 00 04        LDX    #$0004
b04e: 34 70           PSHS   U,Y,X
b050: 17 72 6e        LBSR   $22C1
b053: 32 66           LEAS   $6,S
b055: be 23 bf        LDX    $23BF
b058: 30 0a           LEAX   $A,X
b05a: ce ea 58        LDU    #$EA58
b05d: 1f 12           TFR    X,Y
b05f: 8e 00 04        LDX    #$0004
b062: 34 70           PSHS   U,Y,X
b064: 17 63 16        LBSR   $137D
b067: 32 66           LEAS   $6,S
b069: be 23 bf        LDX    $23BF
b06c: 30 0a           LEAX   $A,X
b06e: 1f 13           TFR    X,U
b070: c6 01           LDB    #$01
b072: 1d              SEX
b073: 1f 02           TFR    D,Y
b075: 8e 00 04        LDX    #$0004
b078: 34 70           PSHS   U,Y,X
b07a: 17 4f ec        LBSR   $0069
b07d: 32 66           LEAS   $6,S
b07f: c6 02           LDB    #$02
b081: f7 23 be        STB    $23BE
b084: ce 00 00        LDU    #$0000
b087: 34 40           PSHS   U
b089: 17 51 8e        LBSR   $021A
b08c: 32 62           LEAS   $2,S
b08e: be 23 bf        LDX    $23BF
b091: 30 88 1f        LEAX   $1F,X
b094: cc 00 04        LDD    #$0004
b097: ed 84           STD    ,X
b099: be 23 bf        LDX    $23BF
b09c: 30 88 1f        LEAX   $1F,X
b09f: ae 84           LDX    ,X
b0a1: 1f 13           TFR    X,U
b0a3: c6 02           LDB    #$02
b0a5: 1d              SEX
b0a6: 1f 02           TFR    D,Y
b0a8: 8e 00 04        LDX    #$0004
b0ab: 34 70           PSHS   U,Y,X
b0ad: 17 72 df        LBSR   $238F
b0b0: 32 66           LEAS   $6,S
b0b2: 5f              CLRB
b0b3: 1d              SEX
b0b4: 1f 03           TFR    D,U
b0b6: c6 03           LDB    #$03
b0b8: 1d              SEX
b0b9: 1f 02           TFR    D,Y
b0bb: 8e 00 04        LDX    #$0004
b0be: 34 70           PSHS   U,Y,X
b0c0: 17 73 b5        LBSR   $2478
b0c3: 32 66           LEAS   $6,S
b0c5: 7f 3c 02        CLR    $3C02
b0c8: 7f 3c 04        CLR    $3C04
b0cb: cc 00 05        LDD    #$0005
b0ce: fd 3c 13        STD    $3C13
b0d1: cc 00 05        LDD    #$0005
b0d4: fd 3c 15        STD    $3C15
b0d7: c6 2b           LDB    #$2B
b0d9: f7 3c 11        STB    $3C11
b0dc: c6 2b           LDB    #$2B
b0de: f7 3c 12        STB    $3C12
b0e1: cc 00 0a        LDD    #$000A
b0e4: fd 3c 9e        STD    $3C9E
b0e7: cc 00 0a        LDD    #$000A
b0ea: fd 3c a0        STD    $3CA0
b0ed: cc 00 0a        LDD    #$000A
b0f0: fd 3c 1b        STD    $3C1B
b0f3: cc 00 0a        LDD    #$000A
b0f6: fd 3c 1d        STD    $3C1D
b0f9: 7f 23 be        CLR    $23BE
b0fc: ce 00 00        LDU    #$0000
b0ff: 34 40           PSHS   U
b101: 17 51 16        LBSR   $021A
b104: 32 62           LEAS   $2,S
b106: be 23 bf        LDX    $23BF
b109: 30 0a           LEAX   $A,X
b10b: 1f 13           TFR    X,U
b10d: 10 8e 3c 05     LDY    #$3C05
b111: 8e 00 04        LDX    #$0004
b114: 34 70           PSHS   U,Y,X
b116: 17 62 64        LBSR   $137D
b119: 32 66           LEAS   $6,S
b11b: ce ea 58        LDU    #$EA58
b11e: 10 8e 3c 08     LDY    #$3C08
b122: 8e 00 04        LDX    #$0004
b125: 34 70           PSHS   U,Y,X
b127: 17 62 53        LBSR   $137D
b12a: 32 66           LEAS   $6,S
b12c: be 23 bf        LDX    $23BF
b12f: 30 0f           LEAX   $F,X
b131: 1f 13           TFR    X,U
b133: 10 8e 3c 0b     LDY    #$3C0B
b137: 8e 00 04        LDX    #$0004
b13a: 34 70           PSHS   U,Y,X
b13c: 17 62 3e        LBSR   $137D
b13f: 32 66           LEAS   $6,S
b141: be 23 bf        LDX    $23BF
b144: 30 0f           LEAX   $F,X
b146: 1f 13           TFR    X,U
b148: 10 8e 3c 0e     LDY    #$3C0E
b14c: 8e 00 04        LDX    #$0004
b14f: 34 70           PSHS   U,Y,X
b151: 17 62 29        LBSR   $137D
b154: 32 66           LEAS   $6,S
b156: cc 00 05        LDD    #$0005
b159: fd 3c 17        STD    $3C17
b15c: cc 00 05        LDD    #$0005
b15f: fd 3c 19        STD    $3C19
b162: 5f              CLRB
b163: 1d              SEX
b164: 1f 03           TFR    D,U
b166: 10 8e 00 02     LDY    #$0002
b16a: 34 60           PSHS   U,Y
b16c: 17 e0 59        LBSR   $91C8
b16f: 32 64           LEAS   $4,S
b171: c6 01           LDB    #$01
b173: 1d              SEX
b174: 1f 03           TFR    D,U
b176: 5f              CLRB
b177: 1d              SEX
b178: 1f 02           TFR    D,Y
b17a: 8e 00 04        LDX    #$0004
b17d: 34 70           PSHS   U,Y,X
b17f: 17 85 91        LBSR   $3713
b182: 32 66           LEAS   $6,S
b184: 32 63           LEAS   $3,S
b186: 39              RTS
b187: fc 73 8f        LDD    $738F
b18a: 17 8b c3        LBSR   $3D50
b18d: ae e9 00 08     LDX    $0008,S
b191: 8c 00 02        CMPX   #$0002
b194: 10 27 00 0a     LBEQ   $B1A2
b198: ce 00 00        LDU    #$0000
b19b: 34 40           PSHS   U
b19d: 17 55 4a        LBSR   $06EA
b1a0: 32 62           LEAS   $2,S
b1a2: ae e9 00 08     LDX    $0008,S
b1a6: 8c 00 01        CMPX   #$0001
b1a9: 10 26 00 11     LBNE   $B1BE
b1ad: f6 22 19        LDB    $2219
b1b0: 4f              CLRA
b1b1: 1f 03           TFR    D,U
b1b3: 10 8e 00 02     LDY    #$0002
b1b7: 34 60           PSHS   U,Y
b1b9: 17 e2 d5        LBSR   $9491
b1bc: 32 64           LEAS   $4,S
b1be: ae e9 00 08     LDX    $0008,S
b1c2: 8c 00 00        CMPX   #$0000
b1c5: 10 26 00 0d     LBNE   $B1D6
b1c9: ce 00 00        LDU    #$0000
b1cc: 34 40           PSHS   U
b1ce: 17 fe 2e        LBSR   $AFFF
b1d1: 32 62           LEAS   $2,S
b1d3: 16 00 8b        LBRA   $B261
b1d6: ce 00 00        LDU    #$0000
b1d9: 34 40           PSHS   U
b1db: 17 53 d3        LBSR   $05B1
b1de: 32 62           LEAS   $2,S
b1e0: ae e9 00 08     LDX    $0008,S
b1e4: 8c 00 01        CMPX   #$0001
b1e7: 10 26 00 66     LBNE   $B251
b1eb: 6f 62           CLR    $2,S
b1ed: e6 62           LDB    $2,S
b1ef: c1 04           CMPB   #$04
b1f1: 10 24 00 5c     LBCC   $B251
b1f5: 8e 24 f0        LDX    #$24F0
b1f8: e6 62           LDB    $2,S
b1fa: 3a              ABX
b1fb: e6 84           LDB    ,X
b1fd: e7 63           STB    $3,S
b1ff: e6 63           LDB    $3,S
b201: 4f              CLRA
b202: 1f 03           TFR    D,U
b204: 10 8e 00 ff     LDY    #$00FF
b208: e6 62           LDB    $2,S
b20a: 4f              CLRA
b20b: 1f 01           TFR    D,X
b20d: cc 00 06        LDD    #$0006
b210: 34 76           PSHS   U,Y,X,D
b212: 17 69 8c        LBSR   $1BA1
b215: 32 68           LEAS   $8,S
b217: e6 63           LDB    $3,S
b219: c4 04           ANDB   #$04
b21b: 10 27 00 16     LBEQ   $B235
b21f: 5f              CLRB
b220: 1d              SEX
b221: 1f 03           TFR    D,U
b223: e6 62           LDB    $2,S
b225: 4f              CLRA
b226: 1f 02           TFR    D,Y
b228: 8e 00 04        LDX    #$0004
b22b: 34 70           PSHS   U,Y,X
b22d: 17 45 6c        LBSR   $F79C
b230: 32 66           LEAS   $6,S
b232: 16 00 14        LBRA   $B249
b235: c6 01           LDB    #$01
b237: 1d              SEX
b238: 1f 03           TFR    D,U
b23a: e6 62           LDB    $2,S
b23c: 4f              CLRA
b23d: 1f 02           TFR    D,Y
b23f: 8e 00 04        LDX    #$0004
b242: 34 70           PSHS   U,Y,X
b244: 17 45 55        LBSR   $F79C
b247: 32 66           LEAS   $6,S
b249: e6 62           LDB    $2,S
b24b: cb 01           ADDB   #$01
b24d: e7 62           STB    $2,S
b24f: 20 9c           BRA    $B1ED
b251: f6 3c 1f        LDB    $3C1F
b254: f7 26 8e        STB    $268E
b257: ce 00 00        LDU    #$0000
b25a: 34 40           PSHS   U
b25c: 17 17 4b        LBSR   $C9AA
b25f: 32 62           LEAS   $2,S
b261: 7f 23 be        CLR    $23BE
b264: ce 00 00        LDU    #$0000
b267: 34 40           PSHS   U
b269: 17 4f ae        LBSR   $021A
b26c: 32 62           LEAS   $2,S
b26e: be 23 bf        LDX    $23BF
b271: 30 88 1f        LEAX   $1F,X
b274: cc 00 04        LDD    #$0004
b277: ed 84           STD    ,X
b279: be 23 bf        LDX    $23BF
b27c: 30 88 1f        LEAX   $1F,X
b27f: ae 84           LDX    ,X
b281: 1f 13           TFR    X,U
b283: 5f              CLRB
b284: 1d              SEX
b285: 1f 02           TFR    D,Y
b287: 8e 00 04        LDX    #$0004
b28a: 34 70           PSHS   U,Y,X
b28c: 17 71 00        LBSR   $238F
b28f: 32 66           LEAS   $6,S
b291: be 23 bf        LDX    $23BF
b294: 30 88 21        LEAX   $21,X
b297: cc 00 0c        LDD    #$000C
b29a: ed 84           STD    ,X
b29c: 5f              CLRB
b29d: 1d              SEX
b29e: 1f 03           TFR    D,U
b2a0: 10 8e 00 0c     LDY    #$000C
b2a4: 8e 00 04        LDX    #$0004
b2a7: 34 70           PSHS   U,Y,X
b2a9: 17 55 04        LBSR   $07B0
b2ac: 32 66           LEAS   $6,S
b2ae: 7f 3c b8        CLR    $3CB8
b2b1: ce 00 00        LDU    #$0000
b2b4: 34 40           PSHS   U
b2b6: 17 d1 e4        LBSR   $849D
b2b9: 32 62           LEAS   $2,S
b2bb: ce 00 00        LDU    #$0000
b2be: 34 40           PSHS   U
b2c0: 17 df 60        LBSR   $9223
b2c3: 32 62           LEAS   $2,S
b2c5: 5f              CLRB
b2c6: 1d              SEX
b2c7: 1f 03           TFR    D,U
b2c9: 10 8e 00 02     LDY    #$0002
b2cd: 34 60           PSHS   U,Y
b2cf: 17 de f6        LBSR   $91C8
b2d2: 32 64           LEAS   $4,S
b2d4: c6 02           LDB    #$02
b2d6: 1d              SEX
b2d7: 1f 03           TFR    D,U
b2d9: 10 8e 00 02     LDY    #$0002
b2dd: 34 60           PSHS   U,Y
b2df: 17 de a0        LBSR   $9182
b2e2: 32 64           LEAS   $4,S
b2e4: cc 6a d0        LDD    #$6AD0
b2e7: fd 22 0f        STD    $220F
b2ea: cc 6f 60        LDD    #$6F60
b2ed: fd 22 11        STD    $2211
b2f0: cc 66 46        LDD    #$6646
b2f3: fd 3c 00        STD    $3C00
b2f6: 7f 3c dd        CLR    $3CDD
b2f9: ee e9 00 08     LDU    $0008,S
b2fd: 10 8e 00 02     LDY    #$0002
b301: 34 60           PSHS   U,Y
b303: 17 f2 94        LBSR   $A59A
b306: 32 64           LEAS   $4,S
b308: ce 00 00        LDU    #$0000
b30b: 34 40           PSHS   U
b30d: 17 e1 24        LBSR   $9434
b310: 32 62           LEAS   $2,S
b312: f6 3c 03        LDB    $3C03
b315: c1 00           CMPB   #$00
b317: 10 27 00 03     LBEQ   $B31E
b31b: 7f 3c 02        CLR    $3C02
b31e: ce 00 00        LDU    #$0000
b321: 34 40           PSHS   U
b323: 17 f4 04        LBSR   $A72A
b326: 32 62           LEAS   $2,S
b328: f6 3c 02        LDB    $3C02
b32b: c1 00           CMPB   #$00
b32d: 10 27 00 0d     LBEQ   $B33E
b331: ce 00 00        LDU    #$0000
b334: 34 40           PSHS   U
b336: 17 f6 df        LBSR   $AA18
b339: 32 62           LEAS   $2,S
b33b: 16 00 13        LBRA   $B351
b33e: f6 3c 04        LDB    $3C04
b341: c1 00           CMPB   #$00
b343: 10 27 00 0a     LBEQ   $B351
b347: ce 00 00        LDU    #$0000
b34a: 34 40           PSHS   U
b34c: 17 f6 5f        LBSR   $A9AE
b34f: 32 62           LEAS   $2,S
b351: fc 22 04        LDD    $2204
b354: 8a 40           ORA    #$40
b356: ca 00           ORB    #$00
b358: fd 22 04        STD    $2204
b35b: cc 6f be        LDD    #$6FBE
b35e: fd 22 13        STD    $2213
b361: 32 64           LEAS   $4,S
b363: 39              RTS
b364: fc 73 8e        LDD    $738E
b367: 17 89 e6        LBSR   $3D50
b36a: ce 41 6b        LDU    #$416B
b36d: 10 8e 00 02     LDY    #$0002
b371: 34 60           PSHS   U,Y
b373: 17 16 92        LBSR   $CA08
b376: 32 64           LEAS   $4,S
b378: ee e9 00 06     LDU    $0006,S
b37c: 10 8e 00 02     LDY    #$0002
b380: 34 60           PSHS   U,Y
b382: 17 fe 02        LBSR   $B187
b385: 32 64           LEAS   $4,S
b387: 32 62           LEAS   $2,S
b389: 39              RTS
b38a: 00 07           NEG    <$07
b38c: 00 01           NEG    <$01
b38e: 00 00           NEG    <$00
b390: 02 ff           XNC    <$FF
; --- $FF padding to end of page 2 (~$0C6E bytes unused) ---
b392: ff ff ff        STU    $FFFF
b395: ff ff ff        STU    $FFFF
b398: ff ff ff        STU    $FFFF
b39b: ff ff ff        STU    $FFFF
b39e: ff ff ff        STU    $FFFF
b3a1: ff ff ff        STU    $FFFF
b3a4: ff ff ff        STU    $FFFF
b3a7: ff ff ff        STU    $FFFF
b3aa: ff ff ff        STU    $FFFF
b3ad: ff ff ff        STU    $FFFF
b3b0: ff ff ff        STU    $FFFF
b3b3: ff ff ff        STU    $FFFF
b3b6: ff ff ff        STU    $FFFF
b3b9: ff ff ff        STU    $FFFF
b3bc: ff ff ff        STU    $FFFF
b3bf: ff ff ff        STU    $FFFF
b3c2: ff ff ff        STU    $FFFF
b3c5: ff ff ff        STU    $FFFF
b3c8: ff ff ff        STU    $FFFF
b3cb: ff ff ff        STU    $FFFF
b3ce: ff ff ff        STU    $FFFF
b3d1: ff ff ff        STU    $FFFF
b3d4: ff ff ff        STU    $FFFF
b3d7: ff ff ff        STU    $FFFF
b3da: ff ff ff        STU    $FFFF
b3dd: ff ff ff        STU    $FFFF
b3e0: ff ff ff        STU    $FFFF
b3e3: ff ff ff        STU    $FFFF
b3e6: ff ff ff        STU    $FFFF
b3e9: ff ff ff        STU    $FFFF
b3ec: ff ff ff        STU    $FFFF
b3ef: ff ff ff        STU    $FFFF
b3f2: ff ff ff        STU    $FFFF
b3f5: ff ff ff        STU    $FFFF
b3f8: ff ff ff        STU    $FFFF
b3fb: ff ff ff        STU    $FFFF
b3fe: ff ff ff        STU    $FFFF
b401: ff ff ff        STU    $FFFF
b404: ff ff ff        STU    $FFFF
b407: ff ff ff        STU    $FFFF
b40a: ff ff ff        STU    $FFFF
b40d: ff ff ff        STU    $FFFF
b410: ff ff ff        STU    $FFFF
b413: ff ff ff        STU    $FFFF
b416: ff ff ff        STU    $FFFF
b419: ff ff ff        STU    $FFFF
b41c: ff ff ff        STU    $FFFF
b41f: ff ff ff        STU    $FFFF
b422: ff ff ff        STU    $FFFF
b425: ff ff ff        STU    $FFFF
b428: ff ff ff        STU    $FFFF
b42b: ff ff ff        STU    $FFFF
b42e: ff ff ff        STU    $FFFF
b431: ff ff ff        STU    $FFFF
b434: ff ff ff        STU    $FFFF
b437: ff ff ff        STU    $FFFF
b43a: ff ff ff        STU    $FFFF
b43d: ff ff ff        STU    $FFFF
b440: ff ff ff        STU    $FFFF
b443: ff ff ff        STU    $FFFF
b446: ff ff ff        STU    $FFFF
b449: ff ff ff        STU    $FFFF
b44c: ff ff ff        STU    $FFFF
b44f: ff ff ff        STU    $FFFF
b452: ff ff ff        STU    $FFFF
b455: ff ff ff        STU    $FFFF
b458: ff ff ff        STU    $FFFF
b45b: ff ff ff        STU    $FFFF
b45e: ff ff ff        STU    $FFFF
b461: ff ff ff        STU    $FFFF
b464: ff ff ff        STU    $FFFF
b467: ff ff ff        STU    $FFFF
b46a: ff ff ff        STU    $FFFF
b46d: ff ff ff        STU    $FFFF
b470: ff ff ff        STU    $FFFF
b473: ff ff ff        STU    $FFFF
b476: ff ff ff        STU    $FFFF
b479: ff ff ff        STU    $FFFF
b47c: ff ff ff        STU    $FFFF
b47f: ff ff ff        STU    $FFFF
b482: ff ff ff        STU    $FFFF
b485: ff ff ff        STU    $FFFF
b488: ff ff ff        STU    $FFFF
b48b: ff ff ff        STU    $FFFF
b48e: ff ff ff        STU    $FFFF
b491: ff ff ff        STU    $FFFF
b494: ff ff ff        STU    $FFFF
b497: ff ff ff        STU    $FFFF
b49a: ff ff ff        STU    $FFFF
b49d: ff ff ff        STU    $FFFF
b4a0: ff ff ff        STU    $FFFF
b4a3: ff ff ff        STU    $FFFF
b4a6: ff ff ff        STU    $FFFF
b4a9: ff ff ff        STU    $FFFF
b4ac: ff ff ff        STU    $FFFF
b4af: ff ff ff        STU    $FFFF
b4b2: ff ff ff        STU    $FFFF
b4b5: ff ff ff        STU    $FFFF
b4b8: ff ff ff        STU    $FFFF
b4bb: ff ff ff        STU    $FFFF
b4be: ff ff ff        STU    $FFFF
b4c1: ff ff ff        STU    $FFFF
b4c4: ff ff ff        STU    $FFFF
b4c7: ff ff ff        STU    $FFFF
b4ca: ff ff ff        STU    $FFFF
b4cd: ff ff ff        STU    $FFFF
b4d0: ff ff ff        STU    $FFFF
b4d3: ff ff ff        STU    $FFFF
b4d6: ff ff ff        STU    $FFFF
b4d9: ff ff ff        STU    $FFFF
b4dc: ff ff ff        STU    $FFFF
b4df: ff ff ff        STU    $FFFF
b4e2: ff ff ff        STU    $FFFF
b4e5: ff ff ff        STU    $FFFF
b4e8: ff ff ff        STU    $FFFF
b4eb: ff ff ff        STU    $FFFF
b4ee: ff ff ff        STU    $FFFF
b4f1: ff ff ff        STU    $FFFF
b4f4: ff ff ff        STU    $FFFF
b4f7: ff ff ff        STU    $FFFF
b4fa: ff ff ff        STU    $FFFF
b4fd: ff ff ff        STU    $FFFF
b500: ff ff ff        STU    $FFFF
b503: ff ff ff        STU    $FFFF
b506: ff ff ff        STU    $FFFF
b509: ff ff ff        STU    $FFFF
b50c: ff ff ff        STU    $FFFF
b50f: ff ff ff        STU    $FFFF
b512: ff ff ff        STU    $FFFF
b515: ff ff ff        STU    $FFFF
b518: ff ff ff        STU    $FFFF
b51b: ff ff ff        STU    $FFFF
b51e: ff ff ff        STU    $FFFF
b521: ff ff ff        STU    $FFFF
b524: ff ff ff        STU    $FFFF
b527: ff ff ff        STU    $FFFF
b52a: ff ff ff        STU    $FFFF
b52d: ff ff ff        STU    $FFFF
b530: ff ff ff        STU    $FFFF
b533: ff ff ff        STU    $FFFF
b536: ff ff ff        STU    $FFFF
b539: ff ff ff        STU    $FFFF
b53c: ff ff ff        STU    $FFFF
b53f: ff ff ff        STU    $FFFF
b542: ff ff ff        STU    $FFFF
b545: ff ff ff        STU    $FFFF
b548: ff ff ff        STU    $FFFF
b54b: ff ff ff        STU    $FFFF
b54e: ff ff ff        STU    $FFFF
b551: ff ff ff        STU    $FFFF
b554: ff ff ff        STU    $FFFF
b557: ff ff ff        STU    $FFFF
b55a: ff ff ff        STU    $FFFF
b55d: ff ff ff        STU    $FFFF
b560: ff ff ff        STU    $FFFF
b563: ff ff ff        STU    $FFFF
b566: ff ff ff        STU    $FFFF
b569: ff ff ff        STU    $FFFF
b56c: ff ff ff        STU    $FFFF
b56f: ff ff ff        STU    $FFFF
b572: ff ff ff        STU    $FFFF
b575: ff ff ff        STU    $FFFF
b578: ff ff ff        STU    $FFFF
b57b: ff ff ff        STU    $FFFF
b57e: ff ff ff        STU    $FFFF
b581: ff ff ff        STU    $FFFF
b584: ff ff ff        STU    $FFFF
b587: ff ff ff        STU    $FFFF
b58a: ff ff ff        STU    $FFFF
b58d: ff ff ff        STU    $FFFF
b590: ff ff ff        STU    $FFFF
b593: ff ff ff        STU    $FFFF
b596: ff ff ff        STU    $FFFF
b599: ff ff ff        STU    $FFFF
b59c: ff ff ff        STU    $FFFF
b59f: ff ff ff        STU    $FFFF
b5a2: ff ff ff        STU    $FFFF
b5a5: ff ff ff        STU    $FFFF
b5a8: ff ff ff        STU    $FFFF
b5ab: ff ff ff        STU    $FFFF
b5ae: ff ff ff        STU    $FFFF
b5b1: ff ff ff        STU    $FFFF
b5b4: ff ff ff        STU    $FFFF
b5b7: ff ff ff        STU    $FFFF
b5ba: ff ff ff        STU    $FFFF
b5bd: ff ff ff        STU    $FFFF
b5c0: ff ff ff        STU    $FFFF
b5c3: ff ff ff        STU    $FFFF
b5c6: ff ff ff        STU    $FFFF
b5c9: ff ff ff        STU    $FFFF
b5cc: ff ff ff        STU    $FFFF
b5cf: ff ff ff        STU    $FFFF
b5d2: ff ff ff        STU    $FFFF
b5d5: ff ff ff        STU    $FFFF
b5d8: ff ff ff        STU    $FFFF
b5db: ff ff ff        STU    $FFFF
b5de: ff ff ff        STU    $FFFF
b5e1: ff ff ff        STU    $FFFF
b5e4: ff ff ff        STU    $FFFF
b5e7: ff ff ff        STU    $FFFF
b5ea: ff ff ff        STU    $FFFF
b5ed: ff ff ff        STU    $FFFF
b5f0: ff ff ff        STU    $FFFF
b5f3: ff ff ff        STU    $FFFF
b5f6: ff ff ff        STU    $FFFF
b5f9: ff ff ff        STU    $FFFF
b5fc: ff ff ff        STU    $FFFF
b5ff: ff ff ff        STU    $FFFF
b602: ff ff ff        STU    $FFFF
b605: ff ff ff        STU    $FFFF
b608: ff ff ff        STU    $FFFF
b60b: ff ff ff        STU    $FFFF
b60e: ff ff ff        STU    $FFFF
b611: ff ff ff        STU    $FFFF
b614: ff ff ff        STU    $FFFF
b617: ff ff ff        STU    $FFFF
b61a: ff ff ff        STU    $FFFF
b61d: ff ff ff        STU    $FFFF
b620: ff ff ff        STU    $FFFF
b623: ff ff ff        STU    $FFFF
b626: ff ff ff        STU    $FFFF
b629: ff ff ff        STU    $FFFF
b62c: ff ff ff        STU    $FFFF
b62f: ff ff ff        STU    $FFFF
b632: ff ff ff        STU    $FFFF
b635: ff ff ff        STU    $FFFF
b638: ff ff ff        STU    $FFFF
b63b: ff ff ff        STU    $FFFF
b63e: ff ff ff        STU    $FFFF
b641: ff ff ff        STU    $FFFF
b644: ff ff ff        STU    $FFFF
b647: ff ff ff        STU    $FFFF
b64a: ff ff ff        STU    $FFFF
b64d: ff ff ff        STU    $FFFF
b650: ff ff ff        STU    $FFFF
b653: ff ff ff        STU    $FFFF
b656: ff ff ff        STU    $FFFF
b659: ff ff ff        STU    $FFFF
b65c: ff ff ff        STU    $FFFF
b65f: ff ff ff        STU    $FFFF
b662: ff ff ff        STU    $FFFF
b665: ff ff ff        STU    $FFFF
b668: ff ff ff        STU    $FFFF
b66b: ff ff ff        STU    $FFFF
b66e: ff ff ff        STU    $FFFF
b671: ff ff ff        STU    $FFFF
b674: ff ff ff        STU    $FFFF
b677: ff ff ff        STU    $FFFF
b67a: ff ff ff        STU    $FFFF
b67d: ff ff ff        STU    $FFFF
b680: ff ff ff        STU    $FFFF
b683: ff ff ff        STU    $FFFF
b686: ff ff ff        STU    $FFFF
b689: ff ff ff        STU    $FFFF
b68c: ff ff ff        STU    $FFFF
b68f: ff ff ff        STU    $FFFF
b692: ff ff ff        STU    $FFFF
b695: ff ff ff        STU    $FFFF
b698: ff ff ff        STU    $FFFF
b69b: ff ff ff        STU    $FFFF
b69e: ff ff ff        STU    $FFFF
b6a1: ff ff ff        STU    $FFFF
b6a4: ff ff ff        STU    $FFFF
b6a7: ff ff ff        STU    $FFFF
b6aa: ff ff ff        STU    $FFFF
b6ad: ff ff ff        STU    $FFFF
b6b0: ff ff ff        STU    $FFFF
b6b3: ff ff ff        STU    $FFFF
b6b6: ff ff ff        STU    $FFFF
b6b9: ff ff ff        STU    $FFFF
b6bc: ff ff ff        STU    $FFFF
b6bf: ff ff ff        STU    $FFFF
b6c2: ff ff ff        STU    $FFFF
b6c5: ff ff ff        STU    $FFFF
b6c8: ff ff ff        STU    $FFFF
b6cb: ff ff ff        STU    $FFFF
b6ce: ff ff ff        STU    $FFFF
b6d1: ff ff ff        STU    $FFFF
b6d4: ff ff ff        STU    $FFFF
b6d7: ff ff ff        STU    $FFFF
b6da: ff ff ff        STU    $FFFF
b6dd: ff ff ff        STU    $FFFF
b6e0: ff ff ff        STU    $FFFF
b6e3: ff ff ff        STU    $FFFF
b6e6: ff ff ff        STU    $FFFF
b6e9: ff ff ff        STU    $FFFF
b6ec: ff ff ff        STU    $FFFF
b6ef: ff ff ff        STU    $FFFF
b6f2: ff ff ff        STU    $FFFF
b6f5: ff ff ff        STU    $FFFF
b6f8: ff ff ff        STU    $FFFF
b6fb: ff ff ff        STU    $FFFF
b6fe: ff ff ff        STU    $FFFF
b701: ff ff ff        STU    $FFFF
b704: ff ff ff        STU    $FFFF
b707: ff ff ff        STU    $FFFF
b70a: ff ff ff        STU    $FFFF
b70d: ff ff ff        STU    $FFFF
b710: ff ff ff        STU    $FFFF
b713: ff ff ff        STU    $FFFF
b716: ff ff ff        STU    $FFFF
b719: ff ff ff        STU    $FFFF
b71c: ff ff ff        STU    $FFFF
b71f: ff ff ff        STU    $FFFF
b722: ff ff ff        STU    $FFFF
b725: ff ff ff        STU    $FFFF
b728: ff ff ff        STU    $FFFF
b72b: ff ff ff        STU    $FFFF
b72e: ff ff ff        STU    $FFFF
b731: ff ff ff        STU    $FFFF
b734: ff ff ff        STU    $FFFF
b737: ff ff ff        STU    $FFFF
b73a: ff ff ff        STU    $FFFF
b73d: ff ff ff        STU    $FFFF
b740: ff ff ff        STU    $FFFF
b743: ff ff ff        STU    $FFFF
b746: ff ff ff        STU    $FFFF
b749: ff ff ff        STU    $FFFF
b74c: ff ff ff        STU    $FFFF
b74f: ff ff ff        STU    $FFFF
b752: ff ff ff        STU    $FFFF
b755: ff ff ff        STU    $FFFF
b758: ff ff ff        STU    $FFFF
b75b: ff ff ff        STU    $FFFF
b75e: ff ff ff        STU    $FFFF
b761: ff ff ff        STU    $FFFF
b764: ff ff ff        STU    $FFFF
b767: ff ff ff        STU    $FFFF
b76a: ff ff ff        STU    $FFFF
b76d: ff ff ff        STU    $FFFF
b770: ff ff ff        STU    $FFFF
b773: ff ff ff        STU    $FFFF
b776: ff ff ff        STU    $FFFF
b779: ff ff ff        STU    $FFFF
b77c: ff ff ff        STU    $FFFF
b77f: ff ff ff        STU    $FFFF
b782: ff ff ff        STU    $FFFF
b785: ff ff ff        STU    $FFFF
b788: ff ff ff        STU    $FFFF
b78b: ff ff ff        STU    $FFFF
b78e: ff ff ff        STU    $FFFF
b791: ff ff ff        STU    $FFFF
b794: ff ff ff        STU    $FFFF
b797: ff ff ff        STU    $FFFF
b79a: ff ff ff        STU    $FFFF
b79d: ff ff ff        STU    $FFFF
b7a0: ff ff ff        STU    $FFFF
b7a3: ff ff ff        STU    $FFFF
b7a6: ff ff ff        STU    $FFFF
b7a9: ff ff ff        STU    $FFFF
b7ac: ff ff ff        STU    $FFFF
b7af: ff ff ff        STU    $FFFF
b7b2: ff ff ff        STU    $FFFF
b7b5: ff ff ff        STU    $FFFF
b7b8: ff ff ff        STU    $FFFF
b7bb: ff ff ff        STU    $FFFF
b7be: ff ff ff        STU    $FFFF
b7c1: ff ff ff        STU    $FFFF
b7c4: ff ff ff        STU    $FFFF
b7c7: ff ff ff        STU    $FFFF
b7ca: ff ff ff        STU    $FFFF
b7cd: ff ff ff        STU    $FFFF
b7d0: ff ff ff        STU    $FFFF
b7d3: ff ff ff        STU    $FFFF
b7d6: ff ff ff        STU    $FFFF
b7d9: ff ff ff        STU    $FFFF
b7dc: ff ff ff        STU    $FFFF
b7df: ff ff ff        STU    $FFFF
b7e2: ff ff ff        STU    $FFFF
b7e5: ff ff ff        STU    $FFFF
b7e8: ff ff ff        STU    $FFFF
b7eb: ff ff ff        STU    $FFFF
b7ee: ff ff ff        STU    $FFFF
b7f1: ff ff ff        STU    $FFFF
b7f4: ff ff ff        STU    $FFFF
b7f7: ff ff ff        STU    $FFFF
b7fa: ff ff ff        STU    $FFFF
b7fd: ff ff ff        STU    $FFFF
b800: ff ff ff        STU    $FFFF
b803: ff ff ff        STU    $FFFF
b806: ff ff ff        STU    $FFFF
b809: ff ff ff        STU    $FFFF
b80c: ff ff ff        STU    $FFFF
b80f: ff ff ff        STU    $FFFF
b812: ff ff ff        STU    $FFFF
b815: ff ff ff        STU    $FFFF
b818: ff ff ff        STU    $FFFF
b81b: ff ff ff        STU    $FFFF
b81e: ff ff ff        STU    $FFFF
b821: ff ff ff        STU    $FFFF
b824: ff ff ff        STU    $FFFF
b827: ff ff ff        STU    $FFFF
b82a: ff ff ff        STU    $FFFF
b82d: ff ff ff        STU    $FFFF
b830: ff ff ff        STU    $FFFF
b833: ff ff ff        STU    $FFFF
b836: ff ff ff        STU    $FFFF
b839: ff ff ff        STU    $FFFF
b83c: ff ff ff        STU    $FFFF
b83f: ff ff ff        STU    $FFFF
b842: ff ff ff        STU    $FFFF
b845: ff ff ff        STU    $FFFF
b848: ff ff ff        STU    $FFFF
b84b: ff ff ff        STU    $FFFF
b84e: ff ff ff        STU    $FFFF
b851: ff ff ff        STU    $FFFF
b854: ff ff ff        STU    $FFFF
b857: ff ff ff        STU    $FFFF
b85a: ff ff ff        STU    $FFFF
b85d: ff ff ff        STU    $FFFF
b860: ff ff ff        STU    $FFFF
b863: ff ff ff        STU    $FFFF
b866: ff ff ff        STU    $FFFF
b869: ff ff ff        STU    $FFFF
b86c: ff ff ff        STU    $FFFF
b86f: ff ff ff        STU    $FFFF
b872: ff ff ff        STU    $FFFF
b875: ff ff ff        STU    $FFFF
b878: ff ff ff        STU    $FFFF
b87b: ff ff ff        STU    $FFFF
b87e: ff ff ff        STU    $FFFF
b881: ff ff ff        STU    $FFFF
b884: ff ff ff        STU    $FFFF
b887: ff ff ff        STU    $FFFF
b88a: ff ff ff        STU    $FFFF
b88d: ff ff ff        STU    $FFFF
b890: ff ff ff        STU    $FFFF
b893: ff ff ff        STU    $FFFF
b896: ff ff ff        STU    $FFFF
b899: ff ff ff        STU    $FFFF
b89c: ff ff ff        STU    $FFFF
b89f: ff ff ff        STU    $FFFF
b8a2: ff ff ff        STU    $FFFF
b8a5: ff ff ff        STU    $FFFF
b8a8: ff ff ff        STU    $FFFF
b8ab: ff ff ff        STU    $FFFF
b8ae: ff ff ff        STU    $FFFF
b8b1: ff ff ff        STU    $FFFF
b8b4: ff ff ff        STU    $FFFF
b8b7: ff ff ff        STU    $FFFF
b8ba: ff ff ff        STU    $FFFF
b8bd: ff ff ff        STU    $FFFF
b8c0: ff ff ff        STU    $FFFF
b8c3: ff ff ff        STU    $FFFF
b8c6: ff ff ff        STU    $FFFF
b8c9: ff ff ff        STU    $FFFF
b8cc: ff ff ff        STU    $FFFF
b8cf: ff ff ff        STU    $FFFF
b8d2: ff ff ff        STU    $FFFF
b8d5: ff ff ff        STU    $FFFF
b8d8: ff ff ff        STU    $FFFF
b8db: ff ff ff        STU    $FFFF
b8de: ff ff ff        STU    $FFFF
b8e1: ff ff ff        STU    $FFFF
b8e4: ff ff ff        STU    $FFFF
b8e7: ff ff ff        STU    $FFFF
b8ea: ff ff ff        STU    $FFFF
b8ed: ff ff ff        STU    $FFFF
b8f0: ff ff ff        STU    $FFFF
b8f3: ff ff ff        STU    $FFFF
b8f6: ff ff ff        STU    $FFFF
b8f9: ff ff ff        STU    $FFFF
b8fc: ff ff ff        STU    $FFFF
b8ff: ff ff ff        STU    $FFFF
b902: ff ff ff        STU    $FFFF
b905: ff ff ff        STU    $FFFF
b908: ff ff ff        STU    $FFFF
b90b: ff ff ff        STU    $FFFF
b90e: ff ff ff        STU    $FFFF
b911: ff ff ff        STU    $FFFF
b914: ff ff ff        STU    $FFFF
b917: ff ff ff        STU    $FFFF
b91a: ff ff ff        STU    $FFFF
b91d: ff ff ff        STU    $FFFF
b920: ff ff ff        STU    $FFFF
b923: ff ff ff        STU    $FFFF
b926: ff ff ff        STU    $FFFF
b929: ff ff ff        STU    $FFFF
b92c: ff ff ff        STU    $FFFF
b92f: ff ff ff        STU    $FFFF
b932: ff ff ff        STU    $FFFF
b935: ff ff ff        STU    $FFFF
b938: ff ff ff        STU    $FFFF
b93b: ff ff ff        STU    $FFFF
b93e: ff ff ff        STU    $FFFF
b941: ff ff ff        STU    $FFFF
b944: ff ff ff        STU    $FFFF
b947: ff ff ff        STU    $FFFF
b94a: ff ff ff        STU    $FFFF
b94d: ff ff ff        STU    $FFFF
b950: ff ff ff        STU    $FFFF
b953: ff ff ff        STU    $FFFF
b956: ff ff ff        STU    $FFFF
b959: ff ff ff        STU    $FFFF
b95c: ff ff ff        STU    $FFFF
b95f: ff ff ff        STU    $FFFF
b962: ff ff ff        STU    $FFFF
b965: ff ff ff        STU    $FFFF
b968: ff ff ff        STU    $FFFF
b96b: ff ff ff        STU    $FFFF
b96e: ff ff ff        STU    $FFFF
b971: ff ff ff        STU    $FFFF
b974: ff ff ff        STU    $FFFF
b977: ff ff ff        STU    $FFFF
b97a: ff ff ff        STU    $FFFF
b97d: ff ff ff        STU    $FFFF
b980: ff ff ff        STU    $FFFF
b983: ff ff ff        STU    $FFFF
b986: ff ff ff        STU    $FFFF
b989: ff ff ff        STU    $FFFF
b98c: ff ff ff        STU    $FFFF
b98f: ff ff ff        STU    $FFFF
b992: ff ff ff        STU    $FFFF
b995: ff ff ff        STU    $FFFF
b998: ff ff ff        STU    $FFFF
b99b: ff ff ff        STU    $FFFF
b99e: ff ff ff        STU    $FFFF
b9a1: ff ff ff        STU    $FFFF
b9a4: ff ff ff        STU    $FFFF
b9a7: ff ff ff        STU    $FFFF
b9aa: ff ff ff        STU    $FFFF
b9ad: ff ff ff        STU    $FFFF
b9b0: ff ff ff        STU    $FFFF
b9b3: ff ff ff        STU    $FFFF
b9b6: ff ff ff        STU    $FFFF
b9b9: ff ff ff        STU    $FFFF
b9bc: ff ff ff        STU    $FFFF
b9bf: ff ff ff        STU    $FFFF
b9c2: ff ff ff        STU    $FFFF
b9c5: ff ff ff        STU    $FFFF
b9c8: ff ff ff        STU    $FFFF
b9cb: ff ff ff        STU    $FFFF
b9ce: ff ff ff        STU    $FFFF
b9d1: ff ff ff        STU    $FFFF
b9d4: ff ff ff        STU    $FFFF
b9d7: ff ff ff        STU    $FFFF
b9da: ff ff ff        STU    $FFFF
b9dd: ff ff ff        STU    $FFFF
b9e0: ff ff ff        STU    $FFFF
b9e3: ff ff ff        STU    $FFFF
b9e6: ff ff ff        STU    $FFFF
b9e9: ff ff ff        STU    $FFFF
b9ec: ff ff ff        STU    $FFFF
b9ef: ff ff ff        STU    $FFFF
b9f2: ff ff ff        STU    $FFFF
b9f5: ff ff ff        STU    $FFFF
b9f8: ff ff ff        STU    $FFFF
b9fb: ff ff ff        STU    $FFFF
b9fe: ff ff ff        STU    $FFFF
ba01: ff ff ff        STU    $FFFF
ba04: ff ff ff        STU    $FFFF
ba07: ff ff ff        STU    $FFFF
ba0a: ff ff ff        STU    $FFFF
ba0d: ff ff ff        STU    $FFFF
ba10: ff ff ff        STU    $FFFF
ba13: ff ff ff        STU    $FFFF
ba16: ff ff ff        STU    $FFFF
ba19: ff ff ff        STU    $FFFF
ba1c: ff ff ff        STU    $FFFF
ba1f: ff ff ff        STU    $FFFF
ba22: ff ff ff        STU    $FFFF
ba25: ff ff ff        STU    $FFFF
ba28: ff ff ff        STU    $FFFF
ba2b: ff ff ff        STU    $FFFF
ba2e: ff ff ff        STU    $FFFF
ba31: ff ff ff        STU    $FFFF
ba34: ff ff ff        STU    $FFFF
ba37: ff ff ff        STU    $FFFF
ba3a: ff ff ff        STU    $FFFF
ba3d: ff ff ff        STU    $FFFF
ba40: ff ff ff        STU    $FFFF
ba43: ff ff ff        STU    $FFFF
ba46: ff ff ff        STU    $FFFF
ba49: ff ff ff        STU    $FFFF
ba4c: ff ff ff        STU    $FFFF
ba4f: ff ff ff        STU    $FFFF
ba52: ff ff ff        STU    $FFFF
ba55: ff ff ff        STU    $FFFF
ba58: ff ff ff        STU    $FFFF
ba5b: ff ff ff        STU    $FFFF
ba5e: ff ff ff        STU    $FFFF
ba61: ff ff ff        STU    $FFFF
ba64: ff ff ff        STU    $FFFF
ba67: ff ff ff        STU    $FFFF
ba6a: ff ff ff        STU    $FFFF
ba6d: ff ff ff        STU    $FFFF
ba70: ff ff ff        STU    $FFFF
ba73: ff ff ff        STU    $FFFF
ba76: ff ff ff        STU    $FFFF
ba79: ff ff ff        STU    $FFFF
ba7c: ff ff ff        STU    $FFFF
ba7f: ff ff ff        STU    $FFFF
ba82: ff ff ff        STU    $FFFF
ba85: ff ff ff        STU    $FFFF
ba88: ff ff ff        STU    $FFFF
ba8b: ff ff ff        STU    $FFFF
ba8e: ff ff ff        STU    $FFFF
ba91: ff ff ff        STU    $FFFF
ba94: ff ff ff        STU    $FFFF
ba97: ff ff ff        STU    $FFFF
ba9a: ff ff ff        STU    $FFFF
ba9d: ff ff ff        STU    $FFFF
baa0: ff ff ff        STU    $FFFF
baa3: ff ff ff        STU    $FFFF
baa6: ff ff ff        STU    $FFFF
baa9: ff ff ff        STU    $FFFF
baac: ff ff ff        STU    $FFFF
baaf: ff ff ff        STU    $FFFF
bab2: ff ff ff        STU    $FFFF
bab5: ff ff ff        STU    $FFFF
bab8: ff ff ff        STU    $FFFF
babb: ff ff ff        STU    $FFFF
babe: ff ff ff        STU    $FFFF
bac1: ff ff ff        STU    $FFFF
bac4: ff ff ff        STU    $FFFF
bac7: ff ff ff        STU    $FFFF
baca: ff ff ff        STU    $FFFF
bacd: ff ff ff        STU    $FFFF
bad0: ff ff ff        STU    $FFFF
bad3: ff ff ff        STU    $FFFF
bad6: ff ff ff        STU    $FFFF
bad9: ff ff ff        STU    $FFFF
badc: ff ff ff        STU    $FFFF
badf: ff ff ff        STU    $FFFF
bae2: ff ff ff        STU    $FFFF
bae5: ff ff ff        STU    $FFFF
bae8: ff ff ff        STU    $FFFF
baeb: ff ff ff        STU    $FFFF
baee: ff ff ff        STU    $FFFF
baf1: ff ff ff        STU    $FFFF
baf4: ff ff ff        STU    $FFFF
baf7: ff ff ff        STU    $FFFF
bafa: ff ff ff        STU    $FFFF
bafd: ff ff ff        STU    $FFFF
bb00: ff ff ff        STU    $FFFF
bb03: ff ff ff        STU    $FFFF
bb06: ff ff ff        STU    $FFFF
bb09: ff ff ff        STU    $FFFF
bb0c: ff ff ff        STU    $FFFF
bb0f: ff ff ff        STU    $FFFF
bb12: ff ff ff        STU    $FFFF
bb15: ff ff ff        STU    $FFFF
bb18: ff ff ff        STU    $FFFF
bb1b: ff ff ff        STU    $FFFF
bb1e: ff ff ff        STU    $FFFF
bb21: ff ff ff        STU    $FFFF
bb24: ff ff ff        STU    $FFFF
bb27: ff ff ff        STU    $FFFF
bb2a: ff ff ff        STU    $FFFF
bb2d: ff ff ff        STU    $FFFF
bb30: ff ff ff        STU    $FFFF
bb33: ff ff ff        STU    $FFFF
bb36: ff ff ff        STU    $FFFF
bb39: ff ff ff        STU    $FFFF
bb3c: ff ff ff        STU    $FFFF
bb3f: ff ff ff        STU    $FFFF
bb42: ff ff ff        STU    $FFFF
bb45: ff ff ff        STU    $FFFF
bb48: ff ff ff        STU    $FFFF
bb4b: ff ff ff        STU    $FFFF
bb4e: ff ff ff        STU    $FFFF
bb51: ff ff ff        STU    $FFFF
bb54: ff ff ff        STU    $FFFF
bb57: ff ff ff        STU    $FFFF
bb5a: ff ff ff        STU    $FFFF
bb5d: ff ff ff        STU    $FFFF
bb60: ff ff ff        STU    $FFFF
bb63: ff ff ff        STU    $FFFF
bb66: ff ff ff        STU    $FFFF
bb69: ff ff ff        STU    $FFFF
bb6c: ff ff ff        STU    $FFFF
bb6f: ff ff ff        STU    $FFFF
bb72: ff ff ff        STU    $FFFF
bb75: ff ff ff        STU    $FFFF
bb78: ff ff ff        STU    $FFFF
bb7b: ff ff ff        STU    $FFFF
bb7e: ff ff ff        STU    $FFFF
bb81: ff ff ff        STU    $FFFF
bb84: ff ff ff        STU    $FFFF
bb87: ff ff ff        STU    $FFFF
bb8a: ff ff ff        STU    $FFFF
bb8d: ff ff ff        STU    $FFFF
bb90: ff ff ff        STU    $FFFF
bb93: ff ff ff        STU    $FFFF
bb96: ff ff ff        STU    $FFFF
bb99: ff ff ff        STU    $FFFF
bb9c: ff ff ff        STU    $FFFF
bb9f: ff ff ff        STU    $FFFF
bba2: ff ff ff        STU    $FFFF
bba5: ff ff ff        STU    $FFFF
bba8: ff ff ff        STU    $FFFF
bbab: ff ff ff        STU    $FFFF
bbae: ff ff ff        STU    $FFFF
bbb1: ff ff ff        STU    $FFFF
bbb4: ff ff ff        STU    $FFFF
bbb7: ff ff ff        STU    $FFFF
bbba: ff ff ff        STU    $FFFF
bbbd: ff ff ff        STU    $FFFF
bbc0: ff ff ff        STU    $FFFF
bbc3: ff ff ff        STU    $FFFF
bbc6: ff ff ff        STU    $FFFF
bbc9: ff ff ff        STU    $FFFF
bbcc: ff ff ff        STU    $FFFF
bbcf: ff ff ff        STU    $FFFF
bbd2: ff ff ff        STU    $FFFF
bbd5: ff ff ff        STU    $FFFF
bbd8: ff ff ff        STU    $FFFF
bbdb: ff ff ff        STU    $FFFF
bbde: ff ff ff        STU    $FFFF
bbe1: ff ff ff        STU    $FFFF
bbe4: ff ff ff        STU    $FFFF
bbe7: ff ff ff        STU    $FFFF
bbea: ff ff ff        STU    $FFFF
bbed: ff ff ff        STU    $FFFF
bbf0: ff ff ff        STU    $FFFF
bbf3: ff ff ff        STU    $FFFF
bbf6: ff ff ff        STU    $FFFF
bbf9: ff ff ff        STU    $FFFF
bbfc: ff ff ff        STU    $FFFF
bbff: ff ff ff        STU    $FFFF
bc02: ff ff ff        STU    $FFFF
bc05: ff ff ff        STU    $FFFF
bc08: ff ff ff        STU    $FFFF
bc0b: ff ff ff        STU    $FFFF
bc0e: ff ff ff        STU    $FFFF
bc11: ff ff ff        STU    $FFFF
bc14: ff ff ff        STU    $FFFF
bc17: ff ff ff        STU    $FFFF
bc1a: ff ff ff        STU    $FFFF
bc1d: ff ff ff        STU    $FFFF
bc20: ff ff ff        STU    $FFFF
bc23: ff ff ff        STU    $FFFF
bc26: ff ff ff        STU    $FFFF
bc29: ff ff ff        STU    $FFFF
bc2c: ff ff ff        STU    $FFFF
bc2f: ff ff ff        STU    $FFFF
bc32: ff ff ff        STU    $FFFF
bc35: ff ff ff        STU    $FFFF
bc38: ff ff ff        STU    $FFFF
bc3b: ff ff ff        STU    $FFFF
bc3e: ff ff ff        STU    $FFFF
bc41: ff ff ff        STU    $FFFF
bc44: ff ff ff        STU    $FFFF
bc47: ff ff ff        STU    $FFFF
bc4a: ff ff ff        STU    $FFFF
bc4d: ff ff ff        STU    $FFFF
bc50: ff ff ff        STU    $FFFF
bc53: ff ff ff        STU    $FFFF
bc56: ff ff ff        STU    $FFFF
bc59: ff ff ff        STU    $FFFF
bc5c: ff ff ff        STU    $FFFF
bc5f: ff ff ff        STU    $FFFF
bc62: ff ff ff        STU    $FFFF
bc65: ff ff ff        STU    $FFFF
bc68: ff ff ff        STU    $FFFF
bc6b: ff ff ff        STU    $FFFF
bc6e: ff ff ff        STU    $FFFF
bc71: ff ff ff        STU    $FFFF
bc74: ff ff ff        STU    $FFFF
bc77: ff ff ff        STU    $FFFF
bc7a: ff ff ff        STU    $FFFF
bc7d: ff ff ff        STU    $FFFF
bc80: ff ff ff        STU    $FFFF
bc83: ff ff ff        STU    $FFFF
bc86: ff ff ff        STU    $FFFF
bc89: ff ff ff        STU    $FFFF
bc8c: ff ff ff        STU    $FFFF
bc8f: ff ff ff        STU    $FFFF
bc92: ff ff ff        STU    $FFFF
bc95: ff ff ff        STU    $FFFF
bc98: ff ff ff        STU    $FFFF
bc9b: ff ff ff        STU    $FFFF
bc9e: ff ff ff        STU    $FFFF
bca1: ff ff ff        STU    $FFFF
bca4: ff ff ff        STU    $FFFF
bca7: ff ff ff        STU    $FFFF
bcaa: ff ff ff        STU    $FFFF
bcad: ff ff ff        STU    $FFFF
bcb0: ff ff ff        STU    $FFFF
bcb3: ff ff ff        STU    $FFFF
bcb6: ff ff ff        STU    $FFFF
bcb9: ff ff ff        STU    $FFFF
bcbc: ff ff ff        STU    $FFFF
bcbf: ff ff ff        STU    $FFFF
bcc2: ff ff ff        STU    $FFFF
bcc5: ff ff ff        STU    $FFFF
bcc8: ff ff ff        STU    $FFFF
bccb: ff ff ff        STU    $FFFF
bcce: ff ff ff        STU    $FFFF
bcd1: ff ff ff        STU    $FFFF
bcd4: ff ff ff        STU    $FFFF
bcd7: ff ff ff        STU    $FFFF
bcda: ff ff ff        STU    $FFFF
bcdd: ff ff ff        STU    $FFFF
bce0: ff ff ff        STU    $FFFF
bce3: ff ff ff        STU    $FFFF
bce6: ff ff ff        STU    $FFFF
bce9: ff ff ff        STU    $FFFF
bcec: ff ff ff        STU    $FFFF
bcef: ff ff ff        STU    $FFFF
bcf2: ff ff ff        STU    $FFFF
bcf5: ff ff ff        STU    $FFFF
bcf8: ff ff ff        STU    $FFFF
bcfb: ff ff ff        STU    $FFFF
bcfe: ff ff ff        STU    $FFFF
bd01: ff ff ff        STU    $FFFF
bd04: ff ff ff        STU    $FFFF
bd07: ff ff ff        STU    $FFFF
bd0a: ff ff ff        STU    $FFFF
bd0d: ff ff ff        STU    $FFFF
bd10: ff ff ff        STU    $FFFF
bd13: ff ff ff        STU    $FFFF
bd16: ff ff ff        STU    $FFFF
bd19: ff ff ff        STU    $FFFF
bd1c: ff ff ff        STU    $FFFF
bd1f: ff ff ff        STU    $FFFF
bd22: ff ff ff        STU    $FFFF
bd25: ff ff ff        STU    $FFFF
bd28: ff ff ff        STU    $FFFF
bd2b: ff ff ff        STU    $FFFF
bd2e: ff ff ff        STU    $FFFF
bd31: ff ff ff        STU    $FFFF
bd34: ff ff ff        STU    $FFFF
bd37: ff ff ff        STU    $FFFF
bd3a: ff ff ff        STU    $FFFF
bd3d: ff ff ff        STU    $FFFF
bd40: ff ff ff        STU    $FFFF
bd43: ff ff ff        STU    $FFFF
bd46: ff ff ff        STU    $FFFF
bd49: ff ff ff        STU    $FFFF
bd4c: ff ff ff        STU    $FFFF
bd4f: ff ff ff        STU    $FFFF
bd52: ff ff ff        STU    $FFFF
bd55: ff ff ff        STU    $FFFF
bd58: ff ff ff        STU    $FFFF
bd5b: ff ff ff        STU    $FFFF
bd5e: ff ff ff        STU    $FFFF
bd61: ff ff ff        STU    $FFFF
bd64: ff ff ff        STU    $FFFF
bd67: ff ff ff        STU    $FFFF
bd6a: ff ff ff        STU    $FFFF
bd6d: ff ff ff        STU    $FFFF
bd70: ff ff ff        STU    $FFFF
bd73: ff ff ff        STU    $FFFF
bd76: ff ff ff        STU    $FFFF
bd79: ff ff ff        STU    $FFFF
bd7c: ff ff ff        STU    $FFFF
bd7f: ff ff ff        STU    $FFFF
bd82: ff ff ff        STU    $FFFF
bd85: ff ff ff        STU    $FFFF
bd88: ff ff ff        STU    $FFFF
bd8b: ff ff ff        STU    $FFFF
bd8e: ff ff ff        STU    $FFFF
bd91: ff ff ff        STU    $FFFF
bd94: ff ff ff        STU    $FFFF
bd97: ff ff ff        STU    $FFFF
bd9a: ff ff ff        STU    $FFFF
bd9d: ff ff ff        STU    $FFFF
bda0: ff ff ff        STU    $FFFF
bda3: ff ff ff        STU    $FFFF
bda6: ff ff ff        STU    $FFFF
bda9: ff ff ff        STU    $FFFF
bdac: ff ff ff        STU    $FFFF
bdaf: ff ff ff        STU    $FFFF
bdb2: ff ff ff        STU    $FFFF
bdb5: ff ff ff        STU    $FFFF
bdb8: ff ff ff        STU    $FFFF
bdbb: ff ff ff        STU    $FFFF
bdbe: ff ff ff        STU    $FFFF
bdc1: ff ff ff        STU    $FFFF
bdc4: ff ff ff        STU    $FFFF
bdc7: ff ff ff        STU    $FFFF
bdca: ff ff ff        STU    $FFFF
bdcd: ff ff ff        STU    $FFFF
bdd0: ff ff ff        STU    $FFFF
bdd3: ff ff ff        STU    $FFFF
bdd6: ff ff ff        STU    $FFFF
bdd9: ff ff ff        STU    $FFFF
bddc: ff ff ff        STU    $FFFF
bddf: ff ff ff        STU    $FFFF
bde2: ff ff ff        STU    $FFFF
bde5: ff ff ff        STU    $FFFF
bde8: ff ff ff        STU    $FFFF
bdeb: ff ff ff        STU    $FFFF
bdee: ff ff ff        STU    $FFFF
bdf1: ff ff ff        STU    $FFFF
bdf4: ff ff ff        STU    $FFFF
bdf7: ff ff ff        STU    $FFFF
bdfa: ff ff ff        STU    $FFFF
bdfd: ff ff ff        STU    $FFFF
be00: ff ff ff        STU    $FFFF
be03: ff ff ff        STU    $FFFF
be06: ff ff ff        STU    $FFFF
be09: ff ff ff        STU    $FFFF
be0c: ff ff ff        STU    $FFFF
be0f: ff ff ff        STU    $FFFF
be12: ff ff ff        STU    $FFFF
be15: ff ff ff        STU    $FFFF
be18: ff ff ff        STU    $FFFF
be1b: ff ff ff        STU    $FFFF
be1e: ff ff ff        STU    $FFFF
be21: ff ff ff        STU    $FFFF
be24: ff ff ff        STU    $FFFF
be27: ff ff ff        STU    $FFFF
be2a: ff ff ff        STU    $FFFF
be2d: ff ff ff        STU    $FFFF
be30: ff ff ff        STU    $FFFF
be33: ff ff ff        STU    $FFFF
be36: ff ff ff        STU    $FFFF
be39: ff ff ff        STU    $FFFF
be3c: ff ff ff        STU    $FFFF
be3f: ff ff ff        STU    $FFFF
be42: ff ff ff        STU    $FFFF
be45: ff ff ff        STU    $FFFF
be48: ff ff ff        STU    $FFFF
be4b: ff ff ff        STU    $FFFF
be4e: ff ff ff        STU    $FFFF
be51: ff ff ff        STU    $FFFF
be54: ff ff ff        STU    $FFFF
be57: ff ff ff        STU    $FFFF
be5a: ff ff ff        STU    $FFFF
be5d: ff ff ff        STU    $FFFF
be60: ff ff ff        STU    $FFFF
be63: ff ff ff        STU    $FFFF
be66: ff ff ff        STU    $FFFF
be69: ff ff ff        STU    $FFFF
be6c: ff ff ff        STU    $FFFF
be6f: ff ff ff        STU    $FFFF
be72: ff ff ff        STU    $FFFF
be75: ff ff ff        STU    $FFFF
be78: ff ff ff        STU    $FFFF
be7b: ff ff ff        STU    $FFFF
be7e: ff ff ff        STU    $FFFF
be81: ff ff ff        STU    $FFFF
be84: ff ff ff        STU    $FFFF
be87: ff ff ff        STU    $FFFF
be8a: ff ff ff        STU    $FFFF
be8d: ff ff ff        STU    $FFFF
be90: ff ff ff        STU    $FFFF
be93: ff ff ff        STU    $FFFF
be96: ff ff ff        STU    $FFFF
be99: ff ff ff        STU    $FFFF
be9c: ff ff ff        STU    $FFFF
be9f: ff ff ff        STU    $FFFF
bea2: ff ff ff        STU    $FFFF
bea5: ff ff ff        STU    $FFFF
bea8: ff ff ff        STU    $FFFF
beab: ff ff ff        STU    $FFFF
beae: ff ff ff        STU    $FFFF
beb1: ff ff ff        STU    $FFFF
beb4: ff ff ff        STU    $FFFF
beb7: ff ff ff        STU    $FFFF
beba: ff ff ff        STU    $FFFF
bebd: ff ff ff        STU    $FFFF
bec0: ff ff ff        STU    $FFFF
bec3: ff ff ff        STU    $FFFF
bec6: ff ff ff        STU    $FFFF
bec9: ff ff ff        STU    $FFFF
becc: ff ff ff        STU    $FFFF
becf: ff ff ff        STU    $FFFF
bed2: ff ff ff        STU    $FFFF
bed5: ff ff ff        STU    $FFFF
bed8: ff ff ff        STU    $FFFF
bedb: ff ff ff        STU    $FFFF
bede: ff ff ff        STU    $FFFF
bee1: ff ff ff        STU    $FFFF
bee4: ff ff ff        STU    $FFFF
bee7: ff ff ff        STU    $FFFF
beea: ff ff ff        STU    $FFFF
beed: ff ff ff        STU    $FFFF
bef0: ff ff ff        STU    $FFFF
bef3: ff ff ff        STU    $FFFF
bef6: ff ff ff        STU    $FFFF
bef9: ff ff ff        STU    $FFFF
befc: ff ff ff        STU    $FFFF
beff: ff ff ff        STU    $FFFF
bf02: ff ff ff        STU    $FFFF
bf05: ff ff ff        STU    $FFFF
bf08: ff ff ff        STU    $FFFF
bf0b: ff ff ff        STU    $FFFF
bf0e: ff ff ff        STU    $FFFF
bf11: ff ff ff        STU    $FFFF
bf14: ff ff ff        STU    $FFFF
bf17: ff ff ff        STU    $FFFF
bf1a: ff ff ff        STU    $FFFF
bf1d: ff ff ff        STU    $FFFF
bf20: ff ff ff        STU    $FFFF
bf23: ff ff ff        STU    $FFFF
bf26: ff ff ff        STU    $FFFF
bf29: ff ff ff        STU    $FFFF
bf2c: ff ff ff        STU    $FFFF
bf2f: ff ff ff        STU    $FFFF
bf32: ff ff ff        STU    $FFFF
bf35: ff ff ff        STU    $FFFF
bf38: ff ff ff        STU    $FFFF
bf3b: ff ff ff        STU    $FFFF
bf3e: ff ff ff        STU    $FFFF
bf41: ff ff ff        STU    $FFFF
bf44: ff ff ff        STU    $FFFF
bf47: ff ff ff        STU    $FFFF
bf4a: ff ff ff        STU    $FFFF
bf4d: ff ff ff        STU    $FFFF
bf50: ff ff ff        STU    $FFFF
bf53: ff ff ff        STU    $FFFF
bf56: ff ff ff        STU    $FFFF
bf59: ff ff ff        STU    $FFFF
bf5c: ff ff ff        STU    $FFFF
bf5f: ff ff ff        STU    $FFFF
bf62: ff ff ff        STU    $FFFF
bf65: ff ff ff        STU    $FFFF
bf68: ff ff ff        STU    $FFFF
bf6b: ff ff ff        STU    $FFFF
bf6e: ff ff ff        STU    $FFFF
bf71: ff ff ff        STU    $FFFF
bf74: ff ff ff        STU    $FFFF
bf77: ff ff ff        STU    $FFFF
bf7a: ff ff ff        STU    $FFFF
bf7d: ff ff ff        STU    $FFFF
bf80: ff ff ff        STU    $FFFF
bf83: ff ff ff        STU    $FFFF
bf86: ff ff ff        STU    $FFFF
bf89: ff ff ff        STU    $FFFF
bf8c: ff ff ff        STU    $FFFF
bf8f: ff ff ff        STU    $FFFF
bf92: ff ff ff        STU    $FFFF
bf95: ff ff ff        STU    $FFFF
bf98: ff ff ff        STU    $FFFF
bf9b: ff ff ff        STU    $FFFF
bf9e: ff ff ff        STU    $FFFF
bfa1: ff ff ff        STU    $FFFF
bfa4: ff ff ff        STU    $FFFF
bfa7: ff ff ff        STU    $FFFF
bfaa: ff ff ff        STU    $FFFF
bfad: ff ff ff        STU    $FFFF
bfb0: ff ff ff        STU    $FFFF
bfb3: ff ff ff        STU    $FFFF
bfb6: ff ff ff        STU    $FFFF
bfb9: ff ff ff        STU    $FFFF
bfbc: ff ff ff        STU    $FFFF
bfbf: ff ff ff        STU    $FFFF
bfc2: ff ff ff        STU    $FFFF
bfc5: ff ff ff        STU    $FFFF
bfc8: ff ff ff        STU    $FFFF
bfcb: ff ff ff        STU    $FFFF
bfce: ff ff ff        STU    $FFFF
bfd1: ff ff ff        STU    $FFFF
bfd4: ff ff ff        STU    $FFFF
bfd7: ff ff ff        STU    $FFFF
bfda: ff ff ff        STU    $FFFF
bfdd: ff ff ff        STU    $FFFF
bfe0: ff ff ff        STU    $FFFF
bfe3: ff ff ff        STU    $FFFF
bfe6: ff ff ff        STU    $FFFF
bfe9: ff ff ff        STU    $FFFF
bfec: ff ff ff        STU    $FFFF
bfef: ff ff ff        STU    $FFFF
bff2: ff ff ff        STU    $FFFF
bff5: ff ff ff        STU    $FFFF
bff8: ff ff ff        STU    $FFFF
bffb: ff ff ff        STU    $FFFF
bffe: ff ff 33        STU    $FF33
;
; #####################################################################################
; PAGE 3 — Diagnostics and self-test (file offset $C000-$FFFF, CPU $4000-$7FFF)
; NOTE: disassembler alignment issue — $C000 byte ($33) is consumed by the 3-byte
; instruction at $BFFE. Actual page 3 data begins at file offset $C000.
; #####################################################################################
;
c001: df 48           STU    <$48
c003: 50              NEGB
c004: 38 39           XANDCC #$39
c006: 30 34           LEAX   -$C,Y
c008: 41              NEGA
c009: 20 46           BRA    $C051
c00b: 69 72           ROL    -$E,S
c00d: 6d 77           TST    -$9,S
c00f: 61 72           NEG    -$E,S
c011: 65 20           LSR    $0,Y
c013: 43              COMA
c014: 6f 70           CLR    -$10,S
c016: 79 72 69        ROL    $7269
c019: 67 68           ASR    $8,S
c01b: 74 20 31        LSR    $2031
c01e: 39              RTS
c01f: 38 37           XANDCC #$37
c021: 20 48           BRA    $C06B
c023: 65 77           LSR    -$9,S
c025: 6c 65           INC    $5,S
c027: 74 74 20        LSR    $7420
c02a: 50              NEGB
c02b: 61 63           NEG    $3,S
c02d: 6b 61           XDEC   $1,S
c02f: 72 64 20        XNC    $6420
c032: 43              COMA
c033: 6f 72           CLR    -$E,S
c035: 70 2e 2a        NEG    $2E2A
c038: 2a 2a           BPL    $C064
c03a: 2a 20           BPL    $C05C
c03c: 20 44           BRA    $C082
c03e: 69 61           ROL    $1,S
c040: 67 6e           ASR    $E,S
c042: 6f 73           CLR    -$D,S
c044: 74 69 63        LSR    $6963
c047: 20 54           BRA    $C09D
c049: 65 73           LSR    -$D,S
c04b: 74 73 20        LSR    $7320
c04e: 61 6e           NEG    $E,S
c050: 64 20           LSR    $0,Y
c052: 43              COMA
c053: 68 65           ASL    $5,S
c055: 63 6b           COM    $B,S
c057: 73 20 20        COM    $2020
c05a: 20 2a           BRA    $C086
c05c: 2a 2a           BPL    $C088
c05e: 2a 00           BPL    $C060
c060: 01 20           NEG    <$20
c062: 4b              XDECA
c063: 65 79           LSR    -$7,S
c065: 62 6f           XNC    $F,S
c067: 61 72           NEG    -$E,S
c069: 64 20           LSR    $0,Y
c06b: 43              COMA
c06c: 68 65           ASL    $5,S
c06e: 63 6b           COM    $B,S
c070: 20 20           BRA    $C092
c072: 20 00           BRA    $C074
c074: 04 20           LSR    <$20
c076: 45              LSRA
c077: 78 69 74        ASL    $6974
c07a: 20 20           BRA    $C09C
c07c: 20 20           BRA    $C09E
c07e: 20 20           BRA    $C0A0
c080: 20 20           BRA    $C0A2
c082: 20 20           BRA    $C0A4
c084: 20 20           BRA    $C0A6
c086: 20 00           BRA    $C088
c088: 01 20           NEG    <$20
c08a: 52              XNCB
c08b: 4f              CLRA
c08c: 4d              TSTA
c08d: 20 43           BRA    $C0D2
c08f: 68 65           ASL    $5,S
c091: 63 6b           COM    $B,S
c093: 73 20 20        COM    $2020
c096: 20 20           BRA    $C0B8
c098: 20 20           BRA    $C0BA
c09a: 20 00           BRA    $C09C
c09c: 03 20           COM    <$20
c09e: 52              XNCB
c09f: 41              NEGA
c0a0: 4d              TSTA
c0a1: 20 43           BRA    $C0E6
c0a3: 68 65           ASL    $5,S
c0a5: 63 6b           COM    $B,S
c0a7: 20 20           BRA    $C0C9
c0a9: 20 20           BRA    $C0CB
c0ab: 20 20           BRA    $C0CD
c0ad: 20 20           BRA    $C0CF
c0af: 00 02           NEG    <$02
c0b1: 20 4c           BRA    $C0FF
c0b3: 43              COMA
c0b4: 44              LSRA
c0b5: 20 43           BRA    $C0FA
c0b7: 68 65           ASL    $5,S
c0b9: 63 6b           COM    $B,S
c0bb: 20 20           BRA    $C0DD
c0bd: 20 20           BRA    $C0DF
c0bf: 20 20           BRA    $C0E1
c0c1: 20 20           BRA    $C0E3
c0c3: 00 04           NEG    <$04
c0c5: 20 45           BRA    $C10C
c0c7: 78 69 74        ASL    $6974
c0ca: 20 20           BRA    $C0EC
c0cc: 20 20           BRA    $C0EE
c0ce: 20 20           BRA    $C0F0
c0d0: 20 20           BRA    $C0F2
c0d2: 20 20           BRA    $C0F4
c0d4: 20 20           BRA    $C0F6
c0d6: 20 00           BRA    $C0D8
c0d8: 01 20           NEG    <$20
c0da: 50              NEGB
c0db: 4c              INCA
c0dc: 4c              INCA
c0dd: 20 43           BRA    $C122
c0df: 68 65           ASL    $5,S
c0e1: 63 6b           COM    $B,S
c0e3: 20 20           BRA    $C105
c0e5: 20 20           BRA    $C107
c0e7: 20 20           BRA    $C109
c0e9: 20 20           BRA    $C10B
c0eb: 00 03           NEG    <$03
c0ed: 20 4d           BRA    $C13C
c0ef: 65 6d           LSR    $D,S
c0f1: 6f 72           CLR    -$E,S
c0f3: 79 20 4d        ROL    $204D
c0f6: 61 70           NEG    -$10,S
c0f8: 20 41           BRA    $C13B
c0fa: 63 63           COM    $3,S
c0fc: 65 73           LSR    -$D,S
c0fe: 73 00 02        COM    >$0002
c101: 20 20           BRA    $C123
c103: 20 20           BRA    $C125
c105: 20 20           BRA    $C127
c107: 20 20           BRA    $C129
c109: 20 20           BRA    $C12B
c10b: 20 20           BRA    $C12D
c10d: 20 20           BRA    $C12F
c10f: 20 20           BRA    $C131
c111: 20 20           BRA    $C133
c113: 00 04           NEG    <$04
c115: 20 45           BRA    $C15C
c117: 78 69 74        ASL    $6974
c11a: 20 20           BRA    $C13C
c11c: 20 20           BRA    $C13E
c11e: 20 20           BRA    $C140
c120: 20 20           BRA    $C142
c122: 20 20           BRA    $C144
c124: 20 20           BRA    $C146
c126: 20 00           BRA    $C128
c128: 01 20           NEG    <$20
c12a: 4d              TSTA
c12b: 61 6e           NEG    $E,S
c12d: 75 61 6c        LSR    $616C
c130: 20 4d           BRA    $C17F
c132: 65 6d           LSR    $D,S
c134: 6f 72           CLR    -$E,S
c136: 79 20 20        ROL    $2020
c139: 20 20           BRA    $C15B
c13b: 00 03           NEG    <$03
c13d: 20 4d           BRA    $C18C
c13f: 61 6e           NEG    $E,S
c141: 75 61 6c        LSR    $616C
c144: 20 43           BRA    $C189
c146: 6f 77           CLR    -$9,S
c148: 43              COMA
c149: 68 69           ASL    $9,S
c14b: 70 20 20        NEG    $2020
c14e: 20 00           BRA    $C150
c150: 02 20           XNC    <$20
c152: 20 20           BRA    $C174
c154: 20 20           BRA    $C176
c156: 20 20           BRA    $C178
c158: 20 20           BRA    $C17A
c15a: 20 20           BRA    $C17C
c15c: 20 20           BRA    $C17E
c15e: 20 20           BRA    $C180
c160: 20 20           BRA    $C182
c162: 20 00           BRA    $C164
c164: 04 20           LSR    <$20
c166: 45              LSRA
c167: 78 69 74        ASL    $6974
c16a: 20 20           BRA    $C18C
c16c: 20 20           BRA    $C18E
c16e: 20 20           BRA    $C190
c170: 20 20           BRA    $C192
c172: 20 20           BRA    $C194
c174: 20 20           BRA    $C196
c176: 20 02           BRA    $C17A
c178: 40              NEGA
c179: 37 4b           PULU   CC,A,DP,S
c17b: 1e c2           EXG    inv,Y
c17d: 39              RTS
c17e: c2 39           SBCB   #$39
c180: 8b 4c           ADDA   #$4C
c182: 40              NEGA
c183: 87 47           XSTA   #$47
c185: 1c 4e           ANDCC  #$4E
c187: f7 4d cf        STB    $4DCF
c18a: 8b 4c           ADDA   #$4C
c18c: 40              NEGA
c18d: d7 53           STB    <$53
c18f: 0f c2           CLR    <$C2
c191: 39              RTS
c192: 52              XNCB
c193: 98 8b           EORA   <$8B
c195: 4c              INCA
c196: 41              NEGA
c197: 27 61           BEQ    $C1FA
c199: bb c2 39        ADDA   $C239
c19c: 5e              XCLRB
c19d: c8 8b           EORB   #$8B
c19f: 4c              INCA
c1a0: 44              LSRA
c1a1: 69 61           ROL    $1,S
c1a3: 67 6e           ASR    $E,S
c1a5: 6f 73           CLR    -$D,S
c1a7: 74 69 63        LSR    $6963
c1aa: 73 20 2d        COM    $202D
c1ad: 20 20           BRA    $C1CF
c1af: 20 20           BRA    $C1D1
c1b1: 20 20           BRA    $C1D3
c1b3: 20 20           BRA    $C1D5
c1b5: 20 20           BRA    $C1D7
c1b7: 20 20           BRA    $C1D9
c1b9: 20 20           BRA    $C1DB
c1bb: 20 20           BRA    $C1DD
c1bd: 20 20           BRA    $C1DF
c1bf: 20 20           BRA    $C1E1
c1c1: 20 20           BRA    $C1E3
c1c3: 20 20           BRA    $C1E5
c1c5: 20 20           BRA    $C1E7
c1c7: 20 4d           BRA    $C216
c1c9: 61 6e           NEG    $E,S
c1cb: 75 61 6c        LSR    $616C
c1ce: 20 4b           BRA    $C21B
c1d0: 65 79           LSR    -$7,S
c1d2: 62 6f           XNC    $F,S
c1d4: 61 72           NEG    -$E,S
c1d6: 64 20           LSR    $0,Y
c1d8: 43              COMA
c1d9: 68 65           ASL    $5,S
c1db: 63 6b           COM    $B,S
c1dd: 20 20           BRA    $C1FF
c1df: 20 20           BRA    $C201
c1e1: 20 50           BRA    $C233
c1e3: 72 65 73        XNC    $6573
c1e6: 73 20 22        COM    $2022
c1e9: 00 04           NEG    <$04
c1eb: 22 20           BHI    $C20D
c1ed: 74 77 69        LSR    $7769
c1f0: 63 65           COM    $5,S
c1f2: 20 74           BRA    $C268
c1f4: 6f 20           CLR    $0,Y
c1f6: 65 78           LSR    -$8,S
c1f8: 69 74           ROL    -$C,S
c1fa: 20 74           BRA    $C270
c1fc: 68 69           ASL    $9,S
c1fe: 73 20 63        COM    $2063
c201: 68 65           ASL    $5,S
c203: 63 6b           COM    $B,S
c205: 2e 20           BGT    $C227
c207: 20 20           BRA    $C229
c209: 20 20           BRA    $C22B
c20b: 20 20           BRA    $C22D
c20d: 20 20           BRA    $C22F
c20f: 20 20           BRA    $C231
c211: 20 20           BRA    $C233
c213: 6b 65           XDEC   $5,S
c215: 79 20 77        ROL    $2077
c218: 61 73           NEG    -$D,S
c21a: 20 70           BRA    $C28C
c21c: 72 65 73        XNC    $6573
c21f: 73 65 64        COM    $6564
c222: 2e 20           BGT    $C244
c224: 45              LSRA
c225: 78 69 74        ASL    $6974
c228: 3d              MUL
c229: 20 22           BRA    $C24D
c22b: 00 04           NEG    <$04
c22d: 22 20           BHI    $C24F
c22f: 78 20 32        ASL    $2032
c232: 4d              TSTA
c233: 61 69           NEG    $9,S
c235: 6e 20           JMP    $0,Y
c237: 52              XNCB
c238: 4f              CLRA
c239: 4d              TSTA
c23a: 20 20           BRA    $C25C
c23c: 20 20           BRA    $C25E
c23e: 20 20           BRA    $C260
c240: 20 20           BRA    $C262
c242: 4f              CLRA
c243: 70 74 20        NEG    $7420
c246: 52              XNCB
c247: 4f              CLRA
c248: 4d              TSTA
c249: 20 70           BRA    $C2BB
c24b: 61 67           NEG    $7,S
c24d: 65 20           LSR    $0,Y
c24f: 20 20           BRA    $C271
c251: 20 40           BRA    $C293
c253: 20 20           BRA    $C275
c255: 20 20           BRA    $C277
c257: 20 48           BRA    $C2A1
c259: 20 28           BRA    $C283
c25b: 20 20           BRA    $C27D
c25d: 20 20           BRA    $C27F
c25f: 20 48           BRA    $C2A9
c261: 29 20           BVS    $C283
c263: 00 04           NEG    <$04
c265: 20 45           BRA    $C2AC
c267: 78 69 74        ASL    $6974
c26a: 43              COMA
c26b: 68 65           ASL    $5,S
c26d: 63 6b           COM    $B,S
c26f: 73 75 6d        COM    $756D
c272: 20 20           BRA    $C294
c274: 20 48           BRA    $C2BE
c276: 20 73           BRA    $C2EB
c278: 2f 62           BLE    $C2DC
c27a: 20 20           BRA    $C29C
c27c: 20 48           BRA    $C2C6
c27e: 20 20           BRA    $C2A0
c280: 50              NEGB
c281: 61 73           NEG    -$D,S
c283: 73 20 20        COM    $2020
c286: 20 20           BRA    $C2A8
c288: 20 20           BRA    $C2AA
c28a: 46              RORA
c28b: 61 69           NEG    $9,S
c28d: 6c 20           INC    $0,Y
c28f: 20 20           BRA    $C2B1
c291: 20 52           BRA    $C2E5
c293: 65 70           LSR    -$10,S
c295: 65 74           LSR    -$C,S
c297: 69 74           ROL    -$C,S
c299: 69 76           ROL    -$A,S
c29b: 65 20           LSR    $0,Y
c29d: 52              XNCB
c29e: 61 6d           NEG    $D,S
c2a0: 20 43           BRA    $C2E5
c2a2: 68 65           ASL    $5,S
c2a4: 63 6b           COM    $B,S
c2a6: 20 20           BRA    $C2C8
c2a8: 20 20           BRA    $C2CA
c2aa: 20 20           BRA    $C2CC
c2ac: 50              NEGB
c2ad: 61 73           NEG    -$D,S
c2af: 73 65 64        COM    $6564
c2b2: 20 20           BRA    $C2D4
c2b4: 20 20           BRA    $C2D6
c2b6: 20 20           BRA    $C2D8
c2b8: 20 74           BRA    $C32E
c2ba: 69 6d           ROL    $D,S
c2bc: 65 73           LSR    -$D,S
c2be: 2c 20           BGE    $C2E0
c2c0: 66 61           ROR    $1,S
c2c2: 69 6c           ROL    $C,S
c2c4: 65 64           LSR    $4,S
c2c6: 20 20           BRA    $C2E8
c2c8: 20 20           BRA    $C2EA
c2ca: 20 20           BRA    $C2EC
c2cc: 20 00           BRA    $C2CE
c2ce: 04 20           LSR    <$20
c2d0: 45              LSRA
c2d1: 78 69 74        ASL    $6974
c2d4: 4c              INCA
c2d5: 43              COMA
c2d6: 44              LSRA
c2d7: 20 44           BRA    $C31D
c2d9: 69 73           ROL    -$D,S
c2db: 70 6c 61        NEG    $6C61
c2de: 79 20 43        ROL    $2043
c2e1: 68 65           ASL    $5,S
c2e3: 63 6b           COM    $B,S
c2e5: 20 20           BRA    $C307
c2e7: 00 04           NEG    <$04
c2e9: 20 45           BRA    $C330
c2eb: 78 69 74        ASL    $6974
c2ee: 4d              TSTA
c2ef: 65 6d           LSR    $D,S
c2f1: 6f 72           CLR    -$E,S
c2f3: 79 20 4d        ROL    $204D
c2f6: 61 70           NEG    -$10,S
c2f8: 20 41           BRA    $C33B
c2fa: 63 63           COM    $3,S
c2fc: 65 73           LSR    -$D,S
c2fe: 73 20 20        COM    $2020
c301: 00 04           NEG    <$04
c303: 20 45           BRA    $C34A
c305: 78 69 74        ASL    $6974
c308: 45              LSRA
c309: 6c 65           INC    $5,S
c30b: 6d 65           TST    $5,S
c30d: 6e 74           JMP    -$C,S
c30f: 20 20           BRA    $C331
c311: 20 20           BRA    $C333
c313: 20 20           BRA    $C335
c315: 20 20           BRA    $C337
c317: 20 20           BRA    $C339
c319: 20 41           BRA    $C35C
c31b: 64 64           LSR    $4,S
c31d: 72 65 73        XNC    $6573
c320: 73 20 20        COM    $2020
c323: 20 20           BRA    $C345
c325: 20 48           BRA    $C36F
c327: 20 44           BRA    $C36D
c329: 61 74           NEG    -$C,S
c32b: 61 20           NEG    $0,Y
c32d: 20 20           BRA    $C34F
c32f: 48              ASLA
c330: 50              NEGB
c331: 4c              INCA
c332: 4c              INCA
c333: 20 43           BRA    $C378
c335: 68 65           ASL    $5,S
c337: 63 6b           COM    $B,S
c339: 20 2d           BRA    $C368
c33b: 20 55           BRA    $C392
c33d: 73 65 20        COM    $6520
c340: 55              LSRB
c341: 50              NEGB
c342: 2f 44           BLE    $C388
c344: 4f              CLRA
c345: 57              ASRB
c346: 4e              XCLRA
c347: 20 6b           BRA    $C3B4
c349: 65 79           LSR    -$7,S
c34b: 73 2e 20        COM    $2E20
c34e: 20 20           BRA    $C370
c350: 20 00           BRA    $C352
c352: 04 20           LSR    <$20
c354: 45              LSRA
c355: 78 69 74        ASL    $6974
c358: 4c              INCA
c359: 6f 6f           CLR    $F,S
c35b: 70 20 69        NEG    $2069
c35e: 73 20 75        COM    $2075
c361: 6e 6c           JMP    $C,S
c363: 6f 63           CLR    $3,S
c365: 6b 65           XDEC   $5,S
c367: 64 20           LSR    $0,Y
c369: 77 69 74        ASR    $6974
c36c: 68 20           ASL    $0,Y
c36e: 61 20           NEG    $0,Y
c370: 76 61 6c        ROR    $616C
c373: 75 65 20        LSR    $6520
c376: 6f 66           CLR    $6,S
c378: 20 31           BRA    $C3AB
c37a: 32 33           LEAS   -$D,Y
c37c: 34 35           PSHS   Y,X,B,CC
c37e: 36 2e           PSHU   Y,DP,D
c380: 5f              CLRB
c381: 5e              XCLRB
c382: 10 00 00        NEG    <$00
c385: 64 4d           LSR    $D,U
c387: 61 6e           NEG    $E,S
c389: 75 61 6c        LSR    $616C
c38c: 20 43           BRA    $C3D1
c38e: 6f 77           CLR    -$9,S
c390: 43              COMA
c391: 68 69           ASL    $9,S
c393: 70 20 43        NEG    $2043
c396: 68 65           ASL    $5,S
c398: 63 6b           COM    $B,S
c39a: 20 20           BRA    $C3BC
c39c: 20 20           BRA    $C3BE
c39e: 20 20           BRA    $C3C0
c3a0: 00 03           NEG    <$03
c3a2: 20 52           BRA    $C3F6
c3a4: 61 6d           NEG    $D,S
c3a6: 2f 52           BLE    $C3FA
c3a8: 65 67           LSR    $7,S
c3aa: 20 20           BRA    $C3CC
c3ac: 52              XNCB
c3ad: 65 67           LSR    $7,S
c3af: 69 73           ROL    -$D,S
c3b1: 74 65 72        LSR    $6572
c3b4: 3d              MUL
c3b5: 20 20           BRA    $C3D7
c3b7: 20 20           BRA    $C3D9
c3b9: 20 44           BRA    $C3FF
c3bb: 61 74           NEG    -$C,S
c3bd: 61 3d           NEG    -$3,Y
c3bf: 20 20           BRA    $C3E1
c3c1: 20 20           BRA    $C3E3
c3c3: 20 20           BRA    $C3E5
c3c5: 20 20           BRA    $C3E7
c3c7: 20 20           BRA    $C3E9
c3c9: 20 20           BRA    $C3EB
c3cb: 20 20           BRA    $C3ED
c3cd: 20 20           BRA    $C3EF
c3cf: 20 20           BRA    $C3F1
c3d1: 20 20           BRA    $C3F3
c3d3: 20 52           BRA    $C427
c3d5: 61 6d           NEG    $D,S
c3d7: 20 41           BRA    $C41A
c3d9: 64 64           LSR    $4,S
c3db: 72 3d 20        XNC    $3D20
c3de: 20 20           BRA    $C400
c3e0: 20 20           BRA    $C402
c3e2: 44              LSRA
c3e3: 61 74           NEG    -$C,S
c3e5: 61 3d           NEG    -$3,Y
c3e7: 20 20           BRA    $C409
c3e9: 20 20           BRA    $C40B
c3eb: 20 20           BRA    $C40D
c3ed: 20 20           BRA    $C40F
c3ef: 20 20           BRA    $C411
c3f1: 20 20           BRA    $C413
c3f3: 20 20           BRA    $C415
c3f5: 20 20           BRA    $C417
c3f7: 20 20           BRA    $C419
c3f9: 20 20           BRA    $C41B
c3fb: 20 4d           BRA    $C44A
c3fd: 61 6e           NEG    $E,S
c3ff: 75 61 6c        LSR    $616C
c402: 20 4d           BRA    $C451
c404: 65 6d           LSR    $D,S
c406: 6f 72           CLR    -$E,S
c408: 79 20 52        ROL    $2052
c40b: 65 61           LSR    $1,S
c40d: 64 2f           LSR    $F,Y
c40f: 57              ASRB
c410: 72 69 74        XNC    $6974
c413: 65 20           LSR    $0,Y
c415: 20 00           BRA    $C417
c417: 01 20           NEG    <$20
c419: 41              NEGA
c41a: 64 64           LSR    $4,S
c41c: 72 65 73        XNC    $6573
c41f: 73 20 20        COM    $2020
c422: 00 02           NEG    <$02
c424: 20 44           BRA    $C46A
c426: 61 74           NEG    -$C,S
c428: 61 20           NEG    $0,Y
c42a: 20 20           BRA    $C44C
c42c: 20 20           BRA    $C44E
c42e: 20 20           BRA    $C450
c430: 20 20           BRA    $C452
c432: 20 20           BRA    $C454
c434: 20 20           BRA    $C456
c436: 20 00           BRA    $C438
c438: 04 20           LSR    <$20
c43a: 45              LSRA
c43b: 78 69 74        ASL    $6974
c43e: 00 01           NEG    <$01
c440: 20 41           BRA    $C483
c442: 64 64           LSR    $4,S
c444: 72 3d 20        XNC    $3D20
c447: 20 20           BRA    $C469
c449: 20 20           BRA    $C46B
c44b: 20 20           BRA    $C46D
c44d: 00 02           NEG    <$02
c44f: 20 44           BRA    $C495
c451: 61 74           NEG    -$C,S
c453: 61 3d           NEG    -$3,Y
c455: 20 20           BRA    $C477
c457: 20 20           BRA    $C479
c459: 20 22           BRA    $C47D
c45b: 20 22           BRA    $C47F
c45d: 20 20           BRA    $C47F
c45f: 00 04           NEG    <$04
c461: 20 45           BRA    $C4A8
c463: 78 69 74        ASL    $6974
c466: 30 39           LEAX   -$7,Y
c468: 32 34           LEAS   -$C,Y
c46a: 34 38           PSHS   Y,X,DP
; ---------------------------------------------------------------------------
; First C-compiled function (page 3).  Diagnostic test routines, keyboard
; test, display test, hardware verification, self-test sequencer.
; Pattern: LDD <rom-addr>; LBSR $7D50 allocates stack frame (= CPU $FD50).
; ---------------------------------------------------------------------------
c46c: fc 4c 60        LDD    $4C60
c46f: 17 b8 de        LBSR   $7D50
c472: be 24 dc        LDX    $24DC
c475: 8c 00 20        CMPX   #$0020
c478: 10 27 02 7b     LBEQ   $C6F7
c47c: f6 3f 80        LDB    $3F80
c47f: c1 00           CMPB   #$00
c481: 10 26 00 2d     LBNE   $C4B2
c485: ce 42 32        LDU    #$4232
c488: c6 10           LDB    #$10
c48a: 1d              SEX
c48b: 1f 02           TFR    D,Y
c48d: 5f              CLRB
c48e: 1d              SEX
c48f: 1f 01           TFR    D,X
c491: cc 00 06        LDD    #$0006
c494: 34 76           PSHS   U,Y,X,D
c496: 17 94 51        LBSR   $58EA
c499: 32 68           LEAS   $8,S
c49b: fc 3f 82        LDD    $3F82
c49e: ed 67           STD    $7,S
c4a0: c6 20           LDB    #$20
c4a2: e7 62           STB    $2,S
c4a4: be 3f 82        LDX    $3F82
c4a7: 30 89 80 00     LEAX   -$8000,X
c4ab: af 65           STX    $5,S
c4ad: 6f 64           CLR    $4,S
c4af: 16 00 85        LBRA   $C537
c4b2: ce 42 42        LDU    #$4242
c4b5: c6 10           LDB    #$10
c4b7: 1d              SEX
c4b8: 1f 02           TFR    D,Y
c4ba: 5f              CLRB
c4bb: 1d              SEX
c4bc: 1f 01           TFR    D,X
c4be: cc 00 06        LDD    #$0006
c4c1: 34 76           PSHS   U,Y,X,D
c4c3: 17 94 24        LBSR   $58EA
c4c6: 32 68           LEAS   $8,S
c4c8: b6 3f 80        LDA    $3F80
c4cb: c6 01           LDB    #$01
c4cd: 17 b8 bf        LBSR   $7D8F
c4d0: ce 24 14        LDU    #$2414
c4d3: 1f 02           TFR    D,Y
c4d5: 8e 00 04        LDX    #$0004
c4d8: 34 70           PSHS   U,Y,X
c4da: 17 84 f4        LBSR   $49D1
c4dd: 32 66           LEAS   $6,S
c4df: ce 24 16        LDU    #$2416
c4e2: c6 01           LDB    #$01
c4e4: 1d              SEX
c4e5: 1f 02           TFR    D,Y
c4e7: c6 0d           LDB    #$0D
c4e9: 1d              SEX
c4ea: 1f 01           TFR    D,X
c4ec: cc 00 06        LDD    #$0006
c4ef: 34 76           PSHS   U,Y,X,D
c4f1: 17 93 f6        LBSR   $58EA
c4f4: 32 68           LEAS   $8,S
c4f6: fc 3f 84        LDD    $3F84
c4f9: ed 67           STD    $7,S
c4fb: f6 3f 80        LDB    $3F80
c4fe: c1 04           CMPB   #$04
c500: 10 23 00 07     LBLS   $C50B
c504: c6 31           LDB    #$31
c506: e7 62           STB    $2,S
c508: 16 00 04        LBRA   $C50F
c50b: c6 20           LDB    #$20
c50d: e7 62           STB    $2,S
c50f: b6 3f 80        LDA    $3F80
c512: c6 01           LDB    #$01
c514: 17 b8 78        LBSR   $7D8F
c517: 8e 40 00        LDX    #$4000
c51a: 17 ba 25        LBSR   $7F42
c51d: be 3f 84        LDX    $3F84
c520: ed 69           STD    $9,S
c522: cc 40 00        LDD    #$4000
c525: 17 b9 31        LBSR   $7E59
c528: 30 8b           LEAX   D,X
c52a: 1f 10           TFR    X,D
c52c: e3 69           ADDD   $9,S
c52e: ed 65           STD    $5,S
c530: f6 3f 80        LDB    $3F80
c533: c0 01           SUBB   #$01
c535: e7 64           STB    $4,S
c537: 33 62           LEAU   $2,S
c539: c6 01           LDB    #$01
c53b: 1d              SEX
c53c: 1f 02           TFR    D,Y
c53e: c6 19           LDB    #$19
c540: 1d              SEX
c541: 1f 01           TFR    D,X
c543: cc 00 06        LDD    #$0006
c546: 34 76           PSHS   U,Y,X,D
c548: 17 93 9f        LBSR   $58EA
c54b: 32 68           LEAS   $8,S
c54d: ce 24 14        LDU    #$2414
c550: 10 ae 65        LDY    $5,S
c553: 8e 00 04        LDX    #$0004
c556: 34 70           PSHS   U,Y,X
c558: 17 86 ae        LBSR   $4C09
c55b: 32 66           LEAS   $6,S
c55d: ce 24 14        LDU    #$2414
c560: c6 04           LDB    #$04
c562: 1d              SEX
c563: 1f 02           TFR    D,Y
c565: c6 1a           LDB    #$1A
c567: 1d              SEX
c568: 1f 01           TFR    D,X
c56a: cc 00 06        LDD    #$0006
c56d: 34 76           PSHS   U,Y,X,D
c56f: 17 93 78        LBSR   $58EA
c572: 32 68           LEAS   $8,S
c574: ce 24 14        LDU    #$2414
c577: 10 ae 67        LDY    $7,S
c57a: 8e 00 04        LDX    #$0004
c57d: 34 70           PSHS   U,Y,X
c57f: 17 86 87        LBSR   $4C09
c582: 32 66           LEAS   $6,S
c584: ce 24 14        LDU    #$2414
c587: c6 04           LDB    #$04
c589: 1d              SEX
c58a: 1f 02           TFR    D,Y
c58c: c6 12           LDB    #$12
c58e: 1d              SEX
c58f: 1f 01           TFR    D,X
c591: cc 00 06        LDD    #$0006
c594: 34 76           PSHS   U,Y,X,D
c596: 17 93 51        LBSR   $58EA
c599: 32 68           LEAS   $8,S
c59b: 8e 3f 86        LDX    #$3F86
c59e: f6 3f 80        LDB    $3F80
c5a1: 3a              ABX
c5a2: ce 24 14        LDU    #$2414
c5a5: e6 84           LDB    ,X
c5a7: 4f              CLRA
c5a8: 1f 02           TFR    D,Y
c5aa: 8e 00 04        LDX    #$0004
c5ad: 34 70           PSHS   U,Y,X
c5af: 17 85 f4        LBSR   $4BA6
c5b2: 32 66           LEAS   $6,S
c5b4: ce 24 14        LDU    #$2414
c5b7: c6 02           LDB    #$02
c5b9: 1d              SEX
c5ba: 1f 02           TFR    D,Y
c5bc: c6 49           LDB    #$49
c5be: 1d              SEX
c5bf: 1f 01           TFR    D,X
c5c1: cc 00 06        LDD    #$0006
c5c4: 34 76           PSHS   U,Y,X,D
c5c6: 17 93 21        LBSR   $58EA
c5c9: 32 68           LEAS   $8,S
c5cb: 8e 3f 86        LDX    #$3F86
c5ce: f6 3f 80        LDB    $3F80
c5d1: 3a              ABX
c5d2: ce 24 80        LDU    #$2480
c5d5: f6 3f 80        LDB    $3F80
c5d8: 4f              CLRA
c5d9: 33 cb           LEAU   D,U
c5db: a6 84           LDA    ,X
c5dd: e6 c4           LDB    ,U
c5df: 17 b7 ad        LBSR   $7D8F
c5e2: ed 69           STD    $9,S
c5e4: e6 64           LDB    $4,S
c5e6: 4f              CLRA
c5e7: e3 69           ADDD   $9,S
c5e9: e7 63           STB    $3,S
c5eb: ce 24 14        LDU    #$2414
c5ee: e6 63           LDB    $3,S
c5f0: 4f              CLRA
c5f1: 1f 02           TFR    D,Y
c5f3: 8e 00 04        LDX    #$0004
c5f6: 34 70           PSHS   U,Y,X
c5f8: 17 85 ab        LBSR   $4BA6
c5fb: 32 66           LEAS   $6,S
c5fd: ce 24 14        LDU    #$2414
c600: c6 02           LDB    #$02
c602: 1d              SEX
c603: 1f 02           TFR    D,Y
c605: c6 51           LDB    #$51
c607: 1d              SEX
c608: 1f 01           TFR    D,X
c60a: cc 00 06        LDD    #$0006
c60d: 34 76           PSHS   U,Y,X,D
c60f: 17 92 d8        LBSR   $58EA
c612: 32 68           LEAS   $8,S
c614: 8e 24 80        LDX    #$2480
c617: f6 3f 80        LDB    $3F80
c61a: 3a              ABX
c61b: e6 64           LDB    $4,S
c61d: e1 84           CMPB   ,X
c61f: 10 26 00 10     LBNE   $C633
c623: 8e 3f 8f        LDX    #$3F8F
c626: f6 3f 80        LDB    $3F80
c629: 3a              ABX
c62a: e6 84           LDB    ,X
c62c: cb 01           ADDB   #$01
c62e: e7 84           STB    ,X
c630: 16 00 0d        LBRA   $C640
c633: 8e 3f 98        LDX    #$3F98
c636: f6 3f 80        LDB    $3F80
c639: 3a              ABX
c63a: e6 84           LDB    ,X
c63c: cb 01           ADDB   #$01
c63e: e7 84           STB    ,X
c640: 8e 3f 8f        LDX    #$3F8F
c643: f6 3f 80        LDB    $3F80
c646: 3a              ABX
c647: ce 24 14        LDU    #$2414
c64a: e6 84           LDB    ,X
c64c: 4f              CLRA
c64d: 1f 02           TFR    D,Y
c64f: 8e 00 04        LDX    #$0004
c652: 34 70           PSHS   U,Y,X
c654: 17 83 7a        LBSR   $49D1
c657: 32 66           LEAS   $6,S
c659: ce 24 14        LDU    #$2414
c65c: c6 02           LDB    #$02
c65e: 1d              SEX
c65f: 1f 02           TFR    D,Y
c661: 8e 00 04        LDX    #$0004
c664: 34 70           PSHS   U,Y,X
c666: 17 86 96        LBSR   $4CFF
c669: 32 66           LEAS   $6,S
c66b: ce 24 14        LDU    #$2414
c66e: c6 03           LDB    #$03
c670: 1d              SEX
c671: 1f 02           TFR    D,Y
c673: c6 5b           LDB    #$5B
c675: 1d              SEX
c676: 1f 01           TFR    D,X
c678: cc 00 06        LDD    #$0006
c67b: 34 76           PSHS   U,Y,X,D
c67d: 17 92 6a        LBSR   $58EA
c680: 32 68           LEAS   $8,S
c682: 8e 3f 98        LDX    #$3F98
c685: f6 3f 80        LDB    $3F80
c688: 3a              ABX
c689: ce 24 14        LDU    #$2414
c68c: e6 84           LDB    ,X
c68e: 4f              CLRA
c68f: 1f 02           TFR    D,Y
c691: 8e 00 04        LDX    #$0004
c694: 34 70           PSHS   U,Y,X
c696: 17 83 38        LBSR   $49D1
c699: 32 66           LEAS   $6,S
c69b: ce 24 14        LDU    #$2414
c69e: c6 02           LDB    #$02
c6a0: 1d              SEX
c6a1: 1f 02           TFR    D,Y
c6a3: 8e 00 04        LDX    #$0004
c6a6: 34 70           PSHS   U,Y,X
c6a8: 17 86 54        LBSR   $4CFF
c6ab: 32 66           LEAS   $6,S
c6ad: ce 24 14        LDU    #$2414
c6b0: c6 03           LDB    #$03
c6b2: 1d              SEX
c6b3: 1f 02           TFR    D,Y
c6b5: c6 65           LDB    #$65
c6b7: 1d              SEX
c6b8: 1f 01           TFR    D,X
c6ba: cc 00 06        LDD    #$0006
c6bd: 34 76           PSHS   U,Y,X,D
c6bf: 17 92 28        LBSR   $58EA
c6c2: 32 68           LEAS   $8,S
c6c4: f6 3f 80        LDB    $3F80
c6c7: f1 3f 81        CMPB   $3F81
c6ca: 10 26 00 06     LBNE   $C6D4
c6ce: 7f 3f 80        CLR    $3F80
c6d1: 16 00 08        LBRA   $C6DC
c6d4: f6 3f 80        LDB    $3F80
c6d7: cb 01           ADDB   #$01
c6d9: f7 3f 80        STB    $3F80
c6dc: ce 00 00        LDU    #$0000
c6df: 34 40           PSHS   U
c6e1: 17 95 c5        LBSR   $5CA9
c6e4: 32 62           LEAS   $2,S
c6e6: ce 05 dc        LDU    #$05DC
c6e9: 10 8e 00 02     LDY    #$0002
c6ed: 34 60           PSHS   U,Y
c6ef: 17 8f 7e        LBSR   $5670
c6f2: 32 64           LEAS   $4,S
c6f4: 16 fd 7b        LBRA   $C472
c6f7: fc 22 02        LDD    $2202
c6fa: 84 ff           ANDA   #$FF
c6fc: c4 fb           ANDB   #$FB
c6fe: fd 22 02        STD    $2202
c701: fc 22 04        LDD    $2204
c704: 84 ff           ANDA   #$FF
c706: c4 fd           ANDB   #$FD
c708: fd 22 04        STD    $2204
c70b: ce 00 03        LDU    #$0003
c70e: 10 8e 00 02     LDY    #$0002
c712: 34 60           PSHS   U,Y
c714: 17 43 b9        LBSR   $0AD0
c717: 32 64           LEAS   $4,S
c719: 32 6b           LEAS   $B,S
c71b: 39              RTS
c71c: fc 4c 62        LDD    $4C62
c71f: 17 b6 2e        LBSR   $7D50
c722: ce 42 32        LDU    #$4232
c725: c6 10           LDB    #$10
c727: 1d              SEX
c728: 1f 02           TFR    D,Y
c72a: 5f              CLRB
c72b: 1d              SEX
c72c: 1f 01           TFR    D,X
c72e: cc 00 06        LDD    #$0006
c731: 34 76           PSHS   U,Y,X,D
c733: 17 91 b4        LBSR   $58EA
c736: 32 68           LEAS   $8,S
c738: ce 42 52        LDU    #$4252
c73b: c6 28           LDB    #$28
c73d: 1d              SEX
c73e: 1f 02           TFR    D,Y
c740: c6 10           LDB    #$10
c742: 1d              SEX
c743: 1f 01           TFR    D,X
c745: cc 00 06        LDD    #$0006
c748: 34 76           PSHS   U,Y,X,D
c74a: 17 91 9d        LBSR   $58EA
c74d: 32 68           LEAS   $8,S
c74f: ce 42 6a        LDU    #$426A
c752: c6 28           LDB    #$28
c754: 1d              SEX
c755: 1f 02           TFR    D,Y
c757: c6 40           LDB    #$40
c759: 1d              SEX
c75a: 1f 01           TFR    D,X
c75c: cc 00 06        LDD    #$0006
c75f: 34 76           PSHS   U,Y,X,D
c761: 17 91 86        LBSR   $58EA
c764: 32 68           LEAS   $8,S
c766: cc ea 14        LDD    #$EA14
c769: fd 3f 82        STD    $3F82
c76c: f6 ea 14        LDB    $EA14
c76f: f7 3f 86        STB    $3F86
c772: 8e 40 00        LDX    #$4000
c775: 30 01           LEAX   $1,X
c777: bf 3f 84        STX    $3F84
c77a: ce 40 02        LDU    #$4002
c77d: 5f              CLRB
c77e: 1d              SEX
c77f: 1f 02           TFR    D,Y
c781: 8e 00 04        LDX    #$0004
c784: 34 70           PSHS   U,Y,X
c786: 17 7a 5a        LBSR   $41E3
c789: 32 66           LEAS   $6,S
c78b: f7 3f 81        STB    $3F81
c78e: c6 01           LDB    #$01
c790: e7 62           STB    $2,S
c792: e6 62           LDB    $2,S
c794: f1 3f 81        CMPB   $3F81
c797: 10 22 00 2c     LBHI   $C7C7
c79b: 8e 3f 86        LDX    #$3F86
c79e: e6 62           LDB    $2,S
c7a0: 3a              ABX
c7a1: a6 62           LDA    $2,S
c7a3: c6 01           LDB    #$01
c7a5: 17 b5 e7        LBSR   $7D8F
c7a8: ed 63           STD    $3,S
c7aa: af 65           STX    $5,S
c7ac: ce 40 01        LDU    #$4001
c7af: 10 ae 63        LDY    $3,S
c7b2: 8e 00 04        LDX    #$0004
c7b5: 34 70           PSHS   U,Y,X
c7b7: 17 7a 29        LBSR   $41E3
c7ba: 32 66           LEAS   $6,S
c7bc: e7 f8 05        STB    [$05,S]
c7bf: e6 62           LDB    $2,S
c7c1: cb 01           ADDB   #$01
c7c3: e7 62           STB    $2,S
c7c5: 20 cb           BRA    $C792
c7c7: 6f 62           CLR    $2,S
c7c9: e6 62           LDB    $2,S
c7cb: c1 0a           CMPB   #$0A
c7cd: 10 24 00 18     LBCC   $C7E9
c7d1: 8e 3f 8f        LDX    #$3F8F
c7d4: e6 62           LDB    $2,S
c7d6: 3a              ABX
c7d7: 6f 84           CLR    ,X
c7d9: 8e 3f 98        LDX    #$3F98
c7dc: e6 62           LDB    $2,S
c7de: 3a              ABX
c7df: 6f 84           CLR    ,X
c7e1: e6 62           LDB    $2,S
c7e3: cb 01           ADDB   #$01
c7e5: e7 62           STB    $2,S
c7e7: 20 e0           BRA    $C7C9
c7e9: 7f 3f 80        CLR    $3F80
c7ec: ce 00 00        LDU    #$0000
c7ef: 34 40           PSHS   U
c7f1: 17 94 b5        LBSR   $5CA9
c7f4: 32 62           LEAS   $2,S
c7f6: ce 00 00        LDU    #$0000
c7f9: 34 40           PSHS   U
c7fb: 17 fc 6e        LBSR   $C46C
c7fe: 32 62           LEAS   $2,S
c800: 32 67           LEAS   $7,S
c802: 39              RTS
c803: fc 4d cb        LDD    $4DCB
c806: 17 b5 47        LBSR   $7D50
c809: ce 00 00        LDU    #$0000
c80c: 34 40           PSHS   U
c80e: 17 8e b7        LBSR   $56C8
c811: 32 62           LEAS   $2,S
c813: be 3f a1        LDX    $3FA1
c816: 8c 00 20        CMPX   #$0020
c819: 10 26 00 0d     LBNE   $C82A
c81d: be 24 dc        LDX    $24DC
c820: 8c 00 20        CMPX   #$0020
c823: 10 26 00 03     LBNE   $C82A
c827: 16 00 03        LBRA   $C82D
c82a: 16 00 1b        LBRA   $C848
c82d: fc 22 02        LDD    $2202
c830: 84 ff           ANDA   #$FF
c832: c4 fb           ANDB   #$FB
c834: fd 22 02        STD    $2202
c837: ce 00 03        LDU    #$0003
c83a: 10 8e 00 02     LDY    #$0002
c83e: 34 60           PSHS   U,Y
c840: 17 42 8d        LBSR   $0AD0
c843: 32 64           LEAS   $4,S
c845: 16 02 d3        LBRA   $CB1B
c848: fc 24 dc        LDD    $24DC
c84b: fd 3f a1        STD    $3FA1
c84e: be 24 dc        LDX    $24DC
c851: 16 01 d8        LBRA   $CA2C
c854: cc 4c 64        LDD    #$4C64
c857: ed 62           STD    $2,S
c859: 6f 64           CLR    $4,S
c85b: 16 02 4f        LBRA   $CAAD
c85e: cc 4c 6d        LDD    #$4C6D
c861: ed 62           STD    $2,S
c863: c6 20           LDB    #$20
c865: e7 64           STB    $4,S
c867: 16 02 43        LBRA   $CAAD
c86a: cc 4c 76        LDD    #$4C76
c86d: ed 62           STD    $2,S
c86f: c6 01           LDB    #$01
c871: e7 64           STB    $4,S
c873: 16 02 37        LBRA   $CAAD
c876: cc 4c 7f        LDD    #$4C7F
c879: ed 62           STD    $2,S
c87b: c6 0d           LDB    #$0D
c87d: e7 64           STB    $4,S
c87f: 16 02 2b        LBRA   $CAAD
c882: cc 4c 88        LDD    #$4C88
c885: ed 62           STD    $2,S
c887: c6 0e           LDB    #$0E
c889: e7 64           STB    $4,S
c88b: 16 02 1f        LBRA   $CAAD
c88e: cc 4c 91        LDD    #$4C91
c891: ed 62           STD    $2,S
c893: c6 05           LDB    #$05
c895: e7 64           STB    $4,S
c897: 16 02 13        LBRA   $CAAD
c89a: cc 4c 9a        LDD    #$4C9A
c89d: ed 62           STD    $2,S
c89f: c6 04           LDB    #$04
c8a1: e7 64           STB    $4,S
c8a3: 16 02 07        LBRA   $CAAD
c8a6: cc 4c a3        LDD    #$4CA3
c8a9: ed 62           STD    $2,S
c8ab: c6 17           LDB    #$17
c8ad: e7 64           STB    $4,S
c8af: 16 01 fb        LBRA   $CAAD
c8b2: cc 4c ac        LDD    #$4CAC
c8b5: ed 62           STD    $2,S
c8b7: c6 0a           LDB    #$0A
c8b9: e7 64           STB    $4,S
c8bb: 16 01 ef        LBRA   $CAAD
c8be: cc 4c b5        LDD    #$4CB5
c8c1: ed 62           STD    $2,S
c8c3: c6 1c           LDB    #$1C
c8c5: e7 64           STB    $4,S
c8c7: 16 01 e3        LBRA   $CAAD
c8ca: cc 4c be        LDD    #$4CBE
c8cd: ed 62           STD    $2,S
c8cf: c6 13           LDB    #$13
c8d1: e7 64           STB    $4,S
c8d3: 16 01 d7        LBRA   $CAAD
c8d6: cc 4c c7        LDD    #$4CC7
c8d9: ed 62           STD    $2,S
c8db: c6 0f           LDB    #$0F
c8dd: e7 64           STB    $4,S
c8df: 16 01 cb        LBRA   $CAAD
c8e2: cc 4c d0        LDD    #$4CD0
c8e5: ed 62           STD    $2,S
c8e7: c6 06           LDB    #$06
c8e9: e7 64           STB    $4,S
c8eb: 16 01 bf        LBRA   $CAAD
c8ee: cc 4c d9        LDD    #$4CD9
c8f1: ed 62           STD    $2,S
c8f3: c6 18           LDB    #$18
c8f5: e7 64           STB    $4,S
c8f7: 16 01 b3        LBRA   $CAAD
c8fa: cc 4c e2        LDD    #$4CE2
c8fd: ed 62           STD    $2,S
c8ff: c6 0b           LDB    #$0B
c901: e7 64           STB    $4,S
c903: 16 01 a7        LBRA   $CAAD
c906: cc 4c eb        LDD    #$4CEB
c909: ed 62           STD    $2,S
c90b: c6 1d           LDB    #$1D
c90d: e7 64           STB    $4,S
c90f: 16 01 9b        LBRA   $CAAD
c912: cc 4c f4        LDD    #$4CF4
c915: ed 62           STD    $2,S
c917: c6 14           LDB    #$14
c919: e7 64           STB    $4,S
c91b: 16 01 8f        LBRA   $CAAD
c91e: cc 4c fd        LDD    #$4CFD
c921: ed 62           STD    $2,S
c923: c6 10           LDB    #$10
c925: e7 64           STB    $4,S
c927: 16 01 83        LBRA   $CAAD
c92a: cc 4d 06        LDD    #$4D06
c92d: ed 62           STD    $2,S
c92f: c6 07           LDB    #$07
c931: e7 64           STB    $4,S
c933: 16 01 77        LBRA   $CAAD
c936: cc 4d 0f        LDD    #$4D0F
c939: ed 62           STD    $2,S
c93b: c6 1a           LDB    #$1A
c93d: e7 64           STB    $4,S
c93f: 16 01 6b        LBRA   $CAAD
c942: cc 4d 18        LDD    #$4D18
c945: ed 62           STD    $2,S
c947: c6 02           LDB    #$02
c949: e7 64           STB    $4,S
c94b: 16 01 5f        LBRA   $CAAD
c94e: cc 4d 21        LDD    #$4D21
c951: ed 62           STD    $2,S
c953: c6 1e           LDB    #$1E
c955: e7 64           STB    $4,S
c957: 16 01 53        LBRA   $CAAD
c95a: cc 4d 2a        LDD    #$4D2A
c95d: ed 62           STD    $2,S
c95f: c6 15           LDB    #$15
c961: e7 64           STB    $4,S
c963: 16 01 47        LBRA   $CAAD
c966: cc 4d 33        LDD    #$4D33
c969: ed 62           STD    $2,S
c96b: c6 11           LDB    #$11
c96d: e7 64           STB    $4,S
c96f: 16 01 3b        LBRA   $CAAD
c972: cc 4d 3c        LDD    #$4D3C
c975: ed 62           STD    $2,S
c977: c6 08           LDB    #$08
c979: e7 64           STB    $4,S
c97b: 16 01 2f        LBRA   $CAAD
c97e: cc 4d 45        LDD    #$4D45
c981: ed 62           STD    $2,S
c983: c6 19           LDB    #$19
c985: e7 64           STB    $4,S
c987: 16 01 23        LBRA   $CAAD
c98a: cc 4d 4e        LDD    #$4D4E
c98d: ed 62           STD    $2,S
c98f: c6 03           LDB    #$03
c991: e7 64           STB    $4,S
c993: 16 01 17        LBRA   $CAAD
c996: cc 4d 57        LDD    #$4D57
c999: ed 62           STD    $2,S
c99b: c6 1f           LDB    #$1F
c99d: e7 64           STB    $4,S
c99f: 16 01 0b        LBRA   $CAAD
c9a2: cc 4d 60        LDD    #$4D60
c9a5: ed 62           STD    $2,S
c9a7: c6 16           LDB    #$16
c9a9: e7 64           STB    $4,S
c9ab: 16 00 ff        LBRA   $CAAD
c9ae: cc 4d 69        LDD    #$4D69
c9b1: ed 62           STD    $2,S
c9b3: c6 12           LDB    #$12
c9b5: e7 64           STB    $4,S
c9b7: 16 00 f3        LBRA   $CAAD
c9ba: cc 4d 72        LDD    #$4D72
c9bd: ed 62           STD    $2,S
c9bf: c6 09           LDB    #$09
c9c1: e7 64           STB    $4,S
c9c3: 16 00 e7        LBRA   $CAAD
c9c6: cc 4d 7b        LDD    #$4D7B
c9c9: ed 62           STD    $2,S
c9cb: c6 1b           LDB    #$1B
c9cd: e7 64           STB    $4,S
c9cf: 16 00 db        LBRA   $CAAD
c9d2: cc 4d 84        LDD    #$4D84
c9d5: ed 62           STD    $2,S
c9d7: c6 0c           LDB    #$0C
c9d9: e7 64           STB    $4,S
c9db: 16 00 cf        LBRA   $CAAD
c9de: cc 4d 8d        LDD    #$4D8D
c9e1: ed 62           STD    $2,S
c9e3: c6 21           LDB    #$21
c9e5: e7 64           STB    $4,S
c9e7: 16 00 c3        LBRA   $CAAD
c9ea: cc 4d 96        LDD    #$4D96
c9ed: ed 62           STD    $2,S
c9ef: c6 22           LDB    #$22
c9f1: e7 64           STB    $4,S
c9f3: 16 00 b7        LBRA   $CAAD
c9f6: cc 4d 9f        LDD    #$4D9F
c9f9: ed 62           STD    $2,S
c9fb: c6 23           LDB    #$23
c9fd: e7 64           STB    $4,S
c9ff: 16 00 ab        LBRA   $CAAD
ca02: cc 4d a8        LDD    #$4DA8
ca05: ed 62           STD    $2,S
ca07: c6 24           LDB    #$24
ca09: e7 64           STB    $4,S
ca0b: 16 00 9f        LBRA   $CAAD
ca0e: cc 4d b1        LDD    #$4DB1
ca11: ed 62           STD    $2,S
ca13: 6f 64           CLR    $4,S
ca15: 16 00 95        LBRA   $CAAD
ca18: cc 4d ba        LDD    #$4DBA
ca1b: ed 62           STD    $2,S
ca1d: 6f 64           CLR    $4,S
ca1f: 16 00 8b        LBRA   $CAAD
ca22: cc 4d c3        LDD    #$4DC3
ca25: ed 62           STD    $2,S
ca27: 6f 64           CLR    $4,S
ca29: 16 00 81        LBRA   $CAAD
ca2c: 8c 00 00        CMPX   #$0000
ca2f: 2d f1           BLT    $CA22
ca31: 8c 00 36        CMPX   #$0036
ca34: 2e ec           BGT    $CA22
ca36: 1f 10           TFR    X,D
ca38: 8e 4a 3f        LDX    #$4A3F
ca3b: 58              ASLB
ca3c: 49              ROLA
ca3d: 6e 9b           JMP    [D,X]
ca3f: 48              ASLA
ca40: 54              LSRB
ca41: 48              ASLA
ca42: 5e              XCLRB
ca43: 48              ASLA
ca44: 6a 48           DEC    $8,U
ca46: 76 48 82        ROR    $4882
ca49: 48              ASLA
ca4a: 8e 48 9a        LDX    #$489A
ca4d: 48              ASLA
ca4e: a6 48           LDA    $8,U
ca50: b2 48 be        SBCA   $48BE
ca53: 48              ASLA
ca54: ca 48           ORB    #$48
ca56: d6 48           LDB    <$48
ca58: e2 48           SBCB   $8,U
ca5a: ee 48           LDU    $8,U
ca5c: fa 49 06        ORB    $4906
ca5f: 49              ROLA
ca60: 12              NOP
ca61: 49              ROLA
ca62: 1e 49           EXG    S,B
ca64: 2a 49           BPL    $CAAF
ca66: 36 49           PSHU   S,DP,CC
ca68: 42              XNCA
ca69: 49              ROLA
ca6a: 4e              XCLRA
ca6b: 49              ROLA
ca6c: 5a              DECB
ca6d: 49              ROLA
ca6e: 66 49           ROR    $9,U
ca70: 72 49 7e        XNC    $497E
ca73: 49              ROLA
ca74: 8a 49           ORA    #$49
ca76: 96 49           LDA    <$49
ca78: a2 49           SBCA   $9,U
ca7a: ae 49           LDX    $9,U
ca7c: ba 49 c6        ORA    $49C6
ca7f: 49              ROLA
ca80: d2 49           SBCB   <$49
ca82: de 49           LDU    <$49
ca84: ea 49           ORB    $9,U
ca86: f6 4a 02        LDB    $4A02
ca89: 48              ASLA
ca8a: 9a 48           ORA    <$48
ca8c: 76 48 5e        ROR    $485E
ca8f: 48              ASLA
ca90: 8e 48 6a        LDX    #$486A
ca93: 48              ASLA
ca94: 82 48           SBCA   #$48
ca96: ee 49           LDU    $9,U
ca98: 42              XNCA
ca99: 49              ROLA
ca9a: 7e 48 fa        JMP    $48FA
ca9d: 49              ROLA
ca9e: 36 49           PSHU   S,DP,CC
caa0: c6 49           LDB    #$49
caa2: 8a 48           ORA    #$48
caa4: b2 49 d2        SBCA   $49D2
caa7: 49              ROLA
caa8: 96 4a           LDA    <$4A
caaa: 0e 4a           JMP    <$4A
caac: 18              X18
caad: e6 64           LDB    $4,S
caaf: 4f              CLRA
cab0: f3 3f a3        ADDD   $3FA3
cab3: fd 3f a3        STD    $3FA3
cab6: ce 42 0a        LDU    #$420A
cab9: c6 28           LDB    #$28
cabb: 1d              SEX
cabc: 1f 02           TFR    D,Y
cabe: c6 40           LDB    #$40
cac0: 1d              SEX
cac1: 1f 01           TFR    D,X
cac3: cc 00 06        LDD    #$0006
cac6: 34 76           PSHS   U,Y,X,D
cac8: 17 8e 1f        LBSR   $58EA
cacb: 32 68           LEAS   $8,S
cacd: ee 62           LDU    $2,S
cacf: c6 08           LDB    #$08
cad1: 1d              SEX
cad2: 1f 02           TFR    D,Y
cad4: c6 40           LDB    #$40
cad6: 1d              SEX
cad7: 1f 01           TFR    D,X
cad9: cc 00 06        LDD    #$0006
cadc: 34 76           PSHS   U,Y,X,D
cade: 17 8e 09        LBSR   $58EA
cae1: 32 68           LEAS   $8,S
cae3: ce 22 85        LDU    #$2285
cae6: 10 be 3f a3     LDY    $3FA3
caea: 8e 00 04        LDX    #$0004
caed: 34 70           PSHS   U,Y,X
caef: 17 7e 20        LBSR   $4912
caf2: 32 66           LEAS   $6,S
caf4: ce 22 86        LDU    #$2286
caf7: c6 04           LDB    #$04
caf9: 1d              SEX
cafa: 1f 02           TFR    D,Y
cafc: c6 24           LDB    #$24
cafe: 1d              SEX
caff: 1f 01           TFR    D,X
cb01: cc 00 06        LDD    #$0006
cb04: 34 76           PSHS   U,Y,X,D
cb06: 17 8d e1        LBSR   $58EA
cb09: 32 68           LEAS   $8,S
cb0b: c6 32           LDB    #$32
cb0d: 1d              SEX
cb0e: 1f 03           TFR    D,U
cb10: 10 8e 00 02     LDY    #$0002
cb14: 34 60           PSHS   U,Y
cb16: 17 8b 57        LBSR   $5670
cb19: 32 64           LEAS   $4,S
cb1b: 32 65           LEAS   $5,S
cb1d: 39              RTS
cb1e: fc 4d cd        LDD    $4DCD
cb21: 17 b2 2c        LBSR   $7D50
cb24: ce 41 a0        LDU    #$41A0
cb27: c6 28           LDB    #$28
cb29: 1d              SEX
cb2a: 1f 02           TFR    D,Y
cb2c: 5f              CLRB
cb2d: 1d              SEX
cb2e: 1f 01           TFR    D,X
cb30: cc 00 06        LDD    #$0006
cb33: 34 76           PSHS   U,Y,X,D
cb35: 17 8d b2        LBSR   $58EA
cb38: 32 68           LEAS   $8,S
cb3a: ce 41 c8        LDU    #$41C8
cb3d: c6 1a           LDB    #$1A
cb3f: 1d              SEX
cb40: 1f 02           TFR    D,Y
cb42: c6 0e           LDB    #$0E
cb44: 1d              SEX
cb45: 1f 01           TFR    D,X
cb47: cc 00 06        LDD    #$0006
cb4a: 34 76           PSHS   U,Y,X,D
cb4c: 17 8d 9b        LBSR   $58EA
cb4f: 32 68           LEAS   $8,S
cb51: ce 41 e2        LDU    #$41E2
cb54: c6 28           LDB    #$28
cb56: 1d              SEX
cb57: 1f 02           TFR    D,Y
cb59: c6 40           LDB    #$40
cb5b: 1d              SEX
cb5c: 1f 01           TFR    D,X
cb5e: cc 00 06        LDD    #$0006
cb61: 34 76           PSHS   U,Y,X,D
cb63: 17 8d 84        LBSR   $58EA
cb66: 32 68           LEAS   $8,S
cb68: 5f              CLRB
cb69: 4f              CLRA
cb6a: fd 3f a1        STD    $3FA1
cb6d: 5f              CLRB
cb6e: 4f              CLRA
cb6f: fd 3f a3        STD    $3FA3
cb72: cc 48 03        LDD    #$4803
cb75: fd 23 b0        STD    $23B0
cb78: fc 22 02        LDD    $2202
cb7b: 8a 00           ORA    #$00
cb7d: ca 04           ORB    #$04
cb7f: fd 22 02        STD    $2202
cb82: 32 62           LEAS   $2,S
cb84: 39              RTS
cb85: fc 4d cd        LDD    $4DCD
cb88: 17 b1 c5        LBSR   $7D50
cb8b: be 22 17        LDX    $2217
cb8e: 16 00 5d        LBRA   $CBEE
cb91: ce 44 66        LDU    #$4466
cb94: 10 8e 23 9a     LDY    #$239A
cb98: c6 06           LDB    #$06
cb9a: 1d              SEX
cb9b: 1f 01           TFR    D,X
cb9d: cc 00 06        LDD    #$0006
cba0: 34 76           PSHS   U,Y,X,D
cba2: 17 76 9d        LBSR   $4242
cba5: 32 68           LEAS   $8,S
cba7: c1 00           CMPB   #$00
cba9: 10 27 00 03     LBEQ   $CBB0
cbad: 16 00 69        LBRA   $CC19
cbb0: fc 22 04        LDD    $2204
cbb3: 8a 01           ORA    #$01
cbb5: ca 00           ORB    #$00
cbb7: fd 22 04        STD    $2204
cbba: 16 00 66        LBRA   $CC23
cbbd: c6 62           LDB    #$62
cbbf: 1d              SEX
cbc0: 1f 03           TFR    D,U
cbc2: 10 8e 00 01     LDY    #$0001
cbc6: c6 62           LDB    #$62
cbc8: 1d              SEX
cbc9: 1f 01           TFR    D,X
cbcb: c6 06           LDB    #$06
cbcd: 1d              SEX
cbce: 34 76           PSHS   U,Y,X,D
cbd0: ce 00 01        LDU    #$0001
cbd3: 10 8e 00 0a     LDY    #$000A
cbd7: 34 60           PSHS   U,Y
cbd9: 17 60 59        LBSR   $2C35
cbdc: 32 6c           LEAS   $C,S
cbde: 16 00 38        LBRA   $CC19
cbe1: ce 00 00        LDU    #$0000
cbe4: 34 40           PSHS   U
cbe6: 17 3e 46        LBSR   $0A2F
cbe9: 32 62           LEAS   $2,S
cbeb: 16 00 2b        LBRA   $CC19
cbee: 8c 00 13        CMPX   #$0013
cbf1: 27 ee           BEQ    $CBE1
cbf3: 8c 00 14        CMPX   #$0014
cbf6: 27 e9           BEQ    $CBE1
cbf8: 8c 00 15        CMPX   #$0015
cbfb: 27 e4           BEQ    $CBE1
cbfd: 8c 00 16        CMPX   #$0016
cc00: 27 df           BEQ    $CBE1
cc02: 8c 00 17        CMPX   #$0017
cc05: 27 da           BEQ    $CBE1
cc07: 8c 00 18        CMPX   #$0018
cc0a: 27 d5           BEQ    $CBE1
cc0c: 8c 00 23        CMPX   #$0023
cc0f: 27 80           BEQ    $CB91
cc11: 8c 00 38        CMPX   #$0038
cc14: 27 a7           BEQ    $CBBD
cc16: 16 00 00        LBRA   $CC19
cc19: fc 22 04        LDD    $2204
cc1c: 84 fe           ANDA   #$FE
cc1e: c4 ff           ANDB   #$FF
cc20: fd 22 04        STD    $2204
cc23: 32 62           LEAS   $2,S
cc25: 39              RTS
cc26: fc 4d cd        LDD    $4DCD
cc29: 17 b1 24        LBSR   $7D50
cc2c: ce 41 78        LDU    #$4178
cc2f: 10 8e 00 02     LDY    #$0002
cc33: 34 60           PSHS   U,Y
cc35: 17 3d d0        LBSR   $0A08
cc38: 32 64           LEAS   $4,S
cc3a: fc 22 04        LDD    $2204
cc3d: 84 01           ANDA   #$01
cc3f: c4 00           ANDB   #$00
cc41: 10 83 00 00     CMPD   #$0000
cc45: 10 27 00 08     LBEQ   $CC51
cc49: f6 22 42        LDB    $2242
cc4c: cb 01           ADDB   #$01
cc4e: f7 22 42        STB    $2242
cc51: cc 4b 85        LDD    #$4B85
cc54: fd 22 0f        STD    $220F
cc57: cc c2 39        LDD    #$C239
cc5a: fd 22 13        STD    $2213
cc5d: 32 62           LEAS   $2,S
cc5f: 39              RTS
cc60: 00 09           NEG    <$09
cc62: 00 05           NEG    <$05
cc64: 20 20           BRA    $CC86
cc66: 4e              XCLRA
cc67: 4f              CLRA
cc68: 4b              XDECA
cc69: 45              LSRA
cc6a: 59              ROLB
cc6b: 20 00           BRA    $CC6D
cc6d: 20 20           BRA    $CC8F
cc6f: 6c 6f           INC    $F,S
cc71: 63 61           COM    $1,S
cc73: 6c 20           INC    $0,Y
cc75: 00 20           NEG    <$20
cc77: 20 20           BRA    $CC99
cc79: 66 31           ROR    -$F,Y
cc7b: 20 20           BRA    $CC9D
cc7d: 20 00           BRA    $CC7F
cc7f: 20 20           BRA    $CCA1
cc81: 70 68 61        NEG    $6861
cc84: 73 65 20        COM    $6520
cc87: 00 77           NEG    <$77
cc89: 61 76           NEG    -$A,S
cc8b: 65 66           LSR    $6,S
cc8d: 6f 72           CLR    -$E,S
cc8f: 6d 00           TST    $0,X
cc91: 20 20           BRA    $CCB3
cc93: 61 6d           NEG    $D,S
cc95: 70 6c 20        NEG    $6C20
cc98: 20 00           BRA    $CC9A
cc9a: 20 20           BRA    $CCBC
cc9c: 66 72           ROR    -$E,S
cc9e: 65 71           LSR    -$F,S
cca0: 20 20           BRA    $CCC2
cca2: 00 20           NEG    <$20
cca4: 73 68 69        COM    $6869
cca7: 66 74           ROR    -$C,S
cca9: 20 20           BRA    $CCCB
ccab: 00 20           NEG    <$20
ccad: 20 20           BRA    $CCCF
ccaf: 66 32           ROR    -$E,Y
ccb1: 20 20           BRA    $CCD3
ccb3: 20 00           BRA    $CCB5
ccb5: 20 20           BRA    $CCD7
ccb7: 20 2d           BRA    $CCE6
ccb9: 20 20           BRA    $CCDB
ccbb: 20 20           BRA    $CCDD
ccbd: 00 20           NEG    <$20
ccbf: 20 20           BRA    $CCE1
ccc1: 37 20           PULU   Y
ccc3: 20 20           BRA    $CCE5
ccc5: 20 00           BRA    $CCC7
ccc7: 20 20           BRA    $CCE9
ccc9: 20 34           BRA    $CCFF
cccb: 20 20           BRA    $CCED
cccd: 20 20           BRA    $CCEF
cccf: 00 20           NEG    <$20
ccd1: 20 20           BRA    $CCF3
ccd3: 31 20           LEAY   $0,Y
ccd5: 20 20           BRA    $CCF7
ccd7: 20 00           BRA    $CCD9
ccd9: 69 6e           ROL    $E,S
ccdb: 63 20           COM    $0,Y
ccdd: 73 65 74        COM    $6574
cce0: 20 00           BRA    $CCE2
cce2: 20 20           BRA    $CD04
cce4: 6c 61           INC    $1,S
cce6: 73 74 20        COM    $7420
cce9: 20 00           BRA    $CCEB
cceb: 20 20           BRA    $CD0D
cced: 20 30           BRA    $CD1F
ccef: 20 20           BRA    $CD11
ccf1: 20 20           BRA    $CD13
ccf3: 00 20           NEG    <$20
ccf5: 20 20           BRA    $CD17
ccf7: 38 20           XANDCC #$20
ccf9: 20 20           BRA    $CD1B
ccfb: 20 00           BRA    $CCFD
ccfd: 20 20           BRA    $CD1F
ccff: 20 35           BRA    $CD36
cd01: 20 20           BRA    $CD23
cd03: 20 20           BRA    $CD25
cd05: 00 20           NEG    <$20
cd07: 20 20           BRA    $CD29
cd09: 32 20           LEAS   $0,Y
cd0b: 20 20           BRA    $CD2D
cd0d: 20 00           BRA    $CD0F
cd0f: 75 70 20        LSR    $7020
cd12: 61 72           NEG    -$E,S
cd14: 72 6f 77        XNC    $6F77
cd17: 00 20           NEG    <$20
cd19: 20 6e           BRA    $CD89
cd1b: 65 78           LSR    -$8,S
cd1d: 74 20 20        LSR    $2020
cd20: 00 20           NEG    <$20
cd22: 20 20           BRA    $CD44
cd24: 2e 20           BGT    $CD46
cd26: 20 20           BRA    $CD48
cd28: 20 00           BRA    $CD2A
cd2a: 20 20           BRA    $CD4C
cd2c: 20 39           BRA    $CD67
cd2e: 20 20           BRA    $CD50
cd30: 20 20           BRA    $CD52
cd32: 00 20           NEG    <$20
cd34: 20 20           BRA    $CD56
cd36: 36 20           PSHU   Y
cd38: 20 20           BRA    $CD5A
cd3a: 20 00           BRA    $CD3C
cd3c: 20 20           BRA    $CD5E
cd3e: 20 33           BRA    $CD73
cd40: 20 20           BRA    $CD62
cd42: 20 20           BRA    $CD64
cd44: 00 64           NEG    <$64
cd46: 6e 20           JMP    $0,Y
cd48: 61 72           NEG    -$E,S
cd4a: 72 6f 77        XNC    $6F77
cd4d: 00 20           NEG    <$20
cd4f: 20 20           BRA    $CD71
cd51: 66 33           ROR    -$D,Y
cd53: 20 20           BRA    $CD75
cd55: 20 00           BRA    $CD57
cd57: 20 20           BRA    $CD79
cd59: 65 6e           LSR    $E,S
cd5b: 74 65 72        LSR    $6572
cd5e: 20 00           BRA    $CD60
cd60: 20 20           BRA    $CD82
cd62: 20 64           BRA    $CDC8
cd64: 65 67           LSR    $7,S
cd66: 20 20           BRA    $CD88
cd68: 00 20           NEG    <$20
cd6a: 20 20           BRA    $CD8C
cd6c: 48              ASLA
cd6d: 7a 20 20        DEC    $2020
cd70: 20 00           BRA    $CD72
cd72: 20 20           BRA    $CD94
cd74: 20 6b           BRA    $CDE1
cd76: 48              ASLA
cd77: 7a 20 20        DEC    $2020
cd7a: 00 62           NEG    <$62
cd7c: 6b 73           XDEC   -$D,S
cd7e: 70 61 63        NEG    $6163
cd81: 65 20           LSR    $0,Y
cd83: 00 20           NEG    <$20
cd85: 20 20           BRA    $CDA7
cd87: 66 34           ROR    -$C,Y
cd89: 20 20           BRA    $CDAB
cd8b: 20 00           BRA    $CD8D
cd8d: 20 53           BRA    $CDE2
cd8f: 50              NEGB
cd90: 41              NEGA
cd91: 52              XNCB
cd92: 45              LSRA
cd93: 30 20           LEAX   $0,Y
cd95: 00 20           NEG    <$20
cd97: 53              COMB
cd98: 50              NEGB
cd99: 41              NEGA
cd9a: 52              XNCB
cd9b: 45              LSRA
cd9c: 31 20           LEAY   $0,Y
cd9e: 00 20           NEG    <$20
cda0: 53              COMB
cda1: 50              NEGB
cda2: 41              NEGA
cda3: 52              XNCB
cda4: 45              LSRA
cda5: 32 20           LEAS   $0,Y
cda7: 00 20           NEG    <$20
cda9: 53              COMB
cdaa: 50              NEGB
cdab: 41              NEGA
cdac: 52              XNCB
cdad: 45              LSRA
cdae: 33 20           LEAU   $0,Y
cdb0: 00 49           NEG    <$49
cdb2: 4e              XCLRA
cdb3: 56              RORB
cdb4: 41              NEGA
cdb5: 4c              INCA
cdb6: 49              ROLA
cdb7: 44              LSRA
cdb8: 20 00           BRA    $CDBA
cdba: 20 44           BRA    $CE00
cdbc: 4f              CLRA
cdbd: 55              LSRB
cdbe: 42              XNCA
cdbf: 4c              INCA
cdc0: 45              LSRA
cdc1: 20 00           BRA    $CDC3
cdc3: 2a 20           BPL    $CDE5
cdc5: 45              LSRA
cdc6: 52              XNCB
cdc7: 52              XNCB
cdc8: 4f              CLRA
cdc9: 52              XNCB
cdca: 20 00           BRA    $CDCC
cdcc: 03 00           COM    <$00
cdce: 00 fc           NEG    <$FC
cdd0: 54              LSRB
cdd1: cb 17           ADDB   #$17
cdd3: af 7b           STX    -$5,S
cdd5: ce 41 a0        LDU    #$41A0
cdd8: c6 28           LDB    #$28
cdda: 1d              SEX
cddb: 1f 02           TFR    D,Y
cddd: 5f              CLRB
cdde: 1d              SEX
cddf: 1f 01           TFR    D,X
cde1: cc 00 06        LDD    #$0006
cde4: 34 76           PSHS   U,Y,X,D
cde6: 17 8b 01        LBSR   $58EA
cde9: 32 68           LEAS   $8,S
cdeb: ce 42 92        LDU    #$4292
cdee: c6 1a           LDB    #$1A
cdf0: 1d              SEX
cdf1: 1f 02           TFR    D,Y
cdf3: c6 0e           LDB    #$0E
cdf5: 1d              SEX
cdf6: 1f 01           TFR    D,X
cdf8: cc 00 06        LDD    #$0006
cdfb: 34 76           PSHS   U,Y,X,D
cdfd: 17 8a ea        LBSR   $58EA
ce00: 32 68           LEAS   $8,S
ce02: ce 42 ac        LDU    #$42AC
ce05: c6 28           LDB    #$28
ce07: 1d              SEX
ce08: 1f 02           TFR    D,Y
ce0a: c6 40           LDB    #$40
ce0c: 1d              SEX
ce0d: 1f 01           TFR    D,X
ce0f: cc 00 06        LDD    #$0006
ce12: 34 76           PSHS   U,Y,X,D
ce14: 17 8a d3        LBSR   $58EA
ce17: 32 68           LEAS   $8,S
ce19: 5f              CLRB
ce1a: 4f              CLRA
ce1b: fd 3f a5        STD    $3FA5
ce1e: 5f              CLRB
ce1f: 4f              CLRA
ce20: fd 3f a7        STD    $3FA7
ce23: be 24 dc        LDX    $24DC
ce26: 8c 00 20        CMPX   #$0020
ce29: 10 27 00 af     LBEQ   $CEDC
ce2d: ce 24 14        LDU    #$2414
ce30: 10 be 3f a5     LDY    $3FA5
ce34: 8e 00 04        LDX    #$0004
ce37: 34 70           PSHS   U,Y,X
ce39: 17 7a d6        LBSR   $4912
ce3c: 32 66           LEAS   $6,S
ce3e: ce 24 14        LDU    #$2414
ce41: c6 04           LDB    #$04
ce43: 1d              SEX
ce44: 1f 02           TFR    D,Y
ce46: 8e 00 04        LDX    #$0004
ce49: 34 70           PSHS   U,Y,X
ce4b: 17 7e b1        LBSR   $4CFF
ce4e: 32 66           LEAS   $6,S
ce50: ce 24 14        LDU    #$2414
ce53: c6 05           LDB    #$05
ce55: 1d              SEX
ce56: 1f 02           TFR    D,Y
ce58: c6 47           LDB    #$47
ce5a: 1d              SEX
ce5b: 1f 01           TFR    D,X
ce5d: cc 00 06        LDD    #$0006
ce60: 34 76           PSHS   U,Y,X,D
ce62: 17 8a 85        LBSR   $58EA
ce65: 32 68           LEAS   $8,S
ce67: ce 24 14        LDU    #$2414
ce6a: 10 be 3f a7     LDY    $3FA7
ce6e: 8e 00 04        LDX    #$0004
ce71: 34 70           PSHS   U,Y,X
ce73: 17 7a 9c        LBSR   $4912
ce76: 32 66           LEAS   $6,S
ce78: ce 24 14        LDU    #$2414
ce7b: c6 04           LDB    #$04
ce7d: 1d              SEX
ce7e: 1f 02           TFR    D,Y
ce80: 8e 00 04        LDX    #$0004
ce83: 34 70           PSHS   U,Y,X
ce85: 17 7e 77        LBSR   $4CFF
ce88: 32 66           LEAS   $6,S
ce8a: ce 24 14        LDU    #$2414
ce8d: c6 05           LDB    #$05
ce8f: 1d              SEX
ce90: 1f 02           TFR    D,Y
ce92: c6 5b           LDB    #$5B
ce94: 1d              SEX
ce95: 1f 01           TFR    D,X
ce97: cc 00 06        LDD    #$0006
ce9a: 34 76           PSHS   U,Y,X,D
ce9c: 17 8a 4b        LBSR   $58EA
ce9f: 32 68           LEAS   $8,S
cea1: ce 00 00        LDU    #$0000
cea4: 34 40           PSHS   U
cea6: 17 8d d9        LBSR   $5C82
cea9: 32 62           LEAS   $2,S
ceab: fc 22 02        LDD    $2202
ceae: 84 40           ANDA   #$40
ceb0: c4 00           ANDB   #$00
ceb2: 10 83 00 00     CMPD   #$0000
ceb6: 10 27 00 16     LBEQ   $CED0
ceba: fc 22 02        LDD    $2202
cebd: 84 bf           ANDA   #$BF
cebf: c4 ff           ANDB   #$FF
cec1: fd 22 02        STD    $2202
cec4: fc 3f a7        LDD    $3FA7
cec7: c3 00 01        ADDD   #$0001
ceca: fd 3f a7        STD    $3FA7
cecd: 16 00 09        LBRA   $CED9
ced0: fc 3f a5        LDD    $3FA5
ced3: c3 00 01        ADDD   #$0001
ced6: fd 3f a5        STD    $3FA5
ced9: 16 ff 47        LBRA   $CE23
cedc: fc 22 04        LDD    $2204
cedf: 84 ff           ANDA   #$FF
cee1: c4 fd           ANDB   #$FD
cee3: fd 22 04        STD    $2204
cee6: ce 00 03        LDU    #$0003
cee9: 10 8e 00 02     LDY    #$0002
ceed: 34 60           PSHS   U,Y
ceef: 17 3b de        LBSR   $0AD0
cef2: 32 64           LEAS   $4,S
cef4: 32 63           LEAS   $3,S
cef6: 39              RTS
cef7: fc 54 cd        LDD    $54CD
cefa: 17 ae 53        LBSR   $7D50
cefd: c6 67           LDB    #$67
ceff: e7 62           STB    $2,S
cf01: c6 01           LDB    #$01
cf03: e7 63           STB    $3,S
cf05: c6 1f           LDB    #$1F
cf07: e7 64           STB    $4,S
cf09: ce ed 11        LDU    #$ED11
cf0c: c6 28           LDB    #$28
cf0e: 1d              SEX
cf0f: 1f 02           TFR    D,Y
cf11: c6 40           LDB    #$40
cf13: 1d              SEX
cf14: 1f 01           TFR    D,X
cf16: cc 00 06        LDD    #$0006
cf19: 34 76           PSHS   U,Y,X,D
cf1b: 17 89 cc        LBSR   $58EA
cf1e: 32 68           LEAS   $8,S
cf20: be 24 dc        LDX    $24DC
cf23: 8c 00 20        CMPX   #$0020
cf26: 10 27 00 af     LBEQ   $CFD9
cf2a: e6 64           LDB    $4,S
cf2c: cb 01           ADDB   #$01
cf2e: e7 64           STB    $4,S
cf30: e6 64           LDB    $4,S
cf32: 4f              CLRA
cf33: 10 83 00 d0     CMPD   #$00D0
cf37: 10 26 00 04     LBNE   $CF3F
cf3b: c6 20           LDB    #$20
cf3d: e7 64           STB    $4,S
cf3f: e6 64           LDB    $4,S
cf41: c1 7f           CMPB   #$7F
cf43: 10 22 00 07     LBHI   $CF4E
cf47: e6 64           LDB    $4,S
cf49: e7 65           STB    $5,S
cf4b: 16 00 04        LBRA   $CF52
cf4e: c6 ff           LDB    #$FF
cf50: e7 65           STB    $5,S
cf52: e6 62           LDB    $2,S
cf54: cb 01           ADDB   #$01
cf56: e7 62           STB    $2,S
cf58: e6 62           LDB    $2,S
cf5a: c1 28           CMPB   #$28
cf5c: 10 26 00 04     LBNE   $CF64
cf60: c6 40           LDB    #$40
cf62: e7 62           STB    $2,S
cf64: e6 62           LDB    $2,S
cf66: c1 68           CMPB   #$68
cf68: 10 26 00 44     LBNE   $CFB0
cf6c: e6 63           LDB    $3,S
cf6e: c1 00           CMPB   #$00
cf70: 10 27 00 36     LBEQ   $CFAA
cf74: ce 41 a0        LDU    #$41A0
cf77: c6 28           LDB    #$28
cf79: 1d              SEX
cf7a: 1f 02           TFR    D,Y
cf7c: 5f              CLRB
cf7d: 1d              SEX
cf7e: 1f 01           TFR    D,X
cf80: cc 00 06        LDD    #$0006
cf83: 34 76           PSHS   U,Y,X,D
cf85: 17 89 62        LBSR   $58EA
cf88: 32 68           LEAS   $8,S
cf8a: ce 42 d4        LDU    #$42D4
cf8d: c6 1a           LDB    #$1A
cf8f: 1d              SEX
cf90: 1f 02           TFR    D,Y
cf92: c6 0e           LDB    #$0E
cf94: 1d              SEX
cf95: 1f 01           TFR    D,X
cf97: cc 00 06        LDD    #$0006
cf9a: 34 76           PSHS   U,Y,X,D
cf9c: 17 89 4b        LBSR   $58EA
cf9f: 32 68           LEAS   $8,S
cfa1: c6 40           LDB    #$40
cfa3: e7 62           STB    $2,S
cfa5: 6f 63           CLR    $3,S
cfa7: 16 00 06        LBRA   $CFB0
cfaa: c6 01           LDB    #$01
cfac: e7 63           STB    $3,S
cfae: 6f 62           CLR    $2,S
cfb0: 33 65           LEAU   $5,S
cfb2: c6 01           LDB    #$01
cfb4: 1d              SEX
cfb5: 1f 02           TFR    D,Y
cfb7: e6 62           LDB    $2,S
cfb9: 4f              CLRA
cfba: 1f 01           TFR    D,X
cfbc: cc 00 06        LDD    #$0006
cfbf: 34 76           PSHS   U,Y,X,D
cfc1: 17 89 26        LBSR   $58EA
cfc4: 32 68           LEAS   $8,S
cfc6: c6 64           LDB    #$64
cfc8: 1d              SEX
cfc9: 1f 03           TFR    D,U
cfcb: 10 8e 00 02     LDY    #$0002
cfcf: 34 60           PSHS   U,Y
cfd1: 17 86 9c        LBSR   $5670
cfd4: 32 64           LEAS   $4,S
cfd6: 16 ff 47        LBRA   $CF20
cfd9: fc 22 04        LDD    $2204
cfdc: 84 ff           ANDA   #$FF
cfde: c4 fd           ANDB   #$FD
cfe0: fd 22 04        STD    $2204
cfe3: ce 00 03        LDU    #$0003
cfe6: 10 8e 00 02     LDY    #$0002
cfea: 34 60           PSHS   U,Y
cfec: 17 3a e1        LBSR   $0AD0
cfef: 32 64           LEAS   $4,S
cff1: 32 66           LEAS   $6,S
cff3: 39              RTS
cff4: fc 55 0d        LDD    $550D
cff7: 17 ad 56        LBSR   $7D50
cffa: c6 01           LDB    #$01
cffc: f7 3f ae        STB    $3FAE
cfff: f6 3f a9        LDB    $3FA9
d002: 16 00 8a        LBRA   $D08F
d005: cc 02 00        LDD    #$0200
d008: fd 3f ab        STD    $3FAB
d00b: cc 54 cf        LDD    #$54CF
d00e: fd 3f af        STD    $3FAF
d011: c6 01           LDB    #$01
d013: f7 3f aa        STB    $3FAA
d016: 16 00 98        LBRA   $D0B1
d019: cc 04 00        LDD    #$0400
d01c: fd 3f ab        STD    $3FAB
d01f: cc 54 d8        LDD    #$54D8
d022: fd 3f af        STD    $3FAF
d025: c6 07           LDB    #$07
d027: f7 3f aa        STB    $3FAA
d02a: 7f 3f ae        CLR    $3FAE
d02d: 16 00 81        LBRA   $D0B1
d030: cc 09 00        LDD    #$0900
d033: fd 3f ab        STD    $3FAB
d036: cc 54 e1        LDD    #$54E1
d039: fd 3f af        STD    $3FAF
d03c: 7f 3f aa        CLR    $3FAA
d03f: 16 00 6f        LBRA   $D0B1
d042: cc 0b 00        LDD    #$0B00
d045: fd 3f ab        STD    $3FAB
d048: cc 54 ea        LDD    #$54EA
d04b: fd 3f af        STD    $3FAF
d04e: 7f 3f aa        CLR    $3FAA
d051: 16 00 5d        LBRA   $D0B1
d054: cc 0c 00        LDD    #$0C00
d057: fd 3f ab        STD    $3FAB
d05a: cc 54 f3        LDD    #$54F3
d05d: fd 3f af        STD    $3FAF
d060: 7f 3f aa        CLR    $3FAA
d063: 16 00 4b        LBRA   $D0B1
d066: cc 0d 00        LDD    #$0D00
d069: fd 3f ab        STD    $3FAB
d06c: cc 54 fc        LDD    #$54FC
d06f: fd 3f af        STD    $3FAF
d072: 7f 3f aa        CLR    $3FAA
d075: 16 00 39        LBRA   $D0B1
d078: cc 10 00        LDD    #$1000
d07b: fd 3f ab        STD    $3FAB
d07e: cc 55 05        LDD    #$5505
d081: fd 3f af        STD    $3FAF
d084: c6 07           LDB    #$07
d086: f7 3f aa        STB    $3FAA
d089: 7f 3f ae        CLR    $3FAE
d08c: 16 00 22        LBRA   $D0B1
d08f: c1 00           CMPB   #$00
d091: 10 25 ff 70     LBCS   $D005
d095: c1 06           CMPB   #$06
d097: 10 22 ff 6a     LBHI   $D005
d09b: 8e 50 a3        LDX    #$50A3
d09e: 4f              CLRA
d09f: 58              ASLB
d0a0: 49              ROLA
d0a1: 6e 9b           JMP    [D,X]
d0a3: 50              NEGB
d0a4: 05 50           LSR    <$50
d0a6: 19              DAA
d0a7: 50              NEGB
d0a8: 30 50           LEAX   -$10,U
d0aa: 42              XNCA
d0ab: 50              NEGB
d0ac: 54              LSRB
d0ad: 50              NEGB
d0ae: 66 50           ROR    -$10,U
d0b0: 78 7f 3f        ASL    $7F3F
d0b3: ad fe           JSR    [W,S]
d0b5: 3f              SWI
d0b6: af c6           STX    A,U
d0b8: 08 1d           ASL    <$1D
d0ba: 1f 02           TFR    D,Y
d0bc: c6 48           LDB    #$48
d0be: 1d              SEX
d0bf: 1f 01           TFR    D,X
d0c1: cc 00 06        LDD    #$0006
d0c4: 34 76           PSHS   U,Y,X,D
d0c6: 17 88 21        LBSR   $58EA
d0c9: 32 68           LEAS   $8,S
d0cb: 32 62           LEAS   $2,S
d0cd: 39              RTS
d0ce: fc 55 11        LDD    $5511
d0d1: 17 ac 7c        LBSR   $7D50
d0d4: cc 55 0f        LDD    #$550F
d0d7: ed 65           STD    $5,S
d0d9: be 22 17        LDX    $2217
d0dc: 16 00 e2        LBRA   $D1C1
d0df: 16 01 12        LBRA   $D1F4
d0e2: ce 00 03        LDU    #$0003
d0e5: 10 8e 00 02     LDY    #$0002
d0e9: 34 60           PSHS   U,Y
d0eb: 17 39 e2        LBSR   $0AD0
d0ee: 32 64           LEAS   $4,S
d0f0: 16 01 a2        LBRA   $D295
d0f3: f6 3f ad        LDB    $3FAD
d0f6: f1 3f aa        CMPB   $3FAA
d0f9: 10 27 00 08     LBEQ   $D105
d0fd: f6 3f ad        LDB    $3FAD
d100: cb 01           ADDB   #$01
d102: f7 3f ad        STB    $3FAD
d105: 16 00 ec        LBRA   $D1F4
d108: f6 3f ad        LDB    $3FAD
d10b: c1 00           CMPB   #$00
d10d: 10 27 00 08     LBEQ   $D119
d111: f6 3f ad        LDB    $3FAD
d114: c0 01           SUBB   #$01
d116: f7 3f ad        STB    $3FAD
d119: 16 00 d8        LBRA   $D1F4
d11c: f6 3f a9        LDB    $3FA9
d11f: c1 06           CMPB   #$06
d121: 10 27 00 08     LBEQ   $D12D
d125: f6 3f a9        LDB    $3FA9
d128: cb 01           ADDB   #$01
d12a: f7 3f a9        STB    $3FA9
d12d: ce 00 00        LDU    #$0000
d130: 34 40           PSHS   U
d132: 17 fe bf        LBSR   $CFF4
d135: 32 62           LEAS   $2,S
d137: 16 00 ba        LBRA   $D1F4
d13a: f6 3f a9        LDB    $3FA9
d13d: c1 00           CMPB   #$00
d13f: 10 27 00 08     LBEQ   $D14B
d143: f6 3f a9        LDB    $3FA9
d146: c0 01           SUBB   #$01
d148: f7 3f a9        STB    $3FA9
d14b: ce 00 00        LDU    #$0000
d14e: 34 40           PSHS   U
d150: 17 fe a1        LBSR   $CFF4
d153: 32 62           LEAS   $2,S
d155: 16 00 9c        LBRA   $D1F4
d158: c6 02           LDB    #$02
d15a: 1d              SEX
d15b: 1f 03           TFR    D,U
d15d: 10 8e 00 02     LDY    #$0002
d161: 34 60           PSHS   U,Y
d163: 17 60 bd        LBSR   $3223
d166: 32 64           LEAS   $4,S
d168: c1 00           CMPB   #$00
d16a: 10 27 00 35     LBEQ   $D1A3
d16e: ce 23 9a        LDU    #$239A
d171: 10 8e 00 02     LDY    #$0002
d175: 34 60           PSHS   U,Y
d177: 17 7a d9        LBSR   $4C53
d17a: 32 64           LEAS   $4,S
d17c: e7 62           STB    $2,S
d17e: be 3f ab        LDX    $3FAB
d181: f6 3f ad        LDB    $3FAD
d184: 3a              ABX
d185: e6 62           LDB    $2,S
d187: e7 84           STB    ,X
d189: f6 3f a9        LDB    $3FA9
d18c: c1 04           CMPB   #$04
d18e: 10 27 00 0c     LBEQ   $D19E
d192: f6 3f a9        LDB    $3FA9
d195: c1 05           CMPB   #$05
d197: 10 27 00 03     LBEQ   $D19E
d19b: 16 00 05        LBRA   $D1A3
d19e: e6 62           LDB    $2,S
d1a0: f7 08 00        STB    $0800
d1a3: ce 01 2c        LDU    #$012C
d1a6: 10 8e 00 02     LDY    #$0002
d1aa: 34 60           PSHS   U,Y
d1ac: 17 84 c1        LBSR   $5670
d1af: 32 64           LEAS   $4,S
d1b1: 16 00 40        LBRA   $D1F4
d1b4: ce 00 00        LDU    #$0000
d1b7: 34 40           PSHS   U
d1b9: 17 85 0c        LBSR   $56C8
d1bc: 32 62           LEAS   $2,S
d1be: 16 00 33        LBRA   $D1F4
d1c1: 8c 00 00        CMPX   #$0000
d1c4: 10 27 ff 17     LBEQ   $D0DF
d1c8: 8c 00 16        CMPX   #$0016
d1cb: 10 27 ff 13     LBEQ   $D0E2
d1cf: 8c 00 17        CMPX   #$0017
d1d2: 10 27 ff 46     LBEQ   $D11C
d1d6: 8c 00 18        CMPX   #$0018
d1d9: 10 27 ff 5d     LBEQ   $D13A
d1dd: 8c 00 1f        CMPX   #$001F
d1e0: 10 27 ff 24     LBEQ   $D108
d1e4: 8c 00 20        CMPX   #$0020
d1e7: 10 27 ff 08     LBEQ   $D0F3
d1eb: 8c 00 23        CMPX   #$0023
d1ee: 10 27 ff 66     LBEQ   $D158
d1f2: 20 c0           BRA    $D1B4
d1f4: be 3f ab        LDX    $3FAB
d1f7: f6 3f ad        LDB    $3FAD
d1fa: 3a              ABX
d1fb: af 63           STX    $3,S
d1fd: e6 f8 03        LDB    [$03,S]
d200: e7 62           STB    $2,S
d202: ce 24 14        LDU    #$2414
d205: 10 ae 63        LDY    $3,S
d208: 8e 00 04        LDX    #$0004
d20b: 34 70           PSHS   U,Y,X
d20d: 17 79 f9        LBSR   $4C09
d210: 32 66           LEAS   $6,S
d212: ce 24 14        LDU    #$2414
d215: c6 04           LDB    #$04
d217: 1d              SEX
d218: 1f 02           TFR    D,Y
d21a: c6 5a           LDB    #$5A
d21c: 1d              SEX
d21d: 1f 01           TFR    D,X
d21f: cc 00 06        LDD    #$0006
d222: 34 76           PSHS   U,Y,X,D
d224: 17 86 c3        LBSR   $58EA
d227: 32 68           LEAS   $8,S
d229: f6 3f ae        LDB    $3FAE
d22c: c1 00           CMPB   #$00
d22e: 10 27 00 19     LBEQ   $D24B
d232: ee 65           LDU    $5,S
d234: c6 02           LDB    #$02
d236: 1d              SEX
d237: 1f 02           TFR    D,Y
d239: c6 65           LDB    #$65
d23b: 1d              SEX
d23c: 1f 01           TFR    D,X
d23e: cc 00 06        LDD    #$0006
d241: 34 76           PSHS   U,Y,X,D
d243: 17 86 a4        LBSR   $58EA
d246: 32 68           LEAS   $8,S
d248: 16 00 29        LBRA   $D274
d24b: ce 24 14        LDU    #$2414
d24e: e6 62           LDB    $2,S
d250: 4f              CLRA
d251: 1f 02           TFR    D,Y
d253: 8e 00 04        LDX    #$0004
d256: 34 70           PSHS   U,Y,X
d258: 17 79 4b        LBSR   $4BA6
d25b: 32 66           LEAS   $6,S
d25d: ce 24 14        LDU    #$2414
d260: c6 02           LDB    #$02
d262: 1d              SEX
d263: 1f 02           TFR    D,Y
d265: c6 65           LDB    #$65
d267: 1d              SEX
d268: 1f 01           TFR    D,X
d26a: cc 00 06        LDD    #$0006
d26d: 34 76           PSHS   U,Y,X,D
d26f: 17 86 78        LBSR   $58EA
d272: 32 68           LEAS   $8,S
d274: c6 65           LDB    #$65
d276: 1d              SEX
d277: 1f 03           TFR    D,U
d279: 10 8e 00 01     LDY    #$0001
d27d: c6 65           LDB    #$65
d27f: 1d              SEX
d280: 1f 01           TFR    D,X
d282: c6 02           LDB    #$02
d284: 1d              SEX
d285: 34 76           PSHS   U,Y,X,D
d287: ce 00 01        LDU    #$0001
d28a: 10 8e 00 0a     LDY    #$000A
d28e: 34 60           PSHS   U,Y
d290: 17 59 a2        LBSR   $2C35
d293: 32 6c           LEAS   $C,S
d295: 32 67           LEAS   $7,S
d297: 39              RTS
d298: fc 55 0d        LDD    $550D
d29b: 17 aa b2        LBSR   $7D50
d29e: ce 41 a0        LDU    #$41A0
d2a1: c6 28           LDB    #$28
d2a3: 1d              SEX
d2a4: 1f 02           TFR    D,Y
d2a6: 5f              CLRB
d2a7: 1d              SEX
d2a8: 1f 01           TFR    D,X
d2aa: cc 00 06        LDD    #$0006
d2ad: 34 76           PSHS   U,Y,X,D
d2af: 17 86 38        LBSR   $58EA
d2b2: 32 68           LEAS   $8,S
d2b4: ce 42 ee        LDU    #$42EE
d2b7: c6 1a           LDB    #$1A
d2b9: 1d              SEX
d2ba: 1f 02           TFR    D,Y
d2bc: c6 0e           LDB    #$0E
d2be: 1d              SEX
d2bf: 1f 01           TFR    D,X
d2c1: cc 00 06        LDD    #$0006
d2c4: 34 76           PSHS   U,Y,X,D
d2c6: 17 86 21        LBSR   $58EA
d2c9: 32 68           LEAS   $8,S
d2cb: ce 43 08        LDU    #$4308
d2ce: c6 28           LDB    #$28
d2d0: 1d              SEX
d2d1: 1f 02           TFR    D,Y
d2d3: c6 40           LDB    #$40
d2d5: 1d              SEX
d2d6: 1f 01           TFR    D,X
d2d8: cc 00 06        LDD    #$0006
d2db: 34 76           PSHS   U,Y,X,D
d2dd: 17 86 0a        LBSR   $58EA
d2e0: 32 68           LEAS   $8,S
d2e2: 7f 3f a9        CLR    $3FA9
d2e5: 7f 3f ad        CLR    $3FAD
d2e8: ce 00 00        LDU    #$0000
d2eb: 34 40           PSHS   U
d2ed: 17 fd 04        LBSR   $CFF4
d2f0: 32 62           LEAS   $2,S
d2f2: cc 50 ce        LDD    #$50CE
d2f5: fd 22 0f        STD    $220F
d2f8: ce 00 00        LDU    #$0000
d2fb: 10 8e 00 02     LDY    #$0002
d2ff: 34 60           PSHS   U,Y
d301: 17 37 cc        LBSR   $0AD0
d304: 32 64           LEAS   $4,S
d306: cc c2 39        LDD    #$C239
d309: fd 22 13        STD    $2213
d30c: 32 62           LEAS   $2,S
d30e: 39              RTS
d30f: fc 55 15        LDD    $5515
d312: 17 aa 3b        LBSR   $7D50
d315: c6 67           LDB    #$67
d317: e7 62           STB    $2,S
d319: c6 01           LDB    #$01
d31b: e7 63           STB    $3,S
d31d: c6 1f           LDB    #$1F
d31f: e7 64           STB    $4,S
d321: ce 43 30        LDU    #$4330
d324: c6 28           LDB    #$28
d326: 1d              SEX
d327: 1f 02           TFR    D,Y
d329: 5f              CLRB
d32a: 1d              SEX
d32b: 1f 01           TFR    D,X
d32d: cc 00 06        LDD    #$0006
d330: 34 76           PSHS   U,Y,X,D
d332: 17 85 b5        LBSR   $58EA
d335: 32 68           LEAS   $8,S
d337: ce 43 58        LDU    #$4358
d33a: c6 28           LDB    #$28
d33c: 1d              SEX
d33d: 1f 02           TFR    D,Y
d33f: c6 40           LDB    #$40
d341: 1d              SEX
d342: 1f 01           TFR    D,X
d344: cc 00 06        LDD    #$0006
d347: 34 76           PSHS   U,Y,X,D
d349: 17 85 9e        LBSR   $58EA
d34c: 32 68           LEAS   $8,S
d34e: ce 43 80        LDU    #$4380
d351: 10 8e 3f b1     LDY    #$3FB1
d355: 8e 00 04        LDX    #$0004
d358: 34 70           PSHS   U,Y,X
d35a: 17 80 20        LBSR   $537D
d35d: 32 66           LEAS   $6,S
d35f: ce 24 14        LDU    #$2414
d362: 10 8e 3f b1     LDY    #$3FB1
d366: 8e 00 04        LDX    #$0004
d369: 34 70           PSHS   U,Y,X
d36b: 17 77 21        LBSR   $4A8F
d36e: 32 66           LEAS   $6,S
d370: ce 24 14        LDU    #$2414
d373: c6 04           LDB    #$04
d375: 1d              SEX
d376: 1f 02           TFR    D,Y
d378: 8e 00 04        LDX    #$0004
d37b: 34 70           PSHS   U,Y,X
d37d: 17 79 7f        LBSR   $4CFF
d380: 32 66           LEAS   $6,S
d382: ce 24 14        LDU    #$2414
d385: c6 06           LDB    #$06
d387: 1d              SEX
d388: 1f 02           TFR    D,Y
d38a: c6 61           LDB    #$61
d38c: 1d              SEX
d38d: 1f 01           TFR    D,X
d38f: cc 00 06        LDD    #$0006
d392: 34 76           PSHS   U,Y,X,D
d394: 17 85 53        LBSR   $58EA
d397: 32 68           LEAS   $8,S
d399: ce 00 00        LDU    #$0000
d39c: 34 40           PSHS   U
d39e: 17 57 d9        LBSR   $2B7A
d3a1: 32 62           LEAS   $2,S
d3a3: ed 68           STD    $8,S
d3a5: ae 68           LDX    $8,S
d3a7: 8c 00 20        CMPX   #$0020
d3aa: 10 27 00 e2     LBEQ   $D490
d3ae: f6 01 00        LDB    $0100
d3b1: c4 20           ANDB   #$20
d3b3: 10 27 00 08     LBEQ   $D3BF
d3b7: cc 55 13        LDD    #$5513
d3ba: ed 66           STD    $6,S
d3bc: 16 00 05        LBRA   $D3C4
d3bf: cc 54 d5        LDD    #$54D5
d3c2: ed 66           STD    $6,S
d3c4: ee 66           LDU    $6,S
d3c6: c6 02           LDB    #$02
d3c8: 1d              SEX
d3c9: 1f 02           TFR    D,Y
d3cb: c6 48           LDB    #$48
d3cd: 1d              SEX
d3ce: 1f 01           TFR    D,X
d3d0: cc 00 06        LDD    #$0006
d3d3: 34 76           PSHS   U,Y,X,D
d3d5: 17 85 12        LBSR   $58EA
d3d8: 32 68           LEAS   $8,S
d3da: c6 32           LDB    #$32
d3dc: 1d              SEX
d3dd: 1f 03           TFR    D,U
d3df: 10 8e 00 02     LDY    #$0002
d3e3: 34 60           PSHS   U,Y
d3e5: 17 82 88        LBSR   $5670
d3e8: 32 64           LEAS   $4,S
d3ea: ae 68           LDX    $8,S
d3ec: 8c 00 13        CMPX   #$0013
d3ef: 10 27 00 0c     LBEQ   $D3FF
d3f3: ae 68           LDX    $8,S
d3f5: 8c 00 19        CMPX   #$0019
d3f8: 10 27 00 03     LBEQ   $D3FF
d3fc: 16 00 8e        LBRA   $D48D
d3ff: ae 68           LDX    $8,S
d401: 8c 00 13        CMPX   #$0013
d404: 10 26 00 17     LBNE   $D41F
d408: ce 3f b1        LDU    #$3FB1
d40b: 10 8e 43 83     LDY    #$4383
d40f: 8e 3f b1        LDX    #$3FB1
d412: cc 00 06        LDD    #$0006
d415: 34 76           PSHS   U,Y,X,D
d417: 17 7f 78        LBSR   $5392
d41a: 32 68           LEAS   $8,S
d41c: 16 00 14        LBRA   $D433
d41f: ce 3f b1        LDU    #$3FB1
d422: 10 8e 43 83     LDY    #$4383
d426: 8e 3f b1        LDX    #$3FB1
d429: cc 00 06        LDD    #$0006
d42c: 34 76           PSHS   U,Y,X,D
d42e: 17 7f 95        LBSR   $53C6
d431: 32 68           LEAS   $8,S
d433: ce 3f b1        LDU    #$3FB1
d436: c6 27           LDB    #$27
d438: 1d              SEX
d439: 1f 02           TFR    D,Y
d43b: 8e 00 04        LDX    #$0004
d43e: 34 70           PSHS   U,Y,X
d440: 17 89 5a        LBSR   $5D9D
d443: 32 66           LEAS   $6,S
d445: ce 24 14        LDU    #$2414
d448: 10 8e 3f b1     LDY    #$3FB1
d44c: 8e 00 04        LDX    #$0004
d44f: 34 70           PSHS   U,Y,X
d451: 17 76 3b        LBSR   $4A8F
d454: 32 66           LEAS   $6,S
d456: ce 24 14        LDU    #$2414
d459: c6 04           LDB    #$04
d45b: 1d              SEX
d45c: 1f 02           TFR    D,Y
d45e: 8e 00 04        LDX    #$0004
d461: 34 70           PSHS   U,Y,X
d463: 17 78 99        LBSR   $4CFF
d466: 32 66           LEAS   $6,S
d468: ce 24 14        LDU    #$2414
d46b: c6 06           LDB    #$06
d46d: 1d              SEX
d46e: 1f 02           TFR    D,Y
d470: c6 61           LDB    #$61
d472: 1d              SEX
d473: 1f 01           TFR    D,X
d475: cc 00 06        LDD    #$0006
d478: 34 76           PSHS   U,Y,X,D
d47a: 17 84 6d        LBSR   $58EA
d47d: 32 68           LEAS   $8,S
d47f: ce 00 96        LDU    #$0096
d482: 10 8e 00 02     LDY    #$0002
d486: 34 60           PSHS   U,Y
d488: 17 81 e5        LBSR   $5670
d48b: 32 64           LEAS   $4,S
d48d: 16 ff 09        LBRA   $D399
d490: fc 22 04        LDD    $2204
d493: 84 ff           ANDA   #$FF
d495: c4 fd           ANDB   #$FD
d497: fd 22 04        STD    $2204
d49a: ce 43 80        LDU    #$4380
d49d: c6 27           LDB    #$27
d49f: 1d              SEX
d4a0: 1f 02           TFR    D,Y
d4a2: 8e 00 04        LDX    #$0004
d4a5: 34 70           PSHS   U,Y,X
d4a7: 17 88 f3        LBSR   $5D9D
d4aa: 32 66           LEAS   $6,S
d4ac: ce 00 96        LDU    #$0096
d4af: 10 8e 00 02     LDY    #$0002
d4b3: 34 60           PSHS   U,Y
d4b5: 17 81 b8        LBSR   $5670
d4b8: 32 64           LEAS   $4,S
d4ba: ce 00 03        LDU    #$0003
d4bd: 10 8e 00 02     LDY    #$0002
d4c1: 34 60           PSHS   U,Y
d4c3: 17 36 0a        LBSR   $0AD0
d4c6: 32 64           LEAS   $4,S
d4c8: 32 6a           LEAS   $A,S
d4ca: 39              RTS
d4cb: 00 01           NEG    <$01
d4cd: 00 04           NEG    <$04
d4cf: 4e              XCLRA
d4d0: 53              COMB
d4d1: 4d              TSTA
d4d2: 49              ROLA
d4d3: 43              COMA
d4d4: 20 20           BRA    $D4F6
d4d6: 20 00           BRA    $D4D8
d4d8: 48              ASLA
d4d9: 50              NEGB
d4da: 2d 49           BLT    $D525
d4dc: 42              XNCA
d4dd: 20 49           BRA    $D528
d4df: 43              COMA
d4e0: 00 46           NEG    <$46
d4e2: 50              NEGB
d4e3: 20 4c           BRA    $D531
d4e5: 45              LSRA
d4e6: 44              LSRA
d4e7: 73 20 00        COM    $2000
d4ea: 48              ASLA
d4eb: 4f              CLRA
d4ec: 50              NEGB
d4ed: 4c              INCA
d4ee: 41              NEGA
d4ef: 54              LSRB
d4f0: 43              COMA
d4f1: 48              ASLA
d4f2: 00 4f           NEG    <$4F
d4f4: 75 74 70        LSR    $7470
d4f7: 75 74 20        LSR    $7420
d4fa: 31 00           LEAY   $0,X
d4fc: 4f              CLRA
d4fd: 75 74 70        LSR    $7470
d500: 75 74 20        LSR    $7420
d503: 32 00           LEAS   $0,X
d505: 54              LSRB
d506: 69 6d           ROL    $D,S
d508: 65 72           LSR    -$E,S
d50a: 20 49           BRA    $D555
d50c: 43              COMA
d50d: 00 00           NEG    <$00
d50f: 2a 2a           BPL    $D53B
d511: 00 05           NEG    <$05
d513: 75 6e 00        LSR    $6E00
d516: 08 fc           ASL    <$FC
d518: 63 a4           COM    ,Y
d51a: 17 a8 33        LBSR   $7D50
d51d: ae e9 00 08     LDX    $0008,S
d521: 16 01 58        LBRA   $D67C
d524: cc 62 4d        LDD    #$624D
d527: ed 62           STD    $2,S
d529: 16 01 b7        LBRA   $D6E3
d52c: cc 62 55        LDD    #$6255
d52f: ed 62           STD    $2,S
d531: 16 01 af        LBRA   $D6E3
d534: cc 62 5d        LDD    #$625D
d537: ed 62           STD    $2,S
d539: 16 01 a7        LBRA   $D6E3
d53c: cc 62 65        LDD    #$6265
d53f: ed 62           STD    $2,S
d541: 16 01 9f        LBRA   $D6E3
d544: cc 62 6d        LDD    #$626D
d547: ed 62           STD    $2,S
d549: 16 01 97        LBRA   $D6E3
d54c: cc 62 75        LDD    #$6275
d54f: ed 62           STD    $2,S
d551: 16 01 8f        LBRA   $D6E3
d554: cc 62 7d        LDD    #$627D
d557: ed 62           STD    $2,S
d559: 16 01 87        LBRA   $D6E3
d55c: cc 62 85        LDD    #$6285
d55f: ed 62           STD    $2,S
d561: 16 01 7f        LBRA   $D6E3
d564: cc 62 8d        LDD    #$628D
d567: ed 62           STD    $2,S
d569: 16 01 77        LBRA   $D6E3
d56c: cc 62 95        LDD    #$6295
d56f: ed 62           STD    $2,S
d571: 16 01 6f        LBRA   $D6E3
d574: cc 62 9d        LDD    #$629D
d577: ed 62           STD    $2,S
d579: 16 01 67        LBRA   $D6E3
d57c: cc 62 a5        LDD    #$62A5
d57f: ed 62           STD    $2,S
d581: 16 01 5f        LBRA   $D6E3
d584: cc 62 ad        LDD    #$62AD
d587: ed 62           STD    $2,S
d589: 16 01 57        LBRA   $D6E3
d58c: cc 62 b5        LDD    #$62B5
d58f: ed 62           STD    $2,S
d591: 16 01 4f        LBRA   $D6E3
d594: cc 62 bd        LDD    #$62BD
d597: ed 62           STD    $2,S
d599: 16 01 47        LBRA   $D6E3
d59c: cc 62 c5        LDD    #$62C5
d59f: ed 62           STD    $2,S
d5a1: 16 01 3f        LBRA   $D6E3
d5a4: cc 62 cd        LDD    #$62CD
d5a7: ed 62           STD    $2,S
d5a9: 16 01 37        LBRA   $D6E3
d5ac: cc 62 d5        LDD    #$62D5
d5af: ed 62           STD    $2,S
d5b1: 16 01 2f        LBRA   $D6E3
d5b4: cc 62 dd        LDD    #$62DD
d5b7: ed 62           STD    $2,S
d5b9: 16 01 27        LBRA   $D6E3
d5bc: cc 62 e5        LDD    #$62E5
d5bf: ed 62           STD    $2,S
d5c1: 16 01 1f        LBRA   $D6E3
d5c4: cc 62 ed        LDD    #$62ED
d5c7: ed 62           STD    $2,S
d5c9: 16 01 17        LBRA   $D6E3
d5cc: cc 62 f5        LDD    #$62F5
d5cf: ed 62           STD    $2,S
d5d1: 16 01 0f        LBRA   $D6E3
d5d4: cc 62 fd        LDD    #$62FD
d5d7: ed 62           STD    $2,S
d5d9: 16 01 07        LBRA   $D6E3
d5dc: cc 63 05        LDD    #$6305
d5df: ed 62           STD    $2,S
d5e1: 16 00 ff        LBRA   $D6E3
d5e4: cc 63 0d        LDD    #$630D
d5e7: ed 62           STD    $2,S
d5e9: 16 00 f7        LBRA   $D6E3
d5ec: cc 63 15        LDD    #$6315
d5ef: ed 62           STD    $2,S
d5f1: 16 00 ef        LBRA   $D6E3
d5f4: cc 63 1d        LDD    #$631D
d5f7: ed 62           STD    $2,S
d5f9: 16 00 e7        LBRA   $D6E3
d5fc: cc 63 25        LDD    #$6325
d5ff: ed 62           STD    $2,S
d601: 16 00 df        LBRA   $D6E3
d604: cc 63 2d        LDD    #$632D
d607: ed 62           STD    $2,S
d609: 16 00 d7        LBRA   $D6E3
d60c: cc 63 35        LDD    #$6335
d60f: ed 62           STD    $2,S
d611: 16 00 cf        LBRA   $D6E3
d614: cc 63 3d        LDD    #$633D
d617: ed 62           STD    $2,S
d619: 16 00 c7        LBRA   $D6E3
d61c: cc 63 45        LDD    #$6345
d61f: ed 62           STD    $2,S
d621: 16 00 bf        LBRA   $D6E3
d624: cc 63 4d        LDD    #$634D
d627: ed 62           STD    $2,S
d629: 16 00 b7        LBRA   $D6E3
d62c: cc 63 55        LDD    #$6355
d62f: ed 62           STD    $2,S
d631: 16 00 af        LBRA   $D6E3
d634: cc 63 5d        LDD    #$635D
d637: ed 62           STD    $2,S
d639: 16 00 a7        LBRA   $D6E3
d63c: cc 63 65        LDD    #$6365
d63f: ed 62           STD    $2,S
d641: 16 00 9f        LBRA   $D6E3
d644: cc 63 6d        LDD    #$636D
d647: ed 62           STD    $2,S
d649: 16 00 97        LBRA   $D6E3
d64c: cc 63 75        LDD    #$6375
d64f: ed 62           STD    $2,S
d651: 16 00 8f        LBRA   $D6E3
d654: cc 63 7d        LDD    #$637D
d657: ed 62           STD    $2,S
d659: 16 00 87        LBRA   $D6E3
d65c: cc 63 85        LDD    #$6385
d65f: ed 62           STD    $2,S
d661: 16 00 7f        LBRA   $D6E3
d664: cc 63 8d        LDD    #$638D
d667: ed 62           STD    $2,S
d669: 16 00 77        LBRA   $D6E3
d66c: cc 63 95        LDD    #$6395
d66f: ed 62           STD    $2,S
d671: 16 00 6f        LBRA   $D6E3
d674: cc 63 9d        LDD    #$639D
d677: ed 62           STD    $2,S
d679: 16 00 67        LBRA   $D6E3
d67c: 8c 00 00        CMPX   #$0000
d67f: 25 f3           BCS    $D674
d681: 8c 00 29        CMPX   #$0029
d684: 22 ee           BHI    $D674
d686: 1f 10           TFR    X,D
d688: 8e 56 8f        LDX    #$568F
d68b: 58              ASLB
d68c: 49              ROLA
d68d: 6e 9b           JMP    [D,X]
d68f: 55              LSRB
d690: 24 55           BCC    $D6E7
d692: 2c 55           BGE    $D6E9
d694: 34 55           PSHS   U,X,B,CC
d696: 3c 55           CWAI   #$55
d698: 44              LSRA
d699: 55              LSRB
d69a: 4c              INCA
d69b: 55              LSRB
d69c: 54              LSRB
d69d: 55              LSRB
d69e: 5c              INCB
d69f: 55              LSRB
d6a0: 64 55           LSR    -$B,U
d6a2: 6c 55           INC    -$B,U
d6a4: 74 55 7c        LSR    $557C
d6a7: 55              LSRB
d6a8: 84 55           ANDA   #$55
d6aa: 8c 55 94        CMPX   #$5594
d6ad: 55              LSRB
d6ae: 9c 55           CMPX   <$55
d6b0: a4 55           ANDA   -$B,U
d6b2: ac 55           CMPX   -$B,U
d6b4: b4 55 bc        ANDA   $55BC
d6b7: 55              LSRB
d6b8: c4 55           ANDB   #$55
d6ba: cc 55 d4        LDD    #$55D4
d6bd: 55              LSRB
d6be: dc 55           LDD    <$55
d6c0: e4 55           ANDB   -$B,U
d6c2: ec 55           LDD    -$B,U
d6c4: f4 55 fc        ANDB   $55FC
d6c7: 56              RORB
d6c8: 04 56           LSR    <$56
d6ca: 0c 56           INC    <$56
d6cc: 14              XHCF
d6cd: 56              RORB
d6ce: 1c 56           ANDCC  #$56
d6d0: 24 56           BCC    $D728
d6d2: 2c 56           BGE    $D72A
d6d4: 34 56           PSHS   U,X,D
d6d6: 3c 56           CWAI   #$56
d6d8: 44              LSRA
d6d9: 56              RORB
d6da: 4c              INCA
d6db: 56              RORB
d6dc: 54              LSRB
d6dd: 56              RORB
d6de: 5c              INCB
d6df: 56              RORB
d6e0: 64 56           LSR    -$A,U
d6e2: 6c ee           INC    W,S
d6e4: 62 c6           XNC    A,U
d6e6: 07 1d           ASR    <$1D
d6e8: 1f 02           TFR    D,Y
d6ea: c6 61           LDB    #$61
d6ec: 1d              SEX
d6ed: 1f 01           TFR    D,X
d6ef: cc 00 06        LDD    #$0006
d6f2: 34 76           PSHS   U,Y,X,D
d6f4: 17 81 f3        LBSR   $58EA
d6f7: 32 68           LEAS   $8,S
d6f9: 32 64           LEAS   $4,S
d6fb: 39              RTS
d6fc: fc 63 a6        LDD    $63A6
d6ff: 17 a6 4e        LBSR   $7D50
d702: 33 63           LEAU   $3,S
d704: 10 ae e9 00 09  LDY    $0009,S
d709: 8e 00 04        LDX    #$0004
d70c: 34 70           PSHS   U,Y,X
d70e: 17 86 2a        LBSR   $5D3B
d711: 32 66           LEAS   $6,S
d713: e7 62           STB    $2,S
d715: e6 62           LDB    $2,S
d717: 16 00 85        LBRA   $D79F
d71a: ae e9 00 0b     LDX    $000B,S
d71e: e6 84           LDB    ,X
d720: c1 00           CMPB   #$00
d722: 10 26 00 1f     LBNE   $D745
d726: ae e9 00 0b     LDX    $000B,S
d72a: 30 01           LEAX   $1,X
d72c: e6 84           LDB    ,X
d72e: c1 00           CMPB   #$00
d730: 10 26 00 11     LBNE   $D745
d734: ae e9 00 0b     LDX    $000B,S
d738: 30 02           LEAX   $2,X
d73a: e6 84           LDB    ,X
d73c: c1 40           CMPB   #$40
d73e: 10 24 00 03     LBCC   $D745
d742: 16 00 0a        LBRA   $D74F
d745: ae e9 00 0b     LDX    $000B,S
d749: 30 02           LEAX   $2,X
d74b: c6 3f           LDB    #$3F
d74d: e7 84           STB    ,X
d74f: ae e9 00 0b     LDX    $000B,S
d753: 30 02           LEAX   $2,X
d755: af 63           STX    $3,S
d757: 16 00 5a        LBRA   $D7B4
d75a: ae e9 00 0b     LDX    $000B,S
d75e: e6 84           LDB    ,X
d760: c1 00           CMPB   #$00
d762: 10 26 00 11     LBNE   $D777
d766: ae e9 00 0b     LDX    $000B,S
d76a: 30 01           LEAX   $1,X
d76c: e6 84           LDB    ,X
d76e: c1 0f           CMPB   #$0F
d770: 10 22 00 03     LBHI   $D777
d774: 16 00 14        LBRA   $D78B
d777: ae e9 00 0b     LDX    $000B,S
d77b: 30 01           LEAX   $1,X
d77d: c6 0f           LDB    #$0F
d77f: e7 84           STB    ,X
d781: ae e9 00 0b     LDX    $000B,S
d785: 30 02           LEAX   $2,X
d787: c6 ff           LDB    #$FF
d789: e7 84           STB    ,X
d78b: ae e9 00 0b     LDX    $000B,S
d78f: 30 01           LEAX   $1,X
d791: af 63           STX    $3,S
d793: 16 00 1e        LBRA   $D7B4
d796: ec e9 00 0b     LDD    $000B,S
d79a: ed 63           STD    $3,S
d79c: 16 00 15        LBRA   $D7B4
d79f: c1 01           CMPB   #$01
d7a1: 10 27 ff 75     LBEQ   $D71A
d7a5: c1 02           CMPB   #$02
d7a7: 27 b1           BEQ    $D75A
d7a9: c1 03           CMPB   #$03
d7ab: 27 ad           BEQ    $D75A
d7ad: c1 04           CMPB   #$04
d7af: 27 e5           BEQ    $D796
d7b1: 16 00 00        LBRA   $D7B4
d7b4: ee 63           LDU    $3,S
d7b6: 10 ae e9 00 09  LDY    $0009,S
d7bb: 8e 00 04        LDX    #$0004
d7be: 34 70           PSHS   U,Y,X
d7c0: 17 85 da        LBSR   $5D9D
d7c3: 32 66           LEAS   $6,S
d7c5: 32 65           LEAS   $5,S
d7c7: 39              RTS
d7c8: fc 63 a8        LDD    $63A8
d7cb: 17 a5 82        LBSR   $7D50
d7ce: 33 62           LEAU   $2,S
d7d0: 10 ae e9 00 0d  LDY    $000D,S
d7d5: 8e 00 04        LDX    #$0004
d7d8: 34 70           PSHS   U,Y,X
d7da: 17 85 5e        LBSR   $5D3B
d7dd: 32 66           LEAS   $6,S
d7df: e7 67           STB    $7,S
d7e1: e6 67           LDB    $7,S
d7e3: 16 00 78        LBRA   $D85E
d7e6: e6 f8 02        LDB    [$02,S]
d7e9: e7 66           STB    $6,S
d7eb: e6 66           LDB    $6,S
d7ed: 4f              CLRA
d7ee: ed 64           STD    $4,S
d7f0: ce 24 14        LDU    #$2414
d7f3: 10 ae 64        LDY    $4,S
d7f6: 8e 00 04        LDX    #$0004
d7f9: 34 70           PSHS   U,Y,X
d7fb: 17 71 14        LBSR   $4912
d7fe: 32 66           LEAS   $6,S
d800: ce 24 14        LDU    #$2414
d803: c6 03           LDB    #$03
d805: 1d              SEX
d806: 1f 02           TFR    D,Y
d808: 8e 00 04        LDX    #$0004
d80b: 34 70           PSHS   U,Y,X
d80d: 17 74 ef        LBSR   $4CFF
d810: 32 66           LEAS   $6,S
d812: c6 04           LDB    #$04
d814: e7 68           STB    $8,S
d816: 16 00 58        LBRA   $D871
d819: ec f8 02        LDD    [$02,S]
d81c: ed 64           STD    $4,S
d81e: ce 24 14        LDU    #$2414
d821: 10 ae 64        LDY    $4,S
d824: 8e 00 04        LDX    #$0004
d827: 34 70           PSHS   U,Y,X
d829: 17 70 e6        LBSR   $4912
d82c: 32 66           LEAS   $6,S
d82e: ce 24 14        LDU    #$2414
d831: c6 01           LDB    #$01
d833: 1d              SEX
d834: 1f 02           TFR    D,Y
d836: 8e 00 04        LDX    #$0004
d839: 34 70           PSHS   U,Y,X
d83b: 17 74 c1        LBSR   $4CFF
d83e: 32 66           LEAS   $6,S
d840: c6 04           LDB    #$04
d842: e7 68           STB    $8,S
d844: 16 00 2a        LBRA   $D871
d847: ce 24 14        LDU    #$2414
d84a: 10 ae 62        LDY    $2,S
d84d: 8e 00 04        LDX    #$0004
d850: 34 70           PSHS   U,Y,X
d852: 17 72 3a        LBSR   $4A8F
d855: 32 66           LEAS   $6,S
d857: c6 07           LDB    #$07
d859: e7 68           STB    $8,S
d85b: 16 00 13        LBRA   $D871
d85e: c1 01           CMPB   #$01
d860: 27 84           BEQ    $D7E6
d862: c1 02           CMPB   #$02
d864: 27 b3           BEQ    $D819
d866: c1 03           CMPB   #$03
d868: 27 af           BEQ    $D819
d86a: c1 04           CMPB   #$04
d86c: 27 d9           BEQ    $D847
d86e: 16 00 00        LBRA   $D871
d871: ce ed 11        LDU    #$ED11
d874: c6 08           LDB    #$08
d876: 1d              SEX
d877: 1f 02           TFR    D,Y
d879: c6 54           LDB    #$54
d87b: 1d              SEX
d87c: 1f 01           TFR    D,X
d87e: cc 00 06        LDD    #$0006
d881: 34 76           PSHS   U,Y,X,D
d883: 17 80 64        LBSR   $58EA
d886: 32 68           LEAS   $8,S
d888: a6 68           LDA    $8,S
d88a: c6 01           LDB    #$01
d88c: 17 a4 f1        LBSR   $7D80
d88f: ce 24 14        LDU    #$2414
d892: 1f 02           TFR    D,Y
d894: c6 54           LDB    #$54
d896: 1d              SEX
d897: 1f 01           TFR    D,X
d899: cc 00 06        LDD    #$0006
d89c: 34 76           PSHS   U,Y,X,D
d89e: 17 80 49        LBSR   $58EA
d8a1: 32 68           LEAS   $8,S
d8a3: 32 69           LEAS   $9,S
d8a5: 39              RTS
d8a6: fc 63 ac        LDD    $63AC
d8a9: 17 a4 a4        LBSR   $7D50
d8ac: ce 25 81        LDU    #$2581
d8af: 10 ae e9 00 06  LDY    $0006,S
d8b4: 34 60           PSHS   U,Y
d8b6: 86 01           LDA    #$01
d8b8: 8e 63 aa        LDX    #$63AA
d8bb: 17 a4 2c        LBSR   $7CEA
d8be: ec e9 00 08     LDD    $0008,S
d8c2: ed 84           STD    ,X
d8c4: ce 25 81        LDU    #$2581
d8c7: 10 ae e9 00 06  LDY    $0006,S
d8cc: 34 60           PSHS   U,Y
d8ce: 86 01           LDA    #$01
d8d0: 8e 63 aa        LDX    #$63AA
d8d3: 17 a4 14        LBSR   $7CEA
d8d6: 30 02           LEAX   $2,X
d8d8: ec e9 00 0a     LDD    $000A,S
d8dc: ed 84           STD    ,X
d8de: ce 25 81        LDU    #$2581
d8e1: 10 ae e9 00 06  LDY    $0006,S
d8e6: 34 60           PSHS   U,Y
d8e8: 86 01           LDA    #$01
d8ea: 8e 63 aa        LDX    #$63AA
d8ed: 17 a3 fa        LBSR   $7CEA
d8f0: 30 04           LEAX   $4,X
d8f2: ee e9 00 0c     LDU    $000C,S
d8f6: 1f 12           TFR    X,Y
d8f8: 8e 00 04        LDX    #$0004
d8fb: 34 70           PSHS   U,Y,X
d8fd: 17 7a 7d        LBSR   $537D
d900: 32 66           LEAS   $6,S
d902: ee e9 00 06     LDU    $0006,S
d906: 10 8e 00 02     LDY    #$0002
d90a: 34 60           PSHS   U,Y
d90c: 17 85 1f        LBSR   $5E2E
d90f: 32 64           LEAS   $4,S
d911: 32 62           LEAS   $2,S
d913: 39              RTS
d914: fc 63 b0        LDD    $63B0
d917: 17 a4 36        LBSR   $7D50
d91a: be 22 17        LDX    $2217
d91d: 16 03 61        LBRA   $DC81
d920: 16 03 c2        LBRA   $DCE5
d923: 5f              CLRB
d924: 4f              CLRA
d925: fd 3f b4        STD    $3FB4
d928: 16 03 ba        LBRA   $DCE5
d92b: be 3f b6        LDX    $3FB6
d92e: 8c 00 00        CMPX   #$0000
d931: 10 26 00 09     LBNE   $D93E
d935: cc 00 01        LDD    #$0001
d938: fd 3f b4        STD    $3FB4
d93b: 16 03 a7        LBRA   $DCE5
d93e: cc 00 02        LDD    #$0002
d941: fd 3f b4        STD    $3FB4
d944: 16 03 9e        LBRA   $DCE5
d947: be 3f b6        LDX    $3FB6
d94a: 8c 00 00        CMPX   #$0000
d94d: 10 26 00 0d     LBNE   $D95E
d951: ce 00 00        LDU    #$0000
d954: 34 40           PSHS   U
d956: 17 7d 6f        LBSR   $56C8
d959: 32 62           LEAS   $2,S
d95b: 16 05 67        LBRA   $DEC5
d95e: cc 00 02        LDD    #$0002
d961: fd 3f b4        STD    $3FB4
d964: 16 03 7e        LBRA   $DCE5
d967: be 3f b6        LDX    $3FB6
d96a: 8c 00 00        CMPX   #$0000
d96d: 10 26 00 0d     LBNE   $D97E
d971: ce 00 00        LDU    #$0000
d974: 34 40           PSHS   U
d976: 17 7d 4f        LBSR   $56C8
d979: 32 62           LEAS   $2,S
d97b: 16 05 47        LBRA   $DEC5
d97e: cc 00 03        LDD    #$0003
d981: fd 3f b4        STD    $3FB4
d984: 16 03 5e        LBRA   $DCE5
d987: be 3f b6        LDX    $3FB6
d98a: 8c 00 00        CMPX   #$0000
d98d: 10 26 00 0d     LBNE   $D99E
d991: ce 00 00        LDU    #$0000
d994: 34 40           PSHS   U
d996: 17 7d 2f        LBSR   $56C8
d999: 32 62           LEAS   $2,S
d99b: 16 05 27        LBRA   $DEC5
d99e: cc 00 04        LDD    #$0004
d9a1: fd 3f b4        STD    $3FB4
d9a4: 16 03 3e        LBRA   $DCE5
d9a7: be 3f b6        LDX    $3FB6
d9aa: 8c 00 00        CMPX   #$0000
d9ad: 10 26 00 08     LBNE   $D9B9
d9b1: cc 00 01        LDD    #$0001
d9b4: ed 64           STD    $4,S
d9b6: 16 00 04        LBRA   $D9BD
d9b9: 5f              CLRB
d9ba: 4f              CLRA
d9bb: ed 64           STD    $4,S
d9bd: ec 64           LDD    $4,S
d9bf: fd 3f b6        STD    $3FB6
d9c2: be 3f b6        LDX    $3FB6
d9c5: 8c 00 01        CMPX   #$0001
d9c8: 10 26 00 1a     LBNE   $D9E6
d9cc: ce 43 d4        LDU    #$43D4
d9cf: c6 28           LDB    #$28
d9d1: 1d              SEX
d9d2: 1f 02           TFR    D,Y
d9d4: c6 40           LDB    #$40
d9d6: 1d              SEX
d9d7: 1f 01           TFR    D,X
d9d9: cc 00 06        LDD    #$0006
d9dc: 34 76           PSHS   U,Y,X,D
d9de: 17 7f 09        LBSR   $58EA
d9e1: 32 68           LEAS   $8,S
d9e3: 16 00 17        LBRA   $D9FD
d9e6: ce 43 ac        LDU    #$43AC
d9e9: c6 28           LDB    #$28
d9eb: 1d              SEX
d9ec: 1f 02           TFR    D,Y
d9ee: c6 40           LDB    #$40
d9f0: 1d              SEX
d9f1: 1f 01           TFR    D,X
d9f3: cc 00 06        LDD    #$0006
d9f6: 34 76           PSHS   U,Y,X,D
d9f8: 17 7e ef        LBSR   $58EA
d9fb: 32 68           LEAS   $8,S
d9fd: 5f              CLRB
d9fe: 4f              CLRA
d9ff: fd 3f b4        STD    $3FB4
da02: 16 02 e0        LBRA   $DCE5
da05: ce 00 03        LDU    #$0003
da08: 10 8e 00 02     LDY    #$0002
da0c: 34 60           PSHS   U,Y
da0e: 17 30 bf        LBSR   $0AD0
da11: 32 64           LEAS   $4,S
da13: 16 04 af        LBRA   $DEC5
da16: ce 00 00        LDU    #$0000
da19: 34 40           PSHS   U
da1b: 17 84 98        LBSR   $5EB6
da1e: 32 62           LEAS   $2,S
da20: 16 02 c2        LBRA   $DCE5
da23: be 3f b6        LDX    $3FB6
da26: 8c 00 01        CMPX   #$0001
da29: 10 26 00 22     LBNE   $DA4F
da2d: be 3f ba        LDX    $3FBA
da30: 8c 00 0f        CMPX   #$000F
da33: 10 25 00 08     LBCS   $DA3F
da37: cc 00 0f        LDD    #$000F
da3a: ed 64           STD    $4,S
da3c: 16 00 08        LBRA   $DA47
da3f: fc 3f ba        LDD    $3FBA
da42: c3 00 01        ADDD   #$0001
da45: ed 64           STD    $4,S
da47: ec 64           LDD    $4,S
da49: fd 3f ba        STD    $3FBA
da4c: 16 00 09        LBRA   $DA58
da4f: fc 3f b8        LDD    $3FB8
da52: c3 00 01        ADDD   #$0001
da55: fd 3f b8        STD    $3FB8
da58: 16 02 8a        LBRA   $DCE5
da5b: be 3f b6        LDX    $3FB6
da5e: 8c 00 01        CMPX   #$0001
da61: 10 26 00 21     LBNE   $DA86
da65: be 3f ba        LDX    $3FBA
da68: 8c 00 00        CMPX   #$0000
da6b: 10 26 00 07     LBNE   $DA76
da6f: 5f              CLRB
da70: 4f              CLRA
da71: ed 64           STD    $4,S
da73: 16 00 08        LBRA   $DA7E
da76: fc 3f ba        LDD    $3FBA
da79: 83 00 01        SUBD   #$0001
da7c: ed 64           STD    $4,S
da7e: ec 64           LDD    $4,S
da80: fd 3f ba        STD    $3FBA
da83: 16 00 1e        LBRA   $DAA4
da86: be 3f b8        LDX    $3FB8
da89: 8c 00 00        CMPX   #$0000
da8c: 10 26 00 07     LBNE   $DA97
da90: 5f              CLRB
da91: 4f              CLRA
da92: ed 64           STD    $4,S
da94: 16 00 08        LBRA   $DA9F
da97: fc 3f b8        LDD    $3FB8
da9a: 83 00 01        SUBD   #$0001
da9d: ed 64           STD    $4,S
da9f: ec 64           LDD    $4,S
daa1: fd 3f b8        STD    $3FB8
daa4: 16 02 3e        LBRA   $DCE5
daa7: be 3f b4        LDX    $3FB4
daaa: 16 01 a3        LBRA   $DC50
daad: c6 05           LDB    #$05
daaf: 1d              SEX
dab0: 1f 03           TFR    D,U
dab2: 10 8e 00 02     LDY    #$0002
dab6: 34 60           PSHS   U,Y
dab8: 17 57 68        LBSR   $3223
dabb: 32 64           LEAS   $4,S
dabd: c1 00           CMPB   #$00
dabf: 10 26 00 03     LBNE   $DAC6
dac3: 16 01 ab        LBRA   $DC71
dac6: be 3f b6        LDX    $3FB6
dac9: 8c 00 01        CMPX   #$0001
dacc: 10 26 00 24     LBNE   $DAF4
dad0: ce 23 9a        LDU    #$239A
dad3: 10 8e 00 02     LDY    #$0002
dad7: 34 60           PSHS   U,Y
dad9: 17 6e 97        LBSR   $4973
dadc: 32 64           LEAS   $4,S
dade: fd 3f ba        STD    $3FBA
dae1: be 3f ba        LDX    $3FBA
dae4: 8c 00 0f        CMPX   #$000F
dae7: 10 23 00 06     LBLS   $DAF1
daeb: cc 00 0f        LDD    #$000F
daee: fd 3f ba        STD    $3FBA
daf1: 16 00 11        LBRA   $DB05
daf4: ce 23 9a        LDU    #$239A
daf7: 10 8e 00 02     LDY    #$0002
dafb: 34 60           PSHS   U,Y
dafd: 17 6e 73        LBSR   $4973
db00: 32 64           LEAS   $4,S
db02: fd 3f b8        STD    $3FB8
db05: 16 01 69        LBRA   $DC71
db08: c6 08           LDB    #$08
db0a: 1d              SEX
db0b: 1f 03           TFR    D,U
db0d: 10 8e 00 02     LDY    #$0002
db11: 34 60           PSHS   U,Y
db13: 17 57 0d        LBSR   $3223
db16: 32 64           LEAS   $4,S
db18: c1 00           CMPB   #$00
db1a: 10 26 00 03     LBNE   $DB21
db1e: 16 01 50        LBRA   $DC71
db21: ce 3f c5        LDU    #$3FC5
db24: 10 8e 23 9a     LDY    #$239A
db28: 8e 00 04        LDX    #$0004
db2b: 34 70           PSHS   U,Y,X
db2d: 17 6f e0        LBSR   $4B10
db30: 32 66           LEAS   $6,S
db32: ce 3f c5        LDU    #$3FC5
db35: 10 be 3f b8     LDY    $3FB8
db39: 8e 00 04        LDX    #$0004
db3c: 34 70           PSHS   U,Y,X
db3e: 17 fb bb        LBSR   $D6FC
db41: 32 66           LEAS   $6,S
db43: 16 01 2b        LBRA   $DC71
db46: c6 05           LDB    #$05
db48: 1d              SEX
db49: 1f 03           TFR    D,U
db4b: 10 8e 00 02     LDY    #$0002
db4f: 34 60           PSHS   U,Y
db51: 17 56 cf        LBSR   $3223
db54: 32 64           LEAS   $4,S
db56: c1 00           CMPB   #$00
db58: 10 26 00 03     LBNE   $DB5F
db5c: 16 01 12        LBRA   $DC71
db5f: ce 23 9a        LDU    #$239A
db62: 10 8e 00 02     LDY    #$0002
db66: 34 60           PSHS   U,Y
db68: 17 6e 08        LBSR   $4973
db6b: 32 64           LEAS   $4,S
db6d: fd 3f bc        STD    $3FBC
db70: be 3f bc        LDX    $3FBC
db73: 8c 10 00        CMPX   #$1000
db76: 10 24 00 08     LBCC   $DB82
db7a: fc 3f bc        LDD    $3FBC
db7d: ed 64           STD    $4,S
db7f: 16 00 05        LBRA   $DB87
db82: cc 0f ff        LDD    #$0FFF
db85: ed 64           STD    $4,S
db87: ec 64           LDD    $4,S
db89: fd 3f bc        STD    $3FBC
db8c: ce 3f c2        LDU    #$3FC2
db8f: 10 be 3f be     LDY    $3FBE
db93: be 3f bc        LDX    $3FBC
db96: fc 3f ba        LDD    $3FBA
db99: 34 76           PSHS   U,Y,X,D
db9b: ce 00 08        LDU    #$0008
db9e: 34 40           PSHS   U
dba0: 17 fd 03        LBSR   $D8A6
dba3: 32 6a           LEAS   $A,S
dba5: 16 00 c9        LBRA   $DC71
dba8: c6 05           LDB    #$05
dbaa: 1d              SEX
dbab: 1f 03           TFR    D,U
dbad: 10 8e 00 02     LDY    #$0002
dbb1: 34 60           PSHS   U,Y
dbb3: 17 56 6d        LBSR   $3223
dbb6: 32 64           LEAS   $4,S
dbb8: c1 00           CMPB   #$00
dbba: 10 26 00 03     LBNE   $DBC1
dbbe: 16 00 b0        LBRA   $DC71
dbc1: ce 23 9a        LDU    #$239A
dbc4: 10 8e 00 02     LDY    #$0002
dbc8: 34 60           PSHS   U,Y
dbca: 17 6d a6        LBSR   $4973
dbcd: 32 64           LEAS   $4,S
dbcf: fd 3f be        STD    $3FBE
dbd2: be 3f be        LDX    $3FBE
dbd5: 8c 10 00        CMPX   #$1000
dbd8: 10 24 00 08     LBCC   $DBE4
dbdc: fc 3f be        LDD    $3FBE
dbdf: ed 64           STD    $4,S
dbe1: 16 00 05        LBRA   $DBE9
dbe4: cc 0f ff        LDD    #$0FFF
dbe7: ed 64           STD    $4,S
dbe9: ec 64           LDD    $4,S
dbeb: fd 3f be        STD    $3FBE
dbee: ce 3f c2        LDU    #$3FC2
dbf1: 10 be 3f be     LDY    $3FBE
dbf5: be 3f bc        LDX    $3FBC
dbf8: fc 3f ba        LDD    $3FBA
dbfb: 34 76           PSHS   U,Y,X,D
dbfd: ce 00 08        LDU    #$0008
dc00: 34 40           PSHS   U
dc02: 17 fc a1        LBSR   $D8A6
dc05: 32 6a           LEAS   $A,S
dc07: 16 00 67        LBRA   $DC71
dc0a: c6 08           LDB    #$08
dc0c: 1d              SEX
dc0d: 1f 03           TFR    D,U
dc0f: 10 8e 00 02     LDY    #$0002
dc13: 34 60           PSHS   U,Y
dc15: 17 56 0b        LBSR   $3223
dc18: 32 64           LEAS   $4,S
dc1a: c1 00           CMPB   #$00
dc1c: 10 26 00 03     LBNE   $DC23
dc20: 16 00 4e        LBRA   $DC71
dc23: ce 3f c2        LDU    #$3FC2
dc26: 10 8e 23 9a     LDY    #$239A
dc2a: 8e 00 04        LDX    #$0004
dc2d: 34 70           PSHS   U,Y,X
dc2f: 17 6e de        LBSR   $4B10
dc32: 32 66           LEAS   $6,S
dc34: ce 3f c2        LDU    #$3FC2
dc37: 10 be 3f be     LDY    $3FBE
dc3b: be 3f bc        LDX    $3FBC
dc3e: fc 3f ba        LDD    $3FBA
dc41: 34 76           PSHS   U,Y,X,D
dc43: ce 00 08        LDU    #$0008
dc46: 34 40           PSHS   U
dc48: 17 fc 5b        LBSR   $D8A6
dc4b: 32 6a           LEAS   $A,S
dc4d: 16 00 21        LBRA   $DC71
dc50: 8c 00 00        CMPX   #$0000
dc53: 10 2d 00 1a     LBLT   $DC71
dc57: 8c 00 04        CMPX   #$0004
dc5a: 10 2e 00 13     LBGT   $DC71
dc5e: 1f 10           TFR    X,D
dc60: 8e 5c 67        LDX    #$5C67
dc63: 58              ASLB
dc64: 49              ROLA
dc65: 6e 9b           JMP    [D,X]
dc67: 5a              DECB
dc68: ad 5b           JSR    -$5,U
dc6a: 08 5b           ASL    <$5B
dc6c: 46              RORA
dc6d: 5b              XDECB
dc6e: a8 5c           EORA   -$4,U
dc70: 0a 16           DEC    <$16
dc72: 00 71           NEG    <$71
dc74: ce 00 00        LDU    #$0000
dc77: 34 40           PSHS   U
dc79: 17 7a 4c        LBSR   $56C8
dc7c: 32 62           LEAS   $2,S
dc7e: 16 00 64        LBRA   $DCE5
dc81: 8c 00 00        CMPX   #$0000
dc84: 10 27 fc 98     LBEQ   $D920
dc88: 8c 00 13        CMPX   #$0013
dc8b: 10 27 fc 94     LBEQ   $D923
dc8f: 8c 00 14        CMPX   #$0014
dc92: 10 27 fc 95     LBEQ   $D92B
dc96: 8c 00 15        CMPX   #$0015
dc99: 10 27 fd 0a     LBEQ   $D9A7
dc9d: 8c 00 16        CMPX   #$0016
dca0: 10 27 fd 61     LBEQ   $DA05
dca4: 8c 00 17        CMPX   #$0017
dca7: 10 27 fd 78     LBEQ   $DA23
dcab: 8c 00 18        CMPX   #$0018
dcae: 10 27 fd a9     LBEQ   $DA5B
dcb2: 8c 00 19        CMPX   #$0019
dcb5: 10 27 fc ce     LBEQ   $D987
dcb9: 8c 00 1a        CMPX   #$001A
dcbc: 10 27 fc a7     LBEQ   $D967
dcc0: 8c 00 1c        CMPX   #$001C
dcc3: 10 27 fc 80     LBEQ   $D947
dcc7: 8c 00 1d        CMPX   #$001D
dcca: 10 27 fd 48     LBEQ   $DA16
dcce: 8c 00 1f        CMPX   #$001F
dcd1: 10 27 fd 86     LBEQ   $DA5B
dcd5: 8c 00 20        CMPX   #$0020
dcd8: 10 27 fd 47     LBEQ   $DA23
dcdc: 8c 00 23        CMPX   #$0023
dcdf: 10 27 fd c4     LBEQ   $DAA7
dce3: 20 8f           BRA    $DC74
dce5: be 3f b6        LDX    $3FB6
dce8: 16 01 4a        LBRA   $DE35
dceb: ce 24 14        LDU    #$2414
dcee: 10 be 3f b8     LDY    $3FB8
dcf2: 8e 00 04        LDX    #$0004
dcf5: 34 70           PSHS   U,Y,X
dcf7: 17 6c 18        LBSR   $4912
dcfa: 32 66           LEAS   $6,S
dcfc: ce 24 17        LDU    #$2417
dcff: c6 02           LDB    #$02
dd01: 1d              SEX
dd02: 1f 02           TFR    D,Y
dd04: c6 4a           LDB    #$4A
dd06: 1d              SEX
dd07: 1f 01           TFR    D,X
dd09: cc 00 06        LDD    #$0006
dd0c: 34 76           PSHS   U,Y,X,D
dd0e: 17 7b d9        LBSR   $58EA
dd11: 32 68           LEAS   $8,S
dd13: fe 3f b8        LDU    $3FB8
dd16: 10 8e 00 02     LDY    #$0002
dd1a: 34 60           PSHS   U,Y
dd1c: 17 fa a9        LBSR   $D7C8
dd1f: 32 64           LEAS   $4,S
dd21: fe 3f b8        LDU    $3FB8
dd24: 10 8e 00 02     LDY    #$0002
dd28: 34 60           PSHS   U,Y
dd2a: 17 f7 ea        LBSR   $D517
dd2d: 32 64           LEAS   $4,S
dd2f: 16 01 14        LBRA   $DE46
dd32: ce 24 14        LDU    #$2414
dd35: 10 be 3f ba     LDY    $3FBA
dd39: 8e 00 04        LDX    #$0004
dd3c: 34 70           PSHS   U,Y,X
dd3e: 17 6b d1        LBSR   $4912
dd41: 32 66           LEAS   $6,S
dd43: ce 24 17        LDU    #$2417
dd46: c6 02           LDB    #$02
dd48: 1d              SEX
dd49: 1f 02           TFR    D,Y
dd4b: c6 4a           LDB    #$4A
dd4d: 1d              SEX
dd4e: 1f 01           TFR    D,X
dd50: cc 00 06        LDD    #$0006
dd53: 34 76           PSHS   U,Y,X,D
dd55: 17 7b 92        LBSR   $58EA
dd58: 32 68           LEAS   $8,S
dd5a: ce 25 81        LDU    #$2581
dd5d: 10 be 3f ba     LDY    $3FBA
dd61: 34 60           PSHS   U,Y
dd63: 86 01           LDA    #$01
dd65: 8e 63 aa        LDX    #$63AA
dd68: 17 9f 7f        LBSR   $7CEA
dd6b: ae 84           LDX    ,X
dd6d: bf 3f bc        STX    $3FBC
dd70: ce 24 14        LDU    #$2414
dd73: 10 be 3f bc     LDY    $3FBC
dd77: 8e 00 04        LDX    #$0004
dd7a: 34 70           PSHS   U,Y,X
dd7c: 17 6b 93        LBSR   $4912
dd7f: 32 66           LEAS   $6,S
dd81: ce 24 15        LDU    #$2415
dd84: c6 04           LDB    #$04
dd86: 1d              SEX
dd87: 1f 02           TFR    D,Y
dd89: c6 54           LDB    #$54
dd8b: 1d              SEX
dd8c: 1f 01           TFR    D,X
dd8e: cc 00 06        LDD    #$0006
dd91: 34 76           PSHS   U,Y,X,D
dd93: 17 7b 54        LBSR   $58EA
dd96: 32 68           LEAS   $8,S
dd98: ce 25 81        LDU    #$2581
dd9b: 10 be 3f ba     LDY    $3FBA
dd9f: 34 60           PSHS   U,Y
dda1: 86 01           LDA    #$01
dda3: 8e 63 aa        LDX    #$63AA
dda6: 17 9f 41        LBSR   $7CEA
dda9: 30 02           LEAX   $2,X
ddab: ae 84           LDX    ,X
ddad: bf 3f be        STX    $3FBE
ddb0: ce 24 14        LDU    #$2414
ddb3: 10 be 3f be     LDY    $3FBE
ddb7: 8e 00 04        LDX    #$0004
ddba: 34 70           PSHS   U,Y,X
ddbc: 17 6b 53        LBSR   $4912
ddbf: 32 66           LEAS   $6,S
ddc1: ce 24 15        LDU    #$2415
ddc4: c6 04           LDB    #$04
ddc6: 1d              SEX
ddc7: 1f 02           TFR    D,Y
ddc9: c6 5a           LDB    #$5A
ddcb: 1d              SEX
ddcc: 1f 01           TFR    D,X
ddce: cc 00 06        LDD    #$0006
ddd1: 34 76           PSHS   U,Y,X,D
ddd3: 17 7b 14        LBSR   $58EA
ddd6: 32 68           LEAS   $8,S
ddd8: ce 25 81        LDU    #$2581
dddb: 10 be 3f ba     LDY    $3FBA
dddf: 34 60           PSHS   U,Y
dde1: 86 01           LDA    #$01
dde3: 8e 63 aa        LDX    #$63AA
dde6: 17 9f 01        LBSR   $7CEA
dde9: 30 04           LEAX   $4,X
ddeb: bf 3f c0        STX    $3FC0
ddee: be 3f c0        LDX    $3FC0
ddf1: e6 84           LDB    ,X
ddf3: f7 3f c2        STB    $3FC2
ddf6: be 3f c0        LDX    $3FC0
ddf9: 30 01           LEAX   $1,X
ddfb: e6 84           LDB    ,X
ddfd: f7 3f c3        STB    $3FC3
de00: be 3f c0        LDX    $3FC0
de03: 30 02           LEAX   $2,X
de05: e6 84           LDB    ,X
de07: f7 3f c4        STB    $3FC4
de0a: ce 24 14        LDU    #$2414
de0d: 10 be 3f c0     LDY    $3FC0
de11: 8e 00 04        LDX    #$0004
de14: 34 70           PSHS   U,Y,X
de16: 17 6c 76        LBSR   $4A8F
de19: 32 66           LEAS   $6,S
de1b: ce 24 14        LDU    #$2414
de1e: c6 08           LDB    #$08
de20: 1d              SEX
de21: 1f 02           TFR    D,Y
de23: c6 60           LDB    #$60
de25: 1d              SEX
de26: 1f 01           TFR    D,X
de28: cc 00 06        LDD    #$0006
de2b: 34 76           PSHS   U,Y,X,D
de2d: 17 7a ba        LBSR   $58EA
de30: 32 68           LEAS   $8,S
de32: 16 00 11        LBRA   $DE46
de35: 8c 00 00        CMPX   #$0000
de38: 10 27 fe af     LBEQ   $DCEB
de3c: 8c 00 01        CMPX   #$0001
de3f: 10 27 fe ef     LBEQ   $DD32
de43: 16 00 00        LBRA   $DE46
de46: be 3f b4        LDX    $3FB4
de49: 16 00 37        LBRA   $DE83
de4c: c6 4a           LDB    #$4A
de4e: e7 63           STB    $3,S
de50: c6 02           LDB    #$02
de52: e7 62           STB    $2,S
de54: 16 00 4d        LBRA   $DEA4
de57: c6 54           LDB    #$54
de59: e7 63           STB    $3,S
de5b: c6 08           LDB    #$08
de5d: e7 62           STB    $2,S
de5f: 16 00 42        LBRA   $DEA4
de62: c6 54           LDB    #$54
de64: e7 63           STB    $3,S
de66: c6 04           LDB    #$04
de68: e7 62           STB    $2,S
de6a: 16 00 37        LBRA   $DEA4
de6d: c6 5a           LDB    #$5A
de6f: e7 63           STB    $3,S
de71: c6 04           LDB    #$04
de73: e7 62           STB    $2,S
de75: 16 00 2c        LBRA   $DEA4
de78: c6 60           LDB    #$60
de7a: e7 63           STB    $3,S
de7c: c6 08           LDB    #$08
de7e: e7 62           STB    $2,S
de80: 16 00 21        LBRA   $DEA4
de83: 8c 00 00        CMPX   #$0000
de86: 10 2d 00 1a     LBLT   $DEA4
de8a: 8c 00 04        CMPX   #$0004
de8d: 10 2e 00 13     LBGT   $DEA4
de91: 1f 10           TFR    X,D
de93: 8e 5e 9a        LDX    #$5E9A
de96: 58              ASLB
de97: 49              ROLA
de98: 6e 9b           JMP    [D,X]
de9a: 5e              XCLRB
de9b: 4c              INCA
de9c: 5e              XCLRB
de9d: 57              ASRB
de9e: 5e              XCLRB
de9f: 62 5e           XNC    -$2,U
dea1: 6d 5e           TST    -$2,U
dea3: 78 e6 63        ASL    $E663
dea6: 4f              CLRA
dea7: 1f 03           TFR    D,U
dea9: 10 8e 00 02     LDY    #$0002
dead: e6 63           LDB    $3,S
deaf: 4f              CLRA
deb0: 1f 01           TFR    D,X
deb2: e6 62           LDB    $2,S
deb4: 4f              CLRA
deb5: 34 76           PSHS   U,Y,X,D
deb7: ce 00 00        LDU    #$0000
deba: 10 8e 00 0a     LDY    #$000A
debe: 34 60           PSHS   U,Y
dec0: 17 4d 72        LBSR   $2C35
dec3: 32 6c           LEAS   $C,S
dec5: 32 66           LEAS   $6,S
dec7: 39              RTS
dec8: fc 63 ac        LDD    $63AC
decb: 17 9e 82        LBSR   $7D50
dece: ce 41 a0        LDU    #$41A0
ded1: c6 28           LDB    #$28
ded3: 1d              SEX
ded4: 1f 02           TFR    D,Y
ded6: 5f              CLRB
ded7: 1d              SEX
ded8: 1f 01           TFR    D,X
deda: cc 00 06        LDD    #$0006
dedd: 34 76           PSHS   U,Y,X,D
dedf: 17 7a 08        LBSR   $58EA
dee2: 32 68           LEAS   $8,S
dee4: ce 43 86        LDU    #$4386
dee7: c6 1a           LDB    #$1A
dee9: 1d              SEX
deea: 1f 02           TFR    D,Y
deec: c6 0e           LDB    #$0E
deee: 1d              SEX
deef: 1f 01           TFR    D,X
def1: cc 00 06        LDD    #$0006
def4: 34 76           PSHS   U,Y,X,D
def6: 17 79 f1        LBSR   $58EA
def9: 32 68           LEAS   $8,S
defb: ce 44 16        LDU    #$4416
defe: c6 28           LDB    #$28
df00: 1d              SEX
df01: 1f 02           TFR    D,Y
df03: c6 40           LDB    #$40
df05: 1d              SEX
df06: 1f 01           TFR    D,X
df08: cc 00 06        LDD    #$0006
df0b: 34 76           PSHS   U,Y,X,D
df0d: 17 79 da        LBSR   $58EA
df10: 32 68           LEAS   $8,S
df12: ce 43 a0        LDU    #$43A0
df15: c6 0c           LDB    #$0C
df17: 1d              SEX
df18: 1f 02           TFR    D,Y
df1a: c6 55           LDB    #$55
df1c: 1d              SEX
df1d: 1f 01           TFR    D,X
df1f: cc 00 06        LDD    #$0006
df22: 34 76           PSHS   U,Y,X,D
df24: 17 79 c3        LBSR   $58EA
df27: 32 68           LEAS   $8,S
df29: ce 07 d0        LDU    #$07D0
df2c: 10 8e 00 02     LDY    #$0002
df30: 34 60           PSHS   U,Y
df32: 17 77 3b        LBSR   $5670
df35: 32 64           LEAS   $4,S
df37: ce 43 ac        LDU    #$43AC
df3a: c6 28           LDB    #$28
df3c: 1d              SEX
df3d: 1f 02           TFR    D,Y
df3f: c6 40           LDB    #$40
df41: 1d              SEX
df42: 1f 01           TFR    D,X
df44: cc 00 06        LDD    #$0006
df47: 34 76           PSHS   U,Y,X,D
df49: 17 79 9e        LBSR   $58EA
df4c: 32 68           LEAS   $8,S
df4e: 5f              CLRB
df4f: 4f              CLRA
df50: fd 3f b4        STD    $3FB4
df53: 5f              CLRB
df54: 4f              CLRA
df55: fd 3f b6        STD    $3FB6
df58: 5f              CLRB
df59: 4f              CLRA
df5a: fd 3f b8        STD    $3FB8
df5d: 5f              CLRB
df5e: 4f              CLRA
df5f: fd 3f ba        STD    $3FBA
df62: 7f 3f c5        CLR    $3FC5
df65: 7f 3f c6        CLR    $3FC6
df68: 7f 3f c7        CLR    $3FC7
df6b: ce 00 00        LDU    #$0000
df6e: 34 40           PSHS   U
df70: 17 7f 67        LBSR   $5EDA
df73: 32 62           LEAS   $2,S
df75: ce 00 00        LDU    #$0000
df78: 34 40           PSHS   U
df7a: 17 88 1c        LBSR   $6799
df7d: 32 62           LEAS   $2,S
df7f: cc 59 14        LDD    #$5914
df82: fd 22 0f        STD    $220F
df85: ce 00 00        LDU    #$0000
df88: 10 8e 00 02     LDY    #$0002
df8c: 34 60           PSHS   U,Y
df8e: 17 2b 3f        LBSR   $0AD0
df91: 32 64           LEAS   $4,S
df93: 32 62           LEAS   $2,S
df95: 39              RTS
df96: fc 63 aa        LDD    $63AA
df99: 17 9d b4        LBSR   $7D50
df9c: be 22 17        LDX    $2217
df9f: 16 00 e6        LBRA   $E088
dfa2: 16 01 16        LBRA   $E0BB
dfa5: 5f              CLRB
dfa6: 4f              CLRA
dfa7: fd 3f b4        STD    $3FB4
dfaa: ce 00 00        LDU    #$0000
dfad: 34 40           PSHS   U
dfaf: 17 7a 14        LBSR   $59C6
dfb2: 32 62           LEAS   $2,S
dfb4: 16 01 04        LBRA   $E0BB
dfb7: cc 00 01        LDD    #$0001
dfba: fd 3f b4        STD    $3FB4
dfbd: ce 00 00        LDU    #$0000
dfc0: 34 40           PSHS   U
dfc2: 17 7a 01        LBSR   $59C6
dfc5: 32 62           LEAS   $2,S
dfc7: 16 00 f1        LBRA   $E0BB
dfca: ce 00 03        LDU    #$0003
dfcd: 10 8e 00 02     LDY    #$0002
dfd1: 34 60           PSHS   U,Y
dfd3: 17 2a fa        LBSR   $0AD0
dfd6: 32 64           LEAS   $4,S
dfd8: 16 01 dd        LBRA   $E1B8
dfdb: fc 3f c8        LDD    $3FC8
dfde: c3 00 01        ADDD   #$0001
dfe1: fd 3f c8        STD    $3FC8
dfe4: 16 00 d4        LBRA   $E0BB
dfe7: fc 3f c8        LDD    $3FC8
dfea: 83 00 01        SUBD   #$0001
dfed: fd 3f c8        STD    $3FC8
dff0: 16 00 c8        LBRA   $E0BB
dff3: be 3f b4        LDX    $3FB4
dff6: 16 00 72        LBRA   $E06B
dff9: c6 04           LDB    #$04
dffb: 1d              SEX
dffc: 1f 03           TFR    D,U
dffe: 10 8e 00 02     LDY    #$0002
e002: 34 60           PSHS   U,Y
e004: 17 52 1c        LBSR   $3223
e007: 32 64           LEAS   $4,S
e009: c1 00           CMPB   #$00
e00b: 10 27 00 11     LBEQ   $E020
e00f: ce 23 9a        LDU    #$239A
e012: 10 8e 00 02     LDY    #$0002
e016: 34 60           PSHS   U,Y
e018: 17 6c 9a        LBSR   $4CB5
e01b: 32 64           LEAS   $4,S
e01d: fd 3f c8        STD    $3FC8
e020: 16 00 55        LBRA   $E078
e023: c6 02           LDB    #$02
e025: 1d              SEX
e026: 1f 03           TFR    D,U
e028: 10 8e 00 02     LDY    #$0002
e02c: 34 60           PSHS   U,Y
e02e: 17 51 f2        LBSR   $3223
e031: 32 64           LEAS   $4,S
e033: c1 00           CMPB   #$00
e035: 10 27 00 2f     LBEQ   $E068
e039: ce 23 9a        LDU    #$239A
e03c: 10 8e 00 02     LDY    #$0002
e040: 34 60           PSHS   U,Y
e042: 17 6c 0e        LBSR   $4C53
e045: 32 64           LEAS   $4,S
e047: e7 62           STB    $2,S
e049: be 3f c8        LDX    $3FC8
e04c: 8c 40 00        CMPX   #$4000
e04f: 10 26 00 05     LBNE   $E058
e053: e6 62           LDB    $2,S
e055: f7 3f cb        STB    $3FCB
e058: be 3f c8        LDX    $3FC8
e05b: 8c 40 00        CMPX   #$4000
e05e: 10 24 00 06     LBCC   $E068
e062: e6 62           LDB    $2,S
e064: e7 9f 3f c8     STB    [$3FC8]
e068: 16 00 0d        LBRA   $E078
e06b: 8c 00 00        CMPX   #$0000
e06e: 27 89           BEQ    $DFF9
e070: 8c 00 01        CMPX   #$0001
e073: 27 ae           BEQ    $E023
e075: 16 00 00        LBRA   $E078
e078: 16 00 40        LBRA   $E0BB
e07b: ce 00 00        LDU    #$0000
e07e: 34 40           PSHS   U
e080: 17 76 45        LBSR   $56C8
e083: 32 62           LEAS   $2,S
e085: 16 00 33        LBRA   $E0BB
e088: 8c 00 00        CMPX   #$0000
e08b: 10 27 ff 13     LBEQ   $DFA2
e08f: 8c 00 13        CMPX   #$0013
e092: 10 27 ff 0f     LBEQ   $DFA5
e096: 8c 00 14        CMPX   #$0014
e099: 10 27 ff 1a     LBEQ   $DFB7
e09d: 8c 00 16        CMPX   #$0016
e0a0: 10 27 ff 26     LBEQ   $DFCA
e0a4: 8c 00 1f        CMPX   #$001F
e0a7: 10 27 ff 3c     LBEQ   $DFE7
e0ab: 8c 00 20        CMPX   #$0020
e0ae: 10 27 ff 29     LBEQ   $DFDB
e0b2: 8c 00 23        CMPX   #$0023
e0b5: 10 27 ff 3a     LBEQ   $DFF3
e0b9: 20 c0           BRA    $E07B
e0bb: be 3f c8        LDX    $3FC8
e0be: 8c 40 00        CMPX   #$4000
e0c1: 10 25 00 0d     LBCS   $E0D2
e0c5: be 3f c8        LDX    $3FC8
e0c8: 8c 7f ff        CMPX   #$7FFF
e0cb: 10 22 00 03     LBHI   $E0D2
e0cf: 16 00 03        LBRA   $E0D5
e0d2: 16 00 18        LBRA   $E0ED
e0d5: fe 3f c8        LDU    $3FC8
e0d8: f6 3f cb        LDB    $3FCB
e0db: 4f              CLRA
e0dc: 1f 02           TFR    D,Y
e0de: 8e 00 04        LDX    #$0004
e0e1: 34 70           PSHS   U,Y,X
e0e3: 17 60 fd        LBSR   $41E3
e0e6: 32 66           LEAS   $6,S
e0e8: e7 62           STB    $2,S
e0ea: 16 00 06        LBRA   $E0F3
e0ed: e6 9f 3f c8     LDB    [$3FC8]
e0f1: e7 62           STB    $2,S
e0f3: ce 24 14        LDU    #$2414
e0f6: 10 be 3f c8     LDY    $3FC8
e0fa: 8e 00 04        LDX    #$0004
e0fd: 34 70           PSHS   U,Y,X
e0ff: 17 6b 07        LBSR   $4C09
e102: 32 66           LEAS   $6,S
e104: ce 24 14        LDU    #$2414
e107: c6 04           LDB    #$04
e109: 1d              SEX
e10a: 1f 02           TFR    D,Y
e10c: c6 49           LDB    #$49
e10e: 1d              SEX
e10f: 1f 01           TFR    D,X
e111: cc 00 06        LDD    #$0006
e114: 34 76           PSHS   U,Y,X,D
e116: 17 77 d1        LBSR   $58EA
e119: 32 68           LEAS   $8,S
e11b: ce 24 14        LDU    #$2414
e11e: e6 62           LDB    $2,S
e120: 4f              CLRA
e121: 1f 02           TFR    D,Y
e123: 8e 00 04        LDX    #$0004
e126: 34 70           PSHS   U,Y,X
e128: 17 6a 7b        LBSR   $4BA6
e12b: 32 66           LEAS   $6,S
e12d: ce 24 14        LDU    #$2414
e130: c6 02           LDB    #$02
e132: 1d              SEX
e133: 1f 02           TFR    D,Y
e135: c6 58           LDB    #$58
e137: 1d              SEX
e138: 1f 01           TFR    D,X
e13a: cc 00 06        LDD    #$0006
e13d: 34 76           PSHS   U,Y,X,D
e13f: 17 77 a8        LBSR   $58EA
e142: 32 68           LEAS   $8,S
e144: 33 62           LEAU   $2,S
e146: c6 01           LDB    #$01
e148: 1d              SEX
e149: 1f 02           TFR    D,Y
e14b: c6 5d           LDB    #$5D
e14d: 1d              SEX
e14e: 1f 01           TFR    D,X
e150: cc 00 06        LDD    #$0006
e153: 34 76           PSHS   U,Y,X,D
e155: 17 77 92        LBSR   $58EA
e158: 32 68           LEAS   $8,S
e15a: be 3f b4        LDX    $3FB4
e15d: 16 00 4b        LBRA   $E1AB
e160: c6 49           LDB    #$49
e162: 1d              SEX
e163: 1f 03           TFR    D,U
e165: 10 8e 00 01     LDY    #$0001
e169: c6 49           LDB    #$49
e16b: 1d              SEX
e16c: 1f 01           TFR    D,X
e16e: c6 04           LDB    #$04
e170: 1d              SEX
e171: 34 76           PSHS   U,Y,X,D
e173: ce 00 01        LDU    #$0001
e176: 10 8e 00 0a     LDY    #$000A
e17a: 34 60           PSHS   U,Y
e17c: 17 4a b6        LBSR   $2C35
e17f: 32 6c           LEAS   $C,S
e181: 16 00 34        LBRA   $E1B8
e184: c6 58           LDB    #$58
e186: 1d              SEX
e187: 1f 03           TFR    D,U
e189: 10 8e 00 01     LDY    #$0001
e18d: c6 58           LDB    #$58
e18f: 1d              SEX
e190: 1f 01           TFR    D,X
e192: c6 02           LDB    #$02
e194: 1d              SEX
e195: 34 76           PSHS   U,Y,X,D
e197: ce 00 01        LDU    #$0001
e19a: 10 8e 00 0a     LDY    #$000A
e19e: 34 60           PSHS   U,Y
e1a0: 17 4a 92        LBSR   $2C35
e1a3: 32 6c           LEAS   $C,S
e1a5: 16 00 10        LBRA   $E1B8
e1a8: 16 00 0d        LBRA   $E1B8
e1ab: 8c 00 00        CMPX   #$0000
e1ae: 27 b0           BEQ    $E160
e1b0: 8c 00 01        CMPX   #$0001
e1b3: 27 cf           BEQ    $E184
e1b5: 16 00 00        LBRA   $E1B8
e1b8: 32 63           LEAS   $3,S
e1ba: 39              RTS
e1bb: fc 63 ac        LDD    $63AC
e1be: 17 9b 8f        LBSR   $7D50
e1c1: ce 41 a0        LDU    #$41A0
e1c4: c6 28           LDB    #$28
e1c6: 1d              SEX
e1c7: 1f 02           TFR    D,Y
e1c9: 5f              CLRB
e1ca: 1d              SEX
e1cb: 1f 01           TFR    D,X
e1cd: cc 00 06        LDD    #$0006
e1d0: 34 76           PSHS   U,Y,X,D
e1d2: 17 77 15        LBSR   $58EA
e1d5: 32 68           LEAS   $8,S
e1d7: ce 43 fc        LDU    #$43FC
e1da: c6 1a           LDB    #$1A
e1dc: 1d              SEX
e1dd: 1f 02           TFR    D,Y
e1df: c6 0e           LDB    #$0E
e1e1: 1d              SEX
e1e2: 1f 01           TFR    D,X
e1e4: cc 00 06        LDD    #$0006
e1e7: 34 76           PSHS   U,Y,X,D
e1e9: 17 76 fe        LBSR   $58EA
e1ec: 32 68           LEAS   $8,S
e1ee: ce 44 3e        LDU    #$443E
e1f1: c6 28           LDB    #$28
e1f3: 1d              SEX
e1f4: 1f 02           TFR    D,Y
e1f6: c6 40           LDB    #$40
e1f8: 1d              SEX
e1f9: 1f 01           TFR    D,X
e1fb: cc 00 06        LDD    #$0006
e1fe: 34 76           PSHS   U,Y,X,D
e200: 17 76 e7        LBSR   $58EA
e203: 32 68           LEAS   $8,S
e205: 5f              CLRB
e206: 4f              CLRA
e207: fd 3f b4        STD    $3FB4
e20a: 5f              CLRB
e20b: 4f              CLRA
e20c: fd 3f c8        STD    $3FC8
e20f: c6 49           LDB    #$49
e211: 1d              SEX
e212: 1f 03           TFR    D,U
e214: 10 8e 00 01     LDY    #$0001
e218: c6 49           LDB    #$49
e21a: 1d              SEX
e21b: 1f 01           TFR    D,X
e21d: c6 04           LDB    #$04
e21f: 1d              SEX
e220: 34 76           PSHS   U,Y,X,D
e222: ce 00 01        LDU    #$0001
e225: 10 8e 00 0a     LDY    #$000A
e229: 34 60           PSHS   U,Y
e22b: 17 4a 07        LBSR   $2C35
e22e: 32 6c           LEAS   $C,S
e230: cc 5f 96        LDD    #$5F96
e233: fd 22 0f        STD    $220F
e236: f6 24 7b        LDB    $247B
e239: f7 3f cb        STB    $3FCB
e23c: ce 00 00        LDU    #$0000
e23f: 10 8e 00 02     LDY    #$0002
e243: 34 60           PSHS   U,Y
e245: 17 28 88        LBSR   $0AD0
e248: 32 64           LEAS   $4,S
e24a: 32 62           LEAS   $2,S
e24c: 39              RTS
e24d: 62 75           XNC    -$B,S
e24f: 66 6c           ROR    $C,S
e251: 61 74           NEG    -$C,S
e253: 30 00           LEAX   $0,X
e255: 62 75           XNC    -$B,S
e257: 66 6c           ROR    $C,S
e259: 61 74           NEG    -$C,S
e25b: 31 00           LEAY   $0,X
e25d: 62 75           XNC    -$B,S
e25f: 66 6c           ROR    $C,S
e261: 61 74           NEG    -$C,S
e263: 32 00           LEAS   $0,X
e265: 62 75           XNC    -$B,S
e267: 66 6c           ROR    $C,S
e269: 61 74           NEG    -$C,S
e26b: 33 00           LEAU   $0,X
e26d: 62 75           XNC    -$B,S
e26f: 66 6c           ROR    $C,S
e271: 61 74           NEG    -$C,S
e273: 34 00           PSHS   
e275: 62 75           XNC    -$B,S
e277: 66 6c           ROR    $C,S
e279: 61 74           NEG    -$C,S
e27b: 35 00           PULS   
e27d: 62 75           XNC    -$B,S
e27f: 66 6c           ROR    $C,S
e281: 61 74           NEG    -$C,S
e283: 36 00           PSHU   
e285: 62 75           XNC    -$B,S
e287: 66 6c           ROR    $C,S
e289: 61 74           NEG    -$C,S
e28b: 37 00           PULU   
e28d: 20 66           BRA    $E2F5
e28f: 72 65 71        XNC    $6571
e292: 5f              CLRB
e293: 61 00           NEG    $0,X
e295: 20 66           BRA    $E2FD
e297: 72 65 71        XNC    $6571
e29a: 5f              CLRB
e29b: 62 00           XNC    $0,X
e29d: 20 66           BRA    $E305
e29f: 72 65 71        XNC    $6571
e2a2: 5f              CLRB
e2a3: 63 00           COM    $0,X
e2a5: 20 66           BRA    $E30D
e2a7: 72 65 71        XNC    $6571
e2aa: 5f              CLRB
e2ab: 64 00           LSR    $0,X
e2ad: 6c 65           INC    $5,S
e2af: 76 65 6c        ROR    $656C
e2b2: 5f              CLRB
e2b3: 61 00           NEG    $0,X
e2b5: 6c 65           INC    $5,S
e2b7: 76 65 6c        ROR    $656C
e2ba: 5f              CLRB
e2bb: 62 00           XNC    $0,X
e2bd: 6c 65           INC    $5,S
e2bf: 76 65 6c        ROR    $656C
e2c2: 5f              CLRB
e2c3: 63 00           COM    $0,X
e2c5: 6c 65           INC    $5,S
e2c7: 76 65 6c        ROR    $656C
e2ca: 5f              CLRB
e2cb: 64 00           LSR    $0,X
e2cd: 70 68 61        NEG    $6861
e2d0: 73 65 5f        COM    $655F
e2d3: 61 00           NEG    $0,X
e2d5: 70 68 61        NEG    $6861
e2d8: 73 65 5f        COM    $655F
e2db: 62 00           XNC    $0,X
e2dd: 70 68 61        NEG    $6861
e2e0: 73 65 5f        COM    $655F
e2e3: 63 00           COM    $0,X
e2e5: 70 68 61        NEG    $6861
e2e8: 73 65 5f        COM    $655F
e2eb: 64 00           LSR    $0,X
e2ed: 72 61 6d        XNC    $616D
e2f0: 5f              CLRB
e2f1: 77 72 74        ASR    $7274
e2f4: 00 72           NEG    <$72
e2f6: 61 6d           NEG    $D,S
e2f8: 5f              CLRB
e2f9: 61 64           NEG    $4,S
e2fb: 64 00           LSR    $0,X
e2fd: 66 6d           ROR    $D,S
e2ff: 5f              CLRB
e300: 72 61 6e        XNC    $616E
e303: 67 00           ASR    $0,X
e305: 70 68 73        NEG    $6873
e308: 5f              CLRB
e309: 63 6e           COM    $E,S
e30b: 74 00 70        LSR    >$0070
e30e: 75 6c 73        LSR    $6C73
e311: 65 5f           LSR    -$1,U
e313: 63 00           COM    $0,X
e315: 61 6d           NEG    $D,S
e317: 5f              CLRB
e318: 63 6f           COM    $F,S
e31a: 6e 74           JMP    -$C,S
e31c: 00 66           NEG    <$66
e31e: 6d 5f           TST    -$1,U
e320: 63 6f           COM    $F,S
e322: 6e 74           JMP    -$C,S
e324: 00 66           NEG    <$66
e326: 72 65 71        XNC    $6571
e329: 5f              CLRB
e32a: 63 74           COM    -$C,S
e32c: 00 7a           NEG    <$7A
e32e: 65 72           LSR    -$E,S
e330: 6f 5f           CLR    -$1,U
e332: 6c 74           INC    -$C,S
e334: 00 77           NEG    <$77
e336: 61 76           NEG    -$A,S
e338: 65 66           LSR    $6,S
e33a: 6d 31           TST    -$F,Y
e33c: 00 77           NEG    <$77
e33e: 61 76           NEG    -$A,S
e340: 65 66           LSR    $6,S
e342: 6d 32           TST    -$E,Y
e344: 00 63           NEG    <$63
e346: 68 61           ASL    $1,S
e348: 6e 61           JMP    $1,S
e34a: 64 64           LSR    $4,S
e34c: 00 6f           NEG    <$6F
e34e: 75 74 5f        LSR    $745F
e351: 6d 75           TST    -$B,S
e353: 78 00 6f        ASL    >$006F
e356: 75 74 5f        LSR    $745F
e359: 6c 61           INC    $1,S
e35b: 74 00 6f        LSR    >$006F
e35e: 75 74 63        LSR    $7463
e361: 6c 6b           INC    $B,S
e363: 31 00           LEAY   $0,X
e365: 6f 75           CLR    -$B,S
e367: 74 63 6c        LSR    $636C
e36a: 6b 32           XDEC   -$E,Y
e36c: 00 63           NEG    <$63
e36e: 6c 6b           INC    $B,S
e370: 64 69           LSR    $9,S
e372: 76 31 00        ROR    $3100
e375: 63 6c           COM    $C,S
e377: 6b 64           XDEC   $4,S
e379: 69 76           ROL    -$A,S
e37b: 32 00           LEAS   $0,X
e37d: 63 6f           COM    $F,S
e37f: 6e 66           JMP    $6,S
e381: 69 67           ROL    $7,S
e383: 72 00 70        XNC    >$0070
e386: 6c 6c           INC    $C,S
e388: 5f              CLRB
e389: 64 69           LSR    $9,S
e38b: 76 00 73        ROR    >$0073
e38e: 79 6e 63        ROL    $6E63
e391: 73 65 6c        COM    $656C
e394: 00 73           NEG    <$73
e396: 79 6e 63        ROL    $6E63
e399: 5f              CLRB
e39a: 72 67 00        XNC    $6700
e39d: 69 6e           ROL    $E,S
e39f: 76 61 6c        ROR    $616C
e3a2: 69 64           ROL    $4,S
e3a4: 00 02           NEG    <$02
e3a6: 00 03           NEG    <$03
e3a8: 00 07           NEG    <$07
e3aa: 00 01           NEG    <$01
e3ac: 00 00           NEG    <$00
e3ae: 00 0f           NEG    <$0F
e3b0: 00 04           NEG    <$04
e3b2: 00 01           NEG    <$01
e3b4: 20 53           BRA    $E409
e3b6: 70 65 63        NEG    $6563
e3b9: 69 61           ROL    $1,S
e3bb: 6c 20           INC    $0,Y
e3bd: 23 20           BLS    $E3DF
e3bf: 20 20           BRA    $E3E1
e3c1: 20 00           BRA    $E3C3
e3c3: 02 20           XNC    <$20
e3c5: 53              COMB
e3c6: 74 61 74        LSR    $6174
e3c9: 75 73 20        LSR    $7320
e3cc: 3d              MUL
e3cd: 20 20           BRA    $E3EF
e3cf: 20 20           BRA    $E3F1
e3d1: 20 20           BRA    $E3F3
e3d3: 00 04           NEG    <$04
e3d5: 20 45           BRA    $E41C
e3d7: 78 69 74        ASL    $6974
e3da: 23 20           BLS    $E3FC
e3dc: 30 20           LEAX   $0,Y
e3de: 20 4c           BRA    $E42C
e3e0: 61 73           NEG    -$D,S
e3e2: 74 20 73        LSR    $2073
e3e5: 74 61 74        LSR    $6174
e3e8: 65 20           LSR    $0,Y
e3ea: 72 65 63        XNC    $6563
e3ed: 61 6c           NEG    $C,S
e3ef: 6c 65           INC    $5,S
e3f1: 64 20           LSR    $0,Y
e3f3: 6f 6e           CLR    $E,S
e3f5: 20 70           BRA    $E467
e3f7: 6f 77           CLR    -$9,S
e3f9: 65 72           LSR    -$E,S
e3fb: 20 75           BRA    $E472
e3fd: 70 20 20        NEG    $2020
e400: 20 20           BRA    $E422
e402: 23 20           BLS    $E424
e404: 31 20           LEAY   $0,Y
e406: 20 44           BRA    $E44C
e408: 69 73           ROL    -$D,S
e40a: 61 62           NEG    $2,S
e40c: 6c 65           INC    $5,S
e40e: 20 61           BRA    $E471
e410: 75 74 6f        LSR    $746F
e413: 6d 61           TST    $1,S
e415: 74 69 63        LSR    $6963
e418: 20 70           BRA    $E48A
e41a: 68 61           ASL    $1,S
e41c: 73 65 20        COM    $6520
e41f: 72 65 73        XNC    $6573
e422: 65 74           LSR    -$C,S
e424: 20 20           BRA    $E446
e426: 20 20           BRA    $E448
e428: 20 20           BRA    $E44A
e42a: 23 20           BLS    $E44C
e42c: 32 20           LEAS   $0,Y
e42e: 20 44           BRA    $E474
e430: 69 73           ROL    -$D,S
e432: 61 62           NEG    $2,S
e434: 6c 65           INC    $5,S
e436: 20 62           BRA    $E49A
e438: 65 65           LSR    $5,S
e43a: 70 65 72        NEG    $6572
e43d: 20 20           BRA    $E45F
e43f: 20 20           BRA    $E461
e441: 20 20           BRA    $E463
e443: 20 20           BRA    $E465
e445: 20 20           BRA    $E467
e447: 20 20           BRA    $E469
e449: 20 20           BRA    $E46B
e44b: 20 20           BRA    $E46D
e44d: 20 20           BRA    $E46F
e44f: 20 20           BRA    $E471
e451: 20 23           BRA    $E476
e453: 20 33           BRA    $E488
e455: 20 20           BRA    $E477
e457: 52              XNCB
e458: 65 76           LSR    -$A,S
e45a: 65 72           LSR    -$E,S
e45c: 73 65 20        COM    $6520
e45f: 6d 6f           TST    $F,S
e461: 64 75           LSR    -$B,S
e463: 6c 61           INC    $1,S
e465: 74 69 6e        LSR    $696E
e468: 67 20           ASR    $0,Y
e46a: 77 61 76        ASR    $6176
e46d: 65 66           LSR    $6,S
e46f: 6f 72           CLR    -$E,S
e471: 6d 73           TST    -$D,S
e473: 20 20           BRA    $E495
e475: 20 20           BRA    $E497
e477: 20 20           BRA    $E499
e479: 20 23           BRA    $E49E
e47b: 20 34           BRA    $E4B1
e47d: 20 20           BRA    $E49F
e47f: 44              LSRA
e480: 69 73           ROL    -$D,S
e482: 61 62           NEG    $2,S
e484: 6c 65           INC    $5,S
e486: 20 6f           BRA    $E4F7
e488: 75 74 70        LSR    $7470
e48b: 75 74 20        LSR    $7420
e48e: 62 6c           XNC    $C,S
e490: 61 6e           NEG    $E,S
e492: 6b 69           XDEC   $9,S
e494: 6e 67           JMP    $7,S
e496: 20 20           BRA    $E4B8
e498: 20 20           BRA    $E4BA
e49a: 20 20           BRA    $E4BC
e49c: 20 20           BRA    $E4BE
e49e: 20 20           BRA    $E4C0
e4a0: 20 20           BRA    $E4C2
e4a2: 23 20           BLS    $E4C4
e4a4: 35 20           PULS   Y
e4a6: 20 20           BRA    $E4C8
e4a8: 20 20           BRA    $E4CA
e4aa: 20 20           BRA    $E4CC
e4ac: 20 20           BRA    $E4CE
e4ae: 20 20           BRA    $E4D0
e4b0: 20 20           BRA    $E4D2
e4b2: 20 20           BRA    $E4D4
e4b4: 20 20           BRA    $E4D6
e4b6: 20 20           BRA    $E4D8
e4b8: 20 20           BRA    $E4DA
e4ba: 20 20           BRA    $E4DC
e4bc: 20 20           BRA    $E4DE
e4be: 20 20           BRA    $E4E0
e4c0: 20 20           BRA    $E4E2
e4c2: 20 20           BRA    $E4E4
e4c4: 20 20           BRA    $E4E6
e4c6: 20 20           BRA    $E4E8
e4c8: 20 20           BRA    $E4EA
e4ca: 23 20           BLS    $E4EC
e4cc: 36 20           PSHU   Y
e4ce: 20 20           BRA    $E4F0
e4d0: 20 20           BRA    $E4F2
e4d2: 20 20           BRA    $E4F4
e4d4: 20 20           BRA    $E4F6
e4d6: 20 20           BRA    $E4F8
e4d8: 20 20           BRA    $E4FA
e4da: 20 20           BRA    $E4FC
e4dc: 20 20           BRA    $E4FE
e4de: 20 20           BRA    $E500
e4e0: 20 20           BRA    $E502
e4e2: 20 20           BRA    $E504
e4e4: 20 20           BRA    $E506
e4e6: 20 20           BRA    $E508
e4e8: 20 20           BRA    $E50A
e4ea: 20 20           BRA    $E50C
e4ec: 20 20           BRA    $E50E
e4ee: 20 20           BRA    $E510
e4f0: 20 20           BRA    $E512
e4f2: 23 20           BLS    $E514
e4f4: 37 20           PULU   Y
e4f6: 20 20           BRA    $E518
e4f8: 20 20           BRA    $E51A
e4fa: 20 20           BRA    $E51C
e4fc: 20 20           BRA    $E51E
e4fe: 20 20           BRA    $E520
e500: 20 20           BRA    $E522
e502: 20 20           BRA    $E524
e504: 20 20           BRA    $E526
e506: 20 20           BRA    $E528
e508: 20 20           BRA    $E52A
e50a: 20 20           BRA    $E52C
e50c: 20 20           BRA    $E52E
e50e: 20 20           BRA    $E530
e510: 20 20           BRA    $E532
e512: 20 20           BRA    $E534
e514: 20 20           BRA    $E536
e516: 20 20           BRA    $E538
e518: 20 20           BRA    $E53A
e51a: 23 20           BLS    $E53C
e51c: 38 20           XANDCC #$20
e51e: 20 20           BRA    $E540
e520: 20 20           BRA    $E542
e522: 20 20           BRA    $E544
e524: 20 20           BRA    $E546
e526: 20 20           BRA    $E548
e528: 20 20           BRA    $E54A
e52a: 20 20           BRA    $E54C
e52c: 20 20           BRA    $E54E
e52e: 20 20           BRA    $E550
e530: 20 20           BRA    $E552
e532: 20 20           BRA    $E554
e534: 20 20           BRA    $E556
e536: 20 20           BRA    $E558
e538: 20 20           BRA    $E55A
e53a: 20 20           BRA    $E55C
e53c: 20 20           BRA    $E55E
e53e: 20 20           BRA    $E560
e540: 20 20           BRA    $E562
e542: 23 20           BLS    $E564
e544: 39              RTS
e545: 20 20           BRA    $E567
e547: 20 20           BRA    $E569
e549: 20 20           BRA    $E56B
e54b: 20 20           BRA    $E56D
e54d: 20 20           BRA    $E56F
e54f: 20 20           BRA    $E571
e551: 20 20           BRA    $E573
e553: 20 20           BRA    $E575
e555: 20 20           BRA    $E577
e557: 20 20           BRA    $E579
e559: 20 20           BRA    $E57B
e55b: 20 20           BRA    $E57D
e55d: 20 20           BRA    $E57F
e55f: 20 20           BRA    $E581
e561: 20 20           BRA    $E583
e563: 20 20           BRA    $E585
e565: 20 20           BRA    $E587
e567: 20 20           BRA    $E589
e569: 20 23           BRA    $E58E
e56b: 31 30           LEAY   -$10,Y
e56d: 20 20           BRA    $E58F
e56f: 20 20           BRA    $E591
e571: 20 20           BRA    $E593
e573: 20 20           BRA    $E595
e575: 20 20           BRA    $E597
e577: 20 20           BRA    $E599
e579: 20 20           BRA    $E59B
e57b: 20 20           BRA    $E59D
e57d: 20 20           BRA    $E59F
e57f: 20 20           BRA    $E5A1
e581: 20 20           BRA    $E5A3
e583: 20 20           BRA    $E5A5
e585: 20 20           BRA    $E5A7
e587: 20 20           BRA    $E5A9
e589: 20 20           BRA    $E5AB
e58b: 20 20           BRA    $E5AD
e58d: 20 20           BRA    $E5AF
e58f: 20 20           BRA    $E5B1
e591: 20 23           BRA    $E5B6
e593: 31 31           LEAY   -$F,Y
e595: 20 20           BRA    $E5B7
e597: 20 20           BRA    $E5B9
e599: 20 20           BRA    $E5BB
e59b: 20 20           BRA    $E5BD
e59d: 20 20           BRA    $E5BF
e59f: 20 20           BRA    $E5C1
e5a1: 20 20           BRA    $E5C3
e5a3: 20 20           BRA    $E5C5
e5a5: 20 20           BRA    $E5C7
e5a7: 20 20           BRA    $E5C9
e5a9: 20 20           BRA    $E5CB
e5ab: 20 20           BRA    $E5CD
e5ad: 20 20           BRA    $E5CF
e5af: 20 20           BRA    $E5D1
e5b1: 20 20           BRA    $E5D3
e5b3: 20 20           BRA    $E5D5
e5b5: 20 20           BRA    $E5D7
e5b7: 20 20           BRA    $E5D9
e5b9: 20 23           BRA    $E5DE
e5bb: 31 32           LEAY   -$E,Y
e5bd: 20 20           BRA    $E5DF
e5bf: 20 20           BRA    $E5E1
e5c1: 20 20           BRA    $E5E3
e5c3: 20 20           BRA    $E5E5
e5c5: 20 20           BRA    $E5E7
e5c7: 20 20           BRA    $E5E9
e5c9: 20 20           BRA    $E5EB
e5cb: 20 20           BRA    $E5ED
e5cd: 20 20           BRA    $E5EF
e5cf: 20 20           BRA    $E5F1
e5d1: 20 20           BRA    $E5F3
e5d3: 20 20           BRA    $E5F5
e5d5: 20 20           BRA    $E5F7
e5d7: 20 20           BRA    $E5F9
e5d9: 20 20           BRA    $E5FB
e5db: 20 20           BRA    $E5FD
e5dd: 20 20           BRA    $E5FF
e5df: 20 20           BRA    $E601
e5e1: 20 23           BRA    $E606
e5e3: 31 33           LEAY   -$D,Y
e5e5: 20 20           BRA    $E607
e5e7: 20 20           BRA    $E609
e5e9: 20 20           BRA    $E60B
e5eb: 20 20           BRA    $E60D
e5ed: 20 20           BRA    $E60F
e5ef: 20 20           BRA    $E611
e5f1: 20 20           BRA    $E613
e5f3: 20 20           BRA    $E615
e5f5: 20 20           BRA    $E617
e5f7: 20 20           BRA    $E619
e5f9: 20 20           BRA    $E61B
e5fb: 20 20           BRA    $E61D
e5fd: 20 20           BRA    $E61F
e5ff: 20 20           BRA    $E621
e601: 20 20           BRA    $E623
e603: 20 20           BRA    $E625
e605: 20 20           BRA    $E627
e607: 20 20           BRA    $E629
e609: 20 23           BRA    $E62E
e60b: 31 34           LEAY   -$C,Y
e60d: 20 20           BRA    $E62F
e60f: 20 20           BRA    $E631
e611: 20 20           BRA    $E633
e613: 20 20           BRA    $E635
e615: 20 20           BRA    $E637
e617: 20 20           BRA    $E639
e619: 20 20           BRA    $E63B
e61b: 20 20           BRA    $E63D
e61d: 20 20           BRA    $E63F
e61f: 20 20           BRA    $E641
e621: 20 20           BRA    $E643
e623: 20 20           BRA    $E645
e625: 20 20           BRA    $E647
e627: 20 20           BRA    $E649
e629: 20 20           BRA    $E64B
e62b: 20 20           BRA    $E64D
e62d: 20 20           BRA    $E64F
e62f: 20 20           BRA    $E651
e631: 20 23           BRA    $E656
e633: 31 35           LEAY   -$B,Y
e635: 20 20           BRA    $E657
e637: 20 20           BRA    $E659
e639: 20 20           BRA    $E65B
e63b: 20 20           BRA    $E65D
e63d: 20 20           BRA    $E65F
e63f: 20 20           BRA    $E661
e641: 20 20           BRA    $E663
e643: 20 20           BRA    $E665
e645: 20 20           BRA    $E667
e647: 20 20           BRA    $E669
e649: 20 20           BRA    $E66B
e64b: 20 20           BRA    $E66D
e64d: 20 20           BRA    $E66F
e64f: 20 20           BRA    $E671
e651: 20 20           BRA    $E673
e653: 20 20           BRA    $E675
e655: 20 20           BRA    $E677
e657: 20 20           BRA    $E679
e659: 20 2a           BRA    $E685
e65b: 2a 2a           BPL    $E687
e65d: 2a 20           BPL    $E67F
e65f: 20 4f           BRA    $E6B0
e661: 70 74 69        NEG    $7469
e664: 6f 6e           CLR    $E,S
e666: 20 46           BRA    $E6AE
e668: 69 72           ROL    -$E,S
e66a: 6d 77           TST    -$9,S
e66c: 61 72           NEG    -$E,S
e66e: 65 20           LSR    $0,Y
e670: 49              ROLA
e671: 6e 73           JMP    -$D,S
e673: 74 61 6c        LSR    $616C
e676: 6c 61           INC    $1,S
e678: 74 69 6f        LSR    $696F
e67b: 6e 20           JMP    $0,Y
e67d: 20 2a           BRA    $E6A9
e67f: 2a 2a           BPL    $E6AB
e681: 2a 45           BPL    $E6C8
e683: 6e 74           JMP    -$C,S
e685: 65 72           LSR    -$E,S
e687: 20 69           BRA    $E6F2
e689: 6e 73           JMP    -$D,S
e68b: 74 61 6c        LSR    $616C
e68e: 6c 61           INC    $1,S
e690: 74 69 6f        LSR    $696F
e693: 6e 20           JMP    $0,Y
e695: 63 6f           COM    $F,S
e697: 64 65           LSR    $5,S
e699: 3a              ABX
e69a: 20 20           BRA    $E6BC
e69c: 20 20           BRA    $E6BE
e69e: 20 20           BRA    $E6C0
e6a0: 20 20           BRA    $E6C2
e6a2: 20 00           BRA    $E6A4
e6a4: 04 20           LSR    <$20
e6a6: 45              LSRA
e6a7: 78 69 74        ASL    $6974
e6aa: 54              LSRB
e6ab: 68 65           ASL    $5,S
e6ad: 20 70           BRA    $E71F
e6af: 72 65 73        XNC    $6573
e6b2: 65 6e           LSR    $E,S
e6b4: 74 6c 79        LSR    $6C79
e6b7: 20 69           BRA    $E722
e6b9: 6e 73           JMP    -$D,S
e6bb: 74 61 6c        LSR    $616C
e6be: 6c 65           INC    $5,S
e6c0: 64 20           LSR    $0,Y
e6c2: 6f 70           CLR    -$10,S
e6c4: 74 69 6f        LSR    $696F
e6c7: 6e 73           JMP    -$D,S
e6c9: 20 61           BRA    $E72C
e6cb: 72 65 3a        XNC    $653A
e6ce: 20 20           BRA    $E6F0
e6d0: 20 20           BRA    $E6F2
e6d2: 2a 2a           BPL    $E6FE
e6d4: 2a 20           BPL    $E6F6
e6d6: 20 41           BRA    $E719
e6d8: 76 61 69        ROR    $6169
e6db: 6c 61           INC    $1,S
e6dd: 62 6c           XNC    $C,S
e6df: 65 20           LSR    $0,Y
e6e1: 46              RORA
e6e2: 69 72           ROL    -$E,S
e6e4: 6d 77           TST    -$9,S
e6e6: 61 72           NEG    -$E,S
e6e8: 65 20           LSR    $0,Y
e6ea: 4f              CLRA
e6eb: 70 74 69        NEG    $7469
e6ee: 6f 6e           CLR    $E,S
e6f0: 20 4c           BRA    $E73E
e6f2: 69 73           ROL    -$D,S
e6f4: 74 20 20        LSR    $2020
e6f7: 2a 2a           BPL    $E723
e6f9: 2a 41           BPL    $E73C
e6fb: 76 61 69        ROR    $6169
e6fe: 6c 61           INC    $1,S
e700: 62 6c           XNC    $C,S
e702: 65 20           LSR    $0,Y
e704: 6f 70           CLR    -$10,S
e706: 74 73 3a        LSR    $733A
e709: 20 54           BRA    $E75F
e70b: 75 72 6e        LSR    $726E
e70e: 20 6f           BRA    $E77F
e710: 66 66           ROR    $6,S
e712: 20 4c           BRA    $E760
e714: 49              ROLA
e715: 4e              XCLRA
e716: 45              LSRA
e717: 20 70           BRA    $E789
e719: 6f 77           CLR    -$9,S
e71b: 65 72           LSR    -$E,S
e71d: 20 74           BRA    $E793
e71f: 6f 20           CLR    $0,Y
e721: 69 6e           ROL    $E,S
e723: 76 6f 6b        ROR    $6F6B
e726: 65 20           LSR    $0,Y
e728: 6f 70           CLR    -$10,S
e72a: 74 69 6f        LSR    $696F
e72d: 6e 73           JMP    -$D,S
e72f: 21 21           BRN    $E752
e731: 20 4f           BRA    $E782
e733: 70 74 69        NEG    $7469
e736: 6f 6e           CLR    $E,S
e738: 20 69           BRA    $E7A3
e73a: 6e 73           JMP    -$D,S
e73c: 74 61 6c        LSR    $616C
e73f: 6c 61           INC    $1,S
e741: 74 69 6f        LSR    $696F
e744: 6e 20           JMP    $0,Y
e746: 6e 6f           JMP    $F,S
e748: 74 20 70        LSR    $2070
e74b: 65 72           LSR    -$E,S
e74d: 66 6f           ROR    $F,S
e74f: 72 6d 61        XNC    $6D61
e752: 62 6c           XNC    $C,S
e754: 65 2e           LSR    $E,Y
e756: 20 20           BRA    $E778
e758: 20 20           BRA    $E77A
e75a: 2a 2a           BPL    $E786
e75c: 2a 2a           BPL    $E788
e75e: 2a 20           BPL    $E780
e760: 20 53           BRA    $E7B5
e762: 65 72           LSR    -$E,S
e764: 69 61           ROL    $1,S
e766: 6c 20           INC    $0,Y
e768: 4e              XCLRA
e769: 75 6d 62        LSR    $6D62
e76c: 65 72           LSR    -$E,S
e76e: 20 49           BRA    $E7B9
e770: 6e 73           JMP    -$D,S
e772: 74 61 6c        LSR    $616C
e775: 6c 61           INC    $1,S
e777: 74 69 6f        LSR    $696F
e77a: 6e 20           JMP    $0,Y
e77c: 20 2a           BRA    $E7A8
e77e: 2a 2a           BPL    $E7AA
e780: 2a 2a           BPL    $E7AC
e782: 53              COMB
e783: 65 72           LSR    -$E,S
e785: 69 61           ROL    $1,S
e787: 6c 20           INC    $0,Y
e789: 6e 75           JMP    -$B,S
e78b: 6d 62           TST    $2,S
e78d: 65 72           LSR    -$E,S
e78f: 20 63           BRA    $E7F4
e791: 61 6e           NEG    $E,S
e793: 6e 6f           JMP    $F,S
e795: 74 20 62        LSR    $2062
e798: 65 20           LSR    $0,Y
e79a: 69 6e           ROL    $E,S
e79c: 73 74 61        COM    $7461
e79f: 6c 6c           INC    $C,S
e7a1: 65 64           LSR    $4,S
e7a3: 2e 20           BGT    $E7C5
e7a5: 20 20           BRA    $E7C7
e7a7: 20 20           BRA    $E7C9
e7a9: 20 45           BRA    $E7F0
e7ab: 6e 74           JMP    -$C,S
e7ad: 65 72           LSR    -$E,S
e7af: 20 35           BRA    $E7E6
e7b1: 20 64           BRA    $E817
e7b3: 69 67           ROL    $7,S
e7b5: 69 74           ROL    -$C,S
e7b7: 20 73           BRA    $E82C
e7b9: 65 72           LSR    -$E,S
e7bb: 69 61           ROL    $1,S
e7bd: 6c 20           INC    $0,Y
e7bf: 6e 75           JMP    -$B,S
e7c1: 6d 62           TST    $2,S
e7c3: 65 72           LSR    -$E,S
e7c5: 2e 20           BGT    $E7E7
e7c7: 53              COMB
e7c8: 2f 4e           BLE    $E818
e7ca: 3d              MUL
e7cb: 20 20           BRA    $E7ED
e7cd: 20 20           BRA    $E7EF
e7cf: 20 20           BRA    $E7F1
e7d1: 20 50           BRA    $E823
e7d3: 72 65 73        XNC    $6573
e7d6: 73 20 53        COM    $2053
e7d9: 48              ASLA
e7da: 49              ROLA
e7db: 46              RORA
e7dc: 54              LSRB
e7dd: 20 00           BRA    $E7DF
e7df: 02 20           XNC    <$20
e7e1: 74 6f 20        LSR    $6F20
e7e4: 69 6e           ROL    $E,S
e7e6: 73 74 61        COM    $7461
e7e9: 6c 6c           INC    $C,S
e7eb: 20 53           BRA    $E840
e7ed: 2f 4e           BLE    $E83D
e7ef: 20 3d           BRA    $E82E
e7f1: 20 20           BRA    $E813
e7f3: 20 20           BRA    $E815
e7f5: 20 20           BRA    $E817
e7f7: 2e 20           BGT    $E819
e7f9: 20 49           BRA    $E844
e7fb: 66 20           ROR    $0,Y
e7fd: 53              COMB
e7fe: 2f 4e           BLE    $E84E
e800: 20 69           BRA    $E86B
e802: 73 20 77        COM    $2077
e805: 72 6f 6e        XNC    $6F6E
e808: 67 20           ASR    $0,Y
e80a: 75 73 65        LSR    $7365
e80d: 20 00           BRA    $E80F
e80f: 03 20           COM    <$20
e811: 52              XNCB
e812: 65 65           LSR    $5,S
e814: 6e 74           JMP    -$C,S
e816: 65 72           LSR    -$E,S
e818: 20 20           BRA    $E83A
e81a: 00 04           NEG    <$04
e81c: 20 45           BRA    $E863
e81e: 78 69 74        ASL    $6974
e821: 2e 53           BGT    $E876
e823: 65 72           LSR    -$E,S
e825: 69 61           ROL    $1,S
e827: 6c 20           INC    $0,Y
e829: 4e              XCLRA
e82a: 75 6d 62        LSR    $6D62
e82d: 65 72           LSR    -$E,S
e82f: 20 53           BRA    $E884
e831: 2f 4e           BLE    $E881
e833: 20 3d           BRA    $E872
e835: 20 20           BRA    $E857
e837: 20 20           BRA    $E859
e839: 20 20           BRA    $E85B
e83b: 20 20           BRA    $E85D
e83d: 69 6e           ROL    $E,S
e83f: 73 74 61        COM    $7461
e842: 6c 6c           INC    $C,S
e844: 65 64           LSR    $4,S
e846: 2e 20           BGT    $E868
e848: 20 20           BRA    $E86A
e84a: 0a ae           DEC    <$AE
e84c: 60 01           NEG    $1,X
e84e: 00 00           NEG    <$00
e850: cc 00 06        LDD    #$0006
e853: 17 94 fa        LBSR   $7D50
e856: ae 6c           LDX    $C,S
e858: cc 00 00        LDD    #$0000
e85b: ed 64           STD    $4,S
e85d: e6 84           LDB    ,X
e85f: e7 62           STB    $2,S
e861: c6 08           LDB    #$08
e863: e7 63           STB    $3,S
e865: 4f              CLRA
e866: e6 65           LDB    $5,S
e868: 58              ASLB
e869: 58              ASLB
e86a: 89 00           ADCA   #$00
e86c: e6 64           LDB    $4,S
e86e: 57              ASRB
e86f: 89 00           ADCA   #$00
e871: 57              ASRB
e872: 57              ASRB
e873: 57              ASRB
e874: 89 00           ADCA   #$00
e876: 58              ASLB
e877: 89 00           ADCA   #$00
e879: 68 62           ASL    $2,S
e87b: 89 00           ADCA   #$00
e87d: 47              ASRA
e87e: 69 65           ROL    $5,S
e880: 69 64           ROL    $4,S
e882: 6a 63           DEC    $3,S
e884: 26 df           BNE    $E865
e886: ac 6e           CMPX   $E,S
e888: 27 04           BEQ    $E88E
e88a: 30 01           LEAX   $1,X
e88c: 20 cf           BRA    $E85D
e88e: ec 64           LDD    $4,S
e890: ed 66           STD    $6,S
e892: 32 68           LEAS   $8,S
e894: 39              RTS
e895: fc 73 36        LDD    $7336
e898: 17 94 b5        LBSR   $7D50
e89b: fc 22 04        LDD    $2204
e89e: 8a 00           ORA    #$00
e8a0: ca 10           ORB    #$10
e8a2: fd 22 04        STD    $2204
e8a5: ce 66 d2        LDU    #$66D2
e8a8: c6 28           LDB    #$28
e8aa: 1d              SEX
e8ab: 1f 02           TFR    D,Y
e8ad: 5f              CLRB
e8ae: 1d              SEX
e8af: 1f 01           TFR    D,X
e8b1: cc 00 06        LDD    #$0006
e8b4: 34 76           PSHS   U,Y,X,D
e8b6: 17 6f ec        LBSR   $58A5
e8b9: 32 68           LEAS   $8,S
e8bb: ce 66 fa        LDU    #$66FA
e8be: c6 10           LDB    #$10
e8c0: 1d              SEX
e8c1: 1f 02           TFR    D,Y
e8c3: c6 40           LDB    #$40
e8c5: 1d              SEX
e8c6: 1f 01           TFR    D,X
e8c8: cc 00 06        LDD    #$0006
e8cb: 34 76           PSHS   U,Y,X,D
e8cd: 17 6f d5        LBSR   $58A5
e8d0: 32 68           LEAS   $8,S
e8d2: ce 23 c5        LDU    #$23C5
e8d5: c6 18           LDB    #$18
e8d7: 1d              SEX
e8d8: 1f 02           TFR    D,Y
e8da: c6 50           LDB    #$50
e8dc: 1d              SEX
e8dd: 1f 01           TFR    D,X
e8df: cc 00 06        LDD    #$0006
e8e2: 34 76           PSHS   U,Y,X,D
e8e4: 17 6f be        LBSR   $58A5
e8e7: 32 68           LEAS   $8,S
e8e9: ce 1b 58        LDU    #$1B58
e8ec: 10 8e 00 02     LDY    #$0002
e8f0: 34 60           PSHS   U,Y
e8f2: 17 6d 7b        LBSR   $5670
e8f5: 32 64           LEAS   $4,S
e8f7: ce 00 00        LDU    #$0000
e8fa: 34 40           PSHS   U
e8fc: 17 70 c7        LBSR   $59C6
e8ff: 32 62           LEAS   $2,S
e901: 32 62           LEAS   $2,S
e903: 39              RTS
e904: fc 73 37        LDD    $7337
e907: 17 94 46        LBSR   $7D50
e90a: 30 64           LEAX   $4,S
e90c: af e8 1a        STX    $1A,S
e90f: fc 3f fe        LDD    $3FFE
e912: ed e8 18        STD    $18,S
e915: ec e9 00 22     LDD    $0022,S
e919: c3 00 01        ADDD   #$0001
e91c: e7 63           STB    $3,S
e91e: e6 63           LDB    $3,S
e920: c1 00           CMPB   #$00
e922: 10 23 00 36     LBLS   $E95C
e926: 6f 62           CLR    $2,S
e928: e6 62           LDB    $2,S
e92a: c1 14           CMPB   #$14
e92c: 10 24 00 12     LBCC   $E942
e930: 30 64           LEAX   $4,S
e932: e6 62           LDB    $2,S
e934: 3a              ABX
e935: ec e8 18        LDD    $18,S
e938: ed 84           STD    ,X
e93a: e6 62           LDB    $2,S
e93c: cb 02           ADDB   #$02
e93e: e7 62           STB    $2,S
e940: 20 e6           BRA    $E928
e942: 33 e8 17        LEAU   $17,S
e945: 31 64           LEAY   $4,S
e947: 8e 00 04        LDX    #$0004
e94a: 34 70           PSHS   U,Y,X
e94c: 17 ff 01        LBSR   $E850
e94f: 32 66           LEAS   $6,S
e951: ed e8 18        STD    $18,S
e954: e6 63           LDB    $3,S
e956: c0 01           SUBB   #$01
e958: e7 63           STB    $3,S
e95a: 20 c2           BRA    $E91E
e95c: ec e8 18        LDD    $18,S
e95f: ed e8 1c        STD    $1C,S
e962: 32 e8 1e        LEAS   $1E,S
e965: 39              RTS
e966: fc 73 40        LDD    $7340
e969: 17 93 e4        LBSR   $7D50
e96c: cc 00 01        LDD    #$0001
e96f: ed 66           STD    $6,S
e971: ce 63 b2        LDU    #$63B2
e974: c6 28           LDB    #$28
e976: 1d              SEX
e977: 1f 02           TFR    D,Y
e979: 5f              CLRB
e97a: 1d              SEX
e97b: 1f 01           TFR    D,X
e97d: cc 00 06        LDD    #$0006
e980: 34 76           PSHS   U,Y,X,D
e982: 17 6f 20        LBSR   $58A5
e985: 32 68           LEAS   $8,S
e987: ce 24 14        LDU    #$2414
e98a: f6 3f cd        LDB    $3FCD
e98d: 4f              CLRA
e98e: 1f 02           TFR    D,Y
e990: 8e 00 04        LDX    #$0004
e993: 34 70           PSHS   U,Y,X
e995: 17 60 39        LBSR   $49D1
e998: 32 66           LEAS   $6,S
e99a: ce 24 14        LDU    #$2414
e99d: c6 02           LDB    #$02
e99f: 1d              SEX
e9a0: 1f 02           TFR    D,Y
e9a2: 8e 00 04        LDX    #$0004
e9a5: 34 70           PSHS   U,Y,X
e9a7: 17 63 55        LBSR   $4CFF
e9aa: 32 66           LEAS   $6,S
e9ac: ce 24 15        LDU    #$2415
e9af: c6 02           LDB    #$02
e9b1: 1d              SEX
e9b2: 1f 02           TFR    D,Y
e9b4: c6 0c           LDB    #$0C
e9b6: 1d              SEX
e9b7: 1f 01           TFR    D,X
e9b9: cc 00 06        LDD    #$0006
e9bc: 34 76           PSHS   U,Y,X,D
e9be: 17 6e e4        LBSR   $58A5
e9c1: 32 68           LEAS   $8,S
e9c3: ae 66           LDX    $6,S
e9c5: f6 3f cd        LDB    $3FCD
e9c8: 17 95 d9        LBSR   $7FA4
e9cb: ed 66           STD    $6,S
e9cd: fc 23 c1        LDD    $23C1
e9d0: a4 66           ANDA   $6,S
e9d2: e4 67           ANDB   $7,S
e9d4: 10 83 00 00     CMPD   #$0000
e9d8: 10 27 00 08     LBEQ   $E9E4
e9dc: cc 73 39        LDD    #$7339
e9df: ed 64           STD    $4,S
e9e1: 16 00 05        LBRA   $E9E9
e9e4: cc 73 3d        LDD    #$733D
e9e7: ed 64           STD    $4,S
e9e9: ee 64           LDU    $4,S
e9eb: c6 03           LDB    #$03
e9ed: 1d              SEX
e9ee: 1f 02           TFR    D,Y
e9f0: c6 1c           LDB    #$1C
e9f2: 1d              SEX
e9f3: 1f 01           TFR    D,X
e9f5: cc 00 06        LDD    #$0006
e9f8: 34 76           PSHS   U,Y,X,D
e9fa: 17 6e a8        LBSR   $58A5
e9fd: 32 68           LEAS   $8,S
e9ff: c6 28           LDB    #$28
ea01: b6 3f cd        LDA    $3FCD
ea04: 3d              MUL
ea05: 8e 63 da        LDX    #$63DA
ea08: 30 8b           LEAX   D,X
ea0a: af 62           STX    $2,S
ea0c: ee 62           LDU    $2,S
ea0e: c6 28           LDB    #$28
ea10: 1d              SEX
ea11: 1f 02           TFR    D,Y
ea13: c6 40           LDB    #$40
ea15: 1d              SEX
ea16: 1f 01           TFR    D,X
ea18: cc 00 06        LDD    #$0006
ea1b: 34 76           PSHS   U,Y,X,D
ea1d: 17 6e 85        LBSR   $58A5
ea20: 32 68           LEAS   $8,S
ea22: 32 68           LEAS   $8,S
ea24: 39              RTS
ea25: fc 73 42        LDD    $7342
ea28: 17 93 25        LBSR   $7D50
ea2b: 6f 62           CLR    $2,S
ea2d: fc 22 04        LDD    $2204
ea30: 84 00           ANDA   #$00
ea32: c4 08           ANDB   #$08
ea34: 10 83 00 00     CMPD   #$0000
ea38: 10 27 00 0d     LBEQ   $EA49
ea3c: be 22 17        LDX    $2217
ea3f: 8c 00 23        CMPX   #$0023
ea42: 10 27 00 03     LBEQ   $EA49
ea46: 16 00 03        LBRA   $EA4C
ea49: 16 00 08        LBRA   $EA54
ea4c: c6 02           LDB    #$02
ea4e: f7 3f cc        STB    $3FCC
ea51: 16 01 d6        LBRA   $EC2A
ea54: be 22 17        LDX    $2217
ea57: 16 01 92        LBRA   $EBEC
ea5a: fc 22 04        LDD    $2204
ea5d: 84 00           ANDA   #$00
ea5f: c4 08           ANDB   #$08
ea61: 10 83 00 00     CMPD   #$0000
ea65: 10 27 00 5e     LBEQ   $EAC7
ea69: c6 02           LDB    #$02
ea6b: f7 3f cc        STB    $3FCC
ea6e: c6 03           LDB    #$03
ea70: 1d              SEX
ea71: 1f 03           TFR    D,U
ea73: 10 8e 00 00     LDY    #$0000
ea77: 8e 00 04        LDX    #$0004
ea7a: 34 70           PSHS   U,Y,X
ea7c: 17 63 62        LBSR   $4DE1
ea7f: 32 66           LEAS   $6,S
ea81: ce 22 1c        LDU    #$221C
ea84: 10 8e 24 14     LDY    #$2414
ea88: 8e 00 04        LDX    #$0004
ea8b: 34 70           PSHS   U,Y,X
ea8d: 17 60 80        LBSR   $4B10
ea90: 32 66           LEAS   $6,S
ea92: 33 65           LEAU   $5,S
ea94: 10 8e 22 1c     LDY    #$221C
ea98: 8e 68 4d        LDX    #$684D
ea9b: cc 00 06        LDD    #$0006
ea9e: 34 76           PSHS   U,Y,X,D
eaa0: 17 69 23        LBSR   $53C6
eaa3: 32 68           LEAS   $8,S
eaa5: c1 00           CMPB   #$00
eaa7: 10 27 00 13     LBEQ   $EABE
eaab: c6 12           LDB    #$12
eaad: 1d              SEX
eaae: 1f 03           TFR    D,U
eab0: 10 8e 00 02     LDY    #$0002
eab4: 34 60           PSHS   U,Y
eab6: 17 59 45        LBSR   $43FE
eab9: 32 64           LEAS   $4,S
eabb: 16 00 06        LBRA   $EAC4
eabe: fc 22 1d        LDD    $221D
eac1: fd 23 c1        STD    $23C1
eac4: 16 00 9c        LBRA   $EB63
eac7: f6 3f cc        LDB    $3FCC
eaca: c1 00           CMPB   #$00
eacc: 10 26 00 5b     LBNE   $EB2B
ead0: c6 03           LDB    #$03
ead2: 1d              SEX
ead3: 1f 03           TFR    D,U
ead5: 10 8e 00 02     LDY    #$0002
ead9: 34 60           PSHS   U,Y
eadb: 17 47 45        LBSR   $3223
eade: 32 64           LEAS   $4,S
eae0: 10 83 00 00     CMPD   #$0000
eae4: 10 27 00 33     LBEQ   $EB1B
eae8: ce 23 9a        LDU    #$239A
eaeb: 10 8e 00 02     LDY    #$0002
eaef: 34 60           PSHS   U,Y
eaf1: 17 5f 42        LBSR   $4A36
eaf4: 32 64           LEAS   $4,S
eaf6: e7 62           STB    $2,S
eaf8: e6 62           LDB    $2,S
eafa: c1 0f           CMPB   #$0F
eafc: 10 22 00 08     LBHI   $EB08
eb00: e6 62           LDB    $2,S
eb02: f7 3f cd        STB    $3FCD
eb05: 16 00 10        LBRA   $EB18
eb08: c6 11           LDB    #$11
eb0a: 1d              SEX
eb0b: 1f 03           TFR    D,U
eb0d: 10 8e 00 02     LDY    #$0002
eb11: 34 60           PSHS   U,Y
eb13: 17 58 e8        LBSR   $43FE
eb16: 32 64           LEAS   $4,S
eb18: 16 00 10        LBRA   $EB2B
eb1b: c6 11           LDB    #$11
eb1d: 1d              SEX
eb1e: 1f 03           TFR    D,U
eb20: 10 8e 00 02     LDY    #$0002
eb24: 34 60           PSHS   U,Y
eb26: 17 58 d5        LBSR   $43FE
eb29: 32 64           LEAS   $4,S
eb2b: f6 3f cc        LDB    $3FCC
eb2e: c1 01           CMPB   #$01
eb30: 10 26 00 2f     LBNE   $EB63
eb34: 8e 00 01        LDX    #$0001
eb37: f6 3f cd        LDB    $3FCD
eb3a: 17 94 67        LBSR   $7FA4
eb3d: ed 63           STD    $3,S
eb3f: be 22 1f        LDX    $221F
eb42: 8c 00 11        CMPX   #$0011
eb45: 10 26 00 0d     LBNE   $EB56
eb49: fc 23 c1        LDD    $23C1
eb4c: aa 63           ORA    $3,S
eb4e: ea 64           ORB    $4,S
eb50: fd 23 c1        STD    $23C1
eb53: 16 00 0d        LBRA   $EB63
eb56: ec 63           LDD    $3,S
eb58: 43              COMA
eb59: 53              COMB
eb5a: b4 23 c1        ANDA   $23C1
eb5d: f4 23 c2        ANDB   $23C2
eb60: fd 23 c1        STD    $23C1
eb63: 16 00 c4        LBRA   $EC2A
eb66: 7f 3f cc        CLR    $3FCC
eb69: 16 00 be        LBRA   $EC2A
eb6c: c6 01           LDB    #$01
eb6e: f7 3f cc        STB    $3FCC
eb71: 16 00 b6        LBRA   $EC2A
eb74: ce 00 00        LDU    #$0000
eb77: 34 40           PSHS   U
eb79: 17 58 9c        LBSR   $4418
eb7c: 32 62           LEAS   $2,S
eb7e: 16 00 a9        LBRA   $EC2A
eb81: f6 3f cd        LDB    $3FCD
eb84: c1 0f           CMPB   #$0F
eb86: 10 24 00 08     LBCC   $EB92
eb8a: f6 3f cd        LDB    $3FCD
eb8d: cb 01           ADDB   #$01
eb8f: f7 3f cd        STB    $3FCD
eb92: 16 00 95        LBRA   $EC2A
eb95: f6 3f cd        LDB    $3FCD
eb98: c1 00           CMPB   #$00
eb9a: 10 23 00 08     LBLS   $EBA6
eb9e: f6 3f cd        LDB    $3FCD
eba1: c0 01           SUBB   #$01
eba3: f7 3f cd        STB    $3FCD
eba6: 16 00 81        LBRA   $EC2A
eba9: fc 22 02        LDD    $2202
ebac: 84 04           ANDA   #$04
ebae: c4 00           ANDB   #$00
ebb0: 10 83 00 00     CMPD   #$0000
ebb4: 10 26 00 21     LBNE   $EBD9
ebb8: fc 22 02        LDD    $2202
ebbb: 84 08           ANDA   #$08
ebbd: c4 00           ANDB   #$00
ebbf: 10 83 00 00     CMPD   #$0000
ebc3: 10 26 00 12     LBNE   $EBD9
ebc7: fc 22 02        LDD    $2202
ebca: 84 00           ANDA   #$00
ebcc: c4 10           ANDB   #$10
ebce: 10 83 00 00     CMPD   #$0000
ebd2: 10 26 00 03     LBNE   $EBD9
ebd6: 16 00 0b        LBRA   $EBE4
ebd9: cc 00 05        LDD    #$0005
ebdc: fd 22 17        STD    $2217
ebdf: 6f 68           CLR    $8,S
ebe1: 16 01 7b        LBRA   $ED5F
ebe4: c6 02           LDB    #$02
ebe6: f7 3f cc        STB    $3FCC
ebe9: 16 00 3e        LBRA   $EC2A
ebec: 8c 00 10        CMPX   #$0010
ebef: 27 83           BEQ    $EB74
ebf1: 8c 00 13        CMPX   #$0013
ebf4: 10 27 ff 6e     LBEQ   $EB66
ebf8: 8c 00 14        CMPX   #$0014
ebfb: 10 27 ff 6d     LBEQ   $EB6C
ebff: 8c 00 16        CMPX   #$0016
ec02: 27 e0           BEQ    $EBE4
ec04: 8c 00 17        CMPX   #$0017
ec07: 10 27 ff 76     LBEQ   $EB81
ec0b: 8c 00 18        CMPX   #$0018
ec0e: 27 85           BEQ    $EB95
ec10: 8c 00 1f        CMPX   #$001F
ec13: 27 80           BEQ    $EB95
ec15: 8c 00 20        CMPX   #$0020
ec18: 10 27 ff 65     LBEQ   $EB81
ec1c: 8c 00 23        CMPX   #$0023
ec1f: 10 27 fe 37     LBEQ   $EA5A
ec23: 8c 00 26        CMPX   #$0026
ec26: 27 81           BEQ    $EBA9
ec28: 20 bf           BRA    $EBE9
ec2a: e6 62           LDB    $2,S
ec2c: c1 30           CMPB   #$30
ec2e: 10 26 00 12     LBNE   $EC44
ec32: fc 22 04        LDD    $2204
ec35: 84 00           ANDA   #$00
ec37: c4 08           ANDB   #$08
ec39: 10 83 00 00     CMPD   #$0000
ec3d: 10 26 00 03     LBNE   $EC44
ec41: 16 00 03        LBRA   $EC47
ec44: 16 00 0a        LBRA   $EC51
ec47: fc 22 02        LDD    $2202
ec4a: 8a 04           ORA    #$04
ec4c: ca 00           ORB    #$00
ec4e: fd 22 02        STD    $2202
ec51: e6 62           LDB    $2,S
ec53: c1 25           CMPB   #$25
ec55: 10 26 00 12     LBNE   $EC6B
ec59: fc 22 04        LDD    $2204
ec5c: 84 00           ANDA   #$00
ec5e: c4 08           ANDB   #$08
ec60: 10 83 00 00     CMPD   #$0000
ec64: 10 26 00 03     LBNE   $EC6B
ec68: 16 00 03        LBRA   $EC6E
ec6b: 16 00 0a        LBRA   $EC78
ec6e: fc 22 02        LDD    $2202
ec71: 8a 08           ORA    #$08
ec73: ca 00           ORB    #$00
ec75: fd 22 02        STD    $2202
ec78: e6 62           LDB    $2,S
ec7a: c1 57           CMPB   #$57
ec7c: 10 26 00 12     LBNE   $EC92
ec80: fc 22 04        LDD    $2204
ec83: 84 00           ANDA   #$00
ec85: c4 08           ANDB   #$08
ec87: 10 83 00 00     CMPD   #$0000
ec8b: 10 26 00 03     LBNE   $EC92
ec8f: 16 00 03        LBRA   $EC95
ec92: 16 00 0a        LBRA   $EC9F
ec95: fc 22 02        LDD    $2202
ec98: 8a 00           ORA    #$00
ec9a: ca 10           ORB    #$10
ec9c: fd 22 02        STD    $2202
ec9f: f6 3f cc        LDB    $3FCC
eca2: c1 00           CMPB   #$00
eca4: 10 26 00 2b     LBNE   $ECD3
eca8: ce 00 00        LDU    #$0000
ecab: 34 40           PSHS   U
ecad: 17 fc b6        LBSR   $E966
ecb0: 32 62           LEAS   $2,S
ecb2: c6 0c           LDB    #$0C
ecb4: 1d              SEX
ecb5: 1f 03           TFR    D,U
ecb7: 10 8e 00 02     LDY    #$0002
ecbb: c6 0c           LDB    #$0C
ecbd: 1d              SEX
ecbe: 1f 01           TFR    D,X
ecc0: c6 02           LDB    #$02
ecc2: 1d              SEX
ecc3: 34 76           PSHS   U,Y,X,D
ecc5: ce 00 00        LDU    #$0000
ecc8: 10 8e 00 0a     LDY    #$000A
eccc: 34 60           PSHS   U,Y
ecce: 17 3f 64        LBSR   $2C35
ecd1: 32 6c           LEAS   $C,S
ecd3: f6 3f cc        LDB    $3FCC
ecd6: c1 01           CMPB   #$01
ecd8: 10 26 00 2a     LBNE   $ED06
ecdc: ce 00 00        LDU    #$0000
ecdf: 34 40           PSHS   U
ece1: 17 fc 82        LBSR   $E966
ece4: 32 62           LEAS   $2,S
ece6: c6 1c           LDB    #$1C
ece8: 1d              SEX
ece9: 1f 03           TFR    D,U
eceb: 10 8e 00 00     LDY    #$0000
ecef: c6 1c           LDB    #$1C
ecf1: 1d              SEX
ecf2: 1f 01           TFR    D,X
ecf4: 5f              CLRB
ecf5: 1d              SEX
ecf6: 34 76           PSHS   U,Y,X,D
ecf8: ce 00 06        LDU    #$0006
ecfb: 10 8e 00 0a     LDY    #$000A
ecff: 34 60           PSHS   U,Y
ed01: 17 3f 31        LBSR   $2C35
ed04: 32 6c           LEAS   $C,S
ed06: f6 3f cc        LDB    $3FCC
ed09: c1 02           CMPB   #$02
ed0b: 10 26 00 4c     LBNE   $ED5B
ed0f: fc 22 04        LDD    $2204
ed12: 84 00           ANDA   #$00
ed14: c4 08           ANDB   #$08
ed16: 10 83 00 00     CMPD   #$0000
ed1a: 10 26 00 0a     LBNE   $ED28
ed1e: ce 00 00        LDU    #$0000
ed21: 34 40           PSHS   U
ed23: 17 6c a0        LBSR   $59C6
ed26: 32 62           LEAS   $2,S
ed28: fc 22 02        LDD    $2202
ed2b: 84 ff           ANDA   #$FF
ed2d: c4 f7           ANDB   #$F7
ed2f: fd 22 02        STD    $2202
ed32: fc 22 02        LDD    $2202
ed35: 84 f7           ANDA   #$F7
ed37: c4 ff           ANDB   #$FF
ed39: fd 22 02        STD    $2202
ed3c: fc 22 02        LDD    $2202
ed3f: 84 fb           ANDA   #$FB
ed41: c4 ff           ANDB   #$FF
ed43: fd 22 02        STD    $2202
ed46: fc 22 02        LDD    $2202
ed49: 84 ff           ANDA   #$FF
ed4b: c4 ef           ANDB   #$EF
ed4d: fd 22 02        STD    $2202
ed50: cc 00 0b        LDD    #$000B
ed53: fd 22 17        STD    $2217
ed56: 6f 68           CLR    $8,S
ed58: 16 00 04        LBRA   $ED5F
ed5b: c6 01           LDB    #$01
ed5d: e7 68           STB    $8,S
ed5f: e6 68           LDB    $8,S
ed61: 32 69           LEAS   $9,S
ed63: 39              RTS
ed64: fc 73 44        LDD    $7344
ed67: 17 8f e6        LBSR   $7D50
ed6a: c6 01           LDB    #$01
ed6c: e7 63           STB    $3,S
ed6e: 6f 64           CLR    $4,S
ed70: be 22 17        LDX    $2217
ed73: 8c 00 23        CMPX   #$0023
ed76: 10 26 00 e6     LBNE   $EE60
ed7a: c6 08           LDB    #$08
ed7c: 1d              SEX
ed7d: 1f 03           TFR    D,U
ed7f: 10 8e 00 02     LDY    #$0002
ed83: 34 60           PSHS   U,Y
ed85: 17 44 9b        LBSR   $3223
ed88: 32 64           LEAS   $4,S
ed8a: 10 83 00 00     CMPD   #$0000
ed8e: 10 27 00 ce     LBEQ   $EE60
ed92: ce 22 1c        LDU    #$221C
ed95: 10 8e 23 9a     LDY    #$239A
ed99: 8e 00 04        LDX    #$0004
ed9c: 34 70           PSHS   U,Y,X
ed9e: 17 5d 6f        LBSR   $4B10
eda1: 32 66           LEAS   $6,S
eda3: f6 22 1c        LDB    $221C
eda6: e7 62           STB    $2,S
eda8: e6 62           LDB    $2,S
edaa: c1 08           CMPB   #$08
edac: 10 24 00 34     LBCC   $EDE4
edb0: fc 22 1d        LDD    $221D
edb3: ed 65           STD    $5,S
edb5: e6 62           LDB    $2,S
edb7: 4f              CLRA
edb8: 1f 03           TFR    D,U
edba: 10 8e 00 02     LDY    #$0002
edbe: 34 60           PSHS   U,Y
edc0: 17 fb 41        LBSR   $E904
edc3: 32 64           LEAS   $4,S
edc5: ed 67           STD    $7,S
edc7: ae 67           LDX    $7,S
edc9: ac 65           CMPX   $5,S
edcb: 10 26 00 15     LBNE   $EDE4
edcf: a6 63           LDA    $3,S
edd1: e6 62           LDB    $2,S
edd3: 17 8f c8        LBSR   $7D9E
edd6: e7 63           STB    $3,S
edd8: f6 3f fc        LDB    $3FFC
eddb: ea 63           ORB    $3,S
eddd: f7 3f fc        STB    $3FFC
ede0: c6 01           LDB    #$01
ede2: e7 64           STB    $4,S
ede4: ce 00 00        LDU    #$0000
ede7: 34 40           PSHS   U
ede9: 17 12 14        LBSR   $0000
edec: 32 62           LEAS   $2,S
edee: ce 66 aa        LDU    #$66AA
edf1: c6 28           LDB    #$28
edf3: 1d              SEX
edf4: 1f 02           TFR    D,Y
edf6: 5f              CLRB
edf7: 1d              SEX
edf8: 1f 01           TFR    D,X
edfa: cc 00 06        LDD    #$0006
edfd: 34 76           PSHS   U,Y,X,D
edff: 17 6a a3        LBSR   $58A5
ee02: 32 68           LEAS   $8,S
ee04: ce 22 85        LDU    #$2285
ee07: c6 28           LDB    #$28
ee09: 1d              SEX
ee0a: 1f 02           TFR    D,Y
ee0c: c6 40           LDB    #$40
ee0e: 1d              SEX
ee0f: 1f 01           TFR    D,X
ee11: cc 00 06        LDD    #$0006
ee14: 34 76           PSHS   U,Y,X,D
ee16: 17 6a 8c        LBSR   $58A5
ee19: 32 68           LEAS   $8,S
ee1b: ce 1b 58        LDU    #$1B58
ee1e: 10 8e 00 02     LDY    #$0002
ee22: 34 60           PSHS   U,Y
ee24: 17 68 49        LBSR   $5670
ee27: 32 64           LEAS   $4,S
ee29: e6 64           LDB    $4,S
ee2b: c1 00           CMPB   #$00
ee2d: 10 27 00 2f     LBEQ   $EE60
ee31: ce 66 5a        LDU    #$665A
ee34: c6 28           LDB    #$28
ee36: 1d              SEX
ee37: 1f 02           TFR    D,Y
ee39: 5f              CLRB
ee3a: 1d              SEX
ee3b: 1f 01           TFR    D,X
ee3d: cc 00 06        LDD    #$0006
ee40: 34 76           PSHS   U,Y,X,D
ee42: 17 6a 60        LBSR   $58A5
ee45: 32 68           LEAS   $8,S
ee47: ce 67 0a        LDU    #$670A
ee4a: c6 28           LDB    #$28
ee4c: 1d              SEX
ee4d: 1f 02           TFR    D,Y
ee4f: c6 40           LDB    #$40
ee51: 1d              SEX
ee52: 1f 01           TFR    D,X
ee54: cc 00 06        LDD    #$0006
ee57: 34 76           PSHS   U,Y,X,D
ee59: 17 6a 49        LBSR   $58A5
ee5c: 32 68           LEAS   $8,S
ee5e: 20 fe           BRA    $EE5E
ee60: ce 00 00        LDU    #$0000
ee63: 34 40           PSHS   U
ee65: 17 6b 5e        LBSR   $59C6
ee68: 32 62           LEAS   $2,S
ee6a: fc 22 02        LDD    $2202
ee6d: 84 ff           ANDA   #$FF
ee6f: c4 f7           ANDB   #$F7
ee71: fd 22 02        STD    $2202
ee74: cc 00 0b        LDD    #$000B
ee77: fd 22 17        STD    $2217
ee7a: 6f 6c           CLR    $C,S
ee7c: e6 6c           LDB    $C,S
ee7e: 32 6d           LEAS   $D,S
ee80: 39              RTS
ee81: fc 73 36        LDD    $7336
ee84: 17 8e c9        LBSR   $7D50
ee87: fc 22 04        LDD    $2204
ee8a: 8a 00           ORA    #$00
ee8c: ca 10           ORB    #$10
ee8e: fd 22 04        STD    $2204
ee91: ce 66 5a        LDU    #$665A
ee94: c6 28           LDB    #$28
ee96: 1d              SEX
ee97: 1f 02           TFR    D,Y
ee99: 5f              CLRB
ee9a: 1d              SEX
ee9b: 1f 01           TFR    D,X
ee9d: cc 00 06        LDD    #$0006
eea0: 34 76           PSHS   U,Y,X,D
eea2: 17 6a 00        LBSR   $58A5
eea5: 32 68           LEAS   $8,S
eea7: ce 68 4a        LDU    #$684A
eeaa: 10 8e 3f fd     LDY    #$3FFD
eeae: c6 03           LDB    #$03
eeb0: 1d              SEX
eeb1: 1f 01           TFR    D,X
eeb3: cc 00 06        LDD    #$0006
eeb6: 34 76           PSHS   U,Y,X,D
eeb8: 17 53 87        LBSR   $4242
eebb: 32 68           LEAS   $8,S
eebd: c1 00           CMPB   #$00
eebf: 10 27 00 1f     LBEQ   $EEE2
eec3: ce ea 58        LDU    #$EA58
eec6: 10 8e 3f fd     LDY    #$3FFD
eeca: c6 03           LDB    #$03
eecc: 1d              SEX
eecd: 1f 01           TFR    D,X
eecf: cc 00 06        LDD    #$0006
eed2: 34 76           PSHS   U,Y,X,D
eed4: 17 53 6b        LBSR   $4242
eed7: 32 68           LEAS   $8,S
eed9: c1 00           CMPB   #$00
eedb: 10 27 00 03     LBEQ   $EEE2
eedf: 16 00 53        LBRA   $EF35
eee2: ce 67 32        LDU    #$6732
eee5: c6 28           LDB    #$28
eee7: 1d              SEX
eee8: 1f 02           TFR    D,Y
eeea: c6 40           LDB    #$40
eeec: 1d              SEX
eeed: 1f 01           TFR    D,X
eeef: cc 00 06        LDD    #$0006
eef2: 34 76           PSHS   U,Y,X,D
eef4: 17 69 ae        LBSR   $58A5
eef7: 32 68           LEAS   $8,S
eef9: ce 00 00        LDU    #$0000
eefc: 34 40           PSHS   U
eefe: 17 67 c7        LBSR   $56C8
ef01: 32 62           LEAS   $2,S
ef03: ce 13 88        LDU    #$1388
ef06: 10 8e 00 02     LDY    #$0002
ef0a: 34 60           PSHS   U,Y
ef0c: 17 67 61        LBSR   $5670
ef0f: 32 64           LEAS   $4,S
ef11: ce 00 00        LDU    #$0000
ef14: 34 40           PSHS   U
ef16: 17 6a ad        LBSR   $59C6
ef19: 32 62           LEAS   $2,S
ef1b: fc 22 02        LDD    $2202
ef1e: 84 ff           ANDA   #$FF
ef20: c4 f7           ANDB   #$F7
ef22: fd 22 02        STD    $2202
ef25: ce 00 00        LDU    #$0000
ef28: 34 40           PSHS   U
ef2a: 17 1c 1f        LBSR   $0B4C
ef2d: 32 62           LEAS   $2,S
ef2f: 16 00 4b        LBRA   $EF7D
ef32: 16 00 48        LBRA   $EF7D
ef35: ce 66 82        LDU    #$6682
ef38: c6 28           LDB    #$28
ef3a: 1d              SEX
ef3b: 1f 02           TFR    D,Y
ef3d: c6 40           LDB    #$40
ef3f: 1d              SEX
ef40: 1f 01           TFR    D,X
ef42: cc 00 06        LDD    #$0006
ef45: 34 76           PSHS   U,Y,X,D
ef47: 17 69 5b        LBSR   $58A5
ef4a: 32 68           LEAS   $8,S
ef4c: c6 59           LDB    #$59
ef4e: 1d              SEX
ef4f: 1f 03           TFR    D,U
ef51: 10 8e 00 02     LDY    #$0002
ef55: c6 59           LDB    #$59
ef57: 1d              SEX
ef58: 1f 01           TFR    D,X
ef5a: c6 06           LDB    #$06
ef5c: 1d              SEX
ef5d: 34 76           PSHS   U,Y,X,D
ef5f: ce 00 00        LDU    #$0000
ef62: 10 8e 00 0a     LDY    #$000A
ef66: 34 60           PSHS   U,Y
ef68: 17 3c ca        LBSR   $2C35
ef6b: 32 6c           LEAS   $C,S
ef6d: cc 6d 64        LDD    #$6D64
ef70: fd 22 0d        STD    $220D
ef73: fc 22 02        LDD    $2202
ef76: 8a 00           ORA    #$00
ef78: ca 08           ORB    #$08
ef7a: fd 22 02        STD    $2202
ef7d: 32 62           LEAS   $2,S
ef7f: 39              RTS
ef80: fc 73 46        LDD    $7346
ef83: 17 8d ca        LBSR   $7D50
ef86: 6f 62           CLR    $2,S
ef88: be 22 17        LDX    $2217
ef8b: 16 00 6e        LBRA   $EFFC
ef8e: f6 3f cc        LDB    $3FCC
ef91: c1 00           CMPB   #$00
ef93: 10 26 00 2e     LBNE   $EFC5
ef97: c6 08           LDB    #$08
ef99: 1d              SEX
ef9a: 1f 03           TFR    D,U
ef9c: 10 8e 00 02     LDY    #$0002
efa0: 34 60           PSHS   U,Y
efa2: 17 42 7e        LBSR   $3223
efa5: 32 64           LEAS   $4,S
efa7: 10 83 00 00     CMPD   #$0000
efab: 10 27 00 16     LBEQ   $EFC5
efaf: ce 3f ce        LDU    #$3FCE
efb2: 10 8e 23 9a     LDY    #$239A
efb6: 8e 00 04        LDX    #$0004
efb9: 34 70           PSHS   U,Y,X
efbb: 17 5b 52        LBSR   $4B10
efbe: 32 66           LEAS   $6,S
efc0: c6 01           LDB    #$01
efc2: f7 3f cc        STB    $3FCC
efc5: 16 00 4a        LBRA   $F012
efc8: 7f 3f cc        CLR    $3FCC
efcb: 16 00 44        LBRA   $F012
efce: f6 3f cc        LDB    $3FCC
efd1: c1 01           CMPB   #$01
efd3: 10 26 00 1a     LBNE   $EFF1
efd7: ce 3f ce        LDU    #$3FCE
efda: 10 8e 3f fd     LDY    #$3FFD
efde: 8e 00 04        LDX    #$0004
efe1: 34 70           PSHS   U,Y,X
efe3: 17 63 97        LBSR   $537D
efe6: 32 66           LEAS   $6,S
efe8: c6 02           LDB    #$02
efea: f7 3f cc        STB    $3FCC
efed: c6 01           LDB    #$01
efef: e7 62           STB    $2,S
eff1: 16 00 1e        LBRA   $F012
eff4: c6 02           LDB    #$02
eff6: f7 3f cc        STB    $3FCC
eff9: 16 00 16        LBRA   $F012
effc: 8c 00 15        CMPX   #$0015
efff: 27 c7           BEQ    $EFC8
f001: 8c 00 16        CMPX   #$0016
f004: 27 ee           BEQ    $EFF4
f006: 8c 00 23        CMPX   #$0023
f009: 27 83           BEQ    $EF8E
f00b: 8c 00 37        CMPX   #$0037
f00e: 27 be           BEQ    $EFCE
f010: 20 e7           BRA    $EFF9
f012: f6 3f cc        LDB    $3FCC
f015: c1 00           CMPB   #$00
f017: 10 26 00 4e     LBNE   $F069
f01b: ce 67 5a        LDU    #$675A
f01e: c6 28           LDB    #$28
f020: 1d              SEX
f021: 1f 02           TFR    D,Y
f023: 5f              CLRB
f024: 1d              SEX
f025: 1f 01           TFR    D,X
f027: cc 00 06        LDD    #$0006
f02a: 34 76           PSHS   U,Y,X,D
f02c: 17 68 76        LBSR   $58A5
f02f: 32 68           LEAS   $8,S
f031: ce 67 aa        LDU    #$67AA
f034: c6 28           LDB    #$28
f036: 1d              SEX
f037: 1f 02           TFR    D,Y
f039: c6 40           LDB    #$40
f03b: 1d              SEX
f03c: 1f 01           TFR    D,X
f03e: cc 00 06        LDD    #$0006
f041: 34 76           PSHS   U,Y,X,D
f043: 17 68 5f        LBSR   $58A5
f046: 32 68           LEAS   $8,S
f048: c6 62           LDB    #$62
f04a: 1d              SEX
f04b: 1f 03           TFR    D,U
f04d: 10 8e 00 02     LDY    #$0002
f051: c6 62           LDB    #$62
f053: 1d              SEX
f054: 1f 01           TFR    D,X
f056: c6 05           LDB    #$05
f058: 1d              SEX
f059: 34 76           PSHS   U,Y,X,D
f05b: ce 00 00        LDU    #$0000
f05e: 10 8e 00 0a     LDY    #$000A
f062: 34 60           PSHS   U,Y
f064: 17 3b ce        LBSR   $2C35
f067: 32 6c           LEAS   $C,S
f069: f6 3f cc        LDB    $3FCC
f06c: c1 01           CMPB   #$01
f06e: 10 26 00 55     LBNE   $F0C7
f072: ce 67 d2        LDU    #$67D2
f075: c6 28           LDB    #$28
f077: 1d              SEX
f078: 1f 02           TFR    D,Y
f07a: 5f              CLRB
f07b: 1d              SEX
f07c: 1f 01           TFR    D,X
f07e: cc 00 06        LDD    #$0006
f081: 34 76           PSHS   U,Y,X,D
f083: 17 68 1f        LBSR   $58A5
f086: 32 68           LEAS   $8,S
f088: ce 67 fa        LDU    #$67FA
f08b: c6 28           LDB    #$28
f08d: 1d              SEX
f08e: 1f 02           TFR    D,Y
f090: c6 40           LDB    #$40
f092: 1d              SEX
f093: 1f 01           TFR    D,X
f095: cc 00 06        LDD    #$0006
f098: 34 76           PSHS   U,Y,X,D
f09a: 17 68 08        LBSR   $58A5
f09d: 32 68           LEAS   $8,S
f09f: ce 24 14        LDU    #$2414
f0a2: 10 8e 3f ce     LDY    #$3FCE
f0a6: 8e 00 04        LDX    #$0004
f0a9: 34 70           PSHS   U,Y,X
f0ab: 17 59 e1        LBSR   $4A8F
f0ae: 32 66           LEAS   $6,S
f0b0: ce 24 17        LDU    #$2417
f0b3: c6 05           LDB    #$05
f0b5: 1d              SEX
f0b6: 1f 02           TFR    D,Y
f0b8: c6 20           LDB    #$20
f0ba: 1d              SEX
f0bb: 1f 01           TFR    D,X
f0bd: cc 00 06        LDD    #$0006
f0c0: 34 76           PSHS   U,Y,X,D
f0c2: 17 67 e0        LBSR   $58A5
f0c5: 32 68           LEAS   $8,S
f0c7: f6 3f cc        LDB    $3FCC
f0ca: c1 02           CMPB   #$02
f0cc: 10 26 00 8a     LBNE   $F15A
f0d0: e6 62           LDB    $2,S
f0d2: c1 00           CMPB   #$00
f0d4: 10 27 00 63     LBEQ   $F13B
f0d8: ce 67 5a        LDU    #$675A
f0db: c6 28           LDB    #$28
f0dd: 1d              SEX
f0de: 1f 02           TFR    D,Y
f0e0: 5f              CLRB
f0e1: 1d              SEX
f0e2: 1f 01           TFR    D,X
f0e4: cc 00 06        LDD    #$0006
f0e7: 34 76           PSHS   U,Y,X,D
f0e9: 17 67 b9        LBSR   $58A5
f0ec: 32 68           LEAS   $8,S
f0ee: ce 68 22        LDU    #$6822
f0f1: c6 28           LDB    #$28
f0f3: 1d              SEX
f0f4: 1f 02           TFR    D,Y
f0f6: c6 40           LDB    #$40
f0f8: 1d              SEX
f0f9: 1f 01           TFR    D,X
f0fb: cc 00 06        LDD    #$0006
f0fe: 34 76           PSHS   U,Y,X,D
f100: 17 67 a2        LBSR   $58A5
f103: 32 68           LEAS   $8,S
f105: ce 24 14        LDU    #$2414
f108: 10 8e 3f fd     LDY    #$3FFD
f10c: 8e 00 04        LDX    #$0004
f10f: 34 70           PSHS   U,Y,X
f111: 17 59 7b        LBSR   $4A8F
f114: 32 66           LEAS   $6,S
f116: ce 24 17        LDU    #$2417
f119: c6 05           LDB    #$05
f11b: 1d              SEX
f11c: 1f 02           TFR    D,Y
f11e: c6 54           LDB    #$54
f120: 1d              SEX
f121: 1f 01           TFR    D,X
f123: cc 00 06        LDD    #$0006
f126: 34 76           PSHS   U,Y,X,D
f128: 17 67 7a        LBSR   $58A5
f12b: 32 68           LEAS   $8,S
f12d: ce 1f 40        LDU    #$1F40
f130: 10 8e 00 02     LDY    #$0002
f134: 34 60           PSHS   U,Y
f136: 17 65 37        LBSR   $5670
f139: 32 64           LEAS   $4,S
f13b: ce 00 00        LDU    #$0000
f13e: 34 40           PSHS   U
f140: 17 68 83        LBSR   $59C6
f143: 32 62           LEAS   $2,S
f145: fc 22 02        LDD    $2202
f148: 84 ff           ANDA   #$FF
f14a: c4 f7           ANDB   #$F7
f14c: fd 22 02        STD    $2202
f14f: cc 00 0b        LDD    #$000B
f152: fd 22 17        STD    $2217
f155: 6f 63           CLR    $3,S
f157: 16 00 04        LBRA   $F15E
f15a: c6 01           LDB    #$01
f15c: e7 63           STB    $3,S
f15e: e6 63           LDB    $3,S
f160: 32 64           LEAS   $4,S
f162: 39              RTS
f163: fc 73 36        LDD    $7336
f166: 17 8b e7        LBSR   $7D50
f169: fc 22 04        LDD    $2204
f16c: 8a 00           ORA    #$00
f16e: ca 10           ORB    #$10
f170: fd 22 04        STD    $2204
f173: ce 67 5a        LDU    #$675A
f176: c6 28           LDB    #$28
f178: 1d              SEX
f179: 1f 02           TFR    D,Y
f17b: 5f              CLRB
f17c: 1d              SEX
f17d: 1f 01           TFR    D,X
f17f: cc 00 06        LDD    #$0006
f182: 34 76           PSHS   U,Y,X,D
f184: 17 67 1e        LBSR   $58A5
f187: 32 68           LEAS   $8,S
f189: ce 68 4a        LDU    #$684A
f18c: 10 8e 3f fd     LDY    #$3FFD
f190: c6 03           LDB    #$03
f192: 1d              SEX
f193: 1f 01           TFR    D,X
f195: cc 00 06        LDD    #$0006
f198: 34 76           PSHS   U,Y,X,D
f19a: 17 50 a5        LBSR   $4242
f19d: 32 68           LEAS   $8,S
f19f: c1 00           CMPB   #$00
f1a1: 10 27 00 53     LBEQ   $F1F8
f1a5: ce 67 82        LDU    #$6782
f1a8: c6 28           LDB    #$28
f1aa: 1d              SEX
f1ab: 1f 02           TFR    D,Y
f1ad: c6 40           LDB    #$40
f1af: 1d              SEX
f1b0: 1f 01           TFR    D,X
f1b2: cc 00 06        LDD    #$0006
f1b5: 34 76           PSHS   U,Y,X,D
f1b7: 17 66 eb        LBSR   $58A5
f1ba: 32 68           LEAS   $8,S
f1bc: ce 00 00        LDU    #$0000
f1bf: 34 40           PSHS   U
f1c1: 17 65 04        LBSR   $56C8
f1c4: 32 62           LEAS   $2,S
f1c6: ce 13 88        LDU    #$1388
f1c9: 10 8e 00 02     LDY    #$0002
f1cd: 34 60           PSHS   U,Y
f1cf: 17 64 9e        LBSR   $5670
f1d2: 32 64           LEAS   $4,S
f1d4: ce 00 00        LDU    #$0000
f1d7: 34 40           PSHS   U
f1d9: 17 67 ea        LBSR   $59C6
f1dc: 32 62           LEAS   $2,S
f1de: fc 22 02        LDD    $2202
f1e1: 84 ff           ANDA   #$FF
f1e3: c4 f7           ANDB   #$F7
f1e5: fd 22 02        STD    $2202
f1e8: ce 00 00        LDU    #$0000
f1eb: 34 40           PSHS   U
f1ed: 17 19 5c        LBSR   $0B4C
f1f0: 32 62           LEAS   $2,S
f1f2: 16 00 4e        LBRA   $F243
f1f5: 16 00 4b        LBRA   $F243
f1f8: 7f 3f cc        CLR    $3FCC
f1fb: ce 67 aa        LDU    #$67AA
f1fe: c6 28           LDB    #$28
f200: 1d              SEX
f201: 1f 02           TFR    D,Y
f203: c6 40           LDB    #$40
f205: 1d              SEX
f206: 1f 01           TFR    D,X
f208: cc 00 06        LDD    #$0006
f20b: 34 76           PSHS   U,Y,X,D
f20d: 17 66 95        LBSR   $58A5
f210: 32 68           LEAS   $8,S
f212: c6 62           LDB    #$62
f214: 1d              SEX
f215: 1f 03           TFR    D,U
f217: 10 8e 00 02     LDY    #$0002
f21b: c6 62           LDB    #$62
f21d: 1d              SEX
f21e: 1f 01           TFR    D,X
f220: c6 05           LDB    #$05
f222: 1d              SEX
f223: 34 76           PSHS   U,Y,X,D
f225: ce 00 00        LDU    #$0000
f228: 10 8e 00 0a     LDY    #$000A
f22c: 34 60           PSHS   U,Y
f22e: 17 3a 04        LBSR   $2C35
f231: 32 6c           LEAS   $C,S
f233: cc 6f 80        LDD    #$6F80
f236: fd 22 0d        STD    $220D
f239: fc 22 02        LDD    $2202
f23c: 8a 00           ORA    #$00
f23e: ca 08           ORB    #$08
f240: fd 22 02        STD    $2202
f243: 32 62           LEAS   $2,S
f245: 39              RTS
f246: fc 73 36        LDD    $7336
f249: 17 8b 04        LBSR   $7D50
f24c: fc 22 02        LDD    $2202
f24f: 84 08           ANDA   #$08
f251: c4 00           ANDB   #$00
f253: 10 83 00 00     CMPD   #$0000
f257: 10 27 00 14     LBEQ   $F26F
f25b: fc 22 02        LDD    $2202
f25e: 84 f7           ANDA   #$F7
f260: c4 ff           ANDB   #$FF
f262: fd 22 02        STD    $2202
f265: ce 00 00        LDU    #$0000
f268: 34 40           PSHS   U
f26a: 17 f6 28        LBSR   $E895
f26d: 32 62           LEAS   $2,S
f26f: fc 22 02        LDD    $2202
f272: 84 04           ANDA   #$04
f274: c4 00           ANDB   #$00
f276: 10 83 00 00     CMPD   #$0000
f27a: 10 27 00 21     LBEQ   $F29F
f27e: fc 22 02        LDD    $2202
f281: 84 fb           ANDA   #$FB
f283: c4 ff           ANDB   #$FF
f285: fd 22 02        STD    $2202
f288: fc 22 02        LDD    $2202
f28b: 84 ff           ANDA   #$FF
f28d: c4 ef           ANDB   #$EF
f28f: fd 22 02        STD    $2202
f292: ce 00 00        LDU    #$0000
f295: 34 40           PSHS   U
f297: 17 fb e7        LBSR   $EE81
f29a: 32 62           LEAS   $2,S
f29c: 16 00 94        LBRA   $F333
f29f: fc 22 02        LDD    $2202
f2a2: 84 00           ANDA   #$00
f2a4: c4 10           ANDB   #$10
f2a6: 10 83 00 00     CMPD   #$0000
f2aa: 10 27 00 17     LBEQ   $F2C5
f2ae: fc 22 02        LDD    $2202
f2b1: 84 ff           ANDA   #$FF
f2b3: c4 ef           ANDB   #$EF
f2b5: fd 22 02        STD    $2202
f2b8: ce 00 00        LDU    #$0000
f2bb: 34 40           PSHS   U
f2bd: 17 fe a3        LBSR   $F163
f2c0: 32 62           LEAS   $2,S
f2c2: 16 00 6e        LBRA   $F333
f2c5: fc 22 04        LDD    $2204
f2c8: 84 00           ANDA   #$00
f2ca: c4 08           ANDB   #$08
f2cc: 10 83 00 00     CMPD   #$0000
f2d0: 10 27 00 14     LBEQ   $F2E8
f2d4: ce 00 00        LDU    #$0000
f2d7: 10 8e 00 00     LDY    #$0000
f2db: 8e 00 04        LDX    #$0004
f2de: 34 70           PSHS   U,Y,X
f2e0: 17 31 32        LBSR   $2415
f2e3: 32 66           LEAS   $6,S
f2e5: 16 00 38        LBRA   $F320
f2e8: fc 22 04        LDD    $2204
f2eb: 8a 00           ORA    #$00
f2ed: ca 10           ORB    #$10
f2ef: fd 22 04        STD    $2204
f2f2: 7f 3f cd        CLR    $3FCD
f2f5: ce 00 00        LDU    #$0000
f2f8: 34 40           PSHS   U
f2fa: 17 f6 69        LBSR   $E966
f2fd: 32 62           LEAS   $2,S
f2ff: c6 0c           LDB    #$0C
f301: 1d              SEX
f302: 1f 03           TFR    D,U
f304: 10 8e 00 02     LDY    #$0002
f308: c6 0c           LDB    #$0C
f30a: 1d              SEX
f30b: 1f 01           TFR    D,X
f30d: c6 02           LDB    #$02
f30f: 1d              SEX
f310: 34 76           PSHS   U,Y,X,D
f312: ce 00 00        LDU    #$0000
f315: 10 8e 00 0a     LDY    #$000A
f319: 34 60           PSHS   U,Y
f31b: 17 39 17        LBSR   $2C35
f31e: 32 6c           LEAS   $C,S
f320: 7f 3f cc        CLR    $3FCC
f323: cc 6a 25        LDD    #$6A25
f326: fd 22 0d        STD    $220D
f329: fc 22 02        LDD    $2202
f32c: 8a 00           ORA    #$00
f32e: ca 08           ORB    #$08
f330: fd 22 02        STD    $2202
f333: 32 62           LEAS   $2,S
f335: 39              RTS
f336: 00 00           NEG    <$00
f338: 1c 4f           ANDCC  #$4F
f33a: 6e 20           JMP    $0,Y
f33c: 00 4f           NEG    <$4F
f33e: 66 66           ROR    $6,S
f340: 00 06           NEG    <$06
f342: 00 07           NEG    <$07
f344: 00 0b           NEG    <$0B
f346: 00 02           NEG    <$02
f348: 3e              XRES
f349: 00 08           NEG    <$08
f34b: 74 45 01        LSR    $4501
f34e: 15              XHCF
f34f: 74 4d 02        LSR    $4D02
f352: 11 74 62 03     LSR    $6203
f356: 15              XHCF
f357: 74 73 04        LSR    $7304
f35a: 16 74 88        LBRA   $67E5
f35d: 0a 11           DEC    <$11
f35f: 74 9e 0b        LSR    $9E0B
f362: 18              X18
f363: 74 af 0c        LSR    $AF0C
f366: 19              DAA
f367: 74 c7 0d        LSR    $C70D
f36a: 1c 74           ANDCC  #$74
f36c: e0 0e           SUBB   $E,X
f36e: 22 74           BHI    $F3E4
f370: fc 0f 15        LDD    $0F15
f373: 75 1e 10        LSR    $1E10
f376: 26 75           BNE    $F3ED
f378: 33 11           LEAU   -$F,X
f37a: 11 75 59 12     LSR    $5912
f37e: 14              XHCF
f37f: 75 6a 13        LSR    $6A13
f382: 10 75 7e 14     LSR    $7E14
f386: 1a 75           ORCC   #$75
f388: 8e 16 1e        LDX    #$161E
f38b: 7a 79 18        DEC    $7918
f38e: 24 75           BCC    $F405
f390: a8 1f           EORA   -$1,X
f392: 22 75           BHI    $F409
f394: cc 29 15        LDD    #$2915
f397: 75 ee 2a        LSR    $EE2A
f39a: 15              XHCF
f39b: 75 ee 2b        LSR    $EE2B
f39e: 20 76           BRA    $F416
f3a0: 03 2c           COM    <$2C
f3a2: 1c 76           ANDCC  #$76
f3a4: 23 2d           BLS    $F3D3
f3a6: 25 76           BCS    $F41E
f3a8: 3f              SWI
f3a9: 2e 12           BGT    $F3BD
f3ab: 76 64 2f        ROR    $642F
f3ae: 24 76           BCC    $F426
f3b0: 76 30 1c        ROR    $301C
f3b3: 76 9a 32        ROR    $9A32
f3b6: 17 76 b6        LBSR   $6A6F
f3b9: 33 1f           LEAU   -$1,X
f3bb: 76 cd 34        ROR    $CD34
f3be: 1c 76           ANDCC  #$76
f3c0: ec 35           LDD    -$B,Y
f3c2: 1c 77           ANDCC  #$77
f3c4: 08 36           ASL    <$36
f3c6: 18              X18
f3c7: 77 24 37        ASR    $2437
f3ca: 1b              NOP
f3cb: 77 3c 38        ASR    $3C38
f3ce: 19              DAA
f3cf: 77 57 39        ASR    $5739
f3d2: 1b              NOP
f3d3: 77 70 3a        ASR    $703A
f3d6: 23 77           BLS    $F44F
f3d8: 8b 3b           ADDA   #$3B
f3da: 28 77           BVC    $F453
f3dc: ae 65           LDX    $5,S
f3de: 21 77           BRN    $F457
f3e0: d6 66           LDB    <$66
f3e2: 27 77           BEQ    $F45B
f3e4: f7 67 27        STB    $6727
f3e7: 78 1e 68        ASL    $1E68
f3ea: 1e 7a           EXG    inv,CC
f3ec: 79 69 1f        ROL    $691F
f3ef: 78 45 6a        ASL    $456A
f3f2: 20 78           BRA    $F46C
f3f4: 64 6b           LSR    $B,S
f3f6: 23 78           BLS    $F470
f3f8: 84 6c           ANDA   #$6C
f3fa: 21 78           BRN    $F474
f3fc: a7 6d           STA    $D,S
f3fe: 25 78           BCS    $F478
f400: c8 6e           EORB   #$6E
f402: 10 78 ed 6f     ASL    $ED6F
f406: 1f 78           TFR    inv,A
f408: fd 70 20        STD    $7020
f40b: 79 1c 71        ROL    $1C71
f40e: 28 79           BVC    $F489
f410: 3c 72           CWAI   #$72
f412: 13              SYNC
f413: 79 64 73        ROL    $6473
f416: 28 79           BVC    $F491
f418: 77 79 17        ASR    $7917
f41b: 79 9f 7a        ROL    $9F7A
f41e: 1b              NOP
f41f: 79 b6 7b        ROL    $B67B
f422: 17 79 d1        LBSR   $6DF6
f425: 7c 20 79        INC    $2079
f428: e8 96           EORB   [A,X]
f42a: 25 78           BCS    $F4A4
f42c: c8 97           EORB   #$97
f42e: 21 7a           BRN    $F4AA
f430: 08 98           ASL    <$98
f432: 28 7a           BVC    $F4AE
f434: 29 99           BVS    $F3CF
f436: 28 7a           BVC    $F4B2
f438: 51              NEGB
f439: a0 1e           SUBA   -$2,X
f43b: 7a 79 ff        DEC    $79FF
f43e: 19              DAA
f43f: 7a 97 ff        DEC    $97FF
f442: 12              NOP
f443: 7a b0 4e        DEC    $B04E
f446: 6f 20           CLR    $0,Y
f448: 45              LSRA
f449: 72 72 6f        XNC    $726F
f44c: 72 4b 65        XNC    $4B65
f44f: 79 20 70        ROL    $2070
f452: 61 72           NEG    -$E,S
f454: 73 65 72        COM    $6572
f457: 20 6e           BRA    $F4C7
f459: 6f 74           CLR    -$C,S
f45b: 20 61           BRA    $F4BE
f45d: 63 74           COM    -$C,S
f45f: 69 76           ROL    -$A,S
f461: 65 49           LSR    $9,U
f463: 6e 76           JMP    -$A,S
f465: 61 6c           NEG    $C,S
f467: 69 64           ROL    $4,S
f469: 20 6b           BRA    $F4D6
f46b: 65 79           LSR    -$7,S
f46d: 20 65           BRA    $F4D4
f46f: 6e 74           JMP    -$C,S
f471: 72 79 49        XNC    $7949
f474: 6e 76           JMP    -$A,S
f476: 61 6c           NEG    $C,S
f478: 69 64           ROL    $4,S
f47a: 20 48           BRA    $F4C4
f47c: 50              NEGB
f47d: 2d 49           BLT    $F4C8
f47f: 42              XNCA
f480: 20 61           BRA    $F4E3
f482: 64 64           LSR    $4,S
f484: 72 65 73        XNC    $6573
f487: 73 4e 6f        COM    $4E6F
f48a: 20 69           BRA    $F4F5
f48c: 6e 63           JMP    $3,S
f48e: 72 65 6d        XNC    $656D
f491: 65 6e           LSR    $E,S
f493: 74 61 62        LSR    $6162
f496: 6c 65           INC    $5,S
f498: 20 66           BRA    $F500
f49a: 69 65           ROL    $5,S
f49c: 6c 64           INC    $4,S
f49e: 4e              XCLRA
f49f: 6f 20           CLR    $0,Y
f4a1: 4f              CLRA
f4a2: 75 74 70        LSR    $7470
f4a5: 75 74 20        LSR    $7420
f4a8: 42              XNCA
f4a9: 6f 61           CLR    $1,S
f4ab: 72 64 20        XNC    $6420
f4ae: 31 48           LEAY   $8,U
f4b0: 61 72           NEG    -$E,S
f4b2: 64 77           LSR    -$9,S
f4b4: 61 72           NEG    -$E,S
f4b6: 65 20           LSR    $0,Y
f4b8: 65 72           LSR    -$E,S
f4ba: 72 6f 72        XNC    $6F72
f4bd: 73 20 64        COM    $2064
f4c0: 65 74           LSR    -$C,S
f4c2: 65 63           LSR    $3,S
f4c4: 74 65 64        LSR    $6564
f4c7: 50              NEGB
f4c8: 4c              INCA
f4c9: 4c              INCA
f4ca: 20 72           BRA    $F53E
f4cc: 65 66           LSR    $6,S
f4ce: 65 72           LSR    -$E,S
f4d0: 65 6e           LSR    $E,S
f4d2: 63 65           COM    $5,S
f4d4: 20 6f           BRA    $F545
f4d6: 75 74 20        LSR    $7420
f4d9: 6f 66           CLR    $6,S
f4db: 20 6c           BRA    $F549
f4dd: 6f 63           CLR    $3,S
f4df: 6b 52           XDEC   -$E,U
f4e1: 65 76           LSR    -$A,S
f4e3: 65 72           LSR    -$E,S
f4e5: 73 65 20        COM    $6520
f4e8: 70 6f 77        NEG    $6F77
f4eb: 65 72           LSR    -$E,S
f4ed: 20 65           BRA    $F554
f4ef: 72 72 6f        XNC    $726F
f4f2: 72 20 64        XNC    $2064
f4f5: 65 74           LSR    -$C,S
f4f7: 65 63           LSR    $3,S
f4f9: 74 65 64        LSR    $6564
f4fc: 4e              XCLRA
f4fd: 6f 20           CLR    $0,Y
f4ff: 72 65 63        XNC    $6563
f502: 61 6c           NEG    $C,S
f504: 6c 20           INC    $0,Y
f506: 73 65 74        COM    $6574
f509: 74 69 6e        LSR    $696E
f50c: 67 20           ASR    $0,Y
f50e: 69 6e           ROL    $E,S
f510: 20 74           BRA    $F586
f512: 68 69           ASL    $9,S
f514: 73 20 72        COM    $2072
f517: 65 67           LSR    $7,S
f519: 69 73           ROL    -$D,S
f51b: 74 65 72        LSR    $6572
f51e: 55              LSRB
f51f: 6e 2d           JMP    $D,Y
f521: 65 78           LSR    -$8,S
f523: 65 63           LSR    $3,S
f525: 75 74 61        LSR    $7461
f528: 62 6c           XNC    $C,S
f52a: 65 20           LSR    $0,Y
f52c: 63 6f           COM    $F,S
f52e: 6d 6d           TST    $D,S
f530: 61 6e           NEG    $E,S
f532: 64 47           LSR    $7,U
f534: 6f 20           CLR    $0,Y
f536: 74 6f 20        LSR    $6F20
f539: 4d              TSTA
f53a: 61 69           NEG    $9,S
f53c: 6e 20           JMP    $0,Y
f53e: 53              COMB
f53f: 65 6c           LSR    $C,S
f541: 65 63           LSR    $3,S
f543: 74 69 6f        LSR    $696F
f546: 6e 20           JMP    $0,Y
f548: 4c              INCA
f549: 65 76           LSR    -$A,S
f54b: 65 6c           LSR    $C,S
f54d: 20 66           BRA    $F5B5
f54f: 6f 72           CLR    -$E,S
f551: 20 53           BRA    $F5A6
f553: 50              NEGB
f554: 45              LSRA
f555: 43              COMA
f556: 49              ROLA
f557: 41              NEGA
f558: 4c              INCA
f559: 4f              CLRA
f55a: 6e 6c           JMP    $C,S
f55c: 79 20 30        ROL    $2030
f55f: 20 2d           BRA    $F58E
f561: 20 31           BRA    $F594
f563: 35 20           PULS   Y
f565: 76 61 6c        ROR    $616C
f568: 69 64           ROL    $4,S
f56a: 4f              CLRA
f56b: 6e 6c           JMP    $C,S
f56d: 79 20 30        ROL    $2030
f570: 20 2d           BRA    $F59F
f572: 20 36           BRA    $F5AA
f574: 35 35           PULS   CC,B,X,Y
f576: 33 35           LEAU   -$B,Y
f578: 20 76           BRA    $F5F0
f57a: 61 6c           NEG    $C,S
f57c: 69 64           ROL    $4,S
f57e: 4e              XCLRA
f57f: 75 6d 62        LSR    $6D62
f582: 65 72           LSR    -$E,S
f584: 20 74           BRA    $F5FA
f586: 6f 6f           CLR    $F,S
f588: 20 6c           BRA    $F5F6
f58a: 61 72           NEG    -$E,S
f58c: 67 65           ASR    $5,S
f58e: 4e              XCLRA
f58f: 6f 74           CLR    -$C,S
f591: 20 61           BRA    $F5F4
f593: 6e 20           JMP    $0,Y
f595: 69 6e           ROL    $E,S
f597: 63 72           COM    -$E,S
f599: 65 6d           LSR    $D,S
f59b: 65 6e           LSR    $E,S
f59d: 74 61 62        LSR    $6162
f5a0: 6c 65           INC    $5,S
f5a2: 20 66           BRA    $F60A
f5a4: 69 65           ROL    $5,S
f5a6: 6c 64           INC    $4,S
f5a8: 4e              XCLRA
f5a9: 6f 20           CLR    $0,Y
f5ab: 73 65 74        COM    $6574
f5ae: 74 61 62        LSR    $6162
f5b1: 6c 65           INC    $5,S
f5b3: 20 66           BRA    $F61B
f5b5: 75 6e 63        LSR    $6E63
f5b8: 74 69 6f        LSR    $696F
f5bb: 6e 73           JMP    -$D,S
f5bd: 20 69           BRA    $F628
f5bf: 6e 20           JMP    $0,Y
f5c1: 74 68 69        LSR    $6869
f5c4: 73 20 77        COM    $2077
f5c7: 69 6e           ROL    $E,S
f5c9: 64 6f           LSR    $F,S
f5cb: 77 4f 70        ASR    $4F70
f5ce: 74 69 6f        LSR    $696F
f5d1: 6e 20           JMP    $0,Y
f5d3: 46              RORA
f5d4: 57              ASRB
f5d5: 20 6e           BRA    $F645
f5d7: 65 65           LSR    $5,S
f5d9: 64 65           LSR    $5,S
f5db: 64 20           LSR    $0,Y
f5dd: 66 6f           ROR    $F,S
f5df: 72 20 44        XNC    $2044
f5e2: 45              LSRA
f5e3: 53              COMB
f5e4: 54              LSRB
f5e5: 4e              XCLRA
f5e6: 20 63           BRA    $F64B
f5e8: 6f 6e           CLR    $E,S
f5ea: 74 72 6f        LSR    $726F
f5ed: 6c 48           INC    $8,U
f5ef: 50              NEGB
f5f0: 2d 49           BLT    $F63B
f5f2: 42              XNCA
f5f3: 20 6e           BRA    $F663
f5f5: 75 6d 62        LSR    $6D62
f5f8: 65 72           LSR    -$E,S
f5fa: 20 69           BRA    $F665
f5fc: 6e 20           JMP    $0,Y
f5fe: 65 72           LSR    -$E,S
f600: 72 6f 72        XNC    $6F72
f603: 4e              XCLRA
f604: 75 6d 62        LSR    $6D62
f607: 65 72           LSR    -$E,S
f609: 20 72           BRA    $F67D
f60b: 65 63           LSR    $3,S
f60d: 65 69           LSR    $9,S
f60f: 76 65 64        ROR    $6564
f612: 20 62           BRA    $F676
f614: 75 74 20        LSR    $7420
f617: 6e 6f           JMP    $F,S
f619: 74 20 65        LSR    $2065
f61c: 78 70 65        ASL    $7065
f61f: 63 74           COM    -$C,S
f621: 65 64           LSR    $4,S
f623: 49              ROLA
f624: 6e 76           JMP    -$A,S
f626: 61 6c           NEG    $C,S
f628: 69 64           ROL    $4,S
f62a: 20 55           BRA    $F681
f62c: 6e 69           JMP    $9,S
f62e: 71 75 65        NEG    $7565
f631: 20 64           BRA    $F697
f633: 61 74           NEG    -$C,S
f635: 61 20           NEG    $0,Y
f637: 72 65 63        XNC    $6563
f63a: 65 69           LSR    $9,S
f63c: 76 65 64        ROR    $6564
f63f: 55              LSRB
f640: 6e 69           JMP    $9,S
f642: 71 75 65        NEG    $7565
f645: 20 64           BRA    $F6AB
f647: 61 74           NEG    -$C,S
f649: 61 20           NEG    $0,Y
f64b: 72 65 63        XNC    $6563
f64e: 65 69           LSR    $9,S
f650: 76 65 64        ROR    $6564
f653: 20 62           BRA    $F6B7
f655: 75 74 20        LSR    $7420
f658: 6e 6f           JMP    $F,S
f65a: 74 20 65        LSR    $2065
f65d: 78 70 65        ASL    $7065
f660: 63 74           COM    -$C,S
f662: 65 64           LSR    $4,S
f664: 49              ROLA
f665: 6e 76           JMP    -$A,S
f667: 61 6c           NEG    $C,S
f669: 69 64           ROL    $4,S
f66b: 20 74           BRA    $F6E1
f66d: 65 72           LSR    -$E,S
f66f: 6d 69           TST    $9,S
f671: 6e 61           JMP    $1,S
f673: 74 6f 72        LSR    $6F72
f676: 54              LSRB
f677: 65 72           LSR    -$E,S
f679: 6d 69           TST    $9,S
f67b: 6e 61           JMP    $1,S
f67d: 74 6f 72        LSR    $6F72
f680: 20 72           BRA    $F6F4
f682: 65 63           LSR    $3,S
f684: 65 69           LSR    $9,S
f686: 76 65 64        ROR    $6564
f689: 20 62           BRA    $F6ED
f68b: 75 74 20        LSR    $7420
f68e: 6e 6f           JMP    $F,S
f690: 74 20 65        LSR    $2065
f693: 78 70 65        ASL    $7065
f696: 63 74           COM    -$C,S
f698: 65 64           LSR    $4,S
f69a: 49              ROLA
f69b: 6e 76           JMP    -$A,S
f69d: 61 6c           NEG    $C,S
f69f: 69 64           ROL    $4,S
f6a1: 20 48           BRA    $F6EB
f6a3: 50              NEGB
f6a4: 2d 49           BLT    $F6EF
f6a6: 42              XNCA
f6a7: 20 74           BRA    $F71D
f6a9: 6f 6b           CLR    $B,S
f6ab: 65 6e           LSR    $E,S
f6ad: 20 72           BRA    $F721
f6af: 65 63           LSR    $3,S
f6b1: 65 69           LSR    $9,S
f6b3: 76 65 64        ROR    $6564
f6b6: 54              LSRB
f6b7: 69 6d           ROL    $D,S
f6b9: 65 20           LSR    $0,Y
f6bb: 76 61 6c        ROR    $616C
f6be: 75 65 20        LSR    $6520
f6c1: 6f 75           CLR    -$B,S
f6c3: 74 20 6f        LSR    $206F
f6c6: 66 20           ROR    $0,Y
f6c8: 72 61 6e        XNC    $616E
f6cb: 67 65           ASR    $5,S
f6cd: 4f              CLRA
f6ce: 6e 20           JMP    $0,Y
f6d0: 26 20           BNE    $F6F2
f6d2: 4f              CLRA
f6d3: 66 66           ROR    $6,S
f6d5: 20 74           BRA    $F74B
f6d7: 69 6d           ROL    $D,S
f6d9: 65 73           LSR    -$D,S
f6db: 20 63           BRA    $F740
f6dd: 61 6e           NEG    $E,S
f6df: 6e 6f           JMP    $F,S
f6e1: 74 20 62        LSR    $2062
f6e4: 6f 74           CLR    -$C,S
f6e6: 68 20           ASL    $0,Y
f6e8: 62 65           XNC    $5,S
f6ea: 20 30           BRA    $F71C
f6ec: 41              NEGA
f6ed: 6d 70           TST    -$10,S
f6ef: 6c 69           INC    $9,S
f6f1: 74 75 64        LSR    $7564
f6f4: 65 20           LSR    $0,Y
f6f6: 76 61 6c        ROR    $616C
f6f9: 75 65 20        LSR    $6520
f6fc: 6f 75           CLR    -$B,S
f6fe: 74 20 6f        LSR    $206F
f701: 66 20           ROR    $0,Y
f703: 72 61 6e        XNC    $616E
f706: 67 65           ASR    $5,S
f708: 46              RORA
f709: 72 65 71        XNC    $6571
f70c: 75 65 6e        LSR    $656E
f70f: 63 79           COM    -$7,S
f711: 20 76           BRA    $F789
f713: 61 6c           NEG    $C,S
f715: 75 65 20        LSR    $6520
f718: 6f 75           CLR    -$B,S
f71a: 74 20 6f        LSR    $206F
f71d: 66 20           ROR    $0,Y
f71f: 72 61 6e        XNC    $616E
f722: 67 65           ASR    $5,S
f724: 54              LSRB
f725: 6f 6e           CLR    $E,S
f727: 65 20           LSR    $0,Y
f729: 6e 75           JMP    -$B,S
f72b: 6d 62           TST    $2,S
f72d: 65 72           LSR    -$E,S
f72f: 20 6f           BRA    $F7A0
f731: 75 74 20        LSR    $7420
f734: 6f 66           CLR    $6,S
f736: 20 72           BRA    $F7AA
f738: 61 6e           NEG    $E,S
f73a: 67 65           ASR    $5,S
f73c: 53              COMB
f73d: 65 71           LSR    -$F,S
f73f: 75 65 6e        LSR    $656E
f742: 63 65           COM    $5,S
f744: 20 69           BRA    $F7AF
f746: 6e 64           JMP    $4,S
f748: 65 78           LSR    -$8,S
f74a: 20 6f           BRA    $F7BB
f74c: 75 74 20        LSR    $7420
f74f: 6f 66           CLR    $6,S
f751: 20 72           BRA    $F7C5
f753: 61 6e           NEG    $E,S
f755: 67 65           ASR    $5,S
f757: 53              COMB
f758: 65 71           LSR    -$F,S
f75a: 75 65 6e        LSR    $656E
f75d: 63 65           COM    $5,S
f75f: 20 65           BRA    $F7C6
f761: 6e 64           JMP    $4,S
f763: 20 6f           BRA    $F7D4
f765: 75 74 20        LSR    $7420
f768: 6f 66           CLR    $6,S
f76a: 20 72           BRA    $F7DE
f76c: 61 6e           NEG    $E,S
f76e: 67 65           ASR    $5,S
f770: 49              ROLA
f771: 6e 76           JMP    -$A,S
f773: 61 6c           NEG    $C,S
f775: 69 64           ROL    $4,S
f777: 20 64           BRA    $F7DD
f779: 69 67           ROL    $7,S
f77b: 69 74           ROL    -$C,S
f77d: 20 66           BRA    $F7E5
f77f: 6f 72           CLR    -$E,S
f781: 20 74           BRA    $F7F7
f783: 68 69           ASL    $9,S
f785: 73 20 62        COM    $2062
f788: 61 73           NEG    -$D,S
f78a: 65 43           LSR    $3,U
f78c: 6f 6d           CLR    $D,S
f78e: 6d 6d           TST    $D,S
f790: 61 6e           NEG    $E,S
f792: 64 20           LSR    $0,Y
f794: 6e 6f           JMP    $F,S
f796: 74 20 70        LSR    $2070
f799: 65 72           LSR    -$E,S
f79b: 6d 69           TST    $9,S
f79d: 74 74 65        LSR    $7465
f7a0: 64 20           LSR    $0,Y
f7a2: 69 6e           ROL    $E,S
f7a4: 20 74           BRA    $F81A
f7a6: 68 69           ASL    $9,S
f7a8: 73 20 6d        COM    $206D
f7ab: 6f 64           CLR    $4,S
f7ad: 65 43           LSR    $3,U
f7af: 6f 6d           CLR    $D,S
f7b1: 6d 6d           TST    $D,S
f7b3: 61 6e           NEG    $E,S
f7b5: 64 20           LSR    $0,Y
f7b7: 6e 6f           JMP    $F,S
f7b9: 74 20 61        LSR    $2061
f7bc: 76 61 69        ROR    $6169
f7bf: 6c 61           INC    $1,S
f7c1: 62 6c           XNC    $C,S
f7c3: 65 20           LSR    $0,Y
f7c5: 69 6e           ROL    $E,S
f7c7: 20 70           BRA    $F839
f7c9: 72 65 73        XNC    $6573
f7cc: 65 6e           LSR    $E,S
f7ce: 74 20 77        LSR    $2077
f7d1: 69 6e           ROL    $E,S
f7d3: 64 6f           LSR    $F,S
f7d5: 77 43 68        ASR    $4368
f7d8: 61 6e           NEG    $E,S
f7da: 6e 65           JMP    $5,S
f7dc: 6c 20           INC    $0,Y
f7de: 41              NEGA
f7df: 20 63           BRA    $F844
f7e1: 61 6e           NEG    $E,S
f7e3: 20 6e           BRA    $F853
f7e5: 6f 74           CLR    -$C,S
f7e7: 20 6d           BRA    $F856
f7e9: 6f 64           CLR    $4,S
f7eb: 75 6c 61        LSR    $6C61
f7ee: 74 65 20        LSR    $6520
f7f1: 69 74           ROL    -$C,S
f7f3: 73 65 6c        COM    $656C
f7f6: 66 43           ROR    $3,U
f7f8: 68 20           ASL    $0,Y
f7fa: 41              NEGA
f7fb: 27 73           BEQ    $F870
f7fd: 20 44           BRA    $F843
f7ff: 43              COMA
f800: 20 77           BRA    $F879
f802: 61 76           NEG    -$A,S
f804: 65 66           LSR    $6,S
f806: 6f 72           CLR    -$E,S
f808: 6d 20           TST    $0,Y
f80a: 63 61           COM    $1,S
f80c: 6e 20           JMP    $0,Y
f80e: 6e 6f           JMP    $F,S
f810: 74 20 62        LSR    $2062
f813: 65 20           LSR    $0,Y
f815: 6d 6f           TST    $F,S
f817: 64 75           LSR    -$B,S
f819: 6c 61           INC    $1,S
f81b: 74 65 64        LSR    $6564
f81e: 4d              TSTA
f81f: 6f 64           CLR    $4,S
f821: 75 6c 61        LSR    $6C61
f824: 74 69 6f        LSR    $696F
f827: 6e 20           JMP    $0,Y
f829: 77 69 74        ASR    $6974
f82c: 68 20           ASL    $0,Y
f82e: 44              LSRA
f82f: 43              COMA
f830: 20 77           BRA    $F8A9
f832: 61 76           NEG    -$A,S
f834: 65 66           LSR    $6,S
f836: 6f 72           CLR    -$E,S
f838: 6d 20           TST    $0,Y
f83a: 6e 6f           JMP    $F,S
f83c: 74 20 61        LSR    $2061
f83f: 6c 6c           INC    $C,S
f841: 6f 77           CLR    -$9,S
f843: 65 64           LSR    $4,S
f845: 41              NEGA
f846: 4d              TSTA
f847: 20 26           BRA    $F86F
f849: 20 44           BRA    $F88F
f84b: 53              COMB
f84c: 42              XNCA
f84d: 20 61           BRA    $F8B0
f84f: 72 65 20        XNC    $6520
f852: 6d 75           TST    -$B,S
f854: 74 75 61        LSR    $7561
f857: 6c 6c           INC    $C,S
f859: 79 20 65        ROL    $2065
f85c: 78 63 6c        ASL    $636C
f85f: 75 73 69        LSR    $7369
f862: 76 65 53        ROR    $6553
f865: 75 6d 6d        LSR    $6D6D
f868: 69 6e           ROL    $E,S
f86a: 67 20           ASR    $0,Y
f86c: 63 68           COM    $8,S
f86e: 61 6e           NEG    $E,S
f870: 6e 65           JMP    $5,S
f872: 6c 73           INC    -$D,S
f874: 20 63           BRA    $F8D9
f876: 61 6e           NEG    $E,S
f878: 6e 6f           JMP    $F,S
f87a: 74 20 62        LSR    $2062
f87d: 65 20           LSR    $0,Y
f87f: 73 70 6c        COM    $706C
f882: 69 74           ROL    -$C,S
f884: 48              ASLA
f885: 6f 70           CLR    -$10,S
f887: 20 52           BRA    $F8DB
f889: 61 6d           NEG    $D,S
f88b: 20 65           BRA    $F8F2
f88d: 6e 61           JMP    $1,S
f88f: 62 6c           XNC    $C,S
f891: 65 64           LSR    $4,S
f893: 20 66           BRA    $F8FB
f895: 6f 72           CLR    -$E,S
f897: 20 74           BRA    $F90D
f899: 68 69           ASL    $9,S
f89b: 73 20 6d        COM    $206D
f89e: 6f 64           CLR    $4,S
f8a0: 20 73           BRA    $F915
f8a2: 6f 75           CLR    -$B,S
f8a4: 72 63 65        XNC    $6365
f8a7: 46              RORA
f8a8: 72 65 71        XNC    $6571
f8ab: 75 65 6e        LSR    $656E
f8ae: 63 79           COM    -$7,S
f8b0: 20 74           BRA    $F926
f8b2: 6f 6f           CLR    $F,S
f8b4: 20 67           BRA    $F91D
f8b6: 72 65 61        XNC    $6561
f8b9: 74 20 66        LSR    $2066
f8bc: 6f 72           CLR    -$E,S
f8be: 20 70           BRA    $F930
f8c0: 75 6c 73        LSR    $6C73
f8c3: 65 20           LSR    $0,Y
f8c5: 6d 6f           TST    $F,S
f8c7: 64 46           LSR    $6,U
f8c9: 72 65 71        XNC    $6571
f8cc: 75 65 6e        LSR    $656E
f8cf: 63 79           COM    -$7,S
f8d1: 20 74           BRA    $F947
f8d3: 6f 6f           CLR    $F,S
f8d5: 20 67           BRA    $F93E
f8d7: 72 65 61        XNC    $6561
f8da: 74 20 66        LSR    $2066
f8dd: 6f 72           CLR    -$E,S
f8df: 20 74           BRA    $F955
f8e1: 68 69           ASL    $9,S
f8e3: 73 20 77        COM    $2077
f8e6: 61 76           NEG    -$A,S
f8e8: 65 66           LSR    $6,S
f8ea: 6f 72           CLR    -$E,S
f8ec: 6d 41           TST    $1,U
f8ee: 4d              TSTA
f8ef: 20 6f           BRA    $F960
f8f1: 72 20 44        XNC    $2044
f8f4: 53              COMB
f8f5: 42              XNCA
f8f6: 20 61           BRA    $F959
f8f8: 63 74           COM    -$C,S
f8fa: 69 76           ROL    -$A,S
f8fc: 65 48           LSR    $8,U
f8fe: 6f 70           CLR    -$10,S
f900: 20 52           BRA    $F954
f902: 61 6d           NEG    $D,S
f904: 20 41           BRA    $F947
f906: 6d 70           TST    -$10,S
f908: 6c 69           INC    $9,S
f90a: 74 75 64        LSR    $7564
f90d: 65 73           LSR    -$D,S
f90f: 20 61           BRA    $F972
f911: 72 65 20        XNC    $6520
f914: 74 6f 6f        LSR    $6F6F
f917: 20 68           BRA    $F981
f919: 69 67           ROL    $7,S
f91b: 68 48           ASL    $8,U
f91d: 6f 70           CLR    -$10,S
f91f: 20 52           BRA    $F973
f921: 61 6d           NEG    $D,S
f923: 20 46           BRA    $F96B
f925: 72 65 71        XNC    $6571
f928: 75 65 6e        LSR    $656E
f92b: 63 69           COM    $9,S
f92d: 65 73           LSR    -$D,S
f92f: 20 61           BRA    $F992
f931: 72 65 20        XNC    $6520
f934: 74 6f 6f        LSR    $6F6F
f937: 20 68           BRA    $F9A1
f939: 69 67           ROL    $7,S
f93b: 68 48           ASL    $8,U
f93d: 6f 70           CLR    -$10,S
f93f: 20 52           BRA    $F993
f941: 61 6d           NEG    $D,S
f943: 20 66           BRA    $F9AB
f945: 72 65 71        XNC    $6571
f948: 75 65 6e        LSR    $656E
f94b: 63 79           COM    -$7,S
f94d: 20 74           BRA    $F9C3
f94f: 6f 6f           CLR    $F,S
f951: 20 67           BRA    $F9BA
f953: 72 65 61        XNC    $6561
f956: 74 20 66        LSR    $2066
f959: 6f 72           CLR    -$E,S
f95b: 20 77           BRA    $F9D4
f95d: 61 76           NEG    -$A,S
f95f: 65 66           LSR    $6,S
f961: 6f 72           CLR    -$E,S
f963: 6d 50           TST    -$10,U
f965: 68 61           ASL    $1,S
f967: 73 65 20        COM    $6520
f96a: 6d 6f           TST    $F,S
f96c: 64 20           LSR    $0,Y
f96e: 69 73           ROL    -$D,S
f970: 20 61           BRA    $F9D3
f972: 63 74           COM    -$C,S
f974: 69 76           ROL    -$A,S
f976: 65 4c           LSR    $C,U
f978: 61 73           NEG    -$D,S
f97a: 74 20 43        LSR    $2043
f97d: 68 20           ASL    $0,Y
f97f: 41              NEGA
f980: 20 66           BRA    $F9E8
f982: 72 65 71        XNC    $6571
f985: 20 69           BRA    $F9F0
f987: 73 20 74        COM    $2074
f98a: 6f 6f           CLR    $F,S
f98c: 20 67           BRA    $F9F5
f98e: 72 65 61        XNC    $6561
f991: 74 20 66        LSR    $2066
f994: 6f 72           CLR    -$E,S
f996: 20 77           BRA    $FA0F
f998: 61 76           NEG    -$A,S
f99a: 65 66           LSR    $6,S
f99c: 6f 72           CLR    -$E,S
f99e: 6d 41           TST    $1,U
f9a0: 6d 70           TST    -$10,S
f9a2: 6c 69           INC    $9,S
f9a4: 74 75 64        LSR    $7564
f9a7: 65 20           LSR    $0,Y
f9a9: 65 78           LSR    -$8,S
f9ab: 63 65           COM    $5,S
f9ad: 65 64           LSR    $4,S
f9af: 73 20 6c        COM    $206C
f9b2: 69 6d           ROL    $D,S
f9b4: 69 74           ROL    -$C,S
f9b6: 41              NEGA
f9b7: 6d 70           TST    -$10,S
f9b9: 6c 69           INC    $9,S
f9bb: 74 75 64        LSR    $7564
f9be: 65 20           LSR    $0,Y
f9c0: 73 75 6d        COM    $756D
f9c3: 20 65           BRA    $FA2A
f9c5: 78 63 65        ASL    $6365
f9c8: 65 64           LSR    $4,S
f9ca: 73 20 6c        COM    $206C
f9cd: 69 6d           ROL    $D,S
f9cf: 69 74           ROL    -$C,S
f9d1: 46              RORA
f9d2: 72 65 71        XNC    $6571
f9d5: 75 65 6e        LSR    $656E
f9d8: 63 79           COM    -$7,S
f9da: 20 65           BRA    $FA41
f9dc: 78 63 65        ASL    $6365
f9df: 65 64           LSR    $4,S
f9e1: 73 20 6c        COM    $206C
f9e4: 69 6d           ROL    $D,S
f9e6: 69 74           ROL    -$C,S
f9e8: 4c              INCA
f9e9: 61 73           NEG    -$D,S
f9eb: 74 20 43        LSR    $2043
f9ee: 68 20           ASL    $0,Y
f9f0: 41              NEGA
f9f1: 20 61           BRA    $FA54
f9f3: 6d 70           TST    -$10,S
f9f5: 6c 69           INC    $9,S
f9f7: 74 75 64        LSR    $7564
f9fa: 65 20           LSR    $0,Y
f9fc: 69 73           ROL    -$D,S
f9fe: 20 74           BRA    $FA74
fa00: 6f 6f           CLR    $F,S
fa02: 20 6c           BRA    $FA70
fa04: 61 72           NEG    -$E,S
fa06: 67 65           ASR    $5,S
fa08: 4f              CLRA
fa09: 75 74 78        LSR    $7478
fa0c: 20 6f           BRA    $FA7D
fa0e: 72 20 6f        XNC    $206F
fa11: 66 66           ROR    $6,S
fa13: 20 64           BRA    $FA79
fa15: 65 73           LSR    -$D,S
fa17: 74 6e 20        LSR    $6E20
fa1a: 72 65 71        XNC    $6571
fa1d: 75 69 72        LSR    $6972
fa20: 65 64           LSR    $4,S
fa22: 20 66           BRA    $FA8A
fa24: 6f 72           CLR    -$E,S
fa26: 20 44           BRA    $FA6C
fa28: 43              COMA
fa29: 44              LSRA
fa2a: 43              COMA
fa2b: 20 6e           BRA    $FA9B
fa2d: 6f 74           CLR    -$C,S
fa2f: 20 70           BRA    $FAA1
fa31: 65 72           LSR    -$E,S
fa33: 6d 69           TST    $9,S
fa35: 74 74 65        LSR    $7465
fa38: 64 20           LSR    $0,Y
fa3a: 77 68 69        ASR    $6869
fa3d: 6c 65           INC    $5,S
fa3f: 20 6d           BRA    $FAAE
fa41: 6f 64           CLR    $4,S
fa43: 75 6c 61        LSR    $6C61
fa46: 74 69 6f        LSR    $696F
fa49: 6e 20           JMP    $0,Y
fa4b: 61 63           NEG    $3,S
fa4d: 74 69 76        LSR    $6976
fa50: 65 4f           LSR    $F,U
fa52: 6e 6c           JMP    $C,S
fa54: 79 20 6f        ROL    $206F
fa57: 6e 65           JMP    $5,S
fa59: 20 44           BRA    $FA9F
fa5b: 43              COMA
fa5c: 20 73           BRA    $FAD1
fa5e: 75 6d 20        LSR    $6D20
fa61: 70 65 72        NEG    $6572
fa64: 6d 69           TST    $9,S
fa66: 74 74 65        LSR    $7465
fa69: 64 20           LSR    $0,Y
fa6b: 69 6e           ROL    $E,S
fa6d: 74 6f 20        LSR    $6F20
fa70: 61 6e           NEG    $E,S
fa72: 20 6f           BRA    $FAE3
fa74: 75 74 70        LSR    $7470
fa77: 75 74 4f        LSR    $744F
fa7a: 75 74 70        LSR    $7470
fa7d: 75 74 20        LSR    $7420
fa80: 73 65 6c        COM    $656C
fa83: 65 63           LSR    $3,S
fa85: 74 65 64        LSR    $6564
fa88: 20 64           BRA    $FAEE
fa8a: 6f 65           CLR    $5,S
fa8c: 73 20 6e        COM    $206E
fa8f: 6f 74           CLR    -$C,S
fa91: 20 65           BRA    $FAF8
fa93: 78 69 73        ASL    $6973
fa96: 74 46 75        LSR    $4675
fa99: 6e 63           JMP    $3,S
fa9b: 74 69 6f        LSR    $696F
fa9e: 6e 20           JMP    $0,Y
faa0: 6e 6f           JMP    $F,S
faa2: 74 20 69        LSR    $2069
faa5: 6d 70           TST    -$10,S
faa7: 6c 65           INC    $5,S
faa9: 6d 65           TST    $5,S
faab: 6e 74           JMP    -$C,S
faad: 65 64           LSR    $4,S
faaf: 2e 4d           BGT    $FAFE
fab1: 65 73           LSR    -$D,S
fab3: 73 61 67        COM    $6167
fab6: 65 20           LSR    $0,Y
fab8: 6e 6f           JMP    $F,S
faba: 74 20 66        LSR    $2066
fabd: 6f 75           CLR    -$B,S
fabf: 6e 64           JMP    $4,S
fac1: 2e 23           BGT    $FAE6
fac3: b6 23 de        LDA    $23DE
fac6: 8e 73 49        LDX    #$7349
fac9: e6 1f           LDB    -$1,X
facb: a1 84           CMPA   ,X
facd: 27 05           BEQ    $FAD4
facf: 30 04           LEAX   $4,X
fad1: 5a              DECB
fad2: 26 f7           BNE    $FACB
fad4: a6 01           LDA    $1,X
fad6: b7 23 df        STA    $23DF
fad9: ae 02           LDX    $2,X
fadb: 10 8e 23 e0     LDY    #$23E0
fadf: e6 80           LDB    ,X+
fae1: e7 a0           STB    ,Y+
fae3: 4a              DECA
fae4: 26 f9           BNE    $FADF
fae6: 39              RTS
fae7: fc 7e b5        LDD    $7EB5
faea: 17 82 63        LBSR   $7D50
faed: be 23 bf        LDX    $23BF
faf0: 30 88 21        LEAX   $21,X
faf3: ae 84           LDX    ,X
faf5: 16 00 56        LBRA   $FB4E
faf8: c6 07           LDB    #$07
fafa: e7 62           STB    $2,S
fafc: 16 00 74        LBRA   $FB73
faff: c6 07           LDB    #$07
fb01: e7 62           STB    $2,S
fb03: be 23 bf        LDX    $23BF
fb06: 30 0d           LEAX   $D,X
fb08: ae 84           LDX    ,X
fb0a: 8c 00 04        CMPX   #$0004
fb0d: 10 26 00 2c     LBNE   $FB3D
fb11: fe 3f d1        LDU    $3FD1
fb14: 10 8e 3f d3     LDY    #$3FD3
fb18: 8e 00 04        LDX    #$0004
fb1b: 34 70           PSHS   U,Y,X
fb1d: 17 58 5d        LBSR   $537D
fb20: 32 66           LEAS   $6,S
fb22: fc 3f d4        LDD    $3FD4
fb25: ed 63           STD    $3,S
fb27: ee 63           LDU    $3,S
fb29: 10 8e 00 02     LDY    #$0002
fb2d: 34 60           PSHS   U,Y
fb2f: 17 57 77        LBSR   $52A9
fb32: 32 64           LEAS   $4,S
fb34: fd 3f d4        STD    $3FD4
fb37: cc 3f d3        LDD    #$3FD3
fb3a: fd 3f d1        STD    $3FD1
fb3d: 16 00 33        LBRA   $FB73
fb40: c6 02           LDB    #$02
fb42: e7 62           STB    $2,S
fb44: 16 00 2c        LBRA   $FB73
fb47: c6 08           LDB    #$08
fb49: e7 62           STB    $2,S
fb4b: 16 00 25        LBRA   $FB73
fb4e: 8c 00 0f        CMPX   #$000F
fb51: 2e f4           BGT    $FB47
fb53: 1f 10           TFR    X,D
fb55: 83 00 07        SUBD   #$0007
fb58: 2d ed           BLT    $FB47
fb5a: 8e 7b 61        LDX    #$7B61
fb5d: 58              ASLB
fb5e: 49              ROLA
fb5f: 6e 9b           JMP    [D,X]
fb61: 7a f8 7a        DEC    $F87A
fb64: f8 7a ff        EORB   $7AFF
fb67: 7b 40 7b        XDEC   $407B
fb6a: 47              ASRA
fb6b: 7b 40 7b        XDEC   $407B
fb6e: 40              NEGA
fb6f: 7b 40 7b        XDEC   $407B
fb72: 40              NEGA
fb73: e6 62           LDB    $2,S
fb75: e7 65           STB    $5,S
fb77: 32 66           LEAS   $6,S
fb79: 39              RTS
fb7a: fc 7e bd        LDD    $7EBD
fb7d: 17 81 d0        LBSR   $7D50
fb80: c6 01           LDB    #$01
fb82: e7 63           STB    $3,S
fb84: c6 09           LDB    #$09
fb86: e7 64           STB    $4,S
fb88: 6f 65           CLR    $5,S
fb8a: c6 02           LDB    #$02
fb8c: e7 66           STB    $6,S
fb8e: ce 25 81        LDU    #$2581
fb91: f6 24 f4        LDB    $24F4
fb94: 4f              CLRA
fb95: 1f 02           TFR    D,Y
fb97: 34 60           PSHS   U,Y
fb99: 86 01           LDA    #$01
fb9b: 8e 7e b7        LDX    #$7EB7
fb9e: 17 81 49        LBSR   $7CEA
fba1: af 69           STX    $9,S
fba3: be 22 15        LDX    $2215
fba6: 16 00 2c        LBRA   $FBD5
fba9: fc 23 bf        LDD    $23BF
fbac: fd 3f d1        STD    $3FD1
fbaf: 16 00 39        LBRA   $FBEB
fbb2: be 23 bf        LDX    $23BF
fbb5: 30 05           LEAX   $5,X
fbb7: bf 3f d1        STX    $3FD1
fbba: 16 00 2e        LBRA   $FBEB
fbbd: ae 69           LDX    $9,S
fbbf: 30 04           LEAX   $4,X
fbc1: bf 3f d1        STX    $3FD1
fbc4: 16 00 24        LBRA   $FBEB
fbc7: cc 26 71        LDD    #$2671
fbca: fd 3f d1        STD    $3FD1
fbcd: 16 00 1b        LBRA   $FBEB
fbd0: 6f 63           CLR    $3,S
fbd2: 16 00 16        LBRA   $FBEB
fbd5: 8c 00 01        CMPX   #$0001
fbd8: 27 cf           BEQ    $FBA9
fbda: 8c 00 06        CMPX   #$0006
fbdd: 27 d3           BEQ    $FBB2
fbdf: 8c 00 0c        CMPX   #$000C
fbe2: 27 d9           BEQ    $FBBD
fbe4: 8c 00 0f        CMPX   #$000F
fbe7: 27 de           BEQ    $FBC7
fbe9: 20 e5           BRA    $FBD0
fbeb: e6 63           LDB    $3,S
fbed: c1 00           CMPB   #$00
fbef: 10 27 00 35     LBEQ   $FC28
fbf3: ce 22 85        LDU    #$2285
fbf6: 10 be 3f d1     LDY    $3FD1
fbfa: 8e 00 04        LDX    #$0004
fbfd: 34 70           PSHS   U,Y,X
fbff: 17 4e 8d        LBSR   $4A8F
fc02: 32 66           LEAS   $6,S
fc04: 5f              CLRB
fc05: 1d              SEX
fc06: 1f 03           TFR    D,U
fc08: c6 07           LDB    #$07
fc0a: 1d              SEX
fc0b: 1f 02           TFR    D,Y
fc0d: c6 08           LDB    #$08
fc0f: 1d              SEX
fc10: 1f 01           TFR    D,X
fc12: cc 22 85        LDD    #$2285
fc15: 34 76           PSHS   U,Y,X,D
fc17: ce 22 85        LDU    #$2285
fc1a: 10 8e 00 0a     LDY    #$000A
fc1e: 34 60           PSHS   U,Y
fc20: 17 51 2d        LBSR   $4D50
fc23: 32 6c           LEAS   $C,S
fc25: 16 02 77        LBRA   $FE9F
fc28: c6 01           LDB    #$01
fc2a: e7 63           STB    $3,S
fc2c: be 22 15        LDX    $2215
fc2f: 16 00 67        LBRA   $FC99
fc32: be 23 bf        LDX    $23BF
fc35: 30 88 15        LEAX   $15,X
fc38: ae 84           LDX    ,X
fc3a: af 67           STX    $7,S
fc3c: 16 00 70        LBRA   $FCAF
fc3f: be 23 bf        LDX    $23BF
fc42: 30 88 1b        LEAX   $1B,X
fc45: ae 84           LDX    ,X
fc47: af 67           STX    $7,S
fc49: 16 00 63        LBRA   $FCAF
fc4c: ae 69           LDX    $9,S
fc4e: 30 0b           LEAX   $B,X
fc50: ae 84           LDX    ,X
fc52: af 67           STX    $7,S
fc54: ae 69           LDX    $9,S
fc56: 30 0d           LEAX   $D,X
fc58: ae 84           LDX    ,X
fc5a: 8c 00 04        CMPX   #$0004
fc5d: 10 26 00 0f     LBNE   $FC70
fc61: ee 67           LDU    $7,S
fc63: 10 8e 00 02     LDY    #$0002
fc67: 34 60           PSHS   U,Y
fc69: 17 56 3d        LBSR   $52A9
fc6c: 32 64           LEAS   $4,S
fc6e: ed 67           STD    $7,S
fc70: 16 00 3c        LBRA   $FCAF
fc73: fc 26 7d        LDD    $267D
fc76: ed 67           STD    $7,S
fc78: be 26 79        LDX    $2679
fc7b: 8c 00 04        CMPX   #$0004
fc7e: 10 26 00 0f     LBNE   $FC91
fc82: ee 67           LDU    $7,S
fc84: 10 8e 00 02     LDY    #$0002
fc88: 34 60           PSHS   U,Y
fc8a: 17 56 1c        LBSR   $52A9
fc8d: 32 64           LEAS   $4,S
fc8f: ed 67           STD    $7,S
fc91: 16 00 1b        LBRA   $FCAF
fc94: 6f 63           CLR    $3,S
fc96: 16 00 16        LBRA   $FCAF
fc99: 8c 00 03        CMPX   #$0003
fc9c: 27 94           BEQ    $FC32
fc9e: 8c 00 08        CMPX   #$0008
fca1: 27 9c           BEQ    $FC3F
fca3: 8c 00 0e        CMPX   #$000E
fca6: 27 a4           BEQ    $FC4C
fca8: 8c 00 11        CMPX   #$0011
fcab: 27 c6           BEQ    $FC73
fcad: 20 e5           BRA    $FC94
fcaf: e6 63           LDB    $3,S
fcb1: c1 00           CMPB   #$00
fcb3: 10 27 00 38     LBEQ   $FCEF
fcb7: ce 22 85        LDU    #$2285
fcba: 10 ae 67        LDY    $7,S
fcbd: 8e 00 04        LDX    #$0004
fcc0: 34 70           PSHS   U,Y,X
fcc2: 17 4c 4d        LBSR   $4912
fcc5: 32 66           LEAS   $6,S
fcc7: 5f              CLRB
fcc8: 1d              SEX
fcc9: 1f 03           TFR    D,U
fccb: c6 04           LDB    #$04
fccd: 1d              SEX
fcce: 1f 02           TFR    D,Y
fcd0: c6 05           LDB    #$05
fcd2: 1d              SEX
fcd3: 1f 01           TFR    D,X
fcd5: cc 22 85        LDD    #$2285
fcd8: 34 76           PSHS   U,Y,X,D
fcda: ce 22 85        LDU    #$2285
fcdd: 10 8e 00 0a     LDY    #$000A
fce1: 34 60           PSHS   U,Y
fce3: 17 50 6a        LBSR   $4D50
fce6: 32 6c           LEAS   $C,S
fce8: c6 06           LDB    #$06
fcea: e7 64           STB    $4,S
fcec: 16 01 b0        LBRA   $FE9F
fcef: c6 01           LDB    #$01
fcf1: e7 63           STB    $3,S
fcf3: be 22 15        LDX    $2215
fcf6: 16 00 a4        LBRA   $FD9D
fcf9: be 23 bf        LDX    $23BF
fcfc: 30 0a           LEAX   $A,X
fcfe: bf 3f d1        STX    $3FD1
fd01: be 23 bf        LDX    $23BF
fd04: 30 88 1f        LEAX   $1F,X
fd07: ae 84           LDX    ,X
fd09: 8c 00 04        CMPX   #$0004
fd0c: 10 26 00 07     LBNE   $FD17
fd10: c6 01           LDB    #$01
fd12: e7 65           STB    $5,S
fd14: 16 00 0c        LBRA   $FD23
fd17: ce 00 00        LDU    #$0000
fd1a: 34 40           PSHS   U
fd1c: 17 fd c8        LBSR   $FAE7
fd1f: 32 62           LEAS   $2,S
fd21: e7 66           STB    $6,S
fd23: be 23 bf        LDX    $23BF
fd26: 30 88 21        LEAX   $21,X
fd29: ae 84           LDX    ,X
fd2b: 8c 00 0b        CMPX   #$000B
fd2e: 10 26 00 04     LBNE   $FD36
fd32: c6 08           LDB    #$08
fd34: e7 64           STB    $4,S
fd36: be 23 bf        LDX    $23BF
fd39: 30 88 14        LEAX   $14,X
fd3c: e6 84           LDB    ,X
fd3e: f7 22 85        STB    $2285
fd41: 16 00 71        LBRA   $FDB5
fd44: ae 69           LDX    $9,S
fd46: 30 07           LEAX   $7,X
fd48: bf 3f d1        STX    $3FD1
fd4b: be 25 14        LDX    $2514
fd4e: 8c 00 04        CMPX   #$0004
fd51: 10 26 00 04     LBNE   $FD59
fd55: c6 01           LDB    #$01
fd57: e7 65           STB    $5,S
fd59: ae 69           LDX    $9,S
fd5b: 30 0a           LEAX   $A,X
fd5d: e6 84           LDB    ,X
fd5f: f7 22 85        STB    $2285
fd62: 16 00 50        LBRA   $FDB5
fd65: be 23 bf        LDX    $23BF
fd68: 30 0f           LEAX   $F,X
fd6a: bf 3f d1        STX    $3FD1
fd6d: ce 00 00        LDU    #$0000
fd70: 34 40           PSHS   U
fd72: 17 fd 72        LBSR   $FAE7
fd75: 32 62           LEAS   $2,S
fd77: e7 66           STB    $6,S
fd79: be 23 bf        LDX    $23BF
fd7c: 30 88 21        LEAX   $21,X
fd7f: ae 84           LDX    ,X
fd81: 8c 00 0b        CMPX   #$000B
fd84: 10 26 00 04     LBNE   $FD8C
fd88: c6 08           LDB    #$08
fd8a: e7 64           STB    $4,S
fd8c: 16 00 26        LBRA   $FDB5
fd8f: cc 26 74        LDD    #$2674
fd92: fd 3f d1        STD    $3FD1
fd95: 16 00 1d        LBRA   $FDB5
fd98: 6f 63           CLR    $3,S
fd9a: 16 00 18        LBRA   $FDB5
fd9d: 8c 00 02        CMPX   #$0002
fda0: 10 27 ff 55     LBEQ   $FCF9
fda4: 8c 00 07        CMPX   #$0007
fda7: 27 bc           BEQ    $FD65
fda9: 8c 00 0d        CMPX   #$000D
fdac: 27 96           BEQ    $FD44
fdae: 8c 00 10        CMPX   #$0010
fdb1: 27 dc           BEQ    $FD8F
fdb3: 20 e3           BRA    $FD98
fdb5: e6 63           LDB    $3,S
fdb7: c1 00           CMPB   #$00
fdb9: 10 27 00 65     LBEQ   $FE22
fdbd: ce 22 86        LDU    #$2286
fdc0: 10 be 3f d1     LDY    $3FD1
fdc4: 8e 00 04        LDX    #$0004
fdc7: 34 70           PSHS   U,Y,X
fdc9: 17 4c c3        LBSR   $4A8F
fdcc: 32 66           LEAS   $6,S
fdce: e6 65           LDB    $5,S
fdd0: c1 00           CMPB   #$00
fdd2: 10 27 00 28     LBEQ   $FDFE
fdd6: c6 0a           LDB    #$0A
fdd8: e7 64           STB    $4,S
fdda: 5f              CLRB
fddb: 1d              SEX
fddc: 1f 03           TFR    D,U
fdde: c6 03           LDB    #$03
fde0: 1d              SEX
fde1: 1f 02           TFR    D,Y
fde3: c6 09           LDB    #$09
fde5: 1d              SEX
fde6: 1f 01           TFR    D,X
fde8: cc 22 85        LDD    #$2285
fdeb: 34 76           PSHS   U,Y,X,D
fded: ce 22 85        LDU    #$2285
fdf0: 10 8e 00 0a     LDY    #$000A
fdf4: 34 60           PSHS   U,Y
fdf6: 17 4f 57        LBSR   $4D50
fdf9: 32 6c           LEAS   $C,S
fdfb: 16 00 21        LBRA   $FE1F
fdfe: 5f              CLRB
fdff: 1d              SEX
fe00: 1f 03           TFR    D,U
fe02: e6 66           LDB    $6,S
fe04: 4f              CLRA
fe05: 1f 02           TFR    D,Y
fe07: c6 08           LDB    #$08
fe09: 1d              SEX
fe0a: 1f 01           TFR    D,X
fe0c: cc 22 85        LDD    #$2285
fe0f: 34 76           PSHS   U,Y,X,D
fe11: ce 22 86        LDU    #$2286
fe14: 10 8e 00 0a     LDY    #$000A
fe18: 34 60           PSHS   U,Y
fe1a: 17 4f 33        LBSR   $4D50
fe1d: 32 6c           LEAS   $C,S
fe1f: 16 00 7d        LBRA   $FE9F
fe22: be 22 15        LDX    $2215
fe25: 16 00 66        LBRA   $FE8E
fe28: be 23 bf        LDX    $23BF
fe2b: 30 88 1f        LEAX   $1F,X
fe2e: ce 22 85        LDU    #$2285
fe31: ae 84           LDX    ,X
fe33: 1f 12           TFR    X,Y
fe35: 8e 00 04        LDX    #$0004
fe38: 34 70           PSHS   U,Y,X
fe3a: 17 4a d5        LBSR   $4912
fe3d: 32 66           LEAS   $6,S
fe3f: c6 05           LDB    #$05
fe41: e7 64           STB    $4,S
fe43: 16 00 59        LBRA   $FE9F
fe46: be 23 bf        LDX    $23BF
fe49: 30 88 21        LEAX   $21,X
fe4c: ce 22 85        LDU    #$2285
fe4f: ae 84           LDX    ,X
fe51: 1f 12           TFR    X,Y
fe53: 8e 00 04        LDX    #$0004
fe56: 34 70           PSHS   U,Y,X
fe58: 17 4a b7        LBSR   $4912
fe5b: 32 66           LEAS   $6,S
fe5d: c6 05           LDB    #$05
fe5f: e7 64           STB    $4,S
fe61: 16 00 3b        LBRA   $FE9F
fe64: f6 24 f4        LDB    $24F4
fe67: 53              COMB
fe68: 1d              SEX
fe69: 84 00           ANDA   #$00
fe6b: c4 0f           ANDB   #$0F
fe6d: e7 62           STB    $2,S
fe6f: ce 22 85        LDU    #$2285
fe72: e6 62           LDB    $2,S
fe74: 4f              CLRA
fe75: 1f 02           TFR    D,Y
fe77: 8e 00 04        LDX    #$0004
fe7a: 34 70           PSHS   U,Y,X
fe7c: 17 4b 52        LBSR   $49D1
fe7f: 32 66           LEAS   $6,S
fe81: c6 03           LDB    #$03
fe83: e7 64           STB    $4,S
fe85: 16 00 17        LBRA   $FE9F
fe88: 16 00 27        LBRA   $FEB2
fe8b: 16 00 11        LBRA   $FE9F
fe8e: 8c 00 04        CMPX   #$0004
fe91: 27 95           BEQ    $FE28
fe93: 8c 00 05        CMPX   #$0005
fe96: 27 ae           BEQ    $FE46
fe98: 8c 00 12        CMPX   #$0012
fe9b: 27 c7           BEQ    $FE64
fe9d: 20 e9           BRA    $FE88
fe9f: e6 64           LDB    $4,S
fea1: 4f              CLRA
fea2: 1f 03           TFR    D,U
fea4: 10 8e 22 85     LDY    #$2285
fea8: 8e 00 04        LDX    #$0004
feab: 34 70           PSHS   U,Y,X
fead: 17 21 4e        LBSR   $1FFE
feb0: 32 66           LEAS   $6,S
feb2: 32 6b           LEAS   $B,S
feb4: 39              RTS
feb5: 00 04           NEG    <$04
feb7: 00 01           NEG    <$01
feb9: 00 00           NEG    <$00
febb: 00 0f           NEG    <$0F
febd: 00 09           NEG    <$09
; --- $FF padding to end of page 3 / end of ROM ---
febf: ff ff ff        STU    $FFFF
fec2: ff ff ff        STU    $FFFF
fec5: ff ff ff        STU    $FFFF
fec8: ff ff ff        STU    $FFFF
fecb: ff ff ff        STU    $FFFF
fece: ff ff ff        STU    $FFFF
fed1: ff ff ff        STU    $FFFF
fed4: ff ff ff        STU    $FFFF
fed7: ff ff ff        STU    $FFFF
feda: ff ff ff        STU    $FFFF
fedd: ff ff ff        STU    $FFFF
fee0: ff ff ff        STU    $FFFF
fee3: ff ff ff        STU    $FFFF
fee6: ff ff ff        STU    $FFFF
fee9: ff ff ff        STU    $FFFF
feec: ff ff ff        STU    $FFFF
feef: ff ff ff        STU    $FFFF
fef2: ff ff ff        STU    $FFFF
fef5: ff ff ff        STU    $FFFF
fef8: ff ff ff        STU    $FFFF
fefb: ff ff ff        STU    $FFFF
fefe: ff ff ff        STU    $FFFF
ff01: ff ff ff        STU    $FFFF
ff04: ff ff ff        STU    $FFFF
ff07: ff ff ff        STU    $FFFF
ff0a: ff ff ff        STU    $FFFF
ff0d: ff ff ff        STU    $FFFF
ff10: ff ff ff        STU    $FFFF
ff13: ff ff ff        STU    $FFFF
ff16: ff ff ff        STU    $FFFF
ff19: ff ff ff        STU    $FFFF
ff1c: ff ff ff        STU    $FFFF
ff1f: ff ff ff        STU    $FFFF
ff22: ff ff ff        STU    $FFFF
ff25: ff ff ff        STU    $FFFF
ff28: ff ff ff        STU    $FFFF
ff2b: ff ff ff        STU    $FFFF
ff2e: ff ff ff        STU    $FFFF
ff31: ff ff ff        STU    $FFFF
ff34: ff ff ff        STU    $FFFF
ff37: ff ff ff        STU    $FFFF
ff3a: ff ff ff        STU    $FFFF
ff3d: ff ff ff        STU    $FFFF
ff40: ff ff ff        STU    $FFFF
ff43: ff ff ff        STU    $FFFF
ff46: ff ff ff        STU    $FFFF
ff49: ff ff ff        STU    $FFFF
ff4c: ff ff ff        STU    $FFFF
ff4f: ff ff ff        STU    $FFFF
ff52: ff ff ff        STU    $FFFF
ff55: ff ff ff        STU    $FFFF
ff58: ff ff ff        STU    $FFFF
ff5b: ff ff ff        STU    $FFFF
ff5e: ff ff ff        STU    $FFFF
ff61: ff ff ff        STU    $FFFF
ff64: ff ff ff        STU    $FFFF
ff67: ff ff ff        STU    $FFFF
ff6a: ff ff ff        STU    $FFFF
ff6d: ff ff ff        STU    $FFFF
ff70: ff ff ff        STU    $FFFF
ff73: ff ff ff        STU    $FFFF
ff76: ff ff ff        STU    $FFFF
ff79: ff ff ff        STU    $FFFF
ff7c: ff ff ff        STU    $FFFF
ff7f: ff ff ff        STU    $FFFF
ff82: ff ff ff        STU    $FFFF
ff85: ff ff ff        STU    $FFFF
ff88: ff ff ff        STU    $FFFF
ff8b: ff ff ff        STU    $FFFF
ff8e: ff ff ff        STU    $FFFF
ff91: ff ff ff        STU    $FFFF
ff94: ff ff ff        STU    $FFFF
ff97: ff ff ff        STU    $FFFF
ff9a: ff ff ff        STU    $FFFF
ff9d: ff ff ff        STU    $FFFF
ffa0: ff ff ff        STU    $FFFF
ffa3: ff ff ff        STU    $FFFF
ffa6: ff ff ff        STU    $FFFF
ffa9: ff ff ff        STU    $FFFF
ffac: ff ff ff        STU    $FFFF
ffaf: ff ff ff        STU    $FFFF
ffb2: ff ff ff        STU    $FFFF
ffb5: ff ff ff        STU    $FFFF
ffb8: ff ff ff        STU    $FFFF
ffbb: ff ff ff        STU    $FFFF
ffbe: ff ff ff        STU    $FFFF
ffc1: ff ff ff        STU    $FFFF
ffc4: ff ff ff        STU    $FFFF
ffc7: ff ff ff        STU    $FFFF
ffca: ff ff ff        STU    $FFFF
ffcd: ff ff ff        STU    $FFFF
ffd0: ff ff ff        STU    $FFFF
ffd3: ff ff ff        STU    $FFFF
ffd6: ff ff ff        STU    $FFFF
ffd9: ff ff ff        STU    $FFFF
ffdc: ff ff ff        STU    $FFFF
ffdf: ff ff ff        STU    $FFFF
ffe2: ff ff ff        STU    $FFFF
ffe5: ff ff ff        STU    $FFFF
ffe8: ff ff ff        STU    $FFFF
ffeb: ff ff ff        STU    $FFFF
ffee: ff ff ff        STU    $FFFF
fff1: ff ff ff        STU    $FFFF
fff4: ff ff ff        STU    $FFFF
fff7: ff ff ff        STU    $FFFF
fffa: ff ff ff        STU    $FFFF
fffd: ff ff ff        STU    $FFFF
