#!/usr/bin/perl -w
use strict;
use UOLbot;

# para *ver* o que realmente está acontecendo, execute:
# perl simples.pl debug
LWP::Debug::level ('+') if grep /debug/i, @ARGV;


# criamos o nosso próprio UserAgent
my $ua = LWP::UserAgent->new;
$ua->agent ('Mozilla/4.0 (compatible; MSIE 6.0; Windows 98)');
$ua->timeout (30);
#$ua->proxy (http => 'http://localhost:8080/'); # para testes


# cria instância de bot
my $bot = new UOLbot (
   UA			=> $ua,
   Nick			=> 'teste',
);

# lista sub-grupo 'São Paulo Interior'
my @rooms = $bot->list_subgrp ('idspin5.conf');
die "can't list_subgrp(): $!" unless @rooms;

# sala #15 ('Saint Charles') ;)
my $url = $rooms[15]->{URL};

# espia a sala
$bot->brief ($url) || die "can't brief(): $!";

# imprime a lista de usuários
print "Users online: ", join ('|', $bot->users), "\n";

# entra na sala
unless ($bot->login ($url)) {
   my $err = $bot->login_error;
   my $msg;
   unless (defined $err) {
      $msg = $!;
   } elsif ($err == 1) {
      $msg = 'nick already used';
   } elsif ($err == 2) {
      $msg = 'room is full';
   } else {
      $msg = 'unknown error';
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
