package UOL::bot;
use strict;


=head1 NOME

UOLbot - interface Perl para bate-papo do UOL


=head1 PLATAFORMAS SUPORTADOS

Teoricamente, B<todos> onde roda o L<perl>. Oficialmente, foi testado em:

=over 4

=item *

Linux
(perl 5.6.1)

=item *

Windows
(ActivePerl 5.6.1 Build 632)

=back


=head1 RESUMO

  #!/usr/bin/perl
  use UOLbot;

  my $bot = new UOLbot (Nick => 'uolbot');

  $bot->login ('batepapo4.uol.com.br:3999');
  $bot->send ("Hello World!");
  $bot->logout;

  exit;


=head1 DESCRI��O

O C<UOLbot> � um m�dulo Perl que implementa interface para webchat (batepapo) do
UOL (http://www.uol.com.br/). Basicamente, a id�ia � poder acessar as fun��es
comunicativas do chat B<de fora> do navegador. No caso, � partir de um programa
escrito em Perl. Um detalhe em destaque: a inten��o � implementar interface
B<completa>. Por exemplo, clientes tais como Jane, UOLME e Chat-N�ia 666
implementam s� um pouco � mais do que parte interativa. "O grosso" do trabalho
em tais clientes � feito pelas DLLs do C<Internet Explorer>. J� o C<UOLbot> �
independente de C<Internet Explorer> assim como � independente do C<Windows>
como todo.

Ent�o, conforme o pr�prio nome diz, voc� pode escrever bots de propaganda
(rob�s de propaganda que andam de sala em sala enchendo o saco das pessoas)
utilizando C<UOLbot>. Voc� tamb�m pode fazer algo �til como o primeiro cliente
de batepapo UOL que seja I<cross-platform>. Fiz de tudo para tais tarefas sejam
mais simplificadas poss�veis, apenas repare no exemplo acima ;)

Bom, qualquer coisa, esse projeto est� I<quase> sempre em expans�o. Comecei
aplicando uma engenharia reversa para saber como o
I<Microsoft Internet Explorer 6.0> interage com servidores do UOL
(sim, a l�gica de opera��o � do IE do come�o ao fim), e atualmente
tenho em m�os um m�dulo orientado � objetos (h�brido, para ser honesto) que
faz virtualmente tudo o que B<voc�> faria num webchat.

I<Obs>: antes que me pergunte, "eu estou lendo em portugu�s aqui,
ent�o por que C<send> e n�o I<enviar>, ou C<logout> ao inv�s de I<sair>?"
A raz�o � simples: o "resto" do L<perl> est� em ingl�s, certo?
Por mim, fica estranho ler e entender o que faz algo como

  next if $bot->enviar and not scalar $bot->usuarios;


=head1 INTRODU��O

Agora, o princ�pio ativo. Antes de tudo, voc� deve criar uma inst�ncia
do bot:

  my $bot = new UOLbot (Nick => 'uolbot');

O par�metro I<Nick> especifica o nickname do bot.
Voc� pode passar outros, que ser�o descritos posteriormente.
Voc� tamb�m pode B<n�o> passar nenhum, a� o seu bot ser� um
discreto "unnamed".
Voc� pode ter v�rias inst�ncias, s� n�o sei qual o sentido
disso. V�rios rob�s para v�rias salas em um s� programa?

Pronto, voc� criou o seu bot... E agora? Ele deve entrar numa sala, n�?

  $bot->login ('batepapo4.uol.com.br:3999');

(�tima sala para propaganda, eheheh)
A� voc� passa a URL da sala. � o �nico par�metro B<necess�rio>.
� claro que ter que saber essa URL � um p� no saco, voc� pode entrar na
sala s� sabendo o seu nome/n�mero. Mas isso � para depois.

Opa, mas espere um pouco. Voc� j� deve ter percebido aqueles c�digos de
verifica��o anti-spam, n� (antes n�o existia isso n�o)... O que fazer
agora? B<NADA>. Lhes apresento orgulhosamente o C<UOL::OCR>!!! � um
sub-componente composto por filtros digitais de imagem e um programa de
OCR (I<Optical Character Recognition>), atualmente o C<jocr>
(http://jocr.sourceforge.net). Tal componente trata dos c�digos de verifica��o
para voc�, e aparentemente muito bem ;)

Bom, e estando na sala, o que fazer? Falar!

  $bot->send ("Hello World!");

"Oi mundo" C<:P>
Sem coment�rios aqui.

Quando voc� "falou" tudo o que quis, tchau para todos!

  $bot->logout;  

Isso � o b�sico. Se n�o entendeu, pare por aqui.

=cut


use vars qw(@ISA $VERSION $OCR);
$VERSION = "2.0";

# define constantes
use constant ENTRY	=> 'http://batepapo.uol.com.br/bp/excgi/salas_new.shl';
use constant BUFSIZE	=> 32768;
use constant CRLF	=> "\012"; #"\015\012";
use constant MAGIC	=> 'D||receive@uol.com.br||3D46E369||7FFFFFFFFFFFFFFFFFFFFFFF||0||5B829405290999D1';


=head1 REQUISITOS

=over 4

=item *

LWP - The World-Wide Web library for Perl (libwww-perl)

=item *

Image::Magick I<(opcional)>

=back

=cut

# os nossos poucos requisitos...
require 5.004;
use Carp;
use HTTP::Cookies;
use IO::Socket;
use LWP::UserAgent;

# tenta carregar o m�dulo OCR
$OCR = 'yes' if eval 'require UOL::OCR';


# LWP 5.63 com HTTP/1.1 seriam talvez avan�ados demais...
@LWP::Protocol::http::EXTRA_SOCK_OPTS = (
   KeepAlive		=> 0,
   SendTE		=> 0,
   HTTPVersion		=> '1.0',
   PeerHTTPVersion	=> '1.0',
   MaxLineLength	=> 0,
   MaxHeaderLines	=> 0,
);


=head1 CONSTRUTOR

=over 4

=item C<new ([ARGS])>

Construtor para o bot. Retorna a refer�ncia para objeto C<UOL::bot>.
Argumentos C<ARGS> devem ser passados em forma:

  new (Chave1 => 'valor1',
       Chave2 => 2);

Note que alguns dos argumentos voc� poder� alterar posteriormente
com m�todos apropriados, e outros n�o.
Argumentos v�lidos (B<todos> opcionais):

=over 4

=item I<UA>

refer�ncia para objeto C<LWP::UserAgent> externo (� criada inst�ncia interna por default)

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

=item I<Avatar>

define "carinha" na frente do nick (n�mero inteiro, para ser descoberto na tentativa e erro :(

I<Obs>: a "carinha" s� vai aparecer se voc� for autenticado com C<auth>!

I<Obs2>: pra tirar a "carinha" j� definida, chame C<$bot-E<gt>avatar (-1)>.

=item I<Fast>

se setado em I<1> faz C<UOLbot> pular passos desnecess�rios de autentica��o/login na sala.
Pode fazer diferen�a em conex�es lentas, por�m pode gerar incompatibilidades, cuidado ao
usar!

=item I<Tries>

n�mero de tentativas para processar/reentrar c�digo de verifica��o. Tenha em mente que o
I<OCR> embutido pode errar para algum tipo de fonte/fundo/texto, por�m quem sabe se na
pr�xima ele acerta? Default � I<3>.

=item I<Auth_Magic>

preconfigura o I<cookie m�gico> que UOL utiliza para saber se o usu�rio � registrado.
Uma boa id�ia � n�o tocar nisso, se quiser experimentar, primeiro d� um C<auth> com
login/senha v�lidos, depois d� um

  print $bot->auth_magic, "\n";

depois copie o que for impresso e cole no

  my $bot = new UOLbot (Auth_Magic => ...);

=item I<ImgCode_Handler>

refer�ncia para a rotina que vai processar a imagem com c�digo de verifica��o.
A minha sugest�o � que voc� n�o toque nisso. O default � tentar carregar um
I<OCR> aqui, se falhar, ent�o a URL da imagem com c�digo de verifica��o � impressa
e voc� (usu�rio) tem que ler/digitar... Argh. De qualquer forma, a sintaxe �:

  ImgCode_Handler => \&my_imgcode_handler
  ...
  sub my_imgcode_handler {
     my ($req, $ua) = @_;
     # $req � ist�ncia HTTP::Request
     # $ua � inst�ncia LWP::UserAgent
     my $resp = $ua->request ($req);
     ...
     return $code;
  }

No caso:

I<$req> � inst�ncia C<HTTP::Request> da imagem-c�digo
I<$ua> � inst�ncia C<LWP::UserAgent> atualmente usada pelo C<UOLbot>
I<$code> � c�digo de 4 caracteres [a-z0-9]

=item I<Listen_Handler>

refer�ncia para a rotina que vai processar as
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
   if (not defined $self->{ua} or not $self->{ua}) {
      my $ua = new LWP::UserAgent;
      $ua->timeout (30);
      $ua->agent ("UOLbot/$VERSION " . $ua->agent);
      $self->{ua} = $ua;
   }
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

   # ativar 'imgcode handler' default
   unless ((defined $self->{imgcode_handler}) and
           (ref ($self->{imgcode_handler}) eq 'CODE')) {
      $self->{imgcode_handler} = $OCR ? \&OCR_imgcode_handler : \&default_imgcode_handler;
   }


   # configura��o b�sica
   $self->{user}	= &ief ($self->{nick});
   $self->{id}		= 0;

   $self->{users}	= [];
   $self->{logged}	= 0;
   $self->{auth}	= 0;
   $self->{auth_magic}	= '';

   $self->{cookies}	= new HTTP::Cookies;
   $self->{header}	= new HTTP::Headers;


   # configura��o avan�ada ;)
   if (not defined $self->{fast} or not $self->{fast}) {
      $self->{fast} = 0;
      $self->{header}->header ('Accept', 'text/html, image/png, image/jpeg, image/gif, image/x-xbitmap, */*');
      $self->{header}->header ('Accept-Encoding', 'deflate, gzip, x-gzip, identity, *;q=0');
   }

   # sujjjjjjjju!
   if (not defined $self->{tries}) {
      $self->{tries} = 3;
   } elsif ($self->{tries} < 1) {
      croak "n�mero de tentativas especificado deve ser maior que 1!";
   }

   # inicializa
   $self->{ua}->cookie_jar ($self->{cookies});

   if (defined $self->{avatar}) {
      $self->avatar ($self->{avatar});
   } else {
      $self->{avatar} = -1;
   }


   # feito!
   return $self;
}


=head1 M�TODOS

Os m�todos do C<UOLbot> s�o:

=over 4

=item C<ua>

=item C<nick>

=item C<color>

=item C<avatar>

=item C<fast>

=item C<tries>

=item C<auth_magic>

=item C<imgcode_handler>

=item C<listen_handler>

M�todos para ler/definir os par�metros definidos pelo C<new>.

I<Obs>: Voc� pode ler os valores a qualquer momento, mas s� poder�
definir quando a inst�ncia I<n�o estiver logada> com C<login>!

=cut

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
sub avatar {
   my $self = shift;
   my $r = $self->getset ('avatar',	@_);
   my $avatar = shift;
   $self->{cookies}->set_cookie (undef, 'AVATARCHAT', $avatar, '/', '.uol.com.br');
   return $r;
}
sub fast {
   shift->getset ('fast',		@_);
}
sub tries {
   my $self = shift;
   my $r = $self->getset ('tries',	@_);
   croak "tries: n�mero de tentativas inv�lido" if @_ and (not defined $self->{tries} or $self->{tries} < 1);
   return $r;
}
sub auth_magic {
   my $self = shift;
   my $r = $self->getset ('auth_magic',	@_);
   if (@_) {
      $self->{auth_magic} = shift;
      $self->{cookies}->set_cookie (undef, 'UOL_ID', $self->{auth_magic}, '/', '.uol.com.br');
      $self->{auth} = 1;
   }
   return $r;
}
sub imgcode_handler {
   shift->getset ('imgcode_handler',	@_);
}
sub listen_handler {
   shift->getset ('listen_handler',	@_);
}


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
   $list = ENTRY.'?ID='.$list unless $list =~ m{^http://};

   # verifica se a URL est� certa...
   my $test = "\Q@{[ENTRY]}\E";
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


=item C<search (STRING)>

Busca por usu�rio com C<STRING> contido no nickname em B<todas> as salas. Retorna I<()> caso
nenhum seja encontrado ou I<array> semelhante ao do C<list_subgrp>:

  my @room = $bot->search ('uolbot');
  foreach $room (@room) {
     print $room->{Nick}, "\n",
           $room->{URL}, "\n",
           $room->{Title}, "\n",
           $room->{Load}, "\n\n";
  }

Onde I<Nick> refere o nickname completo do usu�rio encontrado, I<URL> � o endere�o da sala onde
o usu�rio atualmente se encontra, I<Title> � o t�tulo da mesma (cortado, foi mal) e I<Load> �
quantidade de pessoas presentes na mesma sala.

=cut

sub search {
   my ($self, $str) = @_;

   # se n�o tem o qu� procurar, ent�o n�o tem
   return () unless defined $str;
   # URLs usadas
   my $search	= 'http://batepapo.uol.com.br/bp/excgi/procura.shl?';
   my $menu	= 'http://batepapo.bol.com.br/bpuol/menuport.htm';

   # faz pedido
   my $resp = $self->{ua}->request (HTTP::Request->new (GET => $search . $str, $self->reref ($menu)));
   # verifica pedido
   return () if $resp->is_error;
   my $content = $resp->content;

   # tem algum resultado?
   $content =~ /\btotal=(\d+)/ ||
      croak "search: servidor enviou resposta inv�lida (sem contador de resultados)";
   return () unless $1;

   # processa resultados
   my @list;
   for (my $i = 0; $i < $1; $i++)  {
      # disseca array em JavaScript
      $content =~ /\bn\[$i\]='(.+?)'/ ||
         croak "search: servidor enviou resposta inv�lida (sem resultados)";
      my @data = split /\t/, $1;
      croak "search: servidor enviou resposta inv�lida (resultados mal-formatados)" unless @data == 5;
      my ($nick, $serv, $port, $title, $load) = @data;

      # salva resultados
      push @list, {
	Nick	=> $nick,
	URL	=> "http://batepapo$serv.uol.com.br:$port/",
	Title	=> $title,
	Load	=> $load,
      };
   }

   # pronto!
   $self->{from} = $search . $str;
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
   $room = &room_url ($room) ||
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


=item C<auth ([USER, PASS])>

Autentica usu�rio registrado. Permite entrar nas salas com mais de 30 pessoas e usar
"carinha" na frente do nick. C<USER> � o nome de usu�rio em forma I<'nome@uol.com.br'>
e C<PASS> � a senha. Agora, o mais velho I<hack> de sistema de chat... Omita C<USER>
e C<PASS> e ter�s todos os privil�gios de um usu�rio registrado sem ser um ;)

Retorna I<0> se houver falha (username/senha inv�lidos) e I<1> se tiver sucesso.

I<Obs>: voc� deve autenticar B<antes> de efetuar C<login>!

I<Obs2>: C<auth> utiliza conex�o encriptada via SSL automaticamente quando o m�dulo
C<Crypt::SSLeay> � encontrado no sistema. Sem esse m�dulo, a conex�o efetuada �
insegura e a senha pode ser vista por pessoas mal-intencionadas! Duvido muito,
mas o que custa fazer direito?!

=cut

sub auth {
   my ($self, $user, $pass) = @_;

   # tolera erro bobo
   return 0 if $self->is_logged;

   # e quem disse que precisamos de login/senha v�lidos? ;)
   if ($self->{fast} || @_ < 3) {
      $self->auth_magic (MAGIC);
      return 1;
   }

   # decide se usa HTTP ou HTTPS
   my $url = $self->{ua}->is_protocol_supported ('https') ? 'https' : 'http';
   $url .= '://gasset.uol.com.br/pls/dadias/login_conteudo3';
   my $targ = 'http://batepapo.uol.com.br/bp/troca.htm';
   my $targf = &ief ($targ);

   # acerta username
   $user .= '@uol.com.br' unless $user =~ /\@/;

   # faz pedido
   my $req = $self->{ua}->request (HTTP::Request->new (GET => $url.'?URL='.$targ, $self->{header}));
   return 0 unless $req->is_success;

   # l� chave de sess�o
   $req->content =~ /"p_chave" value="(.*?)"/s ||
      croak "auth: servidor enviou resposta inv�lida (chave n�o encontrada)";
   my $key = $1;

   # l� identificador de sess�o
   $req->content =~ /"p_id_acesso" value="(.*?)"/s ||
      croak "auth: servidor enviou resposta inv�lida (identificador n�o encontrado)";
   my $id = $1;


   # autentica com valores de "id" e "chave" obtidos
   $req = HTTP::Request->new (POST => $url.'_3', $self->reref ($url));
   # monta conteudo
   my $content = "password=$pass&controle=Entrar&Target_URL=$targf&cod_produto=&p_chave=$key&username=$user&p_id_acesso=$id";
   $req->header ('Content-Type', 'application/x-www-form-urlencoded');
   $req->header ('Content-Length', length $content);
   $req->content ($content);

   # faz pedido
   #LWP::Debug::level ('+');
   my $ret = $self->{ua}->simple_request ($req);
   #LWP::Debug::level ('-');
   return 0 unless $ret->is_success;

   # temos o cookie autenticado?
   my $OK = 0;
   $self->{cookies}->scan (
      sub {
         if ($_[1] eq 'UOL_ID') {
	    $OK = 1;
	    $self->{auth_magic} = $_[2];
         }
      }
   );

   return $self->{auth} = $OK;
}


# chamado internamente, nem toque nisso!
sub join {
   my $self = shift;
   my ($room, $ref) = @_;

   # arruma a URL da sala
   $room = &room_url ($room) ||
      croak "join: URL inv�lida";

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
      $self->{ref} = ENTRY;
   }

   $self->{header}->header ('Referer', $self->{ref});

   # envia "Join Server"
   my $resp = $self->post ('', 'JS=1&USER='.$self->{user}.'&GZ=1&nickCor='.$self->{color}, $self->{header});

   # epa... o que aconteceu?
   return 0 if $resp->is_error;

   # outro referer agora...
   $self->{header}->header ('Referer', $room);

   # pega o !@#$%^& c�digo em imagem...
   $resp->content =~ m/="([a-z0-9\-\_]{32,33})"\s+var/is ||
      croak "join: servidor enviou resposta inv�lida (URL da imagem-c�digo n�o encontrada)";

### havia uma FALHA aqui, servidor deu a louca de retornar 33 caracteres :/
#   unless ($resp->content =~ m/="([a-z0-9\-\_]{32})"\s+var/is) {
#      #print STDERR "\n[[[", length $resp->content, "]]]\n\n";
#      open (LOG, ">".scalar time.".dat");
#      print LOG $resp->content;
#      close LOG;
#      return 0;
#   }

   # monta request para a im�gem com c�digo
   my $imgcode = HTTP::Request->new (GET => "http://imgcode.uol.com.br/$1.jpg", $self->{header});
   # para n�o faltar depois...
   $self->{encode} = $1;

   # retorna o request
   return $imgcode;
}


=item C<login (ROOM [, REF])>

Efetua I<login> na sala C<ROOM> de bate-papo. Chama internamente I<imgcode_handler>.
Par�metro C<ROOM> consiste de uma string de formato C<"http://batepapo4.uol.com.br:3999/">.
Se voc� for pregui�oso como eu, pode usar C<"batepapo4.uol.com.br:3999"> apenas. Par�metro
C<REF>, opcional, � o I<Referer>, o documento que continha o link para
C<ROOM>. Se voc� omitir o C<REF>, valor
I<'http://batepapo.uol.com.br/bp/excgi/salas_new.shl'>
ser� usado automaticamente. Se voc� estiver usado C<list_subgrp> ou C<search> antes
de C<login>, a URL de sub-grupo listado ser� usada como C<REF>.
Leia mais sobre C<list_subgrp>/C<search>.

Retorna I<0> se houver falha e I<1> se tiver sucesso. A "falha" mais prov�vel
� que a sala esteja cheia. Utilize o C<login_error> para obter mais detalhes
sobre a falha ocorrida.

=cut

sub login {
   my $self = shift;
   my ($room, $ref) = @_;

   # tolera erro bobo
   if ($self->is_logged) {
      $self->{err} = 0;
      return 0;
   }

   # checka o handler
   unless ((defined $self->{imgcode_handler}) and
           (ref ($self->{imgcode_handler}) eq 'CODE')) {
      croak "login: handler para c�digo de verifica��o inv�lido";
   }

   # quantas tentativas?
   if (not defined $self->{tries} or $self->{tries} < 1) {
      croak "login: n�mero de tentativas inv�lido (\$bot->tries)";
   }

   # passos da verifica��o
   my $vrfy = 0;
   my $i;
   for ($i = 0; $i < $self->{tries}; $i++) {
      # obt�m URL com im�gem do c�digo de verifica��o
      my $imgcode = $self->join ($room, $ref);
      return 0 unless $imgcode;

      # acertamos detalhes aqui...
      $ref = $room;

      # processa a imagem
      my $code = &{$self->{imgcode_handler}} ($imgcode, $self->ua);
      # pode ser �til futuramente
      $self->{decode} = $code;

      # droga, faz o servi�o de digitar certo pelo menos!
      if (not defined $code) {
         $self->{err} = 3;
         return 0;
      } elsif (not ($code =~ /^[a-z0-9]{4}$/)) {
         next;
      }

      # comeon baby!
      if ($self->verify ($code)) {
         $vrfy++;
         last;
      }
   }
   # conseguimos?
   unless ($vrfy) {
      $self->{err} = 3;
      return 0;
   }

   # finaliza a "Trilogia Do Nome Rid�culo"
   $self->{recode} = $i;

   # a grande macro...
   $self->load                  || return 0;
   $self->listen                || return 0;

   # se � que estamos aqui...
   $self->{logged}	= 1;
   $self->{err}		= 0;

   return 1;
}


=item C<is_logged>

Retorna I<n�o-0> se o bot estiver atualmente numa sala de bate-papo e I<0> caso contr�rio.

I<Detalhes T�cnicos>: Para ser exato, retorna o n�mero de tentativas de efetuar a verifica��o.

=cut

sub is_logged {
   my $self = shift;
   return (defined $self->{logged} && $self->{logged}) ? return $self->{recode} + 1 : 0;
}


=item C<encode>

Retorna a parte "encriptada" da URL da �ltima imagem processada contendo c�digo de verifica��o.

=item C<decode>

Retorna o c�digo lido.

=cut

sub encode {
   my $self = shift;
   return (defined $self->{encode}) ? $self->{encode} : '';
}

sub decode {
   my $self = shift;
   return (defined $self->{decode}) ? $self->{decode} : '';
}


=item C<is_auth>

Retorna I<1> se o bot estiver autenticado como usu�rio registrado do UOL.

=cut

sub is_auth {
   return shift->{auth};
}


=item C<login_error>

Retorna o c�digo do erro durante login:

  0     - sucesso
  1     - nickname j� foi utilizado
  2     - sala est� cheia
  3     - c�digo de verifica��o incorreto
  undef - erro desconhecido (ver valor de $!)

=cut

sub login_error {
   return shift->{err};
}

sub verify {
   my ($self, $code) = @_;
   my $resp;
   my $line = sprintf (
      'IMGCODEERROR=0&USER=%s&JS=1&nickCor=%d&avatar=%d&FASE=%%d&IMGCODEPSW=%s',
      $self->{user}, $self->{color}, $self->{avatar}, $code,
   );

   # 1-a fase
   $resp = $self->post ('', sprintf ($line, 1), $self->{header});
   if ($resp->is_error) {
      # que � que poderia ser?
      return 0;
   } elsif (not $resp->content =~ /name="FASE" value="2"/) {
      # ih, c�digo errado...
      $self->{err} = 3;
      return 0;
   }

   # 2-a fase
   $resp = $self->post ('', sprintf ('TESTE=1&'.$line, 2), $self->{header});
   # trata o eventual erro
   if ($resp->code != 200) {
      if ($resp->code == 302) {
         my $redir = $resp->header ('Location');
         if ($redir =~ /sainick/) {
            $self->{err} = 1;	# nick repetido
         } elsif ($redir =~ /esgotada|cheia/) {
            $self->{err} = 2;	# sala cheia
         }
      }
      return 0;
   }

   # salva dados da sess�o
   $resp->content =~ /&ID=(\d+)&/ ||
      croak "join: servidor enviou resposta inv�lida (sem ID adquirido)";
   $self->{id} = $1;
   $self->{usid} = 'USER='.$self->{user}.'&ID='.$self->{id}.'&';

   return 1;
}

sub load {
   my $self = shift;
   local $_;

   # �rvore de frame
   my %tree;
   if ($self->{fast}) {
      %tree = (
         n0_BANNER	=> $self->reref ($self->{room}),
      );
   } else {
      %tree = (
         n0_TOPO	=> $self->reref ($self->{room}),
         n1_BANNER	=> $self->reref ($self->{room}),
         n2_EXTRA	=> $self->reref ($self->{room}.'TOPO&'.$self->{usid}),
      );
   }

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
   $req->scan (sub { $hdr .= $_[0].': '.$_[1].CRLF });

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
	" HTTP/1.0" . CRLF .
	$hdr .
	CRLF
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
      sysread ($sock, $buf, BUFSIZE);
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
de bate-papo. Os dados s�o atualizados toda vez que voc� efetua C<login>,
C<send> ou C<brief>. Desculpe, n�o fui eu quem inventou isso... Retorna no m�nimo
o pr�prio nickname (a sala n�o est� vazia se I<voc�> est� l� C<;)> ou I<()>
no caso de falha. Detalhe: se voc� usou C<brief>, a sala B<pode> estar vazia
portando I<()> B<n�o> significa erro.

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

 $bot->send (Msg => 'mensagem 3', To => 'TODOS', Action => 15);

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

  $bot->send ('bots do UOL, un�-vos!', To => 'bots renegados');

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
      return 0 unless sysread ($self->{sock}, $data, BUFSIZE);
      $self->handle (\$data);
      return 1 unless defined $timeout;
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
   delete $self->{encode};
   delete $self->{decode};
   delete $self->{recode};

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

# organiza, n�...
sub room_url {
   my $room = shift;
   $room = 'http://' . $room unless $room =~ m%^http://%i;
   $room =~ m%^http://batepapo\d\.uol\.com\.br:\d+/?%i ||
      return 0;
   return $room;
}


# o jeito mais pr�tico de ler o c�digo de verifica��o ;)
sub default_imgcode_handler {
   my $req = shift;
   my $code;
   print "\n", '='x62, "\n",
         $req->uri->as_string, "\n";
   print "4-digit code: ";
   chomp ($code = <STDIN>);
   print "="x62, "\n\n";
   return $code;
}

# s� parece ser mais simples que o default :/
sub OCR_imgcode_handler {
   my ($req, $ua) = @_;
   my $resp = $ua->request ($req);
   return 0 if $resp->is_error;
   return &UOL::OCR::jpg2txt ($resp->content);
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

Por�m sempre h� coisas que n�o planejamos afinal, tais como:

=over 4

=item *

organiza��o estranha de m�dulos/m�todos

� resultado dificilmente evit�vel do progresso do C<UOLbot>. Come�a-se
de um jeito, a� muda-se de id�ia e termina de um jeito totalmente diferente.
Com certeza voc� deve estar se perguntando algo do tipo: "mas para qu� dar
um I<nick> � inst�ncia que vai apenas checkar a sala?" ou ent�o: "n�o seria
mais f�cil encapsular o endere�o da sala em C<HTTP::Request> por exemplo, 
afinal vira e mexe aparece URL de um jeito ou de outro!". A pergunta �:
a B<funcionalidade> � prejudicada? Caso contr�rio, para que perder tempo
arrumando coisa insignificante, afinal, n�o � um c�digo B<para massas> ;)

=item *

incompatibilidade com C<Win32>

Calma, calma, voc� B<pode> executar o C<UOLbot> num plataforma C<Win32>.
O grande inconveniente � eu n�o ter o I<port> do C<jocr> necess�rio e
biblioteca C<Image::Magick> para testar fun��es I<OCR>...
Ali�s, vi que I<as vezes> h� falhas muito estranhas no C<LWP>. Uma hora
t� tudo OK, outra hora n�o funciona. Eu fiz testes com
C<ActivePerl 5.6.1 Build 632>, utilizando C<Windows 98>, C<Windows 98 SE>
e C<Windows XP Professional>.
O primeiro e o terceiro n�o apresentaram falhas, o segundo apresentou raramente. Mas
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

utilizar um proxy HTTP

Grande maioria dos proxies p�blicos (os normalmente utilizados para anonimizar
acessos) n�o deixa conectar nas portas n�o-HTTP. B<Nenhuma> das salas de bate-papo
reside na porta HTTP (80). E ent�o?

=back

Outra coisa... Olha a data desse arquivo. B<Nessa> data C<UOLbot> estava
funcionando, pode ter certeza. Se n�o est� agora, � porque pessoal do UOL
alterou o sistema de webchat. Sinto muit�ssimo... O que voc� tem a fazer �
ou procurar vers�o mais atual de C<UOLbot> ou adaptar o c�digo desse aqui.
N�o deve ser dif�cil, fiz c�digo o mais claro e limpo que pude, at� comentei
tudo (���)!

O mesmo se aplica a qualquer valor ou tabela citados aqui. O UOL muda
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

2.0

=cut


=head1 HIST�RICO

=over 4

=item *

B<1.0> I<(25/Jan/2002)> - primeira vers�o funcional.

=item *

B<1.1> I<(09/Fev/2002)> - utilizado o C<Carp::croak> para erros de usu�rio e
adicionado o m�todo C<brief>. Corre��es menores na documenta��o.

=item *

B<1.2> I<(03/Mar/2002)> - adicionados m�todos C<auth> e C<avatar> (para tirar
proveito de ser usu�rio registrado do UOL ;).

=item *

B<1.2a> I<(04/Mar/2002)> - atualiza��es na documenta��o.

=item *

B<1.3> I<(27/Mar/2002)> - reestruturado o processo de login devido �s altera��es
feitas nos servidores do UOL. Agora voc� deve dar um C<join> na sala escolhida,
obter o c�digo de verifica��o e completar opera��o com C<login>. Maldi��o!

=item *

B<1.4> I<(22/Jul/2002)> - C�digo levemente reestruturado para compatibilidade com
m�dulo I<OCR> (para reconhecimento do c�digo de verifica��o) que estou fazendo.
Algumas corre��es menores tamb�m.

=item *

B<2.0> I<(04/Ago/2002)> - C�digo fortemente reestruturado. Muitas mudan�as.
M�dulo C<UOL::OCR> inclu�do.

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

E-Mail: stanis I<AT> linuxmail I<DOT> org

Homepage: http://sysdlabs.hypermart.net/

=cut
