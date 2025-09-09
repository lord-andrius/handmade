package handmade
import "x11"
main :: proc() {
    x11.conectar()
    defer x11.desconectar()
}
