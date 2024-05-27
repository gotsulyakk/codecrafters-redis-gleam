import gleam/io
import gleam/string
import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten
import redis/resp

pub fn main() {
  io.println("Logs from your program will appear here!")
  
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, loop)
    |> glisten.serve(6379)
  
  process.sleep_forever()
}

fn loop(
  msg: glisten.Message(a),
  state: state,
  conn: glisten.Connection(a),
) -> actor.Next(glisten.Message(a), state) {
  case msg {
    glisten.Packet(data) -> {
      handle_message(data, state, conn)
    }
    glisten.User(_) -> {
      actor.continue(state)
    }
  }
}

fn handle_message(
  msg: BitArray,
  state: state,
  conn: glisten.Connection(a),
) -> actor.Next(glisten.Message(a), state) {
  let assert Ok(resp.ParsedResp(data, <<>>)) = resp.parse(msg)
  let assert resp.Array([resp.String(command), ..args]) = data

  case string.lowercase(command), args {
    "ping", _ -> {
      let pong = resp.encode(resp.String("PONG"))
      let assert Ok(_) = glisten.send(conn, bytes_builder.from_bit_array(pong))
      actor.continue(state)
    }
    "echo", [value] -> {
      let pong = resp.encode(value)
      let assert Ok(_) = glisten.send(conn, bytes_builder.from_bit_array(pong))
      actor.continue(state)
    }
    _, _ -> {
      panic as {"Unknown command: "  <> command}
    }
  }
}
