package handmade
import "x11"
import "core:time"

main :: proc() {
    x11.conectar()
    requisicao_janela := x11.Requisicao_Janela{
        codigo_operacao = {
            valor = x11.Possibilidades_Codigo_Operacao.Criar_Janela
        },
        profundidade = {
            valor = 8,
        },
        tamanho_requisicao = {
            valor = (size_of(x11.Requisicao_Janela) - size_of([]u8)) * 8,
        },
        id_janela = cast(x11.Window)x11.gerar_id(),
        id_janela_pai = {
            valor = 0,
        },
        posicao_x ={
            valor = 0,
        },
        posicao_y = {
            valor = 0,
        },
        largura = {
            valor = 600,
        },
        altura = {
            valor = 400,
        },
        classe = {
            valor = x11.Possibilidades_Classe_Janela.Entrada_Saida,
        },
    }
    lista_de_valores: [45]u8
    requisicao_janela.lista_de_valores = lista_de_valores[:]
    x11.criar_janela(&requisicao_janela)
    x11.mapear_janela(requisicao_janela.id_janela)
    time.sleep(time.Second)
    defer x11.desconectar()
}
