package main

import "core:fmt"
import "core:os"

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

Parser_State :: struct {
    input: string,

    tok: Token,
    curr: int,

    heading: bool,
    italic: bool,
    bold: bool,
}

parser :: proc(input: string) -> Parser_State {
    state := Parser_State{input = input}
    return state
}

consume_text :: proc(p: ^Parser_State) -> (Token, bool) {
    text_start := p.curr
    for p.curr + 1 < len(p.input) {
        _, next := p.input[p.curr], p.input[p.curr + 1]
        if next == '*' || next == '_' {
            break
        }
        if p.heading && next == '\n' {
            break
        }
        p.curr += 1
    }
    p.tok.type = Token_Type.Text;
    p.tok.body = p.input[text_start:p.curr+1]

    p.curr += 1
    return p.tok, true
}

next_token :: proc(p: ^Parser_State) -> (Token, bool) {
    if p.curr >= len(p.input) do return Token{}, false

    ch := p.input[p.curr]
    switch ch {
    case '*':
        p.tok.type = Token_Type.Italic_End if p.italic else Token_Type.Italic_Start;
        p.tok.body = ""

        p.italic = !p.italic
        p.curr += 1

        return p.tok, true
    case '_':
        p.tok.type = Token_Type.Bold_End if p.bold else Token_Type.Bold_Start;
        p.tok.body = ""

        p.bold = !p.bold
        p.curr += 1

        return p.tok, true
    case '#':
        p.tok.type = Token_Type.Heading_Start;
        p.tok.body = ""

        p.heading = true;
        p.curr += 1

        return p.tok, true
    case '\n':
        if p.heading {
            p.heading = false;
            p.tok.type = Token_Type.Heading_End;
            p.tok.body = ""

            return p.tok, true
        } else {
            return consume_text(p)
        }
    case:
        return consume_text(p)
    }
    return Token{}, false
}

main :: proc() {
    if len(os.args)-1 != 1 {
        fmt.println("usage: markdown FILE")
        os.exit(1)
    }
    fname := os.args[1]
    data, ok := os.read_entire_file_from_filename(fname);
    if !ok {
        fmt.printf("cannot read file %v\n", fname)
        os.exit(1)
    }
    defer delete(data, context.allocator)

    parser := parser(cast(string)data);
    for {
        t, has := next_token(&parser);
        if !has do break
            switch t.type {
            case Token_Type.Text: 
                fmt.print(t.body)
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

