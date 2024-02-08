#ifndef BAUD
#define BAUD 9600
#endif
#ifndef F_CPU
#define F_CPU 16000000UL
#endif 

#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <util/setbaud.h>

//
// Pin Map
// Data lines are PD
// Address and Z80-side signals are PB
//		ADDR on Bits 0,1,2
//		WR on 3
//		CS on 4
//		IRQ on 5
// Panel-side signals are PC


#define EXPAND(A,B) A ## B
#define JOIN(A,B) (EXPAND(A,B))



#define CS_REG PINB
#define CS_IDX 4
#define CS_BIT (1 << CS_IDX)
#define CS_INTR PCINT4

void flashOnce() {
  PORTB |= 0x20;
  _delay_ms(1000);                      // wait for a second
  PORTB &= ~0x20;
  _delay_ms(1000);                      // wait for a second
}


static volatile uint8_t reg; // Last register read.
static volatile uint8_t next_val; // Next register value to return.

static volatile uint8_t status; 
static volatile uint8_t registers[23];

ISR(PCINT0_vect) {
	volatile uint8_t in;
	// Triggered by PCINT4 which is the only enabled one.
	if (PINB & CS_BIT) { 
		// CS is high.  Nothing to see, not for us.
		return;
	} 
  PORTB ^= 0x20;

	uint8_t addr;
	// CS is low, we have data to work with.
	addr = PORTB & 0xF;  // Read/write in bit 3.  Low is Write
	switch (addr) {
	// Write cases
		case 0:
			status = PIND; return;
		case 1: 
			reg = PIND; return;
		case 2:
			in = PIND;
			registers[reg] = in;
			return;

	// READ CASES.  
		case 8: 
			DDRD = 0xFF;
			PORTD = status; 
			// Delay 3 6mHz clock, so 2mhz clock
			_delay_loop_1(3); // 3 16mhz clocks per iteration, so 9 is close to 2mhz.
			DDRD = 0; // And back to being input lines.
			PORTD = 0xFF;
			return;
		case 9: 
			DDRD = 0xFF;
			PORTD = reg;
			next_val = registers[reg]; // This lookup provides some delay
			_delay_loop_1(2); 
			DDRD = 0;
			PORTD = 0xFF;
			return;
		case 10:
			DDRD = 0xFF;
			PORTD = next_val;
			_delay_loop_1(3); // 3 16mhz clocks per iteration, so 9 is close to 2mhz.
			DDRD = 0;
			PORTD = 0xFF;
			return;
		}
}

void uart_putchar(char c) {
    // Wait until the register to write to is free.
    loop_until_bit_is_set(UCSR0A, UDRE0);

    // Write the byte to the register.
    UDR0 = c;
}

void uart_putstr(char *data) {
    // Loop until end of string writing char by char.
    while(*data){
      uart_putchar(*data++);
    }
}

char HEX[]="0123456789ABCDEF";

// the loop function runs over and over again forever
void loop() {
        uart_putstr("hello\n\r");
	for(int i=0;i<sizeof(registers);i++) {
		uart_putchar(HEX[(registers[i] & 0xF0)>>4] );
		uart_putchar(HEX[(registers[i] & 0xF)] );
		uart_putchar(' ');
	}
	uart_putchar('\n');
	uart_putchar('\r');

        _delay_ms(1000);
	
}

void setup() {
  DDRB = 0x00;  // All inputs from Z80

  PORTB |= 0x1F; // Set the pull-up on all the lines Z80 will drive

	DDRD = 0x00;
	PORTD = 0xFF; // All data lines are inputs, pinned high for Z80 to drive.

	PCMSK0 |= 1 << PCINT4;
	
	PCICR |=  1<<PCIE0;

	sei();
}



void uart_init() {
    // Upper and lower bytes of the calculated prescaler value for baud.
    UBRR0H = UBRRH_VALUE;
    UBRR0L = UBRRL_VALUE;

    // Configure data frame size to 8-bits.
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);

    // Configure to enable transmitter.
    UCSR0B = _BV(TXEN0);
}

int main() {
	setup();
	uart_init();
	flashOnce();
	flashOnce();
	for(;;) loop();
}