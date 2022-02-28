%token COM DOT MINUS STAR LPA RPA INTOPEN INTCLOSE EQ
%token TRUE FALSE
%token NEG CONJ DISJ IMPLIES
%token EXISTS FORALL
%token PREVIOUS NEXT SINCE UNTIL ONCE EVENTUALLY PAST_ALWAYS ALWAYS
%token <string> ID
%token <int> CST
%token EOF

%right SINCE UNTIL
%nonassoc PREVIOUS NEXT ONCE EVENTUALLY PAST_ALWAYS ALWAYS
%right EXISTS FORALL
%right IMPLIES
%left DISJ
%left CONJ
%nonassoc NEG

%type <int FO.FOInt.fmla> formula
%start formula

%%

formula:
  | f=f EOF        { f }

number:
  | n=CST          { n }
  | MINUS n=CST    { -n }

infnumber:
  | n=CST          { Some n }
  | MINUS n=CST    { Some (-n) }
  | STAR           { None }

interval:
  |                                            { FO.TimestampInt.Interval (Some 0, None, true, true) }
  | INTOPEN l=number COM r=infnumber INTCLOSE  { FO.TimestampInt.Interval (Some l, r, true, true) }

f:
  | LPA f=f RPA                           { f }
  | TRUE                                  { FO.FOInt.True }
  | FALSE                                 { FO.FOInt.False }
  | ID LPA termlist RPA                   { FO.FOInt.Pred ($1, $3) }
  | ID EQ t=term                          { FO.FOInt.Eq ($1, t) }
  | NEG f=f                               { FO.FOInt.Neg f }
  | f=f CONJ g=f                          { FO.FOInt.Conj (f, g) }
  | f=f DISJ g=f                          { FO.FOInt.Disj (f, g) }
  | f=f IMPLIES g=f                       { FO.FOInt.Disj (FO.FOInt.Neg f, g) }
  | EXISTS ID DOT f=f %prec EXISTS        { FO.FOInt.Exists ($2, f) }
  | FORALL ID DOT f=f %prec FORALL        { FO.FOInt.Neg (FO.FOInt.Exists ($2, FO.FOInt.Neg f)) }
  | PREVIOUS i=interval f=f               { FO.FOInt.Prev (i, f) }
  | NEXT i=interval f=f                   { FO.FOInt.Next (i, f) }
  | f=f SINCE i=interval g=f              { FO.FOInt.Since (f, i, g) }
  | f=f UNTIL i=interval g=f              { FO.FOInt.Until (f, i, g) }
  | ONCE i=interval f=f                   { FO.FOInt.Since (FO.FOInt.True, i, f) }
  | EVENTUALLY i=interval f=f             { FO.FOInt.Until (FO.FOInt.True, i, f) }
  | PAST_ALWAYS i=interval f=f            { FO.FOInt.Neg (FO.FOInt.Since (FO.FOInt.True, i, FO.FOInt.Neg f)) }
  | ALWAYS i=interval f=f                 { FO.FOInt.Neg (FO.FOInt.Until (FO.FOInt.True, i, FO.FOInt.Neg f)) }

termlist:
  | term COM termlist       { $1 :: $3 }
  | term                    { [$1] }
  |                         { [] }

term:
  | CST                     { FO.FOInt.Const $1 }
  | ID                      { FO.FOInt.Var $1 }
