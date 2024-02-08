; T9500.asm - psr-70 repair project

.nolist
.include "./m328Pdef.inc"
.list 

#define handlertab 0x100
#define tabsize 16
;;;;;;;;;;;;
; We allocate some registers *just* for the interrupt handler.  
; r0-r16 are reserved for userland
; r17-r25 are reserved for interrupts
.def longdelayreg = r10
.def longdelayreg2 = r11
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
.def rval16 = r23 ; Hold the value 16 for our interrupt handler
.def itemp = r24
.def itemp2 = r25

;;
;; r26 onwards are X, Y, Z registers



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

	ldi		rval16, 16
	ldi 	ZH, HIGH(handlertab)
	ldi 	ZL, Low(handlertab)

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
	Jmp		Main

Main:
;	mov r1, rval16
;	call USART_HexOut
;	call Delay
	jmp Main ; let the interrupt handler do all the work.
	;jmp DoBlink ; A test we have a working system.

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
	
LongDelay:
	eor		delayreg, delayreg
	eor		delayreg2, delayreg2
	call 	Delay
	dec 	longdelayreg
	brne 	LongDelay
	ret

DoBlink:
	; Set PORTB as an output for this test
; This initialization happens in Init and doesn't need repeating here.
;	ldi tempH,0b00100000
;	out DDRB,tempH
;	out PortB,tempH

Blink:
	sbi		PORTB, 5

	ldi		tempH, 10
	mov 	longdelayreg, tempH
	call	LongDelay

	cbi		PORTB, 5

	mov 	longdelayreg, tempH
	call	LongDelay

	rjmp Blink
	
#if 0
	sbi		PORTB, 5

	eor 	delayreg, delayreg
	eor		delayreg2, delayreg2
	call	Delay
	
	cbi		PORTB, 5
	eor 	delayreg, delayreg
	eor		delayreg2, delayreg2
	call	Delay

;	rjmp Blink
#endif


;;
;; UART OUTPUT
;;

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

USART_Transmit:
	; Wait for empty transmit buffer
	lds temp, UCSR0A
	SBRS temp,UDRE0
	rjmp USART_Transmit
	; Put data (tempH) into buffer, sends the data 
	sts UDR0,tempH
	ret



; put r1 register to output as hex.
USART_HexOut:
	mov tempH, r1
	andi tempH, 0xF
	ldi ZH, HIGH(2*HEX)
	ldi ZL, LOW(2*HEX)
	add ZL, tempH
	adc ZH, r0
	lpm tempH, Z
	call USART_Transmit
	lsr r1
	lsr r1
	lsr r1
	lsr r1
	ldi ZH, HIGH(2*HEX)
	ldi ZL, LOW(2*HEX)
	add ZL, r1
	adc ZH, r0
	lpm tempH, Z
	call USART_Transmit
	ldi ZH, HIGH(handlertab)
	ldi ZL, LOW(handlertab)
	ret

HEX:
.db "0123456789abcdef"

PCINT0_handler:
	;eor		itemp2, itemp2
	;sbr		itemp2, 1 << 5
	;in		itemp, PORTB
	;eor		itemp, itemp2
	;out		PORTB, itemp
ldi tempH, '*'
call USART_Transmit
;	reti

	; Read the lines.  We sort out whether CS was high or low after
	; doing the urgent thing.  CS going high means we don't commit.

	in	itemp2, PORTD ;; If it was a data write, we needed to grab it, stat.
	in	itemp, PORTB  ;; Ditto for our address lines.
	cbr itemp, 1 << 5 ;; Don't look at that bit...
	; Now we jump to our handler
	eor itemp, itemp
	sbr itemp, 2
	mul itemp, rval16  ;; Yes, we burn a register to hold "16"
	mov r1, itemp
	call USART_HexOut
	mov ZL, itemp
	ijmp

.MACRO toggle
in	itemp, PORTB
eor itemp2, itemp2
sbr itemp2, 1 << 5
eor itemp, itemp2
out PORTB, itemp
	reti
.ENDMACRO
.cseg
.org handlertab + 0 * tabsize
	eor itemp, itemp
	call Delay
	toggle
.org handlertab + 1 * tabsize
	toggle
.org handlertab + 2 * tabsize
	toggle
.org handlertab + 3 * tabsize
	toggle
.org handlertab + 4 * tabsize
	toggle
.org handlertab + 5 * tabsize
	toggle
.org handlertab + 6 * tabsize
	toggle
.org handlertab + 7 * tabsize
	toggle
.org handlertab + 8 * tabsize
	toggle
.org handlertab + 9 * tabsize
	toggle
.org handlertab + 10 * tabsize
	toggle
.org handlertab + 11 * tabsize
	toggle
.org handlertab + 12 * tabsize
	toggle
.org handlertab + 13 * tabsize
	toggle
.org handlertab + 14 * tabsize
	toggle
.org handlertab + 15 * tabsize
	toggle

