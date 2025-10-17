CC = g++                # Compiler
CFLAGS = -std=c++17 -fPIC  # Compiler flags
BISON = bison           # Bison command
FLEX = flex             # Flex command

SRC = main.cpp symbol_table.cpp al.cpp parser.tab.cpp alpha.lex.cpp
BISON_OUT = parser.tab.cpp parser.tab.hpp
FLEX_OUT = alpha.lex.cpp
EXEC = alpha_parser

all: $(EXEC)

parser.tab.cpp parser.tab.hpp: parser.y
	$(BISON) -d parser.y -o parser.tab.cpp

alpha.lex.cpp: alpha.l parser.tab.hpp
	$(FLEX) -o alpha.lex.cpp alpha.l

$(EXEC): $(SRC)
	$(CC) $(CFLAGS) -o $(EXEC) $(SRC)

clean:
	rm -f $(EXEC) $(BISON_OUT) $(FLEX_OUT)