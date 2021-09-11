; VIA 65C22 register and control addresses
PORTB	= $6000
PORTA	= $6001
DDRB	= $6002
DDRA	= $6003
T1CL	= $6004
T1CH	= $6005
T1LL	= $6006
T1LH	= $6007
T2CL	= $6008
T2CH	= $6009
SR		= $600a
ACR		= $600b
PCR		= $600c
IFR		= $600d
IER		= $600e


E =  %10000000
RW = %01000000
RS = %00100000

TEMPY	= $01

NOTEL	= $14		; 2 byte pointer to note lsb
NOTEH	= $16		; 2 byte pointer to note msb

	.org $8000
reset:

; ------------- LCD Message
    jsr init_via_ports	; Set up VIA ports
	jsr init_lcd 	; Initialize the LCD
    jsr clear_lcd	; Clear the LCD 

    ldx #2			; Clearing the LCD directly needs an idle timeout afterwards
.wait:				; this can be cleaned up with a check_busy_flag operation
    lda #$ff
    jsr sleep
    dex
    bne .wait

	lda #<message	; Load message address into A and Y
    ldy #>message
    jsr write_to_screen	; Call subroutine to print the message

; -------------  Play Music

	lda #$40        ; 01000000
	sta IER         ; Interrupt Enable Register

	lda #$c0        ; enable the timer (11000000)
	sta ACR

	lda #$00		; start the timer
	sta T1CL
	sta T1CH

	lda #<NOTELSB
	sta NOTEL
	lda #>NOTELSB
	sta NOTEL + 1 	
	lda #<NOTEMSB
	sta NOTEH
	lda #>NOTEMSB
	sta NOTEH + 1
	
	ldy #$00
play:
	sty TEMPY
	lda SONG_NOTES,y
	beq end         ; Song is null terminated.

	ldx SONG_TIMES,y
	tay
	lda (NOTEL),y
	sta T1CL
	lda (NOTEH),y
	sta T1CH
        jmp again
again:
	lda #$4e	; wait for 0.05 seconds
	sta T2CL
	lda #$c3
	sta T2CH
	lda #$20
wait:
	bit IFR
	beq wait
	dex
	bne again	; keep waiting until duration is up.

	ldy TEMPY
	iny
	jmp play

end:
	lda #$00
	sta ACR     ; turn off timer.

forever:
	jmp forever

; ------------- Routines

init_via_ports:
    lda #%11111111                          ; Set all pins on port B to output
    sta DDRB
    
    lda #%11100001                          ; Set top 3 pins and bottom ones to on port A to output, 4 middle ones to input
    sta DDRA
    rts

;
; clear_lcd
;
clear_lcd:
    pha
    lda #%00000001                          ; Clear Display
    jsr send_lcd_instruction
    pla
    rts

;
; init_lcd - initialize the display
;
init_lcd:
    lda #%00111000                          ; Set 8-bit mode; 2-line display; 5x8 font
    jsr send_lcd_instruction
    
    lda #%00001110                          ; Display on; cursor on; blink off
    jsr send_lcd_instruction
    
    lda #%00000110                          ; Increment and shift cursor; don't shift display
    jsr send_lcd_instruction

    rts

;
; write_to_screen - writes a message to the LCD screen
;
write_to_screen:
STRING = $fe                                ; string pointer needs to be in zero page for indirect indexed addressing
    sta STRING
    sty STRING+1
    ldy #0
.write_chars:
    lda (STRING),Y
    beq .return
    jsr send_lcd_data
    iny
    jmp .write_chars
.return:
    rts

;
; check_busy_flag - 
;
check_busy_flag:
    lda #0                                  ; clear port A
    sta PORTA                               ; clear RS/RW/E bits

    lda #RW                                 ; prepare read mode
    sta PORTA

    bit PORTB                               ; read data from LCD
    bpl .ready                              ; bit 7 not set -> ready
    lda #1                                  ; bit 7 set, LCD is still busy, need waiting
    rts
.ready:
    lda #0
    rts

;
; send_lcd_instruction - sends instruction commands to the LCD screen
;
send_lcd_instruction:
    pha                                    ; preserve A
.loop                                      ; wait until LCD becomes ready
    jsr check_busy_flag
    bne .loop
    pla                                    ; restore A

    sta PORTB                               ; Write accumulator content into PORTB
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits
    lda #E
    sta PORTA                               ; Set E bit to send instruction
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits
    rts

;
; send_lcd_data - sends data to be written to the LCD screen
;
send_lcd_data:
    sta PORTB                               ; Write accumulator content into PORTB
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits
    lda #(RS | E)
    sta PORTA                               ; SET E bit AND register select bit to send instruction
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits
    rts

;
; sleep - subroutine - sleeps for number of cycles read from accumulator
;
sleep:
    tay
loops:
    dey
    bne loops
    rts


; Text
message: 
	.asciiz "Happy Birthday!     BE6502"

; ------------- Lookup tables

; Happy Birthday to you
SONG_NOTES:
	db $30, $30, $32, $30, $35, $34, $6C
	db $30, $30, $32, $30, $37, $35, $6C
	db $30, $30, $3C, $39, $35, $34, $32
	db $6c, $3A, $3A, $39, $35, $37, $35
	db $00

SONG_TIMES:
	db $04, $04, $08, $04, $08, $08, $0c
	db $04, $04, $08, $04, $08, $08, $0c
	db $04, $04, $0c, $0c, $0c, $0c, $0f
	db $0f, $04, $04, $08, $08, $08, $0f
     
NOTELSB:
	db $75	; 0		C0
	db $C4	; 1		C#0/Db0
	db $6F	; 2		D0
	db $6A	; 3		D#0/Eb0
	db $CF	; 4		E0
	db $78	; 5		F0
	db $7A	; 6		F#0/Gb0
	db $B8	; 7		G0
	db $3C	; 8		G#0/Ab0
	db $05	; 9		A0
	db $06	; A		A#0/Bb0
	db $44	; B		B0
	db $BA	; C		C1
	db $5E	; D		C#1/Db1
	db $34	; E		D1
	db $38	; F		D#1/Eb1
	db $67	; 10	E1
	db $BE	; 11	F1
	db $3A	; 12	F#1/Gb1
	db $DC	; 13	G1
	db $A0	; 14	G#1/Ab1
	db $82	; 15	A1
	db $84	; 16	A#1/Bb1
	db $A2	; 17	B1
	db $DC	; 18	C2
	db $2F	; 19	C#2/Db2
	db $9A	; 1A	D2
	db $1C	; 1B	D#2/Eb2
	db $B3	; 1C	E2
	db $5E	; 1D	F2
	db $1D	; 1E	F#2/Gb2
	db $EE	; 1F	G2
	db $CF	; 20	G#2/Ab2
	db $C1	; 21	A2
	db $C2	; 22	A#2/Bb2
	db $D1	; 23	B2
	db $EE	; 24	C3
	db $17	; 25	C#3/Db3
	db $4D	; 26	D3
	db $8E	; 27	D#3/Eb3
	db $D9	; 28	E3
	db $2F	; 29	F3
	db $8E	; 2A	F#3/Gb3
	db $F7	; 2B	G3
	db $67	; 2C	G#3/Ab3
	db $E0	; 2D	A3
	db $61	; 2E	A#3/Bb3
	db $E8	; 2F	B3
	db $77	; 30	C4
	db $0B	; 31	C#4/Db4
	db $A6	; 32	D4
	db $47	; 33	D#4/Eb4
	db $EC	; 34	E4
	db $97	; 35	F4
	db $47	; 36	F#4/Gb4
	db $FB	; 37	G4
	db $B3	; 38	G#4/Ab4
	db $70	; 39	A4
	db $30	; 3A	A#4/Bb4
	db $F4	; 3B	B4
	db $BB	; 3C	C5
	db $85	; 3D	C#5/Db5
	db $53	; 3E	D5
	db $23	; 3F	D#5/Eb5
	db $F6	; 40	E5
	db $CB	; 41	F5
	db $A3	; 42	F#5/Gb5
	db $7D	; 43	G5
	db $59	; 44	G#5/Ab5
	db $38	; 45	A5
	db $18	; 46	A#5/Bb5
	db $FA	; 47	B5
	db $DD	; 48	C6
	db $C2	; 49	C#6/Db6
	db $A9	; 4A	D6
	db $91	; 4B	D#6/Eb6
	db $7B	; 4C	E6
	db $65	; 4D	F6
	db $51	; 4E	F#6/Gb6
	db $3E	; 4F	G6
	db $2C	; 50	G#6/Ab6
	db $1C	; 51	A6
	db $0C	; 52	A#6/Bb6
	db $FD	; 53	B6
	db $EE	; 54	C7
	db $E1	; 55	C#7/Db7
	db $D4	; 56	D7
	db $C8	; 57	D#7/Eb7
	db $BD	; 58	E7
	db $B2	; 59	F7
	db $A8	; 5A	F#7/Gb7
	db $9F	; 5B	G7
	db $96	; 5C	G#7/Ab7
	db $8E	; 5D	A7
	db $86	; 5E	A#7/Bb7
	db $7E	; 5F	B7
	db $77	; 60	C8
	db $70	; 61	C#8/Db8
	db $6A	; 62	D8
	db $64	; 63	D#8/Eb8
	db $5E	; 64	E8
	db $59	; 65	F8
	db $54	; 66	F#8/Gb8
	db $4F	; 67	G8
	db $4B	; 68	G#8/Ab8
	db $47	; 69	A8
	db $43	; 6A	A#8/Bb8
	db $3F	; 6B	B8
	db $00  ; 6C   	NO NOTE

NOTEMSB:
	db $77	; 0		C0
	db $70	; 1		C#0/Db0
	db $6A	; 2		D0
	db $64	; 3		D#0/Eb0
	db $5E	; 4		E0
	db $59	; 5		F0
	db $54	; 6		F#0/Gb0
	db $4F	; 7		G0
	db $4B	; 8		G#0/Ab0
	db $47	; 9		A0
	db $43	; A		A#0/Bb0
	db $3F	; B		B0
	db $3B	; C		C1
	db $38	; D		C#1/Db1
	db $35	; E		D1
	db $32	; F		D#1/Eb1
	db $2F	; 10	E1
	db $2C	; 11	F1
	db $2A	; 12	F#1/Gb1
	db $27	; 13	G1
	db $25	; 14	G#1/Ab1
	db $23	; 15	A1
	db $21	; 16	A#1/Bb1
	db $1F	; 17	B1
	db $1D	; 18	C2
	db $1C	; 19	C#2/Db2
	db $1A	; 1A	D2
	db $19	; 1B	D#2/Eb2
	db $17	; 1C	E2
	db $16	; 1D	F2
	db $15	; 1E	F#2/Gb2
	db $13	; 1F	G2
	db $12	; 20	G#2/Ab2
	db $11	; 21	A2
	db $10	; 22	A#2/Bb2
	db $0F	; 23	B2
	db $0E	; 24	C3
	db $0E	; 25	C#3/Db3
	db $0D	; 26	D3
	db $0C	; 27	D#3/Eb3
	db $0B	; 28	E3
	db $0B	; 29	F3
	db $0A	; 2A	F#3/Gb3
	db $09	; 2B	G3
	db $09	; 2C	G#3/Ab3
	db $08	; 2D	A3
	db $08	; 2E	A#3/Bb3
	db $07	; 2F	B3
	db $07	; 30	C4
	db $07	; 31	C#4/Db4
	db $06	; 32	D4
	db $06	; 33	D#4/Eb4
	db $05	; 34	E4
	db $05	; 35	F4
	db $05	; 36	F#4/Gb4
	db $04	; 37	G4
	db $04	; 38	G#4/Ab4
	db $04	; 39	A4
	db $04	; 3A	A#4/Bb4
	db $03	; 3B	B4
	db $03	; 3C	C5
	db $03	; 3D	C#5/Db5
	db $03	; 3E	D5
	db $03	; 3F	D#5/Eb5
	db $02	; 40	E5
	db $02	; 41	F5
	db $02	; 42	F#5/Gb5
	db $02	; 43	G5
	db $02	; 44	G#5/Ab5
	db $02	; 45	A5
	db $02	; 46	A#5/Bb5
	db $01	; 47	B5
	db $01	; 48	C6
	db $01	; 49	C#6/Db6
	db $01	; 4A	D6
	db $01	; 4B	D#6/Eb6
	db $01	; 4C	E6
	db $01	; 4D	F6
	db $01	; 4E	F#6/Gb6
	db $01	; 4F	G6
	db $01	; 50	G#6/Ab6
	db $01	; 51	A6
	db $01	; 52	A#6/Bb6
	db $00	; 53	B6
	db $00	; 54	C7
	db $00	; 55	C#7/Db7
	db $00	; 56	D7
	db $00	; 57	D#7/Eb7
	db $00	; 58	E7
	db $00	; 59	F7
	db $00	; 5A	F#7/Gb7
	db $00	; 5B	G7
	db $00	; 5C	G#7/Ab7
	db $00	; 5D	A7
	db $00	; 5E	A#7/Bb7
	db $00	; 5F	B7
	db $00	; 60	C8
	db $00	; 61	C#8/Db8
	db $00	; 62	D8
	db $00	; 63	D#8/Eb8
	db $00	; 64	E8
	db $00	; 65	F8
	db $00	; 66	F#8/Gb8
	db $00	; 67	G8
	db $00	; 68	G#8/Ab8
	db $00	; 69	A8
	db $00	; 6A	A#8/Bb8
	db $00	; 6B	B8
	db $00  ; 6C    NO NOTE

vectors:
	.org $fffc
	word reset
	word 0
