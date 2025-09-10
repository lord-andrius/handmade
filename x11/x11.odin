package x11

import "core:sys/linux"
import "core:fmt"
import "core:strings"
import "core:os"

socket_x11: linux.Fd
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

Card16 :: u16
Card8  :: u8


Evento :: bit_field u32{
    codigo: u8 | 8,
    sequencia: u16 | 16,
    nada: u8 | 8,
}

conectar :: proc(allocator := context.allocator) {
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

    socket_x11 = descritor_socket


    // ta faltando coisa mas acho que vai de boa
    Requisicao_Inicializar_Conexao :: struct {
        endian: u8,
        _:   u8,
        versao_maior: Card16,
        versao_menor: Card16,
        tamanho_nome_protocolo_autorizacao: Card16,
        tamanho_dado_protocolo_autorizacao: Card16,
        _: Card16,
    }

    caminho_cookie_magico := os.get_env("$XAUTHORITY")
    defer delete(caminho_cookie_magico)
    cookie_magico, _ := os.read_entire_file(caminho_cookie_magico)
    defer delete(cookie_magico)

    req := Requisicao_Inicializar_Conexao {
        versao_maior = 11,
        versao_menor = 0,
        tamanho_nome_protocolo_autorizacao = cast(u16)len("MIT-MAGIC-COOKIE-1"),
        tamanho_dado_protocolo_autorizacao = cast(u16)len(cookie_magico)
    }

    when ODIN_ENDIAN == .Big {
        req.endian = 0x42
    } else {
        req.endian = 0x6C
    }

    bytes_req := strings.builder_make_none()
    defer strings.builder_destroy(&bytes_req)


    tmp := transmute([size_of(req)]u8)req
    strings.write_bytes(&bytes_req, tmp[:])

    strings.write_string(&bytes_req, "MIT-MAGIC-COOKIE-1")
    strings.write_string(&bytes_req, "MIT-MAGIC-COOKIE-1")
    strings.write_bytes(&bytes_req, cookie_magico)
    strings.write_bytes(&bytes_req, cookie_magico)

    bytes_escritos, erro_writer := linux.write(socket_x11, bytes_req.buf[:])
    if erro_writer != .NONE {
        panic("Não foi possível escrever bytes de inicialização")
    }


    Resposta_Inicializar_Conexao_Falha :: struct {
        codigo_retorno: [1]u8,
        tamanho_motivo: [1]u8,
        versao_maior: [2]u8,
        versao_menor: [2]u8,
        tamanho_dados_adicionais: [2]u8,
        dados_adicionais: []u8,

    }

    Resposta_Inicializar_Conexao :: struct #raw_union {
        falha: Resposta_Inicializar_Conexao_Falha,
    }

    resposta: Resposta_Inicializar_Conexao



    erro_leitura: linux.Errno
    bytes_lidos: int

    for bytes_lidos, erro_leitura = linux.read(socket_x11, resposta.falha.codigo_retorno[:]); erro_leitura == .EAGAIN; bytes_lidos, erro_leitura = linux.read(socket_x11, resposta.falha.codigo_retorno[:]) {
        fmt.println("tentando novamente...")
    }

    if erro_leitura != .NONE {
        panic("Não foi possível ler a resposta da tentativa de conexão");
    }


    bytes_lidos, erro_leitura = linux.read(socket_x11, resposta.falha.tamanho_motivo[:])


    bytes_lidos, erro_leitura = linux.read(socket_x11, resposta.falha.versao_maior[:])

    bytes_lidos, erro_leitura = linux.read(socket_x11, resposta.falha.versao_menor[:])
    bytes_lidos, erro_leitura = linux.read(socket_x11, resposta.falha.tamanho_dados_adicionais[:])
    if (cast(int)(transmute(u16)resposta.falha.tamanho_dados_adicionais)) * 4 > len(buffer) {
        resize(&buffer, (cast(int)(transmute(u16)resposta.falha.tamanho_dados_adicionais)) * 4)
    }
    bytes_lidos, erro_leitura = linux.read(socket_x11, buffer[:transmute(u16)resposta.falha.tamanho_dados_adicionais * 4])
    resposta.falha.dados_adicionais = buffer[:transmute(u16)resposta.falha.tamanho_dados_adicionais * 4]
    fmt.printfln("cookie_magico: %v", len(cookie_magico));
    fmt.printfln("%v", transmute(u8)resposta.falha.codigo_retorno);
    fmt.printfln("%v", transmute(u8)resposta.falha.tamanho_motivo);
    fmt.printfln("%v", transmute(u16)resposta.falha.versao_maior);
    fmt.printfln("%v", transmute(u16)resposta.falha.versao_menor);
    fmt.printfln("%v", transmute(u16)resposta.falha.tamanho_dados_adicionais);
    fmt.printfln("%s", cast(string)resposta.falha.dados_adicionais)


}

desconectar :: proc() {
    delete(buffer)
    linux.close(socket_x11)
}
