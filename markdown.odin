package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"

Token :: struct {
    type: Token_Type,
    loc: Loc,
}

Token_Type :: union {
    Heading_Start,
    Heading_End,
    Bold_Start,
    Bold_End,
    Italic_Start,
    Italic_End,
    Text,
}

Heading_Start :: struct{level: int}
Heading_End :: struct{}
Bold_Start :: struct{}
Bold_End :: struct{}
Italic_Start :: struct{}
Italic_End :: struct{}
Text :: distinct string

Loc :: struct {
    //file: string,
    index: int,
    //line: int,
    //col: int,
}

Lexer :: struct {
    input: string,

    tok: Token,
    cursor: int,

    inside_heading: bool,
    inside_italic: bool,
    inside_bold: bool,
}

init_lexer :: proc(input: string) -> Lexer {
    l := Lexer{input = input}
    return l
}

//consume_text_until :: proc(l: ^Lexer, stop_if_next: []rune) {
//    for l.cursor+1 <= len(l.input)-1 {
//        next := l.input[l.cursor+1]
//        if ... do break
//        l.cursor += 1
//    }
//}
//
//consume_text :: proc(l: ^Lexer) {
//    for l.cursor+1 <= len(l.input)-1 {
//        next := l.input[l.cursor+1]
//        if next == '*' || next == '_' do break
//
//        l.cursor += 1
//    }
//}

skip_whitespace :: proc(l: ^Lexer) {
    for l.cursor <= len(l.input) && strings.is_space(rune(l.input[l.cursor])) {
        l.cursor += 1
    }
}

next_token :: proc(l: ^Lexer) -> (Token, bool) {
    if l.cursor >= len(l.input) do return Token{}, false

    ch := l.input[l.cursor]
    switch ch {
    case '*':
        l.tok.type = Italic_End{} if l.inside_italic else Italic_Start{};

        l.inside_italic = !l.inside_italic
        l.cursor += 1

        return l.tok, true
    case '_':
        l.tok.type = Bold_End{} if l.inside_bold else Bold_Start{};

        l.inside_bold = !l.inside_bold
        l.cursor += 1

        return l.tok, true
    case '#':
        level := 1
        for l.cursor+1 <= len(l.input)-1 {
            next := rune(l.input[l.cursor+1])
            l.cursor += 1
            if next == '#' do level += 1
            else do break
        }

        l.tok.type = Heading_Start{level = level};

        l.inside_heading = true;
        l.cursor += 1

        return l.tok, true
    case '\n':
        l.tok.type = Heading_End{}

        l.inside_heading = false;
        l.cursor += 1

        return l.tok, true

    case:
        // consume text unless the next char is special

        start := l.cursor

        at_newline := false
        for l.cursor+1 <= len(l.input)-1 {
            next := rune(l.input[l.cursor+1])

            // specials for italic/bold, handled in switch cases
            if next == '*' || next == '_' do break

            // end of heading, handled in switch cases
            if l.inside_heading && next == '\n' do break

            // '#' is special when at newline after whitespace, handled in switch cases
            if at_newline {
                if strings.is_space(next) {
                    l.cursor += 1
                    continue
                } else if next == '#' {
                    break
                } else {
                    at_newline = false
                }
            } else if next == '\n' do at_newline = true

            l.cursor += 1
        }

        l.tok.type = Text(l.input[start:l.cursor+1])
        l.cursor += 1
        return l.tok, true
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

    output := os.stdout
    n := len(os.args)
    if n == 1 || n >= 4 {
        fmt.println("usage: markdown FILE OUTPUT")
        os.exit(1)
    }
    if n == 3 {
        err: os.Error
        output, err = os.open(os.args[2], flags = os.O_WRONLY | os.O_CREATE, mode = 0o666)
        if err != nil {
            fmt.println("can't open output file")
            os.exit(1)
        }
    }
    defer os.close(output)

    fname := os.args[1]
    data, ok := os.read_entire_file_from_filename(fname);
    if !ok {
        fmt.printf("cannot read file %v\n", fname)
        os.exit(1)
    }
    defer delete(data, context.allocator)

    lexer := init_lexer(string(data));
    for {
        tok, has := next_token(&lexer);
        if !has do break
        switch t in tok.type {
        case Text:
            _, err := os.write_string(output, string(t))
            fmt.println(err)
        case Heading_Start:
            os.write_string(output, "<h1>")
        case Heading_End:
            os.write_string(output, "</h1>")
        case Italic_Start:
            os.write_string(output, "<em>")
        case Italic_End:
            os.write_string(output, "</em>")
        case Bold_Start:
            os.write_string(output, "<strong>")
        case Bold_End:
            os.write_string(output, "</strong>")
        }
    }
}

