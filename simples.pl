#!/usr/bin/perl -w
use strict;
use UOLbot;

# para *ver* o que realmente est� acontecendo, execute:
# perl simples.pl debug
LWP::Debug::level ('+') if grep /debug/i, @ARGV;
$| = 1;


# criamos o nosso pr�prio UserAgent
my $ua = LWP::UserAgent->new;
$ua->agent ('Mozilla/4.0 (compatible; MSIE 6.0; Windows 98)');
$ua->timeout (30);
#$ua->proxy (http => 'http://localhost:8080/'); # para testes


# cria inst�ncia de bot
my $bot = new UOLbot (
   UA			=> $ua,
   Nick			=> 'teste',
);

# autentica usu�rio registrado
#$bot->auth ('****@uol.com.br', '********') || die "can't auth(): $!";


# lista sub-grupo 'S�o Paulo Interior'
my @rooms = $bot->list_subgrp ('idspin5.conf');
die "can't list_subgrp(): $!" unless @rooms;

# sala #15 ('Saint Charles') ;)
my $url = $rooms[15]->{URL};

# espia a sala
$bot->brief ($url) || die "can't brief(): $!";

# imprime a lista de usu�rios
print "Users online: ", join ('|', $bot->users), "\n";

# entra na sala
my ($imgcode, $code);
$imgcode = $bot->join ($url);
die "can't join(): $!" unless $imgcode;

# pede para o operador identificar o c�digo
# (se algu�m tiver a moral de decifrar essa URL, contact-me!!! ;)
print "\n$imgcode\n";
print " * me diga o c�digo de 4 letras que aparece nessa imagem: ";
chomp ($code = <STDIN>);

# completa o login
unless ($bot->login ($code)) {
   my $err = $bot->login_error;
   my $msg;
   unless (defined $err) {
      $msg = $!;
   } elsif ($err == 1) {
      $msg = 'nick em uso';
   } elsif ($err == 2) {
      $msg = 'sala cheia';
   } elsif ($err == 3) {
      $msg = 'c�digo de verifica��o incorreto';
   } else {
      $msg = 'erro desconhecido';
   }
   die "can't login(): $msg";
}

# envia mensagens
for (my $i = 1; $i <= 5; $i++) {
   $bot->send ("testando $i...") || die "can't send(): $!";
}

# sai da sala
$bot->logout || die "can't logout(): $!";


exit;
