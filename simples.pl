#!/usr/bin/perl -w
use strict;
use UOLbot;

$| = 1;

##############
# para testes
#$UOL::bot::OCR = 0;
#print $UOL::OCR::VERSION, "\n";
#$UOL::OCR::verbosity = 7;
#LWP::Debug::level ('+');
##############

# cria instância de bot
my $bot = new UOLbot (
   Nick		=> 'machinehead',	# nome digno de bot
   Color	=> 3,			# azul
   Avatar	=> 74,			# um feinho
   Fast		=> 1,			# para não descepcionar ;)
);

##############
# para testes
#$bot->ua->proxy (http => 'http://localhost:8080/');
##############

# autentica usuário registrado para entrar em salas com mais de 30 pessoas
my @auth = qw(); # qw(stanislav 123mudar)
print "autenticando\n";
$bot->auth (@auth) || die "can't auth(): $!";

# lista sub-grupo 'Cidades e Regiões/SP Interior (S-Z)'
my $subgrp = 'idspin5.conf';
print "listando sub-grupo $subgrp\n";
my @rooms = $bot->list_subgrp ($subgrp);
die "can't list_subgrp(): $!" unless @rooms;

# sala #17 ('Saint Charles 1') ;)
my $url = $rooms[17]->{URL};

# espia a sala
print "espiando a sala $url\n";
$bot->brief ($url) || die "can't brief(): $!";

# imprime a lista de usuários conectados
print "users online: ", join ('>', $bot->users), "\n";

# entra na sala escolhida
print "entrando na sala $url\n";
unless ($bot->login ($url)) {
   # verificação avançada de erro
   my $err = $bot->login_error;
   my $msg;
   unless (defined $err) {
      $msg = $!;
   } elsif ($err == 1) {
      $msg = 'nick em uso';
   } elsif ($err == 2) {
      $msg = 'sala cheia';
   } elsif ($err == 3) {
      $msg = 'código de verificação incorreto';
   } else {
      $msg = 'erro desconhecido';
   }
   die "can't login(): $msg";
}

# envia mensagens bem... automáticas
for (my $i = 1; $i <= 5; $i++) {
   print "enviando mensagem $i\n";
   $bot->send ("teste $i") || die "can't send(): $!";
}

# sai da sala
print "saindo da sala\n";
$bot->logout || die "can't logout(): $!";

# falows
exit;
