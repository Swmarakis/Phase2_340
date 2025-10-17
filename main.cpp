#include <iostream>
#include <fstream>
#include <iomanip>
#include "al.hpp"
#include "symbol_table.hpp"

extern int yyparse();
extern FILE *yyin;
extern int yydebug;  

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        cerr << "Usage: " << argv[0] << " <input_file>" << endl;
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin)
    {
        cerr << "Cannot open input file: " << argv[1] << endl;
        return 1;
    }

    cout << "\n\n-----------------------    Syntax Analysis    ----------------------------\n\n" << endl;
    
    yydebug = 0;  // Enable debug output
    
    yyparse();
    
    symbol_table.print();
    
    fclose(yyin);
    return 0;
}