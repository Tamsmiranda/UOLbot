#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use UOLbot;
use vars qw(%conf $bot %room);

# OCR est� quebrado mesmo :(
$UOL::bot::OCR = 0;

# formato de configura��o
use constant CONF => qw(
avatar=i
color=i
config=s
delay=i
errdelay=i
fast
limit=i
logfile=s
maxusers=i
minusers=i
msg=s
msgact=i
msgico=i
msgpvt
msgsnd=i
msgto=s
nick=s
pass=s
quiet
rndmax=i
rndmin=i
room=s
shuffle
tries=i
user=s
verbose
);


# m�sera fu�adinha ;)
my $config = 'uolker.ini';
$config = undef unless -f $config;

# defaults
$conf{avatar}	= -1;
$conf{color}	= 0;
$conf{config}	= \$config;
$conf{delay}	= 60;
$conf{errdelay}	= 180;
$conf{fast}	= 0;
$conf{limit}	= 0;
$conf{logfile}	= '';
$conf{maxusers}	= 45;
$conf{minusers}	= 15;
$conf{msg}	= 'uolker rege';
$conf{msgact}	= 0;
$conf{msgico}	= 0;
$conf{msgpvt}	= 0;
$conf{msgsnd}	= 0;
$conf{msgto}	= 'TODOS';
$conf{nick}	= 'uolker';
$conf{pass}	= '';
$conf{quiet}	= 0;
$conf{rndmax}	= 10;
$conf{rndmin}	= 01;
$conf{room}	= 'uolker.lst';
$conf{shuffle}	= 0;
$conf{tries}	= 3;
$conf{user}	= '';
$conf{verbose}	= 0;


# carrega par�metros... cabal�stico, n�o?
# a prioridade � a seguinte (mais baixa => 1):
# 1) arquivo 'uolker.ini' no diret�rio atual
# 2) arquivo especificado com --config
# 3) linha de comando
my @bak = @ARGV;
&loadconf;
&loadconf ($config) if defined $config;
@ARGV = @bak;
&loadconf;

# salva log
if ($conf{logfile}) {
   open (STDOUT, '>>', $conf{logfile})	|| die "falha ao redirecionar STDOUT para $conf{logfile}: $!";
   open (STDERR, '>&STDOUT')		|| die "falha duplicando STDOUT: $!";
}

# prote��o contra "usu�rio inv�lido" ;)
die "rndmin > rndmax" if $conf{rndmin} > $conf{rndmax};
die "minusers > maxusers" if $conf{minusers} > $conf{maxusers};


# cria inst�ncia do UOLbot
$bot = new UOLbot (
   Nick		=> $conf{nick},
   Color	=> $conf{color},
   Avatar	=> $conf{avatar},
   Fast		=> $conf{fast},
   Tries	=> $conf{tries},
) || die "imposs�vel criar inst�ncia UOLbot";

&log ("inicializado\n");

# carrega/prepara a lista de salas
my @room = loadroom ($conf{room});
die "sem lista de salas" unless @room;
&log ("carregadas ", scalar @room, " salas\n");

# autentica
if ($conf{user} && $conf{pass}) {
   &log ("autenticando como [$conf{user}]\n");
   $bot->auth ($conf{user}, $conf{pass}) || die "falha na autentica��o: $!";
} else {
   &log ("autenticando\n");
   $bot->auth || die "falha na autentica��o: $!";
}


# contadores
my $logins = 1;
my $vcodes = 0;
my $tusers = 0;
my $ok;

# no caso de emerg�ncia...
$SIG{INT} = $SIG{TERM} = sub {
   &log ("recebido sinal de t�rmino\n");
   $conf{limit} = $logins;
};

# entra em loop principal
MAIN:
for (;;) {
   &mess (\@room) if $conf{shuffle};

   foreach my $room (@room) {
      $ok = 0;

      # verifica lota��o
      &log ("verificando '$room{$room}'", (($room{$room} ne $room) ? " ($room)" : ''), "\n");
      $bot->brief ($room) || next;
      &log (scalar $bot->users, " usu�rios na sala\n");
      if ($bot->users < $conf{minusers}) {
         &log ("sala pouco lotada\n");
         $ok--;
         next;
      } elsif ($bot->users > $conf{maxusers}) {
         &log ("sala muito lotada\n");
         $ok--;
         next;
      }

      # entra na sala
      &log ("entrando na sala como '", $bot->nick, "'\n");
      unless ($bot->login ($room)) {
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
	    $vcodes += $conf{tries};
	    $ok--;
         } else {
            $msg = 'erro desconhecido';
         }
         &log ("falha durante login: $msg\n");
         next;
      }
      $vcodes += $bot->is_logged;

      # mensagens depurativas
      &log ('imgcode:', $bot->encode, ':', $bot->decode, "\n") if $conf{verbose};

      # forma mensagem com randomizador num�rico
      my $rnd = $conf{rndmin} + rand ($conf{rndmax} - $conf{rndmin} + 1);
      my $msg = sprintf ($conf{msg}, $rnd);
      # envia mensagem
      &log ("enviando mensagem de ", length $msg, " caracteres\n") if $conf{verbose};
      my $sent = $bot->send (
         Msg		=> $msg,
         Action		=> $conf{msgact},
         To		=> $conf{msgto},
         Reserved	=> $conf{msgpvt},
         Sound		=> $conf{msgsnd},
         Icon		=> $conf{msgico},
      );
      # testa
      unless ($sent) {
         &log ("falha enviando mensagem\n");
         $bot->logout;
         next;
      } else {
         $tusers += $bot->users;
      }

      # sai da sala
      &log ("saindo da sala\n");
      $bot->logout;

      $ok++;
   } continue {
      if ($ok == 1 && $conf{verbose}) {
         my $p = (time - $^T) / 60;
	 my $h = $p / 60;
	 my $m = $p % 60;
         &log (sprintf ("efetuados %d logins em %dh %02dm (m�dia por hora %0.2f)\n", $logins, $h, $m, $logins / $h));
         &log (sprintf ("mensagem enviada para %d usu�rios (m�dia por hora %0.2f)\n", $tusers, $tusers / $h));
         &log (sprintf ("m�dia de usu�rios por sala %0.2f\n", $tusers / $logins)) if $logins;
         &log (sprintf ("testados %d c�digos de verifica��o (taxa de acerto %0.2f)\n", $vcodes, $logins / $vcodes)) if $vcodes;
      }

      # imp�e limites caso estejam definidos
      last MAIN if ($conf{limit} > 0) && ($logins >= $conf{limit});

      # o que fazer agora
      if ($ok == 0) {
         # se � que a rede caiu, n�o pioremos a situa��o!
         &log ("erro: aguardando $conf{errdelay} segundos\n");
         sleep $conf{errdelay};
      } elsif ($ok == -1) {
         # pr�xima sala
      } else {
         $logins++;
         # descansa um pouco
         sleep $conf{delay};
      }
   }
}

# at�!
&log ("desativando\n");
exit;


sub log {
   print STDERR "[", scalar localtime, "] - ", @_ unless $conf{quiet};
}

sub loadconf {
   if (@_) {
      @ARGV = ();
      my $file = shift;
      open (INI, $file) || die "config $file: $!";
      while (my $line = <INI>) {
         chomp $line;
         $line =~ s/^\s+//;
         $line =~ s/\s+$//;
         next if $line =~ /^\#/;
         $line = '--'.$line unless $line =~ /^\-\-/;
         push @ARGV, split /\s+/, $line, 2;
      }
      close INI;
   }

   GetOptions (\%conf, CONF);

   return;
}

sub loadroom {
   my $file = shift;
   my @room = ();
   %room = ();
   open (ROOM, $file) || die "room $file: $!";
   while (my $line = <ROOM>) {
      chomp $line;
      $line =~ s/^\s+//;
      $line =~ s/\s+$//;
      next if $line =~ /^\#/;
      if ($line =~ /\.conf$/) {
         &log ("enumerando sub-grupo [$line]\n") if $conf{verbose};
         my @rooms = $bot->list_subgrp ($line);
         die "can't list_subgrp(): $!" unless @rooms;
         foreach my $room (@rooms) {
            $room{$room->{URL}} = $room->{Title};
            push @room, $room->{URL};
         }
      } else {
         my ($url, $title) = split /\s+/, $line, 2;
         $title = $url unless $title;
         $room{$url} = $title;
         push @room, $url;
      }
   }
   close ROOM;
   return @room;
}

sub mess {
   my $array = shift;
   my $loops = 10;
   for (my $i = 0, my $n = scalar @$array; $i < ($n * $loops); $i++) {
      push @$array, splice (@$array, rand ($n - ($i % $n)), 1);
   }
   return;
}
