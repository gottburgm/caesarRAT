#!/bin/sh

echo "* Installing Perl Dependencies ..."
cpan -i LWP::UserAgent
cpan -i LWP::ConnCache
cpan -i HTTP::Request
cpan -i HTTP::Response
cpan -i HTTP::Cookies
cpan -i File::chdir
cpan -i Digest::MD5
cpan -i URI::Escape
cpan -i UUID::Generator::PurePerl
cpan -i App::Packer::PAR
cpan -i PAR::Packer

echo "* Installing Perl package Compilator ..."
wget http://search.cpan.org/CPAN/authors/id/R/RS/RSCHUPP/PAR-Packer-1.041.tar.gz -O /tmp/PAR-Packer.tar.gz
cd /tmp/ ; tar -xzvf PAR-Packer.tar.gz ; cd PAR-Packer* ; perl Makefile.PL ; make ; sudo make install


echo "* Installing Python Depedencies ..."
pip install requests
pip install pyinstaller
sudo pyinstaller -F Client/caesar.py
