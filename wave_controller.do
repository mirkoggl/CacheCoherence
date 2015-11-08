onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/clk
add wave -noupdate /tb/reset
add wave -noupdate /tb/enable
add wave -noupdate -divider Controller
add wave -noupdate /tb/cc_uut/CoreValidIn
add wave -noupdate /tb/cc_uut/CoreMexIn
add wave -noupdate /tb/cc_uut/CoreDataIn
add wave -noupdate /tb/cc_uut/CoreValidOut
add wave -noupdate /tb/cc_uut/CoreMexOut
add wave -noupdate -radix hexadecimal /tb/cc_uut/CoreDataOut
add wave -noupdate /tb/cc_uut/RouterValidIn
add wave -noupdate /tb/cc_uut/RouterDataIn
add wave -noupdate /tb/cc_uut/RouterValidOut
add wave -noupdate /tb/cc_uut/RouterDataOut
add wave -noupdate /tb/cc_uut/CacheDataIn
add wave -noupdate /tb/cc_uut/CacheReadAddr
add wave -noupdate /tb/cc_uut/CacheWriteEn
add wave -noupdate /tb/cc_uut/CacheWriteAddr
add wave -noupdate /tb/cc_uut/CacheDataOut
add wave -noupdate /tb/cc_uut/directory
add wave -noupdate /tb/cc_uut/current_s
add wave -noupdate -divider Memory
add wave -noupdate /tb/mem_uut/raddr
add wave -noupdate /tb/mem_uut/waddr
add wave -noupdate /tb/mem_uut/data
add wave -noupdate /tb/mem_uut/we
add wave -noupdate -radix hexadecimal /tb/mem_uut/q
add wave -noupdate /tb/mem_uut/ram
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 209
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1050 ns}
