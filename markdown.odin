package main

import "core:fmt"
import "core:os"
import "core:mem"

Token_Type :: enum {
    Text,
    Heading_Start,
    Heading_End,
    Bold_Start,
    Bold_End,
    Italic_Start,
    Italic_End,
}

Loc :: struct {
    line: int,
    col: int,
}

Token :: struct {
    body: string,
    type: Token_Type,
    //loc: Loc,
}

Lexer_State :: struct {
    input: string,

    tok: Token,
    curr: int,

    heading: bool,
    italic: bool,
    bold: bool,
}

init_lexer :: proc(input: string) -> Lexer_State {
    l := Lexer_State{input = input}
    return l
}

consume_text :: proc(l: ^Lexer_State) -> (Token, bool) {
    text_start := l.curr
    for l.curr + 1 < len(l.input) {
        _, next := l.input[l.curr], l.input[l.curr + 1]
        if next == '*' || next == '_' {
            break
        }
        if l.heading && next == '\n' {
            break
        }
        l.curr += 1
    }
    l.tok.type = Token_Type.Text;
    l.tok.body = l.input[text_start:l.curr+1]

    l.curr += 1
    return l.tok, true
}

next_token :: proc(l: ^Lexer_State) -> (Token, bool) {
    if l.curr >= len(l.input) do return Token{}, false

    ch := l.input[l.curr]
    switch ch {
    case '*':
        l.tok.type = Token_Type.Italic_End if l.italic else Token_Type.Italic_Start;
        l.tok.body = ""

        l.italic = !l.italic
        l.curr += 1

        return l.tok, true
    case '_':
        l.tok.type = Token_Type.Bold_End if l.bold else Token_Type.Bold_Start;
        l.tok.body = ""

        l.bold = !l.bold
        l.curr += 1

        return l.tok, true
    case '#':
        l.tok.type = Token_Type.Heading_Start;
        l.tok.body = ""

        l.heading = true;
        l.curr += 1

        return l.tok, true
    case '\n':
        if l.heading {
            l.heading = false;
            l.tok.type = Token_Type.Heading_End;
            l.tok.body = ""

            return l.tok, true
        } else {
            return consume_text(l)
        }
    case:
        return consume_text(l)
    }
    return Token{}, false
}

main :: proc() {
    when ODIN_DEBUG {
        fmt.eprintln("=== DEBUG RUN ===")
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    if len(os.args)-1 != 1 {
        fmt.println("usage: markdown FILE")
        os.exit(1)
    }
    defer delete(os.args) // valgrind thinks it's a leak: https://github.com/odin-lang/Odin/issues/1634
    fname := os.args[1]
    data, ok := os.read_entire_file_from_filename(fname);
    if !ok {
        fmt.printf("cannot read file %v\n", fname)
        os.exit(1)
    }
    defer delete(data, context.allocator)

    lexer := init_lexer(cast(string)data);
    for {
        tok, has := next_token(&lexer);
        if !has do break
            switch tok.type {
            case Token_Type.Text: 
                fmt.print(tok.body)
            case Token_Type.Heading_Start: 
                fmt.print("<h1>")
            case Token_Type.Heading_End: 
                fmt.print("</h1>")
            case Token_Type.Italic_Start: 
                fmt.print("<em>")
            case Token_Type.Italic_End: 
                fmt.print("</em>")
            case Token_Type.Bold_Start: 
                fmt.print("<strong>")
            case Token_Type.Bold_End: 
                fmt.print("</strong>")
            }
        }
    }

