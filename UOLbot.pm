package UOLbot;
use strict;


=head1 NOME

UOLbot - Bot para bate-papo da UOL


=head1 PLATAFORMAS SUPORTADOS

Teoricamente, B<todos> onde roda o L<perl>. Oficialmente, foi testado em:

=over 4

=item *

Linux
(perl 5.6.1)

=item *

Windows
(ActivePerl 5.6.1 Build 630)

=back


=head1 RESUMO

  #!/usr/bin/perl
  use UOLbot;

  my $bot = new UOLbot (Nick => 'b0t');

  $bot->login ('http://batepapo4.uol.com.br:3999');
  $bot->send ("oi!");
  $bot->logout;

  exit;


=head1 DESCRI��O

O C<UOLbot> � uma classe que implementa interface para webchat da UOL
(http://www.uol.com.br/). Ele � uma solu��o pr�tica para entrar na sala
de bate-papo, enviar mensagem para todo mundo e sair. Onde tal
habilidade se aplica com sucesso? Propaganda. Sim, spam � muito mau,
mas -- B<rende $$$>.

Voc� que est� prestes a se juntar � liga dos spammers, n�o precisa
de muitos requisitos para usar esse m�dulo. S� o L<perl> e o L<LWP>.
Fiz de tudo para deixar o m�dulo mais simples poss�vel; todas as
"partes m�veis" est�o encapsuladas dentro de uma atraente interface
Orientada a Objetos. N�o se assuste ao abrir o c�digo do m�dulo, esse
� o meu primeiro programa funcional usando Orienta��o a Objetos,
portanto B<por dentro> ainda � uma mistura bizarra de programa��o
linear com OOP.

I<Obs>: antes que me pergunte, "eu estou lendo em portugu�s aqui,
ent�o por que C<send> e n�o I<enviar>, ou C<logout> ao inv�s de I<sair>?"
A raz�o � simples: o "resto" do L<perl> est� em ingl�s, certo?
Por mim, fica estranho ler e entender o que faz algo como

  next if $bot->enviar and not scalar $bot->usuarios;


=head1 INTRODU��O

Agora, o princ�pio ativo. Antes de tudo, voc� deve criar uma inst�ncia
do bot:

  my $bot = new UOLbot (Nick => 'b0t');

O par�metro I<Nick> especifica o nickname do bot.
Voc� pode passar outros, que ser�o descritos posteriormente.
Voc� tamb�m pode B<n�o> passar nenhum, a� o seu bot ser� um
discreto "unnamed".
Voc� pode ter v�rias inst�ncias, s� n�o sei qual o sentido
disso.

Pronto, voc� criou o seu bot... E agora? Ele deve entrar numa sala, n�?

  $bot->login ('http://batepapo4.uol.com.br:3999');

(�tima sala para propaganda, eheheh)
A� voc� passa a URL da sala. � o �nico par�metro B<necess�rio>.
� claro que ter que saber essa URL � um p� no saco, voc� pode entrar na
sala s� sabendo o seu nome. Mas isso � para depois.

Estando na sala, o que fazer? Falar!

  $bot->send ("oi!");

"Oi mundo" C<:P>
Sem coment�rios aqui.

Quando voc� "falou" tudo o que quis, tchau para todos!

  $bot->logout;  

Isso � o b�sico. Se n�o entendeu, pare por aqui.


=head1 M�TODOS

Os m�todos do C<UOLbot> s�o:

=over 4

=cut


use vars qw(@ISA $VERSION $entry $bufsize $CRLF);
$VERSION = "1.1";

# define constantes
$entry		= 'http://batepapo.uol.com.br/bp/excgi/salas_new.shl';
$bufsize	= 32768;
$CRLF		= "\012"; #"\015\012";

# os nossos poucos requisitos...
require 5.004;
use Carp;
use HTTP::Cookies;
use IO::Socket;
use LWP::UserAgent;

# LWP 5.63 com HTTP/1.1 seriam talvez avan�ados demais...
@LWP::Protocol::http::EXTRA_SOCK_OPTS = (
   KeepAlive		=> 0,
   SendTE		=> 0,
   HTTPVersion		=> '1.0',
   PeerHTTPVersion	=> '1.0',
   MaxLineLength	=> 0,
   MaxHeaderLines	=> 0,
);


=item C<new ([ARGS])>

Construtor para o bot. Retorna a refer�ncia para objeto C<UOLbot>.
Argumentos C<ARGS> devem ser passados em forma:

  new (Chave1 => 'valor1',
       Chave2 => 2);

Note que os argumentos especificados aqui s�o I<imut�veis>
depois da inst�ncia ser criada, isto �,
h� m�todos para I<ler> o seu conte�do mas n�o I<gravar>!
Argumentos v�lidos (B<todos> opcionais):

=over 4

=item I<UA>

refer�ncia para objeto LWP::UserAgent externo (� criada inst�ncia interna por default)

=item I<Nick>

o nickname (valor default � I<"unnamed">)

=item I<Color>

a cor do nickname (valor default � I<0>)

I<Obs>: valores poss�veis s�o:

  0 - Preto
  1 - Vermelho
  2 - Verde
  3 - Azul
  4 - Laranja
  5 - Cinza
  6 - Roxo

=item I<Listen_Handler>

refer�ncia para o c�digo que vai processar as
informa��es recebidas da sala (indefinido por default).
Por exemplo:

  Listen_Handler => sub { print $_[0] }

imprime qualquer coisa recebida e

  Listen_Handler => \&listen_handler
  ...
  sub listen_handler {
     my $data = shift;
     ...
     return;
  }

define a sub-rotina I<listen_handler> como handler de 'escuta'.
Nesse caso, vari�vel I<$data> recebe pacotes com c�digo HTML recebidos.

I<Obs>: lembre que nem sempre h� uma mensagem em um pacote. O servidor
(ou buffer do sistema operacional) pode juntar v�rios pacotes num s�.

=back

=cut

sub new {
   my ($class, %conf) = @_;
   my %init;

   # l� par�metros
   foreach my $key (keys %conf) {
      $init {lc $key} = $conf {$key};
   }

   # cria inst�ncia
   my $self = bless { %init }, $class;


   # 'sanity check'
   $self->{ua} = new LWP::UserAgent if not defined $self->{ua} or not $self->{ua};
   if (not defined $self->{nick} or not $self->{nick}) {
      $self->{nick} = 'unnamed';
   }
   if (not defined $self->{color} or not $self->{color}) {
      $self->{color} = 0;
   }

   # desativar 'listen handler' se este n�o for fornecido
   unless ((defined $self->{listen_handler}) and
           (ref ($self->{listen_handler}) eq 'CODE')) {
      $self->{listen_handler} = undef;
   }


   # configura��o b�sica
   $self->{user}	= &ief ($self->{nick});
   $self->{id}		= 0;

   $self->{users}	= [];
   $self->{logged}	= 0;

   $self->{cookies}	= new HTTP::Cookies;
   $self->{header}	= new HTTP::Headers;


   # inicializa
   #$self->{header}->header ('Accept', 'text/html, image/png, image/jpeg, image/gif, image/x-xbitmap, */*');
   #$self->{header}->header ('Accept-Encoding', 'deflate, gzip, x-gzip, identity, *;q=0');

   $self->{ua}->cookie_jar ($self->{cookies});


   # feito!
   return $self;
}


# m�todos para acesso aos par�metros internos...
sub getset {
   my ($self, $key, $val) = @_;
   my $old = $self->{$key};

   $self->{$key} = $val if not $self->is_logged and defined $val;

   return $old;
}

sub ua {
   my $self = shift;
   my $r = $self->getset ('ua',		@_);
   $self->{ua}->cookie_jar ($self->{cookies}) if @_;
   return $r;
}
sub nick {
   my $self = shift;
   my $r = $self->getset ('nick',	@_);
   $self->{user} = &ief (shift) if @_;
   return $r;
}
sub color {
   shift->getset ('color',		@_);
}
sub listen_handler {
   shift->getset ('listen_handler',	@_);
}

=item C<ua>

=item C<nick>

=item C<color>

=item C<listen_handler>

M�todos para ler/definir os par�metros definidos pelo C<new>.

I<Obs>: Voc� pode ler os valores a qualquer momento, mas s� poder�
definir quando a inst�ncia I<n�o estiver logada> com C<login>!

=cut


=item C<list_subgrp (SUBGRP)>

Enumera as salas de bate-papo de um sub-grupo C<SUBGRP>. O tal sub-grupo
� o documento onde nomes das salas, suas URLs e suas lota��es s�o fornecidos.
C<list_subgrp> � simplesmente uma interface para esse documento.
Par�metro C<SUBGRP> � uma string com URL de formato
I<'http://batepapo.uol.com.br/bp/excgi/salas_new.cgi?ID=idim_he.conf'>
ou ent�o simplesmente I<'idim_he.conf'>. Os dois s�o equivalentes.
Quando voc� usa C<list_subgrp> antes de C<login>, C<SUBGRP> � salvo e
utilizado como C<REF> de C<login> automaticamente. O m�todo retorna
um array de hashes se tiver sucesso e I<()> se houver falha. O array
retornado pode ser expandido com:

  my @room = $bot->list_subgrp ('idim_he.conf');
  foreach $room (@room) {
     print $room->{URL}, "\n",
           $room->{Title}, "\n",
           $room->{Load}, "\n\n";
  }

onde C<URL> � a URL da sala de bate-papo, C<Title> � o t�tulo dela e
C<Load> � o n�mero de pessoas na sala
(0-40, -1 significa I<"sala lotada">).

=cut

sub list_subgrp {
   my ($self, $list) = @_;

   # completa o nome se for necess�rio
   $list = $entry.'?ID='.$list unless $list =~ m{^http://};

   # verifica se a URL est� certa...
   my $test = "\Q$entry\E";
   $list =~ /^$test\?ID=.*\.conf$/i ||
      croak "list_subgrp: URL inv�lida";

   # carrega a lista em HTML
   my $req = $self->{ua}->request (HTTP::Request->new (GET => $list, $self->{header}));
   $req->is_success || return ();

   # colhe o nome de servidor
   my ($serv) = $req->content =~ /\bmaq = (\d+)\b/;
   # colhe o caracter usado como separador de lista
   $req->content =~ /\bs="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inv�lida (sem separador)";
   my $sep = "\Q$1\E"; # sim, isso vai para regexp futuramente...

   # colhe os nomes das salas
   $req->content =~ /\bd1="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inv�lida (sem nomes das salas)";
   my @room = split /$sep/, $1;

   # colhe as respectivas portas...
   $req->content =~ /\bd2="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inv�lida (sem portas das salas)";
   my @port = split /$sep/, $1;

   # ...e quantas pessoas tem nelas
   $req->content =~ /\bd3="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inv�lida (sem dados de lota��o)";
   my @load = split /$sep/, $1;


   # monta um vetor de estruturas "sala"
   my @list = ();
   for (my $i = 0; $i < @room; $i++) {
      push @list, {
	URL	=> "http://batepapo$serv.uol.com.br:$port[$i]/",
	Title	=> $room[$i],
	Load	=> $load[$i]
      };
   }


   # lembra a sala listada para usar como referer durante join()
   $self->{from} = $list;
   return @list;
}


=item C<brief (ROOM)>

"Espia" na sala sem entrar nela. Retorna I<0> se falha. Caso tiver sucesso,

=over 4

=item 1

guarda a lista com nomes de usu�rios para depois ser vista com C<users>

=item 2

passa o fragmento da conversa para rotina definida em C<Listen_Handler>

=item 3

retorna I<1>

=back

=cut

sub brief {
   my ($self, $room) = @_;

   # verifica��o b�sica
   $room =~ m%^http://batepapo\d.uol.com.br:\d+/?%i ||
      croak "brief: URL inv�lida";

   # completa a URL
   $room =~ s%/?$%/PUBLIC_BRIEF%;

   # faz pedido
   my $req = $self->{ua}->request (HTTP::Request->new (GET => $room, $self->{header}));
   return 0 unless $req->is_success;

   # pega a lista de usu�rios em HTML
   $req->content =~ / {8}(.*?)\s{8}/s ||
      croak "brief: servidor enviou resposta inv�lida (sem nomes de usu�rios)";

   # processa a lista
   my @users = split /<br>\s*/, $1;
   # salva a lista
   $self->{users} = [];
   foreach my $user (@users) {
      push @{$self->{users}}, $user if $user;
   }

   # e agora as mensagens do pr�prio chat
   $req->content =~ m{rolando</h2></b>\s+(.*?)<p><blockquote>}s ||
      croak "brief: servidor enviou resposta inv�lida (sem mensagens do chat)";
   # processa
   $self->handle (\$1);

   return 1;
}


=item C<login (ROOM [, REF])>

Efetua I<login> na sala C<ROOM> de bate-papo. Par�metro C<ROOM> consiste
de uma string de formato C<"http://batepapo4.uol.com.br:3999/">. Par�metro
C<REF>, opcional, � o I<Referer>, o documento que continha o link para
C<ROOM>. Se voc� omitir o C<REF>, valor
I<'http://batepapo.uol.com.br/bp/excgi/salas_new.shl'>
ser� usado automaticamente. Se voc� estiver usado C<list_subgrp> antes
de C<login>, a URL de sub-grupo listado ser� usada como C<REF>.
Leia mais sobre C<list_subgrp>.

Retorna I<0> se houver falha e I<1> se tiver sucesso. A "falha" mais prov�vel
� que a sala esteja cheia.

=cut

sub login {
   my $self = shift;

   # tolera erro bobo
   return 0 if $self->is_logged;
   $_[0] =~ m%^http://batepapo\d.uol.com.br:\d+/?%i ||
      croak "login: URL inv�lida";

   # a grande macro...
   my $r = $self->join (@_);
   return $r unless $r;

   $self->load    || return 0;
   $self->listen  || return 0;

   # se � que estamos aqui...
   $self->{logged}	= 1;
   $self->{err}		= 0;

   return 1;
}


=item C<is_logged>

Retorna I<1> se o bot estiver atualmente numa sala de bate-papo e I<0> caso contr�rio.

=cut

sub is_logged {
   my $self = shift;
   return (defined $self->{logged} && $self->{logged}) ? 1 : 0;
}


=item C<login_error>

Retorna o c�digo do erro durante login:

  0     - sucesso
  1     - nickname j� foi utilizado
  2     - sala est� cheia
  undef - erro desconhecido (ver valor de $!)

=cut

sub login_error {
   return shift->{err};
}


sub join {
   my ($self, $room, $ref) = @_;

   # processar os par�metros
   croak "erro interno em join(): falta URL da sala" if not defined $room or not $room;
   $room .= '/' unless $room =~ m{/$};

   # "lembra" o Referer se for poss�vel
   $self->{room} = $room;
   if (defined $ref and $ref ne '') {
      $self->{ref} = $ref;
   } elsif (defined $self->{from}) {
      $self->{ref} = $self->{from};
   } else {
      $self->{ref} = $entry;
   }

   $self->{header}->header ('Referer', $self->{ref});

   # envia "Join Server"
   my $resp = $self->post ('', 'JS=1&USER='.$self->{user}.'&nickCor='.$self->{color}, $self->{header});

   # trata o eventual erro
   if ($resp->code != 200) {
      if ($resp->code == 302) {
         my $redir = $resp->header ('Location');
         if ($redir =~ /sainick/) {
            $self->{err} = 1;	# nick repetido
         } elsif ($redir =~ /esgotada/) {
            $self->{err} = 2;	# sala cheia
         }
      }

      return 0;
   }
   
   # salva dados da sess�o
   ($self->{id}) = $resp->content =~ /&ID=(.*?)&/;
   $self->{usid} = 'USER='.$self->{user}.'&ID='.$self->{id}.'&';

   return 1;
}

sub load {
   my $self = shift;
   local $_;

   # �rvore de frame
   my %tree = (
      n0_TOPO	=> $self->reref ($self->{room}),
      n1_BANNER	=> $self->reref ($self->{room}),
      n2_EXTRA	=> $self->reref ($self->{room}.'TOPO&'.$self->{usid}),
   );

   # carrega o frame tal como um browser carregaria
   foreach (sort keys %tree) {
      my $frame = substr $_, 3;
      my $resp = $self->{ua}->simple_request (
         HTTP::Request->new (
	       GET => $self->{room}.$frame.'&'.$self->{usid},
	       $tree {$_}
         )
      );

      return 0 if $resp->is_error;

      # pega a lista de usu�rios na sala
      $self->banner ($resp) if /BANNER/;
   }

   # agora as chamadas HTTP s�o "de dentro" do frame
   $self->{header}->header ('Referer', $self->{room}.'BANNER&'.$self->{usid});

   return 1;
}

sub listen {
   my $self = shift;


   # Temos que fazer conex�o "manualmente" sen�o um request() travaria
   # o programa at� dar timeout.
   # Claro que *existe* o tal do Net::HTTP, ele at� v�m com LWP mais
   # novo, mas o que queremos � COMPATIBILIDADE, certo?

   # monta request
   my $req = HTTP::Request->new (
	GET => $self->{room}.'BODY&'.$self->{usid},
	$self->reref ($self->{room}.'TOPO&'.$self->{usid})
   );

   # completa headers
   $req->push_header ('User-Agent' => $self->{ua}->agent);
   $req->push_header ('Host' => $req->uri->host.':'.$req->uri->port);
   $self->{cookies}->add_cookie_header ($req);

   # copia headers
   my $hdr = '';
   $req->scan (sub { $hdr .= $_[0].': '.$_[1].$CRLF });

   # usar proxy se esse for fornecido
   my $proxy = $self->{ua}->proxy ('http');
   my ($url, $uri);
   if (defined $proxy) {
      $url = $HTTP::URI_CLASS->new ($proxy);
      $uri = $req->uri->as_string;
   } else {
      $url = $req->uri;
      $uri = $url->path;
   }

   # constr�i mensagem HTTP
   my $msg = (
	$req->method .
	' ' .
	$uri .
	" HTTP/1.0" . $CRLF .
	$hdr .
	$CRLF
   );


   # conectar!
   my $sock = IO::Socket::INET->new (
      Proto	=> 'tcp',
      PeerAddr	=> $url->host,
      PeerPort	=> $url->port,
      Timeout	=> 60*60*24*7	# deve ser o suficiente ;)
   ) || return 0;

   # precau��es...
   binmode $sock;
   $sock->autoflush (1);

   # envia mensagem HTTP
   if (defined syswrite ($sock, $msg, length $msg)) {
      # receber 1-o pacote
      my $buf;
      sysread ($sock, $buf, $bufsize);
      # arranca os headers
      $buf =~ s%^.*?text/html\s+%%s; # algu�m tem id�ia melhor?
      # processa
      $self->handle (\$buf);

      # salva socket e retorna
      $self->{sock} = $sock;
      return 1;
   } else {
      return 0;
   }
}


=item C<users>

Retorna array de nicknames de usu�rios atualmente presentes na sala
de bate-papo. Os dados s�o atualizados toda vez que voc� efetua C<login>
ou C<send>. Desculpe, n�o fui eu quem inventou isso... Retorna no m�nimo
o pr�prio nickname (a sala n�o est� vazia se I<voc�> est� l� C<;)> ou I<()>
no caso de falha.

=cut

sub users {
   return @{shift->{users}};
}


=item C<send ([MSG] [, ATTR])>

Envia mensagem C<MSG> para sala de bate-papo. Possui 4 sintaxes:

=over 4

=item 1

 $bot->send ('mensagem 1');

a mais simples, envia string I<'mensagem 1'>

=item 2

 $bot->send ('mensagem 2', To => 'TODOS', Action => 15);

envia string I<'mensagem 2'> com atributos C<To> e C<Action> explicados abaixo

=item 3

 $bot=>send (Msg => 'mensagem 3', To => 'TODOS', Action => 15);

o mesmo de cima para I<'mensagem 3'>

=item 4

 $bot->send ();

sintaxe mais obscura, n�o envia B<nada>, apenas atualiza a lista que
pode ser obtida com m�todo C<users>. De novo, n�o fui eu quem inventou!

=back

Agora, sobre atributos C<ATTR>. S�o todos opcionais
(forma C<Chave =E<gt> 'Valor'>), aqui est� a lista
com uma breve explica��o:

=over 4

=item I<Msg>

a mensagem em si, string (s� pode ser usado com I<sintaxe 3>, ignorado na I<sintaxe 2>!)

=item I<Action>

a��o, valor inteiro. A��es poss�veis:

  0  - fala para (default)
  1  - pergunta para
  2  - responde para
  3  - concorda com
  4  - discorda de
  5  - desculpa-se com
  6  - surpreende-se com
  7  - murmura para
  8  - sorri para
  9  - suspira por
  10 - flerta com
  11 - entusiasma-se com
  12 - ri de
  13 - d� um fora em
  14 - briga com
  15 - grita com
  16 - xinga

  18 - IGNORAR mensagens de
  19 - s� receber mensagens de
  20 - n�o IGNORAR mais

=item I<To>

o nickname do receptor da a��o I<Action>, string. Valor default � I<'TODOS'>.

I<Obs1>: B<n�o necessariamente> � algu�m que esteja na sala. Isto �, voc�
pode fazer:

  $bot->send ('bots da UOL, un�-vos!', To => 'bots renegados');

B<desde que> I<n�o> seja uma mensagem reservada (C<Reserved =E<gt> 1>)!

I<Obs2>: independentemente do valor do I<To>, todos os usu�rios da sala
ir�o ler a mensagem. Para mensagens privadas, use I<Reserved>.

=item I<Reserved>

pode ser I<1> ou I<0>. Quando I<1>, a mensagem � enviada reservadamente
para nickname I<To>. Valor default � I<0>.

=item I<Sound>

som a ser enviado, inteiro. Sons poss�veis:

  0  - nenhum (default)
  14 - Ahn???
  15 - Bang!
  16 - Banjo
  17 - Dinossauro
  18 - Fiu-fiu
  19 - Ocupado
  20 - Oinc
  21 - Pigarro
  22 - Smack!
  23 - Susto
  24 - Telefone
  25 - T�l�ca
  26 - Tosse
  07 - Como �?
  08 - N�o entendi

=item I<Icon>

�cone a ser enviado, inteiro. �cones poss�veis:

  0  - nenhum (default)
  38 - Assustado
  27 - Bocejo
  23 - Careta
  30 - Dentu�o
  18 - Desejo
  31 - Eca !
  32 - Gargalhada
  33 - Indeciso
  34 - Louco
  28 - Na praia
  35 - Ohhh !
  20 - OK!
  36 - Piscada
  37 - Raiva
  19 - Smack!
  21 - Sorriso
  26 - Zangado

=back

Retorna I<0> se houver falha e I<1> se tiver sucesso.

I<Obs>: B<aparentemente> o servidor n�o aceita mensagens E<gt> 200 bytes.

=cut

sub send {
   my $self = shift;

   # tolera erro bobo
   return 0 unless $self->is_logged;


   # processa forma send($msg, To => $to, Action => 15)
   my $says;
   $says = shift if @_ % 2;


   # processa forma send(Msg => $msg, To => $to, Action => 15)
   my %args = @_;

   # l� atributos da mensagem
   my %attr;
   foreach my $key (keys %args) {
      $attr {lc $key} = $args {$key};
   }

   # acerta defaults
   $says	= $attr{msg} if defined $attr{msg} and not defined $says;
   my $action	= (defined $attr{action} && $attr{action} =~ /\d+/) ? $attr{action} : 0;
   my $whoto	= (defined $attr{to}) ? $attr{to} : 'TODOS';
   my $sound	= (defined $attr{sound} && $attr{sound} =~ /\d+/) ? $attr{sound} : 0;
   my $icon	= (defined $attr{icon} && $attr{icon} =~ /\d+/) ? $attr{icon} : 0;


   my $msg = '';
   if (defined $says) {
      # $says =~ s/\[(.+?)\]/'['.&imgf($1).']'/e;

      $msg = $self->{usid};
      $msg .= 'RSV=1&' if defined $attr{reserved} && $attr{reserved} == 1;
      $msg .= sprintf (
         'ACTION=%d&WHOTO=%s&SOM=s%02d&ICON=i%02d&SAYS=%s',

         $action,
         &ief ($whoto),
         $sound,
         $icon,
         &ief ($says)
      );
   }

   # envia mensagem
   my $resp = $self->post ('BANNER', $msg, $self->{header});

   # cai fora se tiver erro
   return 0 if $resp->is_error;

   # pega a lista de usu�rios na sala
   croak "send: servidor enviou resposta inv�lida (imposs�vel processar /BANNER)" unless $self->banner ($resp);

   # no browser real os par�mentos da URI s�o apagados devido ao uso do
   # m�todo POST... tentativa de imitar o mesmo ;)
   $self->{header}->header ('Referer', $self->{room}.'BANNER');

   # limpa buffer
   $self->scroll;

   return 1;
}


=item C<scroll (TIMEOUT)>

I<Obs>: Provavelmente a parte mais chatinha... Mas indispens�vel se voc�
quer comunica��o B<bidirecional>, isto �, o seu bot envia B<E> recebe dados.

O C<scroll> visa limpar buffers de entrada e enviar dados para sub-rotina
definida em C<Listen_Handler> (leia mais sobre argumentos de C<new>). Se o
I<listen_handler> for omitido ent�o os buffers ser�o limpos e a rotina
retornar� sucesso (I<1>). S� retorna I<0> se houver quebra inesperada
de conex�o.

O par�metro C<TIMEOUT> � o tempo que o C<scroll> deva esperar at�
retornar caso o buffer esteja vazio, em segundos. Resumindo,
C<scroll()> ou C<scroll(0)> retorna imediatamente (timeout 0).
C<scroll(10)> aguarda 10 segundos pelo dado. C<scroll(-1)> pausa o programa
at� que um dado apare�a no buffer.

O C<scroll> � chamado automaticamente pelos m�todos C<login>, C<logout>
e C<send>, portando, n�o h� como o seu C<Listen_Handler> perder algum dado.
Por�m, se voc� quiser mais controle, rode um C<scroll> com I<timeout>
razo�vel sempre que estiver esperando alguma resposta do servidor.

I<Obs>: Algu�m a� pensou L<fork>? Acredite em mim, B<n�o> vale a pena!
Eu I<comecei> a desenvolver bot bifurcado, com um I<child> para entrada
(rodando s� C<while ($bot-E<gt>scroll(-1)) { ... }>) e outro para sa�da
(rodando C<$bot-E<gt>send(...)>). A sincroniza��o dos dois virou um inferno e o
L<ActivePerl>, meu plataforma principal, n�o era muito amigo do L<fork>.
Se voc� pensar um pouco, ver� que o problema em quest�o � totalmente
linear, nunca duas a��es s�o feitas em paralelo. Agora, se voc� estiver
usando plataforma L<UNIX> e n�o quiser se preocupar onde p�r o C<scroll>,
coloque antes do C<login>:

  $SIG{ALRM} = sub { $bot->scroll; alarm 1 };
  alarm 1;

Se voc� est� vendo essa t�cnica pela 1-a vez, conforme-se com o que j� tem.

=cut

sub scroll {
   my ($self, $timeout) = @_;
   my $data;

   # scroll() retorna imediatamente enquanto scroll(-1) 'trava'...
   if (!defined $timeout || $timeout eq '') {
      $timeout = 0.0;
   } elsif ($timeout < 0) {
      $timeout = undef;
   }

   # preparar $sock para select()
   my ($rin, $rout);
   $rin = '';
   vec ($rin, fileno ($self->{sock}), 1) = 1;

   # limpa o buffer e ativa o 'listen handler'
   while (select ($rout=$rin, undef, undef, $timeout)) {
      return 0 unless sysread ($self->{sock}, $data, $bufsize);
      $self->handle (\$data);
   }

   return 1;
}


=item C<logout>

Efetua I<logout> da sala de bate-papo. Retorna I<0> se houver falha e
I<1> se tiver sucesso.

=cut

sub logout {
   my $self = shift;

   # sempre deve zerar o $self->{logged}
   return 0 unless $self->is_logged;
   $self->{logged} = 0;
   delete $self->{err};

   # envia "Exit"
   my $resp = $self->{ua}->simple_request (
      HTTP::Request->new (
         GET => $self->{room}.'?'.$self->{usid}.'EXIT=1&',
         $self->reref ($self->{room})
      )
   );

   # depois de sa�da o servidor redireciona cliente para a
   # lista de salas... �til para seres humanos, mas para o bot
   # � mais pr�tico e eficiente ignorar isso
   return 0 unless $resp->code == 302;

   # espera o socket fechar
   $self->scroll (-1);

   # for�a o socket a se fechar
   shutdown ($self->{sock}, 2);

   return 1;
}


# clona o header padr�o e altera o referer
sub reref {
   my $self = shift;

   my $nh = $self->{header}->clone;
   $nh->header ('Referer', shift);

   return $nh;
}

# POST s� serve para encher o saco :/
sub post {
   my ($self, $uri, $content, $header) = @_;

   my $req = HTTP::Request->new (POST => $self->{room}.$uri, $header);
   $req->header ('Content-Type', 'application/x-www-form-urlencoded');
   $req->header ('Content-Length', length $content);
   $req->content ($content);

   return $self->{ua}->simple_request ($req);
}

# ativa o 'listen handler' se esse existir
sub handle {
   my ($self, $dataref) = @_;

   if (defined $self->{listen_handler}) {
      &{$self->{listen_handler}} ($$dataref);
   }
}

# processa o conte�do do BANNER
sub banner {
   my ($self, $resp) = @_;

   # hoje estou com vontade de complicar coisas =D
   local $_ = $resp->content;
   my @data = split /\n/;

   # falha? aqui?!
   return 0 unless @data;

   # busca o in�cio
   while ($_ = shift @data) { last if /WHOTO/ }

   # pula 'TODOS'
   shift @data;

   # salva o resto
   $self->{users} = [];
   while ($_ = shift @data) {
      /"(.*?)"/;
      push @{$self->{users}}, $1;
   }

   return 1;
}


# filtra os caracteres n�o permitidos mas mensagens HTTP
sub ief {
   local $_ = shift;
   s/([^\ \*\-\.0-9\@_a-z])/&httphex ($1)/ieg;
   tr/ /+/;
   return $_;
}
# filtra os caracteres n�o permitidos nos tags [] do chat
sub imgf {
   local $_ = shift;
   s/([\ \"\&\'\<\>\?\[\]])/&httphex ($1)/ieg;
   return $_;
}
# rotina auxiliar
sub httphex {
   return sprintf '%%%x', ord shift;
}

1;
__END__


=back


=head1 BUGS

Testei rigorosamente esse m�dulo, afinal por que a id�ia � que um B<bot>
rode 24 horas por dia 7 dias por semana I<sem manuten��o>.

Por�m deixei de implementar coisas que me pareceram in�teis, tais como:

=over 4

=item *

incompatibilidade com C<Win32>

Calma, calma, voc� B<pode> executar o C<UOLbot> numa plataforma C<Win32>.
Por�m, vi que I<as vezes> h� falhas muito estranhas no C<LWP>. Uma hora
t� tudo OK, outra hora n�o funciona. Eu fiz testes com
C<ActivePerl 5.6.1 Build 630>, utilizando C<Windows 98> e C<Windows 98 SE>.
O primeiro n�o apresentou falhas, o segundo apresentou raramente. Mas
na minha opini�o pessoal, eu n�o confiaria em B<nada> feito pela I<Micro$oft>.
N�o confiaria nem nos softwares livres rodando em cima de produtos da
I<Micro$oft>. Portando, aqui vai uma dica que vai te livrar de muitos problemas:
B<use Linux>.

=item *

toler�ncia � falhas humanas

O m�nimo esperado do usu�rio � que passe par�metros corretos; n�o passe
string onde um n�mero � esperado e nem passe express�o regular onde era
para p�r refer�ncia ao c�digo...

Ainda assim, fiz o necess�rio para proteger o usu�rio contra dar um
C<logout> antes que seja feito um C<login>, portanto n�o se desanime.

=item *

"caretas" na frente do nick

Precisa ser assinante para usar tal artefato in�til. Duvido que um bot assine UOL!

=item *

utilizar um proxy HTTP

Grande maioria dos proxies p�blicos (os normalmente utilizados para anonimizar
acessos) n�o deixa conectar nas portas n�o-HTTP. B<Nenhuma> das salas de bate-papo
reside na porta HTTP (80). E ent�o?

=back

Outra coisa... Olha a data desse arquivo. B<Nessa> data C<UOLbot> estava
funcionando, pode ter certeza. Se n�o est� agora, � porque pessoal da UOL
alterou o sistema de webchat. Sinto muit�ssimo... O que voc� tem a fazer �
ou procurar vers�o mais atual de C<UOLbot> ou adaptar o c�digo desse aqui.
N�o deve ser dif�cil, fiz c�digo o mais claro e limpo que pude, at� comentei
tudo (���)!

O mesmo se aplica a qualquer valor ou tabela citados aqui. A UOL muda
constantemente o seu sistema de webchat, fazer o qu�...

=cut


=head1 REFER�NCIAS

=over 4

=item *

L<LWP> - Library for WWW access in Perl

=back

V�rios exemplos distribu�dos junto com o m�dulo:

=over 4

=item F<simples.pl>

a aplica��o mais simples; listar um sub-grupo, entrar na sala #15,
repetir mensagem 5 vezes, sair.

=item F<crawler.pl>

bot de propaganda; entra em todas as salas nos sub-grupos especificados
e deixa uma mensagem.

=item F<list.pl>

busca em sub-grupos especificados e retorna lista de URLs de salas
de bate-papo e seus respectivos t�tulos.

=back

=cut


=head1 VERS�O

1.1

=cut


=head1 HIST�RICO

=over 4

=item *

B<1.0> I<(25/Jan/2002)> - primeira vers�o funcional

=item *

B<1.1> I<(09/Fev/2002)> - utilizado o C<Carp::croak> para erros de usu�rio e
adicionado o m�todo C<brief>. Corre��es menores na documenta��o.

=back

=cut


=head1 COPYRIGHT

  Copyright (C) por Stanislaw Y. Pusep, Janeiro de 2002

=over 4

=item 1

A utiliza��o desse I<m�dulo>, assim como distribui��o do I<m�dulo> e/ou
suas I<vers�es> (altera��es feitas no I<m�dulo> por terceiros) somente
deve ser feita com autoriza��o explicita proveniente do I<autor>.

=item 2

Aqueles que tem c�pia autorizada do I<m�dulo> tem o direito de gerar
I<vers�es> (alterar o I<m�dulo> conforme for conveniente a eles). B<C<(*)>>

=item 3

Qualquer programa feito com utiliza��o desse I<m�dulo> pode ser usado
para quaisquer fins (inclusive lucrativos). B<C<(*)>>

=back

=over 4

=item B<C<(*)>>

Desde que n�o haja infra��o do C<item 1>.

=back

=cut


=head1 AUTOR

Nome: Stanislaw Y. Pusep

E-Mail: stanis@linuxmail.org

Homepage: http://sysdlabs.hypermart.net/

=cut
