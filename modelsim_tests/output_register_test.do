vlib work

vlog -timescale 1ns/1ns game.v

vsim OutputRegister

log {/*} 

add wave -r {/*}

# -------------------------------------- Tests ----------------------------------------

# Change the in value on RateRegister beforehand

force {in} 00001011011101111010110111011110101101110111101011011101111010110111
force {start} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 0
run 4ns

force {in} 00001011011101111010110111011110101101110111101011011101111010110111
force {start} 1 0, 0 4
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 4000ns