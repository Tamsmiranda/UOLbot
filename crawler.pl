#!/usr/bin/perl -w
use strict;
use HTML::LinkExtor;
use UOLbot;

# para *ver* o que realmente está acontecendo, execute:
# perl simples.pl debug
LWP::Debug::level ('+') if grep /debug/i, @ARGV;


# autoflush de STDOUT
$| = 1;

# cria a instância
my $bot = new UOLbot (Nick => 'Botowski', Listen_Handler => \&handler);
# sim, podemos configurar o UserAgent interno também!
$bot->ua->agent ('Mozilla/4.0 (compatible; MSIE 6.0; Windows 98)');
$bot->ua->timeout (30);


# a lista de sub-grupos onde iremos agir
# (todas as salas onde imagens são permitidas)
my @subgrps = qw(
idim_he.conf
idimhe2.conf
idim_ga.conf
idimga2.conf
idim_ta.conf
idim_sm.conf
idim_le.conf
idspice.conf
id_sexy.conf
id_hust.conf
idhi_qu.conf
);


# inicializa flags/contadores
my $countu = 0;	# contador de pessoas que teoricamente leram a mensagem
my $counts = 0;	# contador de salas para onde a mensagem foi enviada
my $leave = 0;	# flag para indicar quando ^C for apertado
# trata o sinal do ^C
$SIG{INT} = sub { print STDERR "\ndesativando (SIGINT)...\n"; $leave = 1 };

# loop infinito; único modo de sair é apertando ^C (enviando SIGINT)
LOOP:
for (;;) {
   # aleatoriza o array de sub-grupos
   &mess (\@subgrps);

   SUBGRP:
   foreach my $subgrp (@subgrps) {
      last LOOP if $leave;

      my @rooms = $bot->list_subgrp ($subgrp);
      next SUBGRP unless scalar @rooms;

      # aleatoriza o array de salas
      &mess (\@rooms);
      ROOM:
      foreach my $room (@rooms) {
         last LOOP if $leave;

         $bot->login ($room->{URL})		|| next ROOM;
         $bot->send ('bom dia pessoal!')	|| next ROOM;

         $countu += ($bot->users - 1);
         $counts ++;
      } continue {
         $bot->logout;
      }
   }
}

print STDERR "\n\nmensagem enviada para $countu pessoas em $counts salas\n";
exit;


# handler de escuta da sala
sub handler {
   my $data = shift;

   # imprime todos os links para imagens
   foreach my $links (HTML::LinkExtor->new->parse ($data)->eof->links) {
      my ($tag, %links) = @$links;
      next if $tag ne 'img';
      foreach my $link (values %links) {
         next if $link =~ m/\.uol\.com\.br\b/i; # ignora imagens-exemplo
         print "$link\n";
      }
   }

   return;
}

# aleatoriza array qualquer
sub mess {
   my $array = shift;

   my $loops = 10; # quantas vezes "revirar" o array
   for (my $i = 0, my $n = scalar @$array; $i < ($n * $loops); $i++) {
      push @$array, splice (@$array, rand ($n - ($i % $n)), 1);
   }

   return;
}
