#pragma once

#include "minimizer/json.hpp"

#include <map>
#include <optional>
#include <string>
#include <vector>

namespace minimizer {

struct Operand {
    std::string kind;
    std::string table;
    std::string column;
    std::string type;
    std::string value;
};

struct Check {
    std::string id;
    std::string table;
    std::string expression;
    bool supported = false;
    std::string unsupported_reason;
    std::string op;
    std::optional<Operand> left;
    std::optional<Operand> right;
};

struct Row {
    std::string table;
    std::map<std::string, std::optional<std::string>> values;
};

struct Test {
    std::string id;
    bool expected_result = false;
    std::vector<std::string> requirement_ids;
    std::vector<Row> state;
    std::vector<Row> data;
    int state_insert_count = 0;
    int data_insert_count = 0;
};

struct Input {
    int format_version = 0;
    std::string snapshot_sha256;
    std::vector<Check> checks;
    std::vector<Test> tests;
};

Input parse_input(const Json& root);

}  // namespace minimizer
