package UOL::OCR;

require 5.000;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT $VERSION);
use vars qw($gocr $db_path);

# O que está fazendo aqui?!?! Isso aqui é só para *developer*, digo, EU.
# Nada de documentação... Bom, se quer se arriscar, única coisa útil aqui
# é o setting de verbosidade de OCR (soma dos valores abaixo):
#
# 1	abre XV para expor imagem original
# 2	abre XV para expor imagem filtrada por Image::Magick
# 4	abre XV para expor imagem filtrada por varredura de linhas brancas
# 8	faz 'gocr' vomitar tanto texto que você jamais poderá ler
# 16	faz 'gocr' criar arquivos "outXX.bmp"
#
use vars qw($verbosity);
$verbosity = 0;

@ISA		= qw(Exporter);
@EXPORT		= qw(jpg2txt);
$VERSION	= '0.01';

use Carp;
use Cwd qw(abs_path);
use File::Basename;
use FileHandle;
croak "! UOL::OCR: no Image::Magick\n" unless eval 'require Image::Magick';
use IPC::Open2;
use POSIX qw(ceil);

my $path	= abs_path (dirname ($INC{'UOL/OCR.pm'}));
$gocr		= "$path/gocr";
if ($^O =~ /Win32/) {
   $gocr =~ s%/%\\%g;
   $gocr .= '.exe';
}
$db_path	= "$path/db/";
croak "! UOL::OCR: no gocr" unless -e $gocr;
croak "! UOL::OCR: no gocr database" unless -f $db_path.'db.lst';


sub jpg2txt {
   my $blob = shift;
   my $img = new Image::Magick (magick => 'jpg');
   $img->BlobToImage ($blob);

   ### debug ###
   &ImgDebug ($blob) if $verbosity & 1;
   ### debug ###

   $img->Despeckle;
   $img->Enhance;
   $img->Contrast (sharpen => 'True');
   $img->Modulate (brightness => 105);
   $img->Level ('black-point' => 28000, 'mid-point' => 1.0, 'white-point' => 48000);
   $img->Quantize (colors => 2, colorspace => 'gray', dither => 'False');
   $img->Crop (x => 0, y => 0, width => 300, height => 78);
   $img->Trim;
   $img->Set (magick => 'pbm');
   ($blob) = $img->ImageToBlob;

   ### debug ###
   &ImgDebug ($blob) if $verbosity & 2;
   ### debug ###
   
   my @res = &UOLImgFilter ($blob);

   ### debug ###
   &ImgDebug (@res) if $verbosity & 4;
   ### debug ###

   my ($rdr, $wtr);
   # 2      use database (early development)
   # 4      layout analysis, zoning (development)
   # 8      ~ compare non recognized chars
   # 16     ~ divide overlapping chars
   # 32     ~ context correction
   # 64     char packing (development)
   # 128    extend database, prompts user (early development)
   # 256    switch off the OCR engine (makes sense together with -m 2)
   my $m = 2+8;

   my @log = ();
   my $v = 0;
   $v += 1 if $verbosity & 8;
   $v += 32 if $verbosity & 16;
   if ($v) {
      ### debug ###
      @log = ('-v', $v);
      ### debug ###
   } else {
      @log = qw(-e /dev/null);
   }

   my $pid = open2 ($rdr, $wtr, $gocr, '-m', $m, '-p', $db_path, @log, '-');
   croak "jpg2txt: $!" if not defined $pid;
   print $wtr @res;
   local $_ = lc <$rdr>;
   waitpid $pid, 0;

   s/\s+//g;
   return (!/\(/ && /([a-z0-9]{4})/) ? $1 : '';
}

sub ImgDebug {
   if ($ENV{DISPLAY} and not fork) {
      open (DISPLAY, "| display -") || croak "display pipe: $!";
      print DISPLAY @_;
      close DISPLAY;
      exit;
   }
}

sub UOLImgFilter {
   my $data = shift;
   my @pbm = split /\n/, $data;
   chomp @pbm;
   @pbm = grep $_ && !/^#/, @pbm;
   croak "not a valid PBM (P4) file\n" if $pbm[0] ne 'P4';
   my ($x, $y) = split /\s/, $pbm[1];
   my $l = POSIX::ceil ($x / 8);
   my $size = ($l * $y);
   my $offs = length ($data) - $size;
   my @img;
   my $sum = 0;
   for (my $j = 0, my $k = 0; $k < $size; $j++, $k += $l) {
      my $line = unpack 'B*', substr $data, $offs + $k, $l;
      for (my $i = 0; $i < $x; $i++) {
         $sum += $img[$i][$j] = substr $line, $i, 1;
      }
   }
   if ($sum > ($x * $y) / 2) {
      for (my $i = 0; $i < $y; $i++) {
         for (my $j = 0; $j < $x; $j++) {
	    $img[$j][$i] = $img[$j][$i] ? 0 : 1;
	 }
      }
   }
   my ($nx, $ny) = ($x, $y);
   for (my $i = 0, my $lastsum = 0; $i < $y; $i++) {
      $sum = 0;
      for (my $j = 0; $j < $x; $j++) {
         $sum += $img[$j][$i];
      }
      if (!$sum && $lastsum) {
         $img[0][$i] = -1;
         $ny--;
      }
      $lastsum = $sum;
   }
   for (my $j = 0, my $lastsum = 0; $j < $x; $j++) {
      $sum = 0;
      for (my $i = 0; $i < $y; $i++) {
         $sum += $img[$j][$i];
      }
      if (!$sum && $lastsum) {
         $img[$j][0] = -1;
         $nx--;
      }
      $lastsum = $sum;
   }
   my @out;
   push @out, "P1\n",
              "$nx $ny\n";
   my $line = '';
   for (my $i = 0, my $k = 0; $i < $y; $i++) {
      next if $img[0][$i] == -1;
      for (my $j = 0; $j < $x; $j++) {
         next if $img[$j][0] == -1;
         $line .= $img[$j][$i] . ' ';
         unless (++$k % 36) {
            push @out, $line . "\n";
   	 $line = '';
         }
      }
   }
   push @out, $line . "\n" if $line;
   return @out;
}

1;
