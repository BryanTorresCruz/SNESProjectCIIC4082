.include "constants.inc"

.segment "ZEROPAGE"
.importzp pad1,pad1_holds, pad1_press

.segment "CODE"
.export read_controller1
.proc read_controller1
  ; Stack push
  PHP
  PHA

  LDA pad1_holds
  STA pad1_press
  ; Activate player 1's latch
  LDA #$01
  STA CONTROLLER1
  LDA #$00
  STA CONTROLLER1

  ; Initiate shift
  LDA #%00000001
  STA pad1_holds

  ; Loop until we get all button inputs
get_buttons:
  LDA CONTROLLER1
  LSR A
  ROL pad1_holds
  BCC get_buttons
  LDA pad1_press
  EOR pad1_holds
  AND pad1_holds
  STA pad1_press
  ; Stack pull
  PLA
  PLP
  RTS
.endproc