.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_anistate: .res 1
oam_s: .res 1
animation_frame: .res 1  ; New variable to store animation frame
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
pad1_holds: .res 1            ; Bytes that deal with player 1's held inputs
pad1_press: .res 1            ; Bytes that deal with player 1's press inputs
ppu_tile: .res 1            ; PPU tile to write onto the nametable
ppu_hibyte: .res 1            ; High byte of the PPU offset to write to
ppu_lobyte: .res 1            ; Low byte of the PPU offset to write to
tile_offset: .res 1            ; Tile offset to use when getting the PPU tile
tilechnk: .res 1            ; Chunk of tiles being extracted for writing
scroll_x: .res 1            ; X-pos of the scroll line
screen: .res 1            ; Nametable screen to use
stage: .res 1            ; Which stage to load
.exportzp player_x, player_y, player_dir, player_anistate, oam_s, animation_frame, pad1, pad1_holds, pad1_press, ppu_tile, ppu_hibyte, ppu_lobyte, tile_offset, tilechnk, scroll_x, screen, stage

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.import read_controller1

.proc nmi_handler
 ; Copy mempage 2 into OAM on every interrupt
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  ; OAM reads $00s as sprites so $FF the rest of it
  LDX #$00
oam_clean:
  LDA #$FF
  STA $0200,X
  INX
  CPX #$00
  BNE oam_clean
  
  ; read controller
  JSR read_controller1
  ; update tiles *after* DMA transfer
  JSR draw_player
  JSR update_player

  ; Alternate stages on select, A or B button press
  LDA pad1_press
  AND #%11100000
  BEQ stage_skip

  ; If any of the said buttons are pressed, disable PPU flags
  LDX #$00
  STX PPUCTRL
  LDX #%00000110
  STX PPUMASK

  ; Load second stage palette
  LDX #$3F
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palette:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palette

  ; Call drawing routine with given parameters then reenable PPUMASK
  LDA #$01
  STA stage
  LDA #$00
  STA ppu_hibyte
  STA ppu_lobyte
  JSR draw_screens
  LDA #%00011110
  STA PPUMASK
stage_skip:
  
  ; Update PPUSCROLL based on player position
  LDX scroll_x
  STX PPUSCROLL
  LDX #$00
  STX PPUSCROLL

  ; Determine on which screen to load the player on
  LDA screen
  LSR A
  LDA #%01001000
  ROL A
  STA PPUCTRL
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
  LDA #$00
  STA stage
  STA ppu_hibyte
  STA ppu_lobyte
  JSR draw_screens

  LDX #$00
  STX PPUSCROLL
  STX PPUSCROLL
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

.proc update_player
  ; Stack push
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Initialize counter, then load player direction and add animation state
  LDX #$00
  LDA player_dir
  CLC
  ADC player_anistate
  TAY
load_sprites:
  ; Add player y-coord to the sprite y-coord
  LDA sprites, Y
  CLC
  ADC player_y
  STA $0200, X
  INY
  INX

  ; Sprite ID
  LDA sprites, Y
  STA $0200, X
  INY
  INX

  ; Sprite flags
  LDA sprites, Y
  STA $0200, X
  INY
  INX

  ; Add player x-coord to the sprite x-coord
  LDA sprites, Y
  CLC
  ADC player_x
  STA $0200, X
  INY
  INX

  ; Have we written four sprites? If not, continue loop
  CPX #$10
  BNE load_sprites

  ; Stack pull
  PLA
  TYA
  PLA
  TXA
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  LDA pad1_press
  AND #BTN_START
  BEQ pause_check
  LDA animation_frame
  EOR #%10000000
  STA animation_frame

  ; Ignores player inputs and freezes animations if paused (too big to just branch)
pause_check:
  LDA animation_frame
  AND #%10000000
  BEQ right_check
  JMP end
 ; Check each of the button inputs, starting with right
  ; Depending on button input, change player direction and xy coords
  right_check:
  LDA pad1_holds
  AND #BTN_RIGHT
  BEQ left_check
  LDA #$90
  STA player_dir
  LDA #$78
  CMP player_x
  BEQ right_scroll
right_move:
  LDA #$F0
  CMP player_x
  BEQ left_check
  INC player_x
  JMP end_check
left_check:
  LDA pad1_holds
  AND #BTN_LEFT
  BEQ down_check
  LDA #$60
  STA player_dir
  LDA #$78
  CMP player_x
  BEQ left_scroll
left_move:
  LDA #$00
  CMP player_x
  BEQ down_check
  DEC player_x
  JMP end_check
down_check:
  LDA pad1_holds
  AND #BTN_DOWN
  BEQ up_check
  LDA #$00
  STA player_dir
  LDA #$D7
  CMP player_y
  BEQ end_check
  INC player_y
  JMP end_check
up_check:
  LDA pad1_holds
  AND #BTN_UP
  BEQ end_check
  LDA #$30
  STA player_dir
  LDA #$07
  CMP player_y
  BEQ end_check
  DEC player_y
  JMP end_check
right_scroll:
  LDA #$01
  CMP screen
  BEQ right_move
  INC scroll_x
  LDA #$00
  CMP scroll_x
  BNE end_check
  INC screen
  JMP end_check
left_scroll:
  LDA #$00
  ORA screen
  CMP scroll_x
  BEQ left_move
  DEC scroll_x
  LDA #$FF
  CMP scroll_x
  BNE end_check
  DEC screen
  JMP end_check
end_check:

  ; Ignore animation procedure and reset counter if no direction is being held
  LDA pad1_holds
  AND #%00001111
  BEQ cnt_reset

  ; Increase then load animation counter
  INC animation_frame
  LDA animation_frame

  ; Compare counter to four possible states
  CMP #$10
  BCC frame_right
  CMP #$20
  BCC frame_mid
  CMP #$30
  BCC frame_left
  CMP #$40
  BCC frame_mid

cnt_reset:
  LDA #$00
  STA animation_frame
  JMP frame_mid

  ; Load corresponding frame then store to player animation state
frame_right:
  LDA #$10
  JMP store_frame
frame_left:
  LDA #$20
  JMP store_frame
frame_mid:
  LDA #$00
store_frame:
  STA player_anistate
end:
  PLA
  PLP
  RTS
.endproc

.proc draw_screens
  ; Stack push
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Shift stage number accordingly to get correct offset
  LSR stage
  ROR stage

  ; Change offset of tile IDs depending on which stage we're writing to
  LDX #$00
  LDY #$00
  LDA #$04
  STA tile_offset
  LDA stage
  CMP #$00
  BEQ byte_loop
  ASL tile_offset

  ; Firstly, offset counter with stage offset
byte_loop:
  TXA
  CLC
  ADC stage
  TAX

  ; Now load the first byte chunk to cycle through and store it in tilechnk
  LDA stagetiles, X
  STA tilechnk

  ; Clear accumulator and bitshift two bits of the tile chunk into it
chunk_loop:
  LDA #$00
  ASL tilechnk
  ROL A
  ASL tilechnk
  ROL A

  ; Add the tile ID offset before storing it in ppu_tile and draw the metatile
  CLC
  ADC tile_offset
  STA ppu_tile
  JSR draw_metatile

  ; With our metatile written, adjust ppu_lobt and Y-reg as necessary
  INC ppu_lobyte
  INC ppu_lobyte
  INY

  ; Check if the entire chunk has been iterated through (4 blocks per chunk)
  CPY #$04
  BNE chunk_loop

  ; Reset Y-reg, and check if the low bit has reached the next row
  LDY #$00
  LDA ppu_lobyte
  AND #%00100000
  BEQ sum_skip

  ; Skip that row since draw_metatile already drew on it
  LDA ppu_lobyte
  CLC
  ADC #$20
  STA ppu_lobyte

  ; If there was a carry, then store it into ppu_hibt
  LDA ppu_hibyte
  ADC #$00
  STA ppu_hibyte

  ; Finally, skip the next four bytes
  INX
  INX
  INX
  INX
sum_skip:

  ; Increase the byte counter and subtract the stage offset
  INX
  TXA
  SEC
  SBC stage
  TAX

  ; Branch to end if we've gone through both screens
  CPX #$7C
  BEQ end

  ; Branch to the byte loop, unless we're done with the first screen
  CPX #$78
  BNE byte_loop

  ; If done with first screen, set counter and PPU offsets to second screen and jump
  LDX #$04
  STX ppu_hibyte
  LDA #$00
  STA ppu_lobyte
  JMP byte_loop
end:

  ; After drawing both screens, end it off by drawing attributes
  JSR draw_attributes

  ; Correct stage number
  ASL stage
  ROL stage

  ; Stack pull
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_metatile
  ; Stack push
  PHP
  PHA
  TXA
  PHA

  ; Setup and draw first row of the metatile with PPU offsets
  LDA PPUSTATUS
  LDA #$20
  CLC 
  ADC ppu_hibyte
  STA PPUADDR
  LDA #$00
  CLC 
  ADC ppu_lobyte
  STA PPUADDR
  LDX #$00

loop:
  ; Load PPU tile and write it twice
  LDA ppu_tile
  STA PPUDATA
  STA PPUDATA

  ; Did we just draw the second row?
  CPX #$01
  BEQ end

  ; If not, setup and draw second row of the metatile
  INX
  LDA PPUSTATUS
  LDA #$20
  CLC 
  ADC ppu_hibyte
  STA PPUADDR
  LDA #$20
  CLC 
  ADC ppu_lobyte
  STA PPUADDR
  JMP loop
end:

  ; Stack pull
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_attributes
  ; Stack push
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Initiate PPU address to attribute section and initiate counter
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR
  LDX #$00

byte_loop:
  ; Offset counter with stage offset and reset accumulator
  TXA
  CLC
  ADC stage
  TAX

  ; Store the current byte into tilechnk
  LDY stagetiles, X
  STY tilechnk

  ; Do a series of rotates to extract the first attribute's lonibble
  LDA #$00
  ROL tilechnk
  ROL tilechnk
  ROR A
  ROR tilechnk
  ROR A
  ROL tilechnk
  ROL tilechnk
  ROL tilechnk
  ROR A
  ROR tilechnk
  ROR A

  ; Offset counter to the tilechnk below the current one
  INX
  INX
  INX
  INX
  INX
  INX
  INX
  INX

  ; Repeat rotates to extract the first attribute's hinibble
  LDY stagetiles, X
  STY tilechnk
  ROL tilechnk
  ROL tilechnk
  ROR A
  ROR tilechnk
  ROR A
  ROL tilechnk
  ROL tilechnk
  ROL tilechnk
  ROR A
  ROR tilechnk
  ROR A

  ; Return to the original tilechnk we were just on
  DEX
  DEX
  DEX
  DEX
  DEX
  DEX
  DEX
  DEX
  
  ; Store extracted attribute to PPUDATA, then reset accumulator
  STA PPUDATA
  LDA #$00

  ; Another series of rotates, this time for the second attribute's lonibble
  LDY stagetiles, X
  STY tilechnk
  ROR tilechnk
  ROR tilechnk
  ROR tilechnk
  ROR A
  ROR tilechnk
  ROR A
  ROL tilechnk
  ROL tilechnk
  ROL tilechnk
  ROR A
  ROR tilechnk
  ROR A

  ; Offset counter again
  INX
  INX
  INX
  INX
  INX
  INX
  INX
  INX

  ; Repeat rotates again to extract the second attribute's hinibble
  LDY stagetiles, X
  STY tilechnk
  ROR tilechnk
  ROR tilechnk
  ROR tilechnk
  ROR A
  ROR tilechnk
  ROR A
  ROL tilechnk
  ROL tilechnk
  ROL tilechnk
  ROR A
  ROR tilechnk
  ROR A

  ; Reduce offset once more
  DEX
  DEX
  DEX
  DEX
  DEX
  DEX
  DEX
  DEX

  ; Store second attribute to PPUDATA
  STA PPUDATA

  ; Store the prior counter, increase the counter and remove stage offset
  TXA
  AND #%00000100
  STA tilechnk
  INX
  TXA
  SEC
  SBC stage
  TAX

  ; Check if this is the end of a screen row and add accordingly
  AND #%00000100
  CMP tilechnk
  BEQ counter_checks
  TXA
  CLC
  ADC #$0C
  TAX

counter_checks:
  ; If we have written to both screens, end subroutine
  CPX #$84
  BEQ end

  ; Check the next byte of the loop unless we finished the first screen
  CPX #$80
  BNE byte_loop_jump
  
  ; Set counter and PPUADDR to the second screen before returning to loop
  LDX #$04
  LDA PPUSTATUS
  LDA #$27
  STA PPUADDR
  LDA #$C0
  STA PPUADDR
byte_loop_jump:
  JMP byte_loop
end:

  ; Stack pull
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler
.segment "RODATA"

palettes:
.byte $0f, $0c, $21, $37
.byte $0f, $00, $10, $20
.byte $0f, $06, $16, $27
.byte $0f, $0b, $1a, $29

.byte $0f, $0c, $21, $37
.byte $0f, $00, $10, $20
.byte $0f, $06, $16, $27
.byte $0f, $0b, $1a, $29


sprites:
;walking forward animation 
.byte $00, $30, %00100000, $00
.byte $00, $31, %00100000, $08
.byte $08, $40, %00100000, $00
.byte $08, $41, %00100000, $08

.byte $00, $30, %00100000, $00
.byte $00, $31, %00100000, $08
.byte $08, $50, %00100000, $00
.byte $08, $51, %00100000, $08

.byte $00, $30, %00100000, $00
.byte $00, $31, %00100000, $08
.byte $08, $60, %00100000, $00
.byte $08, $61, %00100000, $08

;walking backward animation 
.byte $00, $36, %00100000, $00
.byte $00, $37, %00100000, $08
.byte $08, $46, %00100000, $00
.byte $08, $47, %00100000, $08

.byte $00, $36, %00100000, $00
.byte $00, $37, %00100000, $08
.byte $08, $56, %00100000, $00
.byte $08, $57, %00100000, $08

.byte $00, $36, %00100000, $00
.byte $00, $37, %00100000, $08
.byte $08, $66, %00100000, $00
.byte $08, $67, %00100000, $08

;walking to the left animation 
.byte $00, $34, %00100000, $00
.byte $00, $35, %00100000, $08
.byte $08, $44, %00100000, $00
.byte $08, $45, %00100000, $08

.byte $00, $34, %00100000, $00
.byte $00, $35, %00100000, $08
.byte $08, $54, %00100000, $00
.byte $08, $55, %00100000, $08

.byte $00, $34, %00100000, $00
.byte $00, $35, %00100000, $08
.byte $08, $64, %00100000, $00
.byte $08, $65, %00100000, $08

;walking to the right animation 
.byte $00, $32, %00100000, $00
.byte $00, $33, %00100000, $08
.byte $08, $42, %00100000, $00
.byte $08, $43, %00100000, $08

.byte $00, $32, %00100000, $00
.byte $00, $33, %00100000, $08
.byte $08, $52, %00100000, $00
.byte $08, $53, %00100000, $08

.byte $00, $32, %00100000, $00
.byte $00, $33, %00100000, $08
.byte $08, $62, %00100000, $00
.byte $08, $63, %00100000, $08

stagetiles:
.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$03,$03,$03,$77,$77,$21,$86,$86,$77,$77,$77,$03,$03,$03,$03
	.byte $77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$03,$03,$03,$03,$01
	.byte $01,$03,$03,$03,$77,$77,$01,$77,$77,$77,$77,$77,$03,$03,$03,$03
	.byte $77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$03,$03,$03,$03,$01
	.byte $01,$03,$03,$03,$77,$77,$01,$77,$77,$77,$77,$77,$03,$03,$03,$03
	.byte $77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$03,$03,$03,$03,$01
	.byte $01,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$77,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$77,$01,$77,$77,$77
	.byte $77,$77,$77,$77,$77,$03,$03,$03,$03,$03,$01,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$01,$01,$77,$77,$77,$77,$77,$01,$77,$77,$77
	.byte $77,$01,$77,$77,$77,$03,$03,$03,$03,$03,$01,$01,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$01,$03,$03,$03,$77,$77,$77,$01,$77,$77,$77
	.byte $77,$01,$77,$77,$77,$03,$03,$03,$03,$03,$86,$01,$77,$77,$77,$01
	.byte $01,$86,$77,$77,$77,$01,$03,$03,$03,$77,$77,$77,$01,$77,$01,$77
	.byte $77,$01,$77,$01,$01,$01,$01,$01,$01,$86,$77,$01,$77,$77,$77,$01
	.byte $01,$01,$01,$01,$01,$01,$03,$03,$03,$77,$77,$77,$01,$77,$01,$77
	.byte $77,$01,$77,$01,$03,$03,$03,$03,$01,$01,$01,$01,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$01,$77,$01,$77
	.byte $77,$01,$77,$01,$03,$03,$03,$03,$03,$03,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01,$77
	.byte $77,$01,$77,$01,$03,$03,$03,$03,$03,$03,$a0,$77,$77,$77,$77,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$77,$77,$01,$77,$77,$77,$77,$01,$86
	.byte $77,$77,$86,$01,$03,$03,$03,$03,$03,$03,$86,$86,$86,$86,$77,$01
	.byte $01,$77,$77,$77,$77,$77,$01,$77,$77,$01,$77,$77,$77,$77,$01,$01
	.byte $01,$01,$86,$01,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$01,$01,$01,$77,$77,$01,$77,$77,$77,$77,$01,$77
	.byte $77,$77,$77,$01,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$01,$03,$03,$03,$03,$01,$77,$77,$77,$77,$01,$77
	.byte $77,$77,$77,$01,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$01,$03,$03,$03,$03,$01,$03,$03,$03,$03,$01,$77
	.byte $77,$77,$77,$01,$01,$01,$01,$01,$01,$01,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$01,$03,$03,$03,$03,$01,$03,$03,$03,$03,$01,$03
	.byte $03,$03,$03,$77,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$01,$03,$03,$03,$03,$01,$03,$03,$03,$03,$01,$03
	.byte $03,$03,$03,$77,$77,$01,$77,$77,$77,$01,$77,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$01,$77,$77,$77,$77,$01,$03,$03,$03,$03,$01,$03
	.byte $03,$03,$03,$77,$77,$01,$77,$77,$77,$01,$77,$77,$77,$77,$77,$01
	.byte $01,$86,$77,$77,$01,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01,$01
	.byte $01,$01,$01,$01,$77,$01,$01,$77,$77,$01,$77,$77,$77,$77,$77,$01
	.byte $01,$86,$86,$77,$01,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01,$03
	.byte $03,$77,$77,$01,$77,$77,$01,$77,$77,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$86,$86,$77,$01,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01,$03
	.byte $03,$77,$77,$01,$77,$77,$01,$77,$77,$77,$77,$77,$77,$77,$77,$13
	.byte $01,$86,$77,$77,$01,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01,$77
	.byte $77,$77,$77,$01,$77,$77,$01,$77,$77,$77,$77,$77,$77,$77,$77,$23
	.byte $01,$77,$77,$77,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01,$77
	.byte $77,$77,$77,$01,$01,$01,$01,$77,$77,$77,$01,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$77,$77,$77,$77,$01,$77,$77,$77,$01,$01,$77
	.byte $77,$77,$77,$01,$77,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$01
	.byte $01,$77,$77,$77,$77,$77,$01,$01,$01,$01,$77,$77,$77,$96,$03,$03
	.byte $03,$03,$03,$01,$77,$77,$77,$77,$03,$03,$01,$77,$77,$77,$77,$01
	.byte $b5,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$77,$77,$01,$03,$03
	.byte $03,$03,$03,$01,$77,$77,$77,$03,$03,$03,$01,$77,$77,$77,$77,$01
	.byte $77,$77,$77,$77,$77,$77,$01,$77,$77,$77,$77,$77,$77,$01,$03,$03
	.byte $03,$03,$03,$01,$77,$77,$77,$03,$03,$03,$01,$77,$77,$77,$77,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $00,$10,$50,$00,$50,$50,$10,$00,$44,$01,$45,$40,$40,$00,$00,$11
	.byte $40,$50,$44,$00,$00,$00,$00,$11,$40,$00,$44,$11,$10,$50,$50,$10
	.byte $44,$00,$00,$00,$00,$40,$44,$11,$00,$44,$44,$11,$00,$10,$50,$90
	.byte $44,$15,$44,$00,$01,$10,$01,$11,$00,$00,$00,$00,$00,$00,$00,$00



.segment "CHR"
.incbin "MySprites.chr"