.include "constants.inc"

.segment "CODE"

.export draw_wall
.proc draw_wall

; write a nametable
  ; wall
  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$c4
  STA PPUADDR
  LDX #$01
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$c5
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$c6
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$e4
  STA PPUADDR
  STX PPUDATA
.endproc

.export draw_door
.proc draw_door
  ; door
  LDA PPUSTATUS
	LDA #$23
	STA PPUADDR
	LDA #$df
	STA PPUADDR
	LDX #$13
	STX PPUDATA

	LDA PPUSTATUS
	LDA #$23
	STA PPUADDR
	LDA #$ff
	STA PPUADDR
	LDX #$23
	STX PPUDATA

  ; attribute table
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$d9
  STA PPUADDR
  LDA #%00000000
  STA PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$ef
  STA PPUADDR
  LDA #%00100000
  STA PPUDATA
.endproc
