{
open Lexing
open Fo_parser
}

let blank = [' ' '\r' '\n' '\t']
let num = ['0'-'9']+
let alpha = ['a'-'z' 'A'-'Z']
let alphanums = ['a'-'z' 'A'-'Z' '0'-'9']*

rule token = parse
  | blank                                         { token lexbuf }
  | ","                                           { COM }
  | "."                                           { DOT }
  | "-"                                           { MINUS }
  | "*"                                           { STAR }
  | "("                                           { LPA }
  | ")"                                           { RPA }
  | "["                                           { INTOPEN }
  | "]"                                           { INTCLOSE }
  | "="                                           { EQ }
  | "TRUE"                                        { TRUE }
  | "FALSE"                                       { FALSE }
  | "NOT"                                         { NEG }
  | "AND"                                         { CONJ }
  | "OR"                                          { DISJ }
  | "IMPLIES"                                     { IMPLIES }
  | "EXISTS"                                      { EXISTS }
  | "FORALL"                                      { FORALL }
  | "PREVIOUS"                                    { PREVIOUS }
  | "NEXT"                                        { NEXT }
  | "SINCE"                                       { SINCE }
  | "UNTIL"                                       { UNTIL }
  | "ONCE"                                        { ONCE }
  | "EVENTUALLY"                                  { EVENTUALLY }
  | "PAST_ALWAYS"                                 { PAST_ALWAYS }
  | "ALWAYS"                                      { ALWAYS }
  | (alpha alphanums) as name                     { ID name }
  | num as n                                      { CST (int_of_string n) }
  | eof                                           { EOF }
  | _                                             { failwith "unexpected character" }
