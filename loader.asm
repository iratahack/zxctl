;
; This loader will be contained within a REM statement in
; a BASIC program created using bin2rem.
;
        #define     MIC_OUTPUT 8
        #define     LD_BYTES 0x556
        #define     ERR_SP 0x5c3d

        org     23766                   ; Start address used by bin2rem
start:
        di
        ld      sp, stack

		ld		hl, $5800
		ld		de, $5801
		ld		(hl), 0
		ld		bc, $300-1
		ldir

        ld      hl, banks
        ld      b, 7                    ; # of banks
nextBank:
        push    bc
        push    hl

		; Get length
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      a, d
        or      e
        jr      z, skip

        push    de                      ; Save length

		; Get load address
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl

        push    bc                      ; Save load address

        push    bc
        pop     ix

		; Get destination end
        ld      c, (hl)
        inc     hl
        ld      b, (hl)
        inc     hl

        push    bc                      ; Save dest end address

        call    loadBlock

		; Set the border color
        ld      a, MIC_OUTPUT
        out     ($fe), a

        pop     de                      ; Dest end address
        pop     hl                      ; Load address
        pop     bc                      ; Load length
        add     hl, bc
        dec     hl                      ; Last byte of loaded data
        call    dzx0_standard_back      ; Decompress backwards
skip:
        pop     hl
        ld      bc, 6
        add     hl, bc
        pop     bc
        djnz    nextBank

		; Execute the program
        ld      hl, (execAddr)
        jp      (hl)

		;
		; Load a block from tape
		;
		; Input:
		;		de	- Length
		;		ix	- Load address
		;
loadBlock:
        ld      a, 0xff                 ; Data block
        scf                             ; Load not verify
        ld      hl, $0000               ; Address to jump to on error
        push    hl
        ld      (ERR_SP), sp
        call    LD_BYTES
        di
        pop     hl                      ; Error handler address
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
        dec     c
        ld      a, $80
dzx0sb_literals:
        call    dzx0sb_elias            ; obtain length
        lddr                            ; copy literals
        add     a, a                    ; copy from last offset or new offset?
        jr      c, dzx0sb_new_offset
        call    dzx0sb_elias            ; obtain length
dzx0sb_copy:
        ex      (sp), hl                ; preserve source, restore offset
        push    hl                      ; preserve offset
        add     hl, de                  ; calculate destination - offset
        lddr                            ; copy from offset
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
dzx0sb_elias:
        inc     c                       ; inverted interlaced Elias gamma coding
dzx0sb_elias_loop:
        add     a, a
        jr      nz, dzx0sb_elias_skip
        ld      a, (hl)                 ; load another group of 8 bits
        dec     hl
        rla
dzx0sb_elias_skip:
        ret     nc
dzx0sb_elias_backtrack:
        add     a, a
        rl      c
        rl      b
        jr      dzx0sb_elias_loop
; -----------------------------------------------------------------------------
        ds      32, $55
stack:
execAddr:
        ds      2
banks:
        ds      6                       ; Screen
        ds      6                       ; Bank 1
        ds      6                       ; Bank 3
        ds      6                       ; Bank 4
        ds      6                       ; Bank 6
        ds      6                       ; Bank 7
        ds      6                       ; Main bank (5, 2, 0)
