vlib work

vlog -timescale 1ns/1ns game.v

vsim 	StringGenerator

log {/*} 

add wave {/*}

# -------------------------------------- Tests ----------------------------------------

force {inc} 0
force {reset} 0
force {clock} 1 0, 0 1 -repeat 2
run 4ns

force {inc} 1
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 0
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 1
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 1
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 0
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 1
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 0
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 1
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 0
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 1
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns

force {inc} 0
force {reset} 1
force {clock} 1 0, 0 1 -repeat 2
run 10ns