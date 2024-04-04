.include "constants.inc"
.include "header.inc"

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
	LDA #$00
	STA $2005
	STA $2005
  RTI
.endproc

.import reset_handler

.export main
.proc main
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; write sprite data
  LDX #$00
load_sprites:
  LDA sprites,X
  STA $0200,X
  INX
  CPX #$94
  BNE load_sprites

	; attribute table
	LDA PPUSTATUS
	LDA #$23
	STA PPUADDR
	LDA #$c2
	STA PPUADDR
	LDA #%01000000
	STA PPUDATA

	LDA PPUSTATUS
	LDA #$23
	STA PPUADDR
	LDA #$e0
	STA PPUADDR
	LDA #%00001100
	STA PPUDATA

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
.exportzp player_x, player_y

.segment "RODATA"
palettes:
.byte $0f, $00, $10, $20
.byte $0f, $06, $16, $27
.byte $0f, $0b, $1a, $29
.byte $0f, $19, $09, $29

.byte $0f, $0c, $21, $37
.byte $0f, $00, $10, $20
.byte $0f, $06, $16, $27
.byte $0f, $0b, $1a, $29

sprites:
.byte $10, $00, $00, $10
.byte $18, $10, $00, $10
.byte $10, $00, $00, $1c
.byte $18, $15, $00, $1c
.byte $10, $00, $00, $28
.byte $18, $06, $00, $28
.byte $20, $17, $00, $10
.byte $28, $08, $00, $10
.byte $20, $17, $00, $1c
.byte $28, $18, $00, $1c
.byte $20, $17, $00, $28
.byte $28, $09, $00, $28
.byte $30, $16, $00, $10
.byte $38, $19, $00, $10
.byte $30, $16, $00, $1c
.byte $38, $1a, $00, $1c
.byte $30, $16, $00, $28
.byte $38, $1b, $00, $28
.byte $40, $07, $00, $10
.byte $48, $0a, $00, $10
.byte $40, $07, $00, $1c
.byte $48, $0b, $00, $1c
.byte $40, $07, $00, $28
.byte $48, $0c, $00, $28
.byte $50, $01, $00, $10
.byte $50, $11, $00, $1c
.byte $50, $02, $00, $28
.byte $50, $12, $00, $34
.byte $50, $03, $00, $40
.byte $50, $05, $00, $4c
.byte $60, $13, $00, $10
.byte $68, $23, $00, $10
.byte $60, $04, $00, $1c
.byte $68, $25, $00, $1c
.byte $60, $14, $00, $28
.byte $68, $24, $00, $28

.segment "CHR"
.incbin "MySprites.chr"