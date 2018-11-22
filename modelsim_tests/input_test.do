vlib work

vlog -timescale 1ns/1ns game.v

vsim InputListener

log {/*} 

add wave {/*}

# -------------------------------------- Tests ----------------------------------------

force {toggle} 1
force {clock} 1 0, 0 1 -repeat 2
force {reset} 0
run 4ns

force {toggle} 1 0, 0 7 -repeat 15
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1 
run 1000ns