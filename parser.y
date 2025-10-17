%{
#include <iostream>
#include <string>
#include <cstring>
#include "al.hpp"
#include "symbol_table.hpp"

extern int alpha_yylex(void*);
extern int yylineno;
extern char* yytext;
extern FILE* yyin;

int yyerror(const char* message);

// Wrapper for yylex to call alpha_yylex
int yylex(void* yylval) {
    return alpha_yylex(yylval);
}

int anon_func_counter = 0;
unsigned int current_line = 1;
int function_nesting = 0;  
int loop_nesting = 0;     

%}

%define api.pure full
%define parse.trace
%expect 1

%union {
    alpha_token_t* token;
    Node* node;  
}

%token <token> IF ELSE WHILE FOR FUNCTION RETURN BREAK CONTINUE AND NOT OR LOCAL TRUE FALSE NIL
%token <token> ASSIGN PLUS MINUS MUL DIV MOD EQUALS NOT_EQUALS INCREMENT DECREMENT GREATER LESS
%token <token> GREATER_EQUAL LESS_EQUAL LEFT_BRACE RIGHT_BRACE LEFT_BRACKET RIGHT_BRACKET
%token <token> LEFT_PAREN RIGHT_PAREN SEMICOLON COMMA COLON COLONCOLON DOT DOTDOT
%token <token> INTCONST REALCONST STRINGCONST IDENT COMMENT_LINE COMMENT_BLOCK COMMENT_NESTED
%token <token> ESCAPE_NEWLINE ESCAPE_TAB UNDEFINED

%type <node> lvalue member  // Declare types for nonterminals

%right ASSIGN
%left OR
%left AND
%nonassoc EQUALS NOT_EQUALS
%nonassoc GREATER GREATER_EQUAL LESS LESS_EQUAL
%left PLUS MINUS
%left MUL DIV MOD
%right NOT INCREMENT DECREMENT UMINUS
%left DOT DOTDOT
%left LEFT_BRACKET RIGHT_BRACKET
%left LEFT_PAREN RIGHT_PAREN

%start program

%%

program : stmt_list
        ;

stmt_list : stmt stmt_list
          | /* empty */
          ;

stmt : expr SEMICOLON { delete $2; }
     | ifstmt
     | whilestmt
     | forstmt
     | returnstmt
     | BREAK SEMICOLON { 
          if (loop_nesting == 0) { 
              yyerror("break statement outside of loop"); 
          }
          delete $1; delete $2; 
      }
     | CONTINUE SEMICOLON { 
          if (loop_nesting == 0) { 
              yyerror("continue statement outside of loop"); 
          }
          delete $1; delete $2; 
      }
     | block
     | funcdef
     | SEMICOLON { delete $1; }
     | COMMENT_LINE { delete $1; }
     | COMMENT_BLOCK { delete $1; }
     | COMMENT_NESTED { delete $1; }
     | UNDEFINED { cerr << "\033[31mError\033[0m : Undefined token at line " << $1->line_number << endl; delete $1; }
     ;

expr : assignexpr
     | expr PLUS expr { delete $2; }
     | expr MINUS expr { delete $2; }
     | expr MUL expr { delete $2; }
     | expr DIV expr { delete $2; }
     | expr MOD expr { delete $2; }
     | expr GREATER expr { delete $2; }
     | expr GREATER_EQUAL expr { delete $2; }
     | expr LESS expr { delete $2; }
     | expr LESS_EQUAL expr { delete $2; }
     | expr EQUALS expr { delete $2; }
     | expr NOT_EQUALS expr { delete $2; }
     | expr AND expr { delete $2; }
     | expr OR expr { delete $2; }
     | term
     ;

term : LEFT_PAREN expr RIGHT_PAREN { delete $1; delete $3; }
     | MINUS expr %prec UMINUS { delete $1; }
     | NOT expr { delete $1; }
     | INCREMENT lvalue { 
         SymbolEntry* entry = symbol_table.lookup($2->content);
         if (entry && (entry->type == SymbolType::USER_FUNCTION || 
                       entry->type == SymbolType::LIBRARY_FUNCTION)) {
             cerr << "\033[31mError\033[0m: Using " 
                       << (entry->type == SymbolType::USER_FUNCTION ? "ProgramFunc" : "LibFunc") 
                       << " as an lvalue" << endl;
             YYERROR;
         }
         delete $1;
     }
     | lvalue INCREMENT { 
         SymbolEntry* entry = symbol_table.lookup($1->content);
         if (entry && (entry->type == SymbolType::USER_FUNCTION || 
                       entry->type == SymbolType::LIBRARY_FUNCTION)) {
             cerr << "\033[31mError\033[0m: Using " 
                       << (entry->type == SymbolType::USER_FUNCTION ? "ProgramFunc" : "LibFunc") 
                       << " as an lvalue" << endl;
             YYERROR;
         }
         delete $2;
     }
     | DECREMENT lvalue { 
         SymbolEntry* entry = symbol_table.lookup($2->content);
         if (entry && (entry->type == SymbolType::USER_FUNCTION || 
                       entry->type == SymbolType::LIBRARY_FUNCTION)) {
             cerr << "\033[31mError\033[0m: Using " 
                       << (entry->type == SymbolType::USER_FUNCTION ? "ProgramFunc" : "LibFunc") 
                       << " as an lvalue" << endl;
             YYERROR;
         }
         delete $1;
     }
     | lvalue DECREMENT { 
         SymbolEntry* entry = symbol_table.lookup($1->content);
         if (entry && (entry->type == SymbolType::USER_FUNCTION || 
                       entry->type == SymbolType::LIBRARY_FUNCTION)) {
             cerr << "\033[31mError\033[0m: Using " 
                       << (entry->type == SymbolType::USER_FUNCTION ? "ProgramFunc" : "LibFunc") 
                       << " as an lvalue" << endl;
             YYERROR;
         }
         delete $2;
     }
     | primary
     ;

assignexpr : lvalue ASSIGN expr { 
               SymbolEntry* entry = symbol_table.lookup($1->content);
               if (entry && (entry->type == SymbolType::USER_FUNCTION || 
                             entry->type == SymbolType::LIBRARY_FUNCTION)) {
                   cerr << "\033[31mError\033[0m: Using " 
                             << (entry->type == SymbolType::USER_FUNCTION ? "ProgramFunc" : "LibFunc") 
                             << " as an lvalue" << endl;
                   YYERROR;
               }
               delete $2;
           }
           ;

primary : lvalue
        | call
        | objectdef
        | LEFT_PAREN funcdef RIGHT_PAREN { delete $1; delete $3; }
        | const
        ;

lvalue : IDENT { 
    SymbolEntry* entry = symbol_table.lookup($1->content);
    if (!entry) {
        if (function_nesting == 0) {
            // Outside functions: declare as global or local based on scope
            if (symbol_table.get_current_scope() == 0) {
                symbol_table.insert($1->content, SymbolType::GLOBAL_VARIABLE, yylineno);
            } else {
                symbol_table.insert($1->content, SymbolType::LOCAL_VARIABLE, yylineno);
            }
        } else {
            // Inside function, declare as local
            symbol_table.insert($1->content, SymbolType::LOCAL_VARIABLE, yylineno);
            entry = symbol_table.lookup($1->content);
        }
    }
    $$ = new Node($1->content);
}
       | LOCAL IDENT { 
            SymbolEntry* entry = symbol_table.lookup($2->content, symbol_table.get_current_scope());
            if (!entry) {
                if (symbol_table.is_library_function($2->content)) {
                    yyerror("Cannot shadow library function");
                } else {
                    symbol_table.insert($2->content, SymbolType::LOCAL_VARIABLE, yylineno);
                }
            }
            $$ = new Node($2->content);
            delete $1; delete $2;
        }
       | COLONCOLON IDENT { 
            SymbolEntry* entry = symbol_table.lookup_global($2->content);
            if (!entry) {
                string error_msg = "ERROR: No global variable '::" + string($2->content) + "' exists";
                yyerror(error_msg.c_str());
                YYERROR;
            }
            $$ = new Node($2->content);
            delete $1; delete $2;
        }
       | member { $$ = $1; }
       ;

member : lvalue DOT IDENT { $$ = new Node(/* combine $1 and $3 */); delete $2; delete $3; }
       | lvalue LEFT_BRACKET expr RIGHT_BRACKET { $$ = new Node(/* combine $1 and $3 */); delete $2; delete $4; }
       | call DOT IDENT { $$ = new Node(/* combine $1 and $3 */); delete $2; delete $3; }
       | call LEFT_BRACKET expr RIGHT_BRACKET { $$ = new Node(/* combine $1 and $3 */); delete $2; delete $4; }
       ;

call : call LEFT_PAREN elist RIGHT_PAREN { delete $2; delete $4; }
     | lvalue callsuffix 
     | LEFT_PAREN funcdef RIGHT_PAREN LEFT_PAREN elist RIGHT_PAREN { delete $1; delete $3; delete $4; delete $6; }
     ;

callsuffix : normcall
           | methodcall
           ;

normcall : LEFT_PAREN elist RIGHT_PAREN { delete $1; delete $3; }
         ;

methodcall : DOTDOT IDENT LEFT_PAREN elist RIGHT_PAREN { delete $1; delete $2; delete $3; delete $5; }
           ;

elist : expr
      | elist COMMA expr { delete $2; }
      | /* empty */
      ;

objectdef : LEFT_BRACKET elist RIGHT_BRACKET { delete $1; delete $3; }
          | LEFT_BRACKET indexed RIGHT_BRACKET { delete $1; delete $3; }
          ;

indexed : indexedelem
        | indexed COMMA indexedelem { delete $2; }
        ;

indexedelem : LEFT_BRACE expr COLON expr RIGHT_BRACE { delete $1; delete $3; delete $5; }
            ;

funcdef : FUNCTION funcprefix LEFT_PAREN { symbol_table.increase_scope(); } idlist RIGHT_PAREN { function_nesting++; } funcblock { 
      function_nesting--;
      symbol_table.decrease_scope();
      delete $1; delete $3; delete $6;
  }
  ;

funcblock : LEFT_BRACE stmt_list RIGHT_BRACE { 
      delete $1; delete $3;
  }
  ;

block : LEFT_BRACE { symbol_table.increase_scope(); } stmt_list RIGHT_BRACE { 
      symbol_table.decrease_scope();
      delete $1; delete $4;
  }
  ;

funcprefix : IDENT { 
                if (symbol_table.is_library_function($1->content)) {
                    yyerror("Cannot redefine library function");
                } else {
                    symbol_table.insert($1->content, SymbolType::USER_FUNCTION, yylineno);
                }
                delete $1;
            }
           | /* anonymous function */ { 
                char anon_name[20];
                sprintf(anon_name, "$%d", anon_func_counter++);
                symbol_table.insert(anon_name, SymbolType::USER_FUNCTION, yylineno);
            }
           ;

const : INTCONST { delete $1; }
      | REALCONST { delete $1; }
      | STRINGCONST { delete $1; }
      | NIL { delete $1; }
      | TRUE { delete $1; }
      | FALSE { delete $1; }
      ;

idlist : IDENT { 
           symbol_table.insert($1->content, SymbolType::FORMAL_ARGUMENT, yylineno);
           delete $1;
       }
       | idlist COMMA IDENT { 
           symbol_table.insert($3->content, SymbolType::FORMAL_ARGUMENT, yylineno);
           delete $2; delete $3;
       }
       | /* empty */
       ;

ifstmt : IF LEFT_PAREN expr RIGHT_PAREN stmt { 
           delete $1; delete $2; delete $4; 
       }
       | IF LEFT_PAREN expr RIGHT_PAREN stmt ELSE stmt { 
           delete $1; delete $2; delete $4; delete $6; 
       }
       ;

whilestmt : WHILE LEFT_PAREN expr RIGHT_PAREN { loop_nesting++; } stmt { 
              loop_nesting--;
              delete $1; delete $2; delete $4; 
          }
          ;

forstmt : FOR LEFT_PAREN elist SEMICOLON expr SEMICOLON elist RIGHT_PAREN { loop_nesting++; } stmt { 
            loop_nesting--;
            delete $1; delete $2; delete $4; delete $6; delete $8; 
        }
        ;

returnstmt : RETURN expr SEMICOLON { 
               if (function_nesting == 0) { 
                   yyerror("return statement outside of function"); 
               }
               delete $1; delete $3; 
           }
           | RETURN SEMICOLON { 
               if (function_nesting == 0) { 
                   yyerror("return statement outside of function"); 
               }
               delete $1; delete $2; 
           }
           ;

%%

int yyerror(const char* message) {
    std::cerr << "\033[31mError\033[0m at line " << yylineno << ": " << message << std::endl;
    return 1;
}