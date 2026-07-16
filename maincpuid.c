#include <stdio.h>
#include <sys/io.h> // Required for iopl()


extern char* get_cpu_vendor();
extern char* get_cpu_brand();
extern unsigned int pci_read(unsigned int address);


int main() {
printf("*************************************************************************\n");
printf("*                     Hardware Device Auditor                           *\n");
printf("*                   By Mohd Firoz (hansolo5589)                         *\n");
printf("*************************************************************************\n");
    printf("CPU_VENDOR:%s\n", get_cpu_vendor());
    printf("CPU_BRAND:%s\n", get_cpu_brand());
    
    // Request permission to access I/O ports (Required on Linux)
    if (iopl(3) < 0) { perror("iopl"); return 1; }

    // Scan Bus 0, Device 0, Function 0 (The Host Bridge)
    // 0x80000000 is the Enable Bit + Bus 0, Dev 0, Func 0
    unsigned int val = pci_read(0x80000000);
    
    printf("Vendor/Device ID at Bus 0, Dev 0: 0x%08X\n", val);
    
    // Instead of a pretty message, output something Perl can grab easily
    // printf("PCI_DEVICE_0_%d_%d:0x%08X\n", dev, func, val);

    printf("--- PCI BUS SCANNER ACTIVE ---\n");

    // Loop through Bus 0, Devices 0-31, Function 0
   for(int bus = 0; bus <  256; bus++){
    for (int dev = 0; dev < 32; dev++) {
       for(int func = 0; func < 8; func++){  
       // Address format: 0x80000000 | (bus << 16) | (dev << 11) | (func << 8)
        unsigned int address = 0x80000000 | (bus << 16) | (dev << 11) | (func << 8);
        unsigned int val = pci_read(address);

        // If the Vendor ID is 0xFFFF, no device exists there
        if ((val & 0xFFFF) != 0xFFFF) {
            printf("PCI_DEVICE_0_%d_%d:0x%08X\n", dev, func, val);
        }
       }
      }
    }
    return 0;
}

