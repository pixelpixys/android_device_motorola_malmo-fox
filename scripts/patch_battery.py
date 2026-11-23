import struct

with open('/tmp/recovery_orig', 'rb') as f:
    data = bytearray(f.read())

def make_bl(pc, target):
    diff = (target - pc) >> 2
    return 0x94000000 | (diff & 0x03ffffff)

# Construct hook instructions with clean stack frame of 80 bytes
# buffer is at [sp, 48]
instructions = [
    # 0x18df48:
    0xa9ba7bfd, # stp x29, x30, [sp, -96]!
    0x910003fd, # mov x29, sp
    0xa90153f3, # stp x19, x20, [sp, 16]
    0xa9025bf5, # stp x21, x22, [sp, 32]
    0x52800c93, # mov w19, #100
    0x52800014, # mov w20, #0
    
    # 0x18df60: adr x0, path_capacity (at 0x18e010)
    0x10000580,
    0x52800001, # mov w1, #0 (O_RDONLY)
    make_bl(0x18df68, 0x2e9280), # bl open@plt
    0x7100001f, # cmp w0, #0
    0x540001cb, # b.lt check_status (at 0x18dfa8)
    0x2a0003f5, # mov w21, w0 (fd)
    
    # 0x18df78: read capacity into [sp, 48]
    0x9100c3e1, # add x1, sp, #48
    0x528001e2, # mov w2, #15
    make_bl(0x18df80, 0x2e92a0), # bl read@plt
    0x7100001f, # cmp w0, #0
    0x540000cd, # b.le close_cap (at 0x18dfa0)
    0x9100c3e1, # add x1, sp, #48
    0x3820683f, # strb wzr, [x1, x0] (null-terminate)
    0xaa0103e0, # mov x0, x1
    make_bl(0x18df98, 0x2e9090), # bl atoi@plt
    0x2a0003f3, # mov w19, w0 (cap)

    # 0x18dfa0: close_cap
    0x2a1503e0, # mov w0, w21
    make_bl(0x18dfa4, 0x2e9290), # bl close@plt

    # 0x18dfa8: check_status
    # adr x0, path_status (at 0x18e040)
    0x100004c0,
    0x52800001, # mov w1, #0
    make_bl(0x18dfb0, 0x2e9280), # bl open@plt
    0x7100001f, # cmp w0, #0
    0x5400020b, # b.lt finish (at 0x18dff8)
    0x2a0003f5, # mov w21, w0

    # 0x18dfc0: read status into [sp, 48]
    0x9100c3e1, # add x1, sp, #48
    0x52800022, # mov w2, #1
    make_bl(0x18dfc8, 0x2e92a0), # bl read@plt
    0x7100041f, # cmp w0, #1
    0x5400010b, # b.lt close_status (at 0x18dff0)
    0x9100c3e1, # add x1, sp, #48
    0x39400020, # ldrb w0, [x1]
    0x71010c1f, # cmp w0, #'C'
    0x54000060, # b.eq set_charging
    0x71018c1f, # cmp w0, #'c'
    0x54000041, # b.ne close_status
    0x52800034, # set_charging: mov w20, #1 (0x18dfec)

    # 0x18dff0: close_status
    0x2a1503e0, # mov w0, w21
    make_bl(0x18dff4, 0x2e9290), # bl close@plt

    # 0x18dff8: finish
    0xaa138280, # orr x0, x20, x19, lsl #32
    0xa9425bf5, # ldp x21, x22, [sp, 32]
    0xa94153f3, # ldp x19, x20, [sp, 16]
    0xa8c67bfd, # ldp x29, x30, [sp], #96
    0xd65f03c0, # ret
    0xd503201f, # nop
]

code_bytes = struct.pack(f'<{len(instructions)}I', *instructions)

path_cap = b"/sys/class/power_supply/battery/capacity\0"
path_stat = b"/sys/class/power_supply/battery/status\0"

start_addr = 0x18df48
data[start_addr:start_addr + len(code_bytes)] = code_bytes

cap_addr = 0x18e010
data[cap_addr:cap_addr + len(path_cap)] = path_cap

stat_addr = 0x18e040
data[stat_addr:stat_addr + len(path_stat)] = path_stat

with open('/tmp/b19_rd/system/bin/recovery', 'wb') as f:
    f.write(data)

print('Patch applied successfully!')
