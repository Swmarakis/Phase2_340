#ifndef SYMBOL_TABLE_HPP
#define SYMBOL_TABLE_HPP

#include <string>
#include <vector>
#include <iostream>

using namespace std;

enum class SymbolType {
    GLOBAL_VARIABLE,
    LOCAL_VARIABLE,
    FORMAL_ARGUMENT,
    USER_FUNCTION,
    LIBRARY_FUNCTION
};

struct SymbolEntry {
    string name;
    SymbolType type;
    int line;
    int scope;

    SymbolEntry(const string& n, SymbolType t, int l, int s)
        : name(n), type(t), line(l), scope(s) {}
};

class SymbolTable {
private:
    vector<vector<SymbolEntry>> scopes;
    int current_scope;

public:
    SymbolTable();
    void increase_scope();
    void decrease_scope();
    void insert(const string& name, SymbolType type, int line);
    bool is_library_function(const string& name);
    int get_current_scope() const { return current_scope; }
    void print() const;
    SymbolEntry* lookup(const string& name);
    SymbolEntry* lookup(const string& name, int scope);
    SymbolEntry* lookup_global(const string& name);
    SymbolEntry* lookup_function(const string& name);  // restricted lookup
};

extern SymbolTable symbol_table;

#endif