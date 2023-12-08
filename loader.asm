;
; This loader will be contained within a REM statement in
; a BASIC program created using bin2rem.
;

        defc    MEM_BANK_ROM=0x10
        defc    IO_BORDER=0xfe
        defc    IO_BANK=0x7ffd
        defc    MIC_OUTPUT=8
        defc    FLD_BYTES=+($c000-160)
        defc    LD_BYTES=0x556
        defc    ERR_SP=0x5c3d
        ; Screen memory addresses and dimensions
        defc    SCREEN_START=0x4000
        defc    SCREEN_LENGTH=0x1800
        defc    SCREEN_END=SCREEN_START+SCREEN_LENGTH
        defc    SCREEN_ATTR_START=SCREEN_START+SCREEN_LENGTH
        defc    SCREEN_ATTR_LENGTH=0x300
        defc    SCREEN_ATTR_END=SCREEN_ATTR_START+SCREEN_ATTR_LENGTH
        defc    BORDCR=0x5c48

;
; ROM routine addresses
;
ROM_CLS EQU     0x0DAF                  ; Clears the screen and opens channel 2
ROM_OPEN_CHANNEL    EQU 0x1601          ; Open a channel
ROM_PRINT   EQU 0x203C                  ; Print a string
ATTR_P  EQU     0x5C8D
;
; PRINT control codes - work with ROM_PRINT and RST 0x10
;
INK     EQU     0x10
PAPER   EQU     0x11
FLASH   EQU     0x12
BRIGHT  EQU     0x13
INVERSE EQU     0x14
OVER    EQU     0x15
AT      EQU     0x16
TAB     EQU     0x17
CR      EQU     0x0C

        ; Start address used by bin2rem 23766
        org     0x5cd6
start:
        di
        ld      sp, stack

        xor     a
        ld      (ATTR_P), a
        call    ROM_CLS

        ; Copy LD_BYTES to a non-contended bank
        ld      bc, 160
        ld      hl, LD_BYTES_START
        ld      de, FLD_BYTES
        ldir

        ; Detect 128K/48K
detect48K:
        ld      de, $c000
        ld      bc, IO_BANK             ; Memory bank port

        xor     a
        out     (c), a                  ; Select bank 0
        ld      (de), a                 ; Write 0 to bank 0

        inc     a
        out     (c), a                  ; Select bank 1
        ld      (de), a                 ; Write 1 to bank 1

        dec     a
        out     (c), a                  ; Select bank 0
        ld      a, (de)                 ; Read value from bank 0

        ; a = 0 (128K)
        ; a = 1 (48K)
        or      a
        jr      z, fullLoad

        ; Prevent 128K banks from loading
        ; on 48K systems
        ld      b, 9
        ld      hl, blocks
        ld      de, 7
testBlock:
        ld      a, $15
        cp      (hl)
        jr      z, loadIt
        ld      a, $12
        cp      (hl)
        jr      z, loadIt
        ld      a, $10
        cp      (hl)
        jr      z, loadIt
        ; Prevent block from loading by setting back
        ; to -1
        ld      (hl), -1
loadIt:
        add     hl, de
        djnz    testBlock

fullLoad:
        ld      b, 9
        ld      hl, blocks
nextBlock:
        call    loadBlock
        djnz    nextBlock

        ld      a, MEM_BANK_ROM
        ld      bc, IO_BANK             ; Memory bank port
        out     (c), a                  ; Select bank 0
        ; Exec address is stored directly above stack
        ; we can simply return to the execAddr
        ret

		;
		; Load and decompress a block from tape
		;
		; Input:
        ;       a   - bank
        ;       hl  - Pointer to block data
		;
loadBlock:
        push    bc
        push    hl

        ; Set the bank to load
        ld      bc, IO_BANK
        ld      a, (hl)
        or      a
        jp      m, loadBlockDone
        inc     hl
        out     (c), a

        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        push    de                      ; loadSize

        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl
        push    bc                      ; loadAddr
        push    bc
        pop     ix

        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl
        push    bc                      ; destAddr

        ld      a, 0xff                 ; Data block
        scf                             ; Load not verify
        ld      hl, tapeError           ; Address to jump to on error
        push    hl
        ld      (ERR_SP), sp
tapeLoader  equ $+1
        call    LD_BYTES                ; Do the load
        di
        ret     nc
        pop     hl                      ; Error handler address

        ld      a, MIC_OUTPUT
        out     (IO_BORDER), a

        pop     de                      ; destAddr
        pop     hl                      ; loadAddr
        pop     bc                      ; loadSize
        ld      a, d
        cp      $40                     ; Check for $40xx (screen memory)
        jr      nz, reverse             ; if not, use reverse decompression
        call    dzx0_standard           ; else, decompress forwards
        jr      loadBlockDone

reverse:
        add     hl, bc
        dec     hl                      ; Last byte of loaded data
        call    dzx0_standard_back      ; Decompress backwards

loadBlockDone:
        pop     hl
        ld      bc, $7
        add     hl, bc
        pop     bc
        ret

; -----------------------------------------------------------------------------
; ZX0 decoder by Einar Saukas
; "Standard" version (69 bytes only) - BACKWARDS VARIANT
; -----------------------------------------------------------------------------
; Parameters:
;   HL: last source address (compressed data)
;   DE: last destination address (decompressing)
; -----------------------------------------------------------------------------
dzx0_standard_back:
        ld      bc, 1                   ; preserve default offset 1
        push    bc
        ld      a, $80
dzx0sb_literals:
        call    dzx0sb_elias            ; obtain length
        lddr                            ; copy literals
        inc     c
        add     a, a                    ; copy from last offset or new offset?
        jr      c, dzx0sb_new_offset
        call    dzx0sb_elias            ; obtain length
dzx0sb_copy:
        ex      (sp), hl                ; preserve source, restore offset
        push    hl                      ; preserve offset
        add     hl, de                  ; calculate destination - offset
        lddr                            ; copy from offset
        inc     c
        pop     hl                      ; restore offset
        ex      (sp), hl                ; preserve offset, restore source
        add     a, a                    ; copy from literals or new offset?
        jr      nc, dzx0sb_literals
dzx0sb_new_offset:
        inc     sp                      ; discard last offset
        inc     sp
        call    dzx0sb_elias            ; obtain offset MSB
        dec     b
        ret     z                       ; check end marker
        dec     c                       ; adjust for positive offset
        ld      b, c
        ld      c, (hl)                 ; obtain offset LSB
        dec     hl
        srl     b                       ; last offset bit becomes first length bit
        rr      c
        inc     bc
        push    bc                      ; preserve new offset
        ld      bc, 1                   ; obtain length
        call    c, dzx0sb_elias_backtrack
        inc     bc
        jr      dzx0sb_copy
dzx0sb_elias_backtrack:
        add     a, a
        rl      c
        rl      b
dzx0sb_elias:
        add     a, a                    ; inverted interlaced Elias gamma coding
        jr      nz, dzx0sb_elias_skip
        ld      a, (hl)                 ; load another group of 8 bits
        dec     hl
        rla
dzx0sb_elias_skip:
        jr      c, dzx0sb_elias_backtrack
        ret
; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------
; ZX0 decoder by Einar Saukas & Urusergi
; "Standard" version (68 bytes only)
; -----------------------------------------------------------------------------
; Parameters:
;   HL: source address (compressed data)
;   DE: destination address (decompressing)
; -----------------------------------------------------------------------------
dzx0_standard:
        ld      bc, $ffff               ; preserve default offset 1
        push    bc
        inc     bc
        ld      a, $80
dzx0s_literals:
        call    dzx0s_elias             ; obtain length
        ldir                            ; copy literals
        add     a, a                    ; copy from last offset or new offset?
        jr      c, dzx0s_new_offset
        call    dzx0s_elias             ; obtain length
dzx0s_copy:
        ex      (sp), hl                ; preserve source, restore offset
        push    hl                      ; preserve offset
        add     hl, de                  ; calculate destination - offset
        ldir                            ; copy from offset
        pop     hl                      ; restore offset
        ex      (sp), hl                ; preserve offset, restore source
        add     a, a                    ; copy from literals or new offset?
        jr      nc, dzx0s_literals
dzx0s_new_offset:
        pop     bc                      ; discard last offset
        ld      c, $fe                  ; prepare negative offset
        call    dzx0s_elias_loop        ; obtain offset MSB
        inc     c
        ret     z                       ; check end marker
        ld      b, c
        ld      c, (hl)                 ; obtain offset LSB
        inc     hl
        rr      b                       ; last offset bit becomes first length bit
        rr      c
        push    bc                      ; preserve new offset
        ld      bc, 1                   ; obtain length
        call    nc, dzx0s_elias_backtrack
        inc     bc
        jr      dzx0s_copy
dzx0s_elias:
        inc     c                       ; interlaced Elias gamma coding
dzx0s_elias_loop:
        add     a, a
        jr      nz, dzx0s_elias_skip
        ld      a, (hl)                 ; load another group of 8 bits
        inc     hl
        rla
dzx0s_elias_skip:
        ret     c
dzx0s_elias_backtrack:
        add     a, a
        rl      c
        rl      b
        jr      dzx0s_elias_loop

tapeError:
        call    ROM_CLS
        ld      de, tapeErrorMsg
        ld      bc, tapeErrorMsgEnd-tapeErrorMsg
        call    ROM_PRINT
        jr      $
tapeErrorMsg:
        db      AT, 11, 6, INK, 2, PAPER, 0, FLASH, 1, "Tape loading error!!"
tapeErrorMsgEnd:

; -----------------------------------------------------------------------------
        ds      32, $55
stack:
        ds      2
blocks:
        REPT    9
        db      $ff
        ds      6
        ENDR
        ; The below is overwritten with the tape loader
LD_BYTES_START:
        ds      160, $55
