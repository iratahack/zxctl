        defc    CONSTANT=$D1
        ; $c000 - size of routine - compression delta
        org     $c000-160

LD_BYTES:
        IN      A, ($FE)                ; Make an initial read of port 254
        RRA                             ; Rotate the byte obtained
        AND     20h                     ; but keep only the EAR bit
        LD      C, A                    ; Store the value in the C register
LD_BREAK:
        CP      A                       ; Set the zero flag
LD_START:
;   Now accept only a 'leader signal'.
LD_LEADER:
        LD      B, 9Ch                  ; The timing constant
        CALL    LD_EDGE_2               ; Continue only if two edges are found
        JR      NC, LD_BREAK            ; within the allowed time period

        LD      A, $C6                  ; However the edges must have been found
        CP      B                       ; within about 3,000 T states of each other
        JR      NC, LD_START
        INC     H                       ; Count the pair of edges in the H register
        JR      NZ, LD_LEADER           ; until 256 pairs have been found


;   After the leader come the 'off' and 'on' parts of the sync pulse.
LD_SYNC:
        LD      B, $C9                  ; The timing constant
        CALL    LD_EDGE_1               ; Every edge is considered until two edges
        JR      NC, LD_BREAK            ; are found close together -

        LD      A, B                    ; these will be the start and finishing edges of the
        CP      $D4                     ; 'off' sync pulse
        JR      NC, LD_SYNC

        CALL    LD_EDGE_1               ; The finishing edge of the 'on' pulse
        RET     NC                      ; must exist (Return carry flag reset)

        LD      A, C                    ; The border colours from now on will be
        XOR     03h                     ; BLUE & YELLOW (in ROM)
        LD      C, A
        LD      B, $D0                  ; Set the timing constant for the flag byte  (was B0 in the original ROM)
        JR      LD_MARKER               ; Jump forward into the byte LOADing loop


; The byte LOADing loop is used to fetch the bytes one at a time. The flag byte is
; first. This is followed by the data bytes and the last byte is the 'parity' byte.

LD_LOOP:
        LD      (IX+00h), L
LD_NEXT:
        INC     IX                      ; dst location
LD_DEC:
        LD      B, CONSTANT             ; Set the timing constant  ($B2 in the ROM)
LD_MARKER:
        LD      L, 01h                  ; Clear the 'object' register apart from a 'marker' bit

LD_8_BITS:                              ; The 'LD-8-BITS' loop is used to build up a byte in the L register.
        CALL    LD_EDGE_2               ; Find the length of the 'off' and 'on' pulses of the next bit
        RET     NC                      ; Return if the time period is exceeded (Carry flag reset)
        ld      a, b
        cp      $de
        JP      NC, escseq

        cp      $d5                     ; carry set if period is shorter
        ccf
        RL      L                       ; Include the new bit in the L register
        LD      B, $D0                  ; Set the timing constant for the next bit ($B0)
        JP      NC, LD_8_BITS           ; Jump back whilst there are still bits to be fetched
                            ; (GB-MAX was jumping in FFB3 to POP DE/RET ???)

; Passes round the loop are made until the 'counter' reaches zero. At that point
; the 'parity matching' byte should be holding zero.
nextbyte:
        JP      LD_LOOP
escseq:
        dec     l
        LD      B, CONSTANT             ; Set the timing constant  ($B2 in the ROM)
        CALL    LD_EDGE_2               ; Find the length of the 'off' and 'on' pulses of the next bit
        RET     NC                      ; Return if the time period is exceeded (Carry flag reset)

        LD      A, $D7
        CP      B                       ; the 'long' bit stands for a whole byte set to 0

        jp      c, nextbyte             ; jp if longer

            ; ok, this is a longer period,  look for a byte repeated sequence

        ld      l, (ix-1)               ; load the last byte value

zbloop:
        LD      B, CONSTANT             ; Set the timing constant  ($B2 in the ROM)
        CALL    LD_EDGE_2               ; Find the length of the 'off' and 'on' pulses of the next bit
        RET     NC                      ; Return if the time period is exceeded (Carry flag reset)

        LD      A, $D5
        CP      B
        jp      c, nextbyte             ; jp if longer

        ld      (ix+0), l
        inc     ix

        jp      zbloop



; THE 'LD-EDGE-2' and 'LD-EDGE-1' SUBROUTINES
; These two subroutines form the most important part of the LOAD/VERIFY operation.
; The subroutines are entered with a timing constant in the B register, and the
; previous border colour and 'edge-type' in the C register.
; The subroutines return with the carry flag set if the required number of 'edges'
; have been found in the time allowed; and the change to the value in the B
; register shows just how long it took to find the 'edge(s)'.
; The carry flag will be reset if there is an error. The zero flag then signals
; 'BREAK pressed' by being reset, or 'time-up' by being set.
; The entry point LD-EDGE-2 is used when the length of a complete pulse is
; required and LD-EDGE-1 is used to find the time before the next 'edge'.


LD_EDGE_2:
        CALL    LD_EDGE_1               ; In effect call LD-EDGE-1 twice;
        RET     NC                      ; returning in between in there is an error

LD_EDGE_1:
        LD      A, 0Dh                  ; (was 16 in ROM) Wait 358 T states before entering the sampling loop
LD_DELAY:
        DEC     A
        JR      NZ, LD_DELAY
        AND     A

; The sampling loop is now entered. The value in the B register is incremented for
; each pass; 'time-up' is given when B reaches zero.

LD_SAMPLE:
        INC     B                       ; Count each pass
        RET     Z                       ; Return carry reset & zero set if 'time-up'.
        LD      A, 7Fh                  ;
        IN      A, ($FE)                ; Read from port +7FFE
        RRA                             ; shift the byte
;                RET  NC                 Return carry reset & zero reset if BREAK was pressed
        XOR     C                       ; Now test the byte against the 'last edge-type'
        AND     20h                     ; Jump back unless it has changed
        JR      Z, LD_SAMPLE


; A new 'edge' has been found within the time period allowed for the search.
; So change the border colour and set the carry flag.

        LD      A, C                    ; Change the 'last edge-type'
        CPL                             ; and border colour

        LD      C, A                    ; (ROM) ld a,c  ... (in ROM: RED/CYAN or BLUE/YELLOW)

  IF 0
        LD      A, B                    ; (ROM) cpl
        NOP                             ; (ROM) ld c,a
  ELSE
        LD      A, R
  ENDIF
        AND     7                       ; Keep only the border colour
        OR      8                       ; Signal 'MIC off'
        OUT     ($FE), a                ; Change the border colour
        SCF                             ; Signal the successful search before returning
        RET


;Note: The LD-EDGE-1 subroutine takes 464 T states, plus an additional 59 T
;states for each unsuccessful pass around the sampling loop.
;For example, therefore, when awaiting the sync pulse (see LD-SYNC)
;allowance is made for ten additional passes through the sampling loop.
;The search is thereby for the next edge to be found within, roughly, 1,100 T
;states (464 + 10 * 59 overhead).
;This will prove successful for the sync 'off' pulse that comes after the long
;'leader pulses'.
