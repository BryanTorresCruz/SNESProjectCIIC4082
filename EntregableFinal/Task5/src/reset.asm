.include "constants.inc"

.segment "ZEROPAGE"
.importzp player_x, player_y, player_dir, player_anistate, oam_s, animation_frame, pad1, pad1_holds, pad1_press, ppu_tile, ppu_hibyte, ppu_lobyte, tile_offset, tilechnk, scroll_x, screen, stage

.segment "CODE"
.import main
.export reset_handler
.proc reset_handler
  ; Ignore random IRQs then clear useless BCD logic
  SEI
  CLD
  
  ; Disable audio IRQs
  LDX #$40
  STX $4017

  ; Set up the stack
  LDX #$FF
  TXS

  ; FF -> 00 to clear CTRL and MASK
  INX
  STX PPUCTRL
  STX PPUMASK
  STX $4010

  ; Wait for PPU to fully boot
  BIT PPUSTATUS
vblankwait:
  BIT PPUSTATUS
  BPL vblankwait
vblankwait2:
  BIT PPUSTATUS
  BPL vblankwait2

  ; Set defaults for all the variables
  LDA #$00
  STA player_x
  LDA #$BF
  STA player_y
  LDA #$00
  STA player_dir
  STA player_anistate
  STA animation_frame
  STA pad1_holds
  STA pad1_press
  STA ppu_tile
  STA ppu_hibyte
  STA ppu_lobyte
  STA tile_offset
  STA tilechnk
  STA scroll_x
  STA screen
  STA stage

  JMP main
.endproc
