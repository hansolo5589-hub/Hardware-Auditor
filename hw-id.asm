; *************************************************************************
; *                        Hardware Device Auditor                        *
; *                       By Mohd Firoz (hansolo5589)                     *
; *************************************************************************
; Component: Assembly Backend for PCI/CPU I/O operations
; Linked to: maincpuid.c
; Purpose: Raw hardware register access via I/O ports
; Execution of the program are run using the ./analyze.pl (sudo)


section .data
    vendor_id db "------------", 0
    brand_id  db "------------------------------------------------", 0

section .text
    global get_cpu_vendor
    global get_cpu_brand
    global pci_read

get_cpu_vendor:
    mov eax, 0
    cpuid
    mov [vendor_id], ebx
    mov [vendor_id+4], edx
    mov [vendor_id+8], ecx
    mov rax, vendor_id
    ret

get_cpu_brand:
    mov rdi, brand_id
    mov eax, 0x80000002
    call .fetch_chunk
    mov eax, 0x80000003
    call .fetch_chunk
    mov eax, 0x80000004
    call .fetch_chunk
    mov rax, brand_id
    ret

.fetch_chunk:
    cpuid
    mov [rdi], eax
    mov [rdi+4], ebx
    mov [rdi+8], ecx
    mov [rdi+12], edx
    add rdi, 16
    ret
; pci_read(uint32_t address) -> uint32_t data
pci_read:
    mov eax, edi        ; RDI is the first arg, move into EAX
    mov dx, 0xCF8       ; PCI Address Port
    out dx, eax         ; Send the address to the port
    
    mov dx, 0xCFC       ; PCI Data Port
    in eax, dx          ; Read the data back into EAX
    ret                 ; RAX now holds the 32-bit register value
