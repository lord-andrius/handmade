package x11

import "core:sys/linux"
import "core:fmt"
import "core:strings"

socket_x11: linux.Fd
builder: strings.Builder

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
    builder, erro_builder := strings.builder_make_len_cap(0, 1024)

    if erro_builder != .None {
        panic("Deu ruim ao alocar o construtor")
    }

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

    req := Requisicao_Inicializar_Conexao {
        versao_maior = 6,
        versao_menor = 8,
    }

    when ODIN_ENDIAN == .Big {
        req.endian = 0x42
    } else {
        req.endian = 0x6C
    }

    bytes_req := (transmute([size_of(req)]u8)req)

    linux.write(socket_x11, bytes_req[:])
}

desconectar :: proc() {
    strings.builder_destroy(&builder)
    linux.close(socket_x11)
}
