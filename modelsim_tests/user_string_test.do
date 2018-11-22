vlib work

vlog -timescale 1ns/1ns game.v

vsim 	InputModule

log {/*} 

add wave {/*}

# -------------------------------------- Tests ----------------------------------------

force {toggle} 0
force {push} 0
force {mic} 0
force {mouse} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 0
run 4ns

force {toggle} 1
force {push} 0
force {mic} 0
force {mouse} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 40ns

force {toggle} 0
force {push} 0
force {mic} 0
force {mouse} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 4ns

force {toggle} 1
force {push} 0
force {mic} 0
force {mouse} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 40ns

force {toggle} 0
force {push} 1
force {mic} 0
force {mouse} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 40ns

force {toggle} 0
force {push} 0
force {mic} 1
force {mouse} 0
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 40ns

force {toggle} 0
force {push} 0
force {mic} 0
force {mouse} 1
force {clock} 1 0, 0 1 -repeat 2
force {reset} 1
run 40ns