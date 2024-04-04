.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
animation_frame: .res 1  ; New variable to store animation frame
.exportzp player_x, player_y, pad1

; Define delay constants
.define DELAY_FRAMES 30  ; Adjust this value to change animation speed

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.import read_controller1

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
  LDA #$00
  
  ; read controller
  JSR read_controller1
  ; update tiles *after* DMA transfer
  JSR update_player
  JSR draw_player

  STA $2005
  STA $2005
  RTI
.endproc

.import reset_handler
.import draw_wall
.import draw_door

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

  ;write NameTables
  LDX #$20
  JSR draw_wall

  LDX #$20
  JSR draw_door
  ; write sprite data
  LDX #$00
load_sprites:
  LDA sprites,X
  STA $0200,X
  INX
  CPX #$08
  BNE load_sprites

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
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Increment animation frame
  INC animation_frame
  ; Check if it's time to update animation frame
  LDA animation_frame
  CMP #DELAY_FRAMES
  BCC exit_subroutine  ; If animation frame < delay frames, exit subroutine

  ; If animation frame >= delay frames, reset frame and toggle direction
  LDA #$00
  STA animation_frame
  ; Toggle player direction between 0 and 1
  LDA player_dir
  EOR #$01
  STA player_dir

exit_subroutine:
  ; all done, clean up and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; write player ship tile numbers based on animation frame
  LDA player_dir
  BEQ draw_forward
  JMP draw_forward1

draw_forward:
  LDA #$00
  STA $0201
  LDA #$10
  STA $0209
  JMP done_drawing

draw_forward1:
  LDA #$00
  STA $0201
  LDA animation_frame
  CMP #$05
  BCC not_transition
  JMP transition_tiles

not_transition:
  LDA #$10
  STA $0209
  JMP done_drawing

transition_tiles:
  LDA animation_frame
  CMP #$08
  BCC draw_tile_15
  LDA #$06
  STA $0209
  JMP done_drawing

draw_tile_15:
  LDA #$15 
  STA $0209

done_drawing:
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; restore registers and return
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
.byte $90, $00, $00, $10

.segment "CHR"
.incbin "MySprites.chr"
