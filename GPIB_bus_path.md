There are GPIB transceiver ICs between the P8291A and physical port. These include A2U17 DS75161AN (for interface management), and A2U18 DS75160AN (for data). Pin 11 of A2U17 (direction control) is hard-wired to VCC, so ATN, REN, and IFC are always receivers, and SRQ is always a transmitter, but NRFD, NDAC and DAV depend on the state of TE (pin 1).

## External GPIB bus connections
The GPIB bus uses TTL where low voltage levels represent logical 1.

| GPIB Pin | GPIB Line | A2U17 Pin | A2U18 Pin |
|---|---|---|---|
| 1 | DIO1 | — | 2 |
| 2 | DIO2 | — | 3 |
| 3 | DIO3 | — | 4 |
| 4 | DIO4 | — | 5 |
| 5 | EOI | 7 | — |
| 6 | DAV | 6 | — |
| 7 | NRFD | 5 | — |
| 8 | NDAC | 4 | — |
| 9 | IFC | 3 | — |
| 10 | SRQ | 9 | — |
| 11 | ATN | 8 | — |
| 13 | DIO5 | — | 6 |
| 14 | DIO6 | — | 7 |
| 15 | DIO7 | — | 8 |
| 16 | DIO8 | — | 9 |
| 17 | REN | 2 | — |

## P8291A GPIB IC connections
The P8291A pins for GPIB lines are active low, and their names are prefixed with "_" to indicate this (in the datasheet this is represented as a bar over the line name).

| P8291A Pin | P8291A Line | A2U17 Pin | A2U18 Pin |
|---|---|---|---|
| 1 | T/_R 1 | 1 (Talk Enable) | 1 (Talk Enable) |
| 2 | T/_R 2 |  —| 11 (Pull-Up Enable) |
| 24 | _IFC | 18 | — |
| 25 | _REN | 19 | — |
| 26 | _ATN | 13 | — |
| 27 | _SRQ | 12 | — |
| 28 | _DIO1 | — | 19 |
| 29 | _DIO2 | — | 18 |
| 30 | _DIO3 | — | 17 |
| 31 | _DIO4 | — | 16 |
| 32 | _DIO5 | — | 15 |
| 33 | _DIO6 | — | 14 |
| 34 | _DIO7 | — | 13 |
| 35 | _DIO8 | — | 12 |
| 36 | _DAV | 15 | — |
| 37 | _NRFD | 16 | — |
| 38 | _NDAC | 17 | — |
| 39 | _EOI | 14 | — |
| 40 | VCC | 11 (Direction Control) | — |


## Line Levels During GPIB Stall (bug in firmware)

#### GPIB Bus

Measured on the GPIB bus with original (unmodified) firmware. Voltages checked on both the 8904A and Prologix controller sides to determine which device drives each line.

| Signal | Normal (after power-up) | During Stall |
|---|---|---|
| EOI | High (idle) | High (idle) |
| DAV | High (idle) | High (idle) |
| NRFD | High (idle) | High (idle) |
| NDAC | High (idle) | **Low (driven by 8904A)** |
| IFC | High (idle) | High (idle) |
| SRQ | High (idle) | **Low (driven by 8904A)** |
| ATN | High (idle) | High (idle) |
| REN | Low (driven by Prologix) | Low (driven by Prologix) |

#### P8291A Pins During Stall

| P8291A Pin | P8291A Line | Level |
|---|---|---|
| 1 | T/_R 1 | Low |
| 2 | T/_R 2 | Low |
| 24 | _IFC | High |
| 25 | _REN | Low |
| 26 | _ATN | High |
| 27 | _SRQ | Low |
| 36 | _DAV | High |
| 37 | _NRFD | High |
| 38 | _NDAC | Low |
| 39 | _EOI | High |

#### MC6809 CPU Pins During Stall

| MC6809 Pin | MC6809 Line | Level |
|---|---|---|
| 2 | _NMI | High |
| 3 | _IRQ | Low |
| 4 | _FIRQ | High |
| 5 | BS | Low |
| 6 | BA | Low |

## Line Levels During GPIB Stall, with intermediate latch-only firmware a2u12_fix_irq_latch.bin

#### GPIB Bus

Measured on the GPIB bus with the intermediate latch-only firmware `a2u12_fix_irq_latch.bin`. Voltages checked on both the 8904A and Prologix controller sides to determine which device drives each line.

| Signal | Normal (after power-up) | During Stall |
|---|---|---|
| EOI | High (idle) | High (idle) |
| DAV | High (idle) | High (idle) |
| NRFD | High (idle) | **Low (driven by 8904A)** |
| NDAC | High (idle) | **Low (driven by 8904A)** |
| IFC | High (idle) | High (idle) |
| SRQ | High (idle) | **Low (driven by 8904A)** |
| ATN | High (idle) | High (idle) |
| REN | Low (driven by Prologix) | Low (driven by Prologix) |

#### P8291A Pins During Stall

| P8291A Pin | P8291A Line | Level |
|---|---|---|
| 1 | T/_R 1 | Low |
| 2 | T/_R 2 | Low |
| 24 | _IFC | High |
| 25 | _REN | Low (goes high if Prologix unplugged) |
| 26 | _ATN | High |
| 27 | _SRQ | Low |
| 36 | _DAV | High |
| 37 | _NRFD | Low |
| 38 | _NDAC | Low |
| 39 | _EOI | High |

#### MC6809 CPU Pins During Stall

| MC6809 Pin | MC6809 Line | Level |
|---|---|---|
| 2 | _NMI | High |
| 3 | _IRQ | Low |
| 4 | _FIRQ | High |
| 5 | BS | Low |
| 6 | BA | Low |
