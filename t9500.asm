; T9500.asm - psr-70 repair project

.nolist
.include "./m328Pdef.inc"
.list 

#define DEBUG 0


#define handlertab 0x400
#define tabsize 16
;;;;;;;;;;;;
; We allocate some registers *just* for the interrupt handler.  
; r0-r16 are reserved for userland
; r17-r25 are reserved for interrupts
.def longdelayreg = r10
.def delayreg = r12
.def delayreg2 = r13
.def temp = r15
.def tempH = r16 ;; So we have at least one high register temp value.


;; Interrupt land
.def status = r17	
.def regreq = r18 ; Last write/read to 0 
.def value = r19 ; Value read or to write

.def jumptab = r20 ; To load into Z 
.def jumptab2 = r21 ; just to mark it in-use
.def jtabmult = r22; // Hold the size of the jtab entry. 16 bytes each.
.def tabsize_r = r23 ; Hold the value 16 for our interrupt handler
.def itemp = r24
.def itemp2 = r25

;;
;; r26 onwards are X, Y, Z registers


.MACRO PRINT_BSS 
	push xh
	push xl
	ldi XH, HIGH((@0-BSS)*2+BSSFILL)
	ldi XL, LOW((@0-BSS)*2+BSSFILL)
	call USART_print_bss
	pop xh
	pop xl
.ENDM

.DSEG ; Keep in sync with BSS at the bottom.  Ugly.
BSSFILL:
status_shadow: 
.byte 2
REG:
.byte 24
HelloWorld:
.byte 16
StatusChanged:
.byte 0x500


.CSEG
.org 0x0000
rjmp Init

.org 0x0006 
rjmp PCINT0_handler


;
Init:
	eor		r0, r0		; zero to use
	eor		temp, temp	; Clear tmp
	out		DDRD,temp	; Input data bits
	ser		tempH
	out		PORTD, tempH ; PORTD pullups

	ldi 	tempH, 0b00100000 
	out		DDRB,tempH	; All inputs from Z80 except for blinker
	ldi 	tempH, 0b00011111
	out		PORTB,tempH	; Set the pull-up on all the lines Z80 will drive

	SBI		DDRB, 5 ;; Enable writes to the blinking light
	call 	USART_Init



	; Initialize bss data
	ldi		itemp2, 2 * (BSSEND - BSS)
	ldi 	ZH, HIGH(2*BSS)
	ldi 	ZL, LOW(2*BSS)
	ldi 	YH, HIGH(BSSFILL)
	ldi 	YL, LOW(BSSFILL)
bssloop:
	lpm		r1, Z+
	ST		Y+, r1
	dec 	itemp2
	brne	bssloop
	ldi		tabsize_r, tabsize
	ldi 	XH, HIGH(handlertab)
	ldi 	XL, LOW(handlertab)

#if 1
	lds		temp, PCMSK0
	ldi		tempH, 1 << PCINT4
	or		temp, tempH
	sts		PCMSK0, temp

	lds		temp, PCICR
	ldi		tempH, 1 << PCIE0
	or		temp, tempH
	sts		PCICR, temp

	ldi		itemp2, 0b00100000

	sei
#endif

	LDI ZH, HIGH(TABOFFSET)

	PRINT_BSS hello
Main:
	sei
	push itemp
	ldi itemp, 1
	mov longdelayreg, itemp
	pop itemp
	cli
	call LongDelay
.if 0
	lds r1, status_shadow ; (Status_Shadow - BSS)*2+ BSSFILL
	call USART_HexOut_r1
	mov r1, status
	call USART_HexOut_r1
	call Newline
.endif
	lds r1, status_shadow ; (Status_Shadow - BSS)*2+ BSSFILL
	cp r1, status
	breq Main
	call USART_HexOut_r1
	call Newline

	PRINT_BSS Status
	lds r1, status_shadow
	call USART_HexOut_r1
	mov r1, status
	call USART_HexOut_r1
	call Newline

	sts status_shadow, status
	;call DumpRegisters

	jmp Main ; let the interrupt handler do all the work.
	;jmp Blink ; A test we have a working system.

DumpRegisters:
	ldi tempH, 23
	mov r2, tempH
	ldi 	XH, HIGH((Registers-BSS)*2+BSSFILL)
	ldi 	XL, LOW((Registers-BSS)*2+BSSFILL)
	call DumpMemory
	ret

;; Memory at X for r2 (destructive) iterations; destroys r1

; IN: X, r2
; Destroyed: temp, temph, itemp, r1, X, r2
DumpMemory:
	LD r1, X+
	call USART_HexOut_r1
	LDI tempH, ' '
	call USART_Transmit_tempH
	dec r2
	brne DumpMemory
Newline:
; IN: none
; Destroyed: tempH
	ldi tempH, 0xA
	call USART_Transmit_tempH
	LDI tempH, 0xD
	call USART_Transmit_tempH
	ret

; IN: delayreg, delayreg2
; Destroyed: delayreg, delayreg2
Delay:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	dec 	delayreg
	brne 	Delay
	dec		delayreg2
	brne	Delay
	ret
	
; IN: longdelayreg
; Destroyed: delayreg, delayreg2, longdelayreg
LongDelay:
	eor		delayreg, delayreg
	eor		delayreg2, delayreg2
	call 	Delay
	dec 	longdelayreg
	brne 	LongDelay
	ret

; IN: 
; Destroyed: tempH, longdelayreg, delayreg, delayreg2
Blink:
	sbi		PORTB, 5

	ldi		tempH, 10
	mov 	longdelayreg, tempH
	call	LongDelay

	cbi		PORTB, 5

	mov 	longdelayreg, tempH
	call	LongDelay

	rjmp Blink

;;
;; UART OUTPUT
;;
; IN: none
; Destroyed: tempH
USART_Init:
	; Set baud rate UBBRR = 16000000/(16*9600)-1
	ldi tempH, 0 ; UBRRH_VALUE
	sts UBRR0H, tempH
	ldi tempH, 103 ; UBRRL_VALUE
	sts UBRR0L, tempH
	; Enable receiver and transmitter
	ldi tempH, (1<<RXEN0)|(1<<TXEN0)
	sts UCSR0B,tempH
	; Set frame format: 8data, 2stop bit 
	ldi tempH, (1<<USBS0)|(3<<UCSZ00)
	sts UCSR0C,tempH
	ret	

; IN: tempH
; Destroyed:
; Out: None
;
USART_Transmit_tempH:
	push temp
	sei
USART_Transmit_tempH_loop:
	; Wait for empty transmit buffer
	lds temp, UCSR0A
	SBRS temp,UDRE0
	rjmp USART_Transmit_tempH_loop
	; Put data (tempH) into buffer, sends the data 
	sts UDR0,tempH
	cli
	pop temp
	ret

; IN: tempH
; Destroyed: temp, tempH, itemp
; Out: None
;
USART_HexNibbleOut_tempH:
	andi tempH, 0xF
	CPI tempH, 10
	BRLO USART_HexNibbleOut_tempH_Digit
	; Hex digit.  We will add '0' below, so the constant is a bit odd
	ldi itemp, 'A' - '0' - 10
	add tempH, itemp
USART_HexNibbleOut_tempH_Digit:
	ldi itemp, '0'
	add tempH, itemp
	call USART_Transmit_tempH
	ret

; put r1 register to output as hex.
;
; IN: r1
; Destroyed: tempH, itemp
; Out: None
;
USART_HexOut_r1:
;	cli
	push tempH
	mov tempH, r1
	lsr tempH
	lsr tempH
	lsr tempH
	lsr tempH
	call USART_HexNibbleOut_tempH
	mov tempH, r1
	andi tempH, 0xF
	call USART_HexNibbleOut_tempH
	pop tempH
;	sei
	ret

; IN: Z
; Destroyed: XL, XH
; Out: None
USART_print_bss: 
	push tempH
USART_print_bss_loop:
	ld tempH, X+
	cpi tempH, 0 
	breq USART_print_bss_done
	call USART_Transmit_tempH
	jmp USART_print_bss_loop
USART_print_bss_done:
	pop tempH
	ret



PCINT0_handler:
	; Read the lines.  We sort out whether CS was high or low after
	; doing the urgent thing.  CS going high means we don't commit.

	in	itemp, PINB  ;; Ditto for our address lines.
	; cbr itemp, 0b11110000 ;; Don't look at the CS bit; Can save this instruction by going to 16 byte jumps and ignoring the high order bits.

	; Now we jump to our handler
	mul itemp, tabsize_r  ;; Yes, we burn a register to hold the multiplier
		;; Result in r1:r0

	; Done in init. 
	; LDI ZH, HIGH(TABOFFSET)

	mov ZL, r0

	ijmp


.MACRO toggle
mov status, ZL
.ENDMACRO
.cseg

; First set of 8 targets correspond to a write (line 4 is ~W, so a zero bit means write)
.org handlertab + 0 * tabsize
TABOFFSET:
	in	status, PORTD ;  Gets caught in main.
	reti
.org handlertab + 1 * tabsize
	in      regreq, PORTD ; next register to read
	reti
.org handlertab + 2 * tabsize
	in 	value, PORTD
	ldi	XH, HIGH(REG)
	ldi	XL, LOW(REG)
	add XL, regreq
	st	X, value
	reti
.org handlertab + 3 * tabsize
	reti
.org handlertab + 4 * tabsize
	reti
.org handlertab + 5 * tabsize
	reti
.org handlertab + 6 * tabsize
	reti
.org handlertab + 7 * tabsize
	reti

; Second set of 8 targets are reads.  
.org handlertab + 8 * tabsize
	; addr = 0: status register
	SER tempH
	sts DDRD, tempH
	sts PORTD, status	
	NOP
	NOP
	NOP
	sts 		DDRD, r0
	ser		tempH
	out		PORTD, tempH ; PORTD pullups
	reti
.org handlertab + 9 * tabsize
	; addr = 1; I'm telling the Z80 what register is coming.  Comes after we IRQ and setup regreq and value
	SER tempH
	sts DDRD, tempH
	NOP
	NOP
	NOP
	sts 		DDRD, r0
	out		PORTD, tempH ; PORTD pullups
	reti
.org handlertab + 10 * tabsize
	; addr = 1; I'm telling the Z80 what register is coming.  Comes after we IRQ and setup regreq and value
	SER tempH
	sts DDRD, tempH
	NOP
	NOP
	NOP
	sts 		DDRD, r0
	out		PORTD, tempH ; PORTD pullups
	reti
.org handlertab + 11 * tabsize
	reti
.org handlertab + 12 * tabsize
	reti
.org handlertab + 13 * tabsize
	reti
.org handlertab + 14 * tabsize
	reti
.org handlertab + 15 * tabsize
mov status, ZL
	reti

.cseg
BSS:
StatusShadow:
.db 0,0
Registers:
.db 0b00100000, 0b00000000 ; IC1 Splits, IC2 Pitch, transposer
.db 0b00000000, 0b00000000 ; IC3 meory, fingered...; IC4 tempo, fills
.db 0b10001000, 0b00000000 ; IC5 pops, disco, reggae, big band; IC6 march, samba, salsa, rock
.db 0b00000000, 0b00000000 ; IC 7, IC 8
.db 0b00010001, 0b00000000 ; IC9 Orchestra; IC10 pause
.db 0b00000000, 0b00000000 ; ic11, ic12
.db 0b00000000, 0b00000000 ; ic 13, ic14
.db 0b10001000, 0b00000000 ; ic 15 piano
.db 0b00000000, 0b00000000 ; IC17, IC18
.db 0b00000000, 0b00000000 ; IC19, IC20
.db 0b00000000, 0b00000000 ; IC21 bass...; IC22 save
.db 0b00000000, 0b00000000 ; IC23 LOAD, IC NULL
hello:
.db "hello, world!", 0xA, 0xD, 0
Status:
.db "Status changed: ", 0, 0
BSSEND:

.if 2*(BSSEND-BSS) > 255
.error "BSS too large for single byte copy counter"
.endif
