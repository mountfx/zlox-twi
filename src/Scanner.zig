const std = @import("std");

const Scanner = @This();

source: []const u8,
tokens: std.ArrayList(Token),
keywords: std.StaticStringMap(Token.Type) = std.StaticStringMap(Token.Type).initComptime(.{
    .{ "and", .And },
    .{ "class", .Class },
    .{ "else", .Else },
    .{ "false", .False },
    .{ "for", .For },
    .{ "fun", .Fun },
    .{ "if", .If },
    .{ "nil", .Nil },
    .{ "or", .Or },
    .{ "print", .Print },
    .{ "return", .Return },
    .{ "super", .Super },
    .{ "this", .This },
    .{ "true", .True },
    .{ "var", .Var },
    .{ "while", .While },
}),

start: usize,
current: usize,
line: usize,

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or (char == '_');
}

fn isAlphaNumeric(char: u8) bool {
    return isAlpha(char) or isDigit(char);
}

pub fn init(allocator: std.mem.Allocator, source: []const u8) Scanner {
    return .{
        .source = source,
        .tokens = std.ArrayList(Token).init(allocator),
        .start = 0,
        .current = 0,
        .line = 1,
    };
}

pub fn scanTokens(self: *Scanner) !std.ArrayList(Token) {
    while (!self.isAtEnd()) {
        _ = try self.tokens.append(self.scanToken());
    }

    return self.tokens;
}

pub fn scanToken(self: *Scanner) Token {
    self.skipWhitespace();

    self.start = self.current;

    if (self.isAtEnd()) return self.makeToken(.Eof);

    const c = self.peek();
    self.advance();

    return switch (c) {
        // Single character lexemes
        '(' => self.makeToken(.LeftParen),
        ')' => self.makeToken(.RightParen),
        '{' => self.makeToken(.LeftBrace),
        '}' => self.makeToken(.RightBrace),
        ',' => self.makeToken(.Comma),
        '.' => self.makeToken(.Dot),
        '-' => self.makeToken(.Minus),
        '+' => self.makeToken(.Plus),
        ';' => self.makeToken(.Semicolon),
        '*' => self.makeToken(.Star),
        '/' => self.makeToken(.Slash),

        // Many character lexemes
        '!' => self.makeToken(if (self.match('=')) .BangEqual else .Bang),
        '=' => self.makeToken(if (self.match('=')) .EqualEqual else .Equal),
        '<' => self.makeToken(if (self.match('=')) .LessEqual else .Less),
        '>' => self.makeToken(if (self.match('=')) .GreaterEqual else .Greater),

        // Literals
        '"' => self.scanString(),

        else => {
            if (isDigit(c)) return self.scanNumber();
            if (isAlpha(c)) return self.scanIdentifier();
            return self.makeError("Unexpected character");
        },
    };
}

pub fn peek(self: *Scanner) u8 {
    if (self.isAtEnd()) return 0;
    return self.source[self.current];
}

pub fn peekNext(self: *Scanner) u8 {
    return self.source[self.current + 1];
}

pub fn advance(self: *Scanner) void {
    self.current += 1;
}

pub fn match(self: *Scanner, char: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.peek() != char) return false;
    self.current += 1;
    return true;
}

pub fn isAtEnd(self: *Scanner) bool {
    return self.current >= self.source.len;
}

pub fn makeToken(self: *Scanner, tokenType: Token.Type) Token {
    return .{
        .type = tokenType,
        .lexeme = self.source[self.start..self.current],
        .line = self.line,
    };
}

pub fn makeError(self: *Scanner, message: []const u8) Token {
    return .{
        .type = .Error,
        .lexeme = message,
        .line = self.line,
    };
}

pub fn scanString(self: *Scanner) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') {
            self.line += 1;
        }
        self.advance();
    }

    if (self.isAtEnd()) return self.makeError("Unterminated string");

    self.advance();
    return self.makeToken(.String);
}

pub fn scanNumber(self: *Scanner) Token {
    while (isDigit(self.peek())) self.advance();

    if (self.peek() == '.' and isDigit(self.peekNext())) {
        self.advance();
        while (isDigit(self.peek())) self.advance();
    }

    return self.makeToken(.Number);
}

pub fn scanIdentifier(self: *Scanner) Token {
    while (isAlphaNumeric(self.peek())) self.advance();
    const keyword = self.keywords.get(self.source[self.start..self.current]);
    return self.makeToken(keyword orelse .Identifier);
}

pub fn checkKeyword(self: *Scanner, name: []const u8, ty: Token.Type) Token.Type {
    if (self.current != self.start + name.len) return .Identifier;
    const source = self.source[self.start..self.current];
    return if (std.mem.eql(u8, source, name)) ty else .Identifier;
}

pub fn skipWhitespace(self: *Scanner) void {
    while (true) {
        switch (self.peek()) {
            '\n' => {
                self.line += 1;
                self.advance();
            },
            ' ', '\r', '\t' => {
                self.advance();
            },
            '/' => {
                if (self.peekNext() == '/') {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        self.advance();
                    }
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

pub const Token = struct {
    type: Type,
    lexeme: []const u8,
    line: usize,

    const Type = enum {
        // Single character tokens
        LeftParen,
        RightParen,
        LeftBrace,
        RightBrace,
        Comma,
        Dot,
        Minus,
        Plus,
        Semicolon,
        Slash,
        Star,

        // One or two character tokens
        Bang,
        BangEqual,
        Equal,
        EqualEqual,
        Greater,
        GreaterEqual,
        Less,
        LessEqual,

        // Literals
        Identifier,
        String,
        Number,

        // Keywords
        And,
        Class,
        Else,
        False,
        Fun,
        For,
        If,
        Nil,
        Or,
        Print,
        Return,
        Super,
        This,
        True,
        Var,
        While,

        Error,
        Eof,
    };
};
