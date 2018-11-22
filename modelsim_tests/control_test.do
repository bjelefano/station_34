vlib work

vlog -timescale 1ns/1ns game.v

vsim control

log {/*} 

add wave {/*}

# -------------------------------------- Tests ----------------------------------------
force {start} 0
force {display_done} 0
force {no_lives} 0
force {check} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 0
run 4ns

force {start} 1 0, 0 4 -repeat 48
force {display_done} 0 0, 1 40
force {no_lives} 0 0 , 1 200
force {check} 1 0, 0 80
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 400ns