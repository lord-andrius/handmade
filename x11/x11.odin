package x11

import "core:bytes"
import "core:sys/linux"
import "core:fmt"
import "core:strings"
import "core:os"

Socket_X11: linux.Fd
buffer: [dynamic]u8

Cabecalho_Requisicao :: bit_field u32 {
    operacao: u8  | 8,
    tamanho:  u16 | 16, // cada unidade representa 4 bytes no conteúdo
    dado:     u8  | 8 // O primeiro dado
}

Requisicao :: struct {
    using cabecalho: Cabecalho_Requisicao,
    dados: []u8,
}

Resposta :: struct {
    tamanho: u32, // cada unidade representa 4 bytes no conteúdo
    dados: []u8,
    //Every reply also contains the least significant 16 bits of the sequence number of the corresponding request.
    sequencia: u16,
}

X11_Erro :: struct {
    codigo_erro:       u8,
    operacao_maior:    u8,
    operacao_menor:    u8,
    sequencia:         u16,
    outras_informacoes: []u8,
}


Card32 :: struct #raw_union {
    valor: u32,
    bytes: [4]u8,
}

Card16 :: struct #raw_union {
    valor: u16,
    bytes: [2]u8,
}

Card8  :: struct #raw_union {
    valor: u8,
    bytes: [1]u8,
}

Possibilidades_Codigo_Retorno_Conexao :: enum(u8) {
    Falha = 0,
    Necessita_Autenticacao = 2,
    Sucesso = 1,
}

Codigo_Retorno_Conexao :: struct #raw_union {
    valor: Possibilidades_Codigo_Retorno_Conexao,
    bytes: [1]u8,
}

Bool :: struct #raw_union {
    valor: b8,
    bytes: [1]u8
}

Evento :: bit_field u32{
    codigo: u8 | 8,
    sequencia: u16 | 16,
    nada: u8 | 8,
}

Resposta_Inicializar_Conexao_Falha :: struct {
    codigo_retorno: Codigo_Retorno_Conexao,
    tamanho_motivo: Card8,
    versao_maior: Card16,
    versao_menor: Card16,
    tamanho_dados_adicionais: Card16, // em unidade de 4 bytes
    dados_adicionais: []u8,
}

// não é necessário desalocar em caso de erro
// essa função não pode ser chamada por ela mesma
// ela precisa ser chamada pela função ler_resposta_inicializar_conexao
ler_resposta_inicializar_conexao_falha :: proc(resposta: ^Resposta_Inicializar_Conexao_Falha, allocator := context.allocator) {
    //NOTE: dá uma limpada nesse código fera :)
    erro_leitura: linux.Errno
    bytes_lidos: int

    bytes_lidos, erro_leitura = linux.read(Socket_X11, resposta.tamanho_motivo.bytes[:])
    bytes_lidos, erro_leitura = linux.read(Socket_X11, resposta.versao_maior.bytes[:])
    bytes_lidos, erro_leitura = linux.read(Socket_X11, resposta.versao_menor.bytes[:])
    bytes_lidos, erro_leitura = linux.read(Socket_X11, resposta.tamanho_dados_adicionais.bytes[:])
    if (cast(int)resposta.tamanho_dados_adicionais.valor) * 4 > len(buffer) {
        resize(&buffer, (cast(int)resposta.tamanho_dados_adicionais.valor) * 4)
    }
    bytes_lidos, erro_leitura = linux.read(
        Socket_X11,
        buffer[:resposta.tamanho_dados_adicionais.valor * 4]
    )
    resposta.dados_adicionais = buffer[:resposta.tamanho_dados_adicionais.valor * 4]
}

Conexao: Resposta_Inicializar_Conexao_Sucesso

Resposta_Inicializar_Conexao_Sucesso :: struct {
    codigo_retorno: Codigo_Retorno_Conexao,
    _nada1: Card8,
    versao_maior: Card16,
    versao_menor: Card16,
    tamanho_dados_adicionais: Card16, // em unidade de 4 bytes
    numero_lancamento: Card32,
    id_base_recurso: Card32, //usado para fazer os ids de outras coisas Window, Pixmap
    id_mascara_recurso: Card32,
    tamanho_buffer_movimento: Card32,
    tamanho_provedor: Card16,
    tamanho_maximo_requisicao: Card16,
    numero_de_telas_nas_raizes: Card8,
    numero_formatos_pixmap: Card8,
    // todas as imagens são recebidas e transmitidas nessa ordem
    ordem_byte_imagem: Card8, // 0 Little endian | 1 Big endian
    ordem_byte_bitmap: Card8, // 0 Little endian | 1 Big endian
    formato_unidade_bitmap_scanline: Card8, // quantos bytes é uma unidade do scanline
        formato_preenchimento_bitmap_scanline: Card8, // quantos bytes de preenchimento entre scanlines
            keycode_minimo: Card8,
            keycode_maximo: Card8,
            _nada2: Card32,
            provedor: []u8,
            formatos: []Formato,
                telas: []Tela,
}

// As slices contidas na resposta devem ser deletadas pelo usuário dessa função
ler_resposta_inicializar_conexao_sucesso :: proc(resposta:^Resposta_Inicializar_Conexao_Sucesso, allocator := context.allocator) {

    // descartando _nada1
    linux.read(Socket_X11, resposta._nada1.bytes[:])

    // eu tirei a checagem de erro porque essa checagem já acontesce em ler_resposta_inicializar_conexao
    // NOTE: se der ruim colocar o código que lida com os erros

    // apartir daqui serão lidos os dados adicionais
    bytes_lidos_de_dados_adicionais := 0

    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.versao_maior.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.versao_menor.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.tamanho_dados_adicionais.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.numero_lancamento.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.id_base_recurso.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.id_mascara_recurso.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.tamanho_buffer_movimento.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.tamanho_provedor.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.tamanho_maximo_requisicao.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.numero_de_telas_nas_raizes.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.numero_formatos_pixmap.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.ordem_byte_imagem.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.ordem_byte_bitmap.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.formato_unidade_bitmap_scanline.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.formato_preenchimento_bitmap_scanline.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.keycode_minimo.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta.keycode_maximo.bytes[:]) or_else 0
    bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, resposta._nada2.bytes[:]) or_else 0


    bytes_lidos_ler_string := 0
    resposta.provedor, bytes_lidos_ler_string = ler_string(cast(int)resposta.tamanho_provedor.valor)
    bytes_lidos_de_dados_adicionais += bytes_lidos_ler_string
    // tem um preenchimento entre provedor e formatos
    //NOTE: PERFORMANCE isso é muito ruim alocar seria melhor?
    lixo: [1]u8
    for i in 0..<resposta.tamanho_provedor.valor {
        bytes_lidos_de_dados_adicionais += linux.read(Socket_X11, lixo[:]) or_else 0
    }

    bytes_lidos_ler_formatos := 0
    resposta.formatos, bytes_lidos_ler_formatos = ler_lista_formatos(cast(int)resposta.numero_formatos_pixmap.valor)
    bytes_lidos_de_dados_adicionais += bytes_lidos_ler_formatos

    // essa fórmula eu peguei apartir da doc
    bytes_restantes := (cast(int)resposta.tamanho_dados_adicionais.valor * 4) - bytes_lidos_de_dados_adicionais


    resposta.telas, _ = ler_lista_telas(bytes_restantes)

}

ler_string :: proc(tamanho: int) -> ([]u8, int) {
    str := make([]u8, tamanho)
    bytes_lidos, _ := linux.read(Socket_X11, str)
    return str, bytes_lidos
}

Formato :: struct {
    profundidade: Card8,
    bits_por_pixel: Card8,
    preenchimento_scanline: Card8,
    _nada1: Card8,
    _nada2: Card32,
}

ler_formato :: proc(formato: ^Formato) -> int{
    bytes_lidos := 0
    bytes_lidos += linux.read(Socket_X11, formato.profundidade.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, formato.bits_por_pixel.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, formato.preenchimento_scanline.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, formato._nada1.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, formato._nada2.bytes[:]) or_else 0
    return bytes_lidos
}

ler_lista_formatos :: proc(tamanho: int) -> ([]Formato, int) {
    //NOTE: PERFORMANCE deve ser possível ler tudo de uma vez
    bytes_lidos := 0
    if tamanho == 0 {
        return nil, 0
    }
    formatos := make([]Formato, tamanho)
        for &formato in formatos {
            bytes_lidos += ler_formato(&formato)
        }
        return formatos, bytes_lidos
}

Tela :: struct {
    janela_raiz: Window,
    mapa_de_cores: Colormap,
    pixel_branco: Card32,
    pixel_preto: Card32,
    mascara_de_entrada_atual: Card32,
    largura_em_pixels: Card16,
    altura_em_pixels: Card16,
    largura_em_milimetros: Card16,
    altura_em_milimetros: Card16,
    minimo_mapas_instalados: Card16,
    maximo_mapas_instalados: Card16,
    id_visual: VisualId,
    // NOTE: talvez transformar guardando num enum??????
    // está relacionado se o x11 guarda o conteúdo da janela se ela for ocultada.
    // 0 - Nunca guarda.
    // 1 - Quando mapeada. NOTA: pesquisar mais
    // 2 - Sempre.
    guardando: Card8,
    salva_por_traz: Bool,
    profundidade_raiz: Card8,
    tamanho_profundidades_permitidass: Card8,
    profundidades_permitidas: []Profundidade,

}

ler_tela :: proc(tela: ^Tela) -> int {
    bytes_lidos := 0
    bytes_lidos += linux.read(Socket_X11, tela.janela_raiz.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.mapa_de_cores.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.pixel_branco.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.pixel_preto.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.mascara_de_entrada_atual.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.largura_em_pixels.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.altura_em_pixels.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.largura_em_milimetros.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.altura_em_milimetros.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.minimo_mapas_instalados.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.maximo_mapas_instalados.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.id_visual.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.guardando.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.salva_por_traz.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.profundidade_raiz.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tela.tamanho_profundidades_permitidass.bytes[:]) or_else 0

    bytes_lidos_ler_lista_profundidade := 0
    tela.profundidades_permitidas, bytes_lidos_ler_lista_profundidade = ler_lista_profundidade(cast(int)tela.tamanho_profundidades_permitidass.valor)

    bytes_lidos += bytes_lidos_ler_lista_profundidade
    return bytes_lidos
}

ler_lista_telas :: proc(bytes_para_ler: int) -> ([]Tela, int) {
    bytes_lidos := 0
    telas := make([dynamic]Tela)
    for bytes_lidos < bytes_para_ler {
        tela: Tela
        bytes_lidos += ler_tela(&tela)
        append(&telas, tela)
    }
    return telas[:], bytes_lidos
}

Profundidade :: struct {
    profundidade: Card8,
    _nada1: Card8,
    numero_tipo_visual: Card16,
    _nada2: Card32,
    tipos_visuais: []TipoVisual,
}

ler_profundidade :: proc(profundidade: ^Profundidade) -> int {
    bytes_lidos := 0
    bytes_lidos += linux.read(Socket_X11, profundidade.profundidade.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, profundidade._nada1.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, profundidade.numero_tipo_visual.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, profundidade._nada2.bytes[:]) or_else 0

    bytes_lidos_ler_lista_tipo_visual := 0
    profundidade.tipos_visuais,bytes_lidos_ler_lista_tipo_visual = ler_lista_tipo_visual(cast(int)profundidade.numero_tipo_visual.valor)
    bytes_lidos += bytes_lidos_ler_lista_tipo_visual
    return bytes_lidos
}

ler_lista_profundidade :: proc(tamanho: int) -> ([]Profundidade, int) {
    bytes_lidos := 0
    profundidades := make([]Profundidade, tamanho)
    for &profundidade in profundidades {
        bytes_lidos += ler_profundidade(&profundidade)
    }
    return profundidades, bytes_lidos
}

Possibilidades_Classe_Tipo_Visual :: enum(u8) {
    StaticGray,
    GrayScale,
    StaticColor,
    PseudoColor,
    TrueColor,
    DirectColor,
}

Classe_Tipo_Visual :: struct #raw_union{
    valor: Possibilidades_Classe_Tipo_Visual,
    bytes: [1]u8,
}

TipoVisual :: struct {
    id_visual: VisualId,
    // basicamento é o tipo
    // 0 StaticGray
    // 1 GrayScale
    // 2 StaticColor
    // 3 PseudoColor
    // 4 TrueColor
    // 5 DirectColor
    classe: Classe_Tipo_Visual,
    bits_por_valor_rgb: Card8,
    entrada_mapa_de_cores: Card16,
    mascara_vermelho: Card32,
    mascara_verde: Card32,
    mascara_azul: Card32,
    _nada1: Card32,
}

ler_tipo_visual :: proc(tipo_visual: ^TipoVisual) -> int {
    bytes_lidos := 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.id_visual.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.classe.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.bits_por_valor_rgb.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.entrada_mapa_de_cores.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.mascara_vermelho.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.mascara_verde.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual.mascara_azul.bytes[:]) or_else 0
    bytes_lidos += linux.read(Socket_X11, tipo_visual._nada1.bytes[:]) or_else 0

    return bytes_lidos
}

ler_lista_tipo_visual :: proc(tamanho: int) -> ([]TipoVisual, int){
    //NOTE: PERFORMANCE deve ser possível ler tudo de uma vez
    bytes_lidos := 0
    tipos := make([]TipoVisual, tamanho)
    for &tipo in tipos {
        bytes_lidos += ler_tipo_visual(&tipo)
    }
    return tipos, bytes_lidos
}

Window    :: Card32
Pixmap    :: Card32
Cursor    :: Card32
Font      :: Card32
GContext  :: Card32
Colormap  :: Card32
Drawable  :: Card32
VisualId  :: Card32


Resposta_Inicializar_Conexao :: struct #raw_union {
    falha: Resposta_Inicializar_Conexao_Falha,
    sucesso: Resposta_Inicializar_Conexao_Sucesso,
}

ler_resposta_inicializar_conexao :: proc(resposta: ^Resposta_Inicializar_Conexao) -> (ok: bool) {
    erro_leitura: linux.Errno
    bytes_lidos: int

    // aqui eu to usando resposta.falha.codigo_retorno mas eu poderia usar resposta.sucesso.codigo_retorno
    // tambem é um union
    for bytes_lidos, erro_leitura = linux.read(Socket_X11, resposta.falha.codigo_retorno.bytes[:]); erro_leitura == .EAGAIN; bytes_lidos, erro_leitura = linux.read(Socket_X11, resposta.falha.codigo_retorno.bytes[:]) {

    }

    switch resposta.falha.codigo_retorno.valor {
        case Possibilidades_Codigo_Retorno_Conexao.Necessita_Autenticacao:
            panic("Precisa implementar melhor a autenticação")
        case Possibilidades_Codigo_Retorno_Conexao.Falha:
            ler_resposta_inicializar_conexao_falha(cast(^Resposta_Inicializar_Conexao_Falha)resposta)
            return false
        case Possibilidades_Codigo_Retorno_Conexao.Sucesso:
            ler_resposta_inicializar_conexao_sucesso(cast(^Resposta_Inicializar_Conexao_Sucesso)resposta)
            return true
    }
    panic("Não deveria chegar aqui")

}

//esse é um contador usado para gerar ids
_contador_id: u16 = 0

gerar_id :: proc(conexao := Conexao) -> Card32 {
    if _contador_id == max(u16) {
        panic("Não tem como fazer id's novos")
    }

    novo_id: Card32 = Card32{
        valor = cast(u32)_contador_id,
    }
    novo_id.valor &= conexao.id_mascara_recurso.valor
    novo_id.valor |= conexao.id_base_recurso.valor
    return novo_id
}


conectar :: proc(allocator := context.allocator) -> (ok:bool) {
    buffer := make([dynamic]u8, 4096)

    descritor_socket, erro_socket := linux.socket(
        .UNIX,
        .STREAM,
        {.NONBLOCK},
        .HOPOPT
    )

    if erro_socket != .NONE {
        panic("Deu ruim ao abrir o socket")
    }

    path: [108]u8
    copy(path[:], "/tmp/.X11-unix/X0")

    endereco := linux.Sock_Addr_Un {
        sun_family = .UNIX,
        sun_path = transmute([108]u8)path
    }

    erro_connect := linux.connect(
        descritor_socket,
        &endereco
    )

    if erro_connect != .NONE {
        fmt.println(erro_connect)
        panic("Deu ruim ao conectar no socket")
    }

    Socket_X11 = descritor_socket



    Requisicao_Inicializar_Conexao :: struct {
        endian: u8,
        _nada1:   u8,
        versao_maior: Card16,
        versao_menor: Card16,
        tamanho_nome_protocolo_autorizacao: Card16,
        tamanho_dado_protocolo_autorizacao: Card16,
        _nada2: Card16,
    }

    caminho_cookie_magico := os.get_env("XAUTHORITY")
    defer delete(caminho_cookie_magico)
    cookie_magico, _ := os.read_entire_file(caminho_cookie_magico)
    defer delete(cookie_magico)

    req := Requisicao_Inicializar_Conexao {
        versao_maior = Card16{valor = 11},
        versao_menor = Card16{valor = 0},
        tamanho_nome_protocolo_autorizacao = Card16{valor = cast(u16)len("MIT-MAGIC-COOKIE-1")},
        tamanho_dado_protocolo_autorizacao = Card16{valor = cast(u16)len(cookie_magico)},
    }

    when ODIN_ENDIAN == .Big {
        req.endian = 0x42
    } else {
        req.endian = 0x6C
    }

    bytes_req := strings.builder_make_none()
    defer strings.builder_destroy(&bytes_req)

    strings.write_byte(&bytes_req, req.endian)
    strings.write_byte(&bytes_req, req._nada1)
    strings.write_bytes(&bytes_req, req.versao_maior.bytes[:])
    strings.write_bytes(&bytes_req, req.versao_menor.bytes[:])
    strings.write_bytes(&bytes_req, req.tamanho_nome_protocolo_autorizacao.bytes[:])
    strings.write_bytes(&bytes_req, req.tamanho_dado_protocolo_autorizacao.bytes[:])
    strings.write_bytes(&bytes_req, req._nada2.bytes[:])

    strings.write_string(&bytes_req, "MIT-MAGIC-COOKIE-1")
    strings.write_string(&bytes_req, "MIT-MAGIC-COOKIE-1")
    strings.write_bytes(&bytes_req, cookie_magico)
    strings.write_bytes(&bytes_req, cookie_magico)

    bytes_escritos, erro_writer := linux.write(Socket_X11, bytes_req.buf[:])
    if erro_writer != .NONE {
        panic("Não foi possível escrever bytes de inicialização")
    }

    resposta: Resposta_Inicializar_Conexao

    if ler_resposta_inicializar_conexao(&resposta) {
        // esse é o caso em que a conexão deu certo
        Conexao = resposta.sucesso
        return true
    }

    return false
}

desconectar :: proc() {
    delete(buffer)
    linux.close(Socket_X11)
}


criar_janela :: proc() {

}
