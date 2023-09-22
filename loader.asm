;
; This loader will be contained within a REM statement in
; a BASIC program created using bin2rem.
;
		#define		CUSTOM_LOADER 0

        #define     MEM_BANK_ROM 0x10
        #define     IO_BORDER 0xfe
        #define     IO_BANK 0x7ffd
        #define     MIC_OUTPUT 8
  IF CUSTOM_LOADER
        #define     LD_BYTES $c000 - +(LD_BYTES_END-LD_BYTES_START) - 3
  ELSE
        #define     LD_BYTES 0x556
  ENDIF
        #define     ERR_SP 0x5c3d
        ; Screen memory addresses and dimensions
        #define     SCREEN_START 0x4000
        #define     SCREEN_LENGTH 0x1800
        #define     SCREEN_END SCREEN_START + SCREEN_LENGTH
        #define     SCREEN_ATTR_START SCREEN_START + SCREEN_LENGTH
        #define     SCREEN_ATTR_LENGTH 0x300
        #define     SCREEN_ATTR_END SCREEN_ATTR_START + SCREEN_ATTR_LENGTH
        #define     BORDCR 0x5c48

        ; Start address used by bin2rem 23766
        org     0x5cd6
start:
        di
        ld      sp, stack

        ; Set screen attributes
        ld      hl, SCREEN_ATTR_START
        ld      de, SCREEN_ATTR_START+1
        ld      (hl), 0
        ld      bc, SCREEN_ATTR_LENGTH-1
        ldir

  IF CUSTOM_LOADER
        ; Copy LD_BYTES to a non-interleaved bank
        ld      hl, LD_BYTES_START
        ld      de, LD_BYTES
        ld      bc, LD_BYTES_END-LD_BYTES_START
        ldir
  ENDIF

        ld      a, MEM_BANK_ROM
        ld      hl, screen
        ; Load the screen
        call    loadBlock
        ; Load banks 5, 2, 0 in one go
        call    loadBlock

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
        jr      nz, exec

fullLoad:
        ld      a, MEM_BANK_ROM
        ld      hl, banks

nextBank:
        call    loadBlock
        inc     a
        cp      MEM_BANK_ROM|8
        jr      nz, nextBank

exec:
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
        push    af
        push    hl

        ; Set the bank to load
        ld      bc, IO_BANK
        out     (c), a

        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      a, d
        or      e
        jr      z, loadBlockDone
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

  IF CUSTOM_LOADER
        call    LD_BYTES                ; Do the load
  ELSE
        ld      a, 0xff                 ; Data block
        scf                             ; Load not verify
        ld      hl, $0000               ; Address to jump to on error
        push    hl
        ld      (ERR_SP), sp
        call    LD_BYTES                ; Do the load
        di
        pop     hl                      ; Error handler address
  ENDIF
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
        ld      bc, $6
        add     hl, bc
        pop     af
        ret

  IF CUSTOM_LOADER
LD_BYTES_START:
        binary  "ld_bytes.bin"
LD_BYTES_END:
  ENDIF

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
; -----------------------------------------------------------------------------

        ds      24, $55
stack:
execAddr:
        ds      2
screen:
        ds      6                       ; Screen
mainBank:
        ds      6                       ; Main bank (5, 2, 0)
banks:
        ds      6*8                     ; Banks 0-7
