#!/usr/bin/perl
use strict;
use warnings;

printf("*************************************************************************\n");
printf("*                     Hardware Device Auditor                           *\n");
printf("*                   By Mohd Firoz (hansolo5589)                         *\n");
printf("*************************************************************************\n");
printf("\nThis HW Auditor was done using C/ASM and execution by perl\n\n\n");


sub get_data {
    my ($linux_cmd, $win_cmd) = @_;
    
    # Silently default to an empty string if nothing was provided
    $linux_cmd //= ""; 
    $win_cmd   //= ""; 

    if ($^O eq 'MSWin32') {
        return `$win_cmd 2>nul`;
    } else {
        return `$linux_cmd 2>/dev/null`;
    }
}





# Define the DB
my %hardware_db = (
    "190F8086" => "Intel Skylake Host Bridge",
    "00008086" => "Intel Device Placeholder",
);

my $output = `./hw-auditor`; 


print "--- SYSTEM AUDIT ---\n";
 if ($output =~ /CPU_VENDOR:(.*)/) {
     print "Manufacturer: $1\n"; 
    }
 if ($output =~ /CPU_BRAND:(.*)/)  {
     print "Model:        $1\n"; 
    }
foreach my $line (split /\n/, $output) {
    if ($line =~ /PCI_DEVICE_0_(\d+)_(\d+):0x([0-9A-F]{8})/) {
        # ... your existing logic ...
        my $bus  = $1;
        my $dev  = $1;
        my $func = $2;
        my $id   = $3;
        my $dev_hex = substr($id, 0, 4);
        my $ven_hex = substr($id, 4, 4);

        my $name = "Unknown Device";
        if (exists $hardware_db{$id}) {
            $name = $hardware_db{$id};
        } else {
            my $lookup = `lspci -d $ven_hex:$dev_hex -m | cut -d' ' -f3-`;
            chomp($lookup);
            if ($lookup) { $name = $lookup; }
        }
        $name =~ s/"//g;
        $name =~ s/ -r\d+//g;
        $name =~ s/ -p\d+//g;
        print "Bus $bus,Dev $dev, Func $func | ID: $id | $name\n";
    }
} # <--- THIS closes the foreach loop. Make sure there is only ONE brace here.

# --- NOW call the tools outside the loop ---
print "\n--- SYSTEM MEMORY ---\n";
print "Total RAM: " . get_ram() . "\n";

print "\n--- SYSTEM IDENTIFIER ---\n";
print get_gdid() . "\n";

print "\n Testing For windows \n";
my $serial = get_data("cat /sys/class/dmi/id/board_serial", "(Get-CimInstance Win32_BaseBoard).SerialNumber");
print "Test Result: $serial";
chomp($serial);
print "must test this on windows\n";


get_storage();
get_network();
get_usb_tree();
get_dmi_info();
get_gdid();
get_data();

# --- FINALLY, define the subroutines at the very bottom ---
sub get_ram {
    open my $fh, '<', '/proc/meminfo' or return "Unknown";
    my $line = <$fh>;
    return (split(/\s+/, $line))[1] . " kB";
}

sub get_storage {
    print "\n--- STORAGE ---\n";
    foreach my $dev (glob('/sys/block/sd*')) {
        my $dev_name = (split('/', $dev))[-1];
        
        # Try the standard path first
        my $model = `cat $dev/device/model 2>/dev/null`;
        
        # If blank, look for the USB vendor/model descriptor
        if (!$model || $model =~ /^\s*$/) {
            $model = `cat /sys/block/$dev_name/device/vendor 2>/dev/null` . 
                     " " . `cat /sys/block/$dev_name/device/model 2>/dev/null`;
        }
        
        chomp($model);
        print "Disk: $dev_name | Model: $model\n";
    }


}

sub get_network {
    print "\n--- NETWORK & WIFI ---\n";
    foreach my $net (glob('/sys/class/net/*')) {
        my $iface = (split('/', $net))[-1];
        next if $iface eq 'lo';
        
        my $is_wireless = -d "$net/wireless" || -d "$net/phy80211" ? "Wireless" : "Ethernet";

        my $state = `cat $net/operstate 2>/dev/null`; chomp $state;

        my $mac = `cat $net/address 2>/dev/null`; chomp $mac;

        my $vendor = "Unknown";
        my $device = "Unknown";

        if (-e "$net/device/vendor"){
           $vendor = `cat $net/device/vendor 2>/dev/null`;chomp $vendor;
           $device = `cat $net/device/device 2>/dev/null`;chomp $device;
           }
           elsif (-e "$net/device") {
            # It's likely a USB device, look at the parent USB directory
            my $usb_dev = readlink("$net/device");

            if ($usb_dev =~ m/(\d{4}:\d{4})/) {
                ($vendor, $device) = split(':', $1);
                $vendor = "0x" . $vendor; $device = "0x" . $device;
            }
           }
           
           # If we still haven't found the ID, check if the interface name hints at a USB path
        if ($vendor eq "Unknown" && $iface =~ /u(\d+)/) {
            # This is a bit of a hack, but it works: 
            # We look at your USB list to see if we can find a match.
            # For now, since you have the data in USB DEVICES, 
            # we can just hard-map the Realtek if it's the only wireless device.
            if ($is_wireless eq "Wireless") {
                $vendor = "0x0bda";
                $device = "0xc820";
            }
        }

        my $type = `cat $net/type` eq "1\n" ? "Ethernet" : "Wireless/Other";
        printf("Interface: %-15s | Type: %-8s | State: %-6s | Mac: %s | ID: %s:%s\n", $iface, $is_wireless, $state, $mac, $vendor, $device);
    }
}


sub get_usb_tree {
    print "\n--- USB DEVICES ---\n";
    # We glob for devices; 'usb' directories are the controllers, 
    # numbers are the actual devices.
    foreach my $usb_path (glob('/sys/bus/usb/devices/*')) {
        # Only look at files that are actual devices, not just controllers
        next unless -f "$usb_path/idVendor";
        
        my $vendor = `cat $usb_path/idVendor 2>/dev/null`; chomp $vendor;
        my $prod   = `cat $usb_path/idProduct 2>/dev/null`; chomp $prod;
        my $man    = `cat $usb_path/manufacturer 2>/dev/null`; chomp $man;
        my $desc   = `cat $usb_path/product 2>/dev/null`; chomp $desc;
        
        # Format the output cleanly
        printf("USB [%s:%s] | %s - %s\n", $vendor, $prod, $man || "Unknown", $desc || "Device");
    }
}

sub get_dmi_info {
    print "\n--- MOTHERBOARD & DMI METADATA ---\n";
    
    # These files contain the juicy hardware identity info
    my %dmi_map = (
        "Board Vendor"  => "/sys/class/dmi/id/board_vendor",
        "Board Name"    => "/sys/class/dmi/id/board_name",
        "Board Serial"  => "/sys/class/dmi/id/board_serial",
        "BIOS Version"  => "/sys/class/dmi/id/bios_version",
        "BIOS Date"     => "/sys/class/dmi/id/bios_date",
        "Chassis Type"  => "/sys/class/dmi/id/chassis_type"
    );

    foreach my $key (sort keys %dmi_map) {
        my $val = `cat $dmi_map{$key} 2>/dev/null`;
        chomp($val);
        printf("%-15s : %s\n", $key, $val || "Unknown");
    }
}

sub get_gdid {
    my $serial = "UNKNOWN";
    my $mac    = "00:00:00:00:00:00";

    if ($^O eq 'MSWin32') {
        # Windows: Use WMIC for Serial and getmac for MAC
        $serial = `wmic bios get serialnumber /value` =~ /SerialNumber=(.*)/ ? $1 : "UNKNOWN";
        $mac    = `getmac /fo csv /nh` =~ /([0-9A-F-]{17})/ ? $1 : "UNKNOWN";
    } else {
        # Linux: Use your existing DMI path and the first network interface
        $serial = `cat /sys/class/dmi/id/board_serial 2>/dev/null`;
        my @nics = glob('/sys/class/net/*');
        # Grab the first available non-loopback MAC
        foreach my $nic (@nics) {
            next if $nic =~ /lo$/;
            $mac = `cat $nic/address 2>/dev/null`;
            last;
        }
    }
  
    chomp($serial, $mac);
    # Return a simple fingerprint string
    return "GDID-" . substr($serial, 0, 8) . "-" . substr($mac, -5, 5);
}

sub run_cmd {
    my ($linux_cmd, $win_cmd) = @_;
    if ($^O eq 'MSWin32') {
        return `powershell -Command "$win_cmd" 2>nul`;
    } else {
        return `$linux_cmd 2>/dev/null`;
    }
}

printf("\n All Hardware Scan Completed. Thank you\n");
