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


=head1 DESCRIÇÃO

O C<UOLbot> é um módulo Perl que implementa interface para webchat (batepapo) do
UOL (http://www.uol.com.br/). Basicamente, a idéia é poder acessar as funções
comunicativas do chat B<de fora> do navegador. No caso, à partir de um programa
escrito em Perl. Um detalhe em destaque: a intenção é implementar interface
B<completa>. Por exemplo, clientes tais como Jane, UOLME e Chat-Nóia 666
implementam só um pouco à mais do que parte interativa. "O grosso" do trabalho
em tais clientes é feito pelas DLLs do C<Internet Explorer>. Já o C<UOLbot> é
independente de C<Internet Explorer> assim como é independente do C<Windows>
como todo.

Então, conforme o próprio nome diz, você pode escrever bots de propaganda
(robôs de propaganda que andam de sala em sala enchendo o saco das pessoas)
utilizando C<UOLbot>. Você também pode fazer algo útil como o primeiro cliente
de batepapo UOL que seja I<cross-platform>. Fiz de tudo para tais tarefas sejam
mais simplificadas possíveis, apenas repare no exemplo acima ;)

Bom, qualquer coisa, esse projeto está I<quase> sempre em expansão. Comecei
aplicando uma engenharia reversa para saber como o
I<Microsoft Internet Explorer 6.0> interage com servidores do UOL
(sim, a lógica de operação é do IE do começo ao fim), e atualmente
tenho em mãos um módulo orientado à objetos (híbrido, para ser honesto) que
faz virtualmente tudo o que B<você> faria num webchat.

I<Obs>: antes que me pergunte, "eu estou lendo em português aqui,
então por que C<send> e não I<enviar>, ou C<logout> ao invés de I<sair>?"
A razão é simples: o "resto" do L<perl> está em inglês, certo?
Por mim, fica estranho ler e entender o que faz algo como

  next if $bot->enviar and not scalar $bot->usuarios;


=head1 INTRODUÇÃO

Agora, o princípio ativo. Antes de tudo, você deve criar uma instância
do bot:

  my $bot = new UOLbot (Nick => 'uolbot');

O parâmetro I<Nick> especifica o nickname do bot.
Você pode passar outros, que serão descritos posteriormente.
Você também pode B<não> passar nenhum, aí o seu bot será um
discreto "unnamed".
Você pode ter várias instâncias, só não sei qual o sentido
disso. Vários robôs para várias salas em um só programa?

Pronto, você criou o seu bot... E agora? Ele deve entrar numa sala, né?

  $bot->login ('batepapo4.uol.com.br:3999');

(ótima sala para propaganda, eheheh)
Aí você passa a URL da sala. É o único parâmetro B<necessário>.
É claro que ter que saber essa URL é um pé no saco, você pode entrar na
sala só sabendo o seu nome/número. Mas isso é para depois.

Opa, mas espere um pouco. Você já deve ter percebido aqueles códigos de
verificação anti-spam, né (antes não existia isso não)... O que fazer
agora? B<NADA>. Lhes apresento orgulhosamente o C<UOL::OCR>!!! É um
sub-componente composto por filtros digitais de imagem e um programa de
OCR (I<Optical Character Recognition>), atualmente o C<jocr>
(http://jocr.sourceforge.net). Tal componente trata dos códigos de verificação
para você, e aparentemente muito bem ;)

Bom, e estando na sala, o que fazer? Falar!

  $bot->send ("Hello World!");

"Oi mundo" C<:P>
Sem comentários aqui.

Quando você "falou" tudo o que quis, tchau para todos!

  $bot->logout;  

Isso é o básico. Se não entendeu, pare por aqui.

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

# tenta carregar o módulo OCR
$OCR = 'yes' if eval 'require UOL::OCR';


# LWP 5.63 com HTTP/1.1 seriam talvez avançados demais...
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

Construtor para o bot. Retorna a referência para objeto C<UOL::bot>.
Argumentos C<ARGS> devem ser passados em forma:

  new (Chave1 => 'valor1',
       Chave2 => 2);

Note que alguns dos argumentos você poderá alterar posteriormente
com métodos apropriados, e outros não.
Argumentos válidos (B<todos> opcionais):

=over 4

=item I<UA>

referência para objeto C<LWP::UserAgent> externo (é criada instância interna por default)

=item I<Nick>

o nickname (valor default é I<"unnamed">)

=item I<Color>

a cor do nickname (valor default é I<0>)

I<Obs>: valores possíveis são:

  0 - Preto
  1 - Vermelho
  2 - Verde
  3 - Azul
  4 - Laranja
  5 - Cinza
  6 - Roxo

=item I<Avatar>

define "carinha" na frente do nick (número inteiro, para ser descoberto na tentativa e erro :(

I<Obs>: a "carinha" só vai aparecer se você for autenticado com C<auth>!

I<Obs2>: pra tirar a "carinha" já definida, chame C<$bot-E<gt>avatar (-1)>.

=item I<Fast>

se setado em I<1> faz C<UOLbot> pular passos desnecessários de autenticação/login na sala.
Pode fazer diferença em conexões lentas, porém pode gerar incompatibilidades, cuidado ao
usar!

=item I<Tries>

número de tentativas para processar/reentrar código de verificação. Tenha em mente que o
I<OCR> embutido pode errar para algum tipo de fonte/fundo/texto, porém quem sabe se na
próxima ele acerta? Default é I<3>.

=item I<Auth_Magic>

preconfigura o I<cookie mágico> que UOL utiliza para saber se o usuário é registrado.
Uma boa idéia é não tocar nisso, se quiser experimentar, primeiro dê um C<auth> com
login/senha válidos, depois dê um

  print $bot->auth_magic, "\n";

depois copie o que for impresso e cole no

  my $bot = new UOLbot (Auth_Magic => ...);

=item I<ImgCode_Handler>

referência para a rotina que vai processar a imagem com código de verificação.
A minha sugestão é que você não toque nisso. O default é tentar carregar um
I<OCR> aqui, se falhar, então a URL da imagem com código de verificação é impressa
e você (usuário) tem que ler/digitar... Argh. De qualquer forma, a sintaxe é:

  ImgCode_Handler => \&my_imgcode_handler
  ...
  sub my_imgcode_handler {
     my ($req, $ua) = @_;
     # $req é istância HTTP::Request
     # $ua é instância LWP::UserAgent
     my $resp = $ua->request ($req);
     ...
     return $code;
  }

No caso:

I<$req> é instância C<HTTP::Request> da imagem-código
I<$ua> é instância C<LWP::UserAgent> atualmente usada pelo C<UOLbot>
I<$code> é código de 4 caracteres [a-z0-9]

=item I<Listen_Handler>

referência para a rotina que vai processar as
informações recebidas da sala (indefinido por default).
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
Nesse caso, variável I<$data> recebe pacotes com código HTML recebidos.

I<Obs>: lembre que nem sempre há uma mensagem em um pacote. O servidor
(ou buffer do sistema operacional) pode juntar vários pacotes num só.

=back

=back

=cut

sub new {
   my ($class, %conf) = @_;
   my %init;

   # lê parâmetros
   foreach my $key (keys %conf) {
      $init {lc $key} = $conf {$key};
   }

   # cria instância
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

   # desativar 'listen handler' se este não for fornecido
   unless ((defined $self->{listen_handler}) and
           (ref ($self->{listen_handler}) eq 'CODE')) {
      $self->{listen_handler} = undef;
   }

   # ativar 'imgcode handler' default
   unless ((defined $self->{imgcode_handler}) and
           (ref ($self->{imgcode_handler}) eq 'CODE')) {
      $self->{imgcode_handler} = $OCR ? \&OCR_imgcode_handler : \&default_imgcode_handler;
   }


   # configuração básica
   $self->{user}	= &ief ($self->{nick});
   $self->{id}		= 0;

   $self->{users}	= [];
   $self->{logged}	= 0;
   $self->{auth}	= 0;
   $self->{auth_magic}	= '';

   $self->{cookies}	= new HTTP::Cookies;
   $self->{header}	= new HTTP::Headers;


   # configuração avançada ;)
   if (not defined $self->{fast} or not $self->{fast}) {
      $self->{fast} = 0;
      $self->{header}->header ('Accept', 'text/html, image/png, image/jpeg, image/gif, image/x-xbitmap, */*');
      $self->{header}->header ('Accept-Encoding', 'deflate, gzip, x-gzip, identity, *;q=0');
   }

   # sujjjjjjjju!
   if (not defined $self->{tries}) {
      $self->{tries} = 3;
   } elsif ($self->{tries} < 1) {
      croak "número de tentativas especificado deve ser maior que 1!";
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


=head1 MÉTODOS

Os métodos do C<UOLbot> são:

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

Métodos para ler/definir os parâmetros definidos pelo C<new>.

I<Obs>: Você pode ler os valores a qualquer momento, mas só poderá
definir quando a instância I<não estiver logada> com C<login>!

=cut

# métodos para acesso aos parâmetros internos...
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
   croak "tries: número de tentativas inválido" if @_ and (not defined $self->{tries} or $self->{tries} < 1);
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
é o documento onde nomes das salas, suas URLs e suas lotações são fornecidos.
C<list_subgrp> é simplesmente uma interface para esse documento.
Parâmetro C<SUBGRP> é uma string com URL de formato
I<'http://batepapo.uol.com.br/bp/excgi/salas_new.cgi?ID=idim_he.conf'>
ou então simplesmente I<'idim_he.conf'>. Os dois são equivalentes.
Quando você usa C<list_subgrp> antes de C<login>, C<SUBGRP> é salvo e
utilizado como C<REF> de C<login> automaticamente. O método retorna
um array de hashes se tiver sucesso e I<()> se houver falha. O array
retornado pode ser expandido com:

  my @room = $bot->list_subgrp ('idim_he.conf');
  foreach $room (@room) {
     print $room->{URL}, "\n",
           $room->{Title}, "\n",
           $room->{Load}, "\n\n";
  }

onde C<URL> é a URL da sala de bate-papo, C<Title> é o título dela e
C<Load> é o número de pessoas na sala
(0-40, -1 significa I<"sala lotada">).

=cut

sub list_subgrp {
   my ($self, $list) = @_;

   # completa o nome se for necessário
   $list = ENTRY.'?ID='.$list unless $list =~ m{^http://};

   # verifica se a URL está certa...
   my $test = "\Q@{[ENTRY]}\E";
   $list =~ /^$test\?ID=.*\.conf$/i ||
      croak "list_subgrp: URL inválida";

   # carrega a lista em HTML
   my $req = $self->{ua}->request (HTTP::Request->new (GET => $list, $self->{header}));
   $req->is_success || return ();

   # colhe o nome de servidor
   my ($serv) = $req->content =~ /\bmaq = (\d+)\b/;
   # colhe o caracter usado como separador de lista
   $req->content =~ /\bs="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inválida (sem separador)";
   my $sep = "\Q$1\E"; # sim, isso vai para regexp futuramente...

   # colhe os nomes das salas
   $req->content =~ /\bd1="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inválida (sem nomes das salas)";
   my @room = split /$sep/, $1;

   # colhe as respectivas portas...
   $req->content =~ /\bd2="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inválida (sem portas das salas)";
   my @port = split /$sep/, $1;

   # ...e quantas pessoas tem nelas
   $req->content =~ /\bd3="(.+?)"/ ||
      croak "list_subgrp: servidor enviou resposta inválida (sem dados de lotação)";
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

Busca por usuário com C<STRING> contido no nickname em B<todas> as salas. Retorna I<()> caso
nenhum seja encontrado ou I<array> semelhante ao do C<list_subgrp>:

  my @room = $bot->search ('uolbot');
  foreach $room (@room) {
     print $room->{Nick}, "\n",
           $room->{URL}, "\n",
           $room->{Title}, "\n",
           $room->{Load}, "\n\n";
  }

Onde I<Nick> refere o nickname completo do usuário encontrado, I<URL> é o endereço da sala onde
o usuário atualmente se encontra, I<Title> é o título da mesma (cortado, foi mal) e I<Load> é
quantidade de pessoas presentes na mesma sala.

=cut

sub search {
   my ($self, $str) = @_;

   # se não tem o quê procurar, então não tem
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
      croak "search: servidor enviou resposta inválida (sem contador de resultados)";
   return () unless $1;

   # processa resultados
   my @list;
   for (my $i = 0; $i < $1; $i++)  {
      # disseca array em JavaScript
      $content =~ /\bn\[$i\]='(.+?)'/ ||
         croak "search: servidor enviou resposta inválida (sem resultados)";
      my @data = split /\t/, $1;
      croak "search: servidor enviou resposta inválida (resultados mal-formatados)" unless @data == 5;
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

guarda a lista com nomes de usuários para depois ser vista com C<users>

=item 2

passa o fragmento da conversa para rotina definida em C<Listen_Handler>

=item 3

retorna I<1>

=back

=cut

sub brief {
   my ($self, $room) = @_;

   # verificação básica
   $room = &room_url ($room) ||
      croak "brief: URL inválida";

   # completa a URL
   $room =~ s%/?$%/PUBLIC_BRIEF%;

   # faz pedido
   my $req = $self->{ua}->request (HTTP::Request->new (GET => $room, $self->{header}));
   return 0 unless $req->is_success;

   # pega a lista de usuários em HTML
   $req->content =~ / {8}(.*?)\s{8}/s ||
      croak "brief: servidor enviou resposta inválida (sem nomes de usuários)";

   # processa a lista
   my @users = split /<br>\s*/, $1;
   # salva a lista
   $self->{users} = [];
   foreach my $user (@users) {
      push @{$self->{users}}, $user if $user;
   }

   # e agora as mensagens do próprio chat
   $req->content =~ m{rolando</h2></b>\s+(.*?)<p><blockquote>}s ||
      croak "brief: servidor enviou resposta inválida (sem mensagens do chat)";
   # processa
   $self->handle (\$1);

   return 1;
}


=item C<auth ([USER, PASS])>

Autentica usuário registrado. Permite entrar nas salas com mais de 30 pessoas e usar
"carinha" na frente do nick. C<USER> é o nome de usuário em forma I<'nome@uol.com.br'>
e C<PASS> é a senha. Agora, o mais velho I<hack> de sistema de chat... Omita C<USER>
e C<PASS> e terás todos os privilégios de um usuário registrado sem ser um ;)

Retorna I<0> se houver falha (username/senha inválidos) e I<1> se tiver sucesso.

I<Obs>: você deve autenticar B<antes> de efetuar C<login>!

I<Obs2>: C<auth> utiliza conexão encriptada via SSL automaticamente quando o módulo
C<Crypt::SSLeay> é encontrado no sistema. Sem esse módulo, a conexão efetuada é
insegura e a senha pode ser vista por pessoas mal-intencionadas! Duvido muito,
mas o que custa fazer direito?!

=cut

sub auth {
   my ($self, $user, $pass) = @_;

   # tolera erro bobo
   return 0 if $self->is_logged;

   # e quem disse que precisamos de login/senha válidos? ;)
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

   # lê chave de sessão
   $req->content =~ /"p_chave" value="(.*?)"/s ||
      croak "auth: servidor enviou resposta inválida (chave não encontrada)";
   my $key = $1;

   # lê identificador de sessão
   $req->content =~ /"p_id_acesso" value="(.*?)"/s ||
      croak "auth: servidor enviou resposta inválida (identificador não encontrado)";
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
      croak "join: URL inválida";

   # processar os parâmetros
   croak "erro interno em join(): falta URL da sala" if not defined $room or not $room;
   $room .= '/' unless $room =~ m{/$};

   # "lembra" o Referer se for possível
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

   # pega o !@#$%^& código em imagem...
   $resp->content =~ m/="([a-z0-9\-\_]{32,33})"\s+var/is ||
      croak "join: servidor enviou resposta inválida (URL da imagem-código não encontrada)";

### havia uma FALHA aqui, servidor deu a louca de retornar 33 caracteres :/
#   unless ($resp->content =~ m/="([a-z0-9\-\_]{32})"\s+var/is) {
#      #print STDERR "\n[[[", length $resp->content, "]]]\n\n";
#      open (LOG, ">".scalar time.".dat");
#      print LOG $resp->content;
#      close LOG;
#      return 0;
#   }

   # monta request para a imágem com código
   my $imgcode = HTTP::Request->new (GET => "http://imgcode.uol.com.br/$1.jpg", $self->{header});
   # para não faltar depois...
   $self->{encode} = $1;

   # retorna o request
   return $imgcode;
}


=item C<login (ROOM [, REF])>

Efetua I<login> na sala C<ROOM> de bate-papo. Chama internamente I<imgcode_handler>.
Parâmetro C<ROOM> consiste de uma string de formato C<"http://batepapo4.uol.com.br:3999/">.
Se você for preguiçoso como eu, pode usar C<"batepapo4.uol.com.br:3999"> apenas. Parâmetro
C<REF>, opcional, é o I<Referer>, o documento que continha o link para
C<ROOM>. Se você omitir o C<REF>, valor
I<'http://batepapo.uol.com.br/bp/excgi/salas_new.shl'>
será usado automaticamente. Se você estiver usado C<list_subgrp> ou C<search> antes
de C<login>, a URL de sub-grupo listado será usada como C<REF>.
Leia mais sobre C<list_subgrp>/C<search>.

Retorna I<0> se houver falha e I<1> se tiver sucesso. A "falha" mais provável
é que a sala esteja cheia. Utilize o C<login_error> para obter mais detalhes
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
      croak "login: handler para código de verificação inválido";
   }

   # quantas tentativas?
   if (not defined $self->{tries} or $self->{tries} < 1) {
      croak "login: número de tentativas inválido (\$bot->tries)";
   }

   # passos da verificação
   my $vrfy = 0;
   my $i;
   for ($i = 0; $i < $self->{tries}; $i++) {
      # obtêm URL com imágem do código de verificação
      my $imgcode = $self->join ($room, $ref);
      return 0 unless $imgcode;

      # acertamos detalhes aqui...
      $ref = $room;

      # processa a imagem
      my $code = &{$self->{imgcode_handler}} ($imgcode, $self->ua);
      # pode ser útil futuramente
      $self->{decode} = $code;

      # droga, faz o serviço de digitar certo pelo menos!
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

   # finaliza a "Trilogia Do Nome Ridículo"
   $self->{recode} = $i;

   # a grande macro...
   $self->load                  || return 0;
   $self->listen                || return 0;

   # se é que estamos aqui...
   $self->{logged}	= 1;
   $self->{err}		= 0;

   return 1;
}


=item C<is_logged>

Retorna I<não-0> se o bot estiver atualmente numa sala de bate-papo e I<0> caso contrário.

I<Detalhes Técnicos>: Para ser exato, retorna o número de tentativas de efetuar a verificação.

=cut

sub is_logged {
   my $self = shift;
   return (defined $self->{logged} && $self->{logged}) ? return $self->{recode} + 1 : 0;
}


=item C<encode>

Retorna a parte "encriptada" da URL da última imagem processada contendo código de verificação.

=item C<decode>

Retorna o código lido.

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

Retorna I<1> se o bot estiver autenticado como usuário registrado do UOL.

=cut

sub is_auth {
   return shift->{auth};
}


=item C<login_error>

Retorna o código do erro durante login:

  0     - sucesso
  1     - nickname já foi utilizado
  2     - sala está cheia
  3     - código de verificação incorreto
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
      # que é que poderia ser?
      return 0;
   } elsif (not $resp->content =~ /name="FASE" value="2"/) {
      # ih, código errado...
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

   # salva dados da sessão
   $resp->content =~ /&ID=(\d+)&/ ||
      croak "join: servidor enviou resposta inválida (sem ID adquirido)";
   $self->{id} = $1;
   $self->{usid} = 'USER='.$self->{user}.'&ID='.$self->{id}.'&';

   return 1;
}

sub load {
   my $self = shift;
   local $_;

   # árvore de frame
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

      # pega a lista de usuários na sala
      $self->banner ($resp) if /BANNER/;
   }

   # agora as chamadas HTTP são "de dentro" do frame
   $self->{header}->header ('Referer', $self->{room}.'BANNER&'.$self->{usid});

   return 1;
}

sub listen {
   my $self = shift;


   # Temos que fazer conexão "manualmente" senão um request() travaria
   # o programa até dar timeout.
   # Claro que *existe* o tal do Net::HTTP, ele até vêm com LWP mais
   # novo, mas o que queremos é COMPATIBILIDADE, certo?

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

   # constrói mensagem HTTP
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

   # precauções...
   binmode $sock;
   $sock->autoflush (1);

   # envia mensagem HTTP
   if (defined syswrite ($sock, $msg, length $msg)) {
      # receber 1-o pacote
      my $buf;
      sysread ($sock, $buf, BUFSIZE);
      # arranca os headers
      $buf =~ s%^.*?text/html\s+%%s; # alguém tem idéia melhor?
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

Retorna array de nicknames de usuários atualmente presentes na sala
de bate-papo. Os dados são atualizados toda vez que você efetua C<login>,
C<send> ou C<brief>. Desculpe, não fui eu quem inventou isso... Retorna no mínimo
o próprio nickname (a sala não está vazia se I<você> está lá C<;)> ou I<()>
no caso de falha. Detalhe: se você usou C<brief>, a sala B<pode> estar vazia
portando I<()> B<não> significa erro.

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

sintaxe mais obscura, não envia B<nada>, apenas atualiza a lista que
pode ser obtida com método C<users>. De novo, não fui eu quem inventou!

=back

Agora, sobre atributos C<ATTR>. São todos opcionais
(forma C<Chave =E<gt> 'Valor'>), aqui está a lista
com uma breve explicação:

=over 4

=item I<Msg>

a mensagem em si, string (só pode ser usado com I<sintaxe 3>, ignorado na I<sintaxe 2>!)

=item I<Action>

ação, valor inteiro. Ações possíveis:

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
  13 - dá um fora em
  14 - briga com
  15 - grita com
  16 - xinga

  18 - IGNORAR mensagens de
  19 - só receber mensagens de
  20 - não IGNORAR mais

=item I<To>

o nickname do receptor da ação I<Action>, string. Valor default é I<'TODOS'>.

I<Obs1>: B<não necessariamente> é alguém que esteja na sala. Isto é, você
pode fazer:

  $bot->send ('bots do UOL, uní-vos!', To => 'bots renegados');

B<desde que> I<não> seja uma mensagem reservada (C<Reserved =E<gt> 1>)!

I<Obs2>: independentemente do valor do I<To>, todos os usuários da sala
irão ler a mensagem. Para mensagens privadas, use I<Reserved>.

=item I<Reserved>

pode ser I<1> ou I<0>. Quando I<1>, a mensagem é enviada reservadamente
para nickname I<To>. Valor default é I<0>.

=item I<Sound>

som a ser enviado, inteiro. Sons possíveis:

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
  25 - Tôlôca
  26 - Tosse
  07 - Como é?
  08 - Não entendi

=item I<Icon>

ícone a ser enviado, inteiro. Ícones possíveis:

  0  - nenhum (default)
  38 - Assustado
  27 - Bocejo
  23 - Careta
  30 - Dentuço
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

I<Obs>: B<aparentemente> o servidor não aceita mensagens E<gt> 200 bytes.

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

   # lê atributos da mensagem
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

   # pega a lista de usuários na sala
   croak "send: servidor enviou resposta inválida (impossível processar /BANNER)" unless $self->banner ($resp);

   # no browser real os parâmentos da URI são apagados devido ao uso do
   # método POST... tentativa de imitar o mesmo ;)
   $self->{header}->header ('Referer', $self->{room}.'BANNER');

   # limpa buffer
   $self->scroll;

   return 1;
}


=item C<scroll (TIMEOUT)>

I<Obs>: Provavelmente a parte mais chatinha... Mas indispensável se você
quer comunicação B<bidirecional>, isto é, o seu bot envia B<E> recebe dados.

O C<scroll> visa limpar buffers de entrada e enviar dados para sub-rotina
definida em C<Listen_Handler> (leia mais sobre argumentos de C<new>). Se o
I<listen_handler> for omitido então os buffers serão limpos e a rotina
retornará sucesso (I<1>). Só retorna I<0> se houver quebra inesperada
de conexão.

O parâmetro C<TIMEOUT> é o tempo que o C<scroll> deva esperar até
retornar caso o buffer esteja vazio, em segundos. Resumindo,
C<scroll()> ou C<scroll(0)> retorna imediatamente (timeout 0).
C<scroll(10)> aguarda 10 segundos pelo dado. C<scroll(-1)> pausa o programa
até que um dado apareça no buffer.

O C<scroll> é chamado automaticamente pelos métodos C<login>, C<logout>
e C<send>, portando, não há como o seu C<Listen_Handler> perder algum dado.
Porém, se você quiser mais controle, rode um C<scroll> com I<timeout>
razoável sempre que estiver esperando alguma resposta do servidor.

I<Obs>: Alguém aí pensou L<fork>? Acredite em mim, B<não> vale a pena!
Eu I<comecei> a desenvolver bot bifurcado, com um I<child> para entrada
(rodando só C<while ($bot-E<gt>scroll(-1)) { ... }>) e outro para saída
(rodando C<$bot-E<gt>send(...)>). A sincronização dos dois virou um inferno e o
L<ActivePerl>, meu plataforma principal, não era muito amigo do L<fork>.
Se você pensar um pouco, verá que o problema em questão é totalmente
linear, nunca duas ações são feitas em paralelo. Agora, se você estiver
usando plataforma L<UNIX> e não quiser se preocupar onde pôr o C<scroll>,
coloque antes do C<login>:

  $SIG{ALRM} = sub { $bot->scroll; alarm 1 };
  alarm 1;

Se você está vendo essa técnica pela 1-a vez, conforme-se com o que já tem.

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

   # depois de saída o servidor redireciona cliente para a
   # lista de salas... útil para seres humanos, mas para o bot
   # é mais prático e eficiente ignorar isso
   return 0 unless $resp->code == 302;

   # espera o socket fechar
   $self->scroll (-1);

   # força o socket a se fechar
   shutdown ($self->{sock}, 2);

   return 1;
}


# clona o header padrão e altera o referer
sub reref {
   my $self = shift;

   my $nh = $self->{header}->clone;
   $nh->header ('Referer', shift);

   return $nh;
}

# POST só serve para encher o saco :/
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

# processa o conteúdo do BANNER
sub banner {
   my ($self, $resp) = @_;

   # hoje estou com vontade de complicar coisas =D
   local $_ = $resp->content;
   my @data = split /\n/;

   # falha? aqui?!
   return 0 unless @data;

   # busca o início
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

# organiza, né...
sub room_url {
   my $room = shift;
   $room = 'http://' . $room unless $room =~ m%^http://%i;
   $room =~ m%^http://batepapo\d\.uol\.com\.br:\d+/?%i ||
      return 0;
   return $room;
}


# o jeito mais prático de ler o código de verificação ;)
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

# só parece ser mais simples que o default :/
sub OCR_imgcode_handler {
   my ($req, $ua) = @_;
   my $resp = $ua->request ($req);
   return 0 if $resp->is_error;
   return &UOL::OCR::jpg2txt ($resp->content);
}


# filtra os caracteres não permitidos mas mensagens HTTP
sub ief {
   local $_ = shift;
   s/([^\ \*\-\.0-9\@_a-z])/&httphex ($1)/ieg;
   tr/ /+/;
   return $_;
}

# filtra os caracteres não permitidos nos tags [] do chat
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

Testei rigorosamente esse módulo, afinal por que a idéia é que um B<bot>
rode 24 horas por dia 7 dias por semana I<sem manutenção>.

Porém sempre há coisas que não planejamos afinal, tais como:

=over 4

=item *

organização estranha de módulos/métodos

É resultado dificilmente evitável do progresso do C<UOLbot>. Começa-se
de um jeito, aí muda-se de idéia e termina de um jeito totalmente diferente.
Com certeza você deve estar se perguntando algo do tipo: "mas para quê dar
um I<nick> à instância que vai apenas checkar a sala?" ou então: "não seria
mais fácil encapsular o endereço da sala em C<HTTP::Request> por exemplo, 
afinal vira e mexe aparece URL de um jeito ou de outro!". A pergunta é:
a B<funcionalidade> é prejudicada? Caso contrário, para que perder tempo
arrumando coisa insignificante, afinal, não é um código B<para massas> ;)

=item *

incompatibilidade com C<Win32>

Calma, calma, você B<pode> executar o C<UOLbot> num plataforma C<Win32>.
O grande inconveniente é eu não ter o I<port> do C<jocr> necessário e
biblioteca C<Image::Magick> para testar funções I<OCR>...
Aliás, vi que I<as vezes> há falhas muito estranhas no C<LWP>. Uma hora
tá tudo OK, outra hora não funciona. Eu fiz testes com
C<ActivePerl 5.6.1 Build 632>, utilizando C<Windows 98>, C<Windows 98 SE>
e C<Windows XP Professional>.
O primeiro e o terceiro não apresentaram falhas, o segundo apresentou raramente. Mas
na minha opinião pessoal, eu não confiaria em B<nada> feito pela I<Micro$oft>.
Não confiaria nem nos softwares livres rodando em cima de produtos da
I<Micro$oft>. Portando, aqui vai uma dica que vai te livrar de muitos problemas:
B<use Linux>.

=item *

tolerância à falhas humanas

O mínimo esperado do usuário é que passe parâmetros corretos; não passe
string onde um número é esperado e nem passe expressão regular onde era
para pôr referência ao código...

Ainda assim, fiz o necessário para proteger o usuário contra dar um
C<logout> antes que seja feito um C<login>, portanto não se desanime.

=item *

utilizar um proxy HTTP

Grande maioria dos proxies públicos (os normalmente utilizados para anonimizar
acessos) não deixa conectar nas portas não-HTTP. B<Nenhuma> das salas de bate-papo
reside na porta HTTP (80). E então?

=back

Outra coisa... Olha a data desse arquivo. B<Nessa> data C<UOLbot> estava
funcionando, pode ter certeza. Se não está agora, é porque pessoal do UOL
alterou o sistema de webchat. Sinto muitíssimo... O que você tem a fazer é
ou procurar versão mais atual de C<UOLbot> ou adaptar o código desse aqui.
Não deve ser difícil, fiz código o mais claro e limpo que pude, até comentei
tudo (ôôô)!

O mesmo se aplica a qualquer valor ou tabela citados aqui. O UOL muda
constantemente o seu sistema de webchat, fazer o quê...

=cut


=head1 REFERÊNCIAS

=over 4

=item *

L<LWP> - Library for WWW access in Perl

=back

Vários exemplos distribuídos junto com o módulo:

=over 4

=item F<simples.pl>

a aplicação mais simples; listar um sub-grupo, entrar na sala #15,
repetir mensagem 5 vezes, sair.

=item F<crawler.pl>

bot de propaganda; entra em todas as salas nos sub-grupos especificados
e deixa uma mensagem.

=item F<list.pl>

busca em sub-grupos especificados e retorna lista de URLs de salas
de bate-papo e seus respectivos títulos.

=back

=cut


=head1 VERSÃO

2.0

=cut


=head1 HISTÓRICO

=over 4

=item *

B<1.0> I<(25/Jan/2002)> - primeira versão funcional.

=item *

B<1.1> I<(09/Fev/2002)> - utilizado o C<Carp::croak> para erros de usuário e
adicionado o método C<brief>. Correções menores na documentação.

=item *

B<1.2> I<(03/Mar/2002)> - adicionados métodos C<auth> e C<avatar> (para tirar
proveito de ser usuário registrado do UOL ;).

=item *

B<1.2a> I<(04/Mar/2002)> - atualizações na documentação.

=item *

B<1.3> I<(27/Mar/2002)> - reestruturado o processo de login devido às alterações
feitas nos servidores do UOL. Agora você deve dar um C<join> na sala escolhida,
obter o código de verificação e completar operação com C<login>. Maldição!

=item *

B<1.4> I<(22/Jul/2002)> - Código levemente reestruturado para compatibilidade com
módulo I<OCR> (para reconhecimento do código de verificação) que estou fazendo.
Algumas correções menores também.

=item *

B<2.0> I<(04/Ago/2002)> - Código fortemente reestruturado. Muitas mudanças.
Módulo C<UOL::OCR> incluído.

=back

=cut


=head1 COPYRIGHT

  Copyright (C) por Stanislaw Y. Pusep, Janeiro de 2002

=over 4

=item 1

A utilização desse I<módulo>, assim como distribuição do I<módulo> e/ou
suas I<versões> (alterações feitas no I<módulo> por terceiros) somente
deve ser feita com autorização explicita proveniente do I<autor>.

=item 2

Aqueles que tem cópia autorizada do I<módulo> tem o direito de gerar
I<versões> (alterar o I<módulo> conforme for conveniente a eles). B<C<(*)>>

=item 3

Qualquer programa feito com utilização desse I<módulo> pode ser usado
para quaisquer fins (inclusive lucrativos). B<C<(*)>>

=back

=over 4

=item B<C<(*)>>

Desde que não haja infração do C<item 1>.

=back

=cut


=head1 AUTOR

Nome: Stanislaw Y. Pusep

E-Mail: stanis I<AT> linuxmail I<DOT> org

Homepage: http://sysdlabs.hypermart.net/

=cut
