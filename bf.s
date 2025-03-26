.global brainfuck

# loop cases
# we only check 0 when we first parse [, and every time when we parse ]
# + increses the value of curent cell by 1
# - descreses the value of curent cell by 1
# > moves program to next cell
# < moves program to previous cell
# . prints out the value of current cell as a character
# , takes in character from user and stores it's asci code into current cell
# [] - while loop, continua pana celula curenta este 0
# 255 + 1 = 0
# 0 - 1 = 255
# every cell is 1 byte

.data
	ARRAY: .skip 30000

.text
	chara: .asciz "%c"
	input: .asciz "%c"
brainfuck:
	pushq %rbp
	movq %rsp, %rbp

	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq $-1 # fill the stack, so it's not empty if we have to check paranthesis
	pushq $-1
	pushq $-1
	pushq $-1

	# the brainfuck code string is coming from rdi
	movq %rdi, %r15 # save it to r15

	movq $0, %r12 # r12 = current character index in brainfuck code
	movq $0, %r13 # r13 = current cell index on the brainfuck tape

brainfuck_parse_char: 

	# we process the char at index r12
	movzbq (%r15, %r12), %r8

	cmpq $62, %r8 # >
	je greater_than_case

	cmpq $60, %r8 # <
	je less_than_case

	cmpq $43, %r8 # 
	je plus_case

	cmpq $45, %r8 # -
	je minus_case 

	cmpq $91, %r8 # [
	je loop_start_case

	cmpq $93, %r8 # ]
	je loop_end_case

	cmpq $46, %r8 # .
	je dot_case

	cmpq $44, %r8 # ,
	je comma_case

	cmpq $0, %r8 # null
	je brainfuck_epilogue

	#any other character, we parse the next one (may be whitespace, or random comments)
	incq %r12
	jmp brainfuck_parse_char

plus_case:
	# current cell ++. if 255, wrap to 0
	mov $ARRAY, %r9

	cmpb $255, (%r9, %r13)
	je plus_case_wrap
	addb $1, (%r9, %r13)
	jmp plus_case_end
plus_case_wrap:
	movb $0, (%r9, %r13)
plus_case_end:
	# parse the next char
	incq %r12
	jmp brainfuck_parse_char

minus_case:
	# current cell --. if 0, wrap to 255
	movq $ARRAY, %r9

	cmpq $0, (%r9, %r13)
	je	minus_case_wrap
	decb (%r9, %r13)
	jmp minus_case_end
minus_case_wrap:
	movb $255, (%r9, %r13)
minus_case_end:
	# parse the next char
	incq %r12
	jmp brainfuck_parse_char

less_than_case: # <, ascii code 60
	# current cell index --
	movq $0, %r10 # counter for how many characters we have
less_than_case_loop:
	# cmpq (%r15, %r12, 1), (%r15, %r12+1, 1) 
	incq %r10
	incq %r12
	cmpq $60, (%r15, %r12) 
	je less_than_case_loop
less_than_case_loop_ended:

	subq %r10, %r13

	# parse the next char
	# incq %r12; r12 was already increased in the loop
	jmp brainfuck_parse_char
greater_than_case: # >
	# current cell index is incremented by 1
	incq %r13

	# parse the next char
	incq %r12
	jmp brainfuck_parse_char

dot_case:
	movq $ARRAY, %r9

	# we print the character

	movq $0, %rax
	movq $chara, %rdi
	movq (%r9, %r13, 1), %rsi
	call printf

	// movq $1, %rax
	// movq $1, %rdi
	// leaq (%r9, %r13, 1), %rsi
	// movq $1, %rdx	
	// syscall

	# parse the next char
	incq %r12
	jmp brainfuck_parse_char

comma_case:
	# we take in user input and store it at the current cell
	# we do a syscall read
	movq $ARRAY, %r9
	movq $0, %rax
    movq $input, %rdi
	leaq (%r9, %r13), %rsi # we move the current cell address to rsi
    call scanf # input gets read directly into cell

	# parse the next char
	incq %r12
	jmp brainfuck_parse_char

# loop cases
# we only check 0 when we first parse [, and every time when we parse ]

loop_start_case: # [
	movq $ARRAY, %r9

	cmpq $45, 1(%r15, %r12)
	jne loop_start_normal_case

	cmpq $93, 2(%r15, %r12)
	jne loop_start_normal_case

	mov $0, (%r9, %r13)
	addq $3, %r12

	jmp brainfuck_parse_char

loop_start_normal_case:
	# check if the current cell is 0
	cmpb $0, (%r9, %r13, 1)
	je loop_start_case_zero_outofthegate
	jmp loop_start_case_main

loop_start_case_zero_outofthegate:
	# the loop doesn't execute, because the curent cell is 0 when entering it
	# for every [ : r14 ++, for every ]: r14 --
	# we skipp al paranthesis until we reach a ] and the counter (r14) is 0
	movq $1, %r14 
	movq %r12, %r9 
	incq %r9
loop_start_case_zero_outofthegate_loop:
	cmpb $91, (%r15, %r9, 1) # code for [
	je open_case
	cmpb $93, (%r15, %r9, 1) # code for ]
	je closed_case
	jmp normal_char_case
open_case:
	incq %r14
	jmp after_case_check
closed_case:
	decq %r14
	jmp after_case_check
after_case_check:
	# now we updated r14, we check if it is 0
	cmpq $0, %r14
	je found_the_right_closing # we found the end of the loop
normal_char_case: # default case
	incq %r9
	jmp loop_start_case_zero_outofthegate_loop

found_the_right_closing:
	# the loop doesn't execute, so we process the char after ]
	movq %r9, %r12
	incq %r12
	jmp brainfuck_parse_char

loop_start_case_main:
	# we add the par to the stack. the loop actually executes
	pushq $0 # we push 0 before every [ , and 1 before every ]
	pushq %r12

	incq %r12
	jmp brainfuck_parse_char

loop_end_case:
	# check if ] is on the stack
	cmpq $1, 8(%rsp)
	jne loop_end_case_add_to_stack
	jmp loop_end_case_main
	
loop_end_case_add_to_stack: # if ] wasn't already on stack, we add it
	pushq $1
	pushq %r12

loop_end_case_main:
	# we check if the current cell is 0, so we finish the loop
	movq $ARRAY, %r9
	cmpb $0, (%r9, %r13, 1)
	je loop_end_case_main_zero
	jmp loop_end_case_main_not_zero

loop_end_case_main_zero:
	# remove both par from the stack
	popq %rax
	popq %rax
	popq %rax
	popq %rax
	movq $0, %rax

	#parse next char
	incq %r12
	jmp brainfuck_parse_char
loop_end_case_main_not_zero:
	# put the position of the [ into r12
	movq 16(%rsp), %r12
	incq %r12

	# parse the char after the [
	jmp brainfuck_parse_char

brainfuck_epilogue:
	popq %rax
	popq %rax
	popq %rax
	popq %rax

	pop %r15
	pop %r14
	pop %r13
	pop %r12

	movq $0, %rax # idk

	movq %rbp, %rsp
	popq %rbp
	ret
	
