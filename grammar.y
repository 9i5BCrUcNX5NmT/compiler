# *** Block Level ***
Statement
     / IfStatement
     / LabeledStatement

IfStatement
    <- IfPrefix BlockExpr ( KEYWORD_else Statement )?

LabeledStatement <- Block / LoopStatement

LoopStatement <- WhileStatement

WhileStatement
    <- WhilePrefix BlockExpr

BlockExprStatement
    <- BlockExpr
     / AssignExpr SEMICOLON

BlockExpr <- Block


# *** Expression Level ***

# An assignment or a destructure whose LHS are all lvalue expressions.
AssignExpr <- Expr (AssignOp Expr)?

Expr <- BoolOrExpr

BoolOrExpr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*

BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*

CompareExpr <- AdditionExpr (CompareOp AdditionExpr)?

AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*

MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)*

PrefixExpr <- PrefixOp* PrimaryExpr

PrimaryExpr
    <- IfExpr
     / LoopExpr
     / Block
     / SuffixExpr


IfExpr <- IfPrefix Expr (KEYWORD_else Expr)?

Block <- LBRACE Statement* RBRACE

LoopExpr <- WhileExp

WhileExpr <- WhilePrefix Expr


# Control flow prefixes
IfPrefix <- KEYWORD_if LPAREN Expr RPAREN

WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN

SuffixExpr
    <- PrimaryTypeExpr (SuffixOp)*

PrimaryTypeExpr
    <- GroupedExpr
     / IDENTIFIER
     / IfTypeExpr
     / INTEGER

GroupedExpr <- LPAREN Expr RPAREN

IfTypeExpr <- IfPrefix TypeExpr (KEYWORD_else TypeExpr)?

WhileTypeExpr <- WhilePrefix TypeExpr


# *** Tokens ***
dec <- [0-9]
bin <- [01]

# Operators
AssignOp
    <- EQUAL

# сравнение
CompareOp
    <- EQUALEQUAL
     / LARROW
     / RARROW
     / LARROWEQUAL
     / RARROWEQUAL

# вычитание, сложение
AdditionOp
    <- PLUS
     / MINUS

# умножение, деление
MultiplyOp
    <- ASTERISK
     / SLASH

# знак перед выражением
PrefixOp
    <- EXCLAMATIONMARK
     / MINUS

INTEGER
    <- dec skip


LPAREN <- '(' skip
RPAREN <- ')' skip
PIPE <- '|' skip
ASTERISK             <- '*'      ![*%=|]   skip
COLON                <- ':'                skip
COMMA                <- ','                skip
EQUAL                <- '='      ![>=]     skip
EQUALEQUAL           <- '=='               skip
EXCLAMATIONMARK      <- '!'      ![=]      skip
LARROW               <- '<'      ![<=]     skip
LARROWEQUAL          <- '<='               skip
LBRACE               <- '{'                skip
MINUS                <- '-'      ![%=>|]   skip
PLUS                 <- '+'      ![%+=|]   skip
RARROWEQUAL          <- '>='               skip
RBRACE               <- '}'                skip
SEMICOLON            <- ';'                skip
SLASH                <- '/'      ![=]      skip


IDENTIFIER <- !keyword [A-Za-z_] [A-Za-z0-9_]* skip

end_of_word <- ![a-zA-Z0-9_] skip
KEYWORD_if <- 'if' end_of_word
KEYWORD_while <- 'while' end_of_word
KEYWORD_and <- 'and' end_of_word
KEYWORD_or <- 'or' end_of_word


keyword <- KEYWORD_if / KEYWORD_while / KEYWORD_and / KEYWORD_or