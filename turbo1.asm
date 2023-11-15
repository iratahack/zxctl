        DEFC    MIC_OUTPUT=0x08
        DEFC    EAR_INPUT=0x40
        DEFC    IO_ULA=0xfe
        DEFC    INIT_BORDER=0x00|MIC_OUTPUT
		DEFC	CONSTANT=$B0
        DEFC    CRT_LOADER_RAINBOW=1

        ; $c000 - size of routine - compression delta
        org     $c000-160
        ;
        ; LD_BYTES routine from the ZX Spectrum ROM
        ;
        ; Input:
        ;       ix - Address to load data block
        ;
        ; This routine does not perform 'verify', check the data block type,
        ; check for BREAK or call SA_LD_RET.
        ; Also, there is no flag or parity byte.
        ;
        ; There is no need to pass in the length, the end of the
        ; load is detected if there is a timeout when looking
        ; for the edges of a data byte.
        ;
        ; This loader also takes code from other places to handle run-length
        ; encoding and compression of 0's to a single pulse.
        ;
LD_BYTES:
        LD      A, INIT_BORDER          ; Set the initial border color.
        OUT     (IO_ULA), A
        IN      A, (IO_ULA)             ; Make an initial read of port '254'.
        AND     EAR_INPUT
        LD      C, A                    ; Store the value in the C register (+40 for 'off' and +00 for 'on' - the present EAR state).

LD_START:
		LD		H, 0
; Now accept only a 'leader signal'.
LD_LEADER:
        LD      B, $9C                  ; The timing constant.
        CALL    LD_EDGE_2               ; Continue only if two edges are found within the allowed time period.
        JR      NC, LD_START
        LD      A, $C6                  ; However the edges must have been found within about 3,000 T states of each other.
        CP      B
        JR      NC, LD_START
        INC     H                       ; Count the pair of edges in the H register until '256' pairs have been found.
        JR      NZ, LD_LEADER

; After the leader come the 'off' and 'on' parts of the sync pulse.
LD_SYNC:
        LD      B, $C9                  ; The timing constant.
        CALL    LD_EDGE_1               ; Every edge is considered until two edges are found close together - these will be the start and finishing edges of the 'off' sync pulse.
        JR      NC, LD_START
        LD      A, B
        CP      $D4
        JR      NC, LD_SYNC
        CALL    LD_EDGE_1               ; The finishing edge of the 'on' pulse must exist. (Return carry flag reset.)
        RET     NC
        JR      LD_DEC                  ; Jump forward into the byte loading loop.

; The byte loading loop is used to fetch the bytes one at a time. The flag byte is first. This is followed by the data bytes and the last byte is the 'parity' byte.
LD_LOOP:
        LD      (IX+$00), L             ; Make the actual load when required.

; A new byte can now be collected from the tape.
        INC     IX                      ; Increase the 'destination'.
LD_DEC:
        LD      B, CONSTANT             ; Set the timing constant.
LD_MARKER:
        LD      L, $01                  ; Clear the 'object' register apart from a 'marker' bit.

; The following loop is used to build up a byte in the L register.
LD_8_BITS:
        CALL    LD_EDGE_2               ; Find the length of the 'off' and 'on' pulses of the next bit.
        RET     NC                      ; Return if the time period is exceeded. (Carry flag reset.)
		LD		A, B
		CP		CONSTANT+$28
		JR		NC, escSeq

        CP		CONSTANT+$18            ; Compare the length against approx. 2,400 T states, resetting the carry flag for a '0' and setting it for a '1'.
		CCF
        RL      L                       ; Include the new bit in the L register.
        LD      B, CONSTANT             ; Set the timing constant for the next bit.
        JR      NC, LD_8_BITS           ; Jump back whilst there are still bits to be fetched.
		JR		LD_LOOP

escSeq:
        DEC     L                       ; L = 1 here, decrement it to get 0
        LD      B, CONSTANT             ; Set the timing constant  ($B2 in the ROM)
        CALL    LD_EDGE_2               ; Find the length of the 'off' and 'on' pulses of the next bit
        RET     NC                      ; Return if the time period is exceeded (Carry flag reset)

        LD      A, CONSTANT+$18
        CP      B                       ; the 'long' bit stands for a whole byte set to 0

        JR      C, LD_LOOP              ; jp if longer

            ; ok, this is a longer period,  look for a byte repeated sequence

        LD      L, (IX-1)               ; load the last byte value

zbloop:
        LD      B, CONSTANT             ; Set the timing constant  ($B2 in the ROM)
        CALL    LD_EDGE_2               ; Find the length of the 'off' and 'on' pulses of the next bit
        RET     NC                      ; Return if the time period is exceeded (Carry flag reset)

        LD      A, CONSTANT+$18
        CP      B
        JR      C, LD_LOOP              ; jp if longer

        LD      (IX+0), L
        INC     IX

        JR      zbloop

LD_EDGE_2:
        CALL    LD_EDGE_1               ; In effect call LD_EDGE_1 twice, returning in between if there is an error.
        RET     NC

; This entry point is used by the routine at LD_BYTES.
LD_EDGE_1:
        LD      A, $12                  ; Wait xxx T states before entering the sampling loop.
LD_DELAY:
        DEC     A
        JR      NZ, LD_DELAY

; The sampling loop is now entered. The value in the B register is incremented for each pass;  'time-up' is given when B reaches zero.
; Each unsuccessful loop takes 48 cycles
LD_SAMPLE:
        INC     B                       ; [4] Count each pass.
        RET     Z                       ; [5/11] Return carry reset and zero set if 'time-up'.
        LD      A, 0x7F                 ; [7] Trigger for emulators to let them know we are a loader.
                                        ; These two instructions cause a read from 0x7ffe which includes
                                        ; the 'BREAK' key in bit 0
        IN      A, (IO_ULA)				; [11]
        XOR     C                       ; [4] Now test the byte against the 'last edge-type';  jump back unless it has changed.
        AND     EAR_INPUT				; [7]
        JR      Z, LD_SAMPLE			; [7/12]

; A new 'edge' has been found within the time period allowed for the search. So change the border colour and set the carry flag.
        LD      A, C                    ; [4] Change the 'last edge-type'.
        XOR     EAR_INPUT				; [7]
        LD      C, A
  IF    CRT_LOADER_RAINBOW
        LD      A, R                    ; [9]
        AND     0x07                    ; [7]
  ELSE
        RLCA                            ; [4] Shift the EAR bit (bit 6) into the border color (bit 1)
        RLCA							; [4]
        RLCA							; [4]
  ENDIF
        OR      MIC_OUTPUT              ; [7] Signal 'MIC off'.
        OUT     (IO_ULA), A             ; [11] Change the border colour (red/black).
        SCF                             ; [4] Signal the successful search before returning.
        RET								; [9]
