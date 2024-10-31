read_file -type verilog $env(HDL_SRCS)
read_file -type awl lint.awl

set_option top usb_cdc
set_option language_mode verilog
set_option designread_enable_synthesis no
set_option designread_disable_flatten no
set_option enableSV09 yes

set_option enable_save_restore no

current_goal Design_Read -top usb_cdc

current_goal lint/lint_turbo_rtl -top usb_cdc
run_goal

# help -rules STARC05-2.11.3.1
