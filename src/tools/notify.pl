#!/usr/bin/perl
use strict;
use warnings;
use Net::SMTP;
use Sys::Hostname;
use File::Copy;

# ==============================================================================
# HoneyBee Native Perl Mail Relay (Authenticated SMTP + Atomic File Swap)
# ==============================================================================
# Usage: notify.pl "HoneyBeeBash Warning Bee-mail-predator" mike@honeybeebash.com [path/file] clear
#

# --- Command Line Parameters ---
my $subject     = $ARGV[0] || "HoneyBeeBash Alert \@$host";
my $to          = $ARGV[1] || '';
my $config_path = $ARGV[2] || "";
my $file_path   = $ARGV[3] || "";
my $clear_file  = $ARGV[4] || "clear";
my $host        = hostname();

# CRITICAL FIX: Perl uses 'eq' for string comparisons. '==' forces numerical casting.
if ($to eq "" || $config_path eq "" || $file_path eq "") {
    print "ERROR: Missing required parameters.\n";
    print "Usage: notify.pl \"[Subject]\" \"[Recipient Email]\" \"[Config Path]\" \"[Log File Path (Optional)]\" \"[Clear Flag (Optional)]\"\n";
    exit(1);
}

# Declare to strict that these global variables exist elsewhere
our ($smtp_server, $smtp_port, $smtp_user, $smtp_pass, $smtp_from);

# Source the file
require "$config_path/notify.conf"


# If the configuration is not complete then warn and exit
if ($smtp_server eq "" || $smtp_port eq "" || $smtp_user eq "" || $smtp_pass eq "" || $smtp_from eq "") {
    print "ERROR: Missing notify.conf values.\n";
    print "Edit $HOME/.config/honeybeebash/notify.conf to complete or run install/install.sh again."
    exit(1);
}


my $body = "No attachment or log data provided.";

# --- Phase 1: Safe File Isolation & Truncation ---
if ($file_path eq "") {
    die "Add the path/file reference as third parameter.";
} else {
    if (-f $file_path) {
        # Define a temporary working file path
        my $tmp_working_file = $file_path . ".processing";
        
        # Make file clearing optional but the default
        if ($clear_file == "clear") {
            # ATOMIC MOVE: Renames the file instantly. 
            # Any new Bee writes hitting $file_path right now will start a fresh file.
            if (move($file_path, $tmp_working_file)) {
                
                # Read the isolated content into memory
                if (open(my $fh, '<', $tmp_working_file)) {
                    local $/; # Slurp mode: read entire file at once
                    $body = <$fh>;
                    close($fh);
                    
                    if ($body eq "") {
                        # File is empty, end silent
                        exit 0;
                    }
                }
                
                # Fast deletion of the processed data chunk
                unlink($tmp_working_file);
            } else {
                $body = "WARNING: Found file $file_path but could not isolate it cleanly: $!";
            }
        }
    } else {
        # File not found, end silent
        exit 0;
    }
}

# --- Phase 2: Authenticated SMTP Network Dispatch ---

# 1. Establish the Initial Connection
my $smtp = Net::SMTP->new(
    $smtp_server,
    Port    => $smtp_port,
    Timeout => 10,
    Debug   => 0  # Set to 1 if you need to watch the raw TLS handshake in your shell
) or die "ERROR: Cannot connect to backup mail relay: $!\n";

# 2. Upgrade the Connection to TLS (Crucial for mail.clerck.nl)
$smtp->starttls() 
    or die "ERROR: Failed to establish secure TLS layer: " . $smtp->message() . "\n";

# 3. Challenge Handshake Authentication (Now safely encrypted!)
$smtp->auth($smtp_user, $smtp_pass) 
    or die "ERROR: Authentication failed for user $smtp_user\n";

# 4. Stream Transaction Sequence
$smtp->mail($smtp_from);
if ($smtp->to($to)) {
    $smtp->data();
    $smtp->datasend("From: HoneyBee <$from>\r\n");
    $smtp->datasend("To: $to\r\n");
    $smtp->datasend("Subject: $subject\r\n");
    $smtp->datasend("\r\n"); # Crucial blank boundary line
    $smtp->datasend("$body\r\n");
    $smtp->dataend();
    print "✅ Notification dispatched successfully over TLS from $host.\n";
} else {
    print "ERROR: Recipient denied by server: ", $smtp->message(), "\n";
}

$smtp->quit;

